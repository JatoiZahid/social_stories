import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:social_stories/data/account_api.dart';
import 'package:social_stories/data/models/scene_animation.dart';
import 'package:social_stories/data/models/story.dart';
import 'package:social_stories/data/story_repository.dart';

const animation = SceneAnimation(
  asset: 'assets/animations/spritesheets/brushing_scene_01.png',
  columns: 2,
  rows: 1,
  row: 0,
  frameCount: 2,
  cue: 'brush',
  description: 'The child brushes their teeth.',
  loop: false,
);

void main() {
  test(
      'submissions return uploaded atlas and answer image URLs as server paths',
      () async {
    final api = AccountApi(Uri.parse('https://stories.test'),
        client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final story = body['story'] as Map<String, dynamic>;
      expect(story['pages'][0]['image'], 'uploads/poster.png');
      expect(story['pages'][0]['animation']['asset'], 'uploads/atlas.png');
      expect(
          story['questions'][0]['choiceImages'], ['uploads/brush.png', null]);
      return http.Response(jsonEncode({'id': 's', 'status': 'pending'}), 201);
    }));
    final story = Story.fromJson({
      'id': 'demo',
      'title': 'Demo',
      'pages': [
        {
          'image': 'https://stories.test/uploads/poster.png',
          'animation': {
            ...animation.toJson(),
            'asset': 'https://stories.test/uploads/atlas.png'
          }
        }
      ],
      'questions': const [
        {
          'question': 'Which?',
          'choices': ['Brush', 'Other'],
          'answer': 0,
          'choiceImages': ['https://stories.test/uploads/brush.png', null]
        }
      ],
    });
    await api.submit('token', SubmissionType.newStory, story);
  });

  test('action metadata round trips and survives nonsemantic edits', () {
    const page = StoryPage(
        id: 'p1',
        image: 'poster.png',
        lead: 'We brush.',
        body: 'Gently.',
        animation: animation);
    final copy = StoryPage.fromJson(jsonDecode(jsonEncode(page.toJson())),
        fallbackId: 'p');
    expect(copy.sameAs(page), isTrue);
    expect(copy.animation!.loop, isFalse);
    expect(page.copyWith(id: 'duplicate').animation, same(animation));
    expect(page.copyWith(zoom: 1.2).animation, same(animation));
    expect(page.copyWith(lead: 'We eat.').animation, isNull);
    expect(page.copyWith(body: 'Different action.').animation, isNull);
    expect(page.copyWith(image: 'another.png').animation, isNull);
    expect(page.copyWith(clearAnimation: true).animation, isNull);
    expect(page.copyWith(lead: 'New words.', animation: animation).animation,
        same(animation));
  });

  test('invalid remote atlas metadata is ignored without breaking the page',
      () {
    final valid = animation.toJson();
    for (final invalid in <Object?>[
      null,
      'wrong',
      {...valid, 'columns': 0},
      {...valid, 'row': 1},
      {...valid, 'frameCount': 3},
      {...valid, 'fps': double.nan},
      {...valid, 'posterFrame': -1},
      {...valid, 'columns': 1.5},
      {...valid, 'loop': 'true'},
      {...valid, 'asset': ''},
      {
        ...valid,
        'frameCues': ['one']
      },
      {
        ...valid,
        'frameCues': ['one', 2]
      },
      {
        ...valid,
        'frameCues': ['', 'two']
      },
    ]) {
      expect(SceneAnimation.tryParse(invalid), isNull, reason: '$invalid');
      final page = StoryPage.fromJson(
          {'image': 'still.png', 'animation': invalid},
          fallbackId: 'p');
      expect(page.image, 'still.png');
      expect(page.animation, isNull);
    }
    expect(SceneAnimation.tryParse(valid)!.sameAs(animation), isTrue);
    final phased = SceneAnimation.tryParse({
      ...valid,
      'frameCues': ['We', 'brush']
    })!;
    expect(SceneAnimation.tryParse(phased.toJson())!.sameAs(phased), isTrue);
  });

  test('answer pictures follow unchanged labels and clear renamed choices', () {
    const question = StoryQuestion(
        id: 'q',
        question: 'Which?',
        choices: ['Brush', 'Spoon'],
        answer: 0,
        choiceImages: ['brush.png', 'spoon.png']);
    expect(question.copyWith(choices: ['Spoon', 'Brush']).choiceImages,
        ['spoon.png', 'brush.png']);
    expect(question.copyWith(choices: ['Brush', 'Toy']).choiceImages,
        ['brush.png', null]);
    expect(question.copyWith(choices: ['Brush', 'Brush']).choiceImages,
        [null, null]);
    expect(
        StoryQuestion.fromJson(question.toJson(), fallbackId: 'q')
            .sameAs(question),
        isTrue);
    expect(question.sameAs(question.copyWith(choiceImages: [])), isFalse);
  });

  test('remote uploaded atlases and answer pictures resolve to the server',
      () async {
    final repository = RemoteStoryRepository(Uri.parse('https://stories.test'),
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'stories': [
                {
                  'id': 'demo',
                  'title': 'Demo',
                  'pages': [
                    {
                      'image': 'uploads/poster.png',
                      'animation': {
                        ...animation.toJson(),
                        'asset': 'uploads/atlas.png'
                      }
                    }
                  ],
                  'questions': [
                    {
                      'question': 'Which?',
                      'choices': ['Brush', 'Other'],
                      'answer': 0,
                      'choiceImages': ['uploads/brush.png', null]
                    }
                  ],
                }
              ]
            }),
            200)));
    final story = parseStories(await repository.fetch()).single;
    expect(story.pages.single.animation!.asset,
        'https://stories.test/uploads/atlas.png');
    expect(story.questions.single.choiceImages,
        ['https://stories.test/uploads/brush.png', null]);
  });
}
