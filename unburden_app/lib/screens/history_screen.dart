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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final rooms = await ref.read(apiClientProvider).getChatRooms(token);
      if (mounted) setState(() { _rooms = rooms; _loading = false; });
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
        title: Text('Conversations', style: AppTypography.title(fontSize: 20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
