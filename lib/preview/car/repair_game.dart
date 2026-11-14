import 'package:flutter/foundation.dart';

enum GarageStage {
  introduction,
  explore,
  wheel,
  engine,
  wrench,
  power,
  drive,
  celebration
}

enum RepairPart { wheel, smallWheel, gear, triangle, wrench, sun, moon }

enum RepairDifficulty { easy, medium, advanced }

/// Preview-only state. Every completion is guarded by its actual prerequisites.
class RepairGame extends ChangeNotifier {
  GarageStage stage = GarageStage.introduction;
  RepairDifficulty difficulty = RepairDifficulty.easy;
  bool paused = false, toolbox = false, inspected = false, bonnet = false;
  bool repaired = false, attached = false, sun = false, moon = false;
  bool powered = false, started = false, driving = false, lights = false;
  int turns = 0;
  double distance = 0;
  bool doorOpen = true;
  final Set<int> cleaned = <int>{};
  final Set<int> collectedStars = <int>{};
  int pumpStrokes = 0;
  double steering = 0, wheelSpin = 0, wrenchArc = 0;
  int completedRepairs = 0;
  static const starDistances = [.25, .5, .75];
  static const starLanes = [-1.0, 1.0, 0.0];
  RepairPart? selected;
  String feedback = 'A little help. A big happy journey.';

  bool get ready => switch (stage) {
        GarageStage.introduction || GarageStage.explore => true,
        GarageStage.wheel => repaired && pumpStrokes == 3,
        GarageStage.engine => repaired,
        GarageStage.wrench => turns == 3,
        GarageStage.power => powered,
        GarageStage.drive => distance >= .95 && !driving && started,
        GarageStage.celebration => false,
      };

  void next() {
    if (paused || !ready || stage == GarageStage.celebration) return;
    if (stage.index >= GarageStage.wheel.index) completedRepairs++;
    stage = GarageStage.values[stage.index + 1];
    _resetMission();
    notifyListeners();
  }

  void _resetMission() {
    repaired = attached = inspected = toolbox = bonnet = false;
    sun = moon = powered = started = driving = false;
    turns = 0;
    distance = 0;
    pumpStrokes = 0;
    wrenchArc = steering = 0;
    if (stage != GarageStage.celebration) collectedStars.clear();
    selected = null;
    feedback = '';
  }

  void replay({bool all = false}) {
    if (all) {
      stage = GarageStage.introduction;
      completedRepairs = 0;
      cleaned.clear();
      doorOpen = true;
    }
    if (stage == GarageStage.explore) cleaned.clear();
    _resetMission();
    paused = false;
    lights = false;
    wheelSpin = 0;
    notifyListeners();
  }

  void pause(bool value) {
    paused = value;
    notifyListeners();
  }

  void chooseDifficulty(RepairDifficulty value) {
    difficulty = value;
    notifyListeners();
  }

  void select(RepairPart part) {
    if (!paused) {
      selected = part;
      notifyListeners();
    }
  }

  void inspect() {
    if (!paused && stage == GarageStage.wheel) {
      inspected = true;
      feedback = 'A flat wheel! Open the toolbox.';
      notifyListeners();
    }
  }

  void openToolbox() {
    if (!paused) {
      toolbox = !toolbox;
      notifyListeners();
    }
  }

  void openBonnet() {
    if (!paused && stage == GarageStage.engine) {
      bonnet = true;
      notifyListeners();
    }
  }

  void toggleLights() {
    if (!paused) {
      lights = !lights;
      notifyListeners();
    }
  }

  void toggleDoor() {
    if (paused || stage != GarageStage.explore) return;
    doorOpen = !doorOpen;
    feedback = doorOpen
        ? 'The garage is open. Hello, sunshine!'
        : 'The garage door is closed.';
    notifyListeners();
  }

  void clean(int spot) {
    if (paused ||
        stage != GarageStage.explore ||
        spot < 0 ||
        spot > 3 ||
        !cleaned.add(spot)) {
      return;
    }
    feedback = cleaned.length == 4
        ? 'Sparkling clean! What a shiny car.'
        : '${cleaned.length} of 4 splashes cleaned. Keep wiping!';
    notifyListeners();
  }

