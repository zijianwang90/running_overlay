# Elevation Chart Overlay UI Design Spec

Last updated: 2026-04-29

## Purpose

`Elevation Chart Overlay` is a dedicated overlay module for showing an activity's elevation profile. It replaces the earlier idea of showing elevation inside `Distance Timeline`. The component focuses on a clean elevation area chart and can optionally attach the same configurable **Status Bar** pattern used by Route Map Overlay.

This module should be implemented as a separate overlay type:

```swift
OverlayElementType.elevationChart
```

It should not be implemented as a variant of Distance Timeline or Route Map.

## Core Design Direction

The visual language should be premium sports-video UI: readable over video, compact, and configurable without creating too many redundant preset types.

The component is built from:

```text
Elevation Chart Container
├─ Chart Area
│  ├─ elevation line
│  ├─ optional gradient area fill
│  ├─ optional dual-color area style
│  ├─ optional current position marker
│  ├─ optional min / max markers
│  └─ optional axis / grid / labels
└─ Optional Status Bar
   ├─ 1–4 configurable metric slots
   └─ same layout logic as Route Map Status Bar
```

## Simplified Style Philosophy

Do **not** create separate presets that are only color changes. The previous concepts such as "green gradient", "blue gradient", and "sunset gradient" should be unified into one configurable style:

```text
Gradient Area Chart
```

The user can change gradient colors, line color, fill opacity, and background settings to create different looks.

Keep the following style families:

1. `Gradient Area` — default elevation chart style. One line + gradient area fill.
2. `Dual Area` — same chart, but the area can use two visual regions/colors, controlled by a setting.
3. `Big Numbers` — chart plus stronger large elevation numbers; still uses a normal elevation chart as the base.

Do **not** implement these as dedicated first-version styles:

```text
bar chart
point / dot chart
step chart
segmented chart
```

Those should not appear in the current UI.

## Applies To

- `OverlayElementType.elevationChart` only.
- The optional Status Bar should reuse the Route Map Status Bar design model as much as possible.
- The component should reuse the existing dense Inspector controls: sliders, toggles, segmented controls, color swatches, dropdowns, numeric steppers, and slot editors.

## Implementation Status

Implemented in the Swift app as a dedicated `.elevationChart` overlay path:

- Data model: `ElevationChartStyle` stored under `OverlayStyle.elevationChart`.
- Inspector: `ElevationChartOverlayDetailView`.
- Shared Layout: `CollapsibleLayoutInspectorSection` + `OverlayLayoutInspectorRows`.
- Shared Stats Bar: `CollapsibleStatsBarInspectorSection` + `OverlayStatsBarInspectorRows`, backed by `DistanceTimelineStatsBarConfig`.
- Preview renderer: `PreviewCanvasView.ElevationChartOverlayView`.
- Export renderer: `OverlayFrameRenderer.renderElevationChart`.
- Render layout: `OverlayRenderModel.elevationChartLayout`.

Current implementation keeps the first-version surface focused: structural presets, line/fill controls, current marker, optional axis/grid, big number emphasis, background/effects, and the reusable stats bar. `Dual Area` currently maps to a two-tone area treatment; slope-based climb/descent segmentation remains a later renderer enhancement.

## Header

Content:

- Back icon button.
- Elevation chart icon, suggested SF Symbol: `chart.xyaxis.line` or `mountain.2.fill`.
- Title: `Elevation Chart`.
- Pill: `Overlay`.
- Subtitle: elevation gain or current elevation, for example `Gain 126 m` or `82 m`.
- Trash icon button.

Rules:

- Header height should match other overlay detail panels.
- The subtitle should use the same metric formatting layer used by Numeric Overlay.
- Trash remains the only destructive header action.

## Inspector Section Order

Use the following sections:

```text
Preset
Layout
Chart
Line & Fill
Markers
Axis & Labels
Status Bar
Background
Effects
```

Collapsed Elevation Chart Inspector section headers use one bottom separator only, matching the regular dense Inspector section rhythm without doubled rules between adjacent sections.

The fixed Reset / Done footer reuses the shared Inspector detail footer so its button layout and height match the other overlay detail panels.

## 1. Preset Section

The Preset section should not expose many redundant color variants. It should expose only structural visual presets.

### Preset Options

```swift
enum ElevationChartPreset: String, Codable, CaseIterable {
    case gradientArea
    case dualArea
    case bigNumbers
}
```

