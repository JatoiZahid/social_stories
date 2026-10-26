import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:social_stories/data/models/scene_animation.dart';
import 'package:social_stories/data/models/story.dart';
import 'package:social_stories/data/scene_asset_upgrade.dart';
import 'package:social_stories/data/story_repository.dart';
import 'package:social_stories/data/story_storage.dart';
import 'package:social_stories/data/story_store.dart';

const oldPage = StoryPage(
    id: 'brushing-p1',
    image: 'assets/images/stories/brushing.png',
    lead: 'We brush.',
    body: 'Gently.');
const original = Story(id: 'brushing', title: 'Brushing', pages: [oldPage]);
const action = SceneAnimation(
    asset: 'assets/animations/spritesheets/brushing.png',
    columns: 2,
    rows: 1,
    row: 0,
    frameCount: 2);
final updated = original.copyWith(pages: [
  oldPage.copyWith(
      image: 'assets/images/story_scenes/brushing.png', animation: action)
]);

class UpgradeRepository extends StoryRepository {
  @override
  Future<List<Story>> loadStories() async => [updated];

  @override
  Future<List<Story>> loadLegacySceneSignatures() async => [original];
}

String document(List<Story> stories) => jsonEncode({
      'stories': [for (final s in stories) s.toJson()]
    });

void main() {
  List<Story> upgrade(List<Story> published, {List<Story>? bundled}) =>
      upgradeLegacySceneAssets(
          published: published,
          bundled: bundled ?? [updated],
          signatures: [original]);

  test(
      'upgrades only known unchanged scenes and preserves questions and server list',
      () {
    const question = StoryQuestion(
        id: 'q', question: 'Which?', choices: ['Brush', 'Spoon'], answer: 0);
    final published = original.copyWith(questions: [question]);
    const custom = Story(id: 'custom', title: 'Custom', pages: [oldPage]);
    final result = upgrade([custom, published]);
    expect(result.map((s) => s.id), ['custom', 'brushing']);
    expect(result.first, same(custom));
    expect(result.last.questions.single, same(question));
    expect(result.last.pages.single.animation, same(action));
    expect(upgrade([]), isEmpty,
        reason: 'never restore a removed server story');
  });

  test(
      'preserves altered narration, pictures, framing, title, IDs and existing animation',
      () {
    final changes = [
      original.copyWith(title: 'A different story'),
      original.copyWith(pages: [oldPage.copyWith(id: 'new-id')]),
      original.copyWith(pages: [oldPage.copyWith(lead: 'We eat.')]),
      original.copyWith(pages: [oldPage.copyWith(body: 'Something else.')]),
      original.copyWith(pages: [oldPage.copyWith(image: 'uploads/custom.png')]),
      original.copyWith(pages: [oldPage.copyWith(focus: Alignment.topLeft)]),
      original.copyWith(pages: [oldPage.copyWith(zoom: 1.4)]),
      original.copyWith(pages: [oldPage.copyWith(animation: action)]),
    ];
    for (final changed in changes) {
      expect(upgrade([changed]).single, same(changed));
    }
    final alteredBundle = updated.copyWith(pages: [
      updated.pages.single.copyWith(lead: 'New narration.', animation: action)
    ]);
    expect(
        upgrade([original], bundled: [alteredBundle]).single, same(original));
  });

  test('checks page order and upgrades individual untouched pages', () {
    final second = oldPage.copyWith(id: 'brushing-p2');
    final before = original.copyWith(pages: [oldPage, second]);
    final after = updated.copyWith(
        pages: [updated.pages.first, second.copyWith(animation: action)]);
    final edited = before
        .copyWith(pages: [oldPage, second.copyWith(body: 'Parent edit.')]);
    final result = upgradeLegacySceneAssets(
        published: [edited], bundled: [after], signatures: [before]).single;
    expect(result.pages.first.animation, same(action));
    expect(result.pages.last, same(edited.pages.last));
    final reordered = before.copyWith(pages: [second, oldPage]);
    expect(
        upgradeLegacySceneAssets(
            published: [reordered],
            bundled: [after],
            signatures: [before]).single,
        same(reordered));
  });

  test(
      'cached and refreshed legacy stories gain bundled artwork while drafts remain untouched',
      () async {
    final raw = document([original]);
    final cache = MemoryStoryStorage(raw);
    final remote = RemoteStoryRepository(Uri.parse('https://stories.test'),
        client: MockClient((_) async => http.Response(raw, 200)));
    final draft =
        original.copyWith(pages: [oldPage.copyWith(body: 'A parent draft.')]);
    final storage = MemoryStoryStorage(jsonEncode({
      'overrides': [draft.toJson()]
    }));
    final store = StoryStore(
        repository: UpgradeRepository(),
        storage: storage,
        serverCache: cache,
        remote: remote);
    addTearDown(store.dispose);
    await store.load();
    expect(store.published('brushing')!.pages.single.animation, isNotNull);
    expect(store.draft('brushing')!.pages.single.body, 'A parent draft.');
    expect(store.draft('brushing')!.pages.single.animation, isNull);
    await store.refresh();
    expect(store.published('brushing')!.pages.single.animation, isNotNull);
    expect(parseStories(cache.value!).single.pages.single.animation, isNull,
        reason:
            'keep the server cache as received; upgrade only its local view');
  });
}
