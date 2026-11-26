import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../providers/incharge_provider.dart';

const List<Map<String, String>> _institutionMaster = [
  {'name': 'Vellalar college for women', 'code': 'VCW'},
  {'name': 'Vellalar college of education', 'code': 'VCE'},
  {'name': 'Vellalar college of engineering and technology', 'code': 'VCET'},
  {'name': 'Vellalar college of nursing', 'code': 'VCN'},
  {'name': 'Vellalar college of pharmacy', 'code': 'VCP'},
  {'name': 'Vellalar physiotherapy college', 'code': 'VPC'},
  {'name': 'Vellalar vidyalaya senior secondary school', 'code': 'VVSSS'},
  {'name': 'VET institute of arts and science', 'code': 'VETIAS'},
];

class StudentCrudScreen extends ConsumerStatefulWidget {
  const StudentCrudScreen({super.key});

  @override
  ConsumerState<StudentCrudScreen> createState() => _StudentCrudScreenState();
}

class _StudentCrudScreenState extends ConsumerState<StudentCrudScreen> {
  String _searchQuery = '';
  String? _selectedStageId;
  String? _selectedInstitution;
  String _selectedCategory = 'ALL'; // 'ALL', 'Student', 'Staff'

  static List<String> get _institutionList => _institutionMaster.map((e) => e['name']!).toList();

