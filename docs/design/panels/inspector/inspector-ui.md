# Inspector UI Design Spec

Last updated: 2026-04-26

## Purpose

The Inspector is the right-side editing panel for overlay work in Running Overlay. It has two primary overlay states:

1. **Inspector Outer**: no overlay detail is open. The user can add new overlays and manage existing overlays.
2. **Overlay Detail**: an existing overlay has been opened from the Inspector list or selected from the Preview. The user edits that overlay's content, position, size, style, and animation.

This spec is intended for implementation agents. Treat it as the source of truth for visual direction and interaction behavior for the Inspector refresh.

## Design References

Inspector outer mockup

Overlay detail mockup

Numeric metric overlays use the denser reusable template in [Numeric Overlay UI](../../overlays/numeric/numeric-overlay-ui.md).

## App-Level Direction

The app should feel like a focused desktop video editing tool for athletes and creators: dark, precise, dense, and readable. Avoid marketing-page composition, decorative backgrounds, oversized hero treatments, and large empty black areas.

Use a consistent dark tool-panel language across the app:

- Backgrounds are near-black and charcoal, with subtle elevation through borders and opacity rather than heavy shadows.
- Accent color is a clear blue used for primary actions, selected controls, active tabs, and focus rings.
- Controls should be compact, predictable, and aligned to an 8 px spacing system.
- Corner radius should be restrained. Use 6-8 px for tiles, rows, inputs, and segmented controls.
- Text hierarchy should be clear but not oversized. Inspector UI is a tool surface, not content marketing.

## Design Tokens

Use these values as implementation defaults. SwiftUI can adapt names, but visual output should stay close.

### Color


| Token                       | Hex       | Usage                                   |
| --------------------------- | --------- | --------------------------------------- |
| `app.background`            | `#0B0F12` | Main app/editor background              |
| `panel.background`          | `#15191D` | Inspector panel base                    |
| `panel.backgroundElevated`  | `#1B2025` | Section surfaces, sticky footer         |
| `control.background`        | `#20252A` | Buttons, rows, fields                   |
| `control.backgroundHover`   | `#272D33` | Hovered controls                        |
| `control.backgroundPressed` | `#11161A` | Pressed controls                        |
| `border.subtle`             | `#2B3238` | Dividers and card borders               |
| `border.strong`             | `#3A424A` | Active containers and focusable regions |
| `text.primary`              | `#F3F6F8` | Main text                               |
| `text.secondary`            | `#B6BEC7` | Row subtitles and values                |
| `text.muted`                | `#7E8893` | Hints, disabled labels                  |
| `accent.blue`               | `#2F8CFF` | Primary actions and selected state      |
| `accent.blueSoft`           | `#123052` | Active tab/tile background              |
| `danger.red`                | `#FF5A5F` | Delete/destructive actions              |
| `success.green`             | `#69D26F` | Enabled/status accents                  |
| `warning.yellow`            | `#FFD166` | Warning/value accent when needed        |


### Typography

Use the system font stack, with SF Pro on macOS.


| Role           | Size | Weight                    | Usage                           |
| -------------- | ---- | ------------------------- | ------------------------------- |
| `title`        | 22   | Semibold                  | Inspector header title          |
| `sectionTitle` | 15   | Semibold                  | Section labels                  |
| `body`         | 13   | Regular                   | Control labels, row text        |
| `bodyStrong`   | 13   | Semibold                  | Tile labels and selected values |
| `caption`      | 11   | Regular                   | Hints, subtitles, metadata      |
| `numeric`      | 13   | Medium, monospaced digits | Metric preview values           |


### Spacing And Size


| Token             | Value |
| ----------------- | ----- |
| `space.1`         | 4     |
| `space.2`         | 8     |
| `space.3`         | 12    |
| `space.4`         | 16    |
| `space.5`         | 20    |
| `space.6`         | 24    |
| `panel.paddingX`  | 18    |
| `panel.paddingY`  | 16    |
| `section.gap`     | 22    |
| `control.height`  | 34    |
| `row.height`      | 52    |
| `iconButton.size` | 30    |
| `tile.minHeight`  | 68    |
| `radius.control`  | 7     |
| `radius.panel`    | 8     |
| `border.width`    | 1     |


## State 1: Inspector Outer

The outer Inspector appears when no overlay detail is open. It replaces the current `OverlayLibraryView` content.

### Responsibilities

- Add overlays to the preview.
- Display overlays already added to the project.
- Allow each added overlay row to open its detail editor.
- Provide quick row actions for visibility, lock, and delete.

### Explicit Non-Goals

- Do not show a `Properties` section.
- Do not show an empty property state.
- Do not include sorting, drag handles, or reorder affordances in `Added Elements`.

### Layout

Top to bottom:

1. Header
2. `Add Overlay` section
3. `Added Elements` section
4. Optional footer hint

