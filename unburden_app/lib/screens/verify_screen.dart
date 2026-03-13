import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';

import '../state/auth_provider.dart';
import '../widgets/flow_logo.dart';
import '../widgets/flow_button.dart';
import '../widgets/flow_input.dart';
import '../widgets/warm_card.dart';
import '../widgets/orb_background.dart';
import '../widgets/pill.dart';
import '../widgets/wellbeing_poster.dart';

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
    _emailCtrl.addListener(_handleFieldUpdate);
    _passCtrl.addListener(_handleFieldUpdate);
    _confirmCtrl.addListener(_handleFieldUpdate);
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_handleFieldUpdate);
    _passCtrl.removeListener(_handleFieldUpdate);
    _confirmCtrl.removeListener(_handleFieldUpdate);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _handleFieldUpdate() {
    if (mounted) {
      setState(() {});
    }
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
      debugPrint('[LOGIN] calling api.login...');
      final res = await api.login(_emailCtrl.text.trim().toLowerCase(), _passCtrl.text);
      debugPrint('[LOGIN] got response: token=${res.token.substring(0, 8)}... hasProfile=${res.hasProfile} emailVerified=${res.emailVerified}');
      await auth.setAuth(res.token, res.sessionId);
      await auth.setEmailVerified(res.emailVerified);
      if (res.hasProfile) {
        debugPrint('[LOGIN] has profile, calling getMe...');
        final me = await api.getMe(res.token);
        debugPrint('[LOGIN] got me: ${me.username}');
        await auth.setProfile(me.username, me.avatarId);
        debugPrint('[LOGIN] navigating to /lobby, mounted=$mounted');
        if (mounted) context.go('/lobby');
      } else {
        debugPrint('[LOGIN] no profile, navigating to /profile, mounted=$mounted');
        if (mounted) context.go('/profile');
      }
    } catch (e) {
      debugPrint('[LOGIN] ERROR: $e');
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

  void _submitActiveForm() {
    if (_loading) return;

    switch (_mode) {
      case _Mode.login:
        if (_emailCtrl.text.contains('@') && _passCtrl.text.isNotEmpty) {
          _handleLogin();
        }
      case _Mode.register:
        if (_emailCtrl.text.contains('@') && _passCtrl.text.length >= 8 && _confirmCtrl.text.isNotEmpty) {
          _handleRegister();
        }
      case _Mode.checkEmail:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      backgroundColor: AppColors.snow,
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
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: _posterPanel(),
          ),
        ),
        Container(width: 1, color: AppColors.border),
        Expanded(child: _formPanel(padded: true)),
      ],
    );
  }

  Widget _buildNarrow() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _posterPanel(compact: true),
          const SizedBox(height: 20),
          _formPanel(),
        ],
      ),
    );
  }

  Widget _posterPanel({bool compact = false}) {
    final quote = _quotes[_quoteIndex];
    final mood = switch (_mode) {
      _Mode.login => PosterMood.balance,
      _Mode.register => PosterMood.listening,
      _Mode.checkEmail => PosterMood.grounding,
    };

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 48, vertical: compact ? 0 : 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlowLogo(dark: true, onTap: () => context.go('/')),
          SizedBox(height: compact ? 20 : 28),
          WellbeingPoster(
            eyebrow: _mode == _Mode.login ? 'WELCOME BACK' : _mode == _Mode.register ? 'NEW ROOM' : 'CHECK EMAIL',
            title: _mode == _Mode.login
                ? 'Return to a quieter corner of the internet.'
                : _mode == _Mode.register
                    ? 'Build a care account that feels human from the first tap.'
                    : 'Open the link, then step back in when you are ready.',
            subtitle: _mode == _Mode.login
                ? 'The redesign uses custom poster scenes to reduce the coldness of account screens.'
                : _mode == _Mode.register
                    ? 'A more expressive sign-up flow makes emotional safety visible instead of implied.'
                    : 'Verification now lives inside the same visual system instead of a generic utility screen.',
            mood: mood,
            compact: compact,
          ),
          SizedBox(height: compact ? 16 : 20),
          WarmCard(
            padding: const EdgeInsets.all(18),
            color: AppColors.paper,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WHY THIS FEELS DIFFERENT', style: AppTypography.label(color: AppColors.ink)),
                const SizedBox(height: 10),
                ..._offerItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1, style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                        const SizedBox(height: 4),
                        Text(item.$2, style: AppTypography.body(fontSize: 13, color: AppColors.graphite)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(quote.$1, style: AppTypography.body(fontSize: 13, color: AppColors.ink80)),
                const SizedBox(height: 6),
                Text(quote.$2, style: AppTypography.label(color: AppColors.slate)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formPanel({bool padded = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: padded ? 64 : 0, vertical: padded ? 56 : 0),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: WarmCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _progressBar(),
                const SizedBox(height: 28),
                if (_mode == _Mode.login) _loginForm(),
                if (_mode == _Mode.register) _registerForm(),
                if (_mode == _Mode.checkEmail) _checkEmailView(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressBar() {
    final filled = switch (_mode) {
      _Mode.login => 1,
      _Mode.register => 2,
      _Mode.checkEmail => 3,
    };

    return Row(
      children: List.generate(3, (i) {
        final active = i < filled;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: active ? AppColors.ink : AppColors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? AppColors.ink : AppColors.border, width: 1.3),
            ),
            child: Center(
              child: Text(
                '0${i + 1}',
                style: AppTypography.label(fontSize: 10, color: active ? AppColors.white : AppColors.slate),
              ),
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
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2), width: 1.3),
        borderRadius: AppRadii.mdAll,
      ),
      child: Text(_error!, style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger)),
    );
  }

  Widget _loginForm() {
    final canSubmit = _emailCtrl.text.contains('@') && _passCtrl.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Pill(text: 'SIGN IN TO CONTINUE', variant: PillVariant.plain),
        const SizedBox(height: 16),
        Text('Welcome\nback.', style: AppTypography.heading(fontSize: 46)),
        const SizedBox(height: 8),
        Text('Step into a calmer interface with a direct line to support.', style: AppTypography.body(fontSize: 15, color: AppColors.graphite)),
        const SizedBox(height: 28),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FlowInput(
                label: 'Email',
                placeholder: 'you@example.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {},
              ),
              const SizedBox(height: 14),
              FlowInput(
                label: 'Password',
                placeholder: '••••••••',
                controller: _passCtrl,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitActiveForm(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _errorBanner(),
        FlowButton(
          label: _loading ? 'Signing in…' : 'Sign in →',
          onPressed: canSubmit && !_loading ? _handleLogin : null,
          expand: true,
          loading: _loading,
        ),
        const SizedBox(height: 18),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No account? ', style: AppTypography.ui(fontSize: 13, color: AppColors.slate)),
              GestureDetector(
                onTap: () => _switchMode(_Mode.register),
                child: Text('Create one →', style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _registerForm() {
    final canSubmit = _emailCtrl.text.contains('@') && _passCtrl.text.length >= 8 && _confirmCtrl.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Pill(text: 'CREATE ACCOUNT', variant: PillVariant.plain),
        const SizedBox(height: 16),
        Text('Create\nyour account.', style: AppTypography.heading(fontSize: 46)),
        const SizedBox(height: 8),
        Text('A verification link unlocks the full listener role, while the new UI keeps the process warm and clear.', style: AppTypography.body(fontSize: 15, color: AppColors.graphite)),
        const SizedBox(height: 28),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FlowInput(
                label: 'Email',
                placeholder: 'you@example.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {},
              ),
              const SizedBox(height: 14),
              FlowInput(
                label: 'Password',
                placeholder: 'At least 8 characters',
                controller: _passCtrl,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {},
              ),
              const SizedBox(height: 14),
              FlowInput(
                label: 'Confirm password',
                placeholder: '••••••••',
                controller: _confirmCtrl,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitActiveForm(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _errorBanner(),
        FlowButton(
          label: _loading ? 'Creating account…' : 'Create account →',
          onPressed: canSubmit && !_loading ? _handleRegister : null,
          expand: true,
          loading: _loading,
        ),
        const SizedBox(height: 20),
        Center(child: Text('By continuing you confirm you are 18 or older.', style: AppTypography.ui(fontSize: 11, color: AppColors.slate))),
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Already have an account? ', style: AppTypography.ui(fontSize: 13, color: AppColors.slate)),
              GestureDetector(
                onTap: () => _switchMode(_Mode.login),
                child: Text('Sign in →', style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _checkEmailView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Pill(text: 'VERIFY YOUR EMAIL', variant: PillVariant.plain),
        const SizedBox(height: 16),
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.flow5,
            border: Border.all(color: AppColors.ink, width: 1.4),
          ),
          alignment: Alignment.center,
          child: const Text('✉️', style: TextStyle(fontSize: 24)),
        ),
        const SizedBox(height: 28),
        Text('Check\nyour inbox.', style: AppTypography.heading(fontSize: 46)),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: AppTypography.body(fontSize: 15, color: AppColors.graphite),
            children: [
              const TextSpan(text: 'We sent a verification link to '),
              TextSpan(text: _emailCtrl.text, style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const TextSpan(text: '. Click it to unlock the listener role.'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('You can still set up your profile and start venting in the meantime.', style: AppTypography.body(fontSize: 14, color: AppColors.graphite)),
        const SizedBox(height: 28),
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
