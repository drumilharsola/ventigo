import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../models/room_summary.dart';
import '../models/blocked_user.dart';
import '../services/avatars.dart';
import '../state/auth_provider.dart';
import '../widgets/pill.dart';
import '../widgets/flow_logo.dart';
import '../widgets/flow_button.dart';

String _formatDate(String? unixStr) {
  if (unixStr == null || unixStr.isEmpty) return '';
  final d = DateTime.fromMillisecondsSinceEpoch((int.tryParse(unixStr) ?? 0) * 1000);
  return '${_monthAbbr(d.month)} ${d.day}, ${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _monthAbbr(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

String _formatDuration(String? startedAt, String? endedAt) {
  if (startedAt == null || endedAt == null) return '15 min window';
  final diff = ((int.tryParse(endedAt) ?? 0) - (int.tryParse(startedAt) ?? 0)) ~/ 60;
  return '${diff.clamp(1, 999)} min';
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
    final ts = int.tryParse(room.startedAt.isNotEmpty ? room.startedAt : room.matchedAt) ?? 0;
    if (existing != null) {
      final existTs = int.tryParse(existing.latest.startedAt.isNotEmpty ? existing.latest.startedAt : existing.latest.matchedAt) ?? 0;
      grouped[key] = _GroupedRoom(ts > existTs ? room : existing.latest, existing.count + 1);
    } else {
      grouped[key] = _GroupedRoom(room, 1);
    }
  }
  return grouped.values.toList();
}

class HistoryScreen extends ConsumerStatefulWidget {
  final String? tab;
  const HistoryScreen({super.key, this.tab});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<RoomSummary> _rooms = [];
  List<BlockedUser> _blocked = [];
  bool _loading = true;
  String? _unblocking;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.tab == 'blocked' ? 1 : 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final roomsFuture = ref.read(apiClientProvider).getChatRooms(token);
      final blockedFuture = ref.read(apiClientProvider).getBlockedUsers(token);
      final results = await Future.wait([roomsFuture, blockedFuture]);
      if (!mounted) return;
      setState(() {
        _rooms = results[0] as List<RoomSummary>;
        _blocked = results[1] as List<BlockedUser>;
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handleUnblock(String peerSessionId) async {
    final token = ref.read(authProvider).token;
    if (token == null || _unblocking != null) return;
    setState(() => _unblocking = peerSessionId);
    try {
      await ref.read(apiClientProvider).unblockUser(token, peerSessionId);
      setState(() => _blocked = _blocked.where((u) => u.peerSessionId != peerSessionId).toList());
    } catch (_) {}
    if (mounted) setState(() => _unblocking = null);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupRoomsByPeer(_rooms);

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.snow.withValues(alpha: 0.8),
        elevation: 0,
        title: const FlowLogo(dark: true),
        actions: [
          TextButton(
            onPressed: () => context.go('/lobby'),
            child: Text('← Lobby', style: AppTypography.ui(fontSize: 13, color: AppColors.slate)),
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.ink,
          unselectedLabelColor: AppColors.slate,
          indicatorColor: AppColors.accent,
          labelStyle: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Conversations${grouped.isNotEmpty ? ' · ${grouped.length}' : ''}'),
            Tab(text: 'Blocked${_blocked.isNotEmpty ? ' · ${_blocked.length}' : ''}'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _chatTab(grouped),
                _blockedTab(),
              ],
            ),
    );
  }

  Widget _chatTab(List<_GroupedRoom> grouped) {
    if (grouped.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(borderRadius: AppRadii.lgAll, border: Border.all(color: Colors.black12), color: Colors.white),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('No conversations yet.', style: AppTypography.ui(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.charcoal)),
            const SizedBox(height: 8),
            Text('Your sessions will appear here after you connect with someone.', style: AppTypography.body(fontSize: 13, color: AppColors.slate), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FlowButton(label: 'Go to lobby', onPressed: () => context.go('/lobby')),
          ]),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: grouped.length,
      separatorBuilder: (_, __) => Divider(color: Colors.black.withValues(alpha: 0.07), height: 1),
      itemBuilder: (_, i) {
        final g = grouped[i];
        final r = g.latest;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                child: Text((i + 1).toString().padLeft(2, '0'), style: AppTypography.ui(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mist)),
              ),
              ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl(r.peerAvatarId, size: 88), width: 44, height: 44)),
            ],
          ),
          title: Text(r.peerUsername, style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
          subtitle: Text(
            g.count == 1 ? _formatDate(r.startedAt.isNotEmpty ? r.startedAt : r.matchedAt) : '${g.count} sessions',
            style: AppTypography.body(fontSize: 12, color: AppColors.slate),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (r.status == 'active') const Pill(text: 'Live', variant: PillVariant.success, showDot: true)
              else Text('Ended', style: AppTypography.body(fontSize: 12, color: AppColors.mist)),
              const SizedBox(height: 4),
              Text(
                r.status == 'active' ? 'Open now' : _formatDuration(r.startedAt.isNotEmpty ? r.startedAt : r.matchedAt, r.endedAt),
                style: AppTypography.body(fontSize: 11, color: AppColors.slate),
              ),
            ],
          ),
          onTap: () {
            final params = 'room_id=${Uri.encodeComponent(r.roomId)}${r.peerSessionId.isNotEmpty ? "&peer_session_id=${Uri.encodeComponent(r.peerSessionId)}" : ""}';
            context.go('/chat?$params');
          },
        );
      },
    );
  }

  Widget _blockedTab() {
    if (_blocked.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(borderRadius: AppRadii.lgAll, border: Border.all(color: Colors.black12), color: Colors.white),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('No blocked users.', style: AppTypography.ui(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.charcoal)),
            const SizedBox(height: 8),
            Text("People you block won't match with you or appear on the board.", style: AppTypography.body(fontSize: 13, color: AppColors.slate), textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: _blocked.length,
      itemBuilder: (_, i) {
        final u = _blocked[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: AppRadii.mdAll, color: Colors.white, border: Border.all(color: Colors.black.withValues(alpha: 0.06))),
          child: Row(
            children: [
              ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl(u.avatarId, size: 64), width: 32, height: 32)),
              const SizedBox(width: 10),
              Expanded(child: Text(u.username.isNotEmpty ? u.username : 'Unknown', style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink))),
              FlowButton(
                label: _unblocking == u.peerSessionId ? '…' : 'Unblock',
                variant: FlowButtonVariant.ghost,
                size: FlowButtonSize.sm,
                onPressed: _unblocking == u.peerSessionId ? null : () => _handleUnblock(u.peerSessionId),
              ),
            ],
          ),
        );
      },
    );
  }
}
