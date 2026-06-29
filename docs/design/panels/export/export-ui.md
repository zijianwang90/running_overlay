# Export UI Design Spec

Last updated: 2026-06-18

## Purpose

This spec defines the production export dialog for Running Overlay Studio. The current export sheet is functional but still reads like a debug surface because primary export, test exports, JSON export, and project snapshot controls share the same visual priority.

The production version should make the normal export path obvious, keep project-backed settings visible, and move diagnostic actions into a lower-priority advanced area.

## Design Direction

Use the same dark macOS utility modal language as Project Settings:

- Dark charcoal modal with subtle border and 8 px control radii.
- Compact centered title area with a short status subtitle.
- Grouped sections with left labels and right controls.
- Primary blue `Export` action in the footer.
- Secondary actions use raised dark control styling.
- Debug or diagnostic actions are hidden behind `Advanced` and never compete with the primary export action.

The dialog should feel like the last step in an editor workflow, not a settings page or a developer tool.

## Layout

Recommended modal size: `680 x auto`, with a minimum content width of `620`.

Top to bottom:

1. Header
2. Export destination
3. Export content summary with performance help
4. Encoding settings with codec help
5. Advanced actions, collapsed by default
6. Progress or validation row when relevant
7. Footer actions

Wireframe:

```text
┌──────────────────────────────────────────────────────────────┐
│ Export Overlays                                              │
│ Transparent MOV overlay with alpha channel                   │
│                                                              │
│ Destination                                                  │
│ ┌──────────────────────────────────────────────┐ ┌────────┐ │
│ │ ~/Movies/Running Overlay Studio                     │ │ Choose │ │
│ └──────────────────────────────────────────────┘ └────────┘ │
│                                                              │
│ Output  ⓘ                                                    │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ Format       Transparent MOV                             │ │
│ │ Resolution   1080p 16:9                                  │ │
│ │ Frame Rate   30 fps                                      │ │
│ │ Data FPS     5 fps                                       │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│ Encoding  ⓘ                                                  │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ Codec        [ H.265 with Alpha                 v ]       │ │
│ │ Bitrate      ━━━━━━━━━━━━━●━━━━━━━━━━━━━━      30 Mbps    │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│ ▸ Advanced                                                   │
│                                                              │
│                                         Cancel   Export      │
└──────────────────────────────────────────────────────────────┘
```

Expanded advanced state:

```text
▾ Advanced
┌──────────────────────────────────────────────────────────────┐
│ Diagnostics                                                  │
│ Export Test Frame     Export Test Clip     Export Overlay JSON│
│                                                              │
│ Project Snapshot                                             │
│ Save Snapshot        Restore Snapshot                        │
│                                                              │
│ Full Activity                                                │
│ Export Full Activity                                         │
└──────────────────────────────────────────────────────────────┘
```

## Header

Content:

- Title: `Export Overlays`
- Subtitle: `Transparent MOV overlay with alpha channel`

Visual rules:

- Use `EditorTheme.panelTitleFont` for the title.
- Use `EditorTheme.bodyFont` and `textSecondary` for the subtitle.
- Keep the header left-aligned inside the modal content, not in a separate floating card.
- Do not include explanatory paragraphs.

## Destination Section

The destination section is the first editable area because it is the only required user decision in the current workflow.

Controls:

- Text field showing the abbreviated path.
- Secondary `Choose...` button with a folder icon or label plus icon.

Rules:

- Path field should use the app dark input styling instead of the default rounded light system field.
- The text field may remain editable for keyboard path entry.
- Invalid or inaccessible paths show a compact validation row below the field.
- The choose button opens the existing directory picker.

Validation examples:

- `Folder does not exist. It will be created if possible.`
- `Destination is not writable. Choose another folder.`

## Output Section

This section summarizes project-backed export facts that users need to verify but should not edit here if they already live in Project Settings.

Rows:

- `Format`: `Transparent MOV`
- `Resolution`: current project setting, e.g. `1080p 16:9`
- `Frame Rate`: current project setting, e.g. `30 fps`
- `Data FPS`: current project setting, e.g. `5 fps`

Rules:

- Render as a grouped read-only box.
- Show a compact info icon after the `Output` section title.
- The info icon uses a circle plus exclamation mark or the closest SF Symbol, such as `exclamationmark.circle`.
- Hovering the info icon shows export performance guidance: `1080p currently provides the best export time. 5 fps is usually the best-balanced layer data refresh rate for speed and visual quality. Higher data FPS and 4K export significantly increase render time with the current implementation.`
- Use monospaced digits for numeric values.
- Do not duplicate Project Settings controls for resolution, frame rate, or layer data FPS unless they become directly editable in the export model.

