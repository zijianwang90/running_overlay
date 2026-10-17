# Export Performance Optimization

This project tracks the first export-performance branch for Running Overlay Studio.
The goal is to make export speed measurable first, then reduce repeated work
without changing visual output or export timing.

## Current Export Path

- `SwiftUIOverlayVideoExporter` exports one transparent MOV per segment.
- HEVC-with-alpha output sets VideoToolbox
  `PrioritizeEncodingSpeedOverQuality`, keeping the project bitrate. If
  `AVAssetWriter.canApply(outputSettings:)` rejects it, export falls back to
  the default encoder priority. Only HEVC runs that check, because it costs
  about 35 ms per segment.
- Each video frame is currently represented by a layer-data sample time derived
  from project frame rate, segment time, FIT offset, and Layer Data FPS.
- Shared SwiftUI overlay views are rasterized with `ImageRenderer`, then drawn
  into an `AVAssetWriterInputPixelBufferAdaptor` pixel buffer.
- Only the first video frame of each Layer Data sample is rendered and drawn.
  Later frames with the same sample time append that same pixel buffer again;
  writers only read appended buffers. Profile draw counts and durations
  therefore cover rendered frames only.
- `ImageRenderer` returns 16-bit float extended-sRGB images. The full-frame
  path converts each render once with vImage into the 8-bit BGRA DeviceRGB
  pixel-buffer format (`ExportPixelBufferImageConverter`) before drawing.
  Per-overlay and layered images are drawn directly, because reading their
  pixels for conversion costs more than CoreGraphics drawing them.
- The loop waits for `isReadyForMoreMediaData` after rendering a frame and
  just before appending it, polling every 0.1 ms, so the encoder drains
  queued repeated frames while the next sample renders.
- MOV export now separates conservative static decor overlays from dynamic
  data overlays. Static decor renders once per task, and dynamic data overlays
  render only inside their padded union rect unless that rect covers most of
  the canvas.
- When the dynamic union rect covers most of the canvas, MOV export uses the
  full-frame single-layer path so fallback cases keep the original one-render,
  one-draw cost profile.
- When the dynamic union rect is full-frame but each dynamic overlay has a
  reliable smaller render rect, MOV export can use the per-overlay path:
  render each overlay into its padded local rect, then draw those overlay
  images into one pixel buffer context.

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

## Sixth Milestone

- Add a conservative per-overlay render path for full-frame-union exports whose
  individual overlay padded rects still cover less than 85% of the canvas in
  total.
- Keep v5 full-frame fallback for large single overlays or cases with static
  decor, so the new path does not split a no-benefit render.
- Same-sample reuse now caches the previous set of per-overlay `CGImage`
  renders and still appends every output video frame at its original
  presentation time.

## Final Default

- New projects default Layer Data FPS to 5 fps. The output video frame rate is
  unchanged, but overlay values update every 0.2 seconds by default so export
  can reuse more rendered overlay frames.
- The 5 fps benchmark on the fixed New York snapshot reduced total export time
  from Test12's 408.537s to 183.341s, with image render time dropping from
  282.182s to 134.333s.
- Profiling schema is v5. It adds `renderPath=perOverlay`,
  `overlayRenderPathEnabled`, `overlayRenderAreaRatio`, `overlayRenderCount`,
  `overlayDrawCount`, and JSON-only `overlayProfiles` for per-overlay render
  rects and timing totals.

## Seventh Milestone Candidate

- A conservative Route Map static-layer cache is tested inside the per-overlay
  path.
- Eligible route maps render their static base once per export task: map
  background/snapshot, route stroke, start/end markers, mask, border, and
  shadow.
- The moving current marker renders separately for each unique Layer Data
  sample and composites over the cached static route image.
- Route Map static caching is disabled when the route map stats bar is visible,
  because those values can change with elapsed time.
