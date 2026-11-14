# Repository audit and preview proposal — 2 November 2026

Status: inspected; isolated preview authorized by the supplied master instruction. Production integration is NOT approved.

## Baseline
- Started on `main`, clean working tree. Created `preview/fix-my-broken-car`; no existing changes to preserve.
- `flutter analyze`: zero issues. `flutter test`: 54 passing tests.
- Android debug baseline build passed. Device discovery initially found no connected device; the existing Pixel_10 emulator was subsequently started and native baseline library/story screenshots were captured.
- No independent approved Figma export or screenshot files found in docs/dist. README and source refer to Figma but do not include its original design. Comparison can establish consistency with implemented UI/assets only, not fidelity to an unavailable original.

## Actual architecture and reuse
- `lib/main.dart::main` creates `AppSettings`, `TtsNarrator`, `StoryStore`, `AccountService`, then `StorybookApp`.
- `lib/app.dart::StorybookApp.build` installs `AppScope`, `AppTheme.light`, `MaterialApp`, `LibraryScreen`. Navigation uses imperative `Navigator` routes, not a routing package.
- `lib/features/library/library_screen.dart::_open` pushes `StoryScreen.route` or `StoryEditorScreen.route`. `_StoryGrid` renders story covers.
- `assets/data/stories.json` is the bundled registry; `StoryRepository.loadStories` parses it. `StoryStore.load`, `refresh`, draft/publish operations preserve cached server content and local drafts.
- `lib/data/models/story.dart::Story`, `StoryPage`, `StoryQuestion` model content; `StoryPage.narration` combines lead/body. `scene_catalog.dart` and `scene_asset_upgrade.dart` manage available scenes and legacy content upgrades.
- `StoryScreen._goTo`, `_onPageChanged`, `_next`, `_narrate`, `_pause`, `_resume`, `_stopScene` coordinate navigation, narration and completion. Completion is a dialog/optional quiz; no persistent child completion/progress ledger found.
- `StoryPageView.build` stacks art/narration in portrait and switches to side by side for landscape at the existing breakpoint. Short landscape screens receive compact controls.
- `AnimatedStoryScene._resolve` decodes one sprite atlas. `sceneFrameAt` chooses illustrated poses on `ScenePlayback` timing/word cues; `SceneAtlasPainter` draws contained atlas cells. Scene backgrounds/characters are baked into these atlas frames, not separable articulated game objects. No Flame/Rive dependency. CustomPainter and Flutter state/gestures are already supported.
- `Narrator`, `TtsNarrator`, `ResumableNarrator`, `SilentNarrator` offer speech, stop, pause/resume and test substitution. No speech recognition or dedicated AAC engine found. Preview picture/touch communication will call this actual narrator without requiring speech.
- `AppSettings` exposes autoRead, speechRate, largeText, reducedMotion; settings currently live in memory. Preview must not claim persistence the app does not provide.
- `SettingsSheet.show` uses `ParentGate.show` before account/editing controls. No unrelated parent/settings changes proposed.
- Editor uses drag reorder and `FramingEditor` pinch/drag. No existing child mini-game, repair controller, or drag/drop matching component found.
- `AppColors`, `AppDimens`, `AppTheme.light` define blue #1F6FEB, pale #EDF4FC backdrop, white rounded cards, 48px minimum targets, Nunito and 18/24px radii. Reuse `AppCard`, `ScreenHeader`, `RoundIconButton`, `PillButton`, `NarrationCard` directly.
- Assets: `assets/images/stories` covers, `assets/images/story_scenes` posters, `assets/animations/spritesheets` action atlases. Existing art is warm, softly shaded colorful 2D cartoon illustration.

## Approved story status
All twelve requested entries are absent from the bundled registry: My Haircut Experience; The Ant and the Pigeon; The Lion and the Mouse; The Thirsty Crow; The Hare and the Tortoise; The Fox and the Grapes; The Monkey and the Crocodile; The Clever Rabbit and the Lion; The Boy Who Cried Wolf; My Haircut Visit; My Car is Broken; The Ant and the Grasshopper.
Existing twelve stories are different: Going to School (6 scenes), Going to the Toilet (8), Going to the Doctor (6), Brushing Teeth (6), Restaurant (6), Airport (7), Playground (6), Sharing (6), Asking for Help (6), Personal Space (6), Saying No (6), Staying Safe (6). Preserve all 75 scenes. Server/account-specific stories cannot be inventoried without a configured authenticated source. Do not duplicate/replace any existing story.

## First preview proposal
- A separate `lib/preview/car_preview_main.dart` entry point, never referenced by production `main.dart`, library or registry. Build with `flutter run -t lib/preview/car_preview_main.dart` or `flutter build apk --debug -t lib/preview/car_preview_main.dart`.
- Eight views in one controlled sequence: introduction, garage exploration, wheel, engine, wrench, toy power, test drive, celebration.
- Real DragTarget/Draggable matching for wheel and engine; wrench attaches to bolt then visibly rotates through guided turns; two differently shaped power pieces snap into distinct slots; Start/Go/Stop drive has continuous wheel/body/road motion and finish-marker gating.
- Accessible alternative: select a pictured part then tap its matching target. Wrong choices gently retry. Speech is optional. Easy/medium/advanced alter guidance and ordered actions. Single word/phrase/sentence communication choices reuse TTS.
- Pause, lifecycle background handling, current-mission replay, full replay, sound and reduced motion are preview-local. No production progress/storage schema changes.
- New matching garage raster asset; independently drawn/animated car body, eyes, wheels, lights, tools and targets. An atlas of baked backgrounds cannot provide exact dragged-object contact, so add a small isolated custom-painted game scene rather than alter the story renderer.
- Likely files: only new `lib/preview/**`, preview tests, `docs/car_preview/**`, and new artwork under the already bundled scene-assets directory. No dependencies needed.
- Risks: drop geometry at different aspect ratios, rapid actions skipping steps, audio overlapping after background/replay, reduced motion, large-text/short landscape overflow, generated background style consistency. Verify guarded state transitions, drag success/failure/interruption, layouts, actual rendered frames and Android build/runtime if available.
- Visual differences requiring review: new garage subject and expressive toy-car character. Shared chrome, typography, narration and spacing stay based on the implemented app. Await explicit approval before catalog integration, merging or publishing.

