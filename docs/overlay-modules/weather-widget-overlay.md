# Weather Widget Overlay

Last updated: 2026-11-09

> **Status: bundled component.** The native `.weatherWidget` element and
> `WeatherWidgetOverlayDetailView` were removed without migration (ADR 0015).
> Weather Widget is now the bundled `studio.weather-widget` component, whose
> `weatherWidget` host node exposes the same renderer and data-source settings
> through the generated component Inspector; older elements of the native type
> are dropped on load. The project-level weather cache and API fetch described
> below still apply to the component. This document remains the rendering and
> design reference for that node.
>
> **Single card template (2026-11-09).** The `Preset` control and the
> `compactStrip`, `forecastTile`, `minimalText` and `dashboardBar` templates
> were removed. Only the polished Simple Card remains, at its original
> `300 x 110` default with one inline metric slot. A future alternative
> presentation should ship as a separate component instead of a preset value.

## Purpose

Weather Widget Overlay shows simple day-of-run weather context on top of a video. The module should feel like a weather app plugin: clear condition, temperature, and optional location/secondary metrics.

Design spec:

- [Weather Widget Overlay UI](../design/overlays/weather-widget/weather-widget-overlay-ui.md)
- [Structured spec](../design/overlays/weather-widget/weather-widget-overlay-ui.spec.json)
- [Icon set](../design/overlays/weather-widget/weather-icon-set.png)

## User Goals

- Show weather and temperature without requiring a full dashboard.
- Include location/country once weather data or a manual location is available.
- Keep all weather condition icons visually consistent.
- Use FIT or manual weather data first, then support API-backed weather later.

## Data Inputs

Phase 1:

- FIT temperature when available.
- Manual current temperature.
- Manual condition.
- Manual location.
- Manual humidity, high/low, wind, and feels-like values when enabled.

Phase 2:

- Activity start timestamp.
- GPS start point from FIT (used for coordinate-based localization and weather lookup).
- Historical weather from Open-Meteo archive API (activity date, not current forecast). Cached into the project for export determinism.

## Rendering Model

Recommended layout pipeline:

1. Resolve visible fields.
2. Resolve weather data from API cache or manual fields. If API data is
   unavailable, use a neutral Sunny condition/icon and placeholder strings for
   location, temperature, and secondary metrics.
3. Resolve the weather icon from the shared condition icon set.
4. Lay out the card regions: icon, temperature, condition, location, and one
   inline metric.
5. Draw the optional card background and divider.
6. Draw icon and text.
7. Apply shadow/glow only as readability aids.

## Card

The widget has one template, Simple Card:

- Default blue translucent card at `300 x 110`.
- Left block: condition label plus a large weather icon.
- Center divider: thin vertical rule close to the icon group.
- Right block: location, weekday, large temperature, and one inline metric
  (Humidity by default).

Content and appearance remain parameterized, so the card can be resized,
recolored, and relabeled without switching templates.

## Icon Assets

Weather Widget uses production PNG icons, not cropped bitmap slices, so the icons remain sharp at every card scale.

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

- Layout (host position/scale/opacity plus the component width and height)
- Effects
- Component
- Weather
- Weather Data, Visibility, Labels, Card, Slots and text sections generated
  from the component definition

Weather Widget 1.0 does not expose the shared Background or Border inspector modules. The card does not consume those generic overlay fields, so the user-facing customization surface is intentionally limited to fields that render reliably.

Collapsed Weather Widget Inspector section headers follow the regular single-separator pattern so adjacent section boundaries stay one thin line.

The Inspector exposes one explicit API fetch action in the Location section:

- Activity Location: fetches Open-Meteo historical weather for the activity start date using the first FIT GPS route point. Disabled when the activity has no GPS route.

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

**`WeatherFetchLocationMode` enum** — `activityLocation` is the active fetch mode. The legacy `currentLocation` raw value remains decodable so older project caches stay compatible.

