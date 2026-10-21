import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'speaker_badge.dart';

/// Tinted panel with the speaker button, the bold lead sentence and body text.
class NarrationCard extends StatelessWidget {
  const NarrationCard({
    super.key,
    required this.lead,
    required this.body,
    required this.isSpeaking,
    required this.onSpeakerPressed,
    this.largeText = false,
  });

  final String lead;
  final String body;
  final ValueListenable<bool> isSpeaking;
  final VoidCallback onSpeakerPressed;
  final bool largeText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final leadSize = largeText ? 24.0 : 19.0;
    final bodySize = largeText ? 20.0 : 16.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.tint,
        borderRadius: BorderRadius.circular(AppDimens.radiusL),
        border: Border.all(color: AppColors.border.withAlpha(140)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.gapL),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SpeakerBadge(isSpeaking: isSpeaking, onPressed: onSpeakerPressed),
                const SizedBox(height: AppDimens.gapL),
                Text(
                  lead,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: leadSize,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppDimens.gapM),
                Text(
                  body,
                  style: textTheme.bodyLarge?.copyWith(
                    fontSize: bodySize,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
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
