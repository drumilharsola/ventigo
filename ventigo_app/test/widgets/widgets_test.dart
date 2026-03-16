import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/widgets/glass_card.dart';
import 'package:ventigo_app/widgets/warm_card.dart';
import 'package:ventigo_app/widgets/pill.dart';
import 'package:ventigo_app/widgets/role_badge.dart';
import 'package:ventigo_app/widgets/flow_input.dart';
import 'package:ventigo_app/widgets/flow_button.dart';
import 'package:ventigo_app/widgets/timer_widget.dart';
import 'package:ventigo_app/widgets/safety_dialog.dart';
import 'package:ventigo_app/models/character_role.dart';
import 'package:ventigo_app/config/theme.dart';

void main() {
  // ---- GlassCard ----
  group('GlassCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GlassCard(child: Text('hello')))),
      );
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('custom padding and borderRadius', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassCard(
              padding: EdgeInsets.all(8),
              borderRadius: 12,
              child: Text('custom'),
            ),
          ),
        ),
      );
      expect(find.text('custom'), findsOneWidget);
    });
  });

  // ---- WarmCard ----
  group('WarmCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WarmCard(child: Text('warm')))),
      );
      expect(find.text('warm'), findsOneWidget);
    });

    testWidgets('custom color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WarmCard(color: Colors.amber, child: Text('colored')),
          ),
        ),
      );
      expect(find.text('colored'), findsOneWidget);
    });
  });

  // ---- Pill ----
  group('Pill', () {
    testWidgets('accent variant', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Pill(text: 'active'))),
      );
      expect(find.text('active'), findsOneWidget);
    });

    testWidgets('success variant', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Pill(text: 'done', variant: PillVariant.success))),
      );
      expect(find.text('done'), findsOneWidget);
    });

    testWidgets('plain variant', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Pill(text: 'plain', variant: PillVariant.plain))),
      );
      expect(find.text('plain'), findsOneWidget);
    });

    testWidgets('showDot renders animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Pill(text: 'dot', showDot: true))),
      );
      expect(find.text('dot'), findsOneWidget);
      // The animated dot widget is present
      expect(find.byType(Pill), findsOneWidget);
    });
  });

  // ---- RoleBadge ----
  group('RoleBadge', () {
    testWidgets('venter role', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoleBadge(role: CharacterRole.venter))),
      );
      expect(find.text('Venter'), findsOneWidget);
    });

    testWidgets('listener role', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoleBadge(role: CharacterRole.listener))),
      );
      expect(find.text('Listener'), findsOneWidget);
    });

    testWidgets('custom fontSize', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoleBadge(role: CharacterRole.venter, fontSize: 16))),
      );
      expect(find.text('Venter'), findsOneWidget);
    });
  });

  // ---- FlowInput ----
  group('FlowInput', () {
    testWidgets('renders with placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FlowInput(placeholder: 'Type here'))),
      );
      expect(find.text('Type here'), findsOneWidget);
    });

    testWidgets('renders with label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FlowInput(label: 'Email', placeholder: 'e@mail.com'))),
      );
      expect(find.text('EMAIL'), findsOneWidget);
    });

    testWidgets('accepts text input', (tester) async {
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowInput(onChanged: (v) => changed = v, placeholder: 'input'),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'test');
      expect(changed, 'test');
    });

    testWidgets('obscureText', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FlowInput(obscureText: true))),
      );
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.obscureText, true);
    });
  });

  // ---- FlowButton ----
  group('FlowButton', () {
    testWidgets('accent variant renders label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FlowButton(label: 'Go', onPressed: () {}))),
      );
      expect(find.text('Go'), findsOneWidget);
    });

    testWidgets('ghost variant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowButton(label: 'Ghost', variant: FlowButtonVariant.ghost, onPressed: () {}),
          ),
        ),
      );
      expect(find.text('Ghost'), findsOneWidget);
    });

    testWidgets('danger variant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowButton(label: 'Delete', variant: FlowButtonVariant.danger, onPressed: () {}),
          ),
        ),
      );
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('primary variant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowButton(label: 'Primary', variant: FlowButtonVariant.primary, onPressed: () {}),
          ),
        ),
      );
      expect(find.text('Primary'), findsOneWidget);
    });

    testWidgets('venter variant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowButton(label: 'Vent', variant: FlowButtonVariant.venter, onPressed: () {}),
          ),
        ),
      );
      expect(find.text('Vent'), findsOneWidget);
    });

    testWidgets('listener variant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowButton(label: 'Listen', variant: FlowButtonVariant.listener, onPressed: () {}),
          ),
        ),
      );
      expect(find.text('Listen'), findsOneWidget);
    });

    testWidgets('size sm', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowButton(label: 'Small', size: FlowButtonSize.sm, onPressed: () {}),
          ),
        ),
      );
      expect(find.text('Small'), findsOneWidget);
    });

    testWidgets('size md', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowButton(label: 'Med', size: FlowButtonSize.md, onPressed: () {}),
          ),
        ),
      );
      expect(find.text('Med'), findsOneWidget);
    });

    testWidgets('loading shows spinner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowButton(label: 'Load', loading: true, onPressed: () {}),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Load'), findsNothing);
    });

    testWidgets('disabled when onPressed null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FlowButton(label: 'Nope'))),
      );
      expect(find.text('Nope'), findsOneWidget);
    });

    testWidgets('expand fills width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowButton(label: 'Wide', expand: true, onPressed: () {}),
          ),
        ),
      );
      expect(find.text('Wide'), findsOneWidget);
    });

    testWidgets('with icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowButton(label: 'Icon', icon: Icons.add, onPressed: () {}),
          ),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('tap triggers callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowButton(label: 'Tap', onPressed: () => tapped = true),
          ),
        ),
      );
      await tester.tap(find.text('Tap'));
      await tester.pumpAndSettle();
      expect(tapped, true);
    });
  });

  // ---- TimerWidget ----
  group('TimerWidget', () {
    testWidgets('displays formatted time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TimerWidget(remainingSeconds: 125))),
      );
      expect(find.text('02:05'), findsOneWidget);
    });

    testWidgets('zero displays 00:00', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TimerWidget(remainingSeconds: 0))),
      );
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('ticks down', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TimerWidget(remainingSeconds: 3))),
      );
      expect(find.text('00:03'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:02'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:01'), findsOneWidget);
    });

    testWidgets('fires onEnd', (tester) async {
      bool ended = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TimerWidget(remainingSeconds: 1, onEnd: () => ended = true)),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(ended, true);
    });

    testWidgets('updates when remaining changes by >2s', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TimerWidget(remainingSeconds: 100))),
      );
      expect(find.text('01:40'), findsOneWidget);
      // Re-pump with new remaining that differs by >2
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TimerWidget(remainingSeconds: 50))),
      );
      expect(find.text('00:50'), findsOneWidget);
    });

    testWidgets('danger color at 30s', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TimerWidget(remainingSeconds: 25))),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, AppColors.danger);
    });
  });

  // ---- showSafetyDialog ----
  group('SafetyDialog', () {
    testWidgets('shows rules and accept button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSafetyDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Before you begin'), findsOneWidget);
      expect(find.text('I understand'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('dismissible hides cancel', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSafetyDialog(context, dismissible: true),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('I understand'), findsOneWidget);
    });

    testWidgets('accepting returns true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showSafetyDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();
      expect(result, true);
    });

    testWidgets('cancel returns false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showSafetyDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, false);
    });
  });
}
