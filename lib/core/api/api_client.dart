import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/token_storage.dart';

part 'api_client.g.dart';

String get _baseUrl {
  // Production URL:
  return 'https://vettransport.vetias.ac.in/api';
  // Ngrok URL for local debugging / testing:
  // return 'https://palpitate-rundown-fled.ngrok-free.dev/api';
}

@riverpod
ApiClient apiClient(ApiClientRef ref) {
  return ApiClient(ref.watch(tokenStorageProvider));
}

class ApiClient {
  final TokenStorage _tokenStorage;
  late final Dio _dio;

  ApiClient(this._tokenStorage) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'Bypass-Tunnel-Reminder': 'true',
      },
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(_tokenStorage, _dio),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[API] $obj'),
      ),
    ]);
  }

  Dio get dio => _dio;

  // ============================================================
  // Auth
  // ============================================================
  Future<Response> login(String email, String password) =>
      _dio.post('/auth/login', data: {'email': email, 'password': password});

  Future<Response> refreshToken(String refreshToken) =>
      _dio.post('/auth/refresh', data: {'refreshToken': refreshToken});

  Future<Response> logout(String refreshToken) =>
      _dio.post('/auth/logout', data: {'refreshToken': refreshToken});

  Future<Response> getMe() => _dio.get('/auth/me');

  Future<Response> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  // ============================================================
  // Incharge
  // ============================================================
  Future<Response> getAssignment() => _dio.get('/incharge/assignment');

  Future<Response> startTrip(Map<String, dynamic> data) =>
      _dio.post('/incharge/trips/start', data: data);

  Future<Response> endTrip(String tripId) =>
      _dio.patch('/incharge/trips/$tripId/end');

  Future<Response> startSession(Map<String, dynamic> data) =>
      _dio.post('/incharge/sessions/start', data: data);

  Future<Response> switchSessionStage(String sessionId, String stageId) =>
      _dio.patch('/incharge/sessions/$sessionId/stage', data: {'stageId': stageId});

  Future<Response> endSession(String sessionId) =>
      _dio.patch('/incharge/sessions/$sessionId/end');

  Future<Response> getSessionAttendance(String sessionId) =>
      _dio.get('/incharge/sessions/$sessionId/attendance');

  Future<Response> markAttendance(Map<String, dynamic> data) =>
      _dio.post('/incharge/attendance/mark', data: data);

  Future<Response> photoVerifyAttendance(Map<String, dynamic> data) =>
      _dio.post('/incharge/attendance/photo-verify', data: data);

  Future<Response> recordGuestAttendance(Map<String, dynamic> data) =>
      _dio.post('/incharge/attendance/guest', data: data);

  Future<Response> quickAddAndMarkStudent(Map<String, dynamic> data) =>
      _dio.post('/incharge/attendance/quick-add', data: data);

  Future<Response> selfMarkAttendance(Map<String, dynamic> data) =>
      _dio.post('/incharge/attendance/self-mark', data: data);

  Future<Response> markAbsent(Map<String, dynamic> data) =>
      _dio.post('/incharge/attendance/absent', data: data);

  Future<Response> logGPS(Map<String, dynamic> data) =>
      _dio.post('/incharge/gps', data: data);

  Future<Response> searchStudents(String query, {String? busId}) =>
      _dio.get('/incharge/students/search', queryParameters: {'q': query, if (busId != null) 'busId': busId});

  Future<Response> getRouteStudents() =>
      _dio.get('/incharge/students');

  Future<Response> addStudentToRoute(Map<String, dynamic> data) =>
      _dio.post('/incharge/students', data: data);

  Future<Response> updateStudentOnRoute(String id, Map<String, dynamic> data) =>
      _dio.put('/incharge/students/$id', data: data);

  Future<Response> deleteStudentFromRoute(String id) =>
      _dio.delete('/incharge/students/$id');

  Future<Response> getInchargeTrips() =>
      _dio.get('/incharge/trips');

  Future<Response> getTripAttendance(String tripId) =>
      _dio.get('/incharge/trips/$tripId/attendance');

  Future<Response> syncOfflineAttendance(Map<String, dynamic> data) =>
      _dio.post('/sync/offline-attendance', data: data);

  // ============================================================
  // Student
  // ============================================================
  Future<Response> getStudentProfile() => _dio.get('/student/profile');

  Future<Response> updateStudentProfile(Map<String, dynamic> data) =>
      _dio.patch('/student/profile', data: data);

  Future<Response> getStudentBusLiveLocation() =>
      _dio.get('/student/bus-live-location');

  Future<Response> getTodayAttendance() => _dio.get('/student/attendance/today');

  Future<Response> getAttendanceHistory(Map<String, dynamic> params) =>
      _dio.get('/student/attendance/history', queryParameters: params);

  Future<Response> getAttendanceStats() => _dio.get('/student/attendance/stats');

  Future<Response> getNotifications() => _dio.get('/student/notifications');

  Future<Response> markNotificationRead(String id) =>
      _dio.patch('/student/notifications/$id/read');

  Future<Response> studentSelfMarkAttendance(Map<String, dynamic> data) =>
      _dio.post('/student/attendance/self-mark', data: data);

  // ============================================================
  // Admin
  // ============================================================
  Future<Response> getAdminDashboard() => _dio.get('/admin/dashboard');

  Future<Response> getAdminLiveBuses() => _dio.get('/admin/buses/live');

  Future<Response> getAdminStudents({Map<String, dynamic>? query}) =>
      _dio.get('/admin/students', queryParameters: query);

  Future<Response> createAdminStudent(Map<String, dynamic> data) =>
      _dio.post('/admin/students', data: data);

  Future<Response> updateAdminStudent(String id, Map<String, dynamic> data) =>
      _dio.patch('/admin/students/$id', data: data);

  Future<Response> deleteAdminStudent(String id) =>
      _dio.delete('/admin/students/$id');

  Future<Response> bulkUploadAdminStudents(List<Map<String, dynamic>> students) =>
      _dio.post('/admin/students/bulk', data: {'students': students});

  Future<Response> bulkUpdateRollNumbersByName(List<Map<String, dynamic>> updates) =>
      _dio.post('/admin/students/bulk-update-rollno-by-name', data: {'updates': updates});

  Future<Response> getAdminBuses() => _dio.get('/admin/buses');

  Future<Response> createAdminBus(Map<String, dynamic> data) =>
      _dio.post('/admin/buses', data: data);

  Future<Response> updateAdminBus(String id, Map<String, dynamic> data) =>
      _dio.patch('/admin/buses/$id', data: data);

  Future<Response> deleteAdminBus(String id) =>
      _dio.delete('/admin/buses/$id');

  Future<Response> getAdminRoutes() => _dio.get('/admin/routes');

  Future<Response> createAdminRoute(Map<String, dynamic> data) =>
      _dio.post('/admin/routes', data: data);

  Future<Response> updateAdminRoute(String id, Map<String, dynamic> data) =>
      _dio.patch('/admin/routes/$id', data: data);

  Future<Response> deleteAdminRoute(String id) =>
      _dio.delete('/admin/routes/$id');

  Future<Response> getAdminStages({String? routeId}) =>
      _dio.get('/admin/stages', queryParameters: routeId != null ? {'routeId': routeId} : null);

  Future<Response> createAdminStage(Map<String, dynamic> data) =>
      _dio.post('/admin/stages', data: data);

  Future<Response> updateAdminStage(String id, Map<String, dynamic> data) =>
      _dio.patch('/admin/stages/$id', data: data);

  Future<Response> deleteAdminStage(String id) =>
      _dio.delete('/admin/stages/$id');

  Future<Response> getAdminIncharges() => _dio.get('/admin/incharges');

  Future<Response> createAdminIncharge(Map<String, dynamic> data) =>
      _dio.post('/admin/incharges', data: data);

  Future<Response> updateAdminIncharge(String id, Map<String, dynamic> data) =>
      _dio.patch('/admin/incharges/$id', data: data);

  Future<Response> deleteAdminIncharge(String id) =>
      _dio.delete('/admin/incharges/$id');

  Future<Response> bulkUploadAdminIncharges(List<Map<String, dynamic>> incharges) =>
      _dio.post('/admin/incharges/bulk', data: {'incharges': incharges});

  Future<Response> getAdminInstitutions() => _dio.get('/admin/institutions');

  Future<Response> createAdminInstitution(Map<String, dynamic> data) =>
      _dio.post('/admin/institutions', data: data);

  Future<Response> updateAdminInstitution(String id, Map<String, dynamic> data) =>
      _dio.patch('/admin/institutions/$id', data: data);

  Future<Response> deleteAdminInstitution(String id) =>
      _dio.delete('/admin/institutions/$id');

  Future<Response> getAdminBusAssignments() => _dio.get('/admin/bus-assignments');

  Future<Response> createAdminBusAssignment(Map<String, dynamic> data) =>
      _dio.post('/admin/bus-assignments', data: data);

  Future<Response> deleteAdminBusAssignment(String id) =>
      _dio.delete('/admin/bus-assignments/$id');

  Future<Response> getAdminTrips({Map<String, dynamic>? query}) =>
      _dio.get('/admin/trips', queryParameters: query);

  Future<Response> createAdminTrip(Map<String, dynamic> data) =>
      _dio.post('/admin/trips', data: data);

  Future<Response> getAdminReports({Map<String, dynamic>? query}) =>
      _dio.get('/admin/reports', queryParameters: query);

  Future<Response<List<int>>> exportAdminReport({Map<String, dynamic>? query}) =>
      _dio.get<List<int>>(
        '/admin/reports/export',
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );

  Future<Response> getAdminThresholds() => _dio.get('/admin/thresholds');

  Future<Response> updateAdminThresholds(Map<String, dynamic> data) =>
      _dio.put('/admin/thresholds', data: data);

  Future<Response> getAdminAuditLogs() => _dio.get('/admin/audit-logs');

  // User Management
  Future<Response> getAdminUsers({String? role, String? status, String? search}) =>
      _dio.get('/admin/users', queryParameters: {
        if (role != null) 'role': role,
        if (status != null) 'status': status,
        if (search != null) 'search': search,
      });

  Future<Response> createAdminUser(Map<String, dynamic> data) =>
      _dio.post('/admin/users', data: data);

  Future<Response> updateAdminUser(String id, Map<String, dynamic> data) =>
      _dio.patch('/admin/users/$id', data: data);

  Future<Response> resetAdminUserPassword(String id, String newPassword) =>
      _dio.post('/admin/users/$id/reset-password', data: {'newPassword': newPassword});

  // ============================================================
  // Driver
  // ============================================================
  Future<Response> getDriverProfile() => _dio.get('/driver/me');

  Future<Response> getDriverTodayTrips() => _dio.get('/driver/today-trips');

  /// Start trip: sends mileage photo + startKm as multipart
  Future<Response> driverStartTrip({
    required String tripId,
    required double startKm,
    String? tripType,
    String? photoPath,
    String? spareBus,
    String? remarks,
    String? studentCount,
    String? voicePath,
  }) async {
    final formData = FormData.fromMap({
      'tripId': tripId,
      'startKm': startKm.toString(),
      if (tripType != null && tripType.isNotEmpty) 'tripType': tripType,
      if (spareBus != null && spareBus.isNotEmpty) 'spareBus': spareBus,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      if (studentCount != null && studentCount.isNotEmpty) 'studentCount': studentCount,
      if (photoPath != null)
        'photo': await MultipartFile.fromFile(photoPath, filename: 'mileage_start.jpg'),
      if (voicePath != null)
        'voice': await MultipartFile.fromFile(voicePath, filename: 'voice_start.m4a'),
    });
    return _dio.post('/driver/trip/start', data: formData);
  }

  /// End trip: sends mileage photo + endKm as multipart
  Future<Response> driverEndTrip({
    required String tripId,
    required double endKm,
    String? logId,
    String? tripType,
    double? startKm,
    String? photoPath,
    String? spareBus,
    String? remarks,
    String? studentCount,
    String? voicePath,
  }) async {
    final formData = FormData.fromMap({
      'tripId': tripId,
      'endKm': endKm.toString(),
      if (logId != null && logId.isNotEmpty) 'logId': logId,
      if (tripType != null && tripType.isNotEmpty) 'tripType': tripType,
      if (startKm != null) 'startKm': startKm.toString(),
      if (spareBus != null && spareBus.isNotEmpty) 'spareBus': spareBus,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      if (studentCount != null && studentCount.isNotEmpty) 'studentCount': studentCount,
      if (photoPath != null)
        'photo': await MultipartFile.fromFile(photoPath, filename: 'mileage_end.jpg'),
      if (voicePath != null)
        'voice': await MultipartFile.fromFile(voicePath, filename: 'voice_end.m4a'),
    });
    return _dio.post('/driver/trip/end', data: formData);
  }

  /// Submit day report: vehicle condition fields + images + voice note
  Future<Response> driverSubmitDayReport({
    required Map<String, String> fields,
    List<String> imagePaths = const [],
    String? voicePath,
  }) async {
    final formFields = Map<String, dynamic>.from(fields);
    final List<MultipartFile> imageFiles = [];
    for (final p in imagePaths) {
      imageFiles.add(await MultipartFile.fromFile(p, filename: 'issue.jpg'));
    }
    if (imageFiles.isNotEmpty) formFields['images'] = imageFiles;
    if (voicePath != null) {
      formFields['voice'] = await MultipartFile.fromFile(voicePath, filename: 'voice.m4a');
    }
    return _dio.post('/driver/day-report', data: FormData.fromMap(formFields));
  }

  Future<Response> getDriverReports() => _dio.get('/driver/reports');

  // Admin: Driver Management
  Future<Response> getAdminDrivers({String? search, bool? isActive}) =>
      _dio.get('/admin/drivers', queryParameters: {
        if (search != null) 'search': search,
        if (isActive != null) 'isActive': isActive.toString(),
      });

  Future<Response> createAdminDriver(Map<String, dynamic> data) =>
      _dio.post('/admin/drivers', data: data);

  Future<Response> updateAdminDriver(String id, Map<String, dynamic> data) =>
      _dio.patch('/admin/drivers/$id', data: data);

  Future<Response> deleteAdminDriver(String id) =>
      _dio.delete('/admin/drivers/$id');

  Future<Response> getAdminDriverAssignments() =>
      _dio.get('/admin/driver-assignments');

  Future<Response> createAdminDriverAssignment(Map<String, dynamic> data) =>
      _dio.post('/admin/driver-assignments', data: data);

  Future<Response> deleteAdminDriverAssignment(String id) =>
      _dio.delete('/admin/driver-assignments/$id');

  Future<Response> getAdminDriverReports({String? driverId, String? busId, String? date}) =>
      _dio.get('/admin/driver-reports', queryParameters: {
        if (driverId != null) 'driverId': driverId,
        if (busId != null) 'busId': busId,
        if (date != null) 'date': date,
      });

  // ============================================================
  // Supervisor & Maintenance PO API
  // ============================================================
  Future<Response> getSupervisorDashboard() => _dio.get('/supervisor/dashboard');

  Future<Response> verifyDailyReport({
    required String busId,
    required String reportDate,
    double? verifiedOpeningKm,
    double? verifiedClosingKm,
    String? remarks,
    String? status,
  }) =>
      _dio.post('/supervisor/verify-daily-report', data: {
        'busId': busId,
        'reportDate': reportDate,
        if (verifiedOpeningKm != null) 'verifiedOpeningKm': verifiedOpeningKm,
        if (verifiedClosingKm != null) 'verifiedClosingKm': verifiedClosingKm,
        if (remarks != null) 'remarks': remarks,
        if (status != null) 'status': status,
      });

  Future<Response> getMaintenanceTickets({String? busId, String? status, String? category}) =>
      _dio.get('/supervisor/tickets', queryParameters: {
        if (busId != null) 'busId': busId,
        if (status != null) 'status': status,
        if (category != null) 'category': category,
      });

  Future<Response> createMaintenanceTicket(Map<String, dynamic> data) =>
      _dio.post('/supervisor/tickets', data: data);

  Future<Response> getTicketDetails(String id) =>
      _dio.get('/supervisor/tickets/$id');

  Future<Response> updateTicketStatus(String id, {required String status, String? adminRemarks}) =>
      _dio.patch('/supervisor/tickets/$id/status', data: {
        'status': status,
        if (adminRemarks != null) 'adminRemarks': adminRemarks,
      });
}

