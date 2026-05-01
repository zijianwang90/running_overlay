# Weather Widget Overlay

Last updated: 2026-04-30

## Purpose

Weather Widget Overlay shows simple day-of-run weather context on top of a video. The module should feel like a weather app plugin: clear condition, temperature, and optional location/secondary metrics.

Design spec:

- [Weather Widget Overlay UI](../design/overlays/weather-widget/weather-widget-overlay-ui.md)
- [Structured spec](../design/overlays/weather-widget/weather-widget-overlay-ui.spec.json)
- [Preset board](../design/overlays/weather-widget/weather-widget-presets.png)
- [Icon set](../design/overlays/weather-widget/weather-icon-set.png)

## User Goals

- Show weather and temperature without requiring a full dashboard.
- Include location/country on larger presets, for example `大阪, 日本`.
- Choose from simple app-like presets, including compact and large variants.
- Keep all weather condition icons visually consistent.
- Use FIT or manual weather data first, then support API-backed weather later.

## Data Inputs

Phase 1:

- FIT temperature when available.
- Manual current temperature.
- Manual condition.
- Manual location.
- Manual humidity, high/low, wind, and feels-like values when the selected preset needs them.

Phase 2:

- Activity start timestamp.
- GPS start point from FIT (used for coordinate-based localization and weather lookup) or manually selected location.
- Historical weather from Open-Meteo archive API (activity date, not current forecast). Cached into the project for export determinism.

## Rendering Model

Recommended layout pipeline:

1. Resolve preset and visible fields.
2. Resolve weather data from FIT/manual/API-cache in that order.
3. Resolve the weather icon from the shared condition icon set.
4. Layout fixed preset regions: icon, temperature, condition, location, and metrics.
5. Draw optional card background and divider.
6. Draw icon and text.
7. Apply shadow/glow only as readability aids.

## Presets

- `simpleCard`: default blue translucent weather card with icon, divider, location, temperature, and humidity.
- `compactStrip`: small corner-friendly strip with icon, temperature, condition, and city.
- `forecastTile`: larger tile with location, icon, temperature, high/low, and humidity.
- `minimalText`: text-first treatment with minimal or no container.
- `dashboardBar`: wide bar with location, condition, temperature, and metric chips.

## Inspector

Use dense Inspector sections:

- Preset
- Content
- Location
- Temperature
- Metrics
- Icon
- Layout
- Appearance
- Effects

The first implementation can expose manual fields only. Weather API controls should stay hidden until API lookup, caching, and export determinism are implemented.

## Implementation Plan

### Data Model (`OverlayElement.swift`)

Add all new types in a `// MARK: - Weather Widget` section at the bottom of the file.

**`WeatherCondition` enum** — 10 cases: `sunny, clearNight, partlyCloudy, cloudy, rain, heavyRain, thunder, snow, fog, wind`. Properties: `label(locale:)` auto-localized from activity coordinates (not system locale), `sfSymbolName` (SF Symbol fallback), `iconTint: OverlayColor`. Static func `fromWMO(_ code: Int) -> WeatherCondition` for Phase 2 Open-Meteo WMO code mapping. All fields user-overridable.

**`WeatherTemperatureUnit` enum** — `celsius`, `fahrenheit`. Defaults to system locale. Method `formatted(_ celsius: Double) -> String`.

**`WeatherDataSource` enum** — `fitTemperature` (Phase 1), `manual` (Phase 1), `openMeteo` (Phase 2).

**`WeatherWidgetPreset` enum** — `simpleCard, compactStrip, forecastTile, minimalText, dashboardBar`. Property `defaultSize: CGSize` per design spec.

**`WeatherPayload` struct** (Equatable, Codable) — cached result from FIT or API: `condition, temperatureCelsius, humidity?, highTemperatureCelsius?, lowTemperatureCelsius?, windKph?, feelsLikeCelsius?, resolvedLocation?, sourceDate?`

**`WeatherWidgetStyle` struct** (Equatable, Codable):

