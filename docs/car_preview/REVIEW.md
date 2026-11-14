# Fix My Broken Car — preview review

Status: **Preview created and verified in Flutter tests and Android gameplay; awaiting explicit approval.** No production catalog integration, merge, publication or story implementation has occurred.

Built from the existing application on `preview/fix-my-broken-car`. Repository inspection started 2 November; final verification is dated 3 November 2026 (Asia/Dubai).

## Play the preview
- APK: `dist/fix-my-broken-car-preview.apk` (debug test build, approximately 365 MiB because it retains the existing app asset bundle).
- Separate Android ID: `com.socialstories.social_stories.carpreview`; launcher label: **Car Game Preview**. It can coexist with the story app. Its preferences/progress do not alter story data.
- Rebuild: `powershell -ExecutionPolicy Bypass -File tools/build_car_preview.ps1`.
- Run from Flutter: `flutter run -t lib/preview/car_preview_main.dart --android-project-arg=carPreview=true`. The ordinary `lib/main.dart` still opens the original library.

## Eight views and working actions
1. Introduction: explains the five tasks; Let’s play enters the garage.
2. Exploration: touch the car, toggle lights, open/close the toolbox and inspect the pictured wrench.
3. Wheel: inspect the flat wheel, open the toolbox, choose between wheels, drag the correct wheel into its outline. Wrong wheels and interrupted drags do not repair it.
4. Engine: open the pretend bonnet; choose among gear, triangle and small wheel; place the yellow gear in the engine space.
5. Wrench: place the wrench over the bolt, then make three guided turns. Wrench rotation and bolt tightening are drawn at the contact point.
6. Toy power: match sun triangle and moon square, then press Power. In Advanced mode the sun must be placed first. Headlights illuminate.
7. Test drive: Start, Go, move through illustrated scenery with rotating wheels/body suspension, then Stop at the blue marker. Early Stop explains the target without losing progress. Completion requires reaching the marker and stopping.
8. Celebration: confetti/sparkles, happy car, and full Replay.

Every dragged object also supports select-then-tap placement. Touch/AAC choices at word, phrase and sentence levels call the actual existing narrator. Speech recognition is never required. Help gives the current action; Replay resets the mission; Pause and backgrounding hold gameplay. After backgrounding/preferences the child explicitly resumes. Settings include sound, reduced motion, large text and three difficulty levels. Difficulty changes target sizes and the advanced power ordering; it is an initial preview tuning, not a personalized adaptive learning algorithm.

## Visual evidence and comparison
- Baseline native screenshots: `baseline-library-android.png`, `baseline-story-android.png`.
- `screenshots/` contains all eight actual Flutter views at 360×800, 390×844, 768×1024, 1024×768, 1366×1024 and 800×360 (48 captures). These are Flutter widget-runtime rasterizations, not HTML mockups. Test captures use Arial glyphs in place of the default Ahem test font; native screenshots use the app’s actual theme/font.
- The screen captures were inspected against the implemented app. Existing `AppCard`, `ScreenHeader`, `RoundIconButton`, `PillButton`, `NarrationCard`, `AppColors`, `AppTheme` and spacing/radius conventions are reused. New garage/car/countryside artwork is softly shaded 2D illustration.
- Corrected during visual QA: flat initial body replaced by shaded transparent artwork, independent wheels aligned to arches, countryside upgraded to matching illustration, pause holds the animation pose, narrow targets retain at least 48px hit areas, enlarged-text dropdowns expand to available width.
- Narration remains outside essential artwork. Phone/short-landscape views scroll rather than shrink controls; extra communication choices can be below the initial viewport. Large narration panels scroll independently. Tablet/landscape use side-by-side scene/narration.
- Original approved Figma exports were unavailable. No claim of comparison with an unavailable design or of final design approval is made. Preserve this preview as the candidate reference; do not replace it with future goldens merely to pass tests.

## Automated verification
- Before changes: `flutter analyze` — zero issues; `flutter test` — 54 passed; ordinary Android debug build passed.
- Final: `flutter analyze` — zero issues; `flutter test --dart-define=WRITE_CAR_PREVIEWS=true` — **66 tests passed** (54 existing + 12 preview tests).
- The preview tests exercise state guards, wrong/correct/interrupted real drags, engine choice, tool attachment, repeated wrench turns, power shape mismatch/order, premature/valid stopping, pause timing, rotation while repairing, lifecycle resume, mission/full reset, sound-off preferences, reduced motion, 150% system text, and eight-view responsive rendering at six sizes.
- Existing tests continue to cover story library/navigation, settings/parent/account flows, story sync/drafts, narration playback/cues, all 75 bundled scene atlases and responsive story layouts.
- Analyzer and regression logs: `analyze.log`, `tests.log`. APK build log: `build.log`.
- Baseline and preview builds emit existing Java native-access and flutter_tts Kotlin-plugin migration warnings. These are not new preview regressions. No warnings/assertions were suppressed.

