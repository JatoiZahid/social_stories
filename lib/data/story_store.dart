import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'models/story.dart';
import 'scene_catalog.dart';
import 'scene_asset_upgrade.dart';
import 'story_repository.dart';
import 'story_storage.dart';

/// Single source of truth for stories.
///
/// Published stories are what children read: the ones the app ships with
/// (`assets/data/stories.json`), replaced by the story server's list once it
/// has been fetched. The latest server list is cached on the device so it
/// also shows offline.
///
/// A subscriber's changes are drafts, saved on this device only (edits of
/// published stories, plus new stories). Children never see drafts. A draft
/// is sent to the admin for review and published only once approved.
class StoryStore extends ChangeNotifier {
  StoryStore(
      {required this.repository,
      required this.storage,
      this.remote,
      this.serverCache});

  final StoryRepository repository;
  final StoryStorage storage;

  /// The story server, or null to use only the bundled stories.
  final RemoteStoryRepository? remote;

  /// Keeps the last list downloaded from [remote].
  final StoryStorage? serverCache;

  List<Story> _builtIn = const [];
  List<Story> _bundled = const [];
  List<Story> _legacySignatures = const [];
  final Map<String, Story> _overrides = {};
  final List<Story> _custom = [];
  Future<void>? _loading;
  Future<bool>? _refreshing;
  Timer? _saveTimer;
  bool _disposed = false;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// The published stories: what children see.
  List<Story> get stories => _builtIn;

  /// What an editor sees: published stories with this device's drafts
  /// applied, followed by new stories that are not published yet.
  List<Story> get editableStories => [
        for (final story in _builtIn) _overrides[story.id] ?? story,
        ..._custom,
      ];

  /// The published version of a story, or null if it is not published.
  Story? published(String id) {
    for (final story in _builtIn) {
      if (story.id == id) return story;
    }
    return null;
  }

  /// The version being edited: this device's draft, or else the published story.
  Story? draft(String id) {
    for (final story in editableStories) {
      if (story.id == id) return story;
    }
    return null;
  }

  bool isPublished(String id) => _builtIn.any((s) => s.id == id);

  /// True if this device has unsent changes to the story (or it is a new story).
  bool hasDraft(String id) =>
      _overrides.containsKey(id) || _custom.any((s) => s.id == id);

  // ── Loading ────────────────────────────────────────────────────────────

  Future<void> load() => _loading ??= _load();

  Future<void> reload() {
    _loading = null;
    return load();
  }

  Future<void> _load() async {
    final cached = await _readServerCache();
    try {
      _bundled = await repository.loadStories();
    } catch (_) {
      if (cached == null) {
        _loading = null; // allow retry
        rethrow;
      }
      _bundled = const [];
    }
    _legacySignatures = await repository.loadLegacySceneSignatures();
    _builtIn = cached == null ? _bundled : _upgradeScenes(cached);
    try {
      final raw = await storage.read();
      if (raw != null) _restore(raw);
    } catch (error) {
      // Corrupt saved edits must never stop the app from opening.
      debugPrint('Ignoring saved story edits: $error');
    }
    _loaded = true;
    notifyListeners();
    // Stories are on screen now; check the server for newer ones.
    unawaited(refresh());
  }

  Future<List<Story>?> _readServerCache() async {
    try {
      final raw = await serverCache?.read();
      return raw == null ? null : parseStories(raw);
    } catch (error) {
      debugPrint('Ignoring cached server stories: $error');
      return null;
    }
  }

  bool get hasServer => remote != null;

  /// Downloads the latest stories from the story server. Returns false if
  /// there is no server or it can't be reached; the current stories stay.
  Future<bool> refresh() {
    final remote = this.remote;
    if (remote == null) return Future.value(false);
    return _refreshing ??=
        _refresh(remote).whenComplete(() => _refreshing = null);
  }

  Future<bool> _refresh(RemoteStoryRepository remote) async {
    await load();
    try {
      final raw = await remote.fetch();
      if (_disposed) return false;
      _builtIn = _upgradeScenes(parseStories(raw));
      notifyListeners();
      try {
        await serverCache?.write(raw);
      } catch (error) {
        debugPrint('Could not cache server stories: $error');
      }
      return true;
    } catch (error) {
      debugPrint('Could not reach the story server: $error');
      return false;
    }
  }

  List<Story> _upgradeScenes(List<Story> published) => upgradeLegacySceneAssets(
        published: published,
        bundled: _bundled,
        signatures: _legacySignatures,
      );

