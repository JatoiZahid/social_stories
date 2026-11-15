import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_stories/core/account/account_service.dart';
import 'package:social_stories/core/app_scope.dart';
import 'package:social_stories/core/narration/narrator.dart';
import 'package:social_stories/core/settings/app_settings.dart';
import 'package:social_stories/core/theme/app_theme.dart';
import 'package:social_stories/data/story_repository.dart';
import 'package:social_stories/data/story_storage.dart';
import 'package:social_stories/data/story_store.dart';
import 'package:social_stories/features/puzzles/puzzle_catalog.dart';
import 'package:social_stories/features/puzzles/puzzle_game_screen.dart';
import 'package:social_stories/features/puzzles/puzzle_library_screen.dart';
import 'package:social_stories/features/puzzles/puzzle_parent_screen.dart';
import 'package:social_stories/features/puzzles/puzzle_piece_count_screen.dart';
import 'package:social_stories/shared/widgets/parent_gate.dart';

void main() {
  Future<void> pump(WidgetTester tester,
      {AppSettings? settings, Widget? home}) async {
    final store = StoryStore(
        repository: const StoryRepository(), storage: MemoryStoryStorage());
    final account =
        AccountService(api: null, tokenStorage: MemoryStoryStorage());
    final narrator = SilentNarrator();
    addTearDown(() {
      store.dispose();
      account.dispose();
      narrator.dispose();
    });
    await tester.pumpWidget(AppScope(
      settings: settings ?? AppSettings(),
      store: store,
      account: account,
      narrator: narrator,
      child: MaterialApp(
          theme: AppTheme.light(useGoogleFonts: false),
          home: home ??
              PuzzleGameScreen(
                  puzzle: PicturePuzzle.all.first, random: Random(4))),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> selectPiece(WidgetTester tester, int index) async {
    final scroll = tester.state<ScrollableState>(find.descendant(
        of: find.byKey(const ValueKey('puzzle-piece-tray')),
        matching: find.byType(Scrollable)));
    scroll.position.jumpTo(0);
    await tester.pumpAndSettle();
    final piece = find.byKey(ValueKey('puzzle-piece-$index'));
    if (piece.evaluate().isEmpty) {
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(piece);
    await tester.tap(piece);
  }

  test('twenty-five unique scenes give every included character five puzzles',
      () {
    expect(PicturePuzzle.all, hasLength(25));
    expect(PicturePuzzle.all.map((p) => p.id).toSet(), hasLength(25));
    expect(PicturePuzzle.all.map((p) => p.asset).toSet(), hasLength(25));
    final characters = PicturePuzzle.all.map((p) => p.character).toSet();
    expect(characters, {
      'bluey',
      'bingo',
      'dora',
      'sonic',
      'ant_grasshopper',
    });
    for (final character in characters) {
      expect(PicturePuzzle.all.where((p) => p.character == character),
          hasLength(5));
    }
    for (final puzzle in PicturePuzzle.all) {
      expect(File(puzzle.asset).existsSync(), isTrue, reason: puzzle.asset);
      final header = ByteData.sublistView(File(puzzle.asset).readAsBytesSync());
      expect(header.getUint32(16) / header.getUint32(20),
          closeTo(puzzle.aspectRatio, 0.01),
          reason: puzzle.asset);
    }
    for (final character in [
      'ant',
      'grasshopper',
    ]) {
      expect(PicturePuzzle.all.where((p) => p.characters.contains(character)),
          hasLength(5),
          reason: character);
    }
  });

  test('blurred is default, including older/invalid saved preferences',
      () async {
    expect(AppSettings().puzzleBlurredBackground, isTrue);
    for (final saved in [null, 'old-data', 'blurred']) {
      final settings =
          AppSettings(puzzlePreferences: MemoryStoryStorage(saved));
      await settings.restorePuzzlePreferences();
      expect(settings.puzzleBlurredBackground, isTrue);
    }
  });

  test(
      'parent background choice survives restart and queued changes keep order',
      () async {
    final storage = MemoryStoryStorage();
    final settings = AppSettings(puzzlePreferences: storage);
    settings.puzzleBlurredBackground = false;
    settings.puzzleBlurredBackground = true;
    settings.puzzleBlurredBackground = false;
    await settings.flushPuzzlePreferences();
    final restarted = AppSettings(puzzlePreferences: storage);
    await restarted.restorePuzzlePreferences();
    expect(restarted.puzzleBlurredBackground, isFalse);
    restarted.puzzleBlurredBackground = true;
    await restarted.flushPuzzlePreferences();
    expect(storage.value, 'blurred');
  });

  testWidgets('plain background removes guide and leaves piece tray intact',
      (tester) async {
    final settings = AppSettings();
    await pump(tester, settings: settings);
    expect(find.byKey(const ValueKey('puzzle-blurred-guide')), findsOneWidget);
    settings.puzzleBlurredBackground = false;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('puzzle-blurred-guide')), findsNothing);
    expect(find.byKey(const ValueKey('puzzle-piece-0')), findsOneWidget);
    settings.puzzleBlurredBackground = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('puzzle-blurred-guide')), findsOneWidget);
  });

  testWidgets('all twenty-five bundled puzzle pictures decode', (tester) async {
    await pump(tester);
    final context = tester.element(find.byType(PuzzleGameScreen));
    for (final puzzle in PicturePuzzle.all) {
      await tester.runAsync(() => precacheImage(
          AssetImage(puzzle.asset), context,
          onError: (error, stack) => fail('${puzzle.id}: $error')));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion celebrates then advances with six pieces',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('puzzle-piece-0')));
    await tester.tap(find.byKey(const ValueKey('puzzle-space-1')));
    await tester.pumpAndSettle();
    expect(find.text('0 of 6 pieces'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await selectPiece(tester, i);
      await tester.tap(find.byKey(ValueKey('puzzle-space-$i')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.text('6 of 6 pieces'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Bluey: Sunflower Garden'), findsOneWidget);
    expect(find.text('0 of 6 pieces'), findsOneWidget);
  });

  testWidgets('last puzzle wraps within chosen set and timer cancels on exit',
      (tester) async {
    final set = PicturePuzzle.all
        .where((p) => p.character == 'ant_grasshopper')
        .toList();
    await pump(tester,
        home: PuzzleGameScreen(puzzle: set.last, playlist: set, pieceCount: 9));
    for (var i = 0; i < 9; i++) {
      await selectPiece(tester, i);
      await tester.tap(find.byKey(ValueKey('puzzle-space-$i')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Great job!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Ant & Grasshopper: Seed Baskets'), findsOneWidget);
    expect(find.text('0 of 9 pieces'), findsOneWidget);
    for (var i = 0; i < 9; i++) {
      await selectPiece(tester, i);
      await tester.tap(find.byKey(ValueKey('puzzle-space-$i')));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging correct piece snaps it into place', (tester) async {
    await pump(tester);
    final piece = find.byKey(const ValueKey('puzzle-piece-0'));
    final slot = find.byKey(const ValueKey('puzzle-space-0'));
    await tester.drag(piece, tester.getCenter(slot) - tester.getCenter(piece));
    await tester.pumpAndSettle();
    expect(find.text('1 of 6 pieces'), findsOneWidget);
  });

  testWidgets('picture opens piece-count card with six and nine choices',
      (tester) async {
    await pump(tester, home: const PuzzleLibraryScreen());
    await tester.tap(find.byKey(const ValueKey('open-puzzle-bluey-1')));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzlePieceCountScreen), findsOneWidget);
    expect(find.byType(PuzzleGameScreen), findsNothing);
    expect(find.text('4 pieces'), findsNothing);
    expect(find.text('6 pieces'), findsOneWidget);
    expect(find.text('9 pieces'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('puzzle-size-9')));
    await tester.pumpAndSettle();
    expect(find.text('0 of 9 pieces'), findsOneWidget);
    expect(find.byKey(const ValueKey('puzzle-space-8')), findsOneWidget);
    expect(find.text('4 pieces'), findsNothing);
  });

  testWidgets('character filter exposes exactly five scenes and opens game',
      (tester) async {
    await pump(tester, home: const PuzzleLibraryScreen());
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bingo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-puzzle-bluey-1')), findsNothing);
    expect(find.byKey(const ValueKey('open-puzzle-bingo-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-puzzle-bingo-1')));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzlePieceCountScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('puzzle-size-6')));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzleGameScreen), findsOneWidget);
    expect(find.text('Bingo: Park Picnic'), findsOneWidget);
  });

  testWidgets(
      'puzzle preferences require parent gate and work without subscription',
      (tester) async {
    final storage = MemoryStoryStorage();
    final settings = AppSettings(puzzlePreferences: storage);
    await pump(tester, settings: settings, home: const PuzzleLibraryScreen());
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('parent-puzzle-settings'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(ParentGate), findsOneWidget);
    expect(find.byType(PuzzleParentScreen), findsNothing);
    final question = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((text) => text.startsWith('What is '));
    final numbers = RegExp(r'\d+')
        .allMatches(question)
        .map((m) => int.parse(m[0]!))
        .toList();
    await tester.enterText(
        find.byType(TextField), '${numbers[0] * numbers[1]}');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzleParentScreen), findsOneWidget);
    await tester.tap(find.text('Plain'));
    await tester.pumpAndSettle();
    await settings.flushPuzzlePreferences();
    expect(storage.value, 'plain');
    expect(settings.puzzleBlurredBackground, isFalse);
  });

  for (final group in ['ant_grasshopper']) {
    for (final size in [const Size(360, 640), const Size(800, 360)]) {
      testWidgets('$group puzzle fits $size with matching image proportions',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final puzzle =
            PicturePuzzle.all.firstWhere((p) => p.character == group);
        expect(puzzle.aspectRatio, 4 / 3);
        for (final count in [6, 9]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await pump(tester,
              home: PuzzleGameScreen(puzzle: puzzle, pieceCount: count));
          expect(find.byKey(ValueKey('puzzle-space-${count - 1}')),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('new series can be selected from the scrolling library filters',
      (tester) async {
    await pump(tester, home: const PuzzleLibraryScreen());
    final chip = find.widgetWithText(ChoiceChip, 'Ant & Grasshopper');
    await tester.scrollUntilVisible(chip, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-puzzle-ant_grasshopper-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('open-puzzle-bluey-1')), findsNothing);
    await tester
        .tap(find.byKey(const ValueKey('open-puzzle-ant_grasshopper-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('puzzle-size-6')));
    await tester.pumpAndSettle();
    expect(find.text('Ant & Grasshopper: Seed Baskets'), findsOneWidget);
  });

  for (final size in [
    const Size(360, 640),
    const Size(800, 360),
    const Size(1024, 768)
  ]) {
    testWidgets('piece-count card is usable at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester,
          home: PuzzlePieceCountScreen(
              puzzle: PicturePuzzle.all.first, playlist: PicturePuzzle.all));
      expect(find.text('4 pieces'), findsNothing);
      final choice = find.byKey(const ValueKey('puzzle-size-9'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(find.text('0 of 9 pieces'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('puzzle fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('4 pieces'), findsNothing);
      expect(find.byKey(const ValueKey('puzzle-space-5')), findsOneWidget);
    });
  }
}
