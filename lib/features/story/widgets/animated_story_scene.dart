import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/animation/scene_playback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/scene_animation.dart';
import '../../../data/models/story.dart';
import '../../../shared/widgets/scene_image.dart';

/// Actual illustrated action frames, on the same clock as the spoken page.
/// The camera and image rectangle never move to simulate character action.
class AnimatedStoryScene extends StatefulWidget {
  const AnimatedStoryScene({
    super.key,
    required this.page,
    required this.playback,
    this.reducedMotion = false,
  });

  final StoryPage page;
  final ScenePlayback playback;
  final bool reducedMotion;

  @override
  State<AnimatedStoryScene> createState() => _AnimatedStorySceneState();
}

class _AnimatedStorySceneState extends State<AnimatedStoryScene> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _image;
  String? _asset;
  int _cueRevision = -1;
  String? _cueKey;
  Duration? _cueElapsed;

  int _currentFrame(SceneAnimation config, bool reduced) {
    final clock = widget.playback;
    final key = '${widget.page.id}:${widget.page.narration}:${config.cue}';
    if (_cueRevision != clock.revision || _cueKey != key) {
      _cueRevision = clock.revision;
      _cueKey = key;
      _cueElapsed = null;
    }
    final index =
        config.cue == null ? 0 : widget.page.narration.indexOf(config.cue!);
    final cueProgress = index <= 0 ? 0.0 : index / widget.page.narration.length;
    if (index >= 0 &&
        _cueElapsed == null &&
        clock.narrationProgress >= cueProgress) {
      _cueElapsed = cueProgress == 0
          ? Duration.zero
          : clock.hasWordProgress
              ? clock.elapsed
              : Duration(
                  milliseconds:
                      (clock.estimatedDuration.inMilliseconds * cueProgress)
                          .round());
    }
    return sceneFrameAt(
      config: config,
      narration: widget.page.narration,
      elapsed: clock.elapsed,
      duration: clock.estimatedDuration,
      progress: clock.narrationProgress,
      reducedMotion: reduced,
      cueElapsed: _cueElapsed,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(AnimatedStoryScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.animation?.asset != widget.page.animation?.asset) {
      _resolve();
    }
  }

  void _resolve() {
    final config = widget.page.animation;
    final asset = config != null && config.isValid ? config.asset : null;
    if (_asset == asset) return;
    _detach();
    _asset = asset;
    if (asset == null) return;
    final stream =
        imageProviderFor(asset).resolve(createLocalImageConfiguration(context));
    _stream = stream;
    _listener = ImageStreamListener((info, synchronousCall) {
      if (!mounted || _stream != stream) {
        info.dispose();
        return;
      }
      // Keep one decoded atlas, not a separate decoded bitmap for every frame.
      final previous = _image;
      if (synchronousCall) {
        _image = info;
      } else {
        setState(() => _image = info);
      }
      previous?.dispose();
    }, onError: (Object error, StackTrace? stack) {
      if (!mounted || _stream != stream) return;
      setState(() {
        _image?.dispose();
        _image = null;
      });
      // The page's reviewed poster remains available offline if an atlas fails.
    });
    stream.addListener(_listener!);
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
    _image?.dispose();
    _image = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.page.animation;
    final image = _image?.image;
    if (config == null ||
        !config.isValid ||
        image == null ||
        image.width % config.columns != 0 ||
        image.height % config.rows != 0) {
      return SceneImage(
        frame: widget.page.frame,
        semanticLabel:
            config?.description.isNotEmpty == true ? config!.description : null,
      );
    }
    final reduced = widget.reducedMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return Semantics(
      image: true,
      label: config.description.isEmpty
          ? widget.page.narration
          : config.description,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusL),
        child: ColoredBox(
          color: AppColors.tint,
          child: ListenableBuilder(
            listenable: widget.playback,
            builder: (context, _) => CustomPaint(
              key: const ValueKey('story-action-frames'),
              painter: SceneAtlasPainter(
                image: image,
                config: config,
                frame: _currentFrame(config, reduced),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pure timeline calculation so cue alignment, pauses and final holds are testable.
@visibleForTesting
int sceneFrameAt({
  required SceneAnimation config,
  required String narration,
  required Duration elapsed,
  required Duration duration,
  required double progress,
  bool reducedMotion = false,
  Duration? cueElapsed,
}) {
  if (reducedMotion || !config.isValid) return config.posterFrame;
  final cue = config.cue;
  final cueIndex = cue == null ? 0 : narration.indexOf(cue);
  // A stale cue may never silently animate an unrelated sentence.
  if (cueIndex < 0) return config.posterFrame;
  final cueProgress = narration.isEmpty ? 0.0 : cueIndex / narration.length;
  if (progress < cueProgress) return config.posterFrame;
  if (config.frameCues.isNotEmpty) {
    var frame = 0;
    var previous = -1;
    for (var i = 0; i < config.frameCues.length; i++) {
      final offset = narration.indexOf(config.frameCues[i]);
      if (offset <= previous) return config.posterFrame;
      previous = offset;
      if (narration.isEmpty || progress >= offset / narration.length) frame = i;
    }
    return frame;
  }
  if (!config.loop) {
    final localProgress =
        ((progress - cueProgress) / math.max(0.01, 1 - cueProgress))
            .clamp(0.0, 1.0);
    return math.min(
        config.frameCount - 1, (localProgress * config.frameCount).floor());
  }
  final cueMilliseconds =
      cueElapsed?.inMilliseconds ?? duration.inMilliseconds * cueProgress;
  final afterCue =
      math.max(0.0, (elapsed.inMilliseconds - cueMilliseconds) / 1000);
  return (afterCue * config.fps).floor() % config.frameCount;
}

/// Draw a single source cell into a contained destination; never stretch/crop it.
@visibleForTesting
class SceneAtlasPainter extends CustomPainter {
  SceneAtlasPainter(
      {required this.image, required this.config, required this.frame});

  final ui.Image image;
  final SceneAnimation config;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = Size(image.width / config.columns, image.height / config.rows);
    final fitted = applyBoxFit(BoxFit.contain, cell, size);
    final destination =
        Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    final source = Rect.fromLTWH(
        frame * cell.width, config.row * cell.height, cell.width, cell.height);
    canvas.drawImageRect(image, source, destination,
        Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(SceneAtlasPainter oldDelegate) =>
      image != oldDelegate.image ||
      frame != oldDelegate.frame ||
      !config.sameAs(oldDelegate.config);
}
