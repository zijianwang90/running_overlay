# Weather Providers

Last updated: 2026-11-01

## Policy

Running Overlay Resolve never ships an API key. The default weather path is
Open-Meteo, which requires no account and no key. Any provider that needs a
credential is opt-in, uses a key the user supplies for their own machine, and
stores that key only in local project settings. Keys are never committed,
written into bundles, templates, logs, or support output, and never placed in a
URL that the renderer can choose.

`src/weather/weather.js` is the single control-plane weather module. Every
request URL is constructed inside it, includes no token or key parameter, and is
issued with `redirect: 'error'` so a request cannot leave the selected provider.
The Fuse and the renderer never perform network access; they read the cached
snapshot written by Apply.

## Injection

All fetchers accept the same options so tests and the panel can control them:

```js
{ fetchImpl = globalThis.fetch, now = () => new Date(), timeoutMs = 15_000 }
```

Each request uses an `AbortController`; an abort becomes a "timed out" error.
Tests use a mocked `fetchImpl` and perform no network access.

## Open-Meteo Geocoding

`geocodeLocation(name, options)` resolves a user-typed place name to
coordinates.

- Endpoint: `https://geocoding-api.open-meteo.com/v1/search`
- Query: `name=<trimmed name>`, `count=1`
- Name validation: non-empty after trimming, at most 120 characters, no control
  characters.
- Result: the first match as
  `{ name, latitude, longitude, country, admin1, timezone }`. Missing string
  fields are `null`; coordinates are always finite numbers.
- Errors: `Location not found.` for an empty result list, an "unreadable
  response" error for a malformed payload, and `Location search returned invalid
  coordinates.` for non-finite or out-of-range coordinates.

The returned coordinates feed `fetchWeatherForecast`. These functions perform
no background work: the panel calls them only from an explicit user action.

## Open-Meteo Daily Forecast

`fetchWeatherForecast({ latitude, longitude }, options)` returns a normalized
daily forecast.

- Endpoint: `https://api.open-meteo.com/v1/forecast`
- Validation: latitude in `[-90, 90]`, longitude in `[-180, 180]`, both finite;
  `days` (an option) is a whole number from 1 to 16 and defaults to 7.
- Query: `latitude`, `longitude`, `daily=weather_code,temperature_2m_max,
  temperature_2m_min,precipitation_probability_max,wind_speed_10m_max`,
  `timezone=UTC`, `wind_speed_unit=kmh`, `forecast_days=<days>`.
- Result:

```js
{
  source: 'openMeteo',
  days: [
    {
      date: '2026-11-01',          // ISO calendar day
      condition: 'rain',           // conditionForCode(weather_code)
      highC: 14.2,                 // null when unavailable
      lowC: 5.1,                   // null when unavailable
      precipitationProbability: 80, // 0-100, null when unavailable
      windKph: 12.4,               // null when unavailable
    },
  ],
  fetchedAt: '2026-11-01T12:00:00.000Z',
}
```

`condition` uses the shared ten-condition mapping, so forecast and historical
weather render with the same icon family. Unknown or absent codes read as
`cloudy`. Days with an unparseable date are skipped; a payload with no usable
day is rejected. Missing arrays or arrays that do not match the `time` length
raise `Weather service returned incomplete daily data.` HTTP failures report the
status, and unreadable JSON is reported separately.

## Historical Activity Weather

`fetchActivityWeather(activity, options)` remains the archive path for the
activity date and is unchanged. It queries
`https://archive-api.open-meteo.com/v1/archive` for one UTC day with
`timezone=UTC` and `wind_speed_unit=kmh`, selects the hour containing the
activity start, and records the activity identity, start instant, and first GPS
point so a cached snapshot cannot silently belong to another activity.

## Future Providers

A provider that requires a key is allowed only under these conditions:

- the user enters the key in local project settings; it is never bundled or
  prefilled;
- the key is read from those settings, never from an environment variable or a
  committed file;
- the key is sent in an authorization header or the provider's documented
  parameter, never written into saved bundles, templates, logs, or user-visible
  errors;
- Open-Meteo remains the keyless default, and provider failures fall back to the
  cached or manual values without discarding them.

No OpenWeather, Mapbox, or other key path is implemented by the geocoding and
forecast additions. The existing weather widget design notes still describe
OpenWeather as an optional future source; this document records the key policy
that such a source must follow.
