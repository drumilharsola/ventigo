import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/models/room_messages.dart';
import 'package:ventigo_app/models/chat_message.dart';
import 'package:ventigo_app/state/chat_provider.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/services/api_client.dart';
import '../helpers/test_helpers.dart';

/// Build a testable ChatNotifier that skips auto-init (ended room, so no WS).
ProviderContainer _buildContainer({
  RoomMessages Function(String token, String roomId)? roomMessagesFactory,
}) {
  final fakeApi = _TestApiClient(roomMessagesFactory: roomMessagesFactory);
  final container = ProviderContainer(overrides: [
    authStorageProvider.overrideWithValue(FakeAuthStorage()),
    authProvider.overrideWith(
        (ref) => TestAuthNotifier(initial: kTestAuthState)),
    apiClientProvider.overrideWithValue(fakeApi),
  ]);
  addTearDown(container.dispose);
  return container;
}

class _TestApiClient extends FakeApiClient {
  final RoomMessages Function(String token, String roomId)? roomMessagesFactory;
  int feedbackCalls = 0;
  int appreciationCalls = 0;

  _TestApiClient({this.roomMessagesFactory});

  @override
  Future<RoomMessages> getRoomMessages(String token, String roomId) async {
    if (roomMessagesFactory != null) return roomMessagesFactory!(token, roomId);
    return RoomMessages.fromJson(const {
      'room_id': 'room1',
      'status': 'ended',
      'peer_username': 'peer',
      'peer_avatar_id': 2,
      'peer_session_id': 'psid',
      'messages': [],
      'duration': '900',
      'started_at': '',
      'ended_at': '',
      'has_appreciated': false,
    });
  }

  @override
  Future<void> postFeedback(String token, String roomId, String mood,
      {String text = ''}) async {
    feedbackCalls++;
  }

  @override
  Future<Map<String, dynamic>> postAppreciation(
      String token, String roomId, String message) async {
    appreciationCalls++;
    return {'status': 'ok'};
  }
}

