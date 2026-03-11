import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

class AdminState {
  final AdminStats? stats;
  final List<AdminReport> reports;
  final AdminUser? selectedUser;
  final bool loading;
  final String? error;

  const AdminState({
    this.stats,
    this.reports = const [],
    this.selectedUser,
    this.loading = false,
    this.error,
  });

  AdminState copyWith({
    AdminStats? stats,
    List<AdminReport>? reports,
    AdminUser? selectedUser,
    bool? loading,
    String? error,
    bool clearUser = false,
  }) {
    return AdminState(
      stats: stats ?? this.stats,
      reports: reports ?? this.reports,
      selectedUser: clearUser ? null : (selectedUser ?? this.selectedUser),
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AdminNotifier extends StateNotifier<AdminState> {
  final Ref ref;

  AdminNotifier(this.ref) : super(const AdminState());

  ApiClient get _api => ref.read(apiClientProvider);
  String? get _token => ref.read(authProvider).token;

  Future<bool> checkAdmin() async {
    final token = _token;
    if (token == null) return false;
    try {
      await _api.adminStats(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadStats() async {
    final token = _token;
    if (token == null) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final stats = await _api.adminStats(token);
      state = state.copyWith(stats: stats, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadReports({int offset = 0}) async {
    final token = _token;
    if (token == null) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final reports = await _api.adminListReports(token, offset: offset);
      state = state.copyWith(reports: reports, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadUser(String sessionId) async {
    final token = _token;
    if (token == null) return;
    state = state.copyWith(loading: true, error: null, clearUser: true);
    try {
      final user = await _api.adminGetUser(token, sessionId);
      state = state.copyWith(selectedUser: user, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> toggleSuspend(String sessionId, bool currentlySuspended) async {
    final token = _token;
    if (token == null) return;
    try {
      if (currentlySuspended) {
        await _api.adminUnsuspendUser(token, sessionId);
      } else {
        await _api.adminSuspendUser(token, sessionId);
      }
      await loadUser(sessionId);
    } catch (_) {}
  }

  Future<void> toggleAdmin(String sessionId, bool currentlyAdmin) async {
    final token = _token;
    if (token == null) return;
    try {
      if (currentlyAdmin) {
        await _api.adminRevokeModerator(token, sessionId);
      } else {
        await _api.adminGrantModerator(token, sessionId);
      }
      await loadUser(sessionId);
    } catch (_) {}
  }
}

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier(ref);
});
