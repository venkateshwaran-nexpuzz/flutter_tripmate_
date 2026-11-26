import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/student_provider.dart';

class AttendanceStatsScreen extends ConsumerWidget {
  const AttendanceStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(studentAttendanceStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Visual Analytics & Reports',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryAccent,
        onRefresh: () async {
          ref.invalidate(studentAttendanceStatsProvider);
        },
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
          error: (e, _) => Center(child: Text('Failed to load stats: $e')),
          data: (stats) {
            final present = double.tryParse(stats['presentDays']?.toString() ?? '') ?? (stats['presentDays'] is num ? (stats['presentDays'] as num).toDouble() : 0.0);
            final absent = double.tryParse(stats['absentDays']?.toString() ?? '') ?? (stats['absentDays'] is num ? (stats['absentDays'] as num).toDouble() : 0.0);
            final total = double.tryParse(stats['totalDays']?.toString() ?? '') ?? (stats['totalDays'] is num ? (stats['totalDays'] as num).toDouble() : 0.0);
            final pct = double.tryParse(stats['attendancePercentage']?.toString() ?? '') ?? (stats['attendancePercentage'] is num ? (stats['attendancePercentage'] as num).toDouble() : 100.0);
            final monthlyBreakdown = (stats['monthlyBreakdown'] as List?) ?? [];

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Overall Ring Chart Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 36,
                                  startDegreeOffset: -90,
                                  sections: [
                                    PieChartSectionData(
                                      color: AppTheme.success,
                                      value: present > 0 ? present : 0.001,
                                      title: '${present.toInt()}',
                                      radius: 18,
                                      titleStyle: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12),
                                    ),
                                    PieChartSectionData(
                                      color: AppTheme.danger,
                                      value: absent > 0 ? absent : 0.001,
                                      title: '${absent.toInt()}',
                                      radius: 18,
                                      titleStyle: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12),
                                    ),
                                    if (total == 0)
                                      PieChartSectionData(
                                        color: const Color(0xFFCBD5E1),
                                        value: 1,
                                        title: '0',
                                        radius: 18,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${pct.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: pct >= 75 ? AppTheme.success : AppTheme.danger,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (pct >= 75 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          pct >= 75 ? 'Safe Rate' : 'Low Attendance',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: pct >= 75 ? AppTheme.success : AppTheme.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Text('Overall Attendance Rate', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 12),
                                  _LegendRow(color: AppTheme.success, label: 'Present Days', value: '${present.toInt()} Days'),
                                  _LegendRow(color: AppTheme.danger, label: 'Absent Days', value: '${absent.toInt()} Days'),
                                  _LegendRow(color: AppTheme.primaryAccent, label: 'Total Tracked', value: '${total.toInt()} Days'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 2. Monthly Trend Chart Section
                      const Row(
                        children: [
                          FeatureIconBadge(
                            icon: Icons.bar_chart_rounded,
                            color: AppTheme.primaryAccent,
                            size: 32,
                            iconSize: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Monthly Attendance Trend',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (monthlyBreakdown.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Center(
                            child: Text('No monthly attendance data recorded yet', style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(18),
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
                            children: [
                              SizedBox(
                                height: 200,
                                child: BarChart(
                                  BarChartData(
                                    borderData: FlBorderData(show: false),
                                    gridData: const FlGridData(show: false),
                                    titlesData: FlTitlesData(
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index < 0 || index >= monthlyBreakdown.length) return const SizedBox.shrink();
                                            final month = monthlyBreakdown[index]['month'] as String? ?? '';
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Text(
                                                month.split(' ').first,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    barGroups: monthlyBreakdown.asMap().entries.map((e) {
                                      final index = e.key;
                                      final item = e.value as Map<String, dynamic>;
                                      final p = double.tryParse(item['present']?.toString() ?? '') ?? (item['present'] is num ? (item['present'] as num).toDouble() : 0.0);
                                      final a = double.tryParse(item['absent']?.toString() ?? '') ?? (item['absent'] is num ? (item['absent'] as num).toDouble() : 0.0);

                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(toY: p, color: AppTheme.success, width: 10, borderRadius: BorderRadius.circular(4)),
                                          BarChartRodData(toY: a, color: AppTheme.danger, width: 10, borderRadius: BorderRadius.circular(4)),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  _IndicatorRow(color: AppTheme.success, label: 'Present Days'),
                                  SizedBox(width: 20),
                                  _IndicatorRow(color: AppTheme.danger, label: 'Absent Days'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label, value;
  const _LegendRow({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  final Color color;
  final String label;
  const _IndicatorRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
      ],
    );
  }
}
