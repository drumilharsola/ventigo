import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/character_role.dart';

const _reactionEmojis = ['❤️', '🫂', '💪', '🙏', '😢'];

/// A warm chat bubble with role-specific coloring and reaction support.
class ChatBubble extends StatelessWidget {
  final String text;
  final String from;
  final String time;
  final bool isMe;
  final CharacterRole? myRole;
  final String? clientId;
  final List<String> reactions;
  final void Function(String emoji)? onReaction;

  const ChatBubble({
    super.key,
    required this.text,
    required this.from,
    required this.time,
    required this.isMe,
    this.myRole,
    this.clientId,
    this.reactions = const [],
    this.onReaction,
  });

  void _showReactionPicker(BuildContext context, Offset tapPosition) {
    if (onReaction == null) return;
    HapticFeedback.lightImpact();

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy - 50,
        overlay.size.width - tapPosition.dx,
        overlay.size.height - tapPosition.dy + 50,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.white,
      elevation: 4,
      items: _reactionEmojis.map((emoji) => PopupMenuItem<String>(
        value: emoji,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      )).toList(),
    ).then((emoji) {
      if (emoji != null) onReaction?.call(emoji);
    });
  }

  ({Color bg, Color text, Color border}) _bubbleColors() {
    // The sender sees their own role color; the peer sees the opposite.
    final isSpeaker = isMe
        ? myRole != CharacterRole.listener
        : myRole == CharacterRole.listener;
    return (
      bg: isSpeaker ? AppColors.venterBubble : AppColors.listenerBubble,
      text: AppColors.charcoal,
      border: isSpeaker ? AppColors.venterBorder : AppColors.listenerBorder,
    );
  }

  BorderRadius _bubbleRadius() {
    final isSpeaker = isMe
        ? myRole != CharacterRole.listener
        : myRole == CharacterRole.listener;
    if (isSpeaker) {
      return const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
        bottomRight: Radius.circular(4),
        bottomLeft: Radius.circular(18),
      );
    } else {
      return const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
        bottomRight: Radius.circular(18),
        bottomLeft: Radius.circular(4),
      );
    }
  }

  Widget _buildReactionsRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.map((r) => Container(
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.accentDim,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(r, style: const TextStyle(fontSize: 14)),
        )).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _bubbleColors();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(from, style: AppTypography.micro(fontSize: 11, color: AppColors.slate)),
            ),
          GestureDetector(
            onLongPressStart: (details) => _showReactionPicker(context, details.globalPosition),
            onDoubleTap: () {
              if (onReaction != null) {
                HapticFeedback.lightImpact();
                onReaction?.call('❤️');
              }
            },
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: _bubbleRadius(),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(text, style: AppTypography.body(fontSize: 14, color: colors.text)),
            ),
          ),
          if (reactions.isNotEmpty) _buildReactionsRow(),
          Padding(
            padding: EdgeInsets.only(top: 3, left: isMe ? 0 : 4, right: isMe ? 4 : 0, bottom: 6),
            child: Text(time, style: AppTypography.micro(fontSize: 10, color: AppColors.fog)),
          ),
        ],
      ),
    );
  }
}