- Test8 confirmed a performance win but exposed a per-overlay compositing
  coordinate issue: overlay render rects are top-left SwiftUI coordinates,
  while pixel-buffer drawing needs CoreGraphics bitmap coordinates. The
  compositor now converts local overlay rects before drawing.

## Project Snapshot Workflow

- Use `Save Project Snapshot` in the Export dialog to write
  `running_overlay_project_snapshot.json`.
- Use `Restore Project Snapshot` to replace the current editor state with that
  snapshot before running a benchmark export.
- The snapshot stores exportable state: project settings, parsed activity timeline,
  media references, media folders, timeline, overlay layout, user asset
  references, and FIT source name.
- Runtime state is intentionally cleared on restore: selection, playback,
  media-pool preview, export progress, and undo/redo stacks.
- Video and FIT source files are not copied. Media items keep their existing
  file paths, so snapshots are intended for same-machine benchmark repeats.

## Automated Benchmark Workflow

Run a full snapshot export without opening the editor:

```bash
swift run RunningOverlay --benchmark-export running_overlay_project_snapshot.json
```

By default the command creates `running_overlay_benchmark_<timestamp>` in the
current working directory and writes the MOV outputs plus profiling JSON/CSV
there.

To choose a destination explicitly:

```bash
swift run RunningOverlay \
  --benchmark-export /path/to/running_overlay_project_snapshot.json \
  --benchmark-output /path/to/BenchmarkOut
```

The benchmark runner uses the same snapshot schema and export path as the UI:
settings, activity timeline, media references, timeline clips, overlay layout,
user assets, and FIT offset are restored from the snapshot. It prints segment
progress to stdout and exits with a non-zero code on failure.

To estimate whether clip-level parallel export is worth implementing in the
app, run the parallel process benchmark against the same snapshot:

```bash
scripts/parallel-export-benchmark.rb \
  running_overlay_project_snapshot.json \
  --jobs 2 \
  --output /path/to/parallel-export-benchmark
```

The script first runs the current serial `--benchmark-export` baseline, then
splits exportable timeline clips across worker snapshots and launches that many
headless exporter processes in parallel. It writes `benchmark_summary.txt`,
`benchmark_summary.json`, per-worker logs, shard snapshots, and each worker's
normal export profile files. Use `--skip-serial` when a fresh serial baseline is
already available, and `--prepare-only` to verify shard balance without running
exports.

This benchmark intentionally measures multi-process clip-level parallelism
without changing production export behavior. It is meaningful for projects with
multiple timeline clips that export to separate MOV files; it does not measure a
single long segment split into frame ranges.

A FIT/template-driven variant is available when no project snapshot or source
videos should be used:

```bash
swift run RunningOverlay \
  --benchmark-template-segments /path/to/activity.fit \
  --template Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate \
  --segments 10 \
  --segment-duration 5 \
  --codec proRes4444 \
  --benchmark-output /path/to/output
```

Use `--shard-index` and `--shard-count` to launch multiple processes against
disjoint synthetic segment subsets. A local 2026-06-30 run using
`476473199387771081.fit`, the Easy Run template, 10 synthetic 5-second segments,
and ProRes 4444 measured:

| Workers | Wall-clock | Speedup |
|---:|---:|---:|
| 1 | 23.640 s | 1.00x |
| 2 | 20.150 s | 1.17x |
| 3 | 21.199 s | 1.12x |
| 4 | 19.219 s | 1.23x |

The serial profile was dominated by `imageRenderDuration` (~16.9 s of
~22.3 s profiled export time), but cumulative render and draw time increased
under parallel load. Treat these results as evidence for bounded low-concurrency
clip export rather than unbounded parallelism.

## Profiling Files

UI exports write profiling files only in debug builds. All headless benchmark
commands write them in every build configuration, and the profile's
`buildConfiguration` field records which one produced it. Compare release
profiles with release profiles: Swift debug builds slow app-side model code
much more than SwiftUI and CoreGraphics framework rendering, so debug profiles
overstate model cost.

### Render Model Split

