import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/student_provider.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends ConsumerState<AttendanceHistoryScreen> {
  DateTimeRange? _dateRange;
  String? _status;
  String? _attendanceType;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startStr = _dateRange != null ? DateFormat('yyyy-MM-dd').format(_dateRange!.start) : null;
    final endStr = _dateRange != null ? DateFormat('yyyy-MM-dd').format(_dateRange!.end) : null;

    final historyAsync = ref.watch(studentHistoryStateProvider(
      startDate: startStr,
      endDate: endStr,
      status: _status,
      attendanceType: _attendanceType,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Attendance History',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Filters Panel
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Column(
                  children: [
                    // Date picker trigger button
                    InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 20, color: AppTheme.primaryAccent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _dateRange == null
                                    ? 'Select Date Range'
                                    : '${DateFormat('dd MMM').format(_dateRange!.start)} – ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 22, color: AppTheme.textSecondary),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Dropdowns selection row
                    Row(
                      children: [
                        // Status select
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              labelText: 'Status',
                              labelStyle: const TextStyle(fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All Status', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'present', child: Text('Present', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'absent', child: Text('Absent', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (v) => setState(() => _status = v),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Type select
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _attendanceType,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              labelText: 'Trip Direction',
                              labelStyle: const TextStyle(fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All Trips', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'boarding', child: Text('Boarding', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'exit', child: Text('Return', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (v) => setState(() => _attendanceType = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // History records list view
              Expanded(
                child: historyAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                  error: (e, _) => Center(child: Text('Failed to load history: $e')),
                  data: (records) {
                    if (records.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.calendar_month_outlined, size: 36, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No attendance logs found',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Try selecting a different date range or filter',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    final presentCount = records.where((r) => r['status'] == 'present').length;
                    final absentCount = records.where((r) => r['status'] == 'absent').length;
                    final crossBusCount = records.where((r) => r['cross_bus_status'] == 'CROSS-BUS').length;
                    final totalCount = records.length;
                    final rate = totalCount > 0 ? ((presentCount / totalCount) * 100).toStringAsFixed(1) : '0.0';

                    return Column(
                      children: [
                        // KPI Summary Header (Present, Absent, Attendance Rate, Cross-Bus)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: _HistorySummaryPill(
                                  label: 'Present',
                                  value: '$presentCount',
                                  color: AppTheme.success,
                                  bgColor: const Color(0xFFDCFCE7),
                                  icon: Icons.check_circle_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _HistorySummaryPill(
                                  label: 'Absent',
                                  value: '$absentCount',
                                  color: AppTheme.danger,
                                  bgColor: const Color(0xFFFEE2E2),
                                  icon: Icons.cancel_rounded,
                                ),
                              ),
                              if (crossBusCount > 0) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _HistorySummaryPill(
                                    label: 'Cross-Bus',
                                    value: '$crossBusCount',
                                    color: const Color(0xFFB45309),
                                    bgColor: const Color(0xFFFEF3C7),
                                    icon: Icons.alt_route_rounded,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Expanded(
                                child: _HistorySummaryPill(
                                  label: 'Attendance',
                                  value: '$rate%',
                                  color: const Color(0xFF1E40AF),
                                  bgColor: const Color(0xFFEFF6FF),
                                  icon: Icons.pie_chart_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: records.length,
                            itemBuilder: (ctx, i) {
                              final r = records[i];
                              final isPresent = r['status'] == 'present';
                              final isCrossBus = r['cross_bus_status'] == 'CROSS-BUS';
                              final assignedBus = (r['assigned_bus_number'] ?? '').toString();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: (isPresent ? AppTheme.success : AppTheme.danger).withOpacity(0.35),
                                    width: 1.2,
                                  ),
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
                                    // Card header row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            FeatureIconBadge(
                                              icon: isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                              color: isPresent ? AppTheme.success : AppTheme.danger,
                                              size: 32,
                                              iconSize: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              r['date'] != null
                                                  ? DateFormat('dd MMM yyyy').format(DateTime.parse(r['date']))
                                                  : '—',
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isCrossBus) ...[
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.alt_route_rounded, size: 11, color: Color(0xFFB45309)),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'CROSS-BUS${assignedBus.isNotEmpty && assignedBus != 'None' ? ' ($assignedBus)' : ''}',
                                                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                isPresent ? 'PRESENT' : 'ABSENT',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: isPresent ? AppTheme.success : AppTheme.danger,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 10),

                                    // Detail metrics
                                    _RecordDetailRow(icon: Icons.schedule_rounded, label: 'Time Marked', value: r['time'] ?? '—', iconColor: AppTheme.primaryAccent),
                                    _RecordDetailRow(icon: Icons.directions_bus_rounded, label: 'Bus / Route', value: '${r['bus_number'] ?? '—'} • ${r['route_name'] ?? '—'}', iconColor: AppTheme.secondary),
                                    _RecordDetailRow(icon: Icons.pin_drop_rounded, label: 'Stage Stop', value: r['stage_name'] ?? '—', iconColor: AppTheme.warning),
                                    _RecordDetailRow(icon: Icons.fact_check_rounded, label: 'Trip Direction', value: '${(r['attendance_type'] as String? ?? '—').toUpperCase()} (${r['trip_type'] ?? '—'})', iconColor: const Color(0xFF0284C7)),
                                    _RecordDetailRow(icon: Icons.verified_user_rounded, label: 'Verified By', value: r['incharge_name'] ?? 'Incharge', iconColor: AppTheme.success),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

class _RecordDetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color iconColor;

  const _RecordDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppTheme.primaryAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 95,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _HistorySummaryPill({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
