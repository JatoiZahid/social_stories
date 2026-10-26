import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'models/story.dart';

/// Turns a stories.json document (`{"stories": [...]}`) into stories.
List<Story> parseStories(String raw) {
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return (decoded['stories'] as List<dynamic>)
      .map((story) => Story.fromJson(story as Map<String, dynamic>))
      .toList(growable: false);
}

/// Loads the stories bundled with the app. These are shown until the
/// story server has been reached at least once.
class StoryRepository {
  const StoryRepository({this.bundle, this.path = 'assets/data/stories.json'});

  final AssetBundle? bundle;
  final String path;

  Future<List<Story>> loadStories() async =>
      parseStories(await (bundle ?? rootBundle).loadString(path));

  /// Original scene signatures allow an old server/cache to reuse reviewed
  /// bundled animation without changing any remotely edited content.
  Future<List<Story>> loadLegacySceneSignatures() async {
    // Injected repositories own their content. In particular, in-memory/test
    // repositories must not unexpectedly wait for platform asset I/O.
    if (runtimeType != StoryRepository && bundle == null) return const [];
    try {
      return parseStories(await (bundle ?? rootBundle)
          .loadString('assets/data/legacy_scene_signatures.json'));
    } catch (_) {
      // Custom repositories and older builds may have no migration manifest.
      return const [];
    }
  }
}

/// Fetches the latest stories from the story server (see `server/`).
class RemoteStoryRepository {
  RemoteStoryRepository(this.baseUrl,
      {http.Client? client, this.timeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client();

  /// e.g. `http://192.168.1.20:8080`, without a trailing slash.
  final Uri baseUrl;
  final Duration timeout;
  final http.Client _client;

  /// Returns the server's stories.json with picture paths made absolute,
  /// ready to parse with [parseStories] and to cache on the device.
  /// Throws if the server can't be reached or sends something invalid.
  Future<String> fetch() async {
    final response =
        await _client.get(baseUrl.resolve('/api/stories')).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
          'Story server answered ${response.statusCode}', baseUrl);
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    for (final story in json['stories'] as List<dynamic>) {
      for (final page
          in (story as Map<String, dynamic>)['pages'] as List<dynamic>) {
        final map = page as Map<String, dynamic>;
        map['image'] = _resolveImage(map['image'] as String);
        final animation = map['animation'];
        if (animation is Map<String, dynamic> && animation['asset'] is String) {
          animation['asset'] = _resolveImage(animation['asset'] as String);
        }
      }
      for (final question in story['questions'] as List<dynamic>? ?? const []) {
        if (question is Map<String, dynamic> &&
            question['choiceImages'] is List) {
          question['choiceImages'] = [
            for (final image in question['choiceImages'] as List)
              image is String ? _resolveImage(image) : null,
          ];
        }
      }
    }
    final raw = jsonEncode(json);
    parseStories(raw); // throws FormatException/TypeError on bad data
    return raw;
  }

  /// Bundled pictures stay as assets (they are already in the app);
  /// uploaded ones become full URLs on the server.
  String _resolveImage(String path) {
    if (path.startsWith('assets/') ||
        path.startsWith('http://') ||
        path.startsWith('https://')) {
      return path;
    }
    return baseUrl.resolve('/$path').toString();
  }
}
