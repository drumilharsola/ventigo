import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../state/auth_provider.dart';
import '../widgets/flow_logo.dart';
import '../widgets/orb_background.dart';
import '../widgets/pill.dart';
import '../widgets/flow_button.dart';
import '../config/brand.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  static const _features = [
    ('01', 'Vent freely', 'Say whatever you feel — someone is listening.'),
    ('02', 'Be an anchor', 'Sometimes all a person needs is your presence.'),
    ('03', '15 minutes', 'Short enough to enter, real enough to help.'),
    ('04', 'No trace', 'Anonymous. Ephemeral. Safe.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final authed = auth.isLoggedIn && auth.hasProfile;
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 720;

    return Scaffold(
      body: Stack(
        children: [
          const OrbBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: narrow ? 24 : 64, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nav
                  FlowLogo(onTap: () => context.go('/')),
                  const SizedBox(height: 60),

                  // Pill
                  const Pill(text: 'OPEN · SAFE · FREE'),
                  const SizedBox(height: 24),

                  // Hero
                  RichText(
                    text: TextSpan(
                      style: AppTypography.hero(fontSize: narrow ? 48 : 80),
                      children: [
                        const TextSpan(text: '${Brand.appNamePlain}\n'),
                        TextSpan(
                          text: 'yourself.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            foreground: Paint()
                              ..shader = LinearGradient(
                                colors: [AppColors.accent, AppColors.flow3],
                              ).createShader(const Rect.fromLTWH(0, 0, 300, 80)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'A safe, anonymous space to speak and be heard.',
                    style: AppTypography.body(fontSize: 16),
                  ),
                  const SizedBox(height: 36),

                  // CTA
                  FlowButton(
                    label: authed ? Brand.heroCta : 'Get started →',
                    onPressed: () => context.go(authed ? '/lobby' : '/onboarding'),
                  ),
                  const SizedBox(height: 64),

                  // Feature grid
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: _features.map((f) {
                      return SizedBox(
                        width: narrow ? double.infinity : (size.width - 128 - 60) / 4,
                        child: _FeatureCard(number: f.$1, title: f.$2, body: f.$3),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _FeatureCard({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: AppTypography.label(color: AppColors.accent)),
          const SizedBox(height: 10),
          Text(title, style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(body, style: AppTypography.body(fontSize: 13)),
        ],
      ),
    );
  }
}
