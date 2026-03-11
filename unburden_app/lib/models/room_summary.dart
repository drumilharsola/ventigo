class RoomSummary {
  final String roomId;
  final String status;
  final String matchedAt;
  final String startedAt;
  final String duration;
  final String endedAt;
  final String peerSessionId;
  final String peerUsername;
  final int peerAvatarId;

  const RoomSummary({
    required this.roomId,
    required this.status,
    required this.matchedAt,
    required this.startedAt,
    required this.duration,
    required this.endedAt,
    required this.peerSessionId,
    required this.peerUsername,
    required this.peerAvatarId,
  });

  factory RoomSummary.fromJson(Map<String, dynamic> json) {
    return RoomSummary(
      roomId: json['room_id'] as String,
      status: json['status'] as String,
      matchedAt: json['matched_at']?.toString() ?? '',
      startedAt: json['started_at']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      endedAt: json['ended_at']?.toString() ?? '',
      peerSessionId: json['peer_session_id'] as String,
      peerUsername: json['peer_username'] as String,
      peerAvatarId: (json['peer_avatar_id'] as num).toInt(),
    );
  }
}
