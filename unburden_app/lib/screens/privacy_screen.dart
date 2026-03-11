import 'package:flutter/material.dart';
import '../config/brand.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _section('1. Who We Are',
              '${Brand.appName} is an anonymous peer-support platform that connects people for real-time, one-on-one conversations. Your privacy is fundamental to our mission.'),
          _section('2. Data We Collect',
              'We collect the minimum data necessary to operate the service:\n\n'
              '• Email address (authentication and verification only)\n'
              '• Date of birth (age verification; not stored after check)\n'
              '• Randomly generated username and selected avatar\n'
              '• Chat messages (temporarily stored, auto-deleted after 7 days)\n'
              '• Abuse reports you submit\n\n'
              'We do NOT collect real names, phone numbers, location data, or any personally identifiable information beyond your email.'),
          _section('3. Data Retention',
              'All chat data (rooms, messages) is automatically deleted after 7 days. Account profiles persist as long as your account exists. You may delete your account at any time, which permanently removes all associated data.'),
          _section('4. Data Sharing',
              'We do NOT sell, rent, or share your personal data with third parties. We do not display ads. We do not use tracking pixels or analytics cookies.'),
          _section('5. Your Rights (GDPR)',
              'Under GDPR and similar privacy laws, you have the right to:\n\n'
              '• Access: Export all your data from the Profile page.\n'
              '• Erasure: Delete your account and all associated data permanently.\n'
              '• Rectification: Update your avatar or re-roll your username at any time.\n'
              '• Portability: Download your data in JSON format.'),
          _section('6. Security',
              'All data is transmitted over HTTPS. Passwords are hashed using bcrypt. Sessions are managed via signed JWTs. We apply rate limiting and input sanitization to prevent abuse.'),
          _section('7. Contact',
              'For privacy-related inquiries, contact us at ${Brand.supportEmail.isNotEmpty ? Brand.supportEmail : "support@example.com"}.'),
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
