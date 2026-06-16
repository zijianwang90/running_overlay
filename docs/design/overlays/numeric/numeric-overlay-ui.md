# Numeric Overlay UI Design Spec

Last updated: 2026-06-16 (per-role HR zone tint)

## Purpose

Numeric Overlay is the reusable Inspector detail template for overlays that display a single numeric or numeric-like metric value. It should replace one-off Pace-style detail layouts with a dense, consistent editing surface.

This spec guides all numeric overlay development, including UI, model mapping, formatting, unit selection, background styling, and implementation gaps.

Numeric Overlay 1.0 intentionally uses one render style: Minimal Clean. The Inspector does not expose text style presets or divider controls. Existing `OverlayStyle.textPreset` and `divider*` fields remain decodable for old projects/templates, but numeric preview/export ignores divider rendering and resolves numeric metrics through the Minimal Clean render path.

## Design Reference

![Numeric Overlay mockup](./numeric-overlay.png)

## Applies To

Use this template for these `OverlayElementType` values:

- `heartRate`
- `heartRateZone` — same Inspector sections as other metrics, but value / label / unit / icon each optionally follow the active heart-rate zone color through independent toggles. This type is **not** available as an Interval HUD Bar metric slot (the HUD keeps its own `heartRateZone` / `hrDrop` metrics).
- `pace` — instantaneous speed-derived pace at the playhead.
- `avgPace` — cumulative session average (elapsed ÷ distance); same Inspector and unit options as `pace`.
- `lapPace` — running average within the current lap (in-lap elapsed ÷ in-lap distance).
- `calories`
- `elapsedTime`
- `realTime`
- `distance`
- `elevation`
- `cadence`
- `power`

Do not use this template as-is for `distanceTimeline`, `elevationChart`, `runningGauge`, or `routeMap`. Those overlays may share lower-level controls, but they need chart/gauge/map-specific layouts.

## Design Direction

Numeric Overlay editing should feel closer to a DaVinci Resolve inspector than the earlier loose Pace panel:

- Dense parameter rows.
- Two-column label/control alignment.
- Compact section headers with icons and collapse affordances.
- Thin dividers instead of large card blocks.
- Minimal vertical gaps.
- Most row heights around 30-34 px, with taller adaptive rows for controls that need extra vertical space (for example, anchor grids).
- Controls should be precise, model-backed, and fast to scan.

The panel should still use Running Overlay's dark design tokens and blue accent from [App UI](../../system/app-ui.md).

## Header

Content:

- Back icon button.
- Metric/type icon.
- Title, e.g. `Pace`, `Heart Rate`, `Distance`.
- Pill: `Numeric Overlay`.
- Live value preview, e.g. `13'49" / km`.
- Trash icon button.

Rules:

- Header is compact and aligned with the shared Inspector detail header.
- The live value preview uses the same formatter as Preview and Added Elements.
- Trash remains the only destructive header action.

## Section Model

Sections:

1. `Content`
2. `Layout`
3. `Typography` (value only)
4. `Label`
5. `Unit`
6. `Icon`
7. `Background`
8. `Border`
9. `Effects`

Each section should render as a compact collapsible group:

- Header height: 28-32 px.
- Small icon.
- Section title.
- Optional reset/action icon on the right only when model-backed.
- Body rows use a two-column grid: label left, control right.

Do not use large card containers for every row.

## Content Section

| Control | Example | Requirement |
| --- | --- | --- |
| `Units` dropdown | `Metric (min/km)` | Required for metrics with unit variants. |
| `Format Preview` readout | `13'49" / km` | Always visible and model-backed through formatter. |

### Unit Selection

The Units control is a menu/dropdown. For Pace, include:

- `Metric (min/km)`
- `Imperial (min/mi)`
- `Rowing (min/500m)`

The selected option shows a checkmark.

Other numeric overlays should expose only relevant unit choices:

| Metric | Suggested units |
| --- | --- |
| Heart Rate | `bpm` |
| Pace | `Metric (min/km)`, `Imperial (min/mi)`, `Rowing (min/500m)` |
| Avg Pace / Lap Pace | Same as Pace |
| Distance | `Metric (km)`, `Imperial (mi)`, `Meters (m)` |
| Elevation | `Metric (m)`, `Imperial (ft)` |
| Power | `watts` |
| Cadence | `spm` |
| Calories | `kcal` |
| Elapsed Time | `hh:mm:ss`, `mm:ss`, `seconds` |
| Real Time | `12-hour`, `24-hour` |

Elapsed Time formatting rules:

- Elapsed Time uses active elapsed time: current FIT elapsed time minus any `timerPaused` annotated spans that have occurred so far. While the playhead is inside a timer-paused span, the displayed value freezes at the pause start value.
- `hh:mm:ss` always renders a fixed three-part clock with zero-padded hours/minutes/seconds (for example, `00:10:00`).
- `mm:ss` renders `MM:SS`.
- `seconds` renders rounded whole seconds.

Implementation rule:

- If a metric has only one unit, the Units row can be read-only or omitted.
- Do not show a unit menu with fake choices that do not change formatting.
- Do not show a Style or Preset selector for numeric overlays in 1.0.

## Layout Section

Implemented via the shared `OverlayLayoutInspectorRows` component. Controls:

- Position X and Y numeric fields on one row (three-decimal precision).
- Scale slider, range `0.25...4`, quantized to `0.05`, formatted `1.00x`.
- Minimum Width slider, range `0...720` design units. `0` keeps the text-driven natural width; larger values reserve horizontal space without shrinking the rendered metric content.
- Minimum Height slider, range `0...360` design units. `0` keeps the text-driven natural height.
- Opacity slider, range `0...1`, displayed as a percentage. This controls `OverlayElement.opacity` and fades the whole overlay, not just its background.

Anchor, Padding, and Rotation rows have been removed. Position is set numerically only.

## Typography Section

Controls:

- Font dropdown.
- Font Size slider with numeric value (value text only).
- Weight segmented control: `Regular`, `Medium`, `Semibold`, `Bold`.
- Align segmented control (left / center / right) — backed by `OverlayStyle.textAlignment` for saved style compatibility. Numeric overlay rendering resolves value, label, and unit rows to leading alignment so the left edge stays fixed while dynamic content grows to the right.
- `Zone Color` checkbox for `heartRate` and `heartRateZone` only. Backed by `OverlayStyle.valueColorsFollowHeartRateZones`.

Model mapping:

- Existing model supports `OverlayStyle.fontName`.
- Existing model supports `OverlayStyle.fontSize`.
- Existing model supports `OverlayStyle.fontWeight`.
- `OverlayStyle.textAlignment` is the value alignment (the Align row above writes to it).
- Typography size no longer scales label/unit; label and unit are edited in their own sections.

## Label Section

Controls:

- `Enable Label` toggle in section header accessory.
- Label text field.
- Position segmented control: `Top`, `Bottom`, `Left`, `Right`.
- Align/Anchor segmented control: three options interpreted by position. Row label is `Align` when the label is stacked above/below the value (left / center / right) and `Anchor` when it sits to the side (top / middle / bottom). Backed by `OverlayStyle.labelTextAlignment` (`.leading / .center / .trailing` reused for both axes) for compatibility, while numeric preview/export resolves label placement to leading alignment.
- Label color swatches.
- `Zone Color` checkbox for `heartRate` and `heartRateZone` only. Backed by `OverlayStyle.labelColorsFollowHeartRateZones`.
- Label opacity slider.
- Label font family.
- Label font size.
- Label font weight.

## Unit Section

Controls:

