import 'package:flutter/foundation.dart';

/// User-adjustable reading preferences, shared by every story.
class AppSettings extends ChangeNotifier {
  AppSettings({
    bool autoRead = true,
    bool largeText = false,
    double speechRate = defaultSpeechRate,
  })  : _autoRead = autoRead,
        _largeText = largeText,
        _speechRate = speechRate;

  static const double minSpeechRate = 0.2;
  static const double maxSpeechRate = 0.6;
  static const double defaultSpeechRate = 0.4;

  bool _autoRead;
  bool _largeText;
  double _speechRate;

  /// Read each page aloud as soon as it appears.
  bool get autoRead => _autoRead;
  set autoRead(bool value) => _update(() => _autoRead = value, _autoRead != value);

  /// Bigger story text for early readers.
  bool get largeText => _largeText;
  set largeText(bool value) => _update(() => _largeText = value, _largeText != value);

  bool _editMode = false;

  /// Shows the story editor instead of the reader. Only for subscribers,
  /// turned on from the account screen (behind the grown-ups gate). Kept in
  /// memory only, so the app always restarts in reading mode.
  bool get editMode => _editMode;
  set editMode(bool value) => _update(() => _editMode = value, _editMode != value);

  /// Text-to-speech rate (0.0 – 1.0, platform dependent; 0.5 ≈ normal).
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