**`WeatherPayload` struct** (Equatable, Codable) — cached result from FIT or API: `condition, temperatureCelsius, humidity?, highTemperatureCelsius?, lowTemperatureCelsius?, windKph?, feelsLikeCelsius?, resolvedLocation?, sourceDate?, fetchLocationMode?`

**`WeatherWidgetStyle` struct** (Equatable, Codable):

```
dataSource: WeatherDataSource
manualCondition / manualTemperatureCelsius / manualHumidity / manualHigh / manualLow / manualWind / manualFeelsLike
temperatureUnit: WeatherTemperatureUnit
locationText: String
showLocation / showWeekday / showHumidity / showHighLow / showWind / showFeelsLike: Bool
metricSlots: [WeatherMetricSlotValue] // one inline slot; extra values are dropped
cardBackgroundColor: OverlayColor // persisted legacy/style field; not exposed as a 1.0 Inspector control
cardBackgroundOpacity / cardCornerRadius / iconSize: Double
dividerColor: OverlayColor
dividerEnabled: Bool
dividerThickness / dividerOpacity: Double
showIcon / showConditionLabel: Bool
width / height: Double
cachedWeather: WeatherPayload?     // nil = not yet fetched; round-trips through Codable project snapshot
```

`WeatherWidgetStyle.simpleCard` holds the single card's width, height and visual defaults while leaving content fields at defaults. `ProjectDocument.defaultOverlayStyle(for:)` switches newly added Weather Widget overlays to Open-Meteo with empty location text and no cached payload so the first render uses placeholders until the automatic activity-location fetch succeeds.

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

- `OverlaySharedWeatherWidgetView` renders the single `SimpleCardWeatherView`.
- Shared sub-component `WeatherConditionIconView(condition:size:)` — renders the bundled weather PNG for each condition.
- Thin `OverlaySharedWeatherWidgetView` wrapper to match the project's existing naming convention.

**`PreviewCanvasView.swift`** — add case in the per-type dispatch:
```swift
case .weatherWidget:
    let layout = OverlayRenderModel.weatherWidgetLayout(for: element, in: renderContext)
    OverlaySharedWeatherWidgetView(element: element, layout: layout)
        .overlayForegroundEffects(element: element)
```

### Export Renderer (`SwiftUIOverlayVideoExporter`)

Product preview and export share `SkiaWeatherWidgetModule` and its render model.
`SwiftUIOverlayVideoExporter` coordinates export; its retained SwiftUI comparison
backend rasterizes the shared weather view with `ImageRenderer`.

### Inspector UI (`WeatherWidgetOverlayDetailView.swift`)

New file following the dense detail view structure of the other overlay Inspectors. Use `InspectorDense*` primitives directly — no wrappers.

| Section | Key controls |
|---|---|
| Layout | Host position/scale/opacity plus the component width and height bindings |
| Effects | Host shadow/glow controls |
| Component | Component metadata and "Duplicate to My Components" |
| Weather | Cached snapshot readout and activity-location fetch action |
| Weather Data / Visibility / Labels / Card / Slots / Text | Generated from the component definition |
Shared `OverlayBackgroundInspectorModule` and `OverlayBorderInspectorModule` are intentionally omitted for Weather Widget 1.0.

When `dataSource` is an API source, Weather hides manual value text inputs because condition, temperature, and metric values are owned by the cached API payload. Unit and metric slot assignments remain editable.

Reset Style (shared detail header action menu) restores the card defaults and keeps the temperature unit. There is no footer.

### ProjectDocument Mutations (`ProjectDocument.swift`)

```swift
mutateWeatherWidgetStyle(_ id:, _ mutate:)               // registerUndoPoint
mutateWeatherWidgetStyleContinuous(_ id:, _ mutate:)     // registerContinuousUndoPoint
fetchWeatherForActivityLocation(_ id:)                   // uses first FIT GPS route point
fetchWeatherForNewWeatherWidget(_ id:)                   // automatic activity-location fetch without an undo step
```

