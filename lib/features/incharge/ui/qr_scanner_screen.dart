import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/api/api_client.dart';
import '../../../core/db/local_database.dart';
import '../../../core/gps/gps_service.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../admin/ui/id_card_parser.dart';
import '../providers/incharge_provider.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final Map<String, dynamic>? extra;

  const QRScannerScreen({super.key, required this.sessionId, this.extra});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> with WidgetsBindingObserver {
  late final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    returnImage: false,
    detectionSpeed: DetectionSpeed.unrestricted,
    detectionTimeoutMs: 250,
    formats: const [BarcodeFormat.all],
  );
  bool _processed = false;
  bool _isSwitchingCamera = false;
  String? _statusMessage;
  Color _statusColor = Colors.white;

  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  late String _currentStageId;
  late String _currentStageName;
  bool _isSwitchingStage = false;

  // GPS auto match & Nominatim location state
  StreamSubscription<Position>? _gpsSub;
  Timer? _stationaryGpsTimer;
  Position? _position;
  GpsLocationDetails? _locationDetails;
  bool _isResolvingAddress = false;
  Map<String, dynamic>? _nearestStage;
  double? _nearestDistanceMeters;
  bool _isWithinGeofence = false;
  bool _isGpsLocating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentStageId = widget.extra?['stage_id']?.toString() ?? '';
    _currentStageName = widget.extra?['stage_name']?.toString() ?? 'Active Stop';
    _checkCameraPermission();
    _startGPS();
  }

  Future<void> _resolveReverseGeocode(Position pos) async {
    if (_isResolvingAddress) return;
    _isResolvingAddress = true;
    try {
      final details = await NominatimGeocodingService().reverseGeocode(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        timestamp: pos.timestamp,
      );
      if (mounted) {
        setState(() => _locationDetails = details);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  Future<void> _startGPS() async {
    try {
      final hasPerm = await ref.read(gpsServiceProvider).ensureGpsEnabled(context);
      if (!hasPerm) return;

      final fastPos = await ref.read(gpsServiceProvider).getFastPosition();
      if (fastPos != null && mounted) {
        setState(() => _position = fastPos);
        _matchStage(fastPos);
        _resolveReverseGeocode(fastPos);
      }

      _gpsSub?.cancel();
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
        _matchStage(pos);
        if (_locationDetails == null ||
            Geolocator.distanceBetween(_locationDetails!.latitude, _locationDetails!.longitude, pos.latitude, pos.longitude) > 25) {
          _resolveReverseGeocode(pos);
        }
      });

      // Periodic check every 5s so when bus is stationary at stop, GPS matching doesn't stall
      _stationaryGpsTimer?.cancel();
      _stationaryGpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!mounted) return;
        try {
          final fastPos = await ref.read(gpsServiceProvider).getFastPosition(maxAge: const Duration(seconds: 4));
          if (fastPos != null && mounted) {
            setState(() => _position = fastPos);
            _matchStage(fastPos);
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _matchStage(Position pos, {bool forceSwitch = false, bool showToast = false}) {
    final assignment = ref.read(inchargeAssignmentProvider).value;
    final stages = (assignment?['stages'] as List?) ?? [];
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
      final configuredRadius = (closest['allowed_radius_meters'] as num?)?.toDouble() ?? 250.0;
      // Generous auto-switch buffer (minimum 450m) so stop approach & ±30m mobile GPS deviations don't delay auto-switch
      final autoSwitchRadius = configuredRadius < 450.0 ? 450.0 : configuredRadius;
      final within = minDistance <= autoSwitchRadius;

      if (mounted) {
        setState(() {
          _nearestStage = closest;
          _nearestDistanceMeters = minDistance;
          _isWithinGeofence = minDistance <= configuredRadius;
        });
      }

      final cId = closest['id']?.toString() ?? '';
      final cName = closest['stage_name']?.toString() ?? 'Stop';

      if ((within || forceSwitch) && cId != _currentStageId && !_isSwitchingStage) {
        _switchStage(cId, cName);
      }

      if (showToast && mounted) {
        final dStr = minDistance < 1000 ? '${minDistance.round()}m' : '${(minDistance / 1000).toStringAsFixed(1)}km';
        AppSnackBar.showSuccess(context, 'GPS Matched: $cName ($dStr away)');
      }
    }
  }

  Future<void> _manualMatchGPS() async {
    setState(() => _isGpsLocating = true);
    try {
      final pos = await ref.read(gpsServiceProvider).getCurrentPosition(timeLimit: const Duration(seconds: 4));
      if (pos != null) {
        setState(() => _position = pos);
        _matchStage(pos, forceSwitch: true, showToast: true);
        _resolveReverseGeocode(pos);
      }
    } catch (_) {}
    if (mounted) setState(() => _isGpsLocating = false);
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
        _startGPS();
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
          _processed = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _safeSwitchCamera() async {
    if (_isSwitchingCamera) return;
    setState(() => _isSwitchingCamera = true);
    try {
      // Turn off torch before switching to front camera to prevent hardware crashes
        try {
          await _controller.toggleTorch();
        } catch (_) {}
      await _controller.switchCamera();
    } catch (e) {
      debugPrint('[InchargeScanner] Switch camera error: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'Could not switch camera: Device has only one camera or camera is busy.');
      }
    } finally {
      if (mounted) setState(() => _isSwitchingCamera = false);
    }
  }

  Future<void> _safeToggleTorch() async {
    try {
      if (_controller.value.cameraDirection == CameraFacing.front) {
        if (mounted) {
          AppSnackBar.showInfo(context, 'Flashlight is not available on front camera.');
        }
        return;
      }
      await _controller.toggleTorch();
    } catch (e) {
      debugPrint('[InchargeScanner] Toggle torch error: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'Flashlight is not supported or unavailable.');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stationaryGpsTimer?.cancel();
    _gpsSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _switchStage(String newStageId, String newStageName) async {
    if (_currentStageId == newStageId || _isSwitchingStage) return;
    // Optimistic instantaneous UI update so the screen immediately reflects active stop
    setState(() {
      _isSwitchingStage = true;
      _currentStageId = newStageId;
      _currentStageName = newStageName;
      _statusMessage = 'Active Stop: $newStageName';
      _statusColor = const Color(0xFF38BDF8);
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.switchSessionStage(widget.sessionId, newStageId);
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Switched active stop to $newStageName');
      }
    } catch (e) {
      debugPrint('[InchargeScanner] Network note on stage sync: $e');
    } finally {
      if (mounted) setState(() => _isSwitchingStage = false);
    }
  }

  void _showStagePickerSheet(List<Map<String, dynamic>> stages) {
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.alt_route_rounded, color: Color(0xFF1E40AF), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Select Active Stop Stage',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // GPS Live Status Banner
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
                        child: Text(
                          _nearestStage != null
                              ? 'GPS Nearest: ${_nearestStage!['stage_name']} (${_nearestDistanceMeters! < 1000 ? "${_nearestDistanceMeters!.round()}m" : "${(_nearestDistanceMeters! / 1000).toStringAsFixed(1)}km"})'
                              : 'Acquiring GPS location...',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _isWithinGeofence ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                          ),
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
                const SizedBox(height: 10),
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

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processed) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    // Sanitize barcode: strip ]c1, ]C1, AIM symbologies, invisible control chars
    final cleanCode = IdCardParser.sanitizeBarcode(rawValue);
    final effectiveCode = cleanCode.isNotEmpty ? cleanCode : rawValue.trim();

    // Prevent immediate repeated scanning of the exact same student QR within 1.8s
    if (_lastScannedCode == effectiveCode && _lastScannedTime != null) {
      if (DateTime.now().difference(_lastScannedTime!).inMilliseconds < 1800) {
        return;
      }
    }

    _lastScannedCode = effectiveCode;
    _lastScannedTime = DateTime.now();

    if (!mounted) return;
    setState(() {
      _processed = true;
      _statusMessage = 'Verifying: $effectiveCode...';
      _statusColor = AppTheme.primary;
    });

    final syncService = ref.read(syncServiceProvider);
    final gps = ref.read(gpsServiceProvider);

    // Fast position check from stream memory first (0ms latency)
    Position? pos = _position;
    if (pos == null) {
      // Check if GPS is enabled only if no location acquired yet
      final isGpsOn = await Geolocator.isLocationServiceEnabled();
      if (!isGpsOn) {
        if (mounted) {
          setState(() {
            _processed = false;
            _statusMessage = '⚠️ GPS is turned OFF! Turn on location to scan.';
            _statusColor = Colors.orange;
          });
          await gps.ensureGpsEnabled(context);
        }
        return;
      }
      pos = await gps.getFastPosition();
    }

    final isOnline = await syncService.hasConnectivity();

    final currentLat = pos?.latitude ?? _locationDetails?.latitude;
    final currentLon = pos?.longitude ?? _locationDetails?.longitude;
    final currentAccuracy = pos?.accuracy ?? _locationDetails?.accuracy;
    final currentLocName = _locationDetails?.displayName;

    try {
      final session = widget.extra ?? {};
      final attendanceType = session['trip_type'] == 'evening' ? 'exit' : 'boarding';

      if (isOnline) {
        // Online Attendance Flow
        final result = await ref.read(attendanceMarkingStateProvider.notifier).markByQR(
              sessionId: widget.sessionId,
              qrCode: effectiveCode,
              method: 'qr',
              attendanceType: attendanceType,
              latitude: currentLat,
              longitude: currentLon,
              accuracy: currentAccuracy,
              locationName: currentLocName,
            );

        final studentName = result?['student']?['name'] ?? 'Passenger';
        final rollNumber = result?['student']?['rollNumber'] ?? '';
        final category = result?['student']?['category'] ?? 'Student';
        final isStaff = category.toString().toLowerCase() == 'staff' || category.toString().toLowerCase() == 'faculty';
        final roleLabel = isStaff ? '[Staff] ' : '';
        final isCorrectStage = result?['isCorrectStage'] == true;
        final stageNotice = result?['stageNotice'] ?? '';
        final autoStage = result?['autoDetectedStage'];
        final serverStageName = result?['currentStageName']?.toString();

        if (autoStage != null && autoStage['name'] != null) {
          final newName = autoStage['name'].toString();
          final newId = autoStage['id']?.toString();
          if (mounted) {
            setState(() {
              _currentStageName = newName;
              if (newId != null) _currentStageId = newId;
            });
          }
        } else if (serverStageName != null && serverStageName.isNotEmpty && serverStageName != _currentStageName) {
          if (mounted) {
            setState(() {
              _currentStageName = serverStageName;
            });
          }
        }

        if (isCorrectStage) {
          VoiceService.instance.speakVerified(studentName);
          _showSuccess('$roleLabel$studentName ($rollNumber)\nStop: $_currentStageName');
        } else {
          VoiceService.instance.speakWarning('$studentName, Check Stop');
          _showWarning('$roleLabel$studentName ($rollNumber)\n$stageNotice');
        }
      } else {
        // Offline Attendance Flow
        final localDb = LocalDatabase.instance;
        final student = await localDb.findStudentByQR(effectiveCode);

        if (student == null) {
          VoiceService.instance.speakError('Not found offline');
          _showError('Student not found offline\nScanned Code: "$effectiveCode"', delayMs: 3000);
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
          'latitude': currentLat,
          'longitude': currentLon,
          'accuracy': currentAccuracy,
          'boarded_location': currentLocName,
          'marked_at': DateTime.now().toIso8601String(),
          'status': 'present',
        });

        if (isDifferentBus) {
          VoiceService.instance.speakWarning('${student['name']}, Different Bus');
          _showWarning('${student['name']} - Notice: Assigned to different bus\nScanned: "$rawValue"');
        } else if (isDifferentStage) {
          VoiceService.instance.speakWarning('${student['name']}, Different Stop');
          _showWarning('${student['name']} - Boarded at $_currentStageName (Different Stop)\nScanned: "$rawValue"');
        } else {
          VoiceService.instance.speakVerified(student['name'] ?? 'Passenger');
          _showSuccess('${student['name']} (Present - $_currentStageName)');
        }
      }
    } catch (e) {
      String errorMsg = 'Failed to mark attendance';
      if (e is DioException) {
        final serverError = e.response?.data?['error'] ?? e.response?.data?['message'];
        if (serverError != null && serverError.toString().isNotEmpty) {
          errorMsg = '$serverError\nScanned Code: "$effectiveCode"';
        } else if (e.response?.statusCode == 409) {
          errorMsg = 'Already marked for this trip!\nScanned Code: "$effectiveCode"';
          VoiceService.instance.speakWarning('Already Scanned');
        } else if (e.response?.statusCode == 404) {
          errorMsg = 'Student not found in system\nScanned Code: "$effectiveCode"';
          VoiceService.instance.speakError('Student Not Found');
        } else {
          errorMsg = '${e.message ?? "Network error"}\nScanned: "$effectiveCode"';
        }
      } else {
        final errStr = e.toString();
        if (errStr.contains('409') || errStr.contains('Duplicate')) {
          errorMsg = 'Duplicate attendance detected!\nScanned Code: "$effectiveCode"';
          VoiceService.instance.speakWarning('Already Scanned');
        } else {
          errorMsg = 'Record not found: "$effectiveCode"';
          VoiceService.instance.speakError('Invalid Pass');
        }
      }
      _showError(errorMsg, delayMs: 2500);
    }
  }

  void _showSuccess(String msg, {int delayMs = 900}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = msg;
      _statusColor = AppTheme.success;
    });
    _resumeScanningAfterDelay(delayMs);
  }

  void _showError(String msg, {int delayMs = 2500}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = msg;
      _statusColor = AppTheme.danger;
    });
    _resumeScanningAfterDelay(delayMs);
  }

  void _showWarning(String msg, {int delayMs = 2000}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = msg;
      _statusColor = const Color(0xFFF59E0B);
    });
    _resumeScanningAfterDelay(delayMs);
  }

  void _resumeScanningAfterDelay([int delayMs = 1500]) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        setState(() {
          _processed = false;
          _statusMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final isLandscape = context.isLandscape;
    final dynamicCutout = (min(screenW, screenH) * 0.65).clamp(180.0, 280.0);

    final assignmentAsync = ref.watch(inchargeAssignmentProvider);
    final stages = List<Map<String, dynamic>>.from(assignmentAsync.value?['stages'] ?? []);

    // Find next stage index
    final currentIdx = stages.indexWhere((s) => s['id']?.toString() == _currentStageId);
    final hasNextStage = currentIdx >= 0 && currentIdx + 1 < stages.length;
    final nextStage = hasNextStage ? stages[currentIdx + 1] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Student QR'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
  return Icon(
    state.torchState == TorchState.on
        ? Icons.flash_on_rounded
        : Icons.flash_off_rounded,
    color: state.torchState == TorchState.on
        ? AppTheme.warning
        : null,
  );
},
            ),
            onPressed: _safeToggleTorch,
            tooltip: 'Toggle Flashlight',
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
             builder: (context, state, child) {
  return Icon(
    state.cameraDirection == CameraFacing.front
        ? Icons.camera_front_rounded
        : Icons.camera_rear_rounded,
  );
},
            ),
            onPressed: _safeSwitchCamera,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
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
                        'Starting Camera Scanner...',
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
              return _buildScannerError(context, error);
            },
          ),

          // Scanner overlay layout
          Positioned.fill(
            child: Container(
              decoration: ShapeDecoration(
                shape: QrScannerOverlayShape(
                  borderColor: _statusColor,
                  borderRadius: 16,
                  borderLength: 30,
                  borderWidth: 5,
                  cutOutSize: dynamicCutout,
                ),
              ),
            ),
          ),

          // Processing HUD Loader Overlay in Center Viewfinder
          if (_processed)
            Center(
              child: Container(
                width: dynamicCutout * 0.88,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Recording Attendance...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _lastScannedCode ?? 'Verifying credential',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top Interactive Stop Stage Switcher Bar
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isWithinGeofence ? const Color(0xFF10B981).withOpacity(0.6) : Colors.white.withOpacity(0.2),
                      width: _isWithinGeofence ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isWithinGeofence ? const Color(0xFF10B981).withOpacity(0.25) : Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // Active Stop Indicator (Tap to pick)
                          Expanded(
                            child: InkWell(
                              onTap: stages.isNotEmpty ? () => _showStagePickerSheet(stages) : null,
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _isWithinGeofence ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF38BDF8).withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isWithinGeofence ? Icons.gps_fixed_rounded : Icons.pin_drop_rounded,
                                        color: _isWithinGeofence ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                                        size: 16,
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
                                              Text(
                                                _isWithinGeofence ? 'ACTIVE STOP (GPS MATCH)' : 'ACTIVE STOP (TAP TO CHANGE)',
                                                style: TextStyle(
                                                  color: _isWithinGeofence ? const Color(0xFF34D399) : Colors.white54,
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (_nearestDistanceMeters != null) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  '• ${_nearestDistanceMeters! < 1000 ? "${_nearestDistanceMeters!.round()}m" : "${(_nearestDistanceMeters! / 1000).toStringAsFixed(1)}km"}',
                                                  style: TextStyle(
                                                    color: _isWithinGeofence ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            _currentStageName,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Instant GPS Re-match icon button
                          IconButton(
                            onPressed: _isGpsLocating ? null : _manualMatchGPS,
                            icon: _isGpsLocating
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 1.8))
                                : const Icon(Icons.my_location_rounded, color: Color(0xFF38BDF8), size: 18),
                            tooltip: 'Match GPS Stop Now',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),

                          // Next Stop Quick Button
                          if (hasNextStage && nextStage != null) ...[
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

                      // Row 2: Live Reverse Geocoded Location & Accuracy (OpenStreetMap Nominatim)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _locationDetails != null
                                    ? '${_locationDetails!.displayName} (${_locationDetails!.latitude.toStringAsFixed(4)}, ${_locationDetails!.longitude.toStringAsFixed(4)})'
                                    : (_position != null
                                        ? 'GPS: ${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}'
                                        : 'Locating via GPS...'),
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_position != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (_position!.accuracy <= 20)
                                      ? const Color(0xFF10B981).withOpacity(0.3)
                                      : const Color(0xFFF59E0B).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '±${_position!.accuracy.round()}m',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: (_position!.accuracy <= 20)
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFFFCD34D),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Status bar at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: isLandscape ? 16 : 36,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _statusColor.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_statusMessage != null)
                        Icon(
                          _statusColor == AppTheme.success
                              ? Icons.check_circle_rounded
                              : _statusColor == AppTheme.danger
                              ? Icons.error_outline_rounded
                              : Icons.info_outline_rounded,
                          color: _statusColor,
                          size: 20,
                        ),
                      if (_statusMessage != null) const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _statusMessage ?? 'Align student QR code inside the frame',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _statusColor == Colors.white ? AppTheme.textPrimary : _statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                  ? 'Camera permission is needed to scan student QR codes. Please grant permission in App Settings.'
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

// Custom QR Scanner overlay shapes
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderLength;
  final double borderRadius;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 4,
    this.borderLength = 20,
    this.borderRadius = 0,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path();
    path.addRect(rect);
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final cutOut = cutOutSize;
    final top = (height - cutOut) / 2;
    final left = (width - cutOut) / 2;

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, top, cutOut, cutOut), Radius.circular(borderRadius))),
      ),
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();
    // Top-left
    path.moveTo(left, top + borderLength);
    path.lineTo(left, top + borderRadius);
    path.quadraticBezierTo(left, top, left + borderRadius, top);
    path.lineTo(left + borderLength, top);

    // Top-right
    path.moveTo(left + cutOut - borderLength, top);
    path.lineTo(left + cutOut - borderRadius, top);
    path.quadraticBezierTo(left + cutOut, top, left + cutOut, top + borderRadius);
    path.lineTo(left + cutOut, top + borderLength);

    // Bottom-left
    path.moveTo(left, top + cutOut - borderLength);
    path.lineTo(left, top + cutOut - borderRadius);
    path.quadraticBezierTo(left, top + cutOut, left + borderRadius, top + cutOut);
    path.lineTo(left + borderLength, top + cutOut);

    // Bottom-right
    path.moveTo(left + cutOut - borderLength, top + cutOut);
    path.lineTo(left + cutOut - borderRadius, top + cutOut);
    path.quadraticBezierTo(left + cutOut, top + cutOut, left + cutOut, top + cutOut - borderRadius);
    path.lineTo(left + cutOut, top + cutOut - borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
