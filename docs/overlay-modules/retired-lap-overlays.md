# Retired Lap Overlays

Last updated: 2026-05-13

## Summary

`Lap List`, `Lap Card`, and `Lap Live` were removed from the active app surface while designing the replacement interval-training experience.

The original implementations were useful prototypes, but their UI models were not strong enough for the next interval-focused workflow:

- `Lap List` was a vertical teleprompter list and did not fit the desired horizontal interval HUD direction.
- `Lap Card` focused on completed-lap recap and recovery stats rather than current interval state.
- `Lap Live` was closer to the desired behavior, but its compact vertical layout, REST handling, and inspector model were too constrained for the new `Interval HUD Bar`.

The replacement direction is documented in:

- `docs/overlay-modules/interval-hud-bar-overlay.md`
- `docs/design/overlays/interval-hud-bar/interval-hud-bar-overlay-ui.md`

## Removed Active App Surface

The removal includes:

- `OverlayElementType.lapList`
- `OverlayElementType.lapCard`
- `OverlayElementType.lapLive`
- `LapListStyle`, `LapCardStyle`, and `LapLiveStyle`
- Lap render layouts and render helpers in `OverlayRenderModel`
- SwiftUI preview views in `PreviewCanvasView`
- CoreGraphics export renderers in `OverlayFrameRenderer`
- SwiftUI export dispatch for the three overlay types
- Inspector detail views:
  - `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
  - `Sources/RunningOverlay/UI/LapCardOverlayDetailView.swift`
  - `Sources/RunningOverlay/UI/LapLiveOverlayDetailView.swift`
- Overlay Pool tiles for the three components
- Built-in template references to `Lap Live`
- Dead `lapList`, `lapCard`, and `lapLive` style payloads from bundled template resources

## Recovery Through Git

The deleted implementations are intentionally recoverable through git history.

To inspect the last committed version before removal:

```bash
git show HEAD^:Sources/RunningOverlay/UI/LapListOverlayDetailView.swift
git show HEAD^:Sources/RunningOverlay/UI/LapCardOverlayDetailView.swift
git show HEAD^:Sources/RunningOverlay/UI/LapLiveOverlayDetailView.swift
```

To recover broader implementation details, search the parent commit for:

- `OverlayElementType.lapList`
- `OverlayElementType.lapCard`
- `OverlayElementType.lapLive`
- `OverlayRenderModel.lapListLayout`
- `OverlayRenderModel.lapCardLayout`
- `OverlayRenderModel.lapLiveLayout`
- `LapListOverlayView`
- `LapCardOverlayView`
- `LapLiveOverlayView`

Do not reintroduce these components directly unless the design is revised. Prefer building the new `Interval HUD Bar` from the current interval overlay specs.
