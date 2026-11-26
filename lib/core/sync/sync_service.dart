import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../auth/token_storage.dart';
import '../db/local_database.dart';

part 'sync_service.g.dart';

@riverpod
SyncService syncService(SyncServiceRef ref) {
  final service = SyncService(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
    LocalDatabase.instance,
  );
  service.startListening();
  ref.onDispose(service.dispose);
  return service;
}

class SyncService {
  final ApiClient _api;
  final TokenStorage _tokenStorage;
  final LocalDatabase _db;
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  SyncService(this._api, this._tokenStorage, this._db);

  void startListening() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final hasConnection = !results.contains(ConnectivityResult.none) && results.isNotEmpty;

      if (hasConnection) {
        await syncPending();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  /// Save attendance record to local queue (for offline use)
  Future<String> queueAttendance(Map<String, dynamic> record) async {
    const uuid = Uuid();
    final id = record['id'] ?? uuid.v4();
    final data = {
      ...record,
      'id': id,
      'is_synced': 0,
      'marked_at': record['marked_at'] ?? DateTime.now().toIso8601String(),
    };
    await _db.insertOfflineAttendance(data);
    return id;
  }

  /// Attempt to sync all pending records
  Future<SyncResult> syncPending() async {
    if (_isSyncing) return SyncResult(synced: 0, failed: 0, skipped: 0);
    _isSyncing = true;

    try {
      final pending = await _db.getPendingAttendance();
      if (pending.isEmpty) return SyncResult(synced: 0, failed: 0, skipped: 0);

      final deviceId = await _tokenStorage.getDeviceId();
      final inchargeId = await _tokenStorage.getProfileId();

      final response = await _api.syncOfflineAttendance({
        'deviceId': deviceId,
        'inchargeId': inchargeId,
        'records': pending.map((r) => ({
          'offlineId': r['id'],
          'sessionId': r['session_id'],
          'studentId': r['student_id'],
          'tripId': r['trip_id'],
          'stageId': r['stage_id'],
          'busId': r['bus_id'],
          'routeId': r['route_id'],
          'attendanceType': r['attendance_type'],
          'method': r['method'],
          'latitude': r['latitude'],
          'longitude': r['longitude'],
          'accuracy': r['accuracy'],
          'boardedLocation': r['boarded_location'],
          'markedAt': r['marked_at'],
          'status': r['status'],
        })).toList(),
      });

      final result = response.data['data'];
      final details = result['details'];

      // Mark each record's sync status
      final successIds = (details['success'] as List)
          .map((e) => e['offlineId'] as String)
          .toSet();
      final skipIds = (details['skipped'] as List)
          .map((e) => e['offlineId'] as String)
          .toSet();

      for (final id in {...successIds, ...skipIds}) {
        await _db.markAttendanceSynced(id);
      }

      for (final failed in (details['failed'] as List)) {
        await _db.markAttendanceSyncFailed(
          failed['offlineId'] as String,
          failed['reason'] as String? ?? 'Unknown',
        );
      }

      return SyncResult(
        synced: result['success'] as int,
        failed: result['failed'] as int,
        skipped: result['skipped'] as int,
      );
    } catch (e) {
      return SyncResult(synced: 0, failed: 0, skipped: 0, error: e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  Future<int> getPendingCount() => _db.getPendingCount();

  /// Check current connectivity
  Future<bool> hasConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final int skipped;
  final String? error;

  const SyncResult({
    required this.synced,
    required this.failed,
    required this.skipped,
    this.error,
  });

  bool get hasError => error != null;
  int get total => synced + failed + skipped;
}
