import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

List<Map<String, dynamic>> _extractList(dynamic rawData) {
  if (rawData == null) return [];
  if (rawData is List) {
    return List<Map<String, dynamic>>.from(rawData);
  }
  if (rawData is Map) {
    for (final key in ['data', 'items', 'students', 'buses', 'routes', 'incharges', 'institutions', 'assignments', 'trips', 'users', 'logs', 'rows']) {
      if (rawData[key] is List) {
        return List<Map<String, dynamic>>.from(rawData[key]);
      }
    }
  }
  return [];
}

Map<String, dynamic> _extractMap(dynamic rawData) {
  if (rawData == null) return {};
  if (rawData is Map<String, dynamic>) return rawData;
  if (rawData is Map) return Map<String, dynamic>.from(rawData);
  return {};
}

// ============================================================
// Admin Dashboard Overview Stats
// ============================================================
final adminDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminDashboard();
    return _extractMap(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] Dashboard error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Live Bus Fleet Status & Realtime GPS
// ============================================================
final adminLiveBusesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminLiveBuses();
    return _extractList(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] LiveBuses error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Admin Students Roster Directory (with Institution & Search)
// ============================================================
final adminStudentsFilterProvider = StateProvider<String>((ref) => '');
final adminInstitutionFilterProvider = StateProvider<String>((ref) => 'All');
final adminYearFilterProvider = StateProvider<String>((ref) => 'All');

final adminStudentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminStudents();
    return _extractList(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] Students error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Admin Buses Fleet
// ============================================================
final adminBusesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminBuses();
    return _extractList(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] Buses error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Admin Routes & Stages
// ============================================================
final adminRoutesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminRoutes();
    return _extractList(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] Routes error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Admin Incharges & Crew Leads
// ============================================================
final adminInchargesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminIncharges();
    return _extractList(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] Incharges error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Admin Institutions & Colleges Directory
// ============================================================
final adminInstitutionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminInstitutions();
    return _extractList(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] Institutions error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Admin Bus Route & Crew Assignments
// ============================================================
final adminBusAssignmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminBusAssignments();
    return _extractList(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] BusAssignments error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Admin Daily Trips
// ============================================================
final adminTripsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminTrips();
    return _extractList(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] Trips error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Admin Reports & Analytics / Geofence Audit
// ============================================================
final adminAuditReportsFiltersProvider = StateProvider<Map<String, dynamic>>((ref) {
  final today = DateTime.now().toIso8601String().split('T').first;
  return {
    'startDate': today,
    'endDate': today,
    'busId': '',
    'institutionType': 'All',
    'crossBusOnly': false,
    'mismatchOnly': false,
    'geoDeviationOnly': false,
    'beforeStopOnly': false,
    'afterStopOnly': false,
    'page': 1,
    'limit': 50,
  };
});

final adminAuditReportsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final filters = ref.watch(adminAuditReportsFiltersProvider);
    final response = await api.getAdminReports(query: filters);
    return _extractMap(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] Audit Reports error: $e\n$st');
    rethrow;
  }
});

final adminReportsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminReports();
    return _extractMap(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] Reports error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Admin Threshold Settings
// ============================================================
final adminThresholdsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminThresholds();
    return _extractMap(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] Thresholds error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Admin Audit Logs
// ============================================================
final adminAuditLogsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminAuditLogs();
    return _extractList(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] AuditLogs error: $e\n$st');
    rethrow;
  }
});

// ============================================================
// Admin User Management
// ============================================================
final adminUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.getAdminUsers();
    return _extractList(response.data?['data']);
  } catch (e, st) {
    debugPrint('[AdminProvider] Users error: $e\n$st');
    rethrow;
  }
});

