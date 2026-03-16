import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import '../models/chat_message.dart';
import '../models/room_messages.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';

// -- State --

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
  final bool continueWaiting;
  final bool endingSoon;
  final bool appreciationSent;
  final Map<String, List<ReactionEntry>> reactions;

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
    this.continueWaiting = false,
    this.endingSoon = false,
    this.appreciationSent = false,
    this.reactions = const {},
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
    bool? continueWaiting,
    bool? endingSoon,
    bool? appreciationSent,
    Map<String, List<ReactionEntry>>? reactions,
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
      continueWaiting: continueWaiting ?? this.continueWaiting,
      endingSoon: endingSoon ?? this.endingSoon,
      appreciationSent: appreciationSent ?? this.appreciationSent,
      reactions: reactions ?? this.reactions,
    );
  }
}

/// Simple reaction entry.
class ReactionEntry {
  final String emoji;
  final String from;
  final int? ts;
  const ReactionEntry({required this.emoji, required this.from, this.ts});
}

// -- Notifier --

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
  String? _continueRoomId;

  ChatNotifier(this.ref, {required this.roomId, this.initialPeerSessionId}) : super(const ChatState());

  String? get _token => ref.read(authProvider).token;
  String? get _username => ref.read(authProvider).username;
  ApiClient get _api => ref.read(apiClientProvider);
  /// Expose continue room ID for navigation by the chat screen.
  String? get continueRoomId => _continueRoomId;

  // -- Lifecycle --

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
      fromSession: m.fromSession,
      text: m.text,
      ts: m.ts,
      clientId: m.clientId,
    )).toList();

    // Add 'started' marker when timer has started (started_at is set)
    final startedTs = double.tryParse(data.startedAt) ?? 0;
    final hasStartedMarker = state.transcript.any((t) => t is TranscriptMarker && t.event == 'started' && t.roomId == roomId);
    final List<TranscriptItem> extra = [];
    if (startedTs > 0 && !hasStartedMarker) {
      extra.add(TranscriptMarker(event: 'started', roomId: roomId, ts: startedTs));
    }

    // Add 'ended' marker when room has ended
    final endedTs = double.tryParse(data.endedAt) ?? 0;
    final hasEndedMarker = state.transcript.any((t) => t is TranscriptMarker && t.event == 'ended' && t.roomId == roomId);
    if (endedTs > 0 && !hasEndedMarker) {
      extra.add(TranscriptMarker(event: 'ended', roomId: roomId, ts: endedTs));
    }

    state = state.copyWith(
      transcript: _merge(state.transcript, [...extra, ...msgs]),
      peerUsername: data.peerUsername.isNotEmpty ? data.peerUsername : state.peerUsername,
      peerAvatarId: data.peerAvatarId,
      peerSessionId: data.peerSessionId.isNotEmpty ? data.peerSessionId : state.peerSessionId,
      remaining: _computeRemaining(data),
      timerStarted: data.startedAt.isNotEmpty,
      appreciationSent: data.hasAppreciated,
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

  // -- WebSocket --

  void _connectWs() {
    final token = _token;
    if (token == null || _disposed || state.mode != 'live') return;

    final uri = Uri.parse(Env.chatWsUrl(token, roomId));
    _channel = WebSocketChannel.connect(uri);

    _sub = _channel!.stream.listen(
      (raw) => _handleWs(jsonDecode(raw as String) as Map<String, dynamic>),
      onDone: () {
        state = state.copyWith(connected: false);
        // Don't reconnect - chat WS is session-bound; going offline means ended
      },
      onError: (_) => state = state.copyWith(connected: false),
    );

    state = state.copyWith(connected: true, clearConnectionError: true);
  }

  void _handleHistoryWs(Map<String, dynamic> data, String? username) {
    final msgs = (data['messages'] as List?)
        ?.map((m) => TranscriptMessage(
              from: m['from'] as String,
              fromSession: m['from_session'] as String?,
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
  }

  void _handleMessageWs(Map<String, dynamic> data, String? username) {
    final msg = TranscriptMessage(
      from: data['from'] as String,
      fromSession: data['from_session'] as String?,
      text: data['text'] as String,
      ts: (data['ts'] as num).toDouble(),
      clientId: data['client_id'] as String?,
      replyTo: data['reply_to'] as String?,
      replyText: data['reply_text'] as String?,
      replyFrom: data['reply_from'] as String?,
    );
    state = state.copyWith(transcript: _merge(state.transcript, [msg]));
    if (msg.from != username) {
      state = state.copyWith(peerUsername: msg.from, peerTyping: false);
    }
  }

  void _handleReactionWs(Map<String, dynamic> data) {
    final msgClientId = data['message_client_id'] as String?;
    final emoji = data['emoji'] as String?;
    final reactFrom = data['from'] as String?;
    if (msgClientId != null && emoji != null && reactFrom != null) {
      final updated = Map<String, List<ReactionEntry>>.from(state.reactions);
      final existing = List<ReactionEntry>.from(updated[msgClientId] ?? []);
      final alreadyExists = existing.any((r) => r.emoji == emoji && r.from == reactFrom);
      if (!alreadyExists) {
        final reactTs = (data['ts'] as num?)?.toInt();
        existing.add(ReactionEntry(emoji: emoji, from: reactFrom, ts: reactTs));
        updated[msgClientId] = existing;
        state = state.copyWith(reactions: updated);
      }
    }
  }

  void _handleTypingStart(Map<String, dynamic> data) {
    if (data['from'] != _username) {
      state = state.copyWith(peerTyping: true, peerUsername: data['from'] as String?);
    }
  }

  void _handleTypingStop(Map<String, dynamic> data) {
    if (data['from'] != _username) state = state.copyWith(peerTyping: false);
  }

  void _handleTick(Map<String, dynamic> data) {
    state = state.copyWith(timerStarted: true, remaining: (data['remaining'] as num).toInt());
  }

  void _handleSessionEnd() {
    _appendMarker('ended');
    state = state.copyWith(sessionEnded: true);
  }

  void _handlePeerLeft() {
    _appendMarker('ended');
    state = state.copyWith(peerLeft: true, canExtend: false, sessionEnded: true);
  }

  void _handleExtended(Map<String, dynamic> data) {
    state = state.copyWith(
      remaining: (data['remaining'] as num).toInt(),
      canExtend: false,
      sessionEnded: false,
      continueWaiting: false,
      endingSoon: false,
    );
  }

  void _handleContinueAccepted(Map<String, dynamic> data) {
    state = state.copyWith(continueWaiting: false);
    _continueRoomId = data['room_id'] as String?;
  }

  /// Exposed for unit‑testing WS message handlers.
  @visibleForTesting
  void handleWsForTest(Map<String, dynamic> data) => _handleWs(data);

  /// Exposed for unit‑testing room data application.
  @visibleForTesting
  void applyRoomDataForTest(RoomMessages data) => _applyRoomData(data);

  void _handleWs(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'history':        _handleHistoryWs(data, _username);
      case 'message':        _handleMessageWs(data, _username);
      case 'typing_start':   _handleTypingStart(data);
      case 'typing_stop':    _handleTypingStop(data);
      case 'timer_status':   _handleTimerStatusWs(data);
      case 'tick':           _handleTick(data);
      case 'session_end':    _handleSessionEnd();
      case 'peer_left':      _handlePeerLeft();
      case 'extended':       _handleExtended(data);
      case 'ending_soon':    state = state.copyWith(endingSoon: true);
      case 'continue_request': break;
      case 'continue_accepted': _handleContinueAccepted(data);
      case 'reaction':       _handleReactionWs(data);
      case 'error':          state = state.copyWith(connectionError: data['detail'] as String?);
    }
  }

  void _handleTimerStatusWs(Map<String, dynamic> data) {
    final started = data['started'] as bool? ?? false;
    if (started && !state.timerStarted) {
      _appendMarkerIfMissing('started');
    }
    state = state.copyWith(timerStarted: started, remaining: (data['remaining'] as num).toInt());
  }

  // -- Actions --

  void sendMessage(String text, {TranscriptMessage? replyTo}) {
    if (text.isEmpty || _channel == null || _username == null) return;
    final sessionId = ref.read(authProvider).sessionId;
    final clientId = 'msg-${DateTime.now().millisecondsSinceEpoch}-${text.hashCode.toRadixString(36)}';
    final optimistic = TranscriptMessage(
      from: _username!,
      fromSession: sessionId,
      text: text,
      ts: (DateTime.now().millisecondsSinceEpoch / 1000),
      clientId: clientId,
      replyTo: replyTo?.clientId,
      replyText: replyTo?.text,
      replyFrom: replyTo?.from,
    );
    state = state.copyWith(transcript: _merge(state.transcript, [optimistic]));
    final payload = <String, dynamic>{'type': 'message', 'text': text, 'client_id': clientId};
    if (replyTo?.clientId != null) {
      payload['reply_to'] = replyTo!.clientId;
      payload['reply_text'] = replyTo.text;
      payload['reply_from'] = replyTo.from;
    }
    _channel!.sink.add(jsonEncode(payload));
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

  void requestContinue() {
    _channel?.sink.add(jsonEncode({'type': 'continue'}));
    state = state.copyWith(continueWaiting: true);
  }

  void sendReaction(String messageClientId, String emoji) {
    _channel?.sink.add(jsonEncode({
      'type': 'reaction',
      'message_client_id': messageClientId,
      'emoji': emoji,
    }));
  }

  Future<void> sendFeedback(String mood) async {
    final token = _token;
    if (token == null) return;
    try {
      await _api.postFeedback(token, roomId, mood);
    } catch (_) {}
  }

  Future<void> sendAppreciation(String message) async {
    final token = _token;
    if (token == null) return;
    await _api.postAppreciation(token, roomId, message);
    state = state.copyWith(appreciationSent: true);
  }

  void leave() {
    _channel?.sink.add(jsonEncode({'type': 'leave'}));
    _close();
    _appendMarkerIfMissing('ended');
    state = state.copyWith(mode: 'readonly');
  }

  void dismissSessionEnd() {
    state = state.copyWith(sessionEnded: false);
  }

  // -- Helpers --

  void _appendMarker(String event) {
    final marker = TranscriptMarker(event: event, roomId: roomId, ts: (DateTime.now().millisecondsSinceEpoch / 1000));
    state = state.copyWith(transcript: _merge(state.transcript, [marker]));
  }

  void _appendMarkerIfMissing(String event) {
    final exists = state.transcript.any((t) => t is TranscriptMarker && t.event == event && t.roomId == roomId);
    if (!exists) _appendMarker(event);
  }

  bool _isDuplicateMessage(List<TranscriptItem> list, TranscriptMessage item) {
    return list.any((e) {
      if (e is! TranscriptMessage) return false;
      if (item.clientId != null && e.clientId != null && item.clientId == e.clientId) return true;
      return e.from == item.from && e.text == item.text && e.ts == item.ts;
    });
  }

  List<TranscriptItem> _merge(List<TranscriptItem> existing, List<TranscriptItem> incoming) {
    final merged = [...existing];
    for (final item in incoming) {
      bool exists = false;
      if (item is TranscriptMessage) {
        exists = _isDuplicateMessage(merged, item);
      } else if (item is TranscriptMarker) {
        exists = merged.any((e) => e is TranscriptMarker && e.roomId == item.roomId && e.event == item.event && e.ts == item.ts);
      }
      if (!exists) merged.add(item);
    }
    merged.sort((a, b) => a.ts.compareTo(b.ts));
    return merged;
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
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

// -- Provider family (keyed by roomId) --

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>((ref, roomId) {
  final notifier = ChatNotifier(ref, roomId: roomId);
  notifier.initialize();
  return notifier;
});
