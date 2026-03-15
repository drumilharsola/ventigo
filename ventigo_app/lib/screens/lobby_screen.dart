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
import '../models/room_summary.dart';
import '../services/api_client.dart';
import '../services/avatars.dart';
import '../state/auth_provider.dart';
import '../state/pending_wait_provider.dart';
import '../widgets/flow_logo.dart';
import '../widgets/flow_button.dart';
import '../widgets/pill.dart';
import '../widgets/safety_dialog.dart';

// -- Helpers --

String _roomPeerKey(RoomSummary room) {
  if (room.peerSessionId.isNotEmpty) return room.peerSessionId;
  if (room.peerUsername.isNotEmpty) return room.peerUsername;
  return room.roomId;
}

int _lobbyRoomTs(RoomSummary room) =>
    int.tryParse(room.startedAt.isNotEmpty ? room.startedAt : room.matchedAt) ?? 0;

class _GroupedRoom {
  final RoomSummary latest;
  final int count;
  _GroupedRoom(this.latest, this.count);
}

List<_GroupedRoom> _groupRoomsByPeer(List<RoomSummary> rooms) {
  final grouped = <String, _GroupedRoom>{};
  for (final room in rooms) {
    final key = _roomPeerKey(room);
    final existing = grouped[key];
    if (existing != null) {
      final latest = _lobbyRoomTs(room) > _lobbyRoomTs(existing.latest) ? room : existing.latest;
      grouped[key] = _GroupedRoom(latest, existing.count + 1);
    } else {
      grouped[key] = _GroupedRoom(room, 1);
    }
  }
  return grouped.values.toList();
}

// -- Screen --