### Preset: Gradient Area

Default, most general style.

```text
A smooth elevation line with gradient area fill under the curve.
All color differences should be handled by gradient color settings.
```

Default values:

```swift
preset = .gradientArea
chartStyle = .area
lineColor = #FFFFFF
lineWidth = 2.5
lineOpacity = 0.95
fillEnabled = true
fillGradientColors = [#37D67A, #2F80ED]
fillOpacity = 0.42
dualAreaEnabled = false
bigNumbersEnabled = false
```

In the inspector, the fill gradient editor presents `From` and `To` as stacked
swatch rows. Each row owns one color stop, keeping the color controls compact
inside the fixed-width edit panel.

### Preset: Dual Area

This is not a separate chart type. It enables a dual visual region inside the same area chart.

Use cases:

```text
- show above/below average elevation
- show climb/descent feeling
- create a two-tone visual style
```

Default values:

```swift
preset = .dualArea
chartStyle = .area
lineColor = #FFFFFF
lineWidth = 2.5
fillEnabled = true
dualAreaEnabled = true
dualAreaMode = .splitByBaseline
upperFillGradientColors = [#FFD166, #F97316]
lowerFillGradientColors = [#2F80ED, #38BDF8]
dualAreaBaseline = .averageElevation
bigNumbersEnabled = false
```

### Preset: Big Numbers

Large number emphasis while keeping the elevation chart visible.

```text
The chart remains the background visual. The main value, such as current elevation or elevation gain, becomes the dominant visual element.
```

Default values:

```swift
preset = .bigNumbers
chartStyle = .area
bigNumbersEnabled = true
bigNumberMetric = .currentElevation
bigNumberPosition = .topLeft
bigNumberFontSize = 42
bigNumberUnitFontSize = 17
fillOpacity = 0.28
lineWidth = 2.2
statusBar.enabled = false
```

## 2. Layout Section

Controls:

```text
Anchor
Position X
Position Y
Width
Height
Scale
Rotation
Opacity
```

Recommended default:

```swift
anchor = .bottomLeft
x = 0.08
y = 0.82
width = 420
height = 160
scale = 1.0
rotation = 0
opacity = 1.0
```

Support horizontal wide charts first. Vertical chart orientation is not required for the first version.

## 3. Chart Section

Controls:

```text
Chart Style
Smoothing
Sampling
Chart Padding
Progress Mode
Current Position
```

### Chart Style

Only expose:

```swift
enum ElevationChartStyle: String, Codable, CaseIterable {
    case area
    case lineOnly
}
```

Notes:

- `area` is the default.
- `lineOnly` disables fill but keeps the same line rendering.
- Do not expose bar, dot, step, or segmented chart options.

### Smoothing

```swift
smoothingEnabled: Bool
smoothingAmount: Double // 0...1
```

Default:

```swift
smoothingEnabled = true
smoothingAmount = 0.55
```

### Sampling

```swift
samplingMode: .auto | .raw | .downsampled
maxPointCount: Int
```

Default:

```swift
samplingMode = .auto
maxPointCount = 240
```

### Progress Mode

The chart can show the full route or only progress up to the current video time.

```swift
enum ElevationProgressMode: String, Codable, CaseIterable {
    case fullProfile
    case progressToCurrent
}
```

Default:

```swift
progressMode = .fullProfile
```

## 4. Line & Fill Section

This section owns most of the visual flexibility.

Controls:

```text
Line Enabled
Line Color
Line Width
Line Opacity
Fill Enabled
Fill Gradient
  From
  To
Fill Opacity
Dual Area Enabled
Dual Area Mode
Upper Gradient
Lower Gradient
Baseline
```

### Line

```swift
lineEnabled: Bool
lineColor: ColorToken
lineWidth: Double
lineOpacity: Double
lineGlowEnabled: Bool
lineGlowColor: ColorToken
lineGlowOpacity: Double
lineGlowRadius: Double
```

Default:

```swift
lineEnabled = true
lineColor = .white
lineWidth = 2.5
lineOpacity = 0.95
lineGlowEnabled = false
```

### Fill

```swift
fillEnabled: Bool
fillGradientColors: [ColorToken]
fillGradientDirection: GradientDirection
fillOpacity: Double
```

Recommended gradient directions:

