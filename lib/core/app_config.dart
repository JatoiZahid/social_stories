import 'package:flutter/foundation.dart';

/// Build-time settings.
abstract final class AppConfig {
  /// Set with `--dart-define=STORY_SERVER_URL=http://192.168.1.20:8080`
  /// (the build scripts read it from `story_server.txt`).
  static const String _storyServerUrl = String.fromEnvironment('STORY_SERVER_URL');

  /// Where to fetch the latest stories, or null to use only the stories
  /// bundled with the app. Debug builds default to the server running on
  /// this computer, as seen from the Android emulator.
  static Uri? get storyServer {
    final url = _storyServerUrl.trim();
    if (url.isEmpty) return kDebugMode ? Uri.parse('http://10.0.2.2:8080') : null;
    if (url == 'none') return null;
    return Uri.tryParse(url.endsWith('/') ? url.substring(0, url.length - 1) : url);
  }
}
