import 'dart:math';
import 'package:flutter/material.dart';
import '../config/brand.dart';

/// Animated FlowLogo — spinning ring with orbiting dot + brand text.
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.dark ? const Color(0xFF0B2F2A) : const Color(0xFF62B49C);
    final dotColor = const Color(0xFF62B49C);
    final textColor = widget.dark ? const Color(0xFF0B2F2A) : Colors.white;

    return GestureDetector(
      onTap: widget.onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Spinning ring + dot
          SizedBox(
            width: 28,
            height: 28,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return CustomPaint(
                  painter: _LogoPainter(
                    progress: _ctrl.value,
                    ringColor: ringColor,
                    dotColor: dotColor,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          // Brand text: Unb*ur*den
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Comfortaa',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.2,
              ),
              children: [
                TextSpan(text: Brand.logo.prefix),
                TextSpan(
                  text: Brand.logo.emphasis,
                  style: TextStyle(fontStyle: FontStyle.italic, color: dotColor),
                ),
                TextSpan(text: Brand.logo.suffix),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color dotColor;

  _LogoPainter({required this.progress, required this.ringColor, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Ring
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ringPaint);

    // Orbiting dot
    final angle = progress * 2 * pi;
    final dotOffset = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(dotOffset, 3, dotPaint);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.progress != progress;
}
