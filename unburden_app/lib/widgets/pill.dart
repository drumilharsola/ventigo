import 'package:flutter/material.dart';
import '../config/theme.dart';

enum PillVariant { accent, success, plain }

/// Small label pill — maps .pill / .pill-accent / .pill-success.
class Pill extends StatelessWidget {
  final String text;
  final PillVariant variant;
  final bool showDot;

  const Pill({
    super.key,
    required this.text,
    this.variant = PillVariant.accent,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color borderColor;
    Color textColor;

    switch (variant) {
      case PillVariant.accent:
        bg = AppColors.accentDim;
        borderColor = AppColors.accentGlow;
        textColor = AppColors.accent;
      case PillVariant.success:
        bg = const Color(0x1F80C8A0);
        borderColor = const Color(0x3380C8A0);
        textColor = AppColors.success;
      case PillVariant.plain:
        bg = AppColors.card;
        borderColor = AppColors.border;
        textColor = AppColors.fog;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            _AnimatedDot(color: textColor),
            const SizedBox(width: 7),
          ],
          Text(
            text,
            style: AppTypography.label(fontSize: 11, color: textColor).copyWith(letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDot extends StatefulWidget {
  final Color color;
  const _AnimatedDot({required this.color});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_ctrl),
      child: ScaleTransition(
        scale: Tween(begin: 0.7, end: 1.0).animate(_ctrl),
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
