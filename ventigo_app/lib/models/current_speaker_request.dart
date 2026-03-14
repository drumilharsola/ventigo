class CurrentSpeakerRequest {
  final String requestId;
  final String status;
  final String? roomId;
  final String? postedAt;

  const CurrentSpeakerRequest({
    required this.requestId,
    required this.status,
    this.roomId,
    this.postedAt,
  });

  factory CurrentSpeakerRequest.fromJson(Map<String, dynamic> json) {
    return CurrentSpeakerRequest(
      requestId: json['request_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      roomId: json['room_id'] as String?,
      postedAt: json['posted_at'] as String?,
    );
  }
}
