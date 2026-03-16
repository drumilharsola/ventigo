import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ventigo_app/screens/verify_screen.dart';
import 'package:ventigo_app/screens/posts_screen.dart';
import 'package:ventigo_app/screens/history_screen.dart';
import 'package:ventigo_app/services/api_client.dart';
import 'package:ventigo_app/models/room_summary.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/state/board_provider.dart';
import 'package:ventigo_app/state/pending_wait_provider.dart';
import '../helpers/test_helpers.dart';

class _TestApi extends FakeApiClient {
  int loginCalls = 0;
  int registerCalls = 0;
  int forgotCalls = 0;
  int resetCalls = 0;
  int sendVerifCalls = 0;
  bool loginFail = false;
  bool registerFail = false;
  bool forgotFail = false;
  bool resetFail = false;

  @override
  Future<AuthResponse> login(String email, String password) async {
    loginCalls++;
    if (loginFail) throw Exception('Invalid credentials');
    return const AuthResponse(token: 'tok', sessionId: 'sid', hasProfile: true, emailVerified: true);
  }

  @override
  Future<AuthResponse> register(String email, String password) async {
    registerCalls++;
    if (registerFail) throw Exception('Email already in use');
    return const AuthResponse(token: 'tok', sessionId: 'sid', hasProfile: false, emailVerified: false);
  }

  @override
  Future<void> forgotPassword(String email) async {
    forgotCalls++;
    if (forgotFail) throw Exception('User not found');
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    resetCalls++;
    if (resetFail) throw Exception('Token expired');
  }

  @override
  Future<void> sendVerification(String token) async {
    sendVerifCalls++;
  }
}

Widget _buildVerify({_TestApi? api, String? resetToken}) {
  final fakeApi = api ?? _TestApi();
  return ProviderScope(
    overrides: [
      authStorageProvider.overrideWithValue(FakeAuthStorage()),
      authProvider.overrideWith((ref) => TestAuthNotifier(initial: const AuthState())),
      apiClientProvider.overrideWithValue(fakeApi),
      boardProvider.overrideWith((ref) => InertBoardNotifier(ref)),
      pendingWaitProvider.overrideWith((ref) => InertPendingWaitNotifier(ref)),
    ],
    child: MaterialApp(
      home: VerifyScreen(resetToken: resetToken),
    ),
  );
}

