import 'package:flutter/material.dart';
import '../config/theme.dart';

class OrbBackground extends StatelessWidget {
  final bool dark;
  const OrbBackground({super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final background = dark ? AppColors.darkSurface : AppColors.snow;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [AppColors.darkSurface, AppColors.charcoal]
                  : [AppColors.snow, AppColors.paper],
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(color: dark ? AppColors.grid.withValues(alpha: 0.28) : AppColors.ink.withValues(alpha: 0.035)),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          child: _Orb(
            size: 360,
            color: (dark ? AppColors.flow4 : AppColors.flow4).withValues(alpha: dark ? 0.18 : 0.26),
            blur: 120,
          ),
        ),
        Positioned(
          top: 120,
          left: -120,
          child: _Orb(
            size: 280,
            color: AppColors.listenerPrimary.withValues(alpha: dark ? 0.16 : 0.18),
            blur: 100,
          ),
        ),
        Positioned(
          bottom: -80,
          left: 60,
          child: _Orb(
            size: 260,
            color: AppColors.flow5.withValues(alpha: dark ? 0.11 : 0.16),
            blur: 100,
          ),
        ),
        Positioned(
          top: 80,
          left: 24,
          child: Transform.rotate(
            angle: -0.16,
            child: _Sticker(width: 88, height: 28, color: AppColors.ink.withValues(alpha: dark ? 0.9 : 0.08)),
          ),
        ),
        Positioned(
          bottom: 120,
          right: 36,
          child: Transform.rotate(
            angle: 0.14,
            child: _Sticker(width: 118, height: 36, color: AppColors.plum.withValues(alpha: dark ? 0.32 : 0.18)),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const gap = 36.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.color != color;
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double blur;

  const _Orb({required this.size, required this.color, required this.blur});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: blur, spreadRadius: blur / 2),
        ],
      ),
    );
  }
}

class _Sticker extends StatelessWidget {
  const _Sticker({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
