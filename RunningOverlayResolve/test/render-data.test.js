'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { compileSyncMap } = require('../src/sync/compile-sync-map');
const os = require('node:os');
const { sampleActivity, validateActivity } = require('../src/domain/activity');
const { parseGpxBuffer } = require('../src/activity/gpx-parser');
const {
  ACTIVITY_COLUMNS,
  writeResolveBundle,
  parseWeatherRenderData,
  parseActivityRenderData,
  parseSyncRenderData,
  serializeActivityRenderData,
  serializeSyncRenderData,
} = require('../src/io/render-data');

const fixture = (name) => JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fixtures', name), 'utf8'));

test('activity render data round-trips the portable numeric channels', () => {
  const activity = fixture('activity.synthetic.json');
  const parsed = parseActivityRenderData(serializeActivityRenderData(activity));
  assert.equal(parsed.activityId, activity.activityId);
  assert.deepEqual(parsed.records, activity.records);
  assert.deepEqual(parsed.annotations, activity.annotations);

  const withLaps = { ...activity, laps: [
    { startElapsedUs: 0, startDistanceMeters: 0 },
    { startElapsedUs: 600_000_000, startDistanceMeters: 1_500 },
  ] };
  assert.deepEqual(parseActivityRenderData(serializeActivityRenderData(withLaps)).laps, withLaps.laps);
  assert.throws(() => validateActivity({ ...withLaps, laps: [{ startElapsedUs: 600_000_000, startDistanceMeters: 1 },
    { startElapsedUs: 0, startDistanceMeters: 0 }] }));
  assert.throws(() => validateActivity({ ...withLaps, laps: [{ startElapsedUs: 0, startDistanceMeters: 2 },
    { startElapsedUs: 1, startDistanceMeters: 1 }] }));
});

test('route positions validate as finite degree pairs with non-negative integer segments', () => {
  const base = { schemaVersion: 1, activityId: 'route', startUtcUs: 0, endUtcUs: 0 };
  const valid = { elapsedUs: 0, latitude: 0, longitude: 0, routeSegment: 0 };
  for (const record of [valid, { elapsedUs: 0 },
    { elapsedUs: 0, latitude: null, longitude: null, routeSegment: null },
    { ...valid, latitude: -90, longitude: -180 }, { ...valid, latitude: 90, longitude: 180 }]) {
    assert.equal(validateActivity({ ...base, records: [record] }).records[0], record);
  }
  for (const change of [{ latitude: undefined }, { longitude: null }, { routeSegment: undefined },
    { latitude: NaN }, { longitude: Infinity }, { latitude: 90.01 }, { longitude: -180.01 },
    { routeSegment: -1 }, { routeSegment: 0.5 }, { routeSegment: Number.MAX_SAFE_INTEGER + 1 }]) {
    assert.throws(() => validateActivity({ ...base, records: [{ ...valid, ...change }] }));
  }
});

test('GPS sampling takes the shortest longitude path and suppresses missing/segment gaps', () => {
  const activity = { schemaVersion: 1, activityId: 'route', startUtcUs: 0, endUtcUs: 60,
    records: [
      { elapsedUs: 0, latitude: -10, longitude: 179, routeSegment: 0 },
      { elapsedUs: 10, latitude: 10, longitude: -179, routeSegment: 0 },
      { elapsedUs: 20, latitude: 0, longitude: 179, routeSegment: 0 },
      { elapsedUs: 30, latitude: null, longitude: null, routeSegment: null },
      { elapsedUs: 40, latitude: 0, longitude: 0, routeSegment: 0 },
      { elapsedUs: 50, latitude: 1, longitude: 1, routeSegment: 1 },
      { elapsedUs: 60, heartRateBpm: 120 },
    ] };
  for (const elapsedUs of [5, 15]) {
    const sample = sampleActivity(activity, elapsedUs);
    assert.equal(sample.latitude, elapsedUs === 5 ? 0 : 5);
    assert.equal(Math.abs(sample.longitude), 180);
    assert.equal(sample.routeSegment, 0);
  }
  for (const elapsedUs of [25, 35, 45, 55]) {
    const sample = sampleActivity(activity, elapsedUs);
    assert.equal(sample.latitude, null);
    assert.equal(sample.longitude, null);
    assert.equal(sample.routeSegment, null);
  }
  assert.deepEqual(sampleActivity(activity, 0), activity.records[0]);
  assert.deepEqual(sampleActivity(activity, 30), activity.records[3]);
  assert.deepEqual(sampleActivity(activity, 50), activity.records[5]);
  assert.equal(sampleActivity(activity, -1), null);
  assert.equal(sampleActivity(activity, 61), null);
});

