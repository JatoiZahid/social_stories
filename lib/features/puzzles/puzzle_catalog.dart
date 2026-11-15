import 'package:flutter/foundation.dart';

@immutable
class PicturePuzzle {
  const PicturePuzzle(
      this.character, this.characterName, this.scene, this.title,
      {this.featuredCharacters = const [], this.aspectRatio = 768 / 342});

  final String character;
  final String characterName;
  final int scene;
  final String title;
  final List<String> featuredCharacters;
  final double aspectRatio;
  List<String> get characters =>
      featuredCharacters.isEmpty ? [character] : featuredCharacters;
  String get id => '$character-$scene';
  String get asset => 'assets/images/puzzles/${character}_$scene.png';

  static const all = [
    PicturePuzzle('bluey', 'Bluey', 1, 'Kite Day'),
    PicturePuzzle('bluey', 'Bluey', 2, 'Sunflower Garden'),
    PicturePuzzle('bluey', 'Bluey', 3, 'Block Tower'),
    PicturePuzzle('bluey', 'Bluey', 4, 'Little Sailboat'),
    PicturePuzzle('bluey', 'Bluey', 5, 'Rainbow Painting'),
    PicturePuzzle('bingo', 'Bingo', 1, 'Park Picnic'),
    PicturePuzzle('bingo', 'Bingo', 2, 'Butterfly Meadow'),
    PicturePuzzle('bingo', 'Bingo', 3, 'Sandcastle Fun'),
    PicturePuzzle('bingo', 'Bingo', 4, 'Starry Evening'),
    PicturePuzzle('bingo', 'Bingo', 5, 'Music Time'),
    PicturePuzzle('dora', 'Dora', 1, 'Butterfly Garden'),
    PicturePuzzle('dora', 'Dora', 2, 'Woodland Map'),
    PicturePuzzle('dora', 'Dora', 3, 'Sunflower Pot'),
    PicturePuzzle('dora', 'Dora', 4, 'Colorful Blocks'),
    PicturePuzzle('dora', 'Dora', 5, 'Paper Boat'),
    PicturePuzzle('sonic', 'Sonic', 1, 'Meadow Jog'),
    PicturePuzzle('sonic', 'Sonic', 2, 'Kite in the Park'),
    PicturePuzzle('sonic', 'Sonic', 3, 'Block Builder'),
    PicturePuzzle('sonic', 'Sonic', 4, 'Daisy Garden'),
    PicturePuzzle('sonic', 'Sonic', 5, 'Picnic Basket'),
    PicturePuzzle('ant_grasshopper', 'Ant & Grasshopper', 1, 'Seed Baskets',
        featuredCharacters: ['ant', 'grasshopper'], aspectRatio: 4 / 3),
    PicturePuzzle('ant_grasshopper', 'Ant & Grasshopper', 2, 'Leaf Shelter',
        featuredCharacters: ['ant', 'grasshopper'], aspectRatio: 4 / 3),
    PicturePuzzle('ant_grasshopper', 'Ant & Grasshopper', 3, 'Meadow Music',
        featuredCharacters: ['ant', 'grasshopper'], aspectRatio: 4 / 3),
    PicturePuzzle('ant_grasshopper', 'Ant & Grasshopper', 4, 'Winter Sharing',
        featuredCharacters: ['ant', 'grasshopper'], aspectRatio: 4 / 3),
    PicturePuzzle('ant_grasshopper', 'Ant & Grasshopper', 5, 'Spring Planting',
        featuredCharacters: ['ant', 'grasshopper'], aspectRatio: 4 / 3),
  ];
}
