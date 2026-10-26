import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/narration/narrator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/story.dart';
import '../../shared/widgets/widgets.dart';

/// The multiple-choice quiz after a story's last page. A wrong answer is
/// greyed out and the child tries again, so every question ends on the
/// right answer. Pops with true when all questions are answered.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.story});

  final Story story;

  static Route<bool> route(Story story) => MaterialPageRoute<bool>(
        settings: RouteSettings(name: '/story/${story.id}/quiz'),
        builder: (_) => QuizScreen(story: story),
      );

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Narrator _narrator;
  int _index = 0;
  final Set<int> _wrong = {};
  bool _solved = false;

  List<StoryQuestion> get _questions => widget.story.questions;
  StoryQuestion get _question => _questions[_index];
  bool get _isLast => _index == _questions.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AppScope.read(context).settings.autoRead) {
        _say(_question.narration);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _narrator = AppScope.read(context).narrator;
  }

  @override
  void dispose() {
    _narrator.stop();
    super.dispose();
  }

  void _say(String text) =>
      _narrator.speak(text, rate: AppScope.read(context).settings.speechRate);

  void _choose(int choice) {
    if (_solved || _wrong.contains(choice)) return;
    if (choice == _question.answer) {
      setState(() => _solved = true);
      _say("That's right! ${_question.choices[choice]}.");
    } else {
      setState(() => _wrong.add(choice));
      _say('Not quite. Try again!');
    }
  }

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _index++;
      _wrong.clear();
      _solved = false;
    });
    if (AppScope.read(context).settings.autoRead) _say(_question.narration);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final textTheme = Theme.of(context).textTheme;
    final question = _question;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              child: AppCard(
                child: Column(
                  children: [
                    ScreenHeader(
                      title: 'Quiz',
                      subtitle: InfoPill(
                        label: '${_index + 1} of ${_questions.length}',
                        semanticsLabel:
                            'Question ${_index + 1} of ${_questions.length}',
                      ),
                      leading: RoundIconButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Back to the story',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      trailing: RoundIconButton(
                        icon: Icons.volume_up_rounded,
                        tooltip: 'Read the question',
                        onPressed: () => _say(question.narration),
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapL),
                    Expanded(
                      child: ListView(
                        children: [
                          Text(
                            question.question,
                            textAlign: TextAlign.center,
                            style: (settings.largeText
                                    ? textTheme.headlineMedium
                                    : textTheme.headlineSmall)
                                ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink),
                          ),
                          const SizedBox(height: AppDimens.gapXL),
                          for (var i = 0; i < question.choices.length; i++) ...[
                            _ChoiceButton(
                              label: question.choices[i],
                              image: question.imageForChoice(i),
                              state: _solved && i == question.answer
                                  ? _ChoiceState.right
                                  : _wrong.contains(i)
                                      ? _ChoiceState.wrong
                                      : _ChoiceState.open,
                              enabled: !_solved,
                              largeText: settings.largeText,
                              onTap: () => _choose(i),
                            ),
                            const SizedBox(height: AppDimens.gapM),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapM),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _solved
                          ? Column(
                              key: const ValueKey('solved'),
                              children: [
                                Text("That's right!",
                                    style: textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.green.shade700)),
                                const SizedBox(height: AppDimens.gapM),
                                PillButton(
                                  label: _isLast ? 'Finish' : 'Next Question',
                                  trailingIcon: _isLast
                                      ? Icons.star_rounded
                                      : Icons.chevron_right_rounded,
                                  onPressed: _next,
                                ),
                              ],
                            )
                          : Text(
                              _wrong.isEmpty
                                  ? 'Tap the right answer.'
                                  : 'Not quite. Try again!',
                              key: ValueKey(_wrong.length),
                              style: textTheme.titleMedium?.copyWith(
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ChoiceState { open, right, wrong }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.state,
    required this.enabled,
    required this.largeText,
    required this.onTap,
    this.image,
  });

  final String label;
  final _ChoiceState state;
  final bool enabled;
  final bool largeText;
  final VoidCallback onTap;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final (background, border, icon) = switch (state) {
      _ChoiceState.right => (
          Colors.green.shade50,
          Colors.green.shade600,
          Icons.check_circle_rounded
        ),
      _ChoiceState.wrong => (
          AppColors.tint,
          AppColors.dotInactive,
          Icons.close_rounded
        ),
      _ChoiceState.open => (AppColors.surface, AppColors.border, null),
    };
    final textStyle = (largeText
            ? Theme.of(context).textTheme.titleLarge
            : Theme.of(context).textTheme.titleMedium)
        ?.copyWith(
      fontWeight: FontWeight.w700,
      color: state == _ChoiceState.wrong ? AppColors.inkSoft : AppColors.ink,
      decoration:
          state == _ChoiceState.wrong ? TextDecoration.lineThrough : null,
    );
    return Semantics(
      button: true,
      label: [
        label,
        if (state == _ChoiceState.right) 'right answer',
        if (state == _ChoiceState.wrong) 'not right'
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusL),
          side: BorderSide(
              color: border, width: state == _ChoiceState.right ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusL),
          onTap: enabled && state == _ChoiceState.open ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.gapL, vertical: AppDimens.gapM),
              child: Row(
                children: [
                  if (image != null) ...[
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: Image(
                        image: imageProviderFor(image!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: AppDimens.gapM),
                  ],
                  Expanded(child: Text(label, style: textStyle)),
                  if (icon != null)
                    Icon(icon,
                        color: state == _ChoiceState.right
                            ? Colors.green.shade600
                            : AppColors.inkSoft),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
