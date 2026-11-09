# Inspector UI Design Spec

Last updated: 2026-10-26

## Purpose

The Inspector is the right-side editing panel for overlay work in Running Overlay Studio. It has two primary overlay states:

1. **Inspector Outer**: no overlay detail is open. The user manages existing overlays.
2. **Overlay Detail**: an existing overlay has been opened from the Inspector list or selected from the Preview. The user edits that overlay's content, position, size, style, and animation.

Add-overlay selection now lives in the left `Overlay Pool`; the Inspector should not duplicate the overlay catalog.
Overlay Pool add tiles use a consistent compact card treatment; featured tiles may use a stronger border, but they should not draw a left-side blue accent strip.

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
| `sectionTitle` | 12   | Semibold                  | Detail section headers          |
| `body`         | 13   | Regular                   | Control labels, row text        |
| `bodyStrong`   | 13   | Semibold                  | Tile labels and selected values |
| `caption`      | 11   | Regular                   | Hints, subtitles, metadata      |
| `numeric`      | 12   | Regular, monospaced digits | Values in detail rows and list |
| `valueField`   | 11   | Regular, monospaced digits | Editable slider value fields   |

Detail panels use the dense `NumericTokens` metrics: 28 pt rows and section
headers, 22 pt controls (`.controlSize(.small)`), a 104 pt label column, 24 pt
icon buttons, 18 pt swatches, and a 46 pt slider value field.


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


See [Inspector HIG Review](inspector-hig-review.md) for the macOS HIG
rationale behind the controls described here.

## State 1: Inspector Outer

The outer Inspector appears when no overlay detail is open. It replaces the current `OverlayLibraryView` content.

### Responsibilities

- Display overlays already added to the project.
- Allow each added overlay row to open its detail editor.
- Provide quick row actions for visibility and lock; delete lives in the
  context menu and the detail header's action menu.

### Explicit Non-Goals

- Do not show a `Properties` section.
- Do not show an empty property state.
- Do not include sorting, drag handles, or reorder affordances in `Added Overlays`.
- Do not show the add-overlay catalog, category tabs, or overlay add tiles. Those belong to `Overlay Pool`.

### Layout

Top to bottom:

1. Header
2. `Added Overlays` list

Inspector default width is 460 px with a 460 px minimum, and the panel is user-resizable by dragging its leading split divider. The Inspector must keep its current width across every internal state change — outer state, overlay detail, timeline clip selection, and any future state. The horizontal layout uses a custom `HStack` + `HorizontalResizeHandle` (not SwiftUI `HSplitView`) so widths are stored in `@State` and cannot be reset by child intrinsic-size or identity changes. The app window minimum width must be large enough to contain the left pool minimum, preview minimum, Inspector minimum, and split handles without compressing the Inspector below its stored width. The design mockup is square only for reference output; implementation should use a right-panel layout.

### Header

Content:

- Left: `Inspector`
- Right: status pill such as `2 overlays`

Behavior:

- The pill count updates from `project.overlayLayout.elements.count`.
- Do not add a permanently disabled placeholder button; add a filter control
  only when filtering is implemented.

### Added Overlays List

`AddedOverlaysList` is a native `List(selection:)` with an inset style, a
`Section("Added Overlays")`, and 28 pt minimum row height, so selection
highlight, keyboard navigation, and context menus follow the system list.

Example rows:

- `Running Gauge`, value `10.73 km`
- `Pace`, value `5'10"/km`

Row content:

- Leading overlay type icon.
- Primary name.
- Right-side live value preview.
- Visibility and lock icon buttons, shown on hover or while the overlay is
  hidden or locked so the non-default state stays visible. Hidden rows are
  drawn at reduced opacity.

Icon color:

- Added Overlays row icons and Overlay Detail header icons use `text.primary`.
- Do not tint individual overlay type icons blue; reserve `accent.blue` for primary actions, selected controls, and focus/selection affordances.

Row behavior:

- Clicking the row body opens the Overlay Detail screen for that element.
- Clicking the same overlay in Preview must open the same detail screen.
- Visibility and lock are separate hit targets with immediate model updates.
- Visibility off hides the overlay from both Preview and export output.
- Lock on prevents canvas selection and drag edits from Preview; list actions (unlock/delete/open detail) remain available.
- Right-clicking an Added Overlays row opens the shared overlay context menu: `Duplicate`, `Copy Properties`, `Paste Properties`, `Hide`/`Show`, `Lock`/`Unlock`, and `Delete`, grouped by dividers.
- Paste applies the copied overlay configuration to the target row only when both overlays are in the same paste category (numeric overlays can paste to numeric overlays only).
- No sorting behavior. Do not include drag handles.

