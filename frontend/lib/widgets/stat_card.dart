// lib/widgets/stat_card.dart
// A premium metric card used on search results and dashboards.
import 'package:flutter/material.dart';
import '../core/theme.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: AppTextStyles.headlineMedium.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySmall),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            )),
          ],
        ],
      ),
    );
  }
}
