import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_stories/data/models/story.dart';
import 'package:social_stories/data/scene_catalog.dart';

void main() {
  late List<Story> stories;

  setUpAll(() {
    final raw = File('assets/data/stories.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    stories = (json['stories'] as List<dynamic>)
        .map((s) => Story.fromJson(s as Map<String, dynamic>))
        .toList();
  });

  test('has all 12 stories with unique ids', () {
    expect(stories, hasLength(12));
    expect(stories.map((s) => s.id).toSet(), hasLength(12));
  });

  test('every page has text, a unique id and an image that exists', () {
    for (final story in stories) {
      expect(story.pages.map((p) => p.id).toSet(), hasLength(story.pages.length), reason: story.id);
      for (final page in story.pages) {
        expect(page.lead.trim(), isNotEmpty, reason: story.id);
        expect(page.body.trim(), isNotEmpty, reason: story.id);
        expect(File(page.image).existsSync(), isTrue, reason: page.image);
      }
    }
  });

  test('every scene in the picker exists', () {
    expect(SceneCatalog.all, hasLength(12));
    for (final scene in SceneCatalog.all) {
      expect(File(scene.asset).existsSync(), isTrue, reason: scene.asset);
    }
  });

  test('story survives a JSON round trip', () {
    final story = stories.first;
    final copy = Story.fromJson(jsonDecode(jsonEncode(story.toJson())) as Map<String, dynamic>);
    expect(copy.title, story.title);
    expect(copy.pages.length, story.pages.length);
    for (var i = 0; i < story.pages.length; i++) {
      expect(copy.pages[i].id, story.pages[i].id);
      expect(copy.pages[i].narration, story.pages[i].narration);
      expect(copy.pages[i].zoom, story.pages[i].zoom);
      expect(copy.pages[i].focus, story.pages[i].focus);
    }
  });
}
