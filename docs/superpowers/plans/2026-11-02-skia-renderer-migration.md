# Skia Renderer Migration Plan

> **For agentic workers:** This plan is designed for one lead agent plus parallel
> module agents running in sibling git worktrees through Herdr (`hc`). Read
> `AGENTS.md`, `docs/architecture.md`, `docs/development/export.md`, and
> `docs/development/overlays-and-preview.md` before starting.

**Goal:** Replace SwiftUI `ImageRenderer` overlay rendering with one Skia
renderer shared by preview, export, and the future editor helper, without
regressing visual parity or export speed.

**Scope:** Overlay widgets only. The app's Inspector, timeline, panels, and
other app chrome stay SwiftUI.

**Foundation branch:** `claude/skia-gpu-spike` (the GPU spike worktree with
Metal zero-copy, per-module benchmarks, and the Skia bridge). Commit the
uncommitted spike work first, then branch every workstream from it.

**Status (2026-11-03, product cutover):** The maintainer accepted the Graphite
sample and authorized Skia as the sole product overlay engine. ADR 0011 is the
current decision authority. Skia-enabled Debug/Release now default to Skia;
m159 defaults to Graphite. Release preview is connected, and SwiftPM bundle
packaging embeds/signs the SDK. SwiftUI remains a Debug/test oracle until final
preset/packaging acceptance. Further performance work is bounded to one
prefetch experiment; basic faster-than-real-time throughput is sufficient.
Native Xcode/CI SDK integration and distribution validation remain open.
Historical workstreams and checklists below are not current instructions.

---

## 1. Decisions

1. **One renderer, two hosts.** Skia draws overlay pixels. Preview and export
   both call the same `SkiaOverlayFrameRenderer`; they differ only in the
   target surface (Metal drawable vs. `CVPixelBuffer`/`IOSurface`).
2. **`OverlayRenderModel` stays the layout source of truth.** Do not duplicate
   geometry or style math in the Skia renderer. Port drawing, not layout.
3. **SwiftUI remains the visual oracle during migration.** Every module port is
   validated against the current `OverlayShared*View` output with golden frames
   before it becomes the default.
4. **Feature-flag the backend.** `RUNNING_OVERLAY_RENDERER=swiftUI|skia` (and a
   debug settings toggle) selects the backend per run. Per-module fallback
   stays available until the module's parity gate passes.
5. **No Graphite work in this plan.** Ganesh-on-Metal is the shipping backend
   for now. The `skb_*` bridge is the seam that allows a future Graphite or
   Windows backend without rewriting Swift drawing code.
6. **No project-file or timing-domain changes.** The renderer consumes the same
   `OverlayLayout`, `ActivityTimeline`, `OverlayRenderContext`, and elapsed-time
   values as today.

## 2. Success Criteria

| Area | Gate |
| --- | --- |
| Visual parity | Per-module golden frames at 1280x720, 1920x1080, 3840x2160; mean channel delta and changed-pixel ratio within the reviewed threshold; human review for any snapshot update |
| Easy Run vertical slice | All Easy Run elements render identically in preview and export through Skia |
| Preview | 30 fps at 1080p and 4K on the development Mac; no main-thread stall over one frame budget |
| Export speed | 1080p ProRes 4444 at least 1.8x the current SwiftUI exporter; 4K ProRes at least 1.15x; HEVC alpha within 3% |
| Alpha and color | Transparent background, premultiplied alpha, BT.709 tags preserved for both codecs |
| Determinism | No network access in tests; MapKit and weather snapshots supplied by fixtures/providers |
| Tests | `./scripts/check.sh` and focused visual tests pass |
| Packaging | Skia binary bundled, signed, licensed, and accepted by the App Store validation scripts |

## 3. Target Architecture

```
ProjectDocument
  └─ OverlayLayout + ActivityTimeline + OverlayRenderContext
       └─ OverlayRenderModel (geometry, text runs, colors, progress)
            └─ OverlayFrameRenderer protocol
                 ├─ SwiftUIImageRendererBackend   (migration oracle, removable)
                 └─ SkiaFrameRendererBackend      (target)
                      ├─ SkiaPreviewCanvasView     (CAMetalLayer / drawable)
                      ├─ SkiaOverlayVideoExporter  (CVPixelBuffer / IOSurface)
                      └─ headless helper           (future editor plugin)
```

Current pieces to reuse:

