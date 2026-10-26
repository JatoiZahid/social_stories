import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_stories/core/account/account_service.dart';
import 'package:social_stories/core/app_scope.dart';
import 'package:social_stories/core/narration/narrator.dart';
import 'package:social_stories/core/settings/app_settings.dart';
import 'package:social_stories/core/theme/app_theme.dart';
import 'package:social_stories/data/models/story.dart';
import 'package:social_stories/data/story_storage.dart';
import 'package:social_stories/data/story_store.dart';
import 'package:social_stories/features/story/story_screen.dart';

import 'fake_server.dart';
import 'story_store_test.dart' show FakeRepository;

class ControlledNarrator implements ResumableNarrator {
  final ValueNotifier<bool> speaking = ValueNotifier(false);
  final ValueNotifier<int> offset = ValueNotifier(0);
  final List<String> spoken = [];
  Completer<void>? stopGate;
  int pauses = 0;
  int resumes = 0;

  @override
  ValueListenable<bool> get isSpeaking => speaking;
  @override
  ValueListenable<int> get characterOffset => offset;
  @override
  Future<void> speak(String text, {required double rate}) async {
    spoken.add(text);
    speaking.value = true;
  }

  @override
  Future<void> stop() async {
    speaking.value = false;
    final gate = stopGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> pause() async {
    pauses++;
    speaking.value = false;
  }

  @override
  Future<void> resume({int? fallbackOffset, double? rate}) async {
    resumes++;
    speaking.value = true;
  }

  @override
  void dispose() {
    speaking.dispose();
    offset.dispose();
  }
}

void main() {
  const story = Story(id: 'timed', title: 'Timed story', pages: [
    StoryPage(
        id: 'a',
        image: 'assets/images/stories/sharing.png',
        lead: 'We share our toys.',
        body: 'We ask for a turn.'),
    StoryPage(
        id: 'b',
        image: 'assets/images/stories/sharing.png',
        lead: 'We wait for our turn.',
        body: 'We can play with another toy.'),
  ]);

  late ControlledNarrator narrator;
  late AppSettings settings;

  Future<void> mount(WidgetTester tester, {bool delayedStart = false}) async {
    narrator = ControlledNarrator();
    if (delayedStart) narrator.stopGate = Completer<void>();
    settings = AppSettings();
    final store = StoryStore(
        repository: const FakeRepository(), storage: MemoryStoryStorage());
    final account = AccountService(
        api: FakeServer().api(), tokenStorage: MemoryStoryStorage());
    await tester.pumpWidget(AppScope(
      settings: settings,
      narrator: narrator,
      store: store,
      account: account,
      child: MaterialApp(
          theme: AppTheme.light(useGoogleFonts: false),
          home: const StoryScreen(story: story)),
    ));
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    narrator.stopGate?.complete();
    narrator.stopGate = null;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    narrator.dispose();
  }

  testWidgets('pause/resume keeps word position; replay and page skip reset it',
      (tester) async {
    await mount(tester);
    expect(narrator.spoken.single, story.pages.first.narration);
    narrator.offset.value = 9;
    await tester.tap(find.byTooltip('Pause scene'));
    await tester.pumpAndSettle();
    expect(narrator.pauses, 1);
    expect(find.byTooltip('Resume scene'), findsOneWidget);
    await tester.tap(find.byTooltip('Resume scene'));
    await tester.pump();
    expect(narrator.resumes, 1);
    expect(narrator.offset.value, 9);
    await tester.tap(find.text('Listen Again'));
    await tester.pump();
    expect(narrator.spoken, hasLength(2));
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
    expect(narrator.spoken.last, story.pages.last.narration);
    expect(find.text('2 of 2'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
      'backgrounding cancels a pending narration start and requires explicit resume',
      (tester) async {
    await mount(tester, delayedStart: true);
    expect(narrator.spoken, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final gate = narrator.stopGate!;
    narrator.stopGate = null;
    gate.complete();
    await tester.pump();
    expect(narrator.spoken, isEmpty,
        reason:
            'an earlier async stop must not start speech in the background');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(narrator.spoken, isEmpty);
    await tester.tap(find.byTooltip('Resume scene'));
    await tester.pump();
    expect(narrator.spoken.single, story.pages.first.narration);
    await unmount(tester);
  });

  testWidgets('settings pause narration and offer reduced motion',
      (tester) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(narrator.speaking.value, isFalse);
    expect(find.text('Reduced motion'), findsOneWidget);
    await tester.tap(find.text('Reduced motion'));
    await tester.pumpAndSettle();
    expect(settings.reducedMotion, isTrue);
    await unmount(tester);
  });
}


