# Overlay and Preview Development

## Product Renderer

Skia-enabled builds use `SkiaPreviewCanvasView` in Debug and Release. Skia
draws overlay pixels; SwiftUI owns editor chrome, hit targets, selection and
guides. Release has no renderer toggle. Debug retains the SwiftUI visual oracle
via `RUNNING_OVERLAY_RENDERER=swiftUI` and the preview header toggle. Both hosts
consume `OverlayRenderModel` and `SkiaEasyRunRenderer`; new product rendering
behavior belongs in Skia. See [ADR 0011](../adr/0011-skia-product-renderer.md).

The standalone legacy Core Graphics renderer is removed. SwiftUI comparison
views and the SDK-free path remain on main for several releases, with a
pre-cleanup archive at `archive/swiftui-renderer-2026-11-04` on origin. See
[ADR 0012](../adr/0012-staged-legacy-renderer-retirement.md) before removing them.

### Phase 5: Overlay Editing

- Status: in progress.
- Add overlay element creation.
- Render overlay elements over preview.
- Support selection, dragging, scaling.
- Implement initial font controls.
- Bind elements to sampled FIT data at playhead.

Current implementation:

- `OverlayValueFormatter` formats overlay values from `ActivityTimeline` at the current playhead.
- `ActivityTimeline` supports interpolation for distance, heart rate, pace, elevation, cadence, power, and calories.
- Overlay preview and Inspector value display use the project Layer Data FPS setting, so data values update at the configured cadence rather than every UI refresh.
- Inspector overlay UI follows the dark tool-panel design spec in `docs/design/panels/inspector/inspector-ui.md`, with tokenized colors, spacing, compact added-overlay rows, and selected-overlay detail screens. Add-overlay tiles now live in the left `Overlay Pool`.
- Project Settings Font Library persists favorite overlay-menu fonts and the default font family globally; its `Restore Defaults` action returns to the default monospaced overlay set (`PT Mono`, `Monaco`, `Menlo`, `Andale Mono`) with `PT Mono` as the default.
- Overlay detail panels share reusable inspector modules for cross-overlay consistency: `CollapsibleLayoutInspectorSection` + `OverlayLayoutInspectorRows` (Layout) and `CollapsibleStatsBarInspectorSection` + `OverlayStatsBarInspectorRows` (Stats Bar). New detail views should reuse these modules instead of creating per-overlay variants.
- Interval Timeline uses the same fixed footer pattern as other dense overlay detail views: header and `Reset` / `Done` footer stay pinned while Timeline, Current, Rail, Labels, Background, Border, and Effects sections scroll.
- Shared `Layout` rows are now fixed to `Position`, `Scale`, `Width`, `Height`, and `Opacity`; `Rotation` is intentionally removed from the shared Layout section across overlay detail panels.
- Inspector default width is 460 px and minimum width is 460 px; the panel is user-resizable through the custom `HorizontalResizeHandle`, and `ParameterPanelView` does not impose its own width frame so internal outer/detail/editing state switches cannot resize the right column or squeeze tile content.
- Inspector segmented controls are implemented with native SwiftUI segmented `Picker` (`.pickerStyle(.segmented)`) instead of custom button rows, including shared dense controls used by the Running Gauge, Route Map and generated component detail views.
- Preview overlay elements can be dragged and clamped within the preview coordinate space.
- Preview overlay hit shapes are applied before position layout so each element only intercepts pointer input inside its rendered bounds; clicking the remaining canvas clears the current overlay selection.
- Preview drag uses measured rendered overlay frames for snapping: with safe guides enabled, overlay edges snap to 90%/80% guide lines and overlay center axes snap to the canvas center crosshair; visible overlays also snap to each other's left/center/right and top/center/bottom alignment lines during drag.
- Inspector supports selected overlay font family, font weight, font size (value text), scale, color presets, independent label/unit controls, and advanced background controls.
- SwiftUI overlay previews route configurable text through the shared overlay font helper. macOS system UI font family aliases such as `SF Pro` and `SF Pro Display` render with `Font.system(size:weight:)` to avoid SwiftUI font descriptor weight diagnostics. Custom font families resolve through AppKit to the concrete PostScript face for the selected weight before creating `Font.custom(...)`, so multi-weight families such as JetBrains Mono use their Regular/Medium/SemiBold/Bold faces. Visible weight changes still depend on whether that family provides matching weight faces, so single-weight families such as Monaco may not visibly respond to every weight option.
- Numeric readings (heart rate, HR zone, pace, average and lap pace, calories, elapsed and real time, date, distance, elevation and elevation gain, cadence, power, running dynamics, temperature, grade) are the bundled `studio.numeric` component (ADR 0014). The Overlay Pool Metrics tab adds one preset per metric through `OverlayComponentLibraryItem.numericPresets`; the Inspector is the generated `OverlayComponentDetailView`. The native numeric element types, `NumericOverlayDetailView`, text presets, the Skia/SwiftUI numeric renderers and the numeric-only `OverlayStyle` fields and setters were removed without migration: decoding drops saved elements of those types (`OverlayTemplateElementList`) and opening a project reports how many were removed. Custom Numeric, the manual temperature fallback, numeric background fade/blur and border, and separate value/label/unit opacity were dropped with them.
- `OverlayMetric` is the metric vocabulary shared by components (`metric(id, unit...)`), interval HUD slots, running gauge regions and route-map stats slots. `OverlayValueFormatter.components(for: OverlayMetric, unit:customLabel:activity:elapsedTime:)` is the one numeric formatter; `components(for: OverlayElementType, ...)` only describes non-metric overlays for layer-list previews and chart labels. Elapsed Time renders active elapsed time from `ActivityTimeline.activeElapsedTime(at:)`.
- Components are top-leading anchored. Preview drag of a component uses the canvas pointer location plus a grab offset and the top-leading snap/clamp path, the behavior native numeric overlays had.
- `NumericOverlayDetailView`'s shared swatch and font shortcuts live in `InspectorPresets`; the `InspectorDense*` primitives are unchanged in `InspectorDenseComponents.swift`.
- Shared background Fade Out uses `OverlayFeatherMaskRenderer`, a distance-field rounded-rectangle alpha mask reused by SwiftUI preview and Route Map rendering. The mask fades only the background surface to transparent; it does not fade foreground text/icons or sample/blur the underlying video.
- Running Gauge is the bundled `studio.running-gauge` component, a composite circular dashboard with distance, elapsed time, pace, and heart rate in one module. The native `runningGauge` element type was removed without migration (ADR 0015); its Skia renderer remains as the component's drawing module.
- The running gauge component exposes its dial, ring, tick, divider, region, and typography parameters through the generated component Inspector.
- Route Map is available as a featured overlay module backed by FIT GPS latitude/longitude when present.
- Route Map exposes line color mode and Glow controls through the Inspector.
- Route Map preview attempts a MapKit snapshot when the map background is enabled and falls back to a local dark grid when a snapshot is unavailable.
- Route Map export preloads MapKit snapshots once before MOV/PNG rasterization and passes them into the shared SwiftUI Route Map view as static render assets; if snapshot loading fails, export falls back to the local route/map grid.
- Inspector supports normalized X/Y position entry plus shadow opacity and radius controls.
- Up and down arrow keys nudge the selected overlay element vertically by one percent of the preview canvas.
- Overlay Pool shows add tiles grouped by Metrics, Visuals and Components; clicking a Visuals tile creates the matching bundled `studio.*` component through `ProjectDocument.addComponentFromLibrary`, never a native element. Decor tiles map to their component ports but the category is currently hidden. Native element types still decode and render for projects and templates saved earlier. New tiles select the element and open the generated component Inspector. Featured add tiles use the same card shape and border treatment as other tiles without a left-side blue accent strip.
- Inspector shows a dark outer state when no overlay element is selected, but it only contains `Added Overlays`; it no longer carries the selectable overlay catalog.
- Inspector added-overlay rows show icon, type, live value preview, visibility toggle, lock toggle, delete, and detail navigation without sorting affordances.
- Added Overlays rows expose a context menu (`Copy Properties` / `Paste Properties`) for overlay configuration transfer.
- Overlay visibility now gates both preview and export rendering across Skia and the SwiftUI oracle.
- Overlay lock is persisted and currently blocks Preview canvas selection/drag plus position writes in `ProjectDocument.moveOverlay` / `setOverlayPosition`.
- Overlay configuration paste is category-gated through `OverlayElementType.pasteCategory`; decor overlays paste only within the decor group and components within components.
- Distance Timeline is a dedicated module with minimal, dense, sport, splits, glass, neon, lower-third, and route presets, backed by `DistanceTimelineStyle`.
- Distance Timeline preview/export rendering supports distinct progress treatments, optional system-icon media slots for sport/lower-third, border/background controls, ticks, marker, glow, fade amount, route elevation underlay, and sampled GPS route geometry when available.
- Distance Timeline Value is separate from Label, owns the value font controls, can be disabled, can switch between current/total distance and current distance only, switches metric/imperial units, and supports a Custom Values master toggle that expands four inline metric slots with independent group gap, item gap, size, color, and opacity. Group gap offsets the whole custom group without compressing custom text or changing item gap.
- Distance Timeline Value stays top-anchored while Progress Gap adjusts only the distance from the Value row to the progress track.
- Distance Timeline adds fine-grained controls for Value-to-progress gap, Progress Marker style/color, Label font/color/size/weight and Label-to-Value gap, plus Axis Label font/color/size/weight. Preview and export use the same `DistanceTimelineStyle` fields.
- Distance Timeline Percent was removed from Content and represented by the dedicated Stats Bar, which supports up to four metric slots, top/bottom/left/right placement, separate Inside mode for all four sides, adjustable width/height, item gap, and X/Y offset.
- Route Map Stats Bar now follows the same full shared control surface as Distance Timeline (Placement, Inside, Layout, Size, Width, Offset, Item Gap, Background, Dividers, Radius, Slot 1-4), with Enabled in the section header.
- Route Map and Distance Timeline Stats Bars now share a single renderer path in both Preview and Export (based on the Distance Timeline Stats Bar rendering logic), so future overlay modules can reuse one rendering implementation.
- For Route Map, when Stats Bar is inside the container it reserves map content padding so route lines are not covered; inside bar background is clipped by container shape/radius for a fused edge appearance.
- For Route Map left/right Stats Bar placements, rendering always switches to vertical stack flow and applies `itemSpacing` as row gap.
- Dense and Splits Distance Timeline progress fills render as solid bars; tick marks and axis labels provide the technical/split visual detail.
- The Glass preset no longer fakes a glass fill; its background is disabled until a real blur/material effect is implemented.
- Distance Timeline axis labels use separate **Start / Finish** and **More Points** toggles, each with its own below/above placement and offset; Mode switches start/finish copy vs distance numerals (`0 <unit>` origin); Axis typography also styles the optional marker distance label. Marker size is a dedicated scale multiplier on the progress marker.
- Distance Timeline background/border bounds expand to cover Axis Labels and Stats Bars with Inside enabled at their current side/offset, while attached outside Stats Bars keep their own bar background. Preview selection uses the same dynamic bounds.
- Distance Timeline Stats Bar placement uses the full content bounds, including Axis and Marker labels. Inside only merges the bar into the timeline background/border; all placements remain adjacent to content instead of covering progress or labels.
- Metric picker menus for Distance Timeline custom values, shared Stats Bars, Running Gauge regions, and Interval HUD Bar metric rows derive their selectable activity metrics from `ActivityMetricCatalog.selectableElementTypes`. Adding a new numeric activity metric to `OverlayElementType` should make it appear in these menus after adding the enum bridge case.
- Distance Timeline ticks expose density control, and left/right Stats Bar backgrounds expand to cover all vertical slots.
- Distance Timeline media slots use the generic `OverlayIconSlot` model; the current UI exposes it only for Distance Timeline, but the Codable data and deterministic SVG renderer are reusable by other overlay modules.
- Distance Timeline SVG import embeds static or animated SVG source in `OverlayStyle.distanceTimeline.mediaSlot`; preview and export sample animated SVG from overlay elapsed time so rendered frames are deterministic.
- Interval Timeline is available as a horizontal interval-workout schedule overlay that complements Interval HUD Bar: it uses existing `ActivityTimeline.laps`, renders as a compact title-free timeline rail, keeps the current lap centered and enlarged by default, and summarizes hidden repetitions for high-count workouts such as `1min x25`. See `docs/design/overlays/interval-timeline/interval-timeline-overlay-ui.md` and `docs/overlay-modules/interval-timeline-overlay.md`.
- Interval Timeline modes are explicit: Centered shows a neighbor window, while Full shows all enabled segments. Full mode supports Equal and Duration segment layouts, and Timeline controls can independently hide WU, Rest, and CD segments.
- In Full + Equal mode, the Current Width slider starts at `Equal` and can increase the current segment's target share without changing the default equal-width layout.
- Interval Timeline labels are direct display settings: current active laps use Work Dist/Time, current non-active laps use Rest Kind/Dist/Time, and non-current neighbor labels can be Off, Distance, or Time.
- Interval Timeline centered overflow uses compact `···` edge hints only; WU/CD ghost labels and `xN` hidden-count boxes are not rendered.
- Interval Countdown is available as a compact circular current-segment timer for structured workouts. It uses `ActivityTimeline.currentLap(at:)`, current lap remaining time, and `IntervalKindColorPreferences` for group-colored progress. Preview and export share `OverlayRenderModel.intervalCountdownLayout(for:in:)`. See `docs/design/overlays/interval-countdown/interval-countdown-overlay-ui.md` and `docs/overlay-modules/interval-countdown-overlay.md`.
- Interval Work Summary is available as a short-lived post-work-lap summary card for structured workouts. It uses `ActivityTimeline.lastActiveLap(at:)`, renders only within the configured display window after an active lap ends, and shares `OverlayRenderModel.intervalWorkSummaryLayout(for:in:)` between preview and export. See `docs/design/overlays/interval-work-summary/interval-work-summary-overlay-ui.md` and `docs/overlay-modules/interval-work-summary-overlay.md`.
- Zone Edge Bar is available as an independent HR/pace zone overlay for edge-pinned or free placement. It reads Project Settings HR/pace zones and thresholds, renders current and threshold markers, supports horizontal and vertical bars, and shares the HR-zone palette used by Project Settings and Interval HUD Bar. See `docs/design/overlays/zone-edge-bar/zone-edge-bar-overlay-ui.md` and `docs/overlay-modules/zone-edge-bar-overlay.md`.
- Elevation chart overlays render line/area charts with playhead markers; Smoothing filters quantized elevation samples and draws curved paths in both preview and export, including Progress mode. Current marker sizes are resolved in `OverlayRenderModel` from the shared canvas scale and the marker size multiplier so preview and SwiftUI export remain proportional.
- Running gauge components render circular ticks, a progress ring, section dividers, and core run metrics in both preview and export.
- Route Map overlays render the route path, start marker, finish marker, and current-position marker in both preview and export.
- `OverlayRenderModel` provides the shared layout data used by SwiftUI preview and AVFoundation export rendering.
- Preview overlay positions, drag deltas, guides, font sizes, padding, and chart dimensions are based on the fitted project canvas inside the preview area, so resizing split panes keeps overlays anchored to the same normalized video position.
- Preview can show 90%/80% safety guides and center crosshairs from an in-preview header toggle.
- Preview draws temporary snap guide lines while an overlay drag is actively snapped; these lines are non-interactive and live only in Preview editing, not export rendering.
- Selected overlays show a subtle blue selection border and corner handles on the fitted canvas.
- Corner handles in preview are interactive: dragging a handle updates the selected overlay `scale` directly via `ProjectDocument.setOverlayScale`, with continuous undo grouped to drag end.
- Playback advances the timeline playhead at 30 Hz while active.
- Left and right arrow keys step the timeline playhead backward or forward by one project frame, using the current project frame rate.
- Timeline ruler click/drag seeks the playhead; holding `C` while moving the mouse across the timeline time area scrubs the playhead to the hovered time, with the timeline consuming the `C` key events while the mouse is over it to avoid invalid-key beeps; timeline tracks show a red playhead indicator.

