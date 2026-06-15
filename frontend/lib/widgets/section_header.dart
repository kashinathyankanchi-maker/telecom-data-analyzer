// lib/widgets/section_header.dart
import 'package:flutter/material.dart';
import '../core/theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.accentColor,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left accent bar
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: accentColor ?? AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleLarge),
              if (subtitle != null)
                Text(subtitle!, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
