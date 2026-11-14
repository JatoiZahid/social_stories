import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../core/theme/app_colors.dart';
import 'repair_game.dart';

/// A downward handle stroke must travel before it counts; holding a pointer
/// still or moving sideways cannot inflate the tyre.
class PumpStation extends StatefulWidget {
  const PumpStation({super.key, required this.game});
  final RepairGame game;
  @override
  State<PumpStation> createState() => _PumpStationState();
}

class _PumpStationState extends State<PumpStation> {
  double drag = 0;
  bool counted = false;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Pump tyre',
        button: true,
        onTap: widget.game.paused ? null : widget.game.pump,
        child: GestureDetector(
          key: const ValueKey('pump-handle'),
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) {
            drag = 0;
            counted = false;
          },
          onVerticalDragUpdate: (details) {
            if (widget.game.paused || counted) return;
            setState(() => drag = (drag + details.delta.dy).clamp(0, 30));
            if (drag >= 12) {
              counted = true;
              widget.game.pump();
            }
          },
          onVerticalDragEnd: (_) => setState(() => drag = 0),
          onVerticalDragCancel: () => setState(() => drag = 0),
          child: CustomPaint(
              painter: _PumpPainter(widget.game.pumpStrokes, drag / 30)),
        ),
      );
}

class _PumpPainter extends CustomPainter {
  _PumpPainter(this.strokes, this.press);
  final int strokes;
  final double press;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 150, size.height / 200);
    final paint = Paint()..strokeCap = StrokeCap.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(35, 80, 62, 94), const Radius.circular(16)),
        paint..color = AppColors.primary);
    canvas.drawLine(
        Offset(66, 35 + press * 42),
        const Offset(66, 110),
        paint
          ..color = const Color(0xFFCBD9E5)
          ..strokeWidth = 10);
    canvas.drawLine(
        Offset(29, 35 + press * 42),
        Offset(103, 35 + press * 42),
        paint
          ..color = const Color(0xFF233B55)
          ..strokeWidth = 14);
    canvas.drawLine(
        const Offset(25, 180),
        const Offset(112, 180),
        paint
          ..color = const Color(0xFF233B55)
          ..strokeWidth = 12);
    final hose = Path()
      ..moveTo(95, 150)
      ..quadraticBezierTo(145, 168, 137, 99)
      ..quadraticBezierTo(140, 60, 120, 70);
    canvas.drawPath(
        hose,
        paint
          ..color = const Color(0xFF344B63)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(66, 126), 22, paint..color = Colors.white);
    final angle = math.pi * (.8 + strokes / 3 * 1.4);
    canvas.drawLine(
        const Offset(66, 126),
        Offset(66 + math.cos(angle) * 16, 126 + math.sin(angle) * 16),
        paint
          ..color = strokes == 3 ? Colors.green : const Color(0xFFEF9956)
          ..strokeWidth = 4);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PumpPainter oldDelegate) =>
      oldDelegate.strokes != strokes || oldDelegate.press != press;
}

class WrenchGesture extends StatefulWidget {
  const WrenchGesture({super.key, required this.game});
  final RepairGame game;
  @override
  State<WrenchGesture> createState() => _WrenchGestureState();
}

class _WrenchGestureState extends State<WrenchGesture> {
  double? previous;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        double angle(Offset point) => math.atan2(
            point.dy - box.maxHeight / 2, point.dx - box.maxWidth / 2);
        void update(DragUpdateDetails details) {
          final next = angle(details.localPosition);
          var delta = next - (previous ?? next);
          if (delta > math.pi) delta -= 2 * math.pi;
          if (delta < -math.pi) delta += 2 * math.pi;
          previous = next;
          widget.game.rotateWrench(delta);
        }

        return Semantics(
            label: 'Rotate wrench clockwise',
            button: true,
            onTap: widget.game.paused ? null : widget.game.turn,
            child: GestureDetector(
              key: const ValueKey('wrench-gesture'),
              dragStartBehavior: DragStartBehavior.down,
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) =>
                  previous = angle(details.localPosition),
              onVerticalDragStart: (details) =>
                  previous = angle(details.localPosition),
              onHorizontalDragUpdate: update,
              onVerticalDragUpdate: update,
              onHorizontalDragEnd: (_) => previous = null,
              onVerticalDragEnd: (_) => previous = null,
              onHorizontalDragCancel: () => previous = null,
              onVerticalDragCancel: () => previous = null,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.celebrate.withAlpha(180), width: 3)),
                  child: const Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.rotate_right_rounded,
                          color: AppColors.celebrate, size: 28))),
            ));
      });
}
