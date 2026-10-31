'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { inferRecordingZone, clipSpans } = require('../src/sync/alignment-preview');
const { dataUpdateScript, timeOffsetScript, validOffsetSeconds } = require('../src/resolve/fusion-script');
const { overlayTimeOffset } = require('../src/resolve/managed-overlay');
const { ConfigurationStore, validateConfiguration, contextForResolve } = require('../src/workflow/configuration');
const { WorkflowService } = require('../src/workflow/service');
const activity = require('../fixtures/activity.synthetic.json');
const timeline = require('../fixtures/timeline.synthetic.json');
const mediaById = require('../fixtures/media.synthetic.json');

const wall = { year: 2026, month: 7, day: 2, hour: 18, minute: 47, second: 3, millisecond: 0 };
// Activity from 22:40Z to 00:00Z: the filename clock is Toronto summer time.
const activityStartMs = Date.parse('2026-07-02T22:40:00Z');
const activityEndMs = Date.parse('2026-07-03T00:00:00Z');

test('recording timezone inference places filename clocks inside the activity', () => {
  assert.equal(inferRecordingZone({ wallParts: [wall], activityStartMs, activityEndMs, preferredZones: ['America/Toronto'] }), 'America/Toronto');
  // A preferred zone that does not overlap loses to the whole-hour offset that does.
  assert.equal(inferRecordingZone({ wallParts: [wall], activityStartMs, activityEndMs, preferredZones: ['Asia/Shanghai'] }), 'UTC-04:00');
  assert.equal(inferRecordingZone({ wallParts: [], activityStartMs, activityEndMs }), null);
  const farAway = { ...wall, year: 2025 };
  assert.equal(inferRecordingZone({ wallParts: [farAway], activityStartMs, activityEndMs }), null);
});

test('alignment preview applies capture start, source-in, and the data time offset', () => {
  const items = [
    { timelineItemId: 'a', mediaId: 'm', name: 'A', timelineStartFrame: 0, timelineEndFrameExclusive: 300, sourceStartFrame: 60, sourceFrameRate: { numerator: 30, denominator: 1 } },
    { timelineItemId: 'b', mediaId: 'missing', name: 'B', timelineStartFrame: 300, timelineEndFrameExclusive: 330, sourceStartFrame: 0, sourceFrameRate: { numerator: 30, denominator: 1 } },
    { timelineItemId: 'c', mediaId: 'm', name: 'C', clipEnabled: false, timelineStartFrame: 330, timelineEndFrameExclusive: 360, sourceStartFrame: 0, sourceFrameRate: { numerator: 30, denominator: 1 } },
  ];
  const spans = clipSpans({ items, captureMsByMediaId: { m: activityStartMs + 10_000 }, activityStartMs, activityEndMs,
    frameRate: { numerator: 30, denominator: 1 }, offsetSeconds: 1.5 });
  assert.equal(spans.length, 2);
  assert.deepEqual({ start: spans[0].start, end: spans[0].end, inside: spans[0].overlapsActivity }, { start: 13.5, end: 23.5, inside: true });
  assert.equal(spans[1].known, false);
});

test('a new renderer starts from the draft offset while resyncs never reset it', () => {
  const script = dataUpdateScript({ bundleDirectory: '/tmp/synthetic', origin: 0, token: 't', widgets: [{ id: 'hr', metric: 'heartRate' }], layoutPreset: 'vertical', initialTimeOffsetSeconds: -2.25 });
  assert.match(script, /if fresh then update\("TimeOffset", -2\.25\) end/);
  assert.equal(validOffsetSeconds(1.23456), 1.235);
  assert.throws(() => validOffsetSeconds(Number.NaN), /within one day/);
  assert.throws(() => validOffsetSeconds(90_000), /within one day/);
  assert.throws(() => dataUpdateScript({ bundleDirectory: 'x', origin: 0, token: 't', initialTimeOffsetSeconds: Infinity }), /within one day/);
});

