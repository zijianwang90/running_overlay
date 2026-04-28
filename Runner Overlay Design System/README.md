# Running Overlay — Design System

**Product:** Running Overlay is a native macOS 15 app (Swift 6 / SwiftUI) that lets athletes and video creators import FIT activity files and video clips, design data overlay elements, and export transparent MOV overlays for compositing in video editors.

**Company description:** 一个帮跑者给视频素材添加数据覆层的原生macOS软件 — A native macOS tool helping runners add data overlays to their video footage.

---

## Sources

- **GitHub repo:** `zijianwang90/running_overlay @ develop`
  Full URL: https://github.com/zijianwang90/running_overlay/tree/develop
- **Design docs:** `docs/design/` — contains per-panel `.md` specs, `.spec.json` machine-readable specs, and `.png` mockups
- **Source of truth theme:** `Sources/RunningOverlay/UI/EditorTheme.swift`
- **Design mockups (imported):** `docs/design/*.png`

---

## Product Overview

Running Overlay has a single product surface: a **dark multi-pane desktop editor** for macOS. The layout is:

```
┌──────────────┬─────────────────────────┬──────────────┐
│  Media Pool  │        Preview          │  Inspector   │
│  (left)      │       (center)          │   (right)    │
├──────────────┴─────────────────────────┴──────────────┤
│                     Timeline (bottom)                  │
└────────────────────────────────────────────────────────┘
```

### Key panels:
- **Media Pool** — import and manage video clips; color-mark them; align to activity timeline
- **Preview** — live canvas showing the video frame + overlays at current playhead position; overlay drag-to-position
- **Inspector** — add/manage overlay elements (heart rate, pace, distance, route map, gauge, etc.); edit overlay styles
- **Timeline** — FIT activity track + video clip tracks; drag to align; playhead seek

### Overlay types supported:
Heart Rate, Pace, Calories, Elapsed Time, Real Time, Distance, Elevation, Cadence, Power, Distance Timeline, Elevation Chart, Running Gauge, Route Map

---

## Content Fundamentals

**Tone:** Tool-first. Copy is terse, functional, and precise. No marketing language inside the editor UI.

**Voice:**
- Imperative, second-person implied: `Drop videos here`, `Import Videos`, `Add Overlay`
- No "Welcome" screens, no emoji, no exclamation marks
- Units always explicit: `min/km`, `bpm`, `kcal`, `spm`, `watts`
- Numbers in monospaced: times, durations, coordinates, frame counts

**Casing:**
- Title Case for panel names (`Media Pool`, `Inspector`, `Running Gauge`)
- Sentence case for hints and secondary text (`Choose a data layer to place on the preview`)
- ALL CAPS never used

**Emoji:** Never used in UI copy.

**Metric formatting examples:**
- Pace: `5'10"/km` or `13'49" / km`
- Distance: `10.73 km`, `21.10 km`
- Heart rate: `142 bpm`
- Elapsed time: `55:24`

---

## Visual Foundations

### Color

Dark-editor aesthetic. Near-black app shell with layered charcoal panels. Elevation is communicated through borders and subtle background-value steps, not heavy shadows.

| Token | Hex | Role |
|---|---|---|
| `--app-bg` | `#0B0F12` | Root app background |
| `--app-chrome` | `#101418` | Split views, outer chrome, toolbar |
| `--panel-bg` | `#15191D` | Panel bodies |
| `--panel-header` | `#1B2025` | Panel title bars, elevated sections |
| `--surface-control` | `#20252A` | Buttons, fields, tiles |
| `--surface-hover` | `#272D33` | Hovered controls |
| `--surface-pressed` | `#11161A` | Pressed controls |
| `--surface-selected` | `#263244` | Selected rows |
| `--border-subtle` | `#2B3238` | Dividers, panel borders |
| `--border-strong` | `#3A424A` | Focus rings, active containers |
| `--text-primary` | `#F3F6F8` | Main labels |
| `--text-secondary` | `#B6BEC7` | Metadata, subtitles |
| `--text-muted` | `#7E8893` | Hints, disabled |
| `--accent-blue` | `#2F8CFF` | Primary actions, selected state, focus |
| `--accent-blue-soft` | `#123052` | Active tab/tile background |
| `--danger-red` | `#FF5A5F` | Destructive actions |
| `--success-green` | `#51C96B` | Ready/aligned status |
| `--warning-yellow` | `#FFD166` | Warning/partial state |
| `--timeline-fit` | `#49A862` | FIT activity bar |
| `--timeline-clip` | `#2F73D9` | Video clip blocks |
| `--timeline-playhead` | `#E4525A` | Playhead line |

### Typography

System font stack — SF Pro on macOS. **No web fonts.** Monospaced digits used everywhere a number appears (durations, coordinates, values, frame counts).

