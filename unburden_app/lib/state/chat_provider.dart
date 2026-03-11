import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import '../models/chat_message.dart';
import '../models/room_messages.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';

// ── State ──

class ChatState {
  final List<TranscriptItem> transcript;
  final String? peerUsername;
  final int peerAvatarId;
  final String? peerSessionId;
  final int remaining;
  final bool timerStarted;
  final bool peerTyping;
  final bool sessionEnded;
  final bool peerLeft;
  final bool canExtend;
  final bool connected;
  final String? connectionError;
  final String mode; // checking | live | readonly | expired

  const ChatState({
    this.transcript = const [],
    this.peerUsername,
    this.peerAvatarId = 0,
    this.peerSessionId,
    this.remaining = 900,
    this.timerStarted = false,
    this.peerTyping = false,
    this.sessionEnded = false,
    this.peerLeft = false,
    this.canExtend = true,
    this.connected = false,
    this.connectionError,
    this.mode = 'checking',
  });

  ChatState copyWith({
    List<TranscriptItem>? transcript,
    String? peerUsername,
    int? peerAvatarId,
    String? peerSessionId,
    int? remaining,
    bool? timerStarted,
    bool? peerTyping,
    bool? sessionEnded,
    bool? peerLeft,
    bool? canExtend,
    bool? connected,
    String? connectionError,
    String? mode,
    bool clearConnectionError = false,
  }) {
    return ChatState(
      transcript: transcript ?? this.transcript,
      peerUsername: peerUsername ?? this.peerUsername,
      peerAvatarId: peerAvatarId ?? this.peerAvatarId,
      peerSessionId: peerSessionId ?? this.peerSessionId,
      remaining: remaining ?? this.remaining,
      timerStarted: timerStarted ?? this.timerStarted,
      peerTyping: peerTyping ?? this.peerTyping,
      sessionEnded: sessionEnded ?? this.sessionEnded,
      peerLeft: peerLeft ?? this.peerLeft,
      canExtend: canExtend ?? this.canExtend,
      connected: connected ?? this.connected,
      connectionError: clearConnectionError ? null : (connectionError ?? this.connectionError),
      mode: mode ?? this.mode,
    );
  }
}