- `OverlayRenderModel` layout functions for every module.
- `OverlayShared*View` SwiftUI views as the visual oracle.
- `OverlayFrameRenderer` (legacy Core Graphics) as a semantic reference for
  modules whose CG drawing still matches the SwiftUI output.
- `ExportRenderPlan`, static-layer cache, and frame-reuse logic only where
  benchmarks still justify them; GPU full-frame rendering may make the
  per-overlay plan unnecessary.

## 4. Workstreams

### Phase 0 — Foundation (serial, blocking)

- [ ] Commit the GPU spike to `claude/skia-gpu-spike`; tag it as the migration
      baseline.
- [ ] Decide binary distribution: vendor the pinned `libskia.dylib` in the repo
      or a build script. Record license notices in `docs/assets-and-licenses.md`.
- [ ] Add `OverlayFrameRendererBackend` protocol and `RUNNING_OVERLAY_RENDERER`
      selection; keep SwiftUI as the default.
- [ ] Extract `SkiaFrameRendererBackend` from `SkiaEasyRunRenderer` with a
      stable per-module dispatch table.
- [ ] Extend the C bridge with the primitives the remaining modules need:
      arbitrary paths, arcs, dashed strokes, rect clip, linear/radial
      gradients, multi-run text with alignment/truncation, image tint/opacity,
      and blend modes if required.
- [ ] Add a golden-frame harness: render one module at a fixed time with both
      backends, diff against the SwiftUI oracle, write PNGs and metrics under a
      temporary directory, and fail on threshold breaches.
- [ ] Add an asset provider for SF Symbols and MapKit snapshots so the Skia
      path never performs network or async work during a frame.

Exit criteria: the protocol and harness build; the minimal numeric module
renders through both backends with a reviewed diff.

### Phase 1 — Easy Run vertical slice (serial, de-risks integration)

- [ ] Port the minimal numeric preset, distance timeline, route map, and weather
      widget from the spike to the production renderer module.
- [ ] Add `SkiaPreviewCanvasView` (`NSViewRepresentable` + `CAMetalLayer` or
      `MTKView`) with a persistent Metal context, display-link rendering, and
      drawable presentation on the Skia command queue.
- [ ] Keep SwiftUI selection/drag affordances on top of the Skia canvas; use
      `OverlayRenderModel` rects for hit testing.
- [ ] Add `SkiaOverlayVideoExporter` with the zero-copy `CVPixelBuffer` path,
      ping-pong contexts, frame reuse, progress, cancellation, and security-scoped
      destination handling.
- [ ] Run the Easy Run golden frames and the 1080p/4K ProRes benchmarks.

Exit criteria: Easy Run preview and export use Skia behind the feature flag;
parity and speed gates pass; SwiftUI remains selectable.

### Phase 2 — Module ports (parallel)

Group modules by shared drawing primitives. Each group owns new files and tests;
shared bridge/renderer files stay with the lead. Phase A inventories are
complete; the frozen bridge API and the Phase B decisions are recorded in
`notes/2026-11-02-skia-bridge-freeze.md`.

| Group | Modules | Notes |
| --- | --- | --- |
| T: text presets | 10 canonical numeric presets plus 5 deprecated presets; decor text/icon/solid color | The spike covers only the minimal preset. Port preset composition, borders, backgrounds, dividers, stripes, and icon tinting. |
| D: distance + gauge | distance timeline (all variants), running gauge | Arcs, ticks, progress rings, stats bars. |
| E: elevation | elevation chart (all profiles, dual-area fills, static-fill layers) | Paths, gradients, clipping, marker; reuse the existing static-fill parity idea. |
| R: route + weather | route map (MapKit snapshots, stats bars, marker), weather widget (all styles, SF Symbols) | Image providers, polyline, map opacity, icon cache. |
| I: interval family | interval HUD bar, interval timeline, interval countdown, interval work summary, zone edge bar | Text-heavy; mostly shared primitives and layout models. |

Each module task must include:

- [ ] Skia draw implementation in a new module file.
- [ ] Golden frames against the SwiftUI oracle at three resolutions.
- [ ] Focused unit tests for layout consumption and edge cases.
- [ ] Module documentation update under `docs/overlay-modules/`.
- [ ] Feature-flag fallback until parity review passes.

Exit criteria: every module can render through Skia; unsupported modules still
fall back cleanly; no module changes shared files without lead review.

### Phase 3 — Preview cutover