Pass `--profile-render-model` to `--benchmark-export` or
`--benchmark-template-segments` to split overlay render time:

- Before each unique render, the exporter evaluates the same
  `OverlayRenderModel` layouts that the export SwiftUI views build in their
  bodies, and records that time as `renderModelDuration` (task, segment, and
  per-overlay).
- That probe time is excluded from `imageRenderDuration`, which still includes
  the model work done inside SwiftUI view bodies. The SwiftUI view and
  rasterization share is therefore approximately
  `imageRenderDuration - renderModelDuration`.
- Probe-enabled runs evaluate model layouts one extra time per unique render,
  so compare `totalDuration` only against runs with the same setting.
- Model work done inside shared SwiftUI view bodies, outside the
  `OverlayRenderModel` layout functions, still counts toward the SwiftUI share.

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
- `overlayRenderPathEnabledCount`
- `overlayRenderAreaRatio`
- `overlayRenderCount`
- `overlayDrawCount`
- `buildConfiguration` (`debug` or `release`)
- `renderModelProfilingEnabled`
- `renderModelDuration`

Each segment records the same timing buckets plus `segmentName`,
`outputFileName`, `duration`, `frameCount`, JSON-only `slowFrames`
details for its 10 slowest frames, and JSON-only `overlayProfiles` details
when the per-overlay path is available. Each overlay profile records overlay
type, render rect, render area ratio, render count/duration, and draw
count/duration, plus `renderModelDuration` when model profiling is enabled.

The CSV file contains the same comparison-oriented metrics in a spreadsheet
shape: one `summary` row followed by one `segment` row per exported segment.
Use it to compare before/after exports from the same project snapshot.

For the third benchmark round, compare against the first and second local
profiling artifacts:

- v1 baseline: `<benchmark-output>/v1/export_profile.json`
- v2 layered fallback regression: `<benchmark-output>/v2/export_profile.json`
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

For the sixth benchmark round, look for `renderPath=perOverlay` on segments
whose full dynamic union previously forced `dynamicRenderAreaRatio=1`. The path
is expected to help only when `overlayRenderAreaRatio < 0.85`; otherwise v5
full-frame fallback should remain active.

For the next benchmark round, verify the Test8 performance improvement is kept
and that exported overlay positions match the editor preview.

## Fixed Benchmark Fixture

Export-performance rounds should use the same local, privacy-safe project
snapshot as the benchmark fixture:

```bash
<benchmark-fixtures>/running_overlay_project_snapshot.json
```

Run the benchmark through the non-interactive app entry point and write each
round to a new numbered directory:

```bash
swift run RunningOverlay \
  --benchmark-export "<benchmark-fixtures>/running_overlay_project_snapshot.json" \
  --benchmark-output "<benchmark-output>/round-10"
```

Do not commit benchmark snapshots that contain private FIT data, GPS traces,
media paths, or user assets.

The Test9 automated benchmark produced:

- `totalDuration`: 428.517s
- `imageRenderDuration`: 290.774s
- `pixelBufferDrawDuration`: 135.670s
- `renderPath`: `perOverlay`
- `reuseRate`: 0.666

Compared with Test8, image render time stayed slightly lower, but draw time
rose. The next optimization should therefore avoid increasing the number of
per-frame composited images unless it removes substantially more
`ImageRenderer` work.

## Rejected Distance Timeline Split

Test10 and Test11 tried a conservative Distance Timeline static/dynamic split
with overlay-local precomposition so the final pixel-buffer draw count would
stay flat. The slice was reverted because it increased `ImageRenderer` time
more than it reduced draw time:

- Test10: `totalDuration=435.685s`, `imageRenderDuration=362.332s`,
  `pixelBufferDrawDuration=71.044s`.
- Test11: `totalDuration=470.050s`, `imageRenderDuration=381.938s`,
  `pixelBufferDrawDuration=85.704s`.
- Test9 baseline: `totalDuration=428.517s`, `imageRenderDuration=290.774s`,
  `pixelBufferDrawDuration=135.670s`.

