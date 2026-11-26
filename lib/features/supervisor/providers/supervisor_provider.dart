import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

// Provider for Supervisor Dashboard (Assigned Buses, Today Submissions, Verification Queue)
final supervisorDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.getSupervisorDashboard();
  if (res.data is Map && res.data['success'] == true) {
    return (res.data['data'] as Map<String, dynamic>?) ?? {};
  }
  return {};
});

// Provider for Maintenance Tickets
final maintenanceTicketsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, busId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.getMaintenanceTickets(busId: busId);
  if (res.data is Map && res.data['success'] == true) {
    final list = res.data['data']?['tickets'] as List<dynamic>?;
    return list?.map((e) => e as Map<String, dynamic>).toList() ?? [];
  }
  return [];
});

// Notifier for Supervisor Actions (Verify Report & Create PO Ticket)
class SupervisorActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  final Ref _ref;

  SupervisorActionsNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<bool> verifyDailyReport({
    required String busId,
    required String reportDate,
    double? verifiedOpeningKm,
    double? verifiedClosingKm,
    String? remarks,
    String? status,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _api.verifyDailyReport(
        busId: busId,
        reportDate: reportDate,
        verifiedOpeningKm: verifiedOpeningKm,
        verifiedClosingKm: verifiedClosingKm,
        remarks: remarks,
        status: status,
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(supervisorDashboardProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<Map<String, dynamic>?> createMaintenanceTicket(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.createMaintenanceTicket(data);
      state = const AsyncValue.data(null);
      _ref.invalidate(supervisorDashboardProvider);
      _ref.invalidate(maintenanceTicketsProvider);
      if (res.data is Map && res.data['success'] == true) {
        return res.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final supervisorActionsProvider = StateNotifierProvider<SupervisorActionsNotifier, AsyncValue<void>>((ref) {
  final api = ref.watch(apiClientProvider);
  return SupervisorActionsNotifier(api, ref);
});