Empty state:

- If no overlays exist, show a centered `No Overlays` title with a one-line hint pointing to the Overlay Pool.
- The empty state stays compact. It should not include a duplicate add-overlay grid; users add overlays from the left `Overlay Pool`.

## State 2: Overlay Detail

The detail screen appears when `project.selection == .overlayElement(elementID)` or when the user opens an overlay row. It replaces the current `OverlayElementInspectorView` presentation.

### Responsibilities

- Identify the selected overlay.
- Provide direct editing controls for that overlay.
- Follow the selection: the detail shows whatever overlay is selected, and
  clearing the selection (Esc, clicking empty canvas) returns to the outer
  Inspector. There is no Back or Done button.
- Switch directly to another overlay without returning to the outer Inspector.
- Expose Reset Style and destructive delete from the header's action menu.
- Use [Numeric Overlay UI](../../overlays/numeric/numeric-overlay-ui.md) for single-value numeric metric overlays instead of building one-off Pace, Heart Rate, Distance, Power, Cadence, Calories, Elevation, Elapsed Time, or Real Time panels.

### Detail Header

Every overlay detail view sits below one shared `OverlayDetailHeader`
rendered by `ParameterPanelView`. Individual detail views must not draw their
own header or footer. The header contains:

- a pop-up `Picker` showing the current overlay; the menu lists every overlay
  in list order, with locked overlays disabled;
- an `<n> of <count>` caption (`OverlaySwitcherTitle.position`);
- Previous / Next icon buttons that cycle through unlocked overlays in list
  order, wrapping around;
- an `ellipsis.circle` action menu with `Reset Style`, a divider, and the
  shared overlay context-menu items (Duplicate, Copy/Paste Properties,
  Hide/Show, Lock/Unlock, Delete).

Behavior:

- `Reset Style` calls `ProjectDocument.resetOverlayInspectorStyle(_:)`, which
  resets only the current overlay's style in one undo step (weather keeps its
  temperature unit).
- Delete clears the selection, which returns to the outer Inspector.
- Locked overlays are disabled in the picker and skipped by Previous / Next,
  matching the rule that locked overlays must be unlocked before editing.
- Timeline clip details use `ClipDetailHeader`: icon, title, and a trash icon
  button, with no Back button.

### Layout

Top to bottom:

1. Detail header
2. Overlay-specific collapsible sections
3. Shared Background, Border, and Effects sections

### Collapsible Sections

All detail sections use `InspectorCollapsibleSection` /
`InspectorSectionHeader`:

- A leading disclosure chevron (`chevron.right`, rotated when expanded) and a
  title; no per-section decorative icon.
- Sections that can be switched off show a small checkbox before the title.
  When it is off, the section body is wrapped in `.disabled(true)`; rows read
  `@Environment(\.isEnabled)` and render disabled text instead of fading with
  opacity. Do not add `.opacity(...)` to signal disabled rows.
- Expanding a section scrolls it into view: a section that fits scrolls just
  enough to show its last row, and a taller one pins its header to the top.
  `ParameterPanelView` installs this with `.inspectorRevealsExpandedSections()`.
- Row labels must fit the 104 pt label column on one line at 12 pt. Prefer a
  shorter label (for example `Shadow Spread`, `Active Height`, `From Activity`)
  plus a `.help` tooltip over a wrapped label.
- Boolean rows use `.toggleStyle(.checkbox)` with `.controlSize(.small)`.
- Value menus use `InspectorDenseMenuLabel` with the default `.popUp`
  indicator (⌃⌄) and `.inspectorMenuStyle()`; action menus such as Add Metric
  use `kind: .pullDown`.
- Slider rows pair the slider with an editable value field. Typing a value and
  pressing Return or leaving the field commits it (clamped to the range, with
  `%` read as a unit-interval percentage) and finishes one continuous undo
  edit; Esc cancels.

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