### Preview Playback

- Status: in progress.

Current implementation:

- `PreviewCanvasView` uses `VideoPreviewPlayerView` to display real source video behind overlays.
- `VideoPreviewPlayerView` wraps an `AVPlayerLayer` in `NSViewRepresentable`.
- Preview owns its own compact header with title, project resolution/frame-rate metadata, safe guides toggle, and a static Fit menu placeholder.
- `PreviewCanvasView` computes the actual fitted canvas size from the project resolution aspect ratio and centers that canvas in the available preview region.
- `PreviewCanvasView` includes a DaVinci-style playback control strip below the video canvas with a centered previous/stop/play-pause/next cluster and a right-pinned playback-rate menu.
- The project chooses the first timeline clip containing the current playhead.
- Double-clicking a media-pool row switches preview to that source video at the beginning of the file, starts playback, and keeps source preview time independent from the timeline playhead.
- When the media browser loses focus or the user interacts with the preview/timeline, the preview returns to timeline mode.
- Source video time is derived from the clip's effective start time.
- Space and K toggle play/pause. L starts playback when paused, then steps forward speed through 2x, 4x, and 8x while playing.
- The playback-rate menu exposes direct 1x, 2x, 4x, and 8x choices backed by `ProjectDocument.playbackRate`.
- During playback over a video clip, `AVPlayer` is the timing source and reports source time back to the project playhead through a periodic time observer.
- During media-pool source preview, `AVPlayer` time updates only the temporary source preview position so pausing does not reset to the beginning and does not move the timeline playhead.
- During playback, `AVPlayer` is not repeatedly seeked on every playhead tick; it seeks on clip changes, paused/manual positioning, or large drift correction.
- The main editor timer advances playback only when the current playhead is not covered by a video clip.
- Preview clip selection can skip disabled tracks so users can inspect an underlying track without changing export behavior.
- `ProjectDocument` assigns updated `TimelineModel` values instead of mutating nested fields in place for playhead and zoom changes, making overlay and timeline refresh more reliable.