  void _restore(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _overrides.clear();
    _custom.clear();
    for (final item in json['overrides'] as List<dynamic>? ?? const []) {
      // Kept even if the story is not in the current list, so an edit
      // survives the server briefly dropping that story.
      final story = Story.fromJson(item as Map<String, dynamic>);
      _overrides[story.id] = story;
    }
    for (final item in json['custom'] as List<dynamic>? ?? const []) {
      _custom.add(Story.fromJson(item as Map<String, dynamic>));
    }
  }

  // ── Saving ─────────────────────────────────────────────────────────────

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    // Debounced so typing doesn't write to disk on every key press.
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  /// Writes pending edits to the device now.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final json = jsonEncode({
      'version': 1,
      'overrides': [for (final story in _overrides.values) story.toJson()],
      'custom': [for (final story in _custom) story.toJson()],
    });
    try {
      await storage.write(json);
    } catch (error) {
      debugPrint('Could not save story edits: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_saveTimer?.isActive ?? false) flush();
    super.dispose();
  }

  // ── Stories ────────────────────────────────────────────────────────────

  /// Saves [story] as this device's draft.
  void saveStory(Story story) {
    if (isPublished(story.id)) {
      _overrides[story.id] = story;
    } else {
      final index = _custom.indexWhere((s) => s.id == story.id);
      if (index == -1) {
        _custom.add(story);
      } else {
        _custom[index] = story;
      }
    }
    _changed();
  }

  Story createStory() {
    final story = Story(
      id: newId('story'),
      title: 'My New Story',
      pages: [
        StoryPage(
            id: newId('page'),
            image: SceneCatalog.fallback.asset,
            lead: '',
            body: '')
      ],
    );
    _custom.add(story);
    _changed();
    return story;
  }

  /// Throws away this device's draft: a published story goes back to its
  /// published version; a new story is deleted. Also used after a draft has
  /// been sent for review.
  void discardDraft(String id) {
    final removed = _overrides.remove(id) != null;
    final before = _custom.length;
    _custom.removeWhere((s) => s.id == id);
    if (removed || _custom.length != before) _changed();
  }

  /// Replaces the quiz questions of the draft.
  void setQuestions(String storyId, List<StoryQuestion> questions) {
    final story = draft(storyId);
    if (story != null) saveStory(story.copyWith(questions: questions));
  }

  // ── Pages ──────────────────────────────────────────────────────────────

  void _editPages(
      String storyId, List<StoryPage> Function(List<StoryPage> pages) edit) {
    final story = draft(storyId);
    if (story == null) return;
    final pages = edit([...story.pages]);
    if (pages.isEmpty) return; // a story always keeps at least one page
    saveStory(story.copyWith(pages: pages));
  }

  /// Adds a page after [afterIndex] (default: at the end). The new page
  /// starts with the same picture as the page before it.
  StoryPage? addPage(String storyId, {int? afterIndex}) {
    final story = draft(storyId);
    if (story == null) return null;
    final index =
        (afterIndex ?? story.pages.length - 1).clamp(0, story.pages.length - 1);
    final template = story.pages[index];
    final page = StoryPage(
      id: newId('page'),
      image: template.image,
      focus: template.focus,
      zoom: template.zoom,
      lead: '',
      body: '',
    );
    _editPages(storyId, (pages) => pages..insert(index + 1, page));
    return page;
  }

  void updatePage(String storyId, StoryPage page) =>
      _editPages(storyId, (pages) {
        final index = pages.indexWhere((p) => p.id == page.id);
        if (index != -1) pages[index] = page;
        return pages;
      });

  void insertPage(String storyId, int index, StoryPage page) => _editPages(
        storyId,
        (pages) => pages..insert(index.clamp(0, pages.length), page),
      );

  void duplicatePage(String storyId, String pageId) =>
      _editPages(storyId, (pages) {
        final index = pages.indexWhere((p) => p.id == pageId);
        if (index != -1) {
          pages.insert(index + 1, pages[index].copyWith(id: newId('page')));
        }
        return pages;
      });

  /// Returns false if it is the only page.
  bool deletePage(String storyId, String pageId) {
    final story = draft(storyId);
    if (story == null || story.pages.length <= 1) return false;
    _editPages(storyId, (pages) => pages..removeWhere((p) => p.id == pageId));
    return true;
  }

  /// [to] is the final position after the move.
  void movePage(String storyId, int from, int to) =>
      _editPages(storyId, (pages) {
        if (from < 0 || from >= pages.length) return pages;
        final page = pages.removeAt(from);
        pages.insert(to.clamp(0, pages.length), page);
        return pages;
      });
}
