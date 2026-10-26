import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads story text aloud. Abstract so previews can run without device audio.
abstract class Narrator {
  ValueListenable<bool> get isSpeaking;
  Future<void> speak(String text, {required double rate});
  Future<void> stop();
  void dispose();
}

/// Optional timing capability. Existing custom narrators remain compatible.
abstract interface class ResumableNarrator implements Narrator {
  /// Start of the current word, in the full original narration string.
  ValueListenable<int> get characterOffset;
  Future<void> pause();
  Future<void> resume({int? fallbackOffset, double? rate});
}

/// Device TTS, with native word boundaries when supplied by the engine.
/// Resume re-reads the last reported word rather than cutting a word in half.
class TtsNarrator implements ResumableNarrator {
  TtsNarrator({String language = 'en-US'}) : _language = language {
    _tts
      ..setStartHandler(() {
        if (!_disposed && !_paused && _segment.isNotEmpty) {
          _speaking.value = true;
        }
      })
      ..setCompletionHandler(() {
        if (_disposed || _paused || _segment.isEmpty) return;
        _position.value = _text.length;
        _speaking.value = false;
      })
      ..setCancelHandler(() {
        if (!_disposed && !_starting) _speaking.value = false;
      })
      ..setErrorHandler((_) {
        if (!_disposed) _speaking.value = false;
      })
      ..setProgressHandler((text, start, end, word) {
        if (_disposed || _paused || text != _segment) return;
        _position.value = (_segmentOffset + start).clamp(0, _text.length);
      });
  }

  final FlutterTts _tts = FlutterTts();
  final String _language;
  final ValueNotifier<bool> _speaking = ValueNotifier<bool>(false);
  final ValueNotifier<int> _position = ValueNotifier<int>(0);
  bool _configured = false;
  bool _paused = false;
  bool _starting = false;
  bool _disposed = false;
  int _request = 0;
  int _segmentOffset = 0;
  String _text = '';
  String _segment = '';
  double _rate = 0.4;

  @override
  ValueListenable<bool> get isSpeaking => _speaking;
  @override
  ValueListenable<int> get characterOffset => _position;

  @override
  Future<void> speak(String text, {required double rate}) async {
    final request = ++_request;
    _segment = '';
    _text = text;
    _rate = rate;
    _paused = false;
    _position.value = 0;
    await _startSegment(0, request);
  }

  Future<void> _startSegment(int offset, int request) async {
    _starting = true;
    try {
      await _tts.stop();
      if (_disposed || request != _request) return;
      if (!_configured) {
        await _tts.setLanguage(_language);
        await _tts.awaitSpeakCompletion(false);
        _configured = true;
      }
      if (_disposed || request != _request) return;
      await _tts.setSpeechRate(_rate);
      if (_disposed || request != _request) return;
      _segmentOffset = offset;
      _segment = _text.substring(offset);
      if (_segment.trim().isEmpty) {
        _speaking.value = false;
        return;
      }
      _speaking.value = true;
      await _tts.speak(_segment);
    } catch (error) {
      if (!_disposed && request == _request) _speaking.value = false;
      debugPrint('Narration failed: $error');
    } finally {
      if (request == _request) _starting = false;
    }
  }

  @override
  Future<void> pause() async {
    ++_request;
    _starting = false;
    _paused = true;
    _speaking.value = false;
    try {
      await _tts.stop();
    } catch (_) {
      // A missing speech engine never prevents reading the story.
    }
  }

  @override
  Future<void> resume({int? fallbackOffset, double? rate}) async {
    if (!_paused || _disposed) return;
    _paused = false;
    if (rate != null) _rate = rate;
    var offset = _position.value;
    if (offset == 0 && fallbackOffset != null) {
      offset = fallbackOffset.clamp(0, _text.length);
      while (offset > 0 && offset < _text.length && _text[offset - 1] != ' ') {
        offset--;
      }
    }
    await _startSegment(offset.clamp(0, _text.length), ++_request);
  }

  @override
  Future<void> stop() async {
    ++_request;
    _starting = false;
    _paused = false;
    _segment = '';
    _text = '';
    if (!_disposed) {
      _speaking.value = false;
      _position.value = 0;
    }
    try {
      await _tts.stop();
    } catch (_) {
      // Nothing is playing or no device engine is installed.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    _tts.stop();
    _speaking.dispose();
    _position.dispose();
  }
}

/// No-audio narrator for tests and previews. Records requested narration.
class SilentNarrator implements Narrator {
  final List<String> spoken = <String>[];
  final ValueNotifier<bool> _speaking = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get isSpeaking => _speaking;
  @override
  Future<void> speak(String text, {required double rate}) async =>
      spoken.add(text);
  @override
  Future<void> stop() async => _speaking.value = false;
  @override
  void dispose() => _speaking.dispose();
}
