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
import 'package:social_stories/preview/tyre/tyre_art.dart';
import 'package:social_stories/preview/tyre/tyre_game.dart';
import 'package:social_stories/preview/tyre/tyre_screen.dart';

void turnNut(TyreGame game) {
  for (var i = 0; i < 3; i++) {
    game.assistedTurn();
  }
  game.finishNutMotion();
}

void liftCar(TyreGame game) {
  game.inspect();
  game.drop(TyreTool.jack, 'jack');
  game.finishMotion();
}

void loosen(TyreGame game) {
  for (var i = 0; i < 3; i++) {
    game.drop(TyreTool.wrench, 'nut$i');
    turnNut(game);
  }
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('WRITE_TYRE_PREVIEWS')) return;
    final fonts = [
      FontLoader('SliceText')
        ..addFont(Future.value(ByteData.sublistView(
            File('C:/Windows/Fonts/arial.ttf').readAsBytesSync()))),
      FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(File(
                'C:/flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
            .readAsBytesSync())))
    ];
    for (final font in fonts) {
      await font.load();
    }
  });

  test(
      'full toy repair requires jack, three loosened nuts, removed tyre, matched tyre, three tightened nuts and lowering',
      () {
    final g = TyreGame();
    expect(g.drop(TyreTool.spare, 'hub'), isFalse);
    g.finishMotion();
    g.lower();
    expect(g.step, TyreStep.inspect);
    g.inspect();
    expect(g.drop(TyreTool.wrench, 'jack'), isFalse);
    expect(g.drop(TyreTool.jack, 'jack'), isTrue);
    expect(g.busy, isTrue);
    g.pause(true);
    g.finishMotion();
    expect(g.step, TyreStep.jack);
    g.pause(false);
    g.finishMotion();
    expect(g.raised, isTrue);
    for (var i = 0; i < 3; i++) {
      expect(g.drop(TyreTool.wrench, 'hub'), isFalse);
      expect(g.drop(TyreTool.wrench, 'nut$i'), isTrue);
      g.rotate(.5);
      g.rotate(double.nan);
      g.rotate(20);
      expect(g.turn, 0);
      g.rotate(-.5);
      g.pause(true);
      g.rotate(-.5);
      expect(g.turn, closeTo(.5 / 1.4, .001));
      g.pause(false);
      g.rotate(-.5);
      g.rotate(-.5);
      g.finishNutMotion();
    }
    expect(g.step, TyreStep.remove);
    expect(g.oldRemoved, isFalse);
    expect(g.drop(TyreTool.damaged, 'hub'), isFalse);
    expect(g.drop(TyreTool.damaged, 'tray'), isTrue);
    expect(g.drop(TyreTool.small, 'hub'), isFalse);
    expect(g.newFitted, isFalse);
    expect(g.drop(TyreTool.spare, 'hub'), isTrue);
    expect(g.busy, isTrue);
    g.finishMotion();
    expect(g.step, TyreStep.tighten);
    g.lower();
    expect(g.step, TyreStep.tighten);
    for (var i = 0; i < 3; i++) {
      g.drop(TyreTool.wrench, 'nut$i');
      turnNut(g);
    }
    expect(g.step, TyreStep.lower);
    expect(g.raised, isTrue);
    g.lower();
    g.finishMotion();
    expect(g.step, TyreStep.done);
    expect(g.raised, isFalse);
    g.reset();
    expect(g.step, TyreStep.inspect);
    expect(g.newFitted, isFalse);
    expect(g.oldRemoved, isFalse);
    expect(g.attached, isFalse);
    g.dispose();
  });

  Future<void> mount(WidgetTester tester, TyreGame game,
      {Size size = const Size(1366, 1024),
      GlobalKey? capture,
      AppSettings? settings}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = AppTheme.light(useGoogleFonts: false);
    await tester.pumpWidget(MaterialApp(
        theme: theme.copyWith(
            textTheme: theme.textTheme.apply(
                fontFamily: const bool.fromEnvironment('WRITE_TYRE_PREVIEWS')
                    ? 'SliceText'
                    : null)),
        home: RepaintBoundary(
            key: capture,
            child: TyreGarageScreen(
                game: game,
                narrator: SilentNarrator(),
                settings: settings ?? AppSettings(autoRead: false)))));
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (find.byKey(const ValueKey('tyre-art')).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(const ValueKey('tyre-art')), findsOneWidget,
        reason: 'The actual illustrated workshop must load.');
    expect(tester.takeException(), isNull);
  }

  test(
      'individual nuts settle exactly once, pause safely, and finish nut three automatically',
      () {
    final g = TyreGame();
    liftCar(g);
    for (final i in [2, 0, 1]) {
      g.chooseNut(i);
      expect(g.nut, i);
      expect(g.drop(TyreTool.wrench, 'nut$i'), isTrue);
      for (var j = 0; j < 3; j++) {
        g.assistedTurn();
      }
      expect(g.settlingNut, isTrue);
      expect(g.drop(TyreTool.wrench, 'nut$i'), isFalse);
      g.finishMotion();
      expect(g.busy, isTrue);
      g.pause(true);
      g.finishNutMotion();
      expect(g.loosened.contains(i), isFalse);
      g.pause(false);
      g.finishNutMotion();
      g.finishNutMotion();
      expect(g.loosened.contains(i), isTrue);
    }
    expect(g.loosened.length, 3);
    expect(g.step, TyreStep.remove);
    g.reset();
    expect(g.loosened, isEmpty);
    expect(g.settlingNut, isFalse);
    g.dispose();
  });

  test('coalesced Android quarter-turn is accepted without dropping its angle',
      () {
    final g = TyreGame();
    liftCar(g);
    g.drop(TyreTool.wrench, 'nut0');
    g.rotate(-1.59);
    expect(g.settlingNut, isTrue);
    g.finishNutMotion();
    expect(g.loosened, {0});
    g.dispose();
  });

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('WRITE_TYRE_PREVIEWS')) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File('docs/tyre_preview_v4/screenshots/$name.png')
        ..parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> drag(WidgetTester tester, String source, String target) async {
    final from = tester.getCenter(find.byKey(ValueKey(source))),
        to = tester.getCenter(find.byKey(ValueKey(target)));
    await tester.dragFrom(from, to - from);
    await tester.pump();
  }

  Future<void> gestureTurn(WidgetTester tester, bool clockwise,
      {GlobalKey? captureKey}) async {
    final ring = find.byKey(const ValueKey('rotate-nut'));
    final center = tester.getCenter(ring),
        radius = tester.getSize(ring).width * .33;
    final gesture = await tester.startGesture(center + Offset(radius, 0));
    for (var i = 1; i <= 7; i++) {
      final angle = (clockwise ? 1 : -1) * i * .3;
      await gesture.moveTo(
          center + Offset(radius * math.cos(angle), radius * math.sin(angle)));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    if (captureKey != null) {
      await tester.pump(const Duration(milliseconds: 160));
      await capture(tester, captureKey, 'nut-removal-flight');
    }
    await tester.pump(const Duration(milliseconds: 650));
  }

  testWidgets(
      'real jack, nut rotation, damaged-wheel drag, new-wheel alignment, tightening and lowering complete the slice',
      (tester) async {
    final g = TyreGame();
    final key = GlobalKey();
    await mount(tester, g, capture: key);
    await capture(tester, key, 'garage-landscape');
    await tester.tap(find.byKey(const ValueKey('inspect-zone')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(g.drop(TyreTool.wrench, 'jack'), isFalse);
    expect(g.step, TyreStep.jack);
    expect(g.busy, isFalse);
    await drag(tester, 'drag-jack', 'target-jack');
    expect(g.busy, isTrue);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(g.step, TyreStep.loosen);
    await capture(tester, key, 'car-lifted');
    for (var i = 0; i < 3; i++) {
      await drag(tester, 'drag-wrench', 'target-nut$i');
      expect(g.attached, isTrue);
      if (i == 0) await capture(tester, key, 'wrench-contact');
      await gestureTurn(tester, false, captureKey: i == 0 ? key : null);
      if (i == 0) await capture(tester, key, 'first-nut-in-tray');
    }
    expect(g.step, TyreStep.remove);
    await capture(tester, key, 'remove-damaged-wheel');
    await drag(tester, 'drag-damaged', 'target-tray');
    expect(g.oldRemoved, isTrue);
    await drag(tester, 'drag-small', 'target-hub');
    expect(g.newFitted, isFalse);
    await capture(tester, key, 'wheel-hub');
    await drag(tester, 'drag-spare', 'target-hub');
    await tester.pump(const Duration(milliseconds: 600));
    expect(g.step, TyreStep.tighten);
    await capture(tester, key, 'new-wheel');
    for (var i = 0; i < 3; i++) {
      await drag(tester, 'drag-wrench', 'target-nut$i');
      await gestureTurn(tester, true);
    }
    expect(g.step, TyreStep.lower);
    await capture(tester, key, 'tightened-wheel');
    await tester.tap(find.byKey(const ValueKey('release-zone')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    g.pause(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(g.step, TyreStep.lower);
    // Resizing never loses the supported rig/repair state.
    tester.view.physicalSize = const Size(768, 1024);
    await tester.pump();
    expect(g.newFitted, isTrue);
    g.pause(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(g.step, TyreStep.done);
    await capture(tester, key, 'completion-portrait');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Drive out'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await capture(tester, key, 'victory-drive');
    expect(g.step, TyreStep.done);
    await tester.ensureVisible(find.text('Play again'));
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(g.step, TyreStep.inspect);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  testWidgets(
      'interrupted drag and lifecycle pause cannot install a jack or remove a wheel',
      (tester) async {
    final g = TyreGame()..inspect();
    await mount(tester, g);
    await tester.drag(
        find.byKey(const ValueKey('drag-jack')), const Offset(30, -35));
    await tester.pump();
    expect(g.busy, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    // Leaving during the invalid-drop return must dispose its overlay safely.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(g.paused, isTrue);
    expect(g.drop(TyreTool.jack, 'jack'), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(g.paused, isTrue);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(g.paused, isFalse);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  testWidgets('phone nut targeting survives rotation and pointer cancellation',
      (tester) async {
    final g = TyreGame();
    liftCar(g);
    await mount(tester, g, size: const Size(390, 844));
    await drag(tester, 'drag-wrench', 'target-nut2');
    expect(g.nut, 2);
    final ring = find.byKey(const ValueKey('rotate-nut'));
    final pointer =
        await tester.startGesture(tester.getCenter(ring) + const Offset(35, 0));
    await pointer.cancel();
    await gestureTurn(tester, false);
    expect(g.loosened, {2});
    tester.view.physicalSize = const Size(800, 360);
    await tester.pump();
    await drag(tester, 'drag-wrench', 'target-nut0');
    expect(g.nut, 0);
    await gestureTurn(tester, false);
    expect(g.loosened, {2, 0});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  testWidgets(
      'leaving during nut flight retains paused repair and resumes once',
      (tester) async {
    final g = TyreGame();
    liftCar(g);
    await mount(tester, g);
    g.drop(TyreTool.wrench, 'nut1');
    for (var i = 0; i < 3; i++) {
      g.assistedTurn();
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pumpWidget(const SizedBox());
    expect(g.paused, isTrue);
    expect(g.nutFraction, greaterThan(0));
    expect(g.loosened, isEmpty);
    await mount(tester, g);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(g.loosened, {1});
    expect(g.settlingNut, isFalse);
    expect(g.liftFraction, 1);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
  });

  testWidgets(
      'missing artwork reports a recoverable error rather than a blank scene',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: TyreGarageScreen(
            narrator: SilentNarrator(),
            settings: AppSettings(autoRead: false),
            assetLoader: () =>
                Future<TyreAssets>.error(StateError('Missing artwork')))));
    await tester.pump();
    expect(find.text('The workshop could not load.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1366, 1024),
    const Size(800, 360)
  ]) {
    testWidgets('illustrated garage, contact zones and instructions fit $size',
        (tester) async {
      final g = TyreGame();
      final key = GlobalKey();
      await mount(tester, g,
          size: size,
          capture: key,
          settings: AppSettings(
              autoRead: false, reducedMotion: true, largeText: true));
      await capture(
          tester, key, '${size.width.toInt()}x${size.height.toInt()}-garage');
      g.inspect();
      g.drop(TyreTool.jack, 'jack');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(g.step, TyreStep.loosen);
      final artRect = tester.getRect(find.byKey(const ValueKey('tyre-art')));
      for (var i = 0; i < 3; i++) {
        final nutRect = tester.getRect(find.byKey(ValueKey('target-nut$i')));
        expect(artRect.contains(nutRect.center), isTrue);
        expect(nutRect.width, greaterThanOrEqualTo(48 - 1e-6));
      }
      expect(tester.takeException(), isNull);
      await capture(
          tester, key, '${size.width.toInt()}x${size.height.toInt()}-repair');
      await tester.pumpWidget(const SizedBox());
      g.dispose();
    });
  }
}
