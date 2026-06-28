# Overlay and Preview Development

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
- Inspector segmented controls are implemented with native SwiftUI segmented `Picker` (`.pickerStyle(.segmented)`) instead of custom button rows, including shared dense controls used by Numeric Overlay, Running Gauge, and Route Map detail views.
- Preview overlay elements can be dragged and clamped within the preview coordinate space.
- Preview overlay hit shapes are applied before position layout so each element only intercepts pointer input inside its rendered bounds; clicking the remaining canvas clears the current overlay selection.
- Preview drag uses measured rendered overlay frames for snapping: with safe guides enabled, overlay edges snap to 90%/80% guide lines and overlay center axes snap to the canvas center crosshair; visible overlays also snap to each other's left/center/right and top/center/bottom alignment lines during drag.
- Inspector supports selected overlay font family, font weight, font size (value text), scale, color presets, independent label/unit controls, and advanced background controls.
- SwiftUI overlay previews route configurable text through the shared overlay font helper. macOS system UI font family aliases such as `SF Pro` and `SF Pro Display` render with `Font.system(size:weight:)` to avoid SwiftUI font descriptor weight diagnostics. Custom font families resolve through AppKit to the concrete PostScript face for the selected weight before creating `Font.custom(...)`, so multi-weight families such as JetBrains Mono use their Regular/Medium/SemiBold/Bold faces. Visible weight changes still depend on whether that family provides matching weight faces, so single-weight families such as Monaco may not visibly respond to every weight option.
- Numeric overlays (heart rate, pace, calories, elapsed time, real time, date, distance, elevation, cadence, power) use the dense `NumericOverlayDetailView` Inspector defined in `docs/design/overlays/numeric/numeric-overlay-ui.md`. `ParameterPanelView` routes these `OverlayElementType` values through the new view; other overlay types continue to use `OverlayDetailView`.
- The Date numeric overlay formats `ActivityTimeline.timestamp(at:)` with a Content-section Format menu. Its six options cover common year-month-day and month-day styles, while all other Inspector behavior and preview/export rendering remain shared with Numeric Overlay.
- The Elevation numeric overlay supports `OverlayStyle.elevationDisplayMode` so the same tile can show either live altitude (`current`) or cumulative ascent to the current playhead (`gain`) while keeping the existing meter/feet unit switch.
- Numeric Overlay 1.0 removes the numeric style preset picker and divider controls. Numeric preview/export always uses the Minimal Clean render path and disables divider rendering even if old project/template data decodes `textPreset` or `dividerEnabled`.
- Numeric Overlay 1.0 supports a configurable SF Symbol icon attachment. `OverlayElementType.defaultNumericIconSystemName` seeds each newly added metric, while `OverlayStyle.iconEnabled`, `iconSystemName`, `iconPosition`, `iconTextAlignment`, `iconSize`, `iconColor`, `iconOpacity`, and `iconSpacing` drive the Inspector and shared SwiftUI preview/export path. Numeric Icon and Decor Icon SF Symbol selection share `SFSymbolPicker`, which keeps direct text entry but adds a searchable bundled SF Symbol name catalog generated from public CoreGlyphs symbol order data, sport-first default browsing, cached renderability checks, current-symbol preview, recent symbols, and default reset.
- Heart-rate-related numeric overlays can now tint value, label, unit, and icon independently through `OverlayStyle.valueColorsFollowHeartRateZones`, `labelColorsFollowHeartRateZones`, `unitColorsFollowHeartRateZones`, and `iconColorsFollowHeartRateZones`. `OverlayRenderModel.textLayout` resolves a shared `dynamicHeartRateZoneColor` from the current heart rate sample and `HRZonePalette`, then preview/export consume that render-model field without changing layout or picker behavior.
- Numeric overlay preview/export positioning is top-leading anchored rather than center anchored. Value and label rows resolve to leading alignment so incomplete or shorter dynamic content keeps the same left edge and grows to the right; inline unit alignment still honors `unitTextAlignment` as its top/middle/bottom anchor. Preview placement uses deterministic alignment guides instead of async content-size measurement; numeric drag uses canvas-coordinate pointer location plus a grab offset to track the overlay's top-left corner, then runs a top-leading snap/clamp path so edge snapping still works.
- `OverlayStyle` carries the numeric-overlay editor state: `unitOption`, `showLabel`, `showUnit`, `customLabel`, `labelPosition`, `unitPosition`, `labelFont*`, `unitFont*`, `icon*`, `valueColorsFollowHeartRateZones`, `labelColorsFollowHeartRateZones`, `unitColorsFollowHeartRateZones`, `iconColorsFollowHeartRateZones`, `rotationDegrees`, `accentColor`, `backgroundEnabled` / `backgroundColor` / `backgroundRadius` / `backgroundPaddingX` / `backgroundPaddingY` / `backgroundFadeOut*` / `backgroundBlurRadius`, and `shadowEnabled` / `shadowOffsetX` / `shadowOffsetY`. All new fields decode with safe defaults so old saved projects and overlay templates load unchanged.
- Shared background Fade Out uses `OverlayFeatherMaskRenderer`, a distance-field rounded-rectangle alpha mask reused by SwiftUI preview and CoreGraphics export. The mask fades only the background surface to transparent; it does not fade foreground text/icons or sample/blur the underlying video.
- `OverlayValueFormatter.value(for:element:activity:elapsedTime:)` is element-aware: it picks the unit option and label/unit/custom-label rules from `OverlayStyle` to produce the rendered string and the Inspector's live preview. Elapsed Time overlays render active elapsed time from `ActivityTimeline.activeElapsedTime(at:)`, subtracting FIT timer-paused spans from the real elapsed-time axis so the value matches watch moving/workout time.
- `OverlayElementType.isNumericOverlay` and `OverlayElementType.defaultUnitOption` drive routing into the numeric editor and the unit defaults applied by `ProjectDocument.addOverlayElement`.
- `OverlayRenderModel` and `OverlayFrameRenderer` honor the new background and shadow style fields on the `.minimal` text preset so the same configuration is consistent between preview, calibration PNG, and MOV export.
- `ProjectDocument` exposes setters for every numeric overlay field plus `resetOverlayStyle` used by the numeric Inspector's footer Reset action; all setters are undoable. Heart-rate-specific Inspector toggles for per-role zone coloring (`setOverlayValueColorsFollowHeartRateZones`, `setOverlayLabelColorsFollowHeartRateZones`, `setOverlayUnitColorsFollowHeartRateZones`, `setOverlayIconColorsFollowHeartRateZones`) follow the same undo semantics, while the older `setOverlayTextColorsFollowHeartRateZones` remains as a compatibility-wide setter.
- Text overlays expose a first-position built-in style picker with Minimal, Pill Badge, Metric Card, Big Number, Sport Watch, and Split Label text presets.
- Running Gauge is available as a composite circular dashboard overlay with distance, elapsed time, pace, and heart rate in one module.
- Running Gauge supports Minimal Sport, High Contrast, Trail Adventure, Tech Future, and Retro Digital style presets through the Inspector.
- Route Map is available as a featured overlay module backed by FIT GPS latitude/longitude when present.
- Route Map exposes line color mode and Glow controls through the Inspector.
- Route Map preview attempts a MapKit snapshot when the map background is enabled and falls back to a local dark grid when a snapshot is unavailable.
- Route Map export preloads MapKit snapshots once before MOV/PNG rasterization and passes them into the shared SwiftUI Route Map view as static render assets; if snapshot loading fails, export falls back to the local route/map grid.
- Inspector supports normalized X/Y position entry plus shadow opacity and radius controls.
- Up and down arrow keys nudge the selected overlay element vertically by one percent of the preview canvas.
- Overlay Pool shows add tiles grouped by Metrics, Charts, and Route; clicking a tile calls `ProjectDocument.addOverlayElement`, which selects the new overlay and opens its detail Inspector. Featured add tiles use the same card shape and border treatment as other tiles without a left-side blue accent strip.
- Inspector shows a dark outer state when no overlay element is selected, but it only contains `Added Overlays`; it no longer carries the selectable overlay catalog.
- Inspector added-overlay rows show icon, type, live value preview, visibility toggle, lock toggle, delete, and detail navigation without sorting affordances.
- Added Overlays rows expose a context menu (`Copy Properties` / `Paste Properties`) for overlay configuration transfer.
- Overlay visibility now gates both Preview rendering and `OverlayFrameRenderer` export rendering.
- Overlay lock is persisted and currently blocks Preview canvas selection/drag plus position writes in `ProjectDocument.moveOverlay` / `setOverlayPosition`.
- Overlay configuration paste is category-gated through `OverlayElementType.pasteCategory`; numeric overlays can paste only within the numeric group.
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
- Zone Edge Bar is available as an independent HR/pace zone overlay for edge-pinned or free placement. It reads Project Settings HR/pace zones and thresholds, renders current and threshold markers, supports horizontal and vertical bars, and shares the HR-zone palette used by Project Settings and Interval HUD Bar. See `docs/design/overlays/zone-edge-bar/zone-edge-bar-overlay-ui.md` and `docs/overlay-modules/zone-edge-bar-overlay.md`.
- Elevation chart overlays render line/area charts with playhead markers; Smoothing filters quantized elevation samples and draws curved paths in both preview and export, including Progress mode.
- Running Gauge overlays render circular ticks, a progress ring, section dividers, and core run metrics in both preview and export.
- Route Map overlays render the route path, start marker, finish marker, and current-position marker in both preview and export.
- `OverlayRenderModel` provides the shared layout data used by SwiftUI preview and AVFoundation export rendering.
- Text preset selection is stored on `OverlayStyle`, decodes old templates as the Minimal preset, and is honored by both preview and export renderers.
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
- Successful FIT import automatically applies the user's most recently applied template. If the user has not applied a template before, or the remembered template is unavailable, import falls back to the built-in `Easy Run` template so new projects immediately show a complete overlay layout. Template application also raises a short toast.

Open engineering decisions:

- Template file extension.
- Whether template IDs should be stable UUIDs or derived from filenames.
- How to handle missing future style fields when reading old templates.
