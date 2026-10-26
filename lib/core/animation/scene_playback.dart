import 'dart:async';

import 'package:flutter/foundation.dart';

/// Scene clock shared by narration and actual character-frame animation.
/// Word boundaries override the rate-adjusted estimate on supporting engines.
/// The estimate is finite and this clock never advances the story page.
class ScenePlayback extends ChangeNotifier {
  static const Duration _tickDuration = Duration(milliseconds: 50);
  Timer? _timer;
  Duration _accumulated = Duration.zero;
  Duration _estimatedDuration = const Duration(seconds: 1);
  int _textLength = 0;
  int _wordCount = 1;
  double _rate = 0.4;
  double _progressOrigin = 0;
  Duration _progressOriginTime = Duration.zero;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _hasWordProgress = false;
  bool _speechActive = false;
  double _wordProgress = 0;
  int _revision = 0;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  Duration get elapsed =>
      _accumulated +
      Duration(
        milliseconds: (_timer?.tick ?? 0) * _tickDuration.inMilliseconds,
      );
  Duration get estimatedDuration => _estimatedDuration;
  int get revision => _revision;
  bool get hasWordProgress => _hasWordProgress;

  double get narrationProgress => _hasWordProgress
      ? _wordProgress
      : (_progressOrigin +
              (elapsed - _progressOriginTime).inMilliseconds /
                  _estimatedDuration.inMilliseconds)
          .clamp(0.0, 1.0);

  void prepare({required String narration, required double rate}) {
    _cancelClock();
    _accumulated = Duration.zero;
    _textLength = narration.length;
    _progressOrigin = 0;
    _progressOriginTime = Duration.zero;
    _isPaused = false;
    _speechActive = false;
    _hasWordProgress = false;
    _wordProgress = 0;
    _revision++;
    // About 130 words/minute at the default app rate. Native engines differ;
    // this fallback does not promise sample-accurate audio timing.
    _wordCount = narration.trim().split(RegExp(r'\s+')).length;
    _rate = rate.clamp(0.1, 1.0);
    _estimatedDuration = _durationAt(_rate);
    notifyListeners();
  }

  Duration _durationAt(double rate) {
    final milliseconds = (_wordCount / (130 * (rate / 0.4)) * 60000).round();
    return Duration(milliseconds: milliseconds.clamp(1000, 120000));
  }

  /// Retimes the remaining estimate without jumping a paused pose or word.
  void updateRate(double rate) {
    final clamped = rate.clamp(0.1, 1.0);
    if (_rate == clamped) return;
    _progressOrigin = narrationProgress;
    _progressOriginTime = elapsed;
    _rate = clamped;
    _estimatedDuration = _durationAt(_rate);
    notifyListeners();
  }

  void play() {
    if (_isPlaying) return;
    _isPlaying = true;
    _isPaused = false;
    _timer = Timer.periodic(_tickDuration, (_) {
      if (!_speechActive && narrationProgress >= 1) {
        complete();
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void pause() {
    if (_isPaused) return;
    _cancelClock();
    _isPaused = true;
    notifyListeners();
  }

  void resume() {
    if (_isPaused) play();
  }

  void replay() {
    _cancelClock();
    _speechActive = false;
    _accumulated = Duration.zero;
    _wordProgress = 0;
    _hasWordProgress = false;
    _progressOrigin = 0;
    _progressOriginTime = Duration.zero;
    _revision++;
    play();
  }

  /// Keep an estimate from ending motion while the engine is still speaking.
  void setSpeechActive(bool value) => _speechActive = value;

  void updateProgress(int characterOffset) {
    if (_textLength == 0 || !_isPlaying) return;
    _hasWordProgress = true;
    _wordProgress = (characterOffset / _textLength).clamp(_wordProgress, 1.0);
    notifyListeners();
  }

  void complete() {
    _cancelClock();
    _speechActive = false;
    _isPaused = false;
    _hasWordProgress = true;
    _wordProgress = 1;
    notifyListeners();
  }

  void stop() {
    _cancelClock();
    _accumulated = Duration.zero;
    _isPaused = false;
    _speechActive = false;
    _hasWordProgress = false;
    _wordProgress = 0;
    _progressOrigin = 0;
    _progressOriginTime = Duration.zero;
    _revision++;
    notifyListeners();
  }

  void _cancelClock() {
    _accumulated = elapsed;
    _timer?.cancel();
    _timer = null;
    _isPlaying = false;
  }

  @override
  void dispose() {
    _cancelClock();
    super.dispose();
  }
}
