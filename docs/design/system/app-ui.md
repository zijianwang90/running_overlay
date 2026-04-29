# Running Overlay App UI Design System

Last updated: 2026-04-26

## Purpose

This document defines the application-level UI direction for Running Overlay. Feature-specific specs should extend this system instead of inventing local visual styles.

Related specs:

- [Inspector UI](../panels/inspector/inspector-ui.md)
- [Media Pool UI](../panels/media-pool/media-pool-ui.md)
- [Preview UI](../panels/preview/preview-ui.md)
- [Timeline UI](../panels/timeline/timeline-ui.md)

## Product Character

Running Overlay is a focused desktop editor for aligning running activity data with video and exporting polished overlays. The UI should feel like a professional editing tool: calm, dense, precise, and fast to scan.

The app should not feel like a marketing site, a mobile fitness app, or a decorative dashboard. Visual polish should come from alignment, contrast, typography, and controlled interaction states.

## Core Principles

- **Tool first**: Every visible element should help import, align, preview, style, or export.
- **Dark editor surface**: Use near-black app chrome and charcoal panels, with subtle elevation from borders and state fills.
- **Dense but readable**: Prefer compact controls, consistent row heights, and clear hierarchy over spacious cards.
- **Consistent panels**: Media Pool, Preview, Timeline, and Inspector should share title bars, toolbar buttons, rows, dividers, and focus states.
- **Model-backed controls**: Do not show controls that appear saved unless the project model can persist or apply them.
- **Native macOS where useful**: Keep expected menu, keyboard, drag/drop, and focus behaviors.

## Color Tokens

| Token | Hex | Usage |
| --- | --- | --- |
| `app.bg` | `#0B0F12` | Root app background |
| `app.chrome` | `#101418` | Split views, outer chrome, timeline surround |
| `panel.bg` | `#15191D` | Media Pool, Inspector, timeline panels |
| `panel.header` | `#1B2025` | Panel title/header bars |
| `surface.raised` | `#1B2025` | Elevated sections, popovers, sticky footers |
| `surface.control` | `#20252A` | Buttons, fields, tiles |
| `surface.hover` | `#272D33` | Hovered controls |
| `surface.pressed` | `#11161A` | Pressed controls |
| `surface.selected` | `#263244` | Selected rows/items |
| `border.subtle` | `#2B3238` | Panel borders and dividers |
| `border.strong` | `#3A424A` | Focusable regions and active borders |
| `text.primary` | `#F3F6F8` | Main labels |
| `text.secondary` | `#B6BEC7` | Metadata and row details |
| `text.muted` | `#7E8893` | Disabled text and hints |
| `accent.blue` | `#2F8CFF` | Primary actions, selected tabs, focus rings |
| `accent.blue.soft` | `#123052` | Active segmented/tile background |
| `danger.red` | `#FF5A5F` | Destructive actions |
| `success.green` | `#51C96B` | Successful/ready states |
| `warning.yellow` | `#FFD166` | Warning or partial states |

## Typography

Use the macOS system font. Prefer monospaced digits for metrics, times, durations, and coordinates.

| Role | Size | Weight | Usage |
| --- | ---: | --- | --- |
| `panelTitle` | 22 | Semibold | Major side panel titles |
| `sectionTitle` | 15 | Semibold | Inspector/media section titles |
| `body` | 13 | Regular | Standard labels |
| `bodyStrong` | 13 | Semibold | Row titles and important controls |
| `caption` | 11 | Regular | Metadata, hints, subtitles |
| `numeric` | 13 | Medium | Values, durations, coordinates |
| `timelineLabel` | 11 | Medium | Timeline rulers and clip metadata |

Avoid viewport-scaled type. Keep letter spacing at 0.

## Spacing, Radius, And Sizing

Base spacing unit: 4 px.

| Token | Value |
| --- | ---: |
| `space.1` | 4 |
| `space.2` | 8 |
| `space.3` | 12 |
| `space.4` | 16 |
| `space.5` | 20 |
| `space.6` | 24 |
| `panel.paddingX` | 12-18 |
| `panel.headerHeight` | 48-56 |
| `control.height` | 30-34 |
| `row.height.compact` | 52 |
| `row.height.media` | 68-76 |
| `iconButton.size` | 30 |
| `radius.control` | 7 |
| `radius.panel` | 8 |
| `border.width` | 1 |

