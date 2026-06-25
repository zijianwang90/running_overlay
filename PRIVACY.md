# Privacy

Running Overlay processes source videos and FIT activity files that may contain
private location, health, device, timestamp, and training information.

## Local Processing

Source videos, FIT files, timeline edits, overlay layouts, preview frames, and
exported videos are processed locally on the Mac. The current application does
not include account login, cloud sync, advertising, analytics, telemetry
upload, or crash-reporting services.

Running Overlay reads files selected by the user and writes project snapshots,
templates, diagnostics, and exported media only to locations selected by the
user or to documented local application storage.

Project snapshots may contain:

- local media and asset paths;
- parsed activity timestamps, GPS coordinates, and fitness metrics;
- timeline and overlay configuration;
- cached weather responses and resolved location labels.

Project snapshots do not contain OpenWeather API keys in current versions.
Treat snapshots as private activity data unless they have been intentionally
sanitized.

## Weather and Location Requests

Weather data is requested only when the user selects an API-backed Weather
overlay or triggers a weather refresh.

- Open-Meteo requests receive the selected activity's latitude and longitude,
  activity date, and requested weather fields.
- OpenWeather requests receive latitude, longitude, activity timestamp,
  requested units, and the user's OpenWeather API key.
- macOS geocoding services may be used to resolve the FIT activity coordinate
  into a readable place name. Running Overlay does not request the Mac's
  current location.

Source videos, preview frames, exported overlays, complete FIT files, heart-rate
streams, cadence, pace, power, and layout templates are not uploaded to the
weather providers by Running Overlay.

Weather responses are cached in the Weather overlay configuration so preview
and export remain deterministic without repeated requests.

## Credentials

The OpenWeather API key is stored as a generic password in the macOS Keychain.
It is not written to project settings, project snapshots, templates, logs, or
test fixtures.

When an older project snapshot containing an `openWeatherAPIKey` field is
opened, Running Overlay migrates the value to Keychain. Saving the snapshot
again removes the legacy credential field.

## Public Issues and Contributions

Do not post private videos, FIT/GPX/TCX files, GPS traces, health metrics,
device identifiers, API keys, signing material, project snapshots, screenshots
with sensitive paths, or local preferences in public issues or pull requests.
Use synthetic or deliberately sanitized fixtures.

## Policy Changes

Any contribution that adds or changes network access, analytics, telemetry,
cloud sync, crash reporting, account behavior, credential storage, or user-data
retention must update this policy, user-facing documentation, tests, and the
open-source audit in the same pull request.
