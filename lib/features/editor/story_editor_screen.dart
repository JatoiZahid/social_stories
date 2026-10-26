import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/account_api.dart';
import '../../data/models/story.dart';
import '../../data/story_store.dart';
import '../../shared/widgets/widgets.dart';
import '../story/story_screen.dart';
import 'page_editor_screen.dart';
import 'questions_editor_screen.dart';
import 'widgets/editor_text_field.dart';
import 'widgets/page_list_tile.dart';

enum _StoryAction { preview, reset, delete }

/// Edit mode (subscribers): edit a story's title, its pages (add, reorder by
/// dragging, duplicate, delete) and its quiz questions. Changes are saved as a
/// draft on this device until they are sent for review.
class StoryEditorScreen extends StatefulWidget {
  const StoryEditorScreen({super.key, required this.storyId});

  final String storyId;

  static Route<void> route(String storyId) => MaterialPageRoute<void>(
        settings: RouteSettings(name: '/edit/$storyId'),
        builder: (_) => StoryEditorScreen(storyId: storyId),
      );

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final TextEditingController _title = TextEditingController();
  late StoryStore _store;
  bool _initialised = false;

  Story? get _story => _store.draft(widget.storyId);
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    _store = AppScope.read(context).store;
    _title.text = _story?.title ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _editPage(StoryPage page) => Navigator.of(context)
      .push(PageEditorScreen.route(widget.storyId, page.id));

  void _addPage() {
    final page = _store.addPage(widget.storyId);
    if (page != null) _editPage(page);
  }

  Future<void> _deletePage(StoryPage page, int number) async {
    final story = _story;
    if (story == null) return;
    if (story.pages.length <= 1) {
      _snack('A story needs at least one page.');
      return;
    }
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete page $number?',
      message: 'This removes the page and its text.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
    );
    if (ok) _store.deletePage(widget.storyId, page.id);
  }

  Future<void> _onAction(_StoryAction action) async {
    final story = _story;
    if (story == null) return;
    switch (action) {
      case _StoryAction.preview:
        Navigator.of(context).push(StoryScreen.route(story));
      case _StoryAction.reset:
        final ok = await ConfirmDialog.show(
          context,
          title: 'Discard your changes?',
          message:
              'Your unsent changes to "${story.displayTitle}" will be undone.',
          confirmLabel: 'Discard',
          icon: Icons.restart_alt_rounded,
        );
        if (!ok || !mounted) return;
        _store.discardDraft(story.id);
        _title.text = _story?.title ?? '';
        _snack('Your changes were discarded.');
      case _StoryAction.delete:
        final ok = await ConfirmDialog.show(
          context,
          title: 'Delete this new story?',
          message:
              '"${story.displayTitle}" has not been sent for review. It and all its pages will be deleted.',
          confirmLabel: 'Delete',
          icon: Icons.delete_outline_rounded,
        );
        if (!ok || !mounted) return;
        Navigator.of(context).pop();
        _store.discardDraft(story.id);
    }
  }

  /// Sends the draft for review. A new story leaves the editor (it is
  /// waiting for review now); an edited story shows its published version again.
  Future<void> _send() async {
    final story = _story;
    if (story == null) return;
    final isNew = !_store.isPublished(story.id);
    final ok = await ConfirmDialog.show(
      context,
      title: 'Send for review?',
      message:
          'Our team will check "${story.displayTitle}". Children see it once it is approved. '
          'You can follow it under Account › Sent for review.',
      confirmLabel: 'Send',
      icon: Icons.send_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    try {
      final sent =
          await AppScope.read(context).account.submitDraft(_store, story.id);
      if (!mounted) return;
      _snack(
          'Sent for review: ${sent.map((t) => t.label.toLowerCase()).join(' and ')}.');
      if (isNew) {
        Navigator.of(context).pop();
      } else {
        _title.text = _story?.title ?? '';
      }
    } on ApiError catch (error) {
      if (mounted) _snack(error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  child: story == null
                      ? const Center(
                          child: Text('This story no longer exists.'))
                      : _body(story),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(Story story) {
    final published = _store.isPublished(story.id);
    final hasDraft = _store.hasDraft(story.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Edit Story',
          subtitle: InfoPill(
              label: !published
                  ? 'New story'
                  : hasDraft
                      ? 'Draft'
                      : 'Published'),
          leading: RoundIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          trailing: PopupMenuButton<_StoryAction>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.ink),
            onSelected: _onAction,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _StoryAction.preview,
                child: ListTile(
                    leading: Icon(Icons.play_arrow_rounded),
                    title: Text('Preview story')),
              ),
              if (published)
                PopupMenuItem(
                  value: _StoryAction.reset,
                  enabled: hasDraft,
                  child: const ListTile(
                      leading: Icon(Icons.restart_alt_rounded),
                      title: Text('Discard my changes')),
                ),
              if (!published)
                const PopupMenuItem(
                  value: _StoryAction.delete,
                  child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Delete story')),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapL),
        EditorTextField(
          controller: _title,
          label: 'Story title',
          bold: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            final current = _story;
            if (current != null) {
              _store.saveStory(current.copyWith(title: value));
            }
          },
        ),
        const SizedBox(height: AppDimens.gapL),
        SectionLabel(
          'Pages (${story.pages.length})',
          trailing: PillButton(
            label: 'Preview',
            leadingIcon: Icons.play_arrow_rounded,
            variant: PillButtonVariant.soft,
            onPressed: () => _onAction(_StoryAction.preview),
          ),
        ),
        Text(
          'Tap a page to change its picture or words. Drag ≡ to reorder.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: AppDimens.gapS),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: AppDimens.gapL),
            itemCount: story.pages.length,
            onReorderItem: (from, to) {
              _store.movePage(story.id, from, to);
            },
            itemBuilder: (context, index) {
              final page = story.pages[index];
              return PageListTile(
                key: ValueKey(page.id),
                number: index + 1,
                page: page,
                onTap: () => _editPage(page),
                onDuplicate: () => _store.duplicatePage(story.id, page.id),
                onDelete: () => _deletePage(page, index + 1),
                dragHandle: ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(AppDimens.gapS),
                    child: Icon(Icons.drag_indicator_rounded,
                        color: AppColors.inkSoft),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppDimens.gapS),
        Wrap(
          spacing: AppDimens.gapM,
          runSpacing: AppDimens.gapS,
          alignment: WrapAlignment.center,
          children: [
            PillButton(
              label: 'Add Page',
              leadingIcon: Icons.add_rounded,
              variant: PillButtonVariant.soft,
              onPressed: _addPage,
            ),
            PillButton(
              label: 'Quiz (${story.questions.length})',
              leadingIcon: Icons.quiz_rounded,
              variant: PillButtonVariant.soft,
              onPressed: () => Navigator.of(context)
                  .push(QuestionsEditorScreen.route(story.id)),
            ),
            PillButton(
              label: _sending ? 'Sending…' : 'Send for Review',
              leadingIcon: Icons.send_rounded,
              onPressed: _sending || !hasDraft ? null : _send,
            ),
          ],
        ),
      ],
    );
  }
}
