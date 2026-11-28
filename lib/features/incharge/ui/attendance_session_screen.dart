import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/gps/gps_service.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/db/local_database.dart';
import '../../../core/widgets/app_loader.dart';
import '../../admin/ui/id_card_parser.dart';
import '../providers/incharge_provider.dart';
import 'qr_scanner_screen.dart' show QrScannerOverlayShape;

class AttendanceSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final Map<String, dynamic>? extra;

  const AttendanceSessionScreen({super.key, required this.sessionId, this.extra});

  @override
  ConsumerState<AttendanceSessionScreen> createState() => _AttendanceSessionState();
}

class _AttendanceSessionState extends ConsumerState<AttendanceSessionScreen> with WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    returnImage: false,
    detectionSpeed: DetectionSpeed.unrestricted,
    detectionTimeoutMs: 250,
    formats: const [BarcodeFormat.all],
  );

  Position? _position;
  String? _currentStageId;
  String? _currentStageName;
  bool _isSwitchingStage = false;

  // Real-Time GPS Stop Identification & Matching State
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _stationaryGpsTimer;
  bool _autoGpsMatch = true;
  bool _isGpsLocating = false;
  Map<String, dynamic>? _nearestStage;
  double? _nearestDistanceMeters;
  bool _isWithinGeofence = false;

  // Scanning State (Door NFC / QR Tap Kiosk)
  bool _isScanningLocked = false;
  Map<String, dynamic>? _lastScannedStudent;
  String? _scanMessage;
  Color _scanCardColor = AppTheme.success;
  bool _isTorchOn = false;

  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  // Scanned-student card: visible for ~1s after each result, then fades out
  bool _cardVisible = false;
  Timer? _cardHideTimer;
  Timer? _messageClearTimer;

  void _flashScanCard({Duration hold = const Duration(seconds: 1)}) {
    _cardHideTimer?.cancel();
    _messageClearTimer?.cancel();
    setState(() => _cardVisible = true);
    _cardHideTimer = Timer(hold, () {
      if (mounted) setState(() => _cardVisible = false);
    });
    _messageClearTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _scanMessage = null);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentStageId = widget.extra?['stage_id']?.toString() ?? widget.extra?['stage']?['id']?.toString();
    _currentStageName = widget.extra?['stage_name']?.toString() ?? widget.extra?['stage']?['stage_name']?.toString() ?? 'Active Stop';
    _startGPSListener();
    _checkCameraPermission();
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
          _scannerController.stop();
        } catch (_) {}
        break;
    }
  }

  Future<void> _restartScanner() async {
    try {
      await _scannerController.stop();
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        await _scannerController.start();
        setState(() {
          _isScanningLocked = false;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stationaryGpsTimer?.cancel();
    _cardHideTimer?.cancel();
    _messageClearTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final res = await Permission.camera.request();
      if (res.isGranted) {
        try {
          await _scannerController.start();
        } catch (_) {}
      }
    }
  }

  List<dynamic> _getAvailableStages() {
    final assignment = ref.read(inchargeAssignmentProvider).value;
    final stages = (assignment?['stages'] as List?) ?? (widget.extra?['stages'] as List?) ?? [];
    return stages;
  }

  Future<void> _startGPSListener() async {
    try {
      final hasPerm = await ref.read(gpsServiceProvider).ensureGpsEnabled(context);
      if (!hasPerm) return;

      // 1. Instant initial fast position
      final initialPos = await ref.read(gpsServiceProvider).getFastPosition();
      if (initialPos != null && mounted) {
        setState(() => _position = initialPos);
        _matchStageFromPosition(initialPos);
      }

      // 2. Continuous real-time GPS stream
      _positionStreamSubscription?.cancel();
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
        _matchStageFromPosition(pos);
      }, onError: (e) {
        debugPrint('[KioskGPS] Position stream error: $e');
      });

      // Periodic check every 5s so when bus is stationary at a stop, GPS matching doesn't stall
      _stationaryGpsTimer?.cancel();
      _stationaryGpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!mounted) return;
        try {
          final fastPos = await ref.read(gpsServiceProvider).getFastPosition(maxAge: const Duration(seconds: 4));
          if (fastPos != null && mounted) {
            setState(() => _position = fastPos);
            _matchStageFromPosition(fastPos);
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[KioskGPS] Error starting GPS stream: $e');
    }
  }

  void _matchStageFromPosition(Position pos, {bool forceSwitch = false, bool showFeedback = false}) {
    final stages = _getAvailableStages();
    if (stages.isEmpty) return;

    Map<String, dynamic>? closest;
    double minDistance = double.infinity;

    for (final st in stages) {
      final lat = double.tryParse(st['latitude']?.toString() ?? '');
      final lon = double.tryParse(st['longitude']?.toString() ?? '');
      if (lat != null && lon != null) {
        final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lon);
        if (d < minDistance) {
          minDistance = d;
          closest = Map<String, dynamic>.from(st);
        }
      }
    }

    if (closest != null) {
      final radius = (closest['allowed_radius_meters'] as num?)?.toDouble() ?? 250.0;
      // Generous auto-switch buffer (minimum 450m) to accommodate approach and mobile GPS drift
      final autoSwitchRadius = radius < 450.0 ? 450.0 : radius;
      final withinGeofence = minDistance <= autoSwitchRadius;

      if (mounted) {
        setState(() {
          _nearestStage = closest;
          _nearestDistanceMeters = minDistance;
          _isWithinGeofence = minDistance <= radius;
        });
      }

      final closestId = closest['id']?.toString() ?? '';
      final closestName = closest['stage_name']?.toString() ?? 'Stop';

      // Auto-match switch if enabled and either inside geofence or force requested
      if ((_autoGpsMatch && withinGeofence) || forceSwitch) {
        if (closestId != _currentStageId && !_isSwitchingStage) {
          _switchStage(closestId, closestName, isAutoGps: true);
        }
      }

      if (showFeedback && mounted) {
        final distStr = minDistance < 1000 ? '${minDistance.round()}m' : '${(minDistance / 1000).toStringAsFixed(1)}km';
        if (withinGeofence || closestId == _currentStageId) {
          AppSnackBar.showSuccess(context, 'GPS Matched Stop: $closestName ($distStr away)');
        } else {
          AppSnackBar.showInfo(context, 'Nearest Stop: $closestName ($distStr away)');
        }
      }
    }
  }

  Future<void> _manualMatchGPS() async {
    setState(() => _isGpsLocating = true);
    try {
      final pos = await ref.read(gpsServiceProvider).getCurrentPosition(timeLimit: const Duration(seconds: 4));
      if (pos != null) {
        setState(() => _position = pos);
        _matchStageFromPosition(pos, forceSwitch: true, showFeedback: true);
      } else {
        if (mounted) AppSnackBar.showError(context, 'GPS coordinates unavailable. Ensure location is enabled.');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'GPS Error: $e');
    } finally {
      if (mounted) setState(() => _isGpsLocating = false);
    }
  }

  Future<void> _switchStage(String newStageId, String newStageName, {bool isAutoGps = false}) async {
    if (_isSwitchingStage || newStageId == _currentStageId) return;
    // Optimistic instantaneous UI update so the screen immediately reflects active stop
    setState(() {
      _isSwitchingStage = true;
      _currentStageId = newStageId;
      _currentStageName = newStageName;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.switchSessionStage(widget.sessionId, newStageId);
      if (mounted) {
        if (!isAutoGps) {
          AppSnackBar.showSuccess(context, 'Switched active stop: $newStageName');
        } else {
          AppSnackBar.showSuccess(context, 'GPS Auto-Matched: $newStageName');
        }
      }
    } catch (e) {
      debugPrint('[AttendanceKiosk] Network note on stage sync: $e');
    } finally {
      if (mounted) setState(() => _isSwitchingStage = false);
    }
  }

  // Barcode Detection Handler (Simulates Rapid Tap Scanner)
  Future<void> _onBarcodeDetect(BarcodeCapture capture) async {
    if (_isScanningLocked) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    // Sanitize barcode: strip ]c1, ]C1, AIM symbologies, invisible control chars
    final cleanCode = IdCardParser.sanitizeBarcode(rawValue);
    final effectiveCode = cleanCode.isNotEmpty ? cleanCode : rawValue.trim();

    // Prevent immediate repeated scanning of the exact same student QR within 2.5s
    if (_lastScannedCode == effectiveCode && _lastScannedTime != null) {
      if (DateTime.now().difference(_lastScannedTime!).inMilliseconds < 2500) {
        return;
      }
    }

    _lastScannedCode = effectiveCode;
    _lastScannedTime = DateTime.now();

    setState(() {
      _isScanningLocked = true;
      _scanMessage = 'Scanning: $effectiveCode...';
      _scanCardColor = AppTheme.primaryAccent;
    });

    final syncService = ref.read(syncServiceProvider);
    final gps = ref.read(gpsServiceProvider);

    final pos = await gps.getFastPosition();
    if (pos != null) _position = pos;
    final isOnline = await syncService.hasConnectivity();

    try {
      final session = widget.extra ?? {};
      final attendanceType = session['trip_type'] == 'evening' ? 'exit' : 'boarding';

      if (isOnline) {
        final result = await ref.read(attendanceMarkingStateProvider.notifier).markByQR(
              sessionId: widget.sessionId,
              qrCode: effectiveCode,
              method: 'qr',
              attendanceType: attendanceType,
              latitude: pos?.latitude,
              longitude: pos?.longitude,
            );

        final student = result?['student'] as Map<String, dynamic>?;
        final studentName = student?['name'] ?? 'Student';
        final rollNumber = student?['rollNumber'] ?? student?['roll_number'] ?? '';
        final isCorrectStage = result?['isCorrectStage'] == true;
        final stageNotice = result?['stageNotice'] ?? '';

        if (mounted) {
          if (isCorrectStage) {
            VoiceService.instance.speakVerified(studentName);
          } else {
            VoiceService.instance.speakWarning('$studentName, Check Stop');
          }
          setState(() {
            _flashScanCard();
            _lastScannedStudent = {
              'name': studentName,
              'roll_number': rollNumber,
              'assigned_stage': isCorrectStage ? _currentStageName : (stageNotice.isNotEmpty ? stageNotice : 'Other Stop'),
              'is_correct_stage': isCorrectStage,
              'time': DateTime.now().toIso8601String(),
              'type': 'regular',
            };
            _scanCardColor = isCorrectStage ? AppTheme.success : const Color(0xFFF59E0B);
            _scanMessage = isCorrectStage
                ? '$studentName ($rollNumber) Checked In'
                : '$studentName: $stageNotice';
          });
          ref.invalidate(sessionAttendanceProvider(widget.sessionId));
        }
      } else {
        // Offline Attendance
        final localDb = LocalDatabase.instance;
        final student = await localDb.findStudentByQR(effectiveCode);

        if (student == null) {
          VoiceService.instance.speakError('Not found offline');
          _showScanError('Student QR not found locally. Sync required.\nScanned: "$effectiveCode"');
          return;
        }

        final isDifferentBus = student['assigned_bus_id'] != session['bus_id'];
        final isDifferentStage = student['assigned_stage_id'] != null && student['assigned_stage_id'] != _currentStageId;

        final recordId = 'OFF-${DateTime.now().millisecondsSinceEpoch}-${student['id']}';
        await syncService.queueAttendance({
          'id': recordId,
          'session_id': widget.sessionId,
          'student_id': student['id'],
          'trip_id': session['trip_id'],
          'stage_id': _currentStageId,
          'bus_id': session['bus_id'],
          'route_id': session['route_id'],
          'attendance_type': attendanceType,
          'method': 'qr',
          'latitude': pos?.latitude,
          'longitude': pos?.longitude,
          'marked_at': DateTime.now().toIso8601String(),
          'status': 'present',
        });

        if (mounted) {
          if (isDifferentBus) {
            VoiceService.instance.speakWarning('${student['name']}, Different Bus');
          } else if (isDifferentStage) {
            VoiceService.instance.speakWarning('${student['name']}, Different Stop');
          } else {
            VoiceService.instance.speakVerified(student['name']?.toString() ?? 'Passenger');
          }
          setState(() {
            _flashScanCard();
            _lastScannedStudent = {
              'name': student['name'],
              'roll_number': student['roll_number'],
              'assigned_stage': isDifferentStage ? 'Boarded at $_currentStageName' : _currentStageName,
              'is_correct_stage': !isDifferentStage && !isDifferentBus,
              'time': DateTime.now().toIso8601String(),
              'type': 'regular',
            };
            _scanCardColor = (!isDifferentStage && !isDifferentBus) ? AppTheme.success : const Color(0xFFF59E0B);
            _scanMessage = (isDifferentBus)
                ? '${student['name']} - Different Bus Assigned'
                : (isDifferentStage)
                    ? '${student['name']} - Different Stop'
                    : '${student['name']} Checked In (Offline)';
          });
          ref.invalidate(sessionAttendanceProvider(widget.sessionId));
        }
      }
    } catch (e) {
      String errorMsg = 'Failed to mark attendance';
      if (e is DioException) {
        final code = e.response?.statusCode;
        final data = e.response?.data;
        final serverError = data is Map ? (data['error'] ?? data['message']) : null;
        // Check status codes first so 409/404 always get their voice cue,
        // even when the server also returns a message.
        if (code == 409) {
          errorMsg = '${serverError ?? 'Already marked present for this trip!'}\nScanned Code: "$effectiveCode"';
          VoiceService.instance.speakWarning('Already Scanned');
        } else if (code == 404) {
          errorMsg = '${serverError ?? 'Student not found in system'}\nScanned Code: "$effectiveCode"';
          VoiceService.instance.speakError('Student Not Found');
        } else if (serverError != null && serverError.toString().isNotEmpty) {
          errorMsg = '$serverError\nScanned Code: "$effectiveCode"';
          VoiceService.instance.speakError('Scan Failed');
        } else {
          errorMsg = '${e.message ?? "Network communication error"}\nScanned: "$effectiveCode"';
          VoiceService.instance.speakError('Network Error');
        }
      } else {
        final errStr = e.toString();
        final isDuplicate = errStr.contains('409') || errStr.contains('already');
        errorMsg = isDuplicate
            ? 'Already marked for this trip!\nScanned Code: "$effectiveCode"'
            : 'Record not found: "$effectiveCode"';
        if (isDuplicate) {
          VoiceService.instance.speakWarning('Already Scanned');
        } else {
          VoiceService.instance.speakError('Invalid Pass');
        }
      }
      _showScanError(errorMsg);
    } finally {
      // Auto-unlock scanner after 1.2s so user can read scanned code while keeping high throughput
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _isScanningLocked = false;
          });
        }
      });
    }
  }

  void _showScanError(String msg) {
    if (!mounted) return;
    _cardHideTimer?.cancel();
    _messageClearTimer?.cancel();
    setState(() {
      // Hide the previous student's VERIFIED card so an error isn't shown under someone else's name
      _cardVisible = false;
      _lastScannedStudent = null;
      _scanCardColor = AppTheme.danger;
      _scanMessage = msg;
    });
    _messageClearTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted && _scanMessage == msg) {
        setState(() => _scanMessage = null);
      }
    });
  }

  // --- Modal Sheets: Guest Entry & Quick Add ---
  void _openGuestEntrySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _GuestEntrySheet(
        sessionId: widget.sessionId,
        stageId: _currentStageId ?? '',
        stageName: _currentStageName ?? 'Active Stop',
        position: _position,
        onSuccess: (guestData) {
          ref.invalidate(sessionAttendanceProvider(widget.sessionId));
          if (mounted) {
            VoiceService.instance.speakVerified(guestData['name']?.toString() ?? 'Guest');
            setState(() {
              _flashScanCard();
              _lastScannedStudent = {
                'name': guestData['name'],
                'roll_number': guestData['roll_number'],
                'assigned_stage': 'Guest at $_currentStageName',
                'is_correct_stage': true,
                'time': DateTime.now().toIso8601String(),
                'type': 'guest',
              };
              _scanCardColor = const Color(0xFF8B5CF6); // Purple for guest
              _scanMessage = 'Guest Entry Verified: ${guestData['name']}';
            });
          }
        },
      ),
    );
  }

  void _openQuickAddStudentSheet(List<dynamic> stages) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _QuickAddStudentSheet(
        sessionId: widget.sessionId,
        stages: stages,
        currentStageId: _currentStageId,
        position: _position,
        onSuccess: (studentData) {
          ref.invalidate(sessionAttendanceProvider(widget.sessionId));
          if (mounted) {
            VoiceService.instance.speakVerified(studentData['name']?.toString() ?? 'Student');
            setState(() {
              _flashScanCard();
              _lastScannedStudent = {
                'name': studentData['name'],
                'roll_number': studentData['roll_number'],
                'assigned_stage': _currentStageName,
                'is_correct_stage': true,
                'time': DateTime.now().toIso8601String(),
                'type': 'regular',
              };
              _scanCardColor = AppTheme.success;
              _scanMessage = 'New Student Registered & Checked In!';
            });
          }
        },
      ),
    );
  }

  void _openBoardedListSheet(List<dynamic> records) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _BoardedRosterSheet(
        records: records,
        currentStageName: _currentStageName ?? 'Active Stop',
      ),
    );
  }

  void _showStagePickerSheet(List<dynamic> stages) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.alt_route_rounded, color: Color(0xFF1E40AF), size: 22),
                        SizedBox(width: 8),
                        Text('Switch Active Stop', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textPrimary)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // GPS Live Status & Auto-Detect Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isWithinGeofence ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isWithinGeofence ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isWithinGeofence ? Icons.gps_fixed_rounded : Icons.location_searching_rounded,
                        color: _isWithinGeofence ? const Color(0xFF059669) : const Color(0xFF3B82F6),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nearestStage != null
                                  ? 'GPS Nearest: ${_nearestStage!['stage_name']} (${_nearestDistanceMeters! < 1000 ? "${_nearestDistanceMeters!.round()}m" : "${(_nearestDistanceMeters! / 1000).toStringAsFixed(1)}km"})'
                                  : 'Acquiring high accuracy GPS coordinates...',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _isWithinGeofence ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              _autoGpsMatch ? 'Auto-switching stop when bus reaches station' : 'Manual stop selection mode',
                              style: TextStyle(fontSize: 10.5, color: _isWithinGeofence ? const Color(0xFF047857) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          await _manualMatchGPS();
                          setSheetState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E40AF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _isGpsLocating
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                              : const Text('Re-Match', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Auto-switch Toggle
                InkWell(
                  onTap: () {
                    setState(() => _autoGpsMatch = !_autoGpsMatch);
                    setSheetState(() {});
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Auto-switch stop with GPS geofence',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        Switch(
                          value: _autoGpsMatch,
                          activeColor: const Color(0xFF1E40AF),
                          onChanged: (val) {
                            setState(() => _autoGpsMatch = val);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: stages.length,
                    itemBuilder: (context, index) {
                      final st = stages[index];
                      final sId = st['id']?.toString() ?? '';
                      final sName = st['stage_name'] ?? 'Stop';
                      final seq = st['sequence_order'] ?? (index + 1);
                      final isSelected = sId == _currentStageId;

                      // Distance calculation for this stage
                      double? distToStage;
                      if (_position != null) {
                        final lat = double.tryParse(st['latitude']?.toString() ?? '');
                        final lon = double.tryParse(st['longitude']?.toString() ?? '');
                        if (lat != null && lon != null) {
                          distToStage = Geolocator.distanceBetween(_position!.latitude, _position!.longitude, lat, lon);
                        }
                      }
                      final isNearest = _nearestStage != null && _nearestStage!['id']?.toString() == sId;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: isSelected ? const Color(0xFF1E40AF) : const Color(0xFFF1F5F9),
                          child: Text(
                            '$seq',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                sName,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? const Color(0xFF1E40AF) : AppTheme.textPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            if (distToStage != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isNearest ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isNearest ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isNearest) ...[
                                      const Icon(Icons.near_me_rounded, size: 10, color: Color(0xFF166534)),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(
                                      isNearest
                                          ? (distToStage < 1000 ? "${distToStage.round()}m away" : "${(distToStage / 1000).toStringAsFixed(1)}km away")
                                          : (distToStage < 1000 ? '${distToStage.round()}m' : '${(distToStage / 1000).toStringAsFixed(1)}km'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isNearest ? FontWeight.w800 : FontWeight.w600,
                                        color: isNearest ? const Color(0xFF166534) : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1E40AF), size: 20)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _switchStage(sId, sName);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _endSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Stage Session?'),
        content: const Text('This will lock attendance records for this stop. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End & Lock'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await globalAction(() async {
      final api = ref.read(apiClientProvider);
      await api.endSession(widget.sessionId);
      if (mounted) {
        context.pop();
      }
    },
    message: 'Ending session & locking attendance...',
    successMessage: 'Stage session ended & attendance locked.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.extra ?? {};
    final stageName = _currentStageName ?? (session['stage_name'] as String? ?? 'Stage Stop');
    final sessionAttendanceAsync = ref.watch(sessionAttendanceProvider(widget.sessionId));
    final assignmentAsync = ref.watch(inchargeAssignmentProvider);
    final stages = (assignmentAsync.value?['stages'] as List?) ?? [];

    // Find next stage
    int currentIndex = stages.indexWhere((st) => st['id']?.toString() == _currentStageId);
    Map<String, dynamic>? nextStage = (currentIndex >= 0 && currentIndex < stages.length - 1)
        ? (stages[currentIndex + 1] as Map<String, dynamic>?)
        : null;

    final records = sessionAttendanceAsync.value ?? [];
    final presentCount = records.where((r) => r['status'] == 'present').length;
    final guestCount = records.where((r) => r['is_guest'] == 1 || r['is_guest'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sensors_rounded, color: Color(0xFF38BDF8), size: 15),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Door Scanner Kiosk',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              'Bus ${session['bus_number'] ?? '—'} • $stageName',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Flashlight Toggle
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _isTorchOn ? AppTheme.warning : Colors.white70),
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
            tooltip: 'Flashlight',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          // Camera Switch
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white70),
            onPressed: () => _scannerController.switchCamera(),
            tooltip: 'Switch Camera',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          // End session
          IconButton(
            onPressed: _endSession,
            icon: const Icon(Icons.lock_clock_rounded, color: Color(0xFFF87171)),
            tooltip: 'End Session',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: Stack(
        children: [
          // 1. Live Camera Viewfinder
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onBarcodeDetect,
              placeholderBuilder: (context) {
                return Container(
                  color: const Color(0xFF0F172A),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Starting Attendance Camera...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off_rounded, color: AppTheme.warning, size: 48),
                        const SizedBox(height: 12),
                        Text('Camera paused or inactive: ${error.errorCode.name}',
                            style: const TextStyle(color: Colors.white, fontSize: 13), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _restartScanner,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Restart Scanner'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E40AF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Custom Modern Viewfinder Overlay
          Positioned.fill(
            child: Container(
              decoration: ShapeDecoration(
                shape: QrScannerOverlayShape(
                  borderColor: _scanCardColor,
                  borderRadius: 20,
                  borderLength: 35,
                  borderWidth: 6,
                  cutOutSize: (MediaQuery.of(context).size.width * 0.75).clamp(220.0, 320.0),
                ),
              ),
            ),
          ),

          // 3. Top HUD: Active Stop Switcher & GPS
          Positioned(
            top: 12,
            left: 10,
            right: 10,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.94),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isWithinGeofence ? const Color(0xFF10B981).withOpacity(0.6) : Colors.white.withOpacity(0.18),
                      width: _isWithinGeofence ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isWithinGeofence ? const Color(0xFF10B981).withOpacity(0.25) : Colors.black.withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: stages.isNotEmpty ? () => _showStagePickerSheet(stages) : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _isWithinGeofence
                                        ? const Color(0xFF10B981).withOpacity(0.2)
                                        : const Color(0xFF38BDF8).withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isWithinGeofence ? Icons.gps_fixed_rounded : Icons.location_on_rounded,
                                    color: _isWithinGeofence ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _isWithinGeofence ? 'GPS MATCH' : 'ACTIVE STOP',
                                              style: TextStyle(
                                                color: _isWithinGeofence ? const Color(0xFF34D399) : Colors.white60,
                                                fontSize: 8.0,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (_nearestDistanceMeters != null) ...[
                                            const SizedBox(width: 3),
                                            Text(
                                              '• ${_nearestDistanceMeters! < 1000 ? "${_nearestDistanceMeters!.round()}m" : "${(_nearestDistanceMeters! / 1000).toStringAsFixed(1)}km"}',
                                              style: TextStyle(
                                                color: _isWithinGeofence ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                                fontSize: 8.0,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        stageName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Instant GPS Re-match icon button
                      IconButton(
                        onPressed: _isGpsLocating ? null : _manualMatchGPS,
                        icon: _isGpsLocating
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 1.8))
                            : const Icon(Icons.my_location_rounded, color: Color(0xFF38BDF8), size: 17),
                        tooltip: 'Match GPS Stop Now',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      if (nextStage != null) ...[
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: ElevatedButton(
                            onPressed: _isSwitchingStage
                                ? null
                                : () => _switchStage(nextStage['id'].toString(), nextStage['stage_name']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E40AF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isSwitchingStage)
                                  const SizedBox(width: 9, height: 9, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                                else
                                  const Icon(Icons.skip_next_rounded, size: 13),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '${nextStage['stage_name']}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Scanned Student NFC-Style Live Feedback Card (Appears on scan)
          if (_lastScannedStudent != null)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                opacity: _cardVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                onEnd: () {
                  if (!_cardVisible && mounted) {
                    setState(() => _lastScannedStudent = null);
                  }
                },
                child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.96),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _scanCardColor, width: 2),
                      boxShadow: [
                        BoxShadow(color: _scanCardColor.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _scanCardColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _lastScannedStudent!['type'] == 'guest'
                                ? Icons.card_membership_rounded
                                : Icons.verified_user_rounded,
                            color: _scanCardColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _lastScannedStudent!['name'] ?? 'Student',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _scanCardColor.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _lastScannedStudent!['type'] == 'guest' ? 'GUEST RIDER' : 'VERIFIED',
                                      style: TextStyle(color: _scanCardColor, fontSize: 9.5, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Roll: ${_lastScannedStudent!['roll_number']} • ${_lastScannedStudent!['assigned_stage']}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ),

          // 5. Bottom Control Bar: Quick Add, Guest Snap, Roster
          Positioned(
            left: 14,
            right: 14,
            bottom: 18,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status text pill
                    if (_scanMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _scanCardColor.withOpacity(0.6)),
                        ),
                        child: Text(
                          _scanMessage!,
                          style: TextStyle(color: _scanCardColor, fontSize: 11.5, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Main Action Bar (Glassmorphic)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.94),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        children: [
                          // 1. Guest Entry (Snap ID) Button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _openGuestEntrySheet,
                              icon: const Icon(Icons.camera_alt_rounded, size: 16),
                              label: const Text('Guest (Snap ID)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED), // Vibrant purple
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 2. Quick Add Student Button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openQuickAddStudentSheet(stages),
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                              label: const Text('Quick Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669), // Emerald green
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 3. Boarded Count & Roster Viewer
                          InkWell(
                            onTap: () => _openBoardedListSheet(records),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF475569)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people_alt_rounded, color: Color(0xFF38BDF8), size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$presentCount',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    guestCount > 0 ? '($guestCount G)' : 'Boarded',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Sheet 1: Guest Entry with Camera ID Snap
// -------------------------------------------------------------
class _GuestEntrySheet extends ConsumerStatefulWidget {
  final String sessionId;
  final String stageId;
  final String stageName;
  final Position? position;
  final Function(Map<String, dynamic>) onSuccess;

  const _GuestEntrySheet({
    required this.sessionId,
    required this.stageId,
    required this.stageName,
    required this.position,
    required this.onSuccess,
  });

  @override
  ConsumerState<_GuestEntrySheet> createState() => _GuestEntrySheetState();
}

class _GuestEntrySheetState extends ConsumerState<_GuestEntrySheet> {
  final _rollController = TextEditingController();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _idPhoto;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _rollController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _snapIdCardPhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 70,
        maxWidth: 900,
      );
      if (photo != null && mounted) {
        setState(() => _idPhoto = photo);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Camera error: $e');
      }
    }
  }

  Future<void> _submitGuest() async {
    final rollNo = _rollController.text.trim();
    final name = _nameController.text.trim();

    if (rollNo.isEmpty) {
      setState(() => _error = 'Please enter Guest Roll Number / Register ID');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      String? base64Photo;
      if (_idPhoto != null) {
        final bytes = await _idPhoto!.readAsBytes();
        base64Photo = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      final api = ref.read(apiClientProvider);
      final res = await api.recordGuestAttendance({
        'sessionId': widget.sessionId,
        'guestRollNumber': rollNo,
        'guestName': name.isNotEmpty ? name : 'Guest Rider ($rollNo)',
        'guestNotes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : 'Guest entry via Incharge door scan',
        'idPhoto': base64Photo,
        'latitude': widget.position?.latitude,
        'longitude': widget.position?.longitude,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess({
          'roll_number': rollNo,
          'name': name.isNotEmpty ? name : 'Guest Rider ($rollNo)',
          'id': res.data['data']?['id'],
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Failed to submit guest: ${e.toString().replaceAll('Exception:', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.card_membership_rounded, color: Color(0xFF7C3AED), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Guest / Emergency Rider Entry', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary)),
                      Text('Snap student ID card & record verified entry', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppTheme.dangerLight, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
            ],

            TextField(
              controller: _rollController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Guest Roll Number / ID *',
                hintText: 'e.g. 21CS204',
                prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF7C3AED)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Guest Student Name (Optional)',
                hintText: 'e.g. Anand Kumar',
                prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF7C3AED)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Reason / Notes',
                hintText: 'e.g. Missed regular bus / Exam',
                prefixIcon: Icon(Icons.notes_rounded, color: Color(0xFF7C3AED)),
              ),
            ),
            const SizedBox(height: 14),

            // Camera ID Snapshot Tile
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Physical ID Card Snapshot:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  if (_idPhoto != null)
                    Center(
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_idPhoto!.path),
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: InkWell(
                              onTap: () => setState(() => _idPhoto = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _snapIdCardPhoto,
                        icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF7C3AED)),
                        label: const Text('Take ID Card Photo', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFDDD6FE), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submitGuest,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_submitting ? 'Verifying...' : 'Confirm & Allow Boarding', style: const TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Sheet 2: Quick Add New Regular Student
// -------------------------------------------------------------
class _QuickAddStudentSheet extends ConsumerStatefulWidget {
  final String sessionId;
  final List<dynamic> stages;
  final String? currentStageId;
  final Position? position;
  final Function(Map<String, dynamic>) onSuccess;

  const _QuickAddStudentSheet({
    required this.sessionId,
    required this.stages,
    required this.currentStageId,
    required this.position,
    required this.onSuccess,
  });

  @override
  ConsumerState<_QuickAddStudentSheet> createState() => _QuickAddStudentSheetState();
}

class _QuickAddStudentSheetState extends ConsumerState<_QuickAddStudentSheet> {
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _deptController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedStageId;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedStageId = widget.currentStageId ?? (widget.stages.isNotEmpty ? widget.stages.first['id']?.toString() : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _deptController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitQuickAdd() async {
    final name = _nameController.text.trim();
    final roll = _rollController.text.trim();

    if (name.isEmpty || roll.isEmpty) {
      setState(() => _error = 'Student Name and Roll Number are required');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final phone = _phoneController.text.trim();
      final dept = _deptController.text.trim();
      final res = await api.quickAddAndMarkStudent({
        'sessionId': widget.sessionId,
        'name': name,
        'rollNumber': roll,
        'department': dept.isNotEmpty ? dept : 'General',
        'className': '1st Year',
        if (phone.isNotEmpty) 'phone': phone,
        if (phone.isNotEmpty) 'parentPhone': phone,
        if (_selectedStageId != null) 'stageId': _selectedStageId,
        if (_selectedStageId != null) 'assignedStageId': _selectedStageId,
        if (widget.position?.latitude != null) 'latitude': widget.position!.latitude,
        if (widget.position?.longitude != null) 'longitude': widget.position!.longitude,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess({
          'name': name,
          'roll_number': roll,
          'id': res.data['data']?['id'],
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to register student';
        if (e is DioException) {
          msg = e.response?.data?['error'] ?? e.response?.data?['message'] ?? (e.message ?? 'Server error');
        } else {
          msg = e.toString().replaceAll('Exception:', '');
        }
        setState(() {
          _submitting = false;
          _error = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF059669), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick Add Regular Student', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary)),
                      Text('Registers to this bus & marks present immediately', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppTheme.dangerLight, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
            ],

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                hintText: 'e.g. Priya S',
                prefixIcon: Icon(Icons.person_outline, color: Color(0xFF059669)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _rollController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Roll Number *',
                hintText: 'e.g. 22IT105',
                prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF059669)),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _deptController,
                    decoration: const InputDecoration(
                      labelText: 'Dept / Class',
                      hintText: 'e.g. IT-A',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Parent Phone',
                      hintText: 'e.g. 9876543210',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (widget.stages.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedStageId,
                decoration: const InputDecoration(
                  labelText: 'Assigned Boarding Stop',
                  prefixIcon: Icon(Icons.pin_drop_outlined, color: Color(0xFF059669)),
                ),
                items: widget.stages.map((st) {
                  return DropdownMenuItem<String>(
                    value: st['id']?.toString(),
                    child: Text(st['stage_name'] ?? 'Stop', style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedStageId = v),
              ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submitQuickAdd,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_submitting ? 'Registering...' : 'Register & Check In', style: const TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Sheet 3: Boarded Roster Viewer with Guest Photo Previews
// -------------------------------------------------------------
class _BoardedRosterSheet extends StatelessWidget {
  final List<dynamic> records;
  final String currentStageName;

  const _BoardedRosterSheet({required this.records, required this.currentStageName});

  void _showPhotoDialog(BuildContext context, String title, String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.badge_rounded, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Failed to load ID photo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = records.where((r) => r['status'] == 'present').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.people_alt_rounded, color: Color(0xFF1E40AF), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Boarded Roster ($presentCount)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary)),
                    Text('Stop: $currentStageName', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No students boarded yet at this session', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: records.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = records[i];
                  final isGuest = r['is_guest'] == 1 || r['is_guest'] == true;
                  final hasPhoto = r['guest_id_photo_url'] != null && (r['guest_id_photo_url'] as String).isNotEmpty;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: CircleAvatar(
                      backgroundColor: isGuest ? const Color(0xFFF3E8FF) : const Color(0xFFEFF6FF),
                      child: Icon(
                        isGuest ? Icons.card_membership_rounded : Icons.person,
                        color: isGuest ? const Color(0xFF7C3AED) : const Color(0xFF1E40AF),
                        size: 18,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r['name'] ?? r['guest_name'] ?? 'Student',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isGuest)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(6)),
                            child: const Text('GUEST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED))),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${r['roll_number'] ?? r['guest_roll_number'] ?? ''} • ${PdfReportService.formatTo12Hour(r['marked_at'])}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    trailing: hasPhoto
                        ? IconButton(
                            icon: const Icon(Icons.image_outlined, color: Color(0xFF7C3AED), size: 20),
                            tooltip: 'View ID Photo',
                            onPressed: () => _showPhotoDialog(
                              context,
                              '${r['name'] ?? 'Guest'} ID Photo',
                              r['guest_id_photo_url'],
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