Preview pending:

- More robust clip-boundary handoff during playback.
- Audio mute/preview behavior.

Overlay pending:

- Stroke controls.
- More chart styling controls.
- Keyboard and precision controls for overlay positioning.

### Overlay Templates

- Status: first local library implementation completed.

Design direction:

- Overlay templates should be implemented before full project files.
- Templates persist `OverlayLayout`-like data only, not FIT, media, timeline, playhead, or current sampled values.
- Template persistence should use a versioned, codable schema separate from future project persistence.
- Template application should route through `ProjectDocument` so it participates in undo/redo.
- Template files should be human-inspectable JSON unless there is a strong reason to package assets later.

Suggested model:

```text
OverlayTemplate
  schemaVersion
  id
  name
  createdAt
  updatedAt
  referenceResolution
  elements: [OverlayTemplateElement]

OverlayTemplateElement
  type
  position
  scale
  style
```

Suggested storage:

- Local user template library under Application Support.
- Optional import/export as standalone template files.

Implementation phases:

- Phase A: define Codable template schema and conversion to/from `OverlayLayout`. Completed.
- Phase B: save current overlay layout as a named local template. Completed.
- Phase C: initial template list UI in Project Settings. Completed, then superseded by the left `Templates` Pool.
- Phase D: apply/delete templates with undo support for apply. Completed.
- Phase E: import/export template file. Completed.

