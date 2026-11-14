# Fix My Broken Car — Preview 2

Status: Preview 2 created and verified; awaiting explicit approval. Not integrated into the production shelf. Previous APK/screenshots/recording remain in their original locations.

## What changed
- Swipe muddy paintwork to clean four independent splashes. Each cleaned area shines; a touch alternative is available.
- Open/close the garage shutter, spin the car wheels, explore the toolbox, and switch headlights on/off.
- Fit the correct wheel, then push the actual blue pump handle down three times. A hose connects to the wheel, tyre inflation is visible, and the gauge and air percentage rise. Horizontal drags and repeated movement during one stroke cannot skip inflation.
- Drag clockwise around the attached wrench to tighten its bolt. The wrench follows the gesture; tap Turn remains an alternative input.
- Drag the driving car up/down, or use the steering buttons, to catch optional stars. Missing a star never prevents completion.
- Stop now halts the car immediately, even before the finish marker. Go resumes the journey. The child can take a break without losing progress.
- A five-repair trail marks completed wheel, engine, bolt, power and drive tasks. Celebration displays the driving-star result.

## Visual direction
The first preview's garage, transparent car body and countryside artwork are reused. AppCard, ScreenHeader, NarrationCard, PillButton and the existing palette/typography remain the basis. New pump, shutter, mud, stars and gesture guides are separate Flutter-painted layers; no static screen substitution or new dependency was introduced. Narration stays outside the interactive scene. Phone/short landscape and large text retain scrolling.

## Preview access
- APK: `dist/fix-my-broken-car-preview-v2.apk`
- Android ID: `com.socialstories.social_stories.carpreview` (updates the isolated preview, coexists with the story app).
- Build version: `1.0.0-preview.2`, code 2.
- Rebuild with `tools/build_car_preview.ps1`.
- Screenshots and verification logs are in this directory; Preview 1 evidence remains one directory above.

## Verification
Final analyzer, full regression suite, Android interaction and build results are recorded below. New tests cover real swipe cleaning, downward pump strokes versus wrong-direction dragging, circular wrench gestures, steering, pause/reset guards, star collection, and repair progression. The full suite also checks the original 75 story atlases and existing parent/navigation/data functions.

## Scope and limits
Still a preview awaiting approval. No requested story has been implemented and the game is absent from the normal catalog. Preferences/progress remain in memory. Speech uses the existing TTS service; there is no recorded mechanical sound pack or speech recognition requirement. Physical devices, native iOS and release-performance profiling remain untested. Native emulator startup limitations will be disclosed rather than represented as product performance certification.

Proposed next step after approval: integrate only this approved game through the current app scope/settings, preserve the approved reference screenshots, and rerun regressions before acceptance. No merge or publication without acceptance.


## Final verification — 3 November 2026
- `flutter analyze`: zero issues (`analyze.log`).
- `flutter test --dart-define=WRITE_CAR_PREVIEWS=true`: **72 passed** — 54 existing + 18 preview tests (`tests.log`). No new assertion/hit-test warnings remain. Expected corrupt-cache/offline diagnostics are from existing tests.
- The additional reduced-motion test compares actual scene pixels before/after driving progress; scenery and uncollected stars remain still. Progress continues outside the scene.
- Android debug build succeeded (`build.log`); aapt verified package ID, launcher and version code 2. Installed final APK and confirmed its real native portrait screen and TTS start/completion callbacks (`native-final-runtime.log`). No Flutter unhandled or Android fatal exception appears in that captured preview-process log.
- Native walkthrough passed all five missions using real touches and drags, including wiping, pump strokes and clockwise wrench gestures. The car collected **three driving stars**, stopped at the garage marker and reached five completed repair badges. See `native-interactions.log`.
- Native normal-motion recording and screenshots cover the same final gameplay visuals. Final APK also includes the reduced-motion-only star positioning correction covered by the rendered-pixel test.
- **53 Flutter screenshots** include every view at six phone/tablet sizes, plus cleaning before/after, pump before/after and wrench gesture evidence. Captures wait for decoded illustration assets, rather than displaying loading artwork.
- Native portrait/landscape screenshots use the actual app theme and Nunito font. Widget captures use real Arial glyphs instead of Flutter's Ahem test font.
- Both videos were decoded and inspected: repair walkthrough **128.06 seconds**, test drive **28.83 seconds**, both 1024×768. Original clips are silent screen recordings; TTS activity is separately confirmed through runtime callbacks.
- Android emulator graphics startup failed in windowed mode and its System UI stalled during cold boot. Headless hardware rendering completed the walkthrough. Logs are retained. This is not a physical-device or release frame-rate certification.
- Existing Java native-access and flutter_tts Kotlin migration build warnings remain unchanged. No new dependency or production story/registry change was introduced.
- APK bytes and SHA-256 are in `verification.json`. The original preview APK remains untouched.

## New preview evidence
- [Repair walkthrough](gameplay-repairs-android.mp4) · [Steering/test-drive video](gameplay-drive-android.mp4)
- [Portrait](native-introduction-portrait.png) · [Landscape](native-pump-before-landscape.png)
- [Wiping before](native-mud-before-landscape.png) · [Wiping after](native-mud-after-landscape.png)
- [Inflating the wheel](native-pump-before-landscape.png) · [Wheel inflated](native-pump-after-landscape.png)
- [Wrench gesture](native-wrench-landscape.png) · [Completed repairs and stars](native-celebration-landscape.png)

## Changed components
- `lib/preview/car/repair_game.dart`: inflation gate, guarded cleaning/door/spin/rotation/steering state, star rewards, repair counts and immediate stopping.
- `lib/preview/car/car_preview_screen.dart`: interactive scene regions, repair trail, accessible fallback controls, live progress and narration prompts.
- `lib/preview/car/garage_interactions.dart`: new real pump handle and circular wrench gesture widgets.
- `lib/preview/car/garage_art.dart`: independent shutter, mud/sparkles, connected air hose, inflation, wheel spin, steering and star layers.
- `test/car_preview_test.dart`: 18 preview tests, including rendered reduced-motion verification.
- `tools/build_car_preview.ps1`: versioned Preview 2 build and package check.
- `tools/verify_car_preview_android.py`: native gesture walkthrough and versioned capture/recording output.

**Approval requested:** review Preview 2's new artwork layers, gestures and gameplay, then approve it for scoped production integration or request revisions. No integration, commit, merge or publication has occurred.

