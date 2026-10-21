import 'package:shared_preferences/shared_preferences.dart';

/// A string saved on the device: story drafts, the downloaded stories, the session token.
abstract class StoryStorage {
  Future<String?> read();
  Future<void> write(String json);
  Future<void> clear();
}

class SharedPrefsStoryStorage implements StoryStorage {
  const SharedPrefsStoryStorage([this._key = 'story_edits_v1']);

  /// Key for the latest stories downloaded from the story server.
  static const String serverCacheKey = 'server_stories_v1';

  /// Key for the signed-in user's session token.
  static const String sessionKey = 'session_token_v1';

  final String _key;

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String json) async =>
      (await SharedPreferences.getInstance()).setString(_key, json);

  @override
  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}

/// In-memory storage for tests.
class MemoryStoryStorage implements StoryStorage {
  MemoryStoryStorage([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async => value = json;

  @override
  Future<void> clear() async => value = null;
}
