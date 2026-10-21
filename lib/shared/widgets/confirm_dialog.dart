import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'pill_button.dart';

/// Yes/no question used before destructive actions (delete, reset).
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.icon = Icons.help_outline_rounded,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final IconData icon;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    IconData icon = Icons.help_outline_rounded,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(title: title, message: message, confirmLabel: confirmLabel, icon: icon),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusXL)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.gapXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.primary),
              const SizedBox(height: AppDimens.gapM),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppDimens.gapS),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: AppDimens.gapXL),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Cancel',
                      variant: PillButtonVariant.soft,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapM),
                  Expanded(
                    child: PillButton(label: confirmLabel, onPressed: () => Navigator.of(context).pop(true)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