Current implementation:

- `OverlayTemplate` is a versioned Codable schema that stores metadata and `OverlayTemplateElement` values.
- Template elements store overlay type, normalized position, scale, visibility, lock state, and style.
- `OverlayTemplateStore` persists the local template library as JSON under Application Support.
- `ProjectDocument` loads templates on startup, saves/replaces templates by name, updates an existing user template from the current overlay setup, applies templates to the current overlay layout, deletes templates, and imports/exports standalone `.rotemplate` files.
- Applying a template routes through `ProjectDocument.registerUndoPoint()` so the previous overlay layout can be restored with undo.
- Template management lives in the left `Templates` Pool and has been removed from Project Settings. The pool uses compact name-only rows, built-in templates (`Easy Run`, `Interval Workout`, `Race`), user-template context menus with update-from-current confirmation, an icon-only import footer button, and a primary `Save Current as Template` footer button.
- `Easy Run` is the first authored built-in template and loads from `Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate`; `Interval Workout` and `Race` load from bundled `IntervalWorkout.rotemplate` and `Race.rotemplate` resources authored from local user templates.
- Applying a template from Templates Pool confirms before replacing existing overlays; when the current overlay layout is empty, it applies immediately without a replacement confirmation.
- Successful activity import automatically applies the user's most recently applied template. If the user has not applied a template before, or the remembered template is unavailable, import falls back to the built-in `Easy Run` template so new projects immediately show a complete overlay layout. Template application also raises a short toast.

