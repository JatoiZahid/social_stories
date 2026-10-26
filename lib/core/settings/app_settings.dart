import 'package:flutter/foundation.dart';

/// User-adjustable reading preferences, shared by every story.
class AppSettings extends ChangeNotifier {
  AppSettings({
    bool autoRead = true,
    bool largeText = false,
    bool reducedMotion = false,
    double speechRate = defaultSpeechRate,
  })  : _autoRead = autoRead,
        _largeText = largeText,
        _reducedMotion = reducedMotion,
        _speechRate = speechRate;

  static const double minSpeechRate = 0.2;
  static const double maxSpeechRate = 0.6;
  static const double defaultSpeechRate = 0.4;

  bool _autoRead;
  bool _largeText;
  bool _reducedMotion;
  double _speechRate;

  /// Read each page aloud as soon as it appears.
  bool get autoRead => _autoRead;
  set autoRead(bool value) =>
      _update(() => _autoRead = value, _autoRead != value);

  /// Bigger story text for early readers.
  bool get largeText => _largeText;
  set largeText(bool value) =>
      _update(() => _largeText = value, _largeText != value);

  /// Holds character poses still; narration and controls remain available.
  bool get reducedMotion => _reducedMotion;
  set reducedMotion(bool value) =>
      _update(() => _reducedMotion = value, _reducedMotion != value);

  bool _editMode = false;

  /// Shows the story editor instead of the reader. Only for subscribers,
  /// turned on from the account screen (behind the grown-ups gate). Kept in
  /// memory only, so the app always restarts in reading mode.
  bool get editMode => _editMode;
  set editMode(bool value) =>
      _update(() => _editMode = value, _editMode != value);

  /// Speech rate from 0.0 to 1.0; 0.5 is approximately normal, engine dependent.
  double get speechRate => _speechRate;
  set speechRate(double value) {
    final clamped = value.clamp(minSpeechRate, maxSpeechRate).toDouble();
    _update(() => _speechRate = clamped, _speechRate != clamped);
  }

  void _update(VoidCallback apply, bool changed) {
    if (!changed) return;
    apply();
    notifyListeners();
  }
}
