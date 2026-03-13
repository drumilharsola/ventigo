import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../models/chat_message.dart';

import '../services/avatars.dart';
import '../state/auth_provider.dart';
import '../state/chat_provider.dart';
import '../widgets/flow_logo.dart';
import '../widgets/flow_button.dart';
import '../widgets/pill.dart';
import '../widgets/timer_widget.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/session_end_modal.dart';
import '../widgets/report_modal.dart';
import '../widgets/user_profile_modal.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? peerSessionId;

  const ChatScreen({super.key, required this.roomId, this.peerSessionId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showReport = false;
  bool _showPeerProfile = false;
  bool _confirmingBlock = false;
  bool _blocking = false;
  bool _blocked = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        final max = _scrollCtrl.position.maxScrollExtent;
        final cur = _scrollCtrl.position.pixels;
        if (max - cur < 120) {
          _scrollCtrl.animateTo(max, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      }
    });
  }

  String _formatTime(num ts) {
    final d = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatRemaining(int secs) {
    return '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _handleBlock() async {
    final token = ref.read(authProvider).token;
    final chat = ref.read(chatProvider(widget.roomId));
    if (token == null || chat.peerSessionId == null || _blocking || _blocked) return;
    setState(() => _blocking = true);
    try {
      await ref.read(apiClientProvider).blockUser(token, chat.peerSessionId!, chat.peerUsername ?? '', chat.peerAvatarId);
      setState(() => _blocked = true);
      if (mounted) context.go('/lobby');
    } catch (_) {} finally {
      if (mounted) setState(() => _blocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final chat = ref.watch(chatProvider(widget.roomId));
    final notifier = ref.read(chatProvider(widget.roomId).notifier);

    // Auto-scroll on new messages
    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Stack(
        children: [
          // Ambient orb
          Positioned(top: -100, right: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.accent.withValues(alpha: 0.06), Colors.transparent])))),

          Column(
            children: [
              // ── Header ──
              _buildHeader(chat, notifier, auth),

              // ── Messages ──
              Expanded(child: _buildMessageList(chat, auth)),

              // ── Input or footer ──
              if (chat.mode == 'live') _buildInput(chat, notifier)
              else if (chat.mode == 'readonly' || chat.mode == 'expired') _buildReadonlyFooter(chat),
            ],
          ),

          // ── Modals ──
          if (chat.sessionEnded)
            SessionEndModal(
              canExtend: chat.canExtend,
              onExtend: notifier.extend,
              onClose: notifier.dismissSessionEnd,
            ),
          if (_showReport) ReportModal(onClose: () => setState(() => _showReport = false)),
          if (_showPeerProfile && chat.peerUsername != null && auth.token != null)
            UserProfileModal(
              username: chat.peerUsername!,
              peerSessionId: chat.peerSessionId,
              roomId: widget.roomId,
              onClose: () => setState(() => _showPeerProfile = false),
              onBlocked: () { setState(() => _showPeerProfile = false); context.go('/lobby'); },
            ),
        ],
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader(ChatState chat, ChatNotifier notifier, AuthState auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
        boxShadow: warmShadow(),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const FlowLogo(dark: true),
            const Spacer(),

            // Peer info center
            if (chat.peerUsername != null) ...[
              GestureDetector(
                onTap: () => setState(() => _showPeerProfile = true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      child: CachedNetworkImage(imageUrl: avatarUrl(chat.peerAvatarId, size: 72), width: 36, height: 36),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(chat.peerUsername!, style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                        Text(
                          chat.mode == 'readonly' ? 'Past conversations' : chat.connected ? 'Live · anonymous' : 'Connecting…',
                          style: AppTypography.body(fontSize: 11, color: AppColors.slate),
                        ),
                      ],
                    ),
                    if (chat.peerLeft) ...[
                      const SizedBox(width: 8),
                      Text('disconnected', style: AppTypography.body(fontSize: 11, color: AppColors.danger)),
                    ],
                  ],
                ),
              ),
            ] else
              Text(
                chat.mode == 'checking' ? 'Loading…' : 'Waiting for someone…',
                style: AppTypography.body(fontSize: 13, color: AppColors.slate),
              ),

            const Spacer(),

            // Timer / actions
            if (chat.mode == 'live') ...[
              if (chat.timerStarted)
                TimerWidget(remainingSeconds: chat.remaining, onEnd: () => notifier.extend()) // session_end handled by WS
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim.withValues(alpha: 0.08),
                    border: Border.all(color: AppColors.accentDim.withValues(alpha: 0.18)),
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                  child: Text(_formatRemaining(chat.remaining), style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
                ),
              const SizedBox(width: 8),

              // Report
              IconButton(icon: Text('⚑', style: TextStyle(fontSize: 16, color: AppColors.slate)), onPressed: () => setState(() => _showReport = true)),

              // Block
              if (_confirmingBlock) ...[
                Text('Block?', style: AppTypography.body(fontSize: 11, color: AppColors.danger)),
                IconButton(icon: Text('✓', style: TextStyle(color: AppColors.danger)), onPressed: () { setState(() => _confirmingBlock = false); _handleBlock(); }),
                IconButton(icon: Text('✗', style: TextStyle(color: AppColors.slate)), onPressed: () => setState(() => _confirmingBlock = false)),
              ] else
                IconButton(
                  icon: Text('⛔', style: TextStyle(fontSize: 15, color: _blocked ? AppColors.mist : AppColors.slate)),
                  onPressed: _blocking || _blocked ? null : () => setState(() => _confirmingBlock = true),
                ),

              // Leave
              FlowButton(
                label: 'Leave',
                variant: FlowButtonVariant.danger,
                size: FlowButtonSize.sm,
                onPressed: () { notifier.leave(); context.go('/lobby'); },
              ),
            ],

            // Back button (always)
            IconButton(
              icon: Text('←', style: TextStyle(fontSize: 16, color: AppColors.ink)),
              onPressed: () => context.go('/lobby'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message list ──

  Widget _buildMessageList(ChatState chat, AuthState auth) {
    if (chat.mode == 'checking' && chat.transcript.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (chat.mode == 'expired') {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('404', style: AppTypography.display(fontSize: 48, color: AppColors.mist)),
          const SizedBox(height: 8),
          Text('Conversation no longer available.', style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate)),
          Text('This chat has expired.', style: AppTypography.body(fontSize: 13, color: AppColors.slate)),
        ]),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(20),
      itemCount: chat.transcript.length + (chat.peerTyping ? 1 : 0) + (chat.mode == 'live' ? 1 : 0), // +1 for hint
      itemBuilder: (_, i) {
        // Hint pill at top
        if (chat.mode == 'live' && i == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pill(text: 'Listen first. Respond honestly.', variant: PillVariant.plain),
            ),
          );
        }

        final msgIndex = chat.mode == 'live' ? i - 1 : i;

        // Typing indicator at end
        if (chat.peerTyping && msgIndex == chat.transcript.length) {
          return TypingIndicator(username: chat.peerUsername ?? '');
        }

        if (msgIndex < 0 || msgIndex >= chat.transcript.length) return const SizedBox.shrink();
        final item = chat.transcript[msgIndex];

        if (item is TranscriptMarker) {
          return _buildMarker(item);
        }
        if (item is TranscriptMessage) {
          final isMe = chat.peerUsername != null ? item.from != chat.peerUsername : item.from == auth.username;
          return _buildBubble(item, isMe);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMarker(TranscriptMarker marker) {
    final label = marker.event == 'started' ? 'Chat started' : 'Chat ended';
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: AppTypography.body(fontSize: 11, color: AppColors.slate)),
          const SizedBox(width: 8),
          Text(_formatTime(marker.ts), style: AppTypography.body(fontSize: 11, color: AppColors.mist)),
        ]),
      ),
    );
  }

  Widget _buildBubble(TranscriptMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(msg.from, style: AppTypography.body(fontSize: 11, color: AppColors.slate)),
            ),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppColors.venterBubble : AppColors.listenerBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              border: Border.all(color: isMe ? AppColors.venterBorder : AppColors.listenerBorder),
            ),
            child: Text(msg.text, style: AppTypography.body(fontSize: 14, color: AppColors.ink)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4, bottom: 6),
            child: Text(_formatTime(msg.ts), style: AppTypography.body(fontSize: 10, color: AppColors.mist)),
          ),
        ],
      ),
    );
  }

  // ── Input bar ──

  Widget _buildInput(ChatState chat, ChatNotifier notifier) {
    final disabled = !chat.connected || chat.peerLeft || chat.sessionEnded;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    maxLines: 4,
                    minLines: 1,
                    enabled: !disabled,
                    style: AppTypography.body(fontSize: 14, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: chat.peerLeft ? 'Chat ended' : !chat.connected ? 'Connecting…' : 'Say something…',
                      hintStyle: AppTypography.body(fontSize: 14, color: AppColors.slate),
                      filled: true,
                      fillColor: AppColors.snow,
                      border: OutlineInputBorder(borderRadius: AppRadii.mdAll, borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                      enabledBorder: OutlineInputBorder(borderRadius: AppRadii.mdAll, borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (_) => notifier.resetTypingTimer(),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        notifier.sendMessage(text.trim());
                        _inputCtrl.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    final text = _inputCtrl.text.trim();
                    if (text.isNotEmpty && !disabled) {
                      notifier.sendMessage(text);
                      _inputCtrl.clear();
                    }
                  },
                  child: AnimatedOpacity(
                    opacity: _inputCtrl.text.trim().isEmpty || disabled ? 0.35 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: AppRadii.mdAll),
                      child: Text('↑', style: TextStyle(fontSize: 16, color: AppColors.ink, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Enter to send · Leave any time', style: AppTypography.body(fontSize: 10, color: AppColors.mist)),
          ],
        ),
      ),
    );
  }

  // ── Readonly / expired footer ──

  Widget _buildReadonlyFooter(ChatState chat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_confirmingBlock) ...[
              Text('Block this person?', style: AppTypography.body(fontSize: 12, color: AppColors.danger)),
              const SizedBox(width: 8),
              FlowButton(label: 'Yes', variant: FlowButtonVariant.ghost, size: FlowButtonSize.sm, onPressed: () { setState(() => _confirmingBlock = false); _handleBlock(); }),
              FlowButton(label: 'No', variant: FlowButtonVariant.ghost, size: FlowButtonSize.sm, onPressed: () => setState(() => _confirmingBlock = false)),
            ] else ...[
              FlowButton(
                label: _blocked ? 'Blocked' : _blocking ? 'Blocking…' : 'Block',
                variant: FlowButtonVariant.ghost,
                size: FlowButtonSize.sm,
                onPressed: _blocking || _blocked || chat.peerSessionId == null ? null : () => setState(() => _confirmingBlock = true),
              ),
              const SizedBox(width: 8),
              FlowButton(label: '← Back to lobby', variant: FlowButtonVariant.ghost, size: FlowButtonSize.sm, onPressed: () => context.go('/lobby')),
              const SizedBox(width: 8),
              FlowButton(label: 'Report', variant: FlowButtonVariant.ghost, size: FlowButtonSize.sm, onPressed: () => setState(() => _showReport = true)),
            ],
          ],
        ),
      ),
    );
  }
}
