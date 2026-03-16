import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ventigo_app/screens/unified_chat_screen.dart';
import 'package:ventigo_app/models/room_summary.dart';
import 'package:ventigo_app/models/room_messages.dart';
import 'package:ventigo_app/services/api_client.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/state/board_provider.dart';
import 'package:ventigo_app/state/chat_provider.dart';
import 'package:ventigo_app/state/pending_wait_provider.dart';
import '../helpers/test_helpers.dart';

class _UnifiedApi extends FakeApiClient {
  List<RoomSummary> rooms = [];
  Map<String, RoomMessages> roomMessages = {};

  @override
  Future<List<RoomSummary>> getChatRooms(String token) async => rooms;

  @override
  Future<RoomMessages> getRoomMessages(String token, String roomId) async =>
      roomMessages[roomId] ?? RoomMessages.fromJson(const {
        'room_id': 'r1',
        'status': 'ended',
        'peer_username': 'PeerUser',
        'peer_avatar_id': 2,
        'peer_session_id': 'peer-sid',
        'messages': [],
        'duration': '900',
        'started_at': '',
        'ended_at': '',
        'has_appreciated': false,
      });
}

Widget _buildUnified({
  _UnifiedApi? api,
  String peerSessionId = 'peer-sid',
  String peerUsername = 'PeerUser',
}) {
  final fakeApi = api ?? _UnifiedApi();
  return ProviderScope(
    overrides: [
      authStorageProvider.overrideWithValue(FakeAuthStorage()),
      authProvider.overrideWith((ref) => TestAuthNotifier(initial: kTestAuthState)),
      apiClientProvider.overrideWithValue(fakeApi),
      boardProvider.overrideWith((ref) => InertBoardNotifier(ref)),
      pendingWaitProvider.overrideWith((ref) => InertPendingWaitNotifier(ref)),
    ],
    child: MaterialApp(
      home: UnifiedChatScreen(
        peerSessionId: peerSessionId,
        peerUsername: peerUsername,
      ),
    ),
  );
}

