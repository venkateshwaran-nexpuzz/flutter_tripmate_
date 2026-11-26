import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/token_storage.dart';

part 'auth_provider.g.dart';

// ============================================================
// Auth State Model
// ============================================================
class AuthUser {
  final String id;
  final String email;
  final String role;
  final String? profileId;

  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.profileId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        profileId: json['profileId'] as String?,
      );

  bool get isIncharge => role == 'incharge';
  bool get isStudent => role == 'student';
  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';
  bool get isSupervisor => role == 'supervisor' || role == 'bus_supervisor';
}

// ============================================================
// Auth State Notifier
// ============================================================
@riverpod
class AuthState extends _$AuthState {
  @override
  FutureOr<AuthUser?> build() async {
    // Check if token exists on startup
    final storage = ref.read(tokenStorageProvider);
    final hasToken = await storage.hasToken();
    if (!hasToken) return null;

    // Validate token by calling /me
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.getMe();
      final data = response.data['data'] as Map<String, dynamic>;
      return AuthUser.fromJson(data);
    } catch (_) {
      await storage.clear();
      return null;
    }
  }

  Future<AuthUser> login(String email, String password) async {
    state = const AsyncLoading();

    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);

    try {
      final response = await api.login(email, password);
      final data = response.data['data'] as Map<String, dynamic>;

      await storage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );

      final userData = data['user'] as Map<String, dynamic>;
      await storage.saveUserInfo(
        userId: userData['id'] as String,
        role: userData['role'] as String,
        profileId: userData['profileId'] as String?,
      );

      final user = AuthUser.fromJson(userData);
      state = AsyncData(user);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);

    try {
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken != null) {
        await api.logout(refreshToken);
      }
    } catch (_) {}

    await storage.clear();
    state = const AsyncData(null);
  }
}

// ============================================================
// Convenience provider
// ============================================================
@riverpod
AuthUser? currentUser(CurrentUserRef ref) {
  return ref.watch(authStateProvider).valueOrNull;
}