```
preset: WeatherWidgetPreset
dataSource: WeatherDataSource
manualCondition / manualTemperatureCelsius / manualHumidity / manualHigh / manualLow / manualWind / manualFeelsLike
temperatureUnit: WeatherTemperatureUnit
locationText: String
showLocation / showWeekday / showHumidity / showHighLow / showWind / showFeelsLike: Bool
cardBackgroundColor: OverlayColor
cardBackgroundOpacity / cardCornerRadius / iconSize: Double
showConditionLabel: Bool
width / height: Double
cachedWeather: WeatherPayload?     // nil = not yet fetched; round-trips through Codable project snapshot
```

Static factory `WeatherWidgetStyle.preset(_ preset:)` — sets width/height and visual defaults per preset while leaving content fields at defaults.

`cachedWeather` lives inside `WeatherWidgetStyle` (not on `ProjectDocument`) so it serialises with the project and makes export offline-deterministic once fetched.

### OverlayElement System (`OverlayElement.swift`)

- Add `.weatherWidget` to `OverlayElementType`. Update `label`, `icon`, `supportsTextPresets` (false), `isDecorOverlay` (false), `isNumericOverlay` (false), `pasteCategory`.
- Add `var weatherWidget: WeatherWidgetStyle` to `OverlayStyle`. Initialize to `.default` everywhere.

### Render Layout (`OverlayRenderModel.swift`)

**`WeatherWidgetRenderLayout` struct**: `style, rect: CGRect, condition, temperatureString, locationString, weekdayString, humidityString?, highString?, lowString?, windString?, feelsLikeString?, iconSize, cardCornerRadius`

**`weatherWidgetLayout(for:in:)` static func**:
1. Scale width/height by `element.scale` and `context.canvasScale`; compute `rect` via `centeredRect(for:size:canvasSize:)`.
2. Resolve temperature: `.fitTemperature` → `context.activity.temperature(at: elapsedTime) ?? manual`; `.openMeteo` → `cachedWeather?.temperatureCelsius ?? manual`; `.manual` → manual value.
3. Resolve condition via the same precedence chain.
4. Format all display strings (unit conversion, weekday from `activity.startDate`, optional fields).
5. Pure function — no networking, no side effects.

### SwiftUI Preview Views

**New file** `Sources/RunningOverlay/UI/WeatherWidgetOverlayViews.swift`:

- `WeatherWidgetOverlayView: View` — switches on `layout.style.preset`, dispatches to five private sub-views: `SimpleCardPresetView`, `CompactStripPresetView`, `ForecastTilePresetView`, `MinimalTextPresetView`, `DashboardBarPresetView`.
- Shared sub-component `WeatherConditionIconView(condition:size:)` — renders SF Symbol with condition tint; reused by all presets.
- Thin `OverlaySharedWeatherWidgetView` wrapper to match the project's existing naming convention.

**`PreviewCanvasView.swift`** — add case in the per-type dispatch:
```swift
case .weatherWidget:
    let layout = OverlayRenderModel.weatherWidgetLayout(for: element, in: renderContext)
    OverlaySharedWeatherWidgetView(element: element, layout: layout)
        .overlayForegroundEffects(element: element)
```

### Export Renderer (`OverlayFrameRenderer.swift`)

Add case in `renderElement`. Private `renderWeatherWidget` method: compute layout, construct `WeatherWidgetOverlayView`, rasterise via `ImageRenderer(scale: 2.0)`, draw CGImage at `layout.rect`. Same `ImageRenderer` pattern already used by the lap overlays.

### Inspector UI (`WeatherWidgetOverlayDetailView.swift`)

New file following `NumericOverlayDetailView` structure. Use `InspectorDense*` primitives directly — no wrappers.

