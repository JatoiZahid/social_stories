import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Small rounded label – "1 of 6" in the player, "6 pages" on cover cards.
class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.label, this.semanticsLabel});

  final String label;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
        );
    return Semantics(
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.tint,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}
