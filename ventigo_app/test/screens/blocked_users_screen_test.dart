import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/models/blocked_user.dart';
import 'package:ventigo_app/screens/blocked_users_screen.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import '../helpers/test_helpers.dart';

class _BlockedApi extends FakeApiClient {
  List<BlockedUser> users = [];
  int unblockCalls = 0;

  @override
  Future<List<BlockedUser>> getBlockedUsers(String token) async => users;

  @override
  Future<void> unblockUser(String token, String peerSessionId) async {
    unblockCalls++;
    users = users.where((u) => u.sessionId != peerSessionId).toList();
  }
}

void main() {
  group('BlockedUsersScreen', () {
    testWidgets('empty state', (tester) async {
      await tester.pumpWidget(testApp(const BlockedUsersScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Blocked users'), findsOneWidget);
      expect(find.text('No blocked users.'), findsOneWidget);
    });

    testWidgets('shows blocked user list', (tester) async {
      final api = _BlockedApi()
        ..users = [
          const BlockedUser(sessionId: 's1', username: 'baduser', avatarId: 2, blockedAt: '1700000000'),
          const BlockedUser(sessionId: 's2', username: 'spammer', avatarId: 3, blockedAt: '1700000100'),
        ];
      await tester.pumpWidget(testApp(
        const BlockedUsersScreen(),
        overrides: [
          ...testOverrides(),
          apiClientProvider.overrideWithValue(api),
        ],
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('baduser'), findsOneWidget);
      expect(find.text('spammer'), findsOneWidget);
      expect(find.text('Unblock'), findsNWidgets(2));
    });

    testWidgets('unblock removes user from list', (tester) async {
      final api = _BlockedApi()
        ..users = [
          const BlockedUser(sessionId: 's1', username: 'baduser', avatarId: 2, blockedAt: '1700000000'),
        ];
      await tester.pumpWidget(testApp(
        const BlockedUsersScreen(),
        overrides: [
          ...testOverrides(),
          apiClientProvider.overrideWithValue(api),
        ],
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('baduser'), findsOneWidget);

      await tester.tap(find.text('Unblock'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(api.unblockCalls, 1);
      expect(find.text('No blocked users.'), findsOneWidget);
    });

    testWidgets('shows formatted blocked date', (tester) async {
      final api = _BlockedApi()
        ..users = [
          const BlockedUser(sessionId: 's1', username: 'testbud', avatarId: 1, blockedAt: '1700000000'),
        ];
      await tester.pumpWidget(testApp(
        const BlockedUsersScreen(),
        overrides: [
          ...testOverrides(),
          apiClientProvider.overrideWithValue(api),
        ],
      ));
      await tester.pump(const Duration(milliseconds: 100));
      // The date should be formatted as d/m/y
      expect(find.textContaining('Blocked on'), findsOneWidget);
    });

    testWidgets('empty username shows Unknown user', (tester) async {
      final api = _BlockedApi()
        ..users = [
          const BlockedUser(sessionId: 's1', username: '', avatarId: 1, blockedAt: '0'),
        ];
      await tester.pumpWidget(testApp(
        const BlockedUsersScreen(),
        overrides: [
          ...testOverrides(),
          apiClientProvider.overrideWithValue(api),
        ],
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Unknown user'), findsOneWidget);
    });

    testWidgets('error state', (tester) async {
      final api = _BlockedApi();
      // Override to throw error
      await tester.pumpWidget(testApp(
        const BlockedUsersScreen(),
        overrides: [
          ...testOverrides(),
          apiClientProvider.overrideWithValue(_ErrorBlockedApi()),
        ],
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Exception'), findsOneWidget);
    });
  });
}

class _ErrorBlockedApi extends FakeApiClient {
  @override
  Future<List<BlockedUser>> getBlockedUsers(String token) async {
    throw Exception('Network error');
  }
}
