'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const test = require('node:test');
const { parseGpxBuffer, utcMicroseconds } = require('../src/activity/gpx-parser');
const { loadActivityFile } = require('../src/activity/import-activity');
const { sampleActivity } = require('../src/domain/activity');
const { serializeActivityRenderData, parseActivityRenderData } = require('../src/io/render-data');
const { compileSyncMap } = require('../src/sync/compile-sync-map');
const { activityElapsedUsAtFrame } = require('../src/sync/sample-sync-map');

const fixture = path.join(__dirname, '..', 'fixtures', 'activity.synthetic.gpx');

test('GPX import preserves microsecond time, segment distance, supported metrics, and missing values', async () => {
  const activity = await loadActivityFile(fixture);
  assert.equal(activity.activityId, 'activity.synthetic');
  assert.equal(activity.startUtcUs, 1_767_254_400_123_456);
  assert.equal(activity.endUtcUs - activity.startUtcUs, 30_000_000);
  assert.deepEqual(activity.records.map((record) => record.elapsedUs), [0, 10_000_000, 20_000_000, 30_000_000]);
  assert.equal(activity.records[0].heartRateBpm, 120);
  assert.equal(activity.records[1].heartRateBpm, null);
  assert.equal(activity.records[1].powerWatts, 250);
  assert.equal(activity.records[1].calories, null);
  assert.ok(activity.records[1].distanceMeters > 11 && activity.records[1].distanceMeters < 12);
  assert.equal(activity.records[2].distanceMeters, activity.records[1].distanceMeters);
  assert.ok(activity.records[3].distanceMeters > activity.records[2].distanceMeters);
  assert.ok(activity.records[1].paceSecondsPerKilometer > 850 && activity.records[1].paceSecondsPerKilometer < 950);
  assert.equal(activity.records[2].paceSecondsPerKilometer, 400);
  assert.equal(sampleActivity(activity, 5_000_000).heartRateBpm, null);
  assert.equal(sampleActivity(activity, 15_000_000).heartRateBpm, null);
  assert.equal(sampleActivity(activity, 25_000_000).heartRateBpm, 145);
  const roundTrip = parseActivityRenderData(serializeActivityRenderData(activity));
  assert.equal(roundTrip.records[1].heartRateBpm, null);
  assert.equal(roundTrip.startUtcUs, activity.startUtcUs);
});

test('GPX timestamps require explicit timezones and reject invalid calendar values', () => {
  assert.equal(utcMicroseconds('2026-01-01T10:00:00.123456+02:00'), 1_767_254_400_123_456);
  for (const value of ['2026-01-01T08:00:00', '2026-02-30T08:00:00Z',
    '2026-01-01T08:00:00.1234567Z', '2026-01-01T08:00:00+15:00']) {
    assert.throws(() => utcMicroseconds(value));
  }
});

test('GPX rejects malformed XML, entities, invalid points, and insufficient time', async () => {
  const xml = await fs.readFile(fixture, 'utf8');
  for (const text of [xml.replace('</gpx>', '</wrong>'),
    xml.replace('<trk>', '<!DOCTYPE gpx [<!ENTITY e SYSTEM "file:///secret">]><trk>'),
    xml.replace('lat="0"', 'lat="91"'),
    xml.replace('2026-01-01T08:00:10.123456Z', 'unknown&entity;'),
    xml.replace(/<time>[^<]+<\/time>/g, ''),
    xml.replace(/2026-01-01T08:00:(10|20|30)\.123456Z/g, '2026-01-01T08:00:00.123456Z')]) {
    assert.throws(() => parseGpxBuffer(text));
  }
});

test('file routing accepts the synthetic GPX and rejects unrelated extensions', async () => {
  assert.equal((await loadActivityFile(fixture)).records.length, 4);
  await assert.rejects(loadActivityFile(__filename), /Choose a FIT, GPX/);
});

test('GPX microsecond origin remains exact through a Resolve sync map', async () => {
  const activity = await loadActivityFile(fixture);
  const timeline = { schemaVersion: 1, timelineId: 'gpx-synthetic-timeline', timelineStartFrame: 0,
    timelineEndFrame: 900, referenceVideoTrackIndex: 1, frameRate: { numerator: 30, denominator: 1 },
    items: [{ timelineItemId: 'source-a', mediaId: 'media-a', cameraGroupId: 'camera-a',
      timelineStartFrame: 0, timelineEndFrameExclusive: 900, sourceStartFrame: 0,
      sourceFrameRate: { numerator: 30, denominator: 1 }, speed: { numerator: 1, denominator: 1 }, clipEnabled: true }] };
  const sync = compileSyncMap({ activity, timeline,
    mediaById: { 'media-a': { captureStartUtcUs: activity.startUtcUs } } });
  assert.deepEqual(sync.diagnostics, []);
  assert.equal(activityElapsedUsAtFrame(sync, 0), 0);
  assert.equal(activityElapsedUsAtFrame(sync, 300), 10_000_000);
  assert.equal(activityElapsedUsAtFrame(sync, 600), 20_000_000);
});

test('GPX temperature extensions and grade stay within one segment and need both elevations', () => {
  const gpx = (points) => Buffer.from(`<?xml version="1.0"?><gpx version="1.1" xmlns:tpx="urn:tpx"><trk>${points}</trk></gpx>`);
  const point = (lon, ele, second, temp) => `<trkpt lat="0" lon="${lon}">${ele === null ? '' : `<ele>${ele}</ele>`}`
    + `<time>2026-01-01T08:00:${second}Z</time><extensions><tpx:atemp>${temp}</tpx:atemp></extensions></trkpt>`;
  const activity = parseGpxBuffer(gpx(`<trkseg>${point(0, 100, '00', -3)}${point(0.001, 102, '10', 4.5)}${point(0.002, null, '20', 5)}</trkseg>`
    + `<trkseg>${point(1, 110, '30', 6)}</trkseg>`));
  assert.deepEqual(activity.records.map((record) => record.temperatureCelsius), [-3, 4.5, 5, 6]);
  assert.equal(activity.records[0].gradePercent, null);
  assert.ok(Math.abs(activity.records[1].gradePercent - 2 / 111.19 * 100) < 0.01);
  assert.equal(activity.records[2].gradePercent, null);
  assert.equal(activity.records[3].gradePercent, null);
});
