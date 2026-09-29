'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { compileSyncMap } = require('../src/sync/compile-sync-map');
const {
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
