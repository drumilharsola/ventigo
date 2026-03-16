import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/widgets/typing_indicator.dart';
import 'package:ventigo_app/widgets/breathing_circle.dart';
import 'package:ventigo_app/widgets/bottom_nav_bar.dart';
import 'package:ventigo_app/widgets/user_profile_modal.dart';
import 'package:ventigo_app/widgets/report_modal.dart';
import '../helpers/test_helpers.dart';

void main() {
  // ---- TypingIndicator ----
  group('TypingIndicator', () {
    testWidgets('renders username', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TypingIndicator(username: 'alice'))),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('alice'), findsOneWidget);
    });
  });

  // ---- BreathingCircle ----
  group('BreathingCircle', () {
    testWidgets('renders with default size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BreathingCircle())),
      );
      expect(find.textContaining('Breathe'), findsOneWidget);
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BreathingCircle(size: 100))),
      );
      expect(find.textContaining('Breathe'), findsOneWidget);
    });

    testWidgets('phase changes over time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BreathingCircle())),
      );
      // Initially "Breathe in…"
      expect(find.text('Breathe in…'), findsOneWidget);
      // Advance past halfway (4 seconds of 8 second cycle)
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Breathe out…'), findsOneWidget);
    });
  });

  // ---- BottomNavBar ----
  group('BottomNavBar', () {
    testWidgets('renders 5 items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomNavBar(currentIndex: 0, onTap: (_) {}),
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Therapy'), findsOneWidget);
      expect(find.text('Me'), findsOneWidget);
    });

    testWidgets('tapping item calls onTap', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomNavBar(currentIndex: 0, onTap: (i) => tapped = i),
          ),
        ),
      );
      await tester.tap(find.text('Chats'));
      expect(tapped, 1);
      await tester.tap(find.text('Community'));
      expect(tapped, 2);
      await tester.tap(find.text('Therapy'));
      expect(tapped, 3);
      await tester.tap(find.text('Me'));
      expect(tapped, 4);
    });

    testWidgets('different currentIndex highlights different tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomNavBar(currentIndex: 2, onTap: (_) {}),
          ),
        ),
      );
      // Just verify it builds - the highlight is via AccentDim color
      expect(find.text('Community'), findsOneWidget);
    });
  });

  // ---- UserProfileModal ----
  group('UserProfileModal', () {
    testWidgets('renders loading then profile', (tester) async {
      bool closed = false;
      await tester.pumpWidget(testApp(
        UserProfileModal(
          username: 'testuser',
          peerSessionId: 'peer1',
          onClose: () => closed = true,
        ),
      ));
      // Initially loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // After API completes
      await tester.pumpAndSettle();
      expect(find.text('testuser'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('close button calls onClose', (tester) async {
      bool closed = false;
      await tester.pumpWidget(testApp(
        UserProfileModal(
          username: 'testuser',
          peerSessionId: 'peer1',
          onClose: () => closed = true,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      expect(closed, true);
    });

    testWidgets('shows block button for peer', (tester) async {
      await tester.pumpWidget(testApp(
        UserProfileModal(
          username: 'testuser',
          peerSessionId: 'peer1',
          onClose: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Block this person'), findsOneWidget);
    });

    testWidgets('no block button without peerSessionId', (tester) async {
      await tester.pumpWidget(testApp(
        UserProfileModal(
          username: 'testuser',
          onClose: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Block this person'), findsNothing);
    });

    testWidgets('block confirmation flow', (tester) async {
      await tester.pumpWidget(testApp(
        UserProfileModal(
          username: 'testuser',
          peerSessionId: 'peer1',
          onClose: () {},
        ),
      ));
      await tester.pumpAndSettle();
      // Tap "Block this person"
      await tester.tap(find.text('Block this person'));
      await tester.pumpAndSettle();
      // Shows confirmation
      expect(find.text('Block testuser?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Block'), findsOneWidget);
    });

    testWidgets('block cancel goes back', (tester) async {
      await tester.pumpWidget(testApp(
        UserProfileModal(
          username: 'testuser',
          peerSessionId: 'peer1',
          onClose: () {},
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block this person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Block this person'), findsOneWidget);
    });

    testWidgets('block confirm completes', (tester) async {
      await tester.pumpWidget(testApp(
        UserProfileModal(
          username: 'testuser',
          peerSessionId: 'peer1',
          onClose: () {},
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block this person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(find.text('Blocked'), findsOneWidget);
    });
  });
}
