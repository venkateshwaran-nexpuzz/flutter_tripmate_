import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'token_storage.g.dart';

const _kAccessToken = 'tm_access_token';
const _kRefreshToken = 'tm_refresh_token';
const _kUserId = 'tm_user_id';
const _kUserRole = 'tm_user_role';
const _kProfileId = 'tm_profile_id';
const _kDeviceId = 'tm_device_id';

@riverpod
TokenStorage tokenStorage(TokenStorageRef ref) => TokenStorage();

class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
    ]);
  }

  Future<void> saveUserInfo({
    required String userId,
    required String role,
    String? profileId,
  }) async {
    await Future.wait([
      _storage.write(key: _kUserId, value: userId),
      _storage.write(key: _kUserRole, value: role),
      if (profileId != null) _storage.write(key: _kProfileId, value: profileId),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);
  Future<String?> getUserId() => _storage.read(key: _kUserId);
  Future<String?> getUserRole() => _storage.read(key: _kUserRole);
  Future<String?> getProfileId() => _storage.read(key: _kProfileId);

  Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUserRole),
      _storage.delete(key: _kProfileId),
    ]);
  }

  /// Get or create a persistent device ID
  Future<String> getDeviceId() async {
    var id = await _storage.read(key: _kDeviceId);
    if (id == null || id.isEmpty) {
      id = 'TM-${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: _kDeviceId, value: id);
    }
    return id;
  }
}
