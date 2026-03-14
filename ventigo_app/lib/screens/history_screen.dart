import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/room_summary.dart';
import '../services/avatars.dart';
import '../state/auth_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final String? tab;
  const HistoryScreen({super.key, this.tab});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<RoomSummary> _rooms = [];
  List<Map<String, dynamic>> _connections = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loading = true;
  String _tab = 'chat'; // chat | connections

  @override
  void initState() {
    super.initState();
    _tab = widget.tab == 'connections' ? 'connections' : 'chat';
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final rooms = await ref.read(apiClientProvider).getChatRooms(token);
      Map<String, dynamic>? conns;
      try {
        conns = await ref.read(apiClientProvider).getConnections(token);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _rooms = rooms;
          if (conns != null) {
            _connections = (conns['connections'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            _pendingRequests = (conns['pending_requests'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
    return DateFormat('MMM d, yyyy').format(dt);
  }

  String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);

  Widget _buildPendingRequestTile(Map<String, dynamic> req) {
    final peerUsername = req['peer_username'] as String? ?? 'Anonymous';
    final peerAvatarId = req['peer_avatar_id'] as int? ?? 0;
    final peerSessionId = req['peer_session_id'] as String? ?? '';
    return ListTile(
      leading: ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl(peerAvatarId, size: 72), width: 44, height: 44)),
      title: Text(peerUsername, style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text('Wants to connect', style: AppTypography.body(fontSize: 12, color: AppColors.slate)),
      trailing: FilledButton(
        onPressed: () async {
          final token = ref.read(authProvider).token;
          if (token == null) return;
          await ref.read(apiClientProvider).acceptConnectionRequest(token, peerSessionId);
          _load();
        },
        style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
        child: Text('Accept', style: AppTypography.ui(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.white)),
      ),
    );
  }

  Widget _buildConnectedUserTile(Map<String, dynamic> conn) {
    final peerUsername = conn['peer_username'] as String? ?? 'Anonymous';
    final peerAvatarId = conn['peer_avatar_id'] as int? ?? 0;
    final peerSessionId = conn['peer_session_id'] as String? ?? '';
    return ListTile(
      leading: ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl(peerAvatarId, size: 72), width: 44, height: 44)),
      title: Text(peerUsername, style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () async {
              final token = ref.read(authProvider).token;
              if (token == null) return;
              final roomId = await ref.read(apiClientProvider).directChat(token, peerSessionId);
              if (mounted) context.go('/chat?room_id=${Uri.encodeComponent(roomId)}');
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: Text('Chat', style: AppTypography.ui(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.white)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
            onPressed: () async {
              final token = ref.read(authProvider).token;
              if (token == null) return;
              await ref.read(apiClientProvider).removeConnection(token, peerSessionId);
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsTab() {
    if (_connections.isEmpty && _pendingRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🤝', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No connections yet', style: AppTypography.title(fontSize: 20, color: AppColors.charcoal)),
            const SizedBox(height: 8),
            Text('After a good chat, tap "Connect" to save that person.', style: AppTypography.body(fontSize: 14, color: AppColors.slate), textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_pendingRequests.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('PENDING REQUESTS', style: AppTypography.label(color: AppColors.accent)),
          ),
          ..._pendingRequests.map(_buildPendingRequestTile),
          const Divider(height: 24, indent: 20, endIndent: 20),
        ],
        if (_connections.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('CONNECTED', style: AppTypography.label(color: AppColors.slate)),
          ),
          ..._connections.map(_buildConnectedUserTile),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group rooms by date
    final sorted = List<RoomSummary>.from(_rooms)
      ..sort((a, b) {
        final aTs = int.tryParse(a.startedAt.isNotEmpty ? a.startedAt : a.matchedAt) ?? 0;
        final bTs = int.tryParse(b.startedAt.isNotEmpty ? b.startedAt : b.matchedAt) ?? 0;
        return bTs.compareTo(aTs); // newest first
      });

    // Active rooms on top
    final active = sorted.where((r) => r.status == 'active').toList();
    final ended = sorted.where((r) => r.status != 'active').toList();

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
        title: Text(_tab == 'connections' ? 'Connections' : 'Conversations', style: AppTypography.title(fontSize: 20)),
        actions: [
          TextButton(
            onPressed: () => setState(() => _tab = _tab == 'chat' ? 'connections' : 'chat'),
            child: Text(
              _tab == 'chat' ? 'Connections' : 'Chats',
              style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tab == 'connections'
              ? _buildConnectionsTab()
              : _rooms.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('💬', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text('No conversations yet', style: AppTypography.title(fontSize: 20, color: AppColors.charcoal)),
                      const SizedBox(height: 8),
                      Text('Your chats will appear here.', style: AppTypography.body(fontSize: 14, color: AppColors.slate), textAlign: TextAlign.center),
                    ]),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Active conversations section
                    if (active.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text('ACTIVE NOW', style: AppTypography.label(color: AppColors.accent)),
                      ),
                      ...active.map((r) => _ChatTile(room: r, isActive: true, onTap: () {
                        context.go('/chat?room_id=${Uri.encodeComponent(r.roomId)}');
                      })),
                      const Divider(height: 24, indent: 20, endIndent: 20),
                    ],

                    // Past conversations grouped by date
                    if (ended.isNotEmpty) ...[
                      ..._buildDateGrouped(ended),
                    ],
                  ],
                ),
    );
  }

  List<Widget> _buildDateGrouped(List<RoomSummary> rooms) {
    final widgets = <Widget>[];
    String? lastDate;

    for (final r in rooms) {
      final ts = r.startedAt.isNotEmpty ? r.startedAt : r.matchedAt;
      final dt = _parseTs(ts);
      final dateStr = _formatDate(dt);

      if (dateStr != lastDate) {
        lastDate = dateStr;
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(dateStr.toUpperCase(), style: AppTypography.label(color: AppColors.slate)),
        ));
      }

      widgets.add(_ChatTile(
        room: r,
        isActive: false,
        startTime: _formatTime(dt),
        endTime: r.endedAt.isNotEmpty ? _formatTime(_parseTs(r.endedAt)) : null,
        onTap: () {
          final params = 'room_id=${Uri.encodeComponent(r.roomId)}${r.peerSessionId.isNotEmpty ? "&peer_session_id=${Uri.encodeComponent(r.peerSessionId)}" : ""}';
          context.go('/chat?$params');
        },
      ));
    }

    return widgets;
  }
}

class _ChatTile extends StatelessWidget {
  final RoomSummary room;
  final bool isActive;
  final String? startTime;
  final String? endTime;
  final VoidCallback onTap;

  const _ChatTile({required this.room, required this.isActive, this.startTime, this.endTime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // Avatar with active indicator
            Stack(
              children: [
                ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl(room.peerAvatarId, size: 96), width: 48, height: 48)),
                if (isActive)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Name + status
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.peerUsername.isNotEmpty ? room.peerUsername : 'Anonymous',
                  style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                if (isActive)
                  Text('Live now', style: AppTypography.body(fontSize: 12, color: AppColors.accent))
                else
                  Row(children: [
                    if (startTime != null) ...[
                      Text('Started $startTime', style: AppTypography.body(fontSize: 12, color: AppColors.slate)),
                    ],
                    if (endTime != null) ...[
                      Text(' · Ended $endTime', style: AppTypography.body(fontSize: 12, color: AppColors.mist)),
                    ],
                  ]),
              ],
            )),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: room.role == 'venter'
                    ? AppColors.venterBubble
                    : AppColors.listenerBubble,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                room.role == 'venter' ? '🎤' : '🤝',
                style: const TextStyle(fontSize: 14),
              ),
            ),

            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.mist),
          ],
        ),
      ),
    );
  }
}
