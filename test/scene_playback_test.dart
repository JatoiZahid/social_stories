import 'package:flutter_test/flutter_test.dart';
import 'package:social_stories/core/animation/scene_playback.dart';

void main() {
  testWidgets(
      'changing speed while paused preserves position and slows remaining motion',
      (tester) async {
    final normal = ScenePlayback();
    final slower = ScenePlayback();
    for (final clock in [normal, slower]) {
      clock.prepare(
          narration: 'We pick up the brush and brush our teeth.', rate: 0.4);
      clock.play();
    }
    await tester.pump(const Duration(seconds: 1));
    slower.pause();
    final position = slower.narrationProgress;
    final elapsed = slower.elapsed;
    slower.updateRate(0.2);
    expect(slower.narrationProgress, position);
    expect(slower.elapsed, elapsed);
    slower.resume();
    await tester.pump(const Duration(seconds: 1));
    expect(slower.narrationProgress - position,
        closeTo((normal.narrationProgress - position) / 2, 0.001));
    normal.dispose();
    slower.dispose();
  });
  test('slower narration gives actions more time', () {
    final playback = ScenePlayback();
    addTearDown(playback.dispose);
    playback.prepare(
        narration: 'We pick up the brush and brush our teeth.', rate: 0.4);
    final normal = playback.estimatedDuration;
    playback.prepare(
        narration: 'We pick up the brush and brush our teeth.', rate: 0.2);
    expect(playback.estimatedDuration, greaterThan(normal));
    expect(playback.narrationProgress, 0);
  });

  test('pause freezes the scene and resume continues its clock', () async {
    final playback = ScenePlayback();
    addTearDown(playback.dispose);
    playback.prepare(narration: 'We walk safely with our grown up.', rate: 0.4);
    playback.play();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(playback.elapsed, greaterThan(Duration.zero));
    playback.pause();
    final paused = playback.elapsed;
    expect(playback.isPaused, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(playback.elapsed, paused);
    playback.resume();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(playback.elapsed, greaterThan(paused));
    expect(playback.isPlaying, isTrue);
    final previousRevision = playback.revision;
    playback.replay();
    expect(playback.revision, previousRevision + 1);
    expect(playback.elapsed.inMilliseconds, lessThan(50));
  });

  test(
      'word boundaries override estimated progress and ignore stale paused events',
      () {
    final playback = ScenePlayback();
    addTearDown(playback.dispose);
    playback.prepare(narration: '12345678901234567890', rate: 0.4);
    playback.play();
    playback.updateProgress(10);
    expect(playback.hasWordProgress, isTrue);
    expect(playback.narrationProgress, 0.5);
    playback.pause();
    playback.updateProgress(15);
    expect(playback.narrationProgress, 0.5);
    playback.resume();
    playback.updateProgress(16);
    expect(playback.narrationProgress, 0.8);
    playback.updateProgress(1);
    expect(playback.narrationProgress, 0.8,
        reason: 'late boundaries cannot move a scene backwards');
    playback.stop();
    expect(playback.isPlaying, isFalse);
    expect(playback.isPaused, isFalse);
    expect(playback.narrationProgress, 0);
  });

  test('unavailable speech uses a finite fallback without changing a page',
      () async {
    final playback = ScenePlayback();
    addTearDown(playback.dispose);
    playback.prepare(narration: 'Hello.', rate: 0.6);
    playback.play();
    await Future<void>.delayed(const Duration(milliseconds: 1150));
    expect(playback.isPlaying, isFalse);
    expect(playback.narrationProgress, 1);
  });
}
