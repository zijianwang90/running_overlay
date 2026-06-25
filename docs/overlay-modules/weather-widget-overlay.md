# Weather Widget Overlay

Last updated: 2026-05-07

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
- GPS start point from FIT (used for coordinate-based localization and weather lookup).
- Current device location from CoreLocation when the user explicitly chooses the current-location fetch option.
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

- `simpleCard`: default blue translucent weather card with icon, a compact left visual block, divider, location, temperature, and humidity.
- `compactStrip`: small corner-friendly strip with icon, temperature, condition, and city.
- `forecastTile`: larger tile with location, icon, temperature, high/low, and humidity, separated by horizontal and vertical dividers.
- `minimalText`: text-first treatment with minimal or no container.
- `dashboardBar`: wide taller bar with location, condition, temperature, and readable metric chips.

## Icon Assets

Weather Widget uses production SVG icons, not cropped bitmap slices, so the icons remain sharp at every preset scale.

Assets live under `Sources/RunningOverlay/Resources/Icons/`:

- `weather-sunny.png`
- `weather-clear-night.png`
- `weather-partly-cloudy.png`
- `weather-cloudy.png`
- `weather-rain.png`
- `weather-heavy-rain.png`
- `weather-thunder.png`
- `weather-snow.png`
- `weather-fog.png`
- `weather-wind.png`

`WeatherCondition.bundledImageName` maps each condition to the bundled file name, and `WeatherConditionIconView` renders via the shared `IconView` bundled raster image path.

## Inspector

Use dense Inspector sections:

- Layout
- Preset
- Appearance
- Typography
- Location
- Weather

Weather Widget 1.0 does not expose the shared Background, Border, or Effects inspector modules. The custom weather presets do not consume those generic overlay fields, so the user-facing customization surface is intentionally limited to fields that render reliably.

Collapsed Weather Widget Inspector section headers follow the regular single-separator pattern so adjacent section boundaries stay one thin line.

The Inspector exposes two explicit API fetch actions in the Location section:

- Activity Location: fetches Open-Meteo historical weather for the activity start date using the first FIT GPS route point. Disabled when the activity has no GPS route.
- Current Location: fetches Open-Meteo historical weather for the activity start date using the user's current device location. This requires macOS location permission.

New Weather Widget overlays start in the Open-Meteo source with no baked-in
sample city or sample weather values. When the activity has a FIT GPS route,
adding the widget automatically requests historical weather for the activity
start point. Until a payload is cached, preview/export render `--` placeholders
for weather fields instead of falling back to demo content.

## Implementation Plan

### Data Model (`OverlayElement.swift`)

Add all new types in a `// MARK: - Weather Widget` section at the bottom of the file.

**`WeatherCondition` enum** — 10 cases: `sunny, clearNight, partlyCloudy, cloudy, rain, heavyRain, thunder, snow, fog, wind`. Properties: `label(locale:)` auto-localized from activity coordinates (not system locale), `sfSymbolName` (SF Symbol fallback), `iconTint: OverlayColor`. Static func `fromWMO(_ code: Int) -> WeatherCondition` for Phase 2 Open-Meteo WMO code mapping. All fields user-overridable.

**`WeatherTemperatureUnit` enum** — `celsius`, `fahrenheit`. Defaults to system locale. Method `formatted(_ celsius: Double) -> String`.

**`WeatherDataSource` enum** — `manual`, `openMeteo`, `openWeather`. Legacy `fitTemperature` decodes to `manual` with `useFITTemperature = true`.

**`WeatherWidgetStyle.useFITTemperature`** — when true and FIT records include temperature, overrides API/manual temperature at the current playhead.

**`WeatherMetricSlotValue` enum** — `none`, `humidity`, `highLow`, `wind`, `feelsLike`. Used by Style-specific metric slots; `none` displays as `-` in the Inspector and renders no metric content.

**`WeatherWidgetPreset` enum** — `simpleCard, compactStrip, forecastTile, minimalText, dashboardBar`. Property `defaultSize: CGSize` per design spec.

