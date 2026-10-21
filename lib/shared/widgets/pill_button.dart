import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

enum PillButtonVariant {
  /// Solid blue – "Next", "Finish".
  primary,

  /// Light tinted with blue text – "Listen Again", "Read Again".
  soft,
}

/// The rounded button used for every action in the app.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.variant = PillButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final PillButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == PillButtonVariant.primary;
    final background = isPrimary ? AppColors.primary : AppColors.tint;
    final foreground = isPrimary ? AppColors.onPrimary : AppColors.primary;
    final shape = StadiumBorder(
      side: isPrimary ? BorderSide.none : const BorderSide(color: AppColors.border),
    );
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        );

    return Material(
      color: background,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppDimens.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                Widget text = Text(label, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
                // In a narrow space (e.g. two buttons side by side) the label
                // shrinks instead of overflowing. Flexible is only allowed when
                // the width is bounded, so buttons can still sit in a plain Row.
                if (constraints.hasBoundedWidth) text = Flexible(child: text);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (leadingIcon != null) ...[
                      Icon(leadingIcon, size: 20, color: foreground),
                      const SizedBox(width: AppDimens.gapS),
                    ],
                    text,
                    if (trailingIcon != null) ...[
                      const SizedBox(width: AppDimens.gapS),
                      Icon(trailingIcon, size: 20, color: foreground),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
