import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/chat_message.dart';
import '../models/room_summary.dart';
import '../services/avatars.dart';
import '../state/auth_provider.dart';
import '../state/chat_provider.dart';
import '../widgets/flow_button.dart';
import '../widgets/timer_widget.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/session_end_modal.dart';
import '../widgets/report_modal.dart';
import '../widgets/user_profile_modal.dart';

/// Shows ALL sessions with a specific peer in one scrollable thread.
/// Session started/ended markers separate each room's messages.
/// If the latest room is active, provides live chat input at the bottom.
class UnifiedChatScreen extends ConsumerStatefulWidget {
  final String peerSessionId;
  final String peerUsername;

  const UnifiedChatScreen({
    super.key,
    required this.peerSessionId,
    required this.peerUsername,
  });

  @override
  ConsumerState<UnifiedChatScreen> createState() => _UnifiedChatScreenState();
}

class _UnifiedChatScreenState extends ConsumerState<UnifiedChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();

  List<RoomSummary> _peerRooms = [];
  List<TranscriptItem> _unifiedTranscript = [];
  bool _loading = true;
  String? _activeRoomId;

  bool _showReport = false;
  bool _showPeerProfile = false;
  TranscriptMessage? _replyTo;

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final allRooms = await ref.read(apiClientProvider).getChatRooms(token);
      // Filter to this peer
      final peerRooms = allRooms
          .where((r) =>
              r.peerSessionId == widget.peerSessionId ||
              (widget.peerSessionId.isEmpty && r.peerUsername == widget.peerUsername))
          .toList();

      // Sort oldest first
      peerRooms.sort((a, b) {
        final aTs = int.tryParse(a.startedAt.isNotEmpty ? a.startedAt : a.matchedAt) ?? 0;
        final bTs = int.tryParse(b.startedAt.isNotEmpty ? b.startedAt : b.matchedAt) ?? 0;
        return aTs.compareTo(bTs);
      });

      // Check for active room
      final active = peerRooms.where((r) => r.status == 'active').toList();
      final activeId = active.isNotEmpty ? active.last.roomId : null;

      // Load messages for each room
      final transcript = <TranscriptItem>[];
      for (final room in peerRooms) {
        try {
          final data = await ref.read(apiClientProvider).getRoomMessages(token, room.roomId);

          // Add "Session started" marker
          final startTs = int.tryParse(data.startedAt.isNotEmpty ? data.startedAt : room.matchedAt) ?? 0;
          transcript.add(TranscriptMarker(
            event: 'started',
            roomId: room.roomId,
            ts: startTs.toDouble(),
          ));

          // Add messages
          for (final m in data.messages) {
            transcript.add(TranscriptMessage(
              from: m.from,
              text: m.text,
              ts: m.ts,
              clientId: m.clientId,
            ));
          }

          // Add "Session ended" marker if ended
          if (room.status == 'ended') {
            final endTs = int.tryParse(room.endedAt) ?? 0;
            transcript.add(TranscriptMarker(
              event: 'ended',
              roomId: room.roomId,
              ts: endTs > 0 ? endTs.toDouble() : (startTs + int.parse(room.duration)).toDouble(),
            ));
          }
        } catch (_) {
          // Skip rooms that fail to load
        }
      }

      // Sort entire transcript by timestamp
      transcript.sort((a, b) => a.ts.compareTo(b.ts));

      if (mounted) {
        setState(() {
          _peerRooms = peerRooms;
          _unifiedTranscript = transcript;
          _activeRoomId = activeId;
          _loading = false;
        });

        // Initialize the chat provider for the active room
        if (activeId != null) {
          // The chatProvider auto-initializes via the family provider
          // Just watching it will trigger initialization
          ref.read(chatProvider(activeId));
        }

        // Scroll to bottom after load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTime(num ts) {
    final d = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(num ts) {
    final d = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final time = DateFormat('h:mm a').format(d);
    if (day == today) return 'Today at $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday at $time';
    return '${DateFormat('MMM d').format(d)} at $time';
  }

  String _formatRemaining(int secs) {
    return '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // If there's an active room, also watch its live state for typing, new msgs, etc.
    ChatState? liveChat;
    ChatNotifier? liveNotifier;
    if (_activeRoomId != null) {
      liveChat = ref.watch(chatProvider(_activeRoomId!));
      liveNotifier = ref.read(chatProvider(_activeRoomId!).notifier);
      _scrollToBottom();
    }

    // Build the combined transcript: static historical + live messages for active room
    final displayTranscript = <TranscriptItem>[..._unifiedTranscript];
    if (liveChat != null && _activeRoomId != null) {
      // Merge live transcript items not already in the unified list
      for (final item in liveChat.transcript) {
        bool exists = false;
        if (item is TranscriptMessage) {
          exists = displayTranscript.any((e) {
            if (e is! TranscriptMessage) return false;
            if (item.clientId != null && e.clientId != null && item.clientId == e.clientId) return true;
            return e.from == item.from && e.text == item.text && (e.ts - item.ts).abs() < 2;
          });
        } else if (item is TranscriptMarker) {
          exists = displayTranscript.any((e) =>
              e is TranscriptMarker && e.roomId == item.roomId && e.event == item.event);
        }
        if (!exists) displayTranscript.add(item);
      }
      displayTranscript.sort((a, b) => a.ts.compareTo(b.ts));
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
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accent.withValues(alpha: 0.06),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          Column(
            children: [
              // Header
              _buildHeader(auth, liveChat, liveNotifier),

              // Messages
              Expanded(child: _buildMessageList(displayTranscript, auth, liveChat)),

              // Input
              if (liveChat != null && liveChat.mode == 'live')
                _buildInput(liveChat, liveNotifier!)
              else
                _buildReadonlyFooter(),
            ],
          ),

          // Modals
          if (liveChat?.sessionEnded == true && liveNotifier != null)
            SessionEndModal(
              canExtend: liveChat!.canExtend,
              onExtend: liveNotifier.extend,
              onClose: liveNotifier.dismissSessionEnd,
            ),
          if (_showReport) ReportModal(onClose: () => setState(() => _showReport = false)),
          if (_showPeerProfile && auth.token != null)
            UserProfileModal(
              username: widget.peerUsername,
              peerSessionId: widget.peerSessionId,
              roomId: _activeRoomId ?? (_peerRooms.isNotEmpty ? _peerRooms.last.roomId : ''),
              onClose: () => setState(() => _showPeerProfile = false),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader(AuthState auth, ChatState? liveChat, ChatNotifier? liveNotifier) {
    final peerAvatar = _peerRooms.isNotEmpty ? _peerRooms.first.peerAvatarId : 0;
    final isLive = liveChat != null && liveChat.mode == 'live';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
        boxShadow: warmShadow(),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.ink),
              onPressed: () => _goBack(),
            ),
            GestureDetector(
              onTap: () => setState(() => _showPeerProfile = true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl(peerAvatar, size: 72),
                      width: 36,
                      height: 36,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.peerUsername,
                          style: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                      Text(
                        isLive
                            ? (liveChat.connected ? 'Live · anonymous' : 'Connecting…')
                            : '${_peerRooms.length} ${_peerRooms.length == 1 ? "session" : "sessions"}',
                        style: AppTypography.body(fontSize: 11, color: isLive ? AppColors.success : AppColors.slate),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),

            if (isLive) ...[
              if (liveChat.timerStarted)
                TimerWidget(remainingSeconds: liveChat.remaining, onEnd: () => liveNotifier!.extend())
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                  child: Text(_formatRemaining(liveChat.remaining),
                      style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: Text('⚑', style: TextStyle(fontSize: 14, color: AppColors.slate)),
                onPressed: () => setState(() => _showReport = true),
              ),
              FlowButton(
                label: 'Leave',
                variant: FlowButtonVariant.danger,
                size: FlowButtonSize.sm,
                onPressed: () {
                  liveNotifier!.leave();
                  _goBack();
                },
              ),
            ] else ...[
              IconButton(
                icon: Text('⚑', style: TextStyle(fontSize: 14, color: AppColors.slate)),
                onPressed: () => setState(() => _showReport = true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(List<TranscriptItem> transcript, AuthState auth, ChatState? liveChat) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (transcript.isEmpty) {
      return Center(
        child: Text('No messages yet.', style: AppTypography.body(fontSize: 14, color: AppColors.slate)),
      );
    }

    final itemCount = transcript.length + (liveChat?.peerTyping == true ? 1 : 0);

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(20),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        // Typing indicator at end
        if (liveChat?.peerTyping == true && i == transcript.length) {
          return TypingIndicator(username: widget.peerUsername);
        }

        final item = transcript[i];

        if (item is TranscriptMarker) {
          return _buildMarker(item);
        }
        if (item is TranscriptMessage) {
          final isMe = widget.peerUsername.isNotEmpty
              ? item.from != widget.peerUsername
              : item.from == auth.username;
          final canReply = liveChat != null && liveChat.mode == 'live';
          return _buildBubble(item, isMe, canReply: canReply);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMarker(TranscriptMarker marker) {
    final isStarted = marker.event == 'started';
    final label = isStarted ? 'Session started' : 'Session ended';
    final time = _formatDateTime(marker.ts);

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
          Text(time, style: AppTypography.body(fontSize: 10, color: AppColors.slate)),
        ]),
      ),
    );
  }

  Widget _buildBubble(TranscriptMessage msg, bool isMe, {bool canReply = false}) {
    final bubble = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(msg.from, style: AppTypography.body(fontSize: 11, color: AppColors.slate)),
            ),
          // Reply preview
          if (msg.replyText != null && msg.replyText!.isNotEmpty)
            Container(
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

    if (!canReply) return bubble;

    return Dismissible(
      key: ValueKey(msg.clientId ?? msg.ts),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        setState(() => _replyTo = msg);
        _inputFocus.requestFocus();
        return false;
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
            // Reply preview
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_replyTo!.from,
                              style: AppTypography.ui(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
                          Text(_replyTo!.text,
                              style: AppTypography.body(fontSize: 12, color: AppColors.slate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _replyTo = null),
                      child: Icon(Icons.close_rounded, size: 18, color: AppColors.slate),
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
                      border: OutlineInputBorder(borderRadius: AppRadii.mdAll, borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                      enabledBorder: OutlineInputBorder(borderRadius: AppRadii.mdAll, borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (_) => notifier.resetTypingTimer(),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        notifier.sendMessage(text.trim(), replyTo: _replyTo);
                        _inputCtrl.clear();
                        setState(() => _replyTo = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    final text = _inputCtrl.text.trim();
                    if (text.isNotEmpty && !disabled) {
                      notifier.sendMessage(text, replyTo: _replyTo);
                      _inputCtrl.clear();
                      setState(() => _replyTo = null);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: AppRadii.mdAll),
                    child: Text('↑', style: TextStyle(fontSize: 16, color: AppColors.ink, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadonlyFooter() {
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
            FlowButton(
              label: '← Back',
              variant: FlowButtonVariant.ghost,
              size: FlowButtonSize.sm,
              onPressed: () => _goBack(),
            ),
            const SizedBox(width: 8),
            FlowButton(
              label: 'Report',
              variant: FlowButtonVariant.ghost,
              size: FlowButtonSize.sm,
              onPressed: () => setState(() => _showReport = true),
            ),
          ],
        ),
      ),
    );
  }
}
