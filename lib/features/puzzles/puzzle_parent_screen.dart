import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

/// Opened only after the existing grown-ups gate; independent of subscriptions.
class PuzzleParentScreen extends StatelessWidget {
  const PuzzleParentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle settings')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Puzzle background',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('Choose how much picture guidance your child sees. '
            'Your choice is saved on this device.'),
        const SizedBox(height: 20),
        SegmentedButton<bool>(
          key: const ValueKey('puzzle-background-choice'),
          segments: const [
            ButtonSegment(
                value: true,
                label: Text('Blurred guide'),
                icon: Icon(Icons.blur_on_rounded)),
            ButtonSegment(
                value: false,
                label: Text('Plain'),
                icon: Icon(Icons.crop_square_rounded)),
          ],
          selected: {settings.puzzleBlurredBackground},
          onSelectionChanged: (selection) =>
              settings.puzzleBlurredBackground = selection.single,
        ),
        const SizedBox(height: 16),
        Text(settings.puzzleBlurredBackground
            ? 'Blurred guide: a soft copy of the picture helps your child find each space. This is the default.'
            : 'Plain: empty spaces have no picture underneath. Placed pieces stay visible.'),
      ]),
    );
  }
}
