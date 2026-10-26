import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_stories/data/models/scene_animation.dart';
import 'package:social_stories/features/story/widgets/animated_story_scene.dart';

void main() {
  const loop = SceneAnimation(
    asset: 'atlas.webp',
    columns: 2,
    rows: 1,
    row: 0,
    frameCount: 2,
    fps: 2,
    cue: 'brush',
  );
  int frame(SceneAnimation config, double progress, int milliseconds,
          {bool reduced = false}) =>
      sceneFrameAt(
        config: config,
        narration: 'We brush our teeth.',
        progress: progress,
        elapsed: Duration(milliseconds: milliseconds),
        duration: const Duration(seconds: 10),
        reducedMotion: reduced,
      );

  test('action waits for its narration cue then changes actual frame', () {
    expect(frame(loop, 0, 900), 0);
    expect(frame(loop, 0.3, 2100), 1);
    expect(frame(loop, 0.4, 2600), 0);
  });

  test('one-shot actions hold their final pose instead of reversing a handover',
      () {
    const once = SceneAnimation(
      asset: 'atlas.webp',
      columns: 2,
      rows: 1,
      row: 0,
      frameCount: 2,
      loop: false,
    );
    expect(frame(once, 0, 0), 0);
    expect(frame(once, 0.7, 7000), 1);
    expect(frame(once, 1, 20000), 1);
  });

  test(
      'a native word cue starts at frame zero even when speech is slower than the estimate',
      () {
    expect(
        sceneFrameAt(
            config: loop,
            narration: 'We brush our teeth.',
            progress: 0.3,
            elapsed: const Duration(milliseconds: 3700),
            duration: const Duration(seconds: 10),
            cueElapsed: const Duration(milliseconds: 3700)),
        0);
    expect(
        sceneFrameAt(
            config: loop,
            narration: 'We brush our teeth.',
            progress: 0.3,
            elapsed: const Duration(milliseconds: 4200),
            duration: const Duration(seconds: 10),
            cueElapsed: const Duration(milliseconds: 3700)),
        1);
  });

  test('reduced motion freezes the selected meaningful poster pose', () {
    const config = SceneAnimation(
      asset: 'atlas.webp',
      columns: 2,
      rows: 1,
      row: 0,
      frameCount: 2,
      posterFrame: 1,
    );
    expect(frame(config, 0, 0, reduced: true), 1);
    expect(frame(config, 1, 10000, reduced: true), 1);
  });

  test(
      'distinct actions wait for their actual words rather than equal time fractions',
      () {
    const narration =
        'We get our brush. Then we add paste and brush our teeth.';
    const config = SceneAnimation(
        asset: 'test',
        columns: 3,
        rows: 1,
        row: 0,
        frameCount: 3,
        loop: false,
        frameCues: ['We get', 'add paste', 'brush our teeth']);
    int at(int offset) => sceneFrameAt(
        config: config,
        narration: narration,
        elapsed: const Duration(seconds: 30),
        duration: const Duration(seconds: 10),
        progress: offset / narration.length);
    expect(at(narration.indexOf('add paste') - 1), 0);
    expect(at(narration.indexOf('add paste')), 1);
    expect(at(narration.indexOf('brush our teeth') - 1), 1);
    expect(at(narration.indexOf('brush our teeth')), 2);
  });

  test('a stale narration cue never triggers unrelated artwork', () {
    const config = SceneAnimation(
      asset: 'atlas.webp',
      columns: 2,
      rows: 1,
      row: 0,
      frameCount: 2,
      cue: 'eat breakfast',
    );
    expect(frame(config, 1, 10000), 0);
  });

  test('atlas painter selects the exact cell and contains all its edges',
      () async {
    // Synthetic test colors make neighboring-frame bleed and cropping visible.
    final sourceRecorder = ui.PictureRecorder();
    final sourceCanvas = Canvas(sourceRecorder);
    sourceCanvas.drawRect(const Rect.fromLTWH(0, 0, 8, 4),
        Paint()..color = const Color(0xffff0000));
    sourceCanvas.drawRect(const Rect.fromLTWH(8, 0, 8, 4),
        Paint()..color = const Color(0xff0000ff));
    final sourcePicture = sourceRecorder.endRecording();
    final atlas = await sourcePicture.toImage(16, 4);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const config = SceneAnimation(
        asset: 'test', columns: 2, rows: 1, row: 0, frameCount: 2);
    SceneAtlasPainter(image: atlas, config: config, frame: 1)
        .paint(canvas, const Size(80, 80));
    final picture = recorder.endRecording();
    final output = await picture.toImage(80, 80);
    final bytes =
        (await output.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    int channel(int x, int y, int channel) =>
        bytes.getUint8((y * 80 + x) * 4 + channel);
    expect(channel(40, 5, 3), 0,
        reason: 'letterbox leaves image proportions unchanged');
    expect(channel(40, 40, 0), 0,
        reason: 'no neighboring red frame bleeds into center');
    expect(channel(40, 40, 2), 255);
    expect(channel(40, 74, 3), 0);
    output.dispose();
    picture.dispose();
    atlas.dispose();
    sourcePicture.dispose();
  });
}
