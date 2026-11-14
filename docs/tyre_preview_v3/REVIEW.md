# Fix My Broken Car — tyre preview v3

This is an isolated, reviewable Flutter vertical slice. The production entry point, story registry and other stories remain unchanged. No later missions or integration have been started.

## Play and view

- APK: [fix-my-broken-car-tyre-preview-v3.apk](../../dist/fix-my-broken-car-tyre-preview-v3.apk)
- [Landscape garage](screenshots/1366x1024-garage.png)
- [Portrait garage](screenshots/390x844-garage.png)
- [Native Android portrait completion](native-completion-portrait.png)
- [Wrench attached](screenshots/wrench-contact.png)
- [Exposed hub](screenshots/wheel-hub.png)
- [Portrait completion](screenshots/completion-portrait.png)
- [Android animation recording](gameplay-android.mp4) (silent, raw emulator capture; includes inspection, lifting and loosening).
- [Android second recording](gameplay-android-finish.mp4) (removal, replacement, tightening and lowering).
- Android captures are the `native-*.png` files in this directory.

## Rebuilt slice

New coordinated illustrated garage, expressive blue car, eight expression/blink poses, and matching tool sprites replace the earlier basic art. Body poses are registered to fixed wheel hubs. The car and wheels lift together; the jack arm extends, wrench rotates at each nut, removed tyre moves away, and replacement snaps onto the hub. Completion includes a relieved expression, lights and confetti.

The required order is inspect → place jack → lift → loosen three nuts anticlockwise → remove damaged tyre → match and fit new tyre → tighten three nuts clockwise → lower → celebrate. Wrong tools, wrong-size wheel and wrong rotation direction give feedback. Real drags and rotation gestures have accessible tap alternatives. Narration, replay, gentle native sound effects, pause/resume, reduced motion, text size and communication controls are included.

## Verification

- `flutter test --dart-define=WRITE_TYRE_PREVIEWS=true`: **82 passed**, including ten new tyre tests. See [test log](tests.log).
- `flutter analyze`: **No issues found**. See [analyzer log](analyze.log).
- Android debug build succeeded. See [build log](build.log).
- Complete native Android gesture walkthrough passed, including wrong tools, both wrench directions, removal, replacement and lowering. See [native interaction log](native-interactions.log).
- Screenshots cover six portrait/landscape sizes, plus key repair stages.
- Widget tests exercise the full workflow with actual drags and circular wrench gestures, interrupted drag, lifecycle pause, resume during lowering, replay, missing-asset recovery and layout/accessibility settings.
- APK SHA-256: `E71ADF9CC571B22CAB29F9FC8CA3FC21DED95751C449C5C30738EB9A708A8654` (406,205,761 bytes).

## Changed implementation

Entry: `lib/preview/tyre_preview_main.dart`. Game model, illustrated renderer, screen and sound bridge: `lib/preview/tyre/`. New images: `assets/images/story_scenes/tyre_v3_*`. Audio: `assets/audio/tyre_preview/`. Native sound bridge: `android/app/src/main/kotlin/com/socialstories/social_stories/MainActivity.kt`. Tests: `test/tyre_slice_test.dart`. Build helper: `tools/build_tyre_preview.ps1`.

Exact image prompts are in [ASSET_PROMPTS.json](ASSET_PROMPTS.json). Initial findings are in [DEFICIENCY_REPORT.md](DEFICIENCY_REPORT.md). The existing app theme and available story art guided the design; an independently accessible original Figma reference was unavailable.

## Review boundary

This is a large debug APK containing the existing app assets, not an optimized store release. Android emulator and Flutter test coverage do not replace physical-device, iOS or listening checks. Android screen recordings are silent; narration and earcons must be checked in the installed APK. No claim of production readiness is made.

The emulator ran slowly during capture; the raw recording is interaction evidence, not a smoothness benchmark.

Awaiting approval of this tyre-only slice before further missions or integration.