| Role | Size | Weight | Usage |
|---|---:|---|---|
| Panel Title | 22px | Semibold | `Inspector`, `Media` panel headers |
| Section Title | 15px | Semibold | `Add Overlay`, `Added Elements` |
| Body | 13px | Regular | Row labels, controls |
| Body Strong | 13px | Semibold | Tile labels, row titles |
| Caption | 11px | Regular | Metadata, hints |
| Numeric | 13px | Medium + mono | All metric values |
| Timeline Label | 11px | Medium + mono | Ruler ticks, clip labels |

### Spacing

Base unit: **4px**. Scale: 4 / 8 / 12 / 16 / 20 / 24px.

Key layout measurements:
- Panel header height: 54px
- Control height: 32px (dense: 30px)
- Compact row height: 52px
- Media row height: 72px
- Icon button: 30×30px
- Panel padding X: 14–18px
- Control radius: 7px
- Panel radius: 8px
- Border width: 1px

### Backgrounds & Surfaces

- **No gradients** in UI chrome. Background fills are flat solid colors from the color system.
- Video frames rendered inside a dark letterbox workspace.
- Panel elevation communicated by border-only, not shadow.
- Popovers / context menus: `#1D2228` background, `border.subtle` border, 8px radius.

### Imagery

- No decorative imagery in UI.
- Video thumbnails in media rows are icon wells (`#101418` background), not real thumbnails for performance.
- Safe guide lines in preview: blue/cyan low-opacity, thin, non-interactive.
- Overlay specimens use warm-toned running photography as the canvas backdrop.

### Animation & Interaction

- **No decorative animation.** UI is a tool — content changes are instant or fade fast.
- Drag interactions: overlay drag commits undo at `dragEnd`; slider drag calls `registerContinuousUndoPoint` during drag and `finishContinuousEdit()` on release.
- Hover: background shifts to `--surface-hover` (`#272D33`). No scale/shadow changes.
- Press: background shifts to `--surface-pressed` (`#11161A`).
- Selected row: `--surface-selected` (`#263244`) with subtle blue left accent.
- Focus rings: `--accent-blue` (`#2F8CFF`) outline.

### Cards & Rows

- **No rounded-card-left-border-accent** pattern.
- Overlay tiles: `--surface-control` background, `--border-subtle` border, 7–8px radius. Two-column grid.
- Media rows: alternating `#1B2025` / `#171C21`, full-width, no outer card rounding.
- Inspector sections: thin `--border-subtle` divider between sections. Dense rows (~32px).

### Corner Radii

- Controls, buttons, tiles: 7px
- Panels, menus, popovers: 8px
- Status pills: fully rounded (pill)
- Clip blocks in timeline: 4px

### Shadow

- No outer drop shadows on panels.
- Overlay elements in Preview can have configurable shadow (via `shadowOpacity`, `shadowRadius`, `shadowOffset`).

### Iconography

See **ICONOGRAPHY** section below.

---

## Iconography

**System:** SF Symbols (native macOS). No third-party icon fonts or CDN-linked icon sets.

SF Symbols usage observed:
- `waveform.path.ecg` — FIT import button
- `video.badge.plus` — video import, empty media state
- `square.and.arrow.up` — export
- `gearshape` — project settings
- `eye` / `eye.slash` — overlay visibility
- `lock` / `lock.open` — overlay lock
- `trash` — delete
- `chevron.right` — row disclosure
- `plus` — add overlay tile
- `heart` — heart rate
- `flame` — calories
- `clock` — real time / elapsed time
- `mountain.2` — elevation
- `bolt` — power
- `map` — route map
- `gauge` — running gauge
- `checkmark` — unit selection in menus

**Emoji:** Never used as icons.

**Custom SVG:** None. The app relies entirely on SF Symbols.

**Overlay element icons** are rendered as small SF Symbol glyphs at 16–18pt inside tiles and rows.

Assets copied: design mockup screenshots in `docs/design/`; no logo or app icon assets were found in the repository.

---

## File Index

```
README.md                    ← this file
SKILL.md                     ← agent skill definition
colors_and_type.css          ← CSS design tokens

docs/design/                 ← original design mockup PNGs + specs

preview/
  colors-base.html           ← app/chrome/panel background palette
  colors-semantic.html       ← accent, status, text color swatches
  colors-timeline.html       ← timeline-specific colors
  type-scale.html            ← typography specimens
  spacing-tokens.html        ← spacing + radius + sizing tokens
  components-buttons.html    ← button styles
  components-rows.html       ← media rows + inspector rows
  components-tiles.html      ← overlay add tiles
  components-panel-header.html ← panel header pattern
  components-inspector.html  ← inspector outer panel
  components-timeline.html   ← timeline anatomy

ui_kits/macos_app/
  index.html                 ← full interactive app prototype
  README.md                  ← UI kit notes
```
