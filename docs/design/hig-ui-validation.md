# HIG UI Validation Workflow

Last updated: 2026-07-06

## Purpose

Use this workflow when running an Apple Human Interface Guidelines review of
Running Overlay Studio's macOS UI. The review should produce actionable issues
that can be implemented and tested, not broad design commentary.

The workflow validates the product against three authorities, in this order:

1. Current project requirements and design specs in this repository.
2. The installed Codex HIG skills and their Apple HIG reference snapshots.
3. Local runtime behavior from the macOS app, screenshots, and tests.

Do not copy Apple HIG source text into repository documentation. Summarize
findings and cite the HIG skill/reference name used for the decision.

## Scope

The default validation pass covers:

- Main editor window structure: Media Pool, Preview, Timeline, Inspector, and
  split-pane behavior.
- Toolbar, menu bar, context menus, keyboard shortcuts, and pointer behavior.
- Import, alignment, overlay editing, preview playback, project settings, and
  export flows.
- Empty, loading, progress, error, disabled, selected, focused, and drag/drop
  states.
- Accessibility behavior for labels, VoiceOver order, keyboard operation,
  contrast, focus, and Reduce Motion.
- Preview/export visual parity for overlay surfaces that already have snapshot
  or render-model coverage.

Out of scope unless explicitly requested:

- Redesigning the visual language from scratch.
- Creating or updating visual snapshots.
- Changing app architecture, project-file compatibility, timing conversions, or
  export behavior.
- Reviewing private FIT files, GPS traces, source videos, generated exports, or
  machine-specific paths.

## Required Project Reading

Before starting the validation pass, read only the current documents needed for
the surface under review:

- `docs/index.md`
- `docs/design/README.md`
- `docs/design/system/app-ui.md`
- Relevant `docs/design/panels/*/*-ui.md`
- Relevant `docs/design/overlays/*/*-ui.md`
- `docs/testing.md` before relying on fixtures or visual snapshots

Read `docs/architecture.md` only if the finding would change subsystem
boundaries, render-model flow, timing domains, persistence, or undo semantics.

## HIG Skill Routing

Use the smallest set of HIG skills needed for each review item.

| Review area | Primary HIG skill | Relevant reference topics |
| --- | --- | --- |
| macOS conventions | `hig-platforms` | `designing-for-macos` |
| App-wide visual foundations | `hig-foundations` | `accessibility`, `color`, `dark-mode`, `layout`, `typography`, `sf-symbols`, `writing` |
| Main window and panes | `hig-components-layout` | `split-views`, `sidebars`, `scroll-views`, `windows`, `panels`, `lists-and-tables` |
| Controls and forms | `hig-components-controls` | `toggles`, `segmented-controls`, `sliders`, `steppers`, `pickers`, `text-fields`, `labels` |
| Toolbar, menu, and buttons | `hig-components-menus` | `toolbars`, `the-menu-bar`, `menus`, `context-menus`, `buttons`, `pop-up-buttons`, `pull-down-buttons` |
| Sheets, alerts, and popovers | `hig-components-dialogs` | `sheets`, `alerts`, `popovers` |
| Progress and loading states | `hig-components-status`, `hig-patterns` | `progress-indicators`, `loading`, `feedback` |
| Keyboard, pointer, and drag/drop | `hig-inputs`, `hig-patterns` | `keyboards`, `pointing-devices`, `drag-and-drop`, `undo-and-redo` |
| Data visualization and overlay content | `hig-components-content`, `hig-patterns` | `charts`, `image-views`, `collections`, `charting-data`, `playing-video`, `workouts` |
| Search or path navigation | `hig-components-search` | `search-fields`, `path-controls`, `page-controls`, `searching` |
| Health, weather, privacy, and system integration | `hig-technologies`, `hig-foundations` | `healthkit`, `voiceover`, `privacy`, `icloud`, `generative-ai` |

When a review item spans multiple areas, name each HIG skill used in the issue
record and explain which skill drove the recommendation.

## Validation Pass

### 1. Establish Context

Capture the project-specific baseline before judging the UI:

- Platform: native macOS 15 app.
- UI stack: SwiftUI with focused AppKit interop.
- Product character: professional desktop editor; dense, precise, dark, and
  tool-first.
- Core tasks: import FIT data and video, align media, style overlays, preview,
  and export transparent overlay videos.
- Design system: `docs/design/system/app-ui.md`.

If any of these facts are stale, update the relevant project documentation
before recording HIG findings.

### 2. Inventory Surfaces

Create a short inventory before inspecting details:

- Main editor window and pane hierarchy.
- Media Pool modes and empty/import states.
- Preview canvas, playback controls, guides, and selection affordances.
- Timeline tracks, playhead, zoom, drag/drop, and alignment interactions.
- Inspector outer list and overlay detail editors.
- Project settings, heart-rate/pace zones, font library, and export dialog.
- Menu bar, toolbar, context menus, keyboard shortcuts, and window commands.

