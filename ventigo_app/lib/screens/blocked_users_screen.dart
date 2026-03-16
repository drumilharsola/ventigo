import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/blocked_user.dart';
import '../services/avatars.dart';
import '../state/auth_provider.dart';
import '../utils/time_helpers.dart';
import '../widgets/flow_button.dart';
import '../widgets/skeleton.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  List<BlockedUser> _blockedUsers = [];
  bool _loading = true;
  String? _error;
  String? _unblockingId;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final blockedUsers = await ref.read(apiClientProvider).getBlockedUsers(token);
      if (mounted) {
        setState(() {
          _blockedUsers = blockedUsers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _unblock(String sessionId) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _unblockingId = sessionId);
    try {
      await ref.read(apiClientProvider).unblockUser(token, sessionId);
      if (mounted) {
        setState(() {
          _blockedUsers = _blockedUsers.where((user) => user.sessionId != sessionId).toList();
          _unblockingId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _unblockingId = null;
          _error = e.toString();
        });
      }
    }
  }

  String _formatBlockedAt(String raw) {
    final timestamp = int.tryParse(raw);
    if (timestamp == null || timestamp <= 0) return 'Recently';
    return formatDate(parseTs(raw));
  }

  Widget _buildBlockedUserTile(BlockedUser user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: warmShadow(blur: 18, opacity: 0.08),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: CachedNetworkImage(
              imageUrl: avatarUrl(user.avatarId, size: 72),
              width: 44,
              height: 44,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username.isEmpty ? 'Unknown user' : user.username,
                  style: AppTypography.ui(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Blocked on ${_formatBlockedAt(user.blockedAt)}',
                  style: AppTypography.body(fontSize: 12, color: AppColors.slate),
                ),
              ],
            ),
          ),
          FlowButton(
            label: _unblockingId == user.sessionId ? 'Unblocking...' : 'Unblock',
            variant: FlowButtonVariant.ghost,
            size: FlowButtonSize.sm,
            loading: _unblockingId == user.sessionId,
            onPressed: _unblockingId != null ? null : () => _unblock(user.sessionId),
          ),
        ],
      ),
    );
  }

  Widget _buildListContent() {
    if (_error != null && _blockedUsers.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 14)),
        ],
      );
    }
    if (_blockedUsers.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'No blocked users.',
            style: AppTypography.title(fontSize: 20, color: AppColors.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'People you block will appear here, and you can unblock them anytime.',
            style: AppTypography.body(fontSize: 14, color: AppColors.slate),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _blockedUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _buildBlockedUserTile(_blockedUsers[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(title: Semantics(header: true, child: Text('Blocked users', style: AppTypography.title(fontSize: 22)))),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBlockedUsers,
          child: _loading
              ? SkeletonShimmer(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: List.generate(3, (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: SkeletonListTile(),
                    )),
                  ),
                )
              : _buildListContent(),
        ),
      ),
    );
  }
}