  static const List<String> _studentYearList = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    'Postgraduate',
  ];

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(routeStudentsProvider);
    final assignmentAsync = ref.watch(inchargeAssignmentProvider);

    final assignment = assignmentAsync.valueOrNull ?? {};
    final busNumber = assignment['bus_number']?.toString() ?? 'Assigned Bus';
    final routeName = assignment['route_name']?.toString() ?? 'Route';
    final stages = assignment['stages'] as List? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bus Passenger Directory',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textPrimary),
            ),
            Text(
              'Bus $busNumber • $routeName',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryAccent),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(routeStudentsProvider);
              AppSnackBar.showInfo(context, 'Passenger directory refreshed');
            },
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryAccent),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudentDialog(stages, busNumber, routeName),
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text('Add Passenger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryAccent,
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by Roll No, Name, Class, Dept, or Phone...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryAccent, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Category Filter Tabs (All / Students / Staff)
                Row(
                  children: [
                    _categoryFilterButton('ALL', 'All', Icons.people_alt_outlined),
                    const SizedBox(width: 8),
                    _categoryFilterButton('Student', 'Students', Icons.school_outlined),
                    const SizedBox(width: 8),
                    _categoryFilterButton('Staff', 'Staff', Icons.badge_outlined),
                  ],
                ),

                const SizedBox(height: 8),

                // Boarding Stops Filter Chips
                if (stages.isNotEmpty) ...[
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            selected: _selectedStageId == null,
                            label: const Text('All Stops', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            onSelected: (_) => setState(() => _selectedStageId = null),
                            selectedColor: const Color(0xFFE0E7FF),
                            checkmarkColor: AppTheme.primaryAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                        ...stages.map((st) {
                          final isSelected = _selectedStageId == st['id'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text('${st['stage_name']}', style: const TextStyle(fontSize: 11)),
                              onSelected: (_) => setState(() => _selectedStageId = isSelected ? null : st['id']),
                              selectedColor: const Color(0xFFE0E7FF),
                              checkmarkColor: AppTheme.primaryAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Institution Filter Chips (Codes from Master)
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: _selectedInstitution == null,
                          label: const Text('All Colleges', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          onSelected: (_) => setState(() => _selectedInstitution = null),
                          selectedColor: const Color(0xFFDBEAFE),
                          checkmarkColor: AppTheme.primaryAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                      ..._institutionMaster.map((inst) {
                        final isSelected = _selectedInstitution == inst['name'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(inst['code']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            tooltip: inst['name'],
                            onSelected: (_) => setState(() => _selectedInstitution = isSelected ? null : inst['name']),
                            selectedColor: const Color(0xFFDBEAFE),
                            checkmarkColor: AppTheme.primaryAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Students Roster List
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primaryAccent,
              onRefresh: () async => ref.invalidate(routeStudentsProvider),
              child: studentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
                        const SizedBox(height: 12),
                        Text('Failed to load passengers: $e', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: () => ref.invalidate(routeStudentsProvider), child: const Text('Retry')),
                      ],
                    ),
                  ),
                ),
                data: (students) {
                  final filtered = students.where((s) {
                    final name = (s['name'] as String? ?? '').toLowerCase();
                    final roll = (s['roll_number'] as String? ?? '').toLowerCase();
                    final className = (s['class_name'] as String? ?? '').toLowerCase();
                    final dept = (s['department'] as String? ?? '').toLowerCase();
                    final inst = (s['institution_type'] as String? ?? '').toLowerCase();
                    final phone = (s['phone'] as String? ?? '').toLowerCase();
                    final category = s['category'] as String? ?? 'Student';
                    final stageId = s['assigned_stage_id'] as String?;

                    // Category filter
                    if (_selectedCategory != 'ALL' && category.toLowerCase() != _selectedCategory.toLowerCase()) {
                      return false;
                    }

                    // Stage filter
                    if (_selectedStageId != null && stageId != _selectedStageId) {
                      return false;
                    }

                    // Institution filter
                    if (_selectedInstitution != null && !inst.contains(_selectedInstitution!.toLowerCase())) {
                      return false;
                    }

                    // Search query
                    if (_searchQuery.isNotEmpty) {
                      final matches = name.contains(_searchQuery) ||
                          roll.contains(_searchQuery) ||
                          className.contains(_searchQuery) ||
                          dept.contains(_searchQuery) ||
                          inst.contains(_searchQuery) ||
                          phone.contains(_searchQuery);
                      if (!matches) return false;
                    }

                    return true;
                  }).toList();

                  final studentCount = filtered.where((s) => (s['category'] ?? 'Student') == 'Student').length;
                  final staffCount = filtered.where((s) => (s['category'] ?? 'Student') == 'Staff').length;

                  return Column(
                    children: [
                      // Sub-header stats count (Guarded with Expanded against overflow)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: const Color(0xFFF1F5F9),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                filtered.length == students.length
                                    ? 'Bus $busNumber • ${students.length} Total Passengers'
                                    : 'Showing ${filtered.length} of ${students.length} Passengers',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _badgeChip('🎓 $studentCount', const Color(0xFFEFF6FF), const Color(0xFF1E40AF)),
                            const SizedBox(width: 6),
                            _badgeChip('👔 $staffCount', const Color(0xFFF5F3FF), const Color(0xFF6D28D9)),
                          ],
                        ),
                      ),

                      if (filtered.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const FeatureIconBadge(icon: Icons.people_outline_rounded, color: AppTheme.textMuted, size: 54),
                                const SizedBox(height: 12),
                                const Text('No Passengers Found', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                                const SizedBox(height: 4),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No passengers match your filter criteria'
                                      : 'No students or staff assigned to Bus $busNumber yet',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final student = filtered[i];
                              return _StudentCard(
                                student: student,
                                stages: stages,
                                busNumber: busNumber,
                                routeName: routeName,
                                onEdit: () => _showEditStudentDialog(student, stages, busNumber, routeName),
                                onDelete: () => _confirmDeleteStudent(student),
                                onShowQr: () => _showQrPassDialog(student, busNumber),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryFilterButton(String category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = category),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: isSelected ? Colors.white : AppTheme.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeChip(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textCol.withOpacity(0.2)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textCol)),
    );
  }

  // ============================================================
  // Duplicate Conflict Warning Modal
  // ============================================================
  void _showConflictDialog(BuildContext parentContext, String message, Map<String, dynamic> conflictDetails) {
    showDialog(
      context: parentContext,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Duplicate Entry Detected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.danger)),
                  Text('Roll No / Library ID already taken', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CURRENT ASSIGNEE DETAILS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  _conflictDetailRow(Icons.person_rounded, 'Student / Staff', conflictDetails['name'] ?? '—'),
                  _conflictDetailRow(Icons.badge_rounded, 'Roll / Library No', conflictDetails['rollNumber'] ?? '—'),
                  _conflictDetailRow(Icons.directions_bus_rounded, 'Assigned Bus', conflictDetails['busNumber'] ?? '—'),
                  _conflictDetailRow(Icons.alt_route_rounded, 'Route', conflictDetails['routeName'] ?? '—'),
                  _conflictDetailRow(Icons.school_rounded, 'Department', conflictDetails['department'] ?? '—'),
                  if ((conflictDetails['phone'] ?? '').toString().isNotEmpty && conflictDetails['phone'] != 'N/A')
                    _conflictDetailRow(Icons.phone_rounded, 'Contact Phone', conflictDetails['phone']),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please verify with the person above or admin before re-assigning this Library / Roll Number.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Check & Change Number', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _conflictDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryAccent),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Add Passenger Dialog (Locked strictly to incharge's bus)
  // ============================================================
  void _showAddStudentDialog(List stages, String busNumber, String routeName) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: 'General');
    final designationCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final parentPhoneCtrl = TextEditingController();

    String category = 'Student';
    String selectedInstitution = 'Vellalar college of engineering and technology';
    String selectedYear = '1st Year';
    bool isSubmitting = false;
    String? formError;

    final stageMap = <String, String>{};
    for (final st in stages) {
      final id = st['id']?.toString() ?? '';
      if (id.isNotEmpty) stageMap[id] = st['stage_name']?.toString() ?? 'Stop';
    }
    String? selectedStage = stageMap.isNotEmpty ? stageMap.keys.first : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Register to Bus', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text('Route $routeName • Bus $busNumber', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (formError != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formError!,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w600, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Assigned Route & Bus Badge
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alt_route_rounded, color: Color(0xFF1E40AF), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Route: $routeName',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Assigned Bus: $busNumber',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Passenger Category Toggle
                const Text('Passenger Category *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_outlined, size: 16),
                            SizedBox(width: 6),
                            Text('Student', style: TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        selected: category == 'Student',
                        selectedColor: const Color(0xFFDBEAFE),
                        onSelected: (val) {
                          if (val) setS(() => category = 'Student');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.badge_outlined, size: 16),
                            SizedBox(width: 6),
                            Text('Staff', style: TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        selected: category == 'Staff',
                        selectedColor: const Color(0xFFF3E8FF),
                        onSelected: (val) {
                          if (val) setS(() => category = 'Staff');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Roll Number / Staff ID
                TextFormField(
                  controller: rollCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: category == 'Student' ? 'Roll Number *' : 'Staff ID *',
                    hintText: category == 'Student' ? 'e.g. 24UCO111 or 24AM07' : 'e.g. STF-102',
                    prefixIcon: const Icon(Icons.pin_outlined, size: 18),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Full Name
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. BOOMIKA .M',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                ),
                const SizedBox(height: 12),

                // Class Name (e.g. III B.Sc.Maths)
                TextFormField(
                  controller: classCtrl,
                  decoration: InputDecoration(
                    labelText: category == 'Student' ? 'Class & Section *' : 'Designation / Section',
                    hintText: category == 'Student' ? 'e.g. III B.Sc.Maths or I B.A.English' : 'e.g. Admin Office / Faculty',
                    prefixIcon: const Icon(Icons.class_outlined, size: 18),
                  ),
                  validator: (v) {
                    if (category == 'Student' && (v == null || v.trim().isEmpty)) {
                      return 'Class Name is required for students';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // If Staff: Designation Field
                if (category == 'Staff') ...[
                  TextFormField(
                    controller: designationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Staff Designation',
                      hintText: 'e.g. Assistant Professor / Lab Tech',
                      prefixIcon: Icon(Icons.work_outline_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Department
                TextFormField(
                  controller: deptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Department / Branch',
                    hintText: 'e.g. Mathematics, Commerce, CSE',
                    prefixIcon: Icon(Icons.business_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                // Institution / Stream
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _institutionList.contains(selectedInstitution) ? selectedInstitution : _institutionList.first,
                  decoration: const InputDecoration(
                    labelText: 'Institution / Campus Unit *',
                    prefixIcon: Icon(Icons.apartment_outlined, size: 18),
                  ),
                  items: _institutionMaster.map((inst) => DropdownMenuItem<String>(
                    value: inst['name'],
                    child: Text('${inst['name']} (${inst['code']})', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setS(() => selectedInstitution = v ?? _institutionList.first),
                ),
                const SizedBox(height: 12),

                // Year of Study (for students)
                if (category == 'Student') ...[
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _studentYearList.contains(selectedYear) ? selectedYear : _studentYearList.first,
                    decoration: const InputDecoration(
                      labelText: 'Year of Study *',
                      prefixIcon: Icon(Icons.timeline_outlined, size: 18),
                    ),
                    items: _studentYearList.map((yr) => DropdownMenuItem<String>(
                      value: yr,
                      child: Text(yr, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setS(() => selectedYear = v ?? '1st Year'),
                  ),
                  const SizedBox(height: 12),
                ],

                // Boarding Stop Dropdown
                if (stageMap.isNotEmpty)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: stageMap.containsKey(selectedStage) ? selectedStage : stageMap.keys.first,
                    decoration: const InputDecoration(
                      labelText: 'Boarding Bus Stop',
                      prefixIcon: Icon(Icons.directions_bus_outlined, size: 18),
                    ),
                    items: stageMap.entries.map((e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setS(() => selectedStage = v),
                  ),
                const SizedBox(height: 12),

                // Phone Numbers
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Passenger Phone',
                    hintText: '+91 9876543210',
                    prefixIcon: Icon(Icons.phone_android_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: parentPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: category == 'Student' ? 'Parent / Emergency Contact' : 'Emergency Contact',
                    hintText: '+91 9876543211',
                    prefixIcon: const Icon(Icons.contact_phone_outlined, size: 18),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSubmitting ? null : () async {
                if (!formKey.currentState!.validate()) return;
                final name = nameCtrl.text.trim();
                final roll = rollCtrl.text.trim().toUpperCase();
                final className = classCtrl.text.trim();
                final dept = deptCtrl.text.trim();
                final designation = designationCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final pPhone = parentPhoneCtrl.text.trim();
                final inst = selectedInstitution;
                final yr = category == 'Staff' ? 'Staff' : selectedYear;
                final stg = (selectedStage != null && selectedStage!.isNotEmpty) ? selectedStage : null;

                setS(() {
                  isSubmitting = true;
                  formError = null;
                });

                try {
                  final api = ref.read(apiClientProvider);
                  await api.addStudentToRoute({
                    'name': name,
                    'rollNumber': roll,
                    'className': className.isNotEmpty ? className : (category == 'Staff' ? 'Staff' : yr),
                    'department': dept.isNotEmpty ? dept : 'General',
                    'institutionType': inst,
                    'yearOfStudy': yr,
                    'category': category,
                    'designation': designation.isNotEmpty ? designation : null,
                    'phone': phone.isNotEmpty ? phone : null,
                    'parentPhone': pPhone.isNotEmpty ? pPhone : null,
                    'stageId': stg,
                  });
                  ref.invalidate(routeStudentsProvider);
                  ref.invalidate(inchargeAssignmentProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    AppSnackBar.showSuccess(context, '$category $name ($roll) registered to Bus $busNumber successfully!');
                  }
                } catch (e) {
                  String errMsg = 'Failed to register passenger';
                  Map<String, dynamic>? conflictDetails;
                  if (e is DioException) {
                    final data = e.response?.data;
                    if (data is Map) {
                      if (data['error'] != null) errMsg = data['error'].toString();
                      if (data['conflictingPassenger'] is Map) {
                        conflictDetails = Map<String, dynamic>.from(data['conflictingPassenger']);
                      }
                    }
                  } else {
                    errMsg = e.toString().replaceAll('Exception:', '').trim();
                  }

                  setS(() {
                    isSubmitting = false;
                    formError = errMsg;
                  });

                  if (conflictDetails != null && ctx.mounted) {
                    _showConflictDialog(ctx, errMsg, conflictDetails);
                  } else if (mounted) {
                    AppSnackBar.showError(context, errMsg);
                  }
                }
              },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Register Passenger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Edit Passenger Dialog (All Fields matching Admin)
  // ============================================================
  void _showEditStudentDialog(Map<String, dynamic> student, List stages, String busNumber, String routeName) {
    final formKey = GlobalKey<FormState>();
    final rollCtrl = TextEditingController(text: student['roll_number']);
    final nameCtrl = TextEditingController(text: student['name']);
    final classCtrl = TextEditingController(text: student['class_name'] ?? '');
    final deptCtrl = TextEditingController(text: student['department'] ?? '');
    final designationCtrl = TextEditingController(text: student['designation'] ?? '');
    final phoneCtrl = TextEditingController(text: student['phone'] ?? '');
    final parentPhoneCtrl = TextEditingController(text: student['parent_phone'] ?? '');

    String category = (student['category'] ?? 'Student').toString();
    String selectedInstitution = (student['institution_type'] ?? 'Engineering').toString();
    final currentInstList = List<String>.from(_institutionList);
    if (!currentInstList.contains(selectedInstitution)) {
      currentInstList.insert(0, selectedInstitution);
    }

    String selectedYear = (student['year_of_study'] ?? '1st Year').toString();
    final currentYearList = List<String>.from(_studentYearList);
    if (selectedYear != 'Staff' && !currentYearList.contains(selectedYear)) {
      currentYearList.insert(0, selectedYear);
    }

    bool isActive = student['is_active'] ?? true;
    bool isSubmitting = false;
    String? formError;

    final stageMap = <String, String>{};
    for (final st in stages) {
      final id = st['id']?.toString() ?? '';
      if (id.isNotEmpty) stageMap[id] = st['stage_name']?.toString() ?? 'Stop';
    }
    String? selectedStage = student['assigned_stage_id']?.toString();
    if (selectedStage != null && !stageMap.containsKey(selectedStage)) {
      selectedStage = stageMap.isNotEmpty ? stageMap.keys.first : null;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppTheme.primaryAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit ${student['roll_number']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text('Route: ${student['route_name'] ?? routeName} • Bus: ${student['bus_number'] ?? busNumber}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (formError != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formError!,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w600, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Assigned Route & Bus Badge
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alt_route_rounded, color: Color(0xFF1E40AF), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Route: ${student['route_name'] ?? routeName}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Assigned Bus: ${student['bus_number'] ?? busNumber}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Category Selector
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Student', style: TextStyle(fontWeight: FontWeight.w700)),
                        selected: category == 'Student',
                        selectedColor: const Color(0xFFDBEAFE),
                        onSelected: (val) {
                          if (val) setS(() => category = 'Student');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Staff', style: TextStyle(fontWeight: FontWeight.w700)),
                        selected: category == 'Staff',
                        selectedColor: const Color(0xFFF3E8FF),
                        onSelected: (val) {
                          if (val) setS(() => category = 'Staff');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Roll Number / Staff ID (Editable with duplicate protection)
                TextFormField(
                  controller: rollCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: category == 'Student' ? 'Roll Number *' : 'Staff ID *',
                    prefixIcon: const Icon(Icons.pin_outlined, size: 18),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Name
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 12),

                // Class / Section
                TextFormField(
                  controller: classCtrl,
                  decoration: InputDecoration(
                    labelText: category == 'Student' ? 'Class & Section' : 'Designation / Section',
                    hintText: category == 'Student' ? 'e.g. III B.Sc.Maths' : 'e.g. Admin Office',
                    prefixIcon: const Icon(Icons.class_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                // Staff Designation
                if (category == 'Staff') ...[
                  TextFormField(
                    controller: designationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Staff Designation',
                      prefixIcon: Icon(Icons.work_outline_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Department
                TextFormField(
                  controller: deptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Department / Branch',
                    prefixIcon: Icon(Icons.business_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                // Institution Dropdown
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: currentInstList.contains(selectedInstitution) ? selectedInstitution : currentInstList.first,
                  decoration: const InputDecoration(
                    labelText: 'Institution / Campus Unit',
                    prefixIcon: Icon(Icons.apartment_outlined, size: 18),
                  ),
                  items: currentInstList.map((inst) {
                    final match = _institutionMaster.firstWhere(
                      (m) => m['name']!.toLowerCase() == inst.toLowerCase(),
                      orElse: () => {'name': inst, 'code': ''},
                    );
                    final label = match['code']!.isNotEmpty ? '$inst (${match['code']})' : inst;
                    return DropdownMenuItem<String>(
                      value: inst,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setS(() => selectedInstitution = v ?? currentInstList.first),
                ),
                const SizedBox(height: 12),

                // Year of Study
                if (category == 'Student') ...[
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: currentYearList.contains(selectedYear) ? selectedYear : currentYearList.first,
                    decoration: const InputDecoration(
                      labelText: 'Year of Study',
                      prefixIcon: Icon(Icons.timeline_outlined, size: 18),
                    ),
                    items: currentYearList.map((yr) => DropdownMenuItem<String>(
                      value: yr,
                      child: Text(yr, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setS(() => selectedYear = v ?? '1st Year'),
                  ),
                  const SizedBox(height: 12),
                ],

                // Boarding Stop Dropdown
                if (stageMap.isNotEmpty)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: stageMap.containsKey(selectedStage) ? selectedStage : (selectedStage == null ? null : stageMap.keys.first),
                    decoration: const InputDecoration(
                      labelText: 'Boarding Stage Stop',
                      prefixIcon: Icon(Icons.directions_bus_outlined, size: 18),
                    ),
                    items: stageMap.entries.map((e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setS(() => selectedStage = v),
                  ),
                const SizedBox(height: 12),

                // Phone Numbers
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Passenger Phone',
                    prefixIcon: Icon(Icons.phone_android_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: parentPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: category == 'Student' ? 'Parent Phone' : 'Emergency Contact',
                    prefixIcon: const Icon(Icons.contact_phone_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                // Active Status Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active Transit Passenger', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text(
                    isActive ? 'Included in bus boarding roster' : 'Temporarily suspended from bus',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  value: isActive,
                  activeColor: AppTheme.primaryAccent,
                  onChanged: (v) => setS(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSubmitting ? null : () async {
                if (!formKey.currentState!.validate()) return;
                final roll = rollCtrl.text.trim();
                final name = nameCtrl.text.trim();
                final className = classCtrl.text.trim();
                final dept = deptCtrl.text.trim();
                final designation = designationCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final pPhone = parentPhoneCtrl.text.trim();
                final inst = selectedInstitution;
                final yr = category == 'Staff' ? 'Staff' : selectedYear;
                final stg = selectedStage;

                setS(() {
                  isSubmitting = true;
                  formError = null;
                });

                try {
                  final api = ref.read(apiClientProvider);
                  await api.updateStudentOnRoute(student['id'], {
                    'rollNumber': roll,
                    'name': name,
                    'className': className,
                    'department': dept,
                    'institutionType': inst,
                    'yearOfStudy': yr,
                    'category': category,
                    'designation': designation.isNotEmpty ? designation : null,
                    'phone': phone.isNotEmpty ? phone : null,
                    'parentPhone': pPhone.isNotEmpty ? pPhone : null,
                    'stageId': stg,
                    'isActive': isActive,
                  });
                  ref.invalidate(routeStudentsProvider);
                  ref.invalidate(inchargeAssignmentProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    AppSnackBar.showSuccess(context, 'Updated $name ($roll) successfully!');
                  }
                } catch (e) {
                  String errMsg = 'Failed to update passenger';
                  Map<String, dynamic>? conflictDetails;
                  if (e is DioException) {
                    final data = e.response?.data;
                    if (data is Map) {
                      if (data['error'] != null) errMsg = data['error'].toString();
                      if (data['conflictingPassenger'] is Map) {
                        conflictDetails = Map<String, dynamic>.from(data['conflictingPassenger']);
                      }
                    }
                  } else {
                    errMsg = e.toString().replaceAll('Exception:', '').trim();
                  }

                  setS(() {
                    isSubmitting = false;
                    formError = errMsg;
                  });

                  if (conflictDetails != null && ctx.mounted) {
                    _showConflictDialog(ctx, errMsg, conflictDetails);
                  } else if (mounted) {
                    AppSnackBar.showError(context, errMsg);
                  }
                }
              },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Digital QR Pass Dialog
  // ============================================================
  void _showQrPassDialog(Map<String, dynamic> student, String busNumber) {
    final qrData = student['qr_code'] ?? 'STUDENT_${student['roll_number']}';
    final name = student['name'] ?? '—';
    final roll = student['roll_number'] ?? '—';
    final className = student['class_name'] ?? student['department'] ?? 'General';
    final stopName = student['stage_name'] ?? 'Assigned Stop';
    final category = student['category'] ?? 'Student';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(20),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  '🚌 Bus $busNumber • $category Pass',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.primaryAccent),
                ),
              ),
              const SizedBox(height: 14),

              // Passenger Name & Roll
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                roll,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textMuted),
              ),
              Text(
                className,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6D28D9)),
              ),

              const SizedBox(height: 16),

              // High Resolution QR Code
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 190.0,
                  backgroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 14),

              // Stop Info Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pin_drop_rounded, size: 16, color: AppTheme.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'Stop: $stopName',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Pass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Delete / Remove Confirmation Dialog
  // ============================================================
  Future<void> _confirmDeleteStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
            SizedBox(width: 8),
            Text('Remove from Bus?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${student['name']} (${student['roll_number']}) from your bus?\n\nThey will be unassigned from this vehicle.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove from Bus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await globalAction(() async {
        final api = ref.read(apiClientProvider);
        await api.deleteStudentFromRoute(student['id']);
        ref.invalidate(routeStudentsProvider);
      },
      message: 'Removing ${student['name']} from your bus...',
      successMessage: '${student['name']} removed from your bus.',
      );
    }
  }
}

// ============================================================
// Student / Staff Passenger Card
// ============================================================

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final List stages;
  final String busNumber;
  final String? routeName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShowQr;

  const _StudentCard({
    required this.student,
    required this.stages,
    required this.busNumber,
    this.routeName,
    required this.onEdit,
    required this.onDelete,
    required this.onShowQr,
  });

  @override
  Widget build(BuildContext context) {
    final stageName = student['stage_name'] as String? ?? 'No Stop Assigned';
    final inst = student['institution_type'] as String? ?? 'Vellalar college of engineering and technology';
    final year = student['year_of_study'] as String? ?? '1st Year';
    final className = student['class_name'] as String? ?? '';
    final category = student['category'] as String? ?? 'Student';
    final designation = student['designation'] as String? ?? '';
    final isStaff = category == 'Staff';

    // Color code according to institution
    Color instColor;
    if (inst.toLowerCase().contains('pharm') || inst.toUpperCase().contains('VCP')) {
      instColor = const Color(0xFF059669);
    } else if (inst.toLowerCase().contains('arts') || inst.toUpperCase().contains('VETIAS') || inst.toUpperCase().contains('VCW')) {
      instColor = const Color(0xFF7C3AED);
    } else if (inst.toLowerCase().contains('physio') || inst.toUpperCase().contains('VPC')) {
      instColor = const Color(0xFF0891B2);
    } else if (inst.toLowerCase().contains('school') || inst.toUpperCase().contains('VVSSS')) {
      instColor = const Color(0xFFD97706);
    } else if (inst.toLowerCase().contains('nurs') || inst.toUpperCase().contains('VCN')) {
      instColor = const Color(0xFFDB2777);
    } else if (inst.toLowerCase().contains('educat') || inst.toUpperCase().contains('VCE')) {
      instColor = const Color(0xFF4F46E5);
    } else {
      instColor = const Color(0xFF1E40AF);
    }

    final nameStr = (student['name'] as String? ?? '').trim();
    final initial = nameStr.isNotEmpty ? nameStr[0].toUpperCase() : 'P';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with Category Indicator
          InkWell(
            onTap: onShowQr,
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isStaff ? const Color(0xFFF3E8FF) : instColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isStaff ? const Color(0xFFC084FC) : instColor.withOpacity(0.25), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isStaff ? const Color(0xFF6D28D9) : instColor),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      size: 14,
                      color: isStaff ? const Color(0xFF6D28D9) : AppTheme.primaryAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name & Roll
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        student['name'] ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isStaff ? const Color(0xFFF5F3FF) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isStaff ? const Color(0xFFDDD6FE) : const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        student['roll_number'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: isStaff ? const Color(0xFF6D28D9) : AppTheme.primaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Category & Class badges
                Wrap(
                  spacing: 5,
                  runSpacing: 3,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isStaff ? const Color(0xFFFAF5FF) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: isStaff ? const Color(0xFFE9D5FF) : const Color(0xFFBBF7D0)),
                      ),
                      child: Text(
                        isStaff ? '👔 Staff' : '🎓 Student',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isStaff ? const Color(0xFF7E22CE) : const Color(0xFF15803D)),
                      ),
                    ),

                    // Class Name (e.g. III B.Sc.Maths)
                    if (className.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          className,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                      ),

                    // Institution badge
                    Builder(
                      builder: (context) {
                        String displayBadge = inst;
                        for (final m in _institutionMaster) {
                          if (m['name']!.toLowerCase() == inst.toLowerCase() ||
                              m['code']!.toLowerCase() == inst.toLowerCase()) {
                            displayBadge = m['code']!;
                            break;
                          }
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: instColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            displayBadge,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: instColor),
                          ),
                        );
                      },
                    ),

                    // Designation if staff
                    if (isStaff && designation.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          designation,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                        ),
                      ),

                    // Year of study if student
                    if (!isStaff && year.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          year,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 5),

                // Department
                if ((student['department'] as String? ?? '').isNotEmpty && student['department'] != 'General') ...[
                  Row(
                    children: [
                      const Icon(Icons.school_outlined, size: 13, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          student['department'],
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],

                // Assigned Route & Bus Info Row
                Row(
                  children: [
                    const Icon(Icons.alt_route_rounded, size: 13, color: AppTheme.primaryAccent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Route: ${student['route_name'] ?? routeName ?? 'Assigned'} • Bus: ${student['bus_number'] ?? busNumber}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryAccent,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Stage Stop
                Row(
                  children: [
                    const Icon(Icons.pin_drop_rounded, size: 13, color: AppTheme.secondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        stageName,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.secondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Phone contact with quick copy action
                if (student['phone'] != null || student['parent_phone'] != null) ...[
                  const SizedBox(height: 3),
                  InkWell(
                    onTap: () {
                      final num = student['phone'] ?? student['parent_phone'];
                      Clipboard.setData(ClipboardData(text: num));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Phone number $num copied to clipboard'), duration: const Duration(seconds: 2)),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_android_rounded, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${student['phone'] ?? student['parent_phone']}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded, size: 11, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
            padding: EdgeInsets.zero,
            onSelected: (action) {
              if (action == 'qr') onShowQr();
              if (action == 'edit') onEdit();
              if (action == 'delete') onDelete();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'qr',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 18, color: AppTheme.primaryAccent),
                    SizedBox(width: 8),
                    Text('View QR Pass'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text('Edit Details'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                    SizedBox(width: 8),
                    Text('Remove from Bus', style: TextStyle(color: AppTheme.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
