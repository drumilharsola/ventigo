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

  @override
  Widget build(BuildContext context) {
    // Determine bubble colors based on who sent and their role
    final Color bubbleBg;
    final Color textColor;
    final Color borderCol;

    if (isMe) {
      bubbleBg = myRole == CharacterRole.listener
          ? AppColors.listenerBubble
          : AppColors.venterBubble;
      textColor = AppColors.ink;
      borderCol = myRole == CharacterRole.listener
          ? AppColors.listenerBorder
          : AppColors.venterBorder;
    } else {
      bubbleBg = myRole == CharacterRole.listener
          ? AppColors.venterBubble
          : AppColors.listenerBubble;
      textColor = AppColors.ink;
      borderCol = myRole == CharacterRole.listener
          ? AppColors.venterBorder
          : AppColors.listenerBorder;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(from, style: AppTypography.body(fontSize: 11, color: AppColors.slate)),
            ),
          GestureDetector(
            onLongPressStart: (details) => _showReactionPicker(context, details.globalPosition),
            onDoubleTap: () {
              // Quick react with first emoji (heart)
              if (onReaction != null) {
                HapticFeedback.lightImpact();
                onReaction?.call('❤️');
              }
            },
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                border: Border.all(color: borderCol),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(text, style: AppTypography.body(fontSize: 14, color: textColor)),
            ),
          ),
          // Reactions row
          if (reactions.isNotEmpty)
            Padding(
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
            ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4, bottom: 6),
            child: Text(time, style: AppTypography.body(fontSize: 10, color: AppColors.fog)),
          ),
        ],
      ),
    );
  }
}
