import 'package:flutter/material.dart';


/// Ambient background orbs — maps .orb-a, .orb-b from globals.css.
class OrbBackground extends StatelessWidget {
  const OrbBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        // orb-a: 600×600, purple-ish, top-left area
        Positioned(
          top: -200,
          left: -150,
          child: _Orb(
            size: 600,
            color: Color(0x24B8A4F4), // rgba(184,164,244,0.14)
            blur: 120,
          ),
        ),
        // orb-b: 500×500, pink-ish, bottom-right area
        Positioned(
          bottom: -180,
          right: -120,
          child: _Orb(
            size: 500,
            color: Color(0x1AF0A0B4), // rgba(240,160,180,0.10)
            blur: 120,
          ),
        ),
      ],
    );
  }
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
