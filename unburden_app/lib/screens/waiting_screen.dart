import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import '../config/theme.dart';
import '../data/fun_facts.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../widgets/flow_button.dart';
import '../widgets/orb_background.dart';
import '../widgets/timer_widget.dart';
import '../widgets/breathing_circle.dart';

const _waitWindowSeconds = 10 * 60;

class WaitingScreen extends ConsumerStatefulWidget {
  final String requestId;
  const WaitingScreen({super.key, required this.requestId});

  @override
  ConsumerState<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends ConsumerState<WaitingScreen>
    with SingleTickerProviderStateMixin {
  int _remaining = _waitWindowSeconds;
  bool _timedOut = false;
  bool _loading = true;
  bool _retrying = false;
  late String _requestId;
  late String _funFact;
  Timer? _factTimer;

  // Breathe animation
  late final AnimationController _breatheCtrl;
  bool _breatheIn = true;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _requestId = widget.requestId;
    _funFact = kFunFacts[Random().nextInt(kFunFacts.length)];
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _breatheIn = false);
          _breatheCtrl.reverse();
        } else if (status == AnimationStatus.dismissed) {
          setState(() => _breatheIn = true);
          _breatheCtrl.forward();
        }
      });
    _breatheCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
      // Rotate fun fact every 10 seconds
      _factTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) {
          setState(() => _funFact = kFunFacts[Random().nextInt(kFunFacts.length)]);
        }
      });
    });
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _factTimer?.cancel();
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
    if (mounted) context.go('/home');
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleCancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.snow,
        body: Stack(
          children: [
            const OrbBackground(),
            SafeArea(
              child: _timedOut ? _timedOutView() : _loading ? _loadingView() : _waitingView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingView() {
    return Center(child: CircularProgressIndicator(color: AppColors.accent));
  }

  Widget _waitingView() {
    return Column(
      children: [
        // Top bar with cancel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FlowButton(
                label: '← Cancel',
                variant: FlowButtonVariant.ghost,
                size: FlowButtonSize.sm,
                onPressed: _handleCancel,
              ),
              TimerWidget(remainingSeconds: _remaining, onEnd: _handleTimeout),
            ],
          ),
        ),

        // Center breathing section
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Breathing circle with text
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const BreathingCircle(size: 140),
                          AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              _breatheIn ? 'Breathe in' : 'Breathe out',
                              style: AppTypography.ui(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Your space is ready.',
                      style: AppTypography.title(fontSize: 22, color: AppColors.ink),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Someone will be here soon.',
                      style: AppTypography.body(fontSize: 14, color: AppColors.slate),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Fun fact card
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Container(
                        key: ValueKey(_funFact),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lavender.withValues(alpha: 0.1),
                          borderRadius: AppRadii.lgAll,
                          border: Border.all(color: AppColors.lavender.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FUN FACT',
                              style: AppTypography.label(fontSize: 10, color: AppColors.lavender),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _funFact,
                              style: AppTypography.body(fontSize: 13, color: AppColors.graphite),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cancel button
                    FlowButton(
                      label: 'Cancel',
                      variant: FlowButtonVariant.danger,
                      size: FlowButtonSize.sm,
                      onPressed: _handleCancel,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _timedOutView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⏱', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            Text("No one connected this time.", style: AppTypography.heading(fontSize: 24, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(
              "That's okay — you still showed up for yourself. Listeners are most active in the evenings.",
              style: AppTypography.body(fontSize: 14, color: AppColors.slate),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Journal fallback
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lavender.withValues(alpha: 0.08),
                borderRadius: AppRadii.lgAll,
                border: Border.all(color: AppColors.lavender.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WRITE IT OUT — JUST FOR YOU', style: AppTypography.label(fontSize: 10, color: AppColors.lavender)),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Say what you wanted to say. No one sees this.',
                      hintStyle: AppTypography.body(fontSize: 13, color: AppColors.mist),
                      border: InputBorder.none,
                    ),
                    style: AppTypography.body(fontSize: 14, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FlowButton(
              label: _retrying ? 'Raising hand…' : 'Try again →',
              onPressed: _retrying ? null : _handleRetry,
              loading: _retrying,
            ),
            const SizedBox(height: 12),
            FlowButton(label: 'Back to home', variant: FlowButtonVariant.ghost, onPressed: () => context.go('/home')),
            const SizedBox(height: 20),
            Text(
              'If you\'re struggling right now, you\'re not alone. iCall: 9152987821',
              style: AppTypography.body(fontSize: 12, color: AppColors.slate),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum _ReqStatus { matched, active, inactive }
