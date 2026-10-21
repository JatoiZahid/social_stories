import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/story.dart';
import 'app_card.dart';
import 'info_pill.dart';
import 'scene_image.dart';

/// Library tile: cover illustration, title and page count.
/// In parent mode ([editing]) it shows an edit badge.
class StoryCoverCard extends StatelessWidget {
  const StoryCoverCard({
    super.key,
    required this.story,
    required this.onTap,
    this.editing = false,
  });

  final Story story;
  final VoidCallback onTap;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final pageCount = story.pages.length;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimens.gapS + 2),
      semanticLabel: editing
          ? 'Edit ${story.displayTitle}, $pageCount pages'
          : '${story.displayTitle}, $pageCount pages',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SceneImage(frame: story.cover),
                  if (editing)
                    const Positioned(top: 8, right: 8, child: _EditBadge()),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapS + 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapXS),
              child: Text(
                story.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: AppDimens.gapXS + 2),
            Padding(
              padding: const EdgeInsets.only(left: AppDimens.gapXS, bottom: AppDimens.gapXS),
              child: InfoPill(label: pageCount == 1 ? '1 page' : '$pageCount pages'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditBadge extends StatelessWidget {
  const _EditBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit_rounded, size: 16, color: AppColors.onPrimary),
          const SizedBox(width: 4),
          Text(
            'Edit',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

/// Dashed-looking "+ New story" tile shown at the end of the grid in parent mode.
class AddStoryCard extends StatelessWidget {
  const AddStoryCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Create a new story',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.tint,
            borderRadius: BorderRadius.circular(AppDimens.radiusL),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_circle_rounded, size: 48, color: AppColors.primary),
                const SizedBox(height: AppDimens.gapS),
                Text(
                  'New story',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
