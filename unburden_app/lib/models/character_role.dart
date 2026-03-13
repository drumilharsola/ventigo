import 'package:flutter/material.dart';
import '../config/theme.dart';

/// The two character archetypes in Unburden.
enum CharacterRole { venter, listener }

extension CharacterRoleX on CharacterRole {
  String get displayName => switch (this) {
    CharacterRole.venter => 'Venter',
    CharacterRole.listener => 'Listener',
  };

  String get emoji => switch (this) {
    CharacterRole.venter => '🎤',
    CharacterRole.listener => '🤝',
  };

  String get description => switch (this) {
    CharacterRole.venter => 'Share what\'s on your mind freely.',
    CharacterRole.listener => 'Hold space and be present for someone.',
  };

  String get ctaLabel => switch (this) {
    CharacterRole.venter => 'I need to talk',
    CharacterRole.listener => 'I\'ll listen',
  };

  Color get primary => switch (this) {
    CharacterRole.venter => AppColors.venterPrimary,
    CharacterRole.listener => AppColors.listenerPrimary,
  };

  Color get light => switch (this) {
    CharacterRole.venter => AppColors.venterLight,
    CharacterRole.listener => AppColors.listenerLight,
  };

  Color get bubbleColor => switch (this) {
    CharacterRole.venter => AppColors.venterBubble,
    CharacterRole.listener => AppColors.listenerBubble,
  };

  Color get borderColor => switch (this) {
    CharacterRole.venter => AppColors.venterBorder,
    CharacterRole.listener => AppColors.listenerBorder,
  };
}
