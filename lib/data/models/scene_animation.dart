import 'package:flutter/foundation.dart';

/// A row of genuine action frames in a fixed-grid atlas.
///
/// Frame artwork must be reviewed against the page narration and original
/// character reference before this metadata is attached to a published page.
@immutable
class SceneAnimation {
  const SceneAnimation({
    required this.asset,
    required this.columns,
    required this.rows,
    required this.row,
    required this.frameCount,
    this.fps = 2,
    this.posterFrame = 0,
    this.cue,
    this.description = '',
    this.loop = true,
    this.frameCues = const [],
  });

  final String asset;
  final int columns;
  final int rows;
  final int row;
  final int frameCount;
  final double fps;
  final int posterFrame;

  /// Exact phrase in the narration at which the action starts.
  final String? cue;

  /// Meaningful alternative text describing the scene and action.
  final String description;
  final bool loop;

  /// Ordered phrases that trigger individual poses in a multi-step action.
  /// Empty means a continuous loop or a sequence paced across the narration.
  final List<String> frameCues;

  bool get isValid =>
      asset.trim().isNotEmpty &&
      columns >= 1 &&
      columns <= 32 &&
      rows >= 1 &&
      rows <= 32 &&
      row >= 0 &&
      row < rows &&
      frameCount >= 1 &&
      frameCount <= columns &&
      fps.isFinite &&
      fps >= 0.2 &&
      fps <= 24 &&
      posterFrame >= 0 &&
      posterFrame < frameCount &&
      (cue == null || cue!.length <= 500) &&
      description.length <= 1000 &&
      (frameCues.isEmpty ||
          (!loop &&
              frameCues.length == frameCount &&
              frameCues
                  .every((cue) => cue.trim().isNotEmpty && cue.length <= 500)));

  /// Bad remote metadata should never make the story unreadable.
  static SceneAnimation? tryParse(Object? value) {
    if (value is! Map) return null;
    int? integer(String key) {
      final number = value[key];
      return number is num &&
              number.isFinite &&
              number == number.roundToDouble()
          ? number.toInt()
          : null;
    }

    final asset = value['asset'];
    final columns = integer('columns');
    final rows = integer('rows');
    final row = integer('row');
    final count = integer('frameCount');
    final fps = value['fps'] ?? 2;
    final poster =
        value.containsKey('posterFrame') ? integer('posterFrame') : 0;
    final cue = value['cue'];
    final description = value['description'] ?? '';
    final loop = value['loop'] ?? true;
    final frameCues = value['frameCues'] ?? const <String>[];
    if (asset is! String ||
        columns == null ||
        rows == null ||
        row == null ||
        count == null ||
        fps is! num ||
        poster == null ||
        (cue != null && cue is! String) ||
        description is! String ||
        loop is! bool ||
        frameCues is! List ||
        frameCues.any((cue) => cue is! String)) {
      return null;
    }
    final result = SceneAnimation(
      asset: asset,
      columns: columns,
      rows: rows,
      row: row,
      frameCount: count,
      fps: fps.toDouble(),
      posterFrame: poster,
      cue: cue as String?,
      description: description,
      loop: loop,
      frameCues: List.unmodifiable(frameCues.cast<String>()),
    );
    return result.isValid ? result : null;
  }

  Map<String, dynamic> toJson() => {
        'asset': asset,
        'columns': columns,
        'rows': rows,
        'row': row,
        'frameCount': frameCount,
        'fps': fps,
        'posterFrame': posterFrame,
        if (cue != null) 'cue': cue,
        if (description.isNotEmpty) 'description': description,
        'loop': loop,
        if (frameCues.isNotEmpty) 'frameCues': frameCues,
      };

  bool sameAs(SceneAnimation other) =>
      asset == other.asset &&
      columns == other.columns &&
      rows == other.rows &&
      row == other.row &&
      frameCount == other.frameCount &&
      fps == other.fps &&
      posterFrame == other.posterFrame &&
      cue == other.cue &&
      description == other.description &&
      loop == other.loop &&
      listEquals(frameCues, other.frameCues);
}
