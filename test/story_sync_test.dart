import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:social_stories/data/story_repository.dart';
import 'package:social_stories/data/story_storage.dart';
import 'package:social_stories/data/story_store.dart';

import 'story_store_test.dart' show FakeRepository;

final server = Uri.parse('http://stories.test:8080');

const serverStories = {
  'version': 1,
  'stories': [
    {
      'id': 'haircut',
      'title': 'Getting a Haircut',
      'pages': [
        {'id': 'h1', 'image': 'assets/images/stories/sharing.png', 'lead': 'We sit.', 'body': 'In the chair.'},
        {'id': 'h2', 'image': 'uploads/abc.png', 'lead': 'Snip.', 'body': 'All done.'},
      ],
    },
  ],
};

RemoteStoryRepository remoteThat(Future<http.Response> Function(http.Request) handler) =>
    RemoteStoryRepository(server, client: MockClient(handler));

final online = remoteThat((request) async {
  expect(request.url.path, '/api/stories');
  return http.Response(jsonEncode(serverStories), 200);
});

final offline = remoteThat((_) async => throw const SocketException('no network'));

void main() {
  test('shows the bundled stories first, then the server stories', () async {
    final cache = MemoryStoryStorage();
    final store = StoryStore(
      repository: const FakeRepository(),
      storage: MemoryStoryStorage(),
      remote: online,
      serverCache: cache,
    );
    await store.load();
    expect(store.stories.single.id, 'demo', reason: 'bundled stories show straight away');

    expect(await store.refresh(), isTrue);
    expect(store.stories.single.id, 'haircut');
    expect(store.isPublished('haircut'), isTrue);
    expect(cache.value, isNotNull);
  });

  test('uploaded pictures point at the server; bundled ones stay assets', () async {
    final stories = parseStories(await online.fetch());
    expect(stories.single.pages[0].image, 'assets/images/stories/sharing.png');
    expect(stories.single.pages[1].image, 'http://stories.test:8080/uploads/abc.png');
  });

  test('offline: keeps the last downloaded stories', () async {
    final cache = MemoryStoryStorage(await online.fetch());
    final store = StoryStore(
      repository: const FakeRepository(),
      storage: MemoryStoryStorage(),
      remote: offline,
      serverCache: cache,
    );
    await store.load();
    expect(await store.refresh(), isFalse);
    expect(store.stories.single.id, 'haircut');
  });

  test('server down and nothing cached: bundled stories stay', () async {
    final store = StoryStore(
      repository: const FakeRepository(),
      storage: MemoryStoryStorage(),
      remote: remoteThat((_) async => http.Response('oops', 500)),
      serverCache: MemoryStoryStorage(),
    );
    await store.load();
    expect(await store.refresh(), isFalse);
    expect(store.stories.single.id, 'demo');
  });

  test('a draft of a server story survives a refresh and can be discarded', () async {
    final store = StoryStore(
      repository: const FakeRepository(),
      storage: MemoryStoryStorage(),
      remote: online,
      serverCache: MemoryStoryStorage(),
    );
    await store.load();
    await store.refresh();
    store.saveStory(store.draft('haircut')!.copyWith(title: 'Our Haircut'));
    await store.refresh();
    expect(store.draft('haircut')!.title, 'Our Haircut');

    store.discardDraft('haircut');
    expect(store.draft('haircut')!.title, 'Getting a Haircut');
    await store.flush();
  });
}
