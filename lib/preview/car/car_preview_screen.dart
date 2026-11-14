import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../core/narration/narrator.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/narration_card.dart';
import '../../shared/widgets/pill_button.dart';
import '../../shared/widgets/round_icon_button.dart';
import '../../shared/widgets/screen_header.dart';
import 'garage_art.dart';
import 'garage_interactions.dart';
import 'repair_game.dart';

class CarPreviewScreen extends StatefulWidget {
  const CarPreviewScreen(
      {super.key, required this.narrator, required this.settings, this.game});
  final Narrator narrator;
  final AppSettings settings;
  final RepairGame? game;
  @override
  State<CarPreviewScreen> createState() => _CarPreviewScreenState();
}

class _CarPreviewScreenState extends State<CarPreviewScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final RepairGame game = widget.game ?? RepairGame();
  late final AnimationController clock;
  double time = 0;
  double wrenchTurns = 0;
  double door = 1, spunWheel = 0;
  Offset? cleanPoint;
  ui.Image? bodyImage;
  ui.Image? roadImage;
  bool sound = true, hint = false, reduced = false;
  int speechLevel = 0;
  Duration previous = Duration.zero;
  static const titles = [
    'Hello, little car!',
    'Explore the garage',
    'A new wheel',
    'A missing engine part',
    'Turn the wrench',
    'A little toy power',
    'Ready, steady, go!',
    'You fixed the car!'
  ];
  static const leads = [
    'Fix My Broken Car',
    'Let’s look around together.',
    'Oh no! My wheel is broken!',
    'Something is missing under the bonnet.',
    'This bolt needs a little turn.',
    'Match the two toy power shapes.',
    'Let’s take a gentle test drive.',
    'All done. What a helpful friend!'
  ];

  String get instruction => switch (game.stage) {
        GarageStage.introduction =>
          'Five little repairs. Take your time, ask for help, and make our car smile.',
        GarageStage.explore =>
          'Swipe the muddy splashes off the car. Spin a wheel, open the toolbox, or try the garage door!',
        GarageStage.wheel => !game.inspected
            ? 'Tap the flat wheel to look closely.'
            : !game.toolbox
                ? 'Open the toolbox to find a matching spare.'
                : game.repaired
                    ? game.pumpStrokes == 3
                        ? 'The wheel is full of air. Ready to roll!'
                        : 'The wheel fits! Push the blue pump handle down three times to fill it with air.'
                    : 'Drag the large wheel to the blue wheel outline. Or select it, then tap the outline.',
        GarageStage.engine => !game.bonnet
            ? 'Open the bonnet. This is a pretend toy engine.'
            : game.repaired
                ? 'The yellow gear is in its place!'
                : 'Find the yellow gear and move it into the matching engine space.',
        GarageStage.wrench => !game.attached
            ? 'Move the wrench onto the blue bolt.'
            : game.turns < 3
                ? 'Drag around the glowing circle clockwise to turn the wrench. You can also tap Turn.'
                : 'Snug and secure. Great helping!',
        GarageStage.power => game.powered
            ? 'The headlights shine. Our car has power!'
            : 'Match the sun triangle and moon square. Then press Power.${game.difficulty == RepairDifficulty.advanced ? ' Place the sun first.' : ''}',
        GarageStage.drive => !game.started
            ? 'Press Start to wake the engine.'
            : game.distance >= .95
                ? 'We reached the blue garage marker. Press Stop!'
                : 'Press Go. Steer up and down to catch stars! Stop at the blue garage marker.',
        GarageStage.celebration =>
          'You matched, turned, and helped. The car is ready for a happy journey.',
      };

  @override
  void initState() {
    super.initState();
    _loadBody();
    _loadRoad();
    WidgetsBinding.instance.addObserver(this);
    game.addListener(_changed);
    widget.settings.addListener(_changed);
    clock = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_tick)
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _speak('${leads[game.stage.index]}. $instruction'));
  }

  Future<void> _loadBody() async {
    final data = await rootBundle
        .load('assets/images/story_scenes/car_preview_body.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: 1100);
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => bodyImage = frame.image);
  }

  Future<void> _loadRoad() async {
    final data = await rootBundle
        .load('assets/images/story_scenes/car_preview_road.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: 1400);
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => roadImage = frame.image);
  }

  void _tick() {
    final elapsed = clock.lastElapsedDuration ?? Duration.zero;
    final delta = (elapsed - previous).inMicroseconds / 1000000;
    previous = elapsed;
    if (game.paused) return;
    time += delta;
    wrenchTurns += (game.turns + game.wrenchArc / .9 - wrenchTurns) *
        (delta * 12).clamp(0, 1);
    door += ((game.doorOpen ? 1 : 0) - door) * (delta * 5).clamp(0, 1);
    spunWheel += (game.wheelSpin - spunWheel) * (delta * 5).clamp(0, 1);
    if (game.driving) game.advance(delta / 7);
    if (mounted && !reduced) setState(() {});
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _speak(String text) {
    if (sound && !game.paused) {
      widget.narrator.speak(text, rate: widget.settings.speechRate);
    }
  }

  void _pause(bool value) {
    game.pause(value);
    widget.narrator.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_changed);
    game.removeListener(_changed);
    if (widget.game == null) game.dispose();
    clock.dispose();
    bodyImage?.dispose();
    roadImage?.dispose();
    widget.narrator.stop();
    super.dispose();
  }

  void _next() {
    final before = game.stage;
    game.next();
    if (game.stage != before) {
      hint = false;
      _speak('${leads[game.stage.index]}. $instruction');
    }
  }

  @override
  Widget build(BuildContext context) {
    reduced = widget.settings.reducedMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ScreenHeader(
                      title: 'Fix My Broken Car',
                      subtitle: Text('PREVIEW 2 • ${game.stage.index + 1} of 8',
                          style: const TextStyle(
                              color: AppColors.inkSoft, fontSize: 12)),
                      leading: RoundIconButton(
                          icon: game.paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          tooltip: game.paused ? 'Resume' : 'Pause',
                          onPressed: () => _pause(!game.paused)),
                      trailing: RoundIconButton(
                          icon: Icons.tune_rounded,
                          tooltip: 'Preview preferences',
                          onPressed: _preferences)),
                  const SizedBox(height: 10),
                  _repairTrail(),
                  const SizedBox(height: 10),
                  LayoutBuilder(builder: (context, box) {
                    final wide = box.maxWidth >= 650;
                    final scene = _scene();
                    final narration = SizedBox(
                        height: wide
                            ? 300
                            : (widget.settings.largeText ? 230 : 190),
                        child: NarrationCard(
                            lead: leads[game.stage.index],
                            body: instruction,
                            isSpeaking: widget.narrator.isSpeaking,
                            onSpeakerPressed: () => _speak(
                                '${leads[game.stage.index]}. $instruction'),
                            largeText: widget.settings.largeText));
                    if (wide) {
                      return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: scene),
                            const SizedBox(width: 12),
                            Expanded(flex: 3, child: narration)
                          ]);
                    }
                    return Column(children: [
                      scene,
                      const SizedBox(height: 10),
                      narration
                    ]);
                  }),
                  const SizedBox(height: 10),
                  Text(titles[game.stage.index],
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  IgnorePointer(ignoring: game.paused, child: _actions()),
                  if (game.feedback.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(game.feedback,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.inkSoft)))),
                  if (game.paused)
                    const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Paused. Take all the time you need.',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  const Divider(height: 20),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _button('Help', () {
                          setState(() => hint = !hint);
                          _speak(instruction);
                        }, icon: Icons.lightbulb_outline_rounded, soft: true),
                        _button('Replay', () {
                          widget.narrator.stop();
                          game.replay(
                              all: game.stage == GarageStage.celebration);
                          hint = false;
                        }, icon: Icons.replay_rounded, soft: true),
                        if (game.stage != GarageStage.celebration)
                          _button(
                              game.stage == GarageStage.introduction
                                  ? 'Let’s play'
                                  : 'Next',
                              game.ready && !game.paused ? _next : null,
                              icon: Icons.arrow_forward_rounded),
                      ]),
                  const SizedBox(height: 12),
                  _communication(),
                ]),
              ))),
    ))));
  }

  Widget _button(String label, VoidCallback? action,
          {IconData? icon, bool soft = false}) =>
      Opacity(
          opacity: action == null ? .45 : 1,
          child: PillButton(
              label: label,
              onPressed: action,
              leadingIcon: icon,
              variant:
                  soft ? PillButtonVariant.soft : PillButtonVariant.primary));

  Widget _scene() => AspectRatio(
      aspectRatio: 1.5,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: LayoutBuilder(builder: (context, box) {
            // A shared 900x600 coordinate space keeps targets attached to the artwork.
            Widget at(double x, double y, Widget child,
                    {double width = 82, double height = 82}) =>
                Positioned(
                    left: (x - width / 2) / 900 * box.maxWidth,
                    top: (y - height / 2) / 600 * box.maxHeight,
                    width: width / 900 * box.maxWidth,
                    height: height / 600 * box.maxHeight,
                    child: child);
            final targetWidth = math.max(48 * 900 / box.maxWidth,
                game.difficulty == RepairDifficulty.easy ? 145.0 : 115.0);
            return Stack(fit: StackFit.expand, children: [
              if (game.stage != GarageStage.drive)
                Image.asset('assets/images/story_scenes/car_preview_garage.png',
                    fit: BoxFit.fill),
              RepaintBoundary(
                  key: const ValueKey('garage-art'),
                  child: CustomPaint(
                      painter: GaragePainter(
                          game: game,
                          time: time,
                          reduced: reduced,
                          bodyImage: bodyImage,
                          roadImage: roadImage,
                          door: reduced ? (game.doorOpen ? 1 : 0) : door,
                          spunWheel: reduced ? 0 : spunWheel,
                          wrenchTurns:
                              reduced ? game.turns.toDouble() : wrenchTurns))),
              if (game.stage == GarageStage.drive && game.started)
                at(
                    450 + (-60 + game.distance * 100),
                    370 + game.steering * 32,
                    Semantics(
                        label: 'Steer car up and down',
                        child: GestureDetector(
                          key: const ValueKey('steer-car'),
                          dragStartBehavior: DragStartBehavior.down,
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) => game.steer(
                              game.steering +
                                  details.delta.dy / box.maxHeight * 8),
                          onTap: () => _speak('Beep beep!'),
                          child: const SizedBox.expand(),
                        )),
                    width: 530,
                    height: 250),
              if (game.stage == GarageStage.wheel && !game.inspected)
                at(285, 445, _touch('Inspect flat wheel', game.inspect),
                    width: 160, height: 160),
              if (game.stage == GarageStage.wheel &&
                  game.inspected &&
                  game.toolbox &&
                  !game.repaired)
                at(285, 445, _target('wheel', RepairPart.wheel),
                    width: targetWidth, height: targetWidth),
              if (game.stage == GarageStage.engine && game.bonnet)
                at(
                    610,
                    350,
                    game.repaired
                        ? const PartPicture(RepairPart.gear)
                        : _target('engine', RepairPart.gear),
                    width: targetWidth,
                    height: targetWidth),
              if (game.stage == GarageStage.wrench)
                at(
                    455,
                    396,
                    game.attached && game.turns < 3
                        ? WrenchGesture(game: game)
                        : game.attached
                            ? const SizedBox.shrink()
                            : _target('bolt', RepairPart.wrench),
                    width: game.attached
                        ? math.max(targetWidth, 200)
                        : targetWidth,
                    height: game.attached
                        ? math.max(targetWidth, 200)
                        : targetWidth),
              if (game.stage == GarageStage.wheel &&
                  game.repaired &&
                  game.pumpStrokes < 3)
                at(788, 405, PumpStation(game: game), width: 165, height: 220),
              if (game.stage == GarageStage.power) ...[
                at(
                    340,
                    366,
                    game.sun
                        ? const PartPicture(RepairPart.sun)
                        : _target('sun', RepairPart.sun),
                    width: targetWidth,
                    height: targetWidth),
                at(
                    470,
                    366,
                    game.moon
                        ? const PartPicture(RepairPart.moon)
                        : _target('moon', RepairPart.moon),
                    width: targetWidth,
                    height: targetWidth),
              ],
              if (game.stage == GarageStage.explore) ...[
                at(450, 370, _paintwork(), width: 500, height: 190),
                at(
                    618,
                    445,
                    Semantics(
                        label: 'Spin front wheel',
                        button: true,
                        child: GestureDetector(
                            onTap: game.spinWheel,
                            onPanUpdate: (_) => game.spinWheel(),
                            child: const SizedBox.expand())),
                    width: 140,
                    height: 140),
              ],
              if (hint && !game.paused)
                Positioned(
                    left: 8,
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Colors.white.withAlpha(235),
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(instruction,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13))))),
              if (game.paused)
                ColoredBox(
                    color: Colors.white.withAlpha(110),
                    child: const Center(
                        child: Icon(Icons.pause_circle_filled_rounded,
                            size: 64, color: AppColors.primary))),
            ]);
          })));

  Widget _touch(String label, VoidCallback action) => Semantics(
      button: true,
      label: label,
      child: InkWell(
          onTap: game.paused ? null : action,
          borderRadius: BorderRadius.circular(40),
          child: DecoratedBox(
              decoration: BoxDecoration(
                  border: Border.all(color: AppColors.celebrate, width: 3),
                  borderRadius: BorderRadius.circular(40)),
              child: const Icon(Icons.touch_app_rounded,
                  color: AppColors.celebrate))));

  Widget _target(String name, RepairPart part) => DragTarget<RepairPart>(
      key: ValueKey('target-$name'),
      onWillAcceptWithDetails: (details) => !game.paused,
      onAcceptWithDetails: (details) => _drop(details.data, name),
      builder: (context, candidates, rejected) {
        final matching =
            candidates.isNotEmpty && game.accepts(candidates.first!, name);
        return Semantics(
            button: true,
            label: 'Place ${part.name} here',
            child: InkWell(
                onTap: () {
                  if (game.selected != null) _drop(game.selected!, name);
                },
                child: Container(
                    decoration: BoxDecoration(
                        color: (matching ? Colors.green : AppColors.primary)
                            .withAlpha(65),
                        border: Border.all(
                            color: matching ? Colors.green : AppColors.primary,
                            width: 3),
                        borderRadius: BorderRadius.circular(18)),
                    child: Opacity(
                        opacity: matching ? 1 : .5,
                        child: PartPicture(part)))));
      });

  Widget _repairTrail() {
    const labels = ['Wheel', 'Engine', 'Bolt', 'Power', 'Drive'];
    const icons = [
      Icons.tire_repair_rounded,
      Icons.settings_rounded,
      Icons.build_rounded,
      Icons.bolt_rounded,
      Icons.flag_rounded
    ];
    return Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < labels.length; i++)
            Semantics(
                label:
                    '${labels[i]} ${game.completedRepairs > i ? 'complete' : 'repair'}',
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: game.completedRepairs > i
                            ? const Color(0xFFE5F4E9)
                            : AppColors.tint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          game.completedRepairs > i
                              ? Icons.check_circle_rounded
                              : icons[i],
                          size: 16,
                          color: game.completedRepairs > i
                              ? const Color(0xFF348653)
                              : AppColors.primary),
                      const SizedBox(width: 4),
                      Text(labels[i],
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700))
                    ]))),
        ]);
  }

  Widget _paintwork() => LayoutBuilder(builder: (context, box) {
        Offset point(Offset local) => Offset(
            200 + local.dx / box.maxWidth * 500,
            275 + local.dy / box.maxHeight * 190);
        void update(DragUpdateDetails details) {
          final to = point(details.localPosition),
              from = cleanPoint ?? point(details.localPosition);
          final segment = to - from;
          for (var i = 0; i < GaragePainter.dirtSpots.length; i++) {
            final spot = GaragePainter.dirtSpots[i];
            final fraction = segment.distanceSquared == 0
                ? 0.0
                : (((spot - from).dx * segment.dx +
                            (spot - from).dy * segment.dy) /
                        segment.distanceSquared)
                    .clamp(0, 1)
                    .toDouble();
            if ((spot - (from + segment * fraction)).distance < 36) {
              game.clean(i);
            }
          }
          cleanPoint = to;
        }

        return Semantics(
            label: 'Wipe muddy paintwork',
            child: GestureDetector(
              key: const ValueKey('clean-paintwork'),
              dragStartBehavior: DragStartBehavior.down,
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) =>
                  cleanPoint = point(details.localPosition),
              onVerticalDragStart: (details) =>
                  cleanPoint = point(details.localPosition),
              onHorizontalDragUpdate: update,
              onVerticalDragUpdate: update,
              onHorizontalDragEnd: (_) => cleanPoint = null,
              onVerticalDragEnd: (_) => cleanPoint = null,
              onHorizontalDragCancel: () => cleanPoint = null,
              onVerticalDragCancel: () => cleanPoint = null,
            ));
      });
  void _drop(RepairPart part, String target) {
    final ok = game.drop(part, target);
    _speak(ok ? 'A perfect match!' : 'Try the matching shape.');
  }

  Widget _part(RepairPart part, String label) {
    final selected = game.selected == part;
    final child = Container(
        width: 88,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: selected ? const Color(0xFFDCEBFF) : AppColors.tint,
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: 2),
            borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PartPicture(part),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
        ]));
    return Draggable<RepairPart>(
        key: ValueKey('part-${part.name}'),
        data: part,
        maxSimultaneousDrags: game.paused ? 0 : 1,
        feedback: Material(
            color: Colors.transparent,
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: child),
        childWhenDragging: Opacity(opacity: .25, child: child),
        child: Semantics(
            button: true,
            label: 'Select $label',
            child: InkWell(
                onTap: () => game.select(part),
                borderRadius: BorderRadius.circular(16),
                child: child)));
  }

  Widget _actions() {
    final actions = <Widget>[];
    switch (game.stage) {
      case GarageStage.introduction:
        actions.add(const Text(
            'A pretend garage • No timers • Every way to communicate is welcome',
            textAlign: TextAlign.center));
      case GarageStage.explore:
        actions.addAll([
          _button(
              game.toolbox ? 'Close toolbox' : 'Open toolbox', game.openToolbox,
              soft: true),
          _button(game.lights ? 'Lights off' : 'Lights on', game.toggleLights,
              soft: true),
          _button(
              game.doorOpen ? 'Close garage' : 'Open garage', game.toggleDoor,
              soft: true),
          _button('Spin wheel', game.spinWheel,
              icon: Icons.rotate_right_rounded, soft: true),
          _button(
              'Clean a splash',
              game.cleaned.length < 4
                  ? () => game.clean(List.generate(4, (i) => i)
                      .firstWhere((i) => !game.cleaned.contains(i)))
                  : null,
              icon: Icons.cleaning_services_rounded,
              soft: true),
        ]);
        if (game.toolbox) actions.add(_part(RepairPart.wrench, 'Wrench'));
      case GarageStage.wheel:
        if (!game.inspected) {
          actions.add(_button('Look at wheel', game.inspect, soft: true));
        }
        if (game.inspected && !game.toolbox) {
          actions.add(_button('Open toolbox', game.openToolbox));
        }
        if (game.toolbox && !game.repaired) {
          actions.addAll([
            _part(RepairPart.wheel, 'Large wheel'),
            _part(RepairPart.smallWheel, 'Small wheel')
          ]);
        }
        if (game.repaired) {
          actions.addAll([
            _button('Pump ${game.pumpStrokes}/3',
                game.pumpStrokes < 3 ? game.pump : null,
                icon: Icons.air_rounded),
            Text('Air ${game.pumpStrokes * 100 ~/ 3}%',
                style: const TextStyle(
                    color: AppColors.inkSoft, fontWeight: FontWeight.w700))
          ]);
        }
      case GarageStage.engine:
        if (!game.bonnet) actions.add(_button('Open bonnet', game.openBonnet));
        if (game.bonnet && !game.repaired) {
          actions.addAll([
            _part(RepairPart.gear, 'Yellow gear'),
            _part(RepairPart.triangle, 'Triangle'),
            _part(RepairPart.smallWheel, 'Small wheel')
          ]);
        }
      case GarageStage.wrench:
        if (!game.attached) actions.add(_part(RepairPart.wrench, 'Wrench'));
        if (game.attached) {
          actions.add(_button(
              'Turn ${game.turns}/3', game.turns < 3 ? game.turn : null,
              icon: Icons.rotate_right_rounded));
        }
      case GarageStage.power:
        if (!game.sun) actions.add(_part(RepairPart.sun, 'Sun triangle'));
        if (!game.moon) actions.add(_part(RepairPart.moon, 'Moon square'));
        actions.add(_button(
            'Power', game.sun && game.moon && !game.powered ? game.power : null,
            icon: Icons.bolt_rounded));
      case GarageStage.drive:
        actions.add(SizedBox(
            width: 160,
            child: Column(children: [
              LinearProgressIndicator(
                  value: game.distance,
                  semanticsLabel: 'Journey to garage marker'),
              const SizedBox(height: 4),
              Text(game.distance >= .95 ? 'At the marker' : 'To the garage',
                  style: const TextStyle(fontSize: 12))
            ])));
        actions.addAll([
          _button('Start', !game.started ? game.start : null),
          _button(
              'Go',
              game.started && !game.driving && game.distance < .95
                  ? game.go
                  : null),
          _button('Stop', game.driving ? game.stop : null, soft: true)
        ]);
        actions.addAll([
          _button('Steer up', game.started ? () => game.steer(-1) : null,
              icon: Icons.arrow_upward_rounded, soft: true),
          _button('Middle', game.started ? () => game.steer(0) : null,
              soft: true),
          _button('Steer down', game.started ? () => game.steer(1) : null,
              icon: Icons.arrow_downward_rounded, soft: true),
          Text('${game.collectedStars.length}/3 stars',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.inkSoft))
        ]);
      case GarageStage.celebration:
        actions.addAll([
          const Icon(Icons.stars_rounded, color: AppColors.celebrate, size: 48),
          Text('Five repairs. ${game.collectedStars.length} driving stars!',
              style: const TextStyle(fontWeight: FontWeight.w800))
        ]);
    }
    return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: actions);
  }

  Widget _communication() {
    const words = [
      ['Car', 'Help', 'Go', 'Stop', 'Done'],
      ['Fix car', 'Help me', 'Car go', 'Stop car', 'All done'],
      [
        'My car is broken.',
        'Please help me fix the car.',
        'The car is ready to go.',
        'Please stop the car.',
        'I fixed the wheel.'
      ]
    ];
    const icons = [
      Icons.directions_car_rounded,
      Icons.front_hand_rounded,
      Icons.play_arrow_rounded,
      Icons.stop_rounded,
      Icons.check_circle_rounded
    ];
    return Column(children: [
      const Text('Say it your way',
          style:
              TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < words[speechLevel].length; i++)
              _button(words[speechLevel][i],
                  game.paused ? null : () => _speak(words[speechLevel][i]),
                  icon: icons[i], soft: true)
          ])
    ]);
  }

  Future<void> _preferences() async {
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
                          const Text('Preview preferences',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          SwitchListTile(
                              title: const Text('Sound'),
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
                          DropdownButtonFormField<RepairDifficulty>(
                              isExpanded: true,
                              initialValue: game.difficulty,
                              decoration: const InputDecoration(
                                  labelText: 'Difficulty'),
                              items: [
                                for (final d in RepairDifficulty.values)
                                  DropdownMenuItem(
                                      value: d, child: Text(d.name))
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  update(() => game.chooseDifficulty(v));
                                }
                              }),
                          DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: speechLevel,
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
                                if (v != null) update(() => speechLevel = v);
                              }),
                          const SizedBox(height: 16),
                          _button(
                              'Back to garage', () => Navigator.pop(context)),
                        ]))))));
    // Explicit resume avoids starting movement unexpectedly on sheet dismissal.
    if (mounted) setState(() {});
  }
}
