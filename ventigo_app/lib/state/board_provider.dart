import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import '../models/speaker_request.dart';

import '../state/auth_provider.dart';

// ── State ──

class BoardState {
  final List<SpeakerRequest> requests;
  final String? myRequestId;
  final String? error;

  const BoardState({this.requests = const [], this.myRequestId, this.error});

  BoardState copyWith({List<SpeakerRequest>? requests, String? myRequestId, String? error, bool clearMyRequest = false}) {
    return BoardState(
      requests: requests ?? this.requests,
      myRequestId: clearMyRequest ? null : (myRequestId ?? this.myRequestId),
      error: error,
    );
  }
}

// ── Notifier ──

class BoardNotifier extends StateNotifier<BoardState> {
  final Ref ref;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _disposed = false;

  BoardNotifier(this.ref) : super(const BoardState());

  String? get _token => ref.read(authProvider).token;
  String? get _sessionId => ref.read(authProvider).sessionId;

  void connect() {
    final token = _token;
    if (token == null || _disposed) return;
    _close();

    final uri = Uri.parse(Env.boardWsUrl(token));
    _channel = WebSocketChannel.connect(uri);

    _sub = _channel!.stream.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        _handleMessage(msg);
      },
      onDone: () {
        if (!_disposed) {
          _reconnectTimer = Timer(const Duration(seconds: 3), connect);
        }
      },
      onError: (_) {
        if (!_disposed) {
          _reconnectTimer = Timer(const Duration(seconds: 3), connect);
        }
      },
    );
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final event = msg['event'] as String?;

    if (event == 'error' && (msg['detail'] == 'token_invalid' || msg['detail'] == 'session_replaced')) {
      close();
      ref.read(authProvider.notifier).clear();
      return;
    }

    if (event == 'board_state') {
      final list = _parseRequests(msg['requests'] as List?);
      state = state.copyWith(
        requests: _filterOwn(list),
        myRequestId: msg['my_request_id'] as String?,
        clearMyRequest: msg['my_request_id'] == null,
      );
      return;
    }

    if (event == 'new_request') {
      if (msg['session_id'] == _sessionId) return;
      final id = msg['request_id'] as String;
      if (state.requests.any((r) => r.requestId == id)) return;
      state = state.copyWith(
        requests: [
          ...state.requests,
          SpeakerRequest(
            requestId: id,
            sessionId: msg['session_id'] as String? ?? '',
            username: msg['username'] as String? ?? '',
            avatarId: (msg['avatar_id'] ?? 0).toString(),
            postedAt: msg['posted_at'] as String? ?? '',
          ),
        ],
      );
      return;
    }

    if (event == 'removed_request') {
      state = state.copyWith(
        requests: state.requests.where((r) => r.requestId != msg['request_id']).toList(),
      );
      return;
    }

    // event == 'matched' - handled by the screen
  }

  List<SpeakerRequest> _parseRequests(List? raw) {
    if (raw == null) return [];
    return raw.map((e) => SpeakerRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  List<SpeakerRequest> _filterOwn(List<SpeakerRequest> list) {
    final sid = _sessionId;
    if (sid == null) return list;
    return list.where((r) => r.sessionId != sid).toList();
  }

  Future<void> syncBoard() async {
    final token = _token;
    if (token == null) return;
    try {
      final res = await ref.read(apiClientProvider).getBoard(token);
      state = state.copyWith(
        requests: _filterOwn(res.requests),
        myRequestId: res.myRequestId,
        clearMyRequest: res.myRequestId == null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void close() {
    _close();
  }

  void _close() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _sub = null;
  }

  /// Expose raw message stream for screens that need "matched" events
  Stream<Map<String, dynamic>>? get rawStream {
    return _channel?.stream.map((raw) => jsonDecode(raw as String) as Map<String, dynamic>);
  }

  @override
  void dispose() {
    _disposed = true;
    _close();
    super.dispose();
  }
}

// ── Provider ──

final boardProvider = StateNotifierProvider<BoardNotifier, BoardState>((ref) {
  return BoardNotifier(ref);
});