Inspector default width is 400 px with a 320 px minimum, and the panel is user-resizable by dragging its leading split divider. The Inspector must keep its current width across every internal state change — outer state, overlay detail, timeline clip selection, and any future state. The horizontal layout uses a custom `HStack` + `HorizontalResizeHandle` (not SwiftUI `HSplitView`) so widths are stored in `@State` and cannot be reset by child intrinsic-size or identity changes. The design mockup is square only for reference output; implementation should use a right-panel layout.

### Header

Content:

- Left: `Inspector`
- Right: status pill such as `2 overlays`
- Right trailing icon button: filter/settings

Behavior:

- The pill count updates from `project.overlayLayout.elements.count`.
- Settings/filter may be non-functional initially, but reserve the slot for future overlay filtering.

### Add Overlay Section

Section title: `Add Overlay`

Subtitle: `Choose a data layer to place on the preview`

Tabs:

- `Metrics`
- `Charts`
- `Route`

Default active tab: `Metrics`

The current code has one flat list from `OverlayElementType.allCases`. The refreshed UI can keep a single list initially while rendering the tabs as visual filters. If filtering is implemented:

- `Metrics`: Heart Rate, Pace, Calories, Elapsed Time, Real Time, Distance, Elevation, Cadence, Power
- `Charts`: Distance Timeline, Elevation Chart, Running Gauge
- `Route`: Route Map

Tile content:

- Leading icon
- Label
- Short hint
- Add affordance icon, usually `plus`

Tile list:


| Overlay           | Hint         | Suggested icon |
| ----------------- | ------------ | -------------- |
| Heart Rate        | `bpm`        | `heart-pulse`  |
| Pace              | `min/km`     | `timer`        |
| Calories          | `kcal`       | `flame`        |
| Elapsed Time      | `duration`   | `clock`        |
| Real Time         | `clock time` | `watch`        |
| Distance          | `km / mi`    | `route`        |
| Distance Timeline | `progress`   | `activity`     |
| Elevation         | `altitude`   | `mountain`     |
| Elevation Chart   | `profile`    | `area-chart`   |
| Cadence           | `spm`        | `footprints`   |
| Power             | `watts`      | `zap`          |
| Running Gauge     | `live gauge` | `gauge`        |
| Route Map         | `GPS path`   | `map`          |


Tile behavior:

- Click adds an overlay through the existing add action.
- Newly added overlay can remain unselected or open detail immediately. Preferred behavior: add then open detail, because the Inspector detail screen is the natural next step after adding.
- `Running Gauge` and `Route Map` may use subtle blue accent treatment to show they are richer overlay types, but no tile is selected in the outer state.

### Added Elements Section

Section title: `Added Elements`

Rows shown in mockup:

- `Running Gauge`, subtitle `Distance • Gauge`, value `10.73 km`
- `Pace`, subtitle `Pace • Text`, value `5'10"/km`

Row content:

- Leading overlay type icon.
- Primary name.
- Secondary subtitle.
- Right-side live value preview.
- Visibility icon button.
- Lock icon button.
- Delete icon button.
- Chevron indicating the row opens detail.

Row behavior:

- Clicking the row body opens the Overlay Detail screen for that element.
- Clicking the same overlay in Preview must open the same detail screen.
- Delete button removes the overlay and does not open detail.
- Visibility and lock should be separate hit targets. If the project model does not support these yet, render disabled or omit until model support exists.
- No sorting behavior. Do not include drag handles.

Empty state:

- If no overlays exist, show a compact row-like empty state: `No overlays added yet`.
- Keep the `Add Overlay` grid prominent.

## State 2: Overlay Detail

The detail screen appears when `project.selection == .overlayElement(elementID)` or when the user opens an overlay row. It replaces the current `OverlayElementInspectorView` presentation.

### Responsibilities

- Identify the selected overlay.
- Provide direct editing controls for that overlay.
- Provide a return path to the outer Inspector.
- Expose delete and done actions.
- Use [Numeric Overlay UI](../../overlays/numeric/numeric-overlay-ui.md) for single-value numeric metric overlays instead of building one-off Pace, Heart Rate, Distance, Power, Cadence, Calories, Elevation, Elapsed Time, or Real Time panels.

### Layout

Top to bottom:

1. Detail header
2. `Content` section
3. `Position & Size` section
4. `Style` section
5. `Animation` section
6. Sticky action footer

### Detail Header

For `Running Gauge`:

- Back icon button
- Title: `Running Gauge`
- Pill: `Overlay` or `Data Overlay`
- Value preview: `10.73 km`
- Trash icon button

Behavior:

- Back returns to the outer Inspector and clears overlay detail focus if needed.
- Trash deletes the overlay and returns to the outer Inspector.
- The header value should use the same formatter as the Preview and Added Elements row.

### Content Section

For a metric/gauge overlay, include:

