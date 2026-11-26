import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/pdf_report_service.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E40AF).withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'VET',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'TRIPMATE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 8.5),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () {
              ref.invalidate(adminDashboardProvider);
              ref.invalidate(adminLiveBusesProvider);
              ref.invalidate(adminStudentsProvider);
              ref.invalidate(adminRoutesProvider);
              ref.invalidate(adminBusesProvider);
              ref.invalidate(adminTripsProvider);
              ref.invalidate(adminReportsProvider);
              ref.invalidate(adminThresholdsProvider);
              ref.invalidate(adminUsersProvider);
              AppSnackBar.showInfo(context, 'Admin console data refreshed');
            },
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryAccent, size: 20),
            tooltip: 'Refresh All',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => context.push('/admin/profile'),
            icon: const Icon(Icons.account_circle_outlined, color: AppTheme.primaryAccent, size: 22),
            tooltip: 'Administrator Profile & System Scope',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                AppSnackBar.showSuccess(context, 'Logged out successfully');
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary, size: 20),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: const [
          _AdminOverviewTab(),
          _AdminLiveFleetTab(),
          _AdminStudentsTab(),
          _AdminRoutesBusesTab(),
          _AdminReportsSettingsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1E40AF),
          unselectedItemColor: AppTheme.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              activeIcon: Icon(Icons.dashboard_rounded, color: Color(0xFF1E40AF)),
              label: 'Overview',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gps_fixed_rounded),
              activeIcon: Icon(Icons.gps_fixed_rounded, color: Color(0xFF1E40AF)),
              label: 'Live Fleet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded),
              activeIcon: Icon(Icons.people_alt_rounded, color: Color(0xFF1E40AF)),
              label: 'Students',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.alt_route_rounded),
              activeIcon: Icon(Icons.alt_route_rounded, color: Color(0xFF1E40AF)),
              label: 'Routes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded),
              activeIcon: Icon(Icons.analytics_rounded, color: Color(0xFF1E40AF)),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TAB 1: OVERVIEW
// ============================================================

class _AdminOverviewTab extends ConsumerWidget {
  const _AdminOverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(adminDashboardProvider);
    final liveBusesAsync = ref.watch(adminLiveBusesProvider);

    return RefreshIndicator(
      color: AppTheme.primaryAccent,
      onRefresh: () async {
        ref.invalidate(adminDashboardProvider);
        ref.invalidate(adminLiveBusesProvider);
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Royal Blue Hero Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1D4ED8).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                        ),
                        child: const Center(
                          child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'VET Fleet Control Console',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Real-time Transport & Multi-Campus Oversight',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Quick Access Banner: ID Card Scanner & Student Onboarding Module
                GestureDetector(
                  onTap: () => context.push('/admin/bus-student-scanner'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E40AF).withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF1E40AF), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Bus Student ID Card Scanner',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textPrimary),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 16),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Select bus & scan ID barcode / text OCR to onboard students',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF1E40AF)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // KPI Summary Grid
                dashboardAsync.when(
                  loading: () => const _KpiGridSkeleton(),
                  error: (e, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('Failed to load KPIs: $e', style: const TextStyle(color: AppTheme.danger)),
                  ),
                  data: (data) => _KpiGrid(data: data),
                ),

                const SizedBox(height: 24),

