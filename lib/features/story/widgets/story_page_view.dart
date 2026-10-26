import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/animation/scene_playback.dart';
import '../../../core/theme/app_dimens.dart';
import 'animated_story_scene.dart';
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
    this.playback,
    this.reducedMotion = false,
  });

  final StoryPage page;
  final ValueListenable<bool> isSpeaking;
  final VoidCallback onSpeakerPressed;
  final bool largeText;
  final ScenePlayback? playback;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final image = playback == null
        ? SceneImage(frame: page.frame)
        : AnimatedStoryScene(
            page: page, playback: playback!, reducedMotion: reducedMotion);
    final narration = NarrationCard(
      lead: page.lead,
      body: page.body,
      isSpeaking: isSpeaking,
      onSpeakerPressed: onSpeakerPressed,
      largeText: largeText,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppDimens.wideStoryLayout &&
            MediaQuery.orientationOf(context) == Orientation.landscape) {
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
