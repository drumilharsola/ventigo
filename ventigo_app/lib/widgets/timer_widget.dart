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
  // Track the last server value to detect actual server updates vs rebuilds
  int _lastServerValue = -1;

  @override
  void initState() {
    super.initState();
    _secs = widget.remainingSeconds;
    _lastServerValue = widget.remainingSeconds;
    _startTick();
  }

  @override
  void didUpdateWidget(TimerWidget old) {
    super.didUpdateWidget(old);
    // Only resync if the SERVER actually sent a new value
    // (i.e. the incoming remainingSeconds differs from the last known server value)
    if (widget.remainingSeconds != _lastServerValue) {
      _lastServerValue = widget.remainingSeconds;
      // Resync: trust the server value, but allow small drift (1s) to avoid jitter
      if ((_secs - widget.remainingSeconds).abs() > 1) {
        _secs = widget.remainingSeconds;
      }
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
    final display = _secs.clamp(0, 99 * 60 + 59);
    final mins = (display ~/ 60).toString().padLeft(2, '0');
    final sec = (display % 60).toString().padLeft(2, '0');

    final Color timerColor;
    if (display <= 30) {
      timerColor = AppColors.danger;
    } else if (display <= 120) {
      timerColor = const Color(0xFFE8B450); // orange
    } else if (display <= 300) {
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
