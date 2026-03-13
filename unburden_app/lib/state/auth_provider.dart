import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_storage.dart';
import '../services/api_client.dart';

/// Auth state - token, session, profile, and hydration flag.
class AuthState {
  final String? token;
  final String? sessionId;
  final String? username;
  final int? avatarId;
  final bool? emailVerified;
  final bool hasHydrated;

  const AuthState({
    this.token,
    this.sessionId,
    this.username,
    this.avatarId,
    this.emailVerified,
    this.hasHydrated = false,
  });

  bool get isLoggedIn => token != null;
  bool get hasProfile => username != null;

  AuthState copyWith({
    String? token,
    String? sessionId,
    String? username,
    int? avatarId,
    bool? emailVerified,
    bool? hasHydrated,
  }) {
    return AuthState(
      token: token ?? this.token,
      sessionId: sessionId ?? this.sessionId,
      username: username ?? this.username,
      avatarId: avatarId ?? this.avatarId,
      emailVerified: emailVerified ?? this.emailVerified,
      hasHydrated: hasHydrated ?? this.hasHydrated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthStorage _storage;

  AuthNotifier(this._storage) : super(const AuthState());

  /// Read persisted values on app start (replaces Zustand onRehydrateStorage).
  Future<void> hydrate() async {
    final token = await _storage.readToken();
    final sessionId = await _storage.readSessionId();
    final username = await _storage.readUsername();
    final avatarId = await _storage.readAvatarId();
    final emailVerified = await _storage.readEmailVerified();

    state = AuthState(
      token: token,
      sessionId: sessionId,
      username: username,
      avatarId: avatarId,
      emailVerified: emailVerified,
      hasHydrated: true,
    );
  }

  Future<void> setAuth(String token, String sessionId) async {
    state = state.copyWith(token: token, sessionId: sessionId);
    await _storage.saveAuth(token, sessionId);
  }

  Future<void> setProfile(String username, int avatarId) async {
    state = state.copyWith(username: username, avatarId: avatarId);
    await _storage.saveProfile(username, avatarId);
  }

  Future<void> setAvatarId(int id) async {
    state = state.copyWith(avatarId: id);
    await _storage.saveAvatarId(id);
  }

  Future<void> setEmailVerified(bool verified) async {
    state = state.copyWith(emailVerified: verified);
    await _storage.saveEmailVerified(verified);
  }

  Future<void> clear() async {
    state = const AuthState(hasHydrated: true);
    await _storage.clear();
  }
}

// ────────────────────────── Providers ──────────────────────────

final authStorageProvider = Provider<AuthStorage>((_) => AuthStorage());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authStorageProvider));
});

final apiClientProvider = Provider<ApiClient>((_) => ApiClient());