- Numeric overlays have no text presets; they are the `studio.numeric` component (ADR 0014).
- Running Gauge is the `studio.running-gauge` component (ADR 0015); dial, ring, region, and typography settings are component parameters.
- Route Map does not expose a preset; line color mode and Glow live in the Route Line section.
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

### No Footer

Overlay detail views have no sticky footer. Edits apply immediately, so there
is no `Done` commit step; Reset lives in the header action menu.

## Interaction Rules

- Clicking an overlay row and clicking an overlay in Preview must route to the same detail state.
- Esc in the editor window clears the selection when no text field has focus, no sheet is open, and no modifier is held. `EditorEscapeKeyMonitor` watches key-down at the window, because selecting on the canvas or in the Inspector list does not move keyboard focus and a SwiftUI `onKeyPress` would miss the key.
- Icon buttons use `InspectorIconButtonStyle`, which shows hover and pressed fills.
- Add overlay tiles should be keyboard-focusable.
- Row action buttons must not trigger row navigation.
- Destructive actions should use `danger.red` on hover or confirmation affordance, not constant bright red unless active.
- Sliders should call continuous update while dragging and finish undo grouping at drag end, matching current `finishContinuousEdit()` behavior.
- Numeric fields should commit on submit and preserve normalized coordinate precision.
- The panel should scroll when content exceeds height; the detail header stays fixed.

## Shared Stats Bar Inspector Component

`Stats Bar` is a single shared inspector module and must not diverge by overlay type.

- Use `CollapsibleStatsBarInspectorSection` for section chrome: disclosure chevron, Enabled checkbox before the title, and title.
- Use `OverlayStatsBarInspectorRows` for the section body rows.
- `Enabled` must not appear as a separate first row in expanded content.
- Collapsed Stats Bar headers use the regular single bottom separator; the shared wrapper must not add a top rule that doubles the line against the preceding section.
- Keep one shared row set across overlays: `Placement`, `Inside`, `Layout`, `Size`, `Width`, `Offset`, `Item Gap`, `Background`, `Dividers`, `Radius`, `Value Font/Size/Weight/Color`, `Label Font/Size/Weight/Color`, and `Slot 1...4`.
- Placement-specific rendering behavior must also stay consistent: left/right placements render vertical stack flow, and `Item Gap` affects vertical spacing in that flow.
- Stats Bar typography is self-contained: Value and Label colors come from Stats Bar config, not outer overlay accent/foreground fallbacks.
- Future overlays that need stats-bar controls should reuse this same component pair directly.

## Shared Layout Inspector Component

`Layout` is also a single shared inspector module and must be reused by every overlay detail panel.

- Use `CollapsibleLayoutInspectorSection` for section chrome: title and disclosure behavior.
- Use `OverlayLayoutInspectorRows` for the body rows.
- Canonical row set is fixed: `Position`, `Scale`, `Width`, `Height`, `Opacity`.
- Layout `Opacity` is element-level opacity (`OverlayElement.opacity`) and must fade the whole rendered overlay in preview and export. Background-only transparency belongs in the shared Background module.
- `Rotation` is not part of Layout and must not be shown in this section.
- For square overlays (for example the running gauge component), `Width` and `Height` can be hidden.
- Section ordering rule:
  - if the detail panel starts with a `Preset` section, `Layout` must be the second section;
  - otherwise, `Layout` must be the first section.
- New overlay detail panels must adopt this component pair and ordering rule directly instead of creating local layout section wrappers.

## Shared Background, Border, And Effects Components

`Background`, `Border`, and `Effects` are shared inspector modules and must be available at the end of every overlay detail panel.

