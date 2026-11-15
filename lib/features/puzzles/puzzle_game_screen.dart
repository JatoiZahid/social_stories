import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import 'puzzle_catalog.dart';

class PuzzleGameScreen extends StatefulWidget {
  const PuzzleGameScreen(
      {super.key,
      required this.puzzle,
      this.random,
      this.pieceCount = 6,
      this.playlist})
      : assert(pieceCount == 6 || pieceCount == 9);
  final PicturePuzzle puzzle;
  final Random? random;
  final int pieceCount;
  final List<PicturePuzzle>? playlist;

  @override
  State<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends State<PuzzleGameScreen>
    with WidgetsBindingObserver {
  int get _count => widget.pieceCount;
  late PicturePuzzle _puzzle;
  late final List<PicturePuzzle> _playlist;
  Timer? _completionTimer;
  int? _selected;
  final Set<int> _placed = {};
  late List<int> _order;
  String _message = 'Pick a piece, then tap its space. You can drag too!';
  int get _rows => _count == 9 ? 3 : 2;
  int get _cols => 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _puzzle = widget.puzzle;
    final candidates = widget.playlist ?? PicturePuzzle.all;
    _playlist = candidates.any((p) => p.id == _puzzle.id)
        ? List.unmodifiable(candidates)
        : [_puzzle];
    _shuffle();
  }

  void _shuffle() {
    _order = List.generate(_count, (i) => i)
      ..shuffle(widget.random ?? Random());
  }

  void _restart() {
    _completionTimer?.cancel();
    setState(() {
      _placed.clear();
      _selected = null;
      _message = 'Pick a piece, then tap its space. You can drag too!';
      _shuffle();
    });
  }

