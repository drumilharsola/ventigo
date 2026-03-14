import 'package:flutter/material.dart';
import '../config/brand.dart';
import '../config/theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(title: Text('Privacy Policy', style: AppTypography.title(fontSize: 22))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${Brand.appName} Privacy Policy', style: AppTypography.heading(fontSize: 24)),
            const SizedBox(height: 16),
            Text(
              '${Brand.appName} is designed with your privacy at its core. '
              'We collect only the minimum information needed to provide anonymous peer support sessions.\n\n'
              'We do not sell or share your personal data with third parties.\n\n'
              'Chat messages are end-to-end ephemeral and are not stored after sessions end.\n\n'
              'For questions, contact ${Brand.supportEmail}.',
              style: AppTypography.body(),
            ),
          ],
        ),
      ),
    );
  }
}