Each preset also defines metric slot count and defaults:

- `simpleCard`: 1 slot, default `humidity`
- `compactStrip`: 0 slots
- `forecastTile`: 3 slots, default `highLow, humidity, wind`
- `minimalText`: 0 slots
- `dashboardBar`: 3 slots, default `humidity, wind, feelsLike`

**`WeatherFetchLocationMode` enum** — `activityLocation`, `currentLocation`; stored on fetched payloads so the cache records which API entry point produced it.

**`WeatherPayload` struct** (Equatable, Codable) — cached result from FIT or API: `condition, temperatureCelsius, humidity?, highTemperatureCelsius?, lowTemperatureCelsius?, windKph?, feelsLikeCelsius?, resolvedLocation?, sourceDate?, fetchLocationMode?`

**`WeatherWidgetStyle` struct** (Equatable, Codable):

```
preset: WeatherWidgetPreset
dataSource: WeatherDataSource
manualCondition / manualTemperatureCelsius / manualHumidity / manualHigh / manualLow / manualWind / manualFeelsLike
temperatureUnit: WeatherTemperatureUnit
locationText: String
showLocation / showWeekday / showHumidity / showHighLow / showWind / showFeelsLike: Bool
metricSlots: [WeatherMetricSlotValue] // normalized to the selected preset's slot count
cardBackgroundColor: OverlayColor // persisted legacy/style field; not exposed as a 1.0 Inspector control
cardBackgroundOpacity / cardCornerRadius / iconSize: Double
dividerColor: OverlayColor
dividerEnabled: Bool
dividerThickness / dividerOpacity: Double
showIcon / showConditionLabel: Bool
width / height: Double
cachedWeather: WeatherPayload?     // nil = not yet fetched; round-trips through Codable project snapshot
```

Static factory `WeatherWidgetStyle.preset(_ preset:)` — sets width/height and visual defaults per preset while leaving content fields at defaults. `ProjectDocument.defaultOverlayStyle(for:)` switches newly added Weather Widget overlays to Open-Meteo with empty location text and no cached payload so the first render uses placeholders until the automatic activity-location fetch succeeds.

`cachedWeather` lives inside `WeatherWidgetStyle` (not on `ProjectDocument`) so it serialises with the project and makes export offline-deterministic once fetched.

### OverlayElement System (`OverlayElement.swift`)

- Add `.weatherWidget` to `OverlayElementType`. Update `label`, `icon`, `supportsTextPresets` (false), `isDecorOverlay` (false), `isNumericOverlay` (false), `pasteCategory`.
- Add `var weatherWidget: WeatherWidgetStyle` to `OverlayStyle`. Initialize to `.default` everywhere.

### Render Layout (`OverlayRenderModel.swift`)

**`WeatherWidgetRenderLayout` struct**: `style, rect: CGRect, condition, temperatureString, locationString, weekdayString, humidityString?, highString?, lowString?, windString?, feelsLikeString?, iconSize, cardCornerRadius`

**`weatherWidgetLayout(for:in:)` static func**:
1. Scale width/height by `element.scale` and `context.canvasScale`; compute `rect` via `centeredRect(for:size:canvasSize:)`.
2. Resolve temperature: base value from manual or cached Open-Meteo payload; if `useFITTemperature` and FIT has temperature at the playhead, override with FIT value.
3. Resolve condition via the same precedence chain.
4. Format all display strings (unit conversion, weekday from `activity.startDate`, optional fields).
5. Pure function — no networking, no side effects.

### SwiftUI Preview Views

**New file** `Sources/RunningOverlay/UI/WeatherWidgetOverlayViews.swift`:

