import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'repair_game.dart';

/// Independent, resolution-independent layers: body, expressions, wheels,
/// headlights, bonnet, wrench and scenery all use the same scene coordinates.
class GaragePainter extends CustomPainter {
  GaragePainter(
      {required this.game,
      required this.time,
      required this.reduced,
      this.bodyImage,
      this.roadImage,
      this.door = 1,
      this.spunWheel = 0,
      this.wrenchTurns = 0});
  final double door, spunWheel;
  static const dirtSpots = [
    Offset(320, 356),
    Offset(390, 393),
    Offset(480, 357),
    Offset(550, 414)
  ];
  final ui.Image? bodyImage;
  final ui.Image? roadImage;
  final double wrenchTurns;
  final RepairGame game;
  final double time;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 900, size.height / 600);
    final c = canvas;
    final t = reduced ? 0.0 : time;
    final drive = game.stage == GarageStage.drive;
    final roadDistance =
        reduced ? (game.distance >= .95 ? 1.0 : 0.0) : game.distance;
    final happy = game.stage.index > GarageStage.wheel.index || game.repaired;
    if (!drive && door < .995) {
      final height = 260 * (1 - door);
      final shutter = Rect.fromLTWH(285, 95, 310, height);
      c.drawRRect(
          RRect.fromRectAndRadius(shutter, const Radius.circular(8)),
          Paint()
            ..shader = const LinearGradient(
                    colors: [Color(0xFFB8CEDF), Color(0xFF728FA9)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)
                .createShader(shutter));
      c.save();
      c.clipRect(shutter);
      for (var y = 105.0; y < 355; y += 24) {
        line(c, Offset(287, y), Offset(593, y), const Color(0xFF7F9BB2), 3);
      }
      rect(c, Rect.fromLTWH(419, 76 + height, 42, 7), const Color(0xFF385169),
          radius: 3);
      c.restore();
    }
    if (drive) {
      if (roadImage == null) {
        rect(c, const Rect.fromLTWH(0, 0, 900, 600), const Color(0xFFCFEEFC));
        for (var i = -1; i < 6; i++) {
          final x = (i * 250 - roadDistance * 1000) % 1300 - 200;
          oval(c, Rect.fromLTWH(x, 170, 420, 280), const Color(0xFF95CC7D));
          oval(
              c, Rect.fromLTWH(x + 80, 210, 300, 220), const Color(0xFF78B56C));
        }
        rect(c, const Rect.fromLTWH(0, 390, 900, 210), const Color(0xFF6F7D91));
        rect(c, const Rect.fromLTWH(0, 395, 900, 8), Colors.white);
      } else {
        final image = roadImage!;
        c.drawImageRect(
            image,
            Rect.fromLTWH(roadDistance * image.width * .2, 0, image.width * .8,
                image.height.toDouble()),
            const Rect.fromLTWH(0, 0, 900, 600),
            Paint()..filterQuality = FilterQuality.medium);
      }
      for (var i = -1; i < 9; i++) {
        rect(
            c,
            Rect.fromLTWH(
                (i * 160 - roadDistance * 1600) % 1100 - 100, 530, 80, 8),
            const Color(0xFFFFE9A3),
            radius: 4);
      }
      final marker = 1050 - roadDistance * 460;
      rect(c, Rect.fromLTWH(marker, 285, 9, 170), AppColors.primary);
      rect(c, Rect.fromLTWH(marker - 35, 270, 90, 60), AppColors.primary,
          radius: 12);
      text(c, 'STOP', Offset(marker - 24, 288), 22, Colors.white);
      for (var i = 0; i < RepairGame.starDistances.length; i++) {
        if (game.collectedStars.contains(i)) continue;
        final x = reduced
            ? 650.0 + i * 70
            : 500 + (RepairGame.starDistances[i] - game.distance) * 1400;
        if (x < -40 || x > 950) continue;
        final y = 445 + RepairGame.starLanes[i] * 32;
        c.drawCircle(
            Offset(x, y), 29, Paint()..color = const Color(0x70FFF1AE));
        star(c, Offset(x, y), 21, const Color(0xFFFFC233));
      }
    }
    if (game.stage == GarageStage.celebration) {
      for (var i = 0; i < 24; i++) {
        final x = (i * 137.0) % 900;
        final y = (i * 79 + t * 90) % 470;
        c.save();
        c.translate(x, y);
        c.rotate(i + t);
        rect(
            c,
            const Rect.fromLTWH(-5, -9, 10, 18),
            [
              AppColors.celebrate,
              AppColors.primary,
              const Color(0xFFEF8772)
            ][i % 3],
            radius: 3);
        c.restore();
      }
    }
    if (!drive &&
        (game.stage == GarageStage.explore ||
            game.stage == GarageStage.wheel)) {
      rect(c, const Rect.fromLTWH(40, 405, 112, 65), const Color(0xFFDB6950),
          radius: 9);
      rect(c, const Rect.fromLTWH(48, 413, 96, 12), const Color(0xFF743E35),
          radius: 4);
      c.save();
      c.translate(42, 405);
      c.rotate(game.toolbox ? -.7 : 0);
      rect(c, const Rect.fromLTWH(0, -12, 108, 17), const Color(0xFFEF8C70),
          radius: 5);
      rect(c, const Rect.fromLTWH(36, -24, 36, 13), const Color(0xFF9E5746),
          radius: 5);
      c.restore();
      rect(c, const Rect.fromLTWH(88, 426, 14, 15), const Color(0xFFFFD16A),
          radius: 3);
    }
    final dx = drive ? -60 + roadDistance * 100 : 0.0;
    c.translate(dx, drive ? game.steering * 32 : 0);
    oval(c, const Rect.fromLTWH(155, 456, 590, 48), const Color(0x330D2849));
    c.save();
    final bounce = happy ? math.sin(t * 3) * 3 : math.sin(t * 2) * 1.5;
    c.translate(0, bounce);
    // Small rounded hatchback, drawn without the wheels so each can rotate.
    if (bodyImage == null) {
      final body = Path()
        ..moveTo(180, 401)
        ..quadraticBezierTo(172, 345, 228, 338)
        ..lineTo(298, 245)
        ..quadraticBezierTo(318, 221, 361, 221)
        ..lineTo(493, 221)
        ..quadraticBezierTo(526, 221, 550, 253)
        ..lineTo(621, 337)
        ..quadraticBezierTo(709, 341, 725, 383)
        ..lineTo(729, 432)
        ..quadraticBezierTo(719, 461, 684, 461)
        ..lineTo(221, 461)
        ..quadraticBezierTo(180, 452, 180, 401)
        ..close();
      c.drawShadow(body, const Color(0xFF163E70), 7, false);
      c.drawPath(
          body,
          Paint()
            ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF81CEFF),
                  Color(0xFF378CE9),
                  Color(0xFF2065BE)
                ]).createShader(const Rect.fromLTWH(180, 221, 550, 240)));
      c.drawPath(
          body,
          Paint()
            ..color = const Color(0xFF1E59A5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
      final glass = Path()
        ..moveTo(317, 257)
        ..quadraticBezierTo(325, 247, 347, 247)
        ..lineTo(484, 247)
        ..quadraticBezierTo(505, 247, 520, 269)
        ..lineTo(564, 326)
        ..lineTo(266, 326)
        ..close();
      c.drawPath(
          glass,
          Paint()
            ..shader = const LinearGradient(
                    colors: [Color(0xFFD7F3FC), Color(0xFF9ACDE7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)
                .createShader(const Rect.fromLTWH(266, 247, 300, 80)));
      line(c, const Offset(270, 337), const Offset(585, 337),
          const Color(0xFFA1DDFF), 4);
      line(c, const Offset(434, 343), const Offset(434, 429),
          const Color(0xFF2469AE), 3);
      rect(c, const Rect.fromLTWH(448, 351, 33, 9), const Color(0xFFD5EBFA),
          radius: 5);
      rect(c, const Rect.fromLTWH(179, 411, 47, 22), const Color(0xFFF78267),
          radius: 8);
      rect(c, const Rect.fromLTWH(680, 362, 36, 30), const Color(0xFFFFE59D),
          radius: 12);
    } else {
      final image = bodyImage!;
      c.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          const Rect.fromLTWH(187, 221, 526, 240),
          Paint()..filterQuality = FilterQuality.high);
    }
    if (game.lights) {
      final beam = Path()
        ..moveTo(712, 365)
        ..lineTo(887, 315)
        ..lineTo(887, 441)
        ..lineTo(712, 389)
        ..close();
      c.drawPath(
          beam,
          Paint()
            ..shader = const LinearGradient(
                    colors: [Color(0xAAFFF1B1), Color(0x00FFF1B1)])
                .createShader(const Rect.fromLTWH(712, 315, 175, 126)));
    }
    final blink = t % 4.4 > 4.15;
    for (final x in [386.0, 477.0]) {
      if (blink) {
        line(c, Offset(x - 15, 288), Offset(x + 15, 288), AppColors.ink, 5);
      } else {
        oval(c, Rect.fromCenter(center: Offset(x, 285), width: 40, height: 46),
            Colors.white);
        oval(
            c,
            Rect.fromCenter(center: Offset(x + 4, 289), width: 22, height: 28),
            AppColors.ink);
        oval(
            c,
            Rect.fromCenter(center: Offset(x + 7, 282), width: 7, height: 9),
            Colors.white);
      }
    }
    final smile = Path()
      ..moveTo(551, happy ? 385 : 399)
      ..quadraticBezierTo(590, happy ? 426 : 366, 626, happy ? 385 : 399);
    c.drawPath(
        smile,
        Paint()
          ..color = const Color(0xFF163D70)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6);
    if (game.stage == GarageStage.engine && !game.repaired) {
      oval(c, const Rect.fromLTWH(570, 380, 44, 34), const Color(0xFF3E8BCE));
      oval(c, const Rect.fromLTWH(582, 384, 20, 26), const Color(0xFF163D70));
    }
    oval(c, const Rect.fromLTWH(536, 374, 21, 10), const Color(0xAAFFA6A2));
    if (game.stage == GarageStage.explore) {
      for (var i = 0; i < dirtSpots.length; i++) {
        final p = dirtSpots[i];
        if (game.cleaned.contains(i)) {
          star(c, p, 11, const Color(0xFFF8F4BE));
        } else {
          oval(c, Rect.fromCenter(center: p, width: 37, height: 24),
              const Color(0xFFAA8060));
          oval(
              c,
              Rect.fromCenter(
                  center: p + const Offset(-11, -8), width: 17, height: 19),
              const Color(0xFFAA8060));
          oval(
              c,
              Rect.fromCenter(
                  center: p + const Offset(15, 7), width: 15, height: 14),
              const Color(0xFFAA8060));
          oval(
              c,
              Rect.fromCenter(
                  center: p + const Offset(-2, -2), width: 17, height: 7),
              const Color(0xFFCBA281));
        }
      }
    }
    if (game.bonnet || game.stage == GarageStage.engine) {
      rect(c, const Rect.fromLTWH(540, 327, 136, 50), const Color(0xFF233D59),
          radius: 10);
      if (game.bonnet) {
        c.save();
        c.translate(544, 331);
        c.rotate(-.65);
        rect(c, const Rect.fromLTWH(0, -10, 142, 14), const Color(0xFF6FB9F8),
            radius: 7);
        c.restore();
      } else {
        rect(c, const Rect.fromLTWH(540, 327, 136, 50), const Color(0xFF4797E9),
            radius: 10);
      }
    }
    c.restore();
    if (game.stage == GarageStage.wrench) {
      final bolt = Path();
      final radius = 17 - game.turns * 1.5;
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + wrenchTurns * .5;
        final p =
            Offset(455 + math.cos(a) * radius, 396 + math.sin(a) * radius);
        if (i == 0) {
          bolt.moveTo(p.dx, p.dy);
        } else {
          bolt.lineTo(p.dx, p.dy);
        }
      }
      bolt.close();
      c.drawPath(bolt, Paint()..color = const Color(0xFFDAE8F4));
      line(c, const Offset(449, 396), const Offset(461, 396), AppColors.inkSoft,
          3);
    }
    if (game.stage == GarageStage.wheel &&
        game.repaired &&
        game.pumpStrokes < 3) {
      final hose = Path()
        ..moveTo(780, 475)
        ..cubicTo(800, 557, 285, 568, 285, 445);
      c.drawPath(
          hose,
          Paint()
            ..color = const Color(0xFF263D52)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round);
    }
    for (final x in [285.0, 618.0]) {
      final pressure = x == 285 && game.stage.index <= GarageStage.wheel.index
          ? game.stage == GarageStage.wheel && game.repaired
              ? game.pumpStrokes / 3
              : 0.0
          : 1.0;
      c.save();
      c.translate(x, 445);
      c.scale(1, .68 + pressure * .32);
      c.rotate(game.driving && !reduced
          ? game.distance * 35
          : game.stage == GarageStage.explore
              ? spunWheel
              : 0);
      wheel(c, 56);
      c.restore();
    }
    if (game.stage == GarageStage.wrench && game.attached) {
      c.save();
      c.translate(455, 396);
      c.rotate(-.8 + wrenchTurns * .65);
      rect(c, const Rect.fromLTWH(-8, -5, 16, 90), const Color(0xFFDDE7F2),
          radius: 8);
      oval(c, const Rect.fromLTWH(-20, -20, 40, 40), const Color(0xFFDDE7F2));
      oval(c, const Rect.fromLTWH(-10, -10, 20, 20), AppColors.primary);
      c.restore();
    }
    if (game.repaired || game.turns == 3 || game.powered) {
      for (var i = 0; i < 5; i++) {
        final x = 210 + i * 120.0;
        star(c, Offset(x, 190 + math.sin(t * 3 + i) * 10), 14,
            AppColors.celebrate);
      }
    }
    c.restore();
  }

  static void wheel(Canvas c, double radius) {
    c.drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..shader = const RadialGradient(colors: [
            Color(0xFF68798C),
            Color(0xFF293748),
            Color(0xFF172332)
          ]).createShader(
              Rect.fromCircle(center: Offset.zero, radius: radius)));
    c.drawCircle(
        Offset.zero, radius * .65, Paint()..color = const Color(0xFFD9E6F0));
    c.drawCircle(
        Offset.zero, radius * .46, Paint()..color = const Color(0xFF7D9CB6));
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5;
      line(
          c,
          Offset(math.cos(a) * radius * .18, math.sin(a) * radius * .18),
          Offset(math.cos(a) * radius * .52, math.sin(a) * radius * .52),
          const Color(0xFFF5F9FD),
          radius * .1);
    }
    c.drawCircle(
        Offset.zero, radius * .15, Paint()..color = const Color(0xFF45617B));
  }

  static void star(Canvas c, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? radius : radius * .46;
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    c.drawShadow(path, const Color(0x337B5412), 2, false);
    c.drawPath(path, Paint()..color = color);
  }

  static void rect(Canvas c, Rect r, Color color, {double radius = 0}) =>
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)),
          Paint()..color = color);
  static void oval(Canvas c, Rect r, Color color) =>
      c.drawOval(r, Paint()..color = color);
  static void line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(
          a,
          b,
          Paint()
            ..color = color
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round);
  static void text(
      Canvas c, String value, Offset offset, double size, Color color) {
    final p = TextPainter(
        text: TextSpan(
            text: value,
            style: TextStyle(
                fontSize: size, fontWeight: FontWeight.w900, color: color)),
        textDirection: TextDirection.ltr)
      ..layout();
    p.paint(c, offset);
  }

  @override
  bool shouldRepaint(covariant GaragePainter oldDelegate) => true;
}

