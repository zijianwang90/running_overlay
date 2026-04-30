# Running Overlay Project Log

## 2026-04-30

### Borderless Status Bar Settings Button

- Updated `MainEditorView` status bar `gearshape` button to a borderless icon-only style (`.buttonStyle(.plain)`), so it no longer visually touches the top/bottom edges of the 34 px bar.
- Kept the bottom area height unchanged; only the button presentation changed.
- Added a design-system note in `docs/design/system/app-ui.md` clarifying that compact app-chrome utility actions may use a borderless icon-button variant.

### Replace FIT Button in Media Pool

- Added `ProjectDocument.fitSourceName` (`@Published var`) to track the filename of the currently loaded FIT file.
- `importFitFile()` sets `fitSourceName` to `url.lastPathComponent` on successful import.
- `MediaBrowserView`: added a "Replace FIT" underlined text button directly below the step indicator in `videoImportPlaceholder` (shown when FIT is loaded but no videos yet).
- `MediaBrowserView`: added a FIT status row (green dot + filename + "Replace" link) at the bottom of the filter strip, shown only when media items exist and a FIT is loaded. The bottom border is now owned by the outer `VStack` wrapping both the count/filter row and the FIT row.

### Layout Opacity Applies To Whole Overlay

- Added element-level `OverlayElement.opacity` with `ProjectDocument.setOverlayOpacity`.
- Updated `OverlayLayoutInspectorRows` so the shared Layout `Opacity` row controls the whole overlay instead of binding to background opacity.
- Applied element opacity at both render entry points: `PreviewCanvasView` for live preview and `OverlayFrameRenderer` for export.
- Persisted template opacity through `OverlayTemplateElement`, with a default of `1` for existing templates.

## 2026-04-29

Note:

- Historical entries below may reference `OverlayVideoExporter` as part of the migration timeline. That exporter is now retired; active export runtime uses `SwiftUIOverlayVideoExporter` only.

### Decor Overlay Category — Phase C1 (SVG smoke-test gate)

Spike that gates the IconRendering design before Phase C2 builds it. The previous DistanceTimeline Lower Third icon attempt failed because some SVGs that render fine in WebKit/preview do not render via the path the exporter uses; this test proves macOS-native SVG works in **both** paths so we can keep the design dependency-light.

Result: all three fixture SVGs (simple, `<style>`-block, multicolor) load via `NSImage(contentsOf:)` *and* rasterize successfully into an offscreen `CGContext` with non-trivial pixel coverage. **Gate passed — staying on macOS-native SVG. No SVGKit dependency needed for Phase C2.**

Lottie is intentionally not exercised here; the C6 step will add `lottie-spm` and a separate animation smoke test.

Summary:

- New `Tests/RunningOverlayTests/IconRenderingSmokeTests.swift` — three `@Test` cases covering simple / styled / multicolor SVGs. Each loads as `NSImage`, then draws into a 128×128 RGBA `CGContext` and asserts more than 100 non-transparent pixels.
- New fixtures under `Tests/RunningOverlayTests/Fixtures/Icons/` — `simple-circle.svg`, `styled-square.svg` (uses `<style>` + classes), `multicolor-flag.svg`.
- `Package.swift` — test target gains `resources: [.copy("Fixtures")]` so the SVG files are bundled and resolvable via `Bundle.module`.

Files changed:

- `Package.swift`
- `Tests/RunningOverlayTests/IconRenderingSmokeTests.swift` *(new)*
- `Tests/RunningOverlayTests/Fixtures/Icons/simple-circle.svg` *(new)*
- `Tests/RunningOverlayTests/Fixtures/Icons/styled-square.svg` *(new)*
- `Tests/RunningOverlayTests/Fixtures/Icons/multicolor-flag.svg` *(new)*
- `docs/project-log.md`

Verification:

- `swift build` clean.
- `swift test --filter IconRenderingSmokeTests` — 3/3 pass.
- `swift test` full suite — 61/61 pass (was 58; +3 from this spike).

Plan reference: step **C1** of `~/.claude/plans/overlay-pool-solid-color-layout-bg-effe-shiny-pudding.md`. Next up: **C2** (`IconAsset` enum + Codable round-trip test).

### Decor Overlay Category — Phase A + Phase B (Solid Color end-to-end)

Adds the full **Decor** overlay category to the Pool with the first usable subtype — **Solid Color** — wired end-to-end through model, mutators, live preview, SwiftUI export, and inspector. Decor elements are activity-data-independent visual primitives; Phase B ships the rectangle / rounded rectangle / circle / capsule shape with fill, layout, border, and effects. Icon (Phase D) and Text (Phase F) are scaffolded with placeholder inspectors only.

Note: this work was previously partially landed in a worktree branch that was deleted before commit; this entry consolidates A1→B6 onto develop in a single pass.

Summary:

- **Model (A1, B1)**: `OverlayElementType` gains `decorSolidColor`, `decorIcon`, `decorText` plus `isDecorOverlay` helper. Exhaustive switches in `OverlayValueFormatter`, `NumericOverlayDetailView.numericIcon`, `OverlayUnitOption.options(for:)`, and `OverlayElementType.supportsTextPresets` updated. New `DecorShape` enum (`rectangle | roundedRectangle | circle | capsule`) and `DecorStyle` sub-struct (`shape`, `fillColor`, `width`, `height`, `cornerRadius`) live at the bottom of `OverlayElement.swift`. Wired `var decor: DecorStyle` into `OverlayStyle`'s declaration, default, init, and decoder via `decodeIfPresent ?? .default` so older project files round-trip.
- **Pool (A2)**: `OverlayCategory` gains `.decor`; three tiles (`decorSolidColor` / `decorIcon` / `decorText`) appended to `OverlayTileInfo.all`. Segmented Pool tab picks them up automatically.
- **Inspector dispatch (A3)**: `ParameterPanelView` routes `isDecorOverlay` elements to the new `DecorOverlayDetailView`. Inspector switches on subtype internally — Solid Color shows full sections, Icon/Text show placeholder until later phases.
- **Mutators (B2)**: `ProjectDocument` gains `setDecorShape`, `setDecorFillColor`, `setDecorSize(width:height:)`, `setDecorCornerRadius`, plus generic `mutateDecorStyle` / `mutateDecorStyleContinuous` helpers. Discrete edits use `registerUndoPoint()`, drags use `registerContinuousUndoPoint()`. Switching to `.circle` collapses width/height to the shorter side (mirrors `setOverlayRouteMapShape`).
- **Layout helper (B3 prep)**: New `OverlayRenderModel.decorSolidColorLayout(for:in:)` returns `DecorSolidColorRenderLayout` (shape, pixel size, fill color, scaled corner radius) — same canvas-DPR / element-scale convention as the other overlays.
- **Preview + export (B3, B4)**: New `Sources/RunningOverlay/UI/DecorOverlayViews.swift` defines `OverlaySharedDecorSolidColorView` + `DecorSolidColorOverlayView`. The shared view honors the existing `OverlayStyle` border / shadow / glow flags so the standard inspector modules apply unchanged. Dispatch arms added to both `PreviewCanvasView` and `SwiftUIOverlayVideoExporter` so live preview and exported MOV are pixel-identical.
- **Inspector (B5)**: `DecorOverlayDetailView` composes existing primitives directly — `InspectorDenseRow`, `InspectorDenseSliderRow`, `InspectorDenseSegmented`, `InspectorDenseSwatchStrip`, `OverlayLayoutInspectorRows` (Position / Scale / Width / Height / Opacity), plus the shared `OverlayBorderInspectorModule` and `OverlayEffectsInspectorModule`. No wrapping, no second-pass redesign of those primitives. Sections: Layout, Shape (segmented + corner-radius slider), Fill (color swatches), Border, Effects.
- **Default preset (B6)**: `defaultOverlayStyle(for:)` seeds `decorSolidColor` with a 240×80 white rounded rectangle and turns off `backgroundEnabled` (the shape *is* the background) so the new element is immediately visible on the canvas.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/OverlayPoolView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/DecorOverlayDetailView.swift` *(new)*
- `Sources/RunningOverlay/UI/DecorOverlayViews.swift` *(new)*
- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `docs/project-log.md`

Verification:

- `swift build` clean.
- `swift test` — all 58 tests pass; legacy template round-trip preserved by `decodeIfPresent ?? .default`.

Plan reference: phases **A1 → B6** of `~/.claude/plans/overlay-pool-solid-color-layout-bg-effe-shiny-pudding.md`. Next up: Phase **C** (Icon subsystem foundation — `IconAsset` / `IconRendering` smoke test gate).

### Extract Dense Inspector Components

Summary:

- Moved the shared dense Inspector primitives out of `NumericOverlayDetailView.swift` and into `Sources/RunningOverlay/UI/InspectorRows/InspectorDenseComponents.swift`.
- Kept existing type names and APIs unchanged (`InspectorDenseRow`, `InspectorDenseSliderRow`, `InspectorDenseAxisField`, `InspectorDenseSegmented`, `InspectorDenseMenuLabel`, `InspectorDenseSwatchStrip`, `InspectorAnchorGrid`, `InspectorDetailFooterBar`, and `NumericTokens`) so existing overlay detail views continue to use the same components without call-site churn.
- Updated design documentation to point at the shared component file instead of treating these primitives as Numeric Overlay internals.

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/InspectorDenseComponents.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.md`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/design/overlays/route-map/route-map-overlay-ui.md`
- `docs/project-log.md`

### Group Inspector Row Files

Summary:

- Moved the four shared inspector row files into `Sources/RunningOverlay/UI/InspectorRows/` so reusable row components are easier to find.
- Renamed `StatsBarInspectorRows.swift` and its view type to `OverlayStatsBarInspectorRows` to match the `Overlay...InspectorRows` naming convention used by the background, border, and effects row files.
- Updated overlay detail views and inspector documentation to reference the new component name and path.

### Extract Shared Layout Inspector Rows

Summary:

- Moved the shared Layout inspector rows out of `NumericOverlayDetailView.swift` and into `Sources/RunningOverlay/UI/InspectorRows/OverlayLayoutInspectorRows.swift`.
- Renamed `OverlayLayoutRows` to `OverlayLayoutInspectorRows` so the Layout component follows the same `Overlay...InspectorRows` naming convention as the other shared inspector row files.
- Kept `CollapsibleLayoutInspectorSection` beside the Layout rows so all overlay detail views use one shared Layout section chrome plus one shared body row component.
- Updated all overlay detail views and design docs to reference `OverlayLayoutInspectorRows`.

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/OverlayBackgroundInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayBorderInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayEffectsInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayLayoutInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayStatsBarInspectorRows.swift`
- `Sources/RunningOverlay/UI/DistanceTimelineOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/ElevationChartOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapCardOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapLiveOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `docs/development.md`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.md`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.spec.json`
- `docs/design/overlays/elevation-chart/elevation-chart-overlay-ui.md`
- `docs/design/overlays/elevation-chart/elevation-chart-overlay-ui.spec.json`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/design/overlays/route-map/route-map-overlay-ui.md`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/design/panels/inspector/inspector-ui.spec.json`
- `docs/overlay-modules/distance-timeline-overlay.md`
- `docs/overlay-modules/elevation-chart-overlay.md`
- `docs/overlay-modules/route-map-overlay.md`
- `docs/project-log.md`

### Finalize Shared-Component SwiftUI Export Path

Summary:

- Removed residual per-overlay experimental view implementations from `SwiftUIOverlayVideoExporter`; export now keeps only the shared component route used by preview (`OverlaySharedTextPresetView`, `OverlaySharedDistanceTimelineView`, `OverlaySharedRouteMapView`).
- Updated SwiftUI export filtering to render all visible overlays through the shared-component path, so coverage now matches the full current control set.
- Extended shared-component SwiftUI export coverage to all current overlay controls by adding shared wrappers and exporter dispatch for Elevation Chart, Running Gauge, Lap List, Lap Card, and Lap Live.
- Updated SwiftUI exporter overlay filtering from partial-type checks to `isVisible` so all visible overlays render through the shared-component path.
- Updated `docs/requirements.md` and `docs/development.md` with explicit next-step export optimization directions (layer caching, dirty-region redraw, adaptive quality knobs, and structured performance telemetry).
- Retired legacy export-mode code after parity verification: removed `OverlayVideoExporter` usage and mode-toggle UI, and switched `Export` / `Export Full Activity` / `Export Test Clip` / `Export Test Frame` to the unified SwiftUI shared-component pipeline.

Files changed:

- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

### Unify Preview And SwiftUI Export Call Sites

Summary:

- Updated `PreviewCanvasView` to call shared overlay wrappers for text preset, distance timeline, and route map rendering.
- Updated `SwiftUIOverlayVideoExporter` to call the same shared wrappers with `isInteractive: false`, so export disables selection affordances while keeping component visuals aligned with preview call sites.
- This completes the second step after shared entry-point extraction: both preview and export now invoke the same overlay view entry points.
- Removed an extra horizontal flip transform in SwiftUI experimental video frame drawing to fix mirrored output in `Export SwiftUI Test Clip`.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `docs/project-log.md`

### Extract Shared Overlay View Entry Points

Summary:

- Added a new shared UI file `OverlaySharedViews.swift` with reusable entry-point wrappers for text preset, distance timeline, and route map overlays.
- Exposed `TextPresetOverlayView`, `DistanceTimelineOverlayView`, and `RouteMapOverlayView` at module scope so shared wrappers can reference the same component implementations.
- This sets up the follow-up step where Preview and SwiftUI export both call the same shared view entry points while passing different interactivity flags.

Files changed:

- `Sources/RunningOverlay/UI/OverlaySharedViews.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/project-log.md`

### SwiftUI Per-Frame Export Experiment (Scheme A)

Summary:

- Added a new experimental export pipeline `SwiftUIOverlayVideoExporter` that rasterizes SwiftUI overlay content with `ImageRenderer` per frame and writes transparent MOV via `AVAssetWriter`.
- Added `ProjectDocument.exportSwiftUITestClip(to:)` and `runSwiftUIExport(...)` so this path has independent progress/cancellation handling without changing the existing `OverlayVideoExporter` path.
- Added an `Export SwiftUI Test Clip` action in `ExportDialogView` to trigger the experiment.
- Expanded experiment scope: now renders visible numeric overlays, Distance Timeline, and Route Map through SwiftUI per-frame rasterization for Scheme-A feasibility/performance comparison.
- Added `Export SwiftUI Test Frame` to write one PNG through the same Scheme-A rasterization path at the current playhead.
- Added `Export Overlay JSON` to save the current `OverlayLayout` to `overlay_configuration.json`.
- Split export actions into two button rows in `ExportDialogView` to avoid cramped controls.

Files changed:

- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

### Numeric Overlay Preview Uses Export Renderer

Summary:

- Started the shared-renderer migration on a narrow slice: numeric overlays now render their Preview visual content through `OverlayFrameRenderer`.
- Added `OverlayFrameRenderer.renderNumericPreviewImage(...)`, which renders a single numeric element into the fitted preview canvas, flips the bitmap into display orientation, crops it to the element bounds, and returns an `NSImage` for SwiftUI.
- Added `NumericOverlayRenderedPreviewView` in `PreviewCanvasView`; SwiftUI still owns selection outlines, dragging, snapping, and fallback rendering, while numeric text/background/effects come from the export renderer path.

Files changed:

- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/project-log.md`
### Fix Test Export Orientation/Timing/Accent Parity

