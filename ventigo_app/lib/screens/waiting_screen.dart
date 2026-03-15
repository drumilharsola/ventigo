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
import '../widgets/warm_card.dart';

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

  void _handleWaitWsEvent(Map<String, dynamic> msg) {
    final event = msg['event'] as String?;
    if (event == 'error' && (msg['detail'] == 'token_invalid' || msg['detail'] == 'session_replaced')) {
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
  }

  void _connectWs() {
    final token = _token;
    if (token == null || _timedOut) return;
    _wsSub?.cancel();
    _ws?.sink.close();

    final uri = Uri.parse(Env.boardWsUrl(token));
    _ws = WebSocketChannel.connect(uri);

    _wsSub = _ws!.stream.listen(
      (raw) => _handleWaitWsEvent(jsonDecode(raw as String) as Map<String, dynamic>),
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

  Widget _buildBreathingCircle() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.07).animate(_breatheCtrl),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.peach.withValues(alpha: 0.07),
                border: Border.all(color: AppColors.peach.withValues(alpha: 0.18), width: 1.5),
              ),
            ),
          ),
          // Middle ring
          ScaleTransition(
            scale: Tween<double>(begin: 1.07, end: 1.0).animate(_breatheCtrl),
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.peach.withValues(alpha: 0.11),
                border: Border.all(color: AppColors.peach.withValues(alpha: 0.28), width: 1.5),
              ),
            ),
          ),
          // Core
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.16).animate(_breatheCtrl),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.peach.withValues(alpha: 0.75),
              ),
            ),
          ),
          // Breathe text below
          Positioned(
            bottom: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _breatheIn ? 'BREATHE IN' : 'BREATHE OUT',
                key: ValueKey(_breatheIn),
                style: AppTypography.micro(fontSize: 10, color: AppColors.peach),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunFactCard() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: WarmCard(
        key: ValueKey(_funFact),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\u2726 FUN FACT WHILE YOU WAIT',
              style: AppTypography.micro(fontSize: 10, color: AppColors.amber),
            ),
            const SizedBox(height: 6),
            Text(
              _funFact,
              style: AppTypography.body(fontSize: 14, color: AppColors.graphite),
            ),
          ],
        ),
      ),
    );
  }

  Widget _waitingView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: _handleCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text('Cancel request', style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.venterLight,
                  borderRadius: AppRadii.fullAll,
                ),
                child: Text('\ud83c\udf99 VENTER MODE', style: AppTypography.label(fontSize: 10, color: AppColors.venterPrimary)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBreathingCircle(),
                    const SizedBox(height: 24),
                    // Large timer
                    Text(
                      '${(_remaining ~/ 60).toString().padLeft(2, '0')}:${(_remaining % 60).toString().padLeft(2, '0')}',
                      style: AppTypography.hero(fontSize: 52),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your space is ready. Someone will be here soon.',
                      style: AppTypography.body(fontSize: 14, color: AppColors.slate),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    _buildFunFactCard(),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            Text('⏱', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            Text("No one connected this time.", style: AppTypography.heading(fontSize: 24, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(
              "That's okay - you still showed up for yourself. Listeners are most active in the evenings.",
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
                  Text('WRITE IT OUT - JUST FOR YOU', style: AppTypography.micro(fontSize: 10, color: AppColors.lavender)),
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
    );
  }
}

enum _ReqStatus { matched, active, inactive }
