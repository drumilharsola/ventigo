import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/warm_card.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Stack(
        children: [
          // Ambient orb
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.lavender.withValues(alpha: 0.15),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? 20 : 40,
                vertical: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Professional\nHelp',
                    style: AppTypography.display(
                      fontSize: narrow ? 28 : 40,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Coming soon poster
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.lavender.withValues(alpha: 0.25),
                          AppColors.peach.withValues(alpha: 0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppRadii.lgAll,
                      border: Border.all(
                        color: AppColors.lavender.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.lavender.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.health_and_safety_rounded,
                            size: 40,
                            color: AppColors.lavender,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Connect with a\nProfessional Therapist',
                          textAlign: TextAlign.center,
                          style: AppTypography.title(
                            fontSize: 22,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Get matched with licensed therapists for deeper, '
                          'ongoing support - right from the app.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body(
                            fontSize: 14,
                            color: AppColors.graphite,
                          ).copyWith(height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppRadii.full),
                            border: Border.all(
                                color:
                                    AppColors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '✨ Coming Soon',
                            style: AppTypography.ui(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // What to expect
                  WarmCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What to expect',
                            style: AppTypography.title(
                                fontSize: 18, color: AppColors.ink)),
                        const SizedBox(height: 14),
                        _feature(Icons.verified_user_outlined,
                            'Licensed professionals',
                            'All therapists are verified and certified.'),
                        const SizedBox(height: 12),
                        _feature(Icons.lock_outline_rounded,
                            'Confidential sessions',
                            'Your privacy is always protected.'),
                        const SizedBox(height: 12),
                        _feature(Icons.schedule_rounded,
                            'Flexible scheduling',
                            'Book sessions that fit your routine.'),
                        const SizedBox(height: 12),
                        _feature(Icons.chat_bubble_outline_rounded,
                            'Text, voice & video call options',
                            'Choose how you want to communicate.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reminder
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: AppRadii.lgAll,
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 20, color: AppColors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'In the meantime, Ventigo\'s peer support is always here for you.',
                            style: AppTypography.body(
                                fontSize: 13, color: AppColors.graphite),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _feature(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.lavender),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTypography.ui(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
              Text(desc,
                  style: AppTypography.body(
                      fontSize: 13, color: AppColors.slate)),
            ],
          ),
        ),
      ],
    );
  }
}
