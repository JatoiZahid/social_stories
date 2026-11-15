import 'package:flutter/material.dart';

import 'puzzle_catalog.dart';
import 'puzzle_game_screen.dart';

class PuzzlePieceCountScreen extends StatelessWidget {
  const PuzzlePieceCountScreen(
      {super.key, required this.puzzle, required this.playlist});
  final PicturePuzzle puzzle;
  final List<PicturePuzzle> playlist;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Choose your pieces')),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                        aspectRatio: puzzle.aspectRatio,
                        child: Image.asset(puzzle.asset, fit: BoxFit.contain)),
                    Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          Text(puzzle.title,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final count in [6, 9])
                                FilledButton.icon(
                                  key: ValueKey('puzzle-size-$count'),
                                  icon: const Icon(Icons.extension_rounded),
                                  label: Text('$count pieces'),
                                  onPressed: () =>
                                      Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                        builder: (_) => PuzzleGameScreen(
                                            puzzle: puzzle,
                                            pieceCount: count,
                                            playlist: playlist)),
                                  ),
                                ),
                            ],
                          ),
                        ])),
                  ],
                )),
          ),
        ))),
      );
}
