import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Typing indicator — three animated dots.
class TypingIndicator extends StatefulWidget {
  final String username;

  const TypingIndicator({super.key, required this.username});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    });
    // Stagger: 0ms, 200ms, 400ms
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controllers[1].repeat();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controllers[2].repeat();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Padding(
                padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
                child: _Dot(controller: _controllers[i]),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.username,
          style: AppTypography.label(fontSize: 10, color: AppColors.slate),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  const _Dot({required this.controller});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.0), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.3), weight: 60),
      ]).animate(controller),
      child: ScaleTransition(
        scale: TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 60),
        ]).animate(controller),
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.fog,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
