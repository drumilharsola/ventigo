import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import 'auth_provider.dart';

class PendingWaitState {
  final String? requestId;
  final int remaining;
  final bool timedOut;
  final String? matchedRoomId;

  const PendingWaitState({this.requestId, this.remaining = 600, this.timedOut = false, this.matchedRoomId});

  PendingWaitState copyWith({String? requestId, int? remaining, bool? timedOut, String? matchedRoomId, bool clearRequest = false, bool clearMatch = false}) {
    return PendingWaitState(
      requestId: clearRequest ? null : (requestId ?? this.requestId),
      remaining: remaining ?? this.remaining,
      timedOut: timedOut ?? this.timedOut,
      matchedRoomId: clearMatch ? null : (matchedRoomId ?? this.matchedRoomId),
    );
  }

  bool get isWaiting => requestId != null && !timedOut && matchedRoomId == null;
}

class PendingWaitNotifier extends StateNotifier<PendingWaitState> {
  final Ref ref;
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  bool _disposed = false;

  PendingWaitNotifier(this.ref) : super(const PendingWaitState());

  String? get _token => ref.read(authProvider).token;

  void startWaiting(String requestId, {int remaining = 600}) {
    state = PendingWaitState(requestId: requestId, remaining: remaining);
    _connectWs();
    _startPoll();
  }

  void cancel() {
    final token = _token;
    if (token != null && state.requestId != null) {
      ref.read(apiClientProvider).cancelSpeak(token).catchError((_) {});
    }
    _close();
    state = const PendingWaitState();
  }

  void clearMatch() {
    state = const PendingWaitState();
  }

  void _connectWs() {
    final token = _token;
    if (token == null || _disposed) return;
    _wsSub?.cancel();
    _ws?.sink.close();

    final uri = Uri.parse(Env.boardWsUrl(token));
    _ws = WebSocketChannel.connect(uri);

    _wsSub = _ws!.stream.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        final event = msg['event'] as String?;

        if (event == 'matched') {
          _ws?.sink.close();
          state = state.copyWith(matchedRoomId: msg['room_id'] as String);
        }
        if (event == 'board_state' && msg['my_request_id'] == null && state.requestId != null) {
          state = state.copyWith(timedOut: true);
        }
      },
      onDone: () {
        _reconnectTimer?.cancel();
        if (!_disposed && state.isWaiting) {
          _reconnectTimer = Timer(const Duration(seconds: 3), _connectWs);
        }
      },
    );
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_disposed || !state.isWaiting) return;
      final token = _token;
      final rid = state.requestId;
      if (token == null || rid == null) return;
      try {
        final req = await ref.read(apiClientProvider).getSpeakerRequest(token, rid);
        if (req.status == 'matched' && req.roomId != null) {
          _ws?.sink.close();
          state = state.copyWith(matchedRoomId: req.roomId);
          return;
        }
        if (req.postedAt == null) {
          state = state.copyWith(timedOut: true);
          return;
        }
        final elapsed = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - (int.tryParse(req.postedAt!) ?? 0);
        final rem = (600 - elapsed).clamp(0, 600);
        if (rem <= 0) {
          state = state.copyWith(timedOut: true);
        } else {
          state = state.copyWith(remaining: rem);
        }
      } catch (_) {}
    });
  }

  void _close() {
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
  }

  @override
  void dispose() {
    _disposed = true;
    _close();
    super.dispose();
  }
}

final pendingWaitProvider = StateNotifierProvider<PendingWaitNotifier, PendingWaitState>((ref) {
  return PendingWaitNotifier(ref);
});
