import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../widgets/orb_background.dart';
import '../widgets/warm_card.dart';

class TherapyScreen extends StatelessWidget {
  const TherapyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Stack(
        children: [
          const OrbBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.listenerLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.listenerBorder),
                        ),
                        child: const Center(child: Text('🧠', style: TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Professional Therapy', style: AppTypography.title(fontSize: 20, color: AppColors.ink)),
                            Text('Licensed therapists, on your schedule', style: AppTypography.body(fontSize: 12, color: AppColors.slate)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Coming Soon banner ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: AppRadii.lgAll,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -20,
                          right: -20,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                AppColors.lavender.withValues(alpha: 0.15),
                                Colors.transparent,
                              ]),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.lavender.withValues(alpha: 0.2),
                                borderRadius: AppRadii.fullAll,
                              ),
                              child: Text('COMING SOON', style: AppTypography.label(fontSize: 11, color: AppColors.lavender)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Professional therapy,\nright here in Ventigo.',
                              style: AppTypography.title(fontSize: 22, color: AppColors.white).copyWith(height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'We\'re building a way for you to connect with licensed therapists directly in the app - via chat, call, or video. Stay tuned.',
                              style: AppTypography.body(fontSize: 13, color: AppColors.white.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Peer support info ──
                  Text('Meanwhile, you\'re not alone', style: AppTypography.title(fontSize: 18, color: AppColors.ink)),
                  const SizedBox(height: 8),
                  Text(
                    'Ventigo connects you with real people who listen without judgement. '
                    'Every conversation is anonymous, timed, and safe. '
                    'Sometimes just being heard is the most powerful form of support.',
                    style: AppTypography.body(fontSize: 14, color: AppColors.graphite),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Head to the Chats tab to vent or hold space as a listener.',
                    style: AppTypography.body(fontSize: 13, color: AppColors.slate),
                  ),
                  const SizedBox(height: 28),

                  // ── Emergency contacts (India) ──
                  Text('EMERGENCY HELPLINES (INDIA)', style: AppTypography.label()),
                  const SizedBox(height: 12),

                  _HelplineCard(
                    emoji: '🆘',
                    name: 'iCall',
                    number: '9152987821',
                    desc: 'Mon–Sat, 8 AM – 10 PM',
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 10),
                  _HelplineCard(
                    emoji: '📞',
                    name: 'Vandrevala Foundation',
                    number: '1860-2662-345',
                    desc: '24/7 · Multilingual',
                    color: AppColors.peach,
                  ),
                  const SizedBox(height: 10),
                  _HelplineCard(
                    emoji: '💛',
                    name: 'AASRA',
                    number: '9820466726',
                    desc: '24/7 Crisis Support',
                    color: AppColors.amber,
                  ),
                  const SizedBox(height: 10),
                  _HelplineCard(
                    emoji: '🤝',
                    name: 'Sneha',
                    number: '044-24640050',
                    desc: '24/7 · English & Tamil',
                    color: AppColors.lavender,
                  ),
                  const SizedBox(height: 10),
                  _HelplineCard(
                    emoji: '🧠',
                    name: 'NIMHANS Helpline',
                    number: '080-46110007',
                    desc: 'Mon–Sat, 9:30 AM – 4:30 PM',
                    color: AppColors.flow5,
                  ),
                  const SizedBox(height: 10),
                  _HelplineCard(
                    emoji: '🏥',
                    name: 'Kiran Mental Health',
                    number: '1800-599-0019',
                    desc: '24/7 · Toll-free · Govt. of India',
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 24),

                  // ── Disclaimer ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.08),
                      borderRadius: AppRadii.mdAll,
                      border: Border.all(color: AppColors.amber.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ventigo is a peer support platform, not a substitute for professional mental health care. '
                            'If you are experiencing a mental health emergency, please contact emergency services or a crisis helpline above.',
                            style: AppTypography.body(fontSize: 11, color: AppColors.charcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelplineCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String number;
  final String desc;
  final Color color;

  const _HelplineCard({
    required this.emoji,
    required this.name,
    required this.number,
    required this.desc,
    required this.color,
  });

  Future<void> _dial() async {
    final dialNumber = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: dialNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _dial,
        child: WarmCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(number, style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                    Text(desc, style: AppTypography.body(fontSize: 11, color: AppColors.slate)),
                  ],
                ),
              ),
              Icon(Icons.phone_rounded, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
