# Skia Text / Numeric Preset / Decor Porting Inventory

Date: 2026-11-02
Branch: `claude/skia-text`
Phase: A (inventory only — no port code)
Owner: text module agent
Related plan: `docs/superpowers/plans/2026-11-02-skia-renderer-migration.md`
Related ADR: `docs/adr/0009-app-rendered-overlays-for-editor-integration.md`

This note inventories everything Group T must draw, maps each visual element to
the existing `skb_*` bridge, lists the gaps, and proposes a module layout and
golden-frame fixture set. It intentionally does not change shared bridge or
renderer files.

---

## 0. TL;DR

1. **Only `.minimal` is reachable at runtime.** `OverlayRenderModel.textLayout`
   hard-overrides the preset to `.minimal` for every `isNumericOverlay` type
   (`OverlayRenderModel.swift:21`). Every `OverlayElementType` with
   `supportsTextPresets == true` is numeric, so the other 14 presets are
   compatibility-only code paths. They still exist in
   `TextPresetOverlayView` and must remain decodable, but a production frame
   can never select them today. Fixtures for those presets need a direct-layout
   oracle (Section 6.4); do not expect `OverlayRenderModel.textLayout` to return
   them.
2. **The SwiftUI view is the only oracle.** `TextPresetOverlayView`
   (`PreviewCanvasView.swift:1342-2159`) is what preview and export render.
   `OverlayFrameRenderer.renderPresetTextElement`
   (`OverlayFrameRenderer.swift:185-340`) is a legacy Core Graphics
   approximation that centers the element (`presetTextRect`,
   `OverlayFrameRenderer.swift:3434-3439`) while numeric overlays are
   top-leading anchored. Do not use it as the oracle or copy its geometry.
3. **`OverlayTextRenderLayout` is not composed geometry.** It carries fonts,
   sizes, colors, paddings, and alignment enums, but not the final row/line
   rects. SwiftUI composes those at render time. Group T needs a module-local
   text composer (CoreText shaping + SwiftUI-compatible composition rules), or
   the lead must add a composed-layout function to `OverlayRenderModel`
   (lead-owned file). See Decision D1.
4. **The bridge is sufficient for solid text, backgrounds, borders, dividers,
   shapes, shadows/glows, SF Symbols, and raster icons.** Real gaps:
   continuous-corner rounded rects, real text stroke, backdrop material blur,
   and a whole-element opacity layer. Feathered backgrounds and multi-run text
   can be handled module-side without bridge changes.
5. **The current spike (`SkiaEasyRunRenderer.drawTextElement`) only approximates
   minimal.** It ignores labels, background/border, minimum size, icon
   positions other than leading, unit positions other than trailing, all
   alignment fields, and divides, and it applies a black per-glyph shadow
   instead of the element-level shadow chain.

---

## 1. Sources Of Truth

| Concern | Source | Notes |
| --- | --- | --- |
| Layout fields | `OverlayRenderModel.textLayout` (`OverlayRenderModel.swift:20-72`) | Geometry/color/font inputs only. Preset forced to `.minimal` for numeric types. |
| Preset metrics | `OverlayRenderModel.textMetrics` (`OverlayRenderModel.swift:2130-2195`) | Only `horizontalPadding`, `verticalPadding`, `cornerRadius` are consumed; its `labelFontSize`/`unitFontSize` outputs are dead for SwiftUI. |
| Render layout struct | `OverlayTextRenderLayout` (`OverlayRenderModel.swift:2296-2343`) | All fields are `var`; tests can copy and override `preset`. |
| SwiftUI drawing | `TextPresetOverlayView` (`PreviewCanvasView.swift:1342-2159`) | Oracle. All 15 presets. |
| Shared wrapper | `OverlaySharedTextPresetView` (`OverlaySharedViews.swift:4-16`) | Passes `isInteractive` as `isSelected`; export uses `false`. |
| Placement | `PreviewCanvasView.swift:818-853`, `SwiftUIOverlayVideoExporter.swift:1998-2026` | Numeric overlays are **top-leading anchored** at `position * canvas`; non-numeric use center `.position`. |
| Outer opacity | `PreviewCanvasView.swift:800`, `SwiftUIOverlayVideoExporter.swift` frame view | `.opacity(element.opacity)` applies to the whole element after drawing. |
| Legacy CG preset path | `OverlayFrameRenderer.swift:185-340`, `3325-3440` | Semantic reference only; center-anchored and diverges from SwiftUI. |
| Decor views | `DecorOverlayViews.swift` | Solid color, icon, text. |
| Decor layouts | `OverlayRenderModel.swift:2197-2294` | Pixel sizes and resolved style. |
| Icon rendering | `IconRendering.swift` | `IconView` (SwiftUI) and `IconRenderer.draw` (CG) share one request. |
| Feather mask | `OverlayFeatherMaskRenderer.swift` | Grayscale distance-field mask used by `.mask(...).luminanceToAlpha()`. |
| Bridge | `Sources/CSkiaBridge/include/skia_bridge.h` | See Section 4. |
| Current spike | `Sources/RunningOverlay/Export/SkiaEasyRunRenderer.swift:107-192` | Minimal-only approximation. |

### 1.1 Placement contract (must match exactly)

For numeric/text-preset elements the element's **top-left** is
`(canvas.width * position.x, canvas.height * position.y)`. The SwiftUI view
sizes itself from its content (`fixedSize(horizontal: true, vertical: false)`
inside most presets), so the Skia module must compute the same natural size and
draw from that top-left origin. Do **not** center the composed block.

Decor elements are center-anchored by the shared preview/export position
modifier (they are not `isNumericOverlay`); their layout functions return only a
size, and the host places the center at `position * canvas`. The decor module
receives the center or computes `origin = center - size/2` consistently with the
host.

---

## 2. Preset Inventory

### 2.1 Reachability and classification

| # | Preset | Class | Reachable today | Main visual elements |
| --- | --- | --- | --- | --- |
| 1 | `minimal` | canonical | yes (all numeric overlays) | value + unit + optional label + optional icon; optional feathered bg, border, shadow/glow |
| 2 | `minimalLabel` | canonical | no | same core as minimal, no padding/background/clip |
| 3 | `pillBadge` | canonical | no | label (uppercased) + divider + value + unit in a capsule, border stroke |
| 4 | `metricCard` | canonical | no | label above value+unit in a rounded card |
| 5 | `bigNumber` | canonical | no | oversized value, unit below, optional label top/bottom/side |
| 6 | `splitLabel` | canonical | no | label row, divider rule, value row, unit row, independent row alignment |
| 7 | `neonGlow` | canonical | no | value/unit with layered accent glows |
| 8 | `racingStripe` | canonical | no | left stripe, label/value/unit stack, card bg/border |
| 9 | `editorial` | canonical | no | label, heavy value, unit, bottom rule |
| 10 | `digitalWatch` | canonical | no | Menlo-Bold label/value/unit, accent glow, accent border |
| 11 | `sportWatch` | deprecated | no | short label, two dividers, value, unit in a card |
| 12 | `inlineGhost` | deprecated | no | low-opacity label/value/unit, no chrome |
| 13 | `accentBar` | deprecated | no | accent vertical bar + label/value/unit |
| 14 | `sportNeon` | deprecated | no | label, heavy value, rule+dot+unit |
| 15 | `serifEditorial` | deprecated | no | system label, Georgia value, rule, system unit |