Open engineering decisions:

- Template file extension.
- Whether template IDs should be stable UUIDs or derived from filenames.
- How to handle missing future style fields when reading old templates.

## Declarative Overlay Components (Experimental)

The v0.1 component runtime kernel lives in
`Sources/RunningOverlay/Components/`. It loads and strictly validates
`ros.component/0.1` documents, evaluates the closed expression language,
adapts `ActivityTimeline` to the read-only data contract, and resolves a
component definition plus parameter values into a draw tree for base and
capability nodes.

A `.component` overlay element stores an `OverlayComponentInstance`:
`OverlayTemplateElement.component` holds the id/version/digest/source,
`definition` for imported or project components, and `assets` (base64-keyed
package paths) when image nodes reference assets; `params` holds the authored
values. `OverlayComponentRegistry` parses and caches definitions by canonical
digest plus asset path set, and `OverlayComponentSkiaRenderer` draws the
resolved tree through the shared preview/export Skia context.
`OverlayComponentImageCache` decodes PNG/JPEG assets once per digest and draws
them with contain/fill fit.

The editor wiring is:

- Overlay Pool → Components lists `OverlayComponentLibraryItem.all` (bundled
  `studio.*` definitions, read-only) and offers **Import Component…**, which
  opens a package folder, `.rocomponent` ZIP archive or component JSON file.
  Import validation errors are shown in an alert with their JSON paths.
