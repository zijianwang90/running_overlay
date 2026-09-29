'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { inspectReferenceTrack, mappingIssueForItem } = require('../src/resolve/otio-inspection');
const { carrierTimeline } = require('../src/resolve/managed-overlay');
const { sourceFrameRateFromProperties } = require('../src/resolve/resolve-adapter');
const fps = { numerator: 30, denominator: 1 };
function sample() { return carrierTimeline('/synthetic/source.mov', 100, 30); }
test('ordinary source evidence matches identity, trim and record range', () => {
  const x = sample(); const evidence = inspectReferenceTrack(x, 1, 0, fps);
  const item = { timelineStartFrame: 0, timelineEndFrameExclusive: 100, sourceStartFrame: 0, sourceFrameRate: fps, clipEnabled: true };
  assert.equal(mappingIssueForItem(evidence, item, '/synthetic/source.mov'), null);
  assert.match(mappingIssueForItem(evidence, { ...item, sourceStartFrame: 1 }, '/synthetic/source.mov'), /trim/);
  assert.match(mappingIssueForItem(evidence, item, '/synthetic/other.mov'), /identity/);
});
test('speed, reverse, freeze, speed-ramp and unknown effects block mapping', () => {
  for (const effect of [
    { OTIO_SCHEMA: 'LinearTimeWarp.1', time_scalar: 2 },
    { OTIO_SCHEMA: 'LinearTimeWarp.1', time_scalar: -1 },
    { OTIO_SCHEMA: 'FreezeFrame.1' },
    { OTIO_SCHEMA: 'Effect.1', effect_name: 'Resolve Effect', metadata: { Resolve_OTIO: { 'Effect Name': 'Retime' } } },
  ]) {
    const x = sample(); x.tracks.children[0].children[0].effects = [effect];
    assert.match(inspectReferenceTrack(x, 1, 0, fps)[0].issue, /Retime/);
  }
});
test('nested references and missing or invalid source frame rates are never accepted as ordinary media', () => {
  const x = sample(); x.tracks.children[0].children[0].OTIO_SCHEMA = 'Stack.1';
  assert.match(inspectReferenceTrack(x, 1, 0, fps)[0].issue, /Compound/);
  assert.equal(sourceFrameRateFromProperties({}), null);
  assert.equal(sourceFrameRateFromProperties({ FPS: 'unknown' }), null);
});


test('Resolve NTSC OTIO truncation is bounded by one exported frame without changing source authority', () => {
  const x = sample(); x.global_start_time.rate = 30000/1001;
  const clip = x.tracks.children[0].children[0];
  clip.source_range.duration = { value:119, rate:30000/1001 };
  clip.source_range.start_time = { value:359, rate:30000/1001 };
  const evidence = inspectReferenceTrack(x,1,0,{numerator:30000,denominator:1001});
  const item = { timelineStartFrame:0, timelineEndFrameExclusive:119, sourceStartFrame:360, sourceFrameRate:fps, clipEnabled:true };
  assert.equal(mappingIssueForItem(evidence,item,'/synthetic/source.mov'),null);
  assert.match(mappingIssueForItem(evidence,{...item,sourceStartFrame:361},'/synthetic/source.mov'),/trim/);
});
