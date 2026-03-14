import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../state/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String status; // 'success' | 'error' | '' (from backend redirect)
  const VerifyEmailScreen({super.key, required this.status});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.status == 'success') {
      // Update local auth state so UI reflects verified status
      ref.read(authProvider.notifier).setEmailVerified(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.status == 'success';
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSuccess) ...[
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
                const SizedBox(height: 16),
                Text('Email verified!', style: AppTypography.title()),
                const SizedBox(height: 8),
                Text('You can close this page.', style: AppTypography.body()),
              ] else ...[
                Icon(Icons.error_rounded, color: AppColors.danger, size: 64),
                const SizedBox(height: 16),
                Text('Verification failed', style: AppTypography.title()),
                const SizedBox(height: 8),
                Text('The link may have expired. Please request a new one.',
                    style: AppTypography.body(), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
