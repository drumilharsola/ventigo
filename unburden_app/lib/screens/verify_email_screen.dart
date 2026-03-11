import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../state/auth_provider.dart';
import '../widgets/flow_button.dart';
import '../widgets/orb_background.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String token;
  const VerifyEmailScreen({super.key, required this.token});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  String _stage = 'loading'; // loading | success | error
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    try {
      final api = ref.read(apiClientProvider);
      final auth = ref.read(authProvider.notifier);
      final res = await api.verifyEmail(widget.token);
      await auth.setAuth(res.token, res.sessionId);
      await auth.setEmailVerified(true);
      if (res.hasProfile) {
        final me = await api.getMe(res.token);
        await auth.setProfile(me.username, me.avatarId);
        if (mounted) context.go('/lobby');
      } else {
        if (mounted) context.go('/profile');
      }
      setState(() => _stage = 'success');
    } catch (e) {
      setState(() { _stage = 'error'; _errorMsg = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const OrbBackground(),
          Center(
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.charcoal,
                borderRadius: AppRadii.lgAll,
                border: Border.all(color: AppColors.border),
              ),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case 'loading':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 20),
            Text('Verifying your email…', style: AppTypography.body()),
          ],
        );
      case 'success':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✓', style: TextStyle(fontSize: 40, color: AppColors.success)),
            const SizedBox(height: 16),
            Text('Email verified.', style: AppTypography.heading(fontSize: 22)),
          ],
        );
      default:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✕', style: TextStyle(fontSize: 40, color: AppColors.danger)),
            const SizedBox(height: 16),
            Text('Link expired.', style: AppTypography.heading(fontSize: 22)),
            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(_errorMsg!, style: AppTypography.body(fontSize: 13, color: AppColors.danger), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            FlowButton(label: 'Back to sign in', variant: FlowButtonVariant.ghost, onPressed: () => context.go('/verify')),
          ],
        );
    }
  }
}
