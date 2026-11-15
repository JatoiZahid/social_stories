import 'package:flutter/material.dart';

import '../../shared/widgets/settings_sheet.dart';
import 'puzzle_catalog.dart';
import 'puzzle_piece_count_screen.dart';

class PuzzleLibraryScreen extends StatefulWidget {
  const PuzzleLibraryScreen({super.key});

  @override
  State<PuzzleLibraryScreen> createState() => _PuzzleLibraryScreenState();
}

class _PuzzleLibraryScreenState extends State<PuzzleLibraryScreen> {
  String? _character;

  @override
  Widget build(BuildContext context) {
    final characters = {
      for (final puzzle in PicturePuzzle.all)
        puzzle.character: puzzle.characterName,
    };
    final puzzles = PicturePuzzle.all
        .where((p) => _character == null || p.character == _character)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Picture puzzles'), actions: [
        IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => SettingsSheet.show(context)),
      ]),
      body: SafeArea(
          child: Column(children: [
        SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: const Text('All'),
                        selected: _character == null,
                        onSelected: (_) => setState(() => _character = null))),
                for (final entry in characters.entries)
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          label: Text(entry.value),
                          selected: _character == entry.key,
                          onSelected: (_) =>
                              setState(() => _character = entry.key))),
              ],
            )),
        Expanded(
            child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisExtent: 210,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16),
          itemCount: puzzles.length,
          itemBuilder: (context, index) {
            final puzzle = puzzles[index];
            return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('open-puzzle-${puzzle.id}'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => PuzzlePieceCountScreen(
                              puzzle: puzzle, playlist: puzzles))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: Image.asset(puzzle.asset, fit: BoxFit.cover)),
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(puzzle.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(puzzle.characterName,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          )),
                    ],
                  ),
                ));
          },
        )),
      ])),
    );
  }
}