- `WeatherWidgetOverlayView: View` — switches on `layout.style.preset`, dispatches to five private sub-views: `SimpleCardPresetView`, `CompactStripPresetView`, `ForecastTilePresetView`, `MinimalTextPresetView`, `DashboardBarPresetView`.
- Shared sub-component `WeatherConditionIconView(condition:size:)` — renders the bundled weather PNG for each condition; reused by all presets.
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
| Preset | Compact Styles icon buttons over all presets → `applyWeatherWidgetPreset`; no duplicate text-only Preset menu in 1.0 |
| Appearance | Palette, card opacity, corner radius, show divider, divider color, divider width, divider opacity |
| Location | API fetch buttons for activity/current location; TextField for `locationText`; toggles for showLocation, showWeekday |
| Weather | Combined content/temperature/metric/icon controls: condition, manual values, unit, Style-specific metric slots, showIcon, showConditionLabel |
| Layout | `OverlayLayoutInspectorRows` with position/scale/width/height bindings |
Shared `OverlayBackgroundInspectorModule`, `OverlayBorderInspectorModule`, and `OverlayEffectsInspectorModule` are intentionally omitted for Weather Widget 1.0.

When `dataSource` is an API source, Weather hides manual value text inputs because condition, temperature, and metric values are owned by the cached API payload. Unit and metric slot assignments remain editable.

Footer: Reset / Done.

### ProjectDocument Mutations (`ProjectDocument.swift`)

```swift
mutateWeatherWidgetStyle(_ id:, _ mutate:)               // registerUndoPoint
mutateWeatherWidgetStyleContinuous(_ id:, _ mutate:)     // registerContinuousUndoPoint
applyWeatherWidgetPreset(_ id:, preset:)                 // replaces visual/dimension defaults; preserves content fields + cachedWeather
fetchWeatherForActivityLocation(_ id:)                   // uses first FIT GPS route point
fetchWeatherForCurrentLocation(_ id:)                    // uses CoreLocation current device coordinate
fetchWeatherForNewWeatherWidget(_ id:)                   // automatic activity-location fetch without an undo step
```

Also update `defaultOverlayStyle(for:)` to set `style.weatherWidget = .preset(.simpleCard)` for `.weatherWidget`, then switch the new widget to `.openMeteo` with empty `locationText` and `cachedWeather = nil`.

### Routing

- **`ParameterPanelView.swift`** — add `else if element.type == .weatherWidget` branch routing to `WeatherWidgetOverlayDetailView`.
- **`OverlayPoolView.swift`** — add new `OverlayCategory` case `.weather` (label: "Weather"); register tile with `systemImage: "cloud.sun.fill"`.

### Phase 2: WeatherFetcher (`Sources/RunningOverlay/Weather/WeatherFetcher.swift`)

`WeatherFetcher` supports two API providers:

- Queries historical weather for the activity date (Open-Meteo archive API, free, no key required): `https://archive-api.open-meteo.com/v1/archive?latitude=…&start_date=…&end_date=…&hourly=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&timezone=auto`
- Pick the hour matching activity start time; derive daily H/L from full hourly array.
- Map WMO codes to `WeatherCondition` via `fromWMO(_:)`.
- Optional OpenWeather support uses the One Call 4.0 one-hour timeline with the
  activity timestamp and metric units:
  `https://api.openweathermap.org/data/4.0/onecall/timeline/1h?lat=…&lon=…&start=…&cnt=1&appid=…&units=metric`.
  The API key is entered in Project Settings and stored in macOS Keychain; it
  is not included in project snapshots or templates. OpenWeather timestamp
  responses provide current temperature, condition, humidity, wind, and
  feels-like values; high/low remain unavailable unless a future daily summary
  call is added.
- OpenWeather HTTP 401 responses explain that One Call 4.0 requires a separate
  subscription, that a new key or subscription may still be activating, that
  the first 1,000 calls per day are free, and that Open-Meteo is available as
  the no-key alternative. User-triggered 401 failures also raise a prominent,
  multi-line toast instead of relying only on the bottom status bar.
- Map OpenWeather condition ids and day/night icon ids to `WeatherCondition` via `fromOpenWeather(id:icon:)`.
- `WeatherLocationResolver` provides the two coordinate sources: first FIT route point or current CoreLocation location.
- Reverse geocoding fills `resolvedLocation`; if reverse geocoding fails, coordinates are used as a readable fallback.
- API failures are non-destructive: ProjectDocument keeps the previous cached/manual fields and reports the failure in `statusMessage`.
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

