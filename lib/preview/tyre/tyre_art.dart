import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import 'tyre_game.dart';

class TyreAssets {
  TyreAssets(this.workshop, this.faces, this.tools, this.rig);
  final ui.Image workshop, tools;
  final List<ui.Image> faces;
  final List<List<double>> rig;
  static Future<TyreAssets> load() async {
    Future<ui.Image> read(String name) async {
      final data =
          await rootBundle.load('assets/images/story_scenes/tyre_v3_$name.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    }

    final images = <ui.Image>[];
    try {
      for (final name in [
        'workshop',
        'faces_0',
        'faces_1',
        'faces_2',
        'faces_3',
        'tools'
      ]) {
        images.add(await read(name));
      }
    } catch (_) {
      for (final image in images) {
        image.dispose();
      }
      rethrow;
    }
    final raw = jsonDecode(await rootBundle.loadString(
        'assets/images/story_scenes/tyre_v3_rig.json',
        cache: false)) as List;
    final rig = raw
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    return TyreAssets(images[0], images.sublist(1, 5), images[5], rig);
  }

  void dispose() {
    workshop.dispose();
    for (final face in faces) {
      face.dispose();
    }
    tools.dispose();
  }

  static Rect cell(ui.Image image, int index) => Rect.fromLTWH(
      index % 4 * image.width / 4,
      index ~/ 4 * image.height / 2,
      image.width / 4,
      image.height / 2);
  void tool(Canvas canvas, int index, Rect destination, {bool tight = false}) {
    final cell = TyreAssets.cell(tools, index);
    final source = tight
        ? Rect.fromLTWH(cell.left + cell.width * .08,
            cell.top + cell.height * .08, cell.width * .84, cell.height * .84)
        : cell;
    canvas.drawImageRect(tools, source, destination,
        Paint()..filterQuality = FilterQuality.high);
  }
}

class TyreGeometry {
  static const world = Size(1000, 660);
  static const front = Offset(680, 530);
  static const rear = Offset(305, 530);
  static const oldTray = Offset(180, 565);
  static const jack = Offset(480, 571);
  static const nuts = [Offset(0, -37), Offset(-32, 20), Offset(32, 20)];
  static Offset hub(double lift) => front - Offset(0, lift * 65);
  static Offset nut(int index, double lift) => hub(lift) + nuts[index];
}

/// Shared by drawing and every interactive hitbox, including during zoom.
class GarageCamera {
  GarageCamera(Size viewport, double focus) {
    final short = viewport.height < 330;
    final top = short ? 24.0 : 90.0;
    final bottom = short ? 72.0 : 128.0;
    final area = Rect.fromLTWH(
        0, top, viewport.width, math.max(80, viewport.height - top - bottom));
    scale = math.min(area.width / 1000, area.height / 660) *
        ui.lerpDouble(1.12, 1.24, focus)!;
    final anchor =
        Offset.lerp(const Offset(500, 345), const Offset(500, 330), focus)!;
    origin = area.center - anchor * scale;
  }
  late final double scale;
  late final Offset origin;
  Offset project(Offset world) => origin + world * scale;
}

class TyrePainter extends CustomPainter {
  TyrePainter(
      {required this.assets,
      required this.game,
      required this.lift,
      required this.snap,
      required this.time,
      required this.reduced,
      this.camera,
      this.nutFlight = 0,
      this.departure = 0,
      this.hint = false});
  final GarageCamera? camera;
  final double nutFlight;
  final double departure;
  final TyreAssets assets;
  final TyreGame game;
  final double lift, snap, time;
  final bool reduced, hint;

  @override
  void paint(Canvas c, Size size) {
    c.save();
    final background = applyBoxFit(
        BoxFit.cover,
        Size(assets.workshop.width.toDouble(),
            assets.workshop.height.toDouble()),
        size);
    c.drawImageRect(
        assets.workshop,
        Alignment.center.inscribe(
            background.source,
            Rect.fromLTWH(0, 0, assets.workshop.width.toDouble(),
                assets.workshop.height.toDouble())),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.high);
    if (camera case final view?) {
      c.translate(view.origin.dx, view.origin.dy);
      c.scale(view.scale);
    } else {
      c.scale(size.width / 1000, size.height / 660);
    }
    // A service pad and soft contact shadow place the coordinated rig on floor.
    c.drawOval(const Rect.fromLTWH(130, 565, 760, 70),
        Paint()..color = const Color(0x193D617C));
    c.drawOval(
        Rect.fromLTWH(185, 591 + lift * 5, 650 - lift * 45, 28),
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
          ..color = const Color(0x352B3040));
    final t = reduced ? 0.0 : time;
    if (game.oldRemoved) {
      c.drawOval(const Rect.fromLTWH(110, 610, 145, 18),
          Paint()..color = const Color(0x282B3040));
      assets.tool(c, 1, const Rect.fromLTWH(107, 500, 145, 128), tight: true);
    }
    // A gentle workbench indicator is ambient, never part of a mission gate.
    c.drawCircle(
        const Offset(857, 299),
        4,
        Paint()
          ..color = Color.lerp(const Color(0xFF8BBE8C), const Color(0xFFE6F8A4),
              (math.sin(t * 2) + 1) / 2)!);
    if (game.step.index >= TyreStep.loosen.index || game.busy) {
      assets.tool(c, 2, const Rect.fromLTWH(405, 555, 160, 88), tight: true);
      assets.tool(
          c, 3, Rect.fromLTWH(424, 503 - lift * 65, 128, 104 + lift * 65),
          tight: true);
      if (game.busy &&
          (game.step == TyreStep.jack || game.step == TyreStep.lower)) {
        c.save();
        c.translate(476, 580);
        c.rotate(math.sin(t * 13) * .22);
        c.drawLine(
            Offset.zero,
            const Offset(-83, -28),
            Paint()
              ..color = AppColors.primary
              ..strokeWidth = 12
              ..strokeCap = StrokeCap.round);
        c.restore();
      }
    }
    c.save();
    c.translate(game.step == TyreStep.done ? departure * 1150 : 0, 0);
    final bob = reduced ||
            game.busy ||
            (game.step != TyreStep.inspect && game.step != TyreStep.done)
        ? 0.0
        : math.sin(t * 2.5) * (game.step == TyreStep.done ? 4 : 1.3);
    c.translate(0, -lift * 65 + bob);
    var expression = game.expression;
    if (!reduced && t % 4.2 > 4.06) {
      expression = expression == 1 || expression == 2 ? 7 : 6;
    }
    final image = assets.faces[expression ~/ 2];
    final bodySource = Rect.fromLTWH(expression % 2 * image.width / 2, 0,
        image.width / 2, image.height.toDouble());
    final anchors = assets.rig[expression];
    final bodyScale = (TyreGeometry.front.dx - TyreGeometry.rear.dx) /
        (anchors[1] - anchors[0]);
    final bodyDestination = Rect.fromLTWH(
        TyreGeometry.rear.dx - anchors[0] * bodyScale,
        TyreGeometry.front.dy - anchors[2] * bodyScale,
        bodySource.width * bodyScale,
        bodySource.height * bodyScale);
    c.drawImageRect(image, bodySource, bodyDestination,
        Paint()..filterQuality = FilterQuality.high);
    // Each wheel is a separate illustrated layer. Their contact follows lift.
    c.translate(0, -bob);
    c.save();
    c.translate(305, 530);
    c.rotate(departure * 22);
    assets.tool(c, 0, const Rect.fromLTWH(-95, -95, 190, 190), tight: true);
    c.restore();
    if (game.step != TyreStep.remove && !game.oldRemoved) {
      assets.tool(c, 1, const Rect.fromLTWH(582, 449, 196, 178), tight: true);
    } else if (game.newFitted) {
      final offset = game.busy && game.step == TyreStep.fit
          ? (1 - Curves.easeOutBack.transform(snap)) * 92
          : 0.0;
      c.save();
      c.translate(680 + offset, 530);
      c.rotate(game.busy && game.step == TyreStep.fit
          ? (1 - snap) * .45
          : departure * 22);
      assets.tool(c, 0, const Rect.fromLTWH(-95, -95, 190, 190), tight: true);
      c.restore();
    } else {
      final source = TyreAssets.cell(assets.tools, 0);
      c.drawImageRect(
          assets.tools,
          Rect.fromCenter(
              center: source.center,
              width: source.width * .25,
              height: source.height * .25),
          const Rect.fromLTWH(643, 493, 74, 74),
          Paint()..filterQuality = FilterQuality.high);
    }
    if (game.step == TyreStep.done) {
      final beam = Path()
        ..moveTo(845, 351)
        ..lineTo(990, 314)
        ..lineTo(990, 432)
        ..lineTo(845, 383)
        ..close();
      c.drawPath(
          beam,
          Paint()
            ..shader = const LinearGradient(
                    colors: [Color(0x77FFF2AC), Color(0x00FFF2AC)])
                .createShader(const Rect.fromLTWH(845, 314, 145, 118)));
    }
    c.restore();
    if (game.loosened.isNotEmpty || game.settlingNut) {
      final tray = RRect.fromRectAndRadius(
          const Rect.fromLTWH(100, 585, 182, 64), const Radius.circular(18));
      c.drawRRect(tray.shift(const Offset(0, 7)),
          Paint()..color = const Color(0x3322304A));
      c.drawRRect(
          tray,
          Paint()
            ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEAF3FF),
                  Color(0xFF88A9CF),
                  Color(0xFF52769C)
                ]).createShader(tray.outerRect));
      c.drawRRect(
          RRect.fromRectAndRadius(
              tray.outerRect.deflate(7), const Radius.circular(12)),
          Paint()..color = const Color(0xFF65819F));
      for (var i = 0; i < 3; i++) {
        c.drawOval(
            Rect.fromCenter(
                center: Offset(137 + i * 51, 617), width: 44, height: 31),
            Paint()..color = const Color(0xFF38516F));
      }
      c.drawRRect(
          tray,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = const Color(0xFFBDD3EA));
      for (final i in game.loosened) {
        if (game.tightened.contains(i) ||
            (game.step == TyreStep.tighten &&
                game.settlingNut &&
                game.nut == i)) {
          continue;
        }
        assets.tool(
            c,
            5,
            Rect.fromCenter(
                center: Offset(137 + i * 51, 617), width: 39, height: 39),
            tight: true);
      }
    }
    if (game.step == TyreStep.loosen || game.step == TyreStep.tighten) {
      for (var i = 0; i < 3; i++) {
        if (game.step == TyreStep.loosen && game.loosened.contains(i) ||
            game.settlingNut && game.nut == i) {
          continue;
        }
        final point = TyreGeometry.nut(i, lift);
        final scale =
            game.step == TyreStep.tighten && game.tightened.contains(i)
                ? 29.0
                : 36.0;
        assets.tool(
            c, 5, Rect.fromCenter(center: point, width: scale, height: scale),
            tight: true);
      }
      if (game.settlingNut) {
        final hub = TyreGeometry.nut(game.nut, lift);
        final tray = Offset(137 + game.nut * 51, 617);
        final tightening = game.step == TyreStep.tighten;
        final point = Offset.lerp(
                tightening ? tray : hub,
                tightening ? hub : tray,
                Curves.easeInOut.transform(nutFlight))! -
            Offset(0, math.sin(nutFlight * math.pi) * 55);
        c.save();
        c.translate(point.dx, point.dy);
        c.rotate(nutFlight * math.pi * 2);
        assets.tool(c, 5, const Rect.fromLTWH(-22, -22, 44, 44), tight: true);
        c.restore();
      }
      if (game.attached) {
        final pivot = TyreGeometry.nut(game.nut, lift);
        c.save();
        c.translate(pivot.dx, pivot.dy);
        c.rotate(
            -1.4 + (game.step == TyreStep.loosen ? -1 : 1) * game.turn * 1.4);
        assets.tool(c, 4, const Rect.fromLTWH(-100, -44, 200, 200));
        c.restore();
      }
    }
    if (game.step == TyreStep.done) {
      for (var i = 0; i < 20; i++) {
        final x = 95 + i * 43.0;
        final y = reduced ? 100 + i % 3 * 30.0 : 80 + (i * 53 + t * 72) % 370;
        _star(c, Offset(x, y), i.isEven ? 10 : 6,
            i % 3 == 0 ? AppColors.primary : AppColors.celebrate);
      }
    }
    c.restore();
  }

  static void _star(Canvas c, Offset p, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 - math.pi / 2,
          r = i.isEven ? radius : radius * .45;
      final point = p + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    c.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant TyrePainter oldDelegate) => true;

  // Accessible actions live in the transformed widgets above this decorative
  // canvas. Blinks and paint ticks must not invalidate Android's semantic tree.
  @override
  bool shouldRebuildSemantics(covariant TyrePainter oldDelegate) => false;
}

class IllustratedTool extends StatelessWidget {
  const IllustratedTool(
      {super.key, required this.assets, required this.index, this.size = 72});
  final TyreAssets assets;
  final int index;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ToolPainter(assets, index)));
}

class _ToolPainter extends CustomPainter {
  _ToolPainter(this.assets, this.index);
  final TyreAssets assets;
  final int index;
  @override
  void paint(Canvas c, Size s) => index == 2
      ? _jack(c, s)
      : assets.tool(c, index, Offset.zero & s, tight: true);
  void _jack(Canvas c, Size s) {
    assets.tool(
        c,
        2,
        Rect.fromLTWH(
            s.width * .04, s.height * .57, s.width * .92, s.height * .36),
        tight: true);
    assets.tool(
        c, 3, Rect.fromLTWH(s.width * .17, 0, s.width * .66, s.height * .77),
        tight: true);
  }

  @override
  bool shouldRepaint(covariant _ToolPainter oldDelegate) =>
      oldDelegate.assets != assets || oldDelegate.index != index;
}
