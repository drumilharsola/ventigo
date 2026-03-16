import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ventigo_app/services/auth_storage.dart';
import 'package:ventigo_app/services/api_client.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/state/board_provider.dart';
import 'package:ventigo_app/state/pending_wait_provider.dart';
import 'package:ventigo_app/models/user_profile.dart';
import 'package:ventigo_app/models/room_summary.dart';
import 'package:ventigo_app/models/room_messages.dart';
import 'package:ventigo_app/models/blocked_user.dart';
import 'package:ventigo_app/models/appreciation.dart';
import 'package:ventigo_app/models/current_speaker_request.dart';

/// In-memory fake for [AuthStorage] — no platform channels needed.
class FakeAuthStorage extends AuthStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> readToken() async => _data['token'];
  @override
  Future<String?> readSessionId() async => _data['session_id'];
  @override
  Future<String?> readUsername() async => _data['username'];
  @override
  Future<int?> readAvatarId() async {
    final r = _data['avatar_id'];
    return r != null ? int.tryParse(r) : null;
  }
  @override
  Future<bool?> readEmailVerified() async {
    final r = _data['email_verified'];
    return r != null ? r == 'true' : null;
  }
  @override
  Future<void> saveAuth(String token, String sessionId) async {
    _data['token'] = token;
    _data['session_id'] = sessionId;
  }
  @override
  Future<void> saveProfile(String username, int avatarId) async {
    _data['username'] = username;
    _data['avatar_id'] = avatarId.toString();
  }
  @override
  Future<void> saveAvatarId(int id) async {
    _data['avatar_id'] = id.toString();
  }
  @override
  Future<void> saveEmailVerified(bool verified) async {
    _data['email_verified'] = verified.toString();
  }
  @override
  Future<void> clear() async => _data.clear();
}

/// AuthNotifier subclass that allows setting test state directly.
class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier({AuthState? initial}) : super(FakeAuthStorage()) {
    if (initial != null) state = initial;
  }
}

/// Fake ApiClient that returns dummy data without network calls.
class FakeApiClient extends ApiClient {
  @override
  Future<AuthResponse> register(String email, String password) async =>
      const AuthResponse(token: 'tok', sessionId: 'sid', hasProfile: false, emailVerified: false);

  @override
  Future<AuthResponse> login(String email, String password) async =>
      const AuthResponse(token: 'tok', sessionId: 'sid', hasProfile: true, emailVerified: true);

  @override
  Future<void> sendVerification(String token) async {}

  @override
  Future<AuthResponse> verifyEmail(String verifyToken) async =>
      const AuthResponse(token: 'tok', sessionId: 'sid', hasProfile: true, emailVerified: true);

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<void> resetPassword(String token, String newPassword) async {}

  @override
  Future<ProfileSetupResponse> setProfile(String token, {required String dob, required int avatarId}) async =>
      const ProfileSetupResponse(username: 'testuser', avatarId: 1);

  @override
  Future<UserProfile> getMe(String token) async => UserProfile.fromJson(const {
        'session_id': 'sid',
        'username': 'testuser',
        'avatar_id': 1,
        'speak_count': 5,
        'listen_count': 3,
        'email_verified': true,
        'created_at': '2024-01-01',
      });

  @override
  Future<ProfileSetupResponse> updateProfile(String token, {int? avatarId, bool? rerollUsername}) async =>
      const ProfileSetupResponse(username: 'testuser', avatarId: 1);

  @override
  Future<UserProfile> getUserProfile(String token, String username) async => UserProfile.fromJson(const {
        'session_id': 'sid',
        'username': 'testuser',
        'avatar_id': 1,
        'speak_count': 5,
        'listen_count': 3,
        'email_verified': true,
        'created_at': '2024-01-01',
      });

  @override
  Future<BoardResponse> getBoard(String token) async =>
      const BoardResponse(requests: [], myRequestId: null);

  @override
  Future<SpeakResponse> postSpeak(String token, {String topic = ''}) async =>
      const SpeakResponse(requestId: 'req1', status: 'waiting');

