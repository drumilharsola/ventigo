import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Countdown timer display (MM:SS) - port of Timer.tsx.
class TimerWidget extends StatefulWidget {
  final int remainingSeconds;
  final VoidCallback? onEnd;

  const TimerWidget({super.key, required this.remainingSeconds, this.onEnd});

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  late int _secs;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secs = widget.remainingSeconds;
    _startTick();
  }

  @override
  void didUpdateWidget(TimerWidget old) {
    super.didUpdateWidget(old);
    // Only resync if the server value differs by more than 2s (avoids jitter)
    if ((old.remainingSeconds - widget.remainingSeconds).abs() > 2) {
      _secs = widget.remainingSeconds;
    }
  }

  void _startTick() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secs <= 0) {
        _timer?.cancel();
        widget.onEnd?.call();
        return;
      }
      setState(() => _secs--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = (_secs ~/ 60).toString().padLeft(2, '0');
    final sec = (_secs % 60).toString().padLeft(2, '0');

    final Color timerColor;
    if (_secs <= 30) {
      timerColor = AppColors.danger;
    } else if (_secs <= 120) {
      timerColor = const Color(0xFFE8B450); // orange
    } else if (_secs <= 300) {
      timerColor = const Color(0xFFD4A844); // amber
    } else {
      timerColor = AppColors.accent;
    }

    return Text(
      '$mins:$sec',
      style: AppTypography.ui(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: timerColor,
      ),
    );
  }
}
