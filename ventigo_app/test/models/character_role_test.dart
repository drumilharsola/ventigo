import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/models/character_role.dart';
import 'package:ventigo_app/config/theme.dart';

void main() {
  group('CharacterRole', () {
    test('venter displayName', () {
      expect(CharacterRole.venter.displayName, 'Venter');
    });

    test('listener displayName', () {
      expect(CharacterRole.listener.displayName, 'Listener');
    });

    test('venter emoji', () {
      expect(CharacterRole.venter.emoji, '🎤');
    });

    test('listener emoji', () {
      expect(CharacterRole.listener.emoji, '🤝');
    });

    test('venter description', () {
      expect(CharacterRole.venter.description, contains('mind'));
    });

    test('listener description', () {
      expect(CharacterRole.listener.description, contains('present'));
    });

    test('venter ctaLabel', () {
      expect(CharacterRole.venter.ctaLabel, contains('talk'));
    });

    test('listener ctaLabel', () {
      expect(CharacterRole.listener.ctaLabel, contains('listen'));
    });

    test('venter primary color is peach', () {
      expect(CharacterRole.venter.primary, AppColors.venterPrimary);
    });

    test('listener primary color is lavender', () {
      expect(CharacterRole.listener.primary, AppColors.listenerPrimary);
    });

    test('venter light color', () {
      expect(CharacterRole.venter.light, AppColors.venterLight);
    });

    test('listener light color', () {
      expect(CharacterRole.listener.light, AppColors.listenerLight);
    });

    test('venter bubbleColor', () {
      expect(CharacterRole.venter.bubbleColor, AppColors.venterBubble);
    });

    test('listener bubbleColor', () {
      expect(CharacterRole.listener.bubbleColor, AppColors.listenerBubble);
    });

    test('venter borderColor', () {
      expect(CharacterRole.venter.borderColor, AppColors.venterBorder);
    });

    test('listener borderColor', () {
      expect(CharacterRole.listener.borderColor, AppColors.listenerBorder);
    });
  });

  group('AppColors', () {
    test('ink is dark brown', () {
      expect(AppColors.ink.r, greaterThan(0));
    });

    test('snow is warm white', () {
      expect(AppColors.snow, const Color(0xFFFFF8F0));
    });

    test('peach is warm orange', () {
      expect(AppColors.peach, const Color(0xFFF4A68C));
    });

    test('lavender is purple', () {
      expect(AppColors.lavender, const Color(0xFFC4B5E3));
    });

    test('amber is warm gold', () {
      expect(AppColors.amber, const Color(0xFFE8A84A));
    });
  });

  group('AppRadii', () {
    test('sm is 10', () {
      expect(AppRadii.sm, 10);
    });

    test('md is 18', () {
      expect(AppRadii.md, 18);
    });

    test('lg is 28', () {
      expect(AppRadii.lg, 28);
    });

    test('smAll uses sm radius', () {
      expect(AppRadii.smAll, const BorderRadius.all(Radius.circular(10)));
    });
  });
}
