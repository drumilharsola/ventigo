import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/screens/onboarding_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('shows first step', (tester) async {
      await tester.pumpWidget(testApp(const OnboardingScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Vent freely'), findsOneWidget);
      expect(find.text('Next →'), findsOneWidget);
    });

    testWidgets('navigate to next step', (tester) async {
      await tester.pumpWidget(testApp(const OnboardingScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Next →'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('← Back'), findsOneWidget);
    });

    testWidgets('navigate back from second step', (tester) async {
      await tester.pumpWidget(testApp(const OnboardingScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      // Go to step 2
      await tester.tap(find.text('Next →'));
      await tester.pump(const Duration(milliseconds: 500));

      // Go back
      await tester.tap(find.text('← Back'));
      await tester.pump(const Duration(milliseconds: 500));
      // Back on first step — no back button
      expect(find.text('← Back'), findsNothing);
    });

    testWidgets('last step shows Continue', (tester) async {
      await tester.pumpWidget(testApp(const OnboardingScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap next 3 times to reach step 4
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next →'));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('Continue →'), findsOneWidget);
    });

    testWidgets('with intent shows pill', (tester) async {
      await tester.pumpWidget(testApp(const OnboardingScreen(intent: 'support')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('LISTENER PATH'), findsOneWidget);
    });

    testWidgets('with speak intent shows venter path', (tester) async {
      await tester.pumpWidget(testApp(const OnboardingScreen(intent: 'speak')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('VENTER PATH'), findsOneWidget);
    });
  });
}
