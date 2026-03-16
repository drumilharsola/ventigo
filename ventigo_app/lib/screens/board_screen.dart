import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../models/speaker_request.dart';
import '../services/api_client.dart';
import '../services/avatars.dart';
import '../services/board_ws_service.dart';
import '../state/auth_provider.dart';
import '../widgets/flow_button.dart';
import '../widgets/safety_dialog.dart';
import '../utils/time_helpers.dart';

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

  final BoardWsService _boardWs = BoardWsService();
  StreamSubscription? _boardWsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncBoard();
      _boardWsSub = _boardWs.events.listen(_onBoardEvent);
      _boardWs.connect(() => _token ?? '');
    });
  }

  @override
  void dispose() {
    _boardWsSub?.cancel();
    _boardWs.dispose();
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

  void _onBoardEvent(BoardWsEvent event) {
    switch (event) {
      case AuthErrorEvent():
        ref.read(authProvider.notifier).clear();
        if (mounted) context.go('/verify');
      case BoardStateEvent(:final requests):
        setState(() => _board = _filterOwn(requests));
      case NewRequestEvent(:final request):
        if (request.sessionId == _sessionId) return;
        if (_board.any((r) => r.requestId == request.requestId)) return;
        setState(() => _board = [..._board, request]);
      case RemovedRequestEvent(:final requestId):
        setState(() => _board = _board.where((r) => r.requestId != requestId).toList());
      case MatchedEvent(:final roomId):
        if (mounted) context.go('/chat?room_id=${Uri.encodeComponent(roomId)}');
    }
  }

  List<SpeakerRequest> _filterOwn(List<SpeakerRequest> list) {
    final sid = _sessionId;
    if (sid == null) return list;
    return list.where((r) => r.sessionId != sid).toList();
  }

  Future<bool> _showSafetyDialog() => showSafetyDialog(context);

  Future<void> _handleAccept(String requestId) async {
    final token = _token;
    if (token == null) return;
    if (!await _showSafetyDialog()) return;
    setState(() { _accepting = requestId; _error = ''; });
    try {
      final res = await ref.read(apiClientProvider).acceptSpeaker(token, requestId);
      if (mounted) {
        setState(() => _board = _board.where((r) => r.requestId != requestId).toList());
        context.go('/chat?room_id=${Uri.encodeComponent(res.roomId)}');
      }
    } on AuthException {
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go('/verify');
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _accepting = null; });
    }
  }

  Widget _buildRequestTile(SpeakerRequest req) {
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
          Text('needs to be heard · ${timeAgo(req.postedAt)}', style: AppTypography.body(fontSize: 12, color: AppColors.slate)),
        ])),
        FlowButton(
          label: accepting ? '…' : 'Show up',
          size: FlowButtonSize.sm,
          onPressed: accepting ? null : () => _handleAccept(req.requestId),
        ),
      ]),
    );
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
        title: Semantics(header: true, child: Text('People who need a listener', style: AppTypography.title(fontSize: 22))),
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
                    itemBuilder: (_, i) => _buildRequestTile(_board[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
