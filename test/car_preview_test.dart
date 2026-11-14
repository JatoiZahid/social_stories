import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_stories/core/narration/narrator.dart';
import 'package:social_stories/core/settings/app_settings.dart';
import 'package:social_stories/core/theme/app_theme.dart';
import 'package:social_stories/preview/car/car_preview_screen.dart';
import 'package:social_stories/preview/car/repair_game.dart';
import 'package:social_stories/preview/car/garage_art.dart';

void enterWheel(RepairGame g) {
  g.next();
  g.next();
}

void fixWheel(RepairGame g) {
  g.inspect();
  g.openToolbox();
  g.drop(RepairPart.wheel, 'wheel');
  for (var i = 0; i < 3; i++) {
    g.pump();
  }
  g.next();
}

void fixEngine(RepairGame g) {
  g.openBonnet();
  g.drop(RepairPart.gear, 'engine');
  g.next();
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('WRITE_CAR_PREVIEWS')) return;
    if (!File('C:/Windows/Fonts/arial.ttf').existsSync()) return;
    // Real glyphs make captured Flutter output reviewable; Ahem is only a
    // geometry-testing font. Device captures retain the app's Nunito theme.
    final text = FontLoader('PreviewText')
      ..addFont(Future.value(ByteData.sublistView(
          File('C:/Windows/Fonts/arial.ttf').readAsBytesSync())));
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File(
              'C:/flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytesSync())));
    await text.load();
    await icons.load();
  });
  test(
      'ordered repairs cannot be skipped, wrong parts and rapid repeats are safe',
      () {
    final g = RepairGame();
    enterWheel(g);
    for (var i = 0; i < 5; i++) {
      g.next();
      g.turn();
      g.power();
      g.start();
      g.go();
    }
    expect(g.stage, GarageStage.wheel);
    expect(g.drop(RepairPart.wheel, 'wheel'), isFalse);
    g.inspect();
    g.openToolbox();
    expect(g.drop(RepairPart.smallWheel, 'wheel'), isFalse);
    expect(g.repaired, isFalse);
    expect(g.drop(RepairPart.wheel, 'wheel'), isTrue);
    expect(g.drop(RepairPart.wheel, 'wheel'), isFalse);
    g.next();
    expect(g.stage, GarageStage.wheel);
    for (var i = 0; i < 3; i++) {
      g.pump();
    }
    g.next();
    expect(g.drop(RepairPart.gear, 'engine'), isFalse);
    g.openBonnet();
    expect(g.drop(RepairPart.triangle, 'engine'), isFalse);
    expect(g.drop(RepairPart.gear, 'engine'), isTrue);
    g.next();
    g.turn();
    expect(g.turns, 0);
    g.drop(RepairPart.wrench, 'bolt');
    for (var i = 0; i < 10; i++) {
      g.turn();
    }
    expect(g.turns, 3);
    g.next();
    g.chooseDifficulty(RepairDifficulty.advanced);
    expect(g.drop(RepairPart.moon, 'moon'), isFalse);
    g.drop(RepairPart.sun, 'sun');
    g.power();
    expect(g.powered, isFalse);
    expect(g.drop(RepairPart.moon, 'sun'), isFalse);
    g.drop(RepairPart.moon, 'moon');
    g.power();
    g.next();
    g.go();
    expect(g.driving, isFalse);
    g.start();
    g.go();
    g.advance(.5);
    g.stop();
    expect(g.ready, isFalse);
    g.pause(true);
    g.advance(1);
    g.stop();
    g.next();
    expect(g.distance, .5);
    g.pause(false);
    g.go();
    g.advance(.5);
    expect(g.ready, isFalse);
    g.stop();
    expect(g.ready, isTrue);
    g.next();
    expect(g.stage, GarageStage.celebration);
    g.replay(all: true);
    expect(g.stage, GarageStage.introduction);
    expect(g.distance, 0);
    g.dispose();
  });

  test('mission replay resets prerequisites and selection', () {
    final g = RepairGame();
    enterWheel(g);
    fixWheel(g);
    g.openBonnet();
    g.select(RepairPart.gear);
    g.drop(RepairPart.gear, 'engine');
    g.replay();
    expect(g.stage, GarageStage.engine);
    expect(g.bonnet, isFalse);
    expect(g.repaired, isFalse);
    expect(g.selected, isNull);
    g.next();
    expect(g.stage, GarageStage.engine);
    g.dispose();
  });

  Future<void> mount(WidgetTester tester, RepairGame game,
      {Size size = const Size(390, 844),
      AppSettings? settings,
      GlobalKey? capture}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(useGoogleFonts: false).copyWith(
            textTheme: AppTheme.light(useGoogleFonts: false)
                .textTheme
                .apply(fontFamily: 'PreviewText')),
        home: RepaintBoundary(
            key: capture,
            child: CarPreviewScreen(
                game: game,
                settings: settings ?? AppSettings(autoRead: false),
                narrator: SilentNarrator()))));
    await tester.pump();
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/story_scenes/car_preview_garage.png'),
        tester.element(find.byType(CarPreviewScreen))));
    await tester.pump();
    // A pixel comparison must begin after artwork decoding, even when files
    // are not being exported. Otherwise loading can look like animation.
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      final art = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<GaragePainter>()
          .single;
      if (art.bodyImage != null && art.roadImage != null) break;
    }
    final art = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<GaragePainter>()
        .single;
    expect(art.bodyImage, isNotNull,
        reason: 'Capture actual illustrated car, never the loading fallback.');
    expect(art.roadImage, isNotNull);
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('WRITE_CAR_PREVIEWS')) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File('docs/car_preview/v2/screenshots/$name.png')
        ..parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'genuine drags reject wrong wheel, tolerate interruption, then snap correct wheel',
      (tester) async {
    final g = RepairGame();
    enterWheel(g);
    g.inspect();
    g.openToolbox();
    await mount(tester, g);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final target = tester.getCenter(find.byKey(const ValueKey('target-wheel')));
    final wrong =
        tester.getCenter(find.byKey(const ValueKey('part-smallWheel')));
    await tester.dragFrom(wrong, target - wrong);
    await tester.pump();
    expect(g.repaired, isFalse);
    final source = tester.getCenter(find.byKey(const ValueKey('part-wheel')));
    await tester.dragFrom(source, const Offset(0, -30));
    await tester.pump();
    expect(g.repaired, isFalse);
    await tester.dragFrom(source, target - source);
    await tester.pump();
    expect(g.repaired, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  testWidgets('touch alternative, wrench, pause and lifecycle work',
      (tester) async {
    final g = RepairGame();
    enterWheel(g);
    fixWheel(g);
    fixEngine(g);
    await mount(tester, g);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.tap(find.byKey(const ValueKey('part-wrench')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('target-bolt')));
    await tester.pump();
    expect(g.attached, isTrue);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Turn $i/3'));
      await tester.pump();
    }
    expect(g.turns, 3);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(g.paused, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(g.paused, isTrue);
    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    expect(g.paused, isFalse);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  testWidgets('engine and power matching, driving, rotation and full replay',
      (tester) async {
    final g = RepairGame();
    enterWheel(g);
    fixWheel(g);
    await mount(tester, g, size: const Size(1366, 1024));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.tap(find.text('Open bonnet'));
    await tester.pump();
    Future<void> drag(String part, String target) async {
      final from = tester.getCenter(find.byKey(ValueKey('part-$part')));
      final to = tester.getCenter(find.byKey(ValueKey('target-$target')));
      await tester.dragFrom(from, to - from);
      await tester.pump();
    }

    await drag('triangle', 'engine');
    expect(g.repaired, isFalse);
    await drag('gear', 'engine');
    expect(g.repaired, isTrue);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await drag('wrench', 'bolt');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Turn $i/3'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text('Next'));
    await tester.pump();
    await drag('moon', 'sun');
    expect(g.sun, isFalse);
    await drag('sun', 'sun');
    expect(g.sun, isTrue);
    // Rotate mid-mission; already attached shapes must survive the rebuild.
    tester.view.physicalSize = const Size(768, 1024);
    await tester.pump();
    expect(g.sun, isTrue);
    expect(g.moon, isFalse);
    tester.view.physicalSize = const Size(1366, 1024);
    await tester.pump();
    await drag('moon', 'moon');
    await tester.tap(find.text('Power').last);
    await tester.pump();
    expect(g.lights, isTrue);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.tap(find.text('Go').first);
    await tester.pump(const Duration(seconds: 2));
    expect(g.distance, greaterThan(0));
    expect(g.distance, lessThan(.95));
    await tester.tap(find.text('Stop').first);
    await tester.pump();
    expect(g.ready, isFalse);
    await tester.tap(find.text('Go').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    final held = g.distance;
    await tester.pump(const Duration(seconds: 3));
    expect(g.distance, held);
    await tester.tap(find.byTooltip('Resume'));
    await tester.pump(const Duration(seconds: 8));
    await tester.tap(find.text('Stop').first);
    await tester.pump();
    expect(g.ready, isTrue);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(g.stage, GarageStage.celebration);
    await tester.tap(find.text('Replay'));
    await tester.pump();
    expect(g.stage, GarageStage.introduction);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  testWidgets('large system text, sound off and reduced motion remain playable',
      (tester) async {
    final g = RepairGame();
    final settings = AppSettings(largeText: true, reducedMotion: true);
    await mount(tester, g, size: const Size(360, 800), settings: settings);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();
    await tester.tap(find.byTooltip('Preview preferences'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Sound'));
    await tester.pump();
    await tester.tap(find.text('Sound'));
    await tester.pump();
    await tester.ensureVisible(find.text('Back to garage'));
    await tester.pump();
    await tester.tap(find.text('Back to garage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(g.paused, isTrue);
    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    await tester.ensureVisible(find.text('Let’s play'));
    await tester.tap(find.text('Let’s play'));
    await tester.pump();
    expect(g.stage, GarageStage.explore);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  test('pump, cleaning, gestures, stars and repair badges have guarded state',
      () {
    final g = RepairGame();
    g.pump();
    g.rotateWrench(.5);
    g.clean(0);
    expect(g.pumpStrokes, 0);
    expect(g.cleaned, isEmpty);
    g.next();
    g.clean(0);
    g.clean(0);
    g.clean(99);
    expect(g.cleaned, {0});
    g.pause(true);
    g.clean(1);
    g.toggleDoor();
    g.spinWheel();
    expect(g.cleaned, {0});
    expect(g.doorOpen, isTrue);
    expect(g.wheelSpin, 0);
    g.pause(false);
    g.toggleDoor();
    expect(g.doorOpen, isFalse);
    g.spinWheel();
    expect(g.wheelSpin, greaterThan(0));
    g.next();
    g.inspect();
    g.openToolbox();
    g.drop(RepairPart.wheel, 'wheel');
    g.next();
    expect(g.stage, GarageStage.wheel);
    g.pump();
    g.pause(true);
    g.pump();
    expect(g.pumpStrokes, 1);
    g.pause(false);
    for (var i = 0; i < 10; i++) {
      g.pump();
    }
    expect(g.pumpStrokes, 3);
    g.next();
    expect(g.completedRepairs, 1);
    fixEngine(g);
    g.drop(RepairPart.wrench, 'bolt');
    g.rotateWrench(-1);
    g.rotateWrench(double.nan);
    g.rotateWrench(2);
    expect(g.turns, 0);
    for (var i = 0; i < 12; i++) {
      g.rotateWrench(.3);
    }
    expect(g.turns, 3);
    g.next();
    g.drop(RepairPart.sun, 'sun');
    g.drop(RepairPart.moon, 'moon');
    g.power();
    g.next();
    g.start();
    g.go();
    g.steer(-1);
    g.advance(.26);
    expect(g.collectedStars, {0});
    g.steer(1);
    g.advance(.25);
    expect(g.collectedStars, {0, 1});
    g.steer(0);
    g.advance(.25);
    expect(g.collectedStars, {0, 1, 2});
    g.advance(-2);
    expect(g.distance, .76);
    g.advance(.24);
    g.stop();
    g.next();
    expect(g.completedRepairs, 5);
    expect(g.collectedStars.length, 3);
    g.replay(all: true);
    expect(g.cleaned, isEmpty);
    expect(g.collectedStars, isEmpty);
    expect(g.completedRepairs, 0);
    g.dispose();
  });

  testWidgets('real swipes clean paintwork; pause prevents cleaning',
      (tester) async {
    final g = RepairGame()..next();
    final key = GlobalKey();
    await mount(tester, g, size: const Size(1024, 768), capture: key);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final area = tester.getRect(find.byKey(const ValueKey('clean-paintwork')));
    await capture(tester, key, 'wipe-before');
    await tester.dragFrom(
        Offset(area.left + 10, area.center.dy), Offset(area.width - 20, 0));
    await tester.pump();
    expect(g.cleaned.length, greaterThan(0));
    await capture(tester, key, 'wipe-after');
    final count = g.cleaned.length;
    g.pause(true);
    await tester.pump();
    await tester.dragFrom(
        Offset(area.left + 10, area.bottom - 12), Offset(area.width - 20, 0));
    await tester.pump();
    expect(g.cleaned.length, count);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  testWidgets('real downward pump strokes inflate; horizontal drag does not',
      (tester) async {
    final g = RepairGame();
    enterWheel(g);
    g.inspect();
    g.openToolbox();
    g.drop(RepairPart.wheel, 'wheel');
    final key = GlobalKey();
    await mount(tester, g, size: const Size(1024, 768), capture: key);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await capture(tester, key, 'pump-before');
    final pump = find.byKey(const ValueKey('pump-handle'));
    await tester.drag(pump, const Offset(40, 0));
    await tester.pump();
    expect(g.pumpStrokes, 0);
    for (var i = 0; i < 3; i++) {
      await tester.dragFrom(
          tester.getTopLeft(pump) + const Offset(25, 25), const Offset(0, 65));
      await tester.pump();
      expect(g.pumpStrokes, i + 1);
    }
    expect(g.ready, isTrue);
    await capture(tester, key, 'pump-after');
    g.replay();
    await tester.pump();
    expect(g.pumpStrokes, 0);
    expect(g.repaired, isFalse);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  testWidgets('clockwise wrench drag turns the attached tool', (tester) async {
    final g = RepairGame();
    enterWheel(g);
    fixWheel(g);
    fixEngine(g);
    g.drop(RepairPart.wrench, 'bolt');
    final key = GlobalKey();
    await mount(tester, g, size: const Size(1024, 768), capture: key);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final center =
        tester.getCenter(find.byKey(const ValueKey('wrench-gesture')));
    final gesture = await tester.startGesture(center + const Offset(48, 0));
    for (var i = 1; i <= 8; i++) {
      final a = i * .4;
      await gesture.moveTo(center + Offset(48 * math.cos(a), 48 * math.sin(a)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pump();
    expect(g.turns, greaterThan(0));
    await capture(tester, key, 'wrench-gesture');
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  testWidgets(
      'dragging the driving car steers without changing mission progress',
      (tester) async {
    final g = RepairGame()..stage = GarageStage.drive;
    g.start();
    await mount(tester, g, size: const Size(1024, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.drag(
        find.byKey(const ValueKey('steer-car')), const Offset(0, -65));
    await tester.pump();
    expect(g.steering, lessThan(0));
    expect(g.distance, 0);
    g.pause(true);
    final held = g.steering;
    await tester.pump();
    await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('steer-car'))),
        const Offset(0, 65));
    await tester.pump();
    expect(g.steering, held);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  testWidgets(
      'reduced-motion driving keeps scenery and uncollected stars still',
      (tester) async {
    final g = RepairGame()..stage = GarageStage.drive;
    await mount(tester, g,
        size: const Size(1024, 768),
        settings: AppSettings(reducedMotion: true));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<List<int>> pixels() async {
      return (await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('garage-art')));
        final image = await boundary.toImage();
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final copy = List<int>.from(bytes!.buffer.asUint8List());
        image.dispose();
        return copy;
      }))!;
    }

    g.start();
    g.go();
    await tester.pump();
    final before = await pixels();
    g.advance(.1);
    await tester.pump();
    expect(await pixels(), orderedEquals(before));
    expect(g.distance, .1);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1366, 1024),
    const Size(800, 360)
  ]) {
    testWidgets('all eight rendered views fit $size', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final g = RepairGame();
      final key = GlobalKey();
      await mount(tester, g,
          size: size,
          capture: key,
          settings: AppSettings(largeText: true, reducedMotion: true));
      for (final stage in GarageStage.values) {
        // Evidence fixtures show a reachable state within each mission; gameplay
        // transitions are tested independently above and with actual UI gestures.
        g.stage = stage;
        g.replay();
        g.completedRepairs = (stage.index - 2).clamp(0, 5);
        if (stage == GarageStage.wheel) {
          g.inspect();
          g.openToolbox();
        }
        if (stage == GarageStage.engine) g.openBonnet();
        if (stage == GarageStage.wrench) g.drop(RepairPart.wrench, 'bolt');
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$stage at $size');
        await capture(tester, key,
            '${size.width.toInt()}x${size.height.toInt()}-${stage.name}');
      }
      await tester.pumpWidget(const SizedBox());
      g.dispose();
    });
  }
}