Conclusion: splitting an existing SwiftUI overlay into multiple SwiftUI
renders is not currently a good tradeoff for this project. Future large wins
should reduce `ImageRenderer` invocations or replace expensive SwiftUI overlay
renders, not create more SwiftUI render passes.

## Numeric Batch Candidate

Test12 targeted the remaining repeated `ImageRenderer` calls by batching simple
numeric overlays in the per-overlay path:

- Batchable types are standard numeric/text overlays such as heart rate, pace,
  cadence, elapsed time, real time, distance, elevation, power, temperature,
  and grade.
- Complex overlays stay separate: Distance Timeline, Route Map, Elevation
  Chart, Running Gauge, lap overlays, weather, and decor.
- The batch is enabled only when at least two numeric overlays fit inside a
  padded union rect whose area is below 45% of the canvas and smaller than the
  sum of their individual padded areas.
- The batch still renders through `SwiftUIOverlayLayerView`, so visual output
  should match the current per-overlay path. Profiling records the batch under
  the first grouped numeric overlay type.
- Test12 improved on Test9 and the change is kept:
  `totalDuration=408.537s`, `imageRenderDuration=282.182s`,
  `pixelBufferDrawDuration=124.412s`.
- `overlayRenderCount` dropped from 44,058 to 18,882 and `overlayDrawCount`
  dropped from 150,928 to 75,464.
- A frame extracted from Test12 confirmed the overlay positions match the
  expected preview layout.

## Release Build Profile Round (2026-10-11)

The earlier rounds and the 5 fps default benchmark were measured with debug
builds. This round repeated the template-segments benchmark with release
builds and `--profile-render-model` on an Apple M3: 10 synthetic 5-second
clips (1,500 frames at 30 fps, 250 unique renders at 5 fps Layer Data),
1920x1080, using the committed `synthetic-run.fit` and a local real FIT file.

| Run | Codec | Build | Total | Render | Model | Draw | Writer wait |
|---|---|---|---:|---:|---:|---:|---:|
| Real FIT, Race (full frame) | HEVC alpha | debug | 141.90 s | 90.57 s | 42.19 s | 7.91 s | 0.04 s |
| Real FIT, Race (full frame) | HEVC alpha | release | 15.51 s | 3.61 s | n/a | 7.75 s | 2.43 s |
| Real FIT, Interval Workout (per overlay) | HEVC alpha | release | 15.43 s | 3.80 s | n/a | 1.88 s | 7.90 s |
| Synthetic FIT, Race (full frame) | HEVC alpha | release | 15.48 s | 2.62 s | n/a | 4.46 s | 6.55 s |
| Real FIT, Interval Workout (per overlay) | ProRes 4444 | release | 5.64 s | 3.01 s | n/a | 1.89 s | 0.00 s |
| Real FIT, Race (full frame) | ProRes 4444 | release | 12.35 s | 3.71 s | n/a | 7.86 s | 0.02 s |

Model durations come from separate probe-enabled runs; release probe runs
measured 0.15-0.47 s of model time per task.

Findings:

- Debug profiles are not representative. The same real-FIT Race export took
  141.90 s in debug and 15.51 s in release; `OverlayRenderModel` evaluation
  alone was 42.19 s in debug and 0.47 s in release, because the debug build
  runs linear record scans and route geometry rebuilding unoptimized.
- In release builds, model computation is 5-13% of overlay render time.
  `intervalHUDBar` measured 6.7 ms per render with 0.2 ms of model work, so
  its cost is SwiftUI view construction and rasterization.
- Every release HEVC-with-alpha run finished in 15.4-15.5 s, regardless of
  template, render path, or app-side render and draw time (5.7-11.4 s), with
  the remainder spent waiting for `isReadyForMoreMediaData`. Running the
  same export as 2 or 4 shard processes in parallel took 14.89 s and 14.99 s
  wall-clock. HEVC-with-alpha 1080p export is bound by the hardware encoder
  on this machine (about 100 fps), and app-side render or draw reductions do
  not shorten it.
