import 'package:flutter/material.dart';

import '../../core/animation/scene_playback.dart';
import '../../core/app_scope.dart';
import '../../core/narration/narrator.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/story.dart';
import '../../shared/widgets/widgets.dart';
import 'quiz_screen.dart';
import 'widgets/story_controls.dart';
import 'widgets/story_page_view.dart';

/// Shared story player; scene changes cancel both speech and animation.
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

class _StoryScreenState extends State<StoryScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final ScenePlayback _playback = ScenePlayback();
  Narrator? _attachedNarrator;
  late Narrator _narrator;
  int _index = 0;
  int _request = 0;
  bool _speechWasActive = false;
  bool _stopping = false;
  bool _narrationPending = false;
  bool _narrationStarted = false;
  bool _backgrounded = false;
  bool _didPrecache = false;

  List<StoryPage> get _pages => widget.story.pages;
  bool get _isLastPage => _index == _pages.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoNarrate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _narrator = AppScope.read(context).narrator;
    if (_attachedNarrator != _narrator) {
      _detachNarrator();
      _attachedNarrator = _narrator;
      _narrator.isSpeaking.addListener(_onSpeakingChanged);
      if (_narrator is ResumableNarrator) {
        (_narrator as ResumableNarrator)
            .characterOffset
            .addListener(_onWordProgress);
      }
    }
    if (!_didPrecache) {
      _didPrecache = true;
      // Decode only nearby posters. Loading every large atlas upfront consumes
      // unnecessary tablet memory; each animation loads its own current sheet.
      for (final page in _pages.take(2)) {
        precacheImage(imageProviderFor(page.image), context,
            onError: (_, __) {});
      }
    }
  }

  void _detachNarrator() {
    final old = _attachedNarrator;
    old?.isSpeaking.removeListener(_onSpeakingChanged);
    if (old is ResumableNarrator) {
      old.characterOffset.removeListener(_onWordProgress);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgrounded = state != AppLifecycleState.resumed;
    if (_backgrounded) _pause();
  }

  @override
  void dispose() {
    ++_request;
    WidgetsBinding.instance.removeObserver(this);
    _detachNarrator();
    _narrator.stop();
    _playback.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onWordProgress() {
    if (_stopping || _narrator is! ResumableNarrator) return;
    _playback
        .updateProgress((_narrator as ResumableNarrator).characterOffset.value);
  }

  void _onSpeakingChanged() {
    if (_stopping) return;
    _playback.setSpeechActive(_narrator.isSpeaking.value);
    if (_narrator.isSpeaking.value) {
      _speechWasActive = true;
      if (!_playback.isPaused) _playback.play();
    } else if (_speechWasActive && !_playback.isPaused) {
      _speechWasActive = false;
      _playback.complete();
    }
  }

  Future<void> _narrate() async {
    if (_backgrounded) return;
    final request = ++_request;
    _stopping = true;
    _narrationPending = true;
    _narrationStarted = false;
    _speechWasActive = false;
    final settings = AppScope.read(context).settings;
    final page = _pages[_index];
    _playback.prepare(narration: page.narration, rate: settings.speechRate);
    await _narrator.stop();
    if (!mounted || request != _request || _backgrounded) return;
    _stopping = false;
    _narrationPending = false;
    _narrationStarted = true;
    // Real narration also starts this clock through its speaking signal. An
    // animated scene can play with finite timing when device TTS is absent.
    if (page.animation != null) _playback.play();
    await _narrator.speak(page.narration, rate: settings.speechRate);
  }

  void _autoNarrate() {
    if (mounted && !_backgrounded && AppScope.read(context).settings.autoRead) {
      _narrate();
    }
  }

  Future<void> _pause() async {
    final hadActivity =
        _narrationPending || _playback.isPlaying || _narrator.isSpeaking.value;
    // Invalidate even a pending stop/navigation operation, so it cannot start
    // reading behind the settings sheet or after the app enters background.
    final request = ++_request;
    _narrationPending = false;
    if (!hadActivity) return;
    _stopping = true;
    _playback.setSpeechActive(false);
    _playback.pause();
    if (_narrator is ResumableNarrator) {
      await (_narrator as ResumableNarrator).pause();
    } else {
      await _narrator.stop();
    }
    if (mounted && request == _request) _stopping = false;
  }

  Future<void> _resume() async {
    if (!_playback.isPaused || _backgrounded) return;
    if (!_narrationStarted) return _narrate();
    ++_request;
    _stopping = false;
    final narration = _pages[_index].narration;
    var offset = (_playback.narrationProgress * narration.length).floor();
    while (offset > 0 &&
        offset < narration.length &&
        narration[offset - 1] != ' ') {
      offset--;
    }
    _playback.updateRate(AppScope.read(context).settings.speechRate);
    _playback.resume();
    if (_narrator is ResumableNarrator) {
      await (_narrator as ResumableNarrator).resume(
          fallbackOffset: offset,
          rate: AppScope.read(context).settings.speechRate);
    } else {
      await _narrator.speak(narration.substring(offset),
          rate: AppScope.read(context).settings.speechRate);
    }
  }

  void _toggleNarration() {
    if (_playback.isPaused) {
      _resume();
    } else if (_playback.isPlaying || _narrator.isSpeaking.value) {
      _pause();
    } else {
      _narrate();
    }
  }

  Future<int> _stopScene() async {
    final request = ++_request;
    _narrationPending = false;
    _narrationStarted = false;
    _stopping = true;
    _speechWasActive = false;
    _playback.setSpeechActive(false);
    _playback.stop();
    await _narrator.stop();
    if (mounted && request == _request) _stopping = false;
    return request;
  }

  Future<void> _onPageChanged(int index) async {
    setState(() => _index = index);
    final request = await _stopScene();
    if (mounted && request == _request && _index == index) _autoNarrate();
  }

  Future<void> _goTo(int index) async {
    if (index == _index) return;
    // Stop immediately; narration must not continue during a page transition.
    final request = await _stopScene();
    if (!mounted || request != _request) return;
    final reducedMotion = AppScope.read(context).settings.reducedMotion ||
        MediaQuery.of(context).disableAnimations;
    if ((index - _index).abs() > 1 || reducedMotion) {
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
    final request = await _stopScene();
    if (!mounted || request != _request) return;
    if (widget.story.questions.isNotEmpty) {
      final finished =
          await Navigator.of(context).push(QuizScreen.route(widget.story));
      if (finished != true || !mounted) return;
    }
    final action = await CompletionDialog.show(context,
        storyTitle: widget.story.displayTitle);
    if (!mounted) return;
    switch (action) {
      case CompletionAction.readAgain:
        if (_index == 0) {
          _narrate();
        } else {
          _pageController.jumpToPage(0);
        }
      case CompletionAction.done:
        Navigator.of(context).pop();
      case null:
        break;
    }
  }

  Future<void> _showSettings() async {
    await _pause();
    if (mounted) await SettingsSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final compactHeight = MediaQuery.sizeOf(context).height < 500;
    final reducedMotion =
        settings.reducedMotion || MediaQuery.of(context).disableAnimations;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppDimens.maxStoryWidth),
            child: Padding(
              padding: EdgeInsets.all(
                  compactHeight ? AppDimens.gapS : AppDimens.screenPadding),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(AppDimens.gapM,
                    AppDimens.gapS, AppDimens.gapM, AppDimens.gapL),
                child: Column(
                  children: [
                    ScreenHeader(
                      title: widget.story.displayTitle,
                      subtitle: InfoPill(
                          label: '${_index + 1} of ${_pages.length}',
                          semanticsLabel:
                              'Page ${_index + 1} of ${_pages.length}'),
                      leading: RoundIconButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Back to stories',
                          onPressed: () => Navigator.of(context).maybePop()),
                      trailing: RoundIconButton(
                          icon: Icons.settings_rounded,
                          tooltip: 'Settings',
                          onPressed: _showSettings),
                    ),
                    SizedBox(
                        height:
                            compactHeight ? AppDimens.gapXS : AppDimens.gapM),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _pages.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.gapXS),
                          child: StoryPageView(
                            page: _pages[index],
                            playback: index == _index ? _playback : null,
                            reducedMotion: reducedMotion,
                            isSpeaking: _narrator.isSpeaking,
                            onSpeakerPressed: _toggleNarration,
                            largeText: settings.largeText,
                          ),
                        ),
                      ),
                    ),
                    if (!compactHeight) ...[
                      const SizedBox(height: AppDimens.gapL),
                      ThumbnailStrip(
                          frames: [for (final page in _pages) page.frame],
                          selectedIndex: _index,
                          onSelected: _goTo),
                      const SizedBox(height: AppDimens.gapL),
                    ] else
                      const SizedBox(height: AppDimens.gapS),
                    AnimatedBuilder(
                      animation: _playback,
                      builder: (context, _) => StoryControls(
                        pageCount: _pages.length,
                        currentIndex: _index,
                        onListenAgain: _narrate,
                        onNext: _next,
                        onTogglePlayback: _toggleNarration,
                        isPlaying: _playback.isPlaying,
                        isPaused: _playback.isPaused,
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