- `Enable Unit` toggle in section header accessory.
- Position segmented control: `Top`, `Bottom`, `Left`, `Right`.
- Align/Anchor segmented control — backed by `OverlayStyle.unitTextAlignment`. When the unit is above/below the value it controls horizontal row alignment; when the unit is left/right of the value it controls vertical anchoring (top / middle / bottom) of the inline unit beside the value. Inline units stay baseline-glued to the value horizontally and grow the overlay to the right.
- Color swatch + Alpha.
- `Zone Color` checkbox for `heartRate` and `heartRateZone` only. Backed by `OverlayStyle.unitColorsFollowHeartRateZones`.
- Unit font family.
- Unit font size.
- Unit font weight.
- Spacing slider.

Rendering rules:

- Unit text must remain on one line. An inline unit expands the numeric overlay's natural width instead of wrapping beneath the value when the current width is tight.
- `Min Width` and `Min Height` reserve extra frame space for border rendering and the minimal preset background while the content remains pinned to the top-leading corner.
- Numeric overlay `position` is interpreted as the top-leading corner in preview and SwiftUI export. Dynamic values, labels, units, and icons keep their left edge fixed and extend rightward as content becomes wider. Preview placement must not depend on async content-size measurement; drag computes top-leading position from canvas-coordinate pointer location plus the initial grab offset, and uses a top-leading snap/clamp path so edge snapping still works.

## Icon Section

Controls:

- `Enable Icon` toggle in section header accessory.
- SF Symbol picker with editable name field, current-symbol preview button, searchable popover grid, sport-first default browsing order, recent symbols, and a metric-default reset action. Empty values reset to the metric's default symbol through the project setter; manual names remain accepted for newer SF Symbols not yet in the bundled catalog.
- Position segmented control: `Top`, `Bottom`, `Left`, `Right`.
- Align/Anchor segmented control — backed by `OverlayStyle.iconTextAlignment`. When the icon is above/below the text block it controls horizontal alignment; when the icon is left/right of the text block it controls vertical anchoring (top / middle / bottom).
- Size slider.
- Color swatch + Alpha.
- `Zone Color` checkbox for `heartRate` and `heartRateZone` only. Backed by `OverlayStyle.iconColorsFollowHeartRateZones`. When enabled, the icon tint resolves from the active HR zone color; when disabled, the icon uses the manual swatch like any other metric.
- Spacing slider.

Rendering rules:

- Numeric Overlay 1.0 uses SF Symbols only for this icon slot.
- Each numeric metric gets a default symbol from `OverlayElementType.defaultNumericIconSystemName` when added from the Overlay Pool; users can override `OverlayStyle.iconSystemName`. The picker grid is backed by the shared bundled `SFSymbolCatalog` name list generated from the public CoreGlyphs SF Symbol order catalog; blank search opens to sport-relevant symbols first, typed search scans the full catalog, and renderability checks are cached while typed names remain valid input. Empty or legacy-missing `iconSystemName` values resolve through the element type's default symbol at render time.
- Icons wrap the whole numeric text block, not just the value row, so label/unit layout remains independent.
- `heartRate` and `heartRateZone` can optionally tint value, label, unit, and icon from the shared `HRZonePalette` independently. Each role keeps its own manual swatch as the fallback when the toggle is off or the current timeline sample does not resolve to a valid heart-rate zone.

## Background Section

Implemented with the shared `OverlayBackgroundInspectorModule`. The module owns the section title, icon, disclosure state, and header on/off switch.

Controls:

- `Enable Background` toggle.
- Background color swatch.
- Opacity slider. This controls background-only alpha; whole-overlay opacity lives in Layout.
- Radius slider.
- Padding X and Padding Y fields or compact steppers.
- Gaussian Blur slider.

Model mapping:

- `OverlayStyle.backgroundEnabled` toggles drawing.
- `OverlayStyle.backgroundColor` is the fill color.
- `OverlayStyle.backgroundOpacity` continues to multiply the alpha for backwards-compatible templates.
- `OverlayStyle.backgroundRadius` and `OverlayStyle.backgroundPaddingX/Y` drive the rounded background on the `.minimal` text preset.
- `OverlayStyle.backgroundBlurRadius` applies gaussian blur to the background block.