  @override
  Future<void> cancelSpeak(String token) async {}

  @override
  Future<CurrentSpeakerRequest> getSpeakerRequest(String token, String requestId) async =>
      CurrentSpeakerRequest.fromJson(const {'request_id': 'req1', 'status': 'waiting', 'posted_at': '1700000000'});

  @override
  Future<AcceptResponse> acceptSpeaker(String token, String requestId) async =>
      const AcceptResponse(roomId: 'room1');

  @override
  Future<void> submitReport(String token, String reason, {String? detail, String? roomId}) async {}

  @override
  Future<void> blockUser(String token, String peerSessionId, String username, int avatarId) async {}

  @override
  Future<void> unblockUser(String token, String peerSessionId) async {}

  @override
  Future<List<BlockedUser>> getBlockedUsers(String token) async => [];

  @override
  Future<String?> getActiveRoom(String token) async => null;

  @override
  Future<List<RoomSummary>> getChatRooms(String token) async => [];

  @override
  Future<RoomMessages> getRoomMessages(String token, String roomId) async =>
      RoomMessages.fromJson(const {
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

  @override
  Future<void> postFeedback(String token, String roomId, String mood, {String text = ''}) async {}

  @override
  Future<Map<String, dynamic>> postAppreciation(String token, String roomId, String message) async =>
      {'status': 'ok'};

  @override
  Future<List<Appreciation>> getAppreciations(String token, String username, {int limit = 20, int offset = 0}) async => [];

  @override
  Future<Map<String, dynamic>> sendConnectionRequest(String token, String peerSessionId) async =>
      {'status': 'sent'};

  @override
  Future<void> acceptConnectionRequest(String token, String peerSessionId) async {}

  @override
  Future<void> removeConnection(String token, String peerSessionId) async {}

  @override
  Future<Map<String, dynamic>> getConnections(String token) async =>
      {'accepted': [], 'pending_received': []};

  @override
  Future<String> directChat(String token, String peerSessionId) async => 'room1';

  @override
  Future<List<Map<String, dynamic>>> getPosts() async => [];

  @override
  Future<Map<String, dynamic>> createPost(String token, String text) async =>
      {'id': 'post1', 'text': text};

  @override
  Future<void> deletePost(String token, String postId) async {}

  @override
  Future<Map<String, dynamic>> exportData(String token) async => {'data': {}};

  @override
  Future<void> deleteAccount(String token) async {}
}

/// Inert BoardNotifier — no WebSocket connection or timers.
class InertBoardNotifier extends BoardNotifier {
  InertBoardNotifier(super.ref);
  @override
  void connect() {}
  @override
  Future<void> syncBoard() async {}
  @override
  void close() {}
}

/// Inert PendingWaitNotifier — no polling or WebSocket.
class InertPendingWaitNotifier extends PendingWaitNotifier {
  InertPendingWaitNotifier(super.ref);
  @override
  void startWaiting(String requestId, {int remaining = 600}) {
    state = PendingWaitState(requestId: requestId, remaining: remaining);
  }
  @override
  void cancel() {
    state = const PendingWaitState();
  }
}

/// Standard logged-in auth state for testing.
const kTestAuthState = AuthState(
  token: 'test-token',
  sessionId: 'test-session',
  username: 'testuser',
  avatarId: 1,
  emailVerified: true,
  hasHydrated: true,
);

/// Common provider overrides for widget tests.
List<Override> testOverrides({AuthState? authState}) => [
      authStorageProvider.overrideWithValue(FakeAuthStorage()),
      authProvider.overrideWith((ref) => TestAuthNotifier(initial: authState ?? kTestAuthState)),
      apiClientProvider.overrideWithValue(FakeApiClient()),
      boardProvider.overrideWith((ref) => InertBoardNotifier(ref)),
      pendingWaitProvider.overrideWith((ref) => InertPendingWaitNotifier(ref)),
    ];

/// Wrap a widget in MaterialApp + ProviderScope for testing.
Widget testApp(Widget child, {List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? testOverrides(),
    child: MaterialApp(home: child),
  );
}
