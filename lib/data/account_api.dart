import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models/story.dart';

/// A problem the server reported (or a network failure), with a message
/// that can be shown to the user as is.
class ApiError implements Exception {
  const ApiError(this.message, {this.status});

  final String message;
  final int? status;

  bool get isSignedOut => status == 401;

  @override
  String toString() => message;
}

/// The signed-in user and their subscription.
@immutable
class Account {
  const Account({
    required this.id,
    required this.email,
    required this.name,
    required this.subscribed,
    required this.subscriptionSource,
    required this.subscribedUntil,
    required this.pendingSubmissions,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'] as Map<String, dynamic>? ?? const {};
    return Account(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String? ?? '',
      subscribed: sub['active'] as bool? ?? false,
      subscriptionSource: sub['source'] as String?,
      subscribedUntil:
          DateTime.tryParse(sub['until'] as String? ?? '')?.toLocal(),
      pendingSubmissions: (json['pendingSubmissions'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String email;
  final String name;
  final bool subscribed;

  /// "admin", "google_play" or null.
  final String? subscriptionSource;

  /// When the subscription ends; null with [subscribed] = no end date.
  final DateTime? subscribedUntil;
  final int pendingSubmissions;

  String get displayName => name.trim().isEmpty ? email : name.trim();
}

/// What kind of change a submission is.
enum SubmissionType {
  newStory('new_story', 'New story'),
  editStory('edit_story', 'Story changes'),
  editQuestions('edit_questions', 'Quiz questions');

  const SubmissionType(this.wire, this.label);

  final String wire;
  final String label;

  static SubmissionType parse(String? value) =>
      values.firstWhere((t) => t.wire == value,
          orElse: () => SubmissionType.editStory);
}

/// A change sent for review, as its sender sees it.
@immutable
class Submission {
  const Submission({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.storyId,
    required this.createdAt,
    required this.reviewNote,
  });

  factory Submission.fromJson(Map<String, dynamic> json) => Submission(
        id: json['id'] as String,
        type: SubmissionType.parse(json['type'] as String?),
        status: json['status'] as String? ?? 'pending',
        title: json['title'] as String? ?? '',
        storyId: json['storyId'] as String?,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
        reviewNote: json['reviewNote'] as String?,
      );

  final String id;
  final SubmissionType type;

  /// pending, approved, rejected or withdrawn.
  final String status;
  final String title;
  final String? storyId;
  final DateTime? createdAt;

  /// The admin's message, if they left one.
  final String? reviewNote;

  bool get isPending => status == 'pending';
}

/// Talks to the story server's account endpoints.
class AccountApi {
  AccountApi(this.baseUrl,
      {http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _client = client ?? http.Client();

  final Uri baseUrl;
  final Duration timeout;
  final http.Client _client;

  Future<({String token, Account account})> register(
      String email, String password, String name) async {
    final json = await _send('POST', '/api/auth/register',
        body: {'email': email, 'password': password, 'name': name});
    return (
      token: json['token'] as String,
      account: Account.fromJson(json['user'] as Map<String, dynamic>)
    );
  }

  Future<({String token, Account account})> signIn(
      String email, String password) async {
    final json = await _send('POST', '/api/auth/login',
        body: {'email': email, 'password': password});
    return (
      token: json['token'] as String,
      account: Account.fromJson(json['user'] as Map<String, dynamic>)
    );
  }

  Future<void> signOut(String token) =>
      _send('POST', '/api/auth/logout', token: token);

  Future<Account> me(String token) async =>
      Account.fromJson(await _send('GET', '/api/me', token: token));

  /// Sends a Google Play purchase for the server to check with Google.
  Future<Account> attachGooglePlay(String token,
          {required String productId, required String purchaseToken}) async =>
      Account.fromJson(await _send('POST', '/api/me/google-play',
          token: token,
          body: {'productId': productId, 'purchaseToken': purchaseToken}));

  Future<List<Submission>> submissions(String token) async {
    final list = await _send('GET', '/api/me/submissions', token: token)
        as List<dynamic>;
    return [
      for (final item in list) Submission.fromJson(item as Map<String, dynamic>)
    ];
  }

  Future<Submission> withdraw(String token, String id) async =>
      Submission.fromJson(
          await _send('DELETE', '/api/me/submissions/$id', token: token));

  Future<Submission> submit(
      String token, SubmissionType type, Story story) async {
    final json = await _send('POST', '/api/submissions', token: token, body: {
      'type': type.wire,
      if (type != SubmissionType.newStory) 'storyId': story.id,
      'story': _forServer(story),
    });
    return Submission.fromJson(json);
  }

  /// Pictures uploaded to this server are stored as full URLs in the app;
  /// the server wants them back as `uploads/...`.
  Map<String, dynamic> _forServer(Story story) {
    final json = story.toJson();
    final prefix = baseUrl.resolve('/').toString();
    for (final page in json['pages'] as List<dynamic>) {
      final map = page as Map<String, dynamic>;
      final image = map['image'] as String;
      if (image.startsWith(prefix)) {
        map['image'] = image.substring(prefix.length);
      }
      final animation = map['animation'];
      if (animation is Map<String, dynamic> && animation['asset'] is String) {
        final asset = animation['asset'] as String;
        if (asset.startsWith(prefix)) {
          animation['asset'] = asset.substring(prefix.length);
        }
      }
    }
    for (final question in json['questions'] as List<dynamic>? ?? const []) {
      final map = question as Map<String, dynamic>;
      if (map['choiceImages'] is List) {
        map['choiceImages'] = [
          for (final image in map['choiceImages'] as List)
            image is String && image.startsWith(prefix)
                ? image.substring(prefix.length)
                : image,
        ];
      }
    }
    return json;
  }

  Future<dynamic> _send(String method, String path,
      {String? token, Object? body}) async {
    final request = http.Request(method, baseUrl.resolve(path));
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
          await _client.send(request).timeout(timeout));
    } catch (_) {
      throw const ApiError(
          'Could not reach the story server. Check the internet connection and try again.');
    }
    final text = utf8.decode(response.bodyBytes);
    final Object? json = text.isEmpty ? null : _tryDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final message =
        json is Map<String, dynamic> ? json['error'] as String? : null;
    throw ApiError(
        message ??
            'Something went wrong (${response.statusCode}). Please try again.',
        status: response.statusCode);
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}
