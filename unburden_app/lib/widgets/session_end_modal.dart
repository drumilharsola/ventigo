import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../widgets/flow_button.dart';

/// Session-end modal - maps SessionEndModal.tsx.
class SessionEndModal extends StatelessWidget {
  final bool canExtend;
  final VoidCallback onExtend;
  final VoidCallback onClose;

  const SessionEndModal({
    super.key,
    required this.canExtend,
    required this.onExtend,
    required this.onClose,
  });

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
                child: const Text('⏱', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(height: 20),
              Text("Time's up.", style: AppTypography.heading(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                'The session has ended.',
                style: AppTypography.body(color: AppColors.slate),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              if (canExtend)
                FlowButton(
                  label: 'Extend 15 minutes',
                  onPressed: onExtend,
                  expand: true,
                ),
              if (canExtend) const SizedBox(height: 10),
              FlowButton(
                label: 'Find a new match',
                variant: FlowButtonVariant.ghost,
                onPressed: () => context.go('/lobby'),
                expand: true,
              ),
              const SizedBox(height: 10),
              FlowButton(
                label: 'Close',
                variant: FlowButtonVariant.ghost,
                size: FlowButtonSize.sm,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
