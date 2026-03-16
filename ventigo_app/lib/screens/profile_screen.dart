import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

import '../services/avatars.dart';
import '../state/auth_provider.dart';
import '../utils/time_helpers.dart';
import '../widgets/flow_button.dart';
import '../widgets/orb_background.dart';
import '../widgets/warm_card.dart';

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
  String _memberSince = '';
  bool _deleting = false;
  bool? _emailVerified;
  bool _verificationSending = false;
  String _email = '';



  bool get _isSetup => !ref.read(authProvider).hasProfile;

  @override
  void initState() {
    super.initState();
    if (!_isSetup) _loadStats();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadStats() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final me = await ref.read(apiClientProvider).getMe(token);
      setState(() {
        _memberSince = me.memberSince;
        _emailVerified = me.emailVerified;
        _email = me.email;
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
      if (mounted) context.go('/onboarding');
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

  Future<void> _handleDeleteAccount() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _deleting = true);
    try {
      await ref.read(apiClientProvider).deleteAccount(token);
      await ref.read(authProvider.notifier).clear();
      if (mounted) {
        Navigator.of(context).pop(); // dismiss sheet
        context.go('/');
      }
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showDeleteSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppColors.snow.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text('Delete your account?',
                  style: AppTypography.title(fontSize: 18, color: AppColors.ink)),
              const SizedBox(height: 10),
              Text(
                'This will permanently delete your profile, chat history, and all associated data. This action cannot be undone.',
                style: AppTypography.body(fontSize: 13, color: AppColors.slate),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _deleting ? null : () {
                    _handleDeleteAccount();
                    setSheetState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_deleting ? 'Deleting…' : 'Yes, delete everything',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Cancel', style: AppTypography.ui(fontSize: 15, color: AppColors.slate)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      backgroundColor: AppColors.snow,
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

  // -- Setup view --
  Widget _setupView(bool wide) {
    final currentAvatar = getAvatar(_setupAvatarId);
    final avatarWidget = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: CachedNetworkImage(
        imageUrl: avatarUrl(currentAvatar, size: 120),
        width: 120,
        height: 120,
        placeholder: (_, __) => Container(
          width: 120, height: 120, color: AppColors.pale,
          child: Icon(Icons.person, size: 56, color: AppColors.fog),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 120, height: 120,
          decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(AppRadii.full)),
          child: Icon(Icons.person, size: 56, color: AppColors.fog),
        ),
      ),
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickDate,
            borderRadius: AppRadii.mdAll,
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
                style: AppTypography.ui(color: _dob != null ? AppColors.ink : AppColors.slate),
              ),
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
          Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
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

  // -- Profile view / edit --
  Widget _profileView(AuthState auth, bool wide) {
    final currentAvatarId = _editAvatarId ?? auth.avatarId ?? 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(wide ? 64 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Settings gear in top-right
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: _showSettingsSheet,
              icon: Icon(Icons.settings_outlined, color: AppColors.ink, size: 24),
              tooltip: 'Settings',
            ),
          ),

          // Avatar (tap to edit)
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _editing = true),
                customBorder: const CircleBorder(),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl(currentAvatarId, size: 100),
                        width: 88,
                        height: 88,
                        placeholder: (_, __) => Container(
                          width: 88, height: 88, color: AppColors.pale,
                          child: Icon(Icons.person, size: 48, color: AppColors.fog),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(AppRadii.full)),
                          child: Icon(Icons.person, size: 48, color: AppColors.fog),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.snow, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),
          Center(child: Text(auth.username ?? '', style: AppTypography.title(fontSize: 22))),
          if (_email.isNotEmpty) Center(child: Text(_email, style: AppTypography.ui(fontSize: 13, color: AppColors.slate))),
          if (_memberSince.isNotEmpty) Center(child: Text('Member since ${_formatMemberSince(_memberSince)}', style: AppTypography.label(color: AppColors.slate))),
          const SizedBox(height: 20),

          const SizedBox(height: 24),

          // Quick actions
          _quickActionTile(
            icon: Icons.favorite_border_rounded,
            label: 'My Appreciations',
            onTap: () => context.push('/appreciations'),
          ),
          const SizedBox(height: 10),
          _quickActionTile(
            icon: Icons.emoji_events_outlined,
            label: 'Achievements',
            subtitle: 'Coming soon',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Achievements coming soon!'), behavior: SnackBarBehavior.floating),
              );
            },
          ),

          const SizedBox(height: 24),

          if (_editing) ...[
            Text('CHOOSE AVATAR', style: AppTypography.label()),
            const SizedBox(height: 10),
            _avatarGrid(
              selected: currentAvatarId,
              onSelect: (id) => setState(() => _editAvatarId = id),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Text(_saveError!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FlowButton(label: 'Save changes', onPressed: _handleSave, loading: _saving, expand: true),
            const SizedBox(height: 8),
            FlowButton(label: 'Cancel', variant: FlowButtonVariant.ghost, onPressed: () => setState(() { _editing = false; _editAvatarId = null; _rerollName = false; }), expand: true),
          ],

          const SizedBox(height: 24),
          // Privacy & Terms
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _quickActionTile({required IconData icon, required String label, String? subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.slate),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    if (subtitle != null) Text(subtitle, style: AppTypography.body(fontSize: 11, color: AppColors.mist)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordSheet() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool loading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.snow,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Change Password', style: AppTypography.title(fontSize: 20, color: AppColors.ink)),
                const SizedBox(height: 20),
                TextField(
                  controller: currentPassCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password (min 8 characters)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      if (newPassCtrl.text.length < 8) {
                        setSheetState(() => error = 'Password must be at least 8 characters');
                        return;
                      }
                      if (newPassCtrl.text != confirmPassCtrl.text) {
                        setSheetState(() => error = 'Passwords do not match');
                        return;
                      }
                      setSheetState(() { loading = true; error = null; });
                      try {
                        final token = ref.read(authProvider).token!;
                        await ref.read(apiClientProvider).changePassword(token, currentPassCtrl.text, newPassCtrl.text);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password changed successfully'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      } catch (e) {
                        setSheetState(() { error = e.toString(); loading = false; });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(loading ? 'Saving…' : 'Change Password',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: AppTypography.ui(fontSize: 15, color: AppColors.slate)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangeEmailSheet() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool loading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.snow,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Change Email', style: AppTypography.title(fontSize: 20, color: AppColors.ink)),
                const SizedBox(height: 8),
                Text('A verification link will be sent to your new email.',
                    style: AppTypography.body(fontSize: 13, color: AppColors.slate)),
                const SizedBox(height: 20),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'New Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      if (!emailCtrl.text.contains('@')) {
                        setSheetState(() => error = 'Please enter a valid email');
                        return;
                      }
                      if (passCtrl.text.isEmpty) {
                        setSheetState(() => error = 'Please enter your password');
                        return;
                      }
                      setSheetState(() { loading = true; error = null; });
                      try {
                        final token = ref.read(authProvider).token!;
                        await ref.read(apiClientProvider).changeEmail(token, emailCtrl.text.trim().toLowerCase(), passCtrl.text);
                        await ref.read(authProvider.notifier).setEmailVerified(false);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          setState(() { _email = emailCtrl.text.trim().toLowerCase(); _emailVerified = false; });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email changed. Please verify your new email.'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      } catch (e) {
                        setSheetState(() { error = e.toString(); loading = false; });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(loading ? 'Saving…' : 'Change Email',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: AppTypography.ui(fontSize: 15, color: AppColors.slate)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Settings', style: AppTypography.title(fontSize: 20, color: AppColors.ink)),
              const SizedBox(height: 20),

              // Email verification status
              _emailRow(),
              const SizedBox(height: 16),

              // Settings items
              _settingsItem(Icons.lock_outline_rounded, 'Change Password', () {
                Navigator.of(context).pop();
                _showChangePasswordSheet();
              }),
              _settingsItem(Icons.email_outlined, 'Change Email', () {
                Navigator.of(context).pop();
                _showChangeEmailSheet();
              }),
              _settingsItem(Icons.person_outline_rounded, 'Re-roll Username', () async {
                Navigator.of(context).pop();
                setState(() { _saving = true; _saveError = null; });
                try {
                  final token = ref.read(authProvider).token!;
                  final res = await ref.read(apiClientProvider).updateProfile(token, rerollUsername: true);
                  await ref.read(authProvider.notifier).setProfile(res.username, res.avatarId);
                } catch (e) {
                  setState(() => _saveError = e.toString());
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              }),

              const SizedBox(height: 12),
              Divider(color: AppColors.border),
              const SizedBox(height: 12),

              _settingsItem(Icons.block_outlined, 'Blocked Users', () {
                Navigator.of(context).pop();
                context.push('/blocked-users');
              }),

              const SizedBox(height: 12),
              Divider(color: AppColors.border),
              const SizedBox(height: 12),

              _settingsItem(Icons.logout_rounded, 'Sign Out', () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).clear();
                context.go('/');
              }, color: AppColors.slate),
              _settingsItem(Icons.delete_forever_rounded, 'Delete Account', () {
                Navigator.of(context).pop();
                _showDeleteSheet();
              }, color: AppColors.danger),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final c = color ?? AppColors.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: c),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w500, color: c))),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.mist),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMemberSince(String raw) => formatTimestamp(raw);

  Future<void> _handleExportData() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _saving = true);
    try {
      final data = await ref.read(apiClientProvider).exportData(token);
      final json = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data copied to clipboard'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _emailRow() {
    final auth = ref.read(authProvider);
    final verified = _emailVerified ?? auth.emailVerified ?? false;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: verified ? AppColors.flow5.withValues(alpha: 0.2) : AppColors.sunflower.withValues(alpha: 0.2),
          borderRadius: AppRadii.smAll,
          border: Border.all(color: verified ? AppColors.flow5 : AppColors.sunflower, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Icons.verified_rounded : Icons.warning_amber_rounded,
              size: 16,
              color: verified ? AppColors.ink : AppColors.ink80,
            ),
            const SizedBox(width: 8),
            Text(
              verified ? 'Email verified' : 'Email not verified',
              style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
            if (!verified) ...[
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _verificationSending ? null : _handleSendVerification,
                  child: Text(
                    _verificationSending ? 'Sending…' : 'Verify now →',
                    style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendVerification() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _verificationSending = true);
    try {
      await ref.read(apiClientProvider).sendVerification(token);
    } catch (_) {}
    if (mounted) setState(() => _verificationSending = false);
  }

  Widget _avatarGrid({required int selected, required ValueChanged<int> onSelect}) {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 400 ? 6 : 4;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, mainAxisSpacing: 8, crossAxisSpacing: 8),
        itemCount: avatars.length,
        itemBuilder: (_, i) {
          final a = avatars[i];
          final isSelected = a.id == selected;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(a.id),
              customBorder: const CircleBorder(),
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
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl(a, size: 56),
                    width: 48,
                    height: 48,
                    errorWidget: (_, __, ___) => Container(
                      width: 48, height: 48, color: AppColors.pale,
                      child: Icon(Icons.person, size: 24, color: AppColors.fog),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

}
