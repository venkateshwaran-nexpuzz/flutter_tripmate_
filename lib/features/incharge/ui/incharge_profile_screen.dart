import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/gps/gps_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/widgets/app_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/incharge_provider.dart';

class InchargeProfileScreen extends ConsumerStatefulWidget {
  const InchargeProfileScreen({super.key});

  @override
  ConsumerState<InchargeProfileScreen> createState() => _InchargeProfileScreenState();
}

class _InchargeProfileScreenState extends ConsumerState<InchargeProfileScreen> {
  Position? _pos;
  int _pendingSync = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    try {
      final pos = await ref.read(gpsServiceProvider).getCurrentPosition();
      final count = await ref.read(syncServiceProvider).getPendingCount();
      if (mounted) {
        setState(() {
          _pos = pos;
          _pendingSync = count;
        });
      }
    } catch (_) {}
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    await globalAction(() async {
      final sync = ref.read(syncServiceProvider);
      final result = await sync.syncPending();
      if (mounted) {
        if (result.hasError) {
          AppSnackBar.showError(context, 'Sync failed: ${result.error}');
        } else {
          AppSnackBar.showSuccess(context, 'Synced ${result.synced} offline records successfully!');
        }
        await _loadDiagnostics();
      }
    },
    message: 'Synchronizing offline records...',
    );
    if (mounted) setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final assignmentAsync = ref.watch(inchargeAssignmentProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Staff & Incharge Profile',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryAccent),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(inchargeAssignmentProvider);
              _loadDiagnostics();
              AppSnackBar.showInfo(context, 'Profile refreshed');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryAccent,
        onRefresh: () async {
          ref.invalidate(inchargeAssignmentProvider);
          await _loadDiagnostics();
        },
        child: assignmentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
                  const SizedBox(height: 12),
                  Text('Failed to load profile: $e', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.danger)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(inchargeAssignmentProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) => _buildInchargeContent(context, user, data),
        ),
      ),
    );
  }

  Widget _buildInchargeContent(BuildContext context, dynamic user, Map<String, dynamic> data) {
    final incharge = data['incharge'] as Map<String, dynamic>? ?? {};
    final bus = data['bus'] as Map<String, dynamic>? ?? {};
    final route = data['route'] as Map<String, dynamic>? ?? {};
    final stages = (data['stages'] as List?) ?? [];

    final name = (data['incharge_name'] ?? incharge['name'] ?? data['name'] ?? 'Bus Incharge / Staff').toString();
    final email = (data['email'] ?? incharge['email'] ?? user?.email ?? 'incharge@tripmate.edu').toString();
    final phone = (data['phone'] ?? incharge['phone'] ?? 'Not added').toString();
    final empId = (data['employee_id'] ?? incharge['employee_id'] ?? 'INC-VET').toString();
    final busNo = (data['bus_number'] ?? bus['bus_number'] ?? 'Not Assigned').toString();
    final regNo = (data['registration_no'] ?? data['registration_number'] ?? bus['registration_no'] ?? bus['registration_number'] ?? 'N/A').toString();
    final capacity = data['capacity'] ?? bus['capacity'] ?? 50;
    final routeName = (data['route_name'] ?? route['route_name'] ?? 'Not Assigned').toString();
    final startPt = (data['start_point'] ?? route['start_point'] ?? 'Start').toString();
    final endPt = (data['end_point'] ?? route['end_point'] ?? 'Campus').toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Incharge Staff Identity Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.badge_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'VET FLEET OPERATIONS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Emp ID: $empId',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'CREW LEAD',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'I',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Phone: $phone',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Assigned Vehicle & Route Details
              const Text(
                'Assigned Fleet & Route',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.directions_bus_rounded,
                      iconColor: const Color(0xFF0D9488),
                      label: 'Assigned Bus Number',
                      value: '$busNo (Reg: $regNo)',
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _InfoRow(
                      icon: Icons.airline_seat_recline_normal_rounded,
                      iconColor: const Color(0xFF2563EB),
                      label: 'Seating Capacity',
                      value: '$capacity Passenger Seats',
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _InfoRow(
                      icon: Icons.alt_route_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      label: 'Assigned Route',
                      value: routeName,
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _InfoRow(
                      icon: Icons.timeline_rounded,
                      iconColor: const Color(0xFFE11D48),
                      label: 'Transit Corridor',
                      value: '$startPt to $endPt',
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _InfoRow(
                      icon: Icons.pin_drop_rounded,
                      iconColor: const Color(0xFFD97706),
                      label: 'Assigned Stop Stages',
                      value: '${stages.length} Configured Stops',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Device & GPS Sync Diagnostics
              const Text(
                'Device & Offline Sync Status',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.gps_fixed_rounded,
                      iconColor: _pos != null ? AppTheme.success : AppTheme.warning,
                      label: 'Device GPS Geofence',
                      value: _pos != null
                          ? '${_pos!.latitude.toStringAsFixed(4)}, ${_pos!.longitude.toStringAsFixed(4)} (Active)'
                          : 'Acquiring GPS Signal...',
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _InfoRow(
                      icon: Icons.sync_rounded,
                      iconColor: _pendingSync > 0 ? AppTheme.warning : AppTheme.success,
                      label: 'Offline Queue',
                      value: _pendingSync > 0 ? '$_pendingSync Pending Local Records' : 'All Attendance Synced',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. Manual Sync & Navigation Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSyncing ? null : _triggerManualSync,
                      icon: _isSyncing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: Text(_isSyncing ? 'Syncing...' : 'Sync Offline Logs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/incharge/students'),
                      icon: const Icon(Icons.people_alt_rounded, size: 18),
                      label: const Text('Students Directory'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D9488),
                        side: const BorderSide(color: Color(0xFF0D9488)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await globalAction(() async {
                      await ref.read(authStateProvider.notifier).logout();
                    },
                    message: 'Logging out from Incharge account...',
                    );
                    if (context.mounted) {
                      AppSnackBar.showSuccess(context, 'Logged out successfully');
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Logout from Incharge Account', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE2E2),
                    foregroundColor: AppTheme.danger,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
