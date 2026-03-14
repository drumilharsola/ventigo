import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Show the "Before you begin" safety rules dialog.
///
/// Returns `true` if the user acknowledged, `false` / `null` if cancelled.
/// Pass [dismissible] = true for the chat-screen variant that has no Cancel button.
Future<bool> showSafetyDialog(BuildContext context, {bool dismissible = false}) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      title: Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.accent, size: 24),
          const SizedBox(width: 10),
          Text('Before you begin', style: AppTypography.title(fontSize: 20)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is a safe, anonymous space. To keep it that way:',
              style: AppTypography.body(fontSize: 14, color: AppColors.graphite),
            ),
            const SizedBox(height: 14),
            _safetyRule(Icons.person_off_outlined, 'Do not share personal details (name, location, socials).'),
            const SizedBox(height: 10),
            _safetyRule(Icons.block, 'No hate speech, harassment, or abusive language.'),
            const SizedBox(height: 10),
            _safetyRule(Icons.favorite_border, 'Be kind and respectful - the other person is human too.'),
          ],
        ),
      ),
      actions: [
        if (!dismissible)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTypography.ui(fontSize: 14, color: AppColors.slate)),
          ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          child: Text('I understand', style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white)),
        ),
      ],
    ),
  );
  return accepted == true;
}

Widget _safetyRule(IconData icon, String text) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.slate),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: AppTypography.body(fontSize: 13, color: AppColors.ink))),
    ],
  );
}