Summary:

- Fixed `Export Test Frame` vertical inversion by adding optional post-render row flipping to PNG export and enabling it for test frame export.
- Fixed test clip/frame sampling mismatch by converting playhead project time to activity elapsed time before clamping/quantization.
- Fixed text preset export accent mismatch by using `element.style.accentColor` instead of system accent color in export text preset colors.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

### Rename Test Export API In ProjectDocument

Summary:

- Renamed `ProjectDocument` test export APIs from calibration-oriented names to test-oriented names so method semantics match current behavior.
- `exportCalibrationOverlay(to:)` is now `exportTestClip(to:)`.
- `exportCalibrationFrame(to:)` is now `exportTestFrame(to:)`.
- Updated `ExportDialogView` button actions to call the renamed methods.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/project-log.md`

### Route Map: Runner Position Dot Color

Added a dedicated color picker for the runner's current-position dot in the Route Map overlay inspector (Markers section, "Position Color" row).

Previously the dot always used the route line's foreground color. Now it has its own `routeMapRunnerDotColor` property, defaulting to `foregroundColor` on decode so existing projects look identical.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift` — added `routeMapRunnerDotColor: OverlayColor` to `OverlayStyle`; decoded after `foregroundColor` so the fallback is available
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift` — runner dot now uses `NSColor(element.style.routeMapRunnerDotColor)` instead of `accent`
- `Sources/RunningOverlay/Project/ProjectDocument.swift` — added `setOverlayRouteMapRunnerDotColor`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift` — added "Position Color" swatch row in `markersSection`

### Fix Split Label and Racing Stripe label/line color roles

Summary:

- **Split Label**: the horizontal rule under the label was using `NSColor.controlAccentColor` (macOS system accent) instead of the element's user-configured `accentColor`. Fixed to use `NSColor(element.style.accentColor)`.
- **Racing Stripe**: the label text was rendered in the element's `accentColor`, conflating the stripe color role with the label text role. Fixed to use `colors.foreground` (`element.style.foregroundColor`) so label color is controlled by the same "Color" picker as the rest of the text, while the vertical stripe continues to use `accentColor`.

Color responsibility is now consistent across both presets: label text color → foreground/text color; line/stripe color → accent color.

Files changed:

- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `docs/project-log.md`

### Preview Canvas Overlay Snapping

Summary:

- Added drag-time snapping for Preview overlays using measured rendered overlay frames in fitted-canvas coordinates.
- When safe guides are enabled, overlay left/right/top/bottom edges snap to the 90% and 80% safe-frame guide lines, and overlay center axes snap to the canvas center crosshair.
- Visible overlays can snap to each other's left/center/right and top/center/bottom alignment lines, so neighboring components can be bottom-aligned, top-aligned, left-aligned, right-aligned, or center-aligned while dragging.
- Added temporary non-interactive snap lines during active drag to show which alignment target is being used.
- Fixed the initial frame-measurement placement so dragging uses the overlay's own rendered bounds instead of the whole canvas bounds.
- Updated Preview design and development documentation for snapping behavior.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/development.md`
- `docs/design/panels/preview/preview-ui.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.

### Preview Canvas Drag Performance Optimization

Summary:

- Eliminated per-frame `@Published` mutations during overlay element drag by keeping a local `@State var liveDragPosition` in `PreviewCanvasView`. The position is written to `ProjectDocument` exactly once on drag end, rather than 60+ times per second. This prevents all ProjectDocument observers (Inspector, Timeline, Pool panels) from re-rendering during drag.
- Extracted overlay element rendering into a private `OverlayElementContent` struct conforming to `@preconcurrency Equatable`. With `.equatable()`, SwiftUI skips `body` execution for non-dragged elements when only `liveDragPosition` changes, avoiding redundant `OverlayRenderModel.*Layout()` computations (gauge, map, chart, text) for elements that have not changed.
- Moved selection update (`project.selectOverlay`) and undo checkpoint registration (implicit in `moveOverlay`) from per-frame to once per gesture, removing two sources of per-frame document mutation.
- The `Equatable` comparison covers `element`, `canvasSize`, `sampleTime`, and `isSelected`; `activity` is intentionally excluded because comparing large FIT sample arrays each frame is expensive and `sampleTime` guards layout freshness in practice.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`

Verification:

- Ran `swift build`.
- Ran `swift test` — all tests pass except the pre-existing `runningGaugeLayoutCarriesCoreMetricsAndProgress` time-format assertion failure in `OverlayRenderModelTests`.

### Templates Pool Implementation

Summary:

- Added `Templates` as the third top-toolbar Pool mode.
- Added `TemplatePoolView` with compact name-only rows for built-in and user templates.
- Added built-in templates: `Easy Run`, `Interval Workout`, and `Race`.
- Added confirmation dialogs before built-in or user templates clear and replace the current overlay layout.
- Added user-template context menu actions for rename, duplicate, export, and delete.
- Added footer actions with a small icon-only import button and a primary `Save Current as Template` button.
- Removed the Overlay Templates management section from Project Settings.
- Added ProjectDocument APIs for generated-name saves, built-in template application, rename, and duplicate.
- Added template tests for generated-name save, rename, duplicate, and built-in replacement undo.
- Refined Templates Pool rows to use explicit horizontal separators, removed the accidental center divider, and removed the blank-area import context menu from built-in template space.
- Replaced the placeholder `Easy Run` built-in with the bundled `EasyRun.rotemplate` resource supplied from `/Users/codywang/Desktop/running_overlay/Test 2/Template.rotemplate`.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayTemplate.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate`
- `Sources/RunningOverlay/UI/PoolPanelView.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/TemplatePoolView.swift`
- `Tests/RunningOverlayTests/OverlayTemplateTests.swift`
- `docs/development.md`
- `docs/project-log.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/design/panels/media-pool/media-pool-ui.md`
- `docs/design/panels/media-pool/media-pool-ui.spec.json`

Verification:

- Ran `swift build`.
- Ran `swift test --filter OverlayTemplateTests`.
- Full `swift test` still has the pre-existing Running Gauge time-format assertion failure in `OverlayRenderModelTests`.

### Templates Pool Design Direction

Summary:

- Expanded the left Pool design from two modes to three: `Media Pool`, `Overlay Pool`, and `Templates`.
- Documented Templates Pool as the single template-management surface, replacing Project Settings template controls.
- Defined a compact name-only row treatment for built-in and user templates: no leading icons, no trailing buttons, and no visible ellipsis controls.
- Defined first-pass built-in templates: `Easy Run`, `Interval Workout`, and `Race`.
- Specified that applying any template clears and replaces current overlays only after confirmation.
- Specified user-template right-click actions: rename, duplicate, export, and delete.
- Specified the footer layout: a small square import button on the left and a long `Save Current as Template` primary button on the right.

Files changed:

- `CLAUDE.md`
- `docs/architecture.md`
- `docs/design/README.md`
- `docs/design/panels/media-pool/media-pool-ui.md`
- `docs/design/panels/media-pool/media-pool-ui.spec.json`
- `docs/design/system/app-ui.md`
- `docs/development.md`
- `docs/project-log.md`
- `docs/requirements.md`
- `docs/roadmap.md`

Verification:

- Validated updated JSON specs.

### Left Pool Split And Overlay Pool

Summary:

- Added a top-toolbar `Media Pool` / `Overlay Pool` switch backed by `MainEditorView` state, with `PoolPanelView` rendering the selected left-pane content.
- Moved the add-overlay catalog out of the Inspector and into `OverlayPoolView`, preserving the Metrics, Charts, and Route categories.
- Removed global toolbar FIT/Videos import buttons; Media Pool now owns the import workflow.
- Updated the no-media state to be FIT-first: `Import FIT` before activity data exists, then `Import Videos` after FIT import.
- Changed Inspector outer state to show only `Added Overlays`; detail inspectors and row management actions remain unchanged.
- Updated design, requirements, architecture, and development docs for the new left Pool/Inspector responsibility split.

Files changed:

- `Sources/RunningOverlay/UI/PoolPanelView.swift`
- `Sources/RunningOverlay/UI/OverlayPoolView.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/design/panels/media-pool/media-pool-ui.md`
- `docs/design/panels/media-pool/media-pool-ui.spec.json`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/design/panels/inspector/inspector-ui.spec.json`
- `docs/design/system/app-ui.md`
- `docs/design/README.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/architecture.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Media Pool Status Dot Cleanup

Summary:

- Removed the long right-side alignment status text from media rows.
- Added compact alignment-status dots with hover help text containing the full status label, such as `Aligned by timestamp`.
- Removed the trailing ellipsis icon because row actions are already available through the context menu and the icon did not open a visible menu.
- Added hover help for media mark dots.
- Updated the Media Pool design docs, structured UI spec, and development notes to reflect the current row behavior.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/design/panels/media-pool/media-pool-ui.md`
- `docs/design/panels/media-pool/media-pool-ui.spec.json`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

## 2026-04-28

### Shared Stats Bar + Shared Layout Final Unification

Summary:

- Finalized shared Stats Bar inspector behavior across Distance Timeline and Route Map using one component pair: `CollapsibleStatsBarInspectorSection` + `OverlayStatsBarInspectorRows`.
- Unified the full Stats Bar control surface to the original Distance Timeline set: Placement, Inside, Layout, Size, Width, Offset, Item Gap, Background, Dividers, Radius, and Slot 1-4.
- Moved the Stats Bar Enabled toggle to the section header (left of chevron) and standardized the icon to `tablecells`.
- Added Route Map inside-mode behavior updates: inside bars reserve map-content padding (do not cover route lines), inside bar background merges with container clipping/radius, and left/right placements force vertical stack with Item Gap applied as vertical spacing.
- Unified Stats Bar rendering: Route Map and Distance Timeline now use one shared Preview renderer (`SharedStatsBarContentView`) and one shared Export renderer path (`drawSharedStatsBar`), using Distance Timeline visual logic as baseline.
- Finalized shared Layout inspector behavior across overlay detail panels with one component pair: `CollapsibleLayoutInspectorSection` + `OverlayLayoutInspectorRows`.
- Standardized shared Layout row set to Position, Scale, Width, Height, Opacity (no Rotation), and applied section-ordering rule consistently across detail views.

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/OverlayStatsBarInspectorRows.swift`
- `Sources/RunningOverlay/UI/DistanceTimelineOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapCardOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapLiveOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Overlay/RouteMapOverlay.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/design/overlays/route-map/route-map-overlay-ui.md`
- `docs/overlay-modules/route-map-overlay.md`
- `docs/overlay-modules/distance-timeline-overlay.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build` multiple times after each integration step — Build complete, no errors.

### Shared OverlayLayoutInspectorRows Component + Section Ordering

Summary:

- Extracted the Position/Scale/Width/Height controls used in every overlay detail view into a single shared `OverlayLayoutInspectorRows` struct, now located in `Sources/RunningOverlay/UI/InspectorRows/OverlayLayoutInspectorRows.swift`.
- Removed the Anchor (3×3 grid) and Padding controls from all layout sections. Position is now always set by numeric X/Y fields only.
- `OverlayLayoutInspectorRows` accepts optional `widthBinding`/`heightBinding` parameters; pass `nil` to hide those rows. Running Gauge passes `nil` for both (square component — no explicit dimensions). Distance Timeline passes both. Route Map, Numeric, and Lap views omit them.
- Rotation is intentionally excluded from the shared Layout rows so the cross-overlay Layout surface stays fixed.
- LapList, LapCard, and LapLive's Position section now shows Position X/Y + Scale instead of Scale only.
- Section ordering rule applied: if a detail view has a Preset section it must be first; otherwise Layout is first. Distance Timeline was reordered to: Preset → Layout → Value → Label → …

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/OverlayLayoutInspectorRows.swift` (added `OverlayLayoutInspectorRows`)
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/DistanceTimelineOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapCardOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapLiveOverlayDetailView.swift`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.md`
- `docs/design/overlays/route-map/route-map-overlay-ui.md`
- `docs/project-log.md`

Verification:

- Ran `swift build` — Build complete, no errors.

### Extract Shared OverlayStatsBarInspectorRows Component

Summary:

- Extracted the Stats Bar inspector UI shared between Distance Timeline and Route Map overlays into a new `OverlayStatsBarInspectorRows` view in `OverlayStatsBarInspectorRows.swift`.
- The shared component renders Placement, Layout, Height, Background, Dividers, Radius, and Slot rows, which are identical in both overlays.
- Distance Timeline-specific rows (Inside toggle; Width, Offset X/Y, Item Gap via `ExtraLayoutConfig`) are passed as optional config; Route Map-specific rows (Blur) are passed as an optional value.
- Moved `RouteMapStatsBarPlacement.distanceTimelinePlacements` from a private extension in `DistanceTimelineOverlayDetailView` to the shared file so both callers can reference it.
- Both detail views now delegate to `OverlayStatsBarInspectorRows`, eliminating ~80 lines of duplicated UI code.

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/OverlayStatsBarInspectorRows.swift` (new)
- `Sources/RunningOverlay/UI/DistanceTimelineOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build` — Build complete, no errors.

### Locked Element List-Click Guard

Summary:

- Updated `Added Elements` row navigation so locked overlays cannot open the detail inspector from the list.
- Clicking a locked row now shows a status/toast-style message prompting the user to unlock before editing.
- Kept existing lock behavior unchanged for canvas interaction and context-menu actions.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Overlay Property Copy/Paste Menus

Summary:

- Added right-click `Copy Properties` / `Paste Properties` actions to Inspector Added Elements rows and Preview overlays.
- Implemented model-level copy buffer in `ProjectDocument` and paste validation by overlay category.
- Added `OverlayElementType.pasteCategory` so numeric overlays can paste only to numeric overlays, while non-numeric modules paste only within their own category.
- Paste now applies copied configuration fields (`scale`, `isVisible`, `isLocked`, `style`) to the target element while preserving target identity/type.
- Updated Inspector/Preview/development/requirements documentation for the new context-menu workflow.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/design/panels/preview/preview-ui.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Added Elements Visibility/Lock Actions

Summary:

- Implemented `Added Elements` row visibility and lock actions with real model-backed state.
- Added persistent `OverlayElement.isVisible` / `OverlayElement.isLocked` fields and template-schema compatibility defaults for older templates.
- Updated Preview behavior so hidden overlays are not rendered and locked overlays cannot be selected/dragged from canvas.
- Updated export rendering so invisible overlays are skipped by `OverlayFrameRenderer`.
- Synced Inspector/Preview/development/requirements docs to reflect shipped behavior.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayTemplate.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/design/panels/preview/preview-ui.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Lower Default Timeline Height On Launch

Summary:

- Reduced the initial vertical footprint of the Timeline panel so newly opened windows dedicate more space to Media/Preview/Inspector editing.
- Kept timeline resizing behavior unchanged by only adjusting `TimelineView` default frame targets.
- Updated development documentation to record the new default split allocation.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Preview Corner Handle Scale Drag

Summary:

