import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Structured GPS & Reverse Geocoded Location Model
class GpsLocationDetails {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final String? road;
  final String? area;
  final String? city;
  final String? district;
  final String? state;
  final String? pincode;
  final String displayName;
  final bool isReverseGeocoded;
  final bool isWithinAccuracyThreshold;

  const GpsLocationDetails({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.road,
    this.area,
    this.city,
    this.district,
    this.state,
    this.pincode,
    required this.displayName,
    this.isReverseGeocoded = false,
    this.isWithinAccuracyThreshold = true,
  });

  /// Factory for raw fallback when reverse geocoding is unavailable
  factory GpsLocationDetails.raw({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
    double accuracyThreshold = 20.0,
  }) {
    final latStr = latitude.toStringAsFixed(4);
    final lonStr = longitude.toStringAsFixed(4);
    return GpsLocationDetails(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      timestamp: timestamp,
      displayName: 'GPS ($latStr, $lonStr)',
      isReverseGeocoded: false,
      isWithinAccuracyThreshold: accuracy <= accuracyThreshold,
    );
  }

  /// Convert to JSON map for logging and API payload
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_meters': accuracy,
    'timestamp': timestamp.toIso8601String(),
    'road': road,
    'area': area,
    'city': city,
    'district': district,
    'state': state,
    'pincode': pincode,
    'display_name': displayName,
    'is_geocoded': isReverseGeocoded,
  };

  @override
  String toString() => displayName;
}

/// OpenStreetMap Nominatim Reverse Geocoding Service
class NominatimGeocodingService {
  static final NominatimGeocodingService _instance = NominatimGeocodingService._internal();
  factory NominatimGeocodingService() => _instance;
  NominatimGeocodingService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 2500),
      receiveTimeout: const Duration(milliseconds: 2500),
      headers: {
        'User-Agent': 'TripMate-Bus-Attendance/1.0 (contact: admin@vet.edu)',
        'Accept-Language': 'en',
      },
    ),
  );

  // In-memory cache: (lat_4dec, lon_4dec) -> GpsLocationDetails
  final Map<String, GpsLocationDetails> _cache = {};

  /// Reverse geocode GPS coordinate to structured human-readable location
  Future<GpsLocationDetails> reverseGeocode({
    required double latitude,
    required double longitude,
    required double accuracy,
    DateTime? timestamp,
    double accuracyThreshold = 20.0,
  }) async {
    final time = timestamp ?? DateTime.now();
    final cacheKey = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';

    // 1. Check in-memory cache
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      return GpsLocationDetails(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        timestamp: time,
        road: cached.road,
        area: cached.area,
        city: cached.city,
        district: cached.district,
        state: cached.state,
        pincode: cached.pincode,
        displayName: cached.displayName,
        isReverseGeocoded: true,
        isWithinAccuracyThreshold: accuracy <= accuracyThreshold,
      );
    }

    // 2. Query OpenStreetMap Nominatim
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse';
      final response = await _dio.get(
        url,
        queryParameters: {
          'format': 'jsonv2',
          'lat': latitude,
          'lon': longitude,
          'zoom': 18,
          'addressdetails': 1,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final address = (data['address'] as Map<String, dynamic>?) ?? {};

        // Parse structured fields
        var road = (address['road'] ?? address['street'] ?? address['highway'])?.toString();
        // Clean long highway strings if concatenated
        if (road != null && road.contains('-') && (road.length > 30 || road.split('-').length >= 3)) {
          final segs = road.split('-').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          road = segs.isNotEmpty ? segs.last : road;
        }

        final area = (address['suburb'] ?? address['neighbourhood'] ?? address['residential'])?.toString();
        final city = (address['village'] ?? address['town'] ?? address['city'] ?? address['hamlet'])?.toString();
        final district = (address['county'] ?? address['state_district'])?.toString();
        final state = (address['state'])?.toString();
        final pincode = (address['postcode'])?.toString();

        // Build clean display name: e.g. "Thindal, Erode, Tamil Nadu" or "Erode Road, Kuhalur, Gobichettipalayam"
        final parts = <String>[];
        if (road != null && road.isNotEmpty) parts.add(road);
        if (area != null && area.isNotEmpty && !parts.contains(area)) parts.add(area);
        if (city != null && city.isNotEmpty && !parts.contains(city)) parts.add(city);
        if (district != null && district.isNotEmpty && !parts.contains(district) && parts.length < 3) parts.add(district);
        if (parts.isEmpty && state != null && state.isNotEmpty) parts.add(state);

        final displayName = parts.isNotEmpty
            ? parts.take(3).join(', ')
            : (data['display_name']?.toString().split(',').take(3).join(', ') ?? 'GPS (${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)})');

        final details = GpsLocationDetails(
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          timestamp: time,
          road: road,
          area: area,
          city: city,
          district: district,
          state: state,
          pincode: pincode,
          displayName: displayName,
          isReverseGeocoded: true,
          isWithinAccuracyThreshold: accuracy <= accuracyThreshold,
        );

        _cache[cacheKey] = details;
        return details;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Nominatim Reverse Geocoding Error: $e');
      }
    }

    // 3. Fallback: Return raw coordinates if offline or request fails (never blocks attendance)
    return GpsLocationDetails.raw(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      timestamp: time,
      accuracyThreshold: accuracyThreshold,
    );
  }
}
