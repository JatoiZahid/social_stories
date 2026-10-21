import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/story.dart';
import '../../data/story_store.dart';
import '../../shared/widgets/widgets.dart';

/// Edit mode: the multiple-choice quiz shown after a story's last page.
/// Each question has 2–4 answers; the parent marks the right one.
/// Changes are saved to the story's draft and sent for review with it.
class QuestionsEditorScreen extends StatefulWidget {
  const QuestionsEditorScreen({super.key, required this.storyId});

  final String storyId;

  static const int maxQuestions = 10;

  static Route<void> route(String storyId) => MaterialPageRoute<void>(
        settings: RouteSettings(name: '/edit/$storyId/questions'),
        builder: (_) => QuestionsEditorScreen(storyId: storyId),
      );

  @override
  State<QuestionsEditorScreen> createState() => _QuestionsEditorScreenState();
}

class _QuestionsEditorScreenState extends State<QuestionsEditorScreen> {
  late StoryStore _store;
  bool _initialised = false;

  Story? get _story => _store.draft(widget.storyId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    _store = AppScope.read(context).store;
  }

  void _save(List<StoryQuestion> questions) => _store.setQuestions(widget.storyId, questions);

  void _add() {
    final questions = [...?_story?.questions];
    if (questions.length >= QuestionsEditorScreen.maxQuestions) return;
    questions.add(StoryQuestion(id: newId('question'), question: '', choices: const ['', ''], answer: 0));
    _save(questions);
  }

  void _replace(StoryQuestion question) {
    final questions = [...?_story?.questions];
    final index = questions.indexWhere((q) => q.id == question.id);
    if (index == -1) return;
    questions[index] = question;
    _save(questions);
  }

  void _move(int index, int delta) {
    final questions = [...?_story?.questions];
    final to = index + delta;
    if (to < 0 || to >= questions.length) return;
    questions.insert(to, questions.removeAt(index));
    _save(questions);
  }

  Future<void> _delete(StoryQuestion question, int number) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete question $number?',
      message: 'This removes the question and its answers.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    _save([...?_story?.questions]..removeWhere((q) => q.id == question.id));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final story = _story;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: story == null
                    ? const Center(child: Text('This story no longer exists.'))
                    : _body(story),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(Story story) {
    final questions = story.questions;
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      children: [
        ScreenHeader(
          title: 'Quiz Questions',
          subtitle: InfoPill(label: story.displayTitle),
          leading: RoundIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(height: AppDimens.gapM),
        Text(
          'Children answer these after the last page. Give each question 2 to 4 answers and tap ✓ next to the right one. '
          'Questions are sent for review together with the story.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: AppDimens.gapL),
        if (questions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.gapXL),
            child: Text('No questions yet.', textAlign: TextAlign.center, style: textTheme.bodyLarge),
          ),
        for (var i = 0; i < questions.length; i++) ...[
          _QuestionCard(
            key: ValueKey(questions[i].id),
            number: i + 1,
            question: questions[i],
            onChanged: _replace,
            onDelete: () => _delete(questions[i], i + 1),
            onMoveUp: i == 0 ? null : () => _move(i, -1),
            onMoveDown: i == questions.length - 1 ? null : () => _move(i, 1),
          ),
          const SizedBox(height: AppDimens.gapL),
        ],
        Center(
          child: PillButton(
            label: 'Add Question',
            leadingIcon: Icons.add_rounded,
            onPressed: questions.length >= QuestionsEditorScreen.maxQuestions ? null : _add,
          ),
        ),
      ],
    );
  }
}

/// One question: its text and its answers, with the right one marked.
class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    super.key,
    required this.number,
    required this.question,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int number;
  final StoryQuestion question;
  final ValueChanged<StoryQuestion> onChanged;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final TextEditingController _question = TextEditingController(text: widget.question.question);
  late final List<TextEditingController> _choices = [
    for (final choice in widget.question.choices) TextEditingController(text: choice),
  ];

  @override
  void dispose() {
    _question.dispose();
    for (final c in _choices) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit({int? answer}) => widget.onChanged(widget.question.copyWith(
        question: _question.text,
        choices: [for (final c in _choices) c.text],
        answer: answer ?? widget.question.answer,
      ));

  void _addChoice() {
    if (_choices.length >= StoryQuestion.maxChoices) return;
    setState(() => _choices.add(TextEditingController()));
    _emit();
  }

  void _removeChoice(int index) {
    if (_choices.length <= StoryQuestion.minChoices) return;
    final answer = widget.question.answer;
    setState(() => _choices.removeAt(index).dispose());
    // Keep the same answer marked; if it was the removed one, mark the first.
    _emit(answer: answer == index ? 0 : (answer > index ? answer - 1 : answer));
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.tint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimens.radiusM)),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final answer = widget.question.answer;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Question ${widget.number}',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              IconButton(tooltip: 'Move up', onPressed: widget.onMoveUp, icon: const Icon(Icons.arrow_upward_rounded)),
              IconButton(
                  tooltip: 'Move down', onPressed: widget.onMoveDown, icon: const Icon(Icons.arrow_downward_rounded)),
              IconButton(
                  tooltip: 'Delete question', onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline_rounded)),
            ],
          ),
          const SizedBox(height: AppDimens.gapS),
          TextField(
            controller: _question,
            maxLength: 200,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Question').copyWith(counterText: ''),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: AppDimens.gapM),
          for (var i = 0; i < _choices.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.gapS),
              child: Row(
                children: [
                  IconButton(
                    tooltip: i == answer ? 'Right answer' : 'Mark as the right answer',
                    onPressed: () => _emit(answer: i),
                    icon: Icon(
                      i == answer ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: i == answer ? Colors.green.shade600 : AppColors.inkSoft,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _choices[i],
                      maxLength: 100,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoration('Answer ${i + 1}').copyWith(counterText: ''),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove answer',
                    onPressed: _choices.length > StoryQuestion.minChoices ? () => _removeChoice(i) : null,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          if (_choices.length < StoryQuestion.maxChoices)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addChoice,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add answer'),
              ),
            ),
        ],
      ),
    );
  }
}
