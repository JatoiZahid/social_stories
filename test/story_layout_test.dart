import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_stories/core/account/account_service.dart';
import 'package:social_stories/core/app_scope.dart';
import 'package:social_stories/core/narration/narrator.dart';
import 'package:social_stories/core/settings/app_settings.dart';
import 'package:social_stories/core/theme/app_theme.dart';
import 'package:social_stories/data/models/story.dart';
import 'package:social_stories/data/story_repository.dart';
import 'package:social_stories/data/story_storage.dart';
import 'package:social_stories/data/story_store.dart';
import 'package:social_stories/features/story/story_screen.dart';
import 'package:social_stories/features/story/widgets/animated_story_scene.dart';
import 'package:social_stories/shared/widgets/narration_card.dart';

import 'fake_server.dart';

void main() {
  final raw = jsonDecode(File('assets/data/stories.json').readAsStringSync())
      as Map<String, dynamic>;
  final stories = (raw['stories'] as List)
      .map((s) => Story.fromJson(s as Map<String, dynamic>))
      .toList();
  const sizes = [
    Size(360, 640),
    Size(800, 360),
    Size(768, 1024),
    Size(1024, 768),
    Size(1024, 1366),
    Size(1366, 1024)
  ];

  for (final size in sizes) {
    testWidgets(
        'story controls and full artwork fit ${size.width} x ${size.height}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings =
          AppSettings(autoRead: false, largeText: true, reducedMotion: true);
      final narrator = SilentNarrator();
      final store = StoryStore(
          repository: const StoryRepository(), storage: MemoryStoryStorage());
      final account = AccountService(
          api: FakeServer().api(), tokenStorage: MemoryStoryStorage());
      final previewKey = GlobalKey();
      for (final story in stories.where((s) => const {
            'going_to_the_doctor',
            'airport',
            'staying_safe',
          }.contains(s.id))) {
        // Use its longest page to cover expanded narration as well as every cast.
        final longest = story.pages
            .reduce((a, b) => a.narration.length > b.narration.length ? a : b);
        await tester.pumpWidget(AppScope(
            settings: settings,
            narrator: narrator,
            store: store,
            account: account,
            child: MaterialApp(
                theme: AppTheme.light(useGoogleFonts: false),
                home: RepaintBoundary(
                  key: previewKey,
                  child: StoryScreen(
                      key: ValueKey(story.id),
                      story: story.copyWith(pages: [longest])),
                ))));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${story.id} at $size');
        expect(find.text('Listen Again'), findsOneWidget);
        expect(find.text('Finish'), findsOneWidget);
        if (size.height < 500) {
          expect(tester.getSize(find.byType(AnimatedStoryScene)).height,
              greaterThan(150),
              reason:
                  'short landscape layouts need enough space to understand character actions');
        }
        if (size.height > size.width && size.width >= 768) {
          expect(
              tester.getTopLeft(find.byType(NarrationCard)).dy,
              greaterThan(
                  tester.getBottomLeft(find.byType(AnimatedStoryScene)).dy),
              reason: 'portrait tablets stack the artwork above narration');
        }
        if (const bool.fromEnvironment('WRITE_STORY_PREVIEWS') &&
            story.id == 'staying_safe') {
          await tester.runAsync(() => precacheImage(AssetImage(longest.image),
              tester.element(find.byType(StoryScreen))));
          await tester.pump();
          await tester.runAsync(() async {
            final boundary = previewKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes =
                (await image.toByteData(format: ui.ImageByteFormat.png))!;
            final file = File(
                'build/scene_previews/${size.width.toInt()}x${size.height.toInt()}.png');
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      account.dispose();
      store.dispose();
      narrator.dispose();
      settings.dispose();
    });
  }
}
