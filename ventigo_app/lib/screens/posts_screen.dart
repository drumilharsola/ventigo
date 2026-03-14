import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../services/api_client.dart';
import '../services/avatars.dart';
import '../state/auth_provider.dart';
import '../widgets/warm_card.dart';
import '../utils/time_helpers.dart';

const _postMaxChars = 400;
const _refreshInterval = Duration(seconds: 30);

String _timeLeft(num expiresAt) {
  final secs =
      (expiresAt - DateTime.now().millisecondsSinceEpoch / 1000).floor().clamp(0, 999999);
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m left';
  if (m > 0) return '${m}m left';
  return 'expiring soon';
}

class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key});

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  String? get _token => ref.read(authProvider).token;
  String? get _sessionId => ref.read(authProvider).sessionId;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _loadPosts());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await ref.read(apiClientProvider).getPosts();
      if (mounted) setState(() { _posts = posts; _loading = false; _error = null; });
    } on AuthException {
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go('/verify');
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Could not load posts.'; });
    }
  }

  Future<void> _deletePost(String postId) async {
    final token = _token;
    if (token == null) return;
    try {
      await ref.read(apiClientProvider).deletePost(token, postId);
      setState(() { _posts.removeWhere((p) => p['post_id'] == postId); });
    } catch (_) {}
  }

  void _showCompose() {
    final controller = TextEditingController();
    String? composeError;
    bool posting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final remaining = _postMaxChars - controller.text.length;
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Share something',
                    style: AppTypography.title(fontSize: 18, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(
                  'Anonymous. Disappears in 24 hours.',
                  style: AppTypography.body(fontSize: 13, color: AppColors.slate),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  maxLength: _postMaxChars,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    hintText: 'What\'s on your mind?',
                    hintStyle: AppTypography.body(fontSize: 14, color: AppColors.mist),
                    filled: true,
                    fillColor: AppColors.snow,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: AppRadii.mdAll,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadii.mdAll,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadii.mdAll,
                      borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                    ),
                  ),
                  style: AppTypography.body(fontSize: 14, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (composeError != null)
                      Expanded(
                        child: Text(composeError!,
                            style: AppTypography.body(fontSize: 12, color: AppColors.danger)),
                      )
                    else
                      const Spacer(),
                    Text(
                      '$remaining',
                      style: AppTypography.body(
                        fontSize: 12,
                        color: remaining <= 50 ? AppColors.danger : AppColors.slate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: posting || controller.text.trim().isEmpty
                      ? null
                      : () async {
                          setSheetState(() { posting = true; composeError = null; });
                          try {
                            final token = _token;
                            if (token == null) return;
                            await ref
                                .read(apiClientProvider)
                                .createPost(token, controller.text.trim());
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            _loadPosts();
                          } on AuthException {
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            ref.read(authProvider.notifier).clear();
                            if (mounted) context.go('/verify');
                          } catch (e) {
                            setSheetState(() {
                              composeError = e.toString().replaceFirst('Exception: ', '');
                              posting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.mdAll),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: posting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Post',
                          style: AppTypography.ui(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final postId = post['post_id'] as String? ?? '';
    final text = post['text'] as String? ?? '';
    final username = post['username'] as String? ?? 'anon';
    final avatarId = (post['avatar_id'] as num?)?.toInt() ?? 0;
    final createdAt = post['created_at'] as num? ?? 0;
    final expiresAt = post['expires_at'] as num? ?? 0;
    final postSessionId = post['session_id'] as String? ?? '';
    final isOwn = postSessionId == _sessionId;

    return WarmCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: avatarUrl(avatarId, size: 72),
                  width: 36,
                  height: 36,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username,
                        style: AppTypography.ui(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                    Text(timeAgo(createdAt),
                        style: AppTypography.body(fontSize: 12, color: AppColors.slate)),
                  ],
                ),
              ),
              if (isOwn)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.slate,
                  onPressed: () => _deletePost(postId),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(text, style: AppTypography.body(fontSize: 14, color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(_timeLeft(expiresAt),
              style: AppTypography.body(fontSize: 12, color: AppColors.mist)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        title: Text('Community Board',
            style: AppTypography.title(fontSize: 20, color: AppColors.ink)),
        backgroundColor: AppColors.snow,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _token != null ? _showCompose : null,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPosts,
          color: AppColors.accent,
          child: _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _error != null && _posts.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(_error!,
                            style: TextStyle(color: AppColors.danger, fontSize: 14)),
                      ],
                    )
                  : _posts.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(32),
                          children: [
                            const SizedBox(height: 48),
                            Icon(Icons.eco_rounded,
                                size: 48, color: AppColors.mist),
                            const SizedBox(height: 16),
                            Text(
                              'No posts yet',
                              style: AppTypography.title(
                                  fontSize: 20, color: AppColors.ink),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to share something.\nPosts disappear after 24 hours.',
                              style: AppTypography.body(
                                  fontSize: 14, color: AppColors.slate),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _posts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _buildPostCard(_posts[i]),
                        ),
        ),
      ),
    );
  }
}
