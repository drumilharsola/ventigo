import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'pill.dart';

enum PosterMood { bloom, balance, listening, grounding }

class WellbeingPoster extends StatelessWidget {
  const WellbeingPoster({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.mood = PosterMood.bloom,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final PosterMood mood;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForMood(mood);
    final titleStyle = compact
        ? AppTypography.title(fontSize: 26, color: AppColors.ink)
        : AppTypography.display(fontSize: 40, color: AppColors.ink);

    return Container(
      padding: EdgeInsets.all(compact ? 22 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.background, palette.backgroundSoft],
        ),
        borderRadius: BorderRadius.circular(compact ? 28 : 40),
        border: Border.all(color: AppColors.ink, width: 1.4),
        boxShadow: warmShadow(blur: 28, opacity: 0.12),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -18,
            child: Transform.rotate(
              angle: 0.22,
              child: Container(
                width: compact ? 90 : 120,
                height: compact ? 30 : 38,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Positioned(
            right: compact ? 10 : 18,
            bottom: compact ? 16 : 22,
            child: CharacterCluster(mood: mood, compact: compact),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null) ...[
                Pill(text: eyebrow!, variant: PillVariant.plain),
                SizedBox(height: compact ? 16 : 20),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 220 : 320),
                child: Text(title, style: titleStyle),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 200 : 260),
                child: Text(
                  subtitle,
                  style: AppTypography.body(fontSize: compact ? 13 : 15, color: AppColors.ink80),
                ),
              ),
              SizedBox(height: compact ? 28 : 80),
              Row(
                children: [
                  _PosterToken(color: palette.accent, label: 'talk'),
                  const SizedBox(width: 10),
                  _PosterToken(color: palette.secondary, label: 'breathe'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  _PosterPalette _paletteForMood(PosterMood mood) {
    switch (mood) {
      case PosterMood.bloom:
        return const _PosterPalette(
          background: Color(0xFFFFF2D8),
          backgroundSoft: Color(0xFFFFDCD2),
          accent: AppColors.flow4,
          secondary: AppColors.flow5,
        );
      case PosterMood.balance:
        return const _PosterPalette(
          background: Color(0xFFE6F8FF),
          backgroundSoft: Color(0xFFF3F0FF),
          accent: AppColors.listenerPrimary,
          secondary: AppColors.plum,
        );
      case PosterMood.listening:
        return const _PosterPalette(
          background: Color(0xFFFFE9E1),
          backgroundSoft: Color(0xFFFFF7E9),
          accent: AppColors.venterPrimary,
          secondary: AppColors.sunflower,
        );
      case PosterMood.grounding:
        return const _PosterPalette(
          background: Color(0xFFF1FFD8),
          backgroundSoft: Color(0xFFE8F2FF),
          accent: AppColors.flow5,
          secondary: AppColors.listenerPrimary,
        );
    }
  }
}

class _PosterPalette {
  const _PosterPalette({
    required this.background,
    required this.backgroundSoft,
    required this.accent,
    required this.secondary,
  });

  final Color background;
  final Color backgroundSoft;
  final Color accent;
  final Color secondary;
}

class _PosterToken extends StatelessWidget {
  const _PosterToken({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: AppTypography.label(fontSize: 10, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class CharacterCluster extends StatelessWidget {
  const CharacterCluster({super.key, required this.mood, required this.compact});

  final PosterMood mood;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scale = compact ? 0.82 : 1.0;

    return SizedBox(
      width: 150 * scale,
      height: 170 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 10 * scale,
            bottom: 0,
            child: _CharacterFigure(
              color: mood == PosterMood.listening ? AppColors.listenerPrimary : AppColors.venterPrimary,
              accent: mood == PosterMood.grounding ? AppColors.flow5 : AppColors.paper,
              offset: -0.15,
              scale: scale,
            ),
          ),
          Positioned(
            left: 0,
            bottom: 4 * scale,
            child: _CharacterFigure(
              color: mood == PosterMood.balance ? AppColors.plum : AppColors.listenerPrimary,
              accent: mood == PosterMood.bloom ? AppColors.flow5 : AppColors.sunflower,
              offset: 0.18,
              scale: scale * 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterFigure extends StatelessWidget {
  const _CharacterFigure({
    required this.color,
    required this.accent,
    required this.offset,
    required this.scale,
  });

  final Color color;
  final Color accent;
  final double offset;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: offset,
      child: SizedBox(
        width: 72 * scale,
        height: 130 * scale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 8 * scale,
              left: 18 * scale,
              child: Container(
                width: 36 * scale,
                height: 36 * scale,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE0C2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 14 * scale,
              child: Transform.rotate(
                angle: -0.1,
                child: Container(
                  width: 42 * scale,
                  height: 20 * scale,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40 * scale,
              child: Container(
                width: 72 * scale,
                height: 78 * scale,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
            Positioned(
              top: 64 * scale,
              left: 18 * scale,
              child: Transform.rotate(
                angle: math.pi / 10,
                child: Container(
                  width: 36 * scale,
                  height: 24 * scale,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 12 * scale,
              child: Container(
                width: 14 * scale,
                height: 34 * scale,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 12 * scale,
              child: Container(
                width: 14 * scale,
                height: 34 * scale,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}