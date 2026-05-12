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
- MOV export now separates conservative static decor overlays from dynamic
  data overlays. Static decor renders once per task, and dynamic data overlays
  render only inside their padded union rect unless that rect covers most of
  the canvas.
- When the dynamic union rect covers most of the canvas, MOV export uses the
  full-frame single-layer path so fallback cases keep the original one-render,
  one-draw cost profile.

## First Milestone

- Add project-level performance snapshots so the same loaded project can be
  saved and restored for repeatable export speed tests.
- Emit one profiling artifact set for each completed export task:
  - `export_profile_<timestamp>.json`
  - `export_profile_<timestamp>.csv`
- Reuse the previously rendered `CGImage` when adjacent video frames resolve to
  the same quantized Layer Data sample time.

## Second Milestone

- Split export rendering into static and dynamic layers.
- Cache the static layer for `decorSolidColor`, `decorIcon`, and `decorText`.
- Render dynamic overlays into a padded union rect instead of the full canvas
  when that rect covers less than 85% of the canvas.
- Keep the same-sample dynamic render cache so repeated Layer Data sample times
  reuse the previous dynamic image.
- Extend profiling files to include static/dynamic render and draw timings,
  dynamic render area ratio, static layer cache hits, and dynamic render count.

## Third Milestone

- Keep the layered region path only for exports whose dynamic union rect is
  smaller than the full-frame threshold.
- Route full-frame fallback exports through a single rendered image containing
  all visible overlays, with same-sample reuse and one pixel-buffer clear/draw.
- Extend profiling schema to v3 with render path, dynamic render rect,
  static/dynamic overlay counts, and full-frame fallback count.
- The second benchmark round regressed because the real project fell back to a
  full-canvas dynamic rect while still paying layered draw overhead; v3 exists
  to remove that overhead and make fallback behavior measurable.

## Fourth Milestone

- Add frame-level outlier profiling without changing render output.
- Each segment now records render/draw/frame p50, p95, max, a slow-frame
  threshold, and a count of frames above that threshold.
- JSON segment records include the 10 slowest frames with frame index,
  clip/sample time, render reuse flag, and render/draw/frame durations.
- CSV keeps spreadsheet-friendly summary columns for distribution metrics and
  slow-frame counts; detailed slow-frame arrays are JSON-only.

## Fifth Milestone

- Test4 showed the previous Test3 segment 4 and 9 outliers returned to normal,
  but segment 3 had sustained slow full-frame renders and one 1s slow frame.
- Full-frame fallback now renders `SwiftUIOverlayFrameView` directly instead of
  routing through the cropped layer wrapper used by dynamic-region rendering.
- `ImageRenderer` and pixel-buffer CGContext work are wrapped in autorelease
  boundaries to reduce long-export temporary object buildup and random stalls.
- Profiling schema remains v4; compare v5 output using the existing p50/p95/max
  and `slowFrames` fields.

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
- `staticRenderDuration`
- `dynamicRenderDuration`
- `staticDrawDuration`
- `dynamicDrawDuration`
- `dynamicRenderAreaRatio`
- `staticLayerCacheHitCount`
- `dynamicRenderCount`
- `renderPath`
- `dynamicRenderRectX`, `dynamicRenderRectY`
- `dynamicRenderRectWidth`, `dynamicRenderRectHeight`
- `dynamicOverlayCount`
- `staticOverlayCount`
- `fullFrameFallbackCount`
- `renderDurationP50`, `renderDurationP95`, `renderDurationMax`
- `drawDurationP50`, `drawDurationP95`, `drawDurationMax`
- `frameDurationP50`, `frameDurationP95`, `frameDurationMax`
- `slowFrameThreshold`
- `slowFrameCount`

Each segment records the same timing buckets plus `segmentName`,
`outputFileName`, `duration`, `frameCount`, and JSON-only `slowFrames`
details for its 10 slowest frames.

The CSV file contains the same comparison-oriented metrics in a spreadsheet
shape: one `summary` row followed by one `segment` row per exported segment.
Use it to compare before/after exports from the same project snapshot.

For the third benchmark round, compare against the first and second runs:

- v1 baseline: `/Users/codywang/Documents/Video Production/0509 纽约/Test/export_profile_20260511_132440_578.json`
- v2 layered fallback regression: `/Users/codywang/Documents/Video Production/0509 纽约/Test2/export_profile_20260511_135450_510.json`
- Expected v3 behavior: `renderPath=fullFrameSingleLayer` for the current real
  project, `fullFrameFallbackCount` equal to segment count, and draw timing back
  near the v1 baseline instead of the v2 segment 9 spike.

For the fourth benchmark round, inspect `slowFrameCount`, `frameDurationMax`,
and per-segment `slowFrames` for the segments that were outliers in Test3:

- `DJI_20260509084933_0009_D.MP4`
- `PRO_VID_20260509_091919_00_011.mp4`

If the slow frames cluster around specific `sampleElapsed` values, optimize the
overlay/data path used at those samples. If they are random and sparse, focus on
`ImageRenderer` jitter, memory pressure, and autorelease behavior.

For the fifth benchmark round, confirm that the full-frame fallback path still
reports `renderPath=fullFrameSingleLayer`, then compare segment 3 against Test4:

- `DJI_20260509084453_0008_D.MP4`
- Expected movement: lower `renderDurationP95`, `drawDurationP95`,
  `frameDurationMax`, and `slowFrameCount`.

## Follow-Up Directions

- Expand static-layer eligibility beyond decor overlays when a component can
  prove it is independent of `elapsedTime`.
- Add per-overlay dirty-region composition so only changed overlay bounds are
  redrawn inside the dynamic union rect.
- Adaptive quality presets for draft vs final exports.
- Optional hardware-accelerated composition path after CPU-side profiling has
  identified the real bottlenecks.
