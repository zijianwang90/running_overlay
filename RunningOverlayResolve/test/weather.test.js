'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { conditionForCode, fetchActivityWeather, geocodeLocation, fetchWeatherForecast, validateWeather,
  weatherRenderValues, isWeatherCurrent } = require('../src/weather/weather');

const activity = {
  schemaVersion: 1,
  activityId: 'synthetic-weather',
  startUtcUs: 1_783_016_700_000_000, // 2026-07-02T18:25:00Z
  endUtcUs: 1_783_019_700_000_000,
  records: [
    { elapsedUs: 0, latitude: 43.653226, longitude: -79.383184, routeSegment: 0 },
    { elapsedUs: 60_000_000, latitude: null, longitude: null, routeSegment: null },
  ],
  annotations: [],
};

const hourly = (overrides = {}) => ({
  time: ['2026-07-02T17:00', '2026-07-02T18:00', '2026-07-02T19:00', '2026-07-03T00:00'],
  temperature_2m: [20, 21.4, 23, 99],
  relative_humidity_2m: [70, 68, 60, 50],
  apparent_temperature: [19.5, 21, 22.5, 98],
  weather_code: [3, 61, 2, 0],
  wind_speed_10m: [8, 9.5, 10, 5],
  ...overrides,
});
const response = (body, status = 200) => ({ ok: status >= 200 && status < 300, status, json: async () => body });

test('fetch selects the activity UTC hour with a mocked API and no network', async () => {
  let requested;
  const weather = await fetchActivityWeather(activity, {
    fetchImpl: async (url) => { requested = new URL(url); return response({ hourly: hourly() }); },
    now: () => new Date('2026-07-02T20:00:00Z'),
  });
  assert.equal(requested.host, 'archive-api.open-meteo.com');
  assert.equal(requested.searchParams.get('start_date'), '2026-07-02');
  assert.equal(requested.searchParams.get('end_date'), '2026-07-02');
  assert.equal(requested.searchParams.get('timezone'), 'UTC');
  assert.equal(requested.searchParams.get('latitude'), '43.65323');
  assert.equal(requested.searchParams.get('longitude'), '-79.38318');
  assert.match(requested.searchParams.get('hourly'), /weather_code/);
  // 18:25Z selects the 18:00 UTC row, not the device-local hour.
  assert.equal(weather.temperatureC, 21.4);
  assert.equal(weather.condition, 'rain');
  assert.equal(weather.humidity, 68);
  assert.equal(weather.highC, 23);
  assert.equal(weather.lowC, 20);
  assert.equal(weather.windKph, 9.5);
  assert.equal(weather.feelsLikeC, 21);
  assert.equal(weather.location, '43.6532, -79.3832');
  assert.equal(weather.weekday, 'Thursday');
  assert.equal(weather.fetchedAt, '2026-07-02T20:00:00.000Z');
  assert.equal(weather.activityId, activity.activityId);
  assert.equal(weather.sourceUtcUs, activity.startUtcUs);
});

test('the initial hour wins over a later nearer-to-the-minute sample', async () => {
  const weather = await fetchActivityWeather(activity, {
    fetchImpl: async () => response({ hourly: hourly() }),
    now: () => new Date('2026-07-02T20:00:00Z'),
  });
  assert.equal(weather.temperatureC, 21.4);
  assert.equal(weather.condition, 'rain');
});

test('the nearest sample is used when the activity hour is absent', async () => {
  const missingHour = hourly();
  missingHour.time = ['2026-07-02T17:00', '2026-07-02T19:00', '2026-07-03T00:00'];
  missingHour.temperature_2m = [20, 23, 99];
  missingHour.relative_humidity_2m = [70, 60, 50];
  missingHour.apparent_temperature = [19.5, 22.5, 98];
  missingHour.weather_code = [3, 2, 0];
  missingHour.wind_speed_10m = [8, 10, 5];
  const weather = await fetchActivityWeather({ ...activity, startUtcUs: 1_783_017_900_000_000 }, {
    fetchImpl: async () => response({ hourly: missingHour }),
    now: () => new Date('2026-07-02T20:00:00Z'),
  });
  assert.equal(weather.temperatureC, 23);
  assert.equal(weather.condition, 'partlyCloudy');
});

