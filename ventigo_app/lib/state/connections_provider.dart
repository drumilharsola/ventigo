import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

/// State for the connections system.
class ConnectionsState {
  final List<Map<String, dynamic>> connections;
  final List<Map<String, dynamic>> pendingRequests;
  final bool loading;
  final String? error;

  const ConnectionsState({
    this.connections = const [],
    this.pendingRequests = const [],
    this.loading = false,
    this.error,
  });

  ConnectionsState copyWith({
    List<Map<String, dynamic>>? connections,
    List<Map<String, dynamic>>? pendingRequests,
    bool? loading,
    String? error,
  }) {
    return ConnectionsState(
      connections: connections ?? this.connections,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class ConnectionsNotifier extends StateNotifier<ConnectionsState> {
  final Ref _ref;
  ConnectionsNotifier(this._ref) : super(const ConnectionsState());

  String? get _token => _ref.read(authProvider).token;
  ApiClient get _api => _ref.read(apiClientProvider);

  /// Fetch connections and pending requests from the API.
  Future<void> load() async {
    final token = _token;
    if (token == null) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final data = await _api.getConnections(token);
      state = state.copyWith(
        connections: (data['connections'] as List?)?.cast<Map<String, dynamic>>() ?? [],
        pendingRequests: (data['pending_requests'] as List?)?.cast<Map<String, dynamic>>() ?? [],
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Send a connection request to a peer.
  Future<void> send(String peerSessionId) async {
    final token = _token;
    if (token == null) return;
    try {
      await _api.sendConnectionRequest(token, peerSessionId);
      await load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Accept a pending connection request.
  Future<void> accept(String peerSessionId) async {
    final token = _token;
    if (token == null) return;
    try {
      await _api.acceptConnectionRequest(token, peerSessionId);
      await load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Remove an existing connection.
  Future<void> remove(String peerSessionId) async {
    final token = _token;
    if (token == null) return;
    state = state.copyWith(
      connections: state.connections.where((c) => c['peer_session_id'] != peerSessionId).toList(),
    );
    try {
      await _api.removeConnection(token, peerSessionId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      await load();
    }
  }

  /// Start a direct chat with a connected peer. Returns the room ID.
  Future<String?> startChat(String peerSessionId) async {
    final token = _token;
    if (token == null) return null;
    try {
      return await _api.directChat(token, peerSessionId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

final connectionsProvider =
    StateNotifierProvider<ConnectionsNotifier, ConnectionsState>((ref) {
  return ConnectionsNotifier(ref);
});
