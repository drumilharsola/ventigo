import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

import '../services/avatars.dart';
import '../models/user_profile.dart';
import '../state/auth_provider.dart';
import '../utils/time_helpers.dart';
import '../widgets/flow_button.dart';

/// Peer profile modal - maps UserProfileModal.tsx.
class UserProfileModal extends ConsumerStatefulWidget {
  final String username;
  final String? peerSessionId;
  final String? roomId;
  final VoidCallback onClose;

  const UserProfileModal({
    super.key,
    required this.username,
    this.peerSessionId,
    this.roomId,
    required this.onClose,
  });

  @override
  ConsumerState<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends ConsumerState<UserProfileModal> {
  UserProfile? _profile;
  bool _loading = true;
  bool _blocking = false;
  bool _blocked = false;
  bool _confirmingBlock = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final token = ref.read(authProvider).token!;
      final p = await ref.read(apiClientProvider).getUserProfile(token, widget.username);
      if (mounted) setState(() { _profile = p; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _block() async {
    if (widget.peerSessionId == null || widget.peerSessionId!.isEmpty || _profile == null) {
      return;
    }
    setState(() {
      _blocking = true;
      _error = null;
    });
    try {
      final token = ref.read(authProvider).token!;
      await ref.read(apiClientProvider).blockUser(
        token,
        widget.peerSessionId!,
        _profile!.username,
        _profile!.avatarId,
      );
      if (mounted) {
        setState(() {
          _blocked = true;
          _blocking = false;
          _confirmingBlock = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _blocking = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadii.lgAll,
              border: Border.all(color: AppColors.border),
              boxShadow: warmShadow(blur: 32, opacity: 0.12),
            ),
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _profile == null
                    ? Text(_error ?? 'Could not load profile', style: AppTypography.body(color: AppColors.danger))
                    : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockSection(UserProfile p) {
    if (widget.peerSessionId == null || widget.peerSessionId!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        const SizedBox(height: 20),
        if (_confirmingBlock && !_blocked)
          Column(
            children: [
              Text(
                'Block ${p.username}?',
                style: AppTypography.ui(color: AppColors.danger),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FlowButton(
                    label: 'Cancel',
                    variant: FlowButtonVariant.ghost,
                    size: FlowButtonSize.sm,
                    onPressed: () => setState(() => _confirmingBlock = false),
                  ),
                  const SizedBox(width: 8),
                  FlowButton(
                    label: 'Block',
                    variant: FlowButtonVariant.danger,
                    size: FlowButtonSize.sm,
                    onPressed: _block,
                    loading: _blocking,
                  ),
                ],
              ),
            ],
          )
        else
          FlowButton(
            label: _blocked ? 'Blocked' : 'Block this person',
            variant: _blocked ? FlowButtonVariant.ghost : FlowButtonVariant.danger,
            size: FlowButtonSize.sm,
            onPressed: _blocked ? null : () => setState(() => _confirmingBlock = true),
          ),
      ],
    );
  }

  Widget _buildContent() {
    final p = _profile!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.full),
          child: CachedNetworkImage(
            imageUrl: avatarUrl(p.avatarId, size: 80),
            width: 80, height: 80,
            placeholder: (_, __) => Container(width: 80, height: 80, color: AppColors.card),
          ),
        ),
        const SizedBox(height: 14),
        Text(p.username, style: AppTypography.title(fontSize: 20)),
        if (p.memberSince.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Member since ${_formatTs(p.memberSince)}', style: AppTypography.label(color: AppColors.slate)),
        ],
        const SizedBox(height: 20),
        // Stats
        Column(
          children: [
            // Appreciation count (not tappable for peer profiles)
            Column(
              children: [
                Text(p.appreciationCount.toString(), style: AppTypography.title(fontSize: 24)),
                const SizedBox(height: 4),
                Text('Appreciations 💛', style: AppTypography.label(fontSize: 12, color: AppColors.slate)),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            // Vent / Listen row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat('Vent 🎤', p.speakCount),
                _stat('Support 🤝', p.listenCount),
              ],
            ),
          ],
        ),
        _buildBlockSection(p),
        if (_error != null && !_loading) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        FlowButton(label: 'Close', variant: FlowButtonVariant.ghost, size: FlowButtonSize.sm, onPressed: widget.onClose),
      ],
    );
  }

  Widget _stat(String label, int value) {
    return Column(
      children: [
        Text(value.toString(), style: AppTypography.title(fontSize: 22)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.label(fontSize: 10, color: AppColors.slate)),
      ],
    );
  }

  String _formatTs(String raw) => formatTimestamp(raw);
}