For each surface, note the source design spec and implementation file being
checked.

### 3. Static Source Audit

Review SwiftUI/AppKit code before launching the app:

- Check that shared components and tokens are used instead of local theme
  islands.
- Confirm icon-only controls have help text and accessibility labels.
- Confirm controls expose current state and disabled reasons where relevant.
- Check that destructive actions route through undo when practical.
- Check that continuous edits use continuous undo transactions.
- Identify hard-coded colors, sizes, or text that conflict with the design
  system or HIG skill guidance.
- Check menu commands and keyboard shortcuts for standard placement and naming.

Record source-level findings with file and line references.

### 4. Runtime Visual Pass

Run the app with synthetic or public-safe data only. Do not use private activity
files or private videos for validation artifacts.

Inspect at minimum:

- Fresh launch with no project.
- FIT imported, no media.
- FIT and one or more videos imported.
- Overlay added and selected.
- Timeline zoomed, scrolled, and resized.
- Preview playback stopped, playing, and scrubbed.
- Export dialog before export, invalid destination, and in-progress state when
  available.
- Settings and secondary sheets.
- Light/dark and increased-contrast behavior when feasible.
- Narrow and wide window sizes, including minimum pane widths.

Capture screenshots only when they are needed to make a finding reproducible.
Do not commit screenshots unless they are approved design artifacts or visual
test snapshots.

### 5. Interaction Pass

Validate the macOS interaction model:

- All frequent commands reachable from visible UI and the menu bar.
- Toolbar actions are frequent, clearly grouped, and available through menus.
- Context menu commands are never the only way to complete a task.
- Standard shortcuts are not repurposed.
- Custom shortcuts are limited to frequent app-specific commands.
- Tab order and keyboard-only operation work for forms and primary editing
  flows.
- Pointer hover, resize, selection, and drag/drop feedback are consistent.
- Drag/drop operations preserve or update selection predictably and have
  non-drag alternatives where practical.

### 6. Accessibility Pass

Check each reviewed surface for:

- VoiceOver labels, values, traits, and logical reading order.
- Keyboard focus visibility and Full Keyboard Access behavior.
- Contrast for text, disabled states, selected states, focus rings, and
  warnings.
- Non-color indicators for state, marks, selection, errors, and progress.
- Text expansion and truncation in dense panels.
- Reduce Motion alternatives for any motion that affects spatial orientation.
- Minimum practical hit target size for dense macOS controls.

Prioritize accessibility findings as implementation bugs when they block
operation, hide state, or make a workflow keyboard-inaccessible.

### 7. Preview, Overlay, And Export Pass

For overlay UI, validate both editing controls and rendered output:

- Inspector controls match the overlay design spec and persisted model fields.
- Controls do not imply saved state that the project model cannot preserve.
- Preview and export consume the same render models and style fields.
- Selection affordances are visible in preview and absent from export output.
- Overlay text, colors, opacity, borders, and layout remain readable over video.
- Any visual snapshot change has a clear before/after explanation and requires
  human review.

Use existing focused tests before broad validation when a finding concerns
preview/export parity.

### 8. Record Findings

Use this format for every issue:

```markdown
### [P1|P2|P3] Short Title

- **Surface**: Panel, dialog, overlay, or command path.
- **Evidence**: File/line, screenshot name, or runtime steps.
- **HIG basis**: Skill and reference topic, such as `hig-components-menus/toolbars`.
- **Project basis**: Local design spec or requirement.
- **Problem**: Concrete user-visible mismatch or risk.
- **Expected behavior**: Specific desired behavior.
- **Suggested fix**: Smallest coherent implementation direction.
- **Validation**: Focused test, visual test, manual check, or human review.
```

Severity:

- `P1`: Blocks a primary workflow, creates data-loss risk, prevents keyboard or
  VoiceOver operation, or violates a macOS convention in a way users cannot
  work around.
- `P2`: Degrades a common workflow, creates confusing state, breaks preview/export
  parity, or conflicts with the design system.
- `P3`: Polish, consistency, or documentation issue that does not block work.

## Validation Commands

Use the repository commands, selecting the smallest command that proves the
finding or fix:

```sh
./scripts/test.sh FilterName
./scripts/visual-test.sh
./scripts/check-doc-links.rb
./scripts/check.sh
```

Run `./scripts/check.sh` before considering a UI fix complete. Run
`./scripts/visual-test.sh` when rendered overlay output, preview/export parity,
or visual snapshots are affected.

## Completion Criteria

A HIG UI validation pass is complete when:

- The reviewed surfaces and skipped surfaces are listed.
- Every finding cites both a HIG basis and a project basis.
- Findings are prioritized and reproducible.
- Suggested fixes respect project architecture, undo rules, persistence, and
  preview/export parity.
- Required tests or manual checks are named.
- Any snapshot, export, font, icon, fixture, or licensed-asset change is marked
  for human review.

