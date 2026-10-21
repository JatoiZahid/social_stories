import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/scene_catalog.dart';
import '../../../shared/widgets/widgets.dart';

/// Grid of the bundled scene illustrations. Tap one to use it on the page.
class ScenePicker extends StatelessWidget {
  const ScenePicker({super.key, required this.selected, required this.onSelected});

  /// Asset path of the current picture.
  final String selected;
  final ValueChanged<Scene> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: AppDimens.gapM,
        crossAxisSpacing: AppDimens.gapM,
        childAspectRatio: 0.92,
      ),
      itemCount: SceneCatalog.all.length,
      itemBuilder: (context, index) {
        final scene = SceneCatalog.all[index];
        return _SceneTile(
          scene: scene,
          selected: scene.asset == selected,
          onTap: () => onSelected(scene),
        );
      },
    );
  }
}

class _SceneTile extends StatelessWidget {
  const _SceneTile({required this.scene, required this.selected, required this.onTap});

  final Scene scene;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Picture: ${scene.name}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimens.radiusM + 2),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SceneImage(frame: SceneFrame(scene.asset), radius: AppDimens.radiusM - 1),
                    if (selected)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.check_rounded, size: 16, color: AppColors.onPrimary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.gapXS),
            Text(
              scene.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.inkSoft,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
