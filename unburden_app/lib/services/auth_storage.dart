import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists auth tokens and profile data using flutter_secure_storage.
class AuthStorage {
  final _storage = const FlutterSecureStorage();

  static const _keyToken = 'auth_token';
  static const _keySessionId = 'session_id';
  static const _keyUsername = 'username';
  static const _keyAvatarId = 'avatar_id';
  static const _keyEmailVerified = 'email_verified';

  Future<String?> readToken() => _storage.read(key: _keyToken);
  Future<String?> readSessionId() => _storage.read(key: _keySessionId);
  Future<String?> readUsername() => _storage.read(key: _keyUsername);

  Future<int?> readAvatarId() async {
    final raw = await _storage.read(key: _keyAvatarId);
    return raw != null ? int.tryParse(raw) : null;
  }

  Future<bool?> readEmailVerified() async {
    final raw = await _storage.read(key: _keyEmailVerified);
    return raw != null ? raw == 'true' : null;
  }

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

  Future<void> clear() => _storage.deleteAll();
}
