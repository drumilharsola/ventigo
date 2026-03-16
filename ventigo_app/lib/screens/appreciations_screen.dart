import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../models/appreciation.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../utils/time_helpers.dart';
import '../widgets/orb_background.dart';
import '../widgets/skeleton.dart';

class AppreciationsScreen extends ConsumerStatefulWidget {
  final String? username;

  const AppreciationsScreen({super.key, this.username});

  @override
  ConsumerState<AppreciationsScreen> createState() => _AppreciationsScreenState();
}

class _AppreciationsScreenState extends ConsumerState<AppreciationsScreen> {
  List<Appreciation> _items = [];
  bool _loading = true;
  String? _error;
  int _offset = 0;
  bool _hasMore = true;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _targetUsername {
    if (widget.username != null && widget.username!.isNotEmpty) return widget.username!;
    return ref.read(authProvider).username ?? '';
  }

  bool get _isOwnProfile => widget.username == null || widget.username!.isEmpty;

  Future<void> _load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final items = await ref.read(apiClientProvider).getAppreciations(
        token, _targetUsername, limit: _pageSize, offset: _offset,
      );
      if (mounted) {
        setState(() {
          _items.addAll(items);
          _hasMore = items.length >= _pageSize;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _loadMore() {
    if (_loading || !_hasMore) return;
    _offset += _pageSize;
    _load();
  }

  Future<void> _shareToBoard(Appreciation a) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final text = '💛 Appreciation from ${a.fromUsername}: "${a.message}"';
    try {
      await ref.read(apiClientProvider).createPost(token, text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared to Community!')),
        );
      }
    } on AuthException {
      // ignore
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    }
  }

  String _formatDate(int ts) => formatFullDateTime(ts);

  @override
  Widget build(BuildContext context) {
    final title = _isOwnProfile ? 'My Appreciations' : '${_targetUsername}\'s Appreciations';

    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Stack(
        children: [
          const OrbBackground(),
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: AppColors.ink),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(title, style: AppTypography.title(fontSize: 22), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return SkeletonShimmer(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: List.generate(4, (_) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SkeletonCard(),
          )),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Text(_error!, style: TextStyle(color: AppColors.danger)),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          _isOwnProfile ? 'No appreciations yet' : 'No appreciations to show',
          style: AppTypography.body(color: AppColors.slate),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final a = _items[index];
          return _AppreciationTile(
            appreciation: a,
            formatDate: _formatDate,
            onShare: _isOwnProfile ? () => _shareToBoard(a) : null,
          );
        },
      ),
    );
  }
}

class _AppreciationTile extends StatelessWidget {
  final Appreciation appreciation;
  final String Function(int) formatDate;
  final VoidCallback? onShare;

  const _AppreciationTile({required this.appreciation, required this.formatDate, this.onShare});

  @override
  Widget build(BuildContext context) {
    final roleLabel = appreciation.fromRole == 'venter' ? 'Venter' : 'Listener';
    final roleColor = appreciation.fromRole == 'venter'
        ? AppColors.peach
        : AppColors.lavender;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                appreciation.fromUsername,
                style: AppTypography.label(fontSize: 14, color: AppColors.ink),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  roleLabel,
                  style: AppTypography.label(fontSize: 10, color: roleColor),
                ),
              ),
              const Spacer(),
              Text(
                formatDate(appreciation.createdAt),
                style: AppTypography.label(fontSize: 10, color: AppColors.slate),
              ),
            ],
          ),
          if (appreciation.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              appreciation.message,
              style: AppTypography.body(fontSize: 13),
            ),
          ],
          if (onShare != null) ...[
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onShare,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.lavender.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.share_outlined, size: 14, color: AppColors.lavender),
                      const SizedBox(width: 6),
                      Text('Share to Community', style: AppTypography.ui(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.lavender)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
