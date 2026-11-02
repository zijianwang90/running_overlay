'use strict';

const { invariant } = require('../domain/validation');
const { validateActivity } = require('../domain/activity');

// One square snapshot covers `COVERAGE` route units across its width. The Fuse
// draws it larger than the circular card so the follow camera can pan to the
// route bounds without exposing the snapshot's edge. Change this together with
// the Fuse's Map Coverage default.
const DEFAULT_COVERAGE = 2.75;
const DEFAULT_STYLE = 'mapbox/dark-v11';
const IMAGE_SIZE = 1280;
const PIXEL_RATIO = 2;
const ATTRIBUTION = '© Mapbox © OpenStreetMap';
const MAX_MERCATOR_LATITUDE = 85.05112878;
// A single GPS fix still needs a snapshot; about 400 m across at the equator.
const MIN_SPAN = 0.00006;

const validGps = (record) => typeof record?.latitude === 'number' && Number.isFinite(record.latitude)
  && typeof record?.longitude === 'number' && Number.isFinite(record.longitude)
  && Math.abs(record.latitude) <= 90 && Math.abs(record.longitude) <= 180;

function mercator(record) {
  const latitude = Math.max(-MAX_MERCATOR_LATITUDE, Math.min(MAX_MERCATOR_LATITUDE, record.latitude)) * Math.PI / 180;
  return { x: record.longitude * Math.PI / 180, y: Math.log(Math.tan(Math.PI / 4 + latitude / 2)) };
}

function longitudeDegrees(radians) {
  return radians * 180 / Math.PI;
}

function latitudeDegrees(radians) {
  return (2 * Math.atan(Math.exp(radians)) - Math.PI / 2) * 180 / Math.PI;
}

// Bounds use the same Web Mercator projection and antimeridian unwrap as the
// Fuse's prepare_route, so the snapshot and the route trace share one frame.
function routeFrame(records, { coverage = DEFAULT_COVERAGE } = {}) {
  invariant(Array.isArray(records) && records.length > 0, 'Route map needs activity records.');
  invariant(typeof coverage === 'number' && Number.isFinite(coverage) && coverage >= 1 && coverage <= 3, 'Invalid map coverage.');
  let minX; let maxX; let minY; let maxY;
  let previousLongitude = null;
  for (const record of records) {
    if (!validGps(record)) { previousLongitude = null; continue; }
    let longitude = record.longitude;
    if (previousLongitude != null) longitude = previousLongitude + ((longitude - previousLongitude + 180 + 360) % 360 - 180);
    const point = mercator({ latitude: record.latitude, longitude });
    minX = Math.min(minX ?? point.x, point.x); maxX = Math.max(maxX ?? point.x, point.x);
    minY = Math.min(minY ?? point.y, point.y); maxY = Math.max(maxY ?? point.y, point.y);
    previousLongitude = longitude;
  }
  invariant(minX != null, 'Route map needs an activity with GPS coordinates.');
  const span = Math.max(maxX - minX, maxY - minY, MIN_SPAN);
  const centerX = (minX + maxX) / 2;
  const centerY = (minY + maxY) / 2;
  // The Static Images API takes a center and a zoom instead of a bbox. Mapbox
  // renders zoom 0 as 512 output-independent pixels across one world, so the
  // image side covers size / (512 * 2^zoom) worlds. Invert that for the route
  // span times the coverage factor. @2x doubles the pixels, not the world.
  const zoom = Math.max(0, Math.min(22, Math.log2(IMAGE_SIZE * 2 * Math.PI / (512 * coverage * span))));
  return {
    center: [longitudeDegrees(centerX), latitudeDegrees(centerY)],
    zoom: Math.round(zoom * 1e6) / 1e6,
    coverage,
    size: IMAGE_SIZE,
    pixelRatio: PIXEL_RATIO,
    style: DEFAULT_STYLE,
    attribution: ATTRIBUTION,
  };
}

// Public tokens are pk.*. Keeping the check strict enough to reject whitespace
// also keeps the token out of URL headers and query strings.
function validToken(token) {
  return typeof token === 'string' && /^pk\.[A-Za-z0-9._-]{10,}$/.test(token) && token.length <= 512;
}

function mapboxStaticUrl(frame, token) {
  invariant(validToken(token), 'Enter a Mapbox public access token (pk.*).');
  invariant(Array.isArray(frame.center) && frame.center.length === 2, 'Invalid map center.');
  const center = frame.center.map((value) => value.toFixed(6)).join(',');
  const url = new URL(`https://api.mapbox.com/styles/v1/${frame.style}/static/${center},${frame.zoom},0,0/${frame.size}x${frame.size}@${frame.pixelRatio}x`);
  url.searchParams.set('access_token', token);
  url.searchParams.set('logo', 'true');
  url.searchParams.set('attribution', 'true');
  return url.toString();
}

async function fetchRouteMap(activity, { token, fetchImpl = globalThis.fetch, timeoutMs = 20_000, coverage = DEFAULT_COVERAGE, now = () => new Date() } = {}) {
  invariant(activity && typeof activity === 'object', 'Choose an activity first.');
  validateActivity(activity);
  invariant(typeof fetchImpl === 'function', 'Map fetching is unavailable.');
  const frame = routeFrame(activity.records, { coverage });
  const url = mapboxStaticUrl(frame, token);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  let response; let bytes;
  try {
    response = await fetchImpl(url, { signal: controller.signal, redirect: 'error', headers: { accept: 'image/png' } });
    invariant(response && response.ok, `Map service failed${response?.status ? ` (${response.status})` : ''}. Check the token and connection.`);
    bytes = Buffer.from(await response.arrayBuffer());
  } catch (error) {
    if (error?.name === 'AbortError') throw new Error('Map fetch timed out. Check the connection and try again.');
    throw error;
  } finally { clearTimeout(timer); }
  // Mapbox returns PNG for the static styles API; the Fuse needs the alpha
  // channel declared by the signature, so reject anything else.
  invariant(bytes.length > 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
    'Map service returned an unreadable image.');
  return { bytes, metadata: { ...frame, source: 'mapbox', attribution: ATTRIBUTION, fetchedAt: now().toISOString() } };
}

// The snapshot lives in the immutable render bundle; the token never does.
module.exports = { DEFAULT_COVERAGE, DEFAULT_STYLE, ATTRIBUTION, MIN_SPAN, validGps, routeFrame, validToken, mapboxStaticUrl, fetchRouteMap };