- Upgraded selected-overlay corner handles in preview from visual affordances to interactive drag handles.
- Dragging any of the four blue corner handles now scales the selected overlay by directly updating `OverlayElement.scale`.
- Grouped scale drag updates as a continuous undo operation and commit at drag end.
- Updated preview/requirements/development docs so overlay-canvas interaction behavior matches implementation.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/design/panels/preview/preview-ui.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Numeric Overlay Label/Unit Split + Background Effects

Summary:

- Refactored `NumericOverlayDetailView` to split Label and Unit into standalone sections with independent header toggles.
- Removed label/unit switches and label text editing from Content; Typography now controls value text only.
- Added independent label/unit typography controls (`font`, `size`, `weight`) and independent position controls (`top`, `bottom`, `left`, `right`).
- Added background fade-out and gaussian blur controls in the Numeric overlay background section.
- Standardized new numeric overlays to default to `Minimal Clean`.
- Updated preview/render model + style decoding to support new label/unit and background fields while keeping older projects loadable.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Clip Inspector Dense Sizing Pass

Summary:

- Tightened the selected clip Inspector to match the dense detail-view tokens used by `NumericOverlayDetailView`.
- Removed extra top padding before the clip timing section.
- Reduced clip detail section headers, rows, controls, and icon buttons to the shared dense dimensions.
- Moved `Apply to all clips in this layer` directly below the Offset row instead of keeping it in a sticky footer.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 55 tests passed.

### Upper Panel Divider Tightening

Summary:

- Removed the visual padding created by the upper horizontal resize handles between Media Pool, Preview, and Inspector.
- Kept a wider invisible drag target over the 1 px divider so the split lines remain easy to resize while the panels visually butt together.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 55 tests passed.
- Ran `swift build`.

### Timeline Ruler Hover Placement

Summary:

- Split the timeline ruler into a reserved hover-info band above the time scale and a lower scale band for ticks and labels.
- Moved the ruler hover info pill into the upper band so it no longer sits under the mouse cursor.
- Kept the pill arrow aligned to the hovered ruler position.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/design/timeline-ui.md`
- `docs/design/timeline-ui.spec.json`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 53 tests passed.
- Ran `jq empty docs/design/timeline-ui.spec.json`.

### Media Pool Row Refinement

Summary:

- Refined Media Pool rows against `Runner Overlay Design System/preview/components-rows.html`.
- Split search and status filters into distinct compact rows with design-system padding and borders.
- Tightened media row layout to 72 px height, 42 px thumbnail well, compact metadata, muted right-side status text, mark dot, and trailing more affordance. This was later simplified to a status dot with hover help and no trailing ellipsis.
- Adjusted status filter chips to use the solid active-blue treatment from the row component reference.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 52 tests passed.

### Clip Inspector Detail Style Alignment

Summary:

- Replaced the selected timeline clip Inspector's generic panel presentation with a dedicated clip detail view matching overlay detail structure.
- Added a clip detail header with back navigation, video icon, clip title, Clip pill, live layer/start summary, and delete action.
- Restyled clip timing controls as dense detail rows with a `Clip Timing` section header, editable layer field, Start and Offset numeric inputs, and preserved double-click reset behavior.
- Initially moved the layer-wide offset apply action into the clip detail footer; a follow-up sizing pass moved it directly below the Offset row to match the denser detail-view layout.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 52 tests passed.

### Distance Timeline Overlay Style System Design

Summary:

- Added a Distance Timeline Overlay design board with eight visual directions: Minimal, Dense, Sport, Splits, Glass, Neon, Lower Third, and Route.
- Added implementation-facing UI documentation for `OverlayElementType.distanceTimeline`, including preset behavior, progress track controls, typography, background, border, fade out, and effects.
- Defined customizable left media slots for Sport and Lower Third presets, including static SVG, animated SVG, image, icon, and future video-loop modes.
- Defined Route/Elevation customization, including route/path modes, start/finish/current markers, elevation profile, shaded area under the elevation line, shadow blur, and progress clipping.
- Documented border toggle, edge fade/fade-out behavior, background/material controls, current model gaps, and phased implementation guidance.
- Added the module to `docs/overlay-modules` so follow-up implementation work has both product-level and UI-level guidance.

Files changed:

- `docs/design/README.md`
- `docs/design/distance-timeline-overlay-ui.md`
- `docs/design/distance-timeline-overlay-ui.spec.json`
- `docs/design/distance-timeline-overlay-styles.png`
- `docs/overlay-modules/README.md`
- `docs/overlay-modules/distance-timeline-overlay.md`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/distance-timeline-overlay-ui.spec.json`.
- Documentation/design-only change; tests not run.

## 2026-04-27

### Detail Header Tap Area And Margin Cleanup

Summary:

- Updated detail view section headers so collapse/expand is triggered by tapping the full header row, not only the chevron icon.
- Applied this interaction change consistently across Numeric Overlay, Running Gauge, Route Map, and Lap List detail views.
- Removed extra inner scroll container paddings from these detail views to eliminate unintended outer margins and inter-section spacing artifacts.
- Kept existing control bindings and feature behavior unchanged; this is a visual and hit-area refinement only.

Files changed:

- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Inspector Outer Components Compactness Pass

Summary:

- Updated the outer Inspector (`Add Overlay` and `Added Elements`) to better match the compact density shown in `Runner Overlay Design System/preview/components-inspector.html`.
- Reduced segmented control visible height, tile icon scale, tile min-height, and added-row action button size to tighten vertical rhythm while keeping comfortable click targets.
- Adjusted outer panel and row horizontal paddings for denser composition.
- Fixed the add-tile plus icon alignment by giving the trailing plus a dedicated compact frame so it no longer appears overly flush-right.
- Kept the footer hint text removed (`Click an overlay to edit its style and position` remains absent).

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Detail Views Pixel-Level Polish Pass

Summary:

- Applied a pixel-level UI polish pass across all detail views to better match the `inspector-running-gauge.html` visual spec.
- Standardized switch sizing to mini controls in dense detail rows and section accessories for tighter vertical balance.
- Reduced segmented control visible height in dense detail rows and Lap List segmented pickers for better parity with the compact design target.
- Updated shared detail footers (`Reset` / `Done`) to use a 1:2 width ratio via a shared footer bar component, matching the target action hierarchy.

Files changed:

- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Lap Detail Delete Placement Alignment

Summary:

- Moved `Lap Live`, `Lap Card`, and `Lap List` overlay deletion into the detail header's trailing trash icon button, matching the existing Numeric, Route Map, and Running Gauge top-bar pattern.
- Removed the bottom delete footers from those three Lap detail views so destructive overlay actions have one consistent location.
- Aligned `Lap Live` and `Lap Card` headers with the shared fixed-height elevated Inspector header styling, including bottom separator and bordered category pill.
- Removed the extra top padding above the first `Lap List` detail section so `Layout` starts directly under the header separator.
- Removed the extra full-section outer stroke from shared `Background`, `Border`, and `Effects` inspector modules to prevent left-edge jitter when those sections expand or collapse.
- Removed the inset scroll padding and card-like section spacing from `Lap Card` and `Lap Live`; their overlay-specific sections now use the same full-width header/body rhythm as `Lap List` and Numeric detail sections.
- Replaced the long dense color preset strip with six mainstream swatches plus a trailing fixed-size custom color button that opens the shared system color panel, preventing fixed preset lists or embedded system picker intrinsic width from forcing narrow Inspector panels to overflow horizontally.
- Increased the Inspector split-pane default and minimum width to 460 px, and raised the app window minimum width to 1300 px so the three-column editor cannot compress the Inspector below its stored width.
- Shortened Numeric Overlay four-option segmented labels in dense rows (`Bot`, `Reg`, `Med`, `Semi`) so Label and Unit section expansion does not push segmented controls past the Inspector edge.

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/InspectorDenseComponents.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapLiveOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapCardOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayBackgroundInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayBorderInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayEffectsInspectorRows.swift`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Lap List Detail View Visual Alignment

Summary:

- Updated `LapListOverlayDetailView` to match the same dense detail-view visual structure used by Numeric Overlay, Route Map, and Running Gauge.
- Removed the extra external divider row under the header and moved separator treatment into the header container.
- Updated section header styling to the same top/bottom border rhythm and panel-header background used by other detail views.
- Updated section body spacing to stack rows with the shared row-divider rhythm.

Files changed:

- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Detail Views Visual And Interaction Restyle (No Functional Changes)

Summary:

- Restyled dense Inspector detail views to match the design-system `inspector-running-gauge.html` direction more closely while preserving all existing behavior and bindings.
- Applied the updated dense row/section visual language across shared components so Numeric Overlay, Route Map, and Running Gauge detail views all inherit the same spacing, row height, control density, and section divider rhythm.
- Updated section headers to use explicit top/bottom 1 px borders and panel-header surfaces, and updated dense rows to use fixed-height rows with per-row bottom dividers.
- Updated shared dense control sizing (`rowHeight`, `controlHeight`, label column width, and numeric slider value chip width) for stronger visual parity with the design artifact.
- For Running Gauge, added visual sub-section headers for `Outer Ring` and `Progress Ring` (toggle + chevron) to mirror the reference hierarchy and interaction feel without changing any underlying setting logic.
- Moved Route Map and Running Gauge header separators into header views (removing external extra separator rows) to keep top-bar structure and vertical rhythm aligned with other detail views.

Files changed:

- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Remove Inspector Footer Hint

Summary:

- Removed the bottom Inspector hint bar that displayed `Click an overlay to edit its style and position` in the outer Inspector state.
- Kept the rest of the Inspector layout and add/manage overlay flows unchanged.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Numeric Overlay Header Height Alignment

Summary:

- Aligned the Numeric Overlay detail header bar with the shared top-bar height rhythm used by other editor headers.
- Moved the header separator line into `NumericOverlayHeader` so the panel no longer adds an extra external divider row under the header.
- This removes the extra visual 1 px height and makes the Numeric Overlay top bar match other header bars in both structure and rendered height.

Files changed:

- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Extended FIT Parsing — Running Dynamics + Lap Data

Extended `FitFileParser` and `ActivityTimeline` with two groups of new data:

**Running dynamics (Phase A from the FIT numeric overlay plan)**

Newly parsed FIT record fields (message type 20):

| Field | FIT # | Unit stored | Notes |
|---|---|---|---|
| vertical_oscillation | 39 | mm (double) | uint16 × 0.1 mm |
| ground_contact_time | 41 | ms (double) | uint16 × 0.1 ms |
| stride_length | 84 | m (double) | uint16 × 0.1 mm → m |
| ground_contact_balance | 30 | % (double) | uint8 × 100 (left % * 100) |
| temperature | 13 | °C (double) | sint8 |
| grade | 9 | % (double) | sint16 × 0.01 |

Added to `ActivityRecord`: `verticalOscillationMM`, `groundContactTimeMS`, `strideLengthM`, `groundContactBalance`, `temperatureCelsius`, `gradePercent`.

Added to `ActivityTimeline`: `verticalOscillation(at:)`, `groundContactTime(at:)`, `strideLength(at:)`, `verticalRatio(at:)` (computed: osc/stride × 100), `groundContactBalance(at:)`, `temperature(at:)`, `grade(at:)` — all interpolated.

**Lap data (FIT message type 19)**

Added `LapKind` enum (`warmup / active / rest / cooldown / unknown`) and `LapRecord` struct (lapIndex, startElapsedTime, endElapsedTime, startDistanceMeters, totalDistanceMeters, totalElapsedTime, avgPaceSecondsPerKm, avgHeartRate, maxHeartRate, avgCadenceSPM, avgPowerWatts, totalAscent, kind). Added `laps: [LapRecord]` to `ActivityTimeline`. Classification uses avg speed threshold 3.5 m/s with warm-up/cool-down detection for first and last laps.

Added to `ActivityTimeline`: `currentLap(at:)`, `lapElapsedTime(at:)`, `lapProgress(at:byDistance:)`.

Parser additions: `RawLap` private struct, `makeLap(from:architecture:)` (reads fields 2/7/8/9/13/15/16/17/19/21), `buildLapRecords(startDate:totalLaps:)`, `lapKind(index:total:avgSpeedMS:)`, `parseGroundContactBalance`, int8/int16 decode helpers.

**Numeric overlay types (7 new cases in `OverlayElementType`)**

`verticalOscillation`, `groundContactTime`, `strideLength`, `verticalRatio`, `groundContactBalance`, `temperature`, `grade` — each with corresponding `OverlayUnitOption` cases, `OverlayValueFormatter.components` formatting, `RunningGaugeModel.OverlayGaugeMetric` cases, `numericIcon` SF symbols, and tile entries in the Inspector overlay browser.

Files changed: `FitFileParser.swift`, `ActivityTimeline.swift`, `OverlayElement.swift`, `OverlayValueFormatter.swift`, `RunningGaugeModel.swift`, `NumericOverlayDetailView.swift`, `ParameterPanelView.swift`, `ProjectDocument.swift` (calibration activity `laps: []`), all test files that construct `ActivityTimeline`.

Verification: `swift build` clean. `swift test` — all 51 tests passed.

---

### Lap List Overlay — Teleprompter-Style Lap Course Display

New chart overlay type (`OverlayElementType.lapList`) that renders the full workout lap structure as a vertically scrolling list, centered on the current lap with real-time progress and configurable columns.

**Data model** (`OverlayElement.swift`): Added `LapProgressMode` (distance / time), `LapListAnchor` (top / center / bottom), `LapColumnMetric` (lapNumber / lapKind / distance / elapsedTime / pace / heartRate / cadence / power / ascent), `LapListColumn` (metric + visible), `LapListStyle` (visibleRowCount, currentRowAnchor, fadeEnabled, fadeMinOpacity, progressBarEnabled, progressMode, progressColor, progressOpacity, showCompletedMark, rowHeight, rowCornerRadius, rowSpacing, backgroundOpacity, columns[]). Added `var lapList: LapListStyle` to `OverlayStyle` with `decodeIfPresent` fallback to `.default`.

**Render layout** (`OverlayRenderModel.swift`): Added `LapListRowRenderLayout` (lapRecord, rowRect, progressFraction, isCurrent, rowOpacity, columnTexts) and `LapListRenderLayout`. `lapListLayout(for:in:)` computes: visible window of laps centered at anchor row, per-row opacity from distance-to-current with `fadeMinOpacity` floor, per-row progress (1.0 completed / live fraction current / 0.0 future), column text via `lapColumnText(_:lap:activity:elapsedTime:isCurrent:)`.

**Export renderer** (`OverlayFrameRenderer.swift`): `renderLapList(_:renderContext:)` draws row backgrounds (rounded rect, semi-transparent black), progress bar fills (rounded rect clipped to progress fraction, accent color), current-lap border stroke, and column text laid out in equal-width cells with leading alignment for the first column and centered for the rest. Wired as a new `case .lapList` in `renderElement`.

**Preview** (`PreviewCanvasView.swift`): `LapListOverlayView` SwiftUI view — `VStack` of `lapRow` cells, each a `ZStack` with background, GeometryReader progress bar, optional border stroke, and `HStack` of column `Text` views. Wired as `case .lapList` in `overlayView`.

**Inspector** (`LapListOverlayDetailView.swift`): New dedicated inspector with four collapsible sections: *Layout* (visible rows stepper, current lap anchor segmented picker, row height / spacing / background opacity sliders, fade toggle + min opacity slider), *Progress Bar* (enabled toggle, mode segmented picker, color swatch strip, opacity slider), *Columns* (toggle each of the 9 column metrics), *Position* (scale slider). Header mirrors the Route Map header pattern (back button, icon, title, category pill).

**Routing**: `ParameterPanelView` routes `.lapList` to `LapListOverlayDetailView`. `lapList` tile added to the Charts category in the overlay browser with `isAccent: true`. All 7 new running-dynamics tiles added to the Metrics category.

**ProjectDocument**: Added `mutateLapListStyle(_:_:)` and `mutateLapListStyleContinuous(_:_:)` mutation helpers.

Files changed: `OverlayElement.swift`, `OverlayRenderModel.swift`, `OverlayFrameRenderer.swift`, `PreviewCanvasView.swift`, `ParameterPanelView.swift`, `ProjectDocument.swift`, new file `LapListOverlayDetailView.swift`, `OverlayValueFormatter.swift` (stub case), `NumericOverlayDetailView.swift` (icon), all test files.

Verification: `swift build` clean. `swift test` — all 51 tests passed.

---

### Route Map — Stats Bar (replaces Legend card)

Replaced the bottom-left Start/Finish legend card with a horizontal **Stats Bar** that attaches below the map container. The bar is off by default (`visible = false`) so existing projects are unaffected.

**Data model** (`OverlayElement.swift`): Added `RouteMapStatsMetric` enum (distance / pace / elapsedTime / heartRate / elevation / cadence / power / calories), `RouteMapStatsBarSlot` struct (metric, visible, customLabel), and `OverlayRouteMapStatsBarConfig` (visible, backgroundOpacity, slots[]). Added `routeMapStatsBar: OverlayRouteMapStatsBarConfig` to `OverlayStyle` with `decodeIfPresent` default for backward compatibility.

**Render layout** (`RouteMapOverlay.swift`): Added `OverlayRouteMapStatsBarItemLayout` and `OverlayRouteMapStatsBarLayout` structs. Added `statsBarLayout: OverlayRouteMapStatsBarLayout?` to `OverlayRouteMapRenderLayout`.

**Rect calculation** (`OverlayRenderModel.swift`): `routeMapLayout` now computes `totalRect` (map + bar) centered at `element.position`, splits it into `mapRect` (top) and `statsBarRect` (bottom). Stats bar height = 64 design-pt × element.scale. Slot values are resolved via `OverlayValueFormatter.components`.

**Export renderer** (`OverlayFrameRenderer.swift`): Removed `drawRouteLegend` / `drawLegendItem` / `drawGradientBand` calls. Added `drawRouteMapStatsBar` which renders N equal-width cells with value (large, white), unit (small, 70% white), and label (uppercase, 50% white), separated by thin dividers.

**Preview** (`PreviewCanvasView.swift`): `RouteMapOverlayView.body` is now a `VStack(spacing: 0)` — masked map content on top, stats bar below. Removed `routeLegend` / `legendRow` / `distanceText` helpers. `statsBarView` and `statsBarCell` handle SwiftUI rendering.

**Inspector** (`RouteMapOverlayDetailView.swift`): Rewrote the Legend section as **Stats Bar** — toggle in header, background opacity slider, and 4 slot rows (metric picker + visible toggle each).

**ProjectDocument** (`ProjectDocument.swift`): Added `setOverlayRouteMapStatsBarVisible`, `setOverlayRouteMapStatsBarBackgroundOpacity`, `setOverlayRouteMapStatsBarSlotMetric`, `setOverlayRouteMapStatsBarSlotVisible`.

Files changed: `OverlayElement.swift`, `RouteMapOverlay.swift`, `OverlayRenderModel.swift`, `OverlayFrameRenderer.swift`, `PreviewCanvasView.swift`, `RouteMapOverlayDetailView.swift`, `ProjectDocument.swift`.

---

### Route Map — Edge Fade Preview Fix, Square Fade Fix, Border Toggle, Inspector Cleanup

Three bugs fixed and one new control added, all in the Route Map overlay:

**Edge Fade preview not working (`.luminanceToAlpha()` fix)**

`RouteMapMaskRenderer.makeCGMask` creates a grayscale CGImage with no alpha channel (every pixel has alpha = 1). SwiftUI's `.mask()` modifier reads the mask view's *alpha* channel, not luminance, so the grayscale fade image was treated as fully opaque and had no visual effect. The export path (`CGContext.clip(to:mask:)`) interprets the gray values as luminance and was already correct. Fix: added `.luminanceToAlpha()` to the mask `Image` in `RouteMapOverlayView.body`, converting brightness → alpha before SwiftUI applies the mask.

**Square fade only affecting corners (edge-distance pixel algorithm)**

The original `drawFadeMask` used a radial gradient for both shapes, with the outer radius set to the half-diagonal of the bounding rectangle so the fade would reach every corner. For a square box the half-diagonal is `√2 × (half-side)`, while the center-to-edge-midpoint distance is just `half-side`. The inner boundary `innerRadius = outerRadius × (1 - fadeAmount)` sits close to the edge midpoints, so they receive almost no fade while the corners go fully black — producing the "only corners faded" visual artifact.

Fixed by switching the square case to a **per-pixel minimum-edge-distance** algorithm: `gray = clamp(min(dist_left, dist_right, dist_top, dist_bottom) / fadeWidth, 0, 1)` where `fadeWidth = min(w, h) × 0.5 × fadeAmount`. The shape interior is first filled white using a CGContext clip path (handling rounded corners), then each non-black pixel is multiplied by its edge-distance value. The circle shape retains the existing radial gradient which was already correct.

**Border toggle added to Container section**

The white semi-transparent ring drawn around the container was always-on with no way to disable it. Added `routeMapBorderVisible: Bool` to `OverlayStyle` (default `true`, backwards-compatible via `decodeIfPresent`). The **Border** toggle in the Container inspector section controls the non-selected border in both preview (`RouteMapOverlayView`) and export (`strokeRouteMapBorder`). The selection-state accent border is unaffected.

**Distance row removed from Preset section**

The "Distance" row in the Preset inspector section displayed the total activity distance — a static metadata readout with no configurable effect. Removed to reduce noise; the value already appears in the panel header subtitle.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift` — `routeMapBorderVisible` field
- `Sources/RunningOverlay/Overlay/RouteMapOverlay.swift` — `borderVisible` in render layout; square fade algorithm
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift` — pass `borderVisible` to layout
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift` — guard on `borderVisible` in `strokeRouteMapBorder`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift` — `.luminanceToAlpha()` on mask image; conditional border overlay
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift` — Border toggle in Container; Distance row removed
- `Sources/RunningOverlay/Project/ProjectDocument.swift` — `setOverlayRouteMapBorderVisible` mutation
- `docs/overlay-modules/route-map-overlay.md` — Phase E bug-fix notes
- `docs/project-log.md`