## Effects Section

Implemented with the shared `OverlayEffectsInspectorModule`. Effects has no section-level enable switch; each effect controls its own enabled state.

Controls:

- Shadow toggle.
- Shadow color swatch.
- Shadow opacity slider.
- Shadow radius field/slider.
- Shadow thickness slider.
- Shadow offset X and Y fields.
- Glow toggle.
- Glow color swatch.
- Glow intensity slider.
- Fade Out toggle.
- Fade Amount slider.

Model mapping:

- `OverlayStyle.shadowEnabled` toggles drawing.
- `OverlayStyle.shadowColor`, `shadowOpacity`, `shadowRadius`, `shadowThickness`, `shadowOffsetX`, and `shadowOffsetY` drive the rendered shadow.
- `OverlayStyle.glowEnabled`, `glowColor`, and `glowIntensity` drive the foreground glow.
- `OverlayStyle.backgroundFadeOutEnabled` and `backgroundFadeOutAmount` drive optional edge fade for the background only.

Rendering rules:

- When background is enabled, shadow targets the background/container where the overlay has a background surface.
- When background is disabled, shadow targets the internal foreground elements.
- Glow targets foreground/internal elements.
- Fade Out targets only the background; when background is disabled, Fade Out has no visual effect.

## Border Section

Implemented with the shared `OverlayBorderInspectorModule`. The module owns the section title, icon, disclosure state, and header on/off switch.

Controls:

- `Enable Border` toggle.
- Border color swatch.
- Border opacity slider.
- Border thickness slider.

Model mapping:

- `OverlayStyle.borderEnabled` toggles drawing.
- `OverlayStyle.borderColor`, `borderOpacity`, and `borderWidth` drive the rendered stroke.

## Footer

Sticky footer:

- Secondary `Reset`.
- Primary `Done`.

Rules:

- Footer is compact.
- `Done` returns to Inspector outer/detail navigation as currently defined.
- `Reset` should only appear when reset behavior is implemented.

## Density And Layout Tokens

| Token | Value |
| --- | ---: |
| `numeric.sectionHeaderHeight` | 30 |
| `numeric.rowHeight` | 34 |
| `numeric.anchorGridRowHeight` | 64 (min-height for anchor grid rows) |
| `numeric.rowGap` | 6 |
| `numeric.sectionGap` | 8 |
| `numeric.labelColumnWidth` | 112 |
| `numeric.controlHeight` | 26 |
| `numeric.iconButtonSize` | 28 |
| `numeric.swatchSize` | 22 |

Inspector width:

- Default: 460 px.
- Minimum: 460 px.
- Numeric Overlay must remain usable at 460 px without text clipping.
- Dense segmented controls with four options use compact labels in the Inspector (`Bot` for Bottom, `Reg` / `Med` / `Semi` / `Bold` for font weight) so Label and Unit sections do not overflow at the minimum width.

## Model Gaps

Implemented in `OverlayStyle` (2026-04-26 refactor):

