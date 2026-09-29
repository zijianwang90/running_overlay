'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { ConfigurationStore, parseConfirmedDate, contextForResolve } = require('../src/workflow/configuration');
const { WorkflowService } = require('../src/workflow/service');
const { setDataInputs, findManagedOverlay } = require('../src/resolve/managed-overlay');
const activity = require('../fixtures/activity.synthetic.json');
const timeline = require('../fixtures/timeline.synthetic.json');
const mediaById = require('../fixtures/media.synthetic.json');
const id = 'a'.repeat(64);
test('saved settings survive a fresh store, validate versions, and require explicit valid timezone dates', async (t) => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ro-settings-test-')); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const store = new ConfigurationStore(root);
  const config = { schemaVersion: 1, contextId: id, referenceVideoTrackIndex: 1, activity, confirmedCaptureUtcByMediaId: { media: '2026-01-01T08:05:10+08:00' }, cameraAnchors: { camera: [{ cameraTime: '2026-01-01T00:00:00Z', activityTime: '2026-01-01T00:00:01Z' }] } };
  await store.save(config);
  const restored = await new ConfigurationStore(root).load(id);
  assert.deepEqual(restored.activity, activity); assert.deepEqual(restored.cameraAnchors, config.cameraAnchors);
  assert.deepEqual(restored.confirmedCaptureUtcByMediaId, config.confirmedCaptureUtcByMediaId);
  assert.equal(await store.load('b'.repeat(64)), null);
  assert.throws(() => parseConfirmedDate('2026-01-01T00:00:00'), /timezone/);
  assert.throws(() => parseConfirmedDate('2026-02-30T00:00:00Z'), /calendar/);
  await assert.rejects(store.save({ ...config, schemaVersion: 2 }), /version/);
});
test('Fusion updates require the matching acknowledgment and tolerate only the known void-return bridge error', async () => {
  let script; let reads = 0;
  const comp = {
    Execute: async (value) => { script = value; throw new Error('Execute: Parse - Unknown object type detected for key:result (type:-1)'); },
    GetData: async () => {
      reads++;
      const token = script.match(/local token = string.sub\(\[\[x([^\]]+)/)[1];
      if (reads === 1) throw new Error('GetData: Parse - Unknown object type detected for key:result (type:-1)');
      return reads === 2 ? 'old-operation|ok' : `${token}|ok`;
    },
  };
  await setDataInputs(comp, 'new', 0);
  assert.equal(reads, 3);
  assert.match(script, /AutomaticOrigin/);
  assert.match(script, /comp:EndUndo\(ok\)/);
  await assert.rejects(setDataInputs({ Execute: async () => { throw new Error('Host disconnected'); } }, 'new', 0), /disconnected/);
});
test('Fusion script parameters are literal data even for delimiter and newline-containing paths', () => {
  const { luaString, dataUpdateScript } = require('../src/resolve/fusion-script');
  assert.equal(luaString('line\n]]\n]=]'), 'string.sub([==[xline\n]]\n]=]]==], 2)');
  assert.throws(() => dataUpdateScript({ bundleDirectory:'x', origin:0.5, token:'x' }), /origin/);
});
test('duplicate ownership is refused instead of overwriting an arbitrary composition', async () => {
  const item = { GetMarkers: async () => ({ 0: { customData: 'owner' } }) };
  await assert.rejects(findManagedOverlay({ GetTrackCount: async () => 1, GetItemListInTrack: async () => [item,item] }, 'owner'), /Multiple/);
});
test('service restores configurations, detects edits before mutation, and publishes immutable revisions', async (t) => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ro-service-test-')); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const tl = { GetUniqueId: async () => timeline.timelineId };
  const resolve = { GetProjectManager: async () => ({ GetCurrentProject: async () => ({ IsRenderingInProgress: async () => false, GetUniqueId: async () => 'project', GetCurrentTimeline: async () => tl }) }) };
  const context = await contextForResolve(resolve); let updates = 0; let lastUpdate;
  const scanValue = { timeline: structuredClone(timeline), mediaById, diagnostics: [] };
  const options = { getResolve: async () => resolve, store: new ConfigurationStore(path.join(root, 'config')), bundleRoot: path.join(root, 'bundles'), scan: async () => structuredClone(scanValue), inspectManaged: async () => true, update: async (_resolve, value) => { updates++; lastUpdate = value; return { managedItemId: 'managed-1' }; } };
  const service = new WorkflowService(options);
  const configuration = { schemaVersion: 1, contextId: context.contextId, referenceVideoTrackIndex: 1, activity };
  const snapshot = await service.scanContext(1);
  const first = await service.apply({ configuration, expectedFingerprint: snapshot.fingerprint });
  const reopened = new WorkflowService(options); const restored = await reopened.scanContext();
  assert.equal(restored.stale, false); assert.equal(restored.configuration.managedItemId, 'managed-1');
  const second = await reopened.apply({ configuration: first.configuration, expectedFingerprint: snapshot.fingerprint });
  assert.deepEqual(lastUpdate.widgets, [{ id: 'numeric-1', metric: 'heartRate' }]);
  assert.equal(lastUpdate.layoutPreset, 'vertical');
  assert.notEqual(first.configuration.bundleDirectory, second.configuration.bundleDirectory);
  assert.equal(await fs.readFile(path.join(first.configuration.bundleDirectory, 'sync.rosync'), 'utf8'), await fs.readFile(path.join(second.configuration.bundleDirectory, 'sync.rosync'), 'utf8'));
  const widgetEdit = await reopened.saveConfiguration({ ...second.configuration,
    widgets: [{ id: 'numeric-1', metric: 'heartRate' }, { id: 'pace-1', metric: 'pace' }], layoutPreset: 'grid' });
  assert.equal(widgetEdit.lastAppliedFingerprint, null);
  assert.equal((await reopened.scanContext()).stale, true);
  scanValue.timeline.items[0].timelineStartFrame++;
  assert.equal((await reopened.scanContext()).stale, true);
  await assert.rejects(reopened.apply({ configuration, expectedFingerprint: snapshot.fingerprint }), /changed/);
  assert.equal(updates, 2);
  const changed = await reopened.saveConfiguration({ ...second.configuration, cameraAnchors: { camera: [{ cameraTime:'2026-01-01T00:00:00Z', activityTime:'2026-01-01T00:00:01Z' }] } });
  assert.equal(changed.lastAppliedFingerprint, null);
});


test('missing, disabled and moved managed overlays are stale even when reference data is unchanged', async () => {
  const { managedOverlayIsCurrent } = require('../src/resolve/managed-overlay');
  const owner = `running-overlay:v1:${id}`;
  let enabled = true; let start = 0; let marker = true;
  const item = { GetMarkers: async () => marker ? {0:{customData:owner}} : {}, GetUniqueId: async () => 'managed', GetStart: async () => start, GetEnd: async () => 100, GetSourceStartFrame: async () => 0, GetClipEnabled: async () => enabled };
  let items = [item];
  const host = { GetTrackCount: async () => 1, GetItemListInTrack: async () => items, GetIsTrackEnabled: async () => true };
  const config = {managedItemId:'managed'}; const scan = {timeline:{timelineStartFrame:0,timelineEndFrame:100}};
  assert.equal(await managedOverlayIsCurrent(host,id,config,scan),true);
  enabled = false; assert.equal(await managedOverlayIsCurrent(host,id,config,scan),false);
  enabled = true; start = 10; assert.equal(await managedOverlayIsCurrent(host,id,config,scan),false);
  marker = false; await assert.rejects(managedOverlayIsCurrent(host,id,config,scan),/marker was removed/);
  items = []; assert.equal(await managedOverlayIsCurrent(host,id,config,scan),false);
});

test('switching timelines restores its own reference track instead of reusing an invalid old track', async (t) => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ro-context-test-')); t.after(() => fs.rm(root, { recursive: true, force: true }));
  const hostTimeline = { GetUniqueId: async () => 'new-timeline' };
  const resolve = { GetProjectManager: async () => ({ GetCurrentProject: async () => ({ IsRenderingInProgress: async () => false, GetUniqueId: async () => 'project', GetCurrentTimeline: async () => hostTimeline }) }) };
  let requestedTrack;
  const service = new WorkflowService({ getResolve: async () => resolve, store: new ConfigurationStore(root), bundleRoot: root,
    scan: async (_resolve, options) => { requestedTrack = options.referenceVideoTrackIndex; return { timeline: { ...timeline, timelineId: 'new-timeline' }, mediaById, diagnostics: [] }; },
    inspectManaged: async () => false });
  const result = await service.scanContext(9, 'old-context');
  assert.equal(requestedTrack, 1);
  assert.equal(result.configuration.referenceVideoTrackIndex, 1);
  assert.equal(result.stale, true);
});

test('rendering pauses scans and rejects apply before saving or changing the timeline', async () => {
  let rendering = true; let scans = 0; let saves = 0; let inspections = 0;
  const hostTimeline = { GetUniqueId: async () => timeline.timelineId };
  const project = { IsRenderingInProgress: async () => rendering, GetUniqueId: async () => 'project', GetCurrentTimeline: async () => hostTimeline };
  const resolve = { GetProjectManager: async () => ({ GetCurrentProject: async () => project }) };
  const service = new WorkflowService({ getResolve: async () => resolve, bundleRoot: 'unused',
    store: { load: async () => null, save: async () => { saves++; } },
    scan: async () => { scans++; return { timeline, mediaById, diagnostics: [] }; },
    inspectManaged: async () => { inspections++; return false; },
    update: async () => assert.fail('Must not mutate a rendering project') });
  assert.deepEqual(await service.scanContext(), { paused: true });
  await assert.rejects(service.apply({ configuration: {} }), /Resolve is rendering/);
  assert.equal(scans, 0); assert.equal(inspections, 0); assert.equal(saves, 0);
  rendering = false;
  const resumed = await service.scanContext();
  assert.equal(resumed.stale, true); assert.equal(scans, 1); assert.equal(inspections, 1);
});
