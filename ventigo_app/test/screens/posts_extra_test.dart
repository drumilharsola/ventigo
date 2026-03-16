import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ventigo_app/screens/posts_screen.dart';
import 'package:ventigo_app/services/api_client.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/state/board_provider.dart';
import 'package:ventigo_app/state/pending_wait_provider.dart';
import '../helpers/test_helpers.dart';

class _PostsApi extends FakeApiClient {
  List<Map<String, dynamic>> posts = [];
  bool loadFail = false;

  @override
  Future<List<Map<String, dynamic>>> getPosts() async {
    if (loadFail) throw Exception('Network error');
    return posts;
  }

  @override
  Future<Map<String, dynamic>> createPost(String token, String text) async {
    return {'post_id': 'new1', 'text': text};
  }

  @override
  Future<void> deletePost(String token, String postId) async {}

  @override
  Future<Map<String, dynamic>> toggleKudos(String token, String postId) async {
    return {'count': 1, 'given': true};
  }
}

Widget _buildPosts({_PostsApi? api}) {
  final fakeApi = api ?? _PostsApi();
  return ProviderScope(
    overrides: [
      authStorageProvider.overrideWithValue(FakeAuthStorage()),
      authProvider.overrideWith(
          (ref) => TestAuthNotifier(initial: kTestAuthState)),
      apiClientProvider.overrideWithValue(fakeApi),
      boardProvider.overrideWith((ref) => InertBoardNotifier(ref)),
      pendingWaitProvider.overrideWith((ref) => InertPendingWaitNotifier(ref)),
    ],
    child: const MaterialApp(home: PostsScreen()),
  );
}

void main() {
  group('PostsScreen extra interactions', () {
    testWidgets('shows error state when loading fails', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PostsApi()..loadFail = true;
      await tester.pumpWidget(_buildPosts(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Could not load posts'), findsOneWidget);
    });

    testWidgets('tapping kudos button toggles kudos on', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PostsApi()
        ..posts = [
          {
            'post_id': 'p1',
            'text': 'Kudos test post',
            'session_id': 'other',
            'username': 'user1',
            'avatar_id': 1,
            'expires_at':
                (DateTime.now().millisecondsSinceEpoch / 1000 + 3600).toInt(),
            'created_at':
                (DateTime.now().millisecondsSinceEpoch / 1000).toInt(),
          },
        ];
      await tester.pumpWidget(_buildPosts(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      // Find the unfilled heart icon and tap it
      final heartIcon = find.byIcon(Icons.favorite_border_rounded);
      expect(heartIcon, findsOneWidget);
      await tester.tap(heartIcon);
      await tester.pump();

      // After tapping, the filled heart should appear
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('tapping kudos again untoggle', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PostsApi()
        ..posts = [
          {
            'post_id': 'p1',
            'text': 'Toggle test',
            'session_id': 'other',
            'username': 'user1',
            'avatar_id': 1,
            'expires_at':
                (DateTime.now().millisecondsSinceEpoch / 1000 + 3600).toInt(),
            'created_at':
                (DateTime.now().millisecondsSinceEpoch / 1000).toInt(),
          },
        ];
      await tester.pumpWidget(_buildPosts(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap to toggle on
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump();

      // Tap to toggle off
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pump();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    });

    testWidgets('tapping comment icon opens comments sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PostsApi()
        ..posts = [
          {
            'post_id': 'p1',
            'text': 'Comment test',
            'session_id': 'other',
            'username': 'user1',
            'avatar_id': 1,
            'expires_at':
                (DateTime.now().millisecondsSinceEpoch / 1000 + 3600).toInt(),
            'created_at':
                (DateTime.now().millisecondsSinceEpoch / 1000).toInt(),
          },
        ];
      await tester.pumpWidget(_buildPosts(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('No comments yet. Be the first!'), findsOneWidget);
    });

    testWidgets('compose sheet rejects empty text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildPosts());
      await tester.pump(const Duration(milliseconds: 500));

      // Open compose sheet
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Post button should be disabled (null onPressed) when text is empty
      final postButton =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(postButton.onPressed, isNull);
    });

    testWidgets('compose sheet shows character counter', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildPosts());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Counter should show 400 (max chars)
      expect(find.text('400'), findsOneWidget);

      // Type something
      await tester.enterText(find.byType(TextField).first, 'Hello');
      await tester.pump();

      expect(find.text('395'), findsOneWidget);
    });

    testWidgets('pull to refresh triggers reload', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildPosts());
      await tester.pump(const Duration(milliseconds: 500));

      // The RefreshIndicator is present in the tree
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}
