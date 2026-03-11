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
import '../widgets/flow_logo.dart';
import '../widgets/flow_button.dart';
import '../widgets/pill.dart';
import '../widgets/timer_widget.dart';

// ── Helpers ──

String _timeAgo(String postedAt) {
  final secs = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - (int.tryParse(postedAt) ?? 0);
  if (secs < 60) return 'just now';
  if (secs < 3600) return '${secs ~/ 60}m ago';
  return '${secs ~/ 3600}h ago';
}

class _GroupedRoom {
  final RoomSummary latest;
  final int count;
  _GroupedRoom(this.latest, this.count);
}

List<_GroupedRoom> _groupRoomsByPeer(List<RoomSummary> rooms) {
  final grouped = <String, _GroupedRoom>{};
  for (final room in rooms) {
    final key = room.peerSessionId.isNotEmpty ? room.peerSessionId : room.peerUsername.isNotEmpty ? room.peerUsername : room.roomId;
    final existing = grouped[key];
    if (existing != null) {
      final existTs = int.tryParse(existing.latest.startedAt.isNotEmpty ? existing.latest.startedAt : existing.latest.matchedAt) ?? 0;
      final newTs = int.tryParse(room.startedAt.isNotEmpty ? room.startedAt : room.matchedAt) ?? 0;
      grouped[key] = _GroupedRoom(newTs > existTs ? room : existing.latest, existing.count + 1);
    } else {
      grouped[key] = _GroupedRoom(room, 1);
    }
  }
  return grouped.values.toList();
}

// ── Screen ──

