class CurrentSpeakerRequest {
  final String requestId;
  final String? sessionId;
  final String? username;
  final String? avatarId;
  final String? postedAt;
  final String? status;
  final String? roomId;

  const CurrentSpeakerRequest({
    required this.requestId,
    this.sessionId,
    this.username,
    this.avatarId,
    this.postedAt,
    this.status,
    this.roomId,
  });

  factory CurrentSpeakerRequest.fromJson(Map<String, dynamic> json) {
    return CurrentSpeakerRequest(
      requestId: json['request_id'] as String,
      sessionId: json['session_id'] as String?,
      username: json['username'] as String?,
      avatarId: json['avatar_id']?.toString(),
      postedAt: json['posted_at'] as String?,
      status: json['status'] as String?,
      roomId: json['room_id'] as String?,
    );
  }
}