| Section | Key controls |
|---|---|
| Preset | `Menu` over all presets → `applyWeatherWidgetPreset` |
| Content | Data source picker (FIT / Manual; API greyed in Phase 1); condition picker with icon preview |
| Location | TextField for `locationText`; toggles for showLocation, showWeekday |
| Temperature | Manual temp field; unit picker (°C / °F, defaults to system locale); FIT source indicator |
| Metrics | Toggle + field rows for humidity, H/L, wind, feelsLike |
| Icon | Condition icon preview; iconSize slider; showConditionLabel toggle |
| Layout | `OverlayLayoutInspectorRows` with width/height bindings; corner radius slider |
| Appearance | Card background color swatch strip + opacity slider |
| Effects | `OverlayBackgroundInspectorModule`, `OverlayBorderInspectorModule`, `OverlayEffectsInspectorModule` |

Footer: Reset / Done. Phase 2 adds "Fetch Weather" button → `project.fetchWeatherFromAPI(elementID)`.

### ProjectDocument Mutations (`ProjectDocument.swift`)

```swift
mutateWeatherWidgetStyle(_ id:, _ mutate:)               // registerUndoPoint
mutateWeatherWidgetStyleContinuous(_ id:, _ mutate:)     // registerContinuousUndoPoint
applyWeatherWidgetPreset(_ id:, preset:)                 // replaces visual/dimension defaults; preserves content fields + cachedWeather
fetchWeatherFromAPI(_ id:)                               // Phase 2: Task { await WeatherFetcher.fetch(...) }
```

Also update `defaultOverlayStyle(for:)` to set `style.weatherWidget = .preset(.simpleCard)` for `.weatherWidget`.

### Routing

- **`ParameterPanelView.swift`** — add `else if element.type == .weatherWidget` branch routing to `WeatherWidgetOverlayDetailView`.
- **`OverlayPoolView.swift`** — add new `OverlayCategory` case `.weather` (label: "Weather"); register tile with `systemImage: "cloud.sun.fill"`.

### Phase 2: WeatherFetcher (`Sources/RunningOverlay/Weather/WeatherFetcher.swift`)

`actor WeatherFetcher` with `static func fetch(latitude:longitude:date:manualFallback:) async throws -> WeatherPayload`:

- Queries historical weather for the activity date (Open-Meteo archive API, free, no key required): `https://archive-api.open-meteo.com/v1/archive?latitude=…&start_date=…&end_date=…&hourly=temperature_2m,weathercode,windspeed_10m,relativehumidity_2m,apparent_temperature`
- Pick the hour matching activity start time; derive daily H/L from full hourly array.
- Map WMO codes to `WeatherCondition` via `fromWMO(_:)`.
- GPS coordinates from FIT used for both localization and API lookup; manual location override supported.
- Fall back to `manualFallback` when coordinates are missing or API fails.
- Private `OpenMeteoResponse: Decodable` struct for JSON decoding.

### Tests

- `WeatherWidgetRenderModelTests` — layout resolves FIT/manual/API chain; scales rect; hides optional fields; formats weekday.
- `WeatherWidgetStyleCodingTests` — Codable round-trip with non-nil `cachedWeather`; default has `cachedWeather == nil`.
- `WeatherConditionTests` — WMO code mapping; temperature unit formatting.

### Implementation Order

1. Data model (`WeatherCondition`, `WeatherPayload`, `WeatherWidgetStyle`, etc.)
2. `OverlayElementType` + `OverlayStyle` additions
3. `WeatherWidgetRenderLayout` + `weatherWidgetLayout(for:in:)`
4. `ProjectDocument` mutation methods
5. SwiftUI preview views + `PreviewCanvasView` routing
6. `OverlayFrameRenderer` export path
7. Overlay Pool tile registration
8. `ParameterPanelView` routing
9. Inspector detail view
10. `WeatherFetcher` (Phase 2)
11. Tests

## Current Implementation

Not implemented. The plan above captures the approved implementation approach.

## Resolved Decisions

- **Condition label localization**: Auto-localized from activity coordinates (FIT GPS), not system locale. Every display field is user-editable; manual values override auto-localized ones.
- **Temperature unit default**: Follows system locale (°C or °F), with a per-widget override in Inspector.
- **API weather data**: Always historical weather for the activity date (Open-Meteo archive API). Running is always a past event; forecasts are not meaningful.
