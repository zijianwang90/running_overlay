'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { DEFAULT_COVERAGE, ATTRIBUTION, routeFrame, validToken, mapboxStaticUrl, fetchRouteMap } = require('../src/map/mapbox');

// A short loop near the project's synthetic coordinates. The records are spaced
// so the map frame is a square around the route, independent of network access.
const activity = {
  schemaVersion: 1,
  activityId: 'synthetic-map',
  startUtcUs: 1_783_016_700_000_000,
  endUtcUs: 1_783_017_700_000_000,
  records: [
    { elapsedUs: 0, latitude: 43.6532, longitude: -79.3832, routeSegment: 0 },
    { elapsedUs: 60_000_000, latitude: 43.6540, longitude: -79.3810, routeSegment: 0 },
    { elapsedUs: 120_000_000, latitude: 43.6520, longitude: -79.3800, routeSegment: 0 },
  ],
};
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13]);

test('route frame covers the route bounds expanded by the coverage factor', () => {
  const frame = routeFrame(activity.records);
  assert.equal(frame.coverage, DEFAULT_COVERAGE);
  assert.equal(frame.size, 1280);
  assert.equal(frame.pixelRatio, 2);
  assert.equal(frame.style, 'mapbox/dark-v11');
  assert.equal(frame.attribution, ATTRIBUTION);
  const [longitude, latitude] = frame.center;
  assert.ok(longitude > -79.3832 && longitude < -79.3800);
  assert.ok(latitude > 43.6520 && latitude < 43.6540);
  // The requested zoom covers exactly coverage * span across the image side.
  const span = Math.max(...activity.records.map((record) => record.latitude)).toString();
  assert.ok(frame.zoom > 15 && frame.zoom < 20, String(frame.zoom));
  assert.ok(frame.center.length === 2);
});

test('route frame needs GPS, ignores gaps and handles a single fix', () => {
  assert.throws(() => routeFrame([{ elapsedUs: 0, latitude: null, longitude: null, routeSegment: null }]), /GPS coordinates/);
  const single = routeFrame([{ elapsedUs: 0, latitude: 43.65, longitude: -79.38, routeSegment: 0 }]);
  assert.ok(Number.isFinite(single.zoom));
  assert.ok(single.zoom < 22.1);
  const frame = routeFrame([
    { elapsedUs: 0, latitude: 43.65, longitude: -79.38, routeSegment: 0 },
    { elapsedUs: 1, latitude: null, longitude: null, routeSegment: null },
    { elapsedUs: 2, latitude: 43.66, longitude: -79.37, routeSegment: 1 },
  ]);
  assert.ok(frame.center[0] > -79.38 && frame.center[0] < -79.37);
});

test('static URL carries the bbox, size, logo and attribution but no whitespace', () => {
  const frame = routeFrame(activity.records);
  const url = new URL(mapboxStaticUrl(frame, 'pk.test-token-1234567890'));
  assert.equal(url.host, 'api.mapbox.com');
  assert.match(url.pathname, /\/styles\/v1\/mapbox\/dark-v11\/static\/-?\d+\.\d+,-?\d+\.\d+,\d+\.\d+,0,0\/1280x1280@2x$/);
  assert.equal(url.searchParams.get('access_token'), 'pk.test-token-1234567890');
  assert.equal(url.searchParams.get('logo'), 'true');
  assert.equal(url.searchParams.get('attribution'), 'true');
  assert.doesNotMatch(url.toString(), /\s/);
  assert.throws(() => mapboxStaticUrl(frame, 'sk.secret'), /public access token/);
  assert.throws(() => mapboxStaticUrl(frame, 'pk.bad token'), /public access token/);
});

test('token validation only accepts public Mapbox tokens', () => {
  assert.equal(validToken('pk.eyJ1Ijoic3ludGhldGljIn0.test-signature-123456'), true);
  for (const value of [null, '', 'pk.', 'sk.123456789012345', 'pk.test token', `pk.${'a'.repeat(600)}`]) {
    assert.equal(validToken(value), false, String(value).slice(0, 20));
  }
});

test('fetch validates the PNG signature with a mocked service and no network', async () => {
  let requested;
  const result = await fetchRouteMap(activity, {
    token: 'pk.test-token-1234567890',
    fetchImpl: async (url) => { requested = new URL(url); return { ok: true, status: 200, arrayBuffer: async () => PNG }; },
    now: () => new Date('2026-11-01T12:00:00Z'),
  });
  assert.equal(requested.host, 'api.mapbox.com');
  assert.ok(result.bytes.equals(PNG));
  assert.equal(result.metadata.source, 'mapbox');
  assert.equal(result.metadata.attribution, ATTRIBUTION);
  assert.equal(result.metadata.fetchedAt, '2026-11-01T12:00:00.000Z');
  assert.equal(result.metadata.accessToken, undefined);
  await assert.rejects(fetchRouteMap(activity, {
    token: 'pk.test-token-1234567890',
    fetchImpl: async () => ({ ok: true, status: 200, arrayBuffer: async () => Buffer.from('<html>') }),
  }), /unreadable image/);
  await assert.rejects(fetchRouteMap(activity, {
    token: 'pk.test-token-1234567890',
    fetchImpl: async () => ({ ok: false, status: 401 }),
  }), /Map service failed \(401\)/);
});

test('bundle writer records the map snapshot and its manifest entries', async () => {
  const { writeResolveBundle } = require('../src/io/render-data');
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'ro-map-bundle-'));
  const bundle = await writeResolveBundle(directory, activity, { schemaVersion: 1, activityId: activity.activityId,
    timelineId: 'map-test', timelineFingerprint: 'synthetic', timelineStartFrame: 0, timelineEndFrame: 900,
    frameRate: { numerator: 30, denominator: 1 }, segments: [] }, null,
  { bytes: PNG, metadata: { ...routeFrame(activity.records), fetchedAt: '2026-11-01T12:00:00.000Z', accessToken: 'pk.must-not-leak-123456' } });
  assert.ok((await fs.readFile(path.join(bundle, 'map.png'))).equals(PNG));
  const metadata = JSON.parse(await fs.readFile(path.join(bundle, 'map.json'), 'utf8'));
  assert.equal(metadata.attribution, ATTRIBUTION);
  assert.equal(metadata.accessToken, undefined);
  assert.doesNotMatch(JSON.stringify(metadata), /pk\./);
  const manifest = JSON.parse(await fs.readFile(path.join(bundle, 'manifest.json'), 'utf8'));
  assert.equal(manifest.mapImage, 'map.png');
  assert.equal(manifest.mapMetadata, 'map.json');
  await fs.rm(directory, { recursive: true, force: true });
});
