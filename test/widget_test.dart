import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_stories/app.dart';
import 'package:social_stories/core/account/account_service.dart';
import 'package:social_stories/core/narration/narrator.dart';
import 'package:social_stories/core/settings/app_settings.dart';
import 'package:social_stories/core/theme/app_theme.dart';
import 'package:social_stories/data/models/story.dart';
import 'package:social_stories/data/story_repository.dart';
import 'package:social_stories/data/story_storage.dart';
import 'package:social_stories/data/story_store.dart';

import 'fake_server.dart';
import 'story_store_test.dart' show FakeRepository;

/// One story with a two-question quiz.
class QuizRepository extends StoryRepository {
  const QuizRepository();

  @override
  Future<List<Story>> loadStories() async => const [
        Story(
          id: 'quiz',
          title: 'Quiz Story',
          pages: [StoryPage(id: 'p1', image: 'assets/images/stories/sharing.png', lead: 'We share.', body: 'Nice.')],
          questions: [
            StoryQuestion(id: 'q1', question: 'Do we share?', choices: ['No', 'Yes'], answer: 1),
            StoryQuestion(id: 'q2', question: 'Is sharing kind?', choices: ['Yes', 'No', 'Maybe'], answer: 0),
          ],
        ),
      ];
}

void main() {
  late SilentNarrator narrator;
  late AppSettings settings;
  late StoryStore store;
  late AccountService account;
  late FakeServer server;

  Future<void> pumpApp(
    WidgetTester tester, {
    StoryRepository repository = const FakeRepository(),
    bool signedIn = false,
    bool subscribed = true,
  }) async {
    narrator = SilentNarrator();
    settings = AppSettings();
    store = StoryStore(repository: repository, storage: MemoryStoryStorage());
    server = FakeServer(subscribed: subscribed);
    account = AccountService(api: server.api(), tokenStorage: MemoryStoryStorage());
    if (signedIn) await account.signIn(email: 'parent@example.com', password: 'password123');
    await tester.pumpWidget(
      StorybookApp(
        settings: settings,
        narrator: narrator,
        store: store,
        account: account,
        theme: AppTheme.light(useGoogleFonts: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens a story, narrates, pages forward and finishes', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Demo Story'));
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('Page one lead.'), findsOneWidget);
    expect(narrator.spoken, ['Page one lead. One.']);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
    expect(narrator.spoken.last, 'Page two lead. Two.');

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('Great job!'), findsOneWidget);

    await tester.tap(find.text('All Stories'));
    await tester.pumpAndSettle();
    expect(find.text('Social Stories'), findsOneWidget);
  });

  testWidgets('thumbnail tap jumps to that page', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Demo Story'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Go to page 2'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
  });

  testWidgets('the quiz comes after the last page; a wrong answer can be tried again', (tester) async {
    await pumpApp(tester, repository: const QuizRepository());
    await tester.tap(find.text('Quiz Story'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('Do we share?'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('Not quite. Try again!'), findsOneWidget);
    expect(narrator.spoken.last, 'Not quite. Try again!');

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text("That's right!"), findsOneWidget);
    await tester.tap(find.text('Next Question'));
    await tester.pumpAndSettle();

    expect(find.text('Is sharing kind?'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('Great job!'), findsOneWidget);
  });

  testWidgets('the account area is behind the grown-ups question', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account & story editing'));
    await tester.pumpAndSettle();
    expect(find.text('Grown-ups only'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Not quite. Try this one.'), findsOneWidget);
    expect(find.text('Account'), findsNothing);
  });

  testWidgets('edit mode needs a subscription', (tester) async {
    await pumpApp(tester, signedIn: true, subscribed: false);
    settings.editMode = true;
    await tester.pumpAndSettle();
    expect(find.text('New story'), findsNothing, reason: 'not subscribed, so the library stays in reading mode');

    server.subscribed = true;
    await account.refresh();
    await tester.pumpAndSettle();
    expect(find.text('New story'), findsOneWidget);
  });

  testWidgets('a subscriber edits a story and sends it for review', (tester) async {
    await pumpApp(tester, signedIn: true);
    settings.editMode = true;
    await tester.pumpAndSettle();

    await tester.tap(find.text('Demo Story'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Story'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Story title'), 'Our Day');
    await tester.pump();
    expect(store.draft('demo')!.title, 'Our Day');
    expect(store.stories.single.title, 'Demo Story', reason: 'children still see the published story');

    await tester.tap(find.text('Add Page'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Page'), findsOneWidget);
    expect(find.text('3 of 3'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Main sentence (shown in bold)'), 'We wave goodbye.');
    await tester.pump();
    expect(store.draft('demo')!.pages.last.lead, 'We wave goodbye.');

    final airport = find.bySemanticsLabel('Picture: Airport');
    await tester.ensureVisible(airport);
    await tester.pumpAndSettle();
    await tester.tap(airport);
    await tester.pump();
    expect(store.draft('demo')!.pages.last.image, 'assets/images/stories/airport.png');

    await tester.tap(find.byTooltip('Back to pages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send for Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(server.submissions, hasLength(1));
    expect(server.submissions.single['type'], 'edit_story');
    expect(server.submissions.single['title'], 'Our Day');
    expect(store.hasDraft('demo'), isFalse, reason: 'the draft is removed once sent');
    expect(find.textContaining('Sent for review'), findsOneWidget);

    await store.flush(); // no pending timers at test end
  });

  testWidgets('a subscriber writes a quiz question', (tester) async {
    await pumpApp(tester, signedIn: true);
    settings.editMode = true;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo Story'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quiz (0)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Question'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Question'), 'Who shares?');
    await tester.enterText(find.widgetWithText(TextField, 'Answer 1'), 'Me');
    await tester.enterText(find.widgetWithText(TextField, 'Answer 2'), 'Nobody');
    await tester.tap(find.byTooltip('Mark as the right answer').first);
    await tester.pump();

    final question = store.draft('demo')!.questions.single;
    expect(question.question, 'Who shares?');
    expect(question.choices, ['Me', 'Nobody']);
    expect(question.answer, 1);
    expect(question.isComplete, isTrue);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send for Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(server.submissions.single['type'], 'edit_questions');

    await store.flush();
  });
}
