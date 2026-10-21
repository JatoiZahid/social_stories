import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../shared/widgets/scene_image.dart';

int _idCounter = 0;

/// Unique id for pages and stories created in the editor.
String newId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_idCounter++}';

/// One page of a social story: an illustration plus two short sentences.
@immutable
class StoryPage {
  const StoryPage({
    required this.id,
    required this.image,
    required this.lead,
    required this.body,
    this.focus = Alignment.center,
    this.zoom = 1,
  });

  /// [fallbackId] is used for bundled pages that have no id in the JSON.
  factory StoryPage.fromJson(Map<String, dynamic> json, {required String fallbackId}) {
    final focus = json['focus'] as Map<String, dynamic>?;
    return StoryPage(
      id: json['id'] as String? ?? fallbackId,
      image: json['image'] as String,
      lead: json['lead'] as String? ?? '',
      body: json['body'] as String? ?? '',
      focus: focus == null
          ? Alignment.center
          : Alignment((focus['x'] as num).toDouble(), (focus['y'] as num).toDouble()),
      zoom: (focus?['zoom'] as num?)?.toDouble() ?? 1,
    );
  }

  final String id;

  /// Asset path of the scene illustration.
  final String image;

  /// The main sentence ("First, we…"), shown in bold.
  final String lead;

  /// The supporting sentence(s).
  final String body;

  /// Optional zoom into part of the picture, so pages that share an
  /// illustration still look different. 1 = whole picture.
  final Alignment focus;
  final double zoom;

  SceneFrame get frame => SceneFrame(image, focus: focus, zoom: zoom);

  /// What the narrator reads aloud.
  String get narration => [lead.trim(), body.trim()].where((s) => s.isNotEmpty).join(' ');

  StoryPage copyWith({
    String? id,
    String? image,
    String? lead,
    String? body,
    Alignment? focus,
    double? zoom,
  }) =>
      StoryPage(
        id: id ?? this.id,
        image: image ?? this.image,
        lead: lead ?? this.lead,
        body: body ?? this.body,
        focus: focus ?? this.focus,
        zoom: zoom ?? this.zoom,
      );

  /// Same picture, framing and text (ignoring the id).
  bool sameAs(StoryPage other) =>
      image == other.image && lead == other.lead && body == other.body && focus == other.focus && zoom == other.zoom;

  Map<String, dynamic> toJson() => {
        'id': id,
        'image': image,
        'lead': lead,
        'body': body,
        if (zoom != 1 || focus != Alignment.center)
          'focus': {'x': focus.x, 'y': focus.y, 'zoom': zoom},
      };
}

/// A multiple-choice question asked after the last page.
@immutable
class StoryQuestion {
  const StoryQuestion({required this.id, required this.question, required this.choices, required this.answer});

  factory StoryQuestion.fromJson(Map<String, dynamic> json, {required String fallbackId}) => StoryQuestion(
        id: json['id'] as String? ?? fallbackId,
        question: json['question'] as String? ?? '',
        choices: List.unmodifiable([for (final c in json['choices'] as List<dynamic>? ?? const []) c as String]),
        answer: (json['answer'] as num?)?.toInt() ?? 0,
      );

  static const int minChoices = 2;
  static const int maxChoices = 4;

  final String id;
  final String question;

  /// 2–4 answers to pick from.
  final List<String> choices;

  /// Index of the right answer in [choices].
  final int answer;

  /// What the narrator reads: the question, then the choices.
  String get narration => [question.trim(), ...choices.map((c) => c.trim())].where((s) => s.isNotEmpty).join('. ');

  /// Ready to send: text in the question and every choice, and a valid answer.
  bool get isComplete =>
      question.trim().isNotEmpty &&
      choices.length >= minChoices &&
      choices.every((c) => c.trim().isNotEmpty) &&
      answer >= 0 &&
      answer < choices.length;

  StoryQuestion copyWith({String? id, String? question, List<String>? choices, int? answer}) => StoryQuestion(
        id: id ?? this.id,
        question: question ?? this.question,
        choices: choices == null ? this.choices : List.unmodifiable(choices),
        answer: answer ?? this.answer,
      );

  Map<String, dynamic> toJson() => {'id': id, 'question': question, 'choices': choices, 'answer': answer};

  /// Same content, ignoring ids.
  bool sameAs(StoryQuestion other) =>
      question == other.question && answer == other.answer && listEquals(choices, other.choices);
}

/// A complete social story. Adding a story is a data change only.
@immutable
class Story {
  /// [pages] must not be empty.
  const Story({required this.id, required this.title, required this.pages, this.questions = const []});

  factory Story.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final rawPages = json['pages'] as List<dynamic>;
    final pages = [
      for (var i = 0; i < rawPages.length; i++)
        StoryPage.fromJson(rawPages[i] as Map<String, dynamic>, fallbackId: '$id-p${i + 1}'),
    ];
    if (pages.isEmpty) {
      throw FormatException('Story "$id" has no pages.');
    }
    final rawQuestions = json['questions'] as List<dynamic>? ?? const [];
    final questions = [
      for (var i = 0; i < rawQuestions.length; i++)
        StoryQuestion.fromJson(rawQuestions[i] as Map<String, dynamic>, fallbackId: '$id-q${i + 1}'),
    ];
    return Story(
      id: id,
      title: json['title'] as String,
      pages: List.unmodifiable(pages),
      questions: List.unmodifiable(questions),
    );
  }

  final String id;
  final String title;
  final List<StoryPage> pages;

  /// The quiz after the last page. May be empty.
  final List<StoryQuestion> questions;

  /// Title for display; never empty.
  String get displayTitle => title.trim().isEmpty ? 'Untitled story' : title.trim();

  /// The library card shows the first page's picture.
  SceneFrame get cover => SceneFrame(pages.first.image);

  Story copyWith({String? title, List<StoryPage>? pages, List<StoryQuestion>? questions}) => Story(
        id: id,
        title: title ?? this.title,
        pages: pages == null ? this.pages : List.unmodifiable(pages),
        questions: questions == null ? this.questions : List.unmodifiable(questions),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pages': [for (final page in pages) page.toJson()],
        if (questions.isNotEmpty) 'questions': [for (final q in questions) q.toJson()],
      };

  /// Same title and pages (ignoring page ids).
  bool samePagesAs(Story other) {
    if (title != other.title || pages.length != other.pages.length) return false;
    for (var i = 0; i < pages.length; i++) {
      if (!pages[i].sameAs(other.pages[i])) return false;
    }
    return true;
  }

  /// Same questions (ignoring ids).
  bool sameQuestionsAs(Story other) {
    if (questions.length != other.questions.length) return false;
    for (var i = 0; i < questions.length; i++) {
      if (!questions[i].sameAs(other.questions[i])) return false;
    }
    return true;
  }
}