- With ProRes 4444 the encoder is not the limit, and app-side work dominates.
  The full-frame Race path spends 7.86 s of 12.35 s clearing and redrawing a
  full-canvas image into every pixel buffer, including the 1,250 frames that
  reuse the previous render.

Implications for the next optimization work:

- For HEVC with alpha, only reducing encoder work can make a large
  difference, for example encoder speed or quality properties, or encoding
  fewer distinct frames. Measure these before changing render code.
- For ProRes 4444, reusing the previous pixel buffer for frames with an
  identical Layer Data sample should remove most of the full-frame draw cost.
- Clip-level multi-process export does not help HEVC with alpha on a single
  media-engine machine.

## HEVC Encoder Parameter Round (2026-10-12)

The same release-build template-segments benchmark compared HEVC-with-alpha
compression properties on the real-FIT Interval Workout export. All variants
kept the 30 Mbps average bitrate unless noted.

| Variant | Total | Writer wait |
|---|---:|---:|
| Baseline | 15.46 s | 8.03 s |
| `PrioritizeEncodingSpeedOverQuality` | 10.22 s | 4.15 s |
| `PrioritizeEncodingSpeedOverQuality` + `RealTime` | 9.98 s | 4.02 s |
| `RealTime` | 15.73 s | 7.87 s |
| `AllowFrameReordering=false` | 16.56 s | 9.11 s |
| `TargetQualityForAlpha=0.5` | 15.45 s | 7.99 s |
| `MaxKeyFrameInterval=300` | 15.57 s | 8.10 s |
| `ExpectedFrameRate=30` | 15.47 s | 8.04 s |
| `Quality=0.5` without average bitrate | 15.15 s | 7.59 s |
| Append only frames whose Layer Data sample changed (variable frame rate, experiment only) | 4.18 s | 0.00 s |

Quality was measured by decoding all frames of the first three clips and
comparing them with a ProRes 4444 export of the same content, using
premultiplied color PSNR and alpha PSNR:

| Variant | Color PSNR | Alpha PSNR | Max alpha error | Output size (10 clips) |
|---|---:|---:|---:|---:|
| Baseline | 45.21 dB | 56.06 dB | 22/255 | 5.0 MB |
| Encoding speed priority | 45.04 dB | 52.48 dB | 28/255 | 6.6 MB |
| Variable frame rate | 45.18 dB | 55.98 dB | 22/255 | 1.3 MB |

Encoding speed priority is now the default for HEVC with alpha. After the
change, release benchmark totals were:

| Run | Before | After |
|---|---:|---:|
| Real FIT, Interval Workout (per overlay) | 15.45 s | 10.24 s |
| Real FIT, Race (full frame) | 15.49 s | 12.90 s |
| Synthetic FIT, Interval Workout (per overlay) | 15.15-16.33 s | 10.18 s |
| Synthetic FIT, Race (full frame) | 15.48 s | 10.37 s |

The real-FIT Race export is now app-bound: its writer wait dropped to 0.04 s,
and full-frame pixel-buffer drawing takes 8.04 s.

Variable-frame-rate output was not adopted. It produces about 5 fps average
frame rate files, which some editors may treat as constant frame rate, and it
needs an explicit `endSession(atSourceTime:)` at the clip end to keep the
duration exact. It needs NLE compatibility testing before it can become an
export option.

The variable-frame-rate run also showed that skipping 1,250 of 1,500
full-frame draws only reduced Race draw time from 7.82 s to 6.58 s. Most
full-frame draw cost is the first draw of each newly rendered `ImageRenderer`
image rather than repeated draws of a reused image, so reusing pixel buffers
for repeated samples would save little. Investigate the first-draw conversion
cost instead.

## First-Draw Conversion Round (2026-10-16)

