class SpeakerRequest {
  final String requestId;
  final String sessionId;
  final String username;
  final String avatarId;
  final String postedAt;
  final String topic;

  const SpeakerRequest({
    required this.requestId,
    required this.sessionId,
    required this.username,
    required this.avatarId,
    required this.postedAt,
    this.topic = '',
  });

  factory SpeakerRequest.fromJson(Map<String, dynamic> json) {
    return SpeakerRequest(
      requestId: json['request_id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarId: (json['avatar_id'] ?? 0).toString(),
      postedAt: json['posted_at'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
    );
  }
}
