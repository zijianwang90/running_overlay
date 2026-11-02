'use strict';

const { invariant } = require('../domain/validation');
const { validateActivity } = require('../domain/activity');

const CONDITIONS = Object.freeze(['sunny', 'clearNight', 'partlyCloudy', 'cloudy', 'fog', 'rain', 'heavyRain', 'snow', 'thunder', 'wind']);
const CONDITION_LABELS = Object.freeze({ sunny: 'Sunny', clearNight: 'Clear night', partlyCloudy: 'Partly cloudy', cloudy: 'Cloudy',
  fog: 'Fog', rain: 'Rain', heavyRain: 'Heavy rain', snow: 'Snow', thunder: 'Thunder', wind: 'Wind' });
const WEEKDAYS = Object.freeze(['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']);

// Same Open-Meteo mapping as the macOS app. Unknown or absent codes read as cloudy.
function conditionForCode(code) {
  if (typeof code !== 'number' || !Number.isFinite(code)) return 'cloudy';
  if (code === 0 || code === 1) return 'sunny';
  if (code === 2) return 'partlyCloudy';
  if (code === 3) return 'cloudy';
  if (code === 45 || code === 48) return 'fog';
  if ([51, 53, 55, 56, 57, 61, 63, 65].includes(code)) return 'rain';
  if ([66, 67, 80, 81, 82].includes(code)) return 'heavyRain';
  if ([71, 73, 75, 77, 85, 86].includes(code)) return 'snow';
  if ([95, 96, 99].includes(code)) return 'thunder';
  return 'cloudy';
}

function activityCoordinates(activity) {
  const record = (activity?.records ?? []).find((entry) => entry.latitude != null && entry.longitude != null);
  return record ? { latitude: record.latitude, longitude: record.longitude } : null;
}

function isWeatherCurrent(weather, activity) {
  if (!weather || !activity) return false;
  const coordinates = activityCoordinates(activity);
  return Boolean(coordinates)
    && weather.activityId === activity.activityId
    && weather.sourceUtcUs === activity.startUtcUs
    && Math.abs(weather.latitude - coordinates.latitude) <= 1e-6
    && Math.abs(weather.longitude - coordinates.longitude) <= 1e-6;
}

function assertWeatherValue(value, activity) {
  invariant(value && typeof value === 'object', 'Weather data must be an object.');
  invariant(value.source === 'openMeteo', 'Unsupported weather source.');
  invariant(activity && typeof activity === 'object', 'Weather data needs an activity.');
  invariant(isWeatherCurrent(value, activity), 'Weather data belongs to a different activity. Fetch it again.');
  invariant(CONDITIONS.includes(value.condition), 'Unsupported weather condition.');
  invariant(typeof value.temperatureC === 'number' && Number.isFinite(value.temperatureC) && Math.abs(value.temperatureC) <= 90, 'Invalid weather temperature.');
  for (const [field, limit] of [['humidity', 100], ['windKph', 500], ['feelsLikeC', 90], ['highC', 90], ['lowC', 90]]) {
    const fieldValue = value[field];
    if (fieldValue == null) continue;
    invariant(typeof fieldValue === 'number' && Number.isFinite(fieldValue) && Math.abs(fieldValue) <= limit, `Invalid weather ${field}.`);
  }
  if (value.highC != null && value.lowC != null) invariant(value.highC >= value.lowC, 'Weather high must not be below low.');
  invariant(typeof value.location === 'string' && value.location.length <= 120 && !/[\t\r\n]/.test(value.location), 'Invalid weather location.');
  invariant(typeof value.weekday === 'string' && WEEKDAYS.includes(value.weekday), 'Invalid weather weekday.');
  invariant(typeof value.fetchedAt === 'string' && Number.isFinite(Date.parse(value.fetchedAt)), 'Invalid weather fetch time.');
  return value;
}

// Null weather is valid saved state; anything else must still match the activity.
function validateWeather(value, activity) {
  if (value == null) return null;
  return assertWeatherValue(value, activity);
}