// ============================================================
// Auth Interceptor
// ============================================================

class _AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._tokenStorage, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    if (path.contains('/auth/login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/register')) {
      return handler.next(err);
    }

    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await _tokenStorage.getRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          // Use isolated Dio instance to avoid interceptor recursion
          final refreshDio = Dio(BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
              'Bypass-Tunnel-Reminder': 'true',
            },
          ));

          final response = await refreshDio.post('/auth/refresh', data: {'refreshToken': refreshToken});
          final respData = response.data;
          final newAccessToken = respData['data']?['accessToken'] ?? respData['accessToken'];

          if (newAccessToken != null && newAccessToken is String) {
            await _tokenStorage.saveTokens(
              accessToken: newAccessToken,
              refreshToken: refreshToken,
            );

            // Retry original request if data is not a consumed FormData stream
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newAccessToken';
            if (opts.data is! FormData) {
              try {
                final retryResponse = await _dio.fetch(opts);
                _isRefreshing = false;
                return handler.resolve(retryResponse);
              } catch (_) {
                // Return original error if retry also failed
              }
            }
          }
        }
      } catch (refreshErr) {
        if (refreshErr is DioException && refreshErr.response?.statusCode == 401) {
          await _tokenStorage.clear();
        }
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }
}

/// Helper function to format Dio/network errors nicely for UI
String formatApiError(dynamic e) {
  if (e is DioException) {
    if (e.response?.statusCode == 401) {
      return 'அமர்வு முடிவடைந்தது (401). தயவுசெய்து மீண்டும் உள்நுழையவும். (Session expired, please log in again)';
    }
    if (e.response?.statusCode == 403) {
      return 'அனுமதி மறுக்கப்பட்டது (403). (Access denied)';
    }
    if (e.response?.statusCode == 404) {
      final msg = e.response?.data is Map ? (e.response!.data['error'] ?? e.response!.data['message']) : null;
      return msg?.toString() ?? 'தகவல் கிடைக்கவில்லை (404 Not Found)';
    }
    if (e.response?.data is Map) {
      final msg = e.response!.data['error'] ?? e.response!.data['message'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString();
      }
    }
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return 'இணைப்பு நேரம் முடிந்தது. இணைய இணைப்பை சரிபார்க்கவும். (Connection timeout)';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'சேவையகத்தை தொடர்பு கொள்ள முடியவில்லை. (Server unreachable)';
    }
  }
  return e.toString().replaceAll('Exception: ', '').replaceAll('DioException [bad response]: ', '');
}
