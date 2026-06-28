# Export Development

## Sandboxed Destination Access

- Export destinations must use the URL returned directly by `NSOpenPanel`;
  rebuilding a URL from displayed path text loses the sandbox authorization
  context.
- The suggested destination may point to the first source video's folder, but
  it is not writable until the user explicitly selects a destination folder.
- `SecurityScopedURLAccess` keeps access active for the complete asynchronous
  export task and for synchronous diagnostic JSON writes.
- Do not stop security-scoped access until all frame writes, profiling files,
  and `AVAssetWriter` completion work have finished.

### Phase 6: Export

- Status: first-pass implementation completed.
- Export dialog selects destination, bitrate, clip-based export, or full-activity export.
- Export destination defaults to the folder containing the first video in the media pool, with `~/Movies` as the fallback before videos are loaded.
- Render transparent MOV overlays using H.265 with alpha or ProRes 4444.
- Batch export one overlay video for each timeline clip, including overlapping clips.
- Full-activity export ignores video clips and renders one overlay file from FIT start to finish.
- `Export Test Clip` renders a three-second transparent MOV around the current playhead position using the current overlay layout and active FIT data (falling back to synthetic data when no FIT activity is loaded).
- Export now uses a single SwiftUI-based renderer path that rasterizes shared overlay views (`ImageRenderer`) on each frame and encodes transparent MOV output.
- Preview and export invoke the same shared overlay view entry points (`OverlaySharedTextPresetView`, `OverlaySharedDistanceTimelineView`, `OverlaySharedRouteMapView`) and differ only by `isInteractive` flags.
- Route Map export resolves its `MapSnapshotRequest` from the same layout inputs as preview, preloads matching `NSImage` snapshots before frame rendering, and supplies them to `OverlaySharedRouteMapView` so `ImageRenderer` does not depend on asynchronous view tasks for the map background.
- Shared entry points now also include elevation chart, running gauge, Interval HUD Bar, and Zone Edge Bar (`OverlaySharedElevationChartView`, `OverlaySharedRunningGaugeView`, `OverlaySharedIntervalHUDBarView`, `OverlaySharedZoneEdgeBarView`) so SwiftUI export covers current overlay controls on the same component path.
- Interval HUD Bar style decodes missing newer fields from defaults, allowing early HUD project snapshots to load after the ordered metrics, remaining-primary, and typography controls were added.
- `SwiftUIOverlayVideoExporter` removes its old per-type fallback drawing implementations and keeps only the shared component path used by preview.
- `Export Test Frame` renders a PNG through the same SwiftUI export rasterization path at the current playhead position.
- `Export Overlay JSON` serializes the current `OverlayLayout` as `overlay_configuration.json` for reproducible renderer-debug snapshots.
- `Save Project Snapshot` / `Restore Project Snapshot` in the Export dialog write and load a JSON snapshot of exportable project state for repeatable performance benchmarking.
- `--benchmark-export <snapshot.json>` starts Running Overlay in non-interactive benchmark mode, restores the snapshot, exports all timeline clips through `SwiftUIOverlayVideoExporter`, writes outputs into `running_overlay_benchmark_<timestamp>` under the current working directory unless `--benchmark-output <directory>` is provided, and terminates with a non-zero exit code on failure. Benchmark mode is handled by `RunningOverlayMain` through a minimal AppKit run loop (`HeadlessBenchmarkRunner`) before the SwiftUI editor starts, so `swift run RunningOverlay --benchmark-export …` works reliably from the terminal.
- `--benchmark-elevation <activity.fit> --template <template.rotemplate>` runs a headless A/B export for a real FIT plus `.rotemplate` without a project snapshot or source video. It exports the same activity window twice into sibling folders (`baseline_no_cache`, `cached`) with the elevation chart static-fill cache disabled and enabled, writes `benchmark_summary.txt`, and is intended for local performance and visual inspection. Optional flags: `--start <seconds>`, `--duration <seconds>`, `--benchmark-output <directory>`.
- Main `Export` no longer exposes legacy mode toggles and always uses SwiftUI shared-component export.
- Test clip/frame time sampling uses the same activity-time conversion as preview (`timeline.activityElapsed(atProjectTime:)`) before Layer Data FPS quantization.
- `renderPNG` now supports the same post-render vertical row flip option used by MOV export, so test frame outputs match preview orientation.
- Text preset export accent color now resolves from `element.style.accentColor` rather than `NSColor.controlAccentColor`.
- Apply project frame rate, resolution, bitrate, and Layer Data FPS.
- Generate output filenames with `_overlay.mov`.
- `ProjectDocument` owns structured export progress state for overall and per-output progress.
- The toolbar displays export progress while exporting; clicking the progress control opens a persistent popover with item-level progress.
- The export progress popover keeps the per-output queue in a fixed-height scroll view so long export queues remain reachable.
- Export can be cancelled from the progress popover; the exporter checks cancellation between segments and while rendering frames.
- Export reuses `AVAssetWriterInputPixelBufferAdaptor`'s pixel buffer pool instead of allocating a fresh pixel buffer every frame.
- Export caches attributed text layouts by text/style/sample output, reducing repeated font and string layout work across frames.
- `SwiftUIOverlayVideoExporter` owns MOV encoding, frame timing, and progress while rasterizing shared SwiftUI overlay components per frame.
- Export creates an explicit flipped `NSGraphicsContext` for text drawing so backgrounds and text render through the same bitmap context without global CGContext inversion.
- Export text is rendered through a 2x supersampled transparent offscreen bitmap before compositing back into the output frame, reducing jagged edges on large saturated text and alpha-shadow boundaries.
- Export scales font sizes, padding, rounded corners, shadows, distance timeline geometry, and elevation chart geometry from the shared 1280x720 render reference to the selected project resolution.
- Export renders distance timeline and elevation chart overlays with the same shared progress and sample data used by preview.
- Test clip/frame exports use current overlay content instead of fixed calibration reference overlays.
- Export vertically flips completed pixel-buffer rows before appending frames, compensating for the `CVPixelBuffer` to MOV orientation path so the encoded result matches the preview coordinate system.
- Export reuses the previous `ImageRenderer` output when adjacent video frames quantize to the same Layer Data sample time, while still appending every output frame.
- MOV export uses an `ExportRenderPlan` that separates static decor overlays from dynamic data overlays, caches the static layer once, and renders dynamic overlays into a padded union rect when the rect stays below 85% of the canvas.
- When the dynamic rect reaches the full-frame fallback threshold, MOV export uses a single full-frame render/draw path instead of layered drawing to avoid fallback overhead.
- Full-frame fallback renders `SwiftUIOverlayFrameView` directly; the cropped `SwiftUIOverlayLayerView` wrapper is reserved for static layers and dynamic-region rendering.
- When full-frame fallback is caused by far-apart dynamic overlays rather than a truly large single overlay, MOV export may use `renderPath=perOverlay`: each dynamic overlay renders through the cropped layer wrapper into its own padded rect, then all local images are composited in one pixel-buffer context.
- Per-overlay rendering is intentionally conservative: it requires no static decor overlays, a reliable render rect for every dynamic overlay, and either total padded overlay area below 85% of the canvas or a dispersed-layout exception. The exception applies only when at least two elevation charts qualify for the static-fill cache, every individual padded rect stays below 55% of the canvas, and estimated per-overlay cost (summed padded areas plus 10% canvas overhead per overlay item) stays below 250% of a single full-frame render. Otherwise the exporter keeps the full-frame path because many small `ImageRenderer` passes can cost more than one full-canvas pass.
- Per-overlay and dynamic-region compositing converts SwiftUI top-left render rects into pixel-buffer draw rects before drawing into `CGContext`; full-frame renders still draw at the full canvas rect.
- Inside the per-overlay path, Route Map overlays with no visible stats bar can prerender the static map/route layer once per export task and render only the current marker per unique Layer Data sample. Route maps with visible stats bars stay on the normal per-overlay render because their text values are elapsed-time dependent.
- Inside the per-overlay path, full-profile Elevation Chart overlays can prerender their static fill geometry once per export task and render only the current-position marker per unique Layer Data sample. The chart is baked into layered images (`elevationChartBaseVisibility` chrome/grid/axis/base fill, `elevationChartLineVisibility` line/glow, and for Dark Terrain dual-area charts an `elevationChartLowerVisibility` lower-fill layer). Each frame composites base, the dual-area lower fill cropped to the right of `chartAreaWidth * progress` (`elevationChartCutXInImage`), the line, then the freshly rendered marker plus axis labels. Eligibility (`canUseElevationChartStaticFillCache`) requires full-profile mode and an area fill, and excludes big numbers, a visible stats bar, and the shared foreground glow, because those either change per frame or are applied to the whole composite. `elevationChartStaticFillParity` verifies the composite matches a full single-pass render within anti-aliasing tolerance. Measured locally at 1280x720, the per-frame render work drops from ~1.86 ms to ~0.79 ms per chart (~2.4x), with a one-time ~37 ms cache build.
- Inside the per-overlay path, nearby simple numeric overlays may render as a single `SwiftUIOverlayLayerView` batch when their padded union is smaller than their individual padded areas and below 45% of the canvas. The batch keeps the existing SwiftUI visual path and is profiled under the first grouped numeric overlay type.
- Export-performance benchmarks should use the same privacy-safe local snapshot
  through `swift run RunningOverlay --benchmark-export ... --benchmark-output
  ...`, with each optimization round writing to a new numbered output
  directory. Never commit snapshots containing private media paths or activity
  data.
