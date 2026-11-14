# Enhanced tyre slice: inspection and scope

The existing Flutter tyre preview was inspected, including its source, actual Android screenshots and recordings retained under `docs/tyre_preview_v3/`. The installed previous build is the before reference. This work continues the existing isolated preview on `preview/fix-my-broken-car`; production integration and later missions are excluded.

## Problems and responsible code

- `lib/preview/tyre/tyre_screen.dart`, previous `build`, `_instruction`, `_words`: a persistent side panel and repeated heading, instruction, feedback and hint text competed with the repair. On phones, a 130–170 pixel panel reduced scene space.
- Previous `_tray`: four 74 pixel tiles were always shown, regardless of task; selected state changed colour without lifting, and failed drags had no animated return.
- Previous `build`, `_aac`: pause, hint, reset, inspect, lower, turn and AAC all used similar pill buttons. Several duplicated direct scene actions.
- Previous `_scene`: fixed world scaling had no camera focus. Nuts used closely spaced drop targets. Rotation recognizers competed in the drag arena; an idle accessibility dump could also make automated native interaction appear stuck by reading a stale hierarchy. That capture issue was fixed in v3 tooling, and is distinguished from a gameplay defect.
- `lib/preview/tyre/tyre_game.dart`, previous `rotate`: nuts advanced the counter and disappeared immediately. The final-nut transition was logically correct but had no visible removal or settling feedback.
- `lib/preview/tyre/tyre_art.dart`, previous `paint`: illustrated car, wheels and jack already shared a measured rig and should be retained. Blinks, poses and completion existed; no new car artwork is needed.
- Continuous animation rebuilt the scene overlays and tool controls. The enhanced version confines the ambient clock to painting and hint motion.
- Native verification exposed an event-tolerance edge: a coalesced quarter-turn slightly beyond 90 degrees was discarded by the old per-update guard. The UI now accepts normalized physical turns up to 180 degrees while retaining direction, dead-zone and non-finite-value guards. A dedicated regression test covers a 1.59-radian update.
- Decorative `CustomPainter.shouldRebuildSemantics` inherited `shouldRepaint == true`, invalidating accessibility semantics during ambient painting. Decorative car/guide painters now explicitly retain their unchanged semantics; the separate transformed interactive widgets continue to expose real actions.

## Reused systems

All approved `tyre_v3_*` car/garage/tool images and rig metadata remain intact. Reuses `AppTheme`, `AppColors`, `PageDots`, `PillButton`, `RoundIconButton`, `SpeakerBadge`, `Narrator`, `AppSettings`, `TyreSound`, guarded `TyreGame` state and Flutter animation controllers. No dependency is added. The production entry point, library and story registry are untouched.

## Enhancement scope

Immersive adaptive garage; a single short contextual bubble; task-specific illustrated tool dock; larger targets; shared animated camera/hitbox geometry; tool lifting, drag shadows and invalid-drop return; individually selectable unfinished nuts; visible nut flights and parts tray; guided rotation with an assisted alternative; coordinated lift and jack handle; state-driven facial reactions; completion feedback; separate picture AAC and settings. Only the tyre mission is enhanced. Embedded raster garage details are preserved rather than falsely presented as independently animated layers.

Before imagery and recording are preserved alongside this report. Final validation, comparison images, APK and remaining limitations are documented in REVIEW.md after verification.