Also update `defaultOverlayStyle(for:)` to set `style.weatherWidget = .simpleCard` for `.weatherWidget`, then switch the new widget to `.openMeteo` with empty `locationText` and `cachedWeather = nil`.

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
- `WeatherLocationResolver` uses the first FIT route point and reverse geocodes it into readable location text.
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
6. Shared Skia preview/export module and retained SwiftUI comparison path
7. Overlay Pool tile registration
8. `ParameterPanelView` routing
9. Inspector detail view
10. `WeatherFetcher` (Phase 2)
11. Tests

## Current Implementation

Implemented:

- Weather Widget is a dedicated overlay type with its own Weather category in the Overlay Pool.
- `WeatherWidgetStyle` stores manual/FIT/Open-Meteo source selection, manual weather fields, display toggles, visual fields, and optional cached weather payload.
- `WeatherWidgetStyle.metricSlots` holds the single inline metric and can choose `-`, Humidity, High / Low, Wind, or Feels Like.
- The inline metric renders Feels Like as `Feels 12°C` so the secondary temperature is not confused with the current temperature.
- `WeatherFetcher` queries Open-Meteo historical hourly weather with current field names (`weather_code`, `relative_humidity_2m`, `apparent_temperature`, `wind_speed_10m`) and converts the result into `WeatherPayload`.
- Inspector has one API fetch button for the activity GPS start location. A successful fetch stores the selected provider payload in `cachedWeather` and updates `locationText` from reverse geocoding.
- The card renders in SwiftUI through `OverlaySharedWeatherWidgetView` and in Skia through `SkiaWeatherWidgetModule`.
- The active SwiftUI preview/export path uses bundled transparent PNG weather icons, so conditions no longer rely on mixed SF Symbol silhouettes.
- The card uses the original app-like blue treatment rather than a black-card variant.
- Inspector exposes one inline metric slot menu instead of separate Humidity / High-Low / Wind / Feels Like toggles. Selecting `-` leaves the slot empty.
- Inspector hides manual value inputs in API modes, removes Icon Size from user-facing controls, and adds `showIcon`.
- Inspector provides editable condition label override in manual/FIT mode, palette selection in Appearance, and divider visibility/color/width/opacity controls.
- Inspector omits shared Background and Border modules for Weather Widget 1.0 because they do not affect the custom card renderer.
- Appearance no longer exposes Card Color; card surfaces are palette-owned for Weather Widget 1.0.
- Show Divider hides the card divider while preserving the user's divider color, width, and opacity values.
- The card tightens the left-side visual area before the divider and defaults to `300 x 110`.
- Temperature strings include explicit units (`°C` / `°F`).
- Render model uses cached Open-Meteo values only when the selected data source is `.openMeteo`; FIT/manual modes are not overridden by stale cache data.
- The optional cached metric renders through the card's inline slot.
- The declarative `studio.weather-widget` component (M5i) renders the same
  native module through the `weatherWidget` capability node. Its `dataSource`
  param selects manual values or an API source; API sources render the
  project-level `weatherCache`, so one fetch serves every weather component and
  the snapshot persists with the project. The Inspector shows the cached
  snapshot and fetches it for weather-capable components. Components never
  reach the network.

Remaining:

- Add broader WMO edge-case tests beyond the initial parser/URL coverage.
- Keep the packaged app free of location permission prompts while weather lookup uses only imported FIT coordinates.
- Expand automatic localization beyond the current location-text heuristic.

## Resolved Decisions

- **Condition label localization**: Auto-localized from activity coordinates (FIT GPS), not system locale. Every display field is user-editable; manual values override auto-localized ones.
- **Temperature unit default**: Follows system locale (°C or °F), with a per-widget override in Inspector.
- **API weather data**: Always historical weather for the activity date (Open-Meteo archive API). Running is always a past event; forecasts are not meaningful.
