import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import '../config/theme.dart';
import '../models/speaker_request.dart';
import '../services/api_client.dart';
import '../services/avatars.dart';
import '../state/auth_provider.dart';
import '../widgets/flow_button.dart';

String _timeAgo(String postedAt) {
  final secs = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - (int.tryParse(postedAt) ?? 0);
  if (secs < 60) return 'just now';
  if (secs < 3600) return '${secs ~/ 60}m ago';
  return '${secs ~/ 3600}h ago';
}

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  List<SpeakerRequest> _board = [];
  String? _accepting;
  String _error = '';
  bool _refreshing = false;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncBoard();
      _connectWs();
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    super.dispose();
  }

  String? get _token => ref.read(authProvider).token;
  String? get _sessionId => ref.read(authProvider).sessionId;

  Future<void> _syncBoard() async {
    final token = _token;
    if (token == null) return;
    setState(() => _refreshing = true);
    try {
      final res = await ref.read(apiClientProvider).getBoard(token);
      if (!mounted) return;
      setState(() => _board = _filterOwn(res.requests));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _connectWs() {
    final token = _token;
    if (token == null) return;
    _wsSub?.cancel();
    _ws?.sink.close();

    final uri = Uri.parse(Env.boardWsUrl(token));
    _ws = WebSocketChannel.connect(uri);

    _wsSub = _ws!.stream.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        final event = msg['event'] as String?;

        if (event == 'error' && (msg['detail'] == 'token_invalid' || msg['detail'] == 'session_replaced')) {
          _ws?.sink.close();
          ref.read(authProvider.notifier).clear();
          if (mounted) context.go('/verify');
          return;
        }
        if (event == 'board_state') {
          final list = (msg['requests'] as List?)?.map((e) => SpeakerRequest.fromJson(e as Map<String, dynamic>)).toList() ?? [];
          setState(() => _board = _filterOwn(list));
          return;
        }
        if (event == 'new_request') {
          if (msg['session_id'] == _sessionId) return;
          final id = msg['request_id'] as String;
          if (_board.any((r) => r.requestId == id)) return;
          setState(() {
            _board = [
              ..._board,
              SpeakerRequest(requestId: id, sessionId: '', username: msg['username'] as String? ?? '', avatarId: (msg['avatar_id'] ?? 0).toString(), postedAt: msg['posted_at'] as String? ?? ''),
            ];
          });
          return;
        }
        if (event == 'removed_request') {
          setState(() => _board = _board.where((r) => r.requestId != msg['request_id']).toList());
          return;
        }
        if (event == 'matched') {
          _ws?.sink.close();
          if (mounted) context.go('/chat?room_id=${Uri.encodeComponent(msg['room_id'] as String)}');
        }
      },
      onDone: () {
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 3), _connectWs);
      },
    );
  }

  List<SpeakerRequest> _filterOwn(List<SpeakerRequest> list) {
    final sid = _sessionId;
    if (sid == null) return list;
    return list.where((r) => r.sessionId != sid).toList();
  }

  Future<bool> _showSafetyDialog() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
        title: Row(children: [
          Icon(Icons.shield_outlined, color: AppColors.accent, size: 24),
          const SizedBox(width: 10),
          Text('Before you begin', style: AppTypography.title(fontSize: 20)),
        ]),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This is a safe, anonymous space. To keep it that way:', style: AppTypography.body(fontSize: 14, color: AppColors.graphite)),
            const SizedBox(height: 14),
            _rule(Icons.person_off_outlined, 'Do not share personal details.'),
            const SizedBox(height: 10),
            _rule(Icons.block, 'No hate speech or harassment.'),
            const SizedBox(height: 10),
            _rule(Icons.favorite_border, 'Be kind - the other person is human too.'),
          ],
        ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AppTypography.ui(fontSize: 14, color: AppColors.slate))),
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

  static Widget _rule(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.slate),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTypography.body(fontSize: 13, color: AppColors.ink))),
      ],
    );
  }

  Future<void> _handleAccept(String requestId) async {
    final token = _token;
    if (token == null) return;
    if (!await _showSafetyDialog()) return;
    setState(() { _accepting = requestId; _error = ''; });
    try {
      final res = await ref.read(apiClientProvider).acceptSpeaker(token, requestId);
      if (mounted) context.go('/chat?room_id=${Uri.encodeComponent(res.roomId)}');
    } on AuthException {
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go('/verify');
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _accepting = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.snow,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/chats'),
        ),
        title: Text('People who need a listener', style: AppTypography.title(fontSize: 18)),
        actions: [
          IconButton(
            icon: _refreshing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded),
            onPressed: _refreshing ? null : _syncBoard,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_error.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.danger.withValues(alpha: 0.08),
              child: Text(_error, style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          Expanded(
            child: _board.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🤫', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text('All quiet right now.', style: AppTypography.title(fontSize: 20, color: AppColors.charcoal)),
                        const SizedBox(height: 8),
                        Text('Stay here - new requests will appear automatically.', style: AppTypography.body(fontSize: 14, color: AppColors.slate), textAlign: TextAlign.center),
                      ]),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _board.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final req = _board[i];
                      final accepting = _accepting == req.requestId;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadii.mdAll,
                          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 2))],
                        ),
                        child: Row(children: [
                          ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl(req.avatarId, size: 84), width: 42, height: 42)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(req.username, style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                            Text('needs to be heard · ${_timeAgo(req.postedAt)}', style: AppTypography.body(fontSize: 12, color: AppColors.slate)),
                          ])),
                          FlowButton(
                            label: accepting ? '…' : 'Show up',
                            size: FlowButtonSize.sm,
                            onPressed: accepting ? null : () => _handleAccept(req.requestId),
                          ),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
