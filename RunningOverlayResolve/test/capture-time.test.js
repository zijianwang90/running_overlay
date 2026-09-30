'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const time = require('../src/sync/capture-time');
const { validateConfiguration } = require('../src/workflow/configuration');
const { compileSyncMap } = require('../src/sync/compile-sync-map');
const fixture = (name) => JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fixtures', name), 'utf8'));

test('filename wall times recognize camera names and reject invalid or ambiguous date tokens', () => {
  for (const [name, expected] of [['PRO_VID_20260702_184703_00_009.mp4', [18, 47, 3]], ['VID_20260702_185259_00_010.mp4', [18, 52, 59]], ['CAM_20260702_185736.mov', [18, 57, 36]]]) {
    const result = time.filenameCaptureTime(`/synthetic/${name}`);
    assert.deepEqual(result, { year: 2026, month: 7, day: 2, hour: expected[0], minute: expected[1], second: expected[2], millisecond: 0 });
    assert.equal(Object.hasOwn(result, 'instantUtcUs'), false);
  }
  assert.equal(time.filenameCaptureTime('VID_20240229_235959.mp4').day, 29);
  for (const name of ['VID_20260229_120000.mp4', 'VID_20261301_120000.mp4', 'VID_20260702_246000.mp4', 'VID_20260702_120060.mp4', 'renamed.mp4', 'X20260702_120000.mov', 'CAM_20260702_120000_20260703_130000.mov']) {
    assert.equal(time.filenameCaptureTime(name), null, name);
  }
});

test('recording timezone converts local filename time by its date, independently of machine zone', () => {
  const parts = time.filenameCaptureTime('PRO_VID_20260702_184703_00_009.mp4');
  assert.throws(() => time.toISO(parts, ''), /timezone/);
  assert.equal(time.toISO(parts, 'America/Toronto'), '2026-07-02T22:47:03.000Z');
  assert.equal(time.toISO(parts, 'Asia/Shanghai'), '2026-07-02T10:47:03.000Z');
  assert.equal(time.toISO({ ...parts, month: 1 }, 'America/Toronto'), '2026-01-02T23:47:03.000Z');
  assert.throws(() => time.validateTimeZone('UTC+14:30'), /offset/);
  assert.throws(() => time.validateTimeZone('made-up-zone'), /timezone/);
});

test('saved ISO timestamps retain exact instants and milliseconds in named and fixed-offset pickers', () => {
  for (const iso of ['2026-07-02T18:47:03.123-04:00', '2026-07-02T22:47:03Z', '2026-07-02T18:47:03.009+05:45']) {
    const zone = time.offsetZoneForISO(iso);
    const parts = time.partsAt(Date.parse(iso), zone);
    assert.equal(time.toISO(parts, zone), new Date(iso).toISOString());
  }
  const iso = '2026-07-02T22:47:03.123Z';
  assert.equal(time.toISO(time.partsAt(Date.parse(iso), 'America/Toronto'), 'America/Toronto'), iso);
});

test('DST skipped and repeated local times require a valid explicit occurrence', () => {
  const skipped = time.partsFromDate('2026-03-08', 2, 30, 0);
  assert.equal(time.possibleInstants(skipped, 'America/Toronto').length, 0);
  assert.throws(() => time.toISO(skipped, 'America/Toronto'), /does not exist/);
  const repeated = time.partsFromDate('2026-11-01', 1, 30, 0);
  assert.equal(time.possibleInstants(repeated, 'America/Toronto').length, 2);
  assert.throws(() => time.toISO(repeated, 'America/Toronto'), /occurs twice/);
  assert.equal(time.toISO(repeated, 'America/Toronto', -240), '2026-11-01T05:30:00.000Z');
  assert.equal(time.toISO(repeated, 'America/Toronto', -300), '2026-11-01T06:30:00.000Z');
  assert.equal(time.possibleInstants(time.partsFromDate('2026-04-05', 1, 45, 0), 'Australia/Lord_Howe').length, 2);
  assert.throws(() => time.partsFromDate('2026-02-30', 12, 0, 0), /valid date/);
});

test('filename evidence alone never becomes a sync segment, confirmed timezone time includes source trim', () => {
  const activity = fixture('activity.synthetic.json'); const timeline = fixture('timeline.synthetic.json'); const media = fixture('media.synthetic.json');
  const item = timeline.items[0];
  media[item.mediaId] = { filenameCaptureTime: time.filenameCaptureTime('VID_20260702_184703.mp4'), captureTimeCandidates: [] };
  const refused = compileSyncMap({ activity, timeline, mediaById: media });
  assert.ok(refused.diagnostics.some((entry) => entry.code === 'capture-time-unresolved'));
  assert.ok(!refused.segments.some((segment) => segment.mediaId === item.mediaId));
  const instant = new Date(activity.startUtcUs / 1000).toISOString();
  const parts = time.partsAt(Date.parse(instant), 'America/Toronto');
  media[item.mediaId].captureStartUtcUs = Date.parse(time.toISO(parts, 'America/Toronto')) * 1000;
  media[item.mediaId].captureConfidence = 'locked';
  const accepted = compileSyncMap({ activity, timeline, mediaById: media });
  assert.equal(accepted.segments[0].activityStartUs, item.sourceStartFrame * 1000000 / 30);
});

test('optional timezone preferences preserve old configuration and clock anchors without schema migration', () => {
  const legacy = { schemaVersion: 1, contextId: 'a'.repeat(64), referenceVideoTrackIndex: 1,
    confirmedCaptureUtcByMediaId: { source: '2026-07-02T18:47:03.123-04:00' },
    cameraAnchors: { camera: [{ cameraTime: '2026-07-02T18:47:03-04:00', activityTime: '2026-07-02T18:47:00-04:00' }] } };
  const old = validateConfiguration(legacy);
  assert.equal(old.captureTimeZone, null);
  assert.deepEqual(old.confirmedCaptureUtcByMediaId, legacy.confirmedCaptureUtcByMediaId);
  assert.deepEqual(old.cameraAnchors, legacy.cameraAnchors);
  const updated = validateConfiguration({ ...old, captureTimeZone: 'America/Toronto', captureTimeZonesByMediaId: { source: 'America/Toronto' },
    cameraAnchors: { camera: [{ ...old.cameraAnchors.camera[0], cameraTimeZone: 'America/Toronto', activityTimeZone: 'UTC' }] } });
  assert.deepEqual(validateConfiguration(JSON.parse(JSON.stringify(updated))), updated);
  assert.throws(() => validateConfiguration({ ...old, captureTimeZone: 'invalid-zone' }), /timezone/);
});
