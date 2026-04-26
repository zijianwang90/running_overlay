# Running Overlay Project Log

## 2026-04-26

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
