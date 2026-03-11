import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Frosted-glass card — maps .glass-card from globals.css.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = AppRadii.lg,
    this.blur = 30,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF), // ~4%
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: const Color(0x14FFFFFF)), // ~8%
          ),
          child: child,
        ),
      ),
    );
  }
}
