'use strict';
const path = require('node:path');
const fs = require('node:fs/promises');
const crypto = require('node:crypto');
const { invariant } = require('../domain/validation');
const { scanCurrentTimeline } = require('../resolve/resolve-adapter');
const { updateManagedOverlay, managedOverlayIsCurrent, managedComposition, overlayTimeOffset, OVERLAY_SPLIT, OVERLAY_SPLIT_MESSAGE } = require('../resolve/managed-overlay');
const { validOffsetSeconds } = require('../resolve/fusion-script');
const { compileSyncMap, timelineFingerprint } = require('../sync/compile-sync-map');
const { writeResolveBundle } = require('../io/render-data');
const { contextForResolve, validateConfiguration, applyConfirmedCaptureTimes, cameraModels } = require('./configuration');

const editable = (value) => JSON.stringify([value.referenceVideoTrackIndex, value.activity, value.confirmedCaptureUtcByMediaId, value.cameraAnchors, value.widgets, value.layoutPreset, value.captureTimeZone, value.captureTimeZonesByMediaId]);
class WorkflowService {
  constructor({ getResolve, store, bundleRoot, scan = scanCurrentTimeline, update = updateManagedOverlay, inspectManaged = managedOverlayIsCurrent,
    composition = managedComposition, offset = overlayTimeOffset }) {
    Object.assign(this, { getResolve, store, bundleRoot, scan, update, inspectManaged, composition, offset });
    this.queue = Promise.resolve();
    this.applying = false;
    this.offsetTarget = null;
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
    let managedIsCurrent = false; let splitOverlay = false;
    try { managedIsCurrent = await this.inspectManaged(context.timeline, context.contextId, configuration, scan); }
    catch (error) { if (error.code !== OVERLAY_SPLIT) throw error; splitOverlay = true; this.offsetTarget = null; }
    const timeOffset = splitOverlay
      ? { configuration, value: { seconds: configuration.draftTimeOffsetMs / 1000, animated: false, source: 'unavailable', error: OVERLAY_SPLIT_MESSAGE } }
      : await this.readOffsetForScan(context, configuration);
    return { contextId: context.contextId, scan, configuration: timeOffset.configuration, timeOffset: timeOffset.value, splitOverlay,
      fingerprint: timelineFingerprint(scan.timeline), stale: !managedIsCurrent || configuration.lastAppliedFingerprint !== timelineFingerprint(scan.timeline) };
  }
  async readOffsetForScan(context, configuration) {
    const draft = { seconds: configuration.draftTimeOffsetMs / 1000, animated: false, source: 'draft' };
    if (!configuration.managedItemId) return { configuration, value: draft };
    try {
      const value = { ...await this.offset(await this.targetComposition(context, configuration.managedItemId)), source: 'overlay' };
      const mirrored = Math.round(value.seconds * 1000);
      // Mirror only; the renderer remains authoritative once it exists.
      const saved = mirrored === configuration.draftTimeOffsetMs ? configuration : await this.store.save({ ...configuration, draftTimeOffsetMs: mirrored });
      return { configuration: saved, value };
    } catch (error) {
      this.offsetTarget = null;
      return { configuration, value: { ...draft, source: 'unavailable', error: error.message } };
    }
  }
  async targetComposition(context, managedItemId) {
    const cached = this.offsetTarget;
    if (cached && cached.contextId === context.contextId && cached.managedItemId === managedItemId) return cached.comp;
    const comp = await this.composition(context.timeline, context.contextId, managedItemId);
    this.offsetTarget = { contextId: context.contextId, managedItemId, comp };
    return comp;
  }
  // Runs outside the scan queue so dragging stays responsive, but never while an
  // apply may be replacing the managed clip.
  async setTimeOffset({ contextId, managedItemId, seconds }) {
    invariant(!this.applying, 'The overlay is updating. Adjust timing after it finishes.');
    const value = validOffsetSeconds(seconds);
    const context = await contextForResolve(await this.getResolve());
    invariant(context.contextId === contextId, 'Project or timeline changed. Scan again before adjusting timing.');
    invariant(!await context.project.IsRenderingInProgress(), 'Resolve is rendering. Adjust timing after the export finishes.');
    try { return { ...await this.offset(await this.targetComposition(context, managedItemId), value), source: 'overlay' }; }
    catch (error) { this.offsetTarget = null; throw error; }
  }
  async saveConfiguration(payload) {
    const context = await contextForResolve(await this.getResolve());
    invariant(context.contextId === payload.contextId, 'Project or timeline changed. Scan before saving settings.');
    const previous = await this.configuration(context);
    const value = validateConfiguration({ ...previous, ...payload, lastAppliedFingerprint: previous.lastAppliedFingerprint, managedItemId: previous.managedItemId, bundleDirectory: previous.bundleDirectory,
      // Once an overlay exists its renderer owns the offset; a panel draft cannot overwrite the mirror.
      draftTimeOffsetMs: previous.managedItemId ? previous.draftTimeOffsetMs : payload.draftTimeOffsetMs ?? previous.draftTimeOffsetMs });
    if (editable(previous) !== editable(value)) value.lastAppliedFingerprint = null;
    return this.store.save(value);
  }
  async apply(payload) {
    this.applying = true;
    try { return await this.applyNow(payload); }
    finally { this.applying = false; this.offsetTarget = null; }
  }
  async applyNow(payload) {
    const context = await contextForResolve(await this.getResolve());
    invariant(!await context.project.IsRenderingInProgress(), 'Resolve is rendering. Wait for the export to finish before updating the overlay.');
    const configuration = await this.saveConfiguration(payload.configuration);
    invariant(configuration.activity, 'Choose activity data first.');
    const snapshot = await this.scanContext(configuration.referenceVideoTrackIndex);
    invariant(!snapshot.paused, 'Resolve is rendering. Wait for the export to finish before updating the overlay.');
    invariant(!snapshot.splitOverlay, OVERLAY_SPLIT_MESSAGE);
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
    const result = await this.update(await this.getResolve(), { contextId: configuration.contextId, syncMap, bundleDirectory, expectedItemId: configuration.managedItemId, referenceVideoTrackIndex: configuration.referenceVideoTrackIndex, widgets: configuration.widgets, layoutPreset: configuration.layoutPreset, initialTimeOffsetSeconds: configuration.draftTimeOffsetMs / 1000 });
    const saved = await this.store.save({ ...configuration, ...result, bundleDirectory, lastAppliedFingerprint: snapshot.fingerprint });
    return { configuration: saved, segmentCount: syncMap.segments.length, fingerprint: snapshot.fingerprint };
  }
}
module.exports = { WorkflowService };