```swift
enum GradientDirection: String, Codable, CaseIterable {
    case topToBottom
    case leftToRight
    case diagonal
}
```

Default:

```swift
fillEnabled = true
fillGradientColors = [green, blue]
fillGradientDirection = .topToBottom
fillOpacity = 0.42
```

### Dual Area

Dual Area is an option, not a totally separate chart implementation.

```swift
dualAreaEnabled: Bool
dualAreaMode: ElevationDualAreaMode
dualAreaBaseline: ElevationBaseline
upperFillGradientColors: [ColorToken]
lowerFillGradientColors: [ColorToken]
upperFillOpacity: Double
lowerFillOpacity: Double
```

Enums:

```swift
enum ElevationDualAreaMode: String, Codable, CaseIterable {
    case splitByBaseline
    case climbDescent
}

enum ElevationBaseline: String, Codable, CaseIterable {
    case minElevation
    case averageElevation
    case custom
}
```

Design rules:

- `splitByBaseline` colors the area above and below the chosen baseline differently.
- `climbDescent` colors rising and falling segments differently.
- If `dualAreaEnabled == false`, only `fillGradientColors` is used.
- Dual Area should still look like a smooth area chart, not like a segmented chart.

## 5. Markers Section

Markers are optional and should be visually subtle by default.

Controls:

```text
Current Marker
Min Marker
Max Marker
Start Marker
End Marker
Marker Size
Marker Style
Marker Label
```

### Marker Config

```swift
struct ElevationMarkerConfig: Codable, Equatable {
    var enabled: Bool
    var style: ElevationMarkerStyle
    var size: Double
    var fillColor: ColorToken
    var borderColor: ColorToken
    var borderWidth: Double
    var labelEnabled: Bool
    var labelStyle: ElevationMarkerLabelStyle
}
```

Enums:

```swift
enum ElevationMarkerStyle: String, Codable, CaseIterable {
    case dot
    case ring
    case verticalLine
}

enum ElevationMarkerLabelStyle: String, Codable, CaseIterable {
    case valueOnly
    case labelAndValue
}
```

Default:

```swift
currentMarker.enabled = true
currentMarker.style = .ring
currentMarker.size = 9
currentMarker.fillColor = accentBlue
currentMarker.borderColor = white
currentMarker.borderWidth = 2

minMarker.enabled = false
maxMarker.enabled = false
startMarker.enabled = false
endMarker.enabled = false
```

## 6. Axis & Labels Section

This section controls chart context without making the overlay too busy.

Controls:

```text
Show Grid
Grid Opacity
Show Baseline
Show Min / Max Labels
Show Start / End Labels
Show Elevation Unit
Label Font Size
Label Opacity
```

Default:

```swift
gridEnabled = false
gridOpacity = 0.12
baselineEnabled = false
minMaxLabelsEnabled = false
startEndLabelsEnabled = false
unitEnabled = true
labelFontSize = 10
labelOpacity = 0.55
```

Rules:

- Grid should be off by default.
- Labels should be optional because this overlay is usually small.
- Big Numbers preset may disable most labels to avoid clutter.

## 7. Big Numbers Section

This can appear as a sub-section inside Chart or as a collapsible group inside Axis & Labels.

Controls:

```text
Big Numbers Enabled
Primary Metric
Secondary Metric
Position
Show Unit
Show Label
Font Size
Unit Font Size
Opacity
```

Metrics:

```swift
enum ElevationBigNumberMetric: String, Codable, CaseIterable {
    case currentElevation
    case elevationGain
    case maxElevation
    case minElevation
    case remainingClimb
}
```

Position:

```swift
enum OverlayCornerPosition: String, Codable, CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center
}
```

Default:

```swift
bigNumbersEnabled = false
bigNumberMetric = .currentElevation
bigNumberPosition = .topLeft
bigNumberFontSize = 42
bigNumberUnitFontSize = 17
bigNumberLabelEnabled = true
bigNumberUnitEnabled = true
bigNumberOpacity = 1.0
```

## 8. Status Bar Section

The Elevation Chart can optionally attach the same Status Bar concept used in the Route Map Overlay.

Purpose:

```text
Show compact metrics under or over the chart, such as Elevation Gain, Current Elevation, Distance, Pace, Time, Heart Rate, Power, or Grade.
```

