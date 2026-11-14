import 'dart:math' as math;
import 'package:flutter/foundation.dart';

enum TyreStep { inspect, jack, loosen, remove, fit, tighten, lower, done }

enum TyreTool { jack, wrench, spare, small, damaged }

/// One complete, fictional toy repair. Only validated physical actions advance.
class TyreGame extends ChangeNotifier {
  TyreStep step = TyreStep.inspect;
  TyreTool? selected;
  bool paused = false, busy = false, raised = false, attached = false;
  bool oldRemoved = false, newFitted = false;
  int nut = 0, cueRevision = 0;
  double turn = 0;
  // In-memory scene continuity when leaving/reopening this preview route.
  double liftFraction = 0, snapFraction = 0, nutFraction = 0;
  bool settlingNut = false;
  final Set<int> loosened = {}, tightened = {};
  Set<int> get completedNuts => step == TyreStep.tighten ? tightened : loosened;
  bool toolAvailable(TyreTool tool) => switch (step) {
        TyreStep.jack => tool == TyreTool.jack,
        TyreStep.loosen || TyreStep.tighten => tool == TyreTool.wrench,
        TyreStep.fit => tool == TyreTool.spare || tool == TyreTool.small,
        TyreStep.remove => tool == TyreTool.damaged,
        _ => false,
      };
  String cue = '', feedback = 'Our little friend needs a new wheel.';

  String get heading => const [
        'A little help?',
        'Lift with the toy jack',
        'Loosen the wheel nuts',
        'Take the old wheel away',
        'A perfect new wheel',
        'Tighten the wheel nuts',
        'Gently back down',
        'Ready for happy journeys!'
      ][step.index];
  String get instruction => switch (step) {
        TyreStep.inspect => 'Touch the flat wheel. Let’s look together.',
        TyreStep.jack => busy
            ? 'Up we go. The jack supports our toy car.'
            : 'Drag the blue jack under the glowing chassis mark.',
        TyreStep.loosen => attached
            ? 'Turn the wrench anticlockwise. Nut ${nut + 1} of 3.'
            : 'Place the wrench on the glowing nut. Nut ${nut + 1} of 3.',
        TyreStep.remove => 'Drag the damaged wheel to the illustrated tray.',
        TyreStep.fit => busy
            ? 'The new wheel slides onto its hub.'
            : 'Choose the matching silver wheel. Align it with the glowing hub.',
        TyreStep.tighten => attached
            ? 'Turn clockwise until the nut is snug. Nut ${nut + 1} of 3.'
            : 'Place the wrench on the glowing nut. Nut ${nut + 1} of 3.',
        TyreStep.lower => busy
            ? 'Gently lowering. Almost ready!'
            : 'Press the jack release to lower our toy car.',
        TyreStep.done =>
          'You lifted, turned, matched and helped. Thank you, mechanic!',
      };
  bool get canAct => !paused && !busy;
  int get expression => switch (step) {
        TyreStep.inspect => 1,
        TyreStep.jack => busy ? 3 : 2,
        TyreStep.loosen => loosened.isEmpty ? 1 : 0,
        TyreStep.remove => 0,
        TyreStep.fit => newFitted ? 5 : 3,
        TyreStep.tighten => 5,
        TyreStep.lower => 0,
        TyreStep.done => 4,
      };

  void _event(String sound, String message) {
    cue = sound;
    cueRevision++;
    feedback = message;
    notifyListeners();
  }

  void inspect() {
    if (!canAct || step != TyreStep.inspect) return;
    step = TyreStep.jack;
    _event('soft', 'Oh dear, a flat wheel. We can help.');
  }

  void select(TyreTool tool) {
    if (canAct && toolAvailable(tool)) {
      selected = tool;
      notifyListeners();
    }
  }

  void chooseNut(int index) {
    if (!canAct ||
        attached ||
        index < 0 ||
        index > 2 ||
        (step != TyreStep.loosen && step != TyreStep.tighten) ||
        completedNuts.contains(index)) {
      return;
    }
    nut = index;
    notifyListeners();
  }

