import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../data/models/story.dart';
import '../../../shared/widgets/widgets.dart';

/// One page: illustration + narration. Side by side on wide screens
/// (matches the Figma card), stacked on phones in portrait.
class StoryPageView extends StatelessWidget {
  const StoryPageView({
    super.key,
    required this.page,
    required this.isSpeaking,
    required this.onSpeakerPressed,
    this.largeText = false,
  });

  final StoryPage page;
  final ValueListenable<bool> isSpeaking;
  final VoidCallback onSpeakerPressed;
  final bool largeText;

  @override
  Widget build(BuildContext context) {
    final image = SceneImage(frame: page.frame);
    final narration = NarrationCard(
      lead: page.lead,
      body: page.body,
      isSpeaking: isSpeaking,
      onSpeakerPressed: onSpeakerPressed,
      largeText: largeText,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppDimens.wideStoryLayout) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 11, child: image),
              const SizedBox(width: AppDimens.gapL),
              Expanded(flex: 9, child: narration),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: image),
            const SizedBox(height: AppDimens.gapM),
            Expanded(flex: 4, child: narration),
          ],
        );
      },
    );
  }
}
