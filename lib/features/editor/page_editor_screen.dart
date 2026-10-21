import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/narration/narrator.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/story.dart';
import '../../data/scene_catalog.dart';
import '../../data/story_store.dart';
import '../../shared/widgets/widgets.dart';
import 'widgets/editor_text_field.dart';
import 'widgets/framing_editor.dart';
import 'widgets/scene_picker.dart';

/// Edit mode: edit one page – its picture (from the scene
/// illustrations), how the picture is framed, and its two sentences.
/// Every change is saved to the draft automatically.
class PageEditorScreen extends StatefulWidget {
  const PageEditorScreen({super.key, required this.storyId, required this.pageId});

  final String storyId;
  final String pageId;

  static Route<void> route(String storyId, String pageId) => MaterialPageRoute<void>(
        settings: RouteSettings(name: '/edit/$storyId/$pageId'),
        builder: (_) => PageEditorScreen(storyId: storyId, pageId: pageId),
      );

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  final TextEditingController _lead = TextEditingController();
  final TextEditingController _body = TextEditingController();
  late StoryStore _store;
  late Narrator _narrator;
  bool _initialised = false;
  bool _draggingPicture = false;

  Story? get _story => _store.draft(widget.storyId);

  StoryPage? get _page {
    for (final page in _story?.pages ?? const <StoryPage>[]) {
      if (page.id == widget.pageId) return page;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    _store = AppScope.read(context).store;
    _narrator = AppScope.read(context).narrator;
    _lead.text = _page?.lead ?? '';
    _body.text = _page?.body ?? '';
  }

  @override
  void dispose() {
    _narrator.stop();
    _lead.dispose();
    _body.dispose();
    super.dispose();
  }

  void _update(StoryPage Function(StoryPage page) change) {
    final page = _page;
    if (page != null) _store.updatePage(widget.storyId, change(page));
  }

  void _pickScene(Scene scene) =>
      // A new picture starts unzoomed; parents can then reframe it.
      _update((p) => p.copyWith(image: scene.asset, focus: Alignment.center, zoom: 1));

  void _listen() {
    final page = _page;
    if (page == null || page.narration.isEmpty) return;
    _narrator.speak(page.narration, rate: AppScope.read(context).settings.speechRate);
  }

  void _addPageAfter() {
    final story = _story;
    final page = _page;
    if (story == null || page == null) return;
    final next = _store.addPage(story.id, afterIndex: story.pages.indexOf(page));
    if (next != null) {
      Navigator.of(context).pushReplacement(PageEditorScreen.route(story.id, next.id));
    }
  }

  Future<void> _deletePage() async {
    final story = _story;
    final page = _page;
    if (story == null || page == null) return;
    if (story.pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A story needs at least one page.')),
      );
      return;
    }
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete this page?',
      message: 'This removes the page and its text.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    Navigator.of(context).pop();
    _store.deletePage(story.id, page.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final story = _story;
        final page = _page;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  child: story == null || page == null
                      ? const Center(child: Text('This page no longer exists.'))
                      : _buildBody(story, page),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(Story story, StoryPage page) {
    final number = story.pages.indexOf(page) + 1;

    final picture = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('How the picture looks'),
        FramingEditor(
          frame: page.frame,
          onChanged: (focus, zoom) => _update((p) => p.copyWith(focus: focus, zoom: zoom)),
          onDragging: (dragging) => setState(() => _draggingPicture = dragging),
        ),
      ],
    );

    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Words',
          trailing: PillButton(
            label: 'Listen',
            leadingIcon: Icons.volume_up_rounded,
            variant: PillButtonVariant.soft,
            onPressed: _listen,
          ),
        ),
        EditorTextField(
          controller: _lead,
          label: 'Main sentence (shown in bold)',
          hint: 'First, we…',
          bold: true,
          maxLines: 3,
          onChanged: (value) => _update((p) => p.copyWith(lead: value)),
        ),
        const SizedBox(height: AppDimens.gapM),
        EditorTextField(
          controller: _body,
          label: 'More detail',
          hint: 'Then we…',
          maxLines: 4,
          onChanged: (value) => _update((p) => p.copyWith(body: value)),
        ),
      ],
    );

    final scenes = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Choose a picture'),
        ScenePicker(selected: page.image, onSelected: _pickScene),
      ],
    );

    final actions = Wrap(
      alignment: WrapAlignment.center,
      spacing: AppDimens.gapM,
      runSpacing: AppDimens.gapM,
      children: [
        PillButton(
          label: 'Delete Page',
          leadingIcon: Icons.delete_outline_rounded,
          variant: PillButtonVariant.soft,
          onPressed: _deletePage,
        ),
        PillButton(label: 'Add Next Page', leadingIcon: Icons.add_rounded, onPressed: _addPageAfter),
      ],
    );

    return Column(
      children: [
        ScreenHeader(
          title: 'Edit Page',
          subtitle: InfoPill(
            label: '$number of ${story.pages.length}',
            semanticsLabel: 'Page $number of ${story.pages.length}',
          ),
          leading: RoundIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Back to pages',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          trailing: RoundIconButton(
            icon: Icons.check_rounded,
            tooltip: 'Done',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(height: AppDimens.gapL),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              return SingleChildScrollView(
                // Locked while a finger is on the picture so dragging moves it.
                physics: _draggingPicture ? const NeverScrollableScrollPhysics() : null,
                padding: const EdgeInsets.only(bottom: AppDimens.gapXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: picture),
                          const SizedBox(width: AppDimens.gapXL),
                          Expanded(child: words),
                        ],
                      )
                    else ...[
                      picture,
                      const SizedBox(height: AppDimens.gapXL),
                      words,
                    ],
                    const SizedBox(height: AppDimens.gapXL),
                    scenes,
                    const SizedBox(height: AppDimens.gapXL),
                    actions,
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