- Distance Timeline static/dynamic SwiftUI splitting was benchmarked and reverted after Test10/Test11 because the additional SwiftUI render passes increased `imageRenderDuration` more than the reduced draw cost helped.
- `ImageRenderer` and pixel-buffer CGContext operations run inside autorelease boundaries to reduce temporary object buildup during long exports.
- Each completed export task writes `export_profile_<timestamp>.json` and `export_profile_<timestamp>.csv` into the destination folder with whole-export totals, per-segment timing/reuse metrics, static/dynamic layer metrics, render-path diagnostics, per-overlay render metrics, and frame-level outlier metrics.
- Export profiling stores per-segment render/draw/frame p50, p95, max, slow-frame count, and the 10 slowest frame samples in JSON so benchmark outliers can be tied back to frame index and `sampleElapsed`.

Pending:

- Expand visual snapshot coverage for preview/export overlay render parity.
- Codec fallback handling if HEVC with alpha is unavailable on a machine.

Export performance optimization directions:

- Introduce frame-scoped render caches for static overlay layers (background shapes, static labels, static map tiles) and composite only dynamic layers each frame.
- Add per-overlay dirty-region change detection so exporter rerenders only overlay bounds whose sampled output changes.
- Avoid adding more SwiftUI `ImageRenderer` passes for the same overlay unless a fixed-snapshot benchmark proves a net win.
- Parallelize non-UI preprocessing work (sample-time preparation, layout precompute, route/elevation intermediate buffers) while keeping `ImageRenderer` use on `MainActor`.
- Add adaptive quality knobs for export jobs (supersampling factor, shadow quality, optional map detail level) with profile-based defaults.
- Extend structured export profiling with optional deeper per-frame samples, memory high-water mark, and benchmark fixtures once summary/segment artifacts identify the bottlenecks.
