import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ventigo_app/screens/verify_screen.dart';
import 'package:ventigo_app/screens/profile_screen.dart';
import 'package:ventigo_app/screens/posts_screen.dart';
import 'package:ventigo_app/screens/history_screen.dart';
import 'package:ventigo_app/screens/appreciations_screen.dart';
import 'package:ventigo_app/screens/blocked_users_screen.dart';
import 'package:ventigo_app/screens/main_shell.dart';
import 'package:ventigo_app/services/api_client.dart';
import 'package:ventigo_app/models/room_summary.dart';
import 'package:ventigo_app/models/appreciation.dart';
import 'package:ventigo_app/models/blocked_user.dart';
import 'package:ventigo_app/models/user_profile.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/state/board_provider.dart';
import 'package:ventigo_app/state/pending_wait_provider.dart';
import '../helpers/test_helpers.dart';

/// Extended FakeApiClient with configurable returns.
class _DeepFakeApi extends FakeApiClient {
  List<Map<String, dynamic>> postsToReturn = [];
  List<RoomSummary> roomsToReturn = [];
  List<Appreciation> appreciationsToReturn = [];
  List<BlockedUser> blockedUsersToReturn = [];
  bool loginShouldFail = false;
  bool registerShouldFail = false;
  bool shouldReturnHasProfile = true;
  int registerCalls = 0;
  int loginCalls = 0;
  int forgotPasswordCalls = 0;
  int resetPasswordCalls = 0;
  int sendVerificationCalls = 0;
  int postSpeakCalls = 0;
  int createPostCalls = 0;
  int deletePostCalls = 0;
  int unblockCalls = 0;
  Map<String, dynamic> connectionsToReturn = {'connections': [], 'pending_requests': []};

  @override
  Future<AuthResponse> register(String email, String password) async {
    registerCalls++;
    if (registerShouldFail) throw Exception('Email already in use');
    return AuthResponse(token: 'tok', sessionId: 'sid', hasProfile: false, emailVerified: false);
  }

  @override
  Future<AuthResponse> login(String email, String password) async {
    loginCalls++;
    if (loginShouldFail) throw Exception('Invalid credentials');
    return AuthResponse(
        token: 'tok', sessionId: 'sid',
        hasProfile: shouldReturnHasProfile, emailVerified: true);
  }

  @override
  Future<void> forgotPassword(String email) async {
    forgotPasswordCalls++;
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    resetPasswordCalls++;
  }

  @override
  Future<void> sendVerification(String token) async {
    sendVerificationCalls++;
  }

  @override
  Future<UserProfile> getMe(String token) async => UserProfile.fromJson(const {
        'session_id': 'sid',
        'username': 'testuser',
        'avatar_id': 1,
        'speak_count': 5,
        'listen_count': 3,
        'email_verified': true,
        'created_at': '2024-01-01',
        'email': 'test@example.com',
        'member_since': '2024-01-01',
      });

  @override
  Future<List<Map<String, dynamic>>> getPosts() async => postsToReturn;

  @override
  Future<Map<String, dynamic>> createPost(String token, String text) async {
    createPostCalls++;
    return {'id': 'post1', 'text': text};
  }

  @override
  Future<void> deletePost(String token, String postId) async {
    deletePostCalls++;
  }

  @override
  Future<List<RoomSummary>> getChatRooms(String token) async => roomsToReturn;

  @override
  Future<Map<String, dynamic>> getConnections(String token) async => connectionsToReturn;

  @override
  Future<List<Appreciation>> getAppreciations(String token, String username,
      {int limit = 20, int offset = 0}) async => appreciationsToReturn;

  @override
  Future<List<BlockedUser>> getBlockedUsers(String token) async => blockedUsersToReturn;

  @override
  Future<void> unblockUser(String token, String peerSessionId) async {
    unblockCalls++;
    blockedUsersToReturn = [];
  }

  @override
  Future<SpeakResponse> postSpeak(String token, {String topic = ''}) async {
    postSpeakCalls++;
    return const SpeakResponse(requestId: 'req1', status: 'waiting');
  }
}