## Files and reuse
- New entry point: `lib/preview/car_preview_main.dart`.
- UI/lifecycle/TTS: `lib/preview/car/car_preview_screen.dart`.
- Guarded mission state: `lib/preview/car/repair_game.dart` (`next`, `accepts`, `drop`, `turn`, `power`, `advance`, `stop`, `replay`).
- Layered renderer: `lib/preview/car/garage_art.dart` (`GaragePainter`, `PartPicture`).
- Tests: `test/car_preview_test.dart`.
- Assets: `assets/images/story_scenes/car_preview_{garage,body,road}.png`. Original assets untouched. Exact prompts and generation method: `ASSET_PROMPTS.md`.
- Packaging helper: `tools/build_car_preview.ps1`.
- Two small Android extensions: `android/app/build.gradle.kts` enables the opt-in preview package/label via a Gradle property; `android/app/src/main/AndroidManifest.xml` reads that label. Default production ID and label are preserved.
- Audit/candidate evidence: `docs/car_preview/`. No dependencies were added. Production Dart files and `assets/data/stories.json` were not modified.

## Limitations and proposed integration
This is an approval preview. Preferences and mission progress are in memory; orientation and background/resume preserve the live state, but killing/restarting the process begins a new game. The original app has no persistent child-completion ledger to reuse. Audio uses current TTS; there is no recorded mechanical sound pack or speech recognition. Native iOS and physical-device/performance testing were not performed. Optional garage-door animation, free-spinning exploration wheels, personalized difficulty and sentence-building exercises remain future polish, rather than claims about this preview.

After explicit approval, propose one scoped production entry to this approved game, reuse app-wide settings/narrator via AppScope, decide completion persistence and parent access, preserve the approved visual captures, and repeat native/layout/regression checks. No story registry additions should accompany that integration. Obtain acceptance before starting any story preview. The two haircut stories and My Car is Broken/Fix My Broken Car remain separate planned experiences.

**Approval requested:** approve this car-game preview’s artwork, layout and repair interactions for scoped production integration, or specify revisions. No integration, merge or publication is authorized by this review package alone.


## Native Android verification — 3 November 2026
- Installed and launched the separate preview package on the existing Pixel_10 emulator. APK identity/launcher label were checked with Android aapt, not assumed from source.
- Completed all five missions using actual Android taps and drag gestures located through accessibility labels. Included wrong wheel, wrong engine shape and wrong power-slot attempts. Reached the 8-of-8 celebration and used full Replay back to the introduction. See `native-interactions.log` and `tools/verify_car_preview_android.py`.
- Captured every view in native landscape (`native-*-landscape.png`), plus actual native portrait introduction and celebration. The native screenshots use Nunito and the existing app theme. Orientation/display changes retained the completed live game state.
- `gameplay-android.mp4` is a 170.65-second, 1024×768 recording of real Android gameplay. The MP4 was opened/decoded and a frame inspected (`recording-inspection.png`). Screenrecord does not capture audio in this recording.
- `native-runtime.log` shows TTS utterance start/completion callbacks throughout gameplay; no Flutter unhandled exception or Android fatal exception was found in that captured preview-process log. Audio listening/quality was not independently measured.
- Debug-emulator cold startup logged skipped frames. No physical-device or release/profile frame-time certification is claimed. This remains a performance-validation limitation before final production acceptance.
- Rebuilt the ordinary `lib/main.dart` entry point after the opt-in packaging change; output metadata retained `com.socialstories.social_stories`. Log: `production-build.log`. Both packages install together.
- The ordinary full regression command `flutter test` also passed all 66 tests; see `tests-default.log`.
- Final preview APK SHA-256: `6398AABD35BE3243C35A49701022A539E0C157CA8C00601E55756E8E2E52FBC9` (381,442,497 bytes).

- Post-change native production smoke check: original library opened, Going to School opened, Next navigated to page 2, and Listen Again was activated. Screenshots: `production-library-after.png`, `production-story-after.png`. The car preview is absent from the normal shelf.
