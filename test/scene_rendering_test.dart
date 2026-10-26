import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_stories/core/animation/scene_playback.dart';
import 'package:social_stories/data/models/story.dart';
import 'package:social_stories/features/story/widgets/animated_story_scene.dart';

void main() {
  testWidgets(
      'all 75 bundled scenes decode, advance real action frames and pause',
      (tester) async {
    final raw = jsonDecode(File('assets/data/stories.json').readAsStringSync())
        as Map<String, dynamic>;
    final stories = (raw['stories'] as List)
        .map((s) => Story.fromJson(s as Map<String, dynamic>));
    var count = 0;
    for (final story in stories) {
      for (final page in story.pages) {
        count++;
        final config = page.animation!;
        final clock = ScenePlayback()
          ..prepare(narration: page.narration, rate: 0.4);
        await tester.pumpWidget(
            MaterialApp(home: AnimatedStoryScene(page: page, playback: clock)));
        await tester.runAsync(() => precacheImage(AssetImage(config.asset),
            tester.element(find.byType(AnimatedStoryScene))));
        await tester.pump();
        final painted = find.byKey(const ValueKey('story-action-frames'));
        expect(painted, findsOneWidget,
            reason:
                '${page.id}: actual atlas must decode, not fall back to a poster');
        SceneAtlasPainter painter() =>
            tester.widget<CustomPaint>(painted).painter! as SceneAtlasPainter;
        clock.play();
        await tester.pump();
        expect(painter().frame, 0, reason: page.id);
        if (config.loop) {
          await tester
              .pump(Duration(milliseconds: (1000 / config.fps).ceil() + 50));
          expect(painter().frame, 1,
              reason: '${page.id}: articulated action frame must change');
        } else {
          clock.updateProgress(page.narration.length);
          await tester.pump();
          expect(painter().frame, config.frameCount - 1,
              reason: '${page.id}: one-shot holds final pose');
        }
        clock.pause();
        final pausedFrame = painter().frame;
        await tester.pump(const Duration(milliseconds: 300));
        expect(painter().frame, pausedFrame,
            reason: '${page.id}: pause freezes the actual pose');
        expect(tester.takeException(), isNull, reason: page.id);
        await tester.pumpWidget(const SizedBox.shrink());
        clock.dispose();
      }
    }
    expect(count, 75);
  });
}
