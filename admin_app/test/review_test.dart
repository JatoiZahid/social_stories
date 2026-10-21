import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:social_stories_admin/api.dart';
import 'package:social_stories_admin/screens/home_screen.dart';
import 'package:social_stories_admin/session.dart';

Map<String, dynamic> page(String lead) => {'image': 'assets/images/stories/sharing.png', 'lead': lead, 'body': ''};

/// A fake story server with one pending edit and one user.
class FakeAdminServer {
  final List<String> calls = [];
  String status = 'pending';
  bool subscribed = false;

  Map<String, dynamic> get submission => {
        'id': 's1',
        'type': 'edit_story',
        'status': status,
        'storyId': 'sharing',
        'title': 'Sharing Is Caring',
        'proposed': {'id': 'sharing', 'title': 'Sharing Is Caring', 'pages': [page('We share toys.'), page('New page.')]},
        'base': {'id': 'sharing', 'title': 'Sharing', 'pages': [page('We share toys.')]},
        'submittedBy': {'id': 'u1', 'email': 'parent@example.com', 'name': 'Sam'},
        'createdAt': '2026-10-21T09:00:00Z',
        'outdated': false,
      };

  Map<String, dynamic> get user => {
        'id': 'u1',
        'email': 'parent@example.com',
        'name': 'Sam',
        'createdAt': '2026-10-01T09:00:00Z',
        'subscription': {'active': subscribed, 'source': subscribed ? 'admin' : null, 'adminGranted': subscribed},
        'pendingSubmissions': status == 'pending' ? 1 : 0,
      };

  AdminApi api() => AdminApi(Uri.parse('http://server.test'), 'token', client: MockClient(_handle));

  Future<http.Response> _handle(http.Request r) async {
    calls.add('${r.method} ${r.url.path}');
    http.Response json(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
    final path = r.url.path;
    if (path == '/api/admin/summary') {
      return json({'pending': status == 'pending' ? 1 : 0, 'users': 1, 'subscribers': subscribed ? 1 : 0});
    }
    if (path == '/api/admin/submissions') {
      final wanted = r.url.queryParameters['status'];
      return json(wanted == 'all' || wanted == status ? [submission] : []);
    }
    if (path == '/api/admin/submissions/s1') return json(submission);
    if (path == '/api/admin/submissions/s1/approve') {
      status = 'approved';
      return json(submission);
    }
    if (path == '/api/admin/users') return json([user]);
    if (path == '/api/admin/users/u1/subscription') {
      subscribed = (jsonDecode(r.body) as Map<String, dynamic>)['active'] as bool;
      return json(user);
    }
    return http.Response('{"error":"Not found"}', 404);
  }
}

void main() {
  late FakeAdminServer server;

  Future<void> pump(WidgetTester tester) async {
    server = FakeAdminServer();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(api: server.api(), session: Session())));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a waiting change, compares it and approves it', (tester) async {
    await pump(tester);
    expect(find.text('Sharing Is Caring'), findsOneWidget);
    expect(find.textContaining('Story changes'), findsOneWidget);

    await tester.tap(find.text('Sharing Is Caring'));
    await tester.pumpAndSettle();
    expect(find.text('Sharing'), findsOneWidget, reason: 'old title');
    expect(find.textContaining('Page 2 · new page'), findsOneWidget);
    expect(find.textContaining('Page 1'), findsNothing, reason: 'unchanged pages are hidden by default');

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Thanks!');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Approve')));
    await tester.pumpAndSettle();

    expect(server.calls, contains('POST /api/admin/submissions/s1/approve'));
    expect(find.text('Nothing waiting for review.'), findsOneWidget);
  });

  testWidgets('grants a subscription', (tester) async {
    await pump(tester);
    await tester.tap(find.textContaining('Subscribers').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('No subscription'), findsOneWidget);

    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subscription granted by admin'));
    await tester.pumpAndSettle();
    expect(find.text('No end date'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(server.subscribed, isTrue);
    expect(find.textContaining('Subscribed (granted by admin)'), findsOneWidget);
  });
}
