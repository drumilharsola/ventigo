import 'package:flutter/material.dart';
import '../config/brand.dart';
import '../config/theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(title: Semantics(header: true, child: Text('Terms of Service', style: AppTypography.title(fontSize: 22)))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${Brand.appName} Terms of Service', style: AppTypography.heading(fontSize: 24)),
            const SizedBox(height: 16),
            Text(
              'By using ${Brand.appName}, you agree to engage respectfully with other users.\n\n'
              '${Brand.appName} provides anonymous peer support. It is not a substitute for professional mental health services.\n\n'
              'You must be at least 18 years old to use this service.\n\n'
              'We reserve the right to suspend accounts that violate community guidelines.\n\n'
              'For questions, contact ${Brand.supportEmail}.',
              style: AppTypography.body(),
            ),
          ],
        ),
      ),
    );
  }
}