After HEVC encoding speed priority, the real-FIT Race export was app-bound:
full-frame drawing took 8.04 s of 12.90 s.

Diagnosis:

- `ImageRenderer.cgImage` returns 16-bit half-float, premultiplied RGBA
  images in `kCGColorSpaceExtendedSRGB` (64 bits per pixel).
- The first CoreGraphics draw of a 1920x1080 render into the 8-bit BGRA
  DeviceRGB pixel buffer took 30-57 ms because every pixel is converted and
  color matched; drawing the same image again took about 0.6 ms because the
  converted data is cached. This explains why skipping repeated draws alone
  saved little.
- Reading `ImageRenderer` image pixels is itself expensive, because the
  pixels are produced lazily: about 12 ms for a full-frame image and about
  1.7 ms for a typical per-overlay image, whether through
  `CGDataProviderCopyData` or `vImageBuffer_InitWithCGImage`. The vImage
  conversion itself took 0.09 s for 2,251 overlay images.

Results with ProRes 4444 (app-bound), real FIT, 10 x 5-second clips:

| Variant | Race (full frame) | Easy Run (per overlay) |
|---|---:|---:|
| Pixel-buffer reuse, CoreGraphics first draw | 11.52 s (draw 6.39 s) | 5.42 s (draw 1.39 s) |
| Pixel-buffer reuse, vImage conversion of every render | 8.82 s (draw 0.53 s, render +3.06 s) | 8.96 s (render +4.06 s) |

The adopted change:

- Re-append the previous pixel buffer for frames whose Layer Data sample
  matches the previous frame, on every render path.
- Convert full-frame renders once with `vImageBuffer_InitWithCGImage` into the
  pixel-buffer format; leave per-overlay and layered images to CoreGraphics.

Rejected alternatives:

- Rendering SwiftUI directly into the pixel-buffer `CGContext` with
  `ImageRenderer.render(rasterizationScale:renderer:)` was slower (16.60 s of
  render for 75 frames versus 1.12 s) and visibly changed shadows and glows,
  for example the Distance Timeline progress marker halo. It violates
  preview/export parity.
- Converting per-overlay images with vImage was slower than drawing them,
  because of the lazy pixel read cost above.

Repeated-frame reuse exposed two writer-side costs on the synthetic-FIT
Race ProRes 4444 export, which has sparse content and cheap draws (three
interleaved runs each unless noted):

| Build | Total |
|---|---:|
| `main` before this work | 5.65-5.72 s |
| HEVC speed priority build | 6.03-6.07 s |
| Pixel-buffer reuse and full-frame conversion | 6.38-6.41 s |
| + `canApply` only for HEVC | 6.04-6.06 s (two runs) |
| + wait for the writer just before append, polling every 0.1 ms | 5.86-5.89 s (two runs) |

- `AVAssetWriter.canApply(outputSettings:forMediaType:)` cost about 35 ms per
  segment, so it now runs only when HEVC adds the optional property.
- Reused frames append in bursts. Waiting for writer readiness before
  rendering left the encoder idle while the next sample rendered, and 1 ms
  polling overshot each wait. Waiting just before append with 0.1 ms polling
  reduced writer wait from 0.53 s to 0.33 s.
- With the `canApply` fix and 1 ms polling, full-frame vImage conversion was
  neutral on this sparse export (6.11-6.13 s with conversion versus
  6.12-6.18 s without) and still
  saved about 3.4 s on the real-FIT Race export (7.98-8.02 s versus
  11.44-11.48 s).
- The remaining 0.2 s gap to `main` on this export is writer wait between
  repeated-frame bursts. Removing it would need rendering and appending to run
  concurrently, which is not worth the restructuring for this case.

Parity, decoding ProRes 4444 exports of the first three clips and comparing
with the previous build: Interval Workout was bit-identical; Race had
64.70 dB color PSNR and identical alpha; Easy Run had 76.43 dB color PSNR and
identical alpha.