test('WMO codes match the Mac mapping and unknown codes read as cloudy', () => {
  assert.deepEqual([0, 1, 2, 3, 45, 48, 61, 65, 67, 80, 71, 86, 95, 99, 7, null].map(conditionForCode),
    ['sunny', 'sunny', 'partlyCloudy', 'cloudy', 'fog', 'fog', 'rain', 'rain', 'heavyRain', 'heavyRain',
      'snow', 'snow', 'thunder', 'thunder', 'cloudy', 'cloudy']);
});

test('invalid, missing and out-of-range API data is rejected without leaking a URL', async () => {
  const run = (body, options = {}) => fetchActivityWeather(activity, {
    fetchImpl: async () => response(body, options.status ?? 200), now: () => new Date('2026-07-02T20:00:00Z'),
  });
  await assert.rejects(run({ error: true, reason: 'No data' }), /could not provide historical weather/);
  await assert.rejects(run({ hourly: { time: [], temperature_2m: [] } }), /incomplete hourly data/);
  await assert.rejects(run({ hourly: hourly({ temperature_2m: [null, null, null, null] }) }), /no usable temperatures/);
  await assert.rejects(run({}, { status: 503 }), /failed \(503\)/);
  const weather = await run({ hourly: hourly({ temperature_2m: [null, 21.4, null, null], weather_code: [null, null, null, null] }) });
  assert.equal(weather.condition, 'cloudy');
  assert.equal(weather.highC, 21.4);
  assert.equal(weather.lowC, 21.4);
  const errors = [];
  for (const field of ['temperatureC', 'humidity', 'windKph', 'feelsLikeC', 'highC', 'lowC']) {
    try { await run({ hourly: hourly({ [field === 'temperatureC' ? 'temperature_2m' : field]: [Number.NaN] }) }); }
    catch (error) { errors.push(field); }
  }
  assert.ok(errors.length > 0);
});

test('weather needs GPS and a fetch implementation', async () => {
  await assert.rejects(fetchActivityWeather({ ...activity, records: [{ elapsedUs: 0, latitude: null, longitude: null, routeSegment: null }] }),
    /GPS/);
  await assert.rejects(fetchActivityWeather(activity, { fetchImpl: null }), /unavailable/);
});

test('saved weather is bound to the activity identity, start and first GPS point', () => {
  const weather = { source: 'openMeteo', activityId: activity.activityId, sourceUtcUs: activity.startUtcUs, latitude: 43.653226, longitude: -79.383184,
    condition: 'rain', temperatureC: 21.4, humidity: 68, highC: 23, lowC: 20, windKph: 9.5, feelsLikeC: 21,
    location: 'Toronto', weekday: 'Thursday', fetchedAt: '2026-07-02T20:00:00.000Z' };
  assert.deepEqual(validateWeather(weather, activity), weather);
  assert.equal(validateWeather(null, activity), null);
  assert.equal(isWeatherCurrent(weather, activity), true);
  assert.equal(isWeatherCurrent(weather, { ...activity, activityId: 'other' }), false);
  assert.equal(isWeatherCurrent(weather, { ...activity, startUtcUs: activity.startUtcUs + 1_000_000 }), false);
  assert.equal(isWeatherCurrent(weather, { ...activity, records: [{ elapsedUs: 0, latitude: 1, longitude: 2, routeSegment: 0 }] }), false);
  assert.throws(() => validateWeather({ ...weather, condition: 'hail' }, activity), /condition/);
  assert.throws(() => validateWeather({ ...weather, temperatureC: Number.POSITIVE_INFINITY }, activity), /temperature/);
  assert.throws(() => validateWeather({ ...weather, location: 'a\tb' }, activity), /location/);
  assert.throws(() => validateWeather({ ...weather, fetchedAt: 'yesterday' }, activity), /fetch time/);
  assert.throws(() => validateWeather({ ...weather, activityId: 'other' }, activity), /different activity/);
});

const abortError = () => Object.assign(new Error('aborted'), { name: 'AbortError' });

