import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/gps/gps_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_language_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/incharge_provider.dart';

class InchargeDashboardScreen extends ConsumerStatefulWidget {
  const InchargeDashboardScreen({super.key});

  @override
  ConsumerState<InchargeDashboardScreen> createState() => _InchargeDashboardState();
}

class _InchargeDashboardState extends ConsumerState<InchargeDashboardScreen> {
  Position? _currentPosition;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadGPS();
    _loadPendingCount();
  }

  Future<void> _loadGPS() async {
    final gps = ref.read(gpsServiceProvider);
    if (!mounted) return;
    await gps.ensureGpsEnabled(context);
    final pos = await gps.getCurrentPosition();
    if (mounted) setState(() => _currentPosition = pos);
  }

  Future<void> _loadPendingCount() async {
    final count = await ref.read(syncServiceProvider).getPendingCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  Future<void> _syncNow() async {
    await globalAction(() async {
      final sync = ref.read(syncServiceProvider);
      final result = await sync.syncPending();
      if (mounted) {
        if (result.hasError) {
          AppSnackBar.showError(context, 'Sync failed: ${result.error}');
        } else {
          AppSnackBar.showSuccess(context, 'Synced ${result.synced} offline records successfully!');
        }
        await _loadPendingCount();
      }
    },
    message: 'Synchronizing offline attendance records...',
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignmentAsync = ref.watch(inchargeAssignmentProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const VetBrandLogo(size: 36, compact: true),
        actions: [
          const Center(
            child: AppLanguageButton(compact: true),
          ),
          const SizedBox(width: 2),

          // Pending sync badge
          if (_pendingCount > 0)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: _syncNow,
              tooltip: 'Sync $_pendingCount pending records',
              icon: Stack(
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: AppTheme.warning, size: 20),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () => context.push('/incharge/trips'),
            icon: const Icon(Icons.history_edu_rounded, color: Color(0xFF1E40AF), size: 20),
            tooltip: 'Trip History & PDF Reports',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () => context.push('/incharge/profile'),
            icon: const Icon(Icons.account_circle_outlined, color: AppTheme.primaryAccent, size: 20),
            tooltip: 'Incharge Profile & Fleet Info',
          ),

          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () async {
              await globalAction(() async {
                await ref.read(authStateProvider.notifier).logout();
              },
              message: 'Logging out...',
              );
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary, size: 20),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: RefreshIndicator(
        color: AppTheme.primaryAccent,
        onRefresh: () async {
          ref.invalidate(inchargeAssignmentProvider);
          ref.invalidate(inchargeTripsProvider);
          await _loadGPS();
          await _loadPendingCount();
        },
        child: assignmentAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryAccent),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FeatureIconBadge(
                    icon: Icons.directions_bus_filled_outlined,
                    color: AppTheme.primaryAccent,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Active Bus Assignment Found',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(inchargeAssignmentProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh Assignment'),
                  ),
                ],
              ),
            ),
          ),
          data: (assignment) => _buildContent(assignment),
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> assignment) {
    final bus = assignment['bus_number'] as String?;
    final regNo = assignment['registration_no'] as String?;
    final route = assignment['route_name'] as String?;
    final routeCode = assignment['route_code'] as String?;
    final stages = (assignment['stages'] as List?) ?? [];
    final currentTrip = assignment['current_trip'] as Map<String, dynamic>?;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Incharge Profile Banner (White & Royal Blue)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E40AF).withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_pin_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                assignment['incharge_name'] ?? 'Bus Incharge',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'INCHARGE',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Emp ID: ${assignment['employee_id'] ?? '—'} • Phone: ${assignment['phone'] ?? '—'}',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Vehicle & Route Assignment Card
              _InfoCard(
                title: 'Assigned Bus & Route',
                headerIcon: Icons.directions_bus_rounded,
                children: [
                  _InfoRow(
                    icon: Icons.directions_bus_outlined,
                    label: 'Bus',
                    value: '$bus (${regNo ?? 'TN-REG'})',
                    iconColor: AppTheme.primaryAccent,
                  ),
                  _InfoRow(
                    icon: Icons.alt_route_rounded,
                    label: 'Route',
                    value: '$route (${routeCode ?? 'VET-R'})',
                    iconColor: AppTheme.secondary,
                  ),
                  _InfoRow(
                    icon: Icons.pin_drop_outlined,
                    label: 'Stops',
                    value: '${stages.length} defined stage stops',
                    iconColor: AppTheme.warning,
                  ),
                  _InfoRow(
                    icon: Icons.people_outline_rounded,
                    label: 'Passengers',
                    value: '${assignment['student_count'] ?? 0} active students & staff',
                    iconColor: AppTheme.primaryAccent,
                  ),
                  if (_currentPosition != null)
                    _InfoRow(
                      icon: Icons.my_location_rounded,
                      label: 'GPS Active',
                      value: '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                      iconColor: AppTheme.success,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Current Trip Status Card
              _buildTripCard(currentTrip, assignment),

              const SizedBox(height: 16),

              // Dedicated Trip History Action Card
              _ActionCard(
                title: 'Trip History & PDF Reports',
                subtitle: 'View past trips, inspect student attendance rosters, and print official PDF reports',
                icon: Icons.history_edu_rounded,
                color: const Color(0xFF1E40AF),
                onTap: () => context.push('/incharge/trips'),
              ),

              const SizedBox(height: 16),

              // Student Directory & CRUD Quick Action Card
              _ActionCard(
                title: 'Route Passenger Directory (${assignment['student_count'] ?? 0})',
                subtitle: 'Manage ${assignment['student_count'] ?? 0} assigned students & staff, add new, edit details, and view roster',
                icon: Icons.people_alt_rounded,
                color: AppTheme.secondary,
                onTap: () => context.push('/incharge/students'),
              ),

              const SizedBox(height: 20),

              // Stages Sequence List
              if (stages.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.format_list_numbered_rounded, color: AppTheme.primaryAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Route Stops Sequence',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const Spacer(),
                    Text(
                      '${stages.length} Stops',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...stages.asMap().entries.map((e) {
                  final stage = e.value as Map<String, dynamic>;
                  return _StageCard(stage: stage, index: e.key);
                }),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic>? trip, Map<String, dynamic> assignment) {
    if (trip == null) {
      return _ActionCard(
        title: 'Start Daily Bus Trip',
        subtitle: 'Tap to initiate trip schedule and start scanning attendance',
        icon: Icons.play_circle_filled_rounded,
        color: AppTheme.primaryAccent,
        onTap: () => _showStartTripDialog(assignment),
      );
    }

    final status = trip['status'] as String;
    final isActive = status == 'active';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? AppTheme.primaryAccent.withOpacity(0.4) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isActive ? AppTheme.primaryAccent : Colors.black).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FeatureIconBadge(
                icon: Icons.directions_bus_rounded,
                color: isActive ? AppTheme.success : AppTheme.primaryAccent,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Trip: ${(trip['trip_type'] as String).toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      '${(trip['trip_direction'] as String).capitalize()} • Status: ${status.capitalize()}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.successLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  status.capitalize(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppTheme.success : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),

          if (isActive) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _startSmartAttendanceSession(trip, assignment),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: const Text('Scan Attendance (Auto-GPS)', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showManualStagePicker(trip, assignment),
                        icon: const Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryAccent),
                        label: const Text('Manual Stop', style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.w700, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryAccent, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showCompleteTripConfirmation(trip, assignment),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.danger),
                        label: const Text('Complete Trip', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.danger, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showStartTripDialog(Map<String, dynamic> assignment) {
    String tripType = 'morning';
    String tripDirection = 'boarding';
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.directions_bus_rounded, color: AppTheme.primaryAccent, size: 22),
              SizedBox(width: 8),
              Text('Start New Trip', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Trip Date Picker Tile
                  const Text('Trip Schedule Date:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 7)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setS(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF1E40AF)),
                          const SizedBox(width: 8),
                          Text(
                            '${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppTheme.textPrimary),
                          ),
                          const Spacer(),
                          const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Departure / Start Time Picker Tile
                  const Text('Departure / Start Time:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setS(() => selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF1E40AF)),
                          const SizedBox(width: 8),
                          Text(
                            selectedTime.format(context),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppTheme.textPrimary),
                          ),
                          const Spacer(),
                          const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. Trip Type Selector
                  DropdownButtonFormField<String>(
                    value: tripType,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Trip Type', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: ['morning', 'evening', 'special']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.capitalize(), style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setS(() => tripType = v!),
                  ),
                  const SizedBox(height: 10),

                  // 4. Trip Direction Selector
                  DropdownButtonFormField<String>(
                    value: tripDirection,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Trip Direction', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: const [
                      DropdownMenuItem(value: 'boarding', child: Text('Boarding (Pick-up Students)', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'exit', child: Text('Exit (Drop-off Students)', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) => setS(() => tripDirection = v!),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final formattedDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                final localStartDt = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                final startDateTime = localStartDt.toUtc().toIso8601String();
                final assignmentId = assignment['assignment_id'] ?? assignment['id'];
                final tType = tripType;
                final tDir = tripDirection;
                final sTimeFmt = selectedTime.format(context);

                Navigator.pop(ctx);

                await globalAction(() async {
                  final api = ref.read(apiClientProvider);
                  final response = await api.startTrip({
                    'busAssignmentId': assignmentId,
                    'tripType': tType,
                    'tripDirection': tDir,
                    'tripDate': formattedDate,
                    'startTime': startDateTime,
                  });
                  ref.read(activeTripStateProvider.notifier).setTrip(response.data['data']);
                  ref.invalidate(inchargeAssignmentProvider);
                  ref.invalidate(inchargeTripsProvider);
                },
                message: 'Starting and dispatching bus trip...',
                successMessage: 'Trip started for $formattedDate at $sTimeFmt',
                );
              },
              child: const Text('Confirm & Start Trip'),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _detectNearestStage(List stages, Position? pos) {
    if (stages.isEmpty) return {};
    if (pos == null) return Map<String, dynamic>.from(stages.first as Map);

    Map<String, dynamic> nearest = Map<String, dynamic>.from(stages.first as Map);
    double minDistance = double.infinity;

    for (final s in stages) {
      final stage = s as Map<String, dynamic>;
      final lat = double.tryParse(stage['latitude']?.toString() ?? '');
      final lon = double.tryParse(stage['longitude']?.toString() ?? '');

      if (lat != null && lon != null) {
        final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lon);
        if (dist < minDistance) {
          minDistance = dist;
          nearest = {
            ...stage,
            'distance_meters': dist.round(),
          };
        }
      }
    }
    return nearest;
  }

  Future<void> _startSmartAttendanceSession(
    Map<String, dynamic> trip,
    Map<String, dynamic> assignment, {
    String? forceStageId,
  }) async {
    final stages = (assignment['stages'] as List?) ?? [];
    if (stages.isEmpty) {
      AppSnackBar.showError(context, 'No stage stops configured for this route.');
      return;
    }

    await ref.read(globalLoadingProvider.notifier).runAction(
      context: context,
      message: forceStageId != null ? 'Opening stop session...' : 'Detecting GPS stop & opening scanner...',
      action: () async {
        // Fast GPS location (uses instant memory cache or 1.5s fast lookup)
        Position? pos = _currentPosition;
        try {
          final gps = ref.read(gpsServiceProvider);
          pos = await gps.getFastPosition();
          pos ??= await gps.getCurrentPosition(timeLimit: const Duration(milliseconds: 1500));
          if (mounted && pos != null) setState(() => _currentPosition = pos);
        } catch (_) {}

        Map<String, dynamic> selectedStage;
        if (forceStageId != null) {
          selectedStage = stages.firstWhere(
            (s) => s['id'] == forceStageId,
            orElse: () => stages.first as Map<String, dynamic>,
          ) as Map<String, dynamic>;
        } else {
          selectedStage = _detectNearestStage(stages, pos);
        }

        final api = ref.read(apiClientProvider);
        final response = await api.startSession({
          'tripId': trip['id'],
          'stageId': selectedStage['id'],
          if (pos != null) 'latitude': pos.latitude,
          if (pos != null) 'longitude': pos.longitude,
        });

        final session = response.data['data'] as Map<String, dynamic>;
        final sessionData = {
          ...session,
          'stage_name': selectedStage['stage_name'],
          'bus_id': assignment['bus_id'],
          'route_id': assignment['route_id'],
          'trip_type': trip['trip_type'],
          'bus_number': assignment['bus_number'],
          'route_name': assignment['route_name'],
          'stage_lat': selectedStage['latitude'],
          'stage_lon': selectedStage['longitude'],
          'stage_radius': selectedStage['allowed_radius_meters'],
        };

        if (mounted) {
          final distText = selectedStage['distance_meters'] != null
              ? ' (${selectedStage['distance_meters']}m away)'
              : '';
          AppSnackBar.showSuccess(
            context,
            forceStageId != null
                ? 'Selected stop: ${selectedStage['stage_name']}'
                : 'Auto-detected stop: ${selectedStage['stage_name']}$distText',
          );
          context.push('/incharge/session/${session['id']}', extra: sessionData);
        }
      },
    );
  }

  void _showManualStagePicker(Map<String, dynamic> trip, Map<String, dynamic> assignment) {
    final stages = (assignment['stages'] as List?) ?? [];
    if (stages.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pin_drop_rounded, color: AppTheme.primaryAccent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Choose Stage Stop Manually',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select a stop to override the GPS auto-detection:',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: stages.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final s = stages[i] as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primaryAccent.withOpacity(0.12),
                      child: Text(
                        '${s['sequence_order'] ?? i + 1}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primaryAccent),
                      ),
                    ),
                    title: Text(
                      s['stage_name'] ?? 'Stop ${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startSmartAttendanceSession(trip, assignment, forceStageId: s['id'] as String?);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompleteTripConfirmation(Map<String, dynamic> trip, Map<String, dynamic> assignment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppTheme.danger),
            SizedBox(width: 8),
            Text('Complete Trip & Finalize?'),
          ],
        ),
        content: const Text(
          'Completing this trip will automatically close and lock all attendance sessions. Any student who has not boarded will be recorded as absent.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // 1. Flush and sync any pending offline attendance records before locking trip
                final sync = ref.read(syncServiceProvider);
                try {
                  final pendingCount = await sync.getPendingCount();
                  if (pendingCount > 0) {
                    await sync.syncPending();
                  }
                } catch (syncErr) {
                  debugPrint('Pre-completion sync notice: $syncErr');
                }

                final api = ref.read(apiClientProvider);
                final tripId = trip['id'].toString();
                final res = await api.endTrip(tripId);
                ref.invalidate(inchargeAssignmentProvider);
                ref.invalidate(inchargeTripsProvider);
                ref.read(activeTripStateProvider.notifier).clearTrip();

                final summary = res.data['data']?['summary'] as Map<String, dynamic>?;
                final present = summary?['presentCount'] ?? 0;
                final absent = summary?['absentCount'] ?? 0;
                final total = summary?['totalStudents'] ?? (present + absent);

                if (mounted) {
                  AppSnackBar.showSuccess(context, 'Trip finalized! Attendance is now locked.');
                  _showTripCompletionSuccessDialog(
                    trip: trip,
                    assignment: assignment,
                    present: present,
                    absent: absent,
                    total: total,
                  );
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.showError(context, 'Failed to complete trip: ${formatApiError(e)}');
                }
              }
            },
            child: const Text('Yes, Complete Trip'),
          ),
        ],
      ),
    );
  }

  void _showTripCompletionSuccessDialog({
    required Map<String, dynamic> trip,
    required Map<String, dynamic> assignment,
    required int present,
    required int absent,
    required int total,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.task_alt_rounded, color: AppTheme.success, size: 28),
            SizedBox(width: 10),
            Text('Trip Finalized!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${(trip['trip_type'] ?? 'Morning').toString().toUpperCase()} TRIP (${trip['trip_direction'] ?? 'boarding'})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryAccent),
            ),
            const SizedBox(height: 10),

            // Timing Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.departure_board_rounded, size: 16, color: Color(0xFF1E40AF)),
                      const SizedBox(width: 4),
                      Text(
                        'Start: ${trip['actual_start'] != null ? DateFormat('hh:mm a').format(DateTime.tryParse(trip['actual_start'].toString()) ?? DateTime.now()) : DateFormat('hh:mm a').format(DateTime.now().subtract(const Duration(minutes: 45)))}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.flag_rounded, size: 16, color: AppTheme.success),
                      const SizedBox(width: 4),
                      Text(
                        'Reached: ${DateFormat('hh:mm a').format(DateTime.now())}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.success),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryMiniBox(label: 'Total', count: total, color: AppTheme.textPrimary),
                  _SummaryMiniBox(label: 'Present', count: present, color: AppTheme.success),
                  _SummaryMiniBox(label: 'Absent', count: absent, color: AppTheme.danger),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Attendance sessions are locked. You can now preview and print the official PDF report for records.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiClientProvider);
                final tripId = (trip['id'] ?? '').toString();
                final tripRes = await api.getTripAttendance(tripId);
                final tripData = tripRes.data['data'] as Map<String, dynamic>?;
                final tripMeta = (tripData?['trip'] as Map<String, dynamic>?) ?? {
                  ...trip,
                  'bus_number': assignment['bus_number'],
                  'route_name': assignment['route_name'],
                  'incharge_name': assignment['incharge_name'],
                };
                final attendanceList = List<Map<String, dynamic>>.from(tripData?['attendance'] ?? []);

                await PdfReportService.printTripReport(
                  trip: tripMeta,
                  attendanceRecords: attendanceList,
                );
              } catch (e) {
                if (mounted) {
                  AppSnackBar.showError(context, 'Could not generate PDF: $e');
                }
              }
            },
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: const Text('Print PDF Report'),
          ),
        ],
      ),
    );
  }
}

class _SummaryMiniBox extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryMiniBox({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ============================================================
// Helper UI Widgets
// ============================================================

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData headerIcon;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.headerIcon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headerIcon, size: 18, color: AppTheme.primaryAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color iconColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppTheme.primaryAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 75,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            FeatureIconBadge(icon: icon, color: color, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  final Map<String, dynamic> stage;
  final int index;
  const _StageCard({required this.stage, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primarySubtle),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage['stage_name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                ),
                Text(
                  'Radius: ${stage['allowed_radius_meters']} m',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.secondary),
        ],
      ),
    );
  }
}

extension StringCapExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