  bool accepts(TyreTool tool, String target) {
    if (!canAct) return false;
    return switch (step) {
      TyreStep.jack => tool == TyreTool.jack && target == 'jack',
      TyreStep.loosen || TyreStep.tighten => raised &&
          !attached &&
          tool == TyreTool.wrench &&
          RegExp(r'^nut[0-2]$').hasMatch(target) &&
          !completedNuts.contains(int.parse(target.substring(3))),
      TyreStep.remove => raised && tool == TyreTool.damaged && target == 'tray',
      TyreStep.fit => raised &&
          oldRemoved &&
          !newFitted &&
          tool == TyreTool.spare &&
          target == 'hub',
      _ => false,
    };
  }

  bool drop(TyreTool tool, String target) {
    if (!canAct) return false;
    if (!accepts(tool, target)) {
      _event('soft', 'Find the matching picture. Take your time.');
      return false;
    }
    selected = null;
    switch (step) {
      case TyreStep.jack:
        busy = true;
        _event('jack', 'The toy jack is in place. Lifting gently.');
      case TyreStep.loosen || TyreStep.tighten:
        nut = int.parse(target.substring(3));
        attached = true;
        turn = 0;
        _event('snap', 'A good fit. Now turn the wrench.');
      case TyreStep.remove:
        oldRemoved = true;
        step = TyreStep.fit;
        _event('snap', 'The old wheel is safely in its tray.');
      case TyreStep.fit:
        busy = true;
        newFitted = true;
        _event('snap', 'A perfect match!');
      default:
        break;
    }
    return true;
  }

  void finishMotion() {
    if (paused || !busy || settlingNut) return;
    busy = false;
    switch (step) {
      case TyreStep.jack:
        raised = true;
        liftFraction = 1;
        step = TyreStep.loosen;
      case TyreStep.fit:
        snapFraction = 1;
        step = TyreStep.tighten;
        nut = 0;
      case TyreStep.lower:
        raised = false;
        liftFraction = 0;
        step = TyreStep.done;
      default:
        return;
    }
    _event(step == TyreStep.done ? 'chime' : 'soft', instruction);
  }

  void rotate(double radians) {
    if (!canAct ||
        !attached ||
        (step != TyreStep.loosen && step != TyreStep.tighten) ||
        !radians.isFinite ||
        // Android can coalesce a quarter-turn into one slightly larger update.
        // The pointer tracker normalizes deltas to [-pi, pi] and rejects the
        // central dead zone, so a physical half-turn is a valid maximum.
        radians.abs() > math.pi) {
      return;
    }
    final correct = step == TyreStep.loosen ? -radians : radians;
    if (correct <= 0) return;
    turn = (turn + correct / 1.4).clamp(0, 1);
    if (turn >= 1) {
      attached = false;
      settlingNut = busy = true;
      _event(
          'metal',
          step == TyreStep.loosen
              ? 'Great! This nut is loose.'
              : 'That nut is snug!');
    } else {
      notifyListeners();
    }
  }

  void finishNutMotion() {
    if (!settlingNut || paused) return;
    completedNuts.add(nut);
    settlingNut = busy = false;
    nutFraction = 0;
    turn = 0;
    if (completedNuts.length == 3) {
      step = step == TyreStep.loosen ? TyreStep.remove : TyreStep.lower;
      nut = 0;
    } else {
      nut = List.generate(3, (i) => i)
          .firstWhere((i) => !completedNuts.contains(i));
    }
    _event('soft', instruction);
  }

  void assistedTurn() => rotate(step == TyreStep.loosen ? -.5 : .5);
  void lower() {
    if (!canAct || step != TyreStep.lower || !raised || !newFitted) return;
    busy = true;
    _event('jack', 'Down we go, gently.');
  }

  void pause(bool value) {
    paused = value;
    notifyListeners();
  }

  void reset() {
    liftFraction = snapFraction = nutFraction = 0;
    step = TyreStep.inspect;
    selected = null;
    paused = busy = raised = attached = oldRemoved = newFitted = false;
    nut = 0;
    settlingNut = false;
    loosened.clear();
    tightened.clear();
    turn = 0;
    _event('soft', 'Our little friend needs a new wheel.');
  }
}
