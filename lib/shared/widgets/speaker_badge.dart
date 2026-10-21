import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Circular speaker button that fills in while narration is playing.
class SpeakerBadge extends StatelessWidget {
  const SpeakerBadge({super.key, required this.isSpeaking, required this.onPressed});

  final ValueListenable<bool> isSpeaking;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpeaking,
      builder: (context, speaking, _) {
        return Tooltip(
          message: speaking ? 'Stop reading' : 'Read aloud',
          child: Semantics(
            button: true,
            label: speaking ? 'Stop reading' : 'Read this page aloud',
            excludeSemantics: true,
            onTap: onPressed,
            child: InkResponse(
              onTap: onPressed,
              radius: AppDimens.minTapTarget / 2 + 4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: AppDimens.minTapTarget,
                height: AppDimens.minTapTarget,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: speaking ? AppColors.primary : AppColors.surface,
                  border: Border.all(color: speaking ? AppColors.primary : AppColors.border),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    speaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                    key: ValueKey<bool>(speaking),
                    color: speaking ? AppColors.onPrimary : AppColors.primary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
