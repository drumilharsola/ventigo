import 'package:flutter/material.dart';
import '../config/brand.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _section('1. Acceptance',
              'By using ${Brand.appName}, you agree to these Terms of Service. If you do not agree, please do not use the service.'),
          _section('2. Eligibility',
              'You must be at least 18 years old to use ${Brand.appName}. By creating an account, you confirm you meet this age requirement.'),
          _section('3. Acceptable Use',
              'You agree not to:\n\n'
              '• Harass, threaten, or abuse other users\n'
              '• Share illegal, harmful, or explicit content\n'
              '• Impersonate others or create fake accounts\n'
              '• Attempt to circumvent anonymity to identify other users\n'
              '• Use the platform for spam, advertising, or recruitment\n'
              '• Exploit vulnerabilities or disrupt the service'),
          _section('4. Anonymity',
              '${Brand.appName} is designed around anonymity. You are assigned a random username and are not required to provide real identity information beyond an email address for account verification.'),
          _section('5. Moderation',
              'We reserve the right to suspend or terminate accounts that violate these terms. Users may report abuse, and reports are reviewed by platform moderators.'),
          _section('6. Disclaimer',
              '${Brand.appName} is NOT a substitute for professional mental health care. If you are in crisis, please contact a local emergency service or mental health hotline. The platform is provided "as is" without warranties of any kind.'),
          _section('7. Limitation of Liability',
              'To the maximum extent permitted by law, ${Brand.appName} and its operators shall not be liable for any indirect, incidental, or consequential damages arising from your use of the service.'),
          _section('8. Changes',
              'We may update these terms from time to time. Continued use of the service after changes constitutes acceptance of the updated terms.'),
          _section('9. Contact',
              'Questions about these terms? Contact us at ${Brand.supportEmail.isNotEmpty ? Brand.supportEmail : "support@example.com"}.'),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 15, height: 1.6)),
        ],
      ),
    );
  }
}
