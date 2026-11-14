# Preview 2 scope — 3 November 2026

User requested a more interactive new preview. Extend only the existing isolated game. Preserve Preview 1 APK, screenshots and recording. No production integration or story work is authorized.

Add scene-level swipe cleaning, tap/drag tyre pumping after fitting a wheel, clockwise wrench gestures with tap fallback, garage door and spare-wheel exploration, steering and optional star collection, a five-repair progress strip, and richer contextual hints/feedback. Reuse the current raster layers, existing theme/controls/narration, and guarded RepairGame controller. No dependencies or unrelated screen changes.

Expected edits: lib/preview/car/{repair_game,car_preview_screen,garage_art}.dart, preview tests, versioned Android capture/build helpers and docs/car_preview/v2 evidence. Risks: nested gesture recognition versus scrolling, pause and reset during gestures, wrong-part/repeated-action guards, steering/time-step behavior, and narrow/large-text layouts. Verify model gates, real widget gestures, all responsive sizes, Android full gameplay, screenshots, and new APK identity. Stop for approval after delivering Preview 2.
