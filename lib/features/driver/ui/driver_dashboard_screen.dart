import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_language_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/driver_language_provider.dart';
import '../widgets/driver_language_selector_sheet.dart';

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboardScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Modern sleek background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x262563EB), blurRadius: 4, offset: Offset(0, 1.5)),
                ],
              ),
              child: const Center(
                child: Icon(Icons.directions_bus_rounded, color: Colors.white, size: 17),
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'TRIPMATE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                ref.tr('driver_badge'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 8.5,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // 🌐 Google Translate / Multi-Language Switcher Pill
          const Center(
            child: AppLanguageButton(compact: true),
          ),
          const SizedBox(width: 2),

          // History Button
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.history_rounded, color: Color(0xFF2563EB), size: 21),
            tooltip: ref.tr('history_tooltip'),
            onPressed: () => context.push('/driver/history'),
          ),

          // Logout Button
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text(ref.tr('logout_confirm_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  content: Text(ref.tr('logout_confirm_desc')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(ref.tr('cancel'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(ref.tr('logout'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B), size: 20),
            tooltip: ref.tr('logout_tooltip'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _HomeTab(),
          _TripLogTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1E40AF),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedFontSize: 11.5,
          unselectedFontSize: 11.5,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.home_rounded),
              ),
              activeIcon: const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.home_rounded, color: Color(0xFF1E40AF)),
              ),
              label: ref.tr('tab_home'),
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.directions_bus_rounded),
              ),
              activeIcon: const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.directions_bus_rounded, color: Color(0xFF1E40AF)),
              ),
              label: ref.tr('tab_trip'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TAB 1: HOME — Driver profile + today summary
// ============================================================
class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(driverProfileProvider);
    final tripsAsync = ref.watch(driverTodayTripsProvider);
    String today;
    try {
      today = DateFormat('dd MMM yyyy', 'en').format(DateTime.now());
    } catch (_) {
      final now = DateTime.now();
      today = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    }

    return RefreshIndicator(
      color: const Color(0xFF1E40AF),
      onRefresh: () async {
        ref.invalidate(driverProfileProvider);
        ref.invalidate(driverTodayTripsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Hero Driver Profile Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: Color(0x331D4ED8), blurRadius: 18, offset: Offset(0, 8)),
                ],
              ),
              child: profileAsync.when(
                loading: () => const _BannerSkeleton(),
                error: (e, _) => _ErrorText('${ref.tr('profile_load_failed')}: ${formatApiError(e)}'),
                data: (profile) => Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.2),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 34),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.tr('greeting'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            profile['name'] ?? 'Driver',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  profile['bus_number'] != null
                                      ? 'Bus ${profile['bus_number']}'
                                      : ref.tr('no_bus_assigned'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── 2. Unified Date & Day-End Report Card ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF2563EB), size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref.tr('today_date'),
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          today,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/driver/day-report'),
                    icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                    label: Text(ref.tr('day_report_btn')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 3. Today's Trips Section Header ──
            tripsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (trips) => Row(
                children: [
                  Expanded(
                    child: Text(
                      ref.tr('today_trips_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      final profile = ref.read(driverProfileProvider).valueOrNull;
                      _showSpecialTripModal(context, ref, profile);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, size: 14, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(
                            ref.tr('special_trip_btn'),
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (trips.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        '${trips.length} ${ref.tr('tab_trip')}',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 4. Trips Content (Single unified card when empty, no duplicate button!) ──
            tripsAsync.when(
              loading: () => const _TripCardSkeleton(),
              error: (e, _) => _ErrorText('${ref.tr('trips_load_failed')}: ${formatApiError(e)}'),
              data: (trips) {
                if (trips.isEmpty) {
                  // Only ONE clean card when empty!
                  return const _EmptyTripsUnifiedCard();
                }

                // If trips exist, show trip cards + single bottom quick action
                return Column(
                  children: [
                    ...trips.map((t) => _TripSummaryCard(trip: t)),
                    const SizedBox(height: 14),
                    Builder(
                      builder: (ctx) {
                        final morningPending = trips.where((t) => t['trip_type'] == 'morning' && t['end_km'] == null).firstOrNull;
                        final eveningPending = trips.where((t) => t['trip_type'] == 'evening' && t['start_km'] == null).firstOrNull;
                        final isMorningTime = DateTime.now().hour < 13;

                        final targetTrip = isMorningTime
                            ? (morningPending ?? eveningPending ?? trips.first)
                            : (eveningPending ?? morningPending ?? trips.first);

                        final isMorning = targetTrip['trip_type'] == 'morning';
                        final targetMode = isMorning ? 'end' : (targetTrip['start_km'] == null ? 'start' : 'end');

                        final title = isMorning
                            ? 'காலை முடிவு KM பதிவு (Shift Closing KM)'
                            : (targetTrip['start_km'] == null
                                ? 'மாலை தொடக்க KM பதிவு (Shift Opening KM)'
                                : 'மீட்டர் ரீடிங் பதிவு');
                        final subtitle = isMorning
                            ? 'நேற்றைய மாலை ரீடிங்குடன் கழித்து Total KM கணக்கிடப்படும்'
                            : 'இன்று மாலை காலேஜ் புறப்படும் போது உள்ள ரீடிங்';
                        final cardColor = isMorning ? const Color(0xFF059669) : const Color(0xFF7C3AED);

                        return _ActionCard(
                          icon: isMorning ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                          title: title,
                          subtitle: subtitle,
                          color: cardColor,
                          onTap: () {
                            context.push('/driver/trip-log', extra: {
                              'trip': targetTrip,
                              'mode': targetMode,
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _ActionCard(
                      icon: Icons.stars_rounded,
                      title: ref.tr('special_trip_title'),
                      subtitle: ref.tr('special_trip_sub'),
                      color: const Color(0xFF0284C7),
                      onTap: () {
                        final profile = ref.read(driverProfileProvider).valueOrNull;
                        _showSpecialTripModal(context, ref, profile);
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TAB 2: TRIP LOG
// ============================================================
class _TripLogTab extends ConsumerWidget {
  const _TripLogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(driverTodayTripsProvider);

    return RefreshIndicator(
      color: const Color(0xFF1E40AF),
      onRefresh: () async => ref.invalidate(driverTodayTripsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header instructions banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1E40AF), size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${ref.tr('start_km')} & ${ref.tr('end_km')} Photo Log',
                      style: const TextStyle(
                        color: Color(0xFF1E40AF),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: Text(
                    ref.tr('today_trips_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    final profile = ref.read(driverProfileProvider).valueOrNull;
                    _showSpecialTripModal(context, ref, profile);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, size: 14, color: Color(0xFF0284C7)),
                        const SizedBox(width: 4),
                        Text(
                          ref.tr('special_trip_btn'),
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            tripsAsync.when(
              loading: () => const _TripCardSkeleton(),
              error: (e, _) => _ErrorText('${ref.tr('trips_load_failed')}: ${formatApiError(e)}'),
              data: (trips) => trips.isEmpty
                  ? const _EmptyTripsUnifiedCard()
                  : Column(
                      children: trips
                          .map((t) => _TripActionCard(trip: t))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Unified Single Empty Trips Card (Clean, modern, no duplicate buttons!)
// ============================================================
class _EmptyTripsUnifiedCard extends ConsumerWidget {
  const _EmptyTripsUnifiedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider).valueOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
            ),
            child: const Center(
              child: Icon(Icons.directions_bus_rounded, size: 28, color: Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            ref.tr('no_trips_today'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ref.tr('direct_start_sub'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (ctx) {
                final isMorningTime = DateTime.now().hour < 13;
                return FilledButton.icon(
                  onPressed: () {
                    context.push('/driver/trip-log', extra: {
                      'trip': {
                        'id': 'direct-trip',
                        'trip_type': isMorningTime ? 'morning' : 'evening',
                        'bus_number': profile?['bus_number'],
                        'vehicle_number': profile?['vehicle_number'],
                        'route_name': profile?['route_name'],
                      },
                      'mode': isMorningTime ? 'end' : 'start',
                    });
                  },
                  icon: Icon(isMorningTime ? Icons.wb_sunny_rounded : Icons.nightlight_round, size: 19),
                  label: Text(
                    isMorningTime
                        ? 'காலை முடிவு KM பதிவு (Closing KM)'
                        : 'மாலை தொடக்க KM பதிவு (Opening KM)',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isMorningTime ? const Color(0xFF059669) : const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final profile = ref.read(driverProfileProvider).valueOrNull;
                _showSpecialTripModal(context, ref, profile);
              },
              icon: const Icon(Icons.stars_rounded, size: 18, color: Color(0xFF0284C7)),
              label: Text(
                ref.tr('special_trip_btn'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0284C7)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFBAE6FD)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: const Color(0xFFF0F9FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Trip Summary Card (Home tab — read-only)
// ============================================================
class _TripSummaryCard extends ConsumerWidget {
  final Map<String, dynamic> trip;
  const _TripSummaryCard({required this.trip});

  String _typeLabel(BuildContext context, WidgetRef ref, String? type) {
    switch (type) {
      case 'morning':
        return ref.tr('morning_trip');
      case 'evening':
        return ref.tr('evening_trip');
      case 'special':
        return ref.tr('special_trip');
      default:
        return type ?? '';
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'morning':
        return const Color(0xFFD97706);
      case 'evening':
        return const Color(0xFF7C3AED);
      case 'special':
        return const Color(0xFF0284C7);
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLog = trip['log_id'] != null;
    final isComplete = trip['end_km'] != null;
    final type = trip['trip_type'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _typeColor(type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _typeLabel(context, ref, type),
              style: TextStyle(
                color: _typeColor(type),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trip['remarks'] != null && trip['remarks'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      trip['remarks'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF0284C7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  hasLog
                      ? (isComplete
                          ? '${trip['start_km']} → ${trip['end_km']} KM'
                          : (type == 'evening'
                              ? 'மாலை Opening: ${trip['start_km']} KM'
                              : '${ref.tr('start_km')}: ${trip['start_km']} KM'))
                      : ref.tr('pending'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
                if (isComplete)
                  Text(
                    '${ref.tr('total_km')}: ${(((trip['end_km'] is num ? (trip['end_km'] as num).toDouble() : double.tryParse(trip['end_km'].toString()) ?? 0) - (trip['start_km'] is num ? (trip['start_km'] as num).toDouble() : double.tryParse(trip['start_km'].toString()) ?? 0)).toStringAsFixed(1))} KM',
                    style: const TextStyle(color: Color(0xFF059669), fontSize: 12.5, fontWeight: FontWeight.w700),
                  )
                else if (type == 'evening' && hasLog)
                  const Text(
                    'நாளை காலை கல்லூரியில் முடிவு பதிவு செய்யப்படும்',
                    style: TextStyle(color: Color(0xFF7C3AED), fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          Icon(
            isComplete
                ? Icons.check_circle_rounded
                : (type == 'evening' && hasLog)
                    ? Icons.check_circle_outline_rounded
                    : hasLog
                        ? Icons.radio_button_on_rounded
                        : Icons.radio_button_unchecked_rounded,
            color: isComplete
                ? const Color(0xFF059669)
                : (type == 'evening' && hasLog)
                    ? const Color(0xFF7C3AED)
                    : hasLog
                        ? const Color(0xFFD97706)
                        : const Color(0xFF94A3B8),
            size: 22,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Trip Action Card (Trip Log tab — with Start/End buttons)
// ============================================================
class _TripActionCard extends ConsumerWidget {
  final Map<String, dynamic> trip;
  const _TripActionCard({required this.trip});

  String _typeLabel(BuildContext context, WidgetRef ref, String? type) {
    switch (type) {
      case 'morning':
        return ref.tr('morning_trip');
      case 'evening':
        return ref.tr('evening_trip');
      case 'special':
        return ref.tr('special_trip');
      default:
        return type ?? ref.tr('tab_trip');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasStart = trip['start_km'] != null;
    final hasEnd = trip['end_km'] != null;
    final isMorning = trip['trip_type'] == 'morning';
    final isEvening = trip['trip_type'] == 'evening';
    final isSpecial = trip['trip_type'] == 'special';
    final prevEveOpKm = trip['prev_evening_op_km'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Icon(
                  isSpecial
                      ? Icons.stars_rounded
                      : isEvening
                          ? Icons.nightlight_round
                          : isMorning
                              ? Icons.wb_sunny_rounded
                              : Icons.directions_bus_rounded,
                  color: isSpecial
                      ? const Color(0xFF0284C7)
                      : isEvening
                          ? const Color(0xFF7C3AED)
                          : isMorning
                              ? const Color(0xFFD97706)
                              : const Color(0xFF1E40AF),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSpecial
                        ? (trip['remarks'] != null && trip['remarks'].toString().isNotEmpty
                            ? 'சிறப்பு: ${trip['remarks']}'
                            : 'சிறப்புப் பயணம் (Special Trip)')
                        : isEvening
                            ? 'மாலை பயணம் (Shift OP)'
                            : isMorning
                                ? 'காலை பயணம் (Shift CL)'
                                : _typeLabel(context, ref, trip['trip_type'] as String?),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (hasEnd)
                  _StatusChip(label: ref.tr('completed'), color: const Color(0xFF059669))
                else if (isEvening && hasStart)
                  const _StatusChip(label: 'ஆரம்பமானது (OP Done)', color: Color(0xFF7C3AED))
                else if (hasStart)
                  _StatusChip(label: ref.tr('in_progress'), color: const Color(0xFFD97706))
                else
                  _StatusChip(label: ref.tr('pending'), color: const Color(0xFF64748B)),
              ],
            ),
          ),

          // Previous evening OP hint for morning trips
          if (isMorning && prevEveOpKm != null && !hasEnd)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Text(
                      'நேற்றைய மாலை ஆரம்ப ரீடிங்: $prevEveOpKm KM',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
            ),

          // KM info
          if (hasStart)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _KmInfo(label: ref.tr('start_km'), value: '${trip['start_km']} KM'),
                  if (hasEnd) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    _KmInfo(label: ref.tr('end_km'), value: '${trip['end_km']} KM'),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    _KmInfo(
                      label: ref.tr('total_km'),
                      value: '${(((trip['end_km'] is num ? (trip['end_km'] as num).toDouble() : double.tryParse(trip['end_km'].toString()) ?? 0) - (trip['start_km'] is num ? (trip['start_km'] as num).toDouble() : double.tryParse(trip['start_km'].toString()) ?? 0)).toStringAsFixed(1))} KM',
                      highlight: true,
                    ),
                  ],
                ],
              ),
            ),

          // Action buttons
          if (!hasEnd)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (isMorning)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push('/driver/trip-log', extra: {
                          'trip': trip,
                          'mode': 'end',
                        }),
                        icon: const Icon(Icons.wb_sunny_rounded, size: 18),
                        label: const Text('காலை முடிவு KM பதிவு (Shift CL KM)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                      ),
                    )
                  else if (isEvening)
                    if (!hasStart)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.push('/driver/trip-log', extra: {
                            'trip': trip,
                            'mode': 'start',
                          }),
                          icon: const Icon(Icons.nightlight_round, size: 18),
                          label: const Text('மாலை தொடக்க KM பதிவு (Shift OP KM)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD8B4FE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF7C3AED), size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'மாலை Opening KM பதிவானது • காலை முடிவு பதிவு செய்யவும்',
                                  style: TextStyle(
                                    color: Color(0xFF6B21A8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => context.push('/driver/trip-log', extra: {
                                  'trip': trip,
                                  'mode': 'start',
                                }),
                                child: const Text(
                                  'திருத்து',
                                  style: TextStyle(
                                    color: Color(0xFF7C3AED),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                  else if (isSpecial)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push('/driver/trip-log', extra: {
                          'trip': trip,
                          'mode': hasStart ? 'end' : 'start',
                        }),
                        icon: Icon(hasStart ? Icons.flag_rounded : Icons.play_arrow_rounded, size: 18),
                        label: Text(hasStart ? 'சிறப்புப் பயணம் முடிவு பதிவு (End Special)' : 'சிறப்புப் பயணம் ஆரம்ப KM (Start Special)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: hasStart ? const Color(0xFF059669) : const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                      ),
                    )
                  else ...[
                    if (!hasStart)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.push('/driver/trip-log', extra: {
                            'trip': trip,
                            'mode': 'start',
                          }),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(ref.tr('start_trip')),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E40AF),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                        ),
                      ),
                    if (hasStart && !hasEnd)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.push('/driver/trip-log', extra: {
                            'trip': trip,
                            'mode': 'end',
                          }),
                          icon: const Icon(Icons.stop_rounded, size: 18),
                          label: Text(ref.tr('end_trip')),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Small reusable widgets
// ============================================================
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
        ),
      );
}

class _KmInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _KmInfo({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFF059669) : const Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 22),
            ],
          ),
        ),
      );
}

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton();
  @override
  Widget build(BuildContext context) => Container(height: 60, color: Colors.white12);
}

class _TripCardSkeleton extends StatelessWidget {
  const _TripCardSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      );
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: const TextStyle(color: Color(0xFFDC2626))),
      );
}

// ============================================================
// Special / Extra Duty Trip Modal Sheet
// ============================================================
void _showSpecialTripModal(BuildContext context, WidgetRef ref, Map<String, dynamic>? profile) {
  final TextEditingController destController = TextEditingController();
  String selectedCategoryId = 'diesel';

  final categories = [
    {
      'id': 'diesel',
      'titleKey': 'cat_diesel_bunk',
      'subKey': 'cat_diesel_bunk_sub',
      'icon': Icons.local_gas_station_rounded,
      'color': const Color(0xFFD97706),
    },
    {
      'id': 'workshop',
      'titleKey': 'cat_workshop',
      'subKey': 'cat_workshop_sub',
      'icon': Icons.build_rounded,
      'color': const Color(0xFFDC2626),
    },
    {
      'id': 'campus_duty',
      'titleKey': 'cat_campus_duty',
      'subKey': 'cat_campus_duty_sub',
      'icon': Icons.school_rounded,
      'color': const Color(0xFF0284C7),
    },
    {
      'id': 'event_tour',
      'titleKey': 'cat_event_tour',
      'subKey': 'cat_event_tour_sub',
      'icon': Icons.celebration_rounded,
      'color': const Color(0xFF7C3AED),
    },
    {
      'id': 'other',
      'titleKey': 'cat_other',
      'subKey': 'cat_other_sub',
      'icon': Icons.edit_note_rounded,
      'color': const Color(0xFF475569),
    },
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalCtx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 14,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, -4)),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Color(0x330284C7), blurRadius: 8, offset: Offset(0, 3)),
                          ],
                        ),
                        child: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.tr('special_trip_title'),
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              ref.tr('special_modal_sub'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ref.tr('select_category'),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 10),
                  // Perfectly aligned full-width category cards
                  Column(
                    children: categories.map((cat) {
                      final isSelected = selectedCategoryId == cat['id'];
                      final color = cat['color'] as Color;
                      final title = ref.tr(cat['titleKey'] as String);
                      final sub = ref.tr(cat['subKey'] as String);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setModalState(() => selectedCategoryId = cat['id'] as String),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withOpacity(0.08) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? color : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected ? color.withOpacity(0.15) : const Color(0xFFEDF2F7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(cat['icon'] as IconData, size: 20, color: isSelected ? color : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          sub,
                                          style: TextStyle(
                                            color: isSelected ? color : const Color(0xFF94A3B8),
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? color : const Color(0xFFCBD5E1),
                                        width: isSelected ? 6.5 : 1.5,
                                      ),
                                      color: isSelected ? Colors.white : Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ref.tr('destination_notes'),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: destController,
                    decoration: InputDecoration(
                      hintText: ref.tr('destination_hint'),
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final catObj = categories.firstWhere((c) => c['id'] == selectedCategoryId);
                        final catTitle = ref.tr(catObj['titleKey'] as String);
                        final dest = destController.text.trim();
                        final remarks = dest.isNotEmpty ? '$catTitle: $dest' : catTitle;
                        Navigator.pop(modalCtx);
                        context.push('/driver/trip-log', extra: {
                          'trip': {
                            'id': 'special-${DateTime.now().millisecondsSinceEpoch}',
                            'trip_type': 'special',
                            'remarks': remarks,
                            'bus_number': profile?['bus_number'],
                            'vehicle_number': profile?['vehicle_number'],
                            'route_name': profile?['route_name'],
                          },
                          'mode': 'start',
                        });
                      },
                      icon: const Icon(Icons.speed_rounded, size: 19),
                      label: Text(
                        ref.tr('start_special_trip_btn'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
