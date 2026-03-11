import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import '../config/theme.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../widgets/flow_logo.dart';
import '../widgets/flow_button.dart';
import '../widgets/orb_background.dart';
import '../widgets/pill.dart';
import '../widgets/timer_widget.dart';

const _waitWindowSeconds = 5 * 60;

class WaitingScreen extends ConsumerStatefulWidget {
  final String requestId;
  const WaitingScreen({super.key, required this.requestId});

  @override
  ConsumerState<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends ConsumerState<WaitingScreen> with SingleTickerProviderStateMixin {
  int _remaining = _waitWindowSeconds;
  bool _timedOut = false;
  bool _loading = true;
  bool _retrying = false;
  late String _requestId;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Timer? _pollTimer;

  // Breathing animation
  late AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();
    _requestId = widget.requestId;
    _breathCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    super.dispose();
  }

  String? get _token => ref.read(authProvider).token;

  Future<void> _init() async {
    try {
      final status = await _syncRequest();
      if (!mounted) return;
      if (status == _ReqStatus.matched) return;
      if (status == _ReqStatus.inactive) {
        setState(() => _timedOut = true);
        return;
      }
      _connectWs();
      _startPoll();
    } catch (_) {
      if (mounted) setState(() => _timedOut = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_ReqStatus> _syncRequest() async {
    final token = _token;
    if (token == null) return _ReqStatus.inactive;
    try {
      final req = await ref.read(apiClientProvider).getSpeakerRequest(token, _requestId);
      if (req.status == 'matched' && req.roomId != null) {
        _ws?.sink.close();
        if (mounted) context.go('/chat?room_id=${Uri.encodeComponent(req.roomId!)}');
        return _ReqStatus.matched;
      }
      if (req.postedAt == null) return _ReqStatus.inactive;
      final elapsed = max(0, (DateTime.now().millisecondsSinceEpoch ~/ 1000) - (int.tryParse(req.postedAt!) ?? 0));
      final next = max(0, _waitWindowSeconds - elapsed);
      setState(() => _remaining = next);
      if (next == 0) {
        _handleTimeout();
        return _ReqStatus.inactive;
      }
      return _ReqStatus.active;
    } catch (_) {
      return _ReqStatus.inactive;
    }
  }

  void _connectWs() {
    final token = _token;
    if (token == null || _timedOut) return;
    _wsSub?.cancel();
    _ws?.sink.close();

    final uri = Uri.parse(Env.boardWsUrl(token));
    _ws = WebSocketChannel.connect(uri);

    _wsSub = _ws!.stream.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        final event = msg['event'] as String?;

        if (event == 'error' && msg['detail'] == 'token_invalid') {
          _ws?.sink.close();
          ref.read(authProvider.notifier).clear();
          if (mounted) context.go('/verify');
          return;
        }
        if (event == 'board_state' && msg['my_request_id'] == null) {
          _syncRequest().then((s) {
            if (s != _ReqStatus.matched && s != _ReqStatus.active) {
              setState(() => _timedOut = true);
            }
          });
          return;
        }
        if (event == 'matched') {
          _ws?.sink.close();
          if (mounted) context.go('/chat?room_id=${Uri.encodeComponent(msg['room_id'] as String)}');
        }
      },
      onDone: () {
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 3), () {
          if (!_timedOut && mounted) _connectWs();
        });
      },
    );
  }

  void _startPoll() {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_timedOut || !mounted) return;
      final status = await _syncRequest();
      if (status != _ReqStatus.matched && status != _ReqStatus.active) {
        setState(() => _timedOut = true);
      }
    });
  }

  Future<void> _handleTimeout() async {
    if (_timedOut) return;
    setState(() => _timedOut = true);
    _ws?.sink.close();
    final token = _token;
    if (token == null) return;
    try { await ref.read(apiClientProvider).cancelSpeak(token); } catch (_) {}
  }

  Future<void> _handleCancel() async {
    final token = _token;
    if (token == null) return;
    try { await ref.read(apiClientProvider).cancelSpeak(token); } catch (_) {}
    _ws?.sink.close();
    if (mounted) context.go('/lobby');
  }

  Future<void> _handleRetry() async {
    final token = _token;
    if (token == null) return;
    setState(() => _retrying = true);
    try {
      final res = await ref.read(apiClientProvider).postSpeak(token);
      setState(() {
        _requestId = res.requestId;
        _remaining = _waitWindowSeconds;
        _timedOut = false;
        _retrying = false;
      });
      _connectWs();
      _startPoll();
    } on AuthException {
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go('/verify');
    } catch (_) {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const OrbBackground(),
          SafeArea(
            child: Column(
              children: [
                // Nav
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const FlowLogo(),
                      if (!_timedOut && !_loading)
                        FlowButton(label: '← Lobby', variant: FlowButtonVariant.ghost, size: FlowButtonSize.sm, onPressed: () {
                          final rid = Uri.encodeComponent(_requestId);
                          context.go('/lobby?request_id=$rid');
                        }),
                    ],
                  ),
                ),

                // Center content
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: _timedOut ? _timedOutView() : _waitingView(),
                    ),
                  ),
                ),

                // Bottom actions
                if (!_timedOut && !_loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: FlowButton(
                      label: 'Cancel',
                      variant: FlowButtonVariant.danger,
                      size: FlowButtonSize.sm,
                      onPressed: _handleCancel,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Breathing circle
        AnimatedBuilder(
          animation: _breathCtrl,
          builder: (_, __) {
            final scale = 1.0 + 0.1 * _breathCtrl.value;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.accent.withValues(alpha: 0.3),
                    AppColors.accent.withValues(alpha: 0.05),
                  ]),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 28),

        const Pill(text: 'Finding someone', variant: PillVariant.accent, showDot: true),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(style: AppTypography.display(fontSize: 36), children: [
            const TextSpan(text: 'Your space\nis '),
            TextSpan(text: 'ready.', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.accent)),
          ]),
        ),
        const SizedBox(height: 12),
        Text('Someone will be here soon.', style: AppTypography.body(fontSize: 15, color: AppColors.slate), textAlign: TextAlign.center),
        const SizedBox(height: 20),

        if (!_loading) ...[
          TimerWidget(remainingSeconds: _remaining, onEnd: _handleTimeout),
          const SizedBox(height: 10),
          Text('Most connections happen sooner than 5 minutes.', style: AppTypography.body(fontSize: 12, color: AppColors.mist), textAlign: TextAlign.center),
        ] else
          const CircularProgressIndicator(color: AppColors.accent),
      ],
    );
  }

  Widget _timedOutView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('⏱', style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 20),
        Text("Time's up.", style: AppTypography.heading(fontSize: 28)),
        const SizedBox(height: 10),
        Text('No one joined this time. You can try again.', style: AppTypography.body(fontSize: 14, color: AppColors.slate), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        FlowButton(
          label: _retrying ? 'Raising hand…' : 'Try again →',
          onPressed: _retrying ? null : _handleRetry,
          loading: _retrying,
        ),
        const SizedBox(height: 12),
        FlowButton(label: 'Back to lobby', variant: FlowButtonVariant.ghost, onPressed: () => context.go('/lobby')),
      ],
    );
  }
}

enum _ReqStatus { matched, active, inactive }