class LobbyScreen extends ConsumerStatefulWidget {
  final String? requestId;
  const LobbyScreen({super.key, this.requestId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  List<SpeakerRequest> _board = [];
  List<RoomSummary> _rooms = [];
  String? _accepting;
  String _error = '';
  bool _ventLoading = false;
  bool _refreshing = false;
  String? _pendingRequestId;
  int? _pendingRemaining;
  bool _resendLoading = false;
  bool _resendDone = false;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Timer? _roomSyncTimer;

  @override
  void initState() {
    super.initState();
    _pendingRequestId = widget.requestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncBoard();
      _syncRooms();
      _connectWs();
      _roomSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) => _syncRooms());
      if (_pendingRequestId != null) _syncPendingRequest();
    });
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
        _pendingRequestId = res.myRequestId;
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

  Future<void> _syncPendingRequest() async {
    final token = _token;
    final rid = _pendingRequestId;
    if (token == null || rid == null) return;
    try {
      final req = await ref.read(apiClientProvider).getSpeakerRequest(token, rid);
      if (!mounted) return;
      if (req.status == 'matched' && req.roomId != null) {
        setState(() { _pendingRequestId = null; _pendingRemaining = null; });
        context.go('/chat?room_id=${Uri.encodeComponent(req.roomId!)}');
        return;
      }
      if (req.postedAt == null) {
        setState(() { _pendingRequestId = null; _pendingRemaining = null; });
        return;
      }
      final elapsed = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - (int.tryParse(req.postedAt!) ?? 0);
      setState(() => _pendingRemaining = (300 - elapsed).clamp(0, 300));
    } catch (_) {
      if (mounted) setState(() { _pendingRequestId = null; _pendingRemaining = null; });
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

        if (event == 'error' && msg['detail'] == 'token_invalid') {
          _ws?.sink.close();
          ref.read(authProvider.notifier).clear();
          if (mounted) context.go('/verify');
          return;
        }
        if (event == 'board_state') {
          final list = (msg['requests'] as List?)?.map((e) => SpeakerRequest.fromJson(e as Map<String, dynamic>)).toList() ?? [];
          setState(() {
            _board = _filterOwn(list);
            _pendingRequestId = msg['my_request_id'] as String?;
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

  Future<void> _handleVent() async {
    final token = _token;
    if (token == null) return;
    setState(() { _error = ''; _ventLoading = true; });
    try {
      final res = await ref.read(apiClientProvider).postSpeak(token);
      _ws?.sink.close();
      if (mounted) context.go('/waiting?request_id=${Uri.encodeComponent(res.requestId)}');
    } on AuthException {
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go('/verify');
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _ventLoading = false; });
    }
  }

  Future<void> _handleAccept(String requestId) async {
    final token = _token;
    if (token == null) return;
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

  Future<void> _handleCancelPending() async {
    final token = _token;
    if (token == null) return;
    try { await ref.read(apiClientProvider).cancelSpeak(token); } catch (_) {}
    setState(() { _pendingRequestId = null; _pendingRemaining = null; _error = ''; });
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
                  const SizedBox(width: 8),
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

                    // Listen card
                    _listenCard(auth),
                    const SizedBox(height: 14),

                    // Board
                    _boardSection(auth),
                    const SizedBox(height: 28),

                    // Chat history sidebar (inline on mobile)
                    _historySection(groupedRooms),
                  ]),
                ),
              ),
            ],
          ),

          // Pending request toast
          if (_pendingRequestId != null && _pendingRemaining != null && _pendingRemaining! > 0)
            _pendingToast(),
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
      child: Text(_error, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
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
            color: AppColors.ink,
            borderRadius: AppRadii.lgAll,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 28, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent)),
                const SizedBox(width: 8),
                const Pill(text: 'I need to vent', variant: PillVariant.accent),
              ]),
              const SizedBox(height: 14),
              Text(_ventLoading ? 'Finding your space…' : 'Let it out.', style: AppTypography.title(fontSize: 18, color: Colors.white)),
              const SizedBox(height: 6),
              Text('Open a private room and wait for one good listener to show up.', style: AppTypography.body(fontSize: 13, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listenCard(AuthState auth) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: Colors.black.withValues(alpha: 0.07), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Pill(text: 'I want to listen', variant: PillVariant.plain),
                const SizedBox(height: 12),
                Text('Be present.', style: AppTypography.title(fontSize: 18, color: AppColors.ink)),
                const SizedBox(height: 6),
                Text('Pick someone below, then enter one calm anonymous conversation.', style: AppTypography.body(fontSize: 13, color: AppColors.slate)),
              ]),
              FlowButton(
                label: _refreshing ? 'Refreshing…' : 'Reload',
                variant: FlowButtonVariant.ghost,
                size: FlowButtonSize.sm,
                onPressed: _refreshing ? null : () async {
                  setState(() => _refreshing = true);
                  await _syncBoard();
                  if (mounted) setState(() => _refreshing = false);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _board.isNotEmpty ? '${_board.length} ${_board.length == 1 ? "person" : "people"} want to be heard' : 'no one venting right now',
            style: AppTypography.label(color: AppColors.slate),
          ),
          if (auth.emailVerified != true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Locked until your email is verified.', style: AppTypography.body(fontSize: 12, color: AppColors.danger)),
            ),
        ],
      ),
    );
  }

  Widget _boardSection(AuthState auth) {
    if (!auth.emailVerified! && _board.isEmpty) return const SizedBox.shrink();

    if (auth.emailVerified != true) {
      return _emailVerifyBanner();
    }

    if (_board.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          borderRadius: AppRadii.mdAll,
          border: Border.all(color: Colors.black12, style: BorderStyle.solid),
          color: Colors.white,
        ),
        child: Column(
          children: [
            Text('All quiet right now.', style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.charcoal)),
            const SizedBox(height: 6),
            Text('Stay here and new requests will appear automatically.', style: AppTypography.body(fontSize: 13, color: AppColors.slate)),
          ],
        ),
      );
    }

    return Column(
      children: _board.map((req) => _VentCard(
        req: req,
        accepting: _accepting == req.requestId,
        locked: auth.emailVerified != true,
        onAccept: () => _handleAccept(req.requestId),
      )).toList(),
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
          Expanded(child: Text('🔒 Verify your email to answer requests.', style: AppTypography.body(fontSize: 13, color: AppColors.slate))),
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

  Widget _historySection(List<_GroupedRoom> grouped) {
    if (grouped.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(borderRadius: AppRadii.lgAll, color: Colors.white, border: Border.all(color: Colors.black.withValues(alpha: 0.08))),
        child: Column(children: [
          Text('No chat history yet.', style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.charcoal)),
          const SizedBox(height: 6),
          Text('Your recent connections will appear here for 7 days.', style: AppTypography.body(fontSize: 12, color: AppColors.slate)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(borderRadius: AppRadii.lgAll, color: Colors.white.withValues(alpha: 0.8), border: Border.all(color: Colors.black.withValues(alpha: 0.08))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CHAT HISTORY', style: AppTypography.label(color: AppColors.slate)),
              if (grouped.length > 2)
                TextButton(onPressed: () => context.go('/history'), child: Text('View all', style: AppTypography.ui(fontSize: 12, color: AppColors.slate))),
            ],
          ),
          const SizedBox(height: 12),
          ...grouped.take(2).map((g) => _historyTile(g)),
        ],
      ),
    );
  }

  Widget _historyTile(_GroupedRoom g) {
    final r = g.latest;
    return GestureDetector(
      onTap: () {
        final params = 'room_id=${Uri.encodeComponent(r.roomId)}${r.peerSessionId.isNotEmpty ? "&peer_session_id=${Uri.encodeComponent(r.peerSessionId)}" : ""}';
        context.go('/chat?$params');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl(r.peerAvatarId, size: 68), width: 34, height: 34)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.peerUsername, style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
              Text(g.count == 1 ? '1 session' : '${g.count} sessions', style: AppTypography.body(fontSize: 11, color: AppColors.slate)),
            ])),
            if (r.status == 'active')
              Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }

  Widget _pendingToast() {
    return Positioned(
      right: 20,
      bottom: 20,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.92),
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 40, offset: const Offset(0, 18))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Waiting for someone to join', style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Most connections happen sooner.', style: AppTypography.body(fontSize: 12, color: AppColors.slate)),
                ]),
                FlowButton(
                  label: 'Expand',
                  variant: FlowButtonVariant.ghost,
                  size: FlowButtonSize.sm,
                  onPressed: () => context.go('/waiting?request_id=${Uri.encodeComponent(_pendingRequestId!)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TimerWidget(remainingSeconds: _pendingRemaining!, onEnd: _handleCancelPending),
                FlowButton(label: 'Cancel', variant: FlowButtonVariant.ghost, size: FlowButtonSize.sm, onPressed: _handleCancelPending),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vent card ──

class _VentCard extends StatelessWidget {
  final SpeakerRequest req;
  final bool accepting;
  final bool locked;
  final VoidCallback onAccept;

  const _VentCard({required this.req, required this.accepting, required this.locked, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl(req.avatarId, size: 84), width: 42, height: 42)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(req.username, style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
            Text('needs to be heard · ${_timeAgo(req.postedAt)}', style: AppTypography.body(fontSize: 12, color: AppColors.slate)),
            if (locked) Text('Verify your email to answer this request.', style: AppTypography.body(fontSize: 11, color: AppColors.slate)),
          ])),
          FlowButton(
            label: locked ? 'Locked' : accepting ? '…' : 'Show up',
            size: FlowButtonSize.sm,
            onPressed: accepting || locked ? null : onAccept,
          ),
        ],
      ),
    );
  }
}
