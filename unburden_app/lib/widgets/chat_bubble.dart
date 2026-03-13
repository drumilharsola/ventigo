import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/character_role.dart';

/// A warm chat bubble with role-specific coloring.
class ChatBubble extends StatelessWidget {
  final String text;
  final String from;
  final String time;
  final bool isMe;
  final CharacterRole? myRole;

  const ChatBubble({
    super.key,
    required this.text,
    required this.from,
    required this.time,
    required this.isMe,
    this.myRole,
  });

  @override
  Widget build(BuildContext context) {
    // Determine bubble colors based on who sent and their role
    final Color bubbleBg;
    final Color textColor;
    final Color borderCol;

    if (isMe) {
      // My message: use my role color
      bubbleBg = myRole == CharacterRole.listener
          ? AppColors.listenerBubble
          : AppColors.venterBubble;
      textColor = AppColors.ink;
      borderCol = myRole == CharacterRole.listener
          ? AppColors.listenerBorder
          : AppColors.venterBorder;
    } else {
      // Peer message: use peer role color (opposite of mine)
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
          Container(
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
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4, bottom: 6),
            child: Text(time, style: AppTypography.body(fontSize: 10, color: AppColors.fog)),
          ),
        ],
      ),
    );
  }
}
