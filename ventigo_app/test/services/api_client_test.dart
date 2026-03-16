import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/services/api_client.dart';

/// A Dio interceptor that returns predefined responses for testing.
class MockInterceptor extends Interceptor {
  Response? Function(RequestOptions)? handler;

  MockInterceptor({this.handler});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler h) {
    if (handler != null) {
      final res = handler!(options);
      if (res != null) {
        return h.resolve(res);
      }
    }
    // Default: return empty 200
    h.resolve(Response(requestOptions: options, statusCode: 200, data: {}));
  }
}

/// Create a testable ApiClient with a mock interceptor.
ApiClient createTestClient(MockInterceptor mock) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(mock);
  return ApiClient(dio: dio);
}

void main() {
  // -- AuthException --
  group('AuthException', () {
    test('default message', () {
      const e = AuthException();
      expect(e.message, 'Not authenticated');
      expect(e.toString(), 'Not authenticated');
    });
    test('custom message', () {
      const e = AuthException('Session expired');
      expect(e.message, 'Session expired');
      expect(e.toString(), 'Session expired');
    });
  });

  // -- AuthResponse --
  group('AuthResponse', () {
    test('fromJson', () {
      final r = AuthResponse.fromJson(const {
        'token': 'abc',
        'session_id': 'xyz',
        'has_profile': true,
        'email_verified': false,
      });
      expect(r.token, 'abc');
      expect(r.sessionId, 'xyz');
      expect(r.hasProfile, true);
      expect(r.emailVerified, false);
    });

    test('constructor', () {
      const r = AuthResponse(token: 't', sessionId: 's', hasProfile: false, emailVerified: true);
      expect(r.token, 't');
      expect(r.emailVerified, true);
    });
  });

  // -- ProfileSetupResponse --
  group('ProfileSetupResponse', () {
    test('fromJson', () {
      final r = ProfileSetupResponse.fromJson(const {'username': 'u1', 'avatar_id': 5});
      expect(r.username, 'u1');
      expect(r.avatarId, 5);
    });
    test('fromJson numeric avatar_id', () {
      final r = ProfileSetupResponse.fromJson(const {'username': 'u2', 'avatar_id': 3.0});
      expect(r.avatarId, 3);
    });
  });

  // -- BoardResponse --
  group('BoardResponse', () {
    test('fromJson empty', () {
      final r = BoardResponse.fromJson(const {'requests': [], 'my_request_id': null});
      expect(r.requests, isEmpty);
      expect(r.myRequestId, isNull);
    });
    test('fromJson with data', () {
      final r = BoardResponse.fromJson(const {
        'requests': [
          {'request_id': 'r1', 'session_id': 's1', 'username': 'u1', 'avatar_id': '1', 'posted_at': '123'}
        ],
        'my_request_id': 'r2'
      });
      expect(r.requests.length, 1);
      expect(r.requests.first.requestId, 'r1');
      expect(r.myRequestId, 'r2');
    });
  });

  // -- SpeakResponse --
  group('SpeakResponse', () {
    test('fromJson', () {
      final r = SpeakResponse.fromJson(const {'request_id': 'req1', 'status': 'waiting'});
      expect(r.requestId, 'req1');
      expect(r.status, 'waiting');
    });
  });

  // -- AcceptResponse --
  group('AcceptResponse', () {
    test('fromJson', () {
      final r = AcceptResponse.fromJson(const {'room_id': 'room42'});
      expect(r.roomId, 'room42');
    });
  });

  // -- AdminStats --
  group('AdminStats', () {
    test('fromJson', () {
      final r = AdminStats.fromJson(const {
        'active_rooms': 10,
        'queued_users': 5,
        'board_requests': 3,
        'total_reports': 1,
      });
      expect(r.activeRooms, 10);
      expect(r.queuedUsers, 5);
      expect(r.boardRequests, 3);
      expect(r.totalReports, 1);
    });
    test('fromJson numeric doubles', () {
      final r = AdminStats.fromJson(const {
        'active_rooms': 2.0,
        'queued_users': 0.0,
        'board_requests': 1.0,
        'total_reports': 0.0,
      });
      expect(r.activeRooms, 2);
    });
  });

  // -- AdminReport --
  group('AdminReport', () {
    test('fromJson full', () {
      final r = AdminReport.fromJson(const {
        'report_id': 'rpt1',
        'reporter_session': 'rs1',
        'reported_session': 'rs2',
        'room_id': 'rm1',
        'reason': 'spam',
        'detail': 'sent links',
        'ts': '2024-01-01',
      });
      expect(r.reportId, 'rpt1');
      expect(r.reporterSession, 'rs1');
      expect(r.reportedSession, 'rs2');
      expect(r.roomId, 'rm1');
      expect(r.reason, 'spam');
      expect(r.detail, 'sent links');
      expect(r.ts, '2024-01-01');
    });
    test('fromJson defaults', () {
      final r = AdminReport.fromJson(const {});
      expect(r.reportId, '');
      expect(r.reporterSession, '');
      expect(r.reason, '');
    });
  });

  // -- AdminUser --
  group('AdminUser', () {
    test('fromJson full', () {
      final r = AdminUser.fromJson(const {
        'session_id': 'sid1',
        'username': 'user1',
        'avatar_id': 5,
        'speak_count': 10,
        'listen_count': 8,
        'created_at': '2024-06-01',
        'email_verified': 1,
        'suspended': 0,
        'is_admin': 1,
        'report_count': 2,
      });
      expect(r.sessionId, 'sid1');
      expect(r.username, 'user1');
      expect(r.avatarId, '5');
      expect(r.speakCount, '10');
      expect(r.listenCount, '8');
      expect(r.createdAt, '2024-06-01');
      expect(r.emailVerified, '1');
      expect(r.suspended, '0');
      expect(r.isAdmin, '1');
      expect(r.reportCount, 2);
    });
    test('fromJson defaults', () {
      final r = AdminUser.fromJson(const {});
      expect(r.sessionId, '');
      expect(r.username, '');
      expect(r.avatarId, '0');
      expect(r.speakCount, '0');
      expect(r.reportCount, 0);
    });
  });

  // -- AnalyticsOverview --
  group('AnalyticsOverview', () {
    test('fromJson', () {
      final r = AnalyticsOverview.fromJson(const {
        'dau': 100,
        'mau': 500,
        'sessions_today': 42,
        'registrations_today': 5,
        'reports_today': 1,
        'board_posts_today': 10,
        'avg_session_duration': 780,
      });
      expect(r.dau, 100);
      expect(r.mau, 500);
      expect(r.sessionsToday, 42);
      expect(r.registrationsToday, 5);
      expect(r.reportsToday, 1);
      expect(r.boardPostsToday, 10);
      expect(r.avgSessionDuration, 780);
    });
    test('fromJson defaults', () {
      final r = AnalyticsOverview.fromJson(const {});
      expect(r.dau, 0);
      expect(r.mau, 0);
      expect(r.sessionsToday, 0);
    });
  });

  // -- TimeseriesPoint --
  group('TimeseriesPoint', () {
    test('fromJson', () {
      final r = TimeseriesPoint.fromJson(const {'date': '2024-06-01', 'value': 42});
      expect(r.date, '2024-06-01');
      expect(r.value, 42);
    });
    test('fromJson defaults', () {
      final r = TimeseriesPoint.fromJson(const {});
      expect(r.date, '');
      expect(r.value, 0);
    });
  });

  // -- Tenant --
  group('Tenant', () {
    test('fromJson', () {
      final r = Tenant.fromJson(const {
        'tenant_id': 't1',
        'name': 'Acme',
        'domain': 'acme.com',
        'active': true,
        'created_at': 1700000000.0,
      });
      expect(r.tenantId, 't1');
      expect(r.name, 'Acme');
      expect(r.domain, 'acme.com');
      expect(r.active, true);
      expect(r.createdAt, 1700000000.0);
    });
    test('fromJson defaults', () {
      final r = Tenant.fromJson(const {});
      expect(r.tenantId, '');
      expect(r.name, '');
      expect(r.domain, '');
      expect(r.active, true);
      expect(r.createdAt, 0);
    });
  });

  // ===================================================================
  // API Endpoint Tests (with mock Dio)
  // ===================================================================

  group('register', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, '/auth/register');
        expect(opts.method, 'POST');
        return Response(requestOptions: opts, statusCode: 200, data: {
          'token': 'abc', 'session_id': 'xyz', 'has_profile': false, 'email_verified': false,
        });
      });
      final client = createTestClient(mock);
      final r = await client.register('a@b.com', 'pass');
      expect(r.token, 'abc');
      expect(r.hasProfile, false);
    });
  });

  group('login', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {
          'token': 't1', 'session_id': 's1', 'has_profile': true, 'email_verified': true,
        });
      });
      final client = createTestClient(mock);
      final r = await client.login('a@b.com', 'pass');
      expect(r.token, 't1');
      expect(r.emailVerified, true);
    });
  });

  group('sendVerification', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, '/auth/send-verification');
        expect(opts.headers['Authorization'], 'Bearer tok');
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.sendVerification('tok');
    });
  });

  group('verifyEmail', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, '/auth/verify-email');
        expect(opts.queryParameters['token'], 'vtoken');
        return Response(requestOptions: opts, statusCode: 200, data: {
          'token': 't', 'session_id': 's', 'has_profile': true, 'email_verified': true,
        });
      });
      final client = createTestClient(mock);
      final r = await client.verifyEmail('vtoken');
      expect(r.emailVerified, true);
    });
  });

  group('forgotPassword', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, '/auth/forgot-password');
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.forgotPassword('a@b.com');
    });
  });

  group('resetPassword', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, '/auth/reset-password');
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.resetPassword('tok', 'newpass');
    });
  });

  group('setProfile', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, '/auth/profile');
        expect(opts.method, 'POST');
        return Response(requestOptions: opts, statusCode: 200, data: {
          'username': 'u1', 'avatar_id': 3,
        });
      });
      final client = createTestClient(mock);
      final r = await client.setProfile('tok', dob: '2000-01-01', avatarId: 3);
      expect(r.username, 'u1');
      expect(r.avatarId, 3);
    });
  });

  group('getMe', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, '/auth/me');
        return Response(requestOptions: opts, statusCode: 200, data: {
          'session_id': 'sid', 'username': 'u1', 'avatar_id': 1,
          'speak_count': 5, 'listen_count': 3, 'email_verified': true, 'created_at': '2024-01-01',
        });
      });
      final client = createTestClient(mock);
      final r = await client.getMe('tok');
      expect(r.username, 'u1');
    });
  });

  group('updateProfile', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.method, 'PATCH');
        return Response(requestOptions: opts, statusCode: 200, data: {
          'username': 'u2', 'avatar_id': 5,
        });
      });
      final client = createTestClient(mock);
      final r = await client.updateProfile('tok', avatarId: 5);
      expect(r.avatarId, 5);
    });
  });

  group('getUserProfile', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, contains('/auth/user/'));
        return Response(requestOptions: opts, statusCode: 200, data: {
          'session_id': 'sid', 'username': 'other', 'avatar_id': 2,
          'speak_count': 1, 'listen_count': 1, 'email_verified': true, 'created_at': '2024-01-01',
        });
      });
      final client = createTestClient(mock);
      final r = await client.getUserProfile('tok', 'other');
      expect(r.username, 'other');
    });
  });

  group('getBoard', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, '/board/requests');
        return Response(requestOptions: opts, statusCode: 200, data: {
          'requests': [], 'my_request_id': null,
        });
      });
      final client = createTestClient(mock);
      final r = await client.getBoard('tok');
      expect(r.requests, isEmpty);
    });
  });

  group('postSpeak', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, '/board/speak');
        expect(opts.method, 'POST');
        return Response(requestOptions: opts, statusCode: 200, data: {
          'request_id': 'r1', 'status': 'waiting',
        });
      });
      final client = createTestClient(mock);
      final r = await client.postSpeak('tok', topic: 'stress');
      expect(r.requestId, 'r1');
    });
  });

  group('cancelSpeak', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.method, 'DELETE');
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.cancelSpeak('tok');
    });
  });

  group('getSpeakerRequest', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {
          'request_id': 'r1', 'status': 'waiting', 'posted_at': '123',
        });
      });
      final client = createTestClient(mock);
      final r = await client.getSpeakerRequest('tok', 'r1');
      expect(r.requestId, 'r1');
    });
  });

  group('acceptSpeaker', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'room_id': 'room1'});
      });
      final client = createTestClient(mock);
      final r = await client.acceptSpeaker('tok', 'r1');
      expect(r.roomId, 'room1');
    });
  });

  group('submitReport', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, '/report/');
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.submitReport('tok', 'spam', detail: 'bad links', roomId: 'rm1');
    });
  });

  group('blockUser', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.path, '/block');
        expect(opts.method, 'POST');
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.blockUser('tok', 'peer1', 'baduser', 1);
    });
  });

  group('unblockUser', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.method, 'DELETE');
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.unblockUser('tok', 'peer1');
    });
  });

  group('getBlockedUsers', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'blocked': []});
      });
      final client = createTestClient(mock);
      final r = await client.getBlockedUsers('tok');
      expect(r, isEmpty);
    });
  });

  group('getActiveRoom', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'room_id': 'rm1'});
      });
      final client = createTestClient(mock);
      final r = await client.getActiveRoom('tok');
      expect(r, 'rm1');
    });
    test('no room', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'room_id': null});
      });
      final client = createTestClient(mock);
      final r = await client.getActiveRoom('tok');
      expect(r, isNull);
    });
  });

  group('getChatRooms', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'rooms': []});
      });
      final client = createTestClient(mock);
      final r = await client.getChatRooms('tok');
      expect(r, isEmpty);
    });
  });

  group('getRoomMessages', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {
          'room_id': 'rm1', 'status': 'active', 'peer_username': 'peer',
          'peer_avatar_id': 2, 'peer_session_id': 'ps', 'messages': [],
          'duration': '900', 'started_at': '', 'ended_at': '', 'has_appreciated': false,
        });
      });
      final client = createTestClient(mock);
      final r = await client.getRoomMessages('tok', 'rm1');
      expect(r.peerUsername, 'peer');
      expect(r.status, 'active');
    });
  });

  group('postFeedback', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.method, 'POST');
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.postFeedback('tok', 'rm1', 'happy', text: 'great session');
    });
  });

  group('postAppreciation', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'status': 'ok'});
      });
      final client = createTestClient(mock);
      final r = await client.postAppreciation('tok', 'rm1', 'thank you');
      expect(r['status'], 'ok');
    });
  });

  group('getAppreciations', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'appreciations': []});
      });
      final client = createTestClient(mock);
      final r = await client.getAppreciations('tok', 'user1');
      expect(r, isEmpty);
    });
  });

  group('sendConnectionRequest', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'status': 'sent'});
      });
      final client = createTestClient(mock);
      final r = await client.sendConnectionRequest('tok', 'peer1');
      expect(r['status'], 'sent');
    });
  });

  group('acceptConnectionRequest', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.acceptConnectionRequest('tok', 'peer1');
    });
  });

  group('removeConnection', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.removeConnection('tok', 'peer1');
    });
  });

  group('getConnections', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'accepted': [], 'pending': []});
      });
      final client = createTestClient(mock);
      final r = await client.getConnections('tok');
      expect(r.containsKey('accepted'), true);
    });
  });

  group('directChat', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'room_id': 'dm1'});
      });
      final client = createTestClient(mock);
      final r = await client.directChat('tok', 'peer1');
      expect(r, 'dm1');
    });
  });

  group('getPosts', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {
          'posts': [{'id': 'p1', 'text': 'hello'}],
        });
      });
      final client = createTestClient(mock);
      final r = await client.getPosts();
      expect(r.length, 1);
      expect(r.first['text'], 'hello');
    });
  });

  group('createPost', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {
          'post': {'id': 'p1', 'text': 'hello'},
        });
      });
      final client = createTestClient(mock);
      final r = await client.createPost('tok', 'hello');
      expect(r['text'], 'hello');
    });
  });

  group('deletePost', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.method, 'DELETE');
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.deletePost('tok', 'p1');
    });
  });

  group('exportData', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'data': 'exported'});
      });
      final client = createTestClient(mock);
      final r = await client.exportData('tok');
      expect(r['data'], 'exported');
    });
  });

  group('deleteAccount', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        expect(opts.method, 'DELETE');
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.deleteAccount('tok');
    });
  });

  group('adminStats', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {
          'active_rooms': 1, 'queued_users': 2, 'board_requests': 3, 'total_reports': 4,
        });
      });
      final client = createTestClient(mock);
      final r = await client.adminStats('tok');
      expect(r.activeRooms, 1);
    });
  });

  group('adminListReports', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'reports': []});
      });
      final client = createTestClient(mock);
      final r = await client.adminListReports('tok');
      expect(r, isEmpty);
    });
  });

  group('adminGetUser', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {
          'session_id': 's1', 'username': 'u1', 'avatar_id': 1, 'speak_count': 10,
          'listen_count': 5, 'created_at': '2024', 'email_verified': 1, 'suspended': 0,
          'is_admin': 0, 'report_count': 0,
        });
      });
      final client = createTestClient(mock);
      final r = await client.adminGetUser('tok', 's1');
      expect(r.username, 'u1');
    });
  });

  group('adminSuspendUser', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.adminSuspendUser('tok', 's1');
    });
  });

  group('adminUnsuspendUser', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.adminUnsuspendUser('tok', 's1');
    });
  });

  group('adminGrantModerator', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.adminGrantModerator('tok', 's1');
    });
  });

  group('adminRevokeModerator', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {});
      });
      final client = createTestClient(mock);
      await client.adminRevokeModerator('tok', 's1');
    });
  });

  group('adminAnalyticsOverview', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {
          'dau': 1, 'mau': 2, 'sessions_today': 3, 'registrations_today': 4,
          'reports_today': 5, 'board_posts_today': 6, 'avg_session_duration': 7,
        });
      });
      final client = createTestClient(mock);
      final r = await client.adminAnalyticsOverview('tok');
      expect(r.dau, 1);
    });
  });

  group('adminAnalyticsTimeseries', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {
          'data': [{'date': '2024-01-01', 'value': 42}],
        });
      });
      final client = createTestClient(mock);
      final r = await client.adminAnalyticsTimeseries('tok', 'dau', '2024-01-01', '2024-01-31');
      expect(r.length, 1);
      expect(r.first.value, 42);
    });
  });

  group('adminListTenants', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {'tenants': []});
      });
      final client = createTestClient(mock);
      final r = await client.adminListTenants('adminkey');
      expect(r, isEmpty);
    });
  });

  group('adminCreateTenant', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {
          'tenant_id': 't1', 'name': 'Acme', 'domain': '', 'active': true, 'created_at': 1.0,
        });
      });
      final client = createTestClient(mock);
      final r = await client.adminCreateTenant('adminkey', tenantId: 't1', name: 'Acme');
      expect(r.tenantId, 't1');
    });
  });

  group('adminUpdateTenant', () {
    test('success', () async {
      final mock = MockInterceptor(handler: (opts) {
        return Response(requestOptions: opts, statusCode: 200, data: {
          'tenant_id': 't1', 'name': 'Acme2', 'domain': '', 'active': false, 'created_at': 1.0,
        });
      });
      final client = createTestClient(mock);
      final r = await client.adminUpdateTenant('adminkey', 't1', active: false, name: 'Acme2', domain: 'x.com');
      expect(r.name, 'Acme2');
      expect(r.active, false);
    });
  });

  // -- _rethrow error handling --
  group('_rethrow error handling', () {
    test('timeout throws user-friendly message', () async {
      final mock = MockInterceptor(handler: (opts) {
        throw DioException(
          requestOptions: opts,
          type: DioExceptionType.connectionTimeout,
        );
      });
      final client = createTestClient(mock);
      expect(
        () => client.register('a@b.com', 'p'),
        throwsA(predicate((e) => e.toString().contains('took too long'))),
      );
    });

    test('401 throws AuthException', () async {
      final mock = MockInterceptor(handler: (opts) {
        throw DioException(
          requestOptions: opts,
          error: AuthException('Token expired'),
        );
      });
      final client = createTestClient(mock);
      expect(
        () => client.login('a@b.com', 'p'),
        throwsA(isA<AuthException>()),
      );
    });

    test('server error with detail', () async {
      final mock = MockInterceptor(handler: (opts) {
        throw DioException(
          requestOptions: opts,
          response: Response(requestOptions: opts, statusCode: 500, data: {'detail': 'Internal error'}),
          type: DioExceptionType.badResponse,
        );
      });
      final client = createTestClient(mock);
      expect(
        () => client.forgotPassword('a@b.com'),
        throwsA(predicate((e) => e.toString().contains('Internal error'))),
      );
    });

    test('server error without detail', () async {
      final mock = MockInterceptor(handler: (opts) {
        throw DioException(
          requestOptions: opts,
          response: Response(requestOptions: opts, statusCode: 500, data: 'bad'),
          type: DioExceptionType.badResponse,
        );
      });
      final client = createTestClient(mock);
      expect(
        () => client.forgotPassword('a@b.com'),
        throwsA(predicate((e) => e.toString().contains('Cannot reach the server'))),
      );
    });

    test('receiveTimeout throws user-friendly message', () async {
      final mock = MockInterceptor(handler: (opts) {
        throw DioException(
          requestOptions: opts,
          type: DioExceptionType.receiveTimeout,
        );
      });
      final client = createTestClient(mock);
      expect(
        () => client.register('a@b.com', 'p'),
        throwsA(predicate((e) => e.toString().contains('took too long'))),
      );
    });

    test('non-DioException rethrows as-is', () async {
      // Return invalid data so fromJson throws a TypeError,
      // which reaches _rethrow as a non-DioException.
      final mock = MockInterceptor(handler: (opts) => Response(
        requestOptions: opts,
        statusCode: 200,
        data: 42,
      ));
      final client = createTestClient(mock);
      expect(
        () => client.register('a@b.com', 'p'),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