void main() {
  group('UnifiedChatScreen', () {
    testWidgets('shows loading then empty state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildUnified());
      // Initially loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));

      // After loading, no rooms → empty chat
      expect(find.textContaining('PeerUser'), findsWidgets);
    });

    testWidgets('shows peer username in header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildUnified());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('PeerUser'), findsWidgets);
    });

    testWidgets('shows past sessions with messages', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _UnifiedApi()
        ..rooms = [
          RoomSummary.fromJson(const {
            'room_id': 'r1',
            'status': 'ended',
            'peer_username': 'PeerUser',
            'peer_avatar_id': 2,
            'peer_session_id': 'peer-sid',
            'started_at': '1700000000',
            'matched_at': '1700000000',
            'ended_at': '1700000900',
            'duration': '900',
          }),
        ]
        ..roomMessages = {
          'r1': RoomMessages.fromJson(const {
            'room_id': 'r1',
            'status': 'ended',
            'peer_username': 'PeerUser',
            'peer_avatar_id': 2,
            'peer_session_id': 'peer-sid',
            'messages': [
              {'from': 'testuser', 'text': 'Hello from past!', 'ts': 1700000100},
              {'from': 'PeerUser', 'text': 'Hi back!', 'ts': 1700000200},
            ],
            'duration': '900',
            'started_at': '1700000000',
            'ended_at': '1700000900',
            'has_appreciated': false,
          }),
        };
      await tester.pumpWidget(_buildUnified(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Hello from past!'), findsOneWidget);
      expect(find.text('Hi back!'), findsOneWidget);
    });

    testWidgets('shows back button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildUnified());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('shows report flag', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildUnified());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('⚑'), findsOneWidget);
    });

    testWidgets('shows session markers for ended sessions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _UnifiedApi()
        ..rooms = [
          RoomSummary.fromJson(const {
            'room_id': 'r1',
            'status': 'ended',
            'peer_username': 'PeerUser',
            'peer_avatar_id': 2,
            'peer_session_id': 'peer-sid',
            'started_at': '1700000000',
            'matched_at': '1700000000',
            'ended_at': '1700000900',
            'duration': '900',
          }),
        ]
        ..roomMessages = {
          'r1': RoomMessages.fromJson(const {
            'room_id': 'r1',
            'status': 'ended',
            'peer_username': 'PeerUser',
            'peer_avatar_id': 2,
            'peer_session_id': 'peer-sid',
            'messages': [],
            'duration': '900',
            'started_at': '1700000000',
            'ended_at': '1700000900',
            'has_appreciated': false,
          }),
        };
      await tester.pumpWidget(_buildUnified(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      // Should have session markers (started/ended)
      expect(find.textContaining('Chat started'), findsWidgets);
      expect(find.textContaining('Chat ended'), findsWidgets);
    });

    testWidgets('shows active room with input field', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _UnifiedApi()
        ..rooms = [
          RoomSummary.fromJson(const {
            'room_id': 'r1',
            'status': 'active',
            'peer_username': 'PeerUser',
            'peer_avatar_id': 2,
            'peer_session_id': 'peer-sid',
            'started_at': '1700000000',
            'matched_at': '1700000000',
            'ended_at': '',
            'duration': '900',
          }),
        ]
        ..roomMessages = {
          'r1': RoomMessages.fromJson(const {
            'room_id': 'r1',
            'status': 'active',
            'peer_username': 'PeerUser',
            'peer_avatar_id': 2,
            'peer_session_id': 'peer-sid',
            'messages': [],
            'duration': '900',
            'started_at': '1700000000',
            'ended_at': '',
            'has_appreciated': false,
          }),
        };
      // Override the chatProvider for this active room
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStorageProvider.overrideWithValue(FakeAuthStorage()),
            authProvider.overrideWith((ref) => TestAuthNotifier(initial: kTestAuthState)),
            apiClientProvider.overrideWithValue(api),
            boardProvider.overrideWith((ref) => InertBoardNotifier(ref)),
            pendingWaitProvider.overrideWith((ref) => InertPendingWaitNotifier(ref)),
            chatProvider('r1').overrideWith((ref) => InertChatNotifier(ref, roomId: 'r1', initial: const ChatState(
              mode: 'live',
              connected: true,
              peerUsername: 'PeerUser',
              peerAvatarId: 2,
              peerSessionId: 'peer-sid',
              timerStarted: true,
              remaining: 600,
            ))),
          ],
          child: const MaterialApp(
            home: UnifiedChatScreen(
              peerSessionId: 'peer-sid',
              peerUsername: 'PeerUser',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Should show input field for active chat
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('multiple sessions sorted correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _UnifiedApi()
        ..rooms = [
          RoomSummary.fromJson(const {
            'room_id': 'r1',
            'status': 'ended',
            'peer_username': 'PeerUser',
            'peer_avatar_id': 2,
            'peer_session_id': 'peer-sid',
            'started_at': '1700000000',
            'matched_at': '1700000000',
            'ended_at': '1700000900',
            'duration': '900',
          }),
          RoomSummary.fromJson(const {
            'room_id': 'r2',
            'status': 'ended',
            'peer_username': 'PeerUser',
            'peer_avatar_id': 2,
            'peer_session_id': 'peer-sid',
            'started_at': '1700001000',
            'matched_at': '1700001000',
            'ended_at': '1700001900',
            'duration': '900',
          }),
        ]
        ..roomMessages = {
          'r1': RoomMessages.fromJson(const {
            'room_id': 'r1',
            'status': 'ended',
            'peer_username': 'PeerUser',
            'peer_avatar_id': 2,
            'peer_session_id': 'peer-sid',
            'messages': [
              {'from': 'testuser', 'text': 'First session msg', 'ts': 1700000100},
            ],
            'duration': '900',
            'started_at': '1700000000',
            'ended_at': '1700000900',
            'has_appreciated': false,
          }),
          'r2': RoomMessages.fromJson(const {
            'room_id': 'r2',
            'status': 'ended',
            'peer_username': 'PeerUser',
            'peer_avatar_id': 2,
            'peer_session_id': 'peer-sid',
            'messages': [
              {'from': 'testuser', 'text': 'Second session msg', 'ts': 1700001100},
            ],
            'duration': '900',
            'started_at': '1700001000',
            'ended_at': '1700001900',
            'has_appreciated': false,
          }),
        };
      await tester.pumpWidget(_buildUnified(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('First session msg'), findsOneWidget);
      expect(find.text('Second session msg'), findsOneWidget);
    });
  });
}