function parseHourlyTime(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(typeof value === 'string' ? value : '');
  if (!match) return NaN;
  return Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]), Number(match[4]), Number(match[5]), Number(match[6] ?? 0));
}

const finiteOrNull = (value, limit) => typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= limit ? value : null;

// The API is queried in UTC so the chosen hour is the activity's real UTC hour,
// independent of the editing computer's timezone.
function weatherFromArchive(payload, { activity, latitude, longitude, fetchedAt }) {
  invariant(payload && typeof payload === 'object', 'Weather service returned no data.');
  invariant(payload.error !== true, 'Weather service could not provide historical weather for this time.');
  const times = payload.hourly?.time;
  const temperatures = payload.hourly?.temperature_2m;
  invariant(Array.isArray(times) && Array.isArray(temperatures) && times.length > 0 && times.length === temperatures.length,
    'Weather service returned incomplete hourly data.');
  const targetSeconds = Math.floor(activity.startUtcUs / 1_000_000);
  const targetDay = new Date(targetSeconds * 1000).toISOString().slice(0, 10);
  const parsed = [];
  for (let index = 0; index < times.length; index += 1) {
    const milliseconds = parseHourlyTime(times[index]);
    if (!Number.isFinite(milliseconds)) continue;
    const temperatureC = finiteOrNull(temperatures[index], 90);
    if (temperatureC == null) continue;
    parsed.push({ milliseconds, temperatureC, index });
  }
  invariant(parsed.length > 0, 'Weather service returned no usable temperatures.');
  // Prefer the hour containing the activity start. If the API omits it, use the
  // hourly sample nearest to the real start instant, not the nearest hour of day.
  const targetHour = Math.floor(targetSeconds / 3600) * 3600_000;
  const targetInstant = targetSeconds * 1000;
  let selected = parsed.find((entry) => entry.milliseconds === targetHour);
  if (!selected) {
    let best = Infinity;
    for (const entry of parsed) {
      const distance = Math.abs(entry.milliseconds - targetInstant);
      if (distance < best) { best = distance; selected = entry; }
    }
  }
  const inDay = parsed.filter((entry) => new Date(entry.milliseconds).toISOString().slice(0, 10) === targetDay);
  const dayTemperatures = (inDay.length ? inDay : parsed).map((entry) => entry.temperatureC);
  const at = (name) => payload.hourly?.[name]?.[selected.index];
  const humidity = finiteOrNull(at('relative_humidity_2m'), 100);
  return assertWeatherValue({
    source: 'openMeteo',
    activityId: activity.activityId,
    sourceUtcUs: activity.startUtcUs,
    latitude, longitude,
    condition: conditionForCode(at('weather_code')),
    temperatureC: selected.temperatureC,
    humidity: humidity == null ? null : Math.round(humidity),
    highC: Math.max(...dayTemperatures),
    lowC: Math.min(...dayTemperatures),
    windKph: finiteOrNull(at('wind_speed_10m'), 500),
    feelsLikeC: finiteOrNull(at('apparent_temperature'), 90),
    location: `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`,
    weekday: WEEKDAYS[new Date(targetSeconds * 1000).getUTCDay()],
    fetchedAt,
  }, activity);
}

