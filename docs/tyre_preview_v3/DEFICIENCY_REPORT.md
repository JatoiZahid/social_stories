# Visual and gameplay deficiency audit — 3 November 2026

The user rejected Preview 2. This report does not classify it as approved or production-ready.

## Evidence inspected
Actual code: lib/preview/car/car_preview_screen.dart (_scene, _actions, _repairTrail), garage_art.dart (GaragePainter, PartPicture), garage_interactions.dart (PumpStation/WrenchGesture), repair_game.dart (RepairGame). Existing app components: AppTheme.light, AppColors, AppDimens, AppCard, ScreenHeader, RoundIconButton, PillButton, NarrationCard, TtsNarrator. Existing story illustration: going_to_school_scene_01.png. Prior native views and a fresh launch/capture of the rejected runtime are retained. Independent approved Figma/design exports remain unavailable; implemented story screens/artwork are the baseline, not a fabricated design comparison.

## Specific deficiencies
1. The realistic compact-car body raster has a different visual language from the app's warm illustrated cartoon cast. Procedural eyes, a mouth on the side panel, and mismatched wheels amplify the collage effect. The body and wheel scales/arches do not feel like a designed character rig.
2. Tool, pump and toolbox objects are mostly simple CustomPainter primitives. Their shading/detail does not match the background. Material icons are appropriate shared UI chrome, but not substitutes for illustrated game props.
3. The environment is detailed but camera depth differs from the side-on car. The car is relatively small, with extensive empty service-floor space; the separate narration column and controls consume space needed by the activity.
4. The prior wheel repair is inspect -> drag spare -> pump. There is no jack placement, lifting, individual nuts, removal of the damaged wheel, tightening, or lowering. Added gestures do not replace a meaningful physical sequence.
5. Character expression is mainly a procedural smile curve/eyes plus a small idle bob. It lacks illustrated worried/sad/surprised/excited/relieved reactions with consistent face placement.
6. Tool contact uses broad rectangular target overlays, and large gear overlays cover car details. Some interactive objects feel placed above the scene rather than belonging to a coordinated rig.
7. Continuous whole-screen animation rebuilds are unnecessary. Tool and car transforms should share one coordinate system, with painting driven independently from instructional UI.
8. Confetti provides feedback but the end state lacks a satisfying mechanical resolution tied to a complete repair.

## Replacement vertical slice only
Create a new isolated entry point in the same Flutter project, preserving prior APKs/evidence/code. No production route, story change, other game or remaining mission implementation. Reuse existing theme and header/navigation/buttons/TTS/AAC patterns. Scene dominates the card; a compact instruction dock and illustrated tool tray support it. New coordinated workshop, expressive car body atlas and transparent tool atlas replace the mismatched visual layers.

Sequence: inspect damaged tyre; select/drag jack into marked chassis point; lift the coordinated car rig; place/rotate wrench on each of three wheel nuts; drag damaged tyre to its tray; align and place new tyre on the exposed hub; tighten each nut; lower the car; illustrated relieved/happy reactions and a short completion effect. Include sound-off, pause/lifecycle, reduced motion, narration replay, generous drop targets, explicit touch alternatives, restart, and orientation/layout checks.

Risks to verify: asset atlas framing, consistent wheel/face proportions, target positions during lift, rotation direction and thresholds, input interruption, no skipped states from rapid gestures, child-safe retry feedback, animation/audio cleanup, and portrait/landscape layout. Stop for explicit approval before expanding to engine/washing/customization/driving or integrating into the production catalog.
