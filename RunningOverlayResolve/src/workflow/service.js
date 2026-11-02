'use strict';
const path = require('node:path');
const fs = require('node:fs/promises');
const crypto = require('node:crypto');
const { invariant } = require('../domain/validation');
const { scanCurrentTimeline } = require('../resolve/resolve-adapter');
const { updateManagedOverlay, managedOverlayIsCurrent, offsetPieces, overlayTimeOffset, captureOverlayStyles, OVERLAY_SPLIT, OVERLAY_SPLIT_MESSAGE, OVERLAY_OFF_PIECE } = require('../resolve/managed-overlay');
const { validOffsetSeconds, pairCapturedSlots } = require('../resolve/fusion-script');
const { compileSyncMap, timelineFingerprint } = require('../sync/compile-sync-map');
const { writeResolveBundle } = require('../io/render-data');
const { fetchRouteMap, fetchRouteTiles } = require('../map/mapbox');
const { contextForResolve, validateConfiguration, applyConfirmedCaptureTimes, cameraModels } = require('./configuration');
const { MemorySettingsStore } = require('./settings');
const { offsetAt } = require('../sync/capture-time');
const { templateById } = require('../domain/templates');
const { composeTemplateElements } = require('../domain/user-templates');

// The recording timezone stands in for the activity's local clock. The offset at
// activity start seeds new Real Time widgets; Fusion keeps it editable afterwards.
function clockUtcOffsetHours(configuration, systemTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone) {
  const zone = configuration.captureTimeZone ?? systemTimeZone;
  return offsetAt(Math.floor(configuration.activity.startUtcUs / 1000), zone) / 60;
}

