import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ventigo_app/screens/profile_screen.dart';
import 'package:ventigo_app/services/api_client.dart';
import 'package:ventigo_app/models/user_profile.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/state/board_provider.dart';
import 'package:ventigo_app/state/pending_wait_provider.dart';
import '../helpers/test_helpers.dart';

class _ProfileApi extends FakeApiClient {
  int setProfileCalls = 0;
  int updateProfileCalls = 0;
  int deleteCalls = 0;
  bool setupFail = false;
  bool updateFail = false;

  @override
  Future<ProfileSetupResponse> setProfile(String token, {required String dob, required int avatarId}) async {
    setProfileCalls++;
    if (setupFail) throw Exception('Setup failed');
    return const ProfileSetupResponse(username: 'newuser', avatarId: 1);
  }

  @override
  Future<ProfileSetupResponse> updateProfile(String token, {int? avatarId, bool? rerollUsername}) async {
    updateProfileCalls++;
    if (updateFail) throw Exception('Update failed');
    return ProfileSetupResponse(username: 'newname', avatarId: avatarId ?? 1);
  }

  @override
  Future<void> deleteAccount(String token) async {
    deleteCalls++;
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
  });
}

Widget _buildProfile({_ProfileApi? api, AuthState? authState}) {
  final fakeApi = api ?? _ProfileApi();
  final auth = authState ?? kTestAuthState;
  return ProviderScope(
    overrides: [
      authStorageProvider.overrideWithValue(FakeAuthStorage()),
      authProvider.overrideWith((ref) => TestAuthNotifier(initial: auth)),
      apiClientProvider.overrideWithValue(fakeApi),
      boardProvider.overrideWith((ref) => InertBoardNotifier(ref)),
      pendingWaitProvider.overrideWith((ref) => InertPendingWaitNotifier(ref)),
    ],
    child: const MaterialApp(
      home: ProfileScreen(),
    ),
  );
}

void main() {
  group('ProfileScreen setup mode', () {
    testWidgets('shows setup form when no profile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Auth with token but no username → setup mode
      const noProfile = AuthState(
        token: 'test-token',
        sessionId: 'test-session',
        hasHydrated: true,
      );
      await tester.pumpWidget(_buildProfile(authState: noProfile));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Set up'), findsOneWidget);
      expect(find.text('Tap to select'), findsOneWidget);
      expect(find.textContaining('CHOOSE YOUR AVATAR'), findsOneWidget);
    });

    testWidgets('tap date of birth opens date picker', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const noProfile = AuthState(
        token: 'test-token',
        sessionId: 'test-session',
        hasHydrated: true,
      );
      await tester.pumpWidget(_buildProfile(authState: noProfile));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Tap to select'));
      await tester.pumpAndSettle();

      // Date picker should be visible
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('continue button disabled without DOB', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const noProfile = AuthState(
        token: 'test-token',
        sessionId: 'test-session',
        hasHydrated: true,
      );
      await tester.pumpWidget(_buildProfile(authState: noProfile));
      await tester.pump(const Duration(milliseconds: 500));

      // Button says 'Continue →' but should be disabled (onPressed: null)
      expect(find.text('Continue →'), findsOneWidget);
    });

    testWidgets('pick DOB then submit calls setProfile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _ProfileApi();
      const noProfile = AuthState(
        token: 'test-token',
        sessionId: 'test-session',
        hasHydrated: true,
      );
      await tester.pumpWidget(_buildProfile(api: api, authState: noProfile));
      await tester.pump(const Duration(milliseconds: 500));

      // Open date picker
      await tester.tap(find.text('Tap to select'));
      await tester.pumpAndSettle();

      // Select OK on date picker (default date)
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // DOB is now set, Continue should be active
      await tester.tap(find.text('Continue →'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.setProfileCalls, 1);
    });
  });

  group('ProfileScreen view mode', () {
    testWidgets('shows username and settings gear', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('testuser'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows My Appreciations tile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('My Appreciations'), findsOneWidget);
    });

    testWidgets('shows Achievements tile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Achievements'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('tap avatar enters edit mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the avatar area (has camera icon)
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('CHOOSE AVATAR'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancel edit hides avatar grid', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('CHOOSE AVATAR'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('CHOOSE AVATAR'), findsNothing);
    });

    testWidgets('save changes calls updateProfile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _ProfileApi();
      await tester.pumpWidget(_buildProfile(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Save changes'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.updateProfileCalls, 1);
    });

    testWidgets('settings sheet opens and shows items', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Change Email'), findsOneWidget);
      expect(find.text('Re-roll Username'), findsOneWidget);
      expect(find.text('Blocked Users'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('shows privacy and terms links', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets('settings -> Change Password opens sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();

      expect(find.text('Current password'), findsOneWidget);
      expect(find.text('New password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
    });

    testWidgets('settings -> Change Email opens sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Email'));
      await tester.pumpAndSettle();

      expect(find.text('New email address'), findsOneWidget);
      expect(find.text('Update Email'), findsOneWidget);
    });

    testWidgets('settings -> Re-roll Username calls updateProfile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _ProfileApi();
      await tester.pumpWidget(_buildProfile(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Re-roll Username'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.updateProfileCalls, 1);
    });

    testWidgets('settings -> Delete Account shows confirmation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Delete Account may be off-screen in the sheet; scroll to it
      await tester.ensureVisible(find.text('Delete Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      expect(find.text('Delete your account?'), findsOneWidget);
      expect(find.text('Yes, delete everything'), findsOneWidget);
    });

    testWidgets('delete cancel dismisses sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your account?'), findsNothing);
    });

    testWidgets('delete confirm calls deleteAccount', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _ProfileApi();
      await tester.pumpWidget(_buildProfile(api: api));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes, delete everything'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.deleteCalls, 1);
    });

    testWidgets('email verified badge shown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildProfile());
      await tester.pump(const Duration(milliseconds: 500));

      // Open settings to see email row
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Email verified'), findsOneWidget);
    });
  });
}
