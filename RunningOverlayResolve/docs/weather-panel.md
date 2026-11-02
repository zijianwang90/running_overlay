# Weather Panel

Last updated: 2026-11-01

## Purpose

The Resolve panel's Weather card has two separate paths:

| Path | Source | Saved | Rendered |
| --- | --- | --- | --- |
| Historical activity weather | Open-Meteo archive | Yes, in the project configuration and immutable activity bundle | Yes, by the Weather widget |
| Location search and 7-day forecast | Open-Meteo geocoding and forecast | No | No |

**Fetch historical weather** requests the archive hour containing the activity
start for the activity's first GPS point. The result is validated against the
activity identity, start instant and coordinates, saved with the project, copied
into the immutable activity data, and rendered offline by the Fuse. See
[Historical Weather](architecture.md#historical-weather-v14) and
[Weather Providers](weather-providers.md).

**Search location** resolves a typed place name to coordinates, and **7-day
forecast** shows the daily forecast for that place, or for the activity's first
GPS point when no search has been run. This path is a panel preview only: it
does not change the project, the saved weather, or the overlay, and it performs
no work in the background. The panel says so next to the controls.

## Keyless Requests

Both preview requests use the keyless Open-Meteo APIs through the shared
control-plane module `src/weather/weather.js`:

- `https://geocoding-api.open-meteo.com/v1/search` with `name` and `count=1`,
  implemented by `geocodeLocation(name)`.
- `https://api.open-meteo.com/v1/forecast` with `daily` weather code, high, low,
  precipitation probability and maximum wind, `timezone=UTC`,
  `wind_speed_unit=kmh` and `forecast_days`, implemented by
  `fetchWeatherForecast(coordinates, { days })`.

No key, token or account exists anywhere on this path. The renderer never
chooses a URL: it sends a place name or coordinates to `main.js`, which
validates the payload shape and calls the library. Requests use
`redirect: 'error'`, so they cannot leave Open-Meteo. The existing
`weather:fetch` archive request is unchanged.

## Why The Forecast Is Not Saved

`configuration.weather` is the activity's historical weather.
`isWeatherCurrent` accepts it only when the activity identity, start instant and
first GPS coordinates all match the selected activity. A searched place can be
anywhere on Earth, so writing its forecast into that field would either fail
validation or, worse, attach weather to an activity it does not describe.

Apply copies the validated historical snapshot into the immutable
`.roactivity` bundle. Forecasts are not part of that snapshot, are not written
by Apply, and are not read by the Fuse. Preview, Deliver and project handoff
therefore remain fully offline for the rendered card.

## Defaults And Limits

- Forecast length: 7 days. The library accepts 1 to 16 days; the panel requests
  7.
- Location search: at most 120 characters, trimmed before it is sent. Empty and
  control-character names are rejected by the library.
- Forecast values are shown in °C with whole-number high/low and a whole-number
  precipitation probability. Missing values render `--` rather than a guess.
- Both buttons are disabled while their request is in flight, and the forecast
  button is disabled until a search result or activity GPS coordinates exist.
- Search and forecast state resets when the selected activity changes.

## IPC Surface

| Channel | Payload | Result |
| --- | --- | --- |
| `weather:geocode` | `{ name: string }` | `{ name, latitude, longitude, country, admin1, timezone }` |
| `weather:forecast` | `{ latitude, longitude, days? }` | `{ source: 'openMeteo', days: [...], fetchedAt }` |

`preload.js` exposes these as `geocodeLocation(payload)` and
`fetchForecast(payload)` alongside the existing `fetchWeather(payload)`.

## Tests

```sh
cd RunningOverlayResolve && node --test test/widget-panel.test.js
```

The panel tests run the real `renderer.js` in a `vm` context with a stub API.
They cover a successful search (trimmed name, resolved place, enabled
forecast), a failed search (inline error, forecast stays disabled), a forecast
with one row per returned day that leaves `configuration.weather` untouched, and
a forecast without a search that uses the activity's first GPS point. The
library itself is covered by `test/weather.test.js`.
