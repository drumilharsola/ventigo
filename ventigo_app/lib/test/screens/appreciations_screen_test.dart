import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/models/appreciation.dart';
import 'package:ventigo_app/screens/appreciations_screen.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import '../helpers/test_helpers.dart';

class _AppApi extends FakeApiClient {
  List<Appreciation> items = [];
  int createPostCalls = 0;

  @override
  Future<List<Appreciation>> getAppreciations(String token, String username,
      {int limit = 20, int offset = 0}) async {
    if (offset >= items.length) return [];
    return items.skip(offset).take(limit).toList();
  }

  @override
  Future<Map<String, dynamic>> createPost(String token, String text) async {
    createPostCalls++;
    return {'id': 'post1', 'text': text};
  }
}

void main() {
  group('AppreciationsScreen', () {
    testWidgets('empty own profile', (tester) async {
      await tester.pumpWidget(testApp(const AppreciationsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('My Appreciations'), findsOneWidget);
      expect(find.text('No appreciations yet'), findsOneWidget);
    });

    testWidgets('empty other profile', (tester) async {
      await tester.pumpWidget(testApp(const AppreciationsScreen(username: 'friend')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('friend'), findsWidgets);
      expect(find.text('No appreciations to show'), findsOneWidget);
    });

    testWidgets('shows appreciation tiles', (tester) async {
      final api = _AppApi()
        ..items = [
          const Appreciation(id: 1, fromUsername: 'alice', fromRole: 'venter', message: 'Thank you!', createdAt: 1700000000),
          const Appreciation(id: 2, fromUsername: 'bob', fromRole: 'listener', message: 'Great chat', createdAt: 1700001000),
        ];
      await tester.pumpWidget(testApp(
        const AppreciationsScreen(),
        overrides: [
          ...testOverrides(),
          apiClientProvider.overrideWithValue(api),
        ],
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);
      expect(find.text('Thank you!'), findsOneWidget);
      expect(find.text('Great chat'), findsOneWidget);
      expect(find.text('Venter'), findsOneWidget);
      expect(find.text('Listener'), findsOneWidget);
    });

    testWidgets('share to community calls createPost', (tester) async {
      final api = _AppApi()
        ..items = [
          const Appreciation(id: 1, fromUsername: 'alice', fromRole: 'venter', message: 'Thanks!', createdAt: 1700000000),
        ];
      await tester.pumpWidget(testApp(
        const AppreciationsScreen(),
        overrides: [
          ...testOverrides(),
          apiClientProvider.overrideWithValue(api),
        ],
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Share to Community'), findsOneWidget);

      await tester.tap(find.text('Share to Community'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(api.createPostCalls, 1);
    });

    testWidgets('no share button for other user profile', (tester) async {
      final api = _AppApi()
        ..items = [
          const Appreciation(id: 1, fromUsername: 'alice', fromRole: 'venter', message: 'Thanks!', createdAt: 1700000000),
        ];
      await tester.pumpWidget(testApp(
        const AppreciationsScreen(username: 'friend'),
        overrides: [
          ...testOverrides(),
          apiClientProvider.overrideWithValue(api),
        ],
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Share to Community'), findsNothing);
    });

    testWidgets('back button', (tester) async {
      await tester.pumpWidget(testApp(const AppreciationsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}
