# Export Performance Optimization

This project tracks the first export-performance branch for Running Overlay.
The goal is to make export speed measurable first, then reduce repeated work
without changing visual output or export timing.

## Current Export Path

- `SwiftUIOverlayVideoExporter` exports one transparent MOV per segment.
- Each video frame is currently represented by a layer-data sample time derived
  from project frame rate, segment time, FIT offset, and Layer Data FPS.
- Shared SwiftUI overlay views are rasterized with `ImageRenderer`, then drawn
  into an `AVAssetWriterInputPixelBufferAdaptor` pixel buffer.

## First Milestone

- Add project-level performance snapshots so the same loaded project can be
  saved and restored for repeatable export speed tests.
- Emit one profiling artifact set for each completed export task:
  - `export_profile_<timestamp>.json`
  - `export_profile_<timestamp>.csv`
- Reuse the previously rendered `CGImage` when adjacent video frames resolve to
  the same quantized Layer Data sample time.

## Project Snapshot Workflow

- Use `Save Project Snapshot` in the Export dialog to write
  `running_overlay_project_snapshot.json`.
- Use `Restore Project Snapshot` to replace the current editor state with that
  snapshot before running a benchmark export.
- The snapshot stores exportable state: project settings, parsed FIT timeline,
  media references, media folders, timeline, overlay layout, user asset
  references, and FIT source name.
- Runtime state is intentionally cleared on restore: selection, playback,
  media-pool preview, export progress, and undo/redo stacks.
- Video and FIT source files are not copied. Media items keep their existing
  file paths, so snapshots are intended for same-machine benchmark repeats.

## Profiling Files

The JSON file is the canonical structured record for one completed export task.
It contains task-level totals and a `segments` array.

Task-level fields include:

- `startedAt`, `completedAt`
- `settings`
- `segmentCount`
- `totalFrameCount`
- `renderedFrameCount`
- `reusedFrameCount`
- `reuseRate`
- `totalDuration`
- `imageRenderDuration`
- `pixelBufferDrawDuration`
- `appendDuration`
- `writerWaitDuration`
- `averageFrameDuration`

Each segment records the same timing buckets plus `segmentName`,
`outputFileName`, `duration`, and `frameCount`.

The CSV file contains the same comparison-oriented metrics in a spreadsheet
shape: one `summary` row followed by one `segment` row per exported segment.
Use it to compare before/after exports from the same project snapshot.

## Follow-Up Directions

- Static-layer caching for overlay backgrounds, labels, map snapshots, and
  other unchanged visual layers.
- Dirty-region composition so only changed overlay bounds are redrawn.
- Adaptive quality presets for draft vs final exports.
- Optional hardware-accelerated composition path after CPU-side profiling has
  identified the real bottlenecks.