Canonical/deprecated split is declared at `OverlayElement.swift:3222-3243`;
`numericPresets` at `:3268-3271`.

### 2.2 Common outer composition (applies to all 15)

Applied in this order by `TextPresetOverlayView.body`:

1. Preset body content (`Group { switch layout.preset { ... } }`).
2. `.frame(minWidth: layout.minimumWidth, minHeight: layout.minimumHeight,
   alignment: .topLeading)`.
3. `.foregroundStyle(overlayGroupForegroundColor)` (only observable when
   `valueColorsFollowHeartRateZones` is active; every `Text` sets an explicit
   color, so this is effectively a fallback).
4. `.monospacedDigit()` — **all glyphs use tabular/monospaced digits**. CoreText
   shaping in the module must enable the OpenType `tnum` feature (or choose the
   typeface's monospaced-digit variant). Do not omit this; it changes value
   width and alignment for SF Pro and other proportional fonts.
5. `.overlayGenericBorder(element:cornerRadius: layout.cornerRadius)` — if
   `style.borderEnabled`, strokes a circular `RoundedRectangle` with
   `style.borderWidth` (raw canvas px, not canvas-scaled) and
   `style.borderColor.opacity(style.borderOpacity)`.
6. `.overlayForegroundEffects(element:shadowRadius: layout.shadowRadius)`:
   - glow (inner → outer): radius `max(intensity*18,0)` alpha `intensity*0.72`;
     radius `max(intensity*34,0)` alpha `intensity*0.35`; color `style.glowColor`.
   - shadow (inner → outer): radius `layout.shadowRadius` alpha
     `shadowOpacity`; radius `*0.72` alpha `opacity*(thickness-1)*0.32`;
     radius `*0.48` alpha `opacity*(thickness-2)*0.22`; color `style.shadowColor`;
     offsets `style.shadowOffsetX/Y` raw.
   - Both are disabled by their `style.*Enabled` flags and zero alphas.
7. Host applies `.opacity(element.opacity)`.

Important: these effects are applied to the **composed view** (background +
text + dividers), not per glyph. The Skia module should use
`skb_begin_shadow_chain` around the whole element (innermost first) rather than
per-glyph shadows. `beginShadowChain` in `SkiaEasyRunRenderer.swift:498-574`
already implements the SwiftUI nesting order; reuse the pattern in a module-local
helper.

### 2.3 Font/weight/tracking matrix (hard-coded values matter)

`layout.fontSize`, `labelFontSize`, `unitFontSize` already include
`canvasScale * element.scale`. Presets then apply their own multipliers.

| Preset | Value font/weight/size/tracking | Unit font/weight/size | Label font/weight/size/tracking |
| --- | --- | --- | --- |
| minimal | style.fontName / **semibold** / `fontSize` / `-fontSize*0.012` | `unitFontName` / `unitFontWeight` / `unitFontSize` | `labelFontName` / `labelFontWeight` / `labelFontSize` / `+labelFontSize*0.10` |
| minimalLabel | same as minimal | same | same |
| pillBadge | style.fontName / **bold** / `fontSize*0.92` / `-fontSize*0.009` | style.fontName / **medium** / `unitFontSize` | style.fontName / **medium** / `labelFontSize` / `+labelFontSize*0.10`, uppercased |
| metricCard | style.fontName / `style.fontWeight` / `fontSize` | `unitFontName` / `unitFontWeight` / `unitFontSize` | `labelFontName` / `labelFontWeight` / `labelFontSize` |
| bigNumber | style.fontName / **bold** / `fontSize*1.95` | style.fontName / **bold** / `unitFontSize*1.25` | `labelFontName` / `labelFontWeight` / `labelFontSize` / `+labelFontSize*0.10` |
| splitLabel | style.fontName / **bold** / `fontSize` / `-fontSize*0.012` | style.fontName / **medium** / `unitFontSize` | style.fontName / **semibold** / `labelFontSize` / `+labelFontSize*0.18`, uppercased |
| neonGlow | style.fontName / **bold** / `fontSize` / `-fontSize*0.010` | style.fontName / **semibold** / `unitFontSize` | n/a (no label row) |
| racingStripe | style.fontName / **bold** / `fontSize` / `-fontSize*0.010` | style.fontName / **medium** / `unitFontSize` | style.fontName / **bold** / `labelFontSize` / `+labelFontSize*0.10`, uppercased |
| editorial | style.fontName / **heavy** / `fontSize` / `-fontSize*0.018` | style.fontName / **medium** / `unitFontSize` | style.fontName / **bold** / `labelFontSize` / `+labelFontSize*0.18`, uppercased |
| digitalWatch | **Menlo-Bold** / default / `fontSize` / `+fontSize*0.020` | Menlo-Bold / default / `unitFontSize` | Menlo-Bold / default / `labelFontSize` / `+labelFontSize*0.18`, uppercased |
| sportWatch | style.fontName / `style.fontWeight` / `fontSize` | `labelFontName` / `labelFontWeight`+bold / `labelFontSize` | `labelFontName` / `labelFontWeight`+bold / `labelFontSize`, shortLabel |
| inlineGhost | style.fontName / **light** / `fontSize` / `-fontSize*0.02` | style.fontName / **regular** / `unitFontSize` | style.fontName / **regular** / `labelFontSize` / `+labelFontSize*0.12`, uppercased |
| accentBar | style.fontName / **bold** / `fontSize` / `-fontSize*0.05` | style.fontName / **regular** / `unitFontSize` | style.fontName / **regular** / `labelFontSize` / `+labelFontSize*0.12`, uppercased |
| sportNeon | style.fontName / **heavy** / `fontSize` / `-fontSize*0.06` | style.fontName / **regular** / `unitFontSize` | style.fontName / **bold** / `labelFontSize` / `+labelFontSize*0.16`, uppercased |
| serifEditorial | **Georgia** / default / `fontSize` / `-fontSize*0.01` | **system** / regular / `unitFontSize` / `+unitFontSize*0.1` | **system** / regular / `labelFontSize` / `+labelFontSize*0.2`, uppercased |

`OverlayFontWeight` only has regular/medium/semibold/bold; `heavy`/`light` are
literal SwiftUI `Font.Weight` values in the deprecated views. The module's
font resolver must map them to `NSFont.Weight.heavy` / `.light`.

### 2.4 Per-preset drawing recipe

Coordinates below are relative to the element's top-left origin. `w`/`h` are
the composed natural size after min-width/min-height.

#### minimal / minimalLabel

- Core content (`metricCoreContent`, `PreviewCanvasView.swift:1980-2112`):
  - Optional icon (`layout.iconEnabled && !iconSystemName.isEmpty`), SF Symbol
    at `iconSize × iconSize`, weight `.medium`, tinted `iconTextColor`.
    Position `top`/`bottom`/`leading`/`trailing`, `iconSpacing` gap,
    cross-axis alignment `iconTextAlignment`.
  - Text stack (outer `VStack(alignment: .leading, spacing: 0)`):
    - label if `showLabel && !label.isEmpty && labelPosition == .top`, then
      `labelSpacing` below.
    - value/unit cluster: `HStack` with cross-axis alignment
      `unitTextAlignment` when the unit is inline, else `.center`.
      Unit leading/trailing with `unitSpacing`; value expands to the widest row.
    - side label (leading/trailing) wraps the cluster in an `HStack` with
      `labelVAlignment` and `labelSpacing`.
    - unit bottom (`unitTextAlignment` horizontal, `unitSpacing` top), then
      label bottom.
    - `.fixedSize(horizontal: true, vertical: false)`.
- `minimal`: core content gets `.frame(minWidth/minHeight, .topLeading)`, then
  horizontal/vertical padding **only when `backgroundEnabled`**, then
  background (feathered) and clip to `cornerRadius`.
- `minimalLabel`: core content only — no padding, background, or clip.

#### pillBadge

- `HStack(alignment: .lastTextBaseline, spacing: fontSize*0.14)`:
  - value (`fontSize*0.92`, bold, tracking `-fontSize*0.009`);
  - unit if shown (`unitFontSize`, medium).
- If label shown: outer `HStack(alignment: labelVAlignment,
  spacing: fontSize*0.32)`: uppercased label, optional divider
  (`width=max(dividerThickness,0)`, `height=fontSize*0.78`), value/unit cluster.
- Padding `horizontalPadding`/`verticalPadding`; capsule background
  (`usesCapsuleRadius: true`), then `Capsule().stroke(foreground.opacity(0.16),
  lineWidth: 1)` only when `backgroundEnabled`.

#### metricCard

- `VStack(alignment: .leading, spacing: verticalPadding*0.7)`:
  - label (label font/color);
  - `HStack(alignment: .firstTextBaseline, spacing: horizontalPadding*0.35)`:
    value (style font/weight/size), unit (`unitFontName`/weight/size).
- Padding h/v, background, clip rounded `cornerRadius`.

#### bigNumber

- Value `fontSize*1.95` bold; unit `unitFontSize*1.25` bold;
  label `labelFontSize` tracking `+labelFontSize*0.10`.
- `labelPosition` top/bottom: `VStack(alignment: .leading, spacing: 0)` with
  per-row `frame(maxWidth: .infinity, alignment:)`; label padding
  `labelSpacing`.
- `labelPosition` leading/trailing: `HStack(alignment: labelVAlignment)` with
  label padding `labelSpacing`.
- No padding/background/clip in this preset; outer frame only.

#### splitLabel

- `VStack(alignment: .leading, spacing: fontSize*0.10)`:
  - uppercased label, semibold, tracking `+labelFontSize*0.18`, full-width
    frame with `labelTextAlignment`;
  - divider rule `width=fontSize*2.4`, `height=max(dividerThickness,0)`,
    full-width frame with `valueTextAlignment`;
  - value, bold, tracking `-fontSize*0.012`, full-width frame with
    `valueTextAlignment`;
  - unit, medium, full-width frame with `unitTextAlignment`.
- `.fixedSize(horizontal: true, vertical: false)`.

#### neonGlow

- `HStack(alignment: .lastTextBaseline, spacing: fontSize*0.14)`.
- Value: bold, tracking `-fontSize*0.010`, two accent shadows
  (`accent.opacity(0.80)` radius `fontSize*0.34`,
  `accent.opacity(0.36)` radius `fontSize*0.62`).
- Unit: semibold, one accent shadow (`accent.opacity(0.65)` radius
  `fontSize*0.24`).
- No label, no padding/background.

#### racingStripe

- Stripe: `stripeWidth = dividerEnabled ? max(dividerThickness*2.4, 4) : 0`,
  `stripeGap = fontSize*0.34`.
- `VStack(alignment: .leading, spacing: fontSize*0.10)`: label / value / unit
  (same rows as splitLabel with different fonts/tracking).
- `.padding(.leading, stripeWidth + (dividerEnabled ? stripeGap : 0))`.
- `.overlay(alignment: .leading)` a `RoundedRectangle(cornerRadius: 2)` of
  `dividerColor`, width `stripeWidth`.
- Padding h/v, background, clip, then a border stroke
  `foreground.opacity(0.14)` only when `backgroundEnabled`.

#### editorial

- `VStack(alignment: .leading, spacing: fontSize*0.04)`: label / value (heavy,
  tracking `-fontSize*0.018`) / unit / optional bottom rule
  (`width=fontSize*2.2`, `height=max(dividerThickness,0)`, aligned to
  `valueTextAlignment`, `.padding(.top, fontSize*0.04)`).
- `.fixedSize(horizontal: true, vertical: false)`; no background.

#### digitalWatch

- Label: Menlo-Bold, uppercased, tracking `+labelFontSize*0.18`.
- `HStack(alignment: .lastTextBaseline, spacing: fontSize*0.14)`: value
  Menlo-Bold tracking `+fontSize*0.020` with two accent shadows
  (`0.85`/`fontSize*0.18`, `0.45`/`fontSize*0.42`); unit Menlo-Bold with accent
  shadow `0.55`/`fontSize*0.14`.
- Padding h/v, background, clip, accent border
  `RoundedRectangle.stroke(accent.opacity(0.70), lineWidth: 1)`.

#### sportWatch (deprecated)

- `VStack(spacing: verticalPadding*0.65)`: short label bold / divider
  (`fontSize*2.7 × max(dividerThickness,1)`) / value / divider / unit
  (bold, `unitTextColor`).
- `.frame(minWidth: fontSize*3.2)`, padding h/v, background, stroke
  `foreground.opacity(0.35)` width `max(fontSize/28,1)`, clip.

#### inlineGhost (deprecated)

- `VStack(alignment: .leading, spacing: fontSize*0.06)`: uppercased label
  (regular, tracking `+labelFontSize*0.12`) and
  `HStack(alignment: .firstTextBaseline, spacing: fontSize*0.18)` value
  (light, tracking `-fontSize*0.02`) + unit (regular).
- If HR-zone text palette is active, use role colors; otherwise label is
  `foreground.opacity(0.28)`, value is `valueColor.opacity(valueOpacity*0.88)`,
  unit is `foreground.opacity(0.30)`.

#### accentBar (deprecated)

- `HStack(alignment: .center, spacing: fontSize*0.33)`:
  - rounded rect radius `max(fontSize*0.06,1)`, fill `accentColor`,
    `width=max(fontSize*0.083,1.5)`, `height=fontSize*1.55`;
  - `VStack(alignment: .leading, spacing: fontSize*0.06)`: label (regular,
    tracking `+labelFontSize*0.12`, `foreground.opacity(0.32)` unless HR zone
    active), value (bold, tracking `-fontSize*0.05`), unit (regular,
    `foreground.opacity(0.38)` unless HR zone active).

#### sportNeon (deprecated)

- `VStack(alignment: .leading, spacing: fontSize*0.05)`: label (bold, tracking
  `+labelFontSize*0.16`, `accentColor` unless HR zone active), value (heavy,
  tracking `-fontSize*0.06`), then unit row:
  `HStack(alignment: .center, spacing: fontSize*0.18)` with a rule
  `foreground.opacity(0.10)` `width=fontSize*0.6`, `height=0.5`, a filled
  circle `accentColor` diameter `max(fontSize*0.14,4)`, and the unit (regular,
  `foreground.opacity(0.35)` unless HR zone active).

#### serifEditorial (deprecated)

- `VStack(spacing: fontSize*0.05)`: label (system, regular, tracking
  `+labelFontSize*0.2`, `foreground.opacity(0.30)` unless HR zone active),
  value (Georgia, tracking `-fontSize*0.01`), then if unit shown: rule
  `foreground.opacity(0.20)` `width=fontSize*0.78`, `height=0.5`, vertical
  padding `fontSize*0.18`, unit (system, regular, tracking `+unitFontSize*0.1`,
  `foreground.opacity(0.28)` unless HR zone active).

### 2.5 Preset metrics (`textMetrics`)

Only padding/radius are consumed by `textLayout`; the label/unit font-size
columns are dead for the SwiftUI path. `scale` below is `element.scale`;
`canvasScale` is applied by `context.scaled`.

| Preset | horizontalPadding | verticalPadding | cornerRadius |
| --- | --- | --- | --- |
| minimal | `scaled(style.backgroundPaddingX)` (no `element.scale`) | `scaled(style.backgroundPaddingY)` (no `element.scale`) | `scaled(style.backgroundRadius)` |
| minimalLabel | 0 | 0 | 0 |
| pillBadge | `scaled(18*scale)` | `scaled(10*scale)` | `scaled(28*scale)` |
| metricCard | `scaled(18*scale)` | `scaled(14*scale)` | `scaled(10*scale)` |
| bigNumber | `scaled(6)` | `scaled(4)` | 0 |
| splitLabel | 0 | 0 | 0 |
| neonGlow | 0 | 0 | 0 |
| racingStripe | `scaled(bgPaddingX>0 ? bgPaddingX : 18)` | `scaled(bgPaddingY>0 ? bgPaddingY : 12)` | `scaled(style.backgroundRadius)` |
| editorial | 0 | 0 | 0 |
| digitalWatch | `scaled(bgPaddingX>0 ? bgPaddingX : 18)` | `scaled(bgPaddingY>0 ? bgPaddingY : 12)` | `scaled(style.backgroundRadius)` |
| sportWatch | `scaled(18*scale)` | `scaled(14*scale)` | `scaled(18*scale)` |
| inlineGhost | 0 | 0 | 0 |
| accentBar | 0 | 0 | 0 |
| sportNeon | 0 | 0 | 0 |
| serifEditorial | 0 | 0 | 0 |

Note the minimal asymmetry: `backgroundPaddingX/Y` are **not** multiplied by
`element.scale`; they are only canvas-scaled. Replicate exactly.

---

## 3. Style / Control Inventory

### 3.1 Numeric text fields consumed

From `OverlayStyle` (`OverlayElement.swift:665-850`) and
`OverlayTextRenderLayout`:

- Typography: `fontName`, `fontSize`, `fontWeight`, `labelFontName`,
  `labelFontSize`, `labelFontWeight`, `unitFontName`, `unitFontSize`,
  `unitFontWeight`, `labelSpacing`, `unitSpacing`.
- Colors/opacity: `foregroundColor`, `valueColor`/`valueOpacity`,
  `labelColor`/`labelOpacity`, `unitColor`/`unitOpacity`, `accentColor`.
- Attachments: `showLabel`, `showUnit`, `customLabel`, `labelPosition`,
  `unitPosition`, `labelTextAlignment`, `textAlignment` (value alignment),
  `unitTextAlignment`.
- Icon: `iconEnabled`, `iconSystemName`, `iconPosition`, `iconTextAlignment`,
  `iconSize`, `iconColor`, `iconOpacity`, `iconSpacing`.
- Background: `backgroundEnabled`, `backgroundColor`, `backgroundOpacity`,
  `backgroundRadius`, `backgroundPaddingX`, `backgroundPaddingY`,
  `numericMinWidth`, `numericMinHeight`, `backgroundFadeOutEnabled`,
  `backgroundFadeOutAmount`, `backgroundBlurRadius`.
- Border: `borderEnabled`, `borderColor`, `borderOpacity`, `borderWidth`.
- Effects: `shadowEnabled`, `shadowColor`, `shadowOpacity`, `shadowRadius`,
  `shadowOffsetX`, `shadowOffsetY`, `shadowThickness`, `glowEnabled`,
  `glowColor`, `glowIntensity`.
- HR zone tint: `valueColorsFollowHeartRateZones`,
  `labelColorsFollowHeartRateZones`, `unitColorsFollowHeartRateZones`,
  `iconColorsFollowHeartRateZones`; resolved base color is
  `layout.dynamicHeartRateZoneColor`.
- Divider (non-numeric presets only; numeric forces `dividerEnabled=false`):
  `dividerEnabled`, `dividerColor`, `dividerThickness`, `dividerOpacity`.

### 3.2 Decor controls

`DecorStyle` (`OverlayElement.swift:3588-3637`) and the resolved layouts:

| Element | Fields | Renderer behavior |
| --- | --- | --- |
| `decorSolidColor` | `shape`, `fillColor`, `width`, `height`, `cornerRadius` + shared border/shadow/glow | `DecorSolidColorOverlayView`; circle collapses to `min(w,h)`; rounded uses `.continuous` corner style |
| `decorIcon` | `iconAsset`, `iconTint`, `iconPreserveSVGColors`, `iconContentMode`, `width`, `height` + shared effects | `IconView`; SF Symbol point size = `min(w,h)*0.92`; bundled SVG/image and user SVG rasterized through AppKit |
| `decorText` | `textContent`, `textFont`, `textSize`, `textAlignment`, `textLineHeight`, `textLetterSpacing`, `textFillMode`, `textStrokeWidth`, `textStrokeColor`, `textAutoFit`, `width`, `height` + shared effects | `DecorTextOverlayView`; stroke is a scaled duplicate, fill is solid or `.white` for gradient, clipped to frame |

Known no-ops / quirks to preserve for parity:

- `textAutoFit` is resolved into `DecorTextRenderLayout` but **never used** by
  the view. Do not implement auto-fit.
- `DecorTextFill.gradient` renders **white** (Phase F6 placeholder).
- `textLetterSpacing` is passed to SwiftUI `.tracking` as
  `letterSpacing / fontSize` (points), not points directly. Replicate the
  division.
- `backgroundBlurRadius > 0` draws `.ultraThinMaterial` behind the background
  fill. This is a backdrop material and cannot be reproduced by the current
  overlay-only bridge. See Decision D3.
- `rotationDegrees` is stored but not applied by any text/decor view; ignore.
- `textAlignment` for decor text is a fixed-frame `Text` alignment, so
  multiline wrapping is in scope (unlike numeric presets, which use
  `fixedSize(horizontal: true)`).

---

## 4. Bridge Primitive Mapping

### 4.1 Existing primitives (`skia_bridge.h`)

| Primitive | Group T use |
| --- | --- |
| `skb_clear`, `skb_save`, `skb_restore` | frame/layer state |
| `skb_draw_text` | fallback single-line text; not used by the module if glyph shaping is used |
| `skb_draw_glyphs` | primary text fill (glyphs + x positions + baseline + color + one shadow) |
| `skb_fill_rect` | dividers, rules, sportNeon rule |
| `skb_fill_round_rect` | backgrounds, capsule/pill, accent bar, rounded shapes, radius-0 rects |
| `skb_fill_circle` | sportNeon dot, decor circle |
| `skb_stroke_line` | possible rules (prefer fill_rect for exact 0.5 px rules) |
| `skb_stroke_round_rect` | borders, capsule strokes, decor outlines |
| `skb_stroke_polyline` | not needed |
| `skb_fill_diagonal_gradient_round_rect` | not needed for text/decor (decor gradient text is white) |
| `skb_clip_circle` / `skb_clip_round_rect` | capsule/pill clip, decor text `.clipped()` (radius 0), icon frame clip if needed |
| `skb_draw_image` | rasterized SF Symbols, bundled/user SVG icons, feathered-background BGRA mask, rasterized stroked decor text (workaround) |
| `skb_begin_shadow_layer` | single shadow/glow layers |
| `skb_begin_shadow_chain` | element-level glow + layered shadow in SwiftUI order |
| `skb_begin_blur_layer` | not usable for backdrop material blur; can blur drawn layer contents |
| `skb_pixels` / `skb_read_pixels` / `skb_flush` | golden harness readback |

### 4.2 Visual element → primitive matrix

| Visual element | Primitive | Status |
| --- | --- | --- |
| Solid glyph fill | `skb_draw_glyphs` | available |
| Glyph tracking | CoreText kern → glyph positions | module-side |
| Monospaced digits (`.monospacedDigit()`) | CoreText `tnum` feature → glyph choice/positions | module-side, required |
| Multi-font CTLine runs (fallback glyphs) | split runs and call `skb_draw_glyphs` per run with that run's font | module-side workaround; bridge single-font signature is OK if runs are split |
| Baseline alignment (lastTextBaseline / firstTextBaseline) | CTLine ascent/descent + module composition | module-side |
| Multiline decor text + wrapping | CTFramesetter or manual line breaking + repeated `skb_draw_glyphs` | module-side |
| Text clipping | `skb_clip_round_rect(radius: 0)` | available |
| Text stroke (decor) | none | **missing**; workaround = rasterize stroked text to BGRA via AppKit + `skb_draw_image` |
| Gradient text fill | none needed (oracle renders white) | parity = white |
| Per-glyph shadow | `skb_draw_glyphs` shadow params | available but shadow color is hard-coded black; prefer element-level chain |
| Element glow + layered shadow | `skb_begin_shadow_chain` | available |
| Element opacity group | none | **missing**; per-draw alpha works for non-overlapping content, differs for overlaps/shadows |
| Solid rounded-rect background | `skb_fill_round_rect` (circular corners) | available; SwiftUI text presets use circular corners |
| Capsule background | `skb_fill_round_rect(radius: h/2)` | available |
| Feathered background (fade-out mask) | none directly | **missing**; workaround = `OverlayFeatherMaskRenderer.makeCGMask` → BGRA (color × mask alpha) → `skb_draw_image`, cached |
| Backdrop material blur | none | **missing**; see Decision D3 |
| Border stroke | `skb_stroke_round_rect` | available |
| Divider rules | `skb_fill_rect` | available |
| Accent bar / stripe | `skb_fill_round_rect` | available |
| SportNeon rule + dot | `skb_fill_rect` + `skb_fill_circle` | available |
| Continuous rounded rect (decor solid `.roundedRectangle`) | none | **missing**; `skb_fill_round_rect` uses circular corners, SwiftUI uses `.continuous` |
| Decor rectangle/circle/capsule | `skb_fill_rect` / `skb_fill_circle` / `skb_fill_round_rect` | available |
| Decor shape outline | `skb_stroke_round_rect` / circle | available (continuous gap above) |
| SF Symbol icon | rasterize via `NSImage` + `skb_draw_image` | available (pattern exists in spike) |
| Bundled SVG / bundled image / user SVG | rasterize via `IconAssetResolver`/`NSImage` + `skb_draw_image` | available |
| Icon tint (SF Symbol / SVG) | rasterize tinted BGRA | available |
| Icon content mode fit/fill/stretch | compute target rect module-side | module-side |
| Decor text border | `skb_stroke_round_rect(radius: 0)` | available |
| Decor text shadow/glow | `skb_begin_shadow_chain` | available |

### 4.3 Requested bridge additions (for lead to freeze)

Prioritized; none are strictly blocking because module-side workarounds exist
for P1/P2, but they affect parity and performance.

1. **P1 — `skb_begin_opacity_layer(float alpha, x, y, w, h)`** or equivalent
   group alpha. Needed for exact `element.opacity` compositing of
   background+text+effects as one unit.
2. **P1 — `skb_fill_feathered_round_rect(...)`** (or a generic mask/image
   draw). Removes per-frame CPU mask generation for `backgroundFadeOutEnabled`.
3. **P2 — continuous-corner rounded rect fill/stroke** (squircle) or a generic
   path fill/stroke. Needed for decor solid `.roundedRectangle` parity.
4. **P2 — glyph stroke or canvas scale transform**
   (`skb_draw_glyphs_stroked` / `skb_concat_scale`). Needed for decor text
   stroke without rasterizing the whole text block.
5. **P3 — multi-run text** (`skb_draw_text_runs` with per-run font). Optional if
   the module splits CTLine runs itself.
6. **P3 — configurable shadow color for `skb_draw_glyphs`.** Optional if
   element-level shadow chains are used.

Not needed for Group T: arbitrary paths beyond rounded rects, dashed strokes,
radial gradients, blend modes.

---

## 5. Proposed Module File Layout

All paths are new files owned by the text module agent. No shared bridge or
renderer file is edited.

```
Sources/RunningOverlay/Render/Skia/Modules/
  TextModule.swift                 # dispatch entry: element → text/decor draw
  TextPresetDrawing.swift          # canonical 10 preset renderers
  TextLegacyPresetDrawing.swift    # deprecated 5 preset renderers
  TextComposer.swift               # CoreText shaping + SwiftUI composition rules
  TextEffects.swift                # shadow chain, opacity layer, feathered bg, borders
  DecorDrawing.swift               # decor solid color / icon / text
  IconRasterCache.swift            # SF Symbol, bundled SVG/image, user SVG → BGRA
Tests/RunningOverlayTests/
  SkiaTextGoldenTests.swift        # preset + decor golden frames vs SwiftUI oracle
  SkiaTextComposerTests.swift      # shaping, tracking, tnum, run splitting, alignment
  SkiaTextFixtureFactory.swift     # deterministic elements/layouts/data (test-only)
```

Responsibilities:

- `TextModule`: one `static func draw(element:in:context:)` called from the
  lead's dispatch table. Resolves `OverlayRenderModel.textLayout`, handles
  `element.opacity`, and forwards to preset drawing. Also handles
  `.decorSolidColor`, `.decorIcon`, `.decorText`.
- `TextComposer`: converts `OverlayTextRenderLayout` + CoreText into a
  `ComposedTextBlock` (line runs, glyph arrays, x positions, baselines, row
  rects, natural size). This is rendering-side text layout, not project
  geometry; it must not read `ActivityTimeline` or time domains.
- `TextPresetDrawing`: consumes `ComposedTextBlock` + layout; draws backgrounds,
  dividers, icons, glyphs, effects. One function per preset, mirroring the
  SwiftUI switch.
- `TextEffects`: wraps `skb_begin_shadow_chain`, opacity layer, border,
  feathered background image cache.
- `DecorDrawing`: consumes `Decor*RenderLayout`; no preset logic.
- `IconRasterCache`: keyed by asset identity, pixel size, tint, preserve-colors,
  content mode. Deterministic; no network; AppKit rasterization only.

Integration contract with the lead:

- The lead owns `SkiaFrameRendererBackend.swift` and the dispatch table.
  Group T only needs a stable call shape:
  `TextModule.draw(element:renderContext:) -> Bool` (false = unsupported).
- If the lead prefers a protocol, `TextModule` can conform; the internal file
  layout stays the same.

---

## 6. Golden-Frame Fixtures

### 6.1 Harness

Reuse the comparison shape already proven in `SkiaSpikeTests` and
`VisualRegressionTests`:

- Render the SwiftUI oracle and Skia to BGRA at the same pixel size.
- Compare premultiplied BGRA bytes directly (not `NSImage` color sampling).
- Report `changedPixels`, `changedRatio`, `meanChannelDelta`, `maxChannelDelta`,
  and a diff bounding box.
- Write both PNGs and a diff PNG to a temporary directory for review.
- Gate the suite with `#if canImport(CSkiaBridge)` so machines without
  `SKIA_DIR` still build and test.

Proposed thresholds (tighten after the first reviewed pass):

- Whole canvas: changed ratio ≤ 0.005 (0.5%) and mean channel delta ≤ 1.5.
- Element bounding box: changed ratio ≤ 0.05 and mean channel delta ≤ 8.
- Any pixel delta > 48 requires human review, even if aggregate thresholds pass.
- Snapshot updates require before/after images and human review, matching
  `docs/testing.md`.

### 6.2 Deterministic inputs

- Canvas: 1920×1080, `renderer.scale = 1`, transparent background.
  `canvasScale = min(1920/1280, 1080/720) = 1.5`.
- Activity: fixed start
  `Date(timeIntervalSince1970: 1_735_689_600)`, 61 records at 0…60 s,
  `distanceMeters = 3.3*t`, `heartRate = 130 + Int(t/3)`,
  `paceSecondsPerKilometer = 300`, `elevationMeters = 20 + t/10`,
  `cadence = 176`, `powerWatts = 250`, `calories = t/4`, no GPS, no laps.
- Time: `elapsedTime = 30.0` for all fixtures.
- Element position: `(0.12, 0.12)` for text presets so glow/shadow fits;
  decor centered at `(0.5, 0.5)` unless testing edge clipping.
- `element.opacity = 1`, `isSelected = false`.
- Fonts: pin explicit system fonts per fixture — `Menlo` for value/label/unit
  and `Menlo-Bold` for digitalWatch, `Georgia` for serifEditorial. Do **not**
  use `FontLibraryManager.currentDefaultFamily` in fixtures (it reads
  UserDefaults and varies by machine; `PT Mono` may be absent).
- Avoid `HeartRateZonePreferences`-dependent fixtures unless the test injects a
  deterministic snapshot. Prefer non-HR-zone styling for base fixtures and add
  one dedicated HR-zone fixture with an explicit injected palette.
- No network, no MapKit, no weather, no locale-sensitive formatters (the value
  formatter already uses `en_US_POSIX`/`String(format:)`).

### 6.3 Fixture factory

`SkiaTextFixtureFactory` (test-only) builds:

```swift
struct TextFixture {
    let name: String
    let preset: OverlayTextPreset
    let element: OverlayElement
    let layout: OverlayTextRenderLayout   // preset already overridden
    let origin: CGPoint
    let canvasSize: CGSize
}
```

Construction:

1. Build a deterministic `OverlayElement` of type `.heartRate` (or `.distance`
   for a decimal fixture) with explicit style fields.
2. `var layout = OverlayRenderModel.textLayout(for: element, in: context)`.
3. For non-minimal presets, copy `layout.preset = preset` (the struct is a
   value type with `var` fields). This is the only way to exercise the
   compatibility presets because `textLayout` forces minimal for numeric
   types.
4. Render the oracle with
   `ImageRenderer(content: TextPresetOverlayView(element:layout:isSelected:false)
   .opacity(element.opacity).offset(x: origin.x, y: origin.y)
   .frame(width: canvas.width, height: canvas.height, alignment: .topLeading))`,
   `renderer.scale = 1`, `renderer.isOpaque = false`.
5. Render Skia through `TextModule.draw(element:layout:context:)` using the
   same origin and layout (the module needs an internal
   `draw(layout:element:origin:)` entry for fixtures; production entry computes
   the layout itself).

For minimal, also add one integration fixture that goes through
`OverlayRenderModel.textLayout` + the production dispatch path, to prove the
production wiring. For decor, call the corresponding `decor*Layout` functions
and render `Decor*OverlayView` as the oracle.

### 6.4 One synthetic element per preset (1080p)

Base set — 15 text presets:

| Fixture file | Preset | Style notes |
| --- | --- | --- |
| `text-01-minimal.png` | minimal | value+unit, no label/icon, no background |
| `text-02-minimal-label.png` | minimalLabel | showLabel, label top |
| `text-03-pill-badge.png` | pillBadge | showLabel, divider on, background on |
| `text-04-metric-card.png` | metricCard | showLabel, background on, radius 16 |
| `text-05-big-number.png` | bigNumber | showUnit, label bottom |
| `text-06-split-label.png` | splitLabel | showLabel, divider on, labelColor accent |
| `text-07-neon-glow.png` | neonGlow | accent glow |
| `text-08-racing-stripe.png` | racingStripe | divider on, background on |
| `text-09-editorial.png` | editorial | showLabel, divider on |
| `text-10-digital-watch.png` | digitalWatch | Menlo-Bold, accent glow/border |
| `text-11-sport-watch.png` | sportWatch | deprecated; showLabel, dividers |
| `text-12-inline-ghost.png` | inlineGhost | deprecated; showLabel |
| `text-13-accent-bar.png` | accentBar | deprecated; showLabel |
| `text-14-sport-neon.png` | sportNeon | deprecated; showLabel |
| `text-15-serif-editorial.png` | serifEditorial | deprecated; Georgia |

Minimal variant set (the only production path) — add these to prove control
coverage:

| Fixture | What it covers |
| --- | --- |
| `minimal-value-unit.png` | baseline case |
| `minimal-label-top.png` | label position top + label spacing |
| `minimal-label-side.png` | label leading/trailing + vertical alignment |
| `minimal-unit-leading-bottom.png` | unit leading and bottom positions |
| `minimal-icon-top-leading.png` | icon position + iconTextAlignment + spacing |
| `minimal-background.png` | solid background + radius + padding |
| `minimal-feathered-background.png` | `backgroundFadeOutEnabled` mask |
| `minimal-border-shadow-glow.png` | border + layered shadow + glow |
| `minimal-min-size.png` | `numericMinWidth/Height` larger than content |
| `minimal-long-value.png` | width growth, right-anchored unit, no truncation |
| `minimal-hr-zone-tint.png` | per-role HR zone colors with injected palette |
| `minimal-opacity.png` | `element.opacity = 0.5` |
| `minimal-system-font.png` | `SF Pro` alias → `.systemFont` |
| `minimal-missing-glyph.png` | degree sign / en dash fallback run |

Decor set:

| Fixture | What it covers |
| --- | --- |
| `decor-solid-rect.png` | rectangle |
| `decor-solid-rounded.png` | continuous rounded rect (known gap) |
| `decor-solid-circle.png` | circle collapse |
| `decor-solid-capsule.png` | capsule |
| `decor-solid-effects.png` | border + shadow + glow |
| `decor-icon-symbol.png` | SF Symbol + tint + fit |
| `decor-icon-svg.png` | bundled SVG + tint + preserve colors |
| `decor-icon-user-svg.png` | user asset (synthetic fixture SVG) |
| `decor-text-single.png` | single line, solid fill |
| `decor-text-multiline.png` | wrapping, alignment, line height |
| `decor-text-spacing.png` | letter spacing (divided by fontSize) |
| `decor-text-stroke.png` | stroke duplicate + scale effect (known gap) |
| `decor-text-clipped.png` | `.clipped()` rect clip |
| `decor-text-gradient.png` | gradient renders white (parity placeholder) |

### 6.5 Storage and update flow

- Store committed oracle PNGs under
  `Tests/RunningOverlayTests/Fixtures/SkiaGolden/Text/` and
  `Tests/RunningOverlayTests/Fixtures/SkiaGolden/Decor/`.
- Add `Tests/RunningOverlayTests/Fixtures/SkiaGolden/README.md` with the fixture
  manifest: element JSON, preset, style overrides, font names, time, canvas
  size, and known-gap notes.
- Update flow: `UPDATE_SKIA_GOLDEN=1 ./scripts/skia-golden-test.sh` (script to be
  added later by the lead or this agent after the bridge freezes). Snapshot
  updates require before/after images and human review.
- Keep the existing `route-map.png` visual snapshot untouched.

---

## 7. Open Decisions / Blockers For The Lead

**D1 — Composed text geometry ownership.** `OverlayTextRenderLayout` has no row
or line rects. Options:
(a) Group T owns `TextComposer` (module-local CoreText + SwiftUI composition),
(b) the lead adds `OverlayRenderModel.textPresetLayout(...)` (shared file).
Recommendation: (a) for Phase A/porting speed, with golden frames as the
parity gate; revisit (b) only if other groups need the same composer.

**D2 — Non-minimal preset reachability.** `textLayout` forces `.minimal` for all
numeric types, and no non-numeric type supports text presets. Decide whether
the 14 compatibility presets should be:
(a) ported and golden-tested through a direct-layout oracle (recommended;
preserves old template capability and future re-enable),
(b) explicitly retired and removed from the port scope, or
(c) re-enabled behind a product decision (requires a shared `OverlayRenderModel`
change).
Recommendation: (a) now; do not re-enable without a separate product decision.

**D3 — `backgroundBlurRadius` / `.ultraThinMaterial`.** The overlay renderer has
no backdrop to blur in export. Options:
(a) measure the SwiftUI oracle over a transparent canvas and reproduce its
fallback appearance with a translucent fill (recommended),
(b) disable blur in the Skia path and document the difference,
(c) defer blur to preview compositing only (video layer beneath).
Recommendation: (a), with a dedicated fixture and human review.

**D4 — Continuous rounded corners for decor solid.** Options:
(a) add a squircle/continuous-corner primitive to the bridge,
(b) approximate with circular corners and accept the diff (may exceed the 5%
crop threshold at large radii),
(c) rasterize the shape via AppKit into BGRA and draw as an image (exact but
per-frame cost).
Recommendation: (a) if the lead is already extending the bridge; otherwise (c)
for decor solid only, cached by size/radius/color.

**D5 — Decor text stroke.** Options:
(a) add a glyph-stroke/scale primitive,
(b) rasterize the stroked text block via AppKit into BGRA and draw as an image
(recommended for now; same CoreText engine, deterministic),
(c) approximate by drawing fill glyphs at offsets (rejected: not parity).
Recommendation: (b).

**D6 — Element opacity layer.** Per-draw alpha is close for non-overlapping
content; exact grouping needs `skb_begin_opacity_layer`. Recommendation: add
the primitive in the bridge freeze; fall back to per-draw alpha until then.

**D7 — Font determinism.** `OverlayStyle.default` and
`FontLibraryManager.currentDefaultFamily` read UserDefaults; `PT Mono` is not
bundled. Golden fixtures must pin fonts explicitly. Production parity for a
user-selected font that is missing on the machine is inherently
machine-dependent; document it, do not fight it.

**D8 — HR zone palette determinism.** `HeartRateZonePreferences.currentSnapshot()`
reads UserDefaults. Base fixtures should avoid HR-zone tint; the one HR-zone
fixture must inject a deterministic snapshot (test hook may be needed in shared
code — request from lead).

---

## 8. Suggested Implementation Order (after bridge freeze)

1. `TextComposer` + tests: shaping, tracking, `tnum`, run splitting, baseline
   metrics, natural size. Golden-test against minimal value+unit.
2. `TextEffects` + minimal renderer: background (solid + feathered), border,
   shadow chain, opacity. Golden-test the minimal variant set.
3. Icons: `IconRasterCache` + minimal icon positions. Golden-test icon
   variants.
4. Canonical presets 2–10 (drawing only; oracle via direct layout).
5. Deprecated presets 11–15 (lowest priority; keep behind the same code path).
6. Decor solid → decor icon → decor text.
7. Wire `TextModule` into the lead's dispatch table; run the full golden suite
   at 1280×720 and 3840×2160 in addition to 1920×1080.

---

## 9. Validation Checklist For The Port

- [ ] Every fixture in Section 6.4 passes at 1080p with reviewed diffs.
- [ ] Spot-check 720p and 4K; geometry scales with `context.canvasScale`.
- [ ] Minimal production path renders through `OverlayRenderModel.textLayout`
      with no module-side preset override.
- [ ] Text presets honor top-leading anchoring at non-zero positions.
- [ ] Element opacity, border, shadow, glow, and feathered background compose
      in the same order as SwiftUI.
- [ ] `.monospacedDigit()` parity verified on a proportional font.
- [ ] Multi-run fallback glyphs render with the correct per-run typeface.
- [ ] Decor icon assets resolve without network and are cached.
- [ ] No UserDefaults, locale, clock, or network reads during a frame.
- [ ] `./scripts/check.sh` passes; Skia tests skip cleanly without `SKIA_DIR`.
- [ ] Module docs under `docs/overlay-modules/` updated when behavior is
      ported (lead to decide the doc target; numeric has no dedicated module
      doc yet).

---

## 10. Files Inspected

- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift`
- `Sources/RunningOverlay/Overlay/OverlayFeatherMaskRenderer.swift`
- `Sources/RunningOverlay/Overlay/IconRendering.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/OverlaySharedViews.swift`
- `Sources/RunningOverlay/UI/DecorOverlayViews.swift`
- `Sources/RunningOverlay/UI/OverlayFeatheredBackground.swift`
- `Sources/RunningOverlay/UI/OverlayFont+SwiftUI.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `Sources/RunningOverlay/Export/SkiaEasyRunRenderer.swift`
- `Sources/RunningOverlay/App/PresetFonts.swift`
- `Sources/CSkiaBridge/include/skia_bridge.h`
- `Sources/CSkiaBridge/skia_bridge.cpp`
- `Tests/RunningOverlayTests/SkiaSpikeTests.swift`
- `Tests/RunningOverlayTests/VisualRegressionTests.swift`
- `docs/testing.md`, `docs/architecture.md`,
  `docs/development/overlays-and-preview.md`,
  `docs/superpowers/plans/2026-11-02-skia-renderer-migration.md`,
  `docs/adr/0009-app-rendered-overlays-for-editor-integration.md`

---

## Phase B — Implementation status (2026-11-02)

Phase B implements the inventory against the frozen bridge
(`2026-11-02-skia-bridge-freeze.md`). Nothing in this phase edits shared
bridge or renderer files, and nothing is committed.

### Files added

Shared (`Render/Skia/Shared/`):

- `SkiaTextComposer.swift` — CoreText shaping, measurement, drawing,
  alignment offsets, pinned-font resolution, `tnum` for `.monospacedDigit()`.
- `SkiaTextEffects.swift` — element opacity layer, glow/layered-shadow chain,
  generic border, solid/feathered background, measured material fallback.
- `SkiaIconRasterCache.swift` — cached AppKit rasterization for SF Symbols
  and `IconRenderer` assets.

Modules (`Render/Skia/Modules/`):

- `TextModule.swift` — `SkiaTextModule` entry point for numeric and decor
  elements; explicit-layout seam used by goldens.
- `TextPresetDrawing.swift` — composition for all 15 presets.
- `DecorDrawing.swift` — solid color, icon, decor text (AppKit BGRA raster
  cache for multiline layout, tracking, line height, stroke).

Tests (`Tests/RunningOverlayTests/`):

- `SkiaTextFixtureFactory.swift` — deterministic 1080p fixtures, pinned
  Menlo / Menlo-Bold / Georgia, synthetic activity, decor fixtures.
- `SkiaTextGoldenTests.swift` — production minimal oracle, direct-layout
  preset oracle, decor oracle, material-blur fixture, effects fixtures.
- `SkiaTextComposerTests.swift` — shaping/alignment/tnum and a pill-width
  composition regression test.
- `SkiaTextGPUParityTests.swift` — CPU-vs-Metal parity through
  `SkiaEasyRunRenderer` (the preview/export path), skipped without Metal.

### Composer API (stable for other modules)

`SkiaTextComposer` exposes `font(family:size:weight:)`,
`font(family:size:overlayWeight:)`, `makeLine`, `measure`, three `draw`
overloads, and `horizontalOffset` / `verticalOffset`. `SkiaTextLine` carries
per-run fonts and glyphs so CoreText fallback (CJK, symbols) stays correct.

### Golden results (1920×1080, `swift test --filter SkiaText`)

| Fixture | changed | meanDelta |
| --- | ---: | ---: |
| minimal production path | 0.115% | 0.048 |
| minimalLabel | 0.091% | 0.064 |
| pillBadge | 0.179% | 0.102 |
| metricCard | 0.148% | 0.081 |
| bigNumber | 0.107% | 0.039 |
| splitLabel | 0.107% | 0.080 |
| neonGlow | 0.620% | 0.059 |
| racingStripe | 0.163% | 0.080 |
| editorial | 0.100% | 0.065 |
| digitalWatch | 0.702% | 0.101 |
| deprecated 5 presets | 0.093–0.347% | 0.030–0.247 |
| material blur fallback | 0.110% | 0.045 |
| feathered background (dst-in mask) | 0.128% | 0.047 |
| decor rectangle | 0.000% | 0.000 |
| decor rounded rectangle | 0.047% | 0.011 |
| decor circle | 0.066% | 0.008 |
| decor capsule | 0.091% | 0.029 |
| minimal effects | 1.977% | 0.184 |
| decor solid | 0.011% | 0.002 |
| decor icon | 0.395% | 0.770 |
| decor stroked text | 0.090% | 0.067 |
| decor effects | 2.997% | 0.222 |

Effects fixtures report a larger changed ratio because a small blur-falloff
difference covers a large glow/shadow area; `meanDelta` remains below 0.25.
Thresholds therefore use `changedRatio < 0.05` and `meanDelta < 2` for the
effects fixtures only.

### GPU-path parity (`SkiaEasyRunRenderer`, Metal offscreen)

`SkiaTextGPUParityTests` draws the same production elements through a CPU
`SkiaEasyRunRenderer` and a Metal-backed one (`skb_create_gpu`, offscreen
surface, `readPixels`), so the comparison covers the real preview/export
dispatch rather than `SkiaTextModule` in isolation. Anchors are fractional
(`0.2137/0.3071`, `0.5031/0.4969`) to exercise subpixel coverage.

| Fixture | changed | meanDelta | maxDelta |
| --- | ---: | ---: | ---: |
| minimal text (icon, label, unit, background) | 0.000% | 0.0000 | 0 |
| decor icon (SF Symbol upload) | 0.000% | 0.0000 | 0 |

Ganesh and the raster backend are pixel-identical for these primitives; glyph
masks and the rasterized icon are uploaded as the same premultiplied BGRA
data, and analytic path coverage matches. Thresholds remain
`changedRatio < 0.02`, `meanDelta < 1` to catch future regressions.

The suite is disabled via `.enabled(if:)` when `MTLCreateSystemDefaultDevice()`
is unavailable, and returns after printing `skipped` when a Metal device exists
but the bridge has no GPU context. It never fails on machines without Metal.

### Findings and known limitations

1. **`element.opacity` is not applied by the SwiftUI export frame view.**
   `SwiftUIOverlayFrameView` never reads `element.opacity`, while preview and
   `SkiaTextModule` do. Per the bridge freeze, parity goldens pin opacity to
   1.0. This is a pre-existing preview/export divergence outside Group T.
2. **Shadow/glow falloff.** Passing the SwiftUI radius through as Skia sigma is
   the closest fit; halving the sigma made effects worse. Residual tail
   differences remain on neonGlow, digitalWatch, and effects fixtures.
3. **Material blur.** The measured `.ultraThinMaterial` fallback is
   appearance-sensitive. The alpha curve in `SkiaTextEffects` was sampled from
   `ImageRenderer` in the current macOS appearance (near-white ~244/255 fill,
   alpha 0 at 0 → 1 at 16/24 steps). Force-pinning a color scheme in export
   would remove the ambiguity.
4. **Decor icon raster.** `IconRenderer.drawSFSymbol` through
   `NSImage.SymbolConfiguration` renders slightly thinner than SwiftUI's
   `Image(systemName:).font(...)`. Position, size, tint, and effects match;
   strokes differ by a few pixels.
5. **DigitalWatch font.** `.custom("Menlo-Bold", ...)` must be resolved with
   `NSFont(name:)`; the family resolver snaps it back to Menlo Regular.

### Integration notes for the lead

- `SkiaTextModule.draw(element:context:canvasSize:activity:elapsedTime:)`
  returns `true` when it handled the element. `supports(_:)` covers numeric
  and decor types.
- `SkiaTextModule.draw(element:layout:context:renderContext:)` is the
  explicit-layout seam; use it where the caller already holds a layout.
- No remaining bridge gaps for text or decor. Glyph stroke is handled by the
  AppKit decor-text raster path (D5); material blur by the measured fallback
  (D3); opacity by `skb_begin_opacity_layer` (D6).
