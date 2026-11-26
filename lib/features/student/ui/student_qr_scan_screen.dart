import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/api/api_client.dart';
import '../../../core/gps/gps_service.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/student_provider.dart';

class StudentQRScanScreen extends ConsumerStatefulWidget {
  const StudentQRScanScreen({super.key});

  @override
  ConsumerState<StudentQRScanScreen> createState() => _StudentQRScanScreenState();
}

class _StudentQRScanScreenState extends ConsumerState<StudentQRScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    returnImage: false,
    detectionSpeed: DetectionSpeed.unrestricted,
    detectionTimeoutMs: 250,
    formats: const [BarcodeFormat.all],
  );
  bool _isProcessing = false;
  bool _isSwitchingCamera = false;
  String? _statusMessage;
  Color _statusColor = AppTheme.primaryAccent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final res = await Permission.camera.request();
      if (res.isGranted) {
        try {
          await _controller.start();
        } catch (_) {}
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _restartScanner();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        try {
          _controller.stop();
        } catch (_) {}
        break;
    }
  }

  Future<void> _restartScanner() async {
    try {
      await _controller.stop();
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        await _controller.start();
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _safeSwitchCamera() async {
    if (_isSwitchingCamera) return;
    setState(() => _isSwitchingCamera = true);
    try {
      // Turn off torch before switching to front camera to prevent hardware crashes
      if (_controller.torchState.value == TorchState.on) {
        try {
          await _controller.toggleTorch();
        } catch (_) {}
      }
      await _controller.switchCamera();
    } catch (e) {
      debugPrint('[StudentScanner] Switch camera error: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'Could not switch camera: Device has only one camera or camera is busy.');
      }
    } finally {
      if (mounted) setState(() => _isSwitchingCamera = false);
    }
  }

  Future<void> _safeToggleTorch() async {
    try {
      if (_controller.cameraFacingState.value == CameraFacing.front) {
        if (mounted) {
          AppSnackBar.showInfo(context, 'Flashlight is not available on front camera.');
        }
        return;
      }
      await _controller.toggleTorch();
    } catch (e) {
      debugPrint('[StudentScanner] Toggle torch error: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'Flashlight is not supported or unavailable.');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Reading session code...';
      _statusColor = AppTheme.primaryAccent;
    });

    // Parse Session QR payload:
    // Format: "VET_SESSION:<sessionId>:<stageName>:<timestamp>:<tripType>" or raw sessionId
    String sessionId = rawValue.trim();
    String stageName = 'Bus Stage';
    String? tripType;

    if (rawValue.startsWith('VET_SESSION:') || rawValue.startsWith('TRIPMATE_SESSION:')) {
      final parts = rawValue.split(':');
      if (parts.length >= 2 && parts[1].isNotEmpty) sessionId = parts[1];
      if (parts.length >= 3 && parts[2].isNotEmpty) stageName = parts[2];
      if (parts.length >= 5 && parts[4].isNotEmpty) tripType = parts[4];
    }

    final isEvening = tripType == 'evening' || DateTime.now().hour >= 13;
    final attendanceType = isEvening ? 'exit' : 'boarding';

    final profile = ref.read(studentProfileProvider).value;
    final defaultRoll = profile?['roll_number'] ?? '';
    final studentName = profile?['name'] ?? 'Student';

    if (!mounted) return;

    // Show Confirmation Dialog before marking
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConfirmAttendanceSheet(
        sessionId: sessionId,
        stageName: stageName,
        studentName: studentName,
        rollNumber: defaultRoll,
        attendanceType: attendanceType,
      ),
    );

    if (confirmed != true) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
      return;
    }

    // Submit Attendance with GPS
    setState(() {
      _statusMessage = 'Verifying and recording attendance...';
    });

    try {
      final gps = ref.read(gpsServiceProvider);
      final pos = await gps.getCurrentPosition();
      final api = ref.read(apiClientProvider);

      await api.studentSelfMarkAttendance({
        'sessionId': sessionId,
        'rollNumber': defaultRoll,
        'attendanceType': attendanceType,
        if (pos?.latitude != null) 'latitude': pos!.latitude,
        if (pos?.longitude != null) 'longitude': pos!.longitude,
      });

      if (!mounted) return;

      // Invalidate student today & stats
      ref.invalidate(studentTodayAttendanceProvider);
      ref.invalidate(studentAttendanceStatsProvider);

      // Voice Announcement: "Verified, <Student Name>"
      VoiceService.instance.speakVerified(studentName);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          // Auto-dismiss after ~1.7 seconds to automatically return to student dashboard
          Future.delayed(const Duration(milliseconds: 1700), () {
            if (ctx.mounted) {
              Navigator.of(ctx, rootNavigator: true).pop();
              if (mounted) {
                context.go('/student');
              }
            }
          });

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF16A34A).withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verified!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    studentName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Roll No: $defaultRoll • Stop: $stageName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Redirecting to dashboard...',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Failed: ${e.toString().replaceAll('Exception:', '')}';
        _statusColor = AppTheme.danger;
      });

      AppSnackBar.showError(context, 'Attendance failed: ${e.toString().replaceAll('Exception:', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanWindowSize = min(MediaQuery.of(context).size.width * 0.75, 280.0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Scan Bus Stage QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off_rounded, color: Colors.white);
                  case TorchState.on:
                    return const Icon(Icons.flash_on_rounded, color: AppTheme.warning);
                }
              },
            ),
            onPressed: _safeToggleTorch,
            tooltip: 'Toggle Flashlight',
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front_rounded, color: Colors.white);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear_rounded, color: Colors.white);
                }
              },
            ),
            onPressed: _safeSwitchCamera,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: (context, error, child) {
              return _buildScannerError(context, error);
            },
          ),

          // Dark overlay with cutout
          CustomPaint(
            size: Size.infinite,
            painter: _ScannerOverlayPainter(
              windowSize: scanWindowSize,
              borderColor: _statusColor,
            ),
          ),

          // Processing HUD Loader Overlay in Center Viewfinder
          if (_isProcessing)
            Center(
              child: Container(
                width: scanWindowSize * 0.88,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.7), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Recording Self-Attendance...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Submitting to Bus Incharge',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Instruction Header
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: const Row(
                children: [
                  FeatureIconBadge(
                    icon: Icons.qr_code_scanner_rounded,
                    color: AppTheme.primaryAccent,
                    size: 38,
                    iconSize: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Incharge Stage QR',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Point your camera at the QR code on the Incharge\'s screen',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom status pill
          if (_statusMessage != null)
            Positioned(
              bottom: 40,
              left: 32,
              right: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _statusColor.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessing) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerError(BuildContext context, MobileScannerException error) {
    final isPermissionDenied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPermissionDenied ? Icons.no_photography_rounded : Icons.videocam_off_rounded,
                color: AppTheme.danger,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isPermissionDenied ? 'Camera Permission Required' : 'Camera Unavailable',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isPermissionDenied
                  ? 'Camera permission is needed to scan the Incharge Stage QR code. Please grant permission in App Settings.'
                  : 'Unable to start camera (${error.errorCode.name}). You can switch to Front/Back camera or retry.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                if (isPermissionDenied)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await openAppSettings();
                    },
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Open Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _safeSwitchCamera,
                  icon: const Icon(Icons.flip_camera_android_rounded, size: 18, color: Colors.white),
                  label: const Text('Switch Camera', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final status = await Permission.camera.status;
                    if (!status.isGranted) {
                      final res = await Permission.camera.request();
                      if (!res.isGranted) {
                        await openAppSettings();
                        return;
                      }
                    }
                    try {
                      await _controller.stop();
                    } catch (_) {}
                    await Future.delayed(const Duration(milliseconds: 200));
                    try {
                      await _controller.start();
                    } catch (_) {}
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                  label: const Text('Retry Camera', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Confirmation Bottom Sheet
// ============================================================

class _ConfirmAttendanceSheet extends StatelessWidget {
  final String sessionId;
  final String stageName;
  final String studentName;
  final String rollNumber;
  final String attendanceType;

  const _ConfirmAttendanceSheet({
    required this.sessionId,
    required this.stageName,
    required this.studentName,
    required this.rollNumber,
    this.attendanceType = 'boarding',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                FeatureIconBadge(
                  icon: Icons.verified_user_rounded,
                  color: AppTheme.primaryAccent,
                  size: 42,
                  iconSize: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify & Confirm Attendance',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Confirm your details to mark yourself present',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _SheetRow(label: 'Student Name', value: studentName, icon: Icons.person_rounded),
                  const Divider(height: 16),
                  _SheetRow(label: 'Roll Number', value: rollNumber, icon: Icons.badge_rounded),
                  const Divider(height: 16),
                  _SheetRow(label: 'Boarding Stage', value: stageName, icon: Icons.pin_drop_rounded),
                  const Divider(height: 16),
                  _SheetRow(
                    label: 'Attendance Type',
                    value: attendanceType == 'exit' ? 'Evening Return' : 'Morning Boarding',
                    icon: attendanceType == 'exit' ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text('Confirm Present', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label, value;
  final IconData icon;

  const _SheetRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryAccent),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      ],
    );
  }
}

// ============================================================
// Scanner Overlay Painter
// ============================================================

class _ScannerOverlayPainter extends CustomPainter {
  final double windowSize;
  final Color borderColor;

  _ScannerOverlayPainter({required this.windowSize, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: windowSize, height: windowSize);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Border corners
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final cornerLength = 28.0;

    // Top-left
    canvas.drawLine(Offset(rect.left, rect.top + cornerLength), Offset(rect.left, rect.top), borderPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLength, rect.top), borderPaint);

    // Top-right
    canvas.drawLine(Offset(rect.right - cornerLength, rect.top), Offset(rect.right, rect.top), borderPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLength), borderPaint);

    // Bottom-left
    canvas.drawLine(Offset(rect.left, rect.bottom - cornerLength), Offset(rect.left, rect.bottom), borderPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLength, rect.bottom), borderPaint);

    // Bottom-right
    canvas.drawLine(Offset(rect.right - cornerLength, rect.bottom), Offset(rect.right, rect.bottom), borderPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.windowSize != windowSize || oldDelegate.borderColor != borderColor;
}
