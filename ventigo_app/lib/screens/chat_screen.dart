import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../models/chat_message.dart';

import '../services/avatars.dart';
import '../state/auth_provider.dart';
import '../state/chat_provider.dart';
import '../widgets/flow_button.dart';
import '../widgets/pill.dart';
import '../widgets/timer_widget.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/report_modal.dart';
import '../widgets/user_profile_modal.dart';
import '../widgets/safety_dialog.dart';
import '../utils/time_helpers.dart';
import '../utils/content_filter.dart';

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
  final _inputFocus = FocusNode();
  bool _showReport = false;
  bool _showPeerProfile = false;
  bool _safetyShown = false;
  TranscriptMessage? _replyTo;
  final _appreciationCtrl = TextEditingController();
  bool _appreciationSent = false;
  bool _appreciationSending = false;
  final Set<num> _visibleTimes = {}; // track which msg timestamps are shown

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    _appreciationCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
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

  void _showSafetyDialogIfNeeded(ChatState chat) {
    if (_safetyShown) return;
    if (chat.mode != 'live') return;
    // Show only when no messages yet (new session)
    final hasMessages = chat.transcript.any((t) => t is TranscriptMessage);
    if (hasMessages) {
      _safetyShown = true;
      return;
    }
    _safetyShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSafetyDialog(context, dismissible: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final chat = ref.watch(chatProvider(widget.roomId));
    final notifier = ref.read(chatProvider(widget.roomId).notifier);

    // Auto-scroll on new messages
    _scrollToBottom();

    // Show safety dialog on new live chat
    _showSafetyDialogIfNeeded(chat);

    // Navigate to new room if continue was accepted
    final continueRoomId = notifier.continueRoomId;
    if (continueRoomId != null && continueRoomId != widget.roomId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/chat?room_id=$continueRoomId');
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
      backgroundColor: AppColors.snow,
      body: Stack(
        children: [
          // Ambient orb
          Positioned(top: -100, right: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.accent.withValues(alpha: 0.06), Colors.transparent])))),

          Column(
            children: [
              // -- Header --
              _buildHeader(chat, notifier, auth),

              // -- Messages --
              // Ending soon banner
              if (chat.endingSoon && !chat.sessionEnded && chat.mode == 'live')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  color: const Color(0xFFE8B450).withValues(alpha: 0.1),
                  child: Text(
                    'Session ending soon - make the most of this moment',
                    style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFFE8B450)),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(child: _buildMessageList(chat, auth)),

              // -- Input or footer --
              if (chat.mode == 'live') _buildInput(chat, notifier)
              else if (chat.mode == 'readonly' || chat.mode == 'expired') _buildReadonlyFooter(chat),
            ],
          ),

          // -- Modals --
          ..._buildModals(chat, notifier, auth),
        ],
      ),
      ),
    );
  }

  List<Widget> _buildModals(ChatState chat, ChatNotifier notifier, AuthState auth) {
    // Auto-dismiss sessionEnded so no modal blocks the chat
    if (chat.sessionEnded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifier.dismissSessionEnd());
    }
    return [
      if (_showReport) ReportModal(onClose: () => setState(() => _showReport = false)),
      if (_showPeerProfile && chat.peerUsername != null && auth.token != null)
        UserProfileModal(
          username: chat.peerUsername!,
          peerSessionId: chat.peerSessionId,
          roomId: widget.roomId,
          onClose: () => setState(() => _showPeerProfile = false),
        ),
    ];
  }

  // -- Header --

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
            // Back button
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.ink),
              onPressed: () => _goBack(),
            ),
            const SizedBox(width: 4),

            // Peer info
            if (chat.peerUsername != null) ...[
              Expanded(child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _showPeerProfile = true),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.full),
                        child: CachedNetworkImage(imageUrl: avatarUrl(chat.peerAvatarId, size: 72), width: 36, height: 36),
                      ),
                      const SizedBox(width: 10),
                      Flexible(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(chat.peerUsername!, style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink), overflow: TextOverflow.ellipsis),
                          Text(
                            chat.mode == 'readonly' ? 'Past conversation' : chat.connected ? 'Live · anonymous' : 'Connecting…',
                            style: AppTypography.body(fontSize: 11, color: AppColors.slate),
                          ),
                        ],
                      )),
                      if (chat.peerLeft) ...[
                        const SizedBox(width: 8),
                        Text('left', style: AppTypography.body(fontSize: 11, color: AppColors.danger)),
                      ],
                    ],
                  ),
                ),
              )),
            ] else
              Expanded(child: Text(
                chat.mode == 'checking' ? 'Loading…' : 'Waiting for someone…',
                style: AppTypography.body(fontSize: 13, color: AppColors.slate),
              )),

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
                  child: Text(formatRemaining(chat.remaining), style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
                ),
              const SizedBox(width: 8),

              // Report
              IconButton(icon: Text('⚑', style: TextStyle(fontSize: 16, color: AppColors.slate)), onPressed: () => setState(() => _showReport = true)),

              // End Chat
              FlowButton(
                label: 'End Chat',
                variant: FlowButtonVariant.danger,
                size: FlowButtonSize.sm,
                onPressed: () => notifier.leave(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _shouldShowLabel(int msgIndex, ChatState chat, AuthState auth) {
    for (int j = msgIndex - 1; j >= 0; j--) {
      final prev = chat.transcript[j];
      if (prev is TranscriptMessage) {
        final prevIsMe = prev.fromSession != null
            ? prev.fromSession == auth.sessionId
            : prev.from == auth.username;
        return prevIsMe;
      }
      if (prev is TranscriptMarker) return true;
    }
    return true;
  }

  // -- Message list --

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

    final hasEnded = chat.transcript.any((t) => t is TranscriptMarker && t.event == 'ended');
    final itemCount = chat.transcript.length + (chat.peerTyping ? 1 : 0) + (chat.mode == 'live' ? 1 : 0) + (hasEnded ? 1 : 0);
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(20),
      itemCount: itemCount,
      itemBuilder: (_, i) => _buildChatListItem(i, chat, auth),
    );
  }

  Widget _buildChatListItem(int i, ChatState chat, AuthState auth) {
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

    // Typing indicator
    if (chat.peerTyping && msgIndex == chat.transcript.length) {
      return TypingIndicator(username: chat.peerUsername ?? '');
    }

    // Inline appreciation widget after the last ended marker
    final hasEnded = chat.transcript.any((t) => t is TranscriptMarker && t.event == 'ended');
    if (hasEnded && msgIndex == chat.transcript.length) {
      return _buildInlineAppreciation(chat);
    }

    if (msgIndex < 0 || msgIndex >= chat.transcript.length) return const SizedBox.shrink();
    final item = chat.transcript[msgIndex];

    if (item is TranscriptMarker) return _buildMarker(item);
    if (item is TranscriptMessage) {
      final isMe = item.fromSession != null
          ? item.fromSession == auth.sessionId
          : item.from == auth.username;
      final showLabel = !isMe && _shouldShowLabel(msgIndex, chat, auth);
      return _buildBubble(item, isMe, showLabel: showLabel, peerDisplayName: chat.peerUsername);
    }
    return const SizedBox.shrink();
  }

  Widget _buildMarker(TranscriptMarker marker) {
    final isStarted = marker.event == 'started';
    final label = isStarted ? 'Chat started' : 'Chat ended';
    final time = _formatTime(marker.ts);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isStarted
              ? AppColors.success.withValues(alpha: 0.08)
              : AppColors.danger.withValues(alpha: 0.06),
          border: Border.all(
            color: isStarted
                ? AppColors.success.withValues(alpha: 0.2)
                : AppColors.danger.withValues(alpha: 0.15),
          ),
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isStarted ? Icons.play_circle_outline_rounded : Icons.stop_circle_outlined,
            size: 14,
            color: isStarted ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.ui(fontSize: 11, fontWeight: FontWeight.w600,
              color: isStarted ? AppColors.success : AppColors.danger)),
          const SizedBox(width: 8),
          Text(time, style: AppTypography.body(fontSize: 10, color: AppColors.mist)),
        ]),
      ),
    );
  }

  Widget _buildInlineAppreciation(ChatState chat) {
    final notifier = ref.read(chatProvider(widget.roomId).notifier);
    final peer = chat.peerUsername ?? 'your peer';

    if (chat.appreciationSent || _appreciationSent) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accentDim,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accentGlow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💛', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text('Thank you for appreciating your peer', style: AppTypography.ui(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600))),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appreciate $peer 💛', style: AppTypography.label(fontSize: 13, color: AppColors.slate)),
          const SizedBox(height: 10),
          TextField(
            controller: _appreciationCtrl,
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'You made this conversation meaningful…',
              hintStyle: AppTypography.body(color: AppColors.fog),
              filled: true,
              fillColor: AppColors.snow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.accent)),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FlowButton(
              label: _appreciationSending ? 'Sending…' : 'Send',
              size: FlowButtonSize.sm,
              onPressed: _appreciationSending ? null : () async {
                final text = _appreciationCtrl.text.trim();
                if (text.isEmpty) return;
                setState(() => _appreciationSending = true);
                try {
                  await notifier.sendAppreciation(text);
                  setState(() { _appreciationSent = true; _appreciationSending = false; });
                } catch (_) {
                  setState(() => _appreciationSending = false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _replyPreview(TranscriptMessage msg, bool isMe) {
    if (msg.replyText == null || msg.replyText!.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isMe ? AppColors.venterBubble : AppColors.listenerBubble).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg.replyFrom ?? '', style: AppTypography.ui(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accent)),
          Text(msg.replyText!, style: AppTypography.body(fontSize: 11, color: AppColors.slate), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildBubble(TranscriptMessage msg, bool isMe, {bool canReply = true, bool showLabel = true, String? peerDisplayName}) {
    final timeVisible = _visibleTimes.contains(msg.ts);
    final bubble = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() {
            if (timeVisible) {
              _visibleTimes.remove(msg.ts);
            } else {
              _visibleTimes.add(msg.ts);
            }
          }),
          child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && showLabel)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(peerDisplayName ?? msg.from, style: AppTypography.micro(fontSize: 11, color: AppColors.slate)),
              ),
            _replyPreview(msg, isMe),
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.venterBubble : AppColors.listenerBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: Border.all(color: isMe ? AppColors.venterBorder : AppColors.listenerBorder),
              ),
              child: Text(msg.text, style: AppTypography.body(fontSize: 14, color: AppColors.ink)),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: timeVisible
                  ? Padding(
                      padding: const EdgeInsets.only(top: 3, left: 4, right: 4, bottom: 6),
                      child: Text(_formatTime(msg.ts), style: AppTypography.micro(fontSize: 10, color: AppColors.fog)),
                    )
                  : const SizedBox(height: 6),
            ),
          ],
        ),
        ),
      ),
    );

    if (!canReply) return bubble;

    // Swipe-to-reply: swipe right to reply
    return Dismissible(
      key: ValueKey(msg.clientId ?? msg.ts),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        setState(() => _replyTo = msg);
        _inputFocus.requestFocus();
        return false; // don't actually dismiss
      },
      background: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.reply_rounded, color: AppColors.accent, size: 24),
        ),
      ),
      child: bubble,
    );
  }

  // -- Input bar --

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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply preview bar
            if (_replyTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: AppRadii.mdAll,
                  border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_replyTo!.from, style: AppTypography.ui(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
                        Text(_replyTo!.text, style: AppTypography.body(fontSize: 12, color: AppColors.slate), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    )),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _replyTo = null),
                        child: Icon(Icons.close_rounded, size: 18, color: AppColors.slate),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    focusNode: _inputFocus,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    enabled: !disabled,
                    style: AppTypography.body(fontSize: 14, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: chat.peerLeft ? 'Chat ended' : !chat.connected ? 'Connecting…' : 'Say something…',
                      hintStyle: AppTypography.body(fontSize: 14, color: AppColors.slate),
                      filled: true,
                      fillColor: AppColors.snow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (_) => notifier.resetTypingTimer(),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        final filtered = ContentFilter.mask(text.trim());
                        notifier.sendMessage(filtered, replyTo: _replyTo);
                        _inputCtrl.clear();
                        setState(() => _replyTo = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final text = _inputCtrl.text.trim();
                      if (text.isNotEmpty && !disabled) {
                        final filtered = ContentFilter.mask(text);
                        notifier.sendMessage(filtered, replyTo: _replyTo);
                        _inputCtrl.clear();
                        setState(() => _replyTo = null);
                      }
                    },
                    customBorder: const CircleBorder(),
                    child: AnimatedOpacity(
                      opacity: _inputCtrl.text.trim().isEmpty || disabled ? 0.35 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                        child: Icon(Icons.arrow_upward_rounded, size: 20, color: AppColors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Enter to send · Swipe to reply', style: AppTypography.micro(fontSize: 10, color: AppColors.mist)),
          ],
        ),
      ),
    );
  }

  // -- Readonly / expired footer --

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
            FlowButton(label: '← Back', variant: FlowButtonVariant.ghost, size: FlowButtonSize.sm, onPressed: () => _goBack()),
            const SizedBox(width: 8),
            FlowButton(label: 'Report', variant: FlowButtonVariant.ghost, size: FlowButtonSize.sm, onPressed: () => setState(() => _showReport = true)),
          ],
        ),
      ),
    );
  }
}