class PartPicture extends StatelessWidget {
  const PartPicture(this.part, {super.key, this.size = 48});
  final RepairPart part;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PartPainter(part)));
}

class _PartPainter extends CustomPainter {
  _PartPainter(this.part);
  final RepairPart part;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.translate(size.width / 2, size.height / 2);
    c.scale(size.width / 60);
    if (part == RepairPart.wheel || part == RepairPart.smallWheel) {
      GaragePainter.wheel(c, part == RepairPart.wheel ? 27 : 17);
    } else if (part == RepairPart.wrench) {
      c.rotate(.5);
      GaragePainter.rect(
          c, const Rect.fromLTWH(-5, -9, 10, 35), const Color(0xFF91A8BD),
          radius: 5);
      GaragePainter.oval(
          c, const Rect.fromLTWH(-14, -28, 28, 28), const Color(0xFFB5C9DA));
      GaragePainter.rect(c, const Rect.fromLTWH(-7, -29, 14, 15), Colors.white,
          radius: 2);
    } else if (part == RepairPart.gear) {
      for (var i = 0; i < 8; i++) {
        c.save();
        c.rotate(i * math.pi / 4);
        GaragePainter.rect(
            c, const Rect.fromLTWH(-6, -27, 12, 16), const Color(0xFFFFC233),
            radius: 3);
        c.restore();
      }
      c.drawCircle(Offset.zero, 20, Paint()..color = const Color(0xFFFFD96E));
      c.drawCircle(Offset.zero, 9, Paint()..color = const Color(0xFF986122));
    } else if (part == RepairPart.triangle || part == RepairPart.sun) {
      final p = Path()
        ..moveTo(0, -25)
        ..lineTo(26, 22)
        ..lineTo(-26, 22)
        ..close();
      c.drawShadow(p, Colors.black26, 2, false);
      c.drawPath(
          p,
          Paint()
            ..color = part == RepairPart.sun
                ? const Color(0xFFFFC233)
                : const Color(0xFFF4847B));
      if (part == RepairPart.sun) {
        c.drawCircle(
            const Offset(0, 6), 7, Paint()..color = const Color(0xFFFFF2BD));
      }
    } else {
      GaragePainter.rect(
          c, const Rect.fromLTWH(-23, -23, 46, 46), const Color(0xFF9A8CDD),
          radius: 10);
      c.drawCircle(
          const Offset(0, 0), 13, Paint()..color = const Color(0xFFF2EFFF));
      c.drawCircle(
          const Offset(7, -5), 11, Paint()..color = const Color(0xFF9A8CDD));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _PartPainter oldDelegate) =>
      oldDelegate.part != part;
}
