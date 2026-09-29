'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { sampleActivity, validateActivity } = require('../src/domain/activity');
const { buildCameraClockModel, mapCameraUtcUs } = require('../src/sync/clock-model');
const { rankCaptureTimeCandidates } = require('../src/sync/capture-evidence');
const { compileSyncMap } = require('../src/sync/compile-sync-map');
const { activityElapsedUsAtFrame } = require('../src/sync/sample-sync-map');

const fixture = (name) => JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fixtures', name), 'utf8'));

test('activity sampling interpolates metrics without clamping outside the real-time axis', () => {
  const activity = validateActivity(fixture('activity.synthetic.json'));
  const sample = sampleActivity(activity, 450_000_000);
  assert.equal(sample.elapsedUs, 450_000_000);
  assert.equal(sample.distanceMeters, 1_315);
  assert.equal(sample.heartRateBpm, 148);
  assert.equal(sampleActivity(activity, -1), null);
  assert.equal(sampleActivity(activity, 1_800_000_001), null);
});

test('missing metrics are not carried across an unknown interval', () => {
  const activity = validateActivity({ schemaVersion: 1, activityId: 'missing-metric',
    startUtcUs: 1_767_254_400_000_000, endUtcUs: 1_767_254_420_000_000,
    records: [{ elapsedUs: 0, heartRateBpm: 120, paceSecondsPerKilometer: null },
      { elapsedUs: 10_000_000, heartRateBpm: null, paceSecondsPerKilometer: 350 },
      { elapsedUs: 20_000_000, heartRateBpm: 140, paceSecondsPerKilometer: 330 }] });
  assert.equal(sampleActivity(activity, 0).heartRateBpm, 120);
  assert.equal(sampleActivity(activity, 5_000_000).heartRateBpm, null);
  assert.equal(sampleActivity(activity, 5_000_000).paceSecondsPerKilometer, null);
  assert.equal(sampleActivity(activity, 10_000_000).heartRateBpm, null);
  assert.equal(sampleActivity(activity, 15_000_000).heartRateBpm, null);
  assert.equal(sampleActivity(activity, 15_000_000).paceSecondsPerKilometer, 340);
});

test('one clock anchor applies a constant per-camera offset', () => {
  const model = buildCameraClockModel('camera-a', [{
    cameraUtcUs: 1_767_254_710_000_000,
    fitUtcUs: 1_767_254_707_500_000,
  }]);
  assert.equal(mapCameraUtcUs(model, 1_767_254_720_000_000), 1_767_254_717_500_000);
});

test('two clock anchors estimate bounded linear drift with integer math', () => {
  const model = buildCameraClockModel('camera-a', [
    { cameraUtcUs: 1_000_000_000, fitUtcUs: 1_000_000_000 },
    { cameraUtcUs: 4_600_003_600, fitUtcUs: 4_600_000_000 },
  ]);
  assert.equal(mapCameraUtcUs(model, 4_600_003_600), 4_600_000_000);
  assert.throws(() => buildCameraClockModel('camera-a', [
    { cameraUtcUs: 0, fitUtcUs: 0 },
    { cameraUtcUs: 1_000_000, fitUtcUs: 1_020_000 },
  ]), /exceeds allowed/);
});

test('capture evidence requires independent agreement for high confidence', () => {
  const activity = fixture('activity.synthetic.json');
  const media = fixture('media.synthetic.json')['media-a'];
  const ranked = rankCaptureTimeCandidates(media.captureTimeCandidates, activity);
  assert.equal(ranked.confidence, 'high');
  assert.equal(ranked.selected.source, 'quicktime.creationdate');

  const single = rankCaptureTimeCandidates([media.captureTimeCandidates[0]], activity);
  assert.equal(single.confidence, 'review');

  const duplicatedContainerField = rankCaptureTimeCandidates([
    media.captureTimeCandidates[0],
    {
      ...media.captureTimeCandidates[0],
      source: 'resolve.date-created',
    },
  ], activity);
  assert.equal(duplicatedContainerField.confidence, 'review');
});