class LobbyScreen extends ConsumerStatefulWidget {
  final String? requestId;
  const LobbyScreen({super.key, this.requestId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  List<SpeakerRequest> _board = [];
  List<RoomSummary> _rooms = [];
  String _error = '';
  bool _ventLoading = false;
  bool _resendLoading = false;
  bool _resendDone = false;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Timer? _roomSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncBoard();
      _syncRooms();
      _connectWs();
      _refreshEmailVerified();
      _roomSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _syncRooms();
        _refreshEmailVerified();
      });
      // If there's a pending request from the route, start global waiting
      if (widget.requestId != null) {
        ref.read(pendingWaitProvider.notifier).startWaiting(widget.requestId!);
      }
    });
  }

  /// Sync email_verified from the server (user may have verified in browser).
  Future<void> _refreshEmailVerified() async {
    await ref.read(authProvider.notifier).refreshEmailVerified(ref.read(apiClientProvider));
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _roomSyncTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    super.dispose();
  }

  String? get _token => ref.read(authProvider).token;
  String? get _sessionId => ref.read(authProvider).sessionId;

  Future<void> _syncBoard() async {
    final token = _token;
    if (token == null) return;
    try {
      final res = await ref.read(apiClientProvider).getBoard(token);
      if (!mounted) return;
      setState(() {
        _board = _filterOwn(res.requests);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _syncRooms() async {
    final token = _token;
    if (token == null) return;
    try {
      final res = await ref.read(apiClientProvider).getChatRooms(token);
      if (mounted) setState(() => _rooms = res);
    } catch (_) {}
  }

  void _handleBoardWsEvent(Map<String, dynamic> msg) {
    final event = msg['event'] as String?;

    if (event == 'error' && (msg['detail'] == 'token_invalid' || msg['detail'] == 'session_replaced')) {
      _ws?.sink.close();
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go('/verify');
      return;
    }
    if (event == 'board_state') {
      final list = (msg['requests'] as List?)?.map((e) => SpeakerRequest.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      setState(() {
        _board = _filterOwn(list);
      });
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
  }

  void _connectWs() {
    final token = _token;
    if (token == null) return;
    _wsSub?.cancel();
    _ws?.sink.close();

    final uri = Uri.parse(Env.boardWsUrl(token));
    _ws = WebSocketChannel.connect(uri);

    _wsSub = _ws!.stream.listen(
      (raw) => _handleBoardWsEvent(jsonDecode(raw as String) as Map<String, dynamic>),
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

  Future<bool> _showSafetyDialog() => showSafetyDialog(context);

  Future<void> _handleVent() async {
    final token = _token;
    if (token == null) return;
    if (!await _showSafetyDialog()) return;
    setState(() { _error = ''; _ventLoading = true; });
    try {
      final res = await ref.read(apiClientProvider).postSpeak(token);
      ref.read(pendingWaitProvider.notifier).startWaiting(res.requestId);
      _ws?.sink.close();
      if (mounted) context.go('/waiting?request_id=${Uri.encodeComponent(res.requestId)}');
    } on AuthException {
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go('/verify');
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _ventLoading = false; });
    }
  }


  void _handleSignOut() {
    _ws?.sink.close();
    ref.read(authProvider.notifier).clear();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final groupedRooms = _groupRoomsByPeer(_rooms);
    final activeRooms = groupedRooms.where((g) => g.latest.status == 'active').toList();
    final narrow = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Stack(
        children: [
          // Light orbs
          Positioned(top: -120, right: -120, child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.accentGlow.withValues(alpha: 0.15), Colors.transparent])))),

          // Content
          CustomScrollView(
            slivers: [
              // Nav
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.snow.withValues(alpha: 0.8),
                elevation: 0,
                title: const FlowLogo(dark: true),
                actions: [
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: Row(
                      children: [
                        ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl(auth.avatarId ?? 0, size: 56), width: 28, height: 28)),
                        const SizedBox(width: 6),
                        Text(auth.username ?? '', style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.charcoal)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () {
                      _syncRooms();
                      _syncBoard();
                    },
                    icon: const Icon(Icons.refresh, size: 22),
                    color: AppColors.slate,
                    tooltip: 'Refresh',
                    splashRadius: 20,
                  ),
                  const SizedBox(width: 4),
                  TextButton(onPressed: _handleSignOut, child: Text('Sign out', style: AppTypography.ui(fontSize: 12, color: AppColors.slate))),
                  const SizedBox(width: 16),
                ],
              ),

              // Body
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 40, vertical: 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Greeting
                    RichText(text: TextSpan(style: AppTypography.display(fontSize: narrow ? 32 : 48, color: AppColors.ink), children: [
                      const TextSpan(text: 'Good to see you,\n'),
                      TextSpan(text: '${auth.username}.', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.accent)),
                    ])),
                    const SizedBox(height: 24),

                    // Error
                    if (_error.isNotEmpty) _errorBanner(),

                    // Active room banners
                    if (activeRooms.length == 1) _singleActiveRoomBanner(activeRooms.first),
                    if (activeRooms.length > 1) _multiActiveRoomBanner(activeRooms),

                    const SizedBox(height: 16),

                    // Vent card
                    _ventCard(),
                    const SizedBox(height: 14),

                    // Listen card → opens board page
                    _listenCard(auth),
                    const SizedBox(height: 14),

                    // Chat history → opens history page
                    _chatHistoryCard(groupedRooms),
                    const SizedBox(height: 14),

                    // Email verify banner if needed
                    if (auth.emailVerified != true) _emailVerifyBanner(),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
        borderRadius: AppRadii.mdAll,
      ),
      child: Text(_error, style: TextStyle(color: AppColors.danger, fontSize: 13)),
    );
  }

  Widget _singleActiveRoomBanner(_GroupedRoom g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FlowButton(
        label: 'Continue with ${g.latest.peerUsername} →',
        onPressed: () => context.go('/chat?room_id=${Uri.encodeComponent(g.latest.roomId)}'),
        expand: true,
      ),
    );
  }

  Widget _multiActiveRoomBanner(List<_GroupedRoom> active) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: AppRadii.lgAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LIVE CONVERSATIONS', style: AppTypography.label(color: Colors.white54)),
          const SizedBox(height: 6),
          Text('You have ${active.length} active chats.', style: AppTypography.ui(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: active.map((g) {
            return FlowButton(
              label: g.latest.peerUsername,
              variant: FlowButtonVariant.ghost,
              size: FlowButtonSize.sm,
              onPressed: () => context.go('/chat?room_id=${Uri.encodeComponent(g.latest.roomId)}'),
            );
          }).toList()),
        ],
      ),
    );
  }

  Widget _ventCard() {
    return GestureDetector(
      onTap: _ventLoading ? null : _handleVent,
      child: AnimatedOpacity(
        opacity: _ventLoading ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.venterPrimary, AppColors.accentHover], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: AppRadii.lgAll,
            boxShadow: [BoxShadow(color: AppColors.venterPrimary.withValues(alpha: 0.3), blurRadius: 28, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('🎤', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Pill(text: 'I need to vent', variant: PillVariant.accent),
              ]),
              const SizedBox(height: 14),
              Text(_ventLoading ? 'Finding your space…' : 'Let it out.', style: AppTypography.title(fontSize: 18, color: Colors.white)),
              const SizedBox(height: 6),
              Text('Open a private conversation and wait for one good listener to show up.', style: AppTypography.body(fontSize: 13, color: Colors.white70)),
              if (_board.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4ade80), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      '${_board.length} listener${_board.length != 1 ? "s" : ""} available now',
                      style: AppTypography.micro(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _listenCard(AuthState auth) {
    return GestureDetector(
      onTap: auth.emailVerified != true ? null : () => context.go('/community'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: Colors.black.withValues(alpha: 0.07), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('🤝', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('I want to listen', style: AppTypography.title(fontSize: 18, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(
                  _board.isNotEmpty
                      ? '${_board.length} ${_board.length == 1 ? "person" : "people"} waiting to be heard'
                      : 'See who needs a listener',
                  style: AppTypography.body(fontSize: 13, color: AppColors.slate),
                ),
                if (auth.emailVerified != true)
                  Text('Verify email to unlock', style: AppTypography.micro(fontSize: 11, color: AppColors.danger)),
              ],
            )),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.slate),
          ],
        ),
      ),
    );
  }

  Widget _chatHistoryCard(List<_GroupedRoom> grouped) {
    final activeCount = grouped.where((g) => g.latest.status == 'active').length;
    return GestureDetector(
      onTap: () => context.go('/history'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: Colors.black.withValues(alpha: 0.07), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lavender.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('💬', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conversations', style: AppTypography.title(fontSize: 18, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(
                  grouped.isEmpty
                      ? 'No conversations yet'
                      : activeCount > 0
                          ? '$activeCount active · ${grouped.length} total'
                          : '${grouped.length} past ${grouped.length == 1 ? "chat" : "chats"}',
                  style: AppTypography.body(fontSize: 13, color: AppColors.slate),
                ),
              ],
            )),
            if (activeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                child: Text('$activeCount', style: AppTypography.ui(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.slate),
          ],
        ),
      ),
    );
  }

  Widget _emailVerifyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.accentDim.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.accentDim.withValues(alpha: 0.2)),
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        children: [
          Expanded(child: Text('🔒 Verify your email to unlock all features.', style: AppTypography.body(fontSize: 13, color: AppColors.slate))),
          FlowButton(
            label: _resendDone ? 'Sent ✓' : _resendLoading ? 'Sending…' : 'Resend email',
            size: FlowButtonSize.sm,
            onPressed: _resendLoading || _resendDone ? null : () async {
              setState(() => _resendLoading = true);
              try { await ref.read(apiClientProvider).sendVerification(_token!); setState(() => _resendDone = true); } catch (_) {}
              if (mounted) setState(() => _resendLoading = false);
            },
          ),
        ],
      ),
    );
  }

}
