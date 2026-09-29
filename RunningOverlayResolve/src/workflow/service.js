'use strict';
const path = require('node:path');
const fs = require('node:fs/promises');
const crypto = require('node:crypto');
const { invariant } = require('../domain/validation');
const { scanCurrentTimeline } = require('../resolve/resolve-adapter');
const { updateManagedOverlay, managedOverlayIsCurrent } = require('../resolve/managed-overlay');
const { compileSyncMap, timelineFingerprint } = require('../sync/compile-sync-map');
const { writeResolveBundle } = require('../io/render-data');
const { contextForResolve, validateConfiguration, applyConfirmedCaptureTimes, cameraModels } = require('./configuration');

const editable = (value) => JSON.stringify([value.referenceVideoTrackIndex, value.activity, value.confirmedCaptureUtcByMediaId, value.cameraAnchors, value.widgets, value.layoutPreset]);
class WorkflowService {
  constructor({ getResolve, store, bundleRoot, scan = scanCurrentTimeline, update = updateManagedOverlay, inspectManaged = managedOverlayIsCurrent }) {
    Object.assign(this, { getResolve, store, bundleRoot, scan, update, inspectManaged });
    this.queue = Promise.resolve();
  }
  exclusive(work) {
    const next = this.queue.then(work); this.queue = next.catch(() => {}); return next;
  }
  async configuration(context) {
    return await this.store.load(context.contextId) ?? validateConfiguration({ schemaVersion: 1, contextId: context.contextId, referenceVideoTrackIndex: 1 });
  }
  async scanContext(trackIndex, expectedContextId = null) {
    const resolve = await this.getResolve();
    const context = await contextForResolve(resolve);
    if (await context.project.IsRenderingInProgress()) return { paused: true };
    const configuration = await this.configuration(context);
    const scan = await this.scan(resolve, { referenceVideoTrackIndex: expectedContextId && expectedContextId !== context.contextId ? configuration.referenceVideoTrackIndex : trackIndex ?? configuration.referenceVideoTrackIndex });
    invariant((await contextForResolve(resolve)).contextId === context.contextId, 'Project or timeline changed while scanning. Try again.');
    const managedIsCurrent = await this.inspectManaged(context.timeline, context.contextId, configuration, scan);
    return { contextId: context.contextId, scan, configuration, fingerprint: timelineFingerprint(scan.timeline), stale: !managedIsCurrent || configuration.lastAppliedFingerprint !== timelineFingerprint(scan.timeline) };
  }
  async saveConfiguration(payload) {
    const context = await contextForResolve(await this.getResolve());
    invariant(context.contextId === payload.contextId, 'Project or timeline changed. Scan before saving settings.');
    const previous = await this.configuration(context);
    const value = validateConfiguration({ ...previous, ...payload, lastAppliedFingerprint: previous.lastAppliedFingerprint, managedItemId: previous.managedItemId, bundleDirectory: previous.bundleDirectory });
    if (editable(previous) !== editable(value)) value.lastAppliedFingerprint = null;
    return this.store.save(value);
  }
  async apply(payload) {
    const context = await contextForResolve(await this.getResolve());
    invariant(!await context.project.IsRenderingInProgress(), 'Resolve is rendering. Wait for the export to finish before updating the overlay.');
    const configuration = await this.saveConfiguration(payload.configuration);
    invariant(configuration.activity, 'Choose activity data first.');
    const snapshot = await this.scanContext(configuration.referenceVideoTrackIndex);
    invariant(!snapshot.paused, 'Resolve is rendering. Wait for the export to finish before updating the overlay.');
    invariant(snapshot.fingerprint === payload.expectedFingerprint, 'The reference timeline changed. Scan again before applying.');
    const scanErrors = snapshot.scan.diagnostics.filter((entry) => entry.severity === 'error');
    invariant(scanErrors.length === 0, scanErrors.map((entry) => entry.message).join('\n'));
    const syncMap = compileSyncMap({ activity: configuration.activity, timeline: snapshot.scan.timeline,
      mediaById: applyConfirmedCaptureTimes(snapshot.scan.mediaById, configuration.confirmedCaptureUtcByMediaId), cameraClockModels: cameraModels(configuration) });
    const blocking = syncMap.diagnostics.filter((entry) => entry.severity !== 'info');
    invariant(blocking.length === 0, blocking.map((entry) => entry.message).join('\n'));
    invariant(syncMap.segments.length > 0, 'No safe sync segments were found.');
    const revisionRoot = path.join(this.bundleRoot, configuration.contextId, crypto.randomUUID());
    await fs.mkdir(revisionRoot, { recursive: true, mode: 0o700 });
    const bundleDirectory = await writeResolveBundle(revisionRoot, configuration.activity, syncMap);
    // Data files are immutable: old instances keep their complete revision until the input switch.
    const result = await this.update(await this.getResolve(), { contextId: configuration.contextId, syncMap, bundleDirectory, expectedItemId: configuration.managedItemId, referenceVideoTrackIndex: configuration.referenceVideoTrackIndex, widgets: configuration.widgets, layoutPreset: configuration.layoutPreset });
    const saved = await this.store.save({ ...configuration, ...result, bundleDirectory, lastAppliedFingerprint: snapshot.fingerprint });
    return { configuration: saved, segmentCount: syncMap.segments.length, fingerprint: snapshot.fingerprint };
  }
}
module.exports = { WorkflowService };
