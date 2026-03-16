import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import '../models/speaker_request.dart';

/// Parsed board WebSocket events.
sealed class BoardWsEvent {}

class BoardStateEvent extends BoardWsEvent {
  final List<SpeakerRequest> requests;
  BoardStateEvent(this.requests);
}

class NewRequestEvent extends BoardWsEvent {
  final SpeakerRequest request;
  NewRequestEvent(this.request);
}

class RemovedRequestEvent extends BoardWsEvent {
  final String requestId;
  RemovedRequestEvent(this.requestId);
}

class MatchedEvent extends BoardWsEvent {
  final String roomId;
  MatchedEvent(this.roomId);
}

class AuthErrorEvent extends BoardWsEvent {}

/// Manages a board WebSocket connection with auto-reconnect.
class BoardWsService {
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  final _controller = StreamController<BoardWsEvent>.broadcast();
  String Function()? _tokenGetter;

  /// Stream of parsed board events.
  Stream<BoardWsEvent> get events => _controller.stream;

  /// Connect using a token getter (re-evaluated on each reconnect).
  void connect(String Function() tokenGetter) {
    _tokenGetter = tokenGetter;
    _doConnect();
  }

  void _doConnect() {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return;
    _wsSub?.cancel();
    _ws?.sink.close();

    final uri = Uri.parse(Env.boardWsUrl(token));
    _ws = WebSocketChannel.connect(uri);

    _wsSub = _ws!.stream.listen(
      (raw) => _handle(jsonDecode(raw as String) as Map<String, dynamic>),
      onDone: () {
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 3), _doConnect);
      },
    );
  }

  void _handle(Map<String, dynamic> msg) {
    final event = msg['event'] as String?;

    if (event == 'error' &&
        (msg['detail'] == 'token_invalid' || msg['detail'] == 'session_replaced')) {
      _ws?.sink.close();
      _controller.add(AuthErrorEvent());
      return;
    }
    if (event == 'board_state') {
      final list = (msg['requests'] as List?)
              ?.map((e) => SpeakerRequest.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      _controller.add(BoardStateEvent(list));
      return;
    }
    if (event == 'new_request') {
      _controller.add(NewRequestEvent(SpeakerRequest(
        requestId: msg['request_id'] as String,
        sessionId: msg['session_id'] as String? ?? '',
        username: msg['username'] as String? ?? '',
        avatarId: (msg['avatar_id'] ?? 0).toString(),
        postedAt: msg['posted_at'] as String? ?? '',
        topic: msg['topic'] as String? ?? '',
      )));
      return;
    }
    if (event == 'removed_request') {
      _controller.add(RemovedRequestEvent(msg['request_id'] as String));
      return;
    }
    if (event == 'matched') {
      _ws?.sink.close();
      _controller.add(MatchedEvent(msg['room_id'] as String));
    }
  }

  /// Close the connection without disposing the event stream.
  void close() {
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
  }

  /// Close the connection and dispose the event stream.
  void dispose() {
    close();
    _controller.close();
  }
}
