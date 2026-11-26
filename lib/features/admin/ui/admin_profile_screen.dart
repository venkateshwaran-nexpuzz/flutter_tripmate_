import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_provider.dart';

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final dashboardAsync = ref.watch(adminDashboardProvider);

    final email = user?.email ?? 'admin@tripmate.edu';
    final name = email.contains('@') ? 'Administrator (${email.split('@').first})' : 'System Administrator';
    final role = (user?.role ?? 'ADMIN').toUpperCase();

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
          'Administrator Profile',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryAccent),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(adminDashboardProvider);
              AppSnackBar.showInfo(context, 'Admin stats refreshed');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryAccent,
        onRefresh: () async => ref.invalidate(adminDashboardProvider),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Admin Master Identity Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E40AF).withOpacity(0.35),
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
                                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 10),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'VET INSTITUTIONAL TRANSPORT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      'Executive Admin Console Lead',
                                      style: TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                role,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
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
                              child: const Icon(Icons.shield_rounded, size: 32, color: Colors.white),
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
                                  const Text(
                                    'Multi-Campus Transport Oversight',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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

                  // 2. System Scope & Managed Fleet Counters
                  const Text(
                    'Institutional Scope & Fleet Capacity',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  dashboardAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (data) {
                      final totalBuses = data['totalBuses'] ?? '—';
                      final activeBuses = data['activeBuses'] ?? '—';
                      final totalStudents = data['totalStudents'] ?? '—';
                      final todayAttendance = data['todayAttendance'] ?? '—';

                      return Container(
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
                              iconColor: const Color(0xFF1E40AF),
                              label: 'Total Fleet Buses Registered',
                              value: '$totalBuses Buses ($activeBuses Active Today)',
                            ),
                            const Divider(height: 20, color: Color(0xFFF1F5F9)),
                            _InfoRow(
                              icon: Icons.people_alt_rounded,
                              iconColor: const Color(0xFF059669),
                              label: 'Total Enrolled Students',
                              value: '$totalStudents Students Registered',
                            ),
                            const Divider(height: 20, color: Color(0xFFF1F5F9)),
                            _InfoRow(
                              icon: Icons.fact_check_rounded,
                              iconColor: const Color(0xFF7C3AED),
                              label: 'Today Total Boarding Scans',
                              value: '$todayAttendance Verified Check-ins',
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // 3. Security, Auditing & Access Control
                  const Text(
                    'Security, Auditing & Permissions',
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
                    child: const Column(
                      children: [
                        _InfoRow(
                          icon: Icons.security_rounded,
                          iconColor: Color(0xFFDC2626),
                          label: 'Access Clearance',
                          value: 'Super Administrator (Unrestricted CRUD)',
                        ),
                        Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _InfoRow(
                          icon: Icons.history_toggle_off_rounded,
                          iconColor: Color(0xFFD97706),
                          label: 'Audit Logging Engine',
                          value: 'Enabled (Automated IP & Diff Tracking)',
                        ),
                        Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _InfoRow(
                          icon: Icons.cloud_done_rounded,
                          iconColor: Color(0xFF059669),
                          label: 'Backend Synchronizer',
                          value: 'Connected & Healthy',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Global Action & Logout
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref.globalAction(() async {
                          await ref.read(authStateProvider.notifier).logout();
                        },
                        message: 'Ending Administrator session...',
                        context: context,
                        );
                        if (context.mounted) {
                          AppSnackBar.showSuccess(context, 'Admin session closed');
                          context.go('/login');
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign Out of Admin Console', style: TextStyle(fontWeight: FontWeight.w800)),
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
