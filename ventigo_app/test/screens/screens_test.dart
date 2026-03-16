import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ventigo_app/screens/not_found_screen.dart';
import 'package:ventigo_app/screens/privacy_screen.dart';
import 'package:ventigo_app/screens/terms_screen.dart';
import 'package:ventigo_app/screens/help_screen.dart';
import 'package:ventigo_app/screens/verify_email_screen.dart';
import 'package:ventigo_app/screens/therapy_screen.dart';
import 'package:ventigo_app/screens/home_screen.dart';
import 'package:ventigo_app/screens/posts_screen.dart';
import 'package:ventigo_app/screens/profile_screen.dart';
import 'package:ventigo_app/screens/history_screen.dart';
import 'package:ventigo_app/screens/blocked_users_screen.dart';
import 'package:ventigo_app/screens/appreciations_screen.dart';
import 'package:ventigo_app/screens/onboarding_screen.dart';
import 'package:ventigo_app/screens/landing_screen.dart';
import 'package:ventigo_app/screens/verify_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  // ---- Simple screens (no provider dependencies) ----

  group('PrivacyScreen', () {
    testWidgets('renders title and body', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.textContaining('Ventigo Privacy Policy'), findsOneWidget);
    });
  });

  group('TermsScreen', () {
    testWidgets('renders title and body', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TermsScreen()));
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.textContaining('Ventigo Terms of Service'), findsOneWidget);
    });
  });

  group('HelpScreen', () {
    testWidgets('renders coming soon', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      expect(find.textContaining('Professional'), findsWidgets);
      expect(find.textContaining('Coming Soon'), findsOneWidget);
      expect(find.textContaining('Licensed professionals'), findsOneWidget);
      expect(find.textContaining('Confidential sessions'), findsOneWidget);
      expect(find.textContaining('Flexible scheduling'), findsOneWidget);
    });
  });

  group('NotFoundScreen', () {
    testWidgets('renders 404 message', (tester) async {
      await tester.pumpWidget(testApp(const NotFoundScreen()));
      expect(find.text('404'), findsOneWidget);
      expect(find.text('Page not found.'), findsOneWidget);
    });
  });

  // ---- Screens with provider dependencies ----

  group('VerifyEmailScreen', () {
    testWidgets('renders error status', (tester) async {
      await tester.pumpWidget(testApp(const VerifyEmailScreen(status: 'error')));
      await tester.pump();
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text('Verification failed'), findsOneWidget);
    });

    testWidgets('renders empty status', (tester) async {
      await tester.pumpWidget(testApp(const VerifyEmailScreen(status: '')));
      await tester.pump();
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });
  });

  group('TherapyScreen', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(testApp(const TherapyScreen()));
      await tester.pump();
      expect(find.byType(TherapyScreen), findsOneWidget);
    });
  });

  group('OnboardingScreen', () {
    testWidgets('renders with no intent', (tester) async {
      await tester.pumpWidget(testApp(const OnboardingScreen()));
      await tester.pump();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('renders with vent intent', (tester) async {
      await tester.pumpWidget(testApp(const OnboardingScreen(intent: 'vent')));
      await tester.pump();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });

  group('LandingScreen', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(testApp(const LandingScreen()));
      await tester.pump();
      expect(find.byType(LandingScreen), findsOneWidget);
    });
  });

  group('HomeScreen', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(testApp(const HomeScreen()));
      await tester.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('PostsScreen', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(testApp(const PostsScreen()));
      await tester.pump();
      expect(find.byType(PostsScreen), findsOneWidget);
    });
  });

  group('ProfileScreen', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(testApp(const ProfileScreen()));
      await tester.pump();
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });

  group('HistoryScreen', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(testApp(const HistoryScreen()));
      await tester.pump();
      expect(find.byType(HistoryScreen), findsOneWidget);
    });
  });

  // BoardScreen and ConversationsScreen create WebSocket connections + reconnect
  // timers in initState that cannot be cleanly cancelled in unit tests.
  // Their logic is covered via provider-level tests instead.

  group('VerifyScreen', () {
    testWidgets('renders without reset token', (tester) async {
      await tester.pumpWidget(testApp(const VerifyScreen()));
      await tester.pump();
      expect(find.byType(VerifyScreen), findsOneWidget);
    });

    testWidgets('renders with reset token', (tester) async {
      await tester.pumpWidget(testApp(const VerifyScreen(resetToken: 'tok123')));
      await tester.pump();
      expect(find.byType(VerifyScreen), findsOneWidget);
    });
  });

  // LobbyScreen creates WebSocket + reconnect timers that can't be cancelled
  // in unit tests cleanly. Coverage handled by provider tests.

  group('BlockedUsersScreen', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(testApp(const BlockedUsersScreen()));
      await tester.pump();
      expect(find.byType(BlockedUsersScreen), findsOneWidget);
    });
  });

  group('AppreciationsScreen', () {
    testWidgets('renders with username', (tester) async {
      await tester.pumpWidget(testApp(const AppreciationsScreen(username: 'testuser')));
      await tester.pump();
      expect(find.byType(AppreciationsScreen), findsOneWidget);
    });

    testWidgets('renders without username', (tester) async {
      await tester.pumpWidget(testApp(const AppreciationsScreen()));
      await tester.pump();
      expect(find.byType(AppreciationsScreen), findsOneWidget);
    });
  });
}
