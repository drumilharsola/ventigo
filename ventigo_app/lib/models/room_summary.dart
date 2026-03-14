class RoomSummary {
  final String roomId;
  final String role;
  final String peerUsername;
  final int peerAvatarId;
  final String peerSessionId;
  final String startedAt;
  final String endedAt;
  final String matchedAt;
  final String status;
  final String duration;

  const RoomSummary({
    required this.roomId,
    required this.role,
    required this.peerUsername,
    required this.peerAvatarId,
    required this.peerSessionId,
    required this.startedAt,
    required this.endedAt,
    required this.matchedAt,
    required this.status,
    required this.duration,
  });

  factory RoomSummary.fromJson(Map<String, dynamic> json) {
    return RoomSummary(
      roomId: json['room_id'] as String? ?? '',
      role: json['role'] as String? ?? '',
      peerUsername: json['peer_username'] as String? ?? '',
      peerAvatarId: (json['peer_avatar_id'] as num?)?.toInt() ?? 0,
      peerSessionId: json['peer_session_id'] as String? ?? '',
      startedAt: json['started_at'] as String? ?? '',
      endedAt: json['ended_at'] as String? ?? '',
      matchedAt: json['matched_at'] as String? ?? '',
      status: json['status'] as String? ?? '',
      duration: json['duration']?.toString() ?? '900',
    );
  }
}