const editable = (value) => JSON.stringify([value.referenceVideoTrackIndex, value.activity, value.weather, value.confirmedCaptureUtcByMediaId, value.cameraAnchors, value.widgets, value.templateId, value.customTemplate, value.captureTimeZone, value.captureTimeZonesByMediaId, value.mapDetail]);
class WorkflowService {
  constructor({ getResolve, store, bundleRoot, settings = new MemorySettingsStore(), scan = scanCurrentTimeline, update = updateManagedOverlay, inspectManaged = managedOverlayIsCurrent,
    pieces = offsetPieces, offset = overlayTimeOffset, captureStyles = captureOverlayStyles, fetchMap = fetchRouteMap,
    fetchMapTiles = fetchRouteTiles }) {
    Object.assign(this, { getResolve, store, bundleRoot, settings, scan, update, inspectManaged, pieces, offset, captureStyles, fetchMap, fetchMapTiles });
    this.queue = Promise.resolve();
    this.applying = false;
    this.offsetTarget = null;
  }
  exclusive(work) {
    const next = this.queue.then(work); this.queue = next.catch(() => {}); return next;
  }
  async configuration(context) {
    const loaded = await this.store.load(context.contextId) ?? validateConfiguration({ schemaVersion: 1, contextId: context.contextId, referenceVideoTrackIndex: 1 });
    return await this.migrateLegacyToken(loaded);
  }
  // Older builds kept the Mapbox token in each project. Move it to the user
  // settings once, then rewrite the project file without it, so a normal scan is
  // enough and no apply is required. An existing user token wins.
  async migrateLegacyToken(configuration) {
    if (!configuration.mapboxToken) return configuration;
    const settings = await this.settings.load();
    if (!settings.mapboxToken) await this.settings.save({ ...settings, mapboxToken: configuration.mapboxToken });
    return await this.store.save({ ...configuration, mapboxToken: null });
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
    const timeOffset = await this.readOffsetForScan(context, configuration);
    return { contextId: context.contextId, scan, configuration: timeOffset.configuration, timeOffset: timeOffset.value, splitOverlay,
      // Cut pieces keep their own source frames and move with the footage, so they are never stale.
      fingerprint: timelineFingerprint(scan.timeline), stale: !splitOverlay && (!managedIsCurrent || configuration.lastAppliedFingerprint !== timelineFingerprint(scan.timeline)) };
  }
  async readOffsetForScan(context, configuration) {
    const draft = { seconds: configuration.draftTimeOffsetMs / 1000, animated: false, source: 'draft' };
    if (!configuration.managedItemId) return { configuration, value: draft };
    try {
      const target = await this.offsetTargetAtPlayhead(context, configuration.managedItemId);
      const value = { ...await this.offset(target.comp), source: 'overlay', piece: target.piece };
      const mirrored = Math.round(value.seconds * 1000);
      // Mirror only; the renderer remains authoritative once it exists. Cut pieces
      // hold separate values, so there is no single value to mirror.
      const saved = target.piece || mirrored === configuration.draftTimeOffsetMs ? configuration : await this.store.save({ ...configuration, draftTimeOffsetMs: mirrored });
      return { configuration: saved, value };
    } catch (error) {
      this.offsetTarget = null;
      return { configuration, value: { ...draft, source: 'unavailable', error: error.message } };
    }
  }
  // An uncut overlay is one target. A cut overlay's target is the piece under the
  // playhead; the track above it wins in Resolve, so titles over the overlay hide it.
  async offsetTargetAtPlayhead(context, managedItemId) {
    const cached = this.offsetTarget;
    const pieces = cached && cached.contextId === context.contextId && cached.managedItemId === managedItemId
      ? cached.pieces : await this.pieces(context.timeline, context.contextId, managedItemId);
    this.offsetTarget = { contextId: context.contextId, managedItemId, pieces };
    let index = 0;
    if (pieces.length > 1) {
      const item = await context.timeline.GetCurrentVideoItem();
      const id = item ? String(await item.GetUniqueId()) : null;
      index = pieces.findIndex((piece) => piece.id === id);
      if (index < 0) throw Object.assign(new Error('Park the playhead on a piece of the Running Overlay clip to adjust its timing.'), { code: OVERLAY_OFF_PIECE });
    }
    const target = pieces[index];
    target.comp ??= await target.load();
    return { comp: target.comp, piece: pieces.length > 1 ? { id: target.id, index: index + 1, count: pieces.length } : null };
  }
  // Polled only while the overlay is cut. Null means the panel already shows this piece.
  async readPieceOffset({ contextId, managedItemId, pieceId }) {
    if (this.applying) return null;
    const context = await contextForResolve(await this.getResolve());
    if (context.contextId !== contextId || await context.project.IsRenderingInProgress()) return null;
    try {
      const target = await this.offsetTargetAtPlayhead(context, managedItemId);
      if (target.piece?.id === pieceId) return null;
      return { ...await this.offset(target.comp), source: 'overlay', piece: target.piece };
    } catch (error) {
      if (error.code !== OVERLAY_OFF_PIECE) this.offsetTarget = null;
      return { seconds: 0, animated: false, source: 'unavailable', error: error.message, piece: null };
    }
  }
  // Runs outside the scan queue so dragging stays responsive, but never while an
  // apply may be replacing the managed clip.
  async setTimeOffset({ contextId, managedItemId, seconds }) {
    invariant(!this.applying, 'The overlay is updating. Adjust timing after it finishes.');
    const value = validOffsetSeconds(seconds);
    const context = await contextForResolve(await this.getResolve());
    invariant(context.contextId === contextId, 'Project or timeline changed. Scan again before adjusting timing.');
    invariant(!await context.project.IsRenderingInProgress(), 'Resolve is rendering. Adjust timing after the export finishes.');
    try {
      const target = await this.offsetTargetAtPlayhead(context, managedItemId);
      return { ...await this.offset(target.comp, value), source: 'overlay', piece: target.piece };
    }
    catch (error) { this.offsetTarget = null; throw error; }
  }
  // A template saved before the overlay exists uses the panel's starting layout.
  async currentTemplateElements({ contextId, configuration }) {
    const context = await contextForResolve(await this.getResolve());
    invariant(context.contextId === contextId, 'Project or timeline changed. Scan again before saving a template.');
    invariant(!await context.project.IsRenderingInProgress(), 'Resolve is rendering. Save the template after the export finishes.');
    const value = validateConfiguration(configuration);
    const template = value.customTemplate ?? templateById(value.templateId);
    if (!value.managedItemId) return composeTemplateElements(value.widgets, template);
    // A cut overlay keeps one composition per piece; the first piece that still
    // has active slots supplies the live positions and styles. A piece whose
    // composition cannot be read is skipped rather than failing the save.
    let failure = null;
    for (const piece of await this.pieces(context.timeline, contextId, value.managedItemId)) {
      try {
        const captured = pairCapturedSlots(value.widgets, await this.captureStyles(await piece.load()));
        if (Object.keys(captured).length) return composeTemplateElements(value.widgets, template, captured);
      } catch (error) { failure = error; }
    }
    if (failure) throw failure;
    return composeTemplateElements(value.widgets, template);
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
    // The map snapshot is fetched once per applied revision and then rendered
    // offline. A failed fetch never blocks the overlay; the panel reports it.
    // Static Images requests are billable, so skip the fetch unless a Route Map
    // widget is actually configured.
    // The token is a user-level setting; the project file never holds it. An old
    // panel may still send a legacy token with the apply, so migrate that once.
    const settings = await this.settings.load();
    let mapboxToken = settings.mapboxToken;
    const legacyToken = payload.configuration?.mapboxToken ?? null;
    if (!mapboxToken && legacyToken) {
      mapboxToken = legacyToken;
      await this.settings.save({ ...settings, mapboxToken });
    }
    let mapSnapshot = null;
    let mapTiles = null;
    let mapError = null;
    if (mapboxToken && configuration.widgets.some((widget) => widget.metric === 'routeMap')) {
      try {
        mapSnapshot = await this.fetchMap(configuration.activity, { token: mapboxToken });
        if (configuration.mapDetail) {
          // Detail tiles are opt-in: each apply makes four additional billable
          // Static Images requests. A failure keeps the overview snapshot.
          try { mapTiles = await this.fetchMapTiles(configuration.activity, { token: mapboxToken }); }
          catch (error) { mapError = `Map detail unavailable: ${error.message}`; }
        }
      } catch (error) { mapError = error.message; }
    }
    const revisionRoot = path.join(this.bundleRoot, configuration.contextId, crypto.randomUUID());
    await fs.mkdir(revisionRoot, { recursive: true, mode: 0o700 });
    const bundleDirectory = await writeResolveBundle(revisionRoot, configuration.activity, syncMap, configuration.weather, mapSnapshot, mapTiles);
    // Data files are immutable: old instances keep their complete revision until the input switch.
    const result = await this.update(await this.getResolve(), { contextId: configuration.contextId, syncMap, bundleDirectory, expectedItemId: configuration.managedItemId, referenceVideoTrackIndex: configuration.referenceVideoTrackIndex, widgets: configuration.widgets, templateId: configuration.templateId, customTemplate: configuration.customTemplate, initialTimeOffsetSeconds: configuration.draftTimeOffsetMs / 1000, clockUtcOffsetHours: clockUtcOffsetHours(configuration),
      mapImage: mapSnapshot ? path.join(bundleDirectory, 'map.png') : null,
      mapTiles: mapTiles ? mapTiles.map((_, index) => path.join(bundleDirectory, `map-${index + 1}.png`)) : null });
    const saved = await this.store.save({ ...configuration, ...result, bundleDirectory, lastAppliedFingerprint: snapshot.fingerprint });
    return { configuration: saved, segmentCount: syncMap.segments.length, fingerprint: snapshot.fingerprint, ...(mapError ? { mapError } : {}) };
  }
}
module.exports = { WorkflowService, clockUtcOffsetHours };
