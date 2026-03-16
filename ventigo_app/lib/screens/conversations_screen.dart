import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import '../config/theme.dart';
import '../models/room_summary.dart';
import '../models/speaker_request.dart';
import '../services/api_client.dart';
import '../services/avatars.dart';
import '../state/auth_provider.dart';
import '../state/pending_wait_provider.dart';
import '../widgets/flow_button.dart';
import '../widgets/timer_widget.dart';
import '../widgets/breathing_circle.dart';
import '../utils/time_helpers.dart';
import '../config/routes.dart' show kPathVerify;

// -- Helpers --

@visibleForTesting
int convRoomTs(RoomSummary r) =>
    int.tryParse(r.startedAt.isNotEmpty ? r.startedAt : r.matchedAt) ?? 0;

@visibleForTesting
class PeerGroup {
  final String peerSessionId;
  final String peerUsername;
  final int peerAvatarId;
  final List<RoomSummary> rooms;
  bool get hasActive => rooms.any((r) => r.status == 'active');
  RoomSummary get latest => rooms.first;

  PeerGroup({
    required this.peerSessionId,
    required this.peerUsername,
    required this.peerAvatarId,
    required this.rooms,
  });
}

@visibleForTesting
List<PeerGroup> groupByPeer(List<RoomSummary> rooms) {
  final map = <String, List<RoomSummary>>{};
  for (final r in rooms) {
    final key = r.peerSessionId.isNotEmpty ? r.peerSessionId : r.peerUsername;
    (map[key] ??= []).add(r);
  }
  for (final list in map.values) {
    list.sort((a, b) => convRoomTs(b).compareTo(convRoomTs(a)));
  }
  final groups = map.entries.map((e) {
    final latest = e.value.first;
    return PeerGroup(
      peerSessionId: latest.peerSessionId,
      peerUsername: latest.peerUsername,
      peerAvatarId: latest.peerAvatarId,
      rooms: e.value,
    );
  }).toList();

  groups.sort((a, b) {
    if (a.hasActive != b.hasActive) return a.hasActive ? -1 : 1;
    return convRoomTs(b.latest).compareTo(convRoomTs(a.latest));
  });
  return groups;
}

