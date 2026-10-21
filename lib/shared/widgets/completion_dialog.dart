import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'pill_button.dart';

enum CompletionAction { readAgain, done }

/// "Great job!" shown after the last page of any story.
class CompletionDialog extends StatelessWidget {
  const CompletionDialog({super.key, required this.storyTitle});

  final String storyTitle;

  static Future<CompletionAction?> show(BuildContext context, {required String storyTitle}) {
    return showDialog<CompletionAction>(
      context: context,
      builder: (_) => CompletionDialog(storyTitle: storyTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusXL)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.gapXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: AppColors.tint, shape: BoxShape.circle),
                child: const Icon(Icons.star_rounded, size: 48, color: AppColors.celebrate),
              ),
              const SizedBox(height: AppDimens.gapL),
              Text('Great job!', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppDimens.gapS),
              Text(
                'You finished “$storyTitle”.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppDimens.gapXL),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppDimens.gapM,
                runSpacing: AppDimens.gapM,
                children: [
                  PillButton(
                    label: 'Read Again',
                    leadingIcon: Icons.replay_rounded,
                    variant: PillButtonVariant.soft,
                    onPressed: () => Navigator.of(context).pop(CompletionAction.readAgain),
                  ),
                  PillButton(
                    label: 'All Stories',
                    leadingIcon: Icons.auto_stories_rounded,
                    onPressed: () => Navigator.of(context).pop(CompletionAction.done),
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
