import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/room_summary.dart';
import '../services/api_client.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        title: Text('History', style: AppTypography.title(fontSize: 22)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/lobby'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? Center(child: Text('No conversations yet.', style: AppTypography.body()))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rooms.length,
                  itemBuilder: (_, i) {
                    final r = _rooms[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(avatarUrl(r.peerAvatarId, size: 80)),
                      ),
                      title: Text(r.peerUsername, style: AppTypography.ui(fontWeight: FontWeight.w600)),
                      subtitle: Text(r.role, style: AppTypography.body(fontSize: 12)),
                      trailing: Text(r.status, style: AppTypography.label()),
                      onTap: () => context.go('/chat?room_id=${Uri.encodeComponent(r.roomId)}'),
                    );
                  },
                ),
    );
  }
}
