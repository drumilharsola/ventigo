import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/intent.dart';
import '../widgets/flow_button.dart';
import '../widgets/warm_card.dart';
import '../widgets/orb_background.dart';
import '../widgets/pill.dart';

class OnboardingScreen extends StatefulWidget {
  final String? intent;
  const OnboardingScreen({super.key, this.intent});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageCtrl;
  int _step = 0;

  static const _steps = [
    ('💬', '01', 'Vent freely', 'Say what you are feeling, with no filter or judgement.'),
    ('🫂', '02', 'Be a listener', 'Listen, stay present, and hold space.'),
    ('⏱', '03', '15 minutes', 'A bounded window - light enough to enter, real enough to help.'),
    ('🔒', '04', 'No trace', 'Anonymous. Ephemeral. Nothing is stored.'),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageCtrl.animateToPage(page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    setState(() => _step = page);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseIntent(widget.intent);
    final narrow = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Stack(
        children: [
          const OrbBackground(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Step dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final active = i == _step;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? AppColors.accent : AppColors.mist,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Intent pill
                if (parsed != null)
                  Pill(text: parsed == UserIntent.support ? 'LISTENER PATH' : 'VENTER PATH'),
                if (parsed != null) const SizedBox(height: 8),

                // PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _steps.length,
                    onPageChanged: (i) => setState(() => _step = i),
                    itemBuilder: (_, i) {
                      final step = _steps[i];
                      return Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: narrow ? 24 : 80),
                          child: WarmCard(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(step.$1, style: const TextStyle(fontSize: 48)),
                                const SizedBox(height: 20),
                                Text(step.$2, style: AppTypography.label(color: AppColors.accent)),
                                const SizedBox(height: 12),
                                Text(step.$3, style: AppTypography.title(fontSize: 26), textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                Text(step.$4, style: AppTypography.body(fontSize: 15), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Buttons
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: narrow ? 24 : 80, vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_step > 0)
                        FlowButton(
                          label: '← Back',
                          variant: FlowButtonVariant.ghost,
                          size: FlowButtonSize.md,
                          onPressed: () => _goTo(_step - 1),
                        ),
                      if (_step > 0) const SizedBox(width: 12),
                      FlowButton(
                        label: _step == 3 ? 'Continue →' : 'Next →',
                        onPressed: () {
                          if (_step < 3) {
                            _goTo(_step + 1);
                          } else {
                            context.go('/home');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