Verification: `swift build` succeeded with no errors.

### Inspector Segmented Controls Switched To Native Picker (All Inspector Flows)

Summary:

- Replaced Inspector custom segmented button rows with native SwiftUI segmented pickers (`Picker` with `.pickerStyle(.segmented)`).
- Updated all matching Inspector controls in `ParameterPanelView`, and migrated the shared dense segmented control used by Numeric Overlay, Running Gauge, and Route Map detail inspectors.
- Kept existing bindings and model mutations unchanged so behavior remains identical while interaction/focus/keyboard handling uses native control behavior.
- Removed the custom segmented-row implementations in favor of native segmented pickers.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Route Map — Phase E.1 Centering Fix, Decoupled Map Visibility, Adjustable Container Size, Stronger Edge Softness

Bug fixes and follow-up work on the Phase E refactor based on user feedback that (1) the projected route was running outside the map box, (2) the new Container Preset dropdown duplicated the Container section's controls, (3) square containers couldn't be resized independently, (4) Edge Softness barely affected the rendered output, and (5) "show map" was implicitly tied to Route Style.

Summary:

- Fixed the Mercator centering bug in `OverlayRouteMapRenderLayout.project`. `mercatorY` is monotonically *decreasing* in latitude, so the previous code was assigning the southernmost point's y to `minY` and the northernmost's to `maxY`, which produced a near-zero `yRange` (clamped to `0.000001`) and a huge `scale` that threw points way outside the rect. The new implementation computes `min` / `max` from the four projected corners and projects in a y-down coordinate system (matching both the SwiftUI preview and the `flipped: true` AppKit export context). The Container padding is now derived from the box's design size instead of being a flat `18 pt`, so wide rectangles still keep the polyline well inside the visible map. A regression assertion in `OverlayRenderModelTests` walks every projected point and the current point, and verifies they all fall inside `contentRect` (with a 1 pt FP tolerance for points that land exactly on an edge).
- Decoupled map visibility from the Route Style preset. `OverlayRouteMapPreset` is now `minimal` / `gradient` / `glow` only — the legacy `mapKit` case is migrated to `gradient` on decode for backward compatibility. Map presence is the single responsibility of `routeMapBackgroundStyle`: `.none` hides the map, every other case renders it. `OverlayRenderModel.routeMapLayout` now derives `routeMapProvider` from the background style, so callers no longer need to keep them in sync. `setOverlayRouteMapPreset` no longer mutates `routeMapProvider`.
- Added a dedicated **Show Map** toggle as the section accessory on `Background Map`, backed by the new `setOverlayRouteMapShowMap`. Off → `routeMapBackgroundStyle = .none`; on → restore the previously selected style, defaulting to `.dark` when the previous value was already `.none`. The Map Style dropdown excludes `.none` (`OverlayRouteMapBackgroundStyle.visibleCases`) and disables itself when Show Map is off.
- Added independent container dimensions: `OverlayStyle.routeMapWidth` and `routeMapHeight` (default `320 × 240`, clamped `80...1200`). Square containers expose two sliders; circle containers collapse to a single Size slider that drives both axes (the renderer takes the shorter edge as the diameter). New setters `setOverlayRouteMapWidth` / `setOverlayRouteMapHeight` use continuous undo. Switching shape to `circle` collapses width and height to the shorter edge so editor handles stay synced with the rendered diameter.
- Removed the `Container Preset` dropdown from the Inspector's Preset section because it duplicated the per-field Container controls. `OverlayRouteMapContainerPreset` and `setOverlayRouteMapContainerPreset` are kept for one-click recipes used by templates and tests, but no longer render an Inspector row.
- Reworked `RouteMapMaskRenderer.drawFadeMask` so Edge Softness has the dramatic vignette effect from the design mockup. Both shapes now draw a single radial gradient (3-stop white → white → black at locations `[0, 0.45, 1]`) clipped to the container outline, with the outer radius set to the half-diagonal for square containers so the fade reaches every corner without a hard step. The maximum softness is raised from `0.45` to `0.85` (matching the slider's new range) and exposed as `RouteMapMaskRenderer.maxFadeAmount`.
- Updated `OverlayFrameRenderer` and `PreviewCanvasView` so the map snapshot, the synthetic grid fallback, and the container background colour all key off `routeMapBackgroundStyle != .none` instead of `layout.preset == .mapKit`.

Documentation:

- `docs/design/route-map-overlay-ui.md` — Phase E.1 update. Section list now reads "Route Style Preset + Distance" for `Preset`, "Shape / Width / Height (or Size for circle) / Edge Mode / Edge Softness / Border" for `Container`, and "Show Map (header toggle) + Map Style (excluding none) + Map Opacity" for `Background Map`. Container Preset is documented as a templates-only API. Edge Softness range is `0...0.85`. Acceptance criteria updated to match.
- `docs/design/route-map-overlay-ui.spec.json` — same updates in machine-readable form. The `Container` section now lists `width` / `height` / `size` controls (with `visibleWhen` rules), the `Background Map` section gets a `showMap` accessory definition, and `routeMapPreset` no longer lists `mapKit` as an option. `modelGapsPhaseE` is now empty; the new fields move into `modelBackedToday`.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/RouteMapOverlay.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/design/route-map-overlay-ui.md`
- `docs/design/route-map-overlay-ui.spec.json`
- `docs/project-log.md`

Verification: `swift build` succeeded with only the pre-existing Running Gauge actor-isolation warnings. `swift test` passed all 51 tests in 8 suites; the route map projection regression assertion was added to ensure the centering fix doesn't regress.

## 2026-04-26

### Route Map — Phase E Container Presets, Map Opacity Slider, Inspector Spec Alignment

Summary:

- Promoted Route Map to its own dense Inspector detail view (`RouteMapOverlayDetailView`) modelled on `NumericOverlayDetailView`, so the right panel reuses `InspectorDenseRow`, `InspectorDenseSliderRow`, `InspectorDenseSegmented`, `InspectorDenseMenuLabel`, `InspectorDenseSwatchStrip`, `InspectorAnchorGrid`, and `NumericTokens` for byte-for-byte density parity with Numeric Overlay.
- Reorganised the panel into the eight sections required by the new spec: `Preset` (Container Preset + Route Style Preset + Distance readout), `Layout` (Anchor / X / Y / Scale / Rotation / Opacity), `Container` (Shape / Edge Mode / Edge Softness), `Background Map` (Map Style / Map Opacity), `Route Line`, `Markers`, `Legend` (with toggle accessory in the section header), and `Effects`.
- Introduced `OverlayRouteMapContainerPreset` (`squareHardEdge` / `circleHardEdge` / `squareGradientEdge` / `circleGradientEdge`). Selecting a preset writes a bundle of defaults (`routeMapShape`, `routeMapEdgeFade`, `routeMapFadeAmount`, `routeMapMapOpacity`, `shadowEnabled`, `shadowOpacity`, `shadowRadius`, `shadowOffsetX`, `shadowOffsetY`) onto the element through a single undo checkpoint. The four reference variants from the user's mockup can now be reproduced in one click.
- Added `OverlayStyle.routeMapMapOpacity` (default `0.72`, clamped `0...1`) and wired it through `OverlayRouteMapRenderLayout.mapOpacity`. Preview (`PreviewCanvasView.RouteMapOverlayView`) now applies `layout.mapOpacity` to the MapKit snapshot instead of a hard-coded `0.82`. Export (`OverlayFrameRenderer.drawMapGrid`) now scales the synthetic map grid alpha by `layout.mapOpacity` so still / video exports match the slider.
- Added `setOverlayRouteMapContainerPreset` and `setOverlayRouteMapMapOpacity` mutators to `ProjectDocument`, both registering an undo point so preset switches and slider drags are reversible. `setOverlayRouteMapEdgeSoftness` keeps its dual behaviour (writes both `routeMapFadeAmount` and `routeMapEdgeFade`).
- Persisted the new fields through `OverlayStyle.init(from:)` with `decodeIfPresent` defaults so legacy templates and projects load unchanged. `routeMapMapOpacity` is clamped on decode.
- Added a `RouteMapOverlayHeader` that mirrors the Numeric header (back / icon / title / `Overlay` pill / trash) plus a distance subtitle, replacing the older "1657 pts" header block with a clean `12.86 km` readout.

Documentation:

- New design spec `docs/design/route-map-overlay-ui.md` — header, eight sections, every control's model mapping, density tokens shared with Numeric Overlay, container preset value table, model gaps grouped into Phase E (this revision: container preset + map opacity) and Phase F (border / glow / map adjustments / route line richness / per-marker details / legend item list / typography / blend mode), and acceptance criteria.
- New machine-readable spec `docs/design/route-map-overlay-ui.spec.json` listing every section, control, model path, options, default values, and `containerPresetDefaults` table — same shape as `numeric-overlay-ui.spec.json`.
- Updated `docs/overlay-modules/route-map-overlay.md` with a pointer to the new design spec and added Phase E and Phase F to the implementation phase list, marking Phase D items completed where applicable.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/RouteMapOverlay.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `docs/design/route-map-overlay-ui.md` (new)
- `docs/design/route-map-overlay-ui.spec.json` (new)
- `docs/overlay-modules/route-map-overlay.md`

Verification: `swift build` succeeded (only pre-existing Running Gauge actor-isolation warnings remain). `swift test` passed all 51 tests in 8 suites.

### Running Gauge — Full Module Redesign (7 Layouts × 7 Style Presets, Per-Region Metric Binding)

Summary:

- Promoted the Running Gauge from a hardcoded `Distance / Time / Pace / HR` disc to a fully configurable circular dial module with per-region metric binding, seven data-layout presets, seven visual style presets, and an Inspector that exposes every dial / ring / tick / divider / typography / color / effect knob the renderer consumes. Implements `Running Gauge Overlay 设计与实现指引` end-to-end through MVP scope (sections 1–8, 9, 14, 15 of the guide).
- New data model file `Sources/RunningOverlay/Overlay/RunningGaugeModel.swift` introduces:
  - `OverlayGaugeMetric` (distance / pace / elapsedTime / realTime / heartRate / power / cadence / elevation / calories) with bridging to the existing `OverlayElementType` so `OverlayValueFormatter.components(for:activity:elapsedTime:)` can resolve label/value/unit tuples without duplication.
  - `RunningGaugeRegion` (11 region slots: top, middle, bottom, middleLeft/Center/Right, topLeft/Right, bottomLeft/Center/Right) and `RunningGaugeLayoutPreset` with the seven layouts from the spec — `topBottom`, `topMiddleBottom`, `threeZones`, `topTwoMiddleBottom`, `topThreeMiddleBottom`, `fourZones`, `fiveZones` — each declaring its visible regions in render order.
  - `RunningGaugeRegionConfig` per-region struct: metric, custom label, show label/unit/icon flags, value/label/unit font scale, value/label weight, optional value/label colours.
  - `RunningGaugeProgressMode` (none / distanceTarget / elapsedTimeTarget / heartRateZone / powerZone / paceIntensity / customPercentage).
  - `RunningGaugeStyle`: the single source of truth for a gauge — style preset, layout preset, regions[], dial (color/opacity/glass), outer ring (toggle/color/opacity/width-scale), tick marks (toggle/color/opacities/count/major-every), progress ring (toggle/mode/color/track/opacity/width-scale/rounded-caps), dividers (toggle/color/opacity/width), typography (font/monospaced/primary+secondary weight), color (primary/secondary text/accent), effects (shadow toggle/opacity/radius, glow toggle/color/opacity/radius).
  - Built-in presets `minimalSport`, `highContrastSport`, `roadRun`, `trailAdventure`, `futureTech`, `retroDigital`, `premiumGlass` matching the guide's recommended visual parameters and recommended layout pairings.
  - `RunningGaugeStyle.defaultRegions(for:)` factory that emits the recommended metric assignments per layout (e.g. `topTwoMiddleBottom` → Distance / Pace / Time / HR).
  - `RunningGaugeLayoutEngine.regionFrames(for:in:)` returns per-region `CGRect`s in gauge-local coordinates for every layout, and `dividerSegments(for:)` returns normalised divider lines so the renderer and the SwiftUI preview can share one source of truth.
- Wired `RunningGaugeStyle` into `OverlayStyle.gauge` (with default + Codable migration that seeds the gauge sub-style from the legacy top-level `gaugePreset` for older project files). Extended `OverlayGaugePreset` with two new cases (`.roadRun`, `.premiumGlass`) and updated all preset display labels to match the design guide's bilingual format.
- Refactored `OverlayRunningGaugeRenderLayout` and `OverlayRenderModel.runningGaugeLayout(for:in:)` to compute, for each rendered region, a canvas-space `CGRect`, the formatted metric value components, and value/label/unit font sizes scaled from the gauge diameter using the spec's `gaugeSize × 0.145` baseline. Progress is now derived from `RunningGaugeProgressMode` (distance target → distance ratio, elapsed-time / zone-style modes → elapsed/duration ratio, custom → 0.5 placeholder).
- Replaced `renderRunningGauge` and its helpers in `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift` with a layered draw pass: dial fill → outer ring (configurable width/color/opacity) → tick marks (count, major-every, two opacities) → progress ring (track + arc with rounded caps) → divider lines (driven by `RunningGaugeLayoutEngine.dividerSegments` clamped to a `safeRadius = diameter * 0.40` inset) → per-region label / value / unit text (alignment, weight, monospaced digits via `featureSettings`). The legacy preset-specific helper switches (`gaugeMinimumBackgroundOpacity`, `gaugeValueColor`, `gaugeLabelColor`, `gaugeTickColor`) are gone — colours and opacities now flow directly from the user-editable `RunningGaugeStyle`.
- Rewrote the SwiftUI `RunningGaugeOverlayView` in `PreviewCanvasView.swift` with the same layered structure so the in-editor preview is byte-for-byte parity with the export renderer. Tick and divider shapes share the layout engine helpers; per-region text uses `Text` views positioned via `position(x:y:)` from the same region frames the renderer consumes. New `GaugeMonospacedDigit` and `GaugeGlow` view modifiers conditionally apply monospaced digits and glow shadows so non-tech presets aren't taxed.
- Rebuilt `RunningGaugeOverlayDetailView` to expose 11 dense Inspector sections that mirror the numeric overlay's design language — Style Preset, Position & Scale, Data Layout, Region Settings, Dial, Ring, Ticks, Dividers, Typography, Color, Effects. Region Settings lists every region in the active layout with an inline metric picker; clicking the slider chevron expands a per-region drawer with custom label, show-label/unit toggles, value-size/weight sliders, and value-color swatch. Conditional sub-rows (e.g. tick-color appears only when ticks are enabled, glow color only when glow is on) keep the panel readable across presets.
- Added two new `ProjectDocument` mutators: `mutateGaugeStyle(_:_:)` (generic in-place mutator with a single undo checkpoint) and `setOverlayGaugeLayout(_:layout:)` / `updateOverlayGaugeRegion(_:region:_:)` for the layout + region surface area. `setOverlayGaugePreset` now re-seeds the gauge sub-style from the chosen preset so picking a preset resets visual parameters but not the user's data layout / region bindings.
- Updated `Tests/RunningOverlayTests/OverlayRenderModelTests.swift` to assert against the new region-based layout output (verifying that the default `.roadRun` preset yields `topTwoMiddleBottom` with Distance / Pace / Time / HR bound to top / middleLeft / middleRight / bottom).

Files changed:

- `Sources/RunningOverlay/Overlay/RunningGaugeModel.swift` (new)
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/project-log.md`
- `docs/requirements.md`

Verification:

- `swift build` clean.
- `swift test` 51 tests in 8 suites pass, including the rewritten `runningGaugeLayoutCarriesCoreMetricsAndProgress` and `overlayFrameRendererWritesRunningGaugePNG` golden frame.

Notes / next milestones (deferred to a follow-up per spec section 15 "v1 may defer"):

- Glass blur and texture effects, full free-form custom region drag, multi-progress-ring stacks, and animated entry. The data model already carries `glassEffectEnabled`, glow, and a `RunningGaugeLayoutPreset.custom` placeholder so the renderer/inspector can be extended without further migrations.
- Per-region icons and custom progress max for zone modes — fields are reserved (`showIcon`, `progressMode`) but the renderer currently substitutes time-based progress for HR/Power/Pace zones until a project-level zone configuration lands.

### Running Gauge Inspector — Dense Layout Aligned With Numeric Overlay

Summary:

- Added `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`, a Running Gauge–specific Inspector panel that mirrors the dense design language of `NumericOverlayDetailView`. It reuses the same `NumericTokens` (row height 32, control height 28, panel padding 12/8, control radius 5, monospaced numeric font) and the shared dense components (`InspectorDenseRow`, `InspectorDenseSliderRow`, `InspectorDenseAxisField`, `InspectorDenseSegmented`, `InspectorDenseSwatchStrip`, `InspectorAnchorGrid`, `InspectorDenseMenuLabel`) so the two inspectors are visually identical pixel-for-pixel in spacing, typography, borders, and section disclosure behavior.
- The gauge panel exposes only the parameters the gauge renderer actually consumes, organised into the same five-section pattern used by the numeric inspector:
  - **Style** — gauge preset menu (Minimal Sport / High Contrast / Trail Adventure / Tech Future / Retro Digital).
  - **Layout** — 9-cell anchor grid, X/Y position fields, Scale and Rotation sliders.
  - **Typography** — Font menu, Size slider (drives all internal value/label/unit sub-sizes), Weight segmented control.
  - **Color** — Accent swatch strip (drives the progress arc and value text via `foregroundColor`).
  - **Background** — Opacity slider for the circular gauge background disc.
- Header matches the numeric overlay layout: back chevron, type icon tile, title plus a "Gauge" caption pill, trailing destructive delete button, and a `Reset` / `Done` footer with the same `EditorSecondaryButtonStyle` / `EditorPrimaryButtonStyle` pairing.
- Updated `ParameterPanelView.body` so the overlay element router dispatches `.runningGauge` to the new dense view; numeric overlays still route to `NumericOverlayDetailView` and the remaining non-numeric types (currently only `.routeMap`) keep using the legacy `OverlayDetailView`.

Files changed:

- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift` (new)
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`. Build succeeded.

### Numeric Overlay Presets — Canonical 10 (Minimal Clean → Digital Watch)

Summary:

- Adopted the brief in `assets/image-413a701b-166c-42e5-947c-31b27a732e25.png` as the canonical numeric overlay preset system. The 10 presets exposed in the inspector are: Minimal Clean, Minimal Label, Pill, Metric Card, Big Number, Split Label, Neon Glow, Racing Stripe, Editorial, Digital Watch.
- Added five new `OverlayTextPreset` cases (`.minimalLabel`, `.neonGlow`, `.racingStripe`, `.editorial`, `.digitalWatch`) and renamed display labels for the existing five reused cases (`.minimal` → "Minimal Clean", `.pillBadge` → "Pill", etc.).
- Refreshed `OverlayPresetTokens` to also carry `backgroundColor`, `backgroundOpacity`, and `backgroundRadius`, so applying a preset can fully snap the background look (e.g. Pill → black 48% capsule, Digital Watch → black 60% rounded with phosphor-green accent border).
- Recommended tokens are now defined for all 10 canonical presets. `ProjectDocument.applyOverlayTextPreset` writes the tokens through to `OverlayStyle` and `addOverlayElement(_:)` seeds new numeric elements with the type's recommended preset (e.g. `.power` → Racing Stripe, `.elapsedTime` → Digital Watch, `.heartRate`/`.cadence` → Pill).
- Replaced the preset preview/export bodies for the canonical 10 in `PreviewCanvasView` (`minimalCleanView`, `minimalLabelView`, `pillView`, `splitLabelView`, `neonGlowView`, `racingStripeView`, `editorialView`, `digitalWatchView`) and `OverlayFrameRenderer` (`renderMinimalLabel`, `renderNeonGlow`, `renderRacingStripe`, `renderEditorial`, `renderDigitalWatch`). Added matching `presetTextRect` sizing for each new layout.
- The numeric inspector preset menu and the text-preset row in `ParameterPanelView` both now iterate `OverlayTextPreset.numericPresets` (the 10 canonical cases) so legacy / deprecated cases (`.sportWatch`, `.inlineGhost`, `.accentBar`, `.sportNeon`, `.serifEditorial`) remain decodable for old projects but never appear in the picker.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`. All 51 tests passed.

### Numeric Overlay Visual Presets — Inline Ghost / Accent Bar / Sport Neon / Serif Editorial

Summary:

- Added four new `OverlayTextPreset` cases for numeric overlays: `.inlineGhost`, `.accentBar`, `.sportNeon`, `.serifEditorial`. Each follows the design brief in `assets/image-621dbbba-3e2f-42df-87df-80810a9c2be0.png`.
- Implemented preview rendering for the new presets in `TextPresetOverlayView`, including 0.5 px rules, accent bars/dots, uppercase tracked labels, and Georgia serif numerals.
- Implemented matching export rendering in `OverlayFrameRenderer` (`renderInlineGhost` / `renderAccentBar` / `renderSportNeon` / `renderSerifEditorial`) plus per-preset bounding-box sizing in `presetTextRect`. `drawText` now accepts an optional foreground color so per-element opacity and accent tints work without overriding `OverlayStyle.foregroundColor`.
- Added `OverlayPresetTokens` and `OverlayTextPreset.recommendedTokens`. The new `ProjectDocument.applyOverlayTextPreset` setter snaps `fontName`, `fontSize`, `fontWeight`, `textAlignment`, `showLabel`, `showUnit`, `backgroundEnabled`, and `accentColor` to the brief's tokens (e.g. Sport Neon → 36 pt heavy, cyan accent #22d3ee, transparent background) when the user picks a preset.
- Added a `Style` row to the Content section of the numeric Inspector so users can pick any preset (existing or new) from the dense panel; selecting a preset routes through `applyOverlayTextPreset` so token snapping is undoable and Reset still works.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`. All 51 tests passed.

### Numeric Overlay Preview Wiring & Inspector Polish

Summary:

- Wired numeric overlay preview rendering to the new style fields so toggles in the Inspector now affect the live preview, not just export:
  - `.minimal` text preset honors `showLabel` (renders the label inline) and `showUnit` (hides the unit suffix when off).
  - Background drawing now uses `backgroundEnabled` + `backgroundColor`; turning the toggle off removes the bubble entirely (selection highlight still draws).
  - Shadow drawing now gates on `shadowEnabled` and uses `shadowOffsetX/Y`.
- Removed the read-only `Metric` row at the top of the Content section in the numeric Inspector; metric is already shown in the header.
- Removed the duplicate chevron in `InspectorDenseMenuLabel`; we now rely on the platform `Menu` indicator only.
- Renamed the `Effects` section to `Shadow` (Inspector + design doc) so the title matches the controls inside it.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `docs/design/numeric-overlay-ui.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`. All 51 tests passed.

### Numeric Overlay UI Refactor

Summary:

- Refactored the numeric category Inspector to a dense, DaVinci-style two-column panel matching `docs/design/numeric-overlay-ui.md` and the `numeric-overlay.png` mockup.
- Added a new `NumericOverlayDetailView` with collapsible sections (Content, Layout, Typography, Color, Background, Effects), compact dense rows, and a sticky Reset/Done footer.
- Routed numeric overlay types (heart rate, pace, calories, elapsed time, real time, distance, elevation, cadence, power) through the new view via `ParameterPanelView`; non-numeric overlays continue to use the legacy `OverlayDetailView`.
- Extended `OverlayStyle` with the previously missing fields: `unitOption`, `showLabel`, `showUnit`, `customLabel`, `rotationDegrees`, `textAlignment`, `accentColor`, `backgroundEnabled`, `backgroundColor`, `backgroundRadius`, `backgroundPaddingX`, `backgroundPaddingY`, `shadowEnabled`, `shadowOffsetX`, `shadowOffsetY`. All new fields decode with defaults for legacy templates.
- Added `OverlayUnitOption` and `OverlayTextAlignment` enums plus `OverlayElementType.isNumericOverlay` / `defaultUnitOption` helpers.
- Updated `OverlayValueFormatter` to be element-aware so it honors the new unit option, label/unit visibility, and custom label fields.
- Updated `OverlayRenderModel` and `OverlayFrameRenderer` so the `.minimal` text preset uses the new background color/radius/padding/shadow fields when rendering.
- Added `ProjectDocument` setters for every new field plus a `resetOverlayStyle` action used by the Reset footer button.
- Added formatter tests covering pace metric/imperial/rowing units, distance miles/meters, elevation feet, duration seconds, and label/unit/custom-label flags.
- Updated `docs/design/numeric-overlay-ui.md` to mark the previously-missing model fields as implemented.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift` (new)
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Tests/RunningOverlayTests/OverlayValueFormatterTests.swift`
- `docs/design/numeric-overlay-ui.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 51 tests passed.

### Layer-Wide Clip Offset Action

Summary:

- Updated the clip-offset action in the Inspector from camera-wide apply to layer-wide apply.
- Changed clip Inspector button copy to `Apply to all clips in this layer`.
- Updated timeline offset application logic to target only the selected clip's timeline layer, not all clips sharing camera/source group.
- Added and updated tests to ensure only the current layer receives the offset update.
- Synced requirements, development notes, and roadmap wording with the new layer-wide behavior.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 49 tests passed.

### Numeric Overlay UI Design Spec

Summary:

- Added implementation-facing design documentation for a dense reusable Numeric Overlay Inspector detail template.
- Scoped the template to single-value numeric overlays including Pace, Heart Rate, Distance, Power, Cadence, Calories, Elevation, Elapsed Time, and Real Time.
- Captured the DaVinci-like compact panel direction with dense sections, two-column label/control rows, unit selection, background controls, typography, layout, color, and effects groups.
- Added Pace unit choices: `Metric (min/km)`, `Imperial (min/mi)`, and `Rowing (min/500m)`, plus suggested unit options for other numeric metrics.
- Documented current model-backed fields and model gaps so follow-up agents can separate visual implementation from schema work.
- Linked the Numeric Overlay template from the Inspector design docs and structured spec.

Files changed:

- `docs/design/README.md`
- `docs/design/inspector-ui.md`
- `docs/design/inspector-ui.spec.json`
- `docs/design/numeric-overlay-ui.md`
- `docs/design/numeric-overlay-ui.spec.json`
- `docs/design/numeric-overlay.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/inspector-ui.spec.json docs/design/numeric-overlay-ui.spec.json`.
- Documentation/design-only change; tests not run.

### Stable Pane Widths With Custom Horizontal Splitter

Summary:

- Replaced the upper editor `HSplitView` with a custom `HStack` plus `HorizontalResizeHandle` dividers because SwiftUI `HSplitView` reset child pane widths whenever Inspector internal selection changed (overlay detail, timeline clip selection) or Media Pool content changed (importing/matching media).
- Stored Media Pool and Inspector widths in `@State` (`mediaPoolWidth = 380`, `inspectorWidth = 400`) so user-dragged sizes persist across every internal state change.
- Added Min/Max clamping (Media Pool 300-720 px, Inspector 320-720 px) and `NSCursor.resizeLeftRight` hover feedback on the custom handles.
- Synced Inspector design and project documentation to require width stability across all internal state changes for both panes.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `docs/design/inspector-ui.md`
- `docs/design/inspector-ui.spec.json`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 49 tests passed.

### Resizable Media Pool And Inspector Defaults With Stable Inspector Width

Summary:

- Set Media Pool default width to `380 px` (min `300 px`) and Inspector default width to `400 px` (min `320 px`); both panels remain user-resizable via the split dividers.
- Removed the fixed-width frame from `ParameterPanelView` body so the HSplitView pane width is owned by the split view; internal Inspector selection changes (outer/clip/overlay) no longer resize the right pane.
- Synced Inspector design and project documentation to require draggable Inspector width that is preserved across internal state switches.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/design/inspector-ui.md`
- `docs/design/inspector-ui.spec.json`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All tests passed.
- Ran `jq empty docs/design/inspector-ui.spec.json`.

### Inspector Fixed Width Across Editing States

Summary:

- Fixed the Inspector split-pane width at `380 px` so switching between outer/detail/editing states no longer changes panel width.
- Updated Inspector panel sizing in both the split-view host and `ParameterPanelView` to use a single fixed-width constraint.
- Synced Inspector design and implementation docs to explicitly require fixed-width behavior.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/design/inspector-ui.md`
- `docs/design/inspector-ui.spec.json`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All tests passed.

### Header Height Unification For Media Preview Inspector

Summary:

- Unified top header height across Media, Preview, and Inspector panels.
- Updated Preview header to use the shared `EditorPanelHeader` and shared header button sizing.
- Updated Inspector header to also use `EditorPanelHeader`, with the status label rendered as caption metadata and the trailing icon button as a header action.
- Removed redundant inline `Divider()` after Inspector headers because `EditorPanelHeader` already draws its own bottom divider, eliminating extra vertical pixels that made Inspector taller than Preview.
- Synced requirements and development docs with the new header and button-size consistency rule.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Timeline Frame Step Shortcuts

Summary:

- Changed Left Arrow and Right Arrow to step the timeline playhead backward or forward by one project frame.
- Frame-step size is derived from the current project frame rate.
- Manual frame stepping stops playback and exits temporary media-pool source preview before moving the timeline playhead.
- Added a project-level test covering frame-rate-based stepping.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 49 tests passed.

### Timeline UI Polish: Playhead, Selection, Hover Pill, Header Picker

Summary:

- Removed the timeline header `Preview` `Auto` picker because per-track visibility in the eye-icon menu already covers the same workflow; the implicit auto preview track is preserved.
- Updated the AppKit playhead to a small downward-pointing triangle inside the ruler band connected to a thin red line that extends down through the tracks; the playhead no longer extends above the ruler and is no longer a square block.
- Updated selected timeline clips to draw a 2 px white border on top of the blue fill so the selected clip matches the design mockup.
- Updated the ruler hover info pill to draw a small downward-pointing arrow on its bottom edge whose tip aligns with the hovered ruler position.
- Synced the timeline design docs and project docs with the picker removal, playhead shape rules, selected-clip border rule, and hover-pill arrow rule.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/design/timeline-ui.md`
- `docs/design/timeline-ui.spec.json`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.
- Ran `jq empty docs/design/timeline-ui.spec.json`.

### Timeline UI Restyle Implementation

Summary:

- Reworked timeline visuals in `TimelineView` to match the latest `timeline-ui` design spec while preserving existing timeline behaviors.
- Added timeline-specific AppKit color tokens in `EditorTheme` for FIT bars, clip blocks, playhead, lane bands, label column, splice borders, and drop targets.
- Updated the timeline canvas styling for compact ruler ticks, alternating dark track bands, square-adjacent clip joins, subtle dashed drop targets, compact hover info pills, and a muted-red playhead with a small connected marker.
- Updated timeline header styling to include the explicit `Preview` label and clearer collapse-toggle active-state signaling.
- Synced implementation docs and requirements with the new timeline visual language and removed outdated references to a large playhead head.

Files changed:

- `Sources/RunningOverlay/UI/EditorTheme.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Timeline UI Design Spec

Summary:

- Added implementation-facing design documentation for the bottom Timeline UI.
- Captured current timeline functionality in design form, including Preview track selection, per-track preview visibility, collapse/expand gaps, nonlinear zoom, ruler hover data, FIT layer alignment, video tracks, media drop targets, selected clip styling, and collapsed gap behavior.
- Added the final Timeline mockup with a subtle connected playhead marker and no separate `Gaps hidden` status row.
- Added a machine-readable Timeline UI spec for future agents to refine `TimelineView` and `TimelineCanvasNSView` from structured component, token, and interaction data.
- Updated the app-level design system and design index to include Timeline UI references.

Files changed:

- `docs/design/README.md`
- `docs/design/app-ui.md`
- `docs/design/app-ui.spec.json`
- `docs/design/timeline-ui.md`
- `docs/design/timeline-ui.spec.json`
- `docs/design/timeline.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/app-ui.spec.json docs/design/timeline-ui.spec.json`.
- Documentation/design-only change; tests not run.

### Preview Header And Playback Row Spacing

Summary:

- Removed the apparent top and bottom blank strips in the Preview panel by moving fixed row heights inside the header and playback-row components so their backgrounds fill the rows.
- Reduced the Preview header controls to leave visible vertical margin around the safe guides and Fit buttons.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Preview UI Implementation

Summary:

- Implemented the Preview UI design spec in `PreviewCanvasView`.
- Added an in-preview header with title, project resolution/frame-rate metadata, a safe guides toggle, and a compact Fit menu placeholder.
- Removed the safe guides toggle from the app-level toolbar so Export remains the only app-level action on the right side.
- Restyled the canvas workspace around the fitted project canvas and added a subtle Guides On HUD while safety guides are enabled.
- Added blue safe guide strokes and selected-overlay affordances with a border plus corner handles.
- Reworked the bottom playback row into a centered previous/stop/play-pause/next cluster with a right-pinned playback-rate menu.
- Added direct playback-rate selection for 1x, 2x, 4x, and 8x.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Preview UI Design Spec

Summary:

- Added implementation-facing design documentation for the central Preview UI.
- Captured the final Preview interaction direction: safe guides live in the Preview header, Fit remains in the Preview header, and Export stays in the app toolbar.
- Defined the simplified bottom playback row with centered previous/stop/play-pause/next controls, no timecode, no scrubber, and playback speed pinned to the bottom right.
- Added a machine-readable Preview UI spec for future agents to implement `PreviewCanvasView` and remove the safe guides toggle from `MainEditorView.toolbar`.
- Updated the app-level UI design docs to reference Preview-specific components and guidance.

Files changed:

- `docs/design/README.md`
- `docs/design/app-ui.md`
- `docs/design/app-ui.spec.json`
- `docs/design/preview-ui.md`
- `docs/design/preview-ui.spec.json`
- `docs/design/preview.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/app-ui.spec.json docs/design/preview-ui.spec.json`.
- Documentation/design-only change; tests not run.

### Media Pool Header Menu Simplification

Summary:

- Removed the unused trailing Media Options dropdown from the Media Pool header.
- Changed the mark filter menu entries to use circular color icons.
- Removed the extra chevron-style visual from the mark filter button label.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Media Pool Icon Alignment And Mark Menu Polish

Summary:

- Centered the media row file icon inside its thumbnail well.
- Changed Mark submenu entries to use generated circular color icons so color marks are visible in the native context menu.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Media Pool UI Spec Implementation

Summary:

- Implemented the Media Pool design spec in `MediaBrowserView` with a header toolbar, search field, visible clip count, and real `All` / `Ready` / `Aligned` status filters.
- Added filename search and made tag/status/search filter changes prune hidden selections.
- Restyled media rows with compact file icon wells, hover fills, selected-row blue accent strips, status pills, source-preview play indicators, and Mark submenu color dots.
- Expanded the no-media and filtered-empty states with the import action, matching-workflow helper text, supported-format hint, and dashed drop-zone treatment.
- Preserved drag/drop import, Command-click multi-select, Command+A visible selection, double-click source preview, native context menu actions, and focus-loss preview clearing.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### App UI Visual System Implementation

Summary:

- Added shared SwiftUI/AppKit `EditorTheme` tokens matching `docs/design/app-ui.md` for app backgrounds, panel surfaces, controls, borders, text, accent colors, spacing, radii, and typography.
- Restyled the main toolbar, status bar, export progress popover, Media Pool, Preview playback controls, Timeline toolbar/canvas, Project Settings, and Export dialog toward the shared dark editor system.
- Migrated Inspector token definitions to use the shared app theme while preserving its feature-specific component structure.
- Increased Media Pool split-pane minimum width and kept Inspector width constraints stable for dense controls.
- Updated AppKit timeline drawing colors to use the same app-level palette instead of system window/control backgrounds.

Files changed:

- `Sources/RunningOverlay/UI/EditorTheme.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### App UI Design System And Media Empty State

Summary:

- Added an application-level UI design system for Running Overlay covering product character, shared tokens, typography, layout, component standards, interactions, empty states, and accessibility.
- Added a machine-readable app-level UI spec for future agents to consume shared design guidance consistently across Media Pool, Preview, Timeline, and Inspector work.
- Added the Media Pool empty-state design mockup with drag/drop import affordance, import action, and supported-format hint.
- Updated the Media Pool UI spec and structured spec to reference both populated and empty media states.
- Updated the design docs index so app-level and empty-state assets are discoverable.

Files changed:

- `docs/design/README.md`
- `docs/design/app-ui.md`
- `docs/design/app-ui.spec.json`
- `docs/design/media-pool-ui.md`
- `docs/design/media-pool-ui.spec.json`
- `docs/design/media-pool-empty.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/app-ui.spec.json docs/design/media-pool-ui.spec.json`.
- Documentation/design-only change; tests not run.

### Media Pool UI Design Spec

Summary:

- Added implementation-facing design documentation for the refreshed Media Pool UI.
- Captured the media list layout, header toolbar, search/filter area, row states, context menu, and Mark submenu behavior.
- Aligned Media Pool colors, spacing, typography, row styling, and menu treatment with the Inspector design language.
- Added a machine-readable JSON spec so follow-up agents can implement or restyle `MediaBrowserView` from structured token, component, and interaction data.
- Documented which current Media Pool behaviors must be preserved, including drag/drop import, selection, source preview, context-menu matching, tag filtering, and focus-loss preview clearing.

Files changed:

- `docs/design/README.md`
- `docs/design/media-pool-ui.md`
- `docs/design/media-pool-ui.spec.json`
- `docs/design/media-pool.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/media-pool-ui.spec.json`.
- Documentation/design-only change; tests not run.

## 2026-04-25

### Inspector UI Refactor Implementation

Summary:

- Rebuilt the Inspector SwiftUI surface around the design spec in `docs/design/inspector-ui.md`.
- Added tokenized dark Inspector styling for headers, sections, rows, tiles, icon buttons, segmented controls, sliders, value fields, and swatches.
- Replaced the flat overlay library with an outer add/manage state using Metrics, Charts, and Route tabs plus live-value added-overlay rows.
- Replaced the selected overlay form with a detail state that includes a detail header, Content, Position & Size, Style, and a sticky Done footer.
- Kept controls model-backed and rendered unsupported visibility/lock actions as disabled placeholders while omitting animation, generic opacity, and metric reassignment persistence.
- Restyled clip timing Inspector controls to use the same dark panel language.
- Added a stable 360 px minimum / 380 px ideal Inspector width so hierarchy changes do not collapse the right split pane.
- Expanded add-overlay tab hit targets so clicking anywhere inside a tab segment switches tabs.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/architecture.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Inspector UI Design Spec

Summary:

- Added implementation-facing design documentation for the refreshed Inspector UI.
- Captured the two primary Inspector overlay states: outer add/manage state and selected Overlay Detail state.
- Defined app-level dark editor UI guidance, design tokens, spacing, typography, component structure, and interaction rules.
- Added a machine-readable JSON spec so follow-up agents can implement SwiftUI components from structured state, token, and model mapping data.
- Documented current model gaps for visibility, lock, generic opacity, animation, and metric reassignment controls.

Files changed:

- `docs/design/README.md`
- `docs/design/inspector-ui.md`
- `docs/design/inspector-ui.spec.json`
- `docs/design/inspector-outer.png`
- `docs/design/overlay-detail-running-gauge.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/inspector-ui.spec.json`.
- Documentation/design-only change; tests not run.

### Route Map Overlay First Pass

Summary:

- Added GPS coordinate parsing for FIT record `position_lat` and `position_long`.
- Added route points, route bounds, and current-position interpolation to the activity timeline.
- Added the Route Map overlay type with Minimal, Gradient, Glow, and MapKit presets.
- Added preview/export route rendering with start, finish, and current-position markers.
- Added a MapKit snapshot provider abstraction and preview-time `MKMapSnapshotter` loading for the MapKit preset, with local fallback rendering.
- Added route map render model and PNG export tests.

Files changed:

- `Sources/RunningOverlay/FitData/ActivityTimeline.swift`
- `Sources/RunningOverlay/FitData/FitFileParser.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift`
- `Sources/RunningOverlay/Overlay/RouteMapOverlay.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/overlay-modules/route-map-overlay.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Route Map Overlay Design

Summary:

- Added a dedicated featured overlay module documentation area under `docs/overlay-modules/`.
- Drafted the Route Map Overlay design covering user-facing styles, Inspector controls, FIT GPS data needs, map API options, rendering architecture, caching, privacy, template behavior, and phased implementation.
- Linked the module from README, requirements, and roadmap.

Files changed:

- `README.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/overlay-modules/README.md`
- `docs/overlay-modules/route-map-overlay.md`

Verification:

- Documentation-only change; tests not run.

### Source Preview Playback Controls

Summary:

- Made media-pool double-click source preview start playback immediately instead of showing a paused first frame.
- Kept temporary source preview playback independent from the timeline playhead, including pause/resume from the current source time.
- Added a Preview-area playback strip below the video canvas with previous, stop, play/pause, and next controls.
- Added global K play/pause and L forward-speed behavior, stepping playback from 1x to 2x, 4x, and 8x.
- Moved the toolbar playback button into the Preview area.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/VideoPreviewPlayerView.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 42 tests passed.

### Media Browser Keyboard Focus Cleanup

Summary:

- Restored Command+A selection for the custom media browser by adding an invisible AppKit key-capture view.
- Removed the visible blue system focus ring that appeared around the media browser while it was active.
- Kept first-responder loss tied to clearing transient media-pool preview.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Media Pool Alternating Row Styling

Summary:

- Replaced the system media `List` with a custom scroll view so media rows no longer use horizontal divider lines.
- Added DaVinci-style dark alternating row backgrounds across the media pool, including the empty scroll area behind rows.
- Preserved media selection, Command-click multi-select, select-all-visible, drag-to-timeline, context menu actions, and double-click source preview.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Timeline Empty State And Collapse Icon

Summary:

- Replaced the text `收缩` / `展开` timeline control with an icon-only collapse/expand button and tooltip.
- Changed the completely empty timeline to render as an empty work area without playhead, FIT layer, or fake track.
- Kept the default empty drop lane available once FIT or media context exists, while omitting the FIT layer when no FIT activity is loaded.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Collapse Mode Splice Styling And Drag Lock

Summary:

- Changed collapsed timeline clip rendering to use square internal edges and dark block borders, closer to DaVinci-style clip joins without full-height separator lines.
- Added dark borders to collapsed FIT segments as well, so FIT and video blocks share the same visual boundary language.
- Disabled horizontal dragging for existing video clips while the timeline is collapsed; clicking still selects clips.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Timeline Pinch Zoom And Accurate Clip Widths

Summary:

- Added macOS trackpad pinch zoom support on the AppKit timeline canvas.
- Removed the fixed minimum video clip block width so clip blocks reflect actual media duration at the current zoom level, including fit view.
- Hid clip titles when the block is too narrow to contain text.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Media Pool Source Preview

Summary:

- Added transient media-pool source preview: double-clicking a media row switches the preview to that video from the beginning without placing it on the timeline.
- Media-pool preview is cleared when the media browser loses focus or the user interacts with the preview/timeline, returning the preview to timeline playhead mode.
- Kept media-pool preview from driving timeline playback state or advancing the project playhead.
- Added a project-level test for media-pool preview selection and clearing when the media item is deleted.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`
- `docs/architecture.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Timeline Collapse Mode

Summary:

- Added a `收缩` / `展开` toggle next to the timeline zoom slider.
- Collapsed mode hides no-video gaps: a single layer displays clips back-to-back, while multiple layers display the union of video spans and hide FIT-only gaps.
- Playback in collapsed mode skips hidden empty regions and continues from the next visible video span.
- Timeline clip titles are clipped and middle-truncated inside their blue clip blocks.
- Added tests for collapsed single-layer mapping, multi-layer video-span union mapping, and playback gap skipping.

Files changed:

- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/architecture.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 40 tests passed.

### Export Text Supersampling

Summary:

- Added 2x offscreen supersampling for exported overlay text before compositing it into PNG and MOV frames.
- Applied the same path to plain text overlays and chart/timeline labels so large colored timer text has smoother alpha edges.
- Kept layout sizing, positions, shared render model values, and preview behavior unchanged.

Files changed:

- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 37 tests passed.

### Default Dark Editing Workspace

Summary:

- Set the macOS app default appearance to AppKit `darkAqua`.
- Set the SwiftUI root view preferred color scheme to dark.
- This makes system controls, lists, sheets, inspector, media browser, and timeline default to a dark editing workspace instead of a white/light theme.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 37 tests passed.

### Export Destination Defaults To First Video Folder

Summary:

- Changed the export dialog default destination from a fixed `~/Movies` path to the folder containing the first video in the media pool.
- Kept `~/Movies` as the fallback when no video files are loaded.
- Added tests for both default export destination cases.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 37 tests passed.

### Timeline Full-Height Playhead

Summary:

- Replaced per-track playhead markers with a single DaVinci-style full-height playhead overlay.
- Added a larger red ruler head and a vertical red line spanning the visible timeline canvas.
- Updated timeline documentation to describe the full-height playhead behavior.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/adr/0004-appkit-timeline.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 35 tests passed.

### Inspector Clip Timing Inputs

Summary:

- Replaced selected-clip Start and Offset sliders with second-based numeric inputs in the Inspector.
- Quantized Inspector start and offset edits to 0.01 seconds and displayed fields with two decimal places.
- Added double-click reset behavior on the Start and Offset labels, restoring each value to `0.00 s`.
- Removed the selected-clip Duration control from the Inspector until clip length adjustment is needed.
- Updated documentation for the current Inspector timing behavior.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/architecture.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 33 tests passed.

### Timeline Zoom Centers Playhead

Summary:

- Added zoom-change tracking to the SwiftUI/AppKit timeline bridge.
- Timeline zoom changes now recenter the scroll view on the current playhead.
- Playback still uses the existing keep-playhead-visible behavior.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 35 tests passed.

### Media Pool Explicit Matching And Tags

Summary:

- Changed video import so files enter the media pool without being automatically placed on timeline layers.
- Added `readyToMatch` media status for items with usable timestamps, reserving `aligned` for media that has actually been matched or manually placed.
- Added media-pool multi-selection, select-all-visible, right-click matching to the current layer or a new layer, right-click deletion, and right-click color tag assignment.
- Added media tag filtering in the media browser header while keeping tag assignment inside the context menu.
- Deleting media-pool items also removes timeline clips that reference those media IDs.
- Added tests for explicit matching, media tags, deletion, and undo restoration.

Files changed:

- `Sources/RunningOverlay/MediaImport/MediaItem.swift`
- `Sources/RunningOverlay/MediaImport/MediaMetadataReader.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`
- `docs/architecture.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 35 tests passed.

### Preview Canvas Overlay Position Stability

Summary:

- Changed `PreviewCanvasView` to compute the actual fitted project canvas inside the preview panel from the selected project resolution aspect ratio.
- Moved video preview, safety guides, and editable overlays into that fitted canvas instead of using the outer preview container as the coordinate space.
- Updated overlay drag delta conversion and SwiftUI preview render context to use fitted canvas dimensions, keeping normalized overlay positions stable when preview split panes are resized.
- Preview text, padding, shadows, distance timeline, and elevation chart dimensions now scale with the fitted preview canvas size.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/architecture.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 35 tests passed.

### Project Timeline And Movable FIT Axis

Summary:

- Refactored timeline placement to use project time instead of clamping all clips to FIT elapsed time.
- Added `TimelineModel.fitStartTime` so the FIT activity is a movable axis inside the project timeline.
- Preserved imported video timestamps before activity start and after activity finish, allowing race start/finish buffer footage.
- Added a dedicated draggable `FIT` layer above video layers in the AppKit timeline.
- Updated overlay sampling and export sampling to map project time back to FIT elapsed time through the FIT axis.
- Added tests for pre-start clips, movable FIT axis mapping, layer data sampling with FIT offset, the provided FIT file path, and GoPro-style filename timestamps.

Files changed:

- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `Tests/RunningOverlayTests/FitFileParserTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/architecture.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 33 tests passed.

### Shared Frame Renderer And Calibration PNG

Summary:

- Extracted overlay frame drawing from `OverlayVideoExporter` into `OverlayFrameRenderer`.
- Kept `OverlayVideoExporter` focused on MOV encoding, frame timing, pixel buffer allocation, and progress.
- Added `Export Test Frame` to render a calibration PNG through the same frame renderer used by calibration MOV export.
- Added a PNG render test that verifies the renderer writes a valid PNG file.

Files changed:

- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/architecture.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 29 tests passed.

## 2026-04-24

### Export Pixel Buffer Orientation Fix

Summary:

- Added a final vertical row flip after drawing each overlay frame into the export pixel buffer.
- This compensates for the current `CVPixelBuffer` to MOV orientation path, where a correctly drawn top-left overlay was encoded upside down in QuickTime.
- Normal exports and calibration exports use the same correction.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 28 tests passed.

### Preview Safety Guides And Calibration Export

Summary:

- Added a toolbar safety-frame toggle for preview alignment checks.
- Added 90%/80% preview safety frames and center crosshairs.
- Added a calibration test export from the export dialog that renders a short transparent MOV with fixed reference overlays and safety guides.
- Added optional guide rendering to the export renderer without affecting normal exports.
- Added synthetic calibration activity data so the test clip can be exported even before a FIT file is loaded.
- Added tests for calibration overlay layout and calibration activity data.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 28 tests passed.

### Shared Overlay Render Layout And Chart Export

Summary:

- Added a shared `OverlayRenderModel` for preview/export overlay value, geometry, font, padding, progress, and chart sample layout.
- Updated the SwiftUI preview to consume the shared overlay render layout for text, distance timeline, and elevation chart elements.
- Updated the export renderer to consume the same layout model and render distance timeline plus elevation chart elements instead of treating the chart as plain text.
- Moved export shape drawing to AppKit paths inside a flipped graphics context so text, backgrounds, progress bars, and chart paths use the same top-left coordinate system.
- Added render model tests covering text scaling, distance timeline progress/geometry, and elevation chart sample/progress layout.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/architecture.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 26 tests passed.

### Export Coordinate And Progress Popover Fixes

Summary:

- Removed the export renderer's global CGContext inversion and switched text drawing to a flipped `NSGraphicsContext`, fixing upside-down exported overlay text.
- Added a small export render scale calibration so exported text and controls better match the preview scale.
- Changed the export progress popover from hover-open to click-open so the cancel button remains reachable.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 23 tests passed.

### Export Renderer Text, Scale, Cache, And Codec Fixes

Summary:

- Fixed export text drawing by creating an explicit `NSGraphicsContext` for the bitmap `CGContext`.
- Scaled export text, padding, rounded corners, shadows, and distance timeline geometry from a 1280x720 reference to the selected output resolution.
- Switched frame allocation to `AVAssetWriterInputPixelBufferAdaptor`'s pixel buffer pool.
- Added attributed text layout caching to reduce repeated per-frame font/string work.
- Added a ProRes 4444 codec option alongside H.265 with alpha.
- Removed bitrate compression properties from ProRes 4444 output settings.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Project/ProjectSettings.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 23 tests passed.

### App Focus And Timeline Zoom Slider Granularity

Summary:

- Set the app activation policy to regular on launch so the SwiftPM-started macOS app can become the active keyboard target.
- Timeline mouse-down now activates the app, makes the window key, and makes the AppKit timeline canvas first responder.
- Changed the timeline zoom slider from direct pixels-per-second mapping to a nonlinear 0-100 scale with finer low-end control.
- Reduced Command zoom's first step from fit view to a much smaller pixels-per-second value.
- Added a regression test for low-end zoom slider mapping.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 23 tests passed.

### Timeline Drop Target Highlight And Export Cancellation

Summary:

- Added AppKit timeline key handling so Delete and Forward Delete remove selected clips even when the timeline canvas has focus.
- Added layer highlighting while dragging media onto the timeline.
- Added exactly one new layer drop target beyond existing layers during media drag.
- Added export cancellation from the toolbar progress popover.
- Added cancellation checks inside the export renderer and progress state coverage.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ExportProgressTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 22 tests passed.

### Timeline Layer Label And Export Progress UI

Summary:

- Changed the default empty timeline lane name from `Video` to `Layer 1`.
- Added clearer AppKit timeline separation between the left label column and central lane area.
- Added structured export progress state with overall and per-output item progress.
- Added a toolbar export progress control that shows a hover popover with detailed export progress rows.
- Added export progress tests.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ExportProgressTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 21 tests passed.

### Timeline Delete And Finder Media Drop

Summary:

- Added Delete and Forward Delete handling for selected timeline clips and selected overlay elements.
- Added timeline clip deletion to the timeline model and routed selected deletion through `ProjectDocument` so it is undoable.
- Added Finder file drop support to the media browser for appending supported video files.
- Shared video URL import logic between toolbar import and media browser drop import.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 19 tests passed.

### Slider Tick Mark Cleanup

Summary:

- Removed SwiftUI Slider `step` parameters from timeline zoom, bitrate, clip, and overlay controls to hide macOS tick marks.
- Preserved existing value increments by quantizing values in bindings instead of relying on stepped Slider rendering.

Files changed:

- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 17 tests passed.

### Sequential Feature Pass: Templates, Preview Tracks, Overlay Editing, Export, Timeline Basics

Summary:

- Added standalone `.rotemplate` import/export for overlay templates.
- Moved overlay template management into Project Settings because it is a low-frequency workflow.
- Added preview track selection and per-track preview disable toggles so lower/other tracks can be inspected without affecting export.
- Added overlay X/Y numeric position entry, shadow controls, and arrow-key nudging.
- Added first-pass transparent MOV overlay export using H.265 with alpha.
- Added full FIT activity overlay export that ignores timeline video clips and renders from activity start to finish.
- Added selected clip Inspector controls for camera/track rename, start time, and duration.
- Updated timeline visible-clip selection to use right-open clip ends and support disabled preview tracks.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayTemplate.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Project/ProjectSettings.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 17 tests passed.

### Overlay Template Local Library

Summary:

- Added a versioned Codable overlay template schema.
- Added local JSON persistence for overlay templates under Application Support.
- Added ProjectDocument actions to save, apply, and delete templates.
- Applying a template replaces the current overlay layout and is undoable.
- Added an Overlay Templates section to the Project Settings sheet.
- Added template persistence and undo tests.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayTemplate.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Tests/RunningOverlayTests/OverlayTemplateTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 15 tests passed.

### AVPlayer-Driven Playback Sync

Summary:

- Changed video playback synchronization so `AVPlayer` drives project playhead while the playhead is inside a video clip.
- Added a periodic player time observer that reports activity time back to `ProjectDocument`.
- Kept timer-based playback advancement only for timeline gaps with no visible preview clip.
- Added drift correction for large manual seeks during playback without reintroducing per-frame seeking.
- Added tests for playback time updates and activity-end clamping.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/VideoPreviewPlayerView.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 13 tests passed.

### Layer Data FPS Project Setting

Summary:

- Added a project-level Layer Data FPS setting with 1, 5, 10, 15, and 30 fps presets.
- Quantized FIT-derived overlay sample time through `ProjectDocument` so preview and Inspector values update at the configured cadence.
- Added the setting to the project settings sheet and export dialog.
- Documented that future export rendering must use the same data sampling cadence as preview.

Files changed:

- `Sources/RunningOverlay/Project/ProjectSettings.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 11 tests passed.

### Video Seek And FIT Sampling Fixes

Summary:

- Fixed FIT record elapsed times by normalizing records after parsing with the final activity start date.
- This allows heart rate and other overlay values to sample changing records as playhead moves.
- Reduced video preview jumping by avoiding repeated `AVPlayer` seeks during normal playback.
- Added FIT parser regression assertions that the provided sample has nonzero elapsed record time and varying heart rate values.

Files changed:

- `Sources/RunningOverlay/FitData/FitFileParser.swift`
- `Sources/RunningOverlay/UI/VideoPreviewPlayerView.swift`
- `Tests/RunningOverlayTests/FitFileParserTests.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 9 tests passed.

### Split Divider Cursor Hit Area

Summary:

- Expanded resize cursor hit areas around the main split dividers.
- Added cursor coverage on both sides of the horizontal divider between the upper editor area and timeline.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Playback And Timeline Interaction Fixes

Summary:

- Made playhead and zoom updates assign updated `TimelineModel` values so SwiftUI/AppKit refreshes are reliable.
- Added a Playback command with Space shortcut so play/pause works even when focus is outside the main editor key handler.
- Changed video preview playback so `AVPlayer` is not repeatedly seeked on every playhead tick, reducing playback stutter.
- Added a timeline zoom slider above the AppKit timeline canvas.
- Kept Command + Plus, Command + Minus, and Command-scroll timeline zoom support.
- Added resize cursor hints to major split-view boundaries without intercepting drag events.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/SplitCursorRegion.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Sources/RunningOverlay/UI/VideoPreviewPlayerView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 9 tests passed.

### Overlay Template Requirements

Summary:

- Defined overlay templates as a separate feature from full project files.
- Clarified that templates save reusable overlay layout and style only.
- Excluded FIT data, video paths, timeline clips, playhead, and sampled values from template contents.
- Added initial template UI requirements and implementation phases.

Files changed:

- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/adr/0005-overlay-templates-before-project-files.md`

Verification:

- Documentation-only change.

### Inspector Overlay List And Undo Redo Foundation

Summary:

- Added an Inspector list of already-added overlay elements when no element is selected.
- Clicking an overlay in the list selects the same element as preview selection.
- Added delete controls for overlay elements in the Inspector list.
- Added a project-level snapshot undo/redo stack to `ProjectDocument`.
- Wired `Command-Z` and `Shift-Command-Z` to project undo and redo.
- Routed core timeline and overlay mutations through undo registration.
- Optimized AppKit timeline clip dragging so movement is previewed locally and committed once on mouse-up.
- Added undo/redo tests for overlay add and delete.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 9 tests passed.

### FIT Timeline Refresh And Playback Follow

Summary:

- Fixed AppKit timeline refresh after FIT import by passing activity, timeline, media presence, and selection as explicit values through `NSViewRepresentable`.
- FIT-only projects now show the full activity ruler and an empty video lane before video import.
- Replaced direct timeline zoom mutation from commands and AppKit scroll handling with `ProjectDocument` methods.
- Added horizontal playback follow so the timeline scrolls to keep the playhead visible during playback.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 7 tests passed.

### Real Video Preview And AppKit Timeline

Summary:

- Added AVPlayerLayer-backed source video preview behind the overlay canvas.
- Preview now displays the first timeline clip containing the current playhead.
- Added timeline model lookup for the visible clip at a playhead time.
- Replaced the SwiftUI-rendered timeline with an AppKit self-drawing timeline embedded through `NSViewRepresentable`.
- AppKit timeline now draws ruler, hover data, tracks, clips, playhead, and handles clip selection, clip dragging, ruler seeking, media drops, and Command-scroll zoom.
- Added a timeline model test for visible clip lookup.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Sources/RunningOverlay/UI/VideoPreviewPlayerView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/adr/0004-appkit-timeline.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 7 tests passed.

### Empty Project State And Panel Background Fix

Summary:

- Removed startup sample media, sample timeline clips, sample overlay elements, and fake activity duration.
- Removed mock data helper entry points so startup state cannot accidentally repopulate sample content.
- Timeline now hides fake tracks when no media has been imported.
- Timeline ruler hides labels and hover data until a real FIT activity is loaded.
- Media and Inspector panels now use normal window backgrounds instead of the gray under-page background.
- Removed remaining visible export placeholder wording.

Files changed:

- `Sources/RunningOverlay/FitData/ActivityTimeline.swift`
- `Sources/RunningOverlay/MediaImport/MediaItem.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- Confirmed there are no remaining source/test references to startup placeholder/mock data.

### Overlay Visual Styling And Chart Rendering

Summary:

- Expanded overlay styles with font family, font weight, foreground color, and background opacity.
- Added Inspector controls for font family, font weight, color presets, and background opacity.
- Rendered distance timeline overlays as progress bars.
- Rendered live elevation chart overlays as compact line charts with playhead markers.
- Kept overlay style values in serializable model-friendly RGBA/value types.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 6 tests passed.

### First-Pass Overlay Editing And Live Data Binding

Summary:

- Added activity data interpolation for overlay values.
- Added `OverlayValueFormatter` for heart rate, pace, calories, elapsed time, real time, distance, elevation, cadence, and power.
- Connected preview overlay text to current playhead data instead of static placeholders.
- Added drag positioning for overlay elements in the preview.
- Added selected overlay scale and font size controls in the Inspector.
- Added playback-driven playhead advancement.
- Added timeline ruler seeking and a red playhead indicator.
- Added overlay value formatter tests.

Files changed:

- `Sources/RunningOverlay/FitData/ActivityTimeline.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/OverlayValueFormatterTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 6 tests passed.

### Direct Timeline Clip Movement

Summary:

- Added horizontal drag movement for existing timeline clips.
- Dragging a clip updates its effective timeline start while preserving its alignment offset.
- Added a timeline model test for direct clip movement.
- Marked first-pass timeline editing complete in the roadmap.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 4 tests passed.

### Manual Timeline Placement And Clip Offset Editing

Summary:

- Added drag support from the media browser to timeline tracks.
- Added a default empty timeline track when no imported videos auto-align.
- Dropping media on a timeline track now creates or moves a timeline clip at the drop time.
- Added selected clip offset editing in the Inspector.
- Added the apply-to-camera action for copying the selected offset to clips from the same camera/source group.
- Added timeline model tests for manual placement and camera-wide offset application.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 3 tests passed.

### FIT Import Diagnostics And Developer Field Handling

Summary:

- Fixed FIT parsing for files that include developer field definitions by reading and skipping developer data fields.
- Added FIT import success and failure logs to stdout for `swift run RunningOverlay`.
- Added a parser regression test using the provided FIT sample path when available.

Files changed:

- `Package.swift`
- `Sources/RunningOverlay/FitData/FitFileParser.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Tests/RunningOverlayTests/FitFileParserTests.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- The provided FIT sample parsed successfully in the regression test.

### Video Import And First-Pass Alignment

Summary:

- Added native multi-select video import.
- Added AVFoundation metadata reading for video duration and creation date.
- Added filename timestamp parsing for common camera/phone naming patterns.
- Replaced placeholder video import from toolbar and command menu with real import.
- Rebuilt timeline tracks from auto-aligned imported videos.
- Updated media browser to show inferred timestamps.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/MediaImport/MediaItem.swift`
- `Sources/RunningOverlay/MediaImport/MediaMetadataReader.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Layout Adjustment And FIT Import Start

Summary:

- Adjusted the main editor layout so the timeline spans the full window width.
- Made media browser, preview, inspector, and timeline regions resizable through split-view boundaries.
- Added a native FIT file picker.
- Added a first-pass FIT parser for standard record/session messages.
- Added timeline ruler hover values for elapsed time, real-world time, and distance.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/FitData/ActivityTimeline.swift`
- `Sources/RunningOverlay/FitData/FitFileParser.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/adr/0003-focused-fit-parser.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Native App Skeleton

Summary:

- Created a Swift Package based native macOS SwiftUI app target named `RunningOverlay`.
- Added the first editor layout with media browser, preview, inspector, timeline, status bar, project settings sheet, and export sheet.
- Added placeholder project, activity, media, timeline, and overlay models so later feature work has stable module boundaries.
- Wired basic commands for FIT import placeholder, video import placeholder, playback toggle, and timeline zoom.

Files changed:

- `Package.swift`
- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Project/ProjectSettings.swift`
- `Sources/RunningOverlay/FitData/ActivityTimeline.swift`
- `Sources/RunningOverlay/MediaImport/MediaItem.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/adr/0002-swift-package-bootstrap.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Distance Timeline Refinement

Summary:

- Split Distance Timeline controls into Value, Label, Axis Labels, and Stats Bar sections.
- Added metric/imperial Value units, Value disable mode, four custom Value slots, axis label/distance-point controls, and a Route Map-style Stats Bar.
- Removed the standalone Distance Timeline Typography section; Value now owns the value font, size, weight, and color controls.
- Added a Custom Values master toggle; when enabled, Custom 1-4 metric-picker rows appear and render inline after the main Value with adjustable group gap, item gap, size, color, and opacity.
- Fixed Custom Values inline layout so increasing Group Gap moves the whole custom group without truncating custom values or reducing Item Gap.
- Updated Axis Labels so start/end endpoint text uses Point Gap like intermediate distance points.
- Kept Point Gap editable when More Points is disabled because endpoint labels also depend on it.
- Added Stats Bar width, item gap, and X/Y offset controls, and adjusted inside/attached placement so the bar sits at component edges without covering the progress axis.
- Split Distance Timeline Stats Bar placement into top/bottom/left/right plus a separate Inside toggle, including inside-left and inside-right rendering.
- Expanded Distance Timeline background/border bounds to cover Axis Labels and inside Stats Bar placements at their current size and offset.
- Added Tick Density control and updated tick rendering to use the configured density.
- Fixed left/right Stats Bar background sizing so vertical slots and labels are fully covered.
- Updated Distance Timeline preview selection bounds to cover the dynamic visual bounds, including Axis Labels and Stats Bar.
- Removed inline Percent handling from the Distance Timeline content flow; progress percentage now lives in Stats Bar slots.
- Changed Dense and Splits progress from segmented/dashed fills to solid progress fills.
- Disabled the fake Glass background until a real blur/material effect is available.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/UI/DistanceTimelineOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.md`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.spec.json`
- `docs/overlay-modules/distance-timeline-overlay.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Documentation Bootstrap

Summary:

- Created initial documentation structure for the Running Overlay macOS app.
- Captured the first-pass product requirements from the initial brief.
- Added engineering guidance, proposed module boundaries, architecture notes, roadmap, and decision records.

Files changed:

- `README.md`
- `docs/requirements.md`
- `docs/development.md`
- `docs/architecture.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/adr/0001-documentation-first-development.md`

Verification:

- Confirmed the project directory was empty before creating documentation.
- No code or build verification yet because no app project exists.

### Decor Category — Phases C through G (2026-04-30)

Plan reference: `~/.claude/plans/overlay-pool-solid-color-layout-bg-effe-shiny-pudding.md`.

**Phase C — Icon subsystem**

- `IconAsset` enum (sfSymbol / userStaticSVG / userLottie / bundledSVG) with hand-rolled Codable.
- `IconRendering` dual-path API: `IconView` (SwiftUI) and `IconRenderer.draw` (Core Graphics).
- SF Symbol and bundled SVG rendering with tint, preserveSVGColors, content mode.
- SVG smoke test gate passed (three fixtures rasterize via NSImage + CGContext).
- Lottie dependency (`lottie-ios` 4.5.0) added; LottieView path works; offscreen CG path is a documented limitation.

**Phase D — Decor Icon UI**

- `DecorIconRenderLayout` / `decorIconLayout` on OverlayRenderModel.
- `DecorIconOverlayView` / `OverlaySharedDecorIconView` in DecorOverlayViews.swift.
- Preview canvas and SwiftUI export switch arms wired.
- Full icon inspector: source picker (SF Symbol / Bundled SVG / Upload), symbol search + common grid, weight/scale pickers, tint swatch, content mode, preserveSVGColors toggle, Layout / Background / Effects sections.

**Phase E — User asset store**

- `UserAsset` model + `UserAssetStore` (content-addressed .assets/ folder).
- `ProjectDocument.userAssets` with undo support.
- `IconAssetResolver` wired to resolve user assets from the project.
- Import action via NSOpenPanel for SVG files.
- `OverlayTemplate` schemaVersion bumped to 2; optional `assets` field with custom Codable for backward compat.

**Phase F — Decor Text**

- `DecorFontRef`, `DecorTextFill`, `GradientSpec`, `DecorTextAlignment` types.
- `DecorTextResolved` coalescing nil optionals.
- `DecorTextRenderLayout` / `decorTextLayout` on OverlayRenderModel.
- `DecorTextOverlayView` / `OverlaySharedDecorTextView` with stroke, shadow, glow.
- Full text inspector: content editor, font picker (system/bundled), alignment, line height, letter spacing, auto-fit, fill color, stroke width/color, Layout / Background / Effects.
- Default presets seeded for all three decor types.

**Phase G — Polish**

- All three decor element types render end-to-end: Pool → Canvas → Inspector → Export.
- Default styles on add: Solid Color (240×80 white rounded rect), Icon (SF star.fill, 80×80, white tint), Text ("Hello", SF Pro, 320×60, centered).

Verification:
- `swift build` clean.
- `swift test` — all 75 tests pass.

### Numeric Preset Label/Accent Decoupling (2026-04-30)

Summary:

- Updated `splitLabel`, `racingStripe`, and `editorial` so label text color follows `labelColor`/`labelOpacity`.
- Kept accent visuals style-specific: split divider, racing stripe bar, and editorial underline still use `accentColor`.
- Synced preview and export renderers so canvas output and exported frames match.
- Updated preset apply behavior so these three presets default `labelColor` to the preset accent color for backward visual parity.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/project-log.md`