Use 6-8 px radius for tool controls. Avoid pill-heavy styling unless the control is explicitly a chip, status pill, or segmented tab.

## Layout System

The app is a multi-pane editor:

- Left: Pool panel with `Media Pool`, `Overlay Pool`, and `Templates` modes for import/source management, addable overlay modules, and reusable overlay layouts.
- Center: Preview canvas and playback controls.
- Bottom: Timeline and alignment editing.
- Right: Inspector and overlay/clip details.

Panel rules:

- Panels use a fixed header bar with title and compact toolbar actions.
- Panel content scrolls independently when needed.
- Avoid floating cards inside panels. Use sections, rows, tiles, and dividers.
- Empty states should stay within the panel layout and preserve tool context.
- Resizable split panes should have stable minimum widths so controls do not collapse.

## Component Standards

### Header Bars

- Left-aligned title.
- Right-aligned icon actions.
- Height: 48-56 px.
- Background: `panel.header` or `panel.bg`.
- Bottom border: `border.subtle`.

### Icon Buttons

- Size: 30x30 px.
- Background appears on hover or active state.
- Use SF Symbols if no icon library is present.
- Every icon-only button needs `.help(...)` and accessibility label.
- Disabled state: muted foreground, no strong fill.

### Rows

- Use stable row heights.
- Keep primary text left, metadata below or right, status on the right.
- Selection uses `surface.selected` and an accent border/line where helpful.
- Hover state should be visible but subtle.

### Tiles

- Use tiles for addable overlay items and compact tool choices.
- Include icon, label, and short hint.
- Do not use tiles for every section. Repeated content and framed tools only.

### Segmented Controls And Chips

- Use segmented controls for mutually exclusive modes.
- Use chips for filters and statuses.
- Selected state uses `accent.blue` or `accent.blue.soft`.

### Inputs And Sliders

- Inputs use dark control backgrounds and subtle borders.
- Numeric inputs should use monospaced digits.
- Sliders update continuously and commit undo grouping on drag end where applicable.

### Menus And Popovers

- Native macOS menus are acceptable for v1.
- Custom menus, if needed, use dark elevated background, 8 px radius, subtle border, and blue hover state.
- Destructive actions should not be bright red by default unless active or confirmed.

## Interaction Standards

- Single click selects.
- Double click previews or opens direct editing only where already established.
- Command-click toggles multi-select in lists.
- Command+A applies to the active list or editor region.
- Context menu actions apply to the current selection when right-clicking a selected item; otherwise to the clicked item.
- Drag/drop targets should have clear active feedback.
- Row action buttons must not also trigger row navigation.

## Empty States

Empty states should be functional and compact:

- Preserve the surrounding panel header and controls.
- Use a small icon, concise primary message, one optional secondary message, and one primary action when useful.
- Use dashed drop zones only when drag/drop is supported.
- Avoid large illustrations or marketing copy.

Examples:

- Media Pool before FIT: `Import FIT`, `Start with running activity data`.
- Media Pool after FIT: `Drop videos here`, `Import Videos`.
- Filtered list: `No media matches the current filter`.
- Overlay list: `No overlays added yet`.
- Templates list: compact rows such as `Easy Run`, `Interval Workout`, `Race`, and `No saved templates yet`.

## Accessibility

- Maintain WCAG AA contrast for text.
- Do not rely on color alone for selected, focused, or marked states.
- Provide keyboard focus and labels for all toolbar buttons.
- Keep dense hit targets at least 28x28 px; prefer 30x30 px.
- Preserve platform keyboard conventions.

## Implementation Guidance

Recommended shared SwiftUI structure:

- `RunningOverlayTheme` or `EditorTheme`
- `EditorPanel`
- `EditorPanelHeader`
- `EditorIconButton`
- `EditorSection`
- `EditorRow`
- `EditorSegmentedControl`
- `EditorSearchField`
- `EditorEmptyState`
- `EditorStatusPill`
- `EditorPlaybackButton`
- `EditorDropdownButton`
- `EditorTimelineControl`

Avoid creating separate theme islands such as `InspectorTheme` and `MediaBrowserColor` long term. If local names already exist, migrate toward shared tokens incrementally.

## Documentation Rule

Any new substantial UI design work should add or update:

- A design spec in `docs/design/`
- Any relevant structured `.spec.json`
- A project log entry in [project-log.md](../../project-log.md)
