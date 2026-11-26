import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_language_button.dart';
import '../providers/driver_provider.dart';

/// Driver trip + day report history screen (Tamil)
class DriverHistoryScreen extends ConsumerWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(driverReportsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'வரலாறு',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
          ),
          actions: const [
            Center(child: AppLanguageButton(compact: true)),
            SizedBox(width: 12),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF1E40AF),
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: Color(0xFF1E40AF),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.directions_bus_rounded, size: 18), text: 'பயண பதிவு'),
              Tab(icon: Icon(Icons.assignment_rounded, size: 18), text: 'நாள் அறிக்கை'),
            ],
          ),
        ),
        body: reportsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF))),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 48, color: AppTheme.danger),
                  const SizedBox(height: 12),
                  Text(
                    'வரலாறு ஏற்றவில்லை:\n${formatApiError(e)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(driverReportsProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('மீண்டும் முயற்சிக்கவும் (Retry)'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E40AF)),
                  ),
                ],
              ),
            ),
          ),
          data: (data) => TabBarView(
            children: [
              _TripLogHistory(logs: List<Map<String, dynamic>>.from(data['tripLogs'] ?? [])),
              _DayReportHistory(reports: List<Map<String, dynamic>>.from(data['dayReports'] ?? [])),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Trip Log History Tab
// ────────────────────────────────────────────────────────────
class _TripLogHistory extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const _TripLogHistory({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 56, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('பயண பதிவுகள் இல்லை', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final log = logs[i];
        String date = '—';
        if (log['trip_date'] != null) {
          try {
            date = DateFormat('dd MMM yyyy', 'en').format(DateTime.parse(log['trip_date'].toString()));
          } catch (_) {
            date = log['trip_date'].toString();
          }
        }
        final type = log['trip_type'] as String?;
        final typeLabel = type == 'morning' ? 'காலை' : type == 'evening' ? 'மாலை' : 'சிறப்பு';
        final hasEnd = log['end_km'] != null;
        final totalKm = hasEnd
            ? (((log['end_km'] is num ? (log['end_km'] as num).toDouble() : double.tryParse(log['end_km'].toString()) ?? 0) - (log['start_km'] is num ? (log['start_km'] as num).toDouble() : double.tryParse(log['start_km'].toString()) ?? 0)).toStringAsFixed(1))
            : null;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
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
                        Text(date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(typeLabel, style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasEnd
                          ? '${log['start_km']} → ${log['end_km']} KM (மொத்தம்: $totalKm KM)'
                          : 'ஆரம்பம்: ${log['start_km']} KM (முடிக்கவில்லை)',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                hasEnd ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: hasEnd ? AppTheme.success : AppTheme.warning,
                size: 20,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
// Day Report History Tab
// ────────────────────────────────────────────────────────────
class _DayReportHistory extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  const _DayReportHistory({required this.reports});

  Color _conditionColor(String? cond) {
    switch (cond) {
      case 'excellent':
      case 'good':
      case 'clean':
      case 'full':
      case 'adequate':
        return AppTheme.success;
      case 'fair':
      case 'needs_cleaning':
      case 'low':
        return AppTheme.warning;
      case 'poor':
      case 'dirty':
      case 'empty':
      case 'needs_service':
        return AppTheme.danger;
      default:
        return AppTheme.textMuted;
    }
  }

  String _conditionLabel(String? key) {
    const labels = {
      'full': 'நிரம்பியுள்ளது', 'adequate': 'போதுமான அளவு', 'low': 'குறைவாக', 'empty': 'காலி',
      'clean': 'சுத்தம்', 'needs_cleaning': 'சுத்தம் வேண்டும்', 'dirty': 'அழுக்கு',
      'good': 'நல்லது', 'fair': 'சாதாரணம்', 'poor': 'மோசம்',
      'needs_service': 'சேவை வேண்டும்', 'excellent': 'சிறந்தது',
    };
    return labels[key] ?? key ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 56, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('நாள் அறிக்கைகள் இல்லை', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = reports[i];
        String date = '—';
        if (r['report_date'] != null) {
          try {
            date = DateFormat('dd MMM yyyy', 'en').format(DateTime.parse(r['report_date'].toString()));
          } catch (_) {
            date = r['report_date'].toString();
          }
        }
        final images = (r['issue_images'] as List?)?.cast<String>() ?? [];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_rounded, color: Color(0xFF1E40AF), size: 20),
                    const SizedBox(width: 8),
                    Text(date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const Spacer(),
                    if (r['total_km_today'] != null)
                      _ConditionChip(
                        label: '${r['total_km_today']} KM',
                        color: const Color(0xFF1E40AF),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Condition grid
              Padding(
                padding: const EdgeInsets.all(14),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 3.5,
                  children: [
                    _ConditionRow(label: 'எரிபொருள்', value: r['fuel_status'], color: _conditionColor(r['fuel_status']), valueLabel: _conditionLabel(r['fuel_status'])),
                    _ConditionRow(label: 'சுத்தம்', value: r['cleanliness_status'], color: _conditionColor(r['cleanliness_status']), valueLabel: _conditionLabel(r['cleanliness_status'])),
                    _ConditionRow(label: 'டயர்', value: r['tyre_condition'], color: _conditionColor(r['tyre_condition']), valueLabel: _conditionLabel(r['tyre_condition'])),
                    _ConditionRow(label: 'பிரேக்', value: r['brake_condition'], color: _conditionColor(r['brake_condition']), valueLabel: _conditionLabel(r['brake_condition'])),
                  ],
                ),
              ),

              // Overall condition badge
              if (r['overall_condition'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Text('ஒட்டுமொத்த நிலை: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textMuted)),
                      _ConditionChip(
                        label: _conditionLabel(r['overall_condition'] as String?),
                        color: _conditionColor(r['overall_condition'] as String?),
                      ),
                    ],
                  ),
                ),

              // Issue description
              if (r['issue_description'] != null && (r['issue_description'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r['issue_description'] as String,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Voice + images indicators
              if (r['voice_note_url'] != null || images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(
                    children: [
                      if (r['voice_note_url'] != null) ...[
                        const Icon(Icons.mic_rounded, color: Color(0xFF1E40AF), size: 16),
                        const SizedBox(width: 4),
                        const Text('குரல் குறிப்பு', style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                      ],
                      if (images.isNotEmpty) ...[
                        const Icon(Icons.photo_library_rounded, color: AppTheme.textMuted, size: 16),
                        const SizedBox(width: 4),
                        Text('${images.length} படம்', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }
}

class _ConditionRow extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color color;
  final String valueLabel;
  const _ConditionRow({required this.label, required this.value, required this.color, required this.valueLabel});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          Flexible(
            child: Text(
              valueLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

class _ConditionChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ConditionChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
      );
}
