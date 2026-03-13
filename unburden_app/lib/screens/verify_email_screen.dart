import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String token;
  const VerifyEmailScreen({super.key, required this.token});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  String _status = 'verifying'; // verifying | success | error

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.verifyEmail(widget.token);
      ref.read(authProvider.notifier).setEmailVerified(true);
      if (mounted) setState(() => _status = 'success');
    } catch (_) {
      if (mounted) setState(() => _status = 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_status == 'verifying') ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Verifying your email...', style: AppTypography.body()),
              ],
              if (_status == 'success') ...[
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
                const SizedBox(height: 16),
                Text('Email verified!', style: AppTypography.title()),
                const SizedBox(height: 8),
                Text('You can close this page.', style: AppTypography.body()),
              ],
              if (_status == 'error') ...[
                Icon(Icons.error_rounded, color: AppColors.danger, size: 64),
                const SizedBox(height: 16),
                Text('Verification failed', style: AppTypography.title()),
                const SizedBox(height: 8),
                Text('The link may have expired. Please request a new one.', style: AppTypography.body(), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
