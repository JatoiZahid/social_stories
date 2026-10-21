import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/narration/narrator.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/story.dart';
import '../../shared/widgets/widgets.dart';
import 'quiz_screen.dart';
import 'widgets/story_controls.dart';
import 'widgets/story_page_view.dart';

/// The one story player. Every story (School, Toilet, Doctor…) is rendered
/// by this screen from its [Story] data – there are no per-story screens.
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key, required this.story});

  final Story story;

  static Route<void> route(Story story) => MaterialPageRoute<void>(
        settings: RouteSettings(name: '/story/${story.id}'),
        builder: (_) => StoryScreen(story: story),
      );

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final PageController _pageController = PageController();
  late Narrator _narrator;
  int _index = 0;
  bool _didPrecache = false;

  List<StoryPage> get _pages => widget.story.pages;
  bool get _isLastPage => _index == _pages.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoNarrate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _narrator = AppScope.read(context).narrator;
    if (!_didPrecache) {
      _didPrecache = true;
      for (final page in _pages) {
        precacheImage(imageProviderFor(page.image), context, onError: (_, __) {});
      }
    }
  }

  @override
  void dispose() {
    _narrator.stop();
    _pageController.dispose();
    super.dispose();
  }

  // ── Narration ──────────────────────────────────────────────────────────

  void _narrate() {
    final settings = AppScope.read(context).settings;
    _narrator.speak(_pages[_index].narration, rate: settings.speechRate);
  }

  void _autoNarrate() {
    if (!mounted) return;
    if (AppScope.read(context).settings.autoRead) _narrate();
  }

  void _toggleNarration() {
    if (_narrator.isSpeaking.value) {
      _narrator.stop();
    } else {
      _narrate();
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _narrator.stop();
    _autoNarrate();
  }

  Future<void> _goTo(int index) async {
    if (index == _index) return;
    if ((index - _index).abs() > 1) {
      // Jump so we don't read every page we pass on the way.
      _pageController.jumpToPage(index);
      return;
    }
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _next() async {
    if (!_isLastPage) return _goTo(_index + 1);

    await _narrator.stop();
    if (!mounted) return;
    if (widget.story.questions.isNotEmpty) {
      // The quiz comes first; going back from it returns to the last page.
      final finished = await Navigator.of(context).push(QuizScreen.route(widget.story));
      if (finished != true || !mounted) return;
    }
    final action = await CompletionDialog.show(context, storyTitle: widget.story.displayTitle);
    if (!mounted) return;
    switch (action) {
      case CompletionAction.readAgain:
        if (_index == 0) {
          _autoNarrate();
        } else {
          _pageController.jumpToPage(0);
        }
      case CompletionAction.done:
        Navigator.of(context).pop();
      case null:
        break;
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppDimens.maxStoryWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.gapM,
                  AppDimens.gapS,
                  AppDimens.gapM,
                  AppDimens.gapL,
                ),
                child: Column(
                  children: [
                    ScreenHeader(
                      title: widget.story.displayTitle,
                      subtitle: InfoPill(
                        label: '${_index + 1} of ${_pages.length}',
                        semanticsLabel: 'Page ${_index + 1} of ${_pages.length}',
                      ),
                      leading: RoundIconButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Back to stories',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      trailing: RoundIconButton(
                        icon: Icons.settings_rounded,
                        tooltip: 'Settings',
                        onPressed: () => SettingsSheet.show(context),
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapM),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _pages.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapXS),
                          child: StoryPageView(
                            page: _pages[index],
                            isSpeaking: _narrator.isSpeaking,
                            onSpeakerPressed: _toggleNarration,
                            largeText: settings.largeText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapL),
                    ThumbnailStrip(
                      frames: [for (final page in _pages) page.frame],
                      selectedIndex: _index,
                      onSelected: _goTo,
                    ),
                    const SizedBox(height: AppDimens.gapL),
                    StoryControls(
                      pageCount: _pages.length,
                      currentIndex: _index,
                      onListenAgain: _narrate,
                      onNext: _next,
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
