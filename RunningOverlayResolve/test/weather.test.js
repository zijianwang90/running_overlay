'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { conditionForCode, fetchActivityWeather, validateWeather, weatherRenderValues, isWeatherCurrent } = require('../src/weather/weather');

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

test('render metadata is TSV-safe and omits unavailable values', () => {
  const rows = weatherRenderValues({ condition: 'rain', temperatureC: 21.4, humidity: null, highC: 23, lowC: 20,
    windKph: 9.5, feelsLikeC: null, location: 'Line\n1\tNorth', weekday: 'Thursday', sourceUtcUs: activity.startUtcUs });
  assert.equal(rows.condition, 'rain');
  assert.equal(rows.temperatureC, '21.4');
  assert.equal(rows.humidity, undefined);
  assert.equal(rows.location, 'Line 1 North');
  assert.equal(weatherRenderValues(null), null);
});
