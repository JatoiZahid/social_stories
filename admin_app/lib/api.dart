import 'dart:convert';

import 'package:http/http.dart' as http;

/// A problem the server reported (or a network failure), ready to show.
class ApiError implements Exception {
  const ApiError(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

// ── Models ──────────────────────────────────────────────────────────────

class StoryPage {
  StoryPage.fromJson(Map<String, dynamic> json)
    : image = json['image'] as String? ?? '',
      lead = json['lead'] as String? ?? '',
      body = json['body'] as String? ?? '',
      focusX =
          ((json['focus'] as Map<String, dynamic>?)?['x'] as num?)
              ?.toDouble() ??
          0,
      focusY =
          ((json['focus'] as Map<String, dynamic>?)?['y'] as num?)
              ?.toDouble() ??
          0,
      zoom =
          ((json['focus'] as Map<String, dynamic>?)?['zoom'] as num?)
              ?.toDouble() ??
          1,
      animation = json['animation'] as Map<String, dynamic>?;

  final String image;
  final String lead;
  final String body;
  final double focusX;
  final double focusY;
  final double zoom;
  final Map<String, dynamic>? animation;

  bool sameAs(StoryPage o) =>
      image == o.image &&
      lead == o.lead &&
      body == o.body &&
      focusX == o.focusX &&
      focusY == o.focusY &&
      zoom == o.zoom &&
      jsonEncode(animation) == jsonEncode(o.animation);
}

class StoryQuestion {
  StoryQuestion.fromJson(Map<String, dynamic> json)
    : question = json['question'] as String? ?? '',
      choices = [
        for (final c in json['choices'] as List<dynamic>? ?? const [])
          c as String,
      ],
      answer = (json['answer'] as num?)?.toInt() ?? 0,
      choiceImages = [
        for (final image in json['choiceImages'] as List<dynamic>? ?? const [])
          image as String?,
      ];

  final String question;
  final List<String> choices;
  final int answer;
  final List<String?> choiceImages;

  bool sameAs(StoryQuestion o) =>
      question == o.question &&
      answer == o.answer &&
      choices.join('\u0000') == o.choices.join('\u0000') &&
      jsonEncode(choiceImages) == jsonEncode(o.choiceImages);
}

class Story {
  Story.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String? ?? '',
      title = json['title'] as String? ?? '',
      pages = [
        for (final p in json['pages'] as List<dynamic>? ?? const [])
          StoryPage.fromJson(p as Map<String, dynamic>),
      ],
      questions = [
        for (final q in json['questions'] as List<dynamic>? ?? const [])
          StoryQuestion.fromJson(q as Map<String, dynamic>),
      ];

  final String id;
  final String title;
  final List<StoryPage> pages;
  final List<StoryQuestion> questions;
}

enum SubmissionType {
  newStory('new_story', 'New story'),
  editStory('edit_story', 'Story changes'),
  editQuestions('edit_questions', 'Quiz questions');

  const SubmissionType(this.wire, this.label);

  final String wire;
  final String label;

  static SubmissionType parse(String? v) =>
      values.firstWhere((t) => t.wire == v, orElse: () => editStory);
}

class Submission {
  Submission.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      type = SubmissionType.parse(json['type'] as String?),
      status = json['status'] as String? ?? 'pending',
      storyId = json['storyId'] as String?,
      title = json['title'] as String? ?? '',
      proposed = Story.fromJson(json['proposed'] as Map<String, dynamic>),
      base = json['base'] == null
          ? null
          : Story.fromJson(json['base'] as Map<String, dynamic>),
      submitterEmail =
          (json['submittedBy'] as Map<String, dynamic>?)?['email'] as String? ??
          '',
      submitterName =
          (json['submittedBy'] as Map<String, dynamic>?)?['name'] as String? ??
          '',
      createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '')
          ?.toLocal(),
      reviewedAt = DateTime.tryParse(json['reviewedAt'] as String? ?? '')
          ?.toLocal(),
      reviewNote = json['reviewNote'] as String?,
      outdated = json['outdated'] as bool? ?? false;

  final String id;
  final SubmissionType type;

  /// pending, approved, rejected or withdrawn.
  final String status;
  final String? storyId;
  final String title;

  /// The story as it would look after approval.
  final Story proposed;

  /// The published story when this was sent (null for a new story).
  final Story? base;
  final String submitterEmail;
  final String submitterName;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewNote;

  /// The published story changed after this was sent.
  final bool outdated;

  bool get isPending => status == 'pending';
  String get submitter => submitterName.trim().isEmpty
      ? submitterEmail
      : '${submitterName.trim()} ($submitterEmail)';
}

class AppUser {
  AppUser.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      email = json['email'] as String? ?? '',
      name = json['name'] as String? ?? '',
      createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '')
          ?.toLocal(),
      subscribed =
          (json['subscription'] as Map<String, dynamic>?)?['active'] as bool? ??
          false,
      source =
          (json['subscription'] as Map<String, dynamic>?)?['source'] as String?,
      until = _date((json['subscription'] as Map<String, dynamic>?)?['until']),
      adminGranted =
          (json['subscription'] as Map<String, dynamic>?)?['adminGranted']
              as bool? ??
          false,
      adminUntil = _date(
        (json['subscription'] as Map<String, dynamic>?)?['adminUntil'],
      ),
      googleUntil = _date(
        (json['subscription'] as Map<String, dynamic>?)?['googleUntil'],
      ),
      pending = (json['pendingSubmissions'] as num?)?.toInt() ?? 0;

