import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads story text aloud. Abstract so tests and previews can run silently.
abstract class Narrator {
  /// True while speech is playing; drives the speaker animation.
  ValueListenable<bool> get isSpeaking;

  Future<void> speak(String text, {required double rate});

  Future<void> stop();

  void dispose();
}

/// Device text-to-speech via `flutter_tts`.
class TtsNarrator implements Narrator {
  TtsNarrator({String language = 'en-US'}) : _language = language {
    _tts
      ..setStartHandler(() => _speaking.value = true)
      ..setCompletionHandler(() => _speaking.value = false)
      ..setCancelHandler(() => _speaking.value = false)
      ..setErrorHandler((_) => _speaking.value = false);
  }

  final FlutterTts _tts = FlutterTts();
  final String _language;
  final ValueNotifier<bool> _speaking = ValueNotifier<bool>(false);
  bool _configured = false;

  @override
  ValueListenable<bool> get isSpeaking => _speaking;

  @override
  Future<void> speak(String text, {required double rate}) async {
    try {
      if (!_configured) {
        await _tts.setLanguage(_language);
        await _tts.awaitSpeakCompletion(false);
        _configured = true;
      }
      await _tts.stop();
      await _tts.setSpeechRate(rate);
      _speaking.value = true;
      await _tts.speak(text);
    } catch (error) {
      // TTS is a nice-to-have; never crash the story because of it.
      _speaking.value = false;
      debugPrint('Narration failed: $error');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore – nothing is playing.
    }
    _speaking.value = false;
  }

  @override
  void dispose() {
    _tts.stop();
    _speaking.dispose();
  }
}

/// No-audio narrator for tests and widget previews. Records what it was asked to say.
class SilentNarrator implements Narrator {
  final List<String> spoken = <String>[];
  final ValueNotifier<bool> _speaking = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get isSpeaking => _speaking;

  @override
  Future<void> speak(String text, {required double rate}) async => spoken.add(text);

  @override
  Future<void> stop() async => _speaking.value = false;

  @override
  void dispose() => _speaking.dispose();
}
