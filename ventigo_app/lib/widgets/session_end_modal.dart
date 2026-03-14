import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../widgets/flow_button.dart';

/// Session-end modal with mood check, continue, and extend.
class SessionEndModal extends StatefulWidget {
  final bool canExtend;
  final bool canContinue;
  final bool peerLeft;
  final bool continueWaiting;
  final VoidCallback onExtend;
  final VoidCallback onContinue;
  final VoidCallback onClose;
  final void Function(String mood)? onFeedback;

  const SessionEndModal({
    super.key,
    required this.canExtend,
    this.canContinue = true,
    this.peerLeft = false,
    this.continueWaiting = false,
    required this.onExtend,
    this.onContinue = _noop,
    required this.onClose,
    this.onFeedback,
  });

  static void _noop() {}

  @override
  State<SessionEndModal> createState() => _SessionEndModalState();
}

class _SessionEndModalState extends State<SessionEndModal> {
  String? _selectedMood;

  static const _moods = [
    ('😌', 'Calm', 'calm'),
    ('😊', 'Better', 'better'),
    ('😐', 'Same', 'same'),
    ('😔', 'Worse', 'worse'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadii.lgAll,
            border: Border.all(color: AppColors.border),
            boxShadow: warmShadow(blur: 32, opacity: 0.12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentDim,
                  border: Border.all(color: AppColors.accentGlow),
                ),
                alignment: Alignment.center,
                child: Text(widget.peerLeft ? '👋' : '⏱', style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(height: 20),
              Text(
                widget.peerLeft ? 'They had to go.' : "Time's up.",
                style: AppTypography.heading(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                widget.peerLeft
                    ? 'Your conversation mattered — even if it was brief.'
                    : 'How are you feeling?',
                style: AppTypography.body(color: AppColors.slate),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Mood picker
              if (!widget.peerLeft) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _moods.map((m) {
                    final selected = _selectedMood == m.$3;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedMood = m.$3);
                        widget.onFeedback?.call(m.$3);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: selected ? AppColors.accentDim : Colors.transparent,
                          border: Border.all(
                            color: selected ? AppColors.accent : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(m.$1, style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(m.$2, style: AppTypography.body(fontSize: 10, color: AppColors.slate)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Actions
              if (widget.canContinue && !widget.peerLeft) ...[
                FlowButton(
                  label: widget.continueWaiting ? 'Waiting for them…' : 'Continue chatting',
                  onPressed: widget.continueWaiting ? null : widget.onContinue,
                  expand: true,
                ),
                const SizedBox(height: 10),
              ],
              if (widget.canExtend && !widget.peerLeft) ...[
                FlowButton(
                  label: 'Extend 15 minutes',
                  variant: widget.canContinue ? FlowButtonVariant.ghost : FlowButtonVariant.primary,
                  onPressed: widget.onExtend,
                  expand: true,
                ),
                const SizedBox(height: 10),
              ],
              FlowButton(
                label: 'Back to lobby',
                variant: FlowButtonVariant.ghost,
                onPressed: () => context.go('/chats'),
                expand: true,
              ),
              const SizedBox(height: 10),
              FlowButton(
                label: 'Close',
                variant: FlowButtonVariant.ghost,
                size: FlowButtonSize.sm,
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
