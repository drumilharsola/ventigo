import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../models/character_role.dart';
import '../services/avatars.dart';

/// Avatar wrapped with a role-colored glow ring.
class CharacterAvatar extends StatelessWidget {
  final dynamic avatarId;
  final CharacterRole? role;
  final double size;

  const CharacterAvatar({
    super.key,
    required this.avatarId,
    this.role,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = role?.primary ?? AppColors.accent;
    return Semantics(
      label: 'Avatar',
      excludeSemantics: true,
      child: Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: ringColor.withValues(alpha: 0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl(avatarId, size: (size * 2).toInt()),
          width: size,
          height: size,
          placeholder: (_, __) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: role?.light ?? AppColors.flow1,
              shape: BoxShape.circle,
            ),
          ),
        ),
        ),
      ),
    );
  }
}
