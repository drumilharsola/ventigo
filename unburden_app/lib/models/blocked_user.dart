class BlockedUser {
  final String sessionId;
  final String username;
  final int avatarId;
  final String blockedAt;

  const BlockedUser({
    required this.sessionId,
    required this.username,
    required this.avatarId,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      sessionId: json['peer_session_id'] as String? ?? json['session_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarId: (json['avatar_id'] as num?)?.toInt() ?? 0,
      blockedAt: json['blocked_at'] as String? ?? '',
    );
  }
}
