import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_stories/core/animation/scene_playback.dart';
import 'package:social_stories/data/models/story.dart';
import 'package:social_stories/features/story/widgets/animated_story_scene.dart';

void main() {
  testWidgets('all 132 classic tale illustrations decode in the story player',
      (tester) async {
    final raw = jsonDecode(File('assets/data/stories.json').readAsStringSync())
        as Map<String, dynamic>;
    final stories = (raw['stories'] as List)
        .map((s) => Story.fromJson(s as Map<String, dynamic>));
    var count = 0;
    for (final story in stories) {
      for (final page in story.pages.where((page) => page.animation == null)) {
        final clock = ScenePlayback()
          ..prepare(narration: page.narration, rate: 0.4);
        await tester.pumpWidget(
            MaterialApp(home: AnimatedStoryScene(page: page, playback: clock)));
        await tester.runAsync(() => precacheImage(AssetImage(page.image),
            tester.element(find.byType(AnimatedStoryScene)),
            onError: (error, stack) => fail('${page.id}: $error')));
        await tester.pump();
        expect(find.byType(Image), findsOneWidget, reason: page.id);
        expect(find.byIcon(Icons.image_outlined), findsNothing,
            reason: page.id);
        expect(tester.takeException(), isNull, reason: page.id);
        await tester.pumpWidget(const SizedBox.shrink());
        clock.dispose();
        count++;
      }
    }
    expect(count, 132);
  });

  testWidgets(
      'all 75 animated bundled scenes decode, advance real action frames and pause',
      (tester) async {
    final raw = jsonDecode(File('assets/data/stories.json').readAsStringSync())
        as Map<String, dynamic>;
    final stories = (raw['stories'] as List)
        .map((s) => Story.fromJson(s as Map<String, dynamic>));
    var count = 0;
    for (final story in stories) {
      for (final page in story.pages) {
        if (const {
          'ant_and_grasshopper',
          'ant_and_pigeon',
          'clever_crow',
          'tortoise_and_hare',
          'lion_and_mouse',
          'fox_and_grapes',
          'dog_and_reflection',
          'bundle_of_sticks',
          'enormous_turnip',
          'little_red_hen',
          'cap_seller_and_monkeys',
          'great_race',
          'anansi_pot_of_wisdom',
          'ugly_duckling',
          'goldilocks',
          'gingerbread_man',
          'north_wind_and_sun',
          'fox_and_stork',
          'town_mouse_country_mouse',
          'honest_woodcutter',
          'boy_cried_wolf',
          'fox_and_crow',
        }.contains(story.id)) {
          continue;
        }
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