- `Metric` dropdown, set to `Distance` for the Running Gauge example.
- Format preview row, e.g. `10.73 km`.
- `Show Label` toggle.
- `Show Unit` toggle.
- `Label` text field, e.g. `Distance`.

Implementation note:

- The current model binds overlay type directly to a metric. If metric reassignment is not supported yet, render `Metric` as read-only or skip it for v1.
- Do not add unsupported persistence fields without a model migration plan.
- Numeric metric overlays should follow [Numeric Overlay UI](../../overlays/numeric/numeric-overlay-ui.md), including unit selection where relevant and the denser two-column control layout.

### Position & Size Section

Controls:

- 3x3 anchor grid.
- Numeric `X` and `Y` fields using normalized coordinates.
- `Scale` or `Width`/`Height` control.
- `Opacity` slider, default visual example around `85%`.

Implementation mapping:

- Existing model supports `position.x`, `position.y`, and `scale`.
- Existing model does not yet expose opacity as a separate overlay property. If not implemented, omit or map carefully through style/background only when product behavior is clear.

Anchor grid:

- Each cell is 24-28 px.
- Selected anchor uses `accent.blue`.
- If not implemented, show the grid only when it maps to real position presets.

### Style Section

Controls:

- Segmented style mode: `Minimal`, `Gauge`, `Pill`, `Large`
- Color swatches: text, accent, background
- Font weight segmented control
- Corner radius slider

Implementation mapping:

- Text overlays map to `OverlayTextPreset`: Minimal, Pill Badge, Metric Card, Big Number, Sport Watch, Split Label.
- Running Gauge maps to `OverlayGaugePreset`: Minimal Sport, High Contrast, Trail Adventure, Tech Future, Retro Digital.
- Route Map maps to `OverlayRouteMapPreset`: Minimal, Gradient, Glow, MapKit.
- Existing style supports font name, font size, font weight, foreground color, background opacity, shadow opacity, and shadow radius.

For v1, use existing model-backed controls first:

- Preset picker or segmented control.
- Font family picker.
- Font size slider.
- Font weight segmented control.
- Foreground color swatches.
- Background opacity slider.
- Shadow opacity slider.
- Shadow radius slider.

### Animation Section

Controls shown in design:

- `Enable Animation` toggle, on.
- `Entrance` dropdown, set to `Fade Up`.
- `Duration`, set to `0.4s`.

Implementation note:

- If animation is not model-backed, this section should be hidden in the first implementation or rendered disabled under a feature flag. Do not create UI that appears to save animation if the project file cannot persist it.

### Sticky Footer

Buttons:

- Secondary `Reset`
- Primary `Done`

Behavior:

- `Done` returns to the outer Inspector and keeps the overlay selected on Preview if that selection is needed for canvas handles.
- `Reset` resets only style/layout values for the current overlay. If reset behavior is not implemented yet, omit the button.

## Interaction Rules

- Clicking an overlay row and clicking an overlay in Preview must route to the same detail state.
- Add overlay tiles should be keyboard-focusable.
- Row action buttons must not trigger row navigation.
- Destructive actions should use `danger.red` on hover or confirmation affordance, not constant bright red unless active.
- Sliders should call continuous update while dragging and finish undo grouping at drag end, matching current `finishContinuousEdit()` behavior.
- Numeric fields should commit on submit and preserve normalized coordinate precision.
- The panel should scroll when content exceeds height; header and optional footer may stay fixed.

## SwiftUI Implementation Guidance

The current entry points are:

- `ParameterPanelView`
- `OverlayLibraryView`
- `OverlayElementListView`
- `OverlayElementInspectorView`

Recommended refactor:

- Add `InspectorTheme` for tokenized colors, spacing, radii, and typography.
- Replace `OverlayLibraryView` with an `InspectorOuterView`.
- Replace or restyle `OverlayElementInspectorView` with `OverlayDetailView`.
- Add small reusable controls:
  - `InspectorSection`
  - `InspectorHeader`
  - `InspectorSegmentedControl`
  - `OverlayAddTile`
  - `OverlayElementRow`
  - `InspectorIconButton`
  - `InspectorSliderRow`
  - `InspectorValueField`
  - `ColorSwatchButton`

Keep component APIs model-oriented. Avoid view-only state that diverges from `ProjectDocument`.

## Accessibility

- Minimum text contrast should pass WCAG AA on dark backgrounds.
- Icon-only buttons need `.help(...)` and accessibility labels.
- Hit targets should be at least 28x28 px for dense controls and preferably 30x30 px.
- Selected/focused states should not rely on color alone; use border or checkmark indicators for swatches and selected cells.

## Open Product Questions

- Should adding an overlay immediately open detail? Preferred: yes.
- Should overlay visibility and lock be persisted in `OverlayElement`? Current model does not show those fields.
- Should opacity be a general overlay property or only part of style background/shadow?
- Should animation be in the project schema for v1, or deferred?