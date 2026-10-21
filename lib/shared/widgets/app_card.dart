import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// White rounded surface with the soft blue shadow used across the design.
/// Pass [onTap] to make the whole card tappable.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.gapL),
    this.radius = AppDimens.radiusXL,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(customBorder: shape, onTap: onTap, child: content);
    }
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: Material(
          color: AppColors.surface,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      ),
    );
  }
}
