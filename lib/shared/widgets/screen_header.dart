import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';

/// Centered title with optional subtitle and leading / trailing actions.
/// Used by both the library and the story player.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);
    return Row(
      children: [
        SizedBox(width: AppDimens.minTapTarget, child: leading),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: style,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppDimens.gapXS),
                subtitle!,
              ],
            ],
          ),
        ),
        SizedBox(width: AppDimens.minTapTarget, child: trailing),
      ],
    );
  }
}
