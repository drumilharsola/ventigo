import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../config/brand.dart';
import '../config/theme.dart';

class FlowLogo extends StatefulWidget {
  final bool dark;
  final VoidCallback? onTap;

  const FlowLogo({super.key, this.dark = false, this.onTap});

  @override
  State<FlowLogo> createState() => _FlowLogoState();
}

class _FlowLogoState extends State<FlowLogo> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.dark ? AppColors.ink : AppColors.white;

    return GestureDetector(
      onTap: widget.onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return CustomPaint(
                size: const Size(34, 34),
                painter: _LogoIconPainter(
                  progress: _ctrl.value,
                  dark: widget.dark,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Brand.logo.prefix,
                style: AppTypography.title(fontSize: 18, color: textColor).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => ui.Gradient.linear(
                  Offset.zero,
                  Offset(bounds.width, 0),
                  [AppColors.peach, AppColors.amber, AppColors.lavender],
                  [0.0, 0.5, 1.0],
                ),
                child: Text(
                  Brand.logo.emphasis,
                  style: AppTypography.title(fontSize: 18, color: AppColors.white).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Draws two overlapping speech bubbles: a peach venter bubble (left) and a
/// lavender listener bubble (right), connected by a small amber dot.
class _LogoIconPainter extends CustomPainter {
  final double progress;
  final bool dark;

  _LogoIconPainter({required this.progress, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;

    // Breathing factor
    final breathe = 0.95 + 0.05 * sin(progress * 2 * pi);

    // ── Left bubble - peach/coral (the Venter, speaking) ──
    final peachPaint = Paint()..color = AppColors.peach.withValues(alpha: 0.92);
    final lr = w * 0.30 * breathe;
    final lx = cx - w * 0.10;
    final ly = cy - h * 0.02;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(lx, ly), width: lr * 2, height: lr * 1.7),
      peachPaint,
    );

    // Venter bubble tail (small triangle)
    final tailPath = Path()
      ..moveTo(lx - lr * 0.3, ly + lr * 0.65)
      ..lineTo(lx - lr * 0.75, ly + lr * 1.1)
      ..lineTo(lx - lr * 0.05, ly + lr * 0.80)
      ..close();
    canvas.drawPath(tailPath, peachPaint);

    // ── Right bubble - lavender (the Listener) ──
    final lavPaint = Paint()..color = AppColors.lavender.withValues(alpha: 0.88);
    final rr = w * 0.26 * breathe;
    final rx = cx + w * 0.12;
    final ry = cy + h * 0.04;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(rx, ry), width: rr * 1.8, height: rr * 1.6),
      lavPaint,
    );
  }

  @override
  bool shouldRepaint(_LogoIconPainter old) => old.progress != progress || old.dark != dark;
}
