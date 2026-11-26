import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../providers/auth_provider.dart';
import 'widgets/traveling_bus_animation.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_loading || ref.read(globalLoadingProvider).isLoading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await ref.read(globalLoadingProvider.notifier).runAction(
        action: () => ref.read(authStateProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        ),
        message: 'Signing in to VET Portal...',
        context: context,
        showErrorToast: false,
      );

      if (user == null || !mounted) return;

      if (user.isAdmin || user.role == 'admin' || user.role == 'system_admin' || user.role == 'transport_manager') {
        AppSnackBar.showSuccess(context, 'Welcome back, Administrator!');
        context.go('/admin');
      } else if (user.isSupervisor) {
        AppSnackBar.showSuccess(context, 'Welcome back, Bus Supervisor!');
        context.go('/supervisor');
      } else if (user.isDriver) {
        AppSnackBar.showSuccess(context, 'Welcome back, Driver!');
        context.go('/driver');
      } else if (user.isIncharge) {
        AppSnackBar.showSuccess(context, 'Welcome back, Incharge!');
        context.go('/incharge');
      } else if (user.isStudent) {
        AppSnackBar.showSuccess(context, 'Welcome back, Student!');
        context.go('/student');
      } else {
        final err = 'Unrecognized user role: ${user.role}';
        setState(() {
          _error = err;
        });
        AppSnackBar.showError(context, err);
      }
    } catch (e) {
      if (!mounted) return;
      String errMsg = 'Login failed. Please try again.';

      if (e is DioException) {
        if (e.response?.data is Map) {
          final data = e.response!.data as Map;
          if (data['error'] != null && data['error'].toString().isNotEmpty) {
            errMsg = data['error'].toString();
          } else if (data['message'] != null && data['message'].toString().isNotEmpty) {
            errMsg = data['message'].toString();
          }
          if (data['details'] != null && data['details'].toString().isNotEmpty) {
            errMsg += ' - ${data['details']}';
          }
        } else if (e.response?.statusCode == 401) {
          errMsg = 'Invalid email or password. Please check your credentials.';
        } else if (e.response?.statusCode == 403) {
          errMsg = 'Access Denied: Your account is deactivated or inactive.';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          errMsg = 'Network Error: Cannot connect to server. Please check internet connection.';
        } else {
          errMsg = e.message ?? 'Server Error (${e.response?.statusCode ?? 'Unknown'})';
        }
      } else {
        errMsg = e.toString().contains('401') || e.toString().contains('credentials')
            ? 'Invalid email or password. Please check your credentials.'
            : 'Login failed: ${e.toString().replaceAll('Exception:', '').trim()}';
      }

      setState(() {
        _error = errMsg;
      });
      AppSnackBar.showError(context, errMsg);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = context.isSmallPhone;
    final isLandscape = context.isLandscape;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 16 : 24,
              vertical: isLandscape ? 12 : 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header VET Brand Logo
                      const VetBrandLogo(size: 52, showText: true),

                      const SizedBox(height: 14),

                      // Animated Traveling Bus Highway Track
                      const TravelingBusBanner(height: 110),

                      const SizedBox(height: 16),

                      // Sign In Card (Crisp White + Blue Accent)
                      Container(
                        padding: EdgeInsets.all(isSmall ? 18 : 26),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E40AF).withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryAccent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Transport Portal Login',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Sign in to access Bus Incharge Scanner or Central Admin Portal',
                                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              ),

                              const SizedBox(height: 20),

                              // Error Banner
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: AppTheme.danger,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Email / Roll Number Input
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.text,
                                autocorrect: false,
                                textCapitalization: TextCapitalization.none,
                                decoration: const InputDecoration(
                                  labelText: 'Roll Number or Email',
                                  hintText: 'e.g. 21CS001 or incharge1@tripmate.edu',
                                  helperText: 'Students: Use your Roll Number (e.g. CS2021002)',
                                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.primaryAccent, size: 22),
                                  filled: true,
                                  fillColor: Color(0xFFF8FAFC),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Enter your Roll Number or email' : null,
                              ),

                              const SizedBox(height: 16),

                              // Password Input
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter your password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryAccent, size: 22),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: AppTheme.textMuted,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
                              ),

                              const SizedBox(height: 24),

                              // Login button
                              ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 50),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryAccent,
                                      foregroundColor: Colors.white,
                                      elevation: 3,
                                      shadowColor: AppTheme.primaryAccent.withOpacity(0.4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Sign In to VET Portal',
                                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward_rounded, size: 18),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Footer Note
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_outlined, size: 14, color: AppTheme.textMuted.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          Text(
                            'Velalar Educational Trust • Transport Portal',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