  void spinWheel() {
    if (paused || stage != GarageStage.explore) return;
    wheelSpin += 2.4;
    feedback = 'Round and round goes the wheel!';
    notifyListeners();
  }

  void pump() {
    if (paused || stage != GarageStage.wheel || !repaired || pumpStrokes == 3) {
      return;
    }
    pumpStrokes++;
    feedback = pumpStrokes == 3
        ? 'Full of air! Our wheel is ready.'
        : 'Pump, pump! $pumpStrokes of 3.';
    notifyListeners();
  }

  void rotateWrench(double radians) {
    if (paused ||
        stage != GarageStage.wrench ||
        !attached ||
        turns == 3 ||
        !radians.isFinite ||
        radians <= 0 ||
        radians > 1) {
      return;
    }
    wrenchArc += radians;
    if (wrenchArc >= .9) {
      wrenchArc -= .9;
      turn();
    } else {
      notifyListeners();
    }
  }

  void steer(double value) {
    if (paused || stage != GarageStage.drive || !started || !value.isFinite) {
      return;
    }
    steering = value.clamp(-1, 1);
    notifyListeners();
  }

  bool accepts(RepairPart part, String target) {
    if (paused) return false;
    return switch (stage) {
      GarageStage.wheel => inspected &&
          toolbox &&
          !repaired &&
          target == 'wheel' &&
          part == RepairPart.wheel,
      GarageStage.engine =>
        bonnet && !repaired && target == 'engine' && part == RepairPart.gear,
      GarageStage.wrench =>
        !attached && target == 'bolt' && part == RepairPart.wrench,
      GarageStage.power => target == 'sun' && part == RepairPart.sun && !sun ||
          target == 'moon' &&
              part == RepairPart.moon &&
              !moon &&
              (difficulty != RepairDifficulty.advanced || sun),
      _ => false,
    };
  }

  bool drop(RepairPart part, String target) {
    if (paused) return false;
    final valid = accepts(part, target);
    if (valid) {
      switch (stage) {
        case GarageStage.wheel || GarageStage.engine:
          repaired = true;
        case GarageStage.wrench:
          attached = true;
        case GarageStage.power:
          if (target == 'sun') {
            sun = true;
          } else {
            moon = true;
          }
        default:
          break;
      }
      selected = null;
      feedback = 'A perfect match!';
    } else {
      feedback = 'Try the matching shape. You can do it!';
    }
    notifyListeners();
    return valid;
  }

  void turn() {
    if (paused || stage != GarageStage.wrench || !attached || turns == 3) {
      return;
    }
    turns++;
    wrenchArc = 0;
    feedback = turns == 3
        ? 'The bolt is snug. Well done!'
        : 'Turn again. $turns of 3.';
    notifyListeners();
  }

  void power() {
    if (paused || stage != GarageStage.power || !sun || !moon || powered) {
      return;
    }
    powered = lights = true;
    feedback = 'Lights on! Our toy car has power.';
    notifyListeners();
  }

  void start() {
    if (paused || stage != GarageStage.drive || started) return;
    started = true;
    feedback = 'The engine is ready. Press Go!';
    notifyListeners();
  }

  void go() {
    if (paused || stage != GarageStage.drive || !started || distance >= .95) {
      return;
    }
    driving = true;
    notifyListeners();
  }

  void advance(double amount) {
    if (paused ||
        !driving ||
        stage != GarageStage.drive ||
        !amount.isFinite ||
        amount < 0) {
      return;
    }
    final before = distance;
    distance = (distance + amount).clamp(0, 1);
    for (var i = 0; i < starDistances.length; i++) {
      if (before <= starDistances[i] &&
          distance >= starDistances[i] &&
          (steering - starLanes[i]).abs() <= .6) {
        collectedStars.add(i);
        feedback = 'A shining star! ${collectedStars.length} collected.';
      }
    }
    notifyListeners();
  }

  void stop() {
    if (paused || stage != GarageStage.drive || !started) return;
    if (distance < .95) {
      driving = false;
      feedback = 'A gentle stop. Press Go when you are ready to continue.';
    } else {
      driving = false;
      feedback = 'A safe stop. You fixed the car!';
    }
    notifyListeners();
  }
}