test('offset script reads without writing and refuses to overwrite an animated offset', () => {
  const read = timeOffsetScript({ token: 't' });
  assert.match(read, /local requested = nil/);
  const write = timeOffsetScript({ token: 't', offsetSeconds: 0.5 });
  assert.match(write, /local requested = 0\.5/);
  assert.match(write, /assert\(not animated/);
  assert.match(write, /comp:StartUndo\("Adjust Running Overlay timing"\)/);
  assert.match(write, /RunningOverlay\.ManagedNumeric/);
});

function fusionComp(reply) {
  let script;
  return {
    Execute: async (value) => { script = value; },
    GetData: async () => {
      const token = script.match(/local token = string\.sub\(\[\[x([^\]]+)/)[1];
      return `${token}|${reply}`;
    },
  };
}
test('overlay offset round-trips through the scalar Fusion acknowledgment', async () => {
  assert.deepEqual(await overlayTimeOffset(fusionComp('ok|1.250|static'), 1.25), { seconds: 1.25, animated: false });
  assert.deepEqual(await overlayTimeOffset(fusionComp('ok|-3.000|animated')), { seconds: -3, animated: true });
  await assert.rejects(overlayTimeOffset(fusionComp('error:The data time offset is animated in Fusion.'), 1), /animated in Fusion/);
});

test('configuration validates the draft offset and keeps it out of data staleness', () => {
  const id = 'c'.repeat(64);
  assert.equal(validateConfiguration({ schemaVersion: 1, contextId: id, referenceVideoTrackIndex: 1 }).draftTimeOffsetMs, 0);
  assert.throws(() => validateConfiguration({ schemaVersion: 1, contextId: id, referenceVideoTrackIndex: 1, draftTimeOffsetMs: 0.5 }), /within one day/);
  assert.equal(validateConfiguration({ schemaVersion: 1, contextId: id, referenceVideoTrackIndex: 1, activityLabel: 'run.fit' }).activityLabel, null);
});

async function harness(t, overrides = {}) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ro-offset-test-')); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const hostTimeline = { GetUniqueId: async () => timeline.timelineId };
  const project = { IsRenderingInProgress: async () => false, GetUniqueId: async () => 'project', GetCurrentTimeline: async () => hostTimeline };
  const resolve = { GetProjectManager: async () => ({ GetCurrentProject: async () => project }) };
  const context = await contextForResolve(resolve);
  const calls = { offset: [], update: [], composition: 0 };
  let fusionOffset = 4;
  const service = new WorkflowService({ getResolve: async () => resolve, store: new ConfigurationStore(path.join(root, 'config')), bundleRoot: path.join(root, 'bundles'),
    scan: async () => ({ timeline: structuredClone(timeline), mediaById, diagnostics: [] }), inspectManaged: async () => true,
    update: async (_resolve, value) => { calls.update.push(value); return { managedItemId: 'managed-1' }; },
    composition: async () => { calls.composition++; return { id: 'comp' }; },
    offset: async (_comp, seconds = null) => { calls.offset.push(seconds); if (seconds !== null) fusionOffset = seconds; return { seconds: fusionOffset, animated: false }; },
    ...overrides });
  return { service, context, calls };
}

test('the draft offset seeds creation, then the overlay owns and mirrors it', async (t) => {
  const { service, context, calls } = await harness(t);
  const first = await service.scanContext(1);
  assert.deepEqual(first.timeOffset, { seconds: 0, animated: false, source: 'draft' });
  const draft = await service.saveConfiguration({ schemaVersion: 1, contextId: context.contextId, referenceVideoTrackIndex: 1, activity, draftTimeOffsetMs: 2500 });
  assert.equal(draft.lastAppliedFingerprint, null);
  const applied = await service.apply({ configuration: draft, expectedFingerprint: first.fingerprint });
  assert.equal(calls.update[0].initialTimeOffsetSeconds, 2.5);

  const restored = await service.scanContext(1);
  assert.deepEqual(restored.timeOffset, { seconds: 4, animated: false, source: 'overlay' });
  assert.equal(restored.configuration.draftTimeOffsetMs, 4000);
  // A stale panel draft cannot overwrite the renderer's mirrored value.
  const saved = await service.saveConfiguration({ ...applied.configuration, draftTimeOffsetMs: 0 });
  assert.equal(saved.draftTimeOffsetMs, 4000);

  const written = await service.setTimeOffset({ contextId: context.contextId, managedItemId: 'managed-1', seconds: -1.2346 });
  assert.deepEqual(written, { seconds: -1.235, animated: false, source: 'overlay' });
  assert.equal(calls.composition, 1, 'the composition handle is reused between nudges');
});

test('timing writes are refused during apply, after a context switch, and while rendering', async (t) => {
  let rendering = false;
  const { service, context } = await harness(t);
  service.applying = true;
  await assert.rejects(service.setTimeOffset({ contextId: context.contextId, managedItemId: 'managed-1', seconds: 1 }), /updating/);
  service.applying = false;
  await assert.rejects(service.setTimeOffset({ contextId: 'd'.repeat(64), managedItemId: 'managed-1', seconds: 1 }), /changed/);
  const project = await (await (await service.getResolve()).GetProjectManager()).GetCurrentProject();
  project.IsRenderingInProgress = async () => rendering;
  rendering = true;
  await assert.rejects(service.setTimeOffset({ contextId: context.contextId, managedItemId: 'managed-1', seconds: 1 }), /rendering/);
});

test('an unreadable overlay offset is reported without failing the scan', async (t) => {
  const { service, context } = await harness(t, { offset: async () => { throw new Error('Install the current Numeric Fuse and restart Resolve.'); } });
  await service.store.save(validateConfiguration({ schemaVersion: 1, contextId: context.contextId, referenceVideoTrackIndex: 1, managedItemId: 'managed-1', draftTimeOffsetMs: 750 }));
  const result = await service.scanContext(1);
  assert.equal(result.timeOffset.source, 'unavailable');
  assert.equal(result.timeOffset.seconds, 0.75);
  assert.match(result.timeOffset.error, /Numeric Fuse/);
});