test('geocoding returns the first match with keyless URL parameters', async () => {
  let requested;
  const location = await geocodeLocation('  Toronto  ', {
    fetchImpl: async (url) => {
      requested = new URL(url);
      return response({ results: [
        { name: 'Toronto', latitude: 43.6532, longitude: -79.3832, country: 'Canada', admin1: 'Ontario', timezone: 'America/Toronto' },
        { name: 'Toronto', latitude: 1, longitude: 2, country: 'Elsewhere', admin1: null, timezone: 'UTC' },
      ] });
    },
  });
  assert.equal(requested.host, 'geocoding-api.open-meteo.com');
  assert.equal(requested.pathname, '/v1/search');
  assert.equal(requested.searchParams.get('name'), 'Toronto');
  assert.equal(requested.searchParams.get('count'), '1');
  for (const key of ['access_token', 'api_key', 'appid']) assert.equal(requested.searchParams.get(key), null);
  assert.deepEqual(location, { name: 'Toronto', latitude: 43.6532, longitude: -79.3832, country: 'Canada',
    admin1: 'Ontario', timezone: 'America/Toronto' });
});

test('geocoding keeps missing result fields null', async () => {
  const location = await geocodeLocation('Nowhere', {
    fetchImpl: async () => response({ results: [{ latitude: 10, longitude: 20 }] }),
  });
  assert.deepEqual(location, { name: null, latitude: 10, longitude: 20, country: null, admin1: null, timezone: null });
});

test('geocoding reports empty results and invalid coordinates', async () => {
  const run = (body) => geocodeLocation('Atlantis', { fetchImpl: async () => response(body) });
  await assert.rejects(run({ results: [] }), /Location not found\./);
  await assert.rejects(run({}), /unreadable response/);
  await assert.rejects(run({ error: true }), /Try a different name/);
  await assert.rejects(run({ results: [{ name: 'Bad', latitude: Number.POSITIVE_INFINITY, longitude: 0 }] }), /invalid coordinates/);
  await assert.rejects(run({ results: [{ name: 'Bad', latitude: 0, longitude: Number.NaN }] }), /invalid coordinates/);
});

test('geocoding validates the search text before fetching', async () => {
  const never = async () => { throw new Error('fetch should not run'); };
  await assert.rejects(geocodeLocation('', { fetchImpl: never }), /Choose a location/);
  await assert.rejects(geocodeLocation('   ', { fetchImpl: never }), /Choose a location/);
  await assert.rejects(geocodeLocation(null, { fetchImpl: never }), /Choose a location/);
  await assert.rejects(geocodeLocation('a'.repeat(121), { fetchImpl: never }), /120 characters/);
  await assert.rejects(geocodeLocation('Bad\u0000Name', { fetchImpl: never }), /control characters/);
  await assert.rejects(geocodeLocation('Toronto', { fetchImpl: null }), /unavailable/);
});

test('geocoding surfaces timeouts, unreadable JSON and HTTP errors', async () => {
  await assert.rejects(geocodeLocation('Toronto', { fetchImpl: async () => { throw abortError(); } }), /timed out/);
  await assert.rejects(geocodeLocation('Toronto', {
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => { throw new SyntaxError('bad'); } }),
  }), /unreadable response/);
  await assert.rejects(geocodeLocation('Toronto', { fetchImpl: async () => response({}, 429) }), /failed \(429\)/);
});

const forecastPayload = (overrides = {}) => ({
  daily: {
    time: ['2026-11-01', '2026-11-02', '2026-11-03'],
    weather_code: [0, 61, 95],
    temperature_2m_max: [14.2, 12.5, 16],
    temperature_2m_min: [5.1, 4.8, 7],
    precipitation_probability_max: [0, 80, 45],
    wind_speed_10m_max: [12.4, 20, 8],
    ...overrides,
  },
});

