import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/intent.dart';
import '../widgets/flow_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/orb_background.dart';
import '../widgets/pill.dart';

class OnboardingScreen extends StatefulWidget {
  final String? intent;
  const OnboardingScreen({super.key, this.intent});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  static const _steps = [
    ('💬', '01', 'Vent freely', 'Say what you are feeling, with no filter or judgement.'),
    ('🫂', '02', 'Be an anchor', 'Listen, stay present, and hold space.'),
    ('⏱', '03', '15 minutes', 'A bounded window — light enough to enter, real enough to help.'),
    ('🔒', '04', 'No trace', 'Anonymous. Ephemeral. Nothing is stored.'),
  ];

  @override
  Widget build(BuildContext context) {
    final parsed = parseIntent(widget.intent);
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final step = _steps[_step];

    return Scaffold(
      body: Stack(
        children: [
          const OrbBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: narrow ? 24 : 64),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final active = i == _step;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? AppColors.accent : AppColors.graphite,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),

                    // Intent pill
                    if (parsed != null)
                      Pill(text: parsed == UserIntent.support ? 'KEEPER PATH' : 'SHARER PATH'),
                    if (parsed != null) const SizedBox(height: 16),

                    // Card
                    GlassCard(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(step.$1, style: const TextStyle(fontSize: 40)),
                          const SizedBox(height: 16),
                          Text(step.$2, style: AppTypography.label(color: AppColors.accent)),
                          const SizedBox(height: 10),
                          Text(step.$3, style: AppTypography.title(fontSize: 24), textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          Text(step.$4, style: AppTypography.body(), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_step > 0)
                          FlowButton(
                            label: '← Back',
                            variant: FlowButtonVariant.ghost,
                            size: FlowButtonSize.md,
                            onPressed: () => setState(() => _step--),
                          ),
                        if (_step > 0) const SizedBox(width: 12),
                        FlowButton(
                          label: _step == 3 ? 'Continue →' : 'Next →',
                          onPressed: () {
                            if (_step < 3) {
                              setState(() => _step++);
                            } else {
                              context.go('/verify');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
