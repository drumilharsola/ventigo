import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

enum FlowButtonVariant { accent, primary, ghost, danger, venter, listener }
enum FlowButtonSize { lg, md, sm }

class FlowButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final FlowButtonVariant variant;
  final FlowButtonSize size;
  final bool loading;
  final bool expand;
  final IconData? icon;

  const FlowButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = FlowButtonVariant.accent,
    this.size = FlowButtonSize.lg,
    this.loading = false,
    this.expand = false,
    this.icon,
  });

  @override
  State<FlowButton> createState() => _FlowButtonState();
}

class _FlowButtonState extends State<FlowButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;

    Color bg;
    Color fg;
    Color shadow;
    BorderSide? border;

    switch (widget.variant) {
      case FlowButtonVariant.accent:
        bg = AppColors.accent;
        fg = AppColors.white;
        shadow = AppColors.accent.withValues(alpha: 0.28);
        border = null;
      case FlowButtonVariant.primary:
        bg = AppColors.paper;
        fg = AppColors.ink;
        shadow = AppColors.sunflower.withValues(alpha: 0.18);
        border = BorderSide(color: AppColors.ink, width: 1.5);
      case FlowButtonVariant.ghost:
        bg = AppColors.white.withValues(alpha: 0.82);
        fg = AppColors.ink;
        shadow = AppColors.ink.withValues(alpha: 0.08);
        border = BorderSide(color: AppColors.border, width: 1.3);
      case FlowButtonVariant.danger:
        bg = AppColors.danger.withValues(alpha: 0.12);
        fg = AppColors.danger;
        shadow = AppColors.danger.withValues(alpha: 0.12);
        border = BorderSide(color: AppColors.danger.withValues(alpha: 0.32), width: 1.5);
      case FlowButtonVariant.venter:
        bg = AppColors.venterPrimary;
        fg = AppColors.white;
        shadow = AppColors.venterPrimary.withValues(alpha: 0.26);
        border = null;
      case FlowButtonVariant.listener:
        bg = AppColors.listenerPrimary;
        fg = AppColors.white;
        shadow = AppColors.listenerPrimary.withValues(alpha: 0.24);
        border = null;
    }

    EdgeInsets pad;
    double fontSize;
    switch (widget.size) {
      case FlowButtonSize.lg:
        pad = const EdgeInsets.symmetric(horizontal: 30, vertical: 18);
        fontSize = 14;
      case FlowButtonSize.md:
        pad = const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
        fontSize = 13;
      case FlowButtonSize.sm:
        pad = const EdgeInsets.symmetric(horizontal: 18, vertical: 10);
        fontSize = 12;
    }

    return GestureDetector(
      onTapDown: enabled ? (_) => _scaleCtrl.forward() : null,
      onTapUp: enabled ? (_) => _scaleCtrl.reverse() : null,
      onTapCancel: enabled ? () => _scaleCtrl.reverse() : null,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1.0 : 0.5,
          child: SizedBox(
            width: widget.expand ? double.infinity : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: shadow,
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        widget.onPressed?.call();
                      }
                    : null,
                style: TextButton.styleFrom(
                  backgroundColor: bg,
                  foregroundColor: fg,
                  padding: pad,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.mdAll,
                    side: border ?? BorderSide.none,
                  ),
                  textStyle: AppTypography.ui(fontSize: fontSize, fontWeight: FontWeight.w800),
                ),
                child: widget.loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[Icon(widget.icon, size: 18), const SizedBox(width: 8)],
                          Text(widget.label),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
