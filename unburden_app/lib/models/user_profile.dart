class UserProfile {
  final String username;
  final int avatarId;
  final int speakCount;
  final int listenCount;
  final String memberSince;
  final bool? emailVerified;
  final String email;

  const UserProfile({
    required this.username,
    required this.avatarId,
    this.speakCount = 0,
    this.listenCount = 0,
    this.memberSince = '',
    this.emailVerified,
    this.email = '',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username'] as String,
      avatarId: (json['avatar_id'] as num).toInt(),
      speakCount: (json['speak_count'] as num?)?.toInt() ?? 0,
      listenCount: (json['listen_count'] as num?)?.toInt() ?? 0,
      memberSince: json['member_since']?.toString() ?? '',
      emailVerified: json['email_verified'] as bool?,
      email: json['email']?.toString() ?? '',
    );
  }
}
