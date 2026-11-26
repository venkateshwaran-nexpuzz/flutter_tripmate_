import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'nominatim_service.dart';

export 'nominatim_service.dart';

part 'gps_service.g.dart';

@riverpod
GpsService gpsService(GpsServiceRef ref) {
  final service = GpsService();
  service.startLocationStream();
  ref.onDispose(service.dispose);
  return service;
}

class GpsService {
  Position? _cachedPosition;
  DateTime? _lastGpsTime;
  StreamSubscription<Position>? _positionSubscription;

  Position? get cachedPosition => _cachedPosition;

  /// Start background stream to keep latest coordinates warm in memory
  void startLocationStream() {
    try {
      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10,
        ),
      ).listen(
        (pos) {
          _cachedPosition = pos;
          _lastGpsTime = DateTime.now();
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void dispose() {
    _positionSubscription?.cancel();
  }

  /// Request location permissions and check service availability
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Prompt the user compulsory to turn ON device location service (GPS switch) and permissions
  Future<bool> ensureGpsEnabled(BuildContext context) async {
    // 1. Check if GPS hardware/service switch is ON
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return false;
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'GPS Location Required',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          content: const Text(
            'Bus tracking and student boarding verification require your device GPS to be turned ON.\n\nPlease turn ON Location in your phone settings to continue.',
            style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx, true);
                await Geolocator.openLocationSettings();
              },
              icon: const Icon(Icons.location_on_rounded, size: 18),
              label: const Text('Turn ON GPS', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );

      if (shouldOpenSettings != true) return false;

      // Recheck after opening settings
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    // 2. Check Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Location Permission Needed', style: TextStyle(fontWeight: FontWeight.w800)),
          content: const Text(
            'TripMate needs location permission to record boarding stops. Please grant location permission in App Settings.',
            style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openAppSettings();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return false;
    }

    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  /// Get position instantly (< 10ms) from memory cache or OS last-known position
  Future<Position?> getFastPosition({Duration maxAge = const Duration(minutes: 5)}) async {
    // 1. Return memory-cached position if fresh
    if (_cachedPosition != null && _lastGpsTime != null) {
      if (DateTime.now().difference(_lastGpsTime!) < maxAge) {
        return _cachedPosition;
      }
    }

    // 2. Fetch OS-level last known position (instant, no GPS satellite wait)
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _cachedPosition = lastKnown;
        _lastGpsTime = DateTime.now();
        return lastKnown;
      }
    } catch (_) {}

    // 3. Fallback: Quick query with 1.5s max time limit
    return getCurrentPosition(timeLimit: const Duration(milliseconds: 1500));
  }

  /// Get current position with quick timeout fallback
  Future<Position?> getCurrentPosition({Duration timeLimit = const Duration(seconds: 2)}) async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return _cachedPosition;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: timeLimit,
      );
      _cachedPosition = pos;
      _lastGpsTime = DateTime.now();
      return pos;
    } catch (e) {
      // Fallback to last known position on timeout
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _cachedPosition = lastKnown;
          _lastGpsTime = DateTime.now();
          return lastKnown;
        }
      } catch (_) {}
      return _cachedPosition;
    }
  }

  /// Stream of position updates (for live GPS tracking)
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10 meters
        timeLimit: Duration(seconds: 30),
      ),
    );
  }

  /// Get High-Accuracy Native Device GPS + OpenStreetMap Nominatim Reverse Geocoded Location
  Future<GpsLocationDetails?> getAccurateLocationDetails({
    double accuracyThreshold = 20.0,
    Duration timeout = const Duration(seconds: 4),
    bool resolveAddress = true,
  }) async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      // 1. Fetch live native hardware GPS with best accuracy
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: timeout,
        );
      } catch (_) {
        pos = await getFastPosition();
      }

      if (pos == null) return null;

      _cachedPosition = pos;
      _lastGpsTime = DateTime.now();

      // 2. If reverse geocoding is requested, query OpenStreetMap Nominatim
      if (resolveAddress) {
        return await NominatimGeocodingService().reverseGeocode(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          timestamp: pos.timestamp,
          accuracyThreshold: accuracyThreshold,
        );
      }

      // 3. Raw GPS details
      return GpsLocationDetails.raw(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        timestamp: pos.timestamp,
        accuracyThreshold: accuracyThreshold,
      );
    } catch (_) {
      return null;
    }
  }

  /// Calculate distance in meters between two coordinates
  double distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Validate coordinates are within geofence
  GeofenceResult validateGeofence({
    required double userLat,
    required double userLon,
    required double stageLat,
    required double stageLon,
    required int allowedRadiusMeters,
  }) {
    final distance = distanceBetween(userLat, userLon, stageLat, stageLon);
    return GeofenceResult(
      isValid: distance <= allowedRadiusMeters,
      distanceMeters: distance.round(),
      allowedRadiusMeters: allowedRadiusMeters,
    );
  }
}

class GeofenceResult {
  final bool isValid;
  final int distanceMeters;
  final int allowedRadiusMeters;

  const GeofenceResult({
    required this.isValid,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
  });

  String get message => isValid
      ? 'Within range ($distanceMeters m from stage)'
      : 'Too far from stage ($distanceMeters m, max $allowedRadiusMeters m)';
}