- The same panel's **My Components** section lists definitions carried by the
  project (imported or duplicated), deduplicated by digest. Clicking one adds
  another instance; the context menu exports it back to a `.rocomponent`
  directory or removes every instance in one undo point.
- ZIP import is defensive: stored/deflate entries only, no encryption, ZIP64,
  symlinks, duplicate names or path traversal, per-entry and total size limits,
  and CRC verification. `__MACOSX/` and `.DS_Store` metadata is ignored.
- `ProjectDocument.addComponentFromLibrary` and `importComponentPackage` each
  add one undo point; `addComponentElement` remains the shared mutation.
- `OverlayComponentDetailView` generates the Inspector: Layout rows plus one
  collapsible section per declared `section` (first-appearance order), with
  controls chosen from `params.range`/step/style. Slider edits are continuous
  and share one undo transaction; fields, toggles, menus and color wells are
  discrete edits. `when` expressions hide controls against current data.
- **Duplicate to My Components** promotes a bundled element to an embedded
  project reference; bundled definitions themselves are never edited.

### Native/component parity harness

`NativeComponentParityHarness` (test target) renders a native-module layout and
an equivalent declarative-component layout on the same Skia raster surface and
reports changed pixels, maximum and mean channel deltas, and the bounding box of
changed pixels. Set `PARITY_DUMP_DIR` to also write both renders as PNGs.
`OverlayComponentParityTests` holds the Decor Solid Color pilots (rectangle and
rounded rectangle, with and without element opacity) at exact thresholds. The
numeric pilots and the 13-case `studio.numeric` parity suite ran against the
native numeric renderer until ADR 0014 removed it; their exact-parity results
are recorded in the November 2026 project log. The pilots found and fixed two real defects: element opacity was
applied both as a layer and again per node, and components drew their own
opacity layer while ignoring the host's element-level glow and shadow entirely.

Text nodes gained an optional `tracking` value (to match the native value line's
`-fontSize * 0.012`) and an optional `frame`: without a frame a text node
measures its lines. The new `stack` node lays children along one axis with
spacing and cross-axis alignment, so a unit can follow a value whose width
changes. Stack layout runs at draw time in pixel space because CoreText
advances are not linear in point size: measuring at design size and scaling the
result drifted by about one pixel at 1.5× and three pixels at 2×. Component
definitions with a fixed `size` should still leave a few design units of
padding around text: the renderer clips to the component rectangle and can
otherwise trim the last glyph's ink.

Numeric chrome uses three more primitives. `symbol` draws an SF Symbol through
`SkiaIconRasterCache`, the same raster path as native numeric icons (point size
equals the glyph box edge, weight defaults to medium). `alignSelf` overrides a
stack's cross alignment for one child, for example a unit centered under a
leading value. `"size": "content"` sizes the instance from its measured
top-level nodes plus `padding`, with `minSize` as the inner minimum and the
background filling the padded bounds; the clip is that rect outset by
`OverlayComponentSkiaRenderer.contentInkMargin` (16 design units) so glyph
overhang survives. `OverlayComponentSkiaRenderer.frame(for:renderContext:)`
exposes the measured bounds; `PreviewElementGeometry` uses it for hit testing
and selection, and `--component-render` measures content-sized definitions on
the reference canvas before cropping. The preview draw publishes the bounds it
measured (export never does), so the frame query reuses them shifted to the
element's current position and scaled to the fitted on-screen canvas instead
of resolving and text-measuring every component a second time per update. Native numeric background padding and
radius scaled with the canvas but not the element, while component design
units scale with both; the bundled template conversion divided those values
by each element's scale.

