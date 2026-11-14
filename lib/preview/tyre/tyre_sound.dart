import 'package:flutter/services.dart';

/// Optional Android earcons. Missing platforms never block the repair.
class TyreSound {
  static const _channel = MethodChannel('social_stories/tyre_preview_sound');
  Future<void> play(String name) async {
    try {
      await _channel.invokeMethod<void>('play', name);
    } on MissingPluginException {
      /* Test/iOS: silent feedback remains available. */
    } on PlatformException {/* A sound failure must not interrupt the child. */}
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // No native earcon player is installed on this platform.
    } on PlatformException {
      // Audio may already have stopped during lifecycle teardown.
    }
  }
}