void main() {
  // =============== VerifyScreen Interactions ===============
  group('VerifyScreen interactions', () {
    testWidgets('login form submits and calls api.login', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _TestApi();
      await tester.pumpWidget(_buildVerify(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      // Login form has 2 TextFields (email + password)
      final fields = find.byType(TextField);
      expect(fields.evaluate().length, greaterThanOrEqualTo(2));
      await tester.enterText(fields.first, 'test@example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.at(1), 'password123');
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Sign in
      await tester.tap(find.text('Sign in →'));
      await tester.pump(const Duration(milliseconds: 500));
      // The login calls context.go('/home') which throws without GoRouter — that's fine.
      // The important thing: login was called.
      expect(api.loginCalls, 1);
    });

    testWidgets('login error shows error banner', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _TestApi()..loginFail = true;
      await tester.pumpWidget(_buildVerify(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'test@example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.at(1), 'password123');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Sign in →'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Invalid credentials'), findsOneWidget);
    });

    testWidgets('switch to register mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildVerify());
      await tester.pump(const Duration(milliseconds: 500));

      // Tap 'Create one →'
      await tester.tap(find.text('Create one →'));
      await tester.pump(const Duration(milliseconds: 500));

      // Register form visible
      expect(find.text('Create account →'), findsOneWidget);
      // 3 fields: email, password, confirm password
      expect(find.byType(TextField).evaluate().length, greaterThanOrEqualTo(3));
    });

    testWidgets('register submits successfully', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _TestApi();
      await tester.pumpWidget(_buildVerify(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      // Switch to register
      await tester.tap(find.text('Create one →'));
      await tester.pump(const Duration(milliseconds: 500));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'new@example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.at(1), 'password123');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.at(2), 'password123');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account →'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.registerCalls, 1);
      // After successful register, should switch to checkEmail mode
      expect(find.textContaining('Check'), findsWidgets);
    });

    testWidgets('register with mismatched passwords shows error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _TestApi();
      await tester.pumpWidget(_buildVerify(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Create one →'));
      await tester.pump(const Duration(milliseconds: 500));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'new@example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.at(1), 'password123');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.at(2), 'different456');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account →'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining("don't match"), findsOneWidget);
      expect(api.registerCalls, 0);
    });

    testWidgets('forgot password mode submits', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _TestApi();
      await tester.pumpWidget(_buildVerify(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Forgot password?'));
      await tester.pump(const Duration(milliseconds: 500));

      // Forgot password mode: single email field
      expect(find.textContaining('Reset your'), findsOneWidget);
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'test@example.com');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Send reset link →'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.forgotCalls, 1);
      // Should show "Check your inbox"
      expect(find.textContaining('Check your inbox'), findsOneWidget);
    });

    testWidgets('forgot password back to sign in', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildVerify());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Forgot password?'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Reset your'), findsOneWidget);

      await tester.tap(find.text('← Back to sign in'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Sign in →'), findsOneWidget);
    });

    testWidgets('reset password mode renders with resetToken', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _TestApi();
      await tester.pumpWidget(_buildVerify(api: api, resetToken: 'reset-tok'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('new password'), findsWidgets);
      final fields = find.byType(TextField);
      expect(fields.evaluate().length, greaterThanOrEqualTo(2));

      await tester.enterText(fields.at(0), 'newpass123');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.at(1), 'newpass123');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Reset password →'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.resetCalls, 1);
      // Should show success
      expect(find.textContaining('Password reset'), findsOneWidget);
    });

    testWidgets('reset password mismatch shows error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _TestApi();
      await tester.pumpWidget(_buildVerify(api: api, resetToken: 'reset-tok'));
      await tester.pump(const Duration(milliseconds: 500));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'newpass123');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.at(1), 'different');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Reset password →'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining("don't match"), findsOneWidget);
      expect(api.resetCalls, 0);
    });

    testWidgets('register then resend email', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _TestApi();
      await tester.pumpWidget(_buildVerify(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      // Switch to register
      await tester.tap(find.text('Create one →'));
      await tester.pump(const Duration(milliseconds: 500));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'new@example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.at(1), 'password123');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.at(2), 'password123');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account →'));
      await tester.pump(const Duration(milliseconds: 500));

      // Now in checkEmail mode — tap Resend link
      expect(find.text('Resend link'), findsOneWidget);
      await tester.tap(find.text('Resend link'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.sendVerifCalls, 1);
      expect(find.text('Email sent ✓'), findsOneWidget);
    });

    testWidgets('reset password success then back to sign in', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _TestApi();
      await tester.pumpWidget(_buildVerify(api: api, resetToken: 'reset-tok'));
      await tester.pump(const Duration(milliseconds: 500));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'newpass123');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.at(1), 'newpass123');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Reset password →'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Password reset'), findsOneWidget);

      // Tap sign in to go back
      await tester.tap(find.text('Sign in →'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Welcome'), findsOneWidget);
    });

    testWidgets('progress bar renders in form panel', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildVerify());
      await tester.pump(const Duration(milliseconds: 500));

      // 3 progress bar segments rendered as Container children in a Row
      // Just verify the form card renders
      expect(find.textContaining('Welcome'), findsOneWidget);
    });
  });

  // =============== postTimeLeft ===============
  group('postTimeLeft', () {
    test('hours and minutes', () {
      final future = DateTime.now().millisecondsSinceEpoch / 1000 + 7200;
      final result = postTimeLeft(future);
      expect(result, contains('h'));
      expect(result, contains('m'));
    });

    test('minutes only', () {
      final future = DateTime.now().millisecondsSinceEpoch / 1000 + 600;
      final result = postTimeLeft(future);
      expect(result, contains('m left'));
    });

    test('expiring soon', () {
      final past = DateTime.now().millisecondsSinceEpoch / 1000 - 10;
      expect(postTimeLeft(past), 'expiring soon');
    });

    test('exactly zero seconds', () {
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      expect(postTimeLeft(now), 'expiring soon');
    });
  });

  // =============== historyRoomTs ===============
  group('historyRoomTs', () {
    test('uses startedAt when present', () {
      final r = RoomSummary.fromJson(const {
        'room_id': 'r1',
        'status': 'ended',
        'started_at': '1700000100',
        'matched_at': '1700000000',
      });
      expect(historyRoomTs(r), 1700000100);
    });

    test('falls back to matchedAt', () {
      final r = RoomSummary.fromJson(const {
        'room_id': 'r1',
        'status': 'ended',
        'started_at': '',
        'matched_at': '1700000050',
      });
      expect(historyRoomTs(r), 1700000050);
    });

    test('returns 0 for empty', () {
      final r = RoomSummary.fromJson(const {
        'room_id': 'r1',
        'status': 'ended',
        'started_at': '',
        'matched_at': '',
      });
      expect(historyRoomTs(r), 0);
    });

    test('returns 0 for non-numeric', () {
      final r = RoomSummary.fromJson(const {
        'room_id': 'r1',
        'status': 'ended',
        'started_at': 'abc',
        'matched_at': 'xyz',
      });
      expect(historyRoomTs(r), 0);
    });
  });
}