async function fetchActivityWeather(activity, { fetchImpl = globalThis.fetch, now = () => new Date(), timeoutMs = 15_000 } = {}) {
  invariant(activity && typeof activity === 'object', 'Choose an activity first.');
  validateActivity(activity);
  const coordinates = activityCoordinates(activity);
  invariant(coordinates, 'Weather needs an activity with GPS coordinates.');
  invariant(typeof fetchImpl === 'function', 'Weather fetching is unavailable.');
  const day = new Date(Math.floor(activity.startUtcUs / 1_000_000) * 1000).toISOString().slice(0, 10);
  const url = new URL('https://archive-api.open-meteo.com/v1/archive');
  url.searchParams.set('latitude', coordinates.latitude.toFixed(5));
  url.searchParams.set('longitude', coordinates.longitude.toFixed(5));
  url.searchParams.set('start_date', day);
  url.searchParams.set('end_date', day);
  url.searchParams.set('hourly', 'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m');
  url.searchParams.set('timezone', 'UTC');
  url.searchParams.set('wind_speed_unit', 'kmh');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  let response; let payload;
  try {
    response = await fetchImpl(url.toString(), { signal: controller.signal, redirect: 'error', headers: { accept: 'application/json' } });
    invariant(response && response.ok, `Weather service failed${response?.status ? ` (${response.status})` : ''}. Check the connection and try again.`);
    try { payload = await response.json(); }
    catch { throw new Error('Weather service returned an unreadable response.'); }
  } catch (error) {
    if (error?.name === 'AbortError') throw new Error('Weather service timed out. Check the connection and try again.');
    throw error;
  } finally { clearTimeout(timer); }
  return weatherFromArchive(payload, { activity, latitude: coordinates.latitude, longitude: coordinates.longitude, fetchedAt: now().toISOString() });
}

// Shared keyless request path. The caller owns the URL; no credential is ever
// appended, and redirects are refused so a request cannot leave Open-Meteo.
async function requestJson(url, { fetchImpl, timeoutMs, serviceLabel }) {
  invariant(typeof fetchImpl === 'function', 'Weather fetching is unavailable.');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(url.toString(), { signal: controller.signal, redirect: 'error', headers: { accept: 'application/json' } });
    invariant(response && response.ok, `${serviceLabel} failed${response?.status ? ` (${response.status})` : ''}. Check the connection and try again.`);
    try { return await response.json(); }
    catch { throw new Error(`${serviceLabel} returned an unreadable response.`); }
  } catch (error) {
    if (error?.name === 'AbortError') throw new Error(`${serviceLabel} timed out. Check the connection and try again.`);
    throw error;
  } finally { clearTimeout(timer); }
}

const stringOrNull = (value) => typeof value === 'string' && value.trim() ? value : null;

// Place-name lookup through the keyless Open-Meteo geocoding API. The panel
// resolves a user-typed city to coordinates before requesting a forecast.
async function geocodeLocation(name, { fetchImpl = globalThis.fetch, now = () => new Date(), timeoutMs = 15_000 } = {}) {
  invariant(typeof name === 'string' && name.trim().length > 0, 'Choose a location to search for.');
  const query = name.trim();
  invariant(query.length <= 120, 'Location search must be 120 characters or fewer.');
  invariant(!/[\u0000-\u001F\u007F]/.test(query), 'Location search must not contain control characters.');
  const url = new URL('https://geocoding-api.open-meteo.com/v1/search');
  url.searchParams.set('name', query);
  url.searchParams.set('count', '1');
  const payload = await requestJson(url, { fetchImpl, timeoutMs, serviceLabel: 'Location search' });
  invariant(payload && typeof payload === 'object', 'Location search returned no data.');
  invariant(payload.error !== true, 'Location search failed. Try a different name.');
  invariant(Array.isArray(payload.results), 'Location search returned an unreadable response.');
  invariant(payload.results.length > 0, 'Location not found.');
  const match = payload.results[0];
  invariant(match && typeof match === 'object', 'Location search returned an unreadable response.');
  const { latitude, longitude } = match;
  invariant(typeof latitude === 'number' && Number.isFinite(latitude) && latitude >= -90 && latitude <= 90,
    'Location search returned invalid coordinates.');
  invariant(typeof longitude === 'number' && Number.isFinite(longitude) && longitude >= -180 && longitude <= 180,
    'Location search returned invalid coordinates.');
  return {
    name: stringOrNull(match.name),
    latitude,
    longitude,
    country: stringOrNull(match.country),
    admin1: stringOrNull(match.admin1),
    timezone: stringOrNull(match.timezone),
  };
}

const isIsoDay = (value) => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)
  && Number.isFinite(Date.parse(`${value}T00:00:00Z`));
