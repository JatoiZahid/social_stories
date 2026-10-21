import 'package:flutter/material.dart';

import '../api.dart';

/// A page as children will see it: the framed picture and its two sentences.
class PagePreview extends StatelessWidget {
  const PagePreview({super.key, required this.page, required this.api});

  final StoryPage page;
  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = Alignment(page.focusX, page.focusY);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Transform.scale(
                scale: page.zoom,
                alignment: alignment,
                child: Image.network(
                  api.imageUrl(page.image),
                  fit: BoxFit.cover,
                  alignment: alignment,
                  errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(page.lead.isEmpty ? '(no main sentence)' : page.lead,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        if (page.body.isNotEmpty) Text(page.body, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// A quiz question with its answers; the right one is ticked.
class QuestionPreview extends StatelessWidget {
  const QuestionPreview({super.key, required this.number, required this.question});

  final int number;
  final StoryQuestion question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$number. ${question.question}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        for (var i = 0; i < question.choices.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  i == question.answer ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: i == question.answer ? Colors.green.shade600 : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(question.choices[i],
                      style: i == question.answer ? const TextStyle(fontWeight: FontWeight.w700) : null),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Shows two things next to each other on wide screens, stacked on phones.
class BeforeAfter extends StatelessWidget {
  const BeforeAfter({super.key, required this.before, required this.after});

  final Widget? before;
  final Widget? after;

  @override
  Widget build(BuildContext context) {
    Widget labelled(String label, Widget? child, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
            const SizedBox(height: 4),
            child ?? const Text('—'),
          ],
        );
    final scheme = Theme.of(context).colorScheme;
    final left = labelled('Now', before, scheme.outline);
    final right = labelled('After approval', after, scheme.primary);
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 560
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: left), const SizedBox(width: 16), Expanded(child: right)],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 12), right],
            ),
    );
  }
}