// ── Notifier ──

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref ref;
  final String roomId;
  final String? initialPeerSessionId;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _syncTimer;
  Timer? _typingStopTimer;
  bool _isTyping = false;
  bool _disposed = false;

  ChatNotifier(this.ref, {required this.roomId, this.initialPeerSessionId}) : super(const ChatState());

  String? get _token => ref.read(authProvider).token;
  String? get _username => ref.read(authProvider).username;
  ApiClient get _api => ref.read(apiClientProvider);

  // ── Lifecycle ──

  Future<void> initialize() async {
    final token = _token;
    if (token == null || roomId.isEmpty) {
      state = state.copyWith(mode: 'expired');
      return;
    }

    try {
      final data = await _api.getRoomMessages(token, roomId);
      _applyRoomData(data);

      if (data.status == 'ended') {
        state = state.copyWith(mode: 'readonly');
      } else {
        state = state.copyWith(mode: 'live');
        _connectWs();
        _startSyncTimer();
      }
    } catch (_) {
      state = state.copyWith(mode: 'expired');
    }
  }

  void _applyRoomData(RoomMessages data) {
    final msgs = data.messages.map<TranscriptItem>((m) => TranscriptMessage(
      from: m.from,
      text: m.text,
      ts: m.ts,
      clientId: m.clientId,
    )).toList();

    state = state.copyWith(
      transcript: _merge(state.transcript, msgs),
      peerUsername: data.peerUsername.isNotEmpty ? data.peerUsername : state.peerUsername,
      peerAvatarId: data.peerAvatarId,
      peerSessionId: data.peerSessionId.isNotEmpty ? data.peerSessionId : state.peerSessionId,
      remaining: _computeRemaining(data),
      timerStarted: data.startedAt.isNotEmpty,
    );
  }

  int _computeRemaining(RoomMessages data) {
    final duration = int.tryParse(data.duration) ?? 900;
    if (data.startedAt.isNotEmpty) {
      final elapsed = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - (int.tryParse(data.startedAt) ?? 0);
      return (duration - elapsed).clamp(0, duration);
    }
    return duration;
  }

  // ── WebSocket ──

  void _connectWs() {
    final token = _token;
    if (token == null || _disposed || state.mode != 'live') return;

    final uri = Uri.parse(Env.chatWsUrl(token, roomId));
    _channel = WebSocketChannel.connect(uri);

    _sub = _channel!.stream.listen(
      (raw) => _handleWs(jsonDecode(raw as String) as Map<String, dynamic>),
      onDone: () {
        state = state.copyWith(connected: false);
        // Don't reconnect — chat WS is session-bound; going offline means ended
      },
      onError: (_) => state = state.copyWith(connected: false),
    );

    state = state.copyWith(connected: true, clearConnectionError: true);
  }

  void _handleWs(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final username = _username;

    switch (type) {
      case 'history':
        final msgs = (data['messages'] as List?)
            ?.map((m) => TranscriptMessage(
                  from: m['from'] as String,
                  text: m['text'] as String,
                  ts: (m['ts'] as num).toDouble(),
                  clientId: m['client_id'] as String?,
                ))
            .toList();
        if (msgs != null) {
          state = state.copyWith(transcript: _merge(state.transcript, msgs.cast<TranscriptItem>()));
          final peer = msgs.where((m) => m.from != username).firstOrNull;
          if (peer != null) state = state.copyWith(peerUsername: peer.from);
        }
        break;

      case 'message':
        final msg = TranscriptMessage(
          from: data['from'] as String,
          text: data['text'] as String,
          ts: (data['ts'] as num).toDouble(),
          clientId: data['client_id'] as String?,
        );
        state = state.copyWith(transcript: _merge(state.transcript, [msg]));
        if (msg.from != username) {
          state = state.copyWith(peerUsername: msg.from, peerTyping: false);
        }
        break;

      case 'typing_start':
        if (data['from'] != username) state = state.copyWith(peerTyping: true, peerUsername: data['from'] as String?);
        break;

      case 'typing_stop':
        if (data['from'] != username) state = state.copyWith(peerTyping: false);
        break;

      case 'timer_status':
        final started = data['started'] as bool? ?? false;
        if (started && !state.timerStarted) {
          _appendMarker('started');
        }
        state = state.copyWith(timerStarted: started, remaining: (data['remaining'] as num).toInt());
        break;

      case 'tick':
        if (!state.timerStarted) _appendMarker('started');
        state = state.copyWith(timerStarted: true, remaining: (data['remaining'] as num).toInt());
        break;

      case 'session_end':
        _appendMarker('ended');
        state = state.copyWith(sessionEnded: true);
        break;

      case 'peer_left':
        _appendMarker('ended');
        state = state.copyWith(peerLeft: true, canExtend: false, sessionEnded: true);
        break;

      case 'extended':
        state = state.copyWith(remaining: (data['remaining'] as num).toInt(), canExtend: false, sessionEnded: false);
        break;

      case 'error':
        state = state.copyWith(connectionError: data['detail'] as String?);
        break;
    }
  }

  // ── Actions ──

  void sendMessage(String text) {
    if (text.isEmpty || _channel == null || _username == null) return;
    final clientId = 'msg-${DateTime.now().millisecondsSinceEpoch}-${text.hashCode.toRadixString(36)}';
    final optimistic = TranscriptMessage(from: _username!, text: text, ts: (DateTime.now().millisecondsSinceEpoch / 1000), clientId: clientId);
    state = state.copyWith(transcript: _merge(state.transcript, [optimistic]));
    _channel!.sink.add(jsonEncode({'type': 'message', 'text': text, 'client_id': clientId}));
    _stopTyping();
  }

  void startTyping() {
    if (_isTyping || _channel == null) return;
    _isTyping = true;
    _channel!.sink.add(jsonEncode({'type': 'typing_start'}));
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(milliseconds: 1500), _stopTyping);
  }

  void resetTypingTimer() {
    if (!_isTyping) {
      startTyping();
      return;
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(milliseconds: 1500), _stopTyping);
  }

  void _stopTyping() {
    if (!_isTyping) return;
    _isTyping = false;
    _channel?.sink.add(jsonEncode({'type': 'typing_stop'}));
  }

  void extend() {
    _channel?.sink.add(jsonEncode({'type': 'extend'}));
    state = state.copyWith(sessionEnded: false);
  }

  void leave() {
    _channel?.sink.add(jsonEncode({'type': 'leave'}));
    _close();
  }

  void dismissSessionEnd() {
    state = state.copyWith(sessionEnded: false);
  }

  // ── Helpers ──

  void _appendMarker(String event) {
    final marker = TranscriptMarker(event: event, roomId: roomId, ts: (DateTime.now().millisecondsSinceEpoch / 1000));
    state = state.copyWith(transcript: _merge(state.transcript, [marker]));
  }

  List<TranscriptItem> _merge(List<TranscriptItem> existing, List<TranscriptItem> incoming) {
    final merged = [...existing];
    for (final item in incoming) {
      bool exists = false;
      if (item is TranscriptMessage) {
        exists = merged.any((e) {
          if (e is! TranscriptMessage) return false;
          if (item.clientId != null && e.clientId != null && item.clientId == e.clientId) return true;
          return e.from == item.from && e.text == item.text && e.ts == item.ts;
        });
      } else if (item is TranscriptMarker) {
        exists = merged.any((e) => e is TranscriptMarker && e.roomId == item.roomId && e.event == item.event && e.ts == item.ts);
      }
      if (!exists) merged.add(item);
    }
    merged.sort((a, b) => a.ts.compareTo(b.ts));
    return merged;
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_disposed || state.mode != 'live') return;
      try {
        final token = _token;
        if (token == null) return;
        final data = await _api.getRoomMessages(token, roomId);
        _applyRoomData(data);
        if (data.status == 'ended') {
          state = state.copyWith(mode: 'readonly');
          _close();
        }
      } catch (_) {}
    });
  }

  void _close() {
    _syncTimer?.cancel();
    _typingStopTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _sub = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _close();
    super.dispose();
  }
}

// ── Provider family (keyed by roomId) ──

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>((ref, roomId) {
  final notifier = ChatNotifier(ref, roomId: roomId);
  notifier.initialize();
  return notifier;
});