Status Bar should be reusable and visually consistent with Route Map's Status Bar. The app implementation reuses the same inspector/configuration family already shared by Route Map and Distance Timeline, so Elevation Chart inherits placement, layout, size, typography, dividers, background, and slot editing behavior.

### Status Bar Controls

```text
Enabled
Preset
Position
Layout
Background
Background Opacity
Height
Padding X/Y
Corner Radius
Slot Count
Slot 1–4
Typography
Dividers
```

### Supported Status Bar Presets

```swift
enum ElevationStatusBarPreset: String, Codable, CaseIterable {
    case glassBar
    case minimalStrip
    case sportHUD
    case floatingPill
    case editorial
}
```

### Supported Layouts

```swift
enum StatusBarLayout: String, Codable, CaseIterable {
    case equalColumns
    case autoWidth
    case featuredFirst
    case twoByTwoGrid
    case singleRow
}
```

### Slot Metrics

At minimum support:

```text
Current Elevation
Elevation Gain
Max Elevation
Min Elevation
Grade
Distance
Elapsed Time
Pace
Heart Rate
Power
Cadence
Calories
Custom Text
```

Default slots:

```swift
statusBar.enabled = true
statusBar.layout = .equalColumns
statusBar.slotCount = 3
slot1 = .elevationGain
slot2 = .currentElevation
slot3 = .grade
slot4 = .heartRate // disabled by default
```

Default visual values:

```swift
statusBar.backgroundColor = .black
statusBar.backgroundOpacity = 0.62
statusBar.height = 58
statusBar.paddingX = 14
statusBar.paddingY = 8
statusBar.dividerEnabled = true
statusBar.dividerOpacity = 0.14
statusBar.valueFontSize = 22
statusBar.unitFontSize = 12
statusBar.labelFontSize = 10
statusBar.labelOpacity = 0.48
```

## 9. Background Section

Controls:

```text
Background Enabled
Background Color
Background Opacity
Corner Radius
Padding
Chart Inner Padding
Border
Border Opacity
```

The rendered chart container consumes the shared `OverlayStyle` Background,
Border, and Effects fields. Shared Background Padding expands the background
and border bounds in preview and export; chart inner padding remains controlled
by the Elevation Chart-specific chart padding fields.

Default:

```swift
backgroundEnabled = true
backgroundColor = .black
backgroundOpacity = 0.50
cornerRadius = 16
paddingX = 14
paddingY = 12
borderEnabled = true
borderColor = .white
borderOpacity = 0.12
borderWidth = 1
```

## 10. Effects Section

Controls:

```text
Shadow
Glow
Backdrop Blur
Blend Mode
```

Default:

```swift
shadowEnabled = true
shadowOpacity = 0.28
shadowRadius = 14
shadowOffsetY = 6
backdropBlurEnabled = false
glowEnabled = false
```

## Visual Rules

1. This component is for elevation charts only. Do not include route map rendering.
2. Do not include bar, dot, step, or segmented chart style options in the first version.
3. Color variants should be created by adjustable gradient colors, not by redundant presets.
4. `Dual Area` is a configurable option on the area chart.
5. `Big Numbers` is a visual emphasis mode, not a different chart data type.
6. Status Bar is optional and should reuse the Route Map Status Bar approach.
7. The chart must remain readable on video backgrounds.
8. Default labels should be minimal; advanced labels can be enabled by the user.
9. Presets initialize values only. After choosing a preset, every field remains manually editable.
10. Keep export rendering free of editor selection outlines.

## Minimum Viable Implementation

First version should include:

```text
- Gradient Area preset
- Dual Area preset
- Big Numbers preset
- Line color / width / opacity
- Fill gradient colors / opacity
- Dual Area toggle and two gradient groups
- Current marker
- Optional min / max labels
- Shared Background opacity / corner radius / padding / border
- Optional Status Bar with 1–4 configurable slots
```

Implemented first-version mapping:

```text
Gradient Area -> .gradientArea preset
Dual Area -> .dualArea preset + dualAreaEnabled
Big Numbers -> .bigNumbers preset + bigNumbersEnabled
Layout -> shared OverlayLayoutInspectorRows
Status Bar -> shared OverlayStatsBarInspectorRows / DistanceTimelineStatsBarConfig
```

Second version can add:

```text
- Climb/descent dual coloring based on slope
- Remaining climb metric
- Animated chart progress drawing
- Better downsampling for long activities
- Grade smoothing controls
```
