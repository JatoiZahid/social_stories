import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/narration/narrator.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/page_dots.dart';
import '../../shared/widgets/pill_button.dart';
import '../../shared/widgets/round_icon_button.dart';
import '../../shared/widgets/speaker_badge.dart';
import 'tyre_art.dart';
import 'tyre_game.dart';
import 'tyre_sound.dart';

class TyreGarageScreen extends StatefulWidget {
  const TyreGarageScreen(
      {super.key,
      required this.narrator,
      required this.settings,
      this.game,
      this.assetLoader,
      this.ownsNarrator = false});
  final Future<TyreAssets> Function()? assetLoader;
  final bool ownsNarrator;
  final Narrator narrator;
  final AppSettings settings;
  final TyreGame? game;
  @override
  State<TyreGarageScreen> createState() => _TyreGarageScreenState();
}

class _TyreGarageScreenState extends State<TyreGarageScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final TyreGame game = widget.game ?? TyreGame();
  final sounds = TyreSound();
  TyreAssets? assets;
  Object? assetError;
  late final AnimationController clock,
      lift,
      snap,
      camera,
      nutFlight,
      departure;
  bool sound = true, hint = false, resetting = false;
  int dragging = 0;
  Offset? dragPointer;
  bool departing = false, toolboxOpen = true, mistake = false;
  Timer? feedbackTimer;
  final returns = <OverlayEntry>{};
  int spokenStep = -1, soundRevision = -1, level = 0;
  bool get reduced =>
      widget.settings.reducedMotion || MediaQuery.disableAnimationsOf(context);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    clock =
        AnimationController(vsync: this, duration: const Duration(seconds: 42))
          ..repeat();
    lift = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950))
      ..addStatusListener(_liftStatus);
    snap = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed &&
            game.step == TyreStep.fit &&
            game.busy &&
            !resetting) {
          game.finishMotion();
        }
      });
    camera = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    nutFlight = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 560))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !resetting) {
          game.finishNutMotion();
        }
      });
    departure = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    lift.value = game.liftFraction;
    snap.value = game.snapFraction;
    nutFlight.value = game.nutFraction;
    camera.value =
        game.step == TyreStep.inspect || game.step == TyreStep.done ? 0 : 1;
    game.addListener(_changed);
    widget.settings.addListener(_changed);
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await (widget.assetLoader ?? TyreAssets.load)();
      if (!mounted) {
        value.dispose();
        return;
      }
      setState(() => assets = value);
      _changed();
    } catch (error) {
      debugPrint('Tyre workshop artwork could not load: $error');
      if (mounted) setState(() => assetError = error);
    }
  }

  void _liftStatus(AnimationStatus status) {
    if (resetting || !game.busy || game.paused) return;
    if (status == AnimationStatus.completed && game.step == TyreStep.jack ||
        status == AnimationStatus.dismissed && game.step == TyreStep.lower) {
      game.finishMotion();
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (game.paused) {
      clock.stop();
      lift.stop();
      snap.stop();
      camera.stop();
      nutFlight.stop();
      departure.stop();
      return;
    }
    if (assets == null || resetting) return;
    if (reduced) clock.stop();
    if (!clock.isAnimating && !reduced) clock.repeat();
    if (departing && !departure.isAnimating && departure.value < 1) {
      departure.animateTo(1,
          duration: Duration(milliseconds: reduced ? 1 : 2600),
          curve: Curves.easeInCubic);
    }
    final focus =
        game.step != TyreStep.inspect && game.step != TyreStep.done ? 1.0 : 0.0;
    if (camera.value != focus && !camera.isAnimating) {
      camera.animateTo(focus,
          duration: Duration(milliseconds: reduced ? 1 : 650),
          curve: Curves.easeInOutCubic);
    }
    if (game.settlingNut && !nutFlight.isAnimating) {
      if (nutFlight.value == 1) {
        game.finishNutMotion();
        return;
      }
      nutFlight.animateTo(1,
          duration: Duration(milliseconds: reduced ? 1 : 560));
    } else if (!game.settlingNut) {
      nutFlight.value = 0;
    }
    final newStep = spokenStep != game.step.index;
    if (newStep) {
      toolboxOpen = true;
      mistake = false;
      spokenStep = game.step.index;
      if (widget.settings.autoRead) {
        _say(game.step == TyreStep.jack
            ? 'Oh no! My tyre is flat! $_prompt'
            : _prompt);
      }
    }
    if (soundRevision != game.cueRevision) {
      soundRevision = game.cueRevision;
      if (game.feedback == 'Find the matching picture. Take your time.') {
        mistake = true;
        feedbackTimer?.cancel();
        feedbackTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => mistake = false);
        });
      }
      if (sound && game.cue.isNotEmpty) sounds.play(game.cue);
      if (!newStep && widget.settings.autoRead && game.feedback.isNotEmpty) {
        _say(game.feedback);
      }
    }
    if (game.busy) {
      if ((game.step == TyreStep.jack && lift.value == 1) ||
          (game.step == TyreStep.fit && snap.value == 1) ||
          (game.step == TyreStep.lower && lift.value == 0)) {
        game.finishMotion();
        return;
      }
      if (game.step == TyreStep.jack && !lift.isAnimating) {
        lift.animateTo(1,
            duration: reduced
                ? const Duration(milliseconds: 1)
                : const Duration(milliseconds: 950),
            curve: Curves.easeInOutCubic);
      }
      if (game.step == TyreStep.fit && !snap.isAnimating) {
        snap.animateTo(1,
            duration: reduced
                ? const Duration(milliseconds: 1)
                : const Duration(milliseconds: 480));
      }
      if (game.step == TyreStep.lower && !lift.isAnimating) {
        lift.animateBack(0,
            duration: reduced
                ? const Duration(milliseconds: 1)
                : const Duration(milliseconds: 1100),
            curve: Curves.easeInOutCubic);
      }
    }
  }

  void _say(String text) {
    if (sound && !game.paused) {
      widget.narrator.speak(text, rate: widget.settings.speechRate);
    }
  }

  void _pause(bool value) {
    if (value) {
      clock.stop();
      lift.stop();
      snap.stop();
      camera.stop();
      nutFlight.stop();
      departure.stop();
      widget.narrator.stop();
      sounds.stop();
    }
    game.pause(value);
    if (!value && !reduced) clock.repeat();
  }

  void _reset() {
    resetting = true;
    feedbackTimer?.cancel();
    mistake = false;
    toolboxOpen = true;
    lift.stop();
    snap.stop();
    lift.value = 0;
    snap.value = 0;
    camera.value = 0;
    nutFlight.value = 0;
    departing = false;
    departure.value = 0;
    widget.narrator.stop();
    sounds.stop();
    game.reset();
    spokenStep = -1;
    resetting = false;
    if (!clock.isAnimating) clock.repeat();
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause(true);
  }

  @override
  void dispose() {
    feedbackTimer?.cancel();
    for (final entry in returns) {
      entry.remove();
      entry.dispose();
    }
    returns.clear();
    WidgetsBinding.instance.removeObserver(this);
    game.removeListener(_changed);
    game.liftFraction = lift.value;
    game.snapFraction = snap.value;
    game.nutFraction = nutFlight.value;
    if (widget.game != null) game.pause(true);
    widget.settings.removeListener(_changed);
    clock.dispose();
    lift.dispose();
    snap.dispose();
    camera.dispose();
    nutFlight.dispose();
    departure.dispose();
    assets?.dispose();
    widget.narrator.stop();
    sounds.stop();
    if (widget.ownsNarrator) widget.narrator.dispose();
    if (widget.game == null) game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(children: [
              RoundIconButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context)),
              Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Fix My Broken Car',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Semantics(
                    label: 'Repair step ${game.step.index + 1} of 8',
                    child: PageDots(count: 8, index: game.step.index)),
              ])),
              RoundIconButton(
                  icon: game.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  tooltip: game.paused ? 'Resume' : 'Pause',
                  onPressed: () => _pause(!game.paused)),
              RoundIconButton(
                  icon: Icons.settings_rounded,
                  tooltip: 'Settings',
                  onPressed: _settings),
            ])),
        Expanded(
            child: assets == null
                ? Center(
                    child: assetError == null
                        ? const CircularProgressIndicator()
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('The workshop could not load.'),
                            _button('Try again', _load)
                          ]))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _scene())),
        // Communication is visually separate from game manipulation and never required.
        if (assets != null) _aac(),
      ])));

  Widget _button(String label, VoidCallback? action, {bool soft = false}) =>
      PillButton(
          label: label,
          onPressed: action,
          variant: soft ? PillButtonVariant.soft : PillButtonVariant.primary);

  String get _prompt => game.paused
      ? 'Take your time. Ready when you are.'
      : mistake
          ? 'Find the matching picture. You can try again!'
          : game.settlingNut
              ? game.feedback
              : switch (game.step) {
                  TyreStep.inspect => 'Oh no! My tyre is flat!',
                  TyreStep.jack =>
                    game.busy ? 'Up we go!' : 'Slide the jack under me.',
                  TyreStep.loosen || TyreStep.tighten => game.attached
                      ? (game.step == TyreStep.loosen
                          ? 'Turn left. Follow the arrow!'
                          : 'Turn right. Nice and snug!')
                      : 'Pick up the wrench. Choose a nut.',
                  TyreStep.remove => 'Slide my old wheel into the tray.',
                  TyreStep.fit => game.busy
                      ? 'A perfect fit!'
                      : 'Find my matching new wheel.',
                  TyreStep.lower => game.busy
                      ? 'Gently back down.'
                      : 'Touch the blue jack to lower me.',
                  TyreStep.done => 'I feel great! You fixed my wheel!',
                };

  Widget _bubble(bool compact) => Align(
      alignment: Alignment.topLeft,
      child: Container(
          margin: const EdgeInsets.all(10),
          constraints: BoxConstraints(
              maxWidth: math.min(
                  compact ? 310 : 430, MediaQuery.sizeOf(context).width - 90)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withAlpha(245),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                  bottomLeft: Radius.circular(5)),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 16,
                    offset: Offset(0, 5))
              ]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!compact)
              SpeakerBadge(
                  isSpeaking: widget.narrator.isSpeaking,
                  onPressed: () => _say(_prompt)),
            if (!compact) const SizedBox(width: 10),
            Flexible(
                child: Semantics(
                    liveRegion: true,
                    child: Text(_prompt,
                        style: TextStyle(
                            fontSize:
                                widget.settings.largeText && !compact ? 20 : 16,
                            fontWeight: FontWeight.w800,
                            height: 1.2)))),
          ])));

  Widget _scene() => ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AnimatedBuilder(
          animation:
              Listenable.merge([lift, snap, camera, nutFlight, departure]),
          builder: (context, _) => LayoutBuilder(builder: (context, box) {
                final view = GarageCamera(box.biggest, camera.value);
                final scale = view.scale;
                final compact = box.maxHeight < 330;
                Widget at(String key, Offset point, double width, double height,
                    Widget child) {
                  final p = view.project(point);
                  final w = math.max(56.0, width * scale),
                      h = math.max(56.0, height * scale);
                  return Positioned(
                      key: ValueKey(key),
                      left: p.dx - w / 2,
                      top: p.dy - h / 2,
                      width: w,
                      height: h,
                      child: child);
                }

                final hub = TyreGeometry.hub(lift.value);
                return Stack(fit: StackFit.expand, children: [
                  RepaintBoundary(
                      key: const ValueKey('tyre-art'),
                      child: AnimatedBuilder(
                          animation: clock,
                          builder: (context, _) => CustomPaint(
                              painter: TyrePainter(
                                  assets: assets!,
                                  game: game,
                                  lift: lift.value,
                                  snap: snap.value,
                                  time: clock.value * 42,
                                  reduced: reduced,
                                  camera: view,
                                  nutFlight: nutFlight.value,
                                  departure: departure.value,
                                  hint: hint)))),
                  if (game.step == TyreStep.inspect)
                    at('inspect-zone', hub, 210, 190,
                        _halo('Inspect damaged tyre', game.inspect)),
                  if (game.step == TyreStep.jack && !game.busy)
                    at('jack-zone', TyreGeometry.jack, 190, 130,
                        _target('jack', 'Place jack under car')),
                  if ((game.step == TyreStep.loosen ||
                          game.step == TyreStep.tighten) &&
                      !game.busy)
                    if (game.attached)
                      at(
                          'rotation-zone',
                          TyreGeometry.nut(game.nut, lift.value),
                          300,
                          300,
                          _NutRotation(game: game))
                    else
                      at('nuts-area', hub, 230, 230, _nuts(scale)),
                  if (game.step == TyreStep.remove) ...[
                    at(
                        'old-wheel',
                        hub,
                        196,
                        178,
                        _drag(
                            TyreTool.damaged,
                            IllustratedTool(
                                assets: assets!, index: 1, size: 110))),
                    at('old-tray', TyreGeometry.oldTray, 150, 150,
                        _target('tray', 'Old wheel tray')),
                  ],
                  if (game.step == TyreStep.fit && !game.busy)
                    at('hub-zone', hub, 200, 200,
                        _target('hub', 'Place new tyre on hub')),
                  if (game.step == TyreStep.lower && !game.busy)
                    at('release-zone', TyreGeometry.jack, 190, 130,
                        _halo('Release toy jack', game.lower)),
                  if (hint && game.canAct)
                    at(
                        'hint-hand',
                        switch (game.step) {
                              TyreStep.jack ||
                              TyreStep.lower =>
                                TyreGeometry.jack,
                              TyreStep.loosen ||
                              TyreStep.tighten =>
                                TyreGeometry.nut(game.nut, lift.value),
                              TyreStep.remove => TyreGeometry.oldTray,
                              _ => hub,
                            } +
                            const Offset(42, 42),
                        90,
                        90,
                        IgnorePointer(
                            child: AnimatedBuilder(
                                animation: clock,
                                builder: (context, child) =>
                                    Transform.translate(
                                        offset: Offset(
                                            0,
                                            reduced
                                                ? 0
                                                : math.sin(
                                                        clock.value * 42 * 5) *
                                                    12),
                                        child: const Icon(
                                            Icons.touch_app_rounded,
                                            size: 46,
                                            color: AppColors.celebrate))))),
                  _bubble(compact),
                  Positioned(
                      right: 8,
                      top: compact ? 45 : 10,
                      child: Material(
                          color: Colors.white.withAlpha(235),
                          borderRadius: BorderRadius.circular(24),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (compact)
                              IconButton(
                                  tooltip: 'Read aloud',
                                  onPressed: () => _say(_prompt),
                                  icon: const Icon(Icons.volume_up_rounded)),
                            IconButton(
                                tooltip: 'Show me',
                                onPressed: () {
                                  setState(() => hint = !hint);
                                  _say(_prompt);
                                },
                                icon: Icon(Icons.touch_app_rounded,
                                    color: hint
                                        ? AppColors.primary
                                        : AppColors.inkSoft)),
                          ]))),
                  Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Center(
                          child: game.step == TyreStep.done
                              ? Wrap(spacing: 8, children: [
                                  if (!departing)
                                    _button('Drive out', () {
                                      if (game.paused) return;
                                      setState(() => departing = true);
                                      _say('I fixed the car! Off we go!');
                                      _changed();
                                    }),
                                  _button('Play again', _reset, soft: true),
                                ])
                              : _tray(compact))),
                  if (game.paused)
                    ColoredBox(
                        color: Colors.white.withAlpha(200),
                        child: Center(
                            child: _button('Resume', () => _pause(false)))),
                ]);
              })));

  Widget _nuts(double scale) => LayoutBuilder(builder: (context, box) {
        Offset position(int i) =>
            box.biggest.center(Offset.zero) + TyreGeometry.nuts[i] * scale;
        int? nearest(Offset global) {
          final render = context.findRenderObject() as RenderBox;
          final local = render.globalToLocal(global);
          final available = List.generate(3, (i) => i)
              .where((i) => !game.completedNuts.contains(i))
              .toList()
            ..sort((a, b) => (position(a) - local)
                .distance
                .compareTo((position(b) - local).distance));
          return available.isEmpty ? null : available.first;
        }

        return DragTarget<TyreTool>(
            onWillAcceptWithDetails: (d) =>
                game.canAct && d.data == TyreTool.wrench,
            onAcceptWithDetails: (d) {
              final index = nearest(dragPointer ?? d.offset);
              if (index != null) game.drop(d.data, 'nut$index');
            },
            builder: (context, candidates, rejected) => Stack(children: [
                  if (candidates.isNotEmpty)
                    Center(
                        child: Container(
                            width: box.maxWidth,
                            height: box.maxHeight,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withAlpha(28)))),
                  for (var i = 0; i < 3; i++)
                    if (!game.completedNuts.contains(i))
                      Positioned(
                        left: position(i).dx - 24,
                        top: position(i).dy - 24,
                        width: 48,
                        height: 48,
                        child: Semantics(
                            container: true,
                            button: true,
                            label: 'Place wrench on nut ${i + 1}',
                            onTap: () {
                              game.chooseNut(i);
                              if (game.selected == TyreTool.wrench) {
                                game.drop(TyreTool.wrench, 'nut$i');
                              }
                            },
                            child: GestureDetector(
                                key: ValueKey('target-nut$i'),
                                onTapUp: (d) {
                                  final index = nearest(d.globalPosition);
                                  if (index == null) return;
                                  game.chooseNut(index);
                                  if (game.selected == TyreTool.wrench) {
                                    game.drop(TyreTool.wrench, 'nut$index');
                                  }
                                },
                                child: Center(
                                    child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        width: i == game.nut ? 31 : 23,
                                        height: i == game.nut ? 31 : 23,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                width: i == game.nut ? 3 : 1.5,
                                                color: AppColors.celebrate),
                                            color: i == game.nut
                                                ? AppColors.celebrate
                                                    .withAlpha(35)
                                                : Colors.transparent))))),
                      ),
                ]));
      });

  Widget _halo(String label, VoidCallback action) => Semantics(
      label: label,
      button: true,
      child: InkWell(
          onTap: game.canAct ? action : null,
          customBorder: const CircleBorder(),
          child: Container(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.celebrate.withAlpha(210), width: 3)),
              child: const Align(
                  alignment: Alignment.topRight,
                  child: Icon(Icons.touch_app_rounded,
                      color: AppColors.celebrate, size: 26)))));
  Widget _target(String target, String label, {int? illustration}) =>
      DragTarget<TyreTool>(
          key: ValueKey('target-$target'),
          onWillAcceptWithDetails: (_) => game.canAct,
          onAcceptWithDetails: (d) => game.drop(d.data, target),
          builder: (context, candidates, _) {
            final valid = candidates.isNotEmpty &&
                game.accepts(candidates.first!, target);
            return Semantics(
                label: label,
                button: true,
                child: InkWell(
                    onTap: game.selected == null
                        ? null
                        : () => game.drop(game.selected!, target),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                        decoration: BoxDecoration(
                            color: (valid ? Colors.green : AppColors.primary)
                                .withAlpha(valid ? 55 : 15),
                            border: Border.all(
                                color:
                                    valid ? Colors.green : AppColors.celebrate,
                                width: 3),
                            borderRadius: BorderRadius.circular(30)),
                        child: illustration == null
                            ? const SizedBox.expand()
                            : Opacity(
                                opacity: .65,
                                child: IllustratedTool(
                                    assets: assets!, index: illustration)))));
          });
  Widget _drag(TyreTool tool, Widget child) =>
      LayoutBuilder(builder: (context, box) {
        final enabled = game.canAct && game.toolAvailable(tool);
        return Draggable<TyreTool>(
            key: ValueKey('drag-${tool.name}'),
            data: tool,
            maxSimultaneousDrags: enabled && dragging == 0 ? 1 : 0,
            onDragUpdate: (d) => dragPointer = d.globalPosition,
            onDragStarted: () {
              dragPointer = null;
              game.select(tool);
              setState(() => dragging++);
            },
            onDragEnd: (_) {
              if (mounted) setState(() => dragging = 0);
            },
            onDraggableCanceled: (_, offset) {
              if (!mounted) return;
              final render = context.findRenderObject() as RenderBox;
              final end = render.localToGlobal(Offset.zero);
              late OverlayEntry entry;
              entry = OverlayEntry(
                  builder: (_) => TweenAnimationBuilder<Offset>(
                      tween: Tween(begin: offset, end: end),
                      duration: Duration(milliseconds: reduced ? 1 : 320),
                      curve: Curves.easeOutCubic,
                      onEnd: () {
                        if (returns.remove(entry)) {
                          entry.remove();
                          entry.dispose();
                        }
                      },
                      builder: (context, p, child) => Positioned(
                          left: p.dx,
                          top: p.dy,
                          width: box.maxWidth,
                          height: box.maxHeight,
                          child: IgnorePointer(
                              child: Material(
                                  color: Colors.transparent, child: child)))));
              returns.add(entry);
              Overlay.of(context).insert(entry);
            },
            feedback: Material(
                color: Colors.transparent,
                child: Transform.rotate(
                    angle: -.09,
                    child: Container(
                        width: math.max(90, box.maxWidth),
                        height: math.max(90, box.maxHeight),
                        decoration: const BoxDecoration(boxShadow: [
                          BoxShadow(
                              color: Color(0x3322304A),
                              blurRadius: 20,
                              offset: Offset(0, 12))
                        ]),
                        child: child))),
            childWhenDragging: Opacity(opacity: .15, child: child),
            child: Semantics(
                label: 'Select ${tool.name}',
                button: true,
                enabled: enabled,
                child: InkWell(
                    onTap: enabled ? () => game.select(tool) : null,
                    borderRadius: BorderRadius.circular(20),
                    child: child)));
      });

  Widget _tray(bool compact) {
    final tools = [
      (TyreTool.jack, 2, 'Toy jack'),
      (TyreTool.wrench, 4, 'Wrench'),
      (TyreTool.spare, 0, 'New tyre'),
      (TyreTool.small, 7, 'Small tyre')
    ].where((p) => game.toolAvailable(p.$1)).toList();
    if (tools.isEmpty) return const SizedBox(height: 1);
    final size = compact
        ? 56.0
        : MediaQuery.sizeOf(context).width > 700
            ? 94.0
            : 76.0;
    return Material(
        color: Colors.white.withAlpha(244),
        elevation: 8,
        shadowColor: AppColors.shadow,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Semantics(
                      button: true,
                      label: toolboxOpen ? 'Close toolbox' : 'Open toolbox',
                      child: InkWell(
                          onTap: () {
                            setState(() => toolboxOpen = !toolboxOpen);
                            if (sound) sounds.play('soft');
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: IllustratedTool(
                                  assets: assets!,
                                  index: 6,
                                  size: compact ? 48 : 68)))),
                  if (toolboxOpen)
                    for (final p in tools)
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                              width: size + 16,
                              height: size + (compact ? 8 : 22),
                              child: _drag(
                                  p.$1,
                                  AnimatedContainer(
                                      duration: Duration(
                                          milliseconds: reduced ? 0 : 180),
                                      transform: Matrix4.translationValues(
                                          0, game.selected == p.$1 ? -8 : 0, 0),
                                      decoration: BoxDecoration(
                                          color: game.selected == p.$1
                                              ? AppColors.tint
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                              color: game.selected == p.$1
                                                  ? AppColors.primary
                                                  : AppColors.border,
                                              width: 2)),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IllustratedTool(
                                                assets: assets!,
                                                index: p.$2,
                                                size: size),
                                            if (!compact)
                                              Text(p.$3,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                          ]))))),
                ])));
  }

  Widget _aac() {
    const phrases = [
      ['Wheel', 'Help', 'Turn', 'Done'],
      ['Fix wheel', 'Help car', 'Turn it', 'All done'],
      [
        'Please help me fix the wheel.',
        'I can turn the wrench.',
        'I repaired the car.'
      ]
    ];
    return Semantics(
        container: true,
        label: 'Communication pictures',
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(children: [
              for (var i = 0; i < phrases[level].length; i++)
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: OutlinedButton(
                            onPressed: game.paused
                                ? null
                                : () => _say(phrases[level][i]),
                            style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 5),
                                minimumSize: const Size(48, 52),
                                side:
                                    const BorderSide(color: AppColors.border)),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      [
                                        Icons.tire_repair_rounded,
                                        Icons.front_hand_rounded,
                                        Icons.rotate_right_rounded,
                                        Icons.check_circle_outline_rounded
                                      ][i],
                                      size: 20),
                                  Text(phrases[level][i],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13)),
                                ])))),
            ])));
  }

  Future<void> _settings() async {
    _pause(true);
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => SafeArea(
                child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Settings',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          SwitchListTile(
                              title: const Text('Audio'),
                              value: sound,
                              onChanged: (v) => update(() => sound = v)),
                          SwitchListTile(
                              title: const Text('Reduced motion'),
                              value: widget.settings.reducedMotion,
                              onChanged: (v) => update(
                                  () => widget.settings.reducedMotion = v)),
                          SwitchListTile(
                              title: const Text('Large text'),
                              value: widget.settings.largeText,
                              onChanged: (v) =>
                                  update(() => widget.settings.largeText = v)),
                          DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: level,
                              decoration: const InputDecoration(
                                  labelText: 'Communication'),
                              items: const [
                                DropdownMenuItem(
                                    value: 0, child: Text('Single words')),
                                DropdownMenuItem(
                                    value: 1, child: Text('Short phrases')),
                                DropdownMenuItem(
                                    value: 2, child: Text('Sentences'))
                              ],
                              onChanged: (v) {
                                if (v != null) update(() => level = v);
                              }),
                          const SizedBox(height: 16),
                          _button('Start again', () {
                            Navigator.pop(context);
                            _reset();
                          }),
                          const SizedBox(height: 12),
                          _button(
                              'Back to garage', () => Navigator.pop(context)),
                        ]))))));
    if (mounted) setState(() {});
  }
}

