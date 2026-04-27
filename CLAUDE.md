# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build                          # build
swift run RunningOverlay             # run
swift test                           # all tests
swift test --filter FitFileParserTests  # single test class
RUNNING_OVERLAY_FIT_SAMPLE=/path/to/file.fit swift test  # tests that require a real FIT file
```

## Architecture

Running Overlay is a macOS 15 SwiftUI app (Swift 6, SPM) that ingests FIT activity files and video clips, lets users design data overlay elements, and exports transparent MOV overlays for compositing in video editors.

### Data flow

```
FIT file → FitFileParser → ActivityTimeline (time-indexed samples)
Videos → MediaMetadataReader → MediaItem (inferred timestamps, alignment status)
User aligns video clips → TimelineModel (tracks/clips with alignment offsets)
Playhead → elapsed activity time → OverlayLayout samples metric values
Sampled values + video frame → PreviewCanvasView (fitted to container)
Timeline segments + activity data + overlays → OverlayVideoExporter → .mov files
```

### Key subsystems

| Folder | Purpose |
|---|---|
| `App/` | SwiftUI entry, window setup, command menus, keyboard shortcuts |
| `Project/` | `ProjectDocument` (central @MainActor state hub), `ProjectSettings` (resolutions, frame rates) |
| `FitData/` | Binary FIT parser, `ActivityTimeline` with interpolated metric sampling |
| `MediaImport/` | AVFoundation metadata extraction, alignment state machine |
| `Timeline/` | Multi-track model; clips store `TimeInterval` offsets, not pixels |
| `Overlay/` | `OverlayElement` (13 types), styles, templates, `RunningGaugeModel`, `RouteMapOverlay` |
| `Export/` | `OverlayFrameRenderer` (shared preview+export pipeline), `OverlayVideoExporter` (H.265 / ProRes 4444) |
| `UI/` | SwiftUI views; AppKit self-drawing view for the timeline canvas |

### State management

- `ProjectDocument` is the single @MainActor state hub; all mutations go through its methods.
- Undo/redo is snapshot-based: discrete edits call `registerUndoPoint()`; continuous edits (sliders, drag) call `registerContinuousUndoPoint()` during change and `finishContinuousEdit()` on release.
- All data models are `Equatable` value-type structs. IDs use `UUID`.

### Timing model

There are five distinct time axes — confuse them and export drifts:

1. **Real timestamp** — wall-clock UTC (from FIT records or video metadata)
2. **Activity elapsed time** — seconds since FIT activity start
3. **Media source time** — position inside a video file
4. **Project timeline time** — editable, may be negative
5. **FIT axis time** — the draggable FIT layer offset on the timeline

Conversions between axes are always explicit. Pixel positions are never stored; the timeline stores `TimeInterval` and converts at render time.

### UI conventions

- Dark-only app (`NSAppearance(named: .darkAqua)`, `.preferredColorScheme(.dark)`).
- Custom `HorizontalResizeHandle` instead of `HSplitView` to preserve inspector widths.
- Timeline canvas is AppKit (`NSView`) embedded in SwiftUI for precise hit-testing and rendering.
- Inspector content switches on `EditorSelection` enum (clip editor vs. overlay editor).

### Testing

Uses Swift Testing (`@Test` macro, `#expect`). Test files are in `Tests/RunningOverlayTests/`. Tests must not depend on external files unless gated on `RUNNING_OVERLAY_FIT_SAMPLE`.

## Documentation

Extended design docs, ADRs, and a detailed project log live in `docs/`. Read `docs/architecture.md` for subsystem contracts and `docs/development.md` for engineering principles before making structural changes.
