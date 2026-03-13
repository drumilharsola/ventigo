import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/character_role.dart';

/// A pill badge showing "Venter 🎤" or "Listener 👂" with role-specific colors.
class RoleBadge extends StatelessWidget {
  final CharacterRole role;
  final double fontSize;

  const RoleBadge({super.key, required this.role, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: role.light,
        border: Border.all(color: role.borderColor),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(role.emoji, style: TextStyle(fontSize: fontSize)),
          const SizedBox(width: 5),
          Text(
            role.displayName,
            style: AppTypography.label(fontSize: fontSize, color: role.primary),
          ),
        ],
      ),
    );
  }
}
