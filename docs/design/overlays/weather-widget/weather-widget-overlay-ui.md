# Weather Widget Overlay UI Design Spec

Last updated: 2026-05-01

## Purpose

Weather Widget Overlay is a simple weather-app-style overlay for showing the day-of-run weather context on exported running videos. It should feel like a compact weather app plugin rather than a sport-specific performance module.

The first design pass is visual-only. Do not wire API fetching, FIT extraction, model persistence, or rendering until the preset language is approved.

## Design References

![Weather widget preset board](./weather-widget-presets.png)

![Weather icon set](./weather-icon-set.png)

## User Goals

- Show the current weather condition and temperature clearly.
- Use larger presets that can include location and country, such as `大阪, 日本`.
- Support small corner-friendly presets for videos where weather is secondary.
- Keep weather icons visually consistent across all presets.
- Allow future data to come from FIT temperature, a weather API, or manual fallback values.

## Content Model

Required display fields:

- `condition`: weather state with auto-localized label derived from activity coordinates (not system locale), e.g. `雨` in Japan, `Rain` in US. Every field is user-overridable; manual edits take precedence over auto-localized values.
- `temperature`: current temperature, e.g. `13°C`. Unit defaults to system locale (°C or °F), user-adjustable per widget.

Optional display fields:

- `location`: city and country/region, e.g. `大阪, 日本`.
- `weekday`: localized weekday, e.g. `星期四`.
- `humidity`: relative humidity, e.g. `87% RH`.
- `highTemperature`: daily high, e.g. `H 16°`.
- `lowTemperature`: daily low, e.g. `L 11°`.
- `wind`: wind speed, e.g. `9 km/h`.
- `feelsLike`: apparent temperature, e.g. `Feels 12°`.

## Presets

### Simple Card

Medium rounded rectangle inspired by a clear weather app widget.

Layout:

- Left block: large condition label, e.g. `雨`, plus a large weather icon.
- Center divider: thin vertical rule.
- Right block: `大阪, 日本`, weekday, large `13°C`, humidity.

Default size target: `300 x 110`.

Use this as the default preset because it communicates weather and location with the least explanation.

### Compact Strip

Small horizontal strip for corner placement.

Layout:

- Icon on the left.
- Large temperature.
- Secondary condition and city text.

Default size target: `220 x 56`.

Use when weather is supporting context rather than a primary visual.

### Forecast Tile

Square-ish tile for a richer weather readout.

Layout:

- Top: city/country.
- Center: large icon and temperature.
- Bottom: high, low, humidity.

Default size target: `180 x 180`.

Use for social clips, title-card moments, or videos where weather is part of the story.

### Minimal Text

Lightweight text-first preset with no heavy container.

Layout:

- Location above.
- Large temperature.
- Condition and small icon adjacent or below.

Default size target: content-driven, minimum `160 x 92`.

Use when the editor wants a subtle overlay that does not obscure video content.

### Dashboard Bar

Wide information bar for dashboard-like weather context.

Layout:

- Left: location and condition.
- Middle: large temperature.
- Right: compact metric chips for humidity, wind, and feels-like temperature.

Default size target: `460 x 86`.

Use when more weather metrics matter and there is enough horizontal space.

## Icon System

All weather icons must come from one visual family.

Rules:

- Use a `64 x 64` icon grid as the base design box.
- Keep consistent optical weight across icons.
- Prefer rounded filled shapes with a subtle shared highlight/shadow treatment.
- Avoid mixing outline-only, emoji-like, realistic, and cartoon icon styles.
- Use one coherent palette family:
  - Sunny: warm yellow/orange.
  - Clear night: navy plus pale moon.
  - Cloud states: cool cyan/blue-gray.
  - Rain/heavy rain: blue.
  - Thunder: cloud blue plus yellow lightning.
  - Snow: icy cyan.
  - Fog: gray-blue.
  - Wind: teal-gray.
- Icons should scale cleanly to `20`, `32`, `48`, and `64` px without changing style.

Initial conditions to cover:

- Sunny
- Clear Night
- Partly Cloudy
- Cloudy
- Rain
- Heavy Rain
- Thunder
- Snow
- Fog
- Wind

## Visual Rules

- Do not make the weather widget feel like a running metric by default.
- Larger presets must have a clear location slot.
- Text must remain readable on video; use subtle shadow or translucent backing when needed.
- Avoid decorative background blobs or purely atmospheric graphics.
- Keep cards practical: stable dimensions, predictable alignment, no nested card structures.
- Use 8-18 px corner radii for card presets; compact strip may use a pill radius.
- Prefer blue, white, graphite, and pale sky surfaces with weather-specific accents.
- Avoid purple-heavy palettes.

## Data Strategy

Phase 1 can be manual/FIT-first:

- Current temperature may read from FIT temperature when available.
- If FIT temperature is absent, use manual temperature.
- Condition, high/low, humidity, wind, and feels-like values can be manual fields.

Phase 2 can add weather API support:

- Query historical weather for the activity date (Open-Meteo archive API), not current forecast. Running data is always past events; a forecast is meaningless.
- Use GPS start point from FIT or manually selected location.
- Auto-localize condition labels from activity coordinates (e.g. Japan → Japanese labels), not from system locale. All fields remain user-editable.
- Cache resolved weather data in the project to make export deterministic.
- Keep API failures non-destructive by falling back to manual fields.

## Inspector Guidance

Recommended sections:

- Preset
- Content
- Location
- Temperature
- Metrics
- Icon
- Layout
- Appearance
- Effects

Key controls:

- Preset picker: Simple Card, Compact Strip, Forecast Tile, Minimal Text, Dashboard Bar.
- Condition picker using the shared icon set. Condition labels auto-localize from activity coordinates; user can override any field.
- Data source picker: FIT Temperature, Manual, Weather API later.
- Manual temperature fields with unit picker (°C / °F), defaulting to system locale.
- Location text fields.
- Toggles for weekday, humidity, high/low, wind, feels-like.
- Background opacity and card color.
- Accent color only when the preset uses it.

## Implementation Notes

- Treat this as a dedicated overlay type rather than a numeric temperature variant. It combines icon, condition, location, and optional weather metrics.
- The icon set should be implemented once and reused by every preset.
- Preview and export must share the same render layout.
- API-backed weather must be cached before export so videos are reproducible offline.

## Resolved Decisions

- **Condition label localization**: Auto-localized from activity coordinates (FIT GPS), not system locale. Every display field is user-editable; manual values override auto-localized ones.
- **Temperature unit default**: Follows system locale (°C or °F), with a per-widget override in Inspector.
- **API weather data**: Always historical weather for the activity date (Open-Meteo archive API). Running is always a past event; forecasts are not meaningful.
