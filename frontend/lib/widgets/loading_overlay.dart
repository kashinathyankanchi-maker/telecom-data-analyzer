// lib/widgets/loading_overlay.dart
// Simple loading overlay — shimmer removed (no longer a dependency).
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Full-screen loading overlay.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgBase.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                strokeWidth: 2.5,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: AppTextStyles.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated placeholder row for skeleton loading.
class ShimmerRow extends StatelessWidget {
  const ShimmerRow({super.key, this.height = 56});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// Shows N placeholder rows as a loading list.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 5, this.rowHeight = 56});
  final int count;
  final double rowHeight;

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(count, (_) => ShimmerRow(height: rowHeight)),
  );
}
