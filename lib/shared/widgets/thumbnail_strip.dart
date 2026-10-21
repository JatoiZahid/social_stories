import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'scene_image.dart';

/// Horizontal row of page thumbnails joined by small diamonds.
/// The selected page is outlined and kept scrolled into view.
class ThumbnailStrip extends StatefulWidget {
  const ThumbnailStrip({
    super.key,
    required this.frames,
    required this.selectedIndex,
    required this.onSelected,
    this.itemWidth = 84,
    this.height = 66,
  });

  final List<SceneFrame> frames;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double itemWidth;
  final double height;

  @override
  State<ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<ThumbnailStrip> {
  static const double _gap = 22;
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(ThumbnailStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _scrollToSelected();
  }

  void _scrollToSelected() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final itemStart = widget.selectedIndex * (widget.itemWidth + _gap);
    final centred = itemStart - (position.viewportDimension - widget.itemWidth) / 2;
    _scroll.animateTo(
      centred.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        itemCount: widget.frames.length,
        separatorBuilder: (_, __) => const SizedBox(width: _gap, child: Center(child: _Connector())),
        itemBuilder: (context, index) => SizedBox(
          width: widget.itemWidth,
          child: _Thumbnail(
            frame: widget.frames[index],
            selected: index == widget.selectedIndex,
            label: 'Go to page ${index + 1}',
            onTap: () => widget.onSelected(index),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.frame,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final SceneFrame frame;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusM),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: selected ? 1 : 0.7,
            child: SceneImage(frame: frame, radius: AppDimens.radiusS),
          ),
        ),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: const SizedBox.square(
        dimension: 6,
        child: DecoratedBox(decoration: BoxDecoration(color: AppColors.border)),
      ),
    );
  }
}
