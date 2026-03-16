import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/state/chat_provider.dart';
import 'package:ventigo_app/state/board_provider.dart';
import 'package:ventigo_app/state/pending_wait_provider.dart';
import 'package:ventigo_app/models/chat_message.dart';

void main() {
  // ---- AuthState ----
  group('AuthState', () {
    test('defaults', () {
      const s = AuthState();
      expect(s.token, isNull);
      expect(s.sessionId, isNull);
      expect(s.username, isNull);
      expect(s.avatarId, isNull);
      expect(s.emailVerified, isNull);
      expect(s.hasHydrated, false);
      expect(s.isLoggedIn, false);
      expect(s.hasProfile, false);
    });

    test('isLoggedIn when token set', () {
      const s = AuthState(token: 'tok');
      expect(s.isLoggedIn, true);
    });

    test('hasProfile when username set', () {
      const s = AuthState(username: 'u');
      expect(s.hasProfile, true);
    });

    test('copyWith preserves existing', () {
      const s = AuthState(token: 't', sessionId: 's', username: 'u', avatarId: 1, emailVerified: true, hasHydrated: true);
      final c = s.copyWith();
      expect(c.token, 't');
      expect(c.sessionId, 's');
      expect(c.username, 'u');
      expect(c.avatarId, 1);
      expect(c.emailVerified, true);
      expect(c.hasHydrated, true);
    });

    test('copyWith overrides fields', () {
      const s = AuthState(token: 'old');
      final c = s.copyWith(token: 'new', avatarId: 5, hasHydrated: true);
      expect(c.token, 'new');
      expect(c.avatarId, 5);
      expect(c.hasHydrated, true);
    });
  });

  // ---- ChatState ----
  group('ChatState', () {
    test('defaults', () {
      const s = ChatState();
      expect(s.transcript, isEmpty);
      expect(s.peerUsername, isNull);
      expect(s.peerAvatarId, 0);
      expect(s.peerSessionId, isNull);
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

    test('copyWith preserves existing', () {
      const s = ChatState(peerUsername: 'peer', remaining: 500, mode: 'live');
      final c = s.copyWith();
      expect(c.peerUsername, 'peer');
      expect(c.remaining, 500);
      expect(c.mode, 'live');
    });

    test('copyWith overrides fields', () {
      const s = ChatState();
      final c = s.copyWith(
        peerUsername: 'alice',
        peerAvatarId: 3,
        peerSessionId: 'ps1',
        remaining: 300,
        timerStarted: true,
        peerTyping: true,
        sessionEnded: true,
        peerLeft: true,
        canExtend: false,
        connected: true,
        connectionError: 'err',
        mode: 'readonly',
        continueWaiting: true,
        endingSoon: true,
        appreciationSent: true,
      );
      expect(c.peerUsername, 'alice');
      expect(c.peerAvatarId, 3);
      expect(c.peerSessionId, 'ps1');
      expect(c.remaining, 300);
      expect(c.timerStarted, true);
      expect(c.peerTyping, true);
      expect(c.sessionEnded, true);
      expect(c.peerLeft, true);
      expect(c.canExtend, false);
      expect(c.connected, true);
      expect(c.connectionError, 'err');
      expect(c.mode, 'readonly');
      expect(c.continueWaiting, true);
      expect(c.endingSoon, true);
      expect(c.appreciationSent, true);
    });

    test('copyWith clearConnectionError', () {
      const s = ChatState(connectionError: 'some error');
      final c = s.copyWith(clearConnectionError: true);
      expect(c.connectionError, isNull);
    });

    test('copyWith reactions', () {
      const s = ChatState();
      final c = s.copyWith(reactions: {
        'msg1': [const ReactionEntry(emoji: '❤️', from: 'u1')],
      });
      expect(c.reactions.containsKey('msg1'), true);
      expect(c.reactions['msg1']!.first.emoji, '❤️');
    });

    test('copyWith transcript', () {
      const s = ChatState();
      final c = s.copyWith(transcript: [
        TranscriptMessage(from: 'a', text: 'hi', ts: 1.0),
      ]);
      expect(c.transcript.length, 1);
    });
  });

  // ---- ReactionEntry ----
  group('ReactionEntry', () {
    test('constructor with ts', () {
      const r = ReactionEntry(emoji: '👍', from: 'bob', ts: 12345);
      expect(r.emoji, '👍');
      expect(r.from, 'bob');
      expect(r.ts, 12345);
    });
    test('constructor without ts', () {
      const r = ReactionEntry(emoji: '🎉', from: 'alice');
      expect(r.ts, isNull);
    });
  });

  // ---- BoardState ----
  group('BoardState', () {
    test('defaults', () {
      const s = BoardState();
      expect(s.requests, isEmpty);
      expect(s.myRequestId, isNull);
      expect(s.error, isNull);
    });

    test('copyWith preserves existing', () {
      const s = BoardState(myRequestId: 'r1');
      final c = s.copyWith();
      expect(c.myRequestId, 'r1');
    });

    test('copyWith overrides', () {
      const s = BoardState();
      final c = s.copyWith(myRequestId: 'r2', error: 'fail');
      expect(c.myRequestId, 'r2');
      expect(c.error, 'fail');
    });

    test('copyWith clearMyRequest', () {
      const s = BoardState(myRequestId: 'r1');
      final c = s.copyWith(clearMyRequest: true);
      expect(c.myRequestId, isNull);
    });
  });

  // ---- PendingWaitState ----
  group('PendingWaitState', () {
    test('defaults', () {
      const s = PendingWaitState();
      expect(s.requestId, isNull);
      expect(s.remaining, 600);
      expect(s.timedOut, false);
      expect(s.matchedRoomId, isNull);
      expect(s.isWaiting, false);
    });

    test('isWaiting true when requestId set and not timed out', () {
      const s = PendingWaitState(requestId: 'r1');
      expect(s.isWaiting, true);
    });

    test('isWaiting false when timed out', () {
      const s = PendingWaitState(requestId: 'r1', timedOut: true);
      expect(s.isWaiting, false);
    });

    test('isWaiting false when matched', () {
      const s = PendingWaitState(requestId: 'r1', matchedRoomId: 'room1');
      expect(s.isWaiting, false);
    });

    test('copyWith preserves existing', () {
      const s = PendingWaitState(requestId: 'r1', remaining: 300);
      final c = s.copyWith();
      expect(c.requestId, 'r1');
      expect(c.remaining, 300);
    });

    test('copyWith overrides', () {
      const s = PendingWaitState();
      final c = s.copyWith(requestId: 'r2', remaining: 100, timedOut: true, matchedRoomId: 'rm1');
      expect(c.requestId, 'r2');
      expect(c.remaining, 100);
      expect(c.timedOut, true);
      expect(c.matchedRoomId, 'rm1');
    });

    test('copyWith clearRequest', () {
      const s = PendingWaitState(requestId: 'r1');
      final c = s.copyWith(clearRequest: true);
      expect(c.requestId, isNull);
    });

    test('copyWith clearMatch', () {
      const s = PendingWaitState(matchedRoomId: 'rm1');
      final c = s.copyWith(clearMatch: true);
      expect(c.matchedRoomId, isNull);
    });
  });

  // ---- TranscriptMessage ----
  group('TranscriptMessage', () {
    test('basic fields', () {
      final m = TranscriptMessage(from: 'alice', text: 'hi', ts: 100.0);
      expect(m.from, 'alice');
      expect(m.text, 'hi');
      expect(m.ts, 100.0);
      expect(m.clientId, isNull);
      expect(m.fromSession, isNull);
      expect(m.replyTo, isNull);
      expect(m.replyText, isNull);
      expect(m.replyFrom, isNull);
    });

    test('with optional fields', () {
      final m = TranscriptMessage(
        from: 'bob',
        fromSession: 'sid',
        text: 'reply',
        ts: 200.0,
        clientId: 'cid1',
        replyTo: 'cid0',
        replyText: 'original',
        replyFrom: 'alice',
      );
      expect(m.fromSession, 'sid');
      expect(m.clientId, 'cid1');
      expect(m.replyTo, 'cid0');
      expect(m.replyText, 'original');
      expect(m.replyFrom, 'alice');
    });
  });

  // ---- TranscriptMarker ----
  group('TranscriptMarker', () {
    test('fields', () {
      final m = TranscriptMarker(event: 'started', roomId: 'r1', ts: 50.0);
      expect(m.event, 'started');
      expect(m.roomId, 'r1');
      expect(m.ts, 50.0);
    });
  });
}
