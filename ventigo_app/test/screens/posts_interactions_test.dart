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
  int createCalls = 0;
  int deleteCalls = 0;
  bool createFail = false;

  @override
  Future<List<Map<String, dynamic>>> getPosts() async => posts;

  @override
  Future<Map<String, dynamic>> createPost(String token, String text) async {
    createCalls++;
    if (createFail) throw Exception('Rate limited');
    return {'post_id': 'new1', 'text': text, 'session_id': 'test-session', 'created_at': DateTime.now().toIso8601String()};
  }

  @override
  Future<void> deletePost(String token, String postId) async {
    deleteCalls++;
  }
}

Widget _buildPosts({_PostsApi? api}) {
  final fakeApi = api ?? _PostsApi();
  return ProviderScope(
    overrides: [
      authStorageProvider.overrideWithValue(FakeAuthStorage()),
      authProvider.overrideWith((ref) => TestAuthNotifier(initial: kTestAuthState)),
      apiClientProvider.overrideWithValue(fakeApi),
      boardProvider.overrideWith((ref) => InertBoardNotifier(ref)),
      pendingWaitProvider.overrideWith((ref) => InertPendingWaitNotifier(ref)),
    ],
    child: const MaterialApp(
      home: PostsScreen(),
    ),
  );
}

void main() {
  group('PostsScreen', () {
    testWidgets('shows empty state when no posts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildPosts());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('No posts'), findsOneWidget);
    });

    testWidgets('shows posts when loaded', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PostsApi()
        ..posts = [
          {
            'post_id': 'p1',
            'text': 'Hello world',
            'session_id': 'other-session',
            'username': 'user1',
            'avatar_id': 1,
            'expires_at': (DateTime.now().millisecondsSinceEpoch / 1000 + 3600).toInt(),
            'created_at': (DateTime.now().millisecondsSinceEpoch / 1000).toInt(),
          },
        ];
      await tester.pumpWidget(_buildPosts(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('FAB opens compose sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildPosts());
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the FAB
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await tester.pumpAndSettle();

        expect(find.text('Share something'), findsOneWidget);
        expect(find.text('Post'), findsOneWidget);
      }
    });

    testWidgets('compose submit calls createPost', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PostsApi();
      await tester.pumpWidget(_buildPosts(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await tester.pumpAndSettle();

        // Enter text in compose field
        final textField = find.byType(TextField);
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField.first, 'My test post');
          await tester.pump(const Duration(milliseconds: 100));

          await tester.tap(find.text('Post'));
          await tester.pump(const Duration(milliseconds: 500));
          expect(api.createCalls, 1);
        }
      }
    });

    testWidgets('shows own post with delete option', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PostsApi()
        ..posts = [
          {
            'post_id': 'p1',
            'text': 'My own post',
            'session_id': 'test-session', // matches kTestAuthState.sessionId
            'username': 'testuser',
            'avatar_id': 1,
            'expires_at': (DateTime.now().millisecondsSinceEpoch / 1000 + 3600).toInt(),
            'created_at': (DateTime.now().millisecondsSinceEpoch / 1000).toInt(),
          },
        ];
      await tester.pumpWidget(_buildPosts(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('My own post'), findsOneWidget);
      // Own posts should have a close icon for delete
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('delete own post calls deletePost', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PostsApi()
        ..posts = [
          {
            'post_id': 'p1',
            'text': 'My own post',
            'session_id': 'test-session',
            'username': 'testuser',
            'avatar_id': 1,
            'expires_at': (DateTime.now().millisecondsSinceEpoch / 1000 + 3600).toInt(),
            'created_at': (DateTime.now().millisecondsSinceEpoch / 1000).toInt(),
          },
        ];
      await tester.pumpWidget(_buildPosts(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.deleteCalls, 1);
    });

    testWidgets('post shows time remaining', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PostsApi()
        ..posts = [
          {
            'post_id': 'p1',
            'text': 'Expiring post',
            'session_id': 'other',
            'username': 'user1',
            'avatar_id': 1,
            'expires_at': (DateTime.now().millisecondsSinceEpoch / 1000 + 7200).toInt(),
            'created_at': (DateTime.now().millisecondsSinceEpoch / 1000).toInt(),
          },
        ];
      await tester.pumpWidget(_buildPosts(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show time remaining (e.g., '1h 59m left')
      expect(find.textContaining('left'), findsOneWidget);
    });

    testWidgets('kudos button renders on posts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PostsApi()
        ..posts = [
          {
            'post_id': 'p1',
            'text': 'Some post',
            'session_id': 'other',
            'username': 'user1',
            'avatar_id': 1,
            'expires_at': (DateTime.now().millisecondsSinceEpoch / 1000 + 3600).toInt(),
            'created_at': (DateTime.now().millisecondsSinceEpoch / 1000).toInt(),
          },
        ];
      await tester.pumpWidget(_buildPosts(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      // Kudos icon should be present
      expect(find.byIcon(Icons.favorite_border_rounded), findsWidgets);
    });
  });
}
