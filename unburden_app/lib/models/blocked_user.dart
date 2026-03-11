class BlockedUser {
  final String peerSessionId;
  final String username;
  final int avatarId;
  final String blockedAt;

  const BlockedUser({
    required this.peerSessionId,
    required this.username,
    required this.avatarId,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      peerSessionId: json['peer_session_id'] as String,
      username: json['username'] as String,
      avatarId: (json['avatar_id'] as num).toInt(),
      blockedAt: json['blocked_at'] as String,
    );
  }
}
