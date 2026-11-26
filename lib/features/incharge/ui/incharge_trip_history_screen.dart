import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/widgets/app_loader.dart';
import '../providers/incharge_provider.dart';

class InchargeTripHistoryScreen extends ConsumerStatefulWidget {
  const InchargeTripHistoryScreen({super.key});

  @override
  ConsumerState<InchargeTripHistoryScreen> createState() => _InchargeTripHistoryScreenState();
}

class _InchargeTripHistoryScreenState extends ConsumerState<InchargeTripHistoryScreen> {
  String _selectedFilter = 'all'; // 'all', 'morning', 'evening'
  DateTime? _selectedDate;

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return dateVal.toString();
    }
  }

  String _formatTime(dynamic timeVal) {
    if (timeVal == null) return '—';
    try {
      final dt = DateTime.parse(timeVal.toString()).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return timeVal.toString();
    }
  }

  Future<void> _downloadOrPrintTripPdf(Map<String, dynamic> trip) async {
    await globalAction(() async {
      final api = ref.read(apiClientProvider);
      final tripId = (trip['id'] ?? '').toString();

      final res = await api.getTripAttendance(tripId);
      final data = res.data['data'] as Map<String, dynamic>?;
      final tripMeta = (data?['trip'] as Map<String, dynamic>?) ?? trip;
      final attendanceList = List<Map<String, dynamic>>.from(data?['attendance'] ?? []);

      await PdfReportService.printTripReport(
        trip: tripMeta,
        attendanceRecords: attendanceList,
      );
    },
    message: 'Compiling & Generating PDF Attendance Report...',
    errorMessage: 'Could not generate PDF report. Please try again.',
    );
  }

  void _showPhotoDialog(BuildContext context, String title, String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.badge_rounded, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Failed to load ID photo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTripRosterModal(Map<String, dynamic> trip) {
    final tripId = (trip['id'] ?? '').toString();
    final busNo = trip['bus_number'] ?? 'Bus';
    final routeName = trip['route_name'] ?? 'Route';
    final tripDate = _formatDate(trip['trip_date']);
    final tripType = (trip['trip_type'] ?? 'morning').toString().toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => FutureBuilder(
          future: ref.read(apiClientProvider).getTripAttendance(tripId),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.danger)));
            }

            final res = snapshot.data;
            final data = res?.data['data'] as Map<String, dynamic>?;
            final attendance = List<Map<String, dynamic>>.from(data?['attendance'] ?? []);

            final ownStudents = attendance.where((a) {
              final isGuest = a['is_guest'] == true || a['cross_bus_status'] == 'GUEST';
              final isQuickAdd = a['method'] == 'quick_add' || a['cross_bus_status'] == 'QUICK-ADD';
              final isCross = a['cross_bus_status'] == 'CROSS-BUS';
              return !isGuest && !isQuickAdd && !isCross;
            }).toList();

            final crossBusStudents = attendance.where((a) => a['cross_bus_status'] == 'CROSS-BUS').toList();
            final guestStudents = attendance.where((a) => a['is_guest'] == true || a['cross_bus_status'] == 'GUEST').toList();
            final quickAddStudents = attendance.where((a) => a['method'] == 'quick_add' || a['cross_bus_status'] == 'QUICK-ADD').toList();

            final ownPresentCount = ownStudents.where((a) => a['status'] == 'present').length;
            final ownAbsentCount = ownStudents.where((a) => a['status'] == 'absent').length;
            final totalPresent = attendance.where((a) => a['status'] == 'present').length;
            final totalAbsent = attendance.where((a) => a['status'] == 'absent').length;

            int selectedTab = 0; // 0: Own, 1: Cross-Bus, 2: Guest Snap, 3: Quick Add, 4: All

            return StatefulBuilder(
              builder: (context, setModalState) {
                List<Map<String, dynamic>> currentList;
                if (selectedTab == 0) {
                  currentList = ownStudents;
                } else if (selectedTab == 1) {
                  currentList = crossBusStudents;
                } else if (selectedTab == 2) {
                  currentList = guestStudents;
                } else if (selectedTab == 3) {
                  currentList = quickAddStudents;
                } else {
                  currentList = attendance;
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$tripType Roster • $tripDate', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                                const SizedBox(height: 2),
                                Text('$busNo • $routeName', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _downloadOrPrintTripPdf(trip);
                            },
                            icon: const Icon(Icons.print_rounded, size: 15),
                            label: const Text('Print PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
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
                      const SizedBox(height: 12),

                      // Horizontal Sub-category Filter Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTabChip(
                              label: '🚍 Own Roster (${ownStudents.length})',
                              isSelected: selectedTab == 0,
                              activeColor: const Color(0xFF1E40AF),
                              activeBgColor: const Color(0xFFEFF6FF),
                              onTap: () => setModalState(() => selectedTab = 0),
                            ),
                            const SizedBox(width: 6),
                            _buildTabChip(
                              label: '🔀 Cross-Bus (${crossBusStudents.length})',
                              isSelected: selectedTab == 1,
                              activeColor: const Color(0xFFB45309),
                              activeBgColor: const Color(0xFFFEF3C7),
                              onTap: () => setModalState(() => selectedTab = 1),
                            ),
                            if (guestStudents.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _buildTabChip(
                                label: '📸 Guest Snap (${guestStudents.length})',
                                isSelected: selectedTab == 2,
                                activeColor: const Color(0xFF7C3AED),
                                activeBgColor: const Color(0xFFF3E8FF),
                                onTap: () => setModalState(() => selectedTab = 2),
                              ),
                            ],
                            if (quickAddStudents.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _buildTabChip(
                                label: '⚡ Quick Add (${quickAddStudents.length})',
                                isSelected: selectedTab == 3,
                                activeColor: const Color(0xFF0284C7),
                                activeBgColor: const Color(0xFFE0F2FE),
                                onTap: () => setModalState(() => selectedTab = 3),
                              ),
                            ],
                            const SizedBox(width: 6),
                            _buildTabChip(
                              label: '📋 All (${attendance.length})',
                              isSelected: selectedTab == 4,
                              activeColor: const Color(0xFF334155),
                              activeBgColor: const Color(0xFFF1F5F9),
                              onTap: () => setModalState(() => selectedTab = 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // KPI Pill Status Row based on active selection
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            if (selectedTab == 0) ...[
                              Text('Quota: ${ownStudents.length} Students', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                              const Text(' • ', style: TextStyle(color: Colors.grey)),
                              Text('$ownPresentCount Boarded', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                              const Text(' • ', style: TextStyle(color: Colors.grey)),
                              Text('$ownAbsentCount Absent', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF991B1B))),
                            ] else if (selectedTab == 1) ...[
                              Text('Cross-Bus: ${crossBusStudents.length} Students from other buses', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                            ] else if (selectedTab == 2) ...[
                              Text('Guest Riders: ${guestStudents.length} verified via ID photo snap', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))),
                            ] else if (selectedTab == 3) ...[
                              Text('Quick Add: ${quickAddStudents.length} spot registrations', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                            ] else ...[
                              Text('$totalPresent Boarded', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF166534))),
                              const Text(' • ', style: TextStyle(color: Colors.grey)),
                              Text('$totalAbsent Absent', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF991B1B))),
                              const Spacer(),
                              Text('Total: ${attendance.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 8),

                      Expanded(
                        child: currentList.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    selectedTab == 0
                                        ? 'No registered students for this bus.'
                                        : (selectedTab == 1
                                            ? 'No cross-bus students boarded this trip.'
                                            : (selectedTab == 2
                                                ? 'No guest riders recorded.'
                                                : (selectedTab == 3
                                                    ? 'No quick-add students recorded.'
                                                    : 'No attendance records logged for this trip.'))),
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollCtrl,
                                itemCount: currentList.length,
                                itemBuilder: (context, index) {
                                  final att = currentList[index];
                                  final isGuest = att['is_guest'] == true || att['cross_bus_status'] == 'GUEST';
                                  final isQuickAdd = att['method'] == 'quick_add' || att['cross_bus_status'] == 'QUICK-ADD';
                                  final isCrossBus = att['cross_bus_status'] == 'CROSS-BUS';
                                  final isPresent = (att['status'] ?? '').toString().toLowerCase() == 'present';
                                  final isAbsent = (att['status'] ?? '').toString().toLowerCase() == 'absent';

                                  final sName = att['student_name'] ?? att['guest_name'] ?? att['name'] ?? (isGuest ? 'Guest Rider' : 'Student');
                                  final rollNo = isGuest
                                      ? (att['guest_roll_number'] ?? att['roll_number'] ?? 'GUEST').toString()
                                      : (att['roll_number'] ?? '').toString();

                                  final assignedStop = att['assigned_stage_name'] ?? att['assigned_stop'] ?? (isGuest ? '—' : 'Assigned Stop');
                                  final boardedStop = isAbsent ? '—' : (att['boarded_stage_name'] ?? att['boarded_stop'] ?? '—');
                                  final markedAt = _formatTime(att['marked_at']);
                                  final hasPhoto = att['guest_id_photo_url'] != null && (att['guest_id_photo_url'] as String).isNotEmpty;
                                  final assignedBus = (att['assigned_bus_number'] ?? '').toString();

                                  bool isMatch = false;
                                  if (isPresent && !isGuest) {
                                    isMatch = assignedStop.toString().trim().toLowerCase() == boardedStop.toString().trim().toLowerCase() ||
                                        boardedStop.toString().trim().toLowerCase().contains(assignedStop.toString().trim().toLowerCase());
                                  }

                                  Color cardBg = const Color(0xFFF8FAFC);
                                  Color cardBorder = const Color(0xFFE2E8F0);
                                  if (isAbsent) {
                                    cardBg = const Color(0xFFFFF1F2);
                                    cardBorder = const Color(0xFFFECDD3);
                                  } else if (isGuest) {
                                    cardBg = const Color(0xFFFAF5FF);
                                    cardBorder = const Color(0xFFE9D5FF);
                                  } else if (isCrossBus) {
                                    cardBg = const Color(0xFFFFFBEB);
                                    cardBorder = const Color(0xFFFDE68A);
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: isAbsent
                                              ? const Color(0xFFFEE2E2)
                                              : (isGuest
                                                  ? const Color(0xFFF3E8FF)
                                                  : (isCrossBus ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF))),
                                          child: Icon(
                                            isAbsent
                                                ? Icons.close_rounded
                                                : (isGuest
                                                    ? Icons.card_membership_rounded
                                                    : (isCrossBus ? Icons.alt_route_rounded : Icons.check_rounded)),
                                            size: 18,
                                            color: isAbsent
                                                ? AppTheme.danger
                                                : (isGuest
                                                    ? const Color(0xFF7C3AED)
                                                    : (isCrossBus ? const Color(0xFFB45309) : const Color(0xFF1E40AF))),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      sName,
                                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textPrimary),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (rollNo.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                                      child: Text(rollNo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),

                                              // Category badges row
                                              Row(
                                                children: [
                                                  if (isGuest)
                                                    Container(
                                                      margin: const EdgeInsets.only(right: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(4)),
                                                      child: const Text('GUEST SNAP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED))),
                                                    )
                                                  else if (isCrossBus)
                                                    Container(
                                                      margin: const EdgeInsets.only(right: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                                      child: Text('CROSS-BUS (Assigned: $assignedBus)', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                                                    )
                                                  else if (isQuickAdd)
                                                    Container(
                                                      margin: const EdgeInsets.only(right: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(4)),
                                                      child: const Text('QUICK-ADD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF0284C7))),
                                                    ),
                                                  if (isAbsent)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                                                      child: const Text('ABSENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.danger)),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),

                                              if (isAbsent)
                                                Text('Assigned Stop: $assignedStop', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))
                                              else if (isGuest)
                                                Text('Guest Check-in • $markedAt', style: const TextStyle(fontSize: 10.5, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600))
                                              else
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text('Boarded: $boardedStop ($markedAt)', style: const TextStyle(fontSize: 10.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: isMatch ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                                        borderRadius: BorderRadius.circular(3),
                                                      ),
                                                      child: Text(
                                                        isMatch ? 'MATCH' : 'STAGE MISMATCH',
                                                        style: TextStyle(
                                                          fontSize: 8.5,
                                                          fontWeight: FontWeight.w800,
                                                          color: isMatch ? const Color(0xFF166534) : const Color(0xFFB45309),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (hasPhoto) ...[
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: const Icon(Icons.image_outlined, color: Color(0xFF7C3AED), size: 22),
                                            tooltip: 'View ID Photo',
                                            onPressed: () => _showPhotoDialog(
                                              context,
                                              '$sName ID Photo',
                                              att['guest_id_photo_url'],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color activeBgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor.withOpacity(0.5) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? activeColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(inchargeTripsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Trip History & PDF Logs', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryAccent),
            tooltip: 'Refresh Trip Logs',
            onPressed: () {
              ref.invalidate(inchargeTripsProvider);
              AppSnackBar.showInfo(context, 'Trip history refreshed');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryAccent,
        onRefresh: () async => ref.invalidate(inchargeTripsProvider),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Filter bar & Date selector
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      // Filter Pills Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterPill(
                              label: 'All Shifts',
                              isSelected: _selectedFilter == 'all',
                              onTap: () => setState(() => _selectedFilter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _FilterPill(
                              label: 'Morning (Pickup)',
                              icon: Icons.wb_sunny_rounded,
                              isSelected: _selectedFilter == 'morning',
                              onTap: () => setState(() => _selectedFilter = 'morning'),
                            ),
                            const SizedBox(width: 8),
                            _FilterPill(
                              label: 'Evening (Drop)',
                              icon: Icons.nights_stay_rounded,
                              isSelected: _selectedFilter == 'evening',
                              onTap: () => setState(() => _selectedFilter = 'evening'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate ?? DateTime.now(),
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                }
                              },
                              icon: const Icon(Icons.calendar_today_rounded, size: 13),
                              label: Text(
                                _selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : 'Pick Date',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _selectedDate != null ? const Color(0xFF1E40AF) : AppTheme.textSecondary,
                                side: BorderSide(color: _selectedDate != null ? const Color(0xFF1E40AF) : const Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            if (_selectedDate != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                icon: const Icon(Icons.clear_rounded, size: 16, color: AppTheme.textMuted),
                                onPressed: () => setState(() => _selectedDate = null),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Trips List
                Expanded(
                  child: tripsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                    error: (e, _) => Center(child: Text('Error loading trip history: $e', style: const TextStyle(color: AppTheme.danger))),
                    data: (rawTrips) {
                      var filtered = rawTrips.where((t) {
                        final type = (t['trip_type'] ?? '').toString().toLowerCase();
                        if (_selectedFilter == 'morning' && type != 'morning') return false;
                        if (_selectedFilter == 'evening' && type != 'evening') return false;

                        if (_selectedDate != null) {
                          final tDate = t['trip_date'];
                          if (tDate != null) {
                            try {
                              final dt = DateTime.parse(tDate.toString());
                              if (dt.year != _selectedDate!.year || dt.month != _selectedDate!.month || dt.day != _selectedDate!.day) {
                                return false;
                              }
                            } catch (_) {}
                          }
                        }
                        return true;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_bus_outlined, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text('No trips found', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                              const SizedBox(height: 4),
                              const Text('No past trip records matched your filters.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final trip = filtered[index];
                          return _DedicatedTripCard(
                            trip: trip,
                            onPrintPdf: () => _downloadOrPrintTripPdf(trip),
                            onViewRoster: () => _showTripRosterModal(trip),
                            formatDate: _formatDate,
                            formatTime: _formatTime,
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
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: isSelected ? Colors.white : AppTheme.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DedicatedTripCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onPrintPdf;
  final VoidCallback onViewRoster;
  final String Function(dynamic) formatDate;
  final String Function(dynamic) formatTime;

  const _DedicatedTripCard({
    required this.trip,
    required this.onPrintPdf,
    required this.onViewRoster,
    required this.formatDate,
    required this.formatTime,
  });

  @override
  State<_DedicatedTripCard> createState() => _DedicatedTripCardState();
}

class _DedicatedTripCardState extends State<_DedicatedTripCard> {
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final tripType = (trip['trip_type'] ?? 'morning').toString().toUpperCase();
    final tripDirection = (trip['trip_direction'] ?? 'boarding').toString().toUpperCase();
    final status = (trip['status'] ?? 'completed').toString();
    final isCompleted = status == 'completed';

    final busNo = trip['bus_number'] ?? 'Bus';
    final routeName = trip['route_name'] ?? 'Route';
    final tripDate = widget.formatDate(trip['trip_date']);

    final presentCount = int.tryParse(trip['present_count']?.toString() ?? '0') ?? 0;
    final absentCount = int.tryParse(trip['absent_count']?.toString() ?? '0') ?? 0;
    final ownPresent = int.tryParse(trip['own_present_count']?.toString() ?? '') ?? presentCount;
    final crossBusCount = int.tryParse(trip['cross_bus_count']?.toString() ?? '0') ?? 0;
    final guestCount = int.tryParse(trip['guest_count']?.toString() ?? '0') ?? 0;
    final quickAddCount = int.tryParse(trip['quick_add_count']?.toString() ?? '0') ?? 0;
    final totalStudents = int.tryParse(trip['total_students']?.toString() ?? '0') ?? (ownPresent + absentCount);
    final pct = totalStudents > 0 ? (presentCount / totalStudents).clamp(0.0, 1.0) : 0.0;

    final startStr = trip['actual_start'] ?? trip['scheduled_start'];
    final endStr = trip['actual_end'];
    final startTime = widget.formatTime(startStr);
    final endTime = widget.formatTime(endStr);

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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type, Direction, Date & Status
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tripType == 'MORNING' ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    tripType == 'MORNING' ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                    color: tripType == 'MORNING' ? const Color(0xFFB45309) : const Color(0xFF1E40AF),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$tripType • $tripDirection',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Date: $tripDate  |  $startTime – $endTime',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCompleted ? 'Finalized' : 'Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isCompleted ? const Color(0xFF166534) : const Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Route & Bus Info
            Row(
              children: [
                const Icon(Icons.directions_bus_rounded, size: 14, color: Color(0xFF1E40AF)),
                const SizedBox(width: 4),
                Text(busNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))),
                const SizedBox(width: 8),
                const Icon(Icons.alt_route_rounded, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    routeName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Attendance Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$presentCount / $totalStudents Boarded (${(pct * 100).toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                if (absentCount > 0)
                  Text(
                    '$absentCount Absent',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.danger),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 0.8 ? const Color(0xFF22C55E) : (pct >= 0.5 ? const Color(0xFFF59E0B) : AppTheme.danger),
                ),
              ),
            ),

            const SizedBox(height: 8),
            // Categorized Breakdown Pills
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildTripPill('🚍 Own: $ownPresent', const Color(0xFFDCFCE7), const Color(0xFF166534)),
                if (absentCount > 0)
                  _buildTripPill('❌ Absent: $absentCount', const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
                if (crossBusCount > 0)
                  _buildTripPill('🔀 Cross: $crossBusCount', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
                if (guestCount > 0)
                  _buildTripPill('📸 Guest: $guestCount', const Color(0xFFF3E8FF), const Color(0xFF7C3AED)),
                if (quickAddCount > 0)
                  _buildTripPill('⚡ Quick: $quickAddCount', const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
              ],
            ),

            const SizedBox(height: 12),

            // Action Buttons Row: [View Roster] [Print PDF]
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onViewRoster,
                    icon: const Icon(Icons.people_outline_rounded, size: 14),
                    label: const Text('View Roster', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E40AF),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting
                        ? null
                        : () async {
                            setState(() => _isPrinting = true);
                            try {
                              widget.onPrintPdf();
                            } finally {
                              if (mounted) setState(() => _isPrinting = false);
                            }
                          },
                    icon: _isPrinting
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.print_rounded, size: 14),
                    label: const Text('Print PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}