class _NutRotation extends StatefulWidget {
  const _NutRotation({required this.game});
  final TyreGame game;
  @override
  State<_NutRotation> createState() => _NutRotationState();
}

class _NutRotationState extends State<_NutRotation> {
  Offset? previous;
  int? pointer;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final center = Offset(box.maxWidth / 2, box.maxHeight / 2);
        void update(PointerMoveEvent event) {
          if (pointer != event.pointer) return;
          final now = event.localPosition - center;
          final before = previous;
          previous = now;
          if (before == null || before.distance < 16 || now.distance < 16) {
            return;
          }
          var delta = now.direction - before.direction;
          if (delta > math.pi) delta -= 2 * math.pi;
          if (delta < -math.pi) delta += 2 * math.pi;
          widget.game.rotate(delta);
        }

        return Semantics(
            container: true,
            button: true,
            label: 'Rotate attached wrench',
            onTap: widget.game.canAct ? widget.game.assistedTurn : null,
            child: Listener(
                key: const ValueKey('rotate-nut'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (pointer == null) {
                    pointer = event.pointer;
                    previous = event.localPosition - center;
                  }
                },
                onPointerMove: update,
                onPointerUp: (event) {
                  if (event.pointer == pointer) {
                    pointer = null;
                    previous = null;
                  }
                },
                onPointerCancel: (event) {
                  pointer = null;
                  previous = null;
                },
                child: Stack(alignment: Alignment.center, children: [
                  IgnorePointer(
                      child: CustomPaint(
                          size: box.biggest,
                          painter: _TurnGuide(widget.game.turn,
                              widget.game.step == TyreStep.loosen))),
                  Align(
                      alignment: Alignment.bottomCenter,
                      child: IconButton(
                          tooltip: widget.game.step == TyreStep.loosen
                              ? 'Turn left'
                              : 'Turn right',
                          onPressed: widget.game.canAct
                              ? widget.game.assistedTurn
                              : null,
                          icon: const Icon(Icons.touch_app_rounded,
                              color: AppColors.primary))),
                ])));
      });
}

class _TurnGuide extends CustomPainter {
  _TurnGuide(this.progress, this.left);
  final double progress;
  final bool left;
  @override
  void paint(Canvas c, Size s) {
    final rect = Rect.fromCenter(
        center: s.center(Offset.zero),
        width: s.width * .86,
        height: s.height * .86);
    c.drawArc(
        rect,
        -.3,
        left ? -1.8 : 1.8,
        false,
        Paint()
          ..color = Colors.white.withAlpha(210)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round);
    c.drawArc(
        rect,
        -.3,
        (left ? -1 : 1) * math.max(.08, progress * 1.8),
        false,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round);
    final a = -.3 + (left ? -1.8 : 1.8);
    final p = rect.center +
        Offset(math.cos(a) * rect.width / 2, math.sin(a) * rect.height / 2);
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(a + (left ? -math.pi / 2 : math.pi / 2));
    c.drawPath(
        Path()
          ..moveTo(-10, -8)
          ..lineTo(4, 0)
          ..lineTo(-10, 8),
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
    c.restore();
  }

  @override
  bool shouldRepaint(_TurnGuide old) =>
      old.progress != progress || old.left != left;

  @override
  bool shouldRebuildSemantics(_TurnGuide old) => false;
}
