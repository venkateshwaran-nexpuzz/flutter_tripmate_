import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../theme/app_theme.dart';

/// Global Loading State
class GlobalLoadingState {
  final bool isLoading;
  final String message;
  final String? activeActionKey;
  final DateTime? startedAt;

  const GlobalLoadingState({
    this.isLoading = false,
    this.message = 'Processing...',
    this.activeActionKey,
    this.startedAt,
  });

  GlobalLoadingState copyWith({
    bool? isLoading,
    String? message,
    String? activeActionKey,
    DateTime? startedAt,
  }) {
    return GlobalLoadingState(
      isLoading: isLoading ?? this.isLoading,
      message: message ?? this.message,
      activeActionKey: activeActionKey ?? this.activeActionKey,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

/// Global Process Controller Notifier
class GlobalLoadingNotifier extends StateNotifier<GlobalLoadingState> {
  GlobalLoadingNotifier() : super(const GlobalLoadingState());

  void show({String message = 'Processing...', String? actionKey}) {
    state = GlobalLoadingState(
      isLoading: true,
      message: message,
      activeActionKey: actionKey,
      startedAt: DateTime.now(),
    );
  }

  void hide() {
    if (state.isLoading) {
      state = const GlobalLoadingState(isLoading: false);
    }
  }

  /// Safe asynchronous action executor with:
  /// - Double-tap / duplicate click debounce guard
  /// - Automatic global loader display & pointer absorption
  /// - Guaranteed dismissal in all cases (success, error, or exception)
  /// - User-friendly error message extraction
  Future<T?> runAction<T>({
    required Future<T> Function() action,
    String message = 'Processing...',
    String? actionKey,
    BuildContext? context,
    String? successMessage,
    String? errorMessage,
    bool showErrorToast = true,
  }) async {
    // 1. Debounce / Duplicate tap guard
    if (state.isLoading) {
      debugPrint('[GlobalLoader] Action ignored: another operation is in progress.');
      return null;
    }

    show(message: message, actionKey: actionKey);

    try {
      final result = await action();
      if (successMessage != null && successMessage.isNotEmpty) {
        AppSnackBar.showSuccess(context != null && context.mounted ? context : null, successMessage);
      }
      return result;
    } catch (e) {
      debugPrint('[GlobalLoader] Action error: $e');
      if (showErrorToast) {
        final displayErr = errorMessage ?? _extractErrorMessage(e);
        AppSnackBar.showError(context != null && context.mounted ? context : null, displayErr);
      }
      rethrow;
    } finally {
      hide();
    }
  }

  static String _extractErrorMessage(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        if (data['error'] != null && data['error'].toString().isNotEmpty) {
          return data['error'].toString();
        }
        if (data['message'] != null && data['message'].toString().isNotEmpty) {
          return data['message'].toString();
        }
      }
      if (e.response?.statusCode == 401) {
        return 'Invalid credentials or session expired. Please log in again.';
      } else if (e.response?.statusCode == 403) {
        return 'Access denied: You do not have permission for this action.';
      } else if (e.response?.statusCode == 404) {
        return 'Requested record or endpoint not found on server.';
      } else if (e.response?.statusCode == 409) {
        return 'Conflict: Record already exists or is already processed.';
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout ||
                 e.type == DioExceptionType.connectionError) {
        return 'Network connection error. Please check your internet connection.';
      }
      return e.message ?? 'Network request failed (${e.response?.statusCode ?? 'Error'})';
    }
    return e.toString().replaceAll('Exception:', '').trim();
  }
}

/// Global Riverpod Provider for the entire mobile app
final globalLoadingProvider = StateNotifierProvider<GlobalLoadingNotifier, GlobalLoadingState>((ref) {
  return GlobalLoadingNotifier();
});

/// Extension on WidgetRef to allow seamless one-line actions:
/// `await ref.globalAction(() => api.doSomething(), message: 'Saving...');`
extension GlobalActionRefExtension on WidgetRef {
  Future<T?> globalAction<T>(
    Future<T> Function() action, {
    String message = 'Processing...',
    String? actionKey,
    BuildContext? context,
    String? successMessage,
    String? errorMessage,
    bool showErrorToast = true,
  }) {
    return read(globalLoadingProvider.notifier).runAction<T>(
      action: action,
      message: message,
      actionKey: actionKey,
      context: context,
      successMessage: successMessage,
      errorMessage: errorMessage,
      showErrorToast: showErrorToast,
    );
  }
}

/// Extension on ConsumerState for direct screen usage:
/// `await globalAction(() => api.save(), message: 'Saving...');`
extension GlobalActionStateExtension on ConsumerState {
  Future<T?> globalAction<T>(
    Future<T> Function() action, {
    String message = 'Processing...',
    String? actionKey,
    String? successMessage,
    String? errorMessage,
    bool showErrorToast = true,
  }) {
    return ref.read(globalLoadingProvider.notifier).runAction<T>(
      action: action,
      message: message,
      actionKey: actionKey,
      context: mounted ? context : null,
      successMessage: successMessage,
      errorMessage: errorMessage,
      showErrorToast: showErrorToast,
    );
  }
}

/// Root Global Loading Overlay Widget
/// Injected into `MaterialApp.router(builder: ...)`
class GlobalLoadingOverlay extends ConsumerWidget {
  final Widget child;

  const GlobalLoadingOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingState = ref.watch(globalLoadingProvider);

    return PopScope(
      canPop: !loadingState.isLoading,
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          // The base app contents
          child,

          // Global loading backdrop & indicator
          if (loadingState.isLoading)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    color: Colors.black.withOpacity(0.38),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.85, end: 1.0),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) => Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 36),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                            constraints: const BoxConstraints(maxWidth: 320),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1E40AF).withOpacity(0.18),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Branded Spinner Container
                                Container(
                                  width: 52,
                                  height: 52,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFDBEAFE)),
                                  ),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 3.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E40AF)),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Action Message
                                Text(
                                  loadingState.message,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Subtext reassurance
                                const Text(
                                  'Please wait a moment...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Legacy backward compatibility helper
class AppLoader {
  static void show(BuildContext context, {String message = 'Processing...'}) {}
  static void hide(BuildContext context) {}
}

class AppLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String message;

  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message = 'Please wait...',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withOpacity(0.25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            message,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