Encoder floor: a standalone writer appending pre-drawn 1920x1080 frames in
runs of six (5 fps Layer Data at 30 fps) took 15.09-15.14 s for 1,500 frames
with default HEVC-with-alpha settings (99 fps), 10.34 s with encoding speed
priority (145 fps), and 2.33 s with ProRes 4444.

Final release benchmark, Apple M3, 1920x1080, 10 x 5-second clips (1,500
frames at 30 fps, 5 fps Layer Data). `main` is the build before this work,
"speed" adds HEVC encoding speed priority, and "final" adds this round.
Builds were interleaved per configuration; HEVC values are the mean of two
runs, ProRes values are single runs. Wall-clock comes from the
template-segments benchmark summary.

| FIT | Template (path) | Codec | `main` | Speed | Final | Speedup |
|---|---|---|---:|---:|---:|---:|
| Real | Interval Workout (per overlay) | HEVC alpha | 15.32 s | 10.19 s | 10.22 s | 1.50x |
| Real | Race (full frame) | HEVC alpha | 15.73 s | 11.82 s | 10.61 s | 1.48x |
| Real | Easy Run (per overlay) | HEVC alpha | 15.61 s | 10.64 s | 10.64 s | 1.47x |
| Synthetic | Interval Workout (per overlay) | HEVC alpha | 15.07 s | 10.20 s | 10.20 s | 1.48x |
| Synthetic | Race (full frame) | HEVC alpha | 15.37 s | 10.38 s | 10.41 s | 1.48x |
| Synthetic | Easy Run (per overlay) | HEVC alpha | 15.27 s | 10.36 s | 10.36 s | 1.47x |
| Real | Interval Workout (per overlay) | ProRes 4444 | 5.08 s | 5.36 s | 4.35 s | 1.17x |
| Real | Race (full frame) | ProRes 4444 | 11.87 s | 12.20 s | 7.79 s | 1.52x |
| Real | Easy Run (per overlay) | ProRes 4444 | 5.93 s | 6.25 s | 5.06 s | 1.17x |
| Synthetic | Interval Workout (per overlay) | ProRes 4444 | 4.46 s | 4.74 s | 3.78 s | 1.18x |
| Synthetic | Race (full frame) | ProRes 4444 | 5.83 s | 6.20 s | 5.94 s | 0.98x |
| Synthetic | Easy Run (per overlay) | ProRes 4444 | 5.46 s | 5.73 s | 4.57 s | 1.20x |

Every HEVC-with-alpha configuration now finishes within 3% of the measured
10.34 s encoder floor, so default exports are encoder-bound on this machine.
Further app-side rendering work cannot shorten them; only encoder changes,
such as the rejected variable-frame-rate option, or hardware with more media
engines can.

## Follow-Up Directions

Default HEVC-with-alpha exports are encoder-bound after the 2026-10-16 round,
so the directions below only shorten ProRes 4444 exports or a future
variable-frame-rate option:

- Validate variable-frame-rate output (append only changed Layer Data
  samples, with `endSession(atSourceTime:)` at the clip end) in DaVinci
  Resolve, Final Cut Pro, and Premiere Pro before offering it as an option.
- Measure on Apple silicon with more media engines, where the HEVC floor may
  be lower and app-side render time may matter again.
- Overlap rendering of the next Layer Data sample with appending repeated
  frames to remove the remaining writer wait between bursts.
- Expand static-layer eligibility beyond decor overlays when a component can
  prove it is independent of `elapsedTime`.
- Expand per-overlay eligibility to static-safe overlays once visual parity is
  proven.
- Add dirty-region change detection so overlays whose sampled output did not
  change can reuse their previous local render independently.
- Avoid SwiftUI static/dynamic splits that require additional `ImageRenderer`
  passes unless a benchmark proves the render-time reduction exceeds the extra
  render/composition overhead.
- Adaptive quality presets for draft vs final exports.
- Optional hardware-accelerated composition path after CPU-side profiling has
  identified the real bottlenecks.