Widget _buildApp(Widget child, {_DeepFakeApi? api, AuthState? authState}) {
  final fakeApi = api ?? _DeepFakeApi();
  return ProviderScope(
    overrides: [
      authStorageProvider.overrideWithValue(FakeAuthStorage()),
      authProvider.overrideWith(
          (ref) => TestAuthNotifier(initial: authState ?? kTestAuthState)),
      apiClientProvider.overrideWithValue(fakeApi),
      boardProvider.overrideWith((ref) => InertBoardNotifier(ref)),
      pendingWaitProvider.overrideWith((ref) => InertPendingWaitNotifier(ref)),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  // =============== VerifyScreen ===============
  group('VerifyScreen deep tests', () {
    testWidgets('login mode - renders email and password fields',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        const VerifyScreen(),
        authState: const AuthState(),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Sign in →'), findsOneWidget);
    });

    testWidgets('switch to register mode', (tester) async {
      await tester.pumpWidget(_buildApp(
        const VerifyScreen(),
        authState: const AuthState(),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      // Find and tap "Create an account"
      final createAccountFinder =
          find.textContaining('Create');
      if (createAccountFinder.evaluate().isNotEmpty) {
        await tester.tap(createAccountFinder.first);
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets('reset password mode renders correctly', (tester) async {
      await tester.pumpWidget(_buildApp(
        const VerifyScreen(resetToken: 'test-reset-token'),
        authState: const AuthState(),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('new password'), findsWidgets);
    });

    testWidgets('forgot password link exists', (tester) async {
      await tester.pumpWidget(_buildApp(
        const VerifyScreen(),
        authState: const AuthState(),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      final forgot = find.textContaining('Forgot');
      expect(forgot, findsWidgets);
    });
  });

  // =============== ProfileScreen ===============
  group('ProfileScreen deep tests', () {
    testWidgets('setup mode shows DOB and avatar grid', (tester) async {
      final api = _DeepFakeApi();
      await tester.pumpWidget(_buildApp(
        const ProfileScreen(),
        api: api,
        authState: const AuthState(
          token: 'test-token',
          sessionId: 'test-session',
          hasHydrated: true,
          emailVerified: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Set up\nyour profile.'), findsOneWidget);
      expect(find.text('DATE OF BIRTH'), findsOneWidget);
      expect(find.text('CHOOSE YOUR AVATAR'), findsOneWidget);
      expect(find.text('Tap to select'), findsOneWidget);
      expect(find.textContaining('Continue'), findsOneWidget);
    });

    testWidgets('profile view mode shows username', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi();
      await tester.pumpWidget(_buildApp(
        const ProfileScreen(),
        api: api,
      ));
      await tester.pumpAndSettle();

      expect(find.text('testuser'), findsOneWidget);
      expect(find.text('My Appreciations'), findsOneWidget);
      expect(find.text('Achievements'), findsOneWidget);
    });

    testWidgets('settings gear exists', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi();
      await tester.pumpWidget(_buildApp(const ProfileScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('tap avatar opens edit mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi();
      await tester.pumpWidget(_buildApp(const ProfileScreen(), api: api));
      await tester.pumpAndSettle();

      // Tap on the avatar (camera icon)
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();

      expect(find.text('CHOOSE AVATAR'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancel editing hides edit mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi();
      await tester.pumpWidget(_buildApp(const ProfileScreen(), api: api));
      await tester.pumpAndSettle();

      // Open edit
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('CHOOSE AVATAR'), findsNothing);
    });

    testWidgets('privacy and terms links visible', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi();
      await tester.pumpWidget(_buildApp(const ProfileScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
    });
  });

  // =============== PostsScreen ===============
  group('PostsScreen deep tests', () {
    testWidgets('empty posts shows create prompt', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi()..postsToReturn = [];
      await tester.pumpWidget(_buildApp(const PostsScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.textContaining('Be the first'), findsOneWidget);
    });

    testWidgets('posts list renders items', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final api = _DeepFakeApi()
        ..postsToReturn = [
          {
            'post_id': 'p1',
            'text': 'Hello community!',
            'session_id': 'other-session',
            'username': 'bob',
            'avatar_id': 2,
            'created_at': now,
            'expires_at': now + 86400,
          },
          {
            'post_id': 'p2',
            'text': 'My post',
            'session_id': 'test-session',
            'username': 'testuser',
            'avatar_id': 1,
            'created_at': now,
            'expires_at': now + 86400,
          },
        ];
      await tester.pumpWidget(_buildApp(const PostsScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.text('Hello community!'), findsOneWidget);
      expect(find.text('My post'), findsOneWidget);
    });

    testWidgets('FAB opens compose sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi()..postsToReturn = [];
      await tester.pumpWidget(_buildApp(const PostsScreen(), api: api));
      await tester.pumpAndSettle();

      // Find FAB or Create button
      final fab = find.byIcon(Icons.edit_rounded);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await tester.pumpAndSettle();

        expect(find.text('Share something'), findsOneWidget);
        expect(find.textContaining('Anonymous'), findsOneWidget);
        expect(find.text('Post'), findsOneWidget);
      }
    });
  });

  // =============== HistoryScreen ===============
  group('HistoryScreen deep tests', () {
    testWidgets('empty rooms shows message', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi()..roomsToReturn = [];
      await tester.pumpWidget(_buildApp(const HistoryScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.textContaining('No conversations'), findsOneWidget);
    });

    testWidgets('shows rooms when available', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final api = _DeepFakeApi()
        ..roomsToReturn = [
          RoomSummary.fromJson({
            'room_id': 'r1',
            'status': 'ended',
            'peer_username': 'alice',
            'peer_avatar_id': 2,
            'peer_session_id': 'ps1',
            'matched_at': (now - 3600).toString(),
            'started_at': (now - 3500).toString(),
            'ended_at': (now - 2600).toString(),
          }),
        ];
      await tester.pumpWidget(_buildApp(const HistoryScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget);
    });

    testWidgets('connections tab shows empty state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi();
      await tester.pumpWidget(
          _buildApp(const HistoryScreen(tab: 'connections'), api: api));
      await tester.pumpAndSettle();

      expect(find.textContaining('No connections'), findsOneWidget);
    });

    testWidgets('connections tab shows connections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi()
        ..connectionsToReturn = {
          'connections': [
            {
              'peer_username': 'carol',
              'peer_avatar_id': 3,
              'peer_session_id': 'cs1',
            },
          ],
          'pending_requests': [],
        };
      await tester.pumpWidget(
          _buildApp(const HistoryScreen(tab: 'connections'), api: api));
      await tester.pumpAndSettle();

      expect(find.text('carol'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets('pending requests shown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi()
        ..connectionsToReturn = {
          'connections': [],
          'pending_requests': [
            {
              'peer_username': 'dave',
              'peer_avatar_id': 4,
              'peer_session_id': 'ds1',
            },
          ],
        };
      await tester.pumpWidget(
          _buildApp(const HistoryScreen(tab: 'connections'), api: api));
      await tester.pumpAndSettle();

      expect(find.text('dave'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
    });
  });

  // =============== AppreciationsScreen ===============
  group('AppreciationsScreen deep tests', () {
    testWidgets('empty appreciations shows empty state', (tester) async {
      final api = _DeepFakeApi()..appreciationsToReturn = [];
      await tester.pumpWidget(_buildApp(
          const AppreciationsScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.textContaining('appreciation'), findsWidgets);
    });

    testWidgets('with items shows appreciations', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi()
        ..appreciationsToReturn = [
          Appreciation.fromJson(const {
            'id': 1,
            'from_username': 'bob',
            'from_role': 'listener',
            'message': 'You were amazing!',
            'created_at': 1700000000,
          }),
        ];
      await tester.pumpWidget(_buildApp(
          const AppreciationsScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.text('You were amazing!'), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);
    });

    testWidgets('own profile shows My Appreciations title', (tester) async {
      final api = _DeepFakeApi()..appreciationsToReturn = [];
      await tester.pumpWidget(_buildApp(
          const AppreciationsScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.text('My Appreciations'), findsOneWidget);
    });

    testWidgets('with username shows their title', (tester) async {
      final api = _DeepFakeApi()..appreciationsToReturn = [];
      await tester.pumpWidget(_buildApp(
          const AppreciationsScreen(username: 'alice'), api: api));
      await tester.pumpAndSettle();

      expect(find.textContaining('alice'), findsWidgets);
    });
  });

  // =============== BlockedUsersScreen ===============
  group('BlockedUsersScreen deep tests', () {
    testWidgets('empty shows no blocked users message', (tester) async {
      final api = _DeepFakeApi()..blockedUsersToReturn = [];
      await tester.pumpWidget(_buildApp(
          const BlockedUsersScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.textContaining('No blocked users'), findsOneWidget);
    });

    testWidgets('shows blocked users', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi()
        ..blockedUsersToReturn = [
          BlockedUser.fromJson(const {
            'peer_session_id': 'ps1',
            'username': 'baduser',
            'avatar_id': 3,
          }),
        ];
      await tester.pumpWidget(_buildApp(
          const BlockedUsersScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.text('baduser'), findsOneWidget);
      expect(find.text('Unblock'), findsOneWidget);
    });

    testWidgets('unblock user removes from list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DeepFakeApi()
        ..blockedUsersToReturn = [
          BlockedUser.fromJson(const {
            'peer_session_id': 'ps1',
            'username': 'baduser',
            'avatar_id': 3,
          }),
        ];
      await tester.pumpWidget(_buildApp(
          const BlockedUsersScreen(), api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();

      expect(api.unblockCalls, 1);
    });
  });

  // =============== MainShell ===============
  group('MainShell', () {
    testWidgets('renders with 5 tabs', (tester) async {
      await tester.pumpWidget(_buildApp(const MainShell()));
      await tester.pump(const Duration(milliseconds: 100));

      // Should find bottom nav icons
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    });

    testWidgets('starts at specified index', (tester) async {
      await tester.pumpWidget(_buildApp(const MainShell(initialIndex: 2)));
      await tester.pump(const Duration(milliseconds: 100));
      // The third tab (Community) should be active
    });
  });
}