void main() {
  // -- ChatState --
  group('ChatState', () {
    test('defaults', () {
      const s = ChatState();
      expect(s.transcript, isEmpty);
      expect(s.peerUsername, isNull);
      expect(s.peerAvatarId, 0);
      expect(s.remaining, 900);
      expect(s.timerStarted, false);
      expect(s.peerTyping, false);
      expect(s.sessionEnded, false);
      expect(s.peerLeft, false);
      expect(s.canExtend, true);
      expect(s.connected, false);
      expect(s.connectionError, isNull);
      expect(s.mode, 'checking');
      expect(s.continueWaiting, false);
      expect(s.endingSoon, false);
      expect(s.appreciationSent, false);
      expect(s.reactions, isEmpty);
    });

    test('copyWith all fields', () {
      const s = ChatState();
      final s2 = s.copyWith(
        peerUsername: 'bob',
        peerAvatarId: 3,
        peerSessionId: 'ps',
        remaining: 100,
        timerStarted: true,
        peerTyping: true,
        sessionEnded: true,
        peerLeft: true,
        canExtend: false,
        connected: true,
        connectionError: 'err',
        mode: 'live',
        continueWaiting: true,
        endingSoon: true,
        appreciationSent: true,
        reactions: {
          'msg1': [const ReactionEntry(emoji: '❤️', from: 'bob')]
        },
      );
      expect(s2.peerUsername, 'bob');
      expect(s2.peerAvatarId, 3);
      expect(s2.peerSessionId, 'ps');
      expect(s2.remaining, 100);
      expect(s2.timerStarted, true);
      expect(s2.peerTyping, true);
      expect(s2.sessionEnded, true);
      expect(s2.peerLeft, true);
      expect(s2.canExtend, false);
      expect(s2.connected, true);
      expect(s2.connectionError, 'err');
      expect(s2.mode, 'live');
      expect(s2.continueWaiting, true);
      expect(s2.endingSoon, true);
      expect(s2.appreciationSent, true);
      expect(s2.reactions.length, 1);
    });

    test('clearConnectionError', () {
      const s = ChatState(connectionError: 'oops');
      final s2 = s.copyWith(clearConnectionError: true);
      expect(s2.connectionError, isNull);
    });
  });

  // -- TranscriptMessage / TranscriptMarker --
  group('TranscriptItem', () {
    test('TranscriptMessage fields', () {
      final m = TranscriptMessage(
          from: 'alice', text: 'hi', ts: 100, clientId: 'c1',
          fromSession: 'fs', replyTo: 'r1', replyText: 'rt', replyFrom: 'rf');
      expect(m.from, 'alice');
      expect(m.text, 'hi');
      expect(m.ts, 100);
      expect(m.clientId, 'c1');
      expect(m.fromSession, 'fs');
      expect(m.replyTo, 'r1');
      expect(m.replyText, 'rt');
      expect(m.replyFrom, 'rf');
    });

    test('TranscriptMarker fields', () {
      final m = TranscriptMarker(event: 'ended', roomId: 'r1', ts: 200);
      expect(m.event, 'ended');
      expect(m.roomId, 'r1');
      expect(m.ts, 200);
    });
  });

  // -- ReactionEntry --
  group('ReactionEntry', () {
    test('basic', () {
      const r = ReactionEntry(emoji: '👍', from: 'bob', ts: 99);
      expect(r.emoji, '👍');
      expect(r.from, 'bob');
      expect(r.ts, 99);
    });

    test('without ts', () {
      const r = ReactionEntry(emoji: '❤️', from: 'a');
      expect(r.ts, isNull);
    });
  });

  // -- ChatNotifier (via ProviderContainer) --
  group('ChatNotifier initialize', () {
    test('sets mode to readonly for ended room', () async {
      final container = _buildContainer();
      final notifier = container.read(chatProvider('room1').notifier);
      // give initialize() time to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.mode, 'readonly');
      expect(notifier.state.peerUsername, 'peer');
      expect(notifier.state.peerAvatarId, 2);
    });

    test('sets mode to expired when no token', () async {
      final container = ProviderContainer(overrides: [
        authStorageProvider.overrideWithValue(FakeAuthStorage()),
        authProvider.overrideWith(
            (ref) => TestAuthNotifier(initial: const AuthState())),
        apiClientProvider.overrideWithValue(FakeApiClient()),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(chatProvider('room1').notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.mode, 'expired');
    });

    test('sets mode to expired when roomId is empty', () async {
      final container = _buildContainer();
      final notifier = container.read(chatProvider('').notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.mode, 'expired');
    });

    test('applies room data with messages', () async {
      final container = _buildContainer(
        roomMessagesFactory: (_, __) => RoomMessages(
          status: 'ended',
          peerUsername: 'peer2',
          peerAvatarId: 5,
          peerSessionId: 'ps2',
          matchedAt: '',
          startedAt: '1700000000',
          duration: '600',
          endedAt: '1700000600',
          hasAppreciated: true,
          messages: const [
            ChatMessage(from: 'peer2', text: 'hello', ts: 1700000001, clientId: 'c1'),
            ChatMessage(from: 'me', text: 'hi', ts: 1700000002, clientId: 'c2'),
          ],
        ),
      );
      final notifier = container.read(chatProvider('room1').notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.peerUsername, 'peer2');
      expect(notifier.state.peerAvatarId, 5);
      expect(notifier.state.timerStarted, true);
      expect(notifier.state.appreciationSent, true);
      // transcript should have messages + markers
      expect(notifier.state.transcript.length, greaterThanOrEqualTo(2));
    });

    test('exception during initialize sets mode expired', () async {
      final fakeApi = _TestApiClient(
          roomMessagesFactory: (_, __) {
            throw Exception('network error');
          });
      final container = ProviderContainer(overrides: [
        authStorageProvider.overrideWithValue(FakeAuthStorage()),
        authProvider.overrideWith(
            (ref) => TestAuthNotifier(initial: kTestAuthState)),
        apiClientProvider.overrideWithValue(fakeApi),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(chatProvider('room1').notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.mode, 'expired');
    });
  });

  // -- handleWsForTest (WS message handlers) --
  group('ChatNotifier WS handlers', () {
    late ProviderContainer container;
    late ChatNotifier notifier;

    setUp(() async {
      container = _buildContainer();
      notifier = container.read(chatProvider('room1').notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() => container.dispose());

    test('history adds messages and sets peer', () {
      notifier.handleWsForTest({
        'type': 'history',
        'messages': [
          {'from': 'bob', 'from_session': 'bs', 'text': 'hey', 'ts': 100, 'client_id': 'c1'},
          {'from': 'testuser', 'from_session': 'ts', 'text': 'yo', 'ts': 101, 'client_id': 'c2'},
        ],
      });
      expect(notifier.state.transcript, isNotEmpty);
      expect(notifier.state.peerUsername, 'bob');
    });

    test('history with null messages does nothing', () {
      final before = notifier.state.transcript.length;
      notifier.handleWsForTest({'type': 'history', 'messages': null});
      expect(notifier.state.transcript.length, before);
    });

    test('message adds to transcript', () {
      notifier.handleWsForTest({
        'type': 'message',
        'from': 'bob',
        'from_session': 'bs',
        'text': 'hello!',
        'ts': 200,
        'client_id': 'c10',
      });
      final msgs = notifier.state.transcript.whereType<TranscriptMessage>();
      expect(msgs.any((m) => m.text == 'hello!'), true);
      expect(notifier.state.peerTyping, false);
    });

    test('message with reply fields', () {
      notifier.handleWsForTest({
        'type': 'message',
        'from': 'bob',
        'text': 'reply',
        'ts': 201,
        'client_id': 'c11',
        'reply_to': 'c10',
        'reply_text': 'hello!',
        'reply_from': 'testuser',
      });
      final m = notifier.state.transcript.whereType<TranscriptMessage>().last;
      expect(m.replyTo, 'c10');
      expect(m.replyText, 'hello!');
      expect(m.replyFrom, 'testuser');
    });

    test('own message does not set peer', () {
      notifier.handleWsForTest({
        'type': 'message',
        'from': 'testuser',
        'text': 'my msg',
        'ts': 300,
        'client_id': 'c20',
      });
      // peerUsername should still be 'peer' from init, not 'testuser'
      expect(notifier.state.peerUsername, 'peer');
    });

    test('typing_start sets peerTyping', () {
      notifier.handleWsForTest({'type': 'typing_start', 'from': 'bob'});
      expect(notifier.state.peerTyping, true);
      expect(notifier.state.peerUsername, 'bob');
    });

    test('typing_start from self ignored', () {
      notifier.handleWsForTest({'type': 'typing_start', 'from': 'testuser'});
      expect(notifier.state.peerTyping, false);
    });

    test('typing_stop resets peerTyping', () {
      notifier.handleWsForTest({'type': 'typing_start', 'from': 'bob'});
      expect(notifier.state.peerTyping, true);
      notifier.handleWsForTest({'type': 'typing_stop', 'from': 'bob'});
      expect(notifier.state.peerTyping, false);
    });

    test('typing_stop from self ignored', () {
      notifier.handleWsForTest({'type': 'typing_start', 'from': 'bob'});
      notifier.handleWsForTest({'type': 'typing_stop', 'from': 'testuser'});
      expect(notifier.state.peerTyping, true);
    });

    test('tick updates remaining and timerStarted', () {
      notifier.handleWsForTest({'type': 'tick', 'remaining': 450});
      expect(notifier.state.remaining, 450);
      expect(notifier.state.timerStarted, true);
    });

    test('timer_status started adds marker', () {
      notifier.handleWsForTest({
        'type': 'timer_status',
        'started': true,
        'remaining': 800,
      });
      expect(notifier.state.timerStarted, true);
      expect(notifier.state.remaining, 800);
      final markers = notifier.state.transcript.whereType<TranscriptMarker>();
      expect(markers.any((m) => m.event == 'started'), true);
    });

    test('timer_status not started', () {
      notifier.handleWsForTest({
        'type': 'timer_status',
        'started': false,
        'remaining': 900,
      });
      expect(notifier.state.timerStarted, false);
    });

    test('session_end sets sessionEnded and adds marker', () {
      notifier.handleWsForTest({'type': 'session_end'});
      expect(notifier.state.sessionEnded, true);
      final markers = notifier.state.transcript.whereType<TranscriptMarker>();
      expect(markers.any((m) => m.event == 'ended'), true);
    });

    test('peer_left sets peerLeft and canExtend false', () {
      notifier.handleWsForTest({'type': 'peer_left'});
      expect(notifier.state.peerLeft, true);
      expect(notifier.state.canExtend, false);
      expect(notifier.state.sessionEnded, true);
    });

    test('extended updates remaining and resets flags', () {
      notifier.handleWsForTest({'type': 'session_end'});
      notifier.handleWsForTest({'type': 'extended', 'remaining': 600});
      expect(notifier.state.remaining, 600);
      expect(notifier.state.canExtend, false);
      expect(notifier.state.sessionEnded, false);
      expect(notifier.state.continueWaiting, false);
      expect(notifier.state.endingSoon, false);
    });

    test('ending_soon sets flag', () {
      notifier.handleWsForTest({'type': 'ending_soon'});
      expect(notifier.state.endingSoon, true);
    });

    test('continue_accepted sets continueRoomId', () {
      notifier.handleWsForTest({
        'type': 'continue_accepted',
        'room_id': 'new-room',
      });
      expect(notifier.state.continueWaiting, false);
      expect(notifier.continueRoomId, 'new-room');
    });

    test('error sets connectionError', () {
      notifier.handleWsForTest({'type': 'error', 'detail': 'bad'});
      expect(notifier.state.connectionError, 'bad');
    });

    test('continue_request does nothing', () {
      final before = notifier.state;
      notifier.handleWsForTest({'type': 'continue_request'});
      // state shouldn't change
      expect(notifier.state.mode, before.mode);
    });

    test('unknown type does nothing', () {
      final before = notifier.state;
      notifier.handleWsForTest({'type': 'unknown_type'});
      expect(notifier.state.mode, before.mode);
    });

    test('reaction adds to reactions map', () {
      notifier.handleWsForTest({
        'type': 'reaction',
        'message_client_id': 'c1',
        'emoji': '❤️',
        'from': 'bob',
        'ts': 500,
      });
      expect(notifier.state.reactions['c1']?.length, 1);
      expect(notifier.state.reactions['c1']!.first.emoji, '❤️');
    });

    test('duplicate reaction not added', () {
      notifier.handleWsForTest({
        'type': 'reaction',
        'message_client_id': 'c1',
        'emoji': '❤️',
        'from': 'bob',
      });
      notifier.handleWsForTest({
        'type': 'reaction',
        'message_client_id': 'c1',
        'emoji': '❤️',
        'from': 'bob',
      });
      expect(notifier.state.reactions['c1']?.length, 1);
    });

    test('reaction with null fields ignored', () {
      notifier.handleWsForTest({
        'type': 'reaction',
        'message_client_id': null,
        'emoji': '🔥',
        'from': 'bob',
      });
      expect(notifier.state.reactions, isEmpty);
    });

    test('different reactions to same message', () {
      notifier.handleWsForTest({
        'type': 'reaction',
        'message_client_id': 'c1',
        'emoji': '❤️',
        'from': 'bob',
      });
      notifier.handleWsForTest({
        'type': 'reaction',
        'message_client_id': 'c1',
        'emoji': '👍',
        'from': 'bob',
      });
      expect(notifier.state.reactions['c1']?.length, 2);
    });
  });

  // -- merge dedup logic (tested through handlers) --
  group('ChatNotifier merge dedup', () {
    late ProviderContainer container;
    late ChatNotifier notifier;

    setUp(() async {
      container = _buildContainer();
      notifier = container.read(chatProvider('room1').notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() => container.dispose());

    test('duplicate messages by clientId not added twice', () {
      notifier.handleWsForTest({
        'type': 'message',
        'from': 'bob',
        'text': 'dup',
        'ts': 100,
        'client_id': 'dup1',
      });
      notifier.handleWsForTest({
        'type': 'message',
        'from': 'bob',
        'text': 'dup',
        'ts': 100,
        'client_id': 'dup1',
      });
      final msgs = notifier.state.transcript
          .whereType<TranscriptMessage>()
          .where((m) => m.clientId == 'dup1');
      expect(msgs.length, 1);
    });

    test('duplicate messages by from+text+ts not added', () {
      notifier.handleWsForTest({
        'type': 'message',
        'from': 'bob',
        'text': 'same',
        'ts': 200,
      });
      notifier.handleWsForTest({
        'type': 'message',
        'from': 'bob',
        'text': 'same',
        'ts': 200,
      });
      final msgs = notifier.state.transcript
          .whereType<TranscriptMessage>()
          .where((m) => m.text == 'same');
      expect(msgs.length, 1);
    });

    test('messages sorted by ts', () {
      notifier.handleWsForTest({
        'type': 'message',
        'from': 'bob',
        'text': 'second',
        'ts': 300,
        'client_id': 'c300',
      });
      notifier.handleWsForTest({
        'type': 'message',
        'from': 'bob',
        'text': 'first',
        'ts': 100,
        'client_id': 'c100',
      });
      final tss = notifier.state.transcript.map((t) => t.ts).toList();
      for (int i = 1; i < tss.length; i++) {
        expect(tss[i], greaterThanOrEqualTo(tss[i - 1]));
      }
    });
  });

  // -- applyRoomDataForTest --
  group('ChatNotifier applyRoomData', () {
    late ProviderContainer container;
    late ChatNotifier notifier;

    setUp(() async {
      container = _buildContainer();
      notifier = container.read(chatProvider('room1').notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() => container.dispose());

    test('applies room data with started marker', () {
      notifier.applyRoomDataForTest(RoomMessages(
        status: 'active',
        peerUsername: 'alice',
        peerAvatarId: 7,
        peerSessionId: 'as1',
        matchedAt: '',
        startedAt: '1700000000',
        duration: '600',
        endedAt: '',
        hasAppreciated: false,
        messages: const [
          ChatMessage(from: 'alice', text: 'hi', ts: 1700000001, clientId: 'c1'),
        ],
      ));
      expect(notifier.state.peerUsername, 'alice');
      expect(notifier.state.peerAvatarId, 7);
      expect(notifier.state.timerStarted, true);
      final markers = notifier.state.transcript.whereType<TranscriptMarker>();
      expect(markers.any((m) => m.event == 'started'), true);
    });

    test('applies room data with ended marker', () {
      notifier.applyRoomDataForTest(RoomMessages(
        status: 'ended',
        peerUsername: 'alice',
        peerAvatarId: 7,
        peerSessionId: 'as1',
        matchedAt: '',
        startedAt: '1700000000',
        duration: '600',
        endedAt: '1700000600',
        hasAppreciated: true,
        messages: const [],
      ));
      final markers = notifier.state.transcript.whereType<TranscriptMarker>();
      expect(markers.any((m) => m.event == 'ended'), true);
      expect(notifier.state.appreciationSent, true);
    });

    test('computes remaining from started_at', () {
      final now = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      notifier.applyRoomDataForTest(RoomMessages(
        status: 'active',
        peerUsername: 'x',
        peerAvatarId: 0,
        peerSessionId: '',
        matchedAt: '',
        startedAt: (now - 100).toString(),
        duration: '900',
        endedAt: '',
        hasAppreciated: false,
        messages: const [],
      ));
      // remaining should be roughly 900 - 100 = 800 (± a few seconds)
      expect(notifier.state.remaining, closeTo(800, 5));
    });

    test('remaining clamped to 0', () {
      notifier.applyRoomDataForTest(RoomMessages(
        status: 'active',
        peerUsername: 'x',
        peerAvatarId: 0,
        peerSessionId: '',
        matchedAt: '',
        startedAt: '1000000',
        duration: '900',
        endedAt: '',
        hasAppreciated: false,
        messages: const [],
      ));
      expect(notifier.state.remaining, 0);
    });

    test('remaining defaults to duration when not started', () {
      notifier.applyRoomDataForTest(RoomMessages(
        status: 'active',
        peerUsername: 'x',
        peerAvatarId: 0,
        peerSessionId: '',
        matchedAt: '',
        startedAt: '',
        duration: '1200',
        endedAt: '',
        hasAppreciated: false,
        messages: const [],
      ));
      expect(notifier.state.remaining, 1200);
    });

    test('does not overwrite peerUsername when empty', () {
      notifier.applyRoomDataForTest(RoomMessages(
        status: 'ended',
        peerUsername: 'initial',
        peerAvatarId: 1,
        peerSessionId: 'ps',
        matchedAt: '',
        startedAt: '',
        duration: '900',
        endedAt: '',
        hasAppreciated: false,
        messages: const [],
      ));
      expect(notifier.state.peerUsername, 'initial');
      notifier.applyRoomDataForTest(RoomMessages(
        status: 'ended',
        peerUsername: '',
        peerAvatarId: 1,
        peerSessionId: '',
        matchedAt: '',
        startedAt: '',
        duration: '900',
        endedAt: '',
        hasAppreciated: false,
        messages: const [],
      ));
      // Should keep 'initial', not overwrite with empty
      expect(notifier.state.peerUsername, 'initial');
    });
  });

  // -- Public actions --
  group('ChatNotifier actions', () {
    late ProviderContainer container;
    late ChatNotifier notifier;

    setUp(() async {
      container = _buildContainer();
      notifier = container.read(chatProvider('room1').notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() => container.dispose());

    test('dismissSessionEnd clears flag', () {
      notifier.handleWsForTest({'type': 'session_end'});
      expect(notifier.state.sessionEnded, true);
      notifier.dismissSessionEnd();
      expect(notifier.state.sessionEnded, false);
    });

    test('leave sets mode to readonly', () {
      notifier.leave();
      expect(notifier.state.mode, 'readonly');
    });

    test('sendFeedback calls API', () async {
      await notifier.sendFeedback('happy');
      final api =
          container.read(apiClientProvider) as _TestApiClient;
      expect(api.feedbackCalls, 1);
    });

    test('sendFeedback no-op without token', () async {
      final container2 = ProviderContainer(overrides: [
        authStorageProvider.overrideWithValue(FakeAuthStorage()),
        authProvider.overrideWith(
            (ref) => TestAuthNotifier(initial: const AuthState())),
        apiClientProvider.overrideWithValue(_TestApiClient()),
      ]);
      addTearDown(container2.dispose);
      final n = container2.read(chatProvider('room2').notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await n.sendFeedback('sad');
      final api = container2.read(apiClientProvider) as _TestApiClient;
      expect(api.feedbackCalls, 0);
    });

    test('sendAppreciation sets flag', () async {
      await notifier.sendAppreciation('thanks!');
      expect(notifier.state.appreciationSent, true);
      final api =
          container.read(apiClientProvider) as _TestApiClient;
      expect(api.appreciationCalls, 1);
    });
  });
}
