import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../state/pending_wait_provider.dart';
import '../widgets/timer_widget.dart';

class WaitingOverlay extends ConsumerStatefulWidget {
  const WaitingOverlay({super.key});

  @override
  ConsumerState<WaitingOverlay> createState() => _WaitingOverlayState();
}

class _WaitingOverlayState extends ConsumerState<WaitingOverlay> {
  Offset _position = const Offset(16, 80);
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final wait = ref.watch(pendingWaitProvider);
    final size = MediaQuery.sizeOf(context);

    // Navigate to chat when matched
    if (wait.matchedRoomId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final roomId = ref.read(pendingWaitProvider).matchedRoomId;
        if (roomId != null) {
          ref.read(pendingWaitProvider.notifier).clearMatch();
          ref.read(routerProvider).go('/chat?room_id=${Uri.encodeComponent(roomId)}');
        }
      });
    }

    if (!wait.isWaiting) return const SizedBox.shrink();

    // Hide overlay when on the chats tab (bottom sheet handles waiting there)
    final location = ref.read(routerProvider).routerDelegate.currentConfiguration.uri.path;
    if (location == '/chats' || location == '/waiting') {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _position.dx.clamp(0.0, size.width - 200),
      top: _position.dy.clamp(0.0, size.height - 80),
      child: GestureDetector(
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onPanEnd: (_) => setState(() => _dragging = false),
        child: AnimatedScale(
          scale: _dragging ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Material(
            elevation: 12,
            borderRadius: AppRadii.lgAll,
            color: AppColors.ink.withValues(alpha: 0.94),
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Finding someone…', style: AppTypography.ui(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TimerWidget(
                        remainingSeconds: wait.remaining,
                        onEnd: () => ref.read(pendingWaitProvider.notifier).cancel(),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => ref.read(routerProvider).go('/chats'),
                            child: Icon(Icons.open_in_full_rounded, size: 16, color: Colors.white54),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => ref.read(pendingWaitProvider.notifier).cancel(),
                            child: Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
