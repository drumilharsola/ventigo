import 'chat_message.dart';

class RoomMessages {
  final String status;
  final String peerUsername;
  final int peerAvatarId;
  final String peerSessionId;
  final String matchedAt;
  final String startedAt;
  final String duration;
  final String endedAt;
  final List<ChatMessage> messages;

  const RoomMessages({
    required this.status,
    required this.peerUsername,
    required this.peerAvatarId,
    required this.peerSessionId,
    required this.matchedAt,
    required this.startedAt,
    required this.duration,
    required this.endedAt,
    required this.messages,
  });

  factory RoomMessages.fromJson(Map<String, dynamic> json) {
    return RoomMessages(
      status: json['status'] as String? ?? '',
      peerUsername: json['peer_username'] as String? ?? '',
      peerAvatarId: (json['peer_avatar_id'] as num?)?.toInt() ?? 0,
      peerSessionId: json['peer_session_id'] as String? ?? '',
      matchedAt: json['matched_at'] as String? ?? '',
      startedAt: json['started_at'] as String? ?? '',
      duration: json['duration']?.toString() ?? '900',
      endedAt: json['ended_at'] as String? ?? '',
      messages: (json['messages'] as List?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