- Use `OverlayBackgroundInspectorModule` for complete Background chrome and rows. The module includes the title, disclosure behavior, and the header checkbox.
- Use `OverlayBackgroundInspectorRows` only when a custom section wrapper is explicitly required.
- Canonical Background rows are `Color`, `Opacity`, `Radius`, `Padding`, and `Blur`.
- Use `OverlayBorderInspectorModule` for complete Border chrome and rows. The module includes the title, disclosure behavior, and the header checkbox.
- Use `OverlayBorderInspectorRows` only when a custom section wrapper is explicitly required.
- Canonical Border rows are `Color`, `Opacity`, and `Thickness`.
- Use `OverlayEffectsInspectorModule` for complete Effects chrome and rows. The Effects section has disclosure behavior but no section-level checkbox.
- Use `OverlayEffectsInspectorRows` only when a custom section wrapper is explicitly required.
- Canonical Effects rows are `Shadow`, `Shadow Color`, `Shadow Opacity`, `Shadow Radius`, `Shadow Spread`, `Shadow Offset`, `Glow`, `Glow Color`, `Glow Intensity`, `Fade Out`, and `Fade Amount`.
- Shadow targets the whole background/container when the overlay background is enabled; if background is disabled, shadow targets the internal foreground elements.
- Glow targets foreground/internal elements.
- Fade Out targets only the background. If background is disabled, Fade Out controls may stay visible but have no rendered effect.
- New overlay detail panels must append Background, Border, and Effects after overlay-specific sections, in that order.
- Distance Timeline must not keep its legacy local `Background & Border` or local `Effects` sections once the shared modules are present.
- Shared module headers use the same row background, toggle placement, and chevron placement as other collapsible detail sections; disclosure changes are immediate without animation.
- Shared Background, Border, and Effects modules use the same header/body separator model as regular detail sections and must not add an extra full-section outer stroke that changes the left edge while expanding.
- Dense color swatch strips show a short mainstream preset set plus a trailing fixed-size custom color button that opens the shared system color panel; they must not embed a system color well or impose a long preset-list width as the row minimum because narrow Inspectors should clip neither section headers nor row labels.

## SwiftUI Implementation Guidance

The current entry points are:

- `ParameterPanelView`
- `OverlayLibraryView`
- `OverlayElementListView`
- `OverlayElementInspectorView`

Implementation status: the list below is the original refactor plan. The legacy `OverlayDetailView` and the single-column row primitives it used (`InspectorSliderRow`, `ColorSwatchButton`, and similar) have since been removed from `ParameterPanelView.swift`; every overlay type now has a dedicated detail view built from the `InspectorDense*` primitives in `Sources/RunningOverlay/UI/InspectorRows/`.

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
- Icon-only buttons need `.help(...)` and accessibility labels (`.accessibilityLabel(...)`, normally the same text as the tooltip). This includes the Previous/Next and Delete buttons in the detail headers (clips included), color swatches, and the SF Symbol picker buttons. `InspectorIconButton` (overlay row eye/lock, detail header buttons) already applies `.accessibilityLabel(help)`, so pass a `help` string that reads well as a label; buttons built directly with `Button` must add the label themselves.
- Collapsible section headers must be real `Button`s (`.buttonStyle(.borderless)`), never a bare `.onTapGesture`, so they take keyboard focus (Tab with Full Keyboard Access on), activate with Space, and are exposed to VoiceOver as buttons. Each header sets `.accessibilityLabel(<section title>)` and `.accessibilityValue("Expanded" | "Collapsed")`, so VoiceOver announces "Layout, Expanded, button". Disclosure changes stay immediate with no animation.
- Headers with an enable checkbox (Background, Border, Stats Bar, Divider, and similar) must not nest the checkbox inside the header `Button`. The `Button` wraps the chevron, title, and spacer; the checkbox is its sibling and carries its own label (`.accessibilityLabel("Enable <title>")`); a pointer-only `.onTapGesture` on the row keeps the padding clickable so the mouse hit area is the whole row except the checkbox.
- Section header keyboard, pointer, and VoiceOver behavior needs a live window server, so it is checked by hand after changing a header: with Full Keyboard Access on, Tab to a header and press Space (the section toggles once); click the title, the empty space, and the chevron (each toggles once) and the accessory switch (toggles the switch only, not the section); with VoiceOver, confirm it reads the title, the expanded state, and "button". `InspectorSectionHeaderTests` only covers the window-free layout contract (collapsed shell is one header row tall; expanded adds only the body). Do not add tests that open an `NSWindow` or send synthetic events: a version that did made `swift test` time out on the GitHub macOS runner.
- Hit targets should be at least 28x28 px for dense controls and preferably 30x30 px.
- Selected/focused states should not rely on color alone; use border or checkmark indicators for swatches and selected cells.

## Open Product Questions

- Should adding an overlay immediately open detail? Preferred: yes.
- Should lock also disable inspector field edits, or remain a canvas-interaction lock only?
- Should opacity be a general overlay property or only part of style background/shadow?
- Should animation be in the project schema for v1, or deferred?
