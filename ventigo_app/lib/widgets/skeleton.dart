import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme.dart';

/// A single shimmer placeholder bar.
class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLine({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Shimmer card skeleton matching post/conversation card layouts.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.border, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLine(width: 100, height: 12),
                  const SizedBox(height: 6),
                  const SkeletonLine(width: 60, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonLine(height: 12),
          const SizedBox(height: 8),
          const SkeletonLine(width: 200, height: 12),
          const SizedBox(height: 10),
          const SkeletonLine(width: 80, height: 10),
        ],
      ),
    );
  }
}

/// Shimmer list row skeleton matching conversation/history tiles.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.border, shape: BoxShape.circle)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: 120, height: 13),
                const SizedBox(height: 6),
                const SkeletonLine(width: 80, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps children in a shimmer animation.
class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.snow,
      child: child,
    );
  }
}
