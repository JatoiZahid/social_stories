# Picture puzzles

Social Stories has a new, independent picture-puzzle feature. The WonderPlay
project was inspected as a reference and was not modified. Its scenes and source
were not copied. The existing elephant launcher icon is unchanged.

Open **Play picture puzzles** from the story library. Filter by Bluey, Bingo,
Dora, Sonic, or Ant & Grasshopper: each set has five distinct scenes (25 puzzles
total). Ant and Grasshopper appear together in every scene in their set.
After selecting a picture, choose 6 or 9 pieces on its preview card. Then drag
a piece into its matching space or tap the piece followed by its space. Incorrect matches leave the piece available; a
completed board shows a short celebration and advances after two seconds.
The next puzzle keeps the chosen piece count and the active character filter.
After the last puzzle in the set, play continues with the first one.
The four-piece option is hidden from the child flow.

Under **Settings > Puzzle settings**, pass the grown-ups gate to choose:

- **Blurred guide** (default): a soft, faint copy of the picture is visible
  under the board.
- **Plain**: empty spaces contain no picture. Placed pieces remain visible.

The choice is saved on this device using `puzzle_preferences_v1`. Missing or
unrecognized saved values restore the blurred default. This parent control does
not require sign-in or a subscription. Children cannot change it in the player.

All 25 pictures are bundled for offline use in `assets/images/puzzles/`.
Artwork was generated using the built-in imagegen tool as six-panel sheets;
five panels per set were used. Initial prompts are recorded in
`puzzle_artwork_prompts.json`; expansion prompts and new story notes are in
`content_expansion/`. There are no pig characters in this collection.

Validation: `flutter test test/puzzles_test.dart test/widget_test.dart`.

Cars, Mario & Luigi, and Mickey & Minnie are queued at the user's request until
artwork is available; they are not displayed as playable puzzles. See
`content_expansion/queued_puzzles.json` for the fifteen planned scenes.