test('forecast requests keyless daily fields and normalizes each day', async () => {
  let requested;
  const forecast = await fetchWeatherForecast({ latitude: 43.653226, longitude: -79.383184 }, {
    fetchImpl: async (url) => { requested = new URL(url); return response(forecastPayload()); },
    now: () => new Date('2026-11-01T12:00:00Z'),
    days: 3,
  });
  assert.equal(requested.host, 'api.open-meteo.com');
  assert.equal(requested.pathname, '/v1/forecast');
  assert.equal(requested.searchParams.get('latitude'), '43.65323');
  assert.equal(requested.searchParams.get('longitude'), '-79.38318');
  assert.equal(requested.searchParams.get('daily'),
    'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max');
  assert.equal(requested.searchParams.get('timezone'), 'UTC');
  assert.equal(requested.searchParams.get('wind_speed_unit'), 'kmh');
  assert.equal(requested.searchParams.get('forecast_days'), '3');
  for (const key of ['access_token', 'api_key', 'appid']) assert.equal(requested.searchParams.get(key), null);
  assert.equal(forecast.source, 'openMeteo');
  assert.equal(forecast.fetchedAt, '2026-11-01T12:00:00.000Z');
  assert.deepEqual(forecast.days, [
    { date: '2026-11-01', condition: 'sunny', highC: 14.2, lowC: 5.1, precipitationProbability: 0, windKph: 12.4 },
    { date: '2026-11-02', condition: 'rain', highC: 12.5, lowC: 4.8, precipitationProbability: 80, windKph: 20 },
    { date: '2026-11-03', condition: 'thunder', highC: 16, lowC: 7, precipitationProbability: 45, windKph: 8 },
  ]);
});

test('forecast defaults to seven days', async () => {
  let requested;
  await fetchWeatherForecast({ latitude: 1, longitude: 2 }, {
    fetchImpl: async (url) => { requested = new URL(url); return response(forecastPayload()); },
  });
  assert.equal(requested.searchParams.get('forecast_days'), '7');
});

test('forecast keeps unavailable values null and unknown codes cloudy', async () => {
  const forecast = await fetchWeatherForecast({ latitude: 1, longitude: 2 }, {
    fetchImpl: async () => response(forecastPayload({ weather_code: [null, 61, 95],
      temperature_2m_max: [null, 12.5, 16], temperature_2m_min: [null, 4.8, 7],
      precipitation_probability_max: [null, 180, 45], wind_speed_10m_max: [null, 20, 8] })),
  });
  assert.deepEqual(forecast.days[0], { date: '2026-11-01', condition: 'cloudy', highC: null, lowC: null,
    precipitationProbability: null, windKph: null });
  assert.equal(forecast.days[1].precipitationProbability, null);
});

test('forecast rejects malformed payloads and HTTP errors', async () => {
  const run = (body, status = 200) => fetchWeatherForecast({ latitude: 1, longitude: 2 }, {
    fetchImpl: async () => response(body, status),
  });
  await assert.rejects(run(null), /no data/);
  await assert.rejects(run({ error: true }), /could not provide a forecast/);
  await assert.rejects(run({ daily: { time: [] } }), /incomplete daily data/);
  await assert.rejects(run({ daily: { time: ['2026-11-01'], weather_code: [0], temperature_2m_max: [1],
    temperature_2m_min: [0] } }), /incomplete daily data/);
  await assert.rejects(run(forecastPayload(), 500), /failed \(500\)/);
  await assert.rejects(run({ daily: forecastPayload({ time: ['not-a-day'], weather_code: [0],
    temperature_2m_max: [1], temperature_2m_min: [0], precipitation_probability_max: [0],
    wind_speed_10m_max: [1] }).daily }), /no usable daily data/);
});

test('forecast validates coordinates and day count before fetching', async () => {
  const never = async () => { throw new Error('fetch should not run'); };
  for (const coordinates of [null, {}, { latitude: Number.NaN, longitude: 0 }, { latitude: 91, longitude: 0 },
    { latitude: 0, longitude: 181 }]) {
    await assert.rejects(fetchWeatherForecast(coordinates, { fetchImpl: never }), /Latitude|Longitude/);
  }
  for (const days of [0, 17, 2.5, '3']) {
    await assert.rejects(fetchWeatherForecast({ latitude: 0, longitude: 0 }, { fetchImpl: never, days }), /1 to 16/);
  }
});

test('render metadata is TSV-safe and omits unavailable values', () => {
  const rows = weatherRenderValues({ condition: 'rain', temperatureC: 21.4, humidity: null, highC: 23, lowC: 20,
    windKph: 9.5, feelsLikeC: null, location: 'Line\n1\tNorth', weekday: 'Thursday', sourceUtcUs: activity.startUtcUs });
  assert.equal(rows.condition, 'rain');
  assert.equal(rows.temperatureC, '21.4');
  assert.equal(rows.humidity, undefined);
  assert.equal(rows.location, 'Line 1 North');
  assert.equal(weatherRenderValues(null), null);
});
