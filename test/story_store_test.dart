import 'package:flutter_test/flutter_test.dart';
import 'package:social_stories/data/models/story.dart';
import 'package:social_stories/data/story_repository.dart';
import 'package:social_stories/data/story_storage.dart';
import 'package:social_stories/data/story_store.dart';

class FakeRepository extends StoryRepository {
  const FakeRepository();

  @override
  Future<List<Story>> loadStories() async => const [
        Story(
          id: 'demo',
          title: 'Demo Story',
          pages: [
            StoryPage(id: 'p1', image: 'assets/images/stories/sharing.png', lead: 'Page one lead.', body: 'One.'),
            StoryPage(id: 'p2', image: 'assets/images/stories/sharing.png', lead: 'Page two lead.', body: 'Two.'),
          ],
        ),
      ];
}

void main() {
  late MemoryStoryStorage storage;
  late StoryStore store;

  setUp(() async {
    storage = MemoryStoryStorage();
    store = StoryStore(repository: const FakeRepository(), storage: storage);
    await store.load();
  });

  test('editing a published story makes a draft that children do not see', () async {
    final story = store.draft('demo')!;
    store.saveStory(story.copyWith(title: 'Changed'));
    expect(store.draft('demo')!.title, 'Changed');
    expect(store.hasDraft('demo'), isTrue);
    expect(store.stories.single.title, 'Demo Story', reason: 'children still see the published story');

    await store.flush();
    final reopened = StoryStore(repository: const FakeRepository(), storage: storage);
    await reopened.load();
    expect(reopened.draft('demo')!.title, 'Changed');

    reopened.discardDraft('demo');
    expect(reopened.draft('demo')!.title, 'Demo Story');
  });

  test('add, duplicate, move and delete pages', () {
    final added = store.addPage('demo')!;
    expect(store.draft('demo')!.pages.map((p) => p.id), ['p1', 'p2', added.id]);
    expect(added.image, 'assets/images/stories/sharing.png');

    store.duplicatePage('demo', 'p1');
    expect(store.draft('demo')!.pages, hasLength(4));

    store.movePage('demo', 0, 3);
    expect(store.draft('demo')!.pages.last.id, 'p1');

    expect(store.deletePage('demo', 'p1'), isTrue);
    expect(store.draft('demo')!.pages.any((p) => p.id == 'p1'), isFalse);
  });

  test('the last page cannot be deleted', () {
    store.deletePage('demo', 'p2');
    expect(store.deletePage('demo', 'p1'), isFalse);
    expect(store.draft('demo')!.pages, hasLength(1));
  });

  test('parents can create and delete their own stories', () async {
    final story = store.createStory();
    expect(store.editableStories.last.id, story.id);
    expect(store.stories.any((s) => s.id == story.id), isFalse, reason: 'drafts are not shown to children');
    expect(store.isPublished(story.id), isFalse);

    await store.flush();
    final reopened = StoryStore(repository: const FakeRepository(), storage: storage);
    await reopened.load();
    expect(reopened.draft(story.id), isNotNull);

    reopened.discardDraft(story.id);
    expect(reopened.draft(story.id), isNull);
  });

  test('corrupt saved edits are ignored', () async {
    final broken = StoryStore(
      repository: const FakeRepository(),
      storage: MemoryStoryStorage('{not json'),
    );
    await broken.load();
    expect(broken.stories.single.title, 'Demo Story');
  });
}