test('piecewise sync map respects source trim and jumps at edits', () => {
  const activity = fixture('activity.synthetic.json');
  const timeline = fixture('timeline.synthetic.json');
  const mediaById = fixture('media.synthetic.json');
  const syncMap = compileSyncMap({ activity, timeline, mediaById });

  assert.equal(syncMap.diagnostics.length, 0);
  assert.equal(syncMap.segments.length, 2);
  assert.equal(syncMap.segments[0].activityStartUs, 322_000_000);
  assert.equal(syncMap.segments[1].activityStartUs, 1_200_000_000);
  assert.deepEqual(syncMap.segments[0].activityUsPerTimelineFrame, { numerator: 100_100, denominator: 3 });
  assert.equal(activityElapsedUsAtFrame(syncMap, 0), 322_000_000);
  assert.equal(activityElapsedUsAtFrame(syncMap, 299), 331_976_633);
  assert.equal(activityElapsedUsAtFrame(syncMap, 300), 1_200_000_000);
  assert.equal(activityElapsedUsAtFrame(syncMap, 600), null);
});

test('review-only timestamp evidence does not silently create a segment', () => {
  const activity = fixture('activity.synthetic.json');
  const timeline = fixture('timeline.synthetic.json');
  const mediaById = fixture('media.synthetic.json');
  mediaById['media-a'].captureTimeCandidates = [mediaById['media-a'].captureTimeCandidates[0]];
  const syncMap = compileSyncMap({ activity, timeline, mediaById });
  assert.equal(syncMap.segments.length, 1);
  assert.equal(syncMap.diagnostics[0].code, 'capture-time-needs-review');
});


test('disabled track, unsupported mapping, and changed enabled state invalidate synchronization', () => {
  const { timelineFingerprint } = require('../src/sync/compile-sync-map');
  const activity = fixture('activity.synthetic.json'); const timeline = fixture('timeline.synthetic.json'); const mediaById = fixture('media.synthetic.json');
  const before = timelineFingerprint(timeline);
  timeline.referenceVideoTrackEnabled = false;
  assert.notEqual(timelineFingerprint(timeline), before);
  assert.equal(compileSyncMap({ activity, timeline, mediaById }).segments.length, 0);
  timeline.referenceVideoTrackEnabled = true;
  timeline.items[0].mappingIssue = 'Unverified retime';
  assert.equal(compileSyncMap({ activity, timeline, mediaById }).segments.length, 1);
  delete timeline.items[0].mappingIssue;
  timeline.items[0].clipEnabled = false;
  assert.notEqual(timelineFingerprint(timeline), before);
  timeline.items[0].clipEnabled = true;
  timeline.frameRate = { numerator: 25, denominator: 1 };
  assert.notEqual(timelineFingerprint(timeline), before);
});

test('clock drift changes the rate inside each segment as well as its first frame', () => {
  const activity = fixture('activity.synthetic.json'); const timeline = fixture('timeline.synthetic.json'); const mediaById = fixture('media.synthetic.json');
  const baseline = compileSyncMap({ activity, timeline, mediaById });
  const group = timeline.items[0].cameraGroupId;
  const camera = activity.startUtcUs + baseline.segments[0].activityStartUs;
  const cameraClockModels = { [group]: buildCameraClockModel(group, [{ cameraUtcUs: camera, fitUtcUs: camera }, { cameraUtcUs: camera + 1000000000, fitUtcUs: camera + 1001000000 }]) };
  const result = compileSyncMap({ activity, timeline, mediaById, cameraClockModels });
  assert.equal(result.segments[0].activityStartUs, baseline.segments[0].activityStartUs);
  const first = result.segments[0].timelineStartFrame;
  assert.equal(activityElapsedUsAtFrame(result, first + 100), result.segments[0].activityStartUs + Math.round(100 * 100100 / 3 * 1.001));
});

test('all supported frame rates and timeline origins preserve trim, later comp mapping, cuts and gaps', () => {
  for (const rate of [24,25,30,50,30000/1001,60000/1001]) for (const origin of [0,Math.round(rate)*3600]) {
    const activity = fixture('activity.synthetic.json'); const timeline = fixture('timeline.synthetic.json'); const mediaById = fixture('media.synthetic.json');
    timeline.frameRate = require('../src/resolve/resolve-adapter').parseFrameRate(rate === 30000/1001 ? '29.97' : rate === 60000/1001 ? '59.94' : rate);
    timeline.timelineStartFrame = origin; timeline.timelineEndFrame += origin + 20;
    for (const [index,item] of timeline.items.entries()) { item.timelineStartFrame += origin + index*20; item.timelineEndFrameExclusive += origin + index*20; }
    const map = compileSyncMap({activity,timeline,mediaById});
    assert.equal(activityElapsedUsAtFrame(map,origin),322000000);
    assert.equal(activityElapsedUsAtFrame(map,origin+300),null);
    assert.equal(activityElapsedUsAtFrame(map,origin+320),1200000000);
  }
});
