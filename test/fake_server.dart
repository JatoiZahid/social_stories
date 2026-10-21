import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:social_stories/data/account_api.dart';

/// A tiny in-memory stand-in for the story server's account endpoints.
class FakeServer {
  FakeServer({this.subscribed = true});

  bool subscribed;
  final List<Map<String, dynamic>> submissions = [];

  static const String token = 'session-token';

  Map<String, dynamic> get _user => {
        'id': 'u1',
        'email': 'parent@example.com',
        'name': 'Sam',
        'subscription': {'active': subscribed, 'source': subscribed ? 'admin' : null},
        'pendingSubmissions': submissions.length,
      };

  AccountApi api() => AccountApi(Uri.parse('http://server.test'), client: MockClient(_handle));

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    final signedIn = request.headers['authorization'] == 'Bearer $token';
    http.Response json(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

    if (path == '/api/auth/login') return json({'token': token, 'user': _user});
    if (!signedIn) return json({'error': 'Please sign in.'}, 401);
    switch ((request.method, path)) {
      case ('GET', '/api/me'):
        return json(_user);
      case ('POST', '/api/submissions'):
        if (!subscribed) return json({'error': 'You need an active subscription to do this.'}, 403);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final story = body['story'] as Map<String, dynamic>;
        final submission = {
          'id': 's${submissions.length + 1}',
          'type': body['type'],
          'status': 'pending',
          'storyId': body['storyId'],
          'title': story['title'],
          'story': story,
          'createdAt': '2026-10-21T10:00:00Z',
        };
        submissions.add(submission);
        return json(submission, 201);
      case ('GET', '/api/me/submissions'):
        return json(submissions.reversed.toList());
    }
    return json({'error': 'Not found'}, 404);
  }
}
