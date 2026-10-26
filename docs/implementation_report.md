# Story animation implementation and verification

Reviewed 27 October 2026 with Flutter 3.47.5 / Dart 3.13.4 on Windows.

All 12 bundled stories now use 75 situation-specific scene posters and action
strips containing 210 illustrated key poses. Each strip was generated with the
original story illustration as its character/style reference, visually reviewed,
and corrected when poses, props, emotions, framing or environments were wrong.
The original 12 PNGs, story narration, page counts and bundled questions remain
unchanged; their hashes/content were checked.

## Delivered behavior

- Each scene has its own explicit asset and action metadata. The player displays
  real articulated pose changes, with stable source-cell geometry and contained
  proportions. One-shot actions hold their final pose; repeated actions loop.
- Native TTS word boundaries drive narration progress when the engine supplies
  them. Seventeen multi-action scenes have exact phrase cues for individual
  poses. Other engines use a finite speech-rate estimate. Pause/resume, replay,
  skipping, settings and backgrounding coordinate speech and visual playback.
- Reduced motion holds a meaningful reviewed pose and respects system settings.
  Navigation remains child-paced, with no forced page time limits.
- Short landscape screens give the scene more space while retaining large main
  controls. Portrait tablets stack artwork above narration. Artwork and posters
  preserve their proportions and safe character framing.
- Older cached/server scenes receive new bundled assets only when their original
  title, page order, text, image and framing match. Remote questions, ordering,
  removals and parent-authored edits are preserved. Narration/image edits clear
  the old animation rather than attaching an unrelated action.
- Quiz answer images, when authored, survive storage, upload/submission, review
  and server responses. The original bundle contains zero comprehension
  questions. Existing subscriber/server quizzes retain positive feedback and
  gentle retry behavior.
- Server validation, asset serving and admin comparisons preserve animation and
  answer-image metadata. The iOS runner is included for Mac/Xcode builds.

## Verification

| Check | Result |
| --- | --- |
| Flutter analysis | Passed, zero issues |
| Complete Flutter suite | 54 tests passed |
| Every bundled scene | All 75 atlases decoded, advanced actual frames and paused |
| Responsive widget layouts | 360x640, 800x360, 768x1024, 1024x768, 1024x1366, 1366x1024 |
| Parent features | Gate, subscription mode, drafts, drag reorder, submissions, quizzes and sync covered |
| Admin app | 2 tests passed |
| Java story server | 18 tests passed |
| Asset integrity | 75 mappings; all hashes, grid dimensions, distinct frames and exact poster crops verified |
| Original artwork/text | All 12 original hashes and all narrated story text preserved |
| Android debug build | Passed; packaged story JSON, 150 scene assets and 12 originals verified inside the APK |

There is no separate games module in this checkout.

## Artwork and device limits

These are limited two- or three-pose animations. Native frame sizes are 724x724
or 1024x768; exports retain original generated pixels without upscaling. The
requested native 4K background / 2K character targets remain unmet. Large-tablet
sharpness, physical-device performance and native voice timing require device
review. iOS compilation, signing and physical iPhone/iPad tests require a Mac
and were not performed here. These checks remain explicitly unchecked in the
scene inventory.

Layout preview PNGs under `build/scene_previews/` use Flutter's test font and
show geometry/artwork; their block glyphs do not represent production text.

## Review files and maintenance

- `scene_asset_inventory.json`: every scene's narration, identity, environment,
  emotion, props, action beats, original mismatch and completed/pending checks.
- `generated_scene_assets.json`: final prompts, reference/source paths, visual
  review notes, native dimensions and all atlas/poster hashes.
- `scene_frame_cues.json`: exact narration phrase maps for multi-stage actions.
- `scene_asset_verification.json` and `test_verification.json`: integrity,
  runtime and build evidence, including artifact hash.
- `story_assets_baseline.json`: immutable original data and source-image hashes.

Run `python tools/integrate_scene_assets.py --check` and `flutter test` after
changing assets or narration. `tools/gen_stories.py` preserves authored fields.
The export helper reuses valid workspace PNGs even if the optional original
image-generation directory is unavailable on another machine.

## Android artifact

`dist/social_stories-animated-debug-2026-10-27.apk`

Debug APK size: 376,548,375 bytes.

SHA-256: `ae3ea9441d030e4539effee56f83a17b82b7346d473cb625d4b7b8da078b624c`.
