import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../../driver/providers/driver_language_provider.dart';

class StudentBusTrackingScreen extends ConsumerStatefulWidget {
  const StudentBusTrackingScreen({super.key});

  @override
  ConsumerState<StudentBusTrackingScreen> createState() =>
      _StudentBusTrackingScreenState();
}

class _StudentBusTrackingScreenState
    extends ConsumerState<StudentBusTrackingScreen> {
  final MapController _mapController = MapController();
  Timer? _pollingTimer;
  Timer? _secondsTicker;
  StreamSubscription<Position>? _positionStreamSub;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _trackingData;

  Position? _studentPosition;
  int _secondsSinceUpdate = 0;
  static const int _pollIntervalSeconds = 35;

  @override
  void initState() {
    super.initState();
    _fetchStudentPhoneLocation();
    _fetchLiveBusLocation();

    // Poll every 35 seconds to respect hardware GPS cache interval
    _pollingTimer = Timer.periodic(
      const Duration(seconds: _pollIntervalSeconds),
      (_) => _fetchLiveBusLocation(),
    );

    // 1-second ticker to show "Updated X seconds ago"
    _secondsTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _secondsSinceUpdate++;
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _secondsTicker?.cancel();
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchStudentPhoneLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _studentPosition = pos;
        });
      }

      // Continuously stream student's live phone GPS coordinates so distance updates dynamically!
      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3, // Update every 3 meters
        ),
      ).listen((Position livePos) {
        if (mounted) {
          setState(() {
            _studentPosition = livePos;
          });
        }
      });
    } catch (_) {
      // Non-blocking fallback if location permission is denied
    }
  }

  Future<void> _fetchLiveBusLocation() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.getStudentBusLiveLocation();
      final data = response.data['data'] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _trackingData = data;
          _isLoading = false;
          _errorMessage = null;
          _secondsSinceUpdate = 0;
        });

        _autoFitMap();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to fetch live bus location. Please try again.';
        });
      }
    }
  }

  void _autoFitMap() {
    if (_trackingData == null) return;
    final gps = _trackingData!['gps'] as Map<String, dynamic>?;
    final stage = _trackingData!['stage'] as Map<String, dynamic>?;

    final points = <LatLng>[];

    if (gps != null && gps['latitude'] != null && gps['longitude'] != null) {
      points.add(LatLng(
        (gps['latitude'] as num).toDouble(),
        (gps['longitude'] as num).toDouble(),
      ));
    }

    if (stage != null && stage['latitude'] != null && stage['longitude'] != null) {
      points.add(LatLng(
        (stage['latitude'] as num).toDouble(),
        (stage['longitude'] as num).toDouble(),
      ));
    }

    if (_studentPosition != null) {
      points.add(LatLng(_studentPosition!.latitude, _studentPosition!.longitude));
    }

    if (points.isNotEmpty) {
      try {
        if (points.length == 1) {
          _mapController.move(points.first, 15);
        } else {
          final bounds = LatLngBounds.fromPoints(points);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(50),
            ),
          );
        }
      } catch (_) {}
    }
  }

  // Calculate straight-line distance in km
  double? _calculateDistanceKm(LatLng p1, LatLng p2) {
    final distanceMeters = Geolocator.distanceBetween(
      p1.latitude,
      p1.longitude,
      p2.latitude,
      p2.longitude,
    );
    return distanceMeters / 1000.0;
  }

  // Approximate ETA in minutes
  int? _calculateEtaMinutes(double distanceKm, double speedKmh) {
    if (distanceKm <= 0.1) return 1;
    // Base speed: in city traffic, average is 25-30 km/h even if current speed is high
    double effectiveSpeed = speedKmh > 10 ? speedKmh : 25.0;
    if (effectiveSpeed > 50) effectiveSpeed = 45.0; // clamp for realistic city traffic
    final hours = distanceKm / effectiveSpeed;
    final minutes = (hours * 60).round();
    return minutes < 1 ? 1 : minutes;
  }

  @override
  Widget build(BuildContext context) {
    final hasBus = _trackingData?['hasAssignedBus'] == true;
    final bus = _trackingData?['bus'] as Map<String, dynamic>?;
    final stage = _trackingData?['stage'] as Map<String, dynamic>?;
    final gps = _trackingData?['gps'] as Map<String, dynamic>?;

    LatLng? busLocation;
    double busSpeed = 0.0;
    double busHeading = 0.0;
    String ignitionStatus = 'UNKNOWN';
    String busAddress = '';

    if (gps != null && gps['latitude'] != null && gps['longitude'] != null) {
      busLocation = LatLng(
        (gps['latitude'] as num).toDouble(),
        (gps['longitude'] as num).toDouble(),
      );
      busSpeed = (gps['speed'] as num?)?.toDouble() ?? 0.0;
      busHeading = (gps['heading'] as num?)?.toDouble() ?? 0.0;
      ignitionStatus = (gps['ignitionStatus'] as String?) ?? 'UNKNOWN';
      busAddress = (gps['address'] as String?) ?? '';
    }

    LatLng? stageLocation;
    if (stage != null && stage['latitude'] != null && stage['longitude'] != null) {
      stageLocation = LatLng(
        (stage['latitude'] as num).toDouble(),
        (stage['longitude'] as num).toDouble(),
      );
    }

    LatLng? studentLocation;
    if (_studentPosition != null) {
      studentLocation = LatLng(_studentPosition!.latitude, _studentPosition!.longitude);
    }

    // Dynamic distance calculation prioritizes the student's actual live mobile GPS coordinates.
    // Falls back to static designated stage only if phone GPS permission is not granted.
    final bool isUsingPhoneGps = studentLocation != null;
    final LatLng? targetLocation = studentLocation ?? stageLocation;
    double? distanceKm;
    int? etaMinutes;

    final isSpeedZero = busSpeed < 2.0;
    final isIgnitionOff = ignitionStatus.toUpperCase() == 'OFF';
    final isIgnitionOn = ignitionStatus.toUpperCase() == 'ON';
    final isParked = gps != null && (
      gps['isParked'] == true ||
      gps['vehicleStatus'] == 'PARKED' ||
      (isSpeedZero && isIgnitionOff)
    );
    final isMoving = busSpeed >= 3.0;
    final isIdle = !isParked && !isMoving && isIgnitionOn;
    final isLive = gps != null && (gps['isLive'] == true || (gps['secondsAgo'] != null && (gps['secondsAgo'] as num) < 900));

    if (busLocation != null && targetLocation != null) {
      distanceKm = _calculateDistanceKm(busLocation, targetLocation);
      if (distanceKm != null && !isParked && isMoving) {
        etaMinutes = _calculateEtaMinutes(distanceKm, busSpeed);
      }
    }

    // Extract designated route stages for realistic route path (avoiding direct flight line)
    final rawStages = _trackingData?['routeStages'] as List<dynamic>? ?? [];
    final List<LatLng> routePathPoints = rawStages
        .where((s) => s['latitude'] != null && s['longitude'] != null)
        .map((s) => LatLng((s['latitude'] as num).toDouble(), (s['longitude'] as num).toDouble()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  bus != null ? 'Bus ${bus['busNumber']}' : ref.tr('bus_tracking'),
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isParked
                        ? const Color(0xFFFEF3C7)
                        : isMoving
                            ? const Color(0xFFDCFCE7)
                            : isIdle
                                ? const Color(0xFFFEF9C3)
                                : isLive
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isParked
                          ? const Color(0xFFFDE68A)
                          : isMoving
                              ? const Color(0xFFBBF7D0)
                              : isIdle
                                  ? const Color(0xFFFEF08A)
                                  : isLive
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isParked
                              ? const Color(0xFFD97706)
                              : isMoving
                                  ? const Color(0xFF16A34A)
                                  : isIdle
                                      ? const Color(0xFFCA8A04)
                                      : isLive
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF64748B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isParked
                            ? ref.tr('status_parked')
                            : isMoving
                                ? ref.tr('live_moving')
                                : isIdle
                                    ? ref.tr('status_halted')
                                    : (isLive ? 'LAST KNOWN' : 'OFFLINE'),
                        style: TextStyle(
                          color: isParked
                              ? const Color(0xFFD97706)
                              : isMoving
                                  ? const Color(0xFF16A34A)
                                  : isIdle
                                      ? const Color(0xFFCA8A04)
                                      : isLive
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF64748B),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Builder(
              builder: (context) {
                if (isParked) {
                  return Text(
                    '${ref.tr('status_parked')} • ${ref.tr('engine_off')}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }
                if (isMoving) {
                  return Text(
                    'Hardware GPS • ${ref.tr('live_moving')} (${busSpeed.round()} km/h)',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }
                if (isIdle) {
                  return Text(
                    '${ref.tr('status_halted')} • ${ref.tr('engine_on')}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFCA8A04), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }
                final loggedAt = gps?['loggedAt']?.toString();
                if (loggedAt != null && loggedAt.isNotEmpty) {
                  final dt = DateTime.tryParse(loggedAt)?.toLocal();
                  final dateStr = dt != null ? '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : loggedAt;
                  return Text(
                    '${ref.tr('engine_off')} • Last seen $dateStr',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }
                return Text(
                  'Hardware GPS Telemetry',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.my_location_rounded, color: Color(0xFF1E40AF)),
            tooltip: 'Fit to Viewport',
            onPressed: _autoFitMap,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E40AF)),
            tooltip: 'Refresh GPS Now',
            onPressed: () {
              AppSnackBar.showInfo(context, 'Fetching latest bus GPS telemetry...');
              _fetchLiveBusLocation();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1E40AF)),
                  SizedBox(height: 16),
                  Text(
                    'Locating your bus via GPS...',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : _errorMessage != null && _trackingData == null
              ? _buildErrorView()
              : !hasBus
                  ? _buildNoBusView()
                  : Stack(
                  children: [
                    // 1. OpenStreetMap (Leaflet via flutter_map)
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: busLocation ?? stageLocation ?? const LatLng(11.0168, 76.9558),
                        initialZoom: 14.5,
                        minZoom: 5,
                        maxZoom: 18,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.tripmate.app',
                        ),

                        // Route Polyline along configured stops (Avoid straight flight cut line)
                        if (routePathPoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routePathPoints,
                                strokeWidth: 3.5,
                                color: const Color(0xFF6366F1).withOpacity(0.55),
                                strokeCap: StrokeCap.round,
                                strokeJoin: StrokeJoin.round,
                              ),
                            ],
                          ),

                        // Markers Layer
                        MarkerLayer(
                          markers: [
                            // Bus Marker
                            if (busLocation != null)
                              Marker(
                                point: busLocation,
                                width: isParked ? 120 : 56,
                                height: 56,
                                child: _buildBusMarker(
                                  busNumber: bus?['busNumber']?.toString() ?? '',
                                  heading: busHeading,
                                  isMoving: isMoving,
                                  isParked: isParked,
                                ),
                              ),

                            // Student Stage Marker
                            if (stageLocation != null)
                              Marker(
                                point: stageLocation,
                                width: 50,
                                height: 50,
                                child: _buildStageMarker(
                                  stageName: stage?['name']?.toString() ?? 'Stop',
                                ),
                              ),

                            // Student Current Phone Location Marker
                            if (studentLocation != null)
                              Marker(
                                point: studentLocation,
                                width: 44,
                                height: 44,
                                child: _buildStudentMarker(),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // Top Status Bar: GPS Freshness & Telemetry Cycle
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF1E40AF)),
                                const SizedBox(width: 6),
                                Text(
                                  _secondsSinceUpdate == 0
                                      ? ref.tr('just_updated')
                                      : '${ref.tr('updated_ago')} ${_secondsSinceUpdate}s',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${ref.tr('next_in')} ${(_pollIntervalSeconds - (_secondsSinceUpdate % _pollIntervalSeconds)).clamp(1, _pollIntervalSeconds)}s',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Floating ETA & Bus Telemetry Card
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBottomEtaCard(
                        bus: bus,
                        stage: stage,
                        busLocation: busLocation,
                        busSpeed: busSpeed,
                        ignitionStatus: ignitionStatus,
                        busAddress: busAddress,
                        distanceKm: distanceKm,
                        etaMinutes: etaMinutes,
                        isParked: isParked,
                        isMoving: isMoving,
                        isIdle: isIdle,
                        isUsingPhoneGps: isUsingPhoneGps,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildBusMarker({
    required String busNumber,
    required double heading,
    required bool isMoving,
    required bool isParked,
  }) {
    if (isParked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'P',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'A$busNumber PARKED'.replaceFirst('AA', 'A'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF59E0B), width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.local_parking_rounded, color: Color(0xFFFBBF24), size: 19),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            'Bus $busNumber',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Transform.rotate(
          angle: (heading * 3.141592653589793 / 180),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isMoving ? const Color(0xFF2563EB) : const Color(0xFFD97706),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: (isMoving ? const Color(0xFF2563EB) : const Color(0xFFD97706)).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStageMarker({required String stageName}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE11D48),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            stageName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(Icons.location_on_rounded, color: Color(0xFFE11D48), size: 28),
      ],
    );
  }

  Widget _buildStudentMarker() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withOpacity(0.25),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF059669),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 14),
        ),
      ),
    );
  }

  Widget _buildBottomEtaCard({
    required Map<String, dynamic>? bus,
    required Map<String, dynamic>? stage,
    required LatLng? busLocation,
    required double busSpeed,
    required String ignitionStatus,
    required String busAddress,
    required double? distanceKm,
    required int? etaMinutes,
    required bool isParked,
    required bool isMoving,
    required bool isIdle,
    required bool isUsingPhoneGps,
  }) {
    final inchargePhone = bus?['inchargePhone']?.toString();
    final inchargeName = bus?['inchargeName']?.toString();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Primary Status & Movement Row
          Row(
            children: [
              // Large Badge: Either PARKED or ESTIMATED ARRIVAL
              if (isParked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF334155)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF475569)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'P',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ref.tr('status_parked').toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ref.tr('engine_off'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ref.tr('bus_parked_depot'),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isMoving
                          ? const [Color(0xFF1E40AF), Color(0xFF2563EB)]
                          : const [Color(0xFFB45309), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isMoving ? const Color(0xFF2563EB) : const Color(0xFFD97706)).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isMoving ? ref.tr('est_arrival') : ref.tr('bus_tracking'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isMoving
                            ? (etaMinutes != null ? '~ $etaMinutes MINS' : '—')
                            : ref.tr('status_halted'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (isIdle)
                        Text(
                          ref.tr('engine_on'),
                          style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
              const SizedBox(width: 14),

              // Distance & Movement Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          distanceKm != null ? '${distanceKm.toStringAsFixed(1)} km ${ref.tr('away')}' : 'Location synced',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (isUsingPhoneGps) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.my_location_rounded, size: 10, color: Color(0xFF059669)),
                                SizedBox(width: 2),
                                Text(
                                  'Live GPS',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isParked
                                ? const Color(0xFFD97706)
                                : isMoving
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFCA8A04),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isParked
                                ? ref.tr('trip_not_started')
                                : isMoving
                                    ? '${ref.tr('live_moving')} • ${busSpeed.toStringAsFixed(0)} km/h'
                                    : ref.tr('status_halted'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isParked
                                  ? const Color(0xFFD97706)
                                  : isMoving
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFCA8A04),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${ref.tr('to_stop')}: ${stage?['name'] ?? ref.tr('assigned_stop')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (busAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1.5),
                    child: Icon(Icons.pin_drop_rounded, size: 16, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      busAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),

          // Incharge contact & Call button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inchargeName ?? ref.tr('incharge_assigned'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      inchargePhone != null ? 'Phone: $inchargePhone' : ref.tr('incharge_assigned'),
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (inchargePhone != null && inchargePhone.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inchargePhone));
                    AppSnackBar.showSuccess(context, 'Incharge Phone ($inchargePhone) copied to clipboard');
                  },
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: Text(ref.tr('contact_incharge'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to fetch bus GPS telemetry',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.danger, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchLiveBusLocation();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBusView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF1E40AF), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Bus Assigned Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your profile currently does not have an assigned transport bus. Please contact college bus administration.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
