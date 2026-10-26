import 'models/story.dart';

/// Applies reviewed bundled artwork only to unchanged, known legacy scenes.
///
/// This is an on-device view of the published server list. It never writes to
/// the server, restores removed stories, replaces questions, or touches drafts.
List<Story> upgradeLegacySceneAssets({
  required List<Story> published,
  required List<Story> bundled,
  required List<Story> signatures,
}) {
  final originals = {for (final story in signatures) story.id: story};
  final replacements = {for (final story in bundled) story.id: story};
  return [
    for (final story in published)
      _upgradeStory(story, originals[story.id], replacements[story.id]),
  ];
}

Story _upgradeStory(Story story, Story? original, Story? replacement) {
  if (original == null ||
      replacement == null ||
      story.title != original.title ||
      replacement.title != original.title ||
      story.pages.length != original.pages.length ||
      replacement.pages.length != original.pages.length) {
    return story;
  }
  // A reordered, added, removed, or replaced page changes the story context.
  for (var i = 0; i < original.pages.length; i++) {
    if (story.pages[i].id != original.pages[i].id ||
        replacement.pages[i].id != original.pages[i].id) {
      return story;
    }
  }
  var changed = false;
  final pages = <StoryPage>[];
  for (var i = 0; i < story.pages.length; i++) {
    final page = story.pages[i];
    final before = original.pages[i];
    final after = replacement.pages[i];
    if (page.animation == null &&
        page.sameAs(before) &&
        after.lead == before.lead &&
        after.body == before.body &&
        (after.animation?.isValid ?? false)) {
      changed = true;
      pages.add(page.copyWith(
          image: after.image,
          focus: after.focus,
          zoom: after.zoom,
          animation: after.animation));
    } else {
      pages.add(page);
    }
  }
  return changed ? story.copyWith(pages: pages) : story;
}
