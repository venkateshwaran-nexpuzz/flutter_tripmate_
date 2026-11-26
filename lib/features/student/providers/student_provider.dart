import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api/api_client.dart';

part 'student_provider.g.dart';

// ============================================================
// Student Profile
// ============================================================
@riverpod
Future<Map<String, dynamic>> studentProfile(StudentProfileRef ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getStudentProfile();
  return response.data['data'] as Map<String, dynamic>;
}

// ============================================================
// Student Today's Attendance
// ============================================================
@riverpod
Future<List<Map<String, dynamic>>> studentTodayAttendance(StudentTodayAttendanceRef ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getTodayAttendance();
  return List<Map<String, dynamic>>.from(response.data['data']);
}

// ============================================================
// Student Attendance Stats
// ============================================================
@riverpod
Future<Map<String, dynamic>> studentAttendanceStats(StudentAttendanceStatsRef ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getAttendanceStats();
  return response.data['data'] as Map<String, dynamic>;
}

// ============================================================
// Student Attendance History (Filterable)
// ============================================================
@riverpod
class StudentHistoryState extends _$StudentHistoryState {
  // ignore: unused_field
  String? _startDate;
  // ignore: unused_field
  String? _endDate;
  // ignore: unused_field
  String? _status;
  // ignore: unused_field
  String? _attendanceType;

  @override
  FutureOr<List<Map<String, dynamic>>> build({
    String? startDate,
    String? endDate,
    String? status,
    String? attendanceType,
  }) async {
    final api = ref.read(apiClientProvider);
    final params = <String, dynamic>{
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (status != null) 'status': status,
      if (attendanceType != null) 'attendanceType': attendanceType,
    };
    final response = await api.getAttendanceHistory(params);
    final rawData = response.data['data'];
    if (rawData is Map && rawData['data'] is List) {
      return List<Map<String, dynamic>>.from(rawData['data']);
    } else if (rawData is List) {
      return List<Map<String, dynamic>>.from(rawData);
    }
    return [];
  }
}

// ============================================================
// Student Notifications
// ============================================================
@riverpod
Future<List<Map<String, dynamic>>> studentNotifications(StudentNotificationsRef ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getNotifications();
  return List<Map<String, dynamic>>.from(response.data['data']);
}