// -- Screen --

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  List<RoomSummary> _rooms = [];
  List<SpeakerRequest> _board = [];
  Timer? _roomSyncTimer;
  bool _ventLoading = false;
  String _error = '';
  int _appreciationCount = 0;
  String? _selectedTopic;

  static const _ventTopics = [
    '😔 Feeling low',
    '😰 Anxiety',
    '💔 Heartbreak',
    '😤 Anger / Frustration',
    '🏠 Family issues',
    '📚 Academic stress',
    '💼 Work pressure',
    '🤝 Friendship drama',
    '🫠 Burnout',
    '🌀 Just need to talk',
  ];

  // Board WS (for listener tab)
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;

  // Venter bottom sheet controller
  final DraggableScrollableController _venterSheetCtrl = DraggableScrollableController();
  final DraggableScrollableController _listenerSheetCtrl = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncRooms();
      _syncBoard();
      _connectBoardWs();
      _refreshAppreciationCount();
      _roomSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _syncRooms();
        _refreshAppreciationCount();
      });
      // Listen for match events
      ref.listenManual(pendingWaitProvider, (_, next) {
        if (next.matchedRoomId != null && mounted) {
          ref.read(pendingWaitProvider.notifier).clearMatch();
          context.push('/chat?room_id=${Uri.encodeComponent(next.matchedRoomId!)}');
        }
      });
    });
  }

  /// Sync appreciation count from the server to check listener eligibility.
  Future<void> _refreshAppreciationCount() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final me = await ref.read(apiClientProvider).getMe(token);
      if (mounted) setState(() => _appreciationCount = me.appreciationCount);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _roomSyncTimer?.cancel();
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    _venterSheetCtrl.dispose();
    _listenerSheetCtrl.dispose();
    super.dispose();
  }

  String? get _token => ref.read(authProvider).token;
  String? get _sessionId => ref.read(authProvider).sessionId;

  Future<void> _syncRooms() async {
    final token = _token;
    if (token == null) return;
    try {
      final rooms = await ref.read(apiClientProvider).getChatRooms(token);
      if (mounted && rooms.length != _rooms.length) setState(() => _rooms = rooms);
    } catch (_) {}
  }

  Future<void> _syncBoard() async {
    final token = _token;
    if (token == null) return;
    try {
      final res = await ref.read(apiClientProvider).getBoard(token);
      if (mounted) setState(() => _board = _filterOwn(res.requests));
    } catch (_) {}
  }

  void _handleBoardWsEvent(Map<String, dynamic> msg) {
    final event = msg['event'] as String?;

    if (event == 'error' && (msg['detail'] == 'token_invalid' || msg['detail'] == 'session_replaced')) {
      _ws?.sink.close();
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go(kPathVerify);
      return;
    }
    if (event == 'board_state') {
      final list = (msg['requests'] as List?)
              ?.map((e) => SpeakerRequest.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
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
          SpeakerRequest(
            requestId: id,
            sessionId: '',
            username: msg['username'] as String? ?? '',
            avatarId: (msg['avatar_id'] ?? 0).toString(),
            postedAt: msg['posted_at'] as String? ?? '',
            topic: msg['topic'] as String? ?? '',
          ),
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
      if (mounted) context.push('/chat?room_id=${Uri.encodeComponent(msg['room_id'] as String)}');
    }
  }

  void _connectBoardWs() {
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
        _reconnectTimer = Timer(const Duration(seconds: 3), _connectBoardWs);
      },
    );
  }

  List<SpeakerRequest> _filterOwn(List<SpeakerRequest> list) {
    final sid = _sessionId;
    if (sid == null) return list;
    return list.where((r) => r.sessionId != sid).toList();
  }

  Future<void> _toggleSheet(
    DraggableScrollableController controller, {
    required double collapsed,
    required double expanded,
  }) async {
    if (!controller.isAttached) return;
    final midpoint = (collapsed + expanded) / 2;
    final target = controller.size > midpoint ? collapsed : expanded;
    await controller.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleVent() async {
    final wait = ref.read(pendingWaitProvider);
    // Already waiting - just expand the sheet
    if (wait.isWaiting) {
      _venterSheetCtrl.animateTo(0.7,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    final token = _token;
    if (token == null) return;
    setState(() {
      _error = '';
      _ventLoading = true;
    });
    try {
      final res = await ref.read(apiClientProvider).postSpeak(token, topic: _selectedTopic ?? '');
      ref.read(pendingWaitProvider.notifier).startWaiting(res.requestId);
      if (mounted) {
        _venterSheetCtrl.animateTo(0.7,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } on AuthException {
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go(kPathVerify);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _ventLoading = false);
    }
  }

  Future<void> _handleAccept(String requestId) async {
    final token = _token;
    if (token == null) return;
    setState(() => _error = '');
    try {
      final res = await ref.read(apiClientProvider).acceptSpeaker(token, requestId);
      if (mounted) {
        setState(() => _board = _board.where((r) => r.requestId != requestId).toList());
        context.push('/chat?room_id=${Uri.encodeComponent(res.roomId)}');
      }
    } on AuthException {
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go(kPathVerify);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final venterRooms = _rooms.where((r) => r.role == 'speaker').toList();
    final listenerRooms = _rooms.where((r) => r.role == 'listener').toList();

    return Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(
        child: Column(
          children: [
            // Tab bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.snow,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chats', style: AppTypography.title(fontSize: 24)),
                  const SizedBox(height: 12),
                  Row(
                children: [
                  Expanded(
                    child: TabBar(
                controller: _tabCtrl,
                labelColor: AppColors.ink,
                unselectedLabelColor: AppColors.slate,
                indicatorColor: AppColors.accent,
                indicatorWeight: 2.5,
                labelStyle: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: AppTypography.ui(fontSize: 14),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎤', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        const Flexible(child: Text('Venter', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🤝', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        const Flexible(child: Text('Listener', overflow: TextOverflow.ellipsis)),
                        if (_board.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${_board.length}',
                                style: AppTypography.ui(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
                  ),
                ],
              ),
                ],
              ),
            ),

            // Error banner
            if (_error.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppColors.danger.withValues(alpha: 0.08),
                child: Text(_error, style: TextStyle(color: AppColors.danger, fontSize: 13)),
              ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _venterTab(venterRooms),
                  _listenerTab(listenerRooms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Venter Tab --

  Widget _venterTab(List<RoomSummary> rooms) {
    final groups = groupByPeer(rooms);
    final wait = ref.watch(pendingWaitProvider);

    return Stack(
      children: [
        // Conversation list
        groups.isEmpty && !wait.isWaiting
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 140),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('No conversations yet', style: AppTypography.title(fontSize: 20, color: AppColors.charcoal)),
                    const SizedBox(height: 8),
                    Text('Your vent sessions will appear here.',
                        style: AppTypography.body(fontSize: 14, color: AppColors.slate), textAlign: TextAlign.center),
                  ]),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 160),
                itemCount: groups.length,
                itemBuilder: (_, i) => _PeerTile(
                  group: groups[i],
                  roleBadge: '🎤',
                  onTap: () => context.push(
                    '/unified-chat?peer_session_id=${Uri.encodeComponent(groups[i].peerSessionId)}&peer_username=${Uri.encodeComponent(groups[i].peerUsername)}',
                  ),
                ),
              ),

        // Draggable bottom sheet
        DraggableScrollableSheet(
          controller: _venterSheetCtrl,
          initialChildSize: 0.12,
          minChildSize: 0.12,
          maxChildSize: 0.7,
          snap: true,
          snapSizes: const [0.12, 0.7],
          builder: (sheetCtx, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -4))],
              ),
              child: CustomScrollView(
                controller: scrollCtrl,
                slivers: [
                  // Grab handle
                  SliverToBoxAdapter(
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: () => _toggleSheet(
                          _venterSheetCtrl,
                          collapsed: 0.12,
                          expanded: 0.7,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.mist,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: !wait.isWaiting
                          ? _buildTopicAndVentButton()
                          : _buildWaitingState(wait),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // -- Extracted sheet widgets --

  Widget _buildTopicChip(String topic) {
    final sel = _selectedTopic == topic;
    return GestureDetector(
      onTap: () => setState(() => _selectedTopic = sel ? null : topic),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.accent.withValues(alpha: 0.12) : AppColors.snow,
          borderRadius: AppRadii.fullAll,
          border: Border.all(color: sel ? AppColors.accent : AppColors.border),
        ),
        child: Text(topic, style: AppTypography.ui(
          fontSize: 12,
          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
          color: sel ? AppColors.accent : AppColors.slate,
        )),
      ),
    );
  }

  Widget _buildTopicAndVentButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What do you want to talk about?',
            style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _ventTopics.map((t) => _buildTopicChip(t)).toList(),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _ventLoading ? null : _handleVent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.venterPrimary, AppColors.accentHover],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadii.lgAll,
            ),
            child: Row(
              children: [
                const Text('🎤', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _ventLoading ? 'Finding your space…' : 'I need to vent',
                        style: AppTypography.title(fontSize: 17, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text('Start an anonymous conversation',
                          style: AppTypography.body(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                if (_ventLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  )
                else
                  Icon(Icons.arrow_forward_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingState(PendingWaitState wait) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: AppRadii.lgAll,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Finding someone to listen…',
                    style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              TimerWidget(
                remainingSeconds: wait.remaining,
                onEnd: () => ref.read(pendingWaitProvider.notifier).cancel(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const BreathingCircle(size: 48),
          const SizedBox(height: 8),
          FlowButton(
            label: 'Cancel',
            variant: FlowButtonVariant.ghost,
            size: FlowButtonSize.sm,
            onPressed: () => ref.read(pendingWaitProvider.notifier).cancel(),
          ),
        ],
      ),
    );
  }

  // -- Listener Tab --

  Widget _listenerTab(List<RoomSummary> rooms) {
    final groups = groupByPeer(rooms);
    final auth = ref.watch(authProvider);
    final eligible = _appreciationCount >= 15;

    return Stack(
      children: [
        // Conversation list
        groups.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 140),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('No conversations yet', style: AppTypography.title(fontSize: 20, color: AppColors.charcoal)),
                    const SizedBox(height: 8),
                    Text('Listen sessions will appear here.',
                        style: AppTypography.body(fontSize: 14, color: AppColors.slate), textAlign: TextAlign.center),
                  ]),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 160),
                itemCount: groups.length,
                itemBuilder: (_, i) => _PeerTile(
                  group: groups[i],
                  roleBadge: '🤝',
                  onTap: () => context.push(
                    '/unified-chat?peer_session_id=${Uri.encodeComponent(groups[i].peerSessionId)}&peer_username=${Uri.encodeComponent(groups[i].peerUsername)}',
                  ),
                ),
              ),

        // Draggable bottom sheet - listener requests board
        DraggableScrollableSheet(
          controller: _listenerSheetCtrl,
          initialChildSize: 0.12,
          minChildSize: 0.12,
          maxChildSize: 0.6,
          snap: true,
          snapSizes: const [0.12, 0.6],
          builder: (sheetCtx, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -4))],
              ),
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: _buildListenerSheetContent(eligible),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildListenerSheetContent(bool eligible) {
    return Column(
      children: [
        // Grab handle
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => _toggleSheet(
              _listenerSheetCtrl,
              collapsed: 0.12,
              expanded: 0.6,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text('🤝', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _board.isEmpty
                      ? 'All is quiet right now'
                      : '${_board.length} ${_board.length == 1 ? "person" : "people"} need to be heard',
                  style: AppTypography.title(fontSize: 16, color: AppColors.ink),
                ),
              ),
              IconButton(
                onPressed: () {
                  _syncBoard();
                  _syncRooms();
                },
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppColors.slate,
                tooltip: 'Refresh',
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              if (!eligible)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('🔒', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        if (!eligible) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Text('You need 15 appreciations to listen ($_appreciationCount/15).',
                style: AppTypography.body(fontSize: 13, color: AppColors.danger)),
          ),
        ],
        const SizedBox(height: 10),
        if (_board.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Stay here - new requests appear automatically.',
                style: AppTypography.body(fontSize: 13, color: AppColors.slate)),
          )
        else
          ...List.generate(_board.length, (i) {
            final req = _board[i];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.snow,
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl(req.avatarId, size: 72),
                      width: 36,
                      height: 36,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(req.username,
                            style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                        if (req.topic.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(req.topic,
                                style: AppTypography.body(fontSize: 12, color: AppColors.accent)),
                          ),
                        Text(timeAgo(req.postedAt),
                            style: AppTypography.micro(fontSize: 11, color: AppColors.slate)),
                      ],
                    ),
                  ),
                  FlowButton(
                    label: 'Show up',
                    size: FlowButtonSize.sm,
                    onPressed: !eligible ? null : () => _handleAccept(req.requestId),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 20),
      ],
    );
  }
}

// -- Peer conversation tile --

class _PeerTile extends StatelessWidget {
  final PeerGroup group;
  final String roleBadge;
  final VoidCallback onTap;

  const _PeerTile({required this.group, required this.roleBadge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final latest = group.latest;
    final dt = _parseTs(latest.startedAt.isNotEmpty ? latest.startedAt : latest.matchedAt);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // Avatar with active dot
            Stack(
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl(group.peerAvatarId, size: 96),
                    width: 48,
                    height: 48,
                  ),
                ),
                if (group.hasActive)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(group.peerUsername,
                            style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(roleBadge, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    group.hasActive
                        ? 'Live now'
                        : '${group.rooms.length} ${group.rooms.length == 1 ? "session" : "sessions"} · ${_formatDate(dt)}',
                    style: AppTypography.body(
                      fontSize: 12,
                      color: group.hasActive ? AppColors.success : AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),

            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.mist),
          ],
        ),
      ),
    );
  }

  DateTime _parseTs(String ts) {
    final epoch = int.tryParse(ts) ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM d').format(dt);
  }
}
