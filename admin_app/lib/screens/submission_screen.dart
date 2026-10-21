import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets/format.dart';
import '../widgets/story_preview.dart';

/// One submission: what changes, compared with the published story, and
/// the Approve / Reject buttons. Pops with true after a decision.
class SubmissionScreen extends StatefulWidget {
  const SubmissionScreen({super.key, required this.api, required this.submissionId});

  final AdminApi api;
  final String submissionId;

  @override
  State<SubmissionScreen> createState() => _SubmissionScreenState();
}

class _SubmissionScreenState extends State<SubmissionScreen> {
  late Future<Submission> _loading = widget.api.submission(widget.submissionId);
  bool _onlyChanges = true;
  bool _busy = false;

  Future<void> _decide({required bool approve}) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(approve: approve),
    );
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (approve) {
        await widget.api.approve(widget.submissionId, note);
      } else {
        await widget.api.reject(widget.submissionId, note);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Approved and published.' : 'Rejected. The sender can see your note.')),
      );
      Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Submission>(
      future: _loading,
      builder: (context, snapshot) {
        final s = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(s?.title ?? 'Submission')),
          body: snapshot.hasError
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${snapshot.error}'),
                    TextButton(
                      onPressed: () => setState(() {
                        _loading = widget.api.submission(widget.submissionId);
                      }),
                      child: const Text('Try again'),
                    ),
                  ]),
                )
              : s == null
                  ? const Center(child: CircularProgressIndicator())
                  : _body(s),
          bottomNavigationBar: s == null || !s.isPending
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : () => _decide(approve: false),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : () => _decide(approve: true),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _body(Submission s) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(typeIcon(s.type), color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(s.type.label, style: theme.textTheme.titleMedium),
                ]),
                const SizedBox(height: 8),
                Text('From ${s.submitter}'),
                if (s.createdAt != null) Text('Sent ${formatDateTime(s.createdAt!)}'),
                Text(statusLabel(s.status)),
                if (s.reviewNote != null) Text('Note: ${s.reviewNote}'),
              ],
            ),
          ),
        ),
        if (s.outdated) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'The published story was changed after this was sent. '
                'Approving replaces those changes with this version.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ...switch (s.type) {
          SubmissionType.newStory => _newStory(s),
          SubmissionType.editStory => _storyChanges(s),
          SubmissionType.editQuestions => _questionChanges(s),
        },
      ],
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      );

  Widget _card(Widget child) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      );

  List<Widget> _newStory(Submission s) => [
        _section(s.proposed.title),
        for (var i = 0; i < s.proposed.pages.length; i++)
          _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Page ${i + 1}', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            PagePreview(page: s.proposed.pages[i], api: widget.api),
          ])),
        if (s.proposed.questions.isNotEmpty) ...[
          _section('Quiz'),
          for (var i = 0; i < s.proposed.questions.length; i++)
            _card(QuestionPreview(number: i + 1, question: s.proposed.questions[i])),
        ],
      ];

  List<Widget> _storyChanges(Submission s) {
    final before = s.base!;
    final after = s.proposed;
    final count = math.max(before.pages.length, after.pages.length);
    final rows = <Widget>[];
    var changed = 0;
    for (var i = 0; i < count; i++) {
      final b = i < before.pages.length ? before.pages[i] : null;
      final a = i < after.pages.length ? after.pages[i] : null;
      final same = a != null && b != null && a.sameAs(b);
      if (!same) changed++;
      if (same && _onlyChanges) continue;
      final label = b == null ? 'new page' : a == null ? 'removed' : same ? 'unchanged' : 'changed';
      rows.add(_card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Page ${i + 1} · $label', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        same
            ? PagePreview(page: a, api: widget.api)
            : BeforeAfter(
                before: b == null ? null : PagePreview(page: b, api: widget.api),
                after: a == null ? null : PagePreview(page: a, api: widget.api),
              ),
      ])));
    }
    return [
      if (before.title != after.title)
        _card(BeforeAfter(
          before: Text(before.title, style: Theme.of(context).textTheme.titleMedium),
          after: Text(after.title, style: Theme.of(context).textTheme.titleMedium),
        )),
      Row(children: [
        Expanded(child: _section('Pages: ${after.pages.length} (was ${before.pages.length}), $changed changed')),
      ]),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Show only changed pages'),
        value: _onlyChanges,
        onChanged: (v) => setState(() => _onlyChanges = v),
      ),
      ...rows,
    ];
  }

  List<Widget> _questionChanges(Submission s) {
    final before = s.base!.questions;
    final after = s.proposed.questions;
    Widget list(List<StoryQuestion> qs) => qs.isEmpty
        ? const Text('No questions')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < qs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: QuestionPreview(number: i + 1, question: qs[i]),
                ),
            ],
          );
    return [
      _section('Quiz for "${s.proposed.title}"'),
      _card(BeforeAfter(before: list(before), after: list(after))),
    ];
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.approve});

  final bool approve;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.approve ? 'Approve and publish?' : 'Reject this change?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.approve
              ? 'Children will see it the next time their app loads stories.'
              : 'The story stays as it is. Tell the sender why, so they can fix it.'),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: widget.approve ? 'Note for the sender (optional)' : 'Reason for the sender',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: Text(widget.approve ? 'Approve' : 'Reject'),
        ),
      ],
    );
  }
}
