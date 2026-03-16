import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/models/speaker_request.dart';
import 'package:ventigo_app/models/appreciation.dart';
import 'package:ventigo_app/models/blocked_user.dart';
import 'package:ventigo_app/models/chat_message.dart';
import 'package:ventigo_app/models/room_summary.dart';
import 'package:ventigo_app/models/room_messages.dart';
import 'package:ventigo_app/models/user_profile.dart';
import 'package:ventigo_app/models/current_speaker_request.dart';
import 'package:ventigo_app/models/intent.dart';

void main() {
  group('SpeakerRequest', () {
    test('fromJson parses all fields', () {
      final json = {
        'request_id': 'req-1',
        'session_id': 'sid-1',
        'username': 'Fox',
        'avatar_id': 3,
        'posted_at': '1700000000',
        'topic': 'Anxiety',
      };
      final req = SpeakerRequest.fromJson(json);
      expect(req.requestId, 'req-1');
      expect(req.sessionId, 'sid-1');
      expect(req.username, 'Fox');
      expect(req.avatarId, '3');
      expect(req.postedAt, '1700000000');
      expect(req.topic, 'Anxiety');
    });

    test('fromJson handles missing fields', () {
      final req = SpeakerRequest.fromJson({});
      expect(req.requestId, '');
      expect(req.username, '');
      expect(req.topic, '');
    });

    test('topic defaults to empty', () {
      const req = SpeakerRequest(
        requestId: 'r1',
        sessionId: 's1',
        username: 'Fox',
        avatarId: '0',
        postedAt: '123',
      );
      expect(req.topic, '');
    });
  });

  group('Appreciation', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 42,
        'from_username': 'Panda',
        'from_role': 'listener',
        'message': 'Thanks for listening!',
        'created_at': 1700000000,
      };
      final a = Appreciation.fromJson(json);
      expect(a.id, 42);
      expect(a.fromUsername, 'Panda');
      expect(a.fromRole, 'listener');
      expect(a.message, 'Thanks for listening!');
      expect(a.createdAt, 1700000000);
    });
  });

  group('BlockedUser', () {
    test('fromJson with peer_session_id', () {
      final json = {
        'peer_session_id': 'sid-2',
        'username': 'Bad',
        'avatar_id': 5,
        'blocked_at': '1700000000',
      };
      final u = BlockedUser.fromJson(json);
      expect(u.sessionId, 'sid-2');
      expect(u.username, 'Bad');
      expect(u.avatarId, 5);
    });

    test('fromJson with session_id fallback', () {
      final json = {'session_id': 'sid-3'};
      final u = BlockedUser.fromJson(json);
      expect(u.sessionId, 'sid-3');
    });

    test('fromJson handles missing fields', () {
      final u = BlockedUser.fromJson({});
      expect(u.sessionId, '');
      expect(u.username, '');
      expect(u.avatarId, 0);
    });
  });

  group('ChatMessage', () {
    test('fromJson parses all fields', () {
      final json = {
        'type': 'message',
        'from': 'Fox',
        'from_session': 'sid-1',
        'text': 'hello',
        'ts': 1700000000,
        'client_id': 'cid-1',
      };
      final msg = ChatMessage.fromJson(json);
      expect(msg.type, 'message');
      expect(msg.from, 'Fox');
      expect(msg.fromSession, 'sid-1');
      expect(msg.text, 'hello');
      expect(msg.ts, 1700000000.0);
      expect(msg.clientId, 'cid-1');
    });

    test('toJson produces correct output', () {
      const msg = ChatMessage(
        from: 'Fox',
        text: 'hello',
        ts: 100.0,
        clientId: 'cid-1',
      );
      final json = msg.toJson();
      expect(json['type'], 'message');
      expect(json['text'], 'hello');
      expect(json['client_id'], 'cid-1');
    });

    test('toJson omits null client_id', () {
      const msg = ChatMessage(from: 'Fox', text: 'hi', ts: 100.0);
      final json = msg.toJson();
      expect(json.containsKey('client_id'), isFalse);
    });
  });

  group('RoomSummary', () {
    test('fromJson parses all fields', () {
      final json = {
        'room_id': 'r1',
        'role': 'speaker',
        'peer_username': 'Panda',
        'peer_avatar_id': 5,
        'peer_session_id': 'sid-2',
        'started_at': '123',
        'ended_at': '456',
        'matched_at': '100',
        'status': 'ended',
        'duration': 900,
        'has_appreciated': true,
      };
      final room = RoomSummary.fromJson(json);
      expect(room.roomId, 'r1');
      expect(room.role, 'speaker');
      expect(room.peerUsername, 'Panda');
      expect(room.peerAvatarId, 5);
      expect(room.status, 'ended');
      expect(room.hasAppreciated, isTrue);
    });

    test('fromJson handles missing fields', () {
      final room = RoomSummary.fromJson({});
      expect(room.roomId, '');
      expect(room.peerAvatarId, 0);
      expect(room.duration, '900');
      expect(room.hasAppreciated, isFalse);
    });
  });

  group('RoomMessages', () {
    test('fromJson parses messages list', () {
      final json = {
        'status': 'ended',
        'peer_username': 'Fox',
        'peer_avatar_id': 1,
        'peer_session_id': 'sid-2',
        'matched_at': '100',
        'started_at': '101',
        'duration': '900',
        'ended_at': '1001',
        'has_appreciated': false,
        'messages': [
          {'type': 'message', 'from': 'Fox', 'text': 'hi', 'ts': 200},
        ],
      };
      final rm = RoomMessages.fromJson(json);
      expect(rm.status, 'ended');
      expect(rm.messages.length, 1);
      expect(rm.messages[0].text, 'hi');
    });

    test('fromJson handles empty messages', () {
      final rm = RoomMessages.fromJson({'status': 'active'});
      expect(rm.messages, isEmpty);
    });
  });

  group('UserProfile', () {
    test('fromJson parses all fields', () {
      final json = {
        'username': 'Fox',
        'avatar_id': 3,
        'speak_count': 10,
        'listen_count': 5,
        'appreciation_count': 2,
        'member_since': '2024-01-01',
        'email_verified': true,
        'email': 'fox@test.com',
      };
      final p = UserProfile.fromJson(json);
      expect(p.username, 'Fox');
      expect(p.avatarId, 3);
      expect(p.speakCount, 10);
      expect(p.listenCount, 5);
      expect(p.appreciationCount, 2);
      expect(p.emailVerified, isTrue);
      expect(p.email, 'fox@test.com');
    });

    test('fromJson handles defaults', () {
      final p = UserProfile.fromJson({'username': 'A', 'avatar_id': 0});
      expect(p.speakCount, 0);
      expect(p.listenCount, 0);
      expect(p.email, '');
    });
  });

  group('CurrentSpeakerRequest', () {
    test('fromJson parses all fields', () {
      final json = {
        'request_id': 'req-1',
        'status': 'posted',
        'room_id': 'r1',
        'posted_at': '123',
      };
      final r = CurrentSpeakerRequest.fromJson(json);
      expect(r.requestId, 'req-1');
      expect(r.status, 'posted');
      expect(r.roomId, 'r1');
    });

    test('fromJson handles no room_id', () {
      final json = {'request_id': 'req-1', 'status': 'posted'};
      final r = CurrentSpeakerRequest.fromJson(json);
      expect(r.roomId, isNull);
    });
  });

  group('Intent helpers', () {
    test('parseIntent speak', () {
      expect(parseIntent('speak'), UserIntent.speak);
    });

    test('parseIntent support', () {
      expect(parseIntent('support'), UserIntent.support);
    });

    test('parseIntent null for unknown', () {
      expect(parseIntent('unknown'), isNull);
      expect(parseIntent(null), isNull);
    });

    test('withIntent appends param', () {
      expect(withIntent('/home', UserIntent.speak), '/home?intent=speak');
    });

    test('withIntent appends with &', () {
      expect(withIntent('/home?foo=1', UserIntent.support), '/home?foo=1&intent=support');
    });

    test('withIntent null returns path', () {
      expect(withIntent('/home', null), '/home');
    });

    test('intentLabel for speak', () {
      expect(intentLabel(UserIntent.speak), 'vent freely');
    });

    test('intentLabel for support', () {
      expect(intentLabel(UserIntent.support), 'be a listener');
    });

    test('intentHeading for speak', () {
      expect(intentHeading(UserIntent.speak), contains('Let it out'));
    });

    test('intentHeading for support', () {
      expect(intentHeading(UserIntent.support), contains('Listener'));
    });

    test('intentBody for speak', () {
      expect(intentBody(UserIntent.speak), contains('matched'));
    });

    test('intentBody for support', () {
      expect(intentBody(UserIntent.support), contains('Hold space'));
    });
  });
}