                // Live Bus Fleet Status Header
                const Row(
                  children: [
                    FeatureIconBadge(
                      icon: Icons.directions_bus_rounded,
                      color: AppTheme.primaryAccent,
                      size: 32,
                      iconSize: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Live Fleet Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                liveBusesAsync.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AppTheme.primaryAccent),
                  )),
                  error: (e, _) => Center(child: Text('Live fleet error: $e')),
                  data: (buses) {
                    if (buses.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text('No active trips running right now', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                      );
                    }

                    return Column(
                      children: buses.take(3).map((bus) => _LiveBusCard(bus: bus)).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Low Attendance Risk Watchlist
                dashboardAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (data) {
                    final rawAlerts = data['alerts'] ?? data['riskList'] ?? data['watchlist'];
                    final alerts = rawAlerts is List ? rawAlerts : [];
                    if (alerts.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            FeatureIconBadge(
                              icon: Icons.warning_amber_rounded,
                              color: AppTheme.danger,
                              size: 32,
                              iconSize: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Low Attendance & Risk Watchlist',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: alerts.take(5).map((a) {
                              final student = a as Map<String, dynamic>;
                              final rate = double.tryParse(student['attendance_percentage']?.toString() ?? '0') ?? 0.0;
                              final consecutive = student['consecutive_absences'] ?? 0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFEE2E2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person_off_rounded, color: AppTheme.danger, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${student['name']} (${student['roll_number']})',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary),
                                          ),
                                          Text(
                                            '${student['department'] ?? 'General'} • $consecutive Consecutive Absences',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${rate.toStringAsFixed(1)}%',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.danger),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAB 2: LIVE FLEET MONITOR
// ============================================================

// ============================================================
// TAB 2: LIVE FLEET MONITOR
// ============================================================

class _AdminLiveFleetTab extends ConsumerStatefulWidget {
  const _AdminLiveFleetTab();

  @override
  ConsumerState<_AdminLiveFleetTab> createState() => _AdminLiveFleetTabState();
}

class _AdminLiveFleetTabState extends ConsumerState<_AdminLiveFleetTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openLiveBusDetails(Map<String, dynamic> bus) {
    final busNo = bus['bus_number'] ?? 'Bus';
    final route = bus['route_name'] ?? 'Route';
    final incharge = bus['incharge_name'] ?? 'Incharge';
    final phone = bus['incharge_phone']?.toString();
    final tripType = bus['trip_type'] ?? 'morning';
    final direction = bus['trip_direction'] ?? 'pickup';
    final stage = bus['current_stage'] ?? bus['current_stage_name'] ?? bus['last_stage'] ?? 'Depot';
    final present = bus['present_count'] ?? 0;
    final absent = bus['absent_count'] ?? 0;
    final status = bus['trip_status'] ?? bus['status'] ?? 'active';
    final lat = bus['last_lat'];
    final lon = bus['last_lon'];
    final lastGpsUpdate = bus['last_gps_update'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: status == 'active' ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: status == 'active' ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE)),
                  ),
                  child: Icon(Icons.directions_bus_rounded, color: status == 'active' ? const Color(0xFF059669) : const Color(0xFF1E40AF), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(busNo.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.textPrimary)),
                      Text(route.toString(), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'active' ? const Color(0xFFDCFCE7) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: status == 'active' ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    status.toString().toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: status == 'active' ? const Color(0xFF059669) : const Color(0xFFD97706)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),
            // Trip Meta Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(text: tripType.toString().toUpperCase(), color: tripType == 'morning' ? const Color(0xFF2563EB) : const Color(0xFF7C3AED)),
                _Badge(text: direction.toString().toUpperCase(), color: const Color(0xFF475569)),
                _Badge(text: 'Stop: $stage', color: const Color(0xFF0D9488)),
              ],
            ),
            const SizedBox(height: 14),
            // Attendance summary
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFA7F3D0))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Boarded / Present', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
                        const SizedBox(height: 2),
                        Text('$present Students', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECDD3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Absentees', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF991B1B))),
                        const SizedBox(height: 2),
                        Text('$absent Students', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Incharge Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.person_pin_rounded, color: Color(0xFF1E40AF), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Incharge: $incharge', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary)),
                        if (phone != null && phone.isNotEmpty)
                          Text('Phone: $phone', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  if (phone != null && phone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF1E40AF)),
                      tooltip: 'Copy Phone',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        AppSnackBar.showSuccess(context, 'Incharge phone copied!');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // GPS Location
            if (lat != null && lon != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GPS: $lat, $lon', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E40AF))),
                          if (lastGpsUpdate != null)
                            Text('Updated: ${_formatTime(lastGpsUpdate)}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: 'https://maps.google.com/?q=$lat,$lon'));
                        AppSnackBar.showSuccess(context, 'Google Maps URL copied!');
                      },
                      icon: const Icon(Icons.map_rounded, size: 14),
                      label: const Text('Copy Map', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic timeVal) {
    if (timeVal == null) return '';
    try {
      final dt = DateTime.parse(timeVal.toString()).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$min $ampm';
    } catch (_) {
      return timeVal.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveBusesAsync = ref.watch(adminLiveBusesProvider);

    return RefreshIndicator(
      color: AppTheme.primaryAccent,
      onRefresh: () async => ref.invalidate(adminLiveBusesProvider),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const FeatureIconBadge(
                        icon: Icons.sensors_rounded,
                        color: Color(0xFF2563EB),
                        size: 40,
                        iconSize: 22,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live Fleet Monitor',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            Text(
                              'Real-time telemetry, stage progression, and attendance capture',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ref.invalidate(adminLiveBusesProvider);
                          AppSnackBar.showInfo(context, 'Fleet telemetry refreshed');
                        },
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryAccent),
                        tooltip: 'Refresh Live Fleet',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Live Summary KPIs & Data
                liveBusesAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48.0),
                      child: CircularProgressIndicator(color: AppTheme.primaryAccent),
                    ),
                  ),
                  error: (e, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(16)),
                    child: Text('Live fleet error: $e', style: const TextStyle(color: AppTheme.danger)),
                  ),
                  data: (buses) {
                    final activeBuses = buses.where((b) => (b['trip_status'] ?? b['status']) == 'active').toList();
                    final pendingBuses = buses.where((b) => (b['trip_status'] ?? b['status']) == 'pending').toList();
                    final totalPresent = buses.fold<int>(0, (sum, b) => sum + int.tryParse(b['present_count']?.toString() ?? '0')!);
                    final totalAbsent = buses.fold<int>(0, (sum, b) => sum + int.tryParse(b['absent_count']?.toString() ?? '0')!);

                    final search = _searchCtrl.text.trim().toLowerCase();
                    final filtered = buses.where((b) {
                      final busNo = (b['bus_number'] ?? '').toString().toLowerCase();
                      final route = (b['route_name'] ?? '').toString().toLowerCase();
                      final incharge = (b['incharge_name'] ?? '').toString().toLowerCase();
                      final status = (b['trip_status'] ?? b['status'] ?? 'active').toString().toLowerCase();

                      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;
                      final matchesSearch = search.isEmpty ||
                          busNo.contains(search) ||
                          route.contains(search) ||
                          incharge.contains(search);

                      return matchesStatus && matchesSearch;
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 5 KPI Metric Cards Grid
                        Row(
                          children: [
                            _buildLiveKpiCard('Active Trips', '${buses.length}', Icons.directions_bus_rounded, const Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            _buildLiveKpiCard('On Route', '${activeBuses.length}', Icons.sensors_rounded, const Color(0xFF059669)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildLiveKpiCard('Scheduled', '${pendingBuses.length}', Icons.hourglass_empty_rounded, const Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            _buildLiveKpiCard('Boarded', '$totalPresent', Icons.check_circle_outline_rounded, const Color(0xFF059669)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildLiveKpiCard('Absentees', '$totalAbsent', Icons.cancel_outlined, const Color(0xFFDC2626)),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Search & Status Filters Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _searchCtrl,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Search bus, route, or incharge...',
                                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                                  suffixIcon: _searchCtrl.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildStatusFilterChip('All Statuses', 'all'),
                                    const SizedBox(width: 6),
                                    _buildStatusFilterChip('Active Only', 'active'),
                                    const SizedBox(width: 6),
                                    _buildStatusFilterChip('Pending Only', 'pending'),
                                    const SizedBox(width: 6),
                                    _buildStatusFilterChip('Completed Only', 'completed'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Showing ${filtered.length} of ${buses.length} live units',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        if (filtered.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.sensors_off_rounded, size: 48, color: AppTheme.textMuted),
                                  SizedBox(height: 12),
                                  Text(
                                    'No Active Trips Match Criteria',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Trips started by bus incharges will update automatically.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final b = filtered[index];
                              return InkWell(
                                onTap: () => _openLiveBusDetails(b),
                                borderRadius: BorderRadius.circular(18),
                                child: _LiveBusCard(bus: b),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
      selected: isSelected,
      selectedColor: const Color(0xFF1E40AF),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary),
      checkmarkColor: Colors.white,
      onSelected: (_) => setState(() => _statusFilter = value),
    );
  }

  Widget _buildLiveKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color, letterSpacing: -0.3)),
                  Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TAB 3: STUDENT DIRECTORY (With Multi-Campus Institutions & Year Filters)
// ============================================================

class _AdminStudentsTab extends ConsumerStatefulWidget {
  const _AdminStudentsTab();

  @override
  ConsumerState<_AdminStudentsTab> createState() => _AdminStudentsTabState();
}

class _AdminStudentsTabState extends ConsumerState<_AdminStudentsTab> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _institutionOptions = [
    'All',
    'Matriculation School',
    'CBSE School',
    'Engineering',
    'Arts & Science',
    'Pharmacy',
    'Polytechnic',
    'Nursing',
    'Management',
  ];

  final List<String> _yearOptions = [
    'All',
    'Class 10',
    'Class 12',
    'High School',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditStudentSheet([Map<String, dynamic>? student]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StudentFormSheet(
        student: student,
        onSuccess: () {
          ref.invalidate(adminStudentsProvider);
          ref.invalidate(adminDashboardProvider);
        },
      ),
    );
  }

  void _showBulkUploadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BulkUploadSheet(
        onSuccess: () {
          ref.invalidate(adminStudentsProvider);
          ref.invalidate(adminDashboardProvider);
        },
      ),
    );
  }

  void _showBulkRollUpdateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BulkRollUpdateSheet(
        onSuccess: () {
          ref.invalidate(adminStudentsProvider);
          ref.invalidate(adminDashboardProvider);
        },
      ),
    );
  }

  void _showStudentQrModal(Map<String, dynamic> student) {
    final name = student['name'] ?? 'Student';
    final roll = student['roll_number'] ?? student['rollNumber'] ?? '';
    final dept = student['department'] ?? 'General';
    final qrData = student['qr_code'] ?? student['qrCode'] ?? 'QR-$roll';
    final bus = student['bus_number'] ?? student['busNumber'] ?? 'Bus';
    final stop = student['stage_name'] ?? student['stageName'] ?? 'Stop';

    bool isGeneratingPdf = false;
    bool isGeneratingImage = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge_rounded, color: Color(0xFF1E40AF), size: 22),
                          SizedBox(width: 8),
                          Text('Student QR Pass', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
                    ),
                    child: QrImageView(
                      data: qrData.toString(),
                      version: QrVersions.auto,
                      size: 170.0,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E40AF)),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1E3A8A)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary), textAlign: TextAlign.center),
                  Text('$roll • $dept', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  Text('Bus: $bus • Stop: $stop', style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),

                  // 1. Primary Action: Download / Print Exact QR Code Only (Clean / Sticker)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isGeneratingPdf
                          ? null
                          : () async {
                              setModalState(() => isGeneratingPdf = true);
                              try {
                                await PdfReportService.printExactQrOnly(student: student);
                              } catch (e) {
                                if (mounted) {
                                  AppSnackBar.showError(context, 'Failed to generate QR: $e');
                                }
                              } finally {
                                if (dialogCtx.mounted) {
                                  setModalState(() => isGeneratingPdf = false);
                                }
                              }
                            },
                      icon: isGeneratingPdf
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.qr_code_2_rounded, size: 20),
                      label: Text(isGeneratingPdf ? 'Generating...' : 'Download / Print QR Code Only'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 2. Action Row: Save Pure QR Image (PNG) & Full ID Card Pass (PDF)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isGeneratingImage
                              ? null
                              : () async {
                                  setModalState(() => isGeneratingImage = true);
                                  try {
                                    await PdfReportService.shareExactQrImage(student: student);
                                  } catch (e) {
                                    if (mounted) {
                                      AppSnackBar.showError(context, 'Failed to export QR image: $e');
                                    }
                                  } finally {
                                    if (dialogCtx.mounted) {
                                      setModalState(() => isGeneratingImage = false);
                                    }
                                  }
                                },
                          icon: isGeneratingImage
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E40AF)))
                              : const Icon(Icons.image_rounded, size: 16),
                          label: Text(isGeneratingImage ? 'Exporting...' : 'Save QR Image (PNG)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E40AF),
                            side: const BorderSide(color: Color(0xFFDBEAFE)),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isGeneratingPdf
                              ? null
                              : () async {
                                  setModalState(() => isGeneratingPdf = true);
                                  try {
                                    await PdfReportService.printStudentQrPass(student: student);
                                  } catch (e) {
                                    if (mounted) {
                                      AppSnackBar.showError(context, 'Failed to generate ID pass: $e');
                                    }
                                  } finally {
                                    if (dialogCtx.mounted) {
                                      setModalState(() => isGeneratingPdf = false);
                                    }
                                  }
                                },
                          icon: const Icon(Icons.badge_rounded, size: 16),
                          label: const Text('Full ID Pass (PDF)', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E40AF),
                            side: const BorderSide(color: Color(0xFFDBEAFE)),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 3. Copy QR Text
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: qrData.toString()));
                        AppSnackBar.showSuccess(context, 'QR code text ($qrData) copied!');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('Copy QR Text / Roll No', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showStudentOptions(Map<String, dynamic> student) {
    final name = student['name'] ?? 'Student';
    final roll = student['roll_number'] ?? student['rollNumber'] ?? '';
    final studentId = student['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.school_rounded, color: Color(0xFF1E40AF), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                      Text('Roll No: $roll', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1E40AF)),
              title: const Text('View & Show Student QR Pass', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Display digital QR ID to scan on incharge phone', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showStudentQrModal(student);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF1E40AF)),
              title: const Text('Edit Student & Bus Assignment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Change Name, Dept, Bus, Route or Stop', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditStudentSheet(student);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
              title: const Text('Delete Student', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.danger)),
              subtitle: const Text('Permanently remove student and login access', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Confirm Deletion'),
                    content: Text('Are you sure you want to delete student "$name" ($roll)?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  try {
                    final api = ref.read(apiClientProvider);
                    await api.deleteAdminStudent(studentId);
                    if (mounted) {
                      AppSnackBar.showSuccess(context, 'Student deleted successfully');
                      ref.invalidate(adminStudentsProvider);
                      ref.invalidate(adminDashboardProvider);
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.showError(context, 'Failed to delete student: $e');
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(adminStudentsProvider);
    final search = ref.watch(adminStudentsFilterProvider);
    final selectedInst = ref.watch(adminInstitutionFilterProvider);
    final selectedYear = ref.watch(adminYearFilterProvider);

    return RefreshIndicator(
      color: AppTheme.primaryAccent,
      onRefresh: () async => ref.invalidate(adminStudentsProvider),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Header Banner
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const FeatureIconBadge(
                      icon: Icons.school_rounded,
                      color: Color(0xFF1E40AF),
                      size: 38,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Student Directory & Pass Governance',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary),
                          ),
                          studentsAsync.when(
                            data: (list) => Text(
                              'Total registered students: ${list.length}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            loading: () => const Text('Loading students...', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            error: (_, __) => const Text('Student records', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryAccent),
                      tooltip: 'Refresh Students',
                      onPressed: () {
                        ref.invalidate(adminStudentsProvider);
                        AppSnackBar.showInfo(context, 'Student directory refreshed');
                      },
                    ),
                  ],
                ),
              ),

              // Search, Actions & Filter Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ID Card Scanner Module Hero Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withOpacity(0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/admin/bus-student-scanner'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'ID Card Scanner Module',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                                          ),
                                          SizedBox(width: 6),
                                          Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 16),
                                        ],
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Choose bus & scan barcode / ID text to add students',
                                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Open',
                                        style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.w800, fontSize: 11.5),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF1E3A8A), size: 11),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Action Buttons Row: Add Student & Bulk Upload
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddEditStudentSheet(),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text('Add Student'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E40AF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showBulkUploadSheet,
                            icon: const Icon(Icons.upload_file_rounded, size: 16, color: Color(0xFF1E40AF)),
                            label: const Text('Bulk Add', style: TextStyle(color: Color(0xFF1E40AF), fontWeight: FontWeight.w700, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1E40AF), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _showBulkRollUpdateSheet,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.auto_fix_high_rounded, size: 16, color: Color(0xFF1D4ED8)),
                                SizedBox(width: 4),
                                Text('Roll Nos', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w800, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search Field
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => ref.read(adminStudentsFilterProvider.notifier).state = val.trim().toLowerCase(),
                      decoration: InputDecoration(
                        hintText: 'Search student by Name, Roll No, Email or Dept...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                        suffixIcon: search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(adminStudentsFilterProvider.notifier).state = '';
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Institution Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _institutionOptions.map((inst) {
                          final isSelected = selectedInst == inst;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(inst, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, color: isSelected ? Colors.white : AppTheme.textPrimary)),
                              selected: isSelected,
                              selectedColor: const Color(0xFF1E40AF),
                              backgroundColor: const Color(0xFFF1F5F9),
                              checkmarkColor: Colors.white,
                              onSelected: (_) => ref.read(adminInstitutionFilterProvider.notifier).state = inst,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Year Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _yearOptions.map((yr) {
                          final isSelected = selectedYear == yr;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(yr, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, color: isSelected ? Colors.white : AppTheme.textPrimary)),
                              selected: isSelected,
                              selectedColor: AppTheme.secondary,
                              backgroundColor: const Color(0xFFF1F5F9),
                              checkmarkColor: Colors.white,
                              onSelected: (_) => ref.read(adminYearFilterProvider.notifier).state = yr,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Student List
              Expanded(
                child: studentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                  error: (e, _) => Center(child: Text('Error loading students: $e')),
                  data: (students) {
                    final filtered = students.where((s) {
                      final name = (s['name'] ?? '').toString().toLowerCase();
                      final roll = (s['roll_number'] ?? s['rollNumber'] ?? '').toString().toLowerCase();
                      final dept = (s['department'] ?? '').toString().toLowerCase();
                      final email = (s['email'] ?? '').toString().toLowerCase();
                      final phone = (s['phone'] ?? '').toString().toLowerCase();
                      final inst = (s['institution_type'] ?? s['institutionType'] ?? 'Engineering').toString();
                      final year = (s['year_of_study'] ?? s['yearOfStudy'] ?? '1st Year').toString();

                      final matchesSearch = search.isEmpty ||
                          name.contains(search) ||
                          roll.contains(search) ||
                          dept.contains(search) ||
                          email.contains(search) ||
                          phone.contains(search);

                      final matchesInst = selectedInst == 'All' || inst.toLowerCase() == selectedInst.toLowerCase();
                      final matchesYear = selectedYear == 'All' || year.toLowerCase() == selectedYear.toLowerCase();

                      return matchesSearch && matchesInst && matchesYear;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('No students match criteria', style: TextStyle(color: AppTheme.textSecondary)),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        final name = s['name'] ?? 'Student';
                        final roll = s['roll_number'] ?? s['rollNumber'] ?? '';
                        final dept = s['department'] ?? 'General';
                        final inst = s['institution_type'] ?? s['institutionType'] ?? 'Engineering';
                        final yr = s['year_of_study'] ?? s['yearOfStudy'] ?? '1st Year';
                        final route = s['route_name'] ?? s['routeName'] ?? 'Not Assigned';
                        final stage = s['stage_name'] ?? s['stageName'] ?? 'Default Stop';
                        final rate = double.tryParse(s['attendance_percentage']?.toString() ?? '95') ?? 95.0;

                        return InkWell(
                          onTap: () => _showStudentOptions(s),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: rate >= 75 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${rate.toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: rate >= 75 ? AppTheme.success : AppTheme.danger,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$roll • $dept',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: [
                                          _Badge(text: inst, color: const Color(0xFF1E40AF)),
                                          _Badge(text: yr, color: const Color(0xFF0D9488)),
                                          _Badge(text: '$route ($stage)', color: const Color(0xFF475569)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1E40AF), size: 22),
                                  tooltip: 'View QR Code',
                                  onPressed: () => _showStudentQrModal(s),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STUDENT ADD / EDIT MODAL SHEET
// ============================================================

class _StudentFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? student;
  final VoidCallback onSuccess;

  const _StudentFormSheet({this.student, required this.onSuccess});

  @override
  ConsumerState<_StudentFormSheet> createState() => _StudentFormSheetState();
}

class _StudentFormSheetState extends ConsumerState<_StudentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _rollCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _parentPhoneCtrl;

  late String _institution;
  late String _yearOfStudy;
  String? _selectedBusId;
  String? _selectedRouteId;
  String? _selectedStageId;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl = TextEditingController(text: s?['name'] ?? '');
    _rollCtrl = TextEditingController(text: s?['roll_number'] ?? s?['rollNumber'] ?? '');
    _deptCtrl = TextEditingController(text: s?['department'] ?? 'Computer Science');
    _phoneCtrl = TextEditingController(text: s?['phone'] ?? '');
    _parentPhoneCtrl = TextEditingController(text: s?['parent_phone'] ?? s?['parentPhone'] ?? '');

    _institution = s?['institution_type'] ?? s?['institutionType'] ?? 'Engineering';
    _yearOfStudy = s?['year_of_study'] ?? s?['yearOfStudy'] ?? '1st Year';
    _selectedBusId = s?['assigned_bus_id'] ?? s?['assignedBusId'];
    _selectedRouteId = s?['assigned_route_id'] ?? s?['assignedRouteId'];
    _selectedStageId = s?['assigned_stage_id'] ?? s?['assignedStageId'];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollCtrl.dispose();
    _deptCtrl.dispose();
    _phoneCtrl.dispose();
    _parentPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.student != null;
    final routesAsync = ref.watch(adminRoutesProvider);
    final busesAsync = ref.watch(adminBusesProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FeatureIconBadge(
                    icon: isEdit ? Icons.edit_note_rounded : Icons.person_add_rounded,
                    color: const Color(0xFF1E40AF),
                    size: 36,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Student & Transport' : 'Add New Student',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Student Full Name *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              // Roll Number
              TextFormField(
                controller: _rollCtrl,
                enabled: !isEdit,
                decoration: InputDecoration(
                  labelText: 'Roll Number / Registration No *',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                  filled: isEdit,
                  fillColor: isEdit ? const Color(0xFFF1F5F9) : null,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Roll number is required' : null,
              ),
              const SizedBox(height: 12),

              // Institution & Year Dropdowns Row
              Builder(
                builder: (context) {
                  final instList = [
                    'Vellalar college for women',
                    'Vellalar college of education',
                    'Vellalar college of engineering and technology',
                    'Vellalar college of nursing',
                    'Vellalar college of pharmacy',
                    'Vellalar physiotherapy college',
                    'Vellalar vidyalaya senior secondary school',
                    'VET institute of arts and science',
                  ];
                  if (!instList.contains(_institution)) {
                    instList.insert(0, _institution);
                  }
                  final yearList = [
                    'Class 10',
                    'Class 12',
                    'Class 11',
                    'Class 9',
                    'Class 8',
                    'Class 6-7',
                    'Class 1-5',
                    '1st Year',
                    '2nd Year',
                    '3rd Year',
                    '4th Year',
                  ];
                  if (!yearList.contains(_yearOfStudy)) {
                    yearList.insert(0, _yearOfStudy);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _institution,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Institution / School *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            isDense: true,
                          ),
                          items: instList.map((inst) => DropdownMenuItem(
                            value: inst,
                            child: Text(inst, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          )).toList(),
                          onChanged: (val) => setState(() => _institution = val ?? 'Engineering'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _yearOfStudy,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Class / Year *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            isDense: true,
                          ),
                          items: yearList.map((yr) => DropdownMenuItem(
                            value: yr,
                            child: Text(yr, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          )).toList(),
                          onChanged: (val) => setState(() => _yearOfStudy = val ?? '1st Year'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Department / Section
              TextFormField(
                controller: _deptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Section / Stream / Dept (e.g. Section A, Bio-Maths, CSE)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Phone & Parent Phone
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _parentPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Parent Phone (Alerts)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Student Phone (Opt)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'Bus & Route Transport Assignment',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E40AF)),
              ),
              const SizedBox(height: 10),

              // Bus Selector
              busesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (buses) {
                  final busMap = <String, String>{};
                  for (final b in buses) {
                    final id = b['id']?.toString() ?? '';
                    if (id.isNotEmpty) {
                      busMap[id] = b['bus_number'] ?? 'Bus';
                    }
                  }
                  final validBusId = busMap.containsKey(_selectedBusId) ? _selectedBusId : null;
                  return DropdownButtonFormField<String>(
                    value: validBusId,
                    isExpanded: true,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Bus',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                    hint: const Text('Select Bus'),
                    items: busMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setState(() => _selectedBusId = val),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Route Selector
              routesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (routes) {
                  final routeMap = <String, String>{};
                  for (final r in routes) {
                    final id = r['id']?.toString() ?? '';
                    if (id.isNotEmpty) {
                      routeMap[id] = r['route_name'] ?? 'Route';
                    }
                  }
                  final validRouteId = routeMap.containsKey(_selectedRouteId) ? _selectedRouteId : null;
                  final activeRoute = routes.firstWhere(
                    (r) => r['id']?.toString() == validRouteId,
                    orElse: () => <String, dynamic>{},
                  );
                  final stages = activeRoute['stages'] is List ? (activeRoute['stages'] as List) : [];
                  final stageMap = <String, String>{};
                  for (final st in stages) {
                    if (st is! Map) continue;
                    final sMap = Map<String, dynamic>.from(st);
                    final sId = sMap['id']?.toString() ?? '';
                    if (sId.isNotEmpty) {
                      stageMap[sId] = sMap['stage_name'] ?? 'Stop';
                    }
                  }
                  final validStageId = stageMap.containsKey(_selectedStageId) ? _selectedStageId : null;

                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: validRouteId,
                        isExpanded: true,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Route',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                        hint: const Text('Select Route'),
                        items: routeMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() {
                          _selectedRouteId = val;
                          _selectedStageId = null;
                        }),
                      ),
                      if (stageMap.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: validStageId,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Boarding Stage / Stop',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                          hint: const Text('Select Boarding Stop'),
                          items: stageMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() => _selectedStageId = val),
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _isSaving = true);
                          try {
                            final api = ref.read(apiClientProvider);
                            final payload = {
                              'name': _nameCtrl.text.trim(),
                              'rollNumber': _rollCtrl.text.trim(),
                              'department': _deptCtrl.text.trim(),
                              'className': _yearOfStudy,
                              'institutionType': _institution,
                              'yearOfStudy': _yearOfStudy,
                              'phone': _phoneCtrl.text.trim(),
                              'parentPhone': _parentPhoneCtrl.text.trim(),
                              'assignedBusId': _selectedBusId,
                              'assignedRouteId': _selectedRouteId,
                              'assignedStageId': _selectedStageId,
                            };

                            if (isEdit) {
                              final id = widget.student!['id'].toString();
                              await api.updateAdminStudent(id, payload);
                              if (context.mounted) {
                                AppSnackBar.showSuccess(context, 'Student updated successfully!');
                              }
                            } else {
                              await api.createAdminStudent(payload);
                              if (context.mounted) {
                                AppSnackBar.showSuccess(context, 'Student created and assigned successfully!');
                              }
                            }

                            widget.onSuccess();
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              AppSnackBar.showError(context, 'Operation failed: $e');
                            }
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Save Changes' : 'Create & Assign Student', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BULK STUDENT UPLOAD MODAL SHEET
// ============================================================

class _BulkUploadSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _BulkUploadSheet({required this.onSuccess});

  @override
  ConsumerState<_BulkUploadSheet> createState() => _BulkUploadSheetState();
}

class _BulkUploadSheetState extends ConsumerState<_BulkUploadSheet> {
  final TextEditingController _csvCtrl = TextEditingController();
  String? _batchBusId;
  String? _batchRouteId;
  bool _isUploading = false;

  void _loadSampleTemplate() {
    _csvCtrl.text = '''CS2024101, Harish Raman, Computer Science, Engineering, 1st Year, 9876543210
SCH2024-101, Priya Sundaram, Section A, Velalar Matriculation School, Class 10, 9876543211
CBSE2024-50, K. Rahul, Bio-Maths, Velalar Vidyalaya (CBSE), Class 12, 9876543212
AS2024104, Kavitha M, Commerce, Arts & Science, 2nd Year, 9876543213
SCH2024-102, Arvind Raj, Section B, Velalar Matriculation School, Class 8, 9876543214''';
    setState(() {});
  }

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(adminRoutesProvider);
    final busesAsync = ref.watch(adminBusesProvider);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 18,
          left: 18,
          right: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const FeatureIconBadge(
                    icon: Icons.cloud_upload_rounded,
                    color: Color(0xFF1E40AF),
                    size: 36,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bulk Student Onboarding', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                        Text('Upload multiple students with auto route & bus assignment', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Format: RollNo, Name, Dept, Inst, Year, Phone',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _loadSampleTemplate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.playlist_add_rounded, size: 14, color: Color(0xFF1E40AF)),
                          SizedBox(width: 4),
                          Text('Load Sample', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _csvCtrl,
                minLines: 3,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Paste CSV or text rows here...\nExample:\nCS2024101, Harish R, CSE, Engineering, 1st Year, 9876543210',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Optional Batch Bus & Route Assignment
              const Text('Default Transport Assignment for Batch:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: busesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (buses) {
                        final busMap = <String, String>{};
                        for (final b in buses) {
                          final id = b['id']?.toString() ?? '';
                          if (id.isNotEmpty) busMap[id] = b['bus_number'] ?? 'Bus';
                        }
                        final validBusId = busMap.containsKey(_batchBusId) ? _batchBusId : null;
                        return DropdownButtonFormField<String>(
                          value: validBusId,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Default Bus',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            isDense: true,
                          ),
                          hint: const Text('Select Bus', style: TextStyle(fontSize: 12)),
                          items: busMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (val) => setState(() => _batchBusId = val),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: routesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (routes) {
                        final routeMap = <String, String>{};
                        for (final r in routes) {
                          final id = r['id']?.toString() ?? '';
                          if (id.isNotEmpty) routeMap[id] = r['route_name'] ?? 'Route';
                        }
                        final validRouteId = routeMap.containsKey(_batchRouteId) ? _batchRouteId : null;
                        return DropdownButtonFormField<String>(
                          value: validRouteId,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Default Route',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            isDense: true,
                          ),
                          hint: const Text('Select Route', style: TextStyle(fontSize: 12)),
                          items: routeMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (val) => setState(() => _batchRouteId = val),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isUploading
                    ? null
                    : () async {
                        final text = _csvCtrl.text.trim();
                        if (text.isEmpty) {
                          AppSnackBar.showError(context, 'Please enter or load student data');
                          return;
                        }

                        final lines = text.split('\n');
                        final List<Map<String, dynamic>> studentsList = [];

                        for (final line in lines) {
                          final trimmed = line.trim();
                          if (trimmed.isEmpty) continue;
                          final parts = trimmed.split(',').map((p) => p.trim()).toList();
                          if (parts.isNotEmpty) {
                            studentsList.add({
                              'rollNumber': parts[0],
                              'name': parts.length > 1 ? parts[1] : parts[0],
                              'department': parts.length > 2 ? parts[2] : 'General',
                              'institutionType': parts.length > 3 ? parts[3] : 'Engineering',
                              'yearOfStudy': parts.length > 4 ? parts[4] : '1st Year',
                              'phone': parts.length > 5 ? parts[5] : null,
                              'assignedBusId': _batchBusId,
                              'assignedRouteId': _batchRouteId,
                            });
                          }
                        }

                        if (studentsList.isEmpty) {
                          AppSnackBar.showError(context, 'No valid student rows found');
                          return;
                        }

                        setState(() => _isUploading = true);
                        try {
                          final api = ref.read(apiClientProvider);
                          final res = await api.bulkUploadAdminStudents(studentsList);
                          final count = res.data['data']?['count'] ?? studentsList.length;
                          if (context.mounted) {
                            AppSnackBar.showSuccess(context, 'Successfully uploaded & assigned $count students!');
                          }
                          widget.onSuccess();
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            AppSnackBar.showError(context, 'Bulk upload failed: $e');
                          }
                        } finally {
                          if (mounted) setState(() => _isUploading = false);
                        }
                      },
                icon: _isUploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_isUploading ? 'Uploading & Processing...' : 'Process & Upload Batch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

// ============================================================
// BULK ROLL NUMBER UPDATE BY NAME MODAL SHEET
// ============================================================

class _BulkRollUpdateSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _BulkRollUpdateSheet({required this.onSuccess});

  @override
  ConsumerState<_BulkRollUpdateSheet> createState() => _BulkRollUpdateSheetState();
}

class _BulkRollUpdateSheetState extends ConsumerState<_BulkRollUpdateSheet> {
  final TextEditingController _csvCtrl = TextEditingController();
  bool _isUploading = false;
  Map<String, dynamic>? _result;

  void _loadSampleTemplate() {
    _csvCtrl.text = '''Harish Raman, 21CS101, Computer Science
Priya Sundaram, SCH2024-101, Section A
K. Rahul, CBSE2024-50, Bio-Maths
Kavitha M, AS2024104, Commerce''';
    setState(() {});
  }

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 18,
          left: 18,
          right: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const FeatureIconBadge(
                    icon: Icons.auto_fix_high_rounded,
                    color: Color(0xFF1D4ED8),
                    size: 36,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Match Name & Update Roll Nos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                        Text('Auto-match student name & update roll number', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_result == null) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Format: Student Name, New Roll No, Dept (optional)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _loadSampleTemplate,
                      icon: const Icon(Icons.description_outlined, size: 14),
                      label: const Text('Sample Template', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _csvCtrl,
                  maxLines: 7,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'Paste CSV or text rows here...\nExample:\nArun Kumar, 21CS001, CSE\nPriya S, 21EC002, ECE',
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : () async {
                            final raw = _csvCtrl.text.trim();
                            if (raw.isEmpty) {
                              AppSnackBar.showError(context, 'Please paste or enter student records to update');
                              return;
                            }

                            final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
                            final List<Map<String, dynamic>> updates = [];

                            for (final line in lines) {
                              final parts = line.split(',').map((p) => p.trim()).toList();
                              if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
                                updates.add({
                                  'name': parts[0],
                                  'newRollNumber': parts[1],
                                  'rollNumber': parts[1],
                                  'department': parts.length > 2 ? parts[2] : '',
                                });
                              }
                            }

                            if (updates.isEmpty) {
                              AppSnackBar.showError(context, 'No valid rows found. Each line must have: Name, New Roll Number');
                              return;
                            }

                            setState(() => _isUploading = true);
                            try {
                              final api = ref.read(apiClientProvider);
                              final res = await api.bulkUpdateRollNumbersByName(updates);
                              final data = res.data['data'] as Map<String, dynamic>?;
                              if (mounted) {
                                setState(() {
                                  _result = data;
                                });
                                AppSnackBar.showSuccess(context, 'Updated ${data?['updatedCount'] ?? 0} students successfully!');
                              }
                              widget.onSuccess();
                            } catch (e) {
                              if (mounted) {
                                AppSnackBar.showError(context, 'Roll number update failed: $e');
                              }
                            } finally {
                              if (mounted) setState(() => _isUploading = false);
                            }
                          },
                    icon: _isUploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.auto_fix_high_rounded),
                    label: Text(_isUploading ? 'Matching & Updating...' : 'Match & Update Roll Numbers'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ] else ...[
                // Results Breakdown View
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('${_result?['updatedCount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF065F46))),
                          const Text('Updated', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF047857))),
                        ],
                      ),
                      Column(
                        children: [
                          Text('${_result?['unmatchedCount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF991B1B))),
                          const Text('Not Found', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
                        ],
                      ),
                      Column(
                        children: [
                          Text('${_result?['ambiguousCount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF92400E))),
                          const Text('Duplicates', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAB 4: ROUTES & BUSES
// ============================================================

class _AdminRoutesBusesTab extends ConsumerStatefulWidget {
  const _AdminRoutesBusesTab();

  @override
  ConsumerState<_AdminRoutesBusesTab> createState() => _AdminRoutesBusesTabState();
}

class _AdminRoutesBusesTabState extends ConsumerState<_AdminRoutesBusesTab> {
  int _viewMode = 0; // 0 = Routes, 1 = Buses Fleet, 2 = Incharges & Crew, 3 = Colleges & Inst, 4 = Daily Trips, 5 = User Accounts

  final TextEditingController _routesSearchCtrl = TextEditingController();
  String _routesFilter = 'All';

  final TextEditingController _busesSearchCtrl = TextEditingController();
  String _busesFilter = 'All';

  final TextEditingController _inchargesSearchCtrl = TextEditingController();
  String _inchargesFilter = 'All';

  final TextEditingController _institutionsSearchCtrl = TextEditingController();
  String _institutionsFilter = 'All';

  final TextEditingController _tripsSearchCtrl = TextEditingController();
  String _tripsFilter = 'All';

  final TextEditingController _usersSearchCtrl = TextEditingController();
  String _usersFilter = 'All';

  @override
  void dispose() {
    _routesSearchCtrl.dispose();
    _busesSearchCtrl.dispose();
    _inchargesSearchCtrl.dispose();
    _institutionsSearchCtrl.dispose();
    _tripsSearchCtrl.dispose();
    _usersSearchCtrl.dispose();
    super.dispose();
  }

  void _showRouteOptionsSheet(Map<String, dynamic> route) {
    final name = route['route_name'] ?? 'Route';
    final code = route['route_code'] ?? '';
    final routeId = route['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.alt_route_rounded, color: Color(0xFF1E40AF), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                      if (code.isNotEmpty) Text('Code: $code', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF1E40AF)),
              title: const Text('Add Stop Stage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Add a new pickup/drop stop with GPS coordinates', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditStageDialog(routeId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF1E40AF)),
              title: const Text('Edit Route Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Change name, code, start & destination points', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditRouteDialog(route: route);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
              title: const Text('Delete Route', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.danger)),
              subtitle: const Text('Permanently remove route and associated stop stages', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Confirm Route Deletion'),
                    content: Text('Are you sure you want to delete route "$name"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  try {
                    final api = ref.read(apiClientProvider);
                    await api.deleteAdminRoute(routeId);
                    if (mounted) {
                      AppSnackBar.showSuccess(context, 'Route deleted successfully');
                      ref.invalidate(adminRoutesProvider);
                      ref.invalidate(adminDashboardProvider);
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.showError(context, 'Failed to delete route: $e');
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditRouteDialog({Map<String, dynamic>? route}) {
    final isEdit = route != null;
    final nameCtrl = TextEditingController(text: route?['route_name'] ?? '');
    final codeCtrl = TextEditingController(text: route?['route_code'] ?? '');
    final descCtrl = TextEditingController(text: route?['description'] ?? '');
    final startCtrl = TextEditingController(text: route?['start_point'] ?? '');
    final endCtrl = TextEditingController(text: route?['end_point'] ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.alt_route_rounded, color: Color(0xFF1E40AF), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Route' : 'Create Transit Route',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            Text(
                              isEdit ? 'Update route parameters & stops' : 'Define new college transit corridor',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Route Name *', hintText: 'e.g. Route 1 - Gandhipuram Express', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Route name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(labelText: 'Route Code', hintText: 'e.g. R-01', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: startCtrl,
                          decoration: const InputDecoration(labelText: 'Start Location', hintText: 'e.g. Gandhipuram', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: endCtrl,
                    decoration: const InputDecoration(labelText: 'Destination / End Point', hintText: 'e.g. VET Main Campus', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description / Notes', hintText: 'e.g. Morning pickup via Avinashi Road', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => isSaving = true);
                              try {
                                final api = ref.read(apiClientProvider);
                                final payload = {
                                  'routeName': nameCtrl.text.trim(),
                                  'routeCode': codeCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'startPoint': startCtrl.text.trim(),
                                  'endPoint': endCtrl.text.trim(),
                                };
                                if (isEdit) {
                                  await api.updateAdminRoute(route['id'].toString(), payload);
                                  if (mounted) AppSnackBar.showSuccess(context, 'Route updated successfully!');
                                } else {
                                  await api.createAdminRoute(payload);
                                  if (mounted) AppSnackBar.showSuccess(context, 'Route created successfully!');
                                }
                                ref.invalidate(adminRoutesProvider);
                                ref.invalidate(adminDashboardProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (mounted) AppSnackBar.showError(context, 'Operation failed: $e');
                              } finally {
                                setSheetState(() => isSaving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'Save Changes' : 'Create Route', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showStageOptionsSheet(String routeId, Map<String, dynamic> stage) {
    final stageName = stage['stage_name'] ?? 'Stop Stage';
    final seq = stage['sequence_order']?.toString() ?? '1';
    final stageId = stage['id']?.toString() ?? '';
    final lat = stage['latitude']?.toString() ?? '0.0';
    final lon = stage['longitude']?.toString() ?? '0.0';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.pin_drop_rounded, color: Color(0xFF1E40AF), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stageName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                      Text('Stop #$seq • GPS: $lat, $lon', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_location_alt_rounded, color: Color(0xFF1E40AF)),
              title: const Text('Edit Stop Stage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Change stop name, sequence or GPS coordinates', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditStageDialog(routeId, stage: stage);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
              title: const Text('Delete Stop Stage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.danger)),
              subtitle: const Text('Permanently remove this stop from route', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Confirm Stage Deletion'),
                    content: Text('Are you sure you want to delete stop "$stageName"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  try {
                    final api = ref.read(apiClientProvider);
                    await api.deleteAdminStage(stageId);
                    if (mounted) {
                      AppSnackBar.showSuccess(context, 'Stop stage deleted successfully');
                      ref.invalidate(adminRoutesProvider);
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.showError(context, 'Failed to delete stop: $e');
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditStageDialog(String routeId, {Map<String, dynamic>? stage}) {
    final isEdit = stage != null;
    final nameCtrl = TextEditingController(text: stage?['stage_name'] ?? '');
    final seqCtrl = TextEditingController(text: (stage?['sequence_order'] ?? '1').toString());
    final latCtrl = TextEditingController(text: stage?['latitude']?.toString() ?? '11.0168');
    final lonCtrl = TextEditingController(text: stage?['longitude']?.toString() ?? '76.9558');
    final radiusCtrl = TextEditingController(text: (stage?['allowed_radius_meters'] ?? '200').toString());
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool isFetchingLocation = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF1E40AF), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Stop Stage' : 'Add Stop Stage',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            Text(
                              isEdit ? 'Update stop name & coordinates' : 'Configure stage name & GPS geofence',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Stage / Stop Name *', hintText: 'e.g. Hope College', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Stage name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: seqCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Order # *', hintText: '1, 2, 3...', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: radiusCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Radius (m)', hintText: '200', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: latCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Latitude', hintText: '11.0168', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: lonCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Longitude', hintText: '76.9558', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isFetchingLocation
                        ? null
                        : () async {
                            setSheetState(() => isFetchingLocation = true);
                            try {
                              LocationPermission perm = await Geolocator.checkPermission();
                              if (perm == LocationPermission.denied) {
                                perm = await Geolocator.requestPermission();
                              }
                              if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
                                final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                                latCtrl.text = pos.latitude.toStringAsFixed(6);
                                lonCtrl.text = pos.longitude.toStringAsFixed(6);
                                if (mounted) AppSnackBar.showSuccess(context, 'Acquired current GPS coordinates!');
                              } else {
                                if (mounted) AppSnackBar.showError(context, 'Location permission denied');
                              }
                            } catch (e) {
                              if (mounted) AppSnackBar.showError(context, 'Failed to fetch GPS: $e');
                            } finally {
                              setSheetState(() => isFetchingLocation = false);
                            }
                          },
                    icon: isFetchingLocation
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded, size: 16),
                    label: Text(isFetchingLocation ? 'Acquiring GPS...' : 'Autofill with Device GPS', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1E40AF)),
                      foregroundColor: const Color(0xFF1E40AF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => isSaving = true);
                              try {
                                final api = ref.read(apiClientProvider);
                                final payload = {
                                  'routeId': routeId,
                                  'stageName': nameCtrl.text.trim(),
                                  'sequenceOrder': int.tryParse(seqCtrl.text.trim()) ?? 1,
                                  'latitude': double.tryParse(latCtrl.text.trim()) ?? 11.0168,
                                  'longitude': double.tryParse(lonCtrl.text.trim()) ?? 76.9558,
                                  'allowedRadiusMeters': int.tryParse(radiusCtrl.text.trim()) ?? 200,
                                };
                                if (isEdit) {
                                  await api.updateAdminStage(stage['id'].toString(), payload);
                                  if (mounted) AppSnackBar.showSuccess(context, 'Stop stage updated successfully!');
                                } else {
                                  await api.createAdminStage(payload);
                                  if (mounted) AppSnackBar.showSuccess(context, 'Stop stage added successfully!');
                                }
                                ref.invalidate(adminRoutesProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (mounted) AppSnackBar.showError(context, 'Operation failed: $e');
                              } finally {
                                setSheetState(() => isSaving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'Save Changes' : 'Add Stop Stage', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBusOptionsSheet(Map<String, dynamic> bus) {
    final busNo = bus['bus_number'] ?? 'Bus';
    final reg = bus['registration_no'] ?? bus['registration_number'] ?? 'N/A';
    final busId = bus['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF1E40AF), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(busNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                      Text('Registration: $reg', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF1E40AF)),
              title: const Text('Edit Bus Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Change bus number, registration, capacity or model', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditBusDialog(bus: bus);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
              title: const Text('Delete Bus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.danger)),
              subtitle: const Text('Permanently remove bus from fleet', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Confirm Bus Deletion'),
                    content: Text('Are you sure you want to delete bus "$busNo"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  try {
                    final api = ref.read(apiClientProvider);
                    await api.deleteAdminBus(busId);
                    if (mounted) {
                      AppSnackBar.showSuccess(context, 'Bus removed from fleet successfully');
                      ref.invalidate(adminBusesProvider);
                      ref.invalidate(adminDashboardProvider);
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.showError(context, 'Failed to delete bus: $e');
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditBusDialog({Map<String, dynamic>? bus}) {
    final isEdit = bus != null;
    final busNoCtrl = TextEditingController(text: bus?['bus_number'] ?? '');
    final regCtrl = TextEditingController(text: bus?['registration_no'] ?? bus?['registration_number'] ?? '');
    final capCtrl = TextEditingController(text: (bus?['capacity'] ?? 50).toString());
    final makeCtrl = TextEditingController(text: bus?['make'] ?? '');
    final modelCtrl = TextEditingController(text: bus?['model'] ?? '');
    final yearCtrl = TextEditingController(text: (bus?['year'] ?? 2024).toString());
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF1E40AF), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Fleet Bus' : 'Add New Bus',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            Text(
                              isEdit ? 'Update bus number & specifications' : 'Register a new vehicle to campus fleet',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: busNoCtrl,
                          decoration: const InputDecoration(labelText: 'Bus Number *', hintText: 'e.g. BUS-01', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: regCtrl,
                          decoration: const InputDecoration(labelText: 'Registration No *', hintText: 'e.g. TN38AB1234', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: capCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Capacity (Seats) *', hintText: '50', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: yearCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Model Year', hintText: '2024', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: makeCtrl,
                          decoration: const InputDecoration(labelText: 'Make / Manufacturer', hintText: 'e.g. Ashok Leyland', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: modelCtrl,
                          decoration: const InputDecoration(labelText: 'Model', hintText: 'e.g. Viking', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => isSaving = true);
                              try {
                                final api = ref.read(apiClientProvider);
                                final payload = {
                                  'busNumber': busNoCtrl.text.trim(),
                                  'registrationNo': regCtrl.text.trim(),
                                  'capacity': int.tryParse(capCtrl.text.trim()) ?? 50,
                                  'make': makeCtrl.text.trim(),
                                  'model': modelCtrl.text.trim(),
                                  'year': int.tryParse(yearCtrl.text.trim()) ?? 2024,
                                };
                                if (isEdit) {
                                  await api.updateAdminBus(bus['id'].toString(), payload);
                                  if (mounted) AppSnackBar.showSuccess(context, 'Bus updated successfully!');
                                } else {
                                  await api.createAdminBus(payload);
                                  if (mounted) AppSnackBar.showSuccess(context, 'Bus added to fleet successfully!');
                                }
                                ref.invalidate(adminBusesProvider);
                                ref.invalidate(adminDashboardProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (mounted) AppSnackBar.showError(context, 'Operation failed: $e');
                              } finally {
                                setSheetState(() => isSaving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'Save Changes' : 'Add Vehicle to Fleet', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignBusDialog({String? preselectedRouteId, String? preselectedBusId, String? preselectedInchargeId}) {
    final routes = ref.read(adminRoutesProvider).value ?? [];
    final buses = ref.read(adminBusesProvider).value ?? [];
    final incharges = ref.read(adminInchargesProvider).value ?? [];

    final routeMap = <String, String>{};
    for (final r in routes) {
      final id = r['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        final name = r['route_name'] ?? 'Route';
        final code = r['route_code'] ?? '';
        routeMap[id] = '$name ${code.isNotEmpty ? "($code)" : ""}';
      }
    }

    final busMap = <String, String>{};
    for (final b in buses) {
      final id = b['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        final no = b['bus_number'] ?? 'Bus';
        final reg = b['registration_no'] ?? b['registration_number'] ?? '';
        final cap = b['capacity'] ?? 50;
        busMap[id] = '$no ${reg.isNotEmpty ? "($reg)" : ""} • $cap Seats';
      }
    }

    final inchargeMap = <String, String>{};
    for (final inc in incharges) {
      final id = inc['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        final name = inc['name'] ?? 'Incharge';
        final emp = inc['employee_id'] ?? '';
        final phone = inc['phone'] ?? '';
        inchargeMap[id] = '$name ${emp.isNotEmpty ? "[$emp]" : ""} ${phone.isNotEmpty ? "• $phone" : ""}';
      }
    }

    String? selectedRouteId = (preselectedRouteId != null && routeMap.containsKey(preselectedRouteId))
        ? preselectedRouteId
        : (routeMap.isNotEmpty ? routeMap.keys.first : null);
    String? selectedBusId = (preselectedBusId != null && busMap.containsKey(preselectedBusId))
        ? preselectedBusId
        : (busMap.isNotEmpty ? busMap.keys.first : null);
    String? selectedInchargeId = (preselectedInchargeId != null && inchargeMap.containsKey(preselectedInchargeId))
        ? preselectedInchargeId
        : (inchargeMap.isNotEmpty ? inchargeMap.keys.first : null);
    DateTime validFrom = DateTime.now();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.link_rounded, color: Color(0xFF1E40AF), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assign Bus to Route & Incharge',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                          Text('Link a vehicle and faculty crew lead to a transit route',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 14),

                // 1. Select Route
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: routeMap.containsKey(selectedRouteId) ? selectedRouteId : null,
                  decoration: const InputDecoration(
                    labelText: 'Transit Route *',
                    prefixIcon: Icon(Icons.alt_route_rounded, color: Color(0xFF1E40AF)),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select Route'),
                  items: routeMap.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis, maxLines: 1),
                  )).toList(),
                  onChanged: (val) => setSheetState(() => selectedRouteId = val),
                ),
                const SizedBox(height: 14),

                // 2. Select Bus
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: busMap.containsKey(selectedBusId) ? selectedBusId : null,
                  decoration: const InputDecoration(
                    labelText: 'Fleet Vehicle (Bus) *',
                    prefixIcon: Icon(Icons.directions_bus_rounded, color: Color(0xFF1E40AF)),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select Bus'),
                  items: busMap.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis, maxLines: 1),
                  )).toList(),
                  onChanged: (val) => setSheetState(() => selectedBusId = val),
                ),
                const SizedBox(height: 14),

                // 3. Select Incharge
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: inchargeMap.containsKey(selectedInchargeId) ? selectedInchargeId : null,
                  decoration: const InputDecoration(
                    labelText: 'Crew Lead (Bus Incharge / Staff) *',
                    prefixIcon: Icon(Icons.badge_rounded, color: Color(0xFF1E40AF)),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select Incharge'),
                  items: inchargeMap.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis, maxLines: 1),
                  )).toList(),
                  onChanged: (val) => setSheetState(() => selectedInchargeId = val),
                ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSaving || selectedRouteId == null || selectedBusId == null || selectedInchargeId == null
                        ? null
                        : () async {
                            setSheetState(() => isSaving = true);
                            try {
                              final api = ref.read(apiClientProvider);
                              await api.createAdminBusAssignment({
                                'busId': selectedBusId,
                                'routeId': selectedRouteId,
                                'inchargeId': selectedInchargeId,
                                'validFrom': validFrom.toIso8601String().split('T').first,
                              });
                              if (mounted) {
                                AppSnackBar.showSuccess(context, 'Bus assigned to route & incharge successfully!');
                              }
                              ref.invalidate(adminRoutesProvider);
                              ref.invalidate(adminBusesProvider);
                              ref.invalidate(adminInchargesProvider);
                              ref.invalidate(adminBusAssignmentsProvider);
                              ref.invalidate(adminDashboardProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (mounted) AppSnackBar.showError(context, 'Assignment failed: $e');
                            } finally {
                              setSheetState(() => isSaving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Confirm & Save Assignment', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddEditInchargeDialog({Map<String, dynamic>? incharge}) {
    final isEdit = incharge != null;
    final nameCtrl = TextEditingController(text: incharge?['name'] ?? '');
    final emailCtrl = TextEditingController(text: incharge?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: incharge?['phone'] ?? '');
    final empIdCtrl = TextEditingController(text: incharge?['employee_id'] ?? '');
    final deptCtrl = TextEditingController(text: incharge?['department'] ?? 'General');
    final passCtrl = TextEditingController(text: isEdit ? '' : 'Password123!');
    String institutionType = (incharge?['institution_type'] ?? 'Engineering').toString();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    final institutions = ref.read(adminInstitutionsProvider).value ?? [];

    final Map<String, String> instMap = {};
    if (institutions.isNotEmpty) {
      for (final inst in institutions) {
        final code = (inst['code'] ?? '').toString().trim();
        final name = (inst['name'] ?? '').toString().trim();
        final val = code.isNotEmpty ? code : (name.isNotEmpty ? name : 'Engineering');
        final label = name.isNotEmpty ? (code.isNotEmpty ? '$name ($code)' : name) : val;
        instMap[val] = label;
      }
    }
    if (instMap.isEmpty) {
      instMap['Engineering'] = 'Velalar College of Engineering';
      instMap['Arts & Science'] = 'Velalar Arts and Science';
      instMap['Pharmacy'] = 'Velalar College of Pharmacy';
      instMap['Nursing'] = 'Velalar College of Nursing';
      instMap['Polytechnic'] = 'Velalar Polytechnic College';
    }
    if (!instMap.containsKey(institutionType)) {
      if (institutionType.isNotEmpty) {
        instMap[institutionType] = institutionType;
      } else {
        institutionType = instMap.keys.first;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF1E40AF), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Incharge / Staff' : 'Add New Incharge',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            Text(
                              isEdit ? 'Update staff credentials & personal details' : 'Register faculty or staff as bus incharge',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'e.g. Prof. S. Kumar', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Email
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email Address *', hintText: 'e.g. incharge@tripmate.edu', border: OutlineInputBorder()),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Phone & Employee ID
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+91 9876543210', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: empIdCtrl,
                          decoration: const InputDecoration(labelText: 'Employee ID', hintText: 'EMP-01', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Institution Stream Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: instMap.containsKey(institutionType) ? institutionType : instMap.keys.first,
                    decoration: const InputDecoration(labelText: 'Institution / College *', border: OutlineInputBorder()),
                    items: instMap.entries.map((e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) => setSheetState(() => institutionType = val ?? instMap.keys.first),
                  ),
                  const SizedBox(height: 12),

                  // Department
                  TextFormField(
                    controller: deptCtrl,
                    decoration: const InputDecoration(labelText: 'Department', hintText: 'e.g. Computer Science, Mechanical', border: OutlineInputBorder()),
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Initial Password', hintText: 'Password123!', border: OutlineInputBorder()),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => isSaving = true);
                              try {
                                final api = ref.read(apiClientProvider);
                                final payload = {
                                  'name': nameCtrl.text.trim(),
                                  'email': emailCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                  'employeeId': empIdCtrl.text.trim(),
                                  'department': deptCtrl.text.trim(),
                                  'institutionType': institutionType,
                                  if (!isEdit && passCtrl.text.trim().isNotEmpty) 'password': passCtrl.text.trim(),
                                };
                                if (isEdit) {
                                  await api.updateAdminIncharge(incharge['id'].toString(), payload);
                                  if (mounted) AppSnackBar.showSuccess(context, 'Incharge updated successfully!');
                                } else {
                                  await api.createAdminIncharge(payload);
                                  if (mounted) AppSnackBar.showSuccess(context, 'Incharge created successfully!');
                                }
                                ref.invalidate(adminInchargesProvider);
                                ref.invalidate(adminDashboardProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (mounted) AppSnackBar.showError(context, 'Operation failed: $e');
                              } finally {
                                setSheetState(() => isSaving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'Save Incharge' : 'Create Incharge Account', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInchargeOptionsSheet(Map<String, dynamic> incharge) {
    final name = incharge['name'] ?? 'Incharge';
    final empId = incharge['employee_id'] ?? '';
    final id = incharge['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.badge_rounded, color: Color(0xFF1E40AF), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                      if (empId.isNotEmpty) Text('Employee ID: $empId', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Color(0xFF1E40AF)),
              title: const Text('Assign Bus & Route', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Assign or change operating bus and route for this incharge', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showAssignBusDialog(preselectedInchargeId: id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF1E40AF)),
              title: const Text('Edit Incharge Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Change name, phone, email, institution or department', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditInchargeDialog(incharge: incharge);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
              title: const Text('Deactivate Incharge', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.danger)),
              subtitle: const Text('Deactivate login access and remove bus assignments', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Confirm Deactivation'),
                    content: Text('Are you sure you want to deactivate incharge "$name"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Deactivate'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  try {
                    final api = ref.read(apiClientProvider);
                    await api.deleteAdminIncharge(id);
                    if (mounted) {
                      AppSnackBar.showSuccess(context, 'Incharge deactivated successfully');
                      ref.invalidate(adminInchargesProvider);
                      ref.invalidate(adminRoutesProvider);
                      ref.invalidate(adminBusesProvider);
                      ref.invalidate(adminDashboardProvider);
                    }
                  } catch (e) {
                    if (mounted) AppSnackBar.showError(context, 'Deactivation failed: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkInchargeUploadSheet() {
    final csvCtrl = TextEditingController();
    String? batchBusId;
    String? batchRouteId;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final routesAsync = ref.watch(adminRoutesProvider);
          final busesAsync = ref.watch(adminBusesProvider);

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 18,
                left: 18,
                right: 18,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const FeatureIconBadge(
                          icon: Icons.cloud_upload_rounded,
                          color: Color(0xFF1E40AF),
                          size: 36,
                          iconSize: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bulk Incharge Onboarding', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                              Text('Upload multiple staff/incharges with auto bus & route link', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Format: EmpID, Name, Email, Phone, Institution, Department',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            setSheetState(() {
                              csvCtrl.text = '''EMP101, Prof. S. Ramesh, ramesh@tripmate.edu, 9876543210, Engineering, Computer Science
EMP102, Dr. K. Priya, priya@tripmate.edu, 9876543211, Arts & Science, English
EMP103, M. Suresh, suresh@tripmate.edu, 9876543212, Pharmacy, Pharmacology
EMP104, A. Anitha, anitha@tripmate.edu, 9876543213, Polytechnic, Mechanical''';
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.playlist_add_rounded, size: 14, color: Color(0xFF1E40AF)),
                                SizedBox(width: 4),
                                Text('Load Sample', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: csvCtrl,
                      minLines: 3,
                      maxLines: 5,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      decoration: InputDecoration(
                        hintText: 'Paste CSV or text rows here...\nExample:\nEMP101, Prof. S. Ramesh, ramesh@tripmate.edu, 9876543210, Engineering, CSE',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Default Bus & Route (Optional):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: busesAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (buses) {
                              final busMap = <String, String>{};
                              for (final b in buses) {
                                final id = b['id']?.toString() ?? '';
                                if (id.isNotEmpty) busMap[id] = b['bus_number'] ?? 'Bus';
                              }
                              return DropdownButtonFormField<String>(
                                value: busMap.containsKey(batchBusId) ? batchBusId : null,
                                isExpanded: true,
                                isDense: true,
                                decoration: const InputDecoration(
                                  labelText: 'Default Bus',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  isDense: true,
                                ),
                                hint: const Text('Select Bus', style: TextStyle(fontSize: 12)),
                                items: busMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) => setSheetState(() => batchBusId = val),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: routesAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (routes) {
                              final routeMap = <String, String>{};
                              for (final r in routes) {
                                final id = r['id']?.toString() ?? '';
                                if (id.isNotEmpty) routeMap[id] = r['route_name'] ?? 'Route';
                              }
                              return DropdownButtonFormField<String>(
                                value: routeMap.containsKey(batchRouteId) ? batchRouteId : null,
                                isExpanded: true,
                                isDense: true,
                                decoration: const InputDecoration(
                                  labelText: 'Default Route',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  isDense: true,
                                ),
                                hint: const Text('Select Route', style: TextStyle(fontSize: 12)),
                                items: routeMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) => setSheetState(() => batchRouteId = val),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isUploading
                            ? null
                            : () async {
                                final text = csvCtrl.text.trim();
                                if (text.isEmpty) {
                                  AppSnackBar.showError(context, 'Please enter or load incharge data');
                                  return;
                                }
                                final lines = text.split('\n');
                                final List<Map<String, dynamic>> inchargesList = [];
                                for (final line in lines) {
                                  final trimmed = line.trim();
                                  if (trimmed.isEmpty) continue;
                                  final parts = trimmed.split(',').map((p) => p.trim()).toList();
                                  if (parts.length >= 2) {
                                    inchargesList.add({
                                      'employeeId': parts[0],
                                      'name': parts[1],
                                      'email': parts.length > 2 ? parts[2] : '${parts[0].toLowerCase()}@tripmate.edu',
                                      'phone': parts.length > 3 ? parts[3] : '',
                                      'institutionType': parts.length > 4 ? parts[4] : 'Engineering',
                                      'department': parts.length > 5 ? parts[5] : 'Faculty',
                                      'assignedBusId': batchBusId,
                                      'assignedRouteId': batchRouteId,
                                    });
                                  }
                                }
                                if (inchargesList.isEmpty) {
                                  AppSnackBar.showError(context, 'No valid incharge rows found');
                                  return;
                                }
                                setSheetState(() => isUploading = true);
                                try {
                                  final api = ref.read(apiClientProvider);
                                  final res = await api.bulkUploadAdminIncharges(inchargesList);
                                  final count = res.data['data']?['count'] ?? inchargesList.length;
                                  if (mounted) {
                                    AppSnackBar.showSuccess(context, 'Successfully onboarded $count incharges!');
                                    ref.invalidate(adminInchargesProvider);
                                    ref.invalidate(adminDashboardProvider);
                                    Navigator.pop(ctx);
                                  }
                                } catch (e) {
                                  if (mounted) AppSnackBar.showError(context, 'Bulk upload failed: $e');
                                } finally {
                                  setSheetState(() => isUploading = false);
                                }
                              },
                        icon: isUploading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.cloud_upload_rounded),
                        label: Text(isUploading ? 'Uploading & Processing...' : 'Process & Upload Incharges'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddEditInstitutionDialog({Map<String, dynamic>? institution}) {
    final isEdit = institution != null;
    final nameCtrl = TextEditingController(text: institution?['name'] ?? '');
    final codeCtrl = TextEditingController(text: institution?['code'] ?? '');
    final catCtrl = TextEditingController(text: institution?['category'] ?? 'Engineering');
    final emailCtrl = TextEditingController(text: institution?['contact_email'] ?? '');
    final phoneCtrl = TextEditingController(text: institution?['contact_phone'] ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.school_rounded, color: Color(0xFF1E40AF), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Institution / College' : 'Add New Institution',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            Text(
                              isEdit ? 'Update institution details & contact info' : 'Register college under VET Trust',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Institution Name *', hintText: 'e.g. Velalar College of Engineering and Technology', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Code & Category
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(labelText: 'Short Code *', hintText: 'VCET', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: catCtrl,
                          decoration: const InputDecoration(labelText: 'Category', hintText: 'Engineering, Arts, Nursing', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Email & Phone
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Principal / Contact Email', hintText: 'principal@velalarengg.ac.in', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Office Phone', hintText: '+91 424 2244201', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => isSaving = true);
                              try {
                                final api = ref.read(apiClientProvider);
                                final payload = {
                                  'name': nameCtrl.text.trim(),
                                  'code': codeCtrl.text.trim(),
                                  'category': catCtrl.text.trim(),
                                  'contactEmail': emailCtrl.text.trim(),
                                  'contactPhone': phoneCtrl.text.trim(),
                                };
                                if (isEdit) {
                                  await api.updateAdminInstitution(institution['id'].toString(), payload);
                                  if (mounted) AppSnackBar.showSuccess(context, 'Institution updated successfully!');
                                } else {
                                  await api.createAdminInstitution(payload);
                                  if (mounted) AppSnackBar.showSuccess(context, 'Institution registered successfully!');
                                }
                                ref.invalidate(adminInstitutionsProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (mounted) AppSnackBar.showError(context, 'Operation failed: $e');
                              } finally {
                                setSheetState(() => isSaving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'Save Changes' : 'Register Institution', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInstitutionOptionsSheet(Map<String, dynamic> institution) {
    final name = institution['name'] ?? 'Institution';
    final code = institution['code'] ?? '';
    final id = institution['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.school_rounded, color: Color(0xFF1E40AF), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                      if (code.isNotEmpty) Text('Code: $code', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF1E40AF)),
              title: const Text('Edit Institution Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Update college name, code, contact or category', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditInstitutionDialog(institution: institution);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
              title: const Text('Deactivate Institution', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.danger)),
              subtitle: const Text('Deactivate this institution from active selection', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Confirm Deactivation'),
                    content: Text('Are you sure you want to deactivate "$name"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Deactivate'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  try {
                    final api = ref.read(apiClientProvider);
                    await api.deleteAdminInstitution(id);
                    if (mounted) {
                      AppSnackBar.showSuccess(context, 'Institution deactivated successfully');
                      ref.invalidate(adminInstitutionsProvider);
                    }
                  } catch (e) {
                    if (mounted) AppSnackBar.showError(context, 'Deactivation failed: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }


  String _formatDateTime(dynamic dateVal) {
    if (dateVal == null) return 'Never';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$d/$m/$y $hour:$min $ampm';
    } catch (_) {
      return dateVal.toString();
    }
  }

  void _showAddUserDialog({Map<String, dynamic>? user}) {
    final isEdit = user != null;
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final passwordCtrl = TextEditingController();
    String selectedRole = (user?['role'] ?? 'student').toString().toLowerCase();
    if (!['admin', 'incharge', 'student'].contains(selectedRole)) {
      selectedRole = 'student';
    }
    bool isActive = user?['is_active'] ?? true;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit User Account' : 'Create User Account',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email Address *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Valid email is required' : null,
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password *',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                        helperText: 'Minimum 6 characters',
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters required' : null,
                    ),
                  ],
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'System Role *',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'student', child: Text('Student / Passenger')),
                      DropdownMenuItem(value: 'incharge', child: Text('Bus Incharge / Staff')),
                      DropdownMenuItem(value: 'admin', child: Text('System Administrator')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedRole = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Account Active', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Allow user to authenticate and access app services', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    value: isActive,
                    activeColor: AppTheme.primaryAccent,
                    onChanged: (val) => setSheetState(() => isActive = val),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setSheetState(() => isSaving = true);
                        try {
                          final api = ref.read(apiClientProvider);
                          if (isEdit) {
                            await api.updateAdminUser(
                              user['id'].toString(),
                              {
                                'email': emailCtrl.text.trim(),
                                'role': selectedRole,
                                'isActive': isActive,
                              },
                            );
                          } else {
                            await api.createAdminUser({
                              'email': emailCtrl.text.trim(),
                              'password': passwordCtrl.text,
                              'role': selectedRole,
                              'isActive': isActive,
                            });
                          }
                          if (mounted) {
                            Navigator.pop(ctx);
                            AppSnackBar.showSuccess(context, isEdit ? 'User account updated' : 'User account created successfully');
                            ref.invalidate(adminUsersProvider);
                          }
                        } catch (e) {
                          setSheetState(() => isSaving = false);
                          if (mounted) AppSnackBar.showError(context, 'Failed to save user: $e');
                        }
                      },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'Update User' : 'Create User', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    final email = user['email'] ?? 'User';
    final userId = user['id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Color(0xFF1E40AF), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text('Reset Password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reset authentication password for:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password *',
                    prefixIcon: Icon(Icons.password_rounded),
                    helperText: 'Minimum 6 characters',
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSaving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => isSaving = true);
                try {
                  final api = ref.read(apiClientProvider);
                  await api.resetAdminUserPassword(userId, passwordCtrl.text);
                  if (mounted) {
                    Navigator.pop(dCtx);
                    AppSnackBar.showSuccess(context, 'Password reset successfully for $email');
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (mounted) AppSnackBar.showError(context, 'Failed to reset password: $e');
                }
              },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserOptionsSheet(Map<String, dynamic> user) {
    final email = user['email'] ?? 'User';
    final role = (user['role'] ?? 'student').toString().toUpperCase();
    final isActive = user['is_active'] == true;
    final userId = user['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    email.isNotEmpty ? email[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E40AF), fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Role: $role • Status: ${isActive ? "Active" : "Suspended"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.lock_reset_rounded, color: Color(0xFF1E40AF)),
              title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Set a new login password for this user', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showResetPasswordDialog(user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF1E40AF)),
              title: const Text('Edit User Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Change email address or system role', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddUserDialog(user: user);
              },
            ),
            ListTile(
              leading: Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded, color: isActive ? AppTheme.danger : AppTheme.success),
              title: Text(isActive ? 'Suspend User Access' : 'Activate User Access', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isActive ? AppTheme.danger : AppTheme.success)),
              subtitle: Text(isActive ? 'Prevent user from logging in' : 'Restore user access to the platform', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final api = ref.read(apiClientProvider);
                  await api.updateAdminUser(userId, {'isActive': !isActive});
                  if (mounted) {
                    AppSnackBar.showSuccess(context, isActive ? 'User suspended' : 'User activated');
                    ref.invalidate(adminUsersProvider);
                  }
                } catch (e) {
                  if (mounted) AppSnackBar.showError(context, 'Failed to update user status: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabSearchBar({
    required TextEditingController controller,
    required String hintText,
    required List<String> filterChips,
    required String selectedFilter,
    required ValueChanged<String> onFilterChanged,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: controller,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          controller.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          if (filterChips.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filterChips.map((chip) {
                  final isSel = selectedFilter == chip;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => onFilterChanged(chip),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF1E40AF) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? const Color(0xFF1E40AF) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          chip,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(adminRoutesProvider);
    final busesAsync = ref.watch(adminBusesProvider);
    final inchargesAsync = ref.watch(adminInchargesProvider);
    final institutionsAsync = ref.watch(adminInstitutionsProvider);
    final tripsAsync = ref.watch(adminTripsProvider);
    final usersAsync = ref.watch(adminUsersProvider);

    final routesCount = routesAsync.value?.length ?? 0;
    final busesCount = busesAsync.value?.length ?? 0;
    final inchargesCount = inchargesAsync.value?.length ?? 0;
    final institutionsCount = institutionsAsync.value?.length ?? 0;
    final tripsCount = tripsAsync.value?.length ?? 0;
    final usersCount = usersAsync.value?.length ?? 0;

    return RefreshIndicator(
      color: AppTheme.primaryAccent,
      onRefresh: () async {
        ref.invalidate(adminRoutesProvider);
        ref.invalidate(adminBusesProvider);
        ref.invalidate(adminInchargesProvider);
        ref.invalidate(adminInstitutionsProvider);
        ref.invalidate(adminBusAssignmentsProvider);
        ref.invalidate(adminTripsProvider);
        ref.invalidate(adminUsersProvider);
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Header Banner
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const FeatureIconBadge(
                      icon: Icons.alt_route_rounded,
                      color: Color(0xFF1E40AF),
                      size: 38,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fleet & Route Infrastructure',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary),
                          ),
                          Text(
                            'Manage vehicle assets, transit routes, stops, and crew allocations',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryAccent),
                      tooltip: 'Refresh Infrastructure',
                      onPressed: () {
                        ref.invalidate(adminRoutesProvider);
                        ref.invalidate(adminBusesProvider);
                        ref.invalidate(adminInchargesProvider);
                        ref.invalidate(adminInstitutionsProvider);
                        ref.invalidate(adminBusAssignmentsProvider);
                        AppSnackBar.showInfo(context, 'Infrastructure data refreshed');
                      },
                    ),
                  ],
                ),
              ),

              // Horizontally Scrollable Multi-View Switcher Bar with Badges
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _TabPillButton(
                        title: 'Routes',
                        icon: Icons.alt_route_rounded,
                        isSelected: _viewMode == 0,
                        badgeCount: routesCount,
                        onTap: () => setState(() => _viewMode = 0),
                      ),
                      const SizedBox(width: 8),
                      _TabPillButton(
                        title: 'Buses Fleet',
                        icon: Icons.directions_bus_rounded,
                        isSelected: _viewMode == 1,
                        badgeCount: busesCount,
                        onTap: () => setState(() => _viewMode = 1),
                      ),
                      const SizedBox(width: 8),
                      _TabPillButton(
                        title: 'Incharges & Crew',
                        icon: Icons.badge_rounded,
                        isSelected: _viewMode == 2,
                        badgeCount: inchargesCount,
                        onTap: () => setState(() => _viewMode = 2),
                      ),
                      const SizedBox(width: 8),
                      _TabPillButton(
                        title: 'Colleges & Inst',
                        icon: Icons.school_rounded,
                        isSelected: _viewMode == 3,
                        badgeCount: institutionsCount,
                        onTap: () => setState(() => _viewMode = 3),
                      ),
                      const SizedBox(width: 8),
                      _TabPillButton(
                        title: 'Daily Trips',
                        icon: Icons.history_edu_rounded,
                        isSelected: _viewMode == 4,
                        badgeCount: tripsCount,
                        onTap: () => setState(() => _viewMode = 4),
                      ),
                      const SizedBox(width: 8),
                      _TabPillButton(
                        title: 'User Accounts',
                        icon: Icons.manage_accounts_rounded,
                        isSelected: _viewMode == 5,
                        badgeCount: usersCount,
                        onTap: () => setState(() => _viewMode = 5),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: _viewMode == 0
                    ? _buildRoutesList(routesAsync)
                    : _viewMode == 1
                        ? _buildBusesList(busesAsync)
                        : _viewMode == 2
                            ? _buildInchargesList(inchargesAsync)
                            : _viewMode == 3
                                ? _buildInstitutionsList(institutionsAsync)
                                : _viewMode == 4
                                    ? _buildTripsList(tripsAsync)
                                    : _buildUsersList(usersAsync),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutesList(AsyncValue<List<Map<String, dynamic>>> routesAsync) {
    return routesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (routes) {
        final query = _routesSearchCtrl.text.trim().toLowerCase();
        final filteredRoutes = routes.where((r) {
          final name = (r['route_name'] ?? '').toString().toLowerCase();
          final code = (r['route_code'] ?? '').toString().toLowerCase();
          final desc = (r['description'] ?? '').toString().toLowerCase();
          final stages = r['stages'] is List ? (r['stages'] as List) : [];
          final stageNames = stages.map((s) => (s is Map ? s['stage_name'] ?? '' : '').toString().toLowerCase()).join(' ');

          if (query.isNotEmpty) {
            final match = name.contains(query) || code.contains(query) || desc.contains(query) || stageNames.contains(query);
            if (!match) return false;
          }

          final assignedBuses = r['assigned_buses'] is List ? (r['assigned_buses'] as List) : [];
          final hasBus = assignedBuses.isNotEmpty;
          if (_routesFilter == 'Assigned' && !hasBus) return false;
          if (_routesFilter == 'Unassigned' && hasBus) return false;

          return true;
        }).toList();

        return Column(
          children: [
            _buildSubTabSearchBar(
              controller: _routesSearchCtrl,
              hintText: 'Search routes by name, code, stop stage...',
              filterChips: const ['All', 'Assigned', 'Unassigned'],
              selectedFilter: _routesFilter,
              onFilterChanged: (val) => setState(() => _routesFilter = val),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    query.isNotEmpty || _routesFilter != 'All'
                        ? 'Showing ${filteredRoutes.length} of ${routes.length} Routes'
                        : '${routes.length} Transit Routes',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textPrimary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showAssignBusDialog(),
                        icon: const Icon(Icons.link_rounded, size: 14),
                        label: const Text('Assign Bus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E40AF),
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditRouteDialog(),
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const Text('+ Add Route', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (filteredRoutes.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.alt_route_rounded, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          query.isNotEmpty || _routesFilter != 'All'
                              ? 'No routes match your search or filter'
                              : 'No routes registered yet',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        if (query.isNotEmpty || _routesFilter != 'All') ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _routesSearchCtrl.clear();
                              setState(() => _routesFilter = 'All');
                            },
                            child: const Text('Clear Filter', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredRoutes.length,
                  itemBuilder: (context, index) {
                    final r = filteredRoutes[index];
                    final routeId = r['id']?.toString() ?? '';
                    final name = r['route_name'] ?? 'Route';
                    final code = r['route_code'] ?? '';
                    final desc = r['description'] ?? 'Campus Transport Route';
                    final stages = r['stages'] is List ? (r['stages'] as List) : [];
                    final assignedBuses = r['assigned_buses'] is List ? (r['assigned_buses'] as List) : [];
                    final operatingBus = assignedBuses.isNotEmpty && assignedBuses.first is Map ? (assignedBuses.first as Map<String, dynamic>) : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _showRouteOptionsSheet(r),
                            borderRadius: BorderRadius.circular(10),
                            child: Row(
                              children: [
                                const FeatureIconBadge(
                                  icon: Icons.alt_route_rounded,
                                  color: AppTheme.primaryAccent,
                                  size: 36,
                                  iconSize: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              name,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppTheme.textPrimary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (code.toString().isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                code,
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        desc,
                                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${stages.length} Stops',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.textMuted),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Operating Bus Status
                          if (operatingBus != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F7FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_bus_rounded, color: Color(0xFF1E40AF), size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              'Bus: ${operatingBus['bus_number'] ?? 'Assigned'}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                                            ),
                                            if (operatingBus['registration_no'] != null) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDBEAFE),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  operatingBus['registration_no'],
                                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _showAssignBusDialog(preselectedRouteId: routeId),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded, color: Color(0xFF3B82F6), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        operatingBus['incharge_name'] ?? 'Faculty Incharge',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                      ),
                                      if (operatingBus['incharge_phone'] != null && operatingBus['incharge_phone'].toString().isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.phone_outlined, color: Color(0xFF3B82F6), size: 12),
                                        const SizedBox(width: 3),
                                        Text(
                                          operatingBus['incharge_phone'],
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 16),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'No bus currently assigned',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _showAssignBusDialog(preselectedRouteId: routeId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E40AF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    child: const Text('Assign', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Stop Stages:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                              InkWell(
                                onTap: () => _showAddEditStageDialog(routeId),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_circle_outline_rounded, size: 13, color: Color(0xFF1E40AF)),
                                      SizedBox(width: 3),
                                      Text('Add Stop', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (stages.isEmpty)
                            const Text('No stages added yet. Tap "+ Add Stop" above.', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic))
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: stages.map((s) {
                                final st = s as Map<String, dynamic>;
                                return InkWell(
                                  onTap: () => _showStageOptionsSheet(routeId, st),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.pin_drop_rounded, size: 11, color: Color(0xFF1E40AF)),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${st['sequence_order'] ?? ''}. ${st['stage_name'] ?? ''}',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBusesList(AsyncValue<List<Map<String, dynamic>>> busesAsync) {
    return busesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (buses) {
        final query = _busesSearchCtrl.text.trim().toLowerCase();
        final filteredBuses = buses.where((b) {
          final busNo = (b['bus_number'] ?? '').toString().toLowerCase();
          final reg = (b['registration_no'] ?? b['registration_number'] ?? '').toString().toLowerCase();
          final incharge = (b['incharge_name'] ?? '').toString().toLowerCase();
          final route = (b['route_name'] ?? '').toString().toLowerCase();

          if (query.isNotEmpty) {
            final match = busNo.contains(query) || reg.contains(query) || incharge.contains(query) || route.contains(query);
            if (!match) return false;
          }

          final isAssigned = (b['route_id'] != null || (b['route_name'] != null && b['route_name'] != 'No Route Assigned'));
          if (_busesFilter == 'Assigned' && !isAssigned) return false;
          if (_busesFilter == 'Standby' && isAssigned) return false;

          return true;
        }).toList();

        return Column(
          children: [
            _buildSubTabSearchBar(
              controller: _busesSearchCtrl,
              hintText: 'Search buses by number, plate, route, incharge...',
              filterChips: const ['All', 'Assigned', 'Standby'],
              selectedFilter: _busesFilter,
              onFilterChanged: (val) => setState(() => _busesFilter = val),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    query.isNotEmpty || _busesFilter != 'All'
                        ? 'Showing ${filteredBuses.length} of ${buses.length} Fleet Vehicles'
                        : '${buses.length} Fleet Vehicles',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textPrimary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showAssignBusDialog(),
                        icon: const Icon(Icons.link_rounded, size: 14),
                        label: const Text('Assign Route', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E40AF),
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditBusDialog(),
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const Text('+ Add Bus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (filteredBuses.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_bus_rounded, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          query.isNotEmpty || _busesFilter != 'All'
                              ? 'No buses match your search or filter'
                              : 'No buses registered in fleet yet',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        if (query.isNotEmpty || _busesFilter != 'All') ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _busesSearchCtrl.clear();
                              setState(() => _busesFilter = 'All');
                            },
                            child: const Text('Clear Filter', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredBuses.length,
                  itemBuilder: (context, index) {
                    final b = filteredBuses[index];
                    final busNo = b['bus_number'] ?? 'Bus';
                    final capacity = b['capacity'] ?? 50;
                    final reg = b['registration_no'] ?? b['registration_number'] ?? 'N/A';
                    final inchargeName = b['incharge_name'] ?? 'Unassigned';
                    final routeName = b['route_name'] ?? 'No Route Assigned';

                    return InkWell(
                      onTap: () => _showBusOptionsSheet(b),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF1E40AF), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(busNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppTheme.textPrimary)),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(reg, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text('$capacity seats', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.alt_route_rounded, size: 13, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Route: $routeName',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_pin_rounded, size: 13, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Incharge: $inchargeName',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildInchargesList(AsyncValue<List<Map<String, dynamic>>> inchargesAsync) {
    return inchargesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (incharges) {
        final query = _inchargesSearchCtrl.text.trim().toLowerCase();
        final filteredIncharges = incharges.where((inc) {
          final name = (inc['name'] ?? '').toString().toLowerCase();
          final email = (inc['email'] ?? '').toString().toLowerCase();
          final phone = (inc['phone'] ?? '').toString().toLowerCase();
          final empId = (inc['employee_id'] ?? '').toString().toLowerCase();
          final busNo = (inc['bus_number'] ?? '').toString().toLowerCase();
          final routeName = (inc['route_name'] ?? '').toString().toLowerCase();
          final inst = (inc['institution_type'] ?? '').toString();

          if (query.isNotEmpty) {
            final match = name.contains(query) || email.contains(query) || phone.contains(query) || empId.contains(query) || busNo.contains(query) || routeName.contains(query);
            if (!match) return false;
          }

          if (_inchargesFilter == 'Assigned') {
            final hasAssignment = inc['bus_id'] != null || (inc['bus_number'] != null && inc['bus_number'] != 'Unassigned');
            if (!hasAssignment) return false;
          } else if (_inchargesFilter == 'Unassigned') {
            final hasAssignment = inc['bus_id'] != null || (inc['bus_number'] != null && inc['bus_number'] != 'Unassigned');
            if (hasAssignment) return false;
          } else if (_inchargesFilter != 'All') {
            if (!inst.toLowerCase().contains(_inchargesFilter.toLowerCase())) return false;
          }

          return true;
        }).toList();

        return Column(
          children: [
            _buildSubTabSearchBar(
              controller: _inchargesSearchCtrl,
              hintText: 'Search staff by name, emp ID, phone, email...',
              filterChips: const ['All', 'Assigned', 'Unassigned', 'Engineering', 'Arts & Science', 'Pharmacy', 'Nursing'],
              selectedFilter: _inchargesFilter,
              onFilterChanged: (val) => setState(() => _inchargesFilter = val),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    query.isNotEmpty || _inchargesFilter != 'All'
                        ? 'Showing ${filteredIncharges.length} of ${incharges.length} Incharges'
                        : '${incharges.length} Incharges & Leads',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textPrimary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showBulkInchargeUploadSheet,
                        icon: const Icon(Icons.upload_file_rounded, size: 14),
                        label: const Text('Bulk Upload', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E40AF),
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditInchargeDialog(),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                        label: const Text('+ Add Incharge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (filteredIncharges.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.badge_rounded, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          query.isNotEmpty || _inchargesFilter != 'All'
                              ? 'No incharges match your search or filter'
                              : 'No bus incharges registered yet',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        if (query.isNotEmpty || _inchargesFilter != 'All') ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _inchargesSearchCtrl.clear();
                              setState(() => _inchargesFilter = 'All');
                            },
                            child: const Text('Clear Filter', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredIncharges.length,
                  itemBuilder: (context, index) {
                    final inc = filteredIncharges[index];
                    final name = inc['name'] ?? 'Incharge';
                    final email = inc['email'] ?? '';
                    final phone = inc['phone'] ?? 'No phone';
                    final empId = inc['employee_id'] ?? 'INC';
                    final busNo = inc['bus_number'] ?? 'Unassigned';
                    final routeName = inc['route_name'] ?? 'No Route';
                    final inst = inc['institution_type'] ?? 'Engineering';

                    return InkWell(
                      onTap: () => _showInchargeOptionsSheet(inc),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'I',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E40AF), fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppTheme.textPrimary)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(empId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF166534))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 12, color: AppTheme.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(phone, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                                      if (email.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.email_outlined, size: 12, color: AppTheme.textSecondary),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(email, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Bus: $busNo • Route: $routeName ($inst)',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUsersList(AsyncValue<List<Map<String, dynamic>>> usersAsync) {
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
      error: (e, _) => Center(child: Text('Error loading users: $e')),
      data: (users) {
        final query = _usersSearchCtrl.text.trim().toLowerCase();
        final filteredUsers = users.where((u) {
          final email = (u['email'] ?? '').toString().toLowerCase();
          final fullName = (u['full_name'] ?? '').toString().toLowerCase();
          final rollNo = (u['roll_number'] ?? '').toString().toLowerCase();
          final empId = (u['employee_id'] ?? '').toString().toLowerCase();
          final role = (u['role'] ?? 'student').toString().toLowerCase();
          final isActive = u['is_active'] == true;

          if (query.isNotEmpty) {
            final match = email.contains(query) || fullName.contains(query) || rollNo.contains(query) || empId.contains(query) || role.contains(query);
            if (!match) return false;
          }

          if (_usersFilter == 'Student' && role != 'student') return false;
          if (_usersFilter == 'Incharge' && role != 'incharge') return false;
          if (_usersFilter == 'Admin' && role != 'admin') return false;
          if (_usersFilter == 'Active' && !isActive) return false;
          if (_usersFilter == 'Suspended' && isActive) return false;

          return true;
        }).toList();

        return Column(
          children: [
            _buildSubTabSearchBar(
              controller: _usersSearchCtrl,
              hintText: 'Search users by email, name, role...',
              filterChips: const ['All', 'Student', 'Incharge', 'Admin', 'Active', 'Suspended'],
              selectedFilter: _usersFilter,
              onFilterChanged: (val) => setState(() => _usersFilter = val),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    query.isNotEmpty || _usersFilter != 'All'
                        ? 'Showing ${filteredUsers.length} of ${users.length} Accounts'
                        : '${users.length} Registered Accounts',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textPrimary),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddUserDialog(),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                    label: const Text('+ Add User', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            if (filteredUsers.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.manage_accounts_rounded, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          query.isNotEmpty || _usersFilter != 'All'
                              ? 'No users match your search or filter'
                              : 'No users registered yet',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        if (query.isNotEmpty || _usersFilter != 'All') ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _usersSearchCtrl.clear();
                              setState(() => _usersFilter = 'All');
                            },
                            child: const Text('Clear Filter', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final u = filteredUsers[index];
                    final email = u['email'] ?? '';
                    final role = (u['role'] ?? 'student').toString().toLowerCase();
                    final isActive = u['is_active'] == true;
                    final fullName = u['full_name'];
                    final rollNo = u['roll_number'];
                    final empId = u['employee_id'];
                    final lastLogin = u['last_login_at'];

                    Color roleBg;
                    Color roleColor;
                    IconData roleIcon;
                    if (role == 'admin') {
                      roleBg = const Color(0xFFF3E8FF);
                      roleColor = const Color(0xFF7E22CE);
                      roleIcon = Icons.admin_panel_settings_rounded;
                    } else if (role == 'incharge') {
                      roleBg = const Color(0xFFEFF6FF);
                      roleColor = const Color(0xFF1E40AF);
                      roleIcon = Icons.badge_rounded;
                    } else {
                      roleBg = const Color(0xFFECFDF5);
                      roleColor = const Color(0xFF047857);
                      roleIcon = Icons.school_rounded;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: InkWell(
                        onTap: () => _showUserOptionsSheet(u),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: roleBg,
                                    child: Icon(roleIcon, color: roleColor, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          email,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary),
                                        ),
                                        if (fullName != null && fullName.toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              '$fullName ${rollNo != null ? "($rollNo)" : empId != null ? "($empId)" : ""}',
                                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: roleBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: roleColor),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isActive ? 'Active' : 'Suspended',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Last login: ${_formatDateTime(lastLogin)}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildInstitutionsList(AsyncValue<List<Map<String, dynamic>>> institutionsAsync) {
    return institutionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (institutions) {
        final query = _institutionsSearchCtrl.text.trim().toLowerCase();
        final filteredInstitutions = institutions.where((inst) {
          final name = (inst['name'] ?? '').toString().toLowerCase();
          final code = (inst['code'] ?? '').toString().toLowerCase();
          final cat = (inst['category'] ?? '').toString().toLowerCase();

          if (query.isNotEmpty) {
            final match = name.contains(query) || code.contains(query) || cat.contains(query);
            if (!match) return false;
          }

          if (_institutionsFilter != 'All') {
            if (!cat.contains(_institutionsFilter.toLowerCase()) && !name.contains(_institutionsFilter.toLowerCase())) return false;
          }

          return true;
        }).toList();

        return Column(
          children: [
            _buildSubTabSearchBar(
              controller: _institutionsSearchCtrl,
              hintText: 'Search colleges & institutions by name, code...',
              filterChips: const ['All', 'Engineering', 'Arts & Science', 'Pharmacy', 'Nursing', 'Polytechnic'],
              selectedFilter: _institutionsFilter,
              onFilterChanged: (val) => setState(() => _institutionsFilter = val),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    query.isNotEmpty || _institutionsFilter != 'All'
                        ? 'Showing ${filteredInstitutions.length} of ${institutions.length} Colleges'
                        : '${institutions.length} Trust Institutions',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textPrimary),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditInstitutionDialog(),
                    icon: const Icon(Icons.add_business_rounded, size: 16),
                    label: const Text('+ Add College', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            if (filteredInstitutions.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_rounded, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          query.isNotEmpty || _institutionsFilter != 'All'
                              ? 'No institutions match your search or filter'
                              : 'No institutions registered yet',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        if (query.isNotEmpty || _institutionsFilter != 'All') ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _institutionsSearchCtrl.clear();
                              setState(() => _institutionsFilter = 'All');
                            },
                            child: const Text('Clear Filter', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredInstitutions.length,
                  itemBuilder: (context, index) {
                    final inst = filteredInstitutions[index];
                    final name = inst['name'] ?? 'College';
                    final code = inst['code'] ?? '';
                    final cat = inst['category'] ?? 'College';
                    final email = inst['contact_email'] ?? '—';
                    final phone = inst['contact_phone'] ?? '—';
                    final studentCount = inst['student_count'] ?? 0;
                    final inchargeCount = inst['incharge_count'] ?? 0;

                    return InkWell(
                      onTap: () => _showInstitutionOptionsSheet(inst),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.school_rounded, color: Color(0xFF1E40AF), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary)),
                                      ),
                                      if (code.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF))),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Category: $cat • Phone: $phone', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  if (email != '—') Text('Email: $email', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('$studentCount Students', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('$inchargeCount Incharges', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _showScheduleTripDialog() {
    final buses = ref.read(adminBusesProvider).value ?? [];
    final assignments = buses.where((b) => b['incharge_name'] != null && b['route_name'] != null).toList();

    String? selectedAssignmentId;
    DateTime tripDate = DateTime.now();
    String tripType = 'morning';
    String tripDirection = 'boarding';
    bool isSaving = false;

    if (assignments.isNotEmpty) {
      selectedAssignmentId = assignments.first['assignment_id']?.toString() ?? assignments.first['id']?.toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_road_rounded, color: Color(0xFF1E40AF), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Schedule Daily Bus Trip', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                          Text('Dispatch scheduled morning or evening transit journey', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Assignment Selector
                const Text('Assigned Vehicle & Route *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedAssignmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text('Select Assigned Bus & Route'),
                  items: assignments.map((a) {
                    final id = a['assignment_id']?.toString() ?? a['id']?.toString() ?? '';
                    final busNo = a['bus_number'] ?? 'Bus';
                    final route = a['route_name'] ?? 'Route';
                    final incharge = a['incharge_name'] ?? 'Incharge';
                    return DropdownMenuItem(
                      value: id,
                      child: Text('$busNo • $route ($incharge)', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) => setSheetState(() => selectedAssignmentId = val),
                ),
                const SizedBox(height: 14),

                // Trip Date & Category Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Trip Date *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textPrimary)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: tripDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                              );
                              if (picked != null) {
                                setSheetState(() => tripDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(DateFormat('dd/MM/yyyy').format(tripDate), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF1E40AF)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Trip Category *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textPrimary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: tripType,
                            isExpanded: true,
                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                            items: const [
                              DropdownMenuItem(value: 'morning', child: Text('Morning', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'evening', child: Text('Evening', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'special', child: Text('Special', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (val) => setSheetState(() => tripType = val ?? 'morning'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Trip Direction
                const Text('Transit Direction *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: tripDirection,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  items: const [
                    DropdownMenuItem(value: 'boarding', child: Text('Boarding / Pickup Journey (To Campus)')),
                    DropdownMenuItem(value: 'exit', child: Text('Exit / Drop Journey (To Home)')),
                    DropdownMenuItem(value: 'both', child: Text('Both Inbound & Outbound')),
                  ],
                  onChanged: (val) => setSheetState(() => tripDirection = val ?? 'boarding'),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (isSaving || selectedAssignmentId == null)
                        ? null
                        : () async {
                            setSheetState(() => isSaving = true);
                            try {
                              final api = ref.read(apiClientProvider);
                              final payload = {
                                'busAssignmentId': selectedAssignmentId,
                                'tripDate': DateFormat('yyyy-MM-dd').format(tripDate),
                                'tripType': tripType,
                                'tripDirection': tripDirection,
                              };
                              await api.createAdminTrip(payload);
                              ref.invalidate(adminTripsProvider);
                              ref.invalidate(adminDashboardProvider);
                              if (ctx.mounted) {
                                AppSnackBar.showSuccess(context, 'Trip scheduled successfully!');
                                Navigator.pop(ctx);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AppSnackBar.showError(context, 'Failed to schedule trip: $e');
                              }
                            } finally {
                              setSheetState(() => isSaving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Schedule & Dispatch Trip', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripsList(AsyncValue<List<Map<String, dynamic>>> tripsAsync) {
    return tripsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (trips) {
        final query = _tripsSearchCtrl.text.trim().toLowerCase();
        final filteredTrips = trips.where((t) {
          final busNo = (t['bus_number'] ?? '').toString().toLowerCase();
          final routeName = (t['route_name'] ?? '').toString().toLowerCase();
          final incharge = (t['incharge_name'] ?? '').toString().toLowerCase();
          final tripDate = (t['trip_date'] ?? '').toString().toLowerCase();
          final type = (t['trip_type'] ?? '').toString().toLowerCase();
          final status = (t['status'] ?? '').toString().toLowerCase();

          if (query.isNotEmpty) {
            final match = busNo.contains(query) || routeName.contains(query) || incharge.contains(query) || tripDate.contains(query);
            if (!match) return false;
          }

          if (_tripsFilter == 'Active' && status == 'completed') return false;
          if (_tripsFilter == 'Finalized' && status != 'completed') return false;
          if (_tripsFilter == 'Morning' && type != 'morning') return false;
          if (_tripsFilter == 'Evening' && type != 'evening') return false;

          return true;
        }).toList();

        final activeCount = trips.where((t) => (t['status'] ?? '').toString() == 'active').length;
        final pendingCount = trips.where((t) => (t['status'] ?? '').toString() == 'pending').length;
        final completedCount = trips.where((t) => (t['status'] ?? '').toString() == 'completed').length;

        return Column(
          children: [
            // Top Action Row with Schedule Trip button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Trip Operations & History',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Viewing Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showScheduleTripDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Schedule Trip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

            // Summary KPI Metric Row (4 Cards matching Web)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SCHEDULED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          Text('${trips.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ACTIVE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                          Text('$activeCount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PENDING', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                          Text('$pendingCount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFD97706))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('COMPLETED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                          Text('$completedCount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF475569))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            _buildSubTabSearchBar(
              controller: _tripsSearchCtrl,
              hintText: 'Search trips by bus, route, incharge...',
              filterChips: const ['All', 'Active', 'Finalized', 'Morning', 'Evening'],
              selectedFilter: _tripsFilter,
              onFilterChanged: (val) => setState(() => _tripsFilter = val),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    query.isNotEmpty || _tripsFilter != 'All'
                        ? 'Showing ${filteredTrips.length} of ${trips.length} Trips'
                        : '${trips.length} Daily Trips',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
            if (filteredTrips.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_edu_rounded, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          query.isNotEmpty || _tripsFilter != 'All'
                              ? 'No trips match your search or filter'
                              : 'No daily trips recorded yet',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        if (query.isNotEmpty || _tripsFilter != 'All') ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _tripsSearchCtrl.clear();
                              setState(() => _tripsFilter = 'All');
                            },
                            child: const Text('Clear Filter', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredTrips.length,
                  itemBuilder: (context, index) {
                    final t = filteredTrips[index];
                    final tripDate = t['trip_date'] ?? '';
                    final type = (t['trip_type'] ?? 'morning').toString().toUpperCase();
                    final direction = (t['trip_direction'] ?? 'boarding').toString().toUpperCase();
                    final status = (t['status'] ?? 'completed').toString();
                    final busNo = t['bus_number'] ?? 'Bus';
                    final routeName = t['route_name'] ?? 'Route';
                    final incharge = t['incharge_name'] ?? 'Incharge';
                    final present = t['present_count']?.toString() ?? '0';
                    final absent = t['absent_count']?.toString() ?? '0';
                    final isCompleted = status == 'completed';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isCompleted ? const Color(0xFFEFF6FF) : const Color(0xFFDCFCE7),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  type == 'MORNING' ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                                  color: isCompleted ? const Color(0xFF1E40AF) : AppTheme.success,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$type TRIP ($direction)',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary),
                                    ),
                                    Text('$busNo • $routeName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isCompleted ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isCompleted ? 'Finalized' : 'Active',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isCompleted ? AppTheme.textSecondary : AppTheme.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Present / Absent metrics & Incharge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Incharge: $incharge',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                                child: Text('$present Boarded', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                                child: Text('$absent Absent', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Trip Date: ${PdfReportService.formatToDDMMYYYY(tripDate)}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    final api = ref.read(apiClientProvider);
                                    final tripId = t['id']?.toString() ?? '';
                                    List<Map<String, dynamic>> records = [];

                                    if (tripId.isNotEmpty) {
                                      try {
                                        final attRes = await api.getTripAttendance(tripId);
                                        final attData = attRes.data['data'];
                                        if (attData is List) {
                                          records = List<Map<String, dynamic>>.from(attData);
                                        }
                                      } catch (_) {}
                                    }

                                    if (records.isEmpty) {
                                      final stuRes = await api.getAdminStudents();
                                      final rawData = stuRes.data['data'];
                                      final List rawList = rawData is List
                                          ? rawData
                                          : (rawData is Map && rawData['items'] is List
                                              ? (rawData['items'] as List)
                                              : (rawData is Map && rawData['students'] is List
                                                  ? (rawData['students'] as List)
                                                  : []));
                                      final allStudents = List<Map<String, dynamic>>.from(rawList);

                                      records = allStudents.where((s) {
                                        if (t['route_id'] != null && s['assigned_route_id'] != null) {
                                          return s['assigned_route_id'].toString() == t['route_id'].toString();
                                        }
                                        return true;
                                      }).toList();
                                    }

                                    await PdfReportService.printTripReport(
                                      trip: t,
                                      attendanceRecords: records,
                                    );
                                  } catch (e) {
                                    if (context.mounted) {
                                      AppSnackBar.showError(context, 'PDF generation error: $e');
                                    }
                                  }
                                },
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                                label: const Text('Print PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E40AF),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ============================================================
// TAB 5: REPORTS, RISK CONTROLS & AUDIT LOGS
// ============================================================

class _AdminReportsSettingsTab extends ConsumerStatefulWidget {
  const _AdminReportsSettingsTab();

  @override
  ConsumerState<_AdminReportsSettingsTab> createState() => _AdminReportsSettingsTabState();
}

class _AdminReportsSettingsTabState extends ConsumerState<_AdminReportsSettingsTab> {
  int _viewMode = 0; // 0 = Transit & Geofence Audit, 1 = Analytics, 2 = Risk Thresholds, 3 = Audit Logs

  final TextEditingController _consecutiveCtrl = TextEditingController(text: '3');
  final TextEditingController _lowRateCtrl = TextEditingController(text: '75');
  bool _isSaving = false;
  bool _isExporting = false;

  String _selectedActionFilter = 'All';
  String _selectedTableFilter = 'All';

  @override
  void dispose() {
    _consecutiveCtrl.dispose();
    _lowRateCtrl.dispose();
    super.dispose();
  }

  void _showLogDetails(Map<String, dynamic> log) {
    final action = (log['action'] ?? 'ACTION').toString();
    final table = (log['table_name'] ?? 'table').toString();
    final performedBy = log['performed_by_email'] ?? 'System';
    final role = log['performed_by_role'] ?? 'admin';
    final timestamp = log['performed_at'] ?? '';
    final reason = log['reason']?.toString();
    final oldValue = log['old_value'];
    final newValue = log['new_value'];
    final ip = log['ip_address'] ?? 'Internal';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getActionColor(action).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _getActionColor(action)),
                    ),
                    child: Text(action, style: TextStyle(fontWeight: FontWeight.w900, color: _getActionColor(action), fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Text('Table: $table', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 14),
              Text('User: $performedBy ($role)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
              Text('Time: $timestamp', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Text('IP Address: $ip', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              if (reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                  child: Text('Reason: $reason', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1E40AF))),
                ),
              ],
              const SizedBox(height: 16),
              if (oldValue != null) ...[
                const Text('Old State / Before Change:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.danger)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECDD3))),
                  child: Text(oldValue.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF9F1239))),
                ),
                const SizedBox(height: 12),
              ],
              if (newValue != null) ...[
                const Text('New State / After Change:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.success)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBF7D0))),
                  child: Text(newValue.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF166534))),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'INSERT':
        return AppTheme.success;
      case 'UPDATE':
        return const Color(0xFF1E40AF);
      case 'DELETE':
        return AppTheme.danger;
      case 'EXPORT':
        return const Color(0xFF7C3AED);
      case 'LOGIN':
      case 'LOGOUT':
        return const Color(0xFF0D9488);
      default:
        return AppTheme.textSecondary;
    }
  }

  void _openExportModal(BuildContext context) {
    final currentFilters = ref.read(adminAuditReportsFiltersProvider);
    final buses = ref.read(adminBusesProvider).valueOrNull ?? [];

    String expBusId = currentFilters['busId']?.toString() ?? '';
    String expInstitution = currentFilters['institutionType']?.toString() ?? 'All';
    String expStartDate = currentFilters['startDate']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    String expEndDate = currentFilters['endDate']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    String expScope = currentFilters['crossBusOnly'] == true
        ? 'crossBus'
        : currentFilters['mismatchOnly'] == true
            ? 'mismatch'
            : currentFilters['geoDeviationOnly'] == true
                ? 'geoDeviation'
                : currentFilters['beforeStopOnly'] == true
                    ? 'beforeStop'
                    : currentFilters['afterStopOnly'] == true
                        ? 'afterStop'
                        : 'all';
    String expFormat = 'pdf'; // 'pdf', 'excel', 'csv'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export Audit Report',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Choose bus vehicle, institution, date range & format',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 14),

                // 1. Bus Scope Dropdown
                const Text('Vehicle / Fleet Scope', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: expBusId,
                      isExpanded: true,
                      icon: const Icon(Icons.directions_bus_rounded, color: Color(0xFF2563EB), size: 20),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All Fleet Buses (Complete Audit)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        ...buses.map((b) => DropdownMenuItem(
                              value: b['id']?.toString() ?? '',
                              child: Text('${b['bus_number']} (${b['route_name'] ?? 'Route'})', style: const TextStyle(fontSize: 13)),
                            )),
                      ],
                      onChanged: (val) => setModalState(() => expBusId = val ?? ''),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 2. Institution Scope Dropdown
                const Text('Institution / Campus Scope', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: expInstitution,
                      isExpanded: true,
                      icon: const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 20),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Institutions (Whole Campus)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        DropdownMenuItem(value: 'Engineering', child: Text('Engineering', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Arts & Science', child: Text('Arts & Science', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Pharmacy', child: Text('Pharmacy', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Polytechnic', child: Text('Polytechnic', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Nursing', child: Text('Nursing', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Management', child: Text('Management', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) => setModalState(() => expInstitution = val ?? 'All'),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Date Range
                const Text('Date Range', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(expStartDate) ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setModalState(() => expStartDate = DateFormat('yyyy-MM-dd').format(picked));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Text(expStartDate, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(expEndDate) ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setModalState(() => expEndDate = DateFormat('yyyy-MM-dd').format(picked));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Text(expEndDate, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Quick Date Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickDateChip('Today', DateFormat('yyyy-MM-dd').format(DateTime.now()), DateFormat('yyyy-MM-dd').format(DateTime.now()), expStartDate, expEndDate, (s, e) {
                        setModalState(() {
                          expStartDate = s;
                          expEndDate = e;
                        });
                      }),
                      const SizedBox(width: 6),
                      _buildQuickDateChip('Yesterday', DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1))), DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1))), expStartDate, expEndDate, (s, e) {
                        setModalState(() {
                          expStartDate = s;
                          expEndDate = e;
                        });
                      }),
                      const SizedBox(width: 6),
                      _buildQuickDateChip('Last 7 Days', DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 6))), DateFormat('yyyy-MM-dd').format(DateTime.now()), expStartDate, expEndDate, (s, e) {
                        setModalState(() {
                          expStartDate = s;
                          expEndDate = e;
                        });
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Audit Scope
                const Text('Audit Focus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: expScope,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Attendance Records (Present & Absent)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        DropdownMenuItem(value: 'crossBus', child: Text('Cross-Bus Deviations Only', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        DropdownMenuItem(value: 'mismatch', child: Text('Stop Mismatches Only', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        DropdownMenuItem(value: 'geoDeviation', child: Text('Distance Deviated (Faraway / Off-Stop)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        DropdownMenuItem(value: 'beforeStop', child: Text('Before Stop Boarding Only', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        DropdownMenuItem(value: 'afterStop', child: Text('After Stop Boarding Only', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      ],
                      onChanged: (val) => setModalState(() => expScope = val ?? 'all'),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 5. File Format
                const Text('Output File Format', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildFormatCard('pdf', 'PDF Report', Icons.picture_as_pdf_rounded, const Color(0xFF2563EB), expFormat, (fmt) => setModalState(() => expFormat = fmt)),
                    const SizedBox(width: 8),
                    _buildFormatCard('excel', 'Excel (.xlsx)', Icons.table_chart_rounded, const Color(0xFF0D9488), expFormat, (fmt) => setModalState(() => expFormat = fmt)),
                    const SizedBox(width: 8),
                    _buildFormatCard('csv', 'CSV Data', Icons.description_rounded, const Color(0xFF475569), expFormat, (fmt) => setModalState(() => expFormat = fmt)),
                  ],
                ),

                const SizedBox(height: 20),

                // Download Action Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isExporting
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _handleExportReport(
                              busId: expBusId,
                              institutionType: expInstitution,
                              startDate: expStartDate,
                              endDate: expEndDate,
                              scope: expScope,
                              format: expFormat,
                              buses: buses,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.download_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text('Download ${expFormat.toUpperCase()} Audit Report', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDateChip(String label, String s, String e, String currentS, String currentE, Function(String, String) onSelect) {
    final isSelected = currentS == s && currentE == e;
    return InkWell(
      onTap: () => onSelect(s, e),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatCard(String format, String label, IconData icon, Color color, String currentFormat, Function(String) onSelect) {
    final isSelected = currentFormat == format;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(format),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.08) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: isSelected ? color : const Color(0xFF64748B)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : const Color(0xFF334155),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleExportReport({
    required String busId,
    String? institutionType,
    required String startDate,
    required String endDate,
    required String scope,
    required String format,
    required List<Map<String, dynamic>> buses,
  }) async {
    setState(() => _isExporting = true);
    AppSnackBar.showInfo(context, 'Generating ${format.toUpperCase()} report from server...');

    try {
      final api = ref.read(apiClientProvider);
      final queryParams = {
        'startDate': startDate,
        'endDate': endDate,
        if (busId.isNotEmpty) 'busId': busId,
        if (institutionType != null && institutionType.isNotEmpty && institutionType != 'All') 'institutionType': institutionType,
        'format': format,
        'crossBusOnly': scope == 'crossBus',
        'mismatchOnly': scope == 'mismatch',
        'geoDeviationOnly': scope == 'geoDeviation',
        'beforeStopOnly': scope == 'beforeStop',
        'afterStopOnly': scope == 'afterStop',
      };

      final response = await api.exportAdminReport(query: queryParams);
      final bytes = response.data;

      if (bytes != null && bytes.isNotEmpty) {
        final targetBus = buses.firstWhere((b) => b['id']?.toString() == busId, orElse: () => {});
        final busTag = targetBus.isNotEmpty ? '_${targetBus['bus_number']}' : '_all_buses';
        final fileName = 'audit_report${busTag}_${startDate}_to_$endDate.${format == 'excel' ? 'xlsx' : format}';

        if (format == 'pdf') {
          await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: fileName);
        } else {
          // For Excel/CSV, trigger share sheet
          await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: fileName);
        }
        if (mounted) {
          AppSnackBar.showSuccess(context, 'Audit report generated and ready!');
        }
      } else {
        throw 'Empty report data received';
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Report export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auditReportsAsync = ref.watch(adminAuditReportsProvider);
    final reportsAsync = ref.watch(adminReportsProvider);
    final thresholdsAsync = ref.watch(adminThresholdsProvider);
    final auditLogsAsync = ref.watch(adminAuditLogsProvider);

    return RefreshIndicator(
      color: AppTheme.primaryAccent,
      onRefresh: () async {
        ref.invalidate(adminAuditReportsProvider);
        ref.invalidate(adminReportsProvider);
        ref.invalidate(adminThresholdsProvider);
        ref.invalidate(adminAuditLogsProvider);
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Segmented Sub-Navbar (4 Modes)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TabPillButton(
                        title: 'Audit Reports',
                        icon: Icons.fact_check_rounded,
                        isSelected: _viewMode == 0,
                        onTap: () => setState(() => _viewMode = 0),
                      ),
                      const SizedBox(width: 8),
                      _TabPillButton(
                        title: 'Analytics',
                        icon: Icons.analytics_rounded,
                        isSelected: _viewMode == 1,
                        onTap: () => setState(() => _viewMode = 1),
                      ),
                      const SizedBox(width: 8),
                      _TabPillButton(
                        title: 'Risk Rules',
                        icon: Icons.tune_rounded,
                        isSelected: _viewMode == 2,
                        onTap: () => setState(() => _viewMode = 2),
                      ),
                      const SizedBox(width: 8),
                      _TabPillButton(
                        title: 'Audit Logs',
                        icon: Icons.security_rounded,
                        isSelected: _viewMode == 3,
                        onTap: () => setState(() => _viewMode = 3),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              Expanded(
                child: _viewMode == 0
                    ? _buildAuditReportsView(auditReportsAsync)
                    : _viewMode == 1
                        ? _buildAnalyticsView(reportsAsync)
                        : _viewMode == 2
                            ? _buildThresholdsView(thresholdsAsync)
                            : _buildAuditLogsView(auditLogsAsync),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuditReportsView(AsyncValue<Map<String, dynamic>> auditReportsAsync) {
    final filters = ref.watch(adminAuditReportsFiltersProvider);
    final buses = ref.watch(adminBusesProvider).valueOrNull ?? [];

    final selectedBusId = filters['busId']?.toString() ?? '';
    final selectedInst = filters['institutionType']?.toString() ?? 'All';
    final startDate = filters['startDate']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final endDate = filters['endDate']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final crossBusOnly = filters['crossBusOnly'] == true;
    final mismatchOnly = filters['mismatchOnly'] == true;
    final geoDeviationOnly = filters['geoDeviationOnly'] == true;
    final beforeStopOnly = filters['beforeStopOnly'] == true;
    final afterStopOnly = filters['afterStopOnly'] == true;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Export Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FeatureIconBadge(
                      icon: Icons.fact_check_rounded,
                      color: Color(0xFF2563EB),
                      size: 38,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transit & Geofence Audit',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                          Text(
                            'Cross-Bus, Stop Deviations & GPS Offsets',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Export Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _openExportModal(context),
                    icon: _isExporting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      _isExporting ? 'Generating Report...' : 'Export Audit Report (PDF / Excel)',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Filters Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bus Dropdown
                Row(
                  children: [
                    const Icon(Icons.directions_bus_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    const Text('Bus Fleet Filter:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedBusId,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All Fleet Buses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        ...buses.map((b) => DropdownMenuItem(
                              value: b['id']?.toString() ?? '',
                              child: Text('${b['bus_number']} (${b['route_name'] ?? 'Route'})', style: const TextStyle(fontSize: 12)),
                            )),
                      ],
                      onChanged: (val) {
                        ref.read(adminAuditReportsFiltersProvider.notifier).update((p) => {
                              ...p,
                              'busId': val ?? '',
                              'page': 1,
                            });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Institution Stream Filter Chips
                Row(
                  children: [
                    const Icon(Icons.school_rounded, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    const Text('Institution Stream:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Engineering', 'Arts & Science', 'Pharmacy', 'Polytechnic', 'Nursing', 'Management'].map((inst) {
                      final isSel = selectedInst == inst;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(inst, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w800 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.textPrimary)),
                          selected: isSel,
                          selectedColor: const Color(0xFF1E40AF),
                          backgroundColor: const Color(0xFFF1F5F9),
                          checkmarkColor: Colors.white,
                          onSelected: (_) {
                            ref.read(adminAuditReportsFiltersProvider.notifier).update((p) => {
                                  ...p,
                                  'institutionType': inst,
                                  'page': 1,
                                });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 10),

                // Date Picker Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(startDate) ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            final formatted = DateFormat('yyyy-MM-dd').format(picked);
                            ref.read(adminAuditReportsFiltersProvider.notifier).update((p) => {
                                  ...p,
                                  'startDate': formatted,
                                  'page': 1,
                                });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(startDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(endDate) ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            final formatted = DateFormat('yyyy-MM-dd').format(picked);
                            ref.read(adminAuditReportsFiltersProvider.notifier).update((p) => {
                                  ...p,
                                  'endDate': formatted,
                                  'page': 1,
                                });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(endDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Deviation Quick Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Records', style: TextStyle(fontSize: 11)),
                        selected: !crossBusOnly && !mismatchOnly && !geoDeviationOnly && !beforeStopOnly && !afterStopOnly,
                        selectedColor: const Color(0xFF1E40AF),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: (!crossBusOnly && !mismatchOnly && !geoDeviationOnly && !beforeStopOnly && !afterStopOnly) ? Colors.white : AppTheme.textPrimary,
                          fontWeight: (!crossBusOnly && !mismatchOnly && !geoDeviationOnly && !beforeStopOnly && !afterStopOnly) ? FontWeight.w800 : FontWeight.w500,
                        ),
                        checkmarkColor: Colors.white,
                        onSelected: (_) {
                          ref.read(adminAuditReportsFiltersProvider.notifier).update((p) => {
                                ...p,
                                'crossBusOnly': false,
                                'mismatchOnly': false,
                                'geoDeviationOnly': false,
                                'beforeStopOnly': false,
                                'afterStopOnly': false,
                                'page': 1,
                              });
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Cross-Bus Only', style: TextStyle(fontSize: 11)),
                        selected: crossBusOnly,
                        selectedColor: const Color(0xFFDC2626),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: crossBusOnly ? Colors.white : const Color(0xFF991B1B),
                          fontWeight: crossBusOnly ? FontWeight.w800 : FontWeight.w500,
                        ),
                        checkmarkColor: Colors.white,
                        onSelected: (val) {
                          ref.read(adminAuditReportsFiltersProvider.notifier).update((p) => {
                                ...p,
                                'crossBusOnly': val,
                                'mismatchOnly': false,
                                'geoDeviationOnly': false,
                                'beforeStopOnly': false,
                                'afterStopOnly': false,
                                'page': 1,
                              });
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Stop Deviations', style: TextStyle(fontSize: 11)),
                        selected: mismatchOnly,
                        selectedColor: const Color(0xFFD97706),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: mismatchOnly ? Colors.white : const Color(0xFF92400E),
                          fontWeight: mismatchOnly ? FontWeight.w800 : FontWeight.w500,
                        ),
                        checkmarkColor: Colors.white,
                        onSelected: (val) {
                          ref.read(adminAuditReportsFiltersProvider.notifier).update((p) => {
                                ...p,
                                'mismatchOnly': val,
                                'crossBusOnly': false,
                                'geoDeviationOnly': false,
                                'beforeStopOnly': false,
                                'afterStopOnly': false,
                                'page': 1,
                              });
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Deviated Distance', style: TextStyle(fontSize: 11)),
                        selected: geoDeviationOnly,
                        selectedColor: const Color(0xFFEA580C),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: geoDeviationOnly ? Colors.white : const Color(0xFF9A3412),
                          fontWeight: geoDeviationOnly ? FontWeight.w800 : FontWeight.w500,
                        ),
                        checkmarkColor: Colors.white,
                        onSelected: (val) {
                          ref.read(adminAuditReportsFiltersProvider.notifier).update((p) => {
                                ...p,
                                'geoDeviationOnly': val,
                                'crossBusOnly': false,
                                'mismatchOnly': false,
                                'beforeStopOnly': false,
                                'afterStopOnly': false,
                                'page': 1,
                              });
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Before Stop', style: TextStyle(fontSize: 11)),
                        selected: beforeStopOnly,
                        selectedColor: const Color(0xFFB45309),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: beforeStopOnly ? Colors.white : const Color(0xFF78350F),
                          fontWeight: beforeStopOnly ? FontWeight.w800 : FontWeight.w500,
                        ),
                        checkmarkColor: Colors.white,
                        onSelected: (val) {
                          ref.read(adminAuditReportsFiltersProvider.notifier).update((p) => {
                                ...p,
                                'beforeStopOnly': val,
                                'crossBusOnly': false,
                                'mismatchOnly': false,
                                'geoDeviationOnly': false,
                                'afterStopOnly': false,
                                'page': 1,
                              });
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('After Stop', style: TextStyle(fontSize: 11)),
                        selected: afterStopOnly,
                        selectedColor: const Color(0xFFE11D48),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: afterStopOnly ? Colors.white : const Color(0xFF9F1239),
                          fontWeight: afterStopOnly ? FontWeight.w800 : FontWeight.w500,
                        ),
                        checkmarkColor: Colors.white,
                        onSelected: (val) {
                          ref.read(adminAuditReportsFiltersProvider.notifier).update((p) => {
                                ...p,
                                'afterStopOnly': val,
                                'crossBusOnly': false,
                                'mismatchOnly': false,
                                'geoDeviationOnly': false,
                                'beforeStopOnly': false,
                                'page': 1,
                              });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Audit Feed / Content
          auditReportsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: AppTheme.primaryAccent),
              ),
            ),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(16)),
              child: Text('Failed to load audit records: $e', style: const TextStyle(color: AppTheme.danger)),
            ),
            data: (repData) {
              final rawRows = repData['data'] ?? repData['rows'] ?? [];
              final List<Map<String, dynamic>> rows = rawRows is List ? List<Map<String, dynamic>>.from(rawRows) : [];

              final totalScans = rows.length;
              final crossBusCount = rows.where((r) => r['is_cross_bus_boarding'] == true || (r['cross_bus_status'] == 'CROSS-BUS') || (r['assigned_bus_id'] != null && r['assigned_bus_id'] != r['boarded_bus_id'])).length;
              final stopDevCount = rows.where((r) => r['is_stage_mismatch'] == true || r['stage_match_status'] == 'MISMATCH').length;
              final beforeCount = rows.where((r) => r['deviation_direction'] == 'BEFORE_STOP').length;
              final afterCount = rows.where((r) => r['deviation_direction'] == 'AFTER_STOP').length;
              final inGeofenceCount = rows.where((r) => r['is_inside_geofence'] == true || r['geo_status'] == 'IN_GEOFENCE').length;
              final geofenceRate = totalScans > 0 ? ((inGeofenceCount / totalScans) * 100).toStringAsFixed(0) : '100';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 4 Mini KPI Cards
                  Row(
                    children: [
                      _buildAuditKpiCard('Total Logs', '$totalScans', Icons.qr_code_scanner_rounded, const Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      _buildAuditKpiCard('Cross-Bus', '$crossBusCount', Icons.shuffle_rounded, const Color(0xFFDC2626)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildAuditKpiCard('Stop Dev', '$stopDevCount', Icons.warning_amber_rounded, const Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      _buildAuditKpiCard(
                        beforeCount > 0 || afterCount > 0 ? 'Before / After' : 'In Geofence',
                        beforeCount > 0 || afterCount > 0 ? '${beforeCount}B / ${afterCount}A' : '$geofenceRate%',
                        beforeCount > 0 || afterCount > 0 ? Icons.swap_horiz_rounded : Icons.gps_fixed_rounded,
                        const Color(0xFF059669),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Audit Records Feed (${rows.length})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Showing matching scans',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (rows.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.fact_check_outlined, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 10),
                          Text('No Transit Attendance Records Found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF334155))),
                          SizedBox(height: 4),
                          Text('Try adjusting the date range or filter criteria.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final studentName = row['student_name'] ?? 'Student';
                        final rollNo = row['roll_number'] ?? '—';
                        final dept = row['department'] ?? 'Dept';
                        final inst = row['institution_type'] ?? row['institutionType'] ?? 'Engineering';
                        final assignedBus = row['assigned_bus_number'] ?? '—';
                        final boardedBus = row['boarded_bus_number'] ?? row['bus_number'] ?? '—';
                        final isCrossBus = row['is_cross_bus_boarding'] == true || (row['cross_bus_status'] == 'CROSS-BUS') || (row['assigned_bus_id'] != null && row['assigned_bus_id'] != row['boarded_bus_id']);

                        final assignedStage = row['assigned_stage_name'] ?? 'Assigned Stop';
                        final boardedStage = row['boarded_stage_name'] ?? row['stage_name'] ?? 'Boarded Stop';
                        final isMismatch = row['is_stage_mismatch'] == true || (row['stage_match_status'] == 'MISMATCH');

                        final isInsideGeo = row['is_inside_geofence'] == true || row['geo_status'] == 'IN_GEOFENCE';
                        final devDir = (row['deviation_direction'] ?? '').toString();
                        final devLabel = (row['deviation_label'] ?? row['geo_desc'] ?? '').toString();
                        final distMeters = row['distance_meters'] ?? row['distance_from_stage_meters'];
                        final distText = distMeters != null ? '${double.tryParse(distMeters.toString())?.toStringAsFixed(0) ?? distMeters}m' : '';

                        final status = (row['status'] ?? 'present').toString().toUpperCase();
                        final markedAt = row['marked_at'] != null ? PdfReportService.formatTo12Hour(row['marked_at']) : '—';
                        final markedDate = row['date'] != null ? PdfReportService.formatToDDMMYYYY(row['date']) : 'Today';
                        final inchargeName = row['incharge_name'] ?? 'Faculty Incharge';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCrossBus ? const Color(0xFFFCA5A5) : isMismatch ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                              width: (isCrossBus || isMismatch) ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Student Row & Status
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isCrossBus ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                                    child: Text(
                                      studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: isCrossBus ? const Color(0xFFDC2626) : const Color(0xFF1E40AF),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(studentName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                                        Text('$rollNo • $dept • $inst', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: status == 'PRESENT' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                        color: status == 'PRESENT' ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 10),

                              // Bus Row with Cross-Bus Badge
                              Row(
                                children: [
                                  const Icon(Icons.directions_bus_rounded, size: 14, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isCrossBus ? '$assignedBus  ->  $boardedBus' : 'Bus: $boardedBus',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isCrossBus ? FontWeight.w800 : FontWeight.w600,
                                        color: isCrossBus ? const Color(0xFFDC2626) : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  if (isCrossBus)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFFCA5A5)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.shuffle_rounded, size: 10, color: Color(0xFFDC2626)),
                                          SizedBox(width: 3),
                                          Text('CROSS-BUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                                        ],
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // Stage Row with Stop Mismatch Badge
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFD97706)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isMismatch ? '$assignedStage  ->  $boardedStage' : 'Stop: $boardedStage',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isMismatch ? FontWeight.w800 : FontWeight.w500,
                                        color: isMismatch ? const Color(0xFFB45309) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  if (isMismatch)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded, size: 10, color: Color(0xFFD97706)),
                                          SizedBox(width: 3),
                                          Text('STOP DEV', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                                        ],
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Stop Offset & Direction Pill (Clean Icons, NO EMOJIS)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: devDir == 'BEFORE_STOP'
                                          ? const Color(0xFFFEF3C7)
                                          : devDir == 'AFTER_STOP'
                                              ? const Color(0xFFFEE2E2)
                                              : isInsideGeo
                                                  ? const Color(0xFFECFDF5)
                                                  : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: devDir == 'BEFORE_STOP'
                                            ? const Color(0xFFFDE68A)
                                            : devDir == 'AFTER_STOP'
                                                ? const Color(0xFFFCA5A5)
                                                : isInsideGeo
                                                    ? const Color(0xFFA7F3D0)
                                                    : const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          devDir == 'BEFORE_STOP'
                                              ? Icons.fast_rewind_rounded
                                              : devDir == 'AFTER_STOP'
                                                  ? Icons.fast_forward_rounded
                                                  : isInsideGeo
                                                      ? Icons.check_circle_rounded
                                                      : Icons.near_me_rounded,
                                          size: 11,
                                          color: devDir == 'BEFORE_STOP'
                                              ? const Color(0xFFD97706)
                                              : devDir == 'AFTER_STOP'
                                                  ? const Color(0xFFDC2626)
                                                  : isInsideGeo
                                                      ? const Color(0xFF059669)
                                                      : const Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          devLabel.isNotEmpty
                                              ? devLabel
                                              : (isInsideGeo
                                                  ? 'On-Stop ($distText)'
                                                  : (distText.isNotEmpty ? '$distText Off-Stop' : 'GPS Scan')),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: devDir == 'BEFORE_STOP'
                                                ? const Color(0xFF92400E)
                                                : devDir == 'AFTER_STOP'
                                                    ? const Color(0xFF991B1B)
                                                    : isInsideGeo
                                                        ? const Color(0xFF065F46)
                                                        : const Color(0xFF92400E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$markedDate • $markedAt • $inchargeName',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAuditKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
                  Text(title, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsView(AsyncValue<Map<String, dynamic>> reportsAsync) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              FeatureIconBadge(
                icon: Icons.analytics_rounded,
                color: AppTheme.primaryAccent,
                size: 36,
                iconSize: 20,
              ),
              SizedBox(width: 10),
              Text(
                'Attendance Analytics & Trends',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          reportsAsync.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: AppTheme.primaryAccent),
            )),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(16)),
              child: Text('Analytics error: $e', style: const TextStyle(color: AppTheme.danger)),
            ),
            data: (rep) {
              final overallRate = double.tryParse(rep['overallRate']?.toString() ?? '0') ?? 0.0;
              final totalRecords = rep['totalRecords'] ?? 0;
              final totalAbsences = rep['totalAbsences'] ?? 0;

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Campus Attendance Benchmark', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
                        Text('${overallRate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E40AF))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: overallRate / 100,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E40AF)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Total Logs: $totalRecords', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ),
                        Expanded(
                          child: Text('Total Absences: $totalAbsences', style: const TextStyle(fontSize: 12, color: AppTheme.danger, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildThresholdsView(AsyncValue<Map<String, dynamic>> thresholdsAsync) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              FeatureIconBadge(
                icon: Icons.tune_rounded,
                color: AppTheme.secondary,
                size: 36,
                iconSize: 20,
              ),
              SizedBox(width: 10),
              Text(
                'Attendance Risk Thresholds',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          thresholdsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
            error: (e, _) => const SizedBox.shrink(),
            data: (thresh) {
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configure automatic risk triggers for campus incharge alerts',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _consecutiveCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Consecutive Absences Alert (Days)',
                        prefixIcon: Icon(Icons.person_off_rounded, color: AppTheme.textMuted),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lowRateCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Low Attendance Threshold (%)',
                        prefixIcon: Icon(Icons.percent_rounded, color: AppTheme.textMuted),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() => _isSaving = true);
                                try {
                                  final api = ref.read(apiClientProvider);
                                  await api.updateAdminThresholds({
                                    'consecutiveWarning': int.tryParse(_consecutiveCtrl.text) ?? 3,
                                    'consecutiveInchargeNotify': int.tryParse(_consecutiveCtrl.text) ?? 3,
                                    'consecutiveAdminNotify': 5,
                                    'lowAttendancePercentage': double.tryParse(_lowRateCtrl.text) ?? 75.0,
                                  });
                                  if (context.mounted) {
                                    AppSnackBar.showSuccess(context, 'Threshold settings updated successfully!');
                                  }
                                  ref.invalidate(adminThresholdsProvider);
                                  ref.invalidate(adminDashboardProvider);
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackBar.showError(context, 'Failed to save settings: $e');
                                  }
                                } finally {
                                  if (mounted) setState(() => _isSaving = false);
                                }
                              },
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded),
                        label: Text(_isSaving ? 'Saving...' : 'Save Risk Rules'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAuditLogsView(AsyncValue<List<Map<String, dynamic>>> auditLogsAsync) {
    final actionsList = ['All', 'INSERT', 'UPDATE', 'DELETE', 'EXPORT', 'LOGIN'];
    final tablesList = ['All', 'students', 'attendance', 'users', 'buses', 'absence_thresholds'];

    return Column(
      children: [
        // Action & Table Filter Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Action Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: actionsList.map((act) {
                    final isSel = _selectedActionFilter == act;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(act, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w800 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.textPrimary)),
                        selected: isSel,
                        selectedColor: const Color(0xFF1E40AF),
                        backgroundColor: const Color(0xFFF1F5F9),
                        checkmarkColor: Colors.white,
                        onSelected: (_) => setState(() => _selectedActionFilter = act),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),
              // Table Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: tablesList.map((tbl) {
                    final isSel = _selectedTableFilter == tbl;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(tbl, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w800 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.textPrimary)),
                        selected: isSel,
                        selectedColor: AppTheme.secondary,
                        backgroundColor: const Color(0xFFF1F5F9),
                        checkmarkColor: Colors.white,
                        onSelected: (_) => setState(() => _selectedTableFilter = tbl),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        Expanded(
          child: auditLogsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
            error: (e, _) => Center(child: Text('Audit log error: $e')),
            data: (logs) {
              final filtered = logs.where((l) {
                final action = (l['action'] ?? '').toString().toUpperCase();
                final table = (l['table_name'] ?? '').toString().toLowerCase();

                final matchAction = _selectedActionFilter == 'All' || action == _selectedActionFilter;
                final matchTable = _selectedTableFilter == 'All' || table == _selectedTableFilter.toLowerCase();
                return matchAction && matchTable;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('No audit log records found', style: TextStyle(color: AppTheme.textSecondary)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final log = filtered[index];
                  final action = (log['action'] ?? 'ACTION').toString();
                  final table = (log['table_name'] ?? 'table').toString();
                  final performedBy = log['performed_by_email'] ?? 'System';
                  final timestamp = log['performed_at'] ?? '';
                  final color = _getActionColor(action);

                  return InkWell(
                    onTap: () => _showLogDetails(log),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Text(
                              action,
                              style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Table: $table',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'By $performedBy • $timestamp',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Helper UI Badges and Tab Pill
// ============================================================

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _TabPillButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;

  const _TabPillButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E40AF).withOpacity(0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.25) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// KPI Grid & Live Bus Card Widgets
// ============================================================

class _KpiGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  const _KpiGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final activeBuses = data['activeBuses'] ?? data['activeBusesCount'] ?? data['active_buses'] ?? 0;
    final totalBuses = data['totalBuses'] ?? data['totalBusesCount'] ?? data['total_buses'] ?? 0;
    final todayBoarded = data['presentToday'] ?? data['todayBoardedCount'] ?? data['today_boarded'] ?? 0;
    final totalStudents = data['totalStudents'] ?? data['totalStudentsCount'] ?? data['total_students'] ?? 0;
    final dynamic rawRate = data['overallAttendanceRate'] ?? data['attendanceRate'] ?? data['attendance_rate'];
    final double rate = double.tryParse(rawRate?.toString() ?? '100') ?? 100.0;
    final activeTrips = data['activeSessions'] ?? data['activeTripsCount'] ?? data['active_trips'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Active Buses',
                value: '$activeBuses / $totalBuses',
                subtitle: '$activeTrips Trips Running',
                icon: Icons.directions_bus_rounded,
                color: AppTheme.primaryAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Students Boarded',
                value: '$todayBoarded',
                subtitle: 'Out of $totalStudents Enrolled',
                icon: Icons.people_alt_rounded,
                color: AppTheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Campus Attendance',
                value: '${rate.toStringAsFixed(1)}%',
                subtitle: rate >= 75 ? 'Safe Optimal Rate' : 'Needs Review',
                icon: Icons.donut_large_rounded,
                color: rate >= 75 ? AppTheme.success : AppTheme.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'System Health',
                value: '100% Live',
                subtitle: 'All Systems Operational',
                icon: Icons.cloud_done_rounded,
                color: const Color(0xFF059669),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LiveBusCard extends StatelessWidget {
  final Map<String, dynamic> bus;
  const _LiveBusCard({required this.bus});

  @override
  Widget build(BuildContext context) {
    final busNo = bus['bus_number'] ?? 'Bus';
    final route = bus['route_name'] ?? 'Route';
    final incharge = bus['incharge_name'] ?? 'Incharge';
    final phone = bus['incharge_phone']?.toString();
    final tripType = (bus['trip_type'] ?? 'morning').toString();
    final direction = (bus['trip_direction'] ?? 'pickup').toString();
    final stage = bus['current_stage'] ?? bus['current_stage_name'] ?? bus['last_stage'] ?? 'Depot';
    final status = (bus['trip_status'] ?? bus['status'] ?? 'active').toString();
    final present = bus['present_count']?.toString() ?? '0';
    final absent = bus['absent_count']?.toString() ?? '0';
    final lat = bus['last_lat'];
    final lon = bus['last_lon'];

    final isActive = status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Bus No, Route, Status Chip
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                ),
                child: Icon(
                  Icons.directions_bus_rounded,
                  color: isActive ? const Color(0xFF059669) : const Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      busNo.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                    ),
                    Text(
                      route.toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isActive ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Badges (Category & Direction)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: tripType.toLowerCase() == 'morning' ? const Color(0xFFEFF6FF) : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tripType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: tripType.toLowerCase() == 'morning' ? const Color(0xFF2563EB) : const Color(0xFF7C3AED),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  direction.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF2563EB)),
                    const SizedBox(width: 3),
                    Text(
                      stage.toString(),
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          // Row 3: Incharge info & Present/Absent Pills
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            incharge.toString(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (phone != null && phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 18, top: 1),
                        child: Text(
                          phone,
                          style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              // Boarded Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF059669)),
                    const SizedBox(width: 3),
                    Text(
                      '$present Boarded',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Absent Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel_rounded, size: 11, color: Color(0xFFDC2626)),
                    const SizedBox(width: 3),
                    Text(
                      '$absent Absent',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (lat != null && lon != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.gps_fixed_rounded, size: 11, color: Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text(
                  'GPS: $lat, $lon',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiGridSkeleton extends StatelessWidget {
  const _KpiGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