  static DateTime? _date(Object? v) =>
      DateTime.tryParse(v as String? ?? '')?.toLocal();

  final String id;
  final String email;
  final String name;
  final DateTime? createdAt;
  final bool subscribed;
  final String? source;
  final DateTime? until;
  final bool adminGranted;

  /// Admin subscription end (exclusive: the start of the day after the last day).
  final DateTime? adminUntil;
  final DateTime? googleUntil;
  final int pending;

  String get displayName => name.trim().isEmpty ? email : name.trim();
}

class Summary {
  Summary.fromJson(Map<String, dynamic> json)
    : pending = (json['pending'] as num?)?.toInt() ?? 0,
      users = (json['users'] as num?)?.toInt() ?? 0,
      subscribers = (json['subscribers'] as num?)?.toInt() ?? 0;

  final int pending;
  final int users;
  final int subscribers;
}

// ── API ─────────────────────────────────────────────────────────────────

/// The story server's admin endpoints. Every call sends the admin token.
class AdminApi {
  AdminApi(this.baseUrl, this.token, {http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUrl;
  final String token;
  final http.Client _client;

  /// Full URL of a story picture (bundled ones are served by the server too).
  String imageUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://')
      ? path
      : baseUrl.resolve('/$path').toString();

  /// Throws if the server can't be reached or the token is wrong.
  Future<void> check() => _send('GET', '/api/auth');

  Future<Summary> summary() async =>
      Summary.fromJson(await _send('GET', '/api/admin/summary'));

  Future<List<Submission>> submissions(String status) async {
    final list = await _send(
      'GET',
      '/api/admin/submissions?status=$status',
    ) as List<dynamic>;
    return [
      for (final s in list) Submission.fromJson(s as Map<String, dynamic>),
    ];
  }

  Future<Submission> submission(String id) async =>
      Submission.fromJson(await _send('GET', '/api/admin/submissions/$id'));

  Future<Submission> approve(String id, String note) async =>
      Submission.fromJson(
        await _send(
          'POST',
          '/api/admin/submissions/$id/approve',
          body: {'note': note},
        ),
      );

  Future<Submission> reject(String id, String note) async =>
      Submission.fromJson(
        await _send(
          'POST',
          '/api/admin/submissions/$id/reject',
          body: {'note': note},
        ),
      );

  Future<List<AppUser>> users() async {
    final list = await _send('GET', '/api/admin/users') as List<dynamic>;
    return [for (final u in list) AppUser.fromJson(u as Map<String, dynamic>)];
  }

  /// [lastDay] null = no end date. Ignored when [active] is false.
  Future<AppUser> setSubscription(
    String userId, {
    required bool active,
    DateTime? lastDay,
  }) async {
    final until = lastDay == null
        ? null
        : '${lastDay.year.toString().padLeft(4, '0')}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
    return AppUser.fromJson(
      await _send(
        'PUT',
        '/api/admin/users/$userId/subscription',
        body: {'active': active, 'until': until},
      ),
    );
  }

  Future<dynamic> _send(String method, String path, {Object? body}) async {
    final request = http.Request(method, baseUrl.resolve(path))
      ..headers['authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 15)),
      );
    } catch (_) {
      throw const ApiError(
        'Could not reach the story server. Check the address and the network.',
      );
    }
    final text = utf8.decode(response.bodyBytes);
    Object? json;
    try {
      json = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      json = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final message = json is Map<String, dynamic>
        ? json['error'] as String?
        : null;
    throw ApiError(
      message ?? 'The server answered ${response.statusCode}.',
      status: response.statusCode,
    );
  }
}
