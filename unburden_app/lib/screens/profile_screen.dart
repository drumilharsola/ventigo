import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

import '../services/avatars.dart';
import '../state/auth_provider.dart';
import '../widgets/flow_logo.dart';
import '../widgets/flow_button.dart';
import '../widgets/orb_background.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Setup
  DateTime? _dob;
  int _setupAvatarId = 0;
  bool _loading = false;
  String? _error;

  // View / edit
  bool _editing = false;
  int? _editAvatarId;
  bool _rerollName = false;
  bool _saving = false;
  String? _saveError;
  int _speakCount = 0;
  int _listenCount = 0;
  String _memberSince = '';
  bool _exporting = false;
  bool _showDeleteConfirm = false;
  bool _deleting = false;

  bool get _isSetup => !ref.read(authProvider).hasProfile;

  @override
  void initState() {
    super.initState();
    if (!_isSetup) _loadStats();
  }

  Future<void> _loadStats() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final me = await ref.read(apiClientProvider).getMe(token);
      setState(() {
        _speakCount = me.speakCount;
        _listenCount = me.listenCount;
        _memberSince = me.memberSince;
      });
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _handleSetup() async {
    if (_dob == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final token = ref.read(authProvider).token!;
      final dobStr = '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}';
      final res = await ref.read(apiClientProvider).setProfile(token, dob: dobStr, avatarId: _setupAvatarId);
      await ref.read(authProvider.notifier).setProfile(res.username, res.avatarId);
      if (mounted) context.go('/lobby');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSave() async {
    setState(() { _saving = true; _saveError = null; });
    try {
      final token = ref.read(authProvider).token!;
      final res = await ref.read(apiClientProvider).updateProfile(
        token,
        avatarId: _editAvatarId,
        rerollUsername: _rerollName ? true : null,
      );
      await ref.read(authProvider.notifier).setProfile(res.username, res.avatarId);
      setState(() { _editing = false; _rerollName = false; _editAvatarId = null; });
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleExport() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _exporting = true);
    try {
      final data = await ref.read(apiClientProvider).exportData(token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data exported: ${data.keys.length} sections')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export data')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _deleting = true);
    try {
      await ref.read(apiClientProvider).deleteAccount(token);
      await ref.read(authProvider.notifier).clear();
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) setState(() { _deleting = false; _showDeleteConfirm = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      body: Stack(
        children: [
          const OrbBackground(),
          SafeArea(
            child: _isSetup ? _setupView(wide) : _profileView(auth, wide),
          ),
        ],
      ),
    );
  }

  // ── Setup view ──
  Widget _setupView(bool wide) {
    final currentAvatar = getAvatar(_setupAvatarId);
    final avatarWidget = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: CachedNetworkImage(imageUrl: avatarUrl(currentAvatar, size: 120), width: 120, height: 120),
    );

    final formContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress
        Row(
          children: List.generate(3, (i) {
            return Expanded(
              child: Container(
                height: 2,
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                color: i <= 1 ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
              ),
            );
          }),
        ),
        const SizedBox(height: 48),
        Text('Set up\nyour profile.', style: AppTypography.heading()),
        const SizedBox(height: 32),

        // DOB
        Text('DATE OF BIRTH', style: AppTypography.label()),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: AppRadii.mdAll,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _dob != null
                  ? '${_dob!.day}/${_dob!.month}/${_dob!.year}'
                  : 'Tap to select',
              style: AppTypography.ui(color: _dob != null ? AppColors.white : AppColors.slate),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Avatar grid
        Text('CHOOSE YOUR AVATAR', style: AppTypography.label()),
        const SizedBox(height: 10),
        _avatarGrid(
          selected: _setupAvatarId,
          onSelect: (id) => setState(() => _setupAvatarId = id),
        ),
        const SizedBox(height: 24),

        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          const SizedBox(height: 12),
        ],

        FlowButton(
          label: _loading ? 'Saving…' : 'Continue →',
          onPressed: _dob != null && !_loading ? _handleSetup : null,
          expand: true,
          loading: _loading,
        ),
      ],
    );

    if (wide) {
      return Row(
        children: [
          Expanded(child: Center(child: avatarWidget)),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(64), child: formContent)),
        ],
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [avatarWidget, const SizedBox(height: 24), formContent]),
    );
  }

  // ── Profile view / edit ──
  Widget _profileView(AuthState auth, bool wide) {
    final currentAvatarId = _editAvatarId ?? auth.avatarId ?? 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(wide ? 64 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FlowLogo(onTap: () => context.go('/lobby')),
              const Spacer(),
              FlowButton(label: '← Lobby', variant: FlowButtonVariant.ghost, size: FlowButtonSize.sm, onPressed: () => context.go('/lobby')),
            ],
          ),
          const SizedBox(height: 40),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.full),
              child: CachedNetworkImage(imageUrl: avatarUrl(currentAvatarId, size: 100), width: 100, height: 100),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(auth.username ?? '', style: AppTypography.title(fontSize: 22))),
          if (_memberSince.isNotEmpty) Center(child: Text('Member since $_memberSince', style: AppTypography.label(color: AppColors.slate))),
          const SizedBox(height: 28),

          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('Total', _speakCount + _listenCount),
              _stat('Vent 🎤', _speakCount),
              _stat('Listen 👂', _listenCount),
            ],
          ),
          const SizedBox(height: 32),

          if (_editing) ...[
            Text('CHOOSE AVATAR', style: AppTypography.label()),
            const SizedBox(height: 10),
            _avatarGrid(
              selected: currentAvatarId,
              onSelect: (id) => setState(() => _editAvatarId = id),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _rerollName,
                  onChanged: (v) => setState(() => _rerollName = v ?? false),
                  activeColor: AppColors.accent,
                ),
                Text('Re-roll username', style: AppTypography.ui(fontSize: 13)),
              ],
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Text(_saveError!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FlowButton(label: 'Save changes', onPressed: _handleSave, loading: _saving, expand: true),
            const SizedBox(height: 8),
            FlowButton(label: 'Cancel', variant: FlowButtonVariant.ghost, onPressed: () => setState(() { _editing = false; _editAvatarId = null; _rerollName = false; }), expand: true),
          ] else ...[
            FlowButton(label: 'Edit profile', variant: FlowButtonVariant.ghost, onPressed: () => setState(() => _editing = true), expand: true),
            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _exporting ? null : _handleExport,
                    child: Text(_exporting ? 'Exporting…' : 'Export my data'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showDeleteConfirm = true),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('Delete account'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => context.push('/privacy'),
                  child: const Text('Privacy Policy', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => context.push('/terms'),
                  child: const Text('Terms of Service', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            if (_showDeleteConfirm) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delete your account?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will permanently delete your profile, chat history, and all associated data. This action cannot be undone.',
                      style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _showDeleteConfirm = false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _deleting ? null : _handleDeleteAccount,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                          child: Text(_deleting ? 'Deleting…' : 'Yes, delete everything'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _avatarGrid({required int selected, required ValueChanged<int> onSelect}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: avatars.length,
      itemBuilder: (_, i) {
        final a = avatars[i];
        final isSelected = a.id == selected;
        return GestureDetector(
          onTap: () => onSelect(a.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: CachedNetworkImage(imageUrl: avatarUrl(a, size: 56), width: 56, height: 56),
            ),
          ),
        );
      },
    );
  }

  Widget _stat(String label, int value) {
    return Column(
      children: [
        Text(value.toString(), style: AppTypography.title(fontSize: 24)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.label(fontSize: 10, color: AppColors.slate)),
      ],
    );
  }
}
