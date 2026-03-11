import 'package:flutter/material.dart';
import '../config/theme.dart';

enum FlowButtonVariant { accent, primary, ghost, danger }
enum FlowButtonSize { lg, md, sm }

/// Styled button — maps .btn-accent, .btn-primary, .btn-ghost, .btn-danger.
class FlowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final FlowButtonVariant variant;
  final FlowButtonSize size;
  final bool loading;
  final bool expand;

  const FlowButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = FlowButtonVariant.accent,
    this.size = FlowButtonSize.lg,
    this.loading = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    Color bg;
    Color fg;
    BorderSide? border;

    switch (variant) {
      case FlowButtonVariant.accent:
        bg = AppColors.accent;
        fg = AppColors.ink;
        border = null;
      case FlowButtonVariant.primary:
        bg = AppColors.white;
        fg = AppColors.ink;
        border = null;
      case FlowButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.fog;
        border = const BorderSide(color: AppColors.border);
      case FlowButtonVariant.danger:
        bg = const Color(0x1AE88888);
        fg = AppColors.danger;
        border = BorderSide(color: AppColors.danger.withValues(alpha: 0.25));
    }

    EdgeInsets pad;
    double fontSize;
    switch (size) {
      case FlowButtonSize.lg:
        pad = const EdgeInsets.symmetric(horizontal: 36, vertical: 16);
        fontSize = 14;
      case FlowButtonSize.md:
        pad = const EdgeInsets.symmetric(horizontal: 26, vertical: 12);
        fontSize = 13;
      case FlowButtonSize.sm:
        pad = const EdgeInsets.symmetric(horizontal: 18, vertical: 8);
        fontSize = 12;
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.5,
      child: SizedBox(
        width: expand ? double.infinity : null,
        child: TextButton(
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            padding: pad,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.mdAll,
              side: border ?? BorderSide.none,
            ),
            textStyle: AppTypography.ui(fontSize: fontSize, fontWeight: FontWeight.w600),
          ),
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Text(label),
        ),
      ),
    );
  }
}