Implemented:

- Weather Widget is a dedicated overlay type with its own Weather category in the Overlay Pool.
- `WeatherWidgetStyle` stores preset, manual/FIT/Open-Meteo source selection, manual weather fields, display toggles, visual fields, and optional cached weather payload.
- `WeatherWidgetStyle.metricSlots` replaces the old global metric visibility behavior in rendering. Each Style exposes its own slot count, and every slot can choose `-`, Humidity, High / Low, Wind, or Feels Like.
- Inline metric rows render Feels Like as `Feels 12°C` so the secondary temperature is not confused with the current temperature; Dashboard Bar keeps `Feels` as the chip label and the temperature as the chip value.
- `WeatherFetcher` queries Open-Meteo historical hourly weather with current field names (`weather_code`, `relative_humidity_2m`, `apparent_temperature`, `wind_speed_10m`) and converts the result into `WeatherPayload`.
- Inspector has two API fetch buttons: activity GPS start location and current device location. A successful fetch switches the widget source to Open-Meteo, stores the payload in `cachedWeather`, and updates `locationText` from reverse geocoding.
- Five presets render in SwiftUI through `OverlaySharedWeatherWidgetView`: `simpleCard`, `compactStrip`, `forecastTile`, `minimalText`, and `dashboardBar`.
- The active SwiftUI preview/export path uses bundled transparent PNG weather icons, so conditions no longer rely on mixed SF Symbol silhouettes.
- Preset defaults now use app-like visual treatments instead of black-card variants: blue Simple Card, light Compact Strip, dark Forecast Tile, transparent Minimal Text, and graphite Dashboard Bar.
- `ProjectDocument.applyWeatherWidgetPreset` applies preset visual defaults while preserving content fields and cached weather data.
- Inspector now provides quick Styles icon buttons without a duplicate Preset menu, and orders setup as Preset, Appearance, then Location.
- Inspector combines Content, Temperature, Metrics, and Icon into one Weather section.
- Inspector exposes Style-specific metric slot menus instead of separate Humidity / High-Low / Wind / Feels Like toggles. Selecting `-` leaves that slot empty.
- Inspector hides manual value inputs in API modes, removes Icon Size from user-facing controls, and adds `showIcon`.
- Inspector provides editable condition label override in manual/FIT mode, palette selection in Appearance, and divider visibility/color/width/opacity controls.
- Inspector omits shared Background, Border, and Effects modules for Weather Widget 1.0 because they do not affect the custom SwiftUI preset renderer.
- Appearance no longer exposes Card Color; card surfaces are palette-owned for Weather Widget 1.0.
- Show Divider hides all preset divider lines while preserving the user's divider color, width, and opacity values.
- Simple Card tightens the left-side visual area before the divider, Forecast Tile renders divider lines around its metric area, and Dashboard Bar defaults to `560 x 112` to give metric chips enough height and width.
- Temperature strings include explicit units (`°C` / `°F`).
- Render model uses cached Open-Meteo values only when the selected data source is `.openMeteo`; FIT/manual modes are not overridden by stale cache data.
- Optional cached metrics render through the selected Style's metric slots.

Remaining:

- Add broader WMO edge-case tests beyond the initial parser/URL coverage.
- Add an app-bundle location usage description if the packaged macOS app needs a custom permission prompt.
- Expand automatic localization beyond the current location-text heuristic.

## Resolved Decisions

- **Condition label localization**: Auto-localized from activity coordinates (FIT GPS), not system locale. Every display field is user-editable; manual values override auto-localized ones.
- **Temperature unit default**: Follows system locale (°C or °F), with a per-widget override in Inspector.
- **API weather data**: Always historical weather for the activity date (Open-Meteo archive API). Running is always a past event; forecasts are not meaningful.
