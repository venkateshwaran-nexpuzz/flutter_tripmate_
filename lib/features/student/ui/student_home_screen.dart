import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_language_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/student_provider.dart';

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(studentProfileProvider);
    final todayAsync = ref.watch(studentTodayAttendanceProvider);
    final statsAsync = ref.watch(studentAttendanceStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const VetBrandLogo(size: 34, compact: true),
        actions: [
          const Center(
            child: AppLanguageButton(compact: true),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => context.push('/student/profile'),
            icon: const Icon(Icons.account_circle_outlined, color: AppTheme.primaryAccent),
            tooltip: 'Student Profile & Bus Pass',
          ),
          IconButton(
            onPressed: () async {
              await ref.globalAction(() async {
                await ref.read(authStateProvider.notifier).logout();
              },
              message: 'Logging out from Student Portal...',
              context: context,
              );
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryAccent,
        onRefresh: () async {
          ref.invalidate(studentProfileProvider);
          ref.invalidate(studentTodayAttendanceProvider);
          ref.invalidate(studentAttendanceStatsProvider);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Student Profile Header (Royal Blue Gradient Banner)
                  profileAsync.when(
                    loading: () => const _HeaderSkeleton(),
                    error: (e, _) => _buildErrorBanner('Welcome Student'),
                    data: (profile) => _StudentProfileCard(profile: profile),
                  ),

                  const SizedBox(height: 16),

                  // 2. WHERE IS MY BUS? (PRIMARY LIVE GPS TRACKING ACTION CARD)
                  _WhereIsMyBusCard(profileAsync: profileAsync),

                  const SizedBox(height: 16),

                  // 3. Transport & Assigned Bus Stop Card
                  profileAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (profile) => _AssignedInfoCard(profile: profile),
                  ),

                  const SizedBox(height: 20),

                  // 4. Today's Attendance Status with Live Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          FeatureIconBadge(
                            icon: Icons.today_rounded,
                            color: AppTheme.primaryAccent,
                            size: 32,
                            iconSize: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Today's Attendance",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 13, color: Color(0xFF1E40AF)),
                            const SizedBox(width: 5),
                            Text(
                              DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  todayAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                    error: (e, _) => Center(child: Text('Failed to load status: $e')),
                    data: (records) => _TodayAttendanceSection(records: records),
                  ),

                  const SizedBox(height: 24),

                  // 5. Attendance Performance & Rate Breakdown Grid
                  const Row(
                    children: [
                      FeatureIconBadge(
                        icon: Icons.analytics_rounded,
                        color: AppTheme.secondary,
                        size: 32,
                        iconSize: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Attendance & Absence Rate",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  statsAsync.when(
                    loading: () => const _StatsGridSkeleton(),
                    error: (e, _) => Center(child: Text('Failed to load stats: $e')),
                    data: (stats) => _QuickStatsGrid(stats: stats),
                  ),

                  const SizedBox(height: 24),

                  // 6. Navigation Actions (History & Visual Analytics)
                  Row(
                    children: [
                      Expanded(
                        child: _MenuActionCard(
                          title: 'Attendance History',
                          subtitle: 'View date-wise logs',
                          icon: Icons.history_edu_rounded,
                          color: AppTheme.primaryAccent,
                          onTap: () => context.push('/student/history'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MenuActionCard(
                          title: 'Visual Analytics',
                          subtitle: 'Charts & streak report',
                          icon: Icons.pie_chart_rounded,
                          color: AppTheme.secondary,
                          onTap: () => context.push('/student/stats'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildErrorBanner(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E40AF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  static void _showStudentProfileModal(BuildContext context, Map<String, dynamic>? profile) {
    if (profile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const FeatureIconBadge(
                    icon: Icons.badge_rounded,
                    color: AppTheme.primaryAccent,
                    size: 42,
                    iconSize: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile['name'] ?? 'Student Profile',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                        Text(
                          'Roll No: ${profile['roll_number'] ?? '—'} • ${profile['department'] ?? 'VET Student'}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _ProfileDetailRow(label: 'Institution / Stream', value: profile['institution_type'] ?? 'Engineering', icon: Icons.account_balance_rounded),
                    const Divider(height: 14),
                    _ProfileDetailRow(label: 'Year of Study', value: profile['year_of_study'] ?? '1st Year', icon: Icons.calendar_today_rounded),
                    const Divider(height: 14),
                    _ProfileDetailRow(label: 'Department', value: profile['department'] ?? 'General', icon: Icons.school_rounded),
                    const Divider(height: 14),
                    _ProfileDetailRow(label: 'Email Address', value: profile['email'] ?? '—', icon: Icons.email_outlined),
                    const Divider(height: 14),
                    _ProfileDetailRow(label: 'Student Phone', value: profile['phone'] ?? 'Not added', icon: Icons.phone_android_rounded),
                    const Divider(height: 14),
                    _ProfileDetailRow(label: 'Parent Contact', value: profile['parent_phone'] ?? 'Not added', icon: Icons.contact_phone_outlined),
                    const Divider(height: 14),
                    _ProfileDetailRow(label: 'Assigned Bus', value: profile['bus_number'] ?? 'Not assigned', icon: Icons.directions_bus_rounded),
                    const Divider(height: 14),
                    _ProfileDetailRow(label: 'Bus Route', value: profile['route_name'] ?? 'Not assigned', icon: Icons.alt_route_rounded),
                    const Divider(height: 14),
                    _ProfileDetailRow(label: 'Boarding Stage', value: profile['stage_name'] ?? 'Not assigned', icon: Icons.pin_drop_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Close Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
// Student Profile Card
// ============================================================

class _StudentProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _StudentProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final inst = profile['institution_type'] ?? 'Engineering';
    final year = profile['year_of_study'] ?? '1st Year';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => StudentHomeScreen._showStudentProfileModal(context, profile),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: const Center(
                  child: Icon(Icons.school_rounded, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile['name'] ?? 'Student',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'STUDENT',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Roll No: ${profile['roll_number']} • $inst ($year)',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Dept: ${profile['department'] ?? 'General'}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
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
// Assigned Info Card (Bus & Route)
// ============================================================

class _AssignedInfoCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _AssignedInfoCard({required this.profile});

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
                'Assigned Transport & Stop',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(icon: Icons.directions_bus_outlined, label: 'Bus Number', value: profile['bus_number'] ?? 'Not Assigned', iconColor: AppTheme.primaryAccent),
          _DetailRow(icon: Icons.alt_route_rounded, label: 'Route Name', value: profile['route_name'] ?? 'Not Assigned', iconColor: AppTheme.secondary),
          _DetailRow(icon: Icons.pin_drop_outlined, label: 'Boarding Stop', value: profile['stage_name'] ?? 'Not Assigned', iconColor: AppTheme.warning),
          if (profile['expected_boarding_time'] != null)
            _DetailRow(icon: Icons.schedule_rounded, label: 'Pickup Time', value: profile['expected_boarding_time'], iconColor: AppTheme.success),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/student/track-bus'),
              icon: const Icon(Icons.navigation_rounded, size: 16),
              label: const Text('Track Bus Live on Map', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhereIsMyBusCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> profileAsync;

  const _WhereIsMyBusCard({required this.profileAsync});

  @override
  Widget build(BuildContext context) {
    final busNo = profileAsync.value?['bus_number'];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/student/track-bus'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.navigation_rounded,
                      color: Color(0xFF1E40AF),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Where is My Bus?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'LIVE GPS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        busNo != null
                            ? 'Track Bus $busNo live on map • 35s arrival ETA'
                            : 'Open live map to track your assigned bus',
                        style: const TextStyle(
                          color: Color(0xFFE0E7FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color iconColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppTheme.primaryAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            width: 105,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Today Attendance Section
// ============================================================

class _TodayAttendanceSection extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _TodayAttendanceSection({required this.records});

  @override
  Widget build(BuildContext context) {
    final morning = records.firstWhere((r) => r['trip_type'] == 'morning' && r['attendance_type'] == 'boarding', orElse: () => {});
    final evening = records.firstWhere((r) => r['trip_type'] == 'evening' && r['attendance_type'] == 'exit', orElse: () => {});

    return Row(
      children: [
        Expanded(child: _StatusCard(title: 'Morning Boarding', record: morning, icon: Icons.wb_sunny_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _StatusCard(title: 'Evening Return', record: evening, icon: Icons.nights_stay_rounded)),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> record;
  final IconData icon;

  const _StatusCard({
    required this.title,
    required this.record,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final hasMarked = record.isNotEmpty;
    final isPresent = hasMarked && record['status'] == 'present';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasMarked
              ? (isPresent ? AppTheme.success : AppTheme.danger).withOpacity(0.4)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasMarked) ...[
            Row(
              children: [
                Icon(
                  isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 18,
                  color: isPresent ? AppTheme.success : AppTheme.danger,
                ),
                const SizedBox(width: 6),
                Text(
                  isPresent ? 'Present' : 'Absent',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isPresent ? AppTheme.success : AppTheme.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Time: ${record['marked_time'] ?? '—'}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            Text('Stop: ${record['stage_name'] ?? '—'}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                overflow: TextOverflow.ellipsis),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: AppTheme.warning),
                SizedBox(width: 6),
                Text('Pending', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.warning, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Scan stage QR to mark', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// Attendance & Absence Rate Grid
// ============================================================

class _QuickStatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _QuickStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rate = double.tryParse(stats['attendancePercentage']?.toString() ?? '') ??
        double.tryParse(stats['attendance_percentage']?.toString() ?? '') ??
        (stats['attendancePercentage'] is num ? (stats['attendancePercentage'] as num).toDouble() : 0.0);
    final presentDays = int.tryParse(stats['presentDays']?.toString() ?? '') ??
        int.tryParse(stats['present_days']?.toString() ?? '') ??
        (stats['presentDays'] is num ? (stats['presentDays'] as num).toInt() : 0);
    final absentDays = int.tryParse(stats['absentDays']?.toString() ?? '') ??
        int.tryParse(stats['absent_days']?.toString() ?? '') ??
        (stats['absentDays'] is num ? (stats['absentDays'] as num).toInt() : 0);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Attendance Rate',
            value: '${rate.toStringAsFixed(1)}%',
            icon: Icons.donut_large_rounded,
            color: rate >= 75 ? AppTheme.success : AppTheme.danger,
            subtitle: rate >= 75 ? 'Safe (>75%)' : 'Low (<75%)',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'Present Days',
            value: '$presentDays',
            icon: Icons.check_circle_outline_rounded,
            color: AppTheme.primaryAccent,
            subtitle: 'Boarded Trips',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'Absent Days',
            value: '$absentDays',
            icon: Icons.cancel_outlined,
            color: AppTheme.danger,
            subtitle: 'Missed Trips',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
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

class _MenuActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FeatureIconBadge(icon: icon, color: color, size: 40, iconSize: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final String label, value;
  final IconData icon;

  const _ProfileDetailRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryAccent),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  const _StatsGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
