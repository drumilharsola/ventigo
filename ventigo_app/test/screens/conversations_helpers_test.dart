import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/models/room_summary.dart';
import 'package:ventigo_app/screens/conversations_screen.dart';

RoomSummary _makeRoom({
  required String roomId,
  String status = 'ended',
  String peerSessionId = 'ps1',
  String peerUsername = 'alice',
  int peerAvatarId = 1,
  String matchedAt = '',
  String startedAt = '',
  String role = 'speaker',
}) {
  return RoomSummary.fromJson({
    'room_id': roomId,
    'status': status,
    'peer_session_id': peerSessionId,
    'peer_username': peerUsername,
    'peer_avatar_id': peerAvatarId,
    'matched_at': matchedAt,
    'started_at': startedAt,
    'role': role,
  });
}

void main() {
  group('convRoomTs', () {
    test('uses startedAt when available', () {
      final r = _makeRoom(roomId: 'r1', startedAt: '1700000100', matchedAt: '1700000000');
      expect(convRoomTs(r), 1700000100);
    });

    test('falls back to matchedAt', () {
      final r = _makeRoom(roomId: 'r1', startedAt: '', matchedAt: '1700000050');
      expect(convRoomTs(r), 1700000050);
    });

    test('returns 0 for empty strings', () {
      final r = _makeRoom(roomId: 'r1', startedAt: '', matchedAt: '');
      expect(convRoomTs(r), 0);
    });

    test('invalid string returns 0', () {
      final r = _makeRoom(roomId: 'r1', startedAt: 'abc', matchedAt: 'xyz');
      expect(convRoomTs(r), 0);
    });
  });

  group('PeerGroup', () {
    test('hasActive true when active room', () {
      final g = PeerGroup(
        peerSessionId: 'ps1',
        peerUsername: 'alice',
        peerAvatarId: 1,
        rooms: [_makeRoom(roomId: 'r1', status: 'active')],
      );
      expect(g.hasActive, true);
    });

    test('hasActive false when all ended', () {
      final g = PeerGroup(
        peerSessionId: 'ps1',
        peerUsername: 'alice',
        peerAvatarId: 1,
        rooms: [
          _makeRoom(roomId: 'r1', status: 'ended'),
          _makeRoom(roomId: 'r2', status: 'ended'),
        ],
      );
      expect(g.hasActive, false);
    });

    test('latest returns first room', () {
      final r1 = _makeRoom(roomId: 'r1');
      final r2 = _makeRoom(roomId: 'r2');
      final g = PeerGroup(
        peerSessionId: 'ps1',
        peerUsername: 'alice',
        peerAvatarId: 1,
        rooms: [r1, r2],
      );
      expect(g.latest.roomId, 'r1');
    });
  });

  group('groupByPeer', () {
    test('empty list returns empty', () {
      expect(groupByPeer([]), isEmpty);
    });

    test('single room creates single group', () {
      final rooms = [
        _makeRoom(roomId: 'r1', peerSessionId: 'ps1', peerUsername: 'alice'),
      ];
      final groups = groupByPeer(rooms);
      expect(groups.length, 1);
      expect(groups.first.peerUsername, 'alice');
      expect(groups.first.rooms.length, 1);
    });

    test('groups by peer session id', () {
      final rooms = [
        _makeRoom(roomId: 'r1', peerSessionId: 'ps1', peerUsername: 'alice', startedAt: '1700000000'),
        _makeRoom(roomId: 'r2', peerSessionId: 'ps1', peerUsername: 'alice', startedAt: '1700000100'),
        _makeRoom(roomId: 'r3', peerSessionId: 'ps2', peerUsername: 'bob', startedAt: '1700000050'),
      ];
      final groups = groupByPeer(rooms);
      expect(groups.length, 2);
    });

    test('falls back to peerUsername when peerSessionId empty', () {
      final rooms = [
        _makeRoom(roomId: 'r1', peerSessionId: '', peerUsername: 'alice', startedAt: '1700000000'),
        _makeRoom(roomId: 'r2', peerSessionId: '', peerUsername: 'alice', startedAt: '1700000100'),
      ];
      final groups = groupByPeer(rooms);
      expect(groups.length, 1);
      expect(groups.first.rooms.length, 2);
    });

    test('rooms within group sorted by ts descending', () {
      final rooms = [
        _makeRoom(roomId: 'r1', peerSessionId: 'ps1', startedAt: '1700000000'),
        _makeRoom(roomId: 'r2', peerSessionId: 'ps1', startedAt: '1700000200'),
      ];
      final groups = groupByPeer(rooms);
      // latest should be r2 (newer)
      expect(groups.first.latest.roomId, 'r2');
    });

    test('active groups sorted before ended groups', () {
      final rooms = [
        _makeRoom(roomId: 'r1', peerSessionId: 'ps1', peerUsername: 'alice',
            status: 'ended', startedAt: '1700000200'),
        _makeRoom(roomId: 'r2', peerSessionId: 'ps2', peerUsername: 'bob',
            status: 'active', startedAt: '1700000000'),
      ];
      final groups = groupByPeer(rooms);
      // Bob (active) should come first despite older timestamp
      expect(groups.first.peerUsername, 'bob');
      expect(groups.last.peerUsername, 'alice');
    });

    test('within same status, sorted by ts descending', () {
      final rooms = [
        _makeRoom(roomId: 'r1', peerSessionId: 'ps1', peerUsername: 'alice',
            status: 'ended', startedAt: '1700000000'),
        _makeRoom(roomId: 'r2', peerSessionId: 'ps2', peerUsername: 'bob',
            status: 'ended', startedAt: '1700000200'),
      ];
      final groups = groupByPeer(rooms);
      expect(groups.first.peerUsername, 'bob');
    });
  });
}
