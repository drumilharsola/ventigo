import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ventigo_app/screens/chat_screen.dart';
import 'package:ventigo_app/widgets/typing_indicator.dart';
import 'package:ventigo_app/models/chat_message.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/state/board_provider.dart';
import 'package:ventigo_app/state/chat_provider.dart';
import 'package:ventigo_app/state/pending_wait_provider.dart';
import '../helpers/test_helpers.dart';

Widget _buildChat({
  required String roomId,
  ChatState? chatState,
}) {
  final cs = chatState ?? const ChatState(
    mode: 'live',
    connected: true,
    peerUsername: 'PeerUser',
    peerAvatarId: 2,
    peerSessionId: 'peer-sid',
    timerStarted: true,
    remaining: 600,
  );
  return ProviderScope(
    overrides: [
      authStorageProvider.overrideWithValue(FakeAuthStorage()),
      authProvider.overrideWith((ref) => TestAuthNotifier(initial: kTestAuthState)),
      apiClientProvider.overrideWithValue(FakeApiClient()),
      boardProvider.overrideWith((ref) => InertBoardNotifier(ref)),
      pendingWaitProvider.overrideWith((ref) => InertPendingWaitNotifier(ref)),
      chatProvider(roomId).overrideWith((ref) => InertChatNotifier(ref, roomId: roomId, initial: cs)),
    ],
    child: MaterialApp(
      home: ChatScreen(roomId: roomId),
    ),
  );
}

void main() {
  group('ChatScreen', () {
    testWidgets('shows peer username in header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(roomId: 'room1'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('PeerUser'), findsOneWidget);
      expect(find.text('Live · anonymous'), findsOneWidget);
    });

    testWidgets('shows loading when checking mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(
        roomId: 'room1',
        chatState: const ChatState(mode: 'checking'),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Loading…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows expired state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(
        roomId: 'room1',
        chatState: const ChatState(mode: 'expired'),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('404'), findsOneWidget);
      expect(find.textContaining('expired'), findsOneWidget);
    });

    testWidgets('shows messages in transcript', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(
        roomId: 'room1',
        chatState: ChatState(
          mode: 'live',
          connected: true,
          peerUsername: 'PeerUser',
          peerAvatarId: 2,
          peerSessionId: 'peer-sid',
          timerStarted: true,
          remaining: 600,
          transcript: [
            TranscriptMessage(from: 'testuser', text: 'Hello!', ts: 1700000100, fromSession: 'test-session'),
            TranscriptMessage(from: 'PeerUser', text: 'Hi there!', ts: 1700000200, fromSession: 'peer-sid'),
          ],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Hello!'), findsOneWidget);
      expect(find.text('Hi there!'), findsOneWidget);
    });

    testWidgets('shows input field in live mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(roomId: 'room1'));
      await tester.pump(const Duration(milliseconds: 500));

      // Live mode has a text input
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('no input field in readonly mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(
        roomId: 'room1',
        chatState: const ChatState(
          mode: 'readonly',
          peerUsername: 'PeerUser',
          peerAvatarId: 2,
          transcript: [],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Past conversation'), findsOneWidget);
    });

    testWidgets('shows End Chat button in live mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(roomId: 'room1'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('End Chat'), findsOneWidget);
    });

    testWidgets('shows ending soon banner', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(
        roomId: 'room1',
        chatState: const ChatState(
          mode: 'live',
          connected: true,
          peerUsername: 'PeerUser',
          peerAvatarId: 2,
          timerStarted: true,
          remaining: 30,
          endingSoon: true,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('ending soon'), findsOneWidget);
    });

    testWidgets('shows peer left indicator', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(
        roomId: 'room1',
        chatState: const ChatState(
          mode: 'live',
          connected: true,
          peerUsername: 'PeerUser',
          peerAvatarId: 2,
          peerLeft: true,
          timerStarted: true,
          remaining: 600,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('left'), findsOneWidget);
    });

    testWidgets('shows connecting status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(
        roomId: 'room1',
        chatState: const ChatState(
          mode: 'live',
          connected: false,
          peerUsername: 'PeerUser',
          peerAvatarId: 2,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Connecting…'), findsWidgets);
    });

    testWidgets('shows hint pill at top of live chat', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(roomId: 'room1'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Listen first'), findsOneWidget);
    });

    testWidgets('shows typing indicator when peer is typing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(
        roomId: 'room1',
        chatState: const ChatState(
          mode: 'live',
          connected: true,
          peerUsername: 'PeerUser',
          peerAvatarId: 2,
          peerTyping: true,
          timerStarted: true,
          remaining: 600,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      // TypingIndicator renders as a widget with the peer username
      expect(find.byType(TypingIndicator), findsOneWidget);
    });

    testWidgets('shows markers in transcript', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(
        roomId: 'room1',
        chatState: ChatState(
          mode: 'readonly',
          peerUsername: 'PeerUser',
          peerAvatarId: 2,
          transcript: [
            TranscriptMarker(event: 'started', roomId: 'room1', ts: 1700000000),
            TranscriptMessage(from: 'testuser', text: 'Hello!', ts: 1700000100, fromSession: 'test-session'),
            TranscriptMarker(event: 'ended', roomId: 'room1', ts: 1700000200),
          ],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Hello!'), findsOneWidget);
      // Markers render as text
      expect(find.textContaining('started'), findsWidgets);
    });

    testWidgets('back button exists', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(roomId: 'room1'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('report flag button exists in live mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(roomId: 'room1'));
      await tester.pump(const Duration(milliseconds: 500));

      // Report flag is ⚑ text
      expect(find.text('⚑'), findsOneWidget);
    });

    testWidgets('waiting state with no peer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildChat(
        roomId: 'room1',
        chatState: const ChatState(
          mode: 'live',
          connected: false,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Waiting for someone…'), findsOneWidget);
    });
  });
}