  void _scheduleNext() {
    _completionTimer?.cancel();
    _completionTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) _advance();
    });
  }

  void _advance() {
    _completionTimer?.cancel();
    final index = _playlist.indexWhere((p) => p.id == _puzzle.id);
    setState(() {
      _puzzle = _playlist[(index + 1) % _playlist.length];
      _placed.clear();
      _selected = null;
      _message = 'Pick a piece, then tap its space. You can drag too!';
      _shuffle();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _completionTimer?.cancel();
    if (state == AppLifecycleState.resumed && _placed.length == _count) {
      _scheduleNext();
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _place(int piece, int space) {
    if (_placed.contains(piece) || _placed.contains(space)) return;
    setState(() {
      if (piece != space) {
        _selected = piece;
        _message = 'Try another space. Take your time!';
        return;
      }
      _placed.add(piece);
      _selected = null;
      _message = _placed.length == _count
          ? 'You did it! Your picture is complete!'
          : 'Nice match! Choose your next piece.';
    });
    if (_placed.length == _count) _scheduleNext();
  }

  Widget _slice(int index) =>
      PuzzleSlice(asset: _puzzle.asset, index: index, rows: _rows, cols: _cols);

  Widget _board(bool blurred) => Center(
        child: AspectRatio(
          aspectRatio: _puzzle.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: const Color(0xFFFFF5DF),
              child: Stack(children: [
                if (blurred)
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: Opacity(
                        opacity: 0.45,
                        child: ImageFiltered(
                          key: const ValueKey('puzzle-blurred-guide'),
                          imageFilter:
                              ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Image.asset(_puzzle.asset, fit: BoxFit.fill),
                        ),
                      ),
                    ),
                  ),
                GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  crossAxisCount: _cols,
                  childAspectRatio: _puzzle.aspectRatio * _rows / _cols,
                  children: [
                    for (var i = 0; i < _count; i++)
                      DragTarget<int>(
                        onWillAcceptWithDetails: (details) =>
                            !_placed.contains(i),
                        onAcceptWithDetails: (details) =>
                            _place(details.data, i),
                        builder: (context, candidates, rejected) => Semantics(
                          label:
                              'Space ${i + 1}${_placed.contains(i) ? ', complete' : ''}',
                          button: !_placed.contains(i),
                          child: GestureDetector(
                            key: ValueKey('puzzle-space-$i'),
                            onTap: () {
                              if (_selected != null) _place(_selected!, i);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: candidates.isNotEmpty
                                      ? AppColors.primary
                                      : AppColors.ink.withValues(alpha: 0.18),
                                  width: candidates.isNotEmpty ? 3 : 1,
                                ),
                              ),
                              child: _placed.contains(i) ? _slice(i) : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _tray(bool landscape) => GridView.builder(
        key: const ValueKey('puzzle-piece-tray'),
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: landscape ? 2 : 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: min(1.5, _puzzle.aspectRatio * _rows / _cols),
        ),
        itemCount: _count,
        itemBuilder: (context, position) {
          final piece = _order[position];
          if (_placed.contains(piece)) return const SizedBox.shrink();
          return LayoutBuilder(builder: (context, box) {
            final tile = Semantics(
              label: 'Piece ${piece + 1}',
              button: true,
              selected: _selected == piece,
              child: GestureDetector(
                key: ValueKey('puzzle-piece-$piece'),
                onTap: () => setState(() => _selected = piece),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          _selected == piece ? AppColors.primary : Colors.white,
                      width: 3,
                    ),
                  ),
                  child: Center(
                      child: AspectRatio(
                          aspectRatio: _puzzle.aspectRatio * _rows / _cols,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: _slice(piece)))),
                ),
              ),
            );
            return Draggable<int>(
              data: piece,
              feedback: Material(
                elevation: 8,
                child: SizedBox(
                    width: box.maxWidth,
                    height:
                        box.maxWidth / (_puzzle.aspectRatio * _rows / _cols),
                    child: _slice(piece)),
              ),
              childWhenDragging: Opacity(opacity: 0.25, child: tile),
              child: tile,
            );
          });
        },
      );

  @override
  Widget build(BuildContext context) {
    final blurred = AppScope.of(context).settings.puzzleBlurredBackground;
    final complete = _placed.length == _count;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_puzzle.characterName}: ${_puzzle.title}'),
        actions: [
          IconButton(
            tooltip: 'Start again',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _restart,
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            const SizedBox(height: 8),
            Semantics(
                liveRegion: true,
                child: Text('${_placed.length} of $_count pieces',
                    key: const ValueKey('puzzle-progress'))),
            const SizedBox(height: 8),
            Expanded(child: LayoutBuilder(builder: (context, box) {
              final landscape = box.maxWidth > box.maxHeight * 1.25;
              return Flex(
                direction: landscape ? Axis.horizontal : Axis.vertical,
                children: [
                  Expanded(
                      flex: 6,
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _board(blurred))),
                  Expanded(
                      flex: 4,
                      child: complete
                          ? Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.6, end: 1),
                                    duration: AppScope.of(context)
                                                .settings
                                                .reducedMotion ||
                                            MediaQuery.of(context)
                                                .disableAnimations
                                        ? Duration.zero
                                        : const Duration(milliseconds: 450),
                                    builder: (context, scale, child) =>
                                        Transform.scale(
                                            scale: scale, child: child),
                                    child: const Icon(Icons.stars_rounded,
                                        color: AppColors.celebrate, size: 56),
                                  ),
                                  const Text('Great job!',
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold)),
                                  const Text('Your next puzzle is coming!'),
                                  FilledButton(
                                      key: const ValueKey('puzzle-next'),
                                      onPressed: _advance,
                                      child: const Text('Next puzzle')),
                                ]))
                          : _tray(landscape)),
                ],
              );
            })),
            Padding(
                padding: const EdgeInsets.all(12),
                child: Semantics(
                    liveRegion: true,
                    child: Text(_message, textAlign: TextAlign.center))),
          ]),
        ),
      ),
    );
  }
}

/// Clips a piece from the exact same uncropped picture as the guide board.
class PuzzleSlice extends StatelessWidget {
  const PuzzleSlice(
      {super.key,
      required this.asset,
      required this.index,
      required this.rows,
      required this.cols});
  final String asset;
  final int index, rows, cols;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: LayoutBuilder(
            builder: (context, box) => ClipRect(
                  child: OverflowBox(
                    alignment: Alignment(-1 + 2 * (index % cols) / (cols - 1),
                        -1 + 2 * (index ~/ cols) / (rows - 1)),
                    minWidth: box.maxWidth * cols,
                    maxWidth: box.maxWidth * cols,
                    minHeight: box.maxHeight * rows,
                    maxHeight: box.maxHeight * rows,
                    child: Image.asset(asset, fit: BoxFit.fill),
                  ),
                )),
      );
}
