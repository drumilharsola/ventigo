import 'package:flutter/material.dart';
import '../config/theme.dart';

enum PillVariant { accent, success, plain }

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
        bg = AppColors.flow5.withValues(alpha: 0.7);
        borderColor = AppColors.ink;
        textColor = AppColors.ink;
      case PillVariant.success:
        bg = AppColors.success.withValues(alpha: 0.12);
        borderColor = AppColors.success.withValues(alpha: 0.2);
        textColor = AppColors.success;
      case PillVariant.plain:
        bg = AppColors.white.withValues(alpha: 0.8);
        borderColor = AppColors.border;
        textColor = AppColors.ink;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor, width: 1.4),
        borderRadius: BorderRadius.circular(AppRadii.full),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6))],
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
            style: AppTypography.label(fontSize: 11, color: textColor).copyWith(letterSpacing: 1.1),
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
