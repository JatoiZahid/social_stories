import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Header icon button (back chevron, settings gear) with a 48px tap target.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 28,
      color: AppColors.ink,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppDimens.minTapTarget),
      ),
    );
  }
}