- [ ] Make Skia the default preview backend.
- [ ] Verify resize, backing scale, canvas background, video compositing,
      selection, drag, snapping, guides, and keyboard nudging.
- [ ] Verify 30 fps at 1080p and 4K with the full template set.
- [ ] Keep the SwiftUI preview path behind the flag for one release.

### Phase 4 — Export cutover

- [ ] Make Skia the default export backend for ProRes 4444 and HEVC alpha.
- [ ] Re-evaluate `ExportRenderPlan` static/dynamic/per-overlay branches; keep
      only branches that still beat full-frame GPU rendering.
- [ ] Re-run the fixed benchmark suite (1080p/4K, both codecs, synthetic Easy
      Run and the fixed project snapshot).
- [ ] Remove the SwiftUI `ImageRenderer` export path and its dead tests after
      the fallback window.
- [ ] Verify App Store packaging, code signing, notarization, and license
      notices.

### Phase 5 — Editor helper (follow-on)

- [ ] Extract a headless render entry point that accepts a job file.
- [ ] Resolve proof of concept: launch the helper from a panel, render one
      frame, import it.
- [ ] Golden-frame comparison between app export and editor-imported frames.

## 5. Parallel Development With Herdr

### Worktree layout

```sh
# after committing the foundation
git worktree add ../running_overlay_skia_text    -b claude/skia-text    claude/skia-gpu-spike
git worktree add ../running_overlay_skia_charts  -b claude/skia-charts  claude/skia-gpu-spike
git worktree add ../running_overlay_skia_route   -b claude/skia-route   claude/skia-gpu-spike
git worktree add ../running_overlay_skia_intervals -b claude/skia-intervals claude/skia-gpu-spike
git worktree add ../running_overlay_skia_preview -b claude/skia-preview claude/skia-gpu-spike
```

### Launching agents

```sh
hc run --bg --name skia-text --cwd ../running_overlay_skia_text \
  claude "Read docs/superpowers/plans/2026-11-02-skia-renderer-migration.md. Implement Group T only. Own only Sources/RunningOverlay/Render/Skia/Modules/Text*.swift and Tests/RunningOverlayTests/SkiaText*.swift. Do not edit shared bridge or renderer files; report needed primitives to $HC_TERMINAL_ID. Run focused tests and golden frames. Report changed behavior, tests, gaps, and files. Do not commit or start subagents."
```

Repeat for `skia-charts` (Groups D + E), `skia-route` (Group R), and
`skia-intervals` (Group I). Start `skia-preview` in parallel with the foundation
because it is independent of module ports.

### Lead loop

```sh
hc ls
hc wait --children all
hc read --lines 120 skia-text
hc send skia-text "Focus on the pill and metric-card presets first."
```

Rules:

- Maximum four module agents at once; run performance benchmarks serially.
- One owner per file. Shared files: `Sources/CSkiaBridge/**`,
  `SkiaFrameRendererBackend.swift`, `Package.swift`, `OverlayRenderModel.swift`,
  `docs/architecture.md`, and the ADR.
- Agents report blockers instead of editing shared files.
- Merge order: foundation, vertical slice, text presets, distance/gauge,
  elevation, route/weather, interval family, preview, export.
- Do not commit or push from module agents; the lead reviews and commits.

## 6. Risks

| Risk | Mitigation |
| --- | --- |
| Ganesh deprecation / third-party prebuilt | Pin and vendor the binary, keep the bridge seam, evaluate Graphite separately |
| Text and shadow parity | Use CoreText shaping, golden frames, and human-reviewed snapshot updates |
| SF Symbols and MapKit assets | Rasterize through AppKit into cached BGRA images; inject snapshots before frame rendering |
| Metal drawable presentation | Prove the `CAMetalLayer` + Skia queue presentation in Phase 1 before module breadth |
| App Store review and binary size | Bundle the 5.7 MB dylib, sign it with the app, update notices and validation scripts |
| Preview/video compositing | Keep the video layer beneath the transparent Skia canvas; verify alpha and color space |
| Parallel merge conflicts | File ownership, foundation first, serialized benchmark runs |
| Scope creep | Easy Run vertical slice first; deprecated text presets last |

## 7. First Week

1. Approve this plan and commit the GPU spike foundation.
2. Start the foundation agent and the preview-host agent in parallel.
3. Create the first module worktrees once the bridge API is frozen.
4. Review the Easy Run vertical slice: golden frames, 1080p/4K benchmarks, and
   preview smoothness.
5. Only then open the remaining module groups.
