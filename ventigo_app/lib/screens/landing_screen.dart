import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../state/auth_provider.dart';
import '../widgets/flow_logo.dart';
import '../widgets/orb_background.dart';
import '../widgets/pill.dart';
import '../widgets/flow_button.dart';
import '../widgets/wellbeing_poster.dart';
import '../config/brand.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  static const _signals = [
    ('01', '15-minute sessions'),
    ('02', 'Anonymous by design'),
    ('03', 'Presence over advice'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final authed = auth.isLoggedIn && auth.hasProfile;
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 900;
    final maxWidth = narrow ? size.width : 1240.0;

    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Stack(
        children: [
          const OrbBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 32, vertical: 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),
                      // -- Sticky frosted nav --
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            color: AppColors.snow.withValues(alpha: 0.85),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                FlowLogo(dark: true, onTap: () => context.go('/')),
                                if (!authed)
                                  TextButton(
                                    onPressed: () => context.go('/verify'),
                                    child: Text('Sign in', style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _flexSection(
                        narrow: narrow,
                        children: [
                          Expanded(
                            flex: narrow ? 0 : 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Pill(text: 'ANONYMOUS CARE · NO NOISE · NO JUDGEMENT', showDot: true),
                                const SizedBox(height: 22),
                                RichText(
                                  text: TextSpan(
                                    style: AppTypography.hero(fontSize: narrow ? 60 : 96),
                                    children: [
                                      const TextSpan(text: 'Talk\n'),
                                      TextSpan(
                                        text: 'messy.',
                                        style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.peach),
                                      ),
                                      const TextSpan(text: '\nLand softer.'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 620),
                                  child: Text(
                                    '${Brand.appNamePlain} turns emotional overwhelm into a short, human, one-to-one check-in. No public room. No audience. Just relief, presence, and a clean exit.',
                                    style: AppTypography.body(fontSize: 17, color: AppColors.graphite),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  children: [
                                    FlowButton(
                                      label: 'I need to exhale',
                                      variant: FlowButtonVariant.venter,
                                      icon: Icons.mic_rounded,
                                      onPressed: () => context.go(authed ? '/home' : '/verify'),
                                    ),
                                    FlowButton(
                                      label: 'I can hold space',
                                      variant: FlowButtonVariant.listener,
                                      icon: Icons.favorite_outline_rounded,
                                      onPressed: () => context.go(authed ? '/community' : '/verify'),
                                    ),
                                  ],
                                ),
                                if (authed) ...[
                                  const SizedBox(height: 14),
                                  FlowButton(
                                    label: 'Enter the room →',
                                    variant: FlowButtonVariant.ghost,
                                    icon: Icons.arrow_outward_rounded,
                                    onPressed: () => context.go('/home'),
                                  ),
                                ],
                                const SizedBox(height: 28),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: _signals
                                      .map((item) => _SignalChip(number: item.$1, label: item.$2))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: narrow ? 0 : 28, height: narrow ? 24 : 0),
                          Expanded(
                            flex: narrow ? 0 : 5,
                            child: const WellbeingPoster(
                              title: 'A place to offload before the feeling becomes the room.',
                              subtitle: 'A warm space shaped around how you actually feel - not a clinical form or a crowded feed.',
                              mood: PosterMood.bloom,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _flexSection({required bool narrow, required List<Widget> children}) {
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.map((c) {
          if (c is Expanded) return c.child;
          return c;
        }).toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.88),
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: AppColors.border, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(number, style: AppTypography.label(color: AppColors.accent)),
          const SizedBox(width: 10),
          Text(label, style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        ],
      ),
    );
  }
}