- `unitOption` (`OverlayUnitOption`) — per-overlay unit preference, decoded with default fallback for legacy projects.
- `showLabel`, `showUnit`, `customLabel` — control label/unit visibility and override label text.
- `labelPosition`, `unitPosition` — top/bottom/left/right placement around the numeric value.
- `labelFontName` / `labelFontSize` / `labelFontWeight` — label-only typography controls.
- `unitFontName` / `unitFontSize` / `unitFontWeight` — unit-only typography controls.
- `iconEnabled`, `iconSystemName`, `iconPosition`, `iconTextAlignment`, `iconSize`, `iconColor`, `iconOpacity`, `iconSpacing` — SF Symbol icon controls for numeric overlays.
- `rotationDegrees` — legacy field retained for decode compatibility; Numeric Overlay 1.0 does not expose rotation controls.
- `textAlignment` (`OverlayTextAlignment`) — leading/center/trailing alignment.
- `accentColor` — legacy field retained for decode compatibility; Numeric Overlay 1.0 does not expose accent controls.
- `backgroundEnabled`, `backgroundColor`, `backgroundRadius`, `backgroundPaddingX`, `backgroundPaddingY` — explicit background controls; the legacy `backgroundOpacity` field continues to scale the alpha and stays decoded.
- `numericMinWidth`, `numericMinHeight` — optional text-overlay minimum frame dimensions; `0` preserves natural text sizing for legacy projects.
- `backgroundFadeOutEnabled`, `backgroundFadeOutAmount`, `backgroundBlurRadius` — background edge fade and blur controls.
- `borderEnabled`, `borderColor`, `borderOpacity`, `borderWidth` — shared border controls.
- `shadowEnabled`, `shadowColor`, `shadowOffsetX`, `shadowOffsetY`, `shadowThickness` — shadow toggle plus color, direction, and thickness, in addition to existing `shadowOpacity` / `shadowRadius`.
- `glowEnabled`, `glowColor`, `glowIntensity` — foreground glow controls shared by detail panels.

`OverlayElementType.isNumericOverlay`, `OverlayElementType.defaultUnitOption`, and `OverlayElementType.defaultNumericIconSystemName` provide the unit/icon defaults applied by `ProjectDocument.addOverlayElement` and used to filter the unit menu. Numeric preview/export forces the Minimal Clean render path and disables divider rendering, regardless of decoded `textPreset` or `dividerEnabled` values.

Still routed through metric type (no separate model field):

- Metric reassignment independent of `OverlayElementType` (changing the metric requires creating a new element).

Model-backed and rendered today (post-refactor):

- Type-derived metric.
- Formatted value preview, honoring `unitOption`, `showLabel`, `showUnit`, and `customLabel`.
- Position X/Y, scale, minimum width, minimum height.
- Font name, font size, font weight.
- Foreground/text color and accent color.
- Background enabled / color / radius / padding X / padding Y (`.minimal` text preset uses padding + radius for the rounded background).
- Background opacity (legacy multiplier on the alpha).
- Border enabled / color / opacity / thickness.
- Shadow enabled / color / opacity / radius / thickness / offset X / offset Y.
- Glow enabled / color / intensity.
- Fade Out enabled / amount for background edge fade.
- Rotation.
- Text alignment.

## Implementation Guidance

Recommended components:

- `NumericOverlayDetailView`
- `Sources/RunningOverlay/UI/InspectorRows/InspectorDenseComponents.swift`
- `InspectorDenseSection`
- `InspectorDenseRow`
- `InspectorDenseMenuRow`
- `InspectorDenseToggleRow`
- `InspectorDenseSliderRow`
- `InspectorDenseNumberPairRow`
- `InspectorUnitMenu`
- `InspectorAnchorGrid`
- `InspectorSwatchRow`
- `InspectorSegmentedIconControl`

Suggested type helpers:

- `OverlayMetricKind`
- `OverlayUnitOption`
- `OverlayNumericFormat`
- `OverlayBackgroundStyle`
- `OverlayTextAlignment`

Do not duplicate one detail view per metric. Metric-specific behavior should be driven by configuration:

- available units
- default label
- formatter
- supported controls
- icon

## Acceptance Criteria

- Pace, Heart Rate, Distance, Power, Cadence, Calories, Elevation, Elapsed Time, and Real Time can all use the same dense detail template.
- Pace exposes `Metric (min/km)`, `Imperial (min/mi)`, and `Rowing (min/500m)`.
- Single-unit metrics do not show fake unit menus.
- Background toggle and background controls are present in the design, but implementation only enables model-backed controls.
- The panel is visibly denser than the earlier Pace implementation and avoids large cards or loose vertical gaps.
- The formatted preview updates when metric/unit, typography, and icon choices change.
