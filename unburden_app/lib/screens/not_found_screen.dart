import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../widgets/flow_button.dart';
import '../widgets/orb_background.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Stack(
        children: [
          const OrbBackground(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('404', style: AppTypography.display(fontSize: 80, color: Colors.white.withValues(alpha: 0.12))),
                const SizedBox(height: 12),
                Text('Page not found.', style: AppTypography.heading(fontSize: 22)),
                const SizedBox(height: 8),
                Text("The page you're looking for doesn't exist.", style: AppTypography.body(fontSize: 14, color: AppColors.slate)),
                const SizedBox(height: 28),
                FlowButton(label: '← Back home', variant: FlowButtonVariant.ghost, onPressed: () => context.go('/')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
