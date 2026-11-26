import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_language_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/providers/driver_language_provider.dart';
import '../providers/supervisor_provider.dart';
import '../services/supervisor_print_service.dart';

class SupervisorDashboardScreen extends ConsumerStatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  ConsumerState<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends ConsumerState<SupervisorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedBusId; // null = All Buses

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showVerifyDialog(Map<String, dynamic> log, Map<String, dynamic> bus, bool isTa) {
    final openCtrl = TextEditingController(text: log['opening_km']?.toString() ?? '');
    final closeCtrl = TextEditingController(text: log['closing_km']?.toString() ?? '');
    final remarksCtrl = TextEditingController(
      text: isTa ? 'வாகன ஓடோமீட்டர் மற்றும் எரிபொருள் சரிபார்க்கப்பட்டது.' : 'Vehicle odometer and fuel verified on site.',
    );
    bool isFlagging = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFlagging ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isFlagging ? Icons.flag_rounded : Icons.verified_rounded,
                  color: isFlagging ? Colors.red : const Color(0xFF15803D),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isFlagging
                      ? (isTa ? 'வித்தியாசம் குறி (Flag Variance)' : 'Flag Variance')
                      : (isTa ? 'நாள் அறிக்கை சரிபார் (Verify Log)' : 'Verify Daily Log'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isTa ? "பேருந்து" : "Bus"}: Bus ${bus['bus_number'] ?? log['bus_number']} (${bus['registration_no'] ?? log['registration_no'] ?? ''})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isTa ? "தேதி" : "Date"}: ${log['km_date'] ?? ''}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: openCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: isTa ? 'துவக்க கி.மீ (Opening KM)' : 'Opening KM',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: closeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: isTa ? 'நிறைவு கி.மீ (Closing KM)' : 'Closing KM',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: remarksCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isTa ? 'சரிபார்ப்பு குறிப்பு (Inspection Remarks)' : 'Inspection Remarks',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: isFlagging,
                      activeColor: Colors.red,
                      onChanged: (v) => setDlgState(() => isFlagging = v ?? false),
                    ),
                    Expanded(
                      child: Text(
                        isTa ? 'மீட்டர் வித்தியாசமாக உள்ளது (ஆடிட் தேவை)' : 'Flag odometer variance for audit',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isTa ? 'ரத்து' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFlagging ? Colors.red : const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final openKm = double.tryParse(openCtrl.text.trim());
                final closeKm = double.tryParse(closeCtrl.text.trim());
                final busId = (bus['bus_id'] ?? log['bus_id']).toString();
                final ok = await ref.read(supervisorActionsProvider.notifier).verifyDailyReport(
                  busId: busId,
                  reportDate: log['km_date'].toString(),
                  verifiedOpeningKm: openKm,
                  verifiedClosingKm: closeKm,
                  remarks: remarksCtrl.text.trim(),
                  status: isFlagging ? 'flagged' : 'verified',
                );
                if (mounted) {
                  if (ok) {
                    AppSnackBar.showSuccess(
                      context,
                      isFlagging
                          ? (isTa ? 'அறிக்கை கொடியிடப்பட்டது' : 'Daily report flagged for audit')
                          : (isTa ? 'தினசரி அறிக்கை சரிபார்க்கப்பட்டது!' : 'Daily report verified successfully!'),
                    );
                  } else {
                    AppSnackBar.showError(
                      context,
                      isTa ? 'சரிபார்ப்பில் பிழை' : 'Failed to verify daily report',
                    );
                  }
                }
              },
              child: Text(
                isFlagging
                    ? (isTa ? 'கொடியிடு' : 'Flag Variance')
                    : (isTa ? 'சரிபார்' : 'Verify Log'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNewTicketSheet(List<dynamic> assignedBuses, bool isTa) {
    if (assignedBuses.isEmpty) {
      AppSnackBar.showInfo(
        context,
        isTa ? 'பேருந்துகள் எதுவும் ஒதுக்கப்படவில்லை.' : 'No buses assigned to you yet.',
      );
      return;
    }

    // If already filtered by a bus, navigate directly
    if (_selectedBusId != null) {
      final bus = assignedBuses.firstWhere(
        (b) => b['bus_id'].toString() == _selectedBusId,
        orElse: () => assignedBuses.first,
      );
      context.push('/supervisor/ticket/new', extra: bus);
      return;
    }

    // Otherwise show bottom sheet to pick bus
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isTa ? 'பேருந்தை தேர்வு செய்யவும்' : 'Select Bus Asset',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Text(
              isTa ? 'எந்த பேருந்திற்கு பராமரிப்பு அல்லது PO தேவை?' : 'Which bus requires maintenance or PO requisition?',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: assignedBuses.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (c, idx) {
                  final bus = assignedBuses[idx] as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    title: Text(
                      'Bus ${bus['bus_number']}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${bus['registration_no'] ?? ''} • Odo: ${bus['current_odometer'] ?? '—'} km',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/supervisor/ticket/new', extra: bus);
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

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(supervisorDashboardProvider);
    final user = ref.watch(authStateProvider).value;
    final currentLang = ref.watch(driverLanguageProvider);
    final isTa = currentLang == DriverLanguage.tamil;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x330284C7), blurRadius: 4, offset: Offset(0, 1.5)),
                ],
              ),
              child: const Center(
                child: Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TRIPMATE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'SUPERVISOR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 8.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  user?.email ?? (isTa ? 'பேருந்து மேற்பார்வையாளர்' : 'Bus Supervisor'),
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
        actions: [
          // 🌐 Google Translate / Multi-Language Button
          const Center(
            child: AppLanguageButton(compact: true),
          ),
          const SizedBox(width: 2),

          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8), size: 20),
            tooltip: isTa ? 'புதுப்பி' : 'Refresh',
            onPressed: () {
              ref.invalidate(supervisorDashboardProvider);
              AppSnackBar.showInfo(context, isTa ? 'தரவு புதுப்பிக்கப்படுகிறது...' : 'Refreshing data...');
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8), size: 20),
            tooltip: isTa ? 'வெளியேறு' : 'Log Out',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(isTa ? 'வெளியேறவா?' : 'Log Out?', style: const TextStyle(fontWeight: FontWeight.w800)),
                  content: Text(
                    isTa
                        ? 'நிச்சயமாக மேற்பார்வையாளர் கணக்கிலிருந்து வெளியேற விரும்புகிறீர்களா?'
                        : 'Are you sure you want to log out from this supervisor account?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(isTa ? 'ரத்து' : 'Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(isTa ? 'வெளியேறு' : 'Log Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          tabs: [
            Tab(icon: const Icon(Icons.fact_check_rounded, size: 19), text: isTa ? 'KM சரிபார்ப்பு' : 'KM Verification'),
            Tab(icon: const Icon(Icons.build_circle_rounded, size: 19), text: isTa ? 'பராமரிப்பு & PO' : 'Maintenance & PO'),
            Tab(icon: const Icon(Icons.directions_bus_rounded, size: 19), text: isTa ? 'பேருந்துகள்' : 'Buses'),
          ],
        ),
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7))),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  isTa ? 'தகவலை ஏற்றுவதில் பிழை: $err' : 'Failed to load supervisor data: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(supervisorDashboardProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(isTa ? 'மீண்டும் முயற்சி செய்' : 'Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final assignedBuses = (data['assignedBuses'] as List<dynamic>?) ?? [];
          final allDailyLogs = (data['dailyLogs'] as List<dynamic>?) ?? [];
          final driverTrips = (data['driverTrips'] as List<dynamic>?) ?? [];
          final allRecentTickets = (data['recentTickets'] as List<dynamic>?) ?? [];
          final pendingCount = (data['pendingVerificationCount'] as num?)?.toInt() ?? 0;
          final activeTicketsCount = (data['activeTicketsCount'] as num?)?.toInt() ?? 0;
          final totalDayKm = (data['totalDayKm'] as num?) ?? 0;

          // Filter by selected bus
          final dailyLogs = _selectedBusId == null
              ? allDailyLogs
              : allDailyLogs.where((l) => l['bus_id']?.toString() == _selectedBusId).toList();

          final recentTickets = _selectedBusId == null
              ? allRecentTickets
              : allRecentTickets.where((t) => t['bus_id']?.toString() == _selectedBusId).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              // ── TAB 1: KM LOGS & DAILY REPORT VERIFICATION ────────
              RefreshIndicator(
                onRefresh: () async => ref.invalidate(supervisorDashboardProvider),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview Metric Cards
                      _buildOverviewMetrics(
                        totalBuses: assignedBuses.length,
                        pendingCount: pendingCount,
                        activeTickets: activeTicketsCount,
                        totalDayKm: totalDayKm,
                        isTa: isTa,
                      ),
                      const SizedBox(height: 14),

                      // Bus Filter Chips Bar
                      if (assignedBuses.isNotEmpty)
                        _buildBusFilterBar(assignedBuses, isTa),

                      // Section Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isTa ? 'ஓட்டுநரின் தினசரி பதிவுகள்' : 'Driver Daily KM Logs',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isTa ? '${dailyLogs.length} பதிவுகள்' : '${dailyLogs.length} logs',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (assignedBuses.isEmpty)
                        _buildNoBusesCard(isTa)
                      else if (dailyLogs.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.assignment_turned_in_outlined, size: 44, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text(
                                isTa ? 'தினசரி பதிவுகள் எதுவும் இல்லை' : 'No Daily Logs Available',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isTa
                                    ? 'ஓட்டுநர் பயணத்தை தொடங்கியவுடன் KM பதிவுகள் தானாக இங்கு தோன்றும்.'
                                    : 'Driver KM odometer logs will appear here once trips are recorded.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 12),
                              if (_selectedBusId != null)
                                TextButton.icon(
                                  onPressed: () => setState(() => _selectedBusId = null),
                                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                                  label: Text(isTa ? 'அனைத்து பேருந்துகளையும் காண்க' : 'View all assigned buses'),
                                ),
                            ],
                          ),
                        )
                      else
                        ...dailyLogs.map((log) {
                          final logMap = log as Map<String, dynamic>;
                          final matchingBus = assignedBuses.firstWhere(
                            (b) => b['bus_id']?.toString() == logMap['bus_id']?.toString(),
                            orElse: () => {
                              'bus_id': logMap['bus_id'],
                              'bus_number': logMap['bus_number'] ?? '—',
                              'registration_no': logMap['registration_no'] ?? '',
                              'driver_name': logMap['driver_name'],
                            },
                          ) as Map<String, dynamic>;
                          return _buildDailyLogCard(logMap, matchingBus, driverTrips, isTa);
                        }),
                    ],
                  ),
                ),
              ),

              // ── TAB 2: MAINTENANCE & PO REQUISITION TICKETS ────────
              RefreshIndicator(
                onRefresh: () async => ref.invalidate(supervisorDashboardProvider),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Action Banner: Raise New Ticket / PO Order
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(color: Color(0x26312E81), blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isTa ? 'பழுது & பொருட்கள் தேவை (PO)' : 'Vehicle Issue & PO Requisition',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isTa
                                        ? 'புதிய பராமரிப்பு கோரிக்கை பதிவு செய்து PO ரசீது அச்சிடவும்.'
                                        : 'Log maintenance request & generate purchase requisition voucher.',
                                    style: const TextStyle(color: Color(0xFFC7D2FE), fontSize: 10.5),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF38BDF8),
                                foregroundColor: const Color(0xFF0F172A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onPressed: () => _openNewTicketSheet(assignedBuses, isTa),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(
                                isTa ? '+ புதிய PO' : '+ New PO',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Bus Filter Chips Bar
                      if (assignedBuses.isNotEmpty)
                        _buildBusFilterBar(assignedBuses, isTa),

                      // Recent Tickets List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isTa ? 'பராமரிப்பு கோரிக்கைகள்' : 'Active Maintenance Tickets',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            isTa ? '${recentTickets.length} கோரிக்கைகள்' : '${recentTickets.length} tickets',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4338CA)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (assignedBuses.isEmpty)
                        _buildNoBusesCard(isTa)
                      else if (recentTickets.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 44, color: Colors.green.shade400),
                              const SizedBox(height: 10),
                              Text(
                                isTa ? 'பிரச்சனைகள் ஏதுமில்லை' : 'All Clear',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isTa
                                    ? 'நிலுவையில் உள்ள பராமரிப்பு அல்லது PO கோரிக்கைகள் எதுவும் இல்லை.'
                                    : 'There are no active maintenance tickets or pending PO requisitions.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      else
                        ...recentTickets.map((t) => _buildTicketCard(t as Map<String, dynamic>, isTa)),
                    ],
                  ),
                ),
              ),

              // ── TAB 3: ASSIGNED BUSES OVERVIEW ────────────────────
              RefreshIndicator(
                onRefresh: () async => ref.invalidate(supervisorDashboardProvider),
                child: assignedBuses.isEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: _buildNoBusesCard(isTa),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: assignedBuses.length,
                        itemBuilder: (ctx, idx) {
                          final bus = assignedBuses[idx] as Map<String, dynamic>;
                          return _buildFleetBusCard(bus, isTa);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoBusesCard(bool isTa) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: const Icon(Icons.directions_bus_outlined, size: 38, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          Text(
            isTa ? 'பேருந்துகள் ஒதுக்கப்படவில்லை' : 'No Buses Assigned Yet',
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            isTa
                ? 'உங்கள் மேற்பார்வையாளர் கணக்கிற்கு இன்னும் பேருந்துகள் ஒதுக்கப்படவில்லை.\nபோக்குவரத்து நிர்வாக போர்ட்டல் (Maintenance -> Bus Supervisor Assignments) மூலம் பேருந்துகளை ஒதுக்க நிர்வாகியை அணுகவும்.'
                : 'No bus assets are currently assigned to your supervisor account.\nPlease ask the transport administrator to assign buses to you from the Admin Portal.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => ref.invalidate(supervisorDashboardProvider),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(isTa ? 'புதுப்பி (Refresh)' : 'Refresh Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMetrics({
    required int totalBuses,
    required int pendingCount,
    required int activeTickets,
    required num totalDayKm,
    required bool isTa,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: [
        _buildMetricTile(
          title: isTa ? 'ஒதுக்கப்பட்ட பேருந்துகள்' : 'Assigned Buses',
          value: isTa ? '$totalBuses பேருந்துகள்' : '$totalBuses Buses',
          subtitle: isTa ? 'இயக்கத்தில் உள்ளவை' : 'Active Fleet',
          icon: Icons.directions_bus_rounded,
          color: const Color(0xFF0284C7),
          bg: const Color(0xFFE0F2FE),
        ),
        _buildMetricTile(
          title: isTa ? 'சரிபார்ப்பு நிலுவை' : 'Pending Verification',
          value: isTa ? '$pendingCount பதிவுகள்' : '$pendingCount Logs',
          subtitle: pendingCount > 0
              ? (isTa ? 'சரிபார்க்கவும்' : 'Needs Review')
              : (isTa ? 'அனைத்தும் சரி' : 'All Clear'),
          icon: Icons.pending_actions_rounded,
          color: pendingCount > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
          bg: pendingCount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
        ),
        _buildMetricTile(
          title: isTa ? 'பராமரிப்பு கோரிக்கைகள்' : 'Maintenance Tickets',
          value: isTa ? '$activeTickets கோரிக்கைகள்' : '$activeTickets Tickets',
          subtitle: isTa ? 'நிலுவை கோரிக்கைகள்' : 'Open Issues / PO',
          icon: Icons.build_circle_rounded,
          color: const Color(0xFF7C3AED),
          bg: const Color(0xFFEDE9FE),
        ),
        _buildMetricTile(
          title: isTa ? 'இன்றைய மொத்த கி.மீ' : "Today's Total KM",
          value: isTa ? '$totalDayKm கி.மீ' : '$totalDayKm km',
          subtitle: isTa ? 'பயண தூரம்' : 'Fleet Distance',
          icon: Icons.speed_rounded,
          color: const Color(0xFF059669),
          bg: const Color(0xFFD1FAE5),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 1.5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusFilterBar(List<dynamic> assignedBuses, bool isTa) {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: Text(isTa ? 'அனைத்தும்' : 'All'),
            selected: _selectedBusId == null,
            onSelected: (val) {
              if (val) setState(() => _selectedBusId = null);
            },
            selectedColor: const Color(0xFF0284C7),
            labelStyle: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _selectedBusId == null ? Colors.white : const Color(0xFF334155),
            ),
            backgroundColor: Colors.white,
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: _selectedBusId == null ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1)),
            ),
          ),
          const SizedBox(width: 6),
          ...assignedBuses.map((b) {
            final bus = b as Map<String, dynamic>;
            final id = bus['bus_id']?.toString();
            final isSelected = _selectedBusId == id;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text('Bus ${bus['bus_number']}'),
                selected: isSelected,
                onSelected: (val) {
                  setState(() => _selectedBusId = val ? id : null);
                },
                selectedColor: const Color(0xFF0284C7),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDailyLogCard(
    Map<String, dynamic> log,
    Map<String, dynamic> bus,
    List<dynamic> driverTrips,
    bool isTa,
  ) {
    final date = log['km_date']?.toString() ?? '';
    final openKm = log['opening_km'] != null ? '${log['opening_km']} km' : '—';
    final closeKm = log['closing_km'] != null ? '${log['closing_km']} km' : '—';
    final totalKm = log['total_km'] != null ? '${log['total_km']} km' : '0 km';
    final vStatus = log['verification_status']?.toString();
    final isVerified = vStatus == 'verified';
    final isFlagged = vStatus == 'flagged';
    final user = ref.watch(authStateProvider).value;

    final busNumber = bus['bus_number'] ?? log['bus_number'] ?? '—';
    final regNo = bus['registration_no'] ?? log['registration_no'] ?? '';
    final rawDriverName = bus['driver_name'] ?? log['driver_name'];
    final driverName = (rawDriverName != null && rawDriverName.toString().trim().isNotEmpty)
        ? rawDriverName.toString()
        : (isTa ? 'நியமிக்கப்படவில்லை' : 'Not Assigned');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVerified ? const Color(0xFF86EFAC) : (isFlagged ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1)),
          width: isVerified || isFlagged ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      'Bus $busNumber',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1E40AF)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    regNo,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF15803D)),
                      const SizedBox(width: 4),
                      Text(
                        isTa ? 'சரிபார்க்கப்பட்டது' : 'Verified',
                        style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w800, fontSize: 10),
                      ),
                    ],
                  ),
                )
              else if (isFlagged)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag_rounded, size: 12, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        isTa ? 'வித்தியாசம்' : 'Flagged',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 10),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    isTa ? 'நிலுவை சரிபார்ப்பு' : 'Pending Verification',
                    style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w800, fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${isTa ? "தேதி" : "Date"}: $date',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
              ),
              Text(
                '${isTa ? "ஓட்டுநர்" : "Driver"}: $driverName',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(isTa ? 'துவக்க கி.மீ' : 'Opening KM', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(openKm, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ],
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                Column(
                  children: [
                    Text(isTa ? 'நிறைவு கி.மீ' : 'Closing KM', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(closeKm, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ],
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                Column(
                  children: [
                    Text(isTa ? 'மொத்த கி.மீ' : 'Total KM', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(totalKm, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E40AF))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showVerifyDialog(log, bus, isTa),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: Text(
                    isVerified
                        ? (isTa ? 'மீண்டும் சரிபார்' : 'Re-verify')
                        : (isTa ? 'சரிபார்' : 'Verify Log'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    SupervisorPrintService.printDailyLogSheet(
                      bus: bus,
                      log: log,
                      supervisorName: user?.email ?? 'Supervisor',
                      driverName: driverName,
                    );
                  },
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: Text(isTa ? 'அச்சிடு' : 'Print Sheet', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, bool isTa) {
    final ticketNo = ticket['ticket_no'] ?? '';
    final title = ticket['title'] ?? '';
    final busNo = ticket['bus_number'] ?? '';
    final priority = ticket['priority']?.toString().toUpperCase() ?? 'MEDIUM';
    final status = ticket['status']?.toString().toUpperCase() ?? 'RAISED';
    final estCost = ticket['estimated_total_cost'] != null ? '₹${ticket['estimated_total_cost']}' : '₹0';
    final needsPurchase = ticket['needs_purchase'] == true;

    Color priorityColor = Colors.orange;
    if (priority == 'CRITICAL' || priority == 'HIGH') priorityColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(ticketNo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF4338CA))),
                  if (busNo.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(4)),
                      child: Text('Bus $busNo', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Color(0xFF3730A3))),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(priority, style: TextStyle(color: priorityColor, fontWeight: FontWeight.w800, fontSize: 9.5)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Row(
            children: [
              if (needsPurchase)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    isTa ? '🛒 பொருட்கள் தேவை (PO)' : '🛒 Needs Purchase (PO)',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                  ),
                ),
              Text(
                '${isTa ? "மதிப்பீடு" : "Est. Cost"}: $estCost',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF334155)),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status: $status', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final api = ref.read(apiClientProvider);
                  final res = await api.getTicketDetails(ticket['id'].toString());
                  if (res.data is Map && res.data['success'] == true) {
                    final tData = res.data['data']['ticket'] as Map<String, dynamic>;
                    final items = (res.data['data']['items'] as List<dynamic>?) ?? [];
                    SupervisorPrintService.printPoVoucher(ticket: tData, items: items);
                  }
                },
                icon: const Icon(Icons.print_rounded, size: 14),
                label: Text(isTa ? 'PO ரசீது அச்சிடு' : 'Print PO Voucher', style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFleetBusCard(Map<String, dynamic> bus, bool isTa) {
    final busNo = bus['bus_number'] ?? '—';
    final regNo = bus['registration_no'] ?? '—';
    final capacity = bus['capacity'] != null
        ? '${bus['capacity']} ${isTa ? "இருக்கைகள்" : "Seats"}'
        : (isTa ? '55 இருக்கைகள்' : '55 Seats');
    final rawDriverName = bus['driver_name'];
    final driverName = (rawDriverName != null && rawDriverName.toString().trim().isNotEmpty)
        ? rawDriverName.toString()
        : (isTa ? 'நியமிக்கப்படவில்லை' : 'Not Assigned');
    final driverPhone = bus['driver_phone'] ?? '';
    final odo = bus['current_odometer'] != null ? '${bus['current_odometer']} km' : '—';
    final lastAddress = bus['last_hardware_address'] ?? (isTa ? 'இயக்கத்தில் உள்ளது' : 'Live Fleet');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 1.5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bus $busNo', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                      Text('$regNo • $capacity', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  isTa ? 'இயக்கத்தில் உள்ளது' : 'Active Bus',
                  style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w800, fontSize: 10),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isTa ? 'ஓட்டுநர்' : 'Driver', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(driverName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  if (driverPhone.isNotEmpty)
                    Text(driverPhone, style: const TextStyle(fontSize: 10.5, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(isTa ? 'தற்போதைய கி.மீ (Odo)' : 'Current Odometer (Odo)', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(odo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E3A8A))),
                  Text(lastAddress, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedBusId = bus['bus_id']?.toString();
                      _tabController.animateTo(0);
                    });
                  },
                  icon: const Icon(Icons.assignment_rounded, size: 14),
                  label: Text(isTa ? 'KM பதிவுகள்' : 'View KM Logs', style: const TextStyle(fontSize: 11.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF312E81),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    context.push('/supervisor/ticket/new', extra: bus);
                  },
                  icon: const Icon(Icons.handyman_rounded, size: 14),
                  label: Text(
                    isTa ? 'PO / பழுது பதிவு' : 'Log Issue / PO',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
