import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';

import '../state/auth_provider.dart';
import '../widgets/flow_logo.dart';
import '../widgets/flow_button.dart';
import '../widgets/flow_input.dart';
import '../widgets/glass_card.dart';
import '../widgets/orb_background.dart';
import '../widgets/pill.dart';

enum _Mode { login, register, checkEmail }

class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  _Mode _mode = _Mode.login;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _resendLoading = false;
  bool _resendDone = false;
  String? _pendingToken;
  late int _quoteIndex;

  static const _quotes = [
    ('"Give sorrow words; the grief that does not speak whispers the o\'er-fraught heart, and bids it break."', 'William Shakespeare · Macbeth'),
    ('"To weep is to make less the depth of grief."', 'William Shakespeare · Henry VI'),
    ('"The best way out is always through."', 'Robert Frost · A Servant to Servants'),
    ('"Although the world is full of suffering, it is also full of the overcoming of it."', 'Helen Keller · Optimism'),
    ('"I am not afraid of storms, for I am learning how to sail my ship."', 'Louisa May Alcott · Little Women'),
    ('"Nothing can bring you peace but yourself."', 'Ralph Waldo Emerson · Self-Reliance'),
    ('"Be not afraid of life. Believe that life is worth living, and your belief will help create the fact."', 'William James · The Will to Believe'),
    ('"The soul would have no rainbow had the eyes no tears."', 'John Vance Cheney · Tears'),
    ('"A loving heart is the truest wisdom."', 'Charles Dickens · David Copperfield'),
    ('"What do we live for, if it is not to make life less difficult for each other?"', 'George Eliot · Middlemarch'),
  ];

  static const _offerItems = [
    ('Anonymous', 'Come in without your real name. Just be yourself here.'),
    ('Private', 'Each conversation is one-to-one, with no public room and no audience.'),
    ('Gentle and short', 'A session lasts 15 minutes, so it stays light enough to enter and leave.'),
  ];

  @override
  void initState() {
    super.initState();
    _quoteIndex = Random().nextInt(_quotes.length);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_Mode next) {
    setState(() {
      _mode = next;
      _error = null;
      _passCtrl.clear();
      _confirmCtrl.clear();
    });
  }

  Future<void> _handleLogin() async {
    setState(() { _error = null; _loading = true; });
    try {
      final api = ref.read(apiClientProvider);
      final auth = ref.read(authProvider.notifier);
      final res = await api.login(_emailCtrl.text.trim().toLowerCase(), _passCtrl.text);
      await auth.setAuth(res.token, res.sessionId);
      await auth.setEmailVerified(res.emailVerified);
      if (res.hasProfile) {
        final me = await api.getMe(res.token);
        await auth.setProfile(me.username, me.avatarId);
        if (mounted) context.go('/lobby');
      } else {
        if (mounted) context.go('/profile');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = "Passwords don't match");
      return;
    }
    setState(() { _error = null; _loading = true; });
    try {
      final api = ref.read(apiClientProvider);
      final auth = ref.read(authProvider.notifier);
      final res = await api.register(_emailCtrl.text.trim().toLowerCase(), _passCtrl.text);
      await auth.setAuth(res.token, res.sessionId);
      await auth.setEmailVerified(false);
      _pendingToken = res.token;
      _switchMode(_Mode.checkEmail);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResend() async {
    if (_pendingToken == null) return;
    setState(() { _resendLoading = true; _resendDone = false; });
    try {
      await ref.read(apiClientProvider).sendVerification(_pendingToken!);
      setState(() => _resendDone = true);
    } catch (_) {}
    finally { if (mounted) setState(() => _resendLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      body: Stack(
        children: [
          const OrbBackground(),
          SafeArea(
            child: wide ? _buildWide() : _buildNarrow(),
          ),
        ],
      ),
    );
  }

  Widget _buildWide() {
    return Row(
      children: [
        Expanded(child: _quotePanel()),
        Container(width: 1, color: AppColors.border),
        Expanded(child: _formPanel()),
      ],
    );
  }

  Widget _buildNarrow() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _formPanel(),
    );
  }

  // ── Left: Quote panel ──
  Widget _quotePanel() {
    final quote = _quotes[_quoteIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FlowLogo(onTap: () => context.go('/')),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Pill(text: 'ANONYMOUS. PRIVATE. HUMAN.'),
              const SizedBox(height: 18),
              Text(
                quote.$1,
                style: AppTypography.display(fontSize: 28).copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 10),
              Text(quote.$2, style: AppTypography.label(color: AppColors.slate)),
              const SizedBox(height: 28),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WHAT WE OFFER', style: AppTypography.label()),
                    const SizedBox(height: 10),
                    ..._offerItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.$1, style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(item.$2, style: AppTypography.body(fontSize: 13)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('Speak without holding back.', style: AppTypography.title(fontSize: 24)),
              const SizedBox(height: 10),
              Text(
                'You will be matched with one steady person for a short anonymous conversation.',
                style: AppTypography.body(fontSize: 14),
              ),
            ],
          ),
          Text('ANONYMOUS. SAFE. HUMAN.', style: AppTypography.label(color: AppColors.graphite)),
        ],
      ),
    );
  }

  // ── Right: Form panel ──
  Widget _formPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          _progressBar(),
          const SizedBox(height: 48),
          if (_mode == _Mode.login) _loginForm(),
          if (_mode == _Mode.register) _registerForm(),
          if (_mode == _Mode.checkEmail) _checkEmailView(),
        ],
      ),
    );
  }

  Widget _progressBar() {
    int filled;
    switch (_mode) {
      case _Mode.login:
        filled = 1;
      case _Mode.register:
        filled = 2;
      case _Mode.checkEmail:
        filled = 2;
    }
    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            height: 2,
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            decoration: BoxDecoration(
              color: i < filled
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _errorBanner() {
    if (_error == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
        borderRadius: AppRadii.mdAll,
      ),
      child: Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
    );
  }

  // ── Login ──
  Widget _loginForm() {
    final canSubmit = _emailCtrl.text.contains('@') && _passCtrl.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome\nback.', style: AppTypography.heading()),
        const SizedBox(height: 8),
        Text('Sign in to continue.', style: AppTypography.body(fontSize: 14, color: AppColors.slate)),
        const SizedBox(height: 40),
        FlowInput(label: 'Email', placeholder: 'you@example.com', controller: _emailCtrl, keyboardType: TextInputType.emailAddress, autofocus: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        FlowInput(label: 'Password', placeholder: '••••••••', controller: _passCtrl, obscureText: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        _errorBanner(),
        FlowButton(
          label: _loading ? 'Signing in…' : 'Sign in →',
          onPressed: canSubmit && !_loading ? _handleLogin : null,
          expand: true,
          loading: _loading,
        ),
        const SizedBox(height: 28),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No account? ', style: AppTypography.ui(fontSize: 13, color: AppColors.slate)),
              GestureDetector(
                onTap: () => _switchMode(_Mode.register),
                child: Text('Create one →', style: AppTypography.ui(fontSize: 13, color: AppColors.accent)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Register ──
  Widget _registerForm() {
    final canSubmit = _emailCtrl.text.contains('@') && _passCtrl.text.length >= 8 && _confirmCtrl.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create\nyour account.', style: AppTypography.heading()),
        const SizedBox(height: 8),
        Text('A verification link will be sent to your email so you can fully unlock the keeper role.', style: AppTypography.body(fontSize: 14, color: AppColors.slate)),
        const SizedBox(height: 40),
        FlowInput(label: 'Email', placeholder: 'you@example.com', controller: _emailCtrl, keyboardType: TextInputType.emailAddress, autofocus: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        FlowInput(label: 'Password', placeholder: 'At least 8 characters', controller: _passCtrl, obscureText: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        FlowInput(label: 'Confirm password', placeholder: '••••••••', controller: _confirmCtrl, obscureText: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        _errorBanner(),
        FlowButton(
          label: _loading ? 'Creating account…' : 'Create account →',
          onPressed: canSubmit && !_loading ? _handleRegister : null,
          expand: true,
          loading: _loading,
        ),
        const SizedBox(height: 20),
        Center(child: Text('By continuing you confirm you are 18 or older.', style: AppTypography.ui(fontSize: 11, color: const Color(0x33FFFFFF)))),
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Already have an account? ', style: AppTypography.ui(fontSize: 13, color: AppColors.slate)),
              GestureDetector(
                onTap: () => _switchMode(_Mode.login),
                child: Text('Sign in →', style: AppTypography.ui(fontSize: 13, color: AppColors.accent)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Check email ──
  Widget _checkEmailView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentDim,
            border: Border.all(color: AppColors.accentGlow),
          ),
          alignment: Alignment.center,
          child: const Text('✉️', style: TextStyle(fontSize: 24)),
        ),
        const SizedBox(height: 28),
        Text('Check\nyour inbox.', style: AppTypography.heading()),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: AppTypography.body(fontSize: 14, color: AppColors.slate),
            children: [
              const TextSpan(text: 'We sent a verification link to '),
              TextSpan(text: _emailCtrl.text, style: AppTypography.ui(fontSize: 14, color: AppColors.fog)),
              const TextSpan(text: '. Click it to unlock the listener role.'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('You can still set up your profile and start venting in the meantime.', style: AppTypography.body(fontSize: 13, color: AppColors.slate)),
        const SizedBox(height: 40),
        FlowButton(label: 'Set up profile →', onPressed: () => context.go('/profile'), expand: true),
        const SizedBox(height: 12),
        FlowButton(
          label: _resendDone ? 'Email sent ✓' : _resendLoading ? 'Sending…' : 'Resend link',
          variant: FlowButtonVariant.ghost,
          onPressed: _resendLoading || _resendDone ? null : _handleResend,
          expand: true,
          loading: _resendLoading,
        ),
      ],
    );
  }
}