test('route TSV columns append after existing metrics and numeric-only v1 files still load', () => {
  const activity = fixture('activity.synthetic.json');
  const text = serializeActivityRenderData(activity);
  assert.deepEqual(ACTIVITY_COLUMNS.slice(-3), ['latitude_deg', 'longitude_deg', 'route_segment']);
  const legacyText = text.split('\n').map((line) => /^(columns|record)\t/.test(line)
    ? line.split('\t').slice(0, -3).join('\t') : line).join('\n');
  assert.deepEqual(parseActivityRenderData(legacyText).records, activity.records);
  const gps = { ...activity, records: [{ ...activity.records[0], latitude: 0, longitude: 0, routeSegment: 0 },
    activity.records[1]] };
  const gpsText = serializeActivityRenderData(gps);
  assert.deepEqual(gpsText.split('\n').find((line) => line.startsWith('record\t')).split('\t').slice(15), ['0', '0', '0']);
  assert.deepEqual(parseActivityRenderData(gpsText).records, gps.records);
});

test('GPX route coordinates and segments survive JSON and TSV bundle round trips', async (context) => {
  const activity = parseGpxBuffer(fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'activity.synthetic.gpx')));
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'resolve-route-'));
  context.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const weather = { source: 'openMeteo', activityId: activity.activityId, sourceUtcUs: activity.startUtcUs,
    latitude: 0, longitude: 0, condition: 'rain', temperatureC: 18.5, humidity: 72, highC: 20, lowC: 16,
    windKph: 8, feelsLikeC: 17, location: 'Synthetic', weekday: 'Monday', fetchedAt: '2026-01-01T12:00:00.000Z' };
  const bundle = await writeResolveBundle(directory, activity, { schemaVersion: 1,
    activityId: activity.activityId, timelineId: 'route-test', timelineFingerprint: 'synthetic',
    timelineStartFrame: 0, timelineEndFrame: 900, frameRate: { numerator: 30, denominator: 1 }, segments: [] }, weather);
  const tsvText = fs.readFileSync(path.join(bundle, 'activity.roactivity'), 'utf8');
  assert.deepEqual(parseWeatherRenderData(tsvText), { condition: 'rain', temperatureC: 18.5, humidity: 72, highC: 20, lowC: 16,
    windKph: 8, feelsLikeC: 17, location: 'Synthetic', weekday: 'Monday', sourceUtcUs: activity.startUtcUs });
  const json = JSON.parse(fs.readFileSync(path.join(bundle, 'activity.json'), 'utf8'));
  const tsv = parseActivityRenderData(fs.readFileSync(path.join(bundle, 'activity.roactivity'), 'utf8'));
  for (const restored of [json, tsv]) {
    assert.deepEqual(restored.records.map(({ latitude, longitude, routeSegment }) =>
      [latitude, longitude, routeSegment]), [[0, 0, 0], [0, 0.0001, 0], [10, 10, 1], [10, 10.0001, 1]]);
    assert.equal(sampleActivity(restored, 15_000_000).latitude, null);
    assert.equal(sampleActivity(restored, 20_000_000).routeSegment, 1);
  }
});

test('sync render data preserves frame and rational-time authority', () => {
  const activity = fixture('activity.synthetic.json');
  const syncMap = compileSyncMap({
    activity,
    timeline: fixture('timeline.synthetic.json'),
    mediaById: fixture('media.synthetic.json'),
  });
  const parsed = parseSyncRenderData(serializeSyncRenderData(syncMap));
  assert.equal(parsed.timelineFingerprint, syncMap.timelineFingerprint);
  assert.deepEqual(parsed.frameRate, { numerator: 30_000, denominator: 1_001 });
  assert.equal(parsed.segments[0].activityStartUs, 322_000_000);
  assert.deepEqual(parsed.segments[0].activityUsPerTimelineFrame, { numerator: 100_100, denominator: 3 });
});
