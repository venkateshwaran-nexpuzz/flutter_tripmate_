import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/db/local_database.dart';

part 'incharge_provider.g.dart';

// ============================================================
// Incharge Assignment
// ============================================================
@riverpod
Future<Map<String, dynamic>> inchargeAssignment(InchargeAssignmentRef ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getAssignment();
  return response.data['data'] as Map<String, dynamic>;
}

// ============================================================
// Session Attendance (live list for current session)
// ============================================================
@riverpod
Future<List<Map<String, dynamic>>> sessionAttendance(
  SessionAttendanceRef ref,
  String sessionId,
) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getSessionAttendance(sessionId);
  return List<Map<String, dynamic>>.from(response.data['data']);
}

// ============================================================
// Route Students List (Roster for incharge)
// ============================================================
final routeStudentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getRouteStudents();
  final list = List<Map<String, dynamic>>.from(response.data['data']);
  try {
    await LocalDatabase.instance.cacheStudents(list);
  } catch (_) {}
  return list;
});

// ============================================================
// Current Trip State Notifier
// ============================================================
@riverpod
class ActiveTripState extends _$ActiveTripState {
  @override
  Map<String, dynamic>? build() => null;

  void setTrip(Map<String, dynamic> trip) => state = trip;
  void clearTrip() => state = null;
}

// ============================================================
// Active Session State Notifier
// ============================================================
@riverpod
class ActiveSessionState extends _$ActiveSessionState {
  @override
  Map<String, dynamic>? build() => null;

  void setSession(Map<String, dynamic> session) => state = session;
  void clearSession() => state = null;
}

// ============================================================
// Mark Attendance Use Case Notifier
// ============================================================
@riverpod
class AttendanceMarkingState extends _$AttendanceMarkingState {
  @override
  AsyncValue<Map<String, dynamic>?> build() => const AsyncData(null);

  Future<Map<String, dynamic>?> markByQR({
    required String sessionId,
    required String qrCode,
    required String method,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? locationName,
    String attendanceType = 'boarding',
  }) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.markAttendance({
        'sessionId': sessionId,
        'studentIdentifier': qrCode,
        'identifierType': 'qr',
        'method': method,
        'attendanceType': attendanceType,
        'deviceTime': DateTime.now().toUtc().toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (locationName != null && locationName.isNotEmpty) 'boardedLocation': locationName,
      });
      final result = response.data['data'] as Map<String, dynamic>;
      state = AsyncData(result);
      ref.invalidate(sessionAttendanceProvider(sessionId));
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> markByPhotoVerification({
    required String sessionId,
    required String rollNumber,
    required double? latitude,
    required double? longitude,
    String? notes,
    String attendanceType = 'boarding',
  }) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.photoVerifyAttendance({
        'sessionId': sessionId,
        'rollNumber': rollNumber,
        'attendanceType': attendanceType,
        'deviceTime': DateTime.now().toUtc().toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (notes != null) 'notes': notes,
      });
      final result = response.data['data'] as Map<String, dynamic>;
      state = AsyncData(result);
      ref.invalidate(sessionAttendanceProvider(sessionId));
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> markByRollNumber({
    required String sessionId,
    required String rollNumber,
    double? latitude,
    double? longitude,
    String attendanceType = 'boarding',
  }) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.markAttendance({
        'sessionId': sessionId,
        'studentIdentifier': rollNumber,
        'identifierType': 'roll_number',
        'method': 'roll_number',
        'attendanceType': attendanceType,
        'deviceTime': DateTime.now().toUtc().toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
      final result = response.data['data'] as Map<String, dynamic>;
      state = AsyncData(result);
      ref.invalidate(sessionAttendanceProvider(sessionId));
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  void reset() => state = const AsyncData(null);
}

// ============================================================
// Incharge Trips & Attendance History Provider
// ============================================================
final inchargeTripsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getInchargeTrips();
  return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
});