## Encoding Section

Controls:

- `Codec` menu, backed by `project.settings.exportCodec`.
- `Bitrate` slider, backed by `project.settings.bitrateMbps`.

Rules:

- Show a compact info icon after the `Encoding` section title.
- The info icon uses the same style and hover behavior as the Output info icon.
- Hovering the info icon shows codec guidance: `Transparent overlay export requires alpha-capable codecs. HEVC keeps file size controlled but is significantly slower. ProRes exports much faster but creates much larger files.`
- Keep the codec menu and bitrate slider editable because they are currently export-specific project settings.
- Right-align the bitrate value as `30 Mbps`.
- Use a filled blue slider track where practical.
- Values update project settings; encoding controls live only in the export dialog, not Project Settings.

## Section Help Icons

Use help icons only where users need export-specific tradeoff guidance before starting a long render.

Rules:

- Size: `14-16 px`.
- Foreground: `textMuted`, changing to `textSecondary` on hover.
- Hit target: at least `28 x 28 px`.
- Hovering the info icon shows a compact floating help panel with the section guidance. Render the panel outside the scroll view so it is not clipped.
- Native AppKit `toolTip` and SwiftUI `.help` are unreliable inside sheets, so use an explicit hover tooltip view.
- Do not show persistent explanatory text in the dialog by default.

## Advanced Section

Collapsed by default.

Purpose:

- Keep useful developer and diagnostic actions available without making them look like normal production choices.

Groups:

- `Diagnostics`: `Export Test Frame`, `Export Test Clip`, `Export Overlay JSON` (Debug builds only; hidden in production builds)
- `Project Snapshot`: `Save Snapshot`, `Restore Snapshot` (Debug builds only; hidden in production builds)
- `Full Activity`: `Export Full Activity`

Rules:

- Use disclosure state local to the dialog.
- Advanced actions use secondary buttons only.
- Do not use the primary blue style inside the advanced section.
- Hide Diagnostics and Project Snapshot actions from production builds.
- Keep destructive or state-restoring actions visually separate from export diagnostics.
- Disable all actions consistently while `project.isExporting` is true.

## Footer

Content:

- Optional left status text when exporting or validation fails.
- Right-aligned secondary `Cancel`.
- Right-aligned primary `Export`.

Rules:

- Footer is separated from content by a subtle divider.
- `Export` is the only primary blue button.
- `Export` uses the default keyboard shortcut.
- `Cancel` dismisses the dialog without changing export settings beyond already-bound controls.
- The footer should remain visible if content scrolls in smaller windows.

## Exporting State

When `project.isExporting` is true:

- Disable destination editing, codec menu, bitrate slider, advanced buttons, and primary export.
- Replace or augment the footer status with a compact message such as `Exporting...`.
- If progress becomes available later, show a thin progress indicator above the footer.

Do not dismiss the dialog automatically before the user can see export start or validation errors. If the underlying exporter remains fire-and-forget in this iteration, dismissal can keep the current behavior until progress reporting is added.

## Copy

Use English UI copy until the planned localization pass.

Button labels:

- `Choose...`
- `Cancel`
- `Export`
- `Export Test Frame`
- `Export Test Clip`
- `Export Overlay JSON`
- `Export Full Activity`
- `Save Snapshot`
- `Restore Snapshot`

Field labels:

- `Destination`
- `Output`
- `Format`
- `Resolution`
- `Frame Rate`
- `Data FPS`
- `Encoding`
- `Codec`
- `Bitrate`
- `Advanced`

## Implementation Notes

Current SwiftUI entry point:

- `Sources/RunningOverlay/UI/ExportDialogView.swift`

Recommended structure:

- Keep `ExportDialogView` as the public sheet view.
- Add small private subviews in the same file first:
  - `ExportSection`
  - `ExportReadOnlyRow`
  - `ExportAdvancedActions`
  - `ExportFooter`
- Reuse `EditorTheme`, `EditorPrimaryButtonStyle`, and `EditorSecondaryButtonStyle`.
- Avoid new theme tokens unless a missing primitive is clearly shared with other modals.
- Keep any validation helper local unless export validation becomes reusable elsewhere.

## Non-Goals

- Export preset management.
- Batch export.
- Queue management.
- Cloud share destinations.
- New codec options beyond the current `ProjectExportCodec` model.
- Moving project settings out of Project Settings.
