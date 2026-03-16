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
import '../widgets/skeleton.dart';
import '../utils/time_helpers.dart';
import '../utils/content_filter.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

const _postMaxChars = 400;
const _refreshInterval = Duration(seconds: 30);

@visibleForTesting
String postTimeLeft(num expiresAt) {
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

  // Kudos & comments — backed by API
  final Map<String, int> _kudosCounts = {};
  final Set<String> _kudosGiven = {};
  final Map<String, List<Map<String, dynamic>>> _comments = {};

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
      if (mounted && (posts.length != _posts.length || _loading)) {
        setState(() { _posts = posts; _loading = false; _error = null; });
        _loadAllKudos(posts);
      }
    } on AuthException {
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go('/verify');
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Could not load posts.'; });
    }
  }

  Future<void> _loadAllKudos(List<Map<String, dynamic>> posts) async {
    final token = _token;
    if (token == null) return;
    final api = ref.read(apiClientProvider);
    for (final post in posts) {
      final postId = post['post_id'] as String? ?? '';
      if (postId.isEmpty) continue;
      try {
        final data = await api.getKudos(token, postId);
        if (mounted) {
          setState(() {
            _kudosCounts[postId] = (data['count'] as num?)?.toInt() ?? 0;
            if (data['given'] == true) _kudosGiven.add(postId);
          });
        }
      } catch (_) {}
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

  Widget _buildComposeField(TextEditingController controller, StateSetter setSheetState) {
    return TextField(
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
    );
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
          return _buildComposeContent(
            ctx: ctx,
            setSheetState: setSheetState,
            controller: controller,
            composeError: composeError,
            posting: posting,
            onPost: () async {
              setSheetState(() { posting = true; composeError = null; });
              final err = await _handleCreatePost(controller.text.trim(), ctx);
              if (err != null) {
                setSheetState(() { composeError = err; posting = false; });
              }
            },
          );
        });
      },
    );
  }

  Future<String?> _handleCreatePost(String text, BuildContext sheetCtx) async {
    // Content moderation check
    final violation = ContentFilter.validate(text);
    if (violation != null) return violation;

    try {
      final token = _token;
      if (token == null) return null;
      await ref.read(apiClientProvider).createPost(token, text);
      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
      _loadPosts();
      return null;
    } on AuthException {
      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
      ref.read(authProvider.notifier).clear();
      if (mounted) context.go('/verify');
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Widget _buildComposeContent({
    required BuildContext ctx,
    required StateSetter setSheetState,
    required TextEditingController controller,
    required String? composeError,
    required bool posting,
    required VoidCallback onPost,
  }) {
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
          _buildComposeField(controller, setSheetState),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (composeError != null)
                Expanded(
                  child: Text(composeError,
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
                : onPost,
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
    final kudos = _kudosCounts[postId] ?? 0;
    final hasKudos = _kudosGiven.contains(postId);
    final commentCount = _comments[postId]?.length ?? 0;

    return Semantics(
      label: 'Post by $username',
      child: WarmCard(
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
          Text(text, style: AppTypography.body(fontSize: 14, color: AppColors.ink), maxLines: 15, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(postTimeLeft(expiresAt),
              style: AppTypography.body(fontSize: 12, color: AppColors.mist)),
          const SizedBox(height: 10),
          // Kudos & Comment row
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    // Optimistic update
                    final wasGiven = hasKudos;
                    setState(() {
                      if (wasGiven) {
                        _kudosGiven.remove(postId);
                        _kudosCounts[postId] = (kudos - 1).clamp(0, 999999);
                      } else {
                        _kudosGiven.add(postId);
                        _kudosCounts[postId] = kudos + 1;
                      }
                    });
                    final token = _token;
                    if (token == null) return;
                    try {
                      final data = await ref.read(apiClientProvider).toggleKudos(token, postId);
                      if (mounted) {
                        setState(() {
                          _kudosCounts[postId] = (data['count'] as num?)?.toInt() ?? _kudosCounts[postId]!;
                          if (data['given'] == true) {
                            _kudosGiven.add(postId);
                          } else {
                            _kudosGiven.remove(postId);
                          }
                        });
                      }
                    } catch (_) {
                      // Rollback
                      if (mounted) {
                        setState(() {
                          if (wasGiven) {
                            _kudosGiven.add(postId);
                            _kudosCounts[postId] = kudos;
                          } else {
                            _kudosGiven.remove(postId);
                            _kudosCounts[postId] = kudos;
                          }
                        });
                      }
                    }
                  },
                  borderRadius: AppRadii.fullAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasKudos ? AppColors.peach.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: AppRadii.fullAll,
                      border: Border.all(color: hasKudos ? AppColors.peach.withValues(alpha: 0.4) : AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(hasKudos ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 16,
                            color: hasKudos ? AppColors.peach : AppColors.slate),
                        if (kudos > 0) ...[
                          const SizedBox(width: 4),
                          Text('$kudos', style: AppTypography.ui(fontSize: 12, fontWeight: FontWeight.w600,
                              color: hasKudos ? AppColors.peach : AppColors.slate)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showCommentsSheet(postId, username),
                  borderRadius: AppRadii.fullAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.fullAll,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.slate),
                        if (commentCount > 0) ...[
                          const SizedBox(width: 4),
                          Text('$commentCount', style: AppTypography.ui(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  void _showCommentsSheet(String postId, String postUsername) {
    final commentCtrl = TextEditingController();
    bool loadingComments = true;
    // Load comments from API when sheet opens
    ref.read(apiClientProvider).getComments(postId).then((comments) {
      if (mounted) {
        setState(() => _comments[postId] = comments);
        // Trigger sheet rebuild through StatefulBuilder
      }
    }).catchError((_) {}).whenComplete(() => loadingComments = false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final postComments = _comments[postId] ?? [];
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Comments', style: AppTypography.title(fontSize: 18, color: AppColors.ink)),
              const SizedBox(height: 12),
              if (postComments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No comments yet. Be the first!', style: AppTypography.body(fontSize: 13, color: AppColors.slate)),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.3),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: postComments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = postComments[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.snow,
                          borderRadius: AppRadii.smAll,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((c['username'] ?? 'anon').toString(), style: AppTypography.ui(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink)),
                            const SizedBox(height: 4),
                            Text((c['text'] ?? '').toString(), style: AppTypography.body(fontSize: 13, color: AppColors.charcoal)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentCtrl,
                      maxLength: 200,
                      style: AppTypography.body(fontSize: 13, color: AppColors.ink),
                      decoration: InputDecoration(
                        hintText: 'Add a comment…',
                        hintStyle: AppTypography.body(fontSize: 13, color: AppColors.mist),
                        filled: true,
                        fillColor: AppColors.snow,
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: AppRadii.mdAll, borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: AppRadii.mdAll, borderSide: BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final text = commentCtrl.text.trim();
                        if (text.isEmpty) return;
                        final violation = ContentFilter.validate(text);
                        if (violation != null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(violation)));
                          return;
                        }
                        final token = _token;
                        if (token == null) return;
                        try {
                          final comment = await ref.read(apiClientProvider).addComment(token, postId, text);
                          setSheetState(() {
                            _comments.putIfAbsent(postId, () => []);
                            _comments[postId]!.add(comment);
                            commentCtrl.clear();
                          });
                          setState(() {});
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Could not post comment: $e')),
                            );
                          }
                        }
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildPostsList() {
    if (_loading) {
      return SkeletonShimmer(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: List.generate(4, (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonCard(),
          )),
        ),
      );
    }
    if (_error != null && _posts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 14)),
        ],
      );
    }
    if (_posts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 48),
          Icon(Icons.eco_rounded, size: 48, color: AppColors.mist),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: AppTypography.title(fontSize: 20, color: AppColors.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something.\nPosts disappear after 24 hours.',
            style: AppTypography.body(fontSize: 14, color: AppColors.slate),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildPostCard(_posts[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        title: Semantics(header: true, child: Text('Community',
            style: AppTypography.title(fontSize: 20, color: AppColors.ink))),
        automaticallyImplyLeading: false,
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
          child: _buildPostsList(),
        ),
      ),
    );
  }
}
