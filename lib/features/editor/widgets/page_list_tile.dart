import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/story.dart';
import '../../../shared/widgets/widgets.dart';

/// One row in the story editor's page list: thumbnail, text preview and
/// actions. [dragHandle] is supplied by the reorderable list.
class PageListTile extends StatelessWidget {
  const PageListTile({
    super.key,
    required this.number,
    required this.page,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
    required this.dragHandle,
  });

  final int number;
  final StoryPage page;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasText = page.lead.trim().isNotEmpty || page.body.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.gapXS + 2),
      child: AppCard(
        onTap: onTap,
        radius: AppDimens.radiusL,
        padding: const EdgeInsets.all(AppDimens.gapS),
        semanticLabel: 'Page $number. ${hasText ? page.narration : 'No text yet'}. Tap to edit.',
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 76,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SceneImage(frame: page.frame, radius: AppDimens.radiusM),
                  Positioned(
                    left: 4,
                    top: 4,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        '$number',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.gapM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page.lead.trim().isEmpty ? 'No text yet – tap to write' : page.lead,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: page.lead.trim().isEmpty ? AppColors.inkSoft : AppColors.ink,
                      fontStyle: page.lead.trim().isEmpty ? FontStyle.italic : null,
                    ),
                  ),
                  if (page.body.trim().isNotEmpty)
                    Text(
                      page.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Duplicate page',
              icon: const Icon(Icons.copy_rounded),
              color: AppColors.inkSoft,
              onPressed: onDuplicate,
            ),
            IconButton(
              tooltip: 'Delete page',
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.inkSoft,
              onPressed: onDelete,
            ),
            dragHandle,
          ],
        ),
      ),
    );
  }
}
