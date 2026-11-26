import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

// ============================================================
// Driver Profile Provider
// ============================================================
final driverProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getDriverProfile();
  return response.data['data'] as Map<String, dynamic>;
});

// ============================================================
// Today's Trips Provider
// ============================================================
final driverTodayTripsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getDriverTodayTrips();
  return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
});

// ============================================================
// Driver History Provider
// ============================================================
final driverReportsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getDriverReports();
  return response.data['data'] as Map<String, dynamic>;
});

// ============================================================
// Active Trip State (for start/end tracking)
// ============================================================
class ActiveDriverTripNotifier extends StateNotifier<Map<String, dynamic>?> {
  ActiveDriverTripNotifier() : super(null);

  void setTrip(Map<String, dynamic> trip) => state = trip;
  void clearTrip() => state = null;
}

final activeDriverTripProvider = StateNotifierProvider<ActiveDriverTripNotifier, Map<String, dynamic>?>((ref) {
  return ActiveDriverTripNotifier();
});