const probabilityOrNull = (value) => typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 100 ? value : null;
const FORECAST_DAILY_FIELDS = Object.freeze(['weather_code', 'temperature_2m_max', 'temperature_2m_min',
  'precipitation_probability_max', 'wind_speed_10m_max']);

// Keyless daily forecast through Open-Meteo. Days are normalized to the ten
// renderer conditions; unavailable values stay null rather than guessing.
async function fetchWeatherForecast(coordinates, { fetchImpl = globalThis.fetch, now = () => new Date(),
  timeoutMs = 15_000, days = 7 } = {}) {
  const { latitude, longitude } = coordinates && typeof coordinates === 'object' ? coordinates : {};
  invariant(typeof latitude === 'number' && Number.isFinite(latitude) && latitude >= -90 && latitude <= 90,
    'Latitude must be a finite number between -90 and 90.');
  invariant(typeof longitude === 'number' && Number.isFinite(longitude) && longitude >= -180 && longitude <= 180,
    'Longitude must be a finite number between -180 and 180.');
  invariant(Number.isInteger(days) && days >= 1 && days <= 16, 'Forecast days must be a whole number from 1 to 16.');
  const url = new URL('https://api.open-meteo.com/v1/forecast');
  url.searchParams.set('latitude', latitude.toFixed(5));
  url.searchParams.set('longitude', longitude.toFixed(5));
  url.searchParams.set('daily', FORECAST_DAILY_FIELDS.join(','));
  url.searchParams.set('timezone', 'UTC');
  url.searchParams.set('wind_speed_unit', 'kmh');
  url.searchParams.set('forecast_days', String(days));
  const payload = await requestJson(url, { fetchImpl, timeoutMs, serviceLabel: 'Weather service' });
  invariant(payload && typeof payload === 'object', 'Weather service returned no data.');
  invariant(payload.error !== true, 'Weather service could not provide a forecast.');
  const daily = payload.daily;
  invariant(daily && typeof daily === 'object' && Array.isArray(daily.time) && daily.time.length > 0,
    'Weather service returned incomplete daily data.');
  for (const field of FORECAST_DAILY_FIELDS) {
    invariant(Array.isArray(daily[field]) && daily[field].length === daily.time.length,
      'Weather service returned incomplete daily data.');
  }
  const normalized = [];
  for (let index = 0; index < daily.time.length; index += 1) {
    if (!isIsoDay(daily.time[index])) continue;
    normalized.push({
      date: daily.time[index],
      condition: conditionForCode(daily.weather_code[index]),
      highC: finiteOrNull(daily.temperature_2m_max[index], 90),
      lowC: finiteOrNull(daily.temperature_2m_min[index], 90),
      precipitationProbability: probabilityOrNull(daily.precipitation_probability_max[index]),
      windKph: finiteOrNull(daily.wind_speed_10m_max[index], 500),
    });
  }
  invariant(normalized.length > 0, 'Weather service returned no usable daily data.');
  return { source: 'openMeteo', days: normalized, fetchedAt: now().toISOString() };
}

// Metadata rows are appended to the immutable activity TSV. The renderer reads
// them at load time only; it never performs network access.
function sanitizeCell(value) {
  return String(value).replace(/[\t\r\n]+/g, ' ').slice(0, 160);
}
function weatherRenderValues(weather) {
  if (!weather) return null;
  const values = {};
  for (const [key, value] of Object.entries({
    condition: weather.condition,
    temperatureC: weather.temperatureC,
    humidity: weather.humidity,
    highC: weather.highC,
    lowC: weather.lowC,
    windKph: weather.windKph,
    feelsLikeC: weather.feelsLikeC,
    location: weather.location,
    weekday: weather.weekday,
    sourceUtcUs: weather.sourceUtcUs,
  })) {
    if (value != null) values[key] = sanitizeCell(value);
  }
  return values;
}

module.exports = { CONDITIONS, CONDITION_LABELS, WEEKDAYS, conditionForCode, validateWeather, isWeatherCurrent,
  fetchActivityWeather, geocodeLocation, fetchWeatherForecast, weatherRenderValues };