Use the harness before porting a built-in. Differences are attributable to
draw-tree construction, not the backend, so non-text geometry should be exact;
text drawn through different rasterization paths (for example the AppKit decor
text cache) needs a looser threshold or a structural comparison. Element-level
opacity, shadow and glow in `OverlayStyle` are host styling: the component
renderer applies them once around the whole element, so definitions must not
repeat them.

Numeric text comes from the host. `metric(id, unit...)` (expression builtin)
returns a record of the strings `OverlayValueFormatter` produces for an
`OverlayMetric`; `OverlayComponentMetricCatalog` validates ids and resolves
unit candidates. Formatting therefore has one implementation; components never
reimplement pace, duration, date or unit conversion rules.
`OverlayComponentMetricTests` checks every metric, unit and sampled time
against the formatter, the no-data placeholders, and a pinned table of the
exact strings native numeric overlays showed. Raw numbers for lap pace and running dynamics are available as
`activity.*` signals and series.

The bundled `studio.numeric` definition (`Resources/Components/numeric.json`)
is the generic numeric overlay: a `metricId` enum plus one unit param per
metric family feed `metric(...)`, and stacks reproduce `composeMinimal`. The
text block is a vertical stack of top label, row, bottom unit and bottom
label with fixed spacers for the differing gaps; the row is stretched across
the block so a flexible spacer pushes a trailing unit or label to the edge
when a wider label or unit widens the block, exactly as the native layout
does. The icon wraps the block in a stack whose direction and alignment are
expressions. `OverlayComponentLibraryItem.numericPresets` lists one Pool entry
per metric (`studio.numeric#<metric>`) that seeds `metricId`; the Overlay Pool
Metrics tab shows them. `OverlayComponentLibrary.numericElement` builds the
same instance in code (calibration layout, tests).

Headless authoring:

```sh
swift run RunningOverlay --component-validate path/to/Card.rocomponent
swift run RunningOverlay --component-render path/to/Card.rocomponent \
  --component-output /tmp/card.png --component-scale 2
```

Validation works in every build and prints the id, version, digest and asset
bytes. Rendering requires the Skia build; it uses default parameter values, no
activity data, a transparent canvas, and crops the PNG to the component's
design size (measured size for content-sized definitions).

Current limitations: the CLI render uses default parameters and no FIT data;
bundled components currently ship without image assets; renaming a project
component in place is not supported (export, edit the JSON and re-import);
layout is limited to one-dimensional stacks and content-sized components, so
wrapping, distribution and flexible sizing are not available. Adding the first component element raises
the project schema to version 2, so this remains subject to the human review
rules in `AGENTS.md` (project-file compatibility) and to pixel-parity evidence
against native modules.

- Format and data contract: `docs/overlay-components/spec-v0.1.md`.
- Decision and gates: `docs/adr/0013-declarative-overlay-components.md`.
- Tests: `OverlayComponentExpressionTests`, `OverlayComponentLoaderTests`,
  `OverlayComponentMetricTests`,
  `OverlayComponentDataTests`, `OverlayComponentResolverTests`,
  `OverlayComponentIntegrationTests`, `OverlayComponentArchiveTests`,
  `OverlayComponentParityTests`.
- Fixtures: `Tests/RunningOverlayTests/Fixtures/Components/`.

The next integration steps are M5d–M5e (legacy mapping, then native removal; see
`docs/overlay-components/README.md`) and M6 (authoring guide and AI skill).

### Component Authoring Commands

The [component authoring guide](../overlay-components/authoring.md) documents
`--component-activity` (FIT/GPX), `--component-at` (activity elapsed seconds) and
`--component-params` (strict JSON overrides) for headless PNG rendering. These
commands reuse the activity parser, resolver and product Skia renderer; no
project/timeline time conversions or external services are involved. Reproduce
the public scalar/series/list gallery with `./scripts/component-gallery.sh`.
