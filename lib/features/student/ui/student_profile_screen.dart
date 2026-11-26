import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_language_button.dart';
import '../../../core/api/api_client.dart';
import 'package:dio/dio.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/student_provider.dart';

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(studentProfileProvider);

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
          'Student Profile & Pass',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          const Center(
            child: AppLanguageButton(compact: true),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryAccent),
            tooltip: 'Refresh Profile',
            onPressed: () {
              ref.invalidate(studentProfileProvider);
              AppSnackBar.showInfo(context, 'Refreshing student profile...');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryAccent,
        onRefresh: () async => ref.invalidate(studentProfileProvider),
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
                  const SizedBox(height: 12),
                  Text('Failed to load profile: $e', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.danger)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(studentProfileProvider),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
          data: (profile) => _buildProfileContent(context, ref, profile),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, Map<String, dynamic> profile) {
    final name = profile['name'] ?? 'Student';
    final rollNumber = profile['roll_number'] ?? '—';
    final dept = profile['department'] ?? 'General';
    final institution = profile['institution_type'] ?? 'Engineering';
    final year = profile['year_of_study'] ?? '1st Year';
    final email = profile['email'] ?? '—';
    final phone = profile['phone'] ?? 'Not added';
    final parentPhone = profile['parent_phone'] ?? 'Not added';
    final busNo = profile['bus_number'] ?? 'Not assigned';
    final routeName = profile['route_name'] ?? 'Not assigned';
    final stageName = profile['stage_name'] ?? 'Not assigned';
    final pickupTime = profile['expected_boarding_time'];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Digital Student ID & Bus Pass Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D4ED8).withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header with College Name & Live Pass Badge
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
                              child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VET GROUP OF INSTITUTIONS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Digital Bus Pass & Student ID',
                                  style: TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'ACTIVE',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Avatar, Name & Roll
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Roll No: $rollNumber',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$dept • $institution ($year)',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 14),

                    // Admin Issued Pass Official Badge (Students cannot self-generate QR)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.badge_outlined, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Official Transit Pass Issued by Admin',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Official barcode pass & attendance ID are generated and issued by the College Transport Office.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
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

              const SizedBox(height: 20),

              // 2. Transport & Bus Details Section
              const Text(
                'Transport Assignment',
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
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.directions_bus_rounded,
                      iconColor: const Color(0xFF1E40AF),
                      label: 'Assigned Bus',
                      value: busNo,
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _InfoRow(
                      icon: Icons.alt_route_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      label: 'Route Name',
                      value: routeName,
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _InfoRow(
                      icon: Icons.pin_drop_rounded,
                      iconColor: const Color(0xFFE11D48),
                      label: 'Boarding Stop Stage',
                      value: stageName,
                    ),
                    if (pickupTime != null) ...[
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _InfoRow(
                        icon: Icons.schedule_rounded,
                        iconColor: const Color(0xFF059669),
                        label: 'Estimated Pickup',
                        value: pickupTime.toString(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Academic & Contact Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Academic & Contact Details',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  TextButton.icon(
                    onPressed: () => _showEditProfileDialog(context, ref, profile),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1E40AF),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.account_balance_rounded,
                      iconColor: const Color(0xFF2563EB),
                      label: 'Institution',
                      value: institution,
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _InfoRow(
                      icon: Icons.school_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      label: 'Department & Year',
                      value: '$dept • $year',
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      iconColor: const Color(0xFF64748B),
                      label: 'Student Email',
                      value: email,
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _InfoRow(
                      icon: Icons.phone_android_rounded,
                      iconColor: const Color(0xFF059669),
                      label: 'Student Phone',
                      value: phone,
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _InfoRow(
                      icon: Icons.contact_phone_outlined,
                      iconColor: const Color(0xFFD97706),
                      label: 'Parent Contact Phone',
                      value: parentPhone,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Quick Actions (History, Scan, Logout)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/student/history'),
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text('Trip Logs'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: const Color(0xFF1E40AF),
                        side: const BorderSide(color: Color(0xFF1E40AF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/student/stats'),
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text('Stats'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: const Color(0xFF1E40AF),
                        side: const BorderSide(color: Color(0xFF1E40AF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. Profile Action Buttons: Edit Profile & Change Password
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showEditProfileDialog(context, ref, profile),
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showChangePasswordDialog(context, ref),
                      icon: const Icon(Icons.lock_reset_rounded, size: 20),
                      label: const Text('Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E40AF),
                        side: const BorderSide(color: Color(0xFF1E40AF), width: 1.5),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref.globalAction(() async {
                      await ref.read(authStateProvider.notifier).logout();
                    },
                    message: 'Logging out from Student Portal...',
                    context: context,
                    );
                    if (context.mounted) {
                      AppSnackBar.showSuccess(context, 'Logged out successfully');
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Logout from Account', style: TextStyle(fontWeight: FontWeight.w800)),
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
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChangePasswordSheet(ref: ref),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(ref: ref, profile: profile),
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

class _ChangePasswordSheet extends StatefulWidget {
  final WidgetRef ref;

  const _ChangePasswordSheet({required this.ref});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.ref.read(apiClientProvider).changePassword(
        currentPassword: _currentController.text.trim(),
        newPassword: _newController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        AppSnackBar.showSuccess(context, 'Password changed successfully! Please keep it secure.');
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to update password. Please check your current password.';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['error'] != null) {
            msg = data['error'].toString();
          } else if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        }
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF1E40AF), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Account Password',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Update your student portal login password',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Current Password
              TextFormField(
                controller: _currentController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter your current password';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // New Password
              TextFormField(
                controller: _newController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  helperText: 'Minimum 8 characters (letters, numbers, symbols recommended)',
                  prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                validator: (val) {
                  if (val == null || val.length < 8) return 'Password must be at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Confirm New Password
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                validator: (val) {
                  if (val != _newController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final WidgetRef ref;
  final Map<String, dynamic> profile;

  const _EditProfileSheet({required this.ref, required this.profile});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _rollNumberController;
  late final TextEditingController _deptController;
  late final TextEditingController _yearController;
  late final TextEditingController _institutionController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _parentPhoneController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p['name']?.toString() ?? '');
    _rollNumberController = TextEditingController(text: p['roll_number']?.toString() ?? '');
    _deptController = TextEditingController(text: p['department']?.toString() ?? '');
    _yearController = TextEditingController(text: p['year_of_study']?.toString() ?? '1st Year');
    _institutionController = TextEditingController(text: p['institution_type']?.toString() ?? 'Arts and Science');
    _emailController = TextEditingController(text: p['email']?.toString() ?? '');
    _phoneController = TextEditingController(text: p['phone']?.toString() ?? '');
    _parentPhoneController = TextEditingController(text: p['parent_phone']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollNumberController.dispose();
    _deptController.dispose();
    _yearController.dispose();
    _institutionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = {
        'name': _nameController.text.trim(),
        'roll_number': _rollNumberController.text.trim().toUpperCase(),
        'department': _deptController.text.trim(),
        'year_of_study': _yearController.text.trim(),
        'institution_type': _institutionController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'parent_phone': _parentPhoneController.text.trim(),
      };

      await widget.ref.read(apiClientProvider).updateStudentProfile(data);

      widget.ref.invalidate(studentProfileProvider);

      if (mounted) {
        Navigator.of(context).pop();
        AppSnackBar.showSuccess(context, 'Profile details updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to update profile details.';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['error'] != null) {
            msg = data['error'].toString();
          } else if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        }
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_note_rounded, color: Color(0xFF1E40AF), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Student Profile',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Update personal, academic & contact details',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Student name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Roll Number
                    TextFormField(
                      controller: _rollNumberController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Roll Number * (Login ID)',
                        helperText: 'e.g. 21CS001 (used to log in)',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Roll number is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Institution Type
                    TextFormField(
                      controller: _institutionController,
                      decoration: InputDecoration(
                        labelText: 'Institution Type *',
                        helperText: 'e.g. Arts and Science, Engineering, Polytechnic',
                        prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Institution type is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Department & Year Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _deptController,
                            decoration: InputDecoration(
                              labelText: 'Department *',
                              helperText: 'e.g. CSE, IT, B.Com',
                              prefixIcon: const Icon(Icons.school_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Department required';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _yearController,
                            decoration: InputDecoration(
                              labelText: 'Year *',
                              helperText: 'e.g. 1st Year',
                              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Year required';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Student Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address *',
                        helperText: 'Used for account recovery and notices',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Email is required';
                        if (!val.contains('@') || !val.contains('.')) return 'Invalid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Student Phone Number
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Student Mobile Phone',
                        helperText: 'Student contact number',
                        prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Parent Contact Phone
                    TextFormField(
                      controller: _parentPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Parent Contact Phone',
                        helperText: 'Emergency contact number',
                        prefixIcon: const Icon(Icons.contact_phone_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


