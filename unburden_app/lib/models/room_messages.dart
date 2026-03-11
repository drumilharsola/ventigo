import 'room_summary.dart';
import 'chat_message.dart';

class RoomMessages extends RoomSummary {
  final List<ChatMessage> messages;

  RoomMessages({
    required super.roomId,
    required super.status,
    required super.matchedAt,
    required super.startedAt,
    required super.duration,
    required super.endedAt,
    required super.peerSessionId,
    required super.peerUsername,
    required super.peerAvatarId,
    required this.messages,
  });

  factory RoomMessages.fromJson(Map<String, dynamic> json) {
    return RoomMessages(
      roomId: json['room_id'] as String,
      status: json['status'] as String,
      matchedAt: json['matched_at']?.toString() ?? '',
      startedAt: json['started_at']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      endedAt: json['ended_at']?.toString() ?? '',
      peerSessionId: json['peer_session_id'] as String,
      peerUsername: json['peer_username'] as String,
      peerAvatarId: (json['peer_avatar_id'] as num).toInt(),
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
