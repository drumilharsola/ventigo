import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around flutter_secure_storage.
/// Persists auth tokens + profile data (replaces Zustand persist middleware).
class AuthStorage {
  static const _storage = FlutterSecureStorage();

  static const _keyToken = 'auth_token';
  static const _keySessionId = 'auth_session_id';
  static const _keyUsername = 'auth_username';
  static const _keyAvatarId = 'auth_avatar_id';
  static const _keyEmailVerified = 'auth_email_verified';

  // ── Write ──

  Future<void> saveAuth(String token, String sessionId) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keySessionId, value: sessionId);
  }

  Future<void> saveProfile(String username, int avatarId) async {
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyAvatarId, value: avatarId.toString());
  }

  Future<void> saveAvatarId(int id) async {
    await _storage.write(key: _keyAvatarId, value: id.toString());
  }

  Future<void> saveEmailVerified(bool verified) async {
    await _storage.write(key: _keyEmailVerified, value: verified.toString());
  }

  // ── Read ──

  Future<String?> readToken() => _storage.read(key: _keyToken);
  Future<String?> readSessionId() => _storage.read(key: _keySessionId);
  Future<String?> readUsername() => _storage.read(key: _keyUsername);

  Future<int?> readAvatarId() async {
    final s = await _storage.read(key: _keyAvatarId);
    return s != null ? int.tryParse(s) : null;
  }

  Future<bool?> readEmailVerified() async {
    final s = await _storage.read(key: _keyEmailVerified);
    return s != null ? s == 'true' : null;
  }

  // ── Clear ──

  Future<void> clear() => _storage.deleteAll();
}
