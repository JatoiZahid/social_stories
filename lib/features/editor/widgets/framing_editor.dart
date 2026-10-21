import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/widgets.dart';

/// Quick framing choices for a page's picture.
enum FramingPreset {
  whole('Whole picture', Alignment.center, 1),
  closeUp('Close-up', Alignment.center, 1.5),
  left('Left side', Alignment.centerLeft, 1.5),
  right('Right side', Alignment.centerRight, 1.5),
  top('Top', Alignment.topCenter, 1.5),
  bottom('Bottom', Alignment.bottomCenter, 1.5);

  const FramingPreset(this.label, this.focus, this.zoom);

  final String label;
  final Alignment focus;
  final double zoom;

  bool matches(Alignment focus, double zoom) =>
      (this.focus.x - focus.x).abs() < 0.01 &&
      (this.focus.y - focus.y).abs() < 0.01 &&
      (this.zoom - zoom).abs() < 0.01;
}

/// Live preview of a page picture. Drag (or pinch) to choose which part
/// shows; the slider and preset chips set the zoom.
class FramingEditor extends StatefulWidget {
  const FramingEditor({
    super.key,
    required this.frame,
    required this.onChanged,
    this.onDragging,
  });

  static const double minZoom = 1;
  static const double maxZoom = 2;

  final SceneFrame frame;
  final void Function(Alignment focus, double zoom) onChanged;

  /// True while a finger is on the preview. Parents use it to stop the
  /// surrounding page from scrolling so the drag moves the picture.
  final ValueChanged<bool>? onDragging;

  @override
  State<FramingEditor> createState() => _FramingEditorState();
}

class _FramingEditorState extends State<FramingEditor> {
  double _zoomAtGestureStart = 1;
  int _pointers = 0;

  void _pointerDown(PointerDownEvent _) {
    if (_pointers++ == 0) widget.onDragging?.call(true);
  }

  void _pointerUp(PointerEvent _) {
    if (_pointers > 0 && --_pointers == 0) widget.onDragging?.call(false);
  }

  Alignment get _focus => widget.frame.focus;
  double get _zoom => widget.frame.zoom;

  void _onScaleStart(ScaleStartDetails details) => _zoomAtGestureStart = _zoom;

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    final zoom = (_zoomAtGestureStart * details.scale)
        .clamp(FramingEditor.minZoom, FramingEditor.maxZoom)
        .toDouble();
    var focus = _focus;
    if (zoom > 1.01) {
      // Dragging right should reveal more of the left side, so the focus
      // moves the opposite way. Scaled so the picture follows the finger.
      final dx = -details.focalPointDelta.dx * 2 / ((zoom - 1) * size.width);
      final dy = -details.focalPointDelta.dy * 2 / ((zoom - 1) * size.height);
      focus = Alignment(
        (focus.x + dx).clamp(-1.0, 1.0).toDouble(),
        (focus.y + dy).clamp(-1.0, 1.0).toDouble(),
      );
    }
    widget.onChanged(focus, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1.2,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return Listener(
                onPointerDown: _pointerDown,
                onPointerUp: _pointerUp,
                onPointerCancel: _pointerUp,
                child: GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: (details) => _onScaleUpdate(details, size),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SceneImage(frame: widget.frame),
                    Positioned(
                      left: AppDimens.gapS,
                      bottom: AppDimens.gapS,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.ink.withAlpha(150),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text(
                            _zoom > 1.01 ? 'Drag to move · pinch to zoom' : 'Pinch or use the slider to zoom',
                            style: textTheme.labelSmall?.copyWith(color: AppColors.onPrimary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppDimens.gapS),
        Row(
          children: [
            const Icon(Icons.zoom_out_rounded, color: AppColors.inkSoft),
            Expanded(
              child: Slider(
                value: _zoom.clamp(FramingEditor.minZoom, FramingEditor.maxZoom).toDouble(),
                min: FramingEditor.minZoom,
                max: FramingEditor.maxZoom,
                label: '${(_zoom * 100).round()}%',
                onChanged: (zoom) => widget.onChanged(_focus, zoom),
              ),
            ),
            const Icon(Icons.zoom_in_rounded, color: AppColors.inkSoft),
          ],
        ),
        Wrap(
          spacing: AppDimens.gapS,
          runSpacing: AppDimens.gapS,
          children: [
            for (final preset in FramingPreset.values)
              ChoiceChip(
                label: Text(preset.label),
                selected: preset.matches(_focus, _zoom),
                onSelected: (_) => widget.onChanged(preset.focus, preset.zoom),
              ),
          ],
        ),
      ],
    );
  }
}
