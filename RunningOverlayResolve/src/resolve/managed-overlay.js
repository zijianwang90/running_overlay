'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const zlib = require('node:zlib');
const crypto = require('node:crypto');
const { invariant } = require('../domain/validation');
const { dataUpdateScript, timeOffsetScript } = require('./fusion-script');
const { contextForResolve } = require('../workflow/configuration');
const FUSE_ID = 'Fuse.RunningOverlayNumeric';
const TRACK_NAME = 'Running Overlay';
const OVERLAY_SPLIT = 'overlay-split';
const OVERLAY_SPLIT_MESSAGE = 'The Running Overlay clip is in more than one piece, so it cannot be updated as one clip. Undo the cuts or delete the extra pieces to update it.';
const OVERLAY_OFF_PIECE = 'overlay-off-piece';
const values = (object) => Array.isArray(object) ? object : Object.values(object ?? {});

// A generated transparent still is only a duration carrier, never rendered overlay media.
function transparentPNG() {
  const crc = (buffer) => {
    let value = 0xffffffff;
    for (const byte of buffer) { value ^= byte; for (let bit = 0; bit < 8; bit++) value = (value >>> 1) ^ ((value & 1) ? 0xedb88320 : 0); }
    return (value ^ 0xffffffff) >>> 0;
  };
  const chunk = (type, data) => {
    const label = Buffer.from(type); const size = Buffer.alloc(4); size.writeUInt32BE(data.length);
    const checksum = Buffer.alloc(4); checksum.writeUInt32BE(crc(Buffer.concat([label, data])));
    return Buffer.concat([size, label, data, checksum]);
  };
  const header = Buffer.alloc(13); header.writeUInt32BE(16, 0); header.writeUInt32BE(16, 4); header[8] = 8; header[9] = 6;
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', header), chunk('IDAT', zlib.deflateSync(Buffer.alloc(16 * (1 + 16 * 4)))), chunk('IEND', Buffer.alloc(0))]);
}
function carrierTimeline(file, duration, fps) {
  const time = (value) => ({ OTIO_SCHEMA: 'RationalTime.1', rate: fps, value });
  const range = (length) => ({ OTIO_SCHEMA: 'TimeRange.1', start_time: time(0), duration: time(length) });
  return { OTIO_SCHEMA: 'Timeline.1', name: 'Running Overlay Carrier', global_start_time: time(0), metadata: {}, tracks: {
    OTIO_SCHEMA: 'Stack.1', children: [{ OTIO_SCHEMA: 'Track.1', kind: 'Video', name: TRACK_NAME, children: [{
      OTIO_SCHEMA: 'Clip.2', name: TRACK_NAME, source_range: range(duration), effects: [], enabled: true,
      media_references: { DEFAULT_MEDIA: { OTIO_SCHEMA: 'ExternalReference.1', target_url: file, available_range: range(1), metadata: {} } }, active_media_reference_key: 'DEFAULT_MEDIA',
    }] }],
  } };
}
async function pieceKey(item) {
  const media = await item.GetMediaPoolItem?.();
  return media?.GetUniqueId ? `media:${await media.GetUniqueId()}` : `name:${await item.GetName?.()}`;
}
async function managedPieces(timeline, owner, expectedItemId = null) {
  const items = [];
  const count = Number(await timeline.GetTrackCount('video'));
  for (let track = 1; track <= count; track++) {
    for (const item of values(await timeline.GetItemListInTrack('video', track))) {
      const owned = values(await item.GetMarkers()).some((marker) => marker.customData === owner);
      if (expectedItemId && String(await item.GetUniqueId()) === expectedItemId) invariant(owned, 'The saved overlay ownership marker was removed. Restore its marker before updating.');
      items.push({ item, track, owned });
    }
  }
  const found = items.filter((entry) => entry.owned);
  // A blade cut may leave the ownership marker on only one piece, so the other
  // piece is recognized by sharing the same source on the same track.
  if (found.length === 1) {
    const key = await pieceKey(found[0].item);
    for (const entry of items) if (!entry.owned && entry.track === found[0].track && await pieceKey(entry.item) === key) found.push(entry);
  }
  return found;
}
const splitError = () => Object.assign(new Error(OVERLAY_SPLIT_MESSAGE), { code: OVERLAY_SPLIT });
async function findManagedOverlay(timeline, owner, expectedItemId = null) {
  const found = await managedPieces(timeline, owner, expectedItemId);
  if (found.length > 1) throw splitError();
  return found[0] ?? null;
}
async function managedOverlayIsCurrent(timeline, contextId, configuration, scan) {
  const found = await findManagedOverlay(timeline, `running-overlay:v1:${contextId}`, configuration.managedItemId);
  if (!found || !configuration.managedItemId) return false;
  return String(await found.item.GetUniqueId()) === configuration.managedItemId
    && Number(await found.item.GetStart()) === scan.timeline.timelineStartFrame
    && Number(await found.item.GetEnd()) === scan.timeline.timelineEndFrame
    && Number(await found.item.GetSourceStartFrame()) === 0
    && await found.item.GetClipEnabled() !== false
    && await timeline.GetIsTrackEnabled('video', found.track) !== false;
}
const BRIDGE_VOID = /Parse - Unknown object type detected for key:result \(type:-1\)/;
async function fusionVoid(operation) {
  try { await operation(); }
  catch (error) {
    // Resolve 21 Workflow cannot marshal Fusion's void return. The operation has
    // executed; its scalar acknowledgment is checked separately.
    if (!BRIDGE_VOID.test(error.message)) throw error;
  }
}
// The Workflow bridge returns empty objects for Fusion Tool instances. Execute a
// transaction inside Fusion, then read its token-scoped scalar acknowledgment.
async function runFusionOperation(comp, script, token, { attempts = 100, intervalMs = 100 } = {}) {
  await fusionVoid(() => comp.Execute(script));
  let result;
  for (let attempt = 0; attempt < attempts; attempt++) {
    try { result = await comp.GetData('RunningOverlay.Operation'); }
    catch (error) {
      if (!BRIDGE_VOID.test(error.message)) throw error;
      result = null; // Fusion has not written the first acknowledgment yet.
    }
    if (typeof result === 'string' && result.startsWith(`${token}|`)) break;
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  if (typeof result === 'string' && result.startsWith(`${token}|error:`)) throw new Error(result.slice(`${token}|error:`.length));
  invariant(typeof result === 'string' && (result === `${token}|ok` || result.startsWith(`${token}|ok|`)), 'Fusion did not acknowledge the overlay update.');
  return result.slice(`${token}|ok`.length).replace(/^\|/, '');
}
async function setDataInputs(comp, bundleDirectory, origin, initialize = false, widgets, layoutPreset, initialTimeOffsetSeconds = 0) {
  const token = crypto.randomUUID();
  await runFusionOperation(comp, dataUpdateScript({ bundleDirectory, origin, token, initialize, widgets, layoutPreset, initialTimeOffsetSeconds }), token);
}
// Offset reads and writes run often while the user watches the edit, so they
// use a short poll and never rescan the timeline.
async function overlayTimeOffset(comp, offsetSeconds = null) {
  const token = crypto.randomUUID();
  const payload = await runFusionOperation(comp, timeOffsetScript({ token, offsetSeconds }), token, { attempts: 120, intervalMs: 25 });
  const [value, state] = payload.split('|');
  const seconds = Number(value);
  invariant(Number.isFinite(seconds), 'Fusion returned an invalid data time offset.');
  return { seconds, animated: state === 'animated' };
}
// Each cut piece has its own composition, so each keeps its own offset. Compositions
// load lazily: a heavily cut overlay only touches the pieces the user visits.
async function offsetPieces(timeline, contextId, managedItemId) {
  invariant(managedItemId, 'Create the overlay first.');
  const found = await managedPieces(timeline, `running-overlay:v1:${contextId}`, managedItemId);
  invariant(found.length > 0, 'The managed overlay is missing. Update the overlay to recreate it.');
  if (new Set(found.map((entry) => entry.track)).size > 1) throw splitError();
  const pieces = [];
  for (const { item } of found) pieces.push({ id: String(await item.GetUniqueId()), start: Number(await item.GetStart()), load: async () => {
    invariant(Number(await item.GetFusionCompCount()) === 1, 'The managed clip must contain exactly one Fusion composition.');
    return item.GetFusionCompByIndex(1);
  } });
  invariant(pieces.length > 1 || pieces[0].id === managedItemId, 'The managed overlay is missing. Update the overlay to recreate it.');
  return pieces.sort((left, right) => left.start - right.start);
}
async function createCarrierPoolItem(project, timeline, directory, duration, fps) {
  const pool = await project.GetMediaPool();
  const png = path.join(directory, 'carrier.png');
  const otio = path.join(directory, 'carrier.otio');
  await fs.writeFile(png, transparentPNG());
  await fs.writeFile(otio, JSON.stringify(carrierTimeline(png, duration, fps)));
  let staging = null;
  try {
    staging = await pool.ImportTimelineFromFile(otio, { timelineName: `Running Overlay Setup ${crypto.randomUUID()}` });
    invariant(staging, 'Resolve could not create the overlay duration carrier.');
    invariant(await project.SetCurrentTimeline(staging), 'Could not open overlay staging timeline.');
    const clips = values(await staging.GetItemListInTrack('video', 1));
    invariant(clips.length === 1 && Number(await clips[0].GetDuration()) === duration, 'Resolve changed the overlay duration during import.');
    const fusionClip = await staging.CreateFusionClip(clips);
    invariant(fusionClip, 'Resolve could not create a Fusion clip.');
    const media = await fusionClip.GetMediaPoolItem();
    invariant(media, 'Resolve did not expose the Fusion clip for placement.');
    return media;
  } finally {
    await project.SetCurrentTimeline(timeline);
    if (staging) await pool.DeleteTimelines([staging]);
  }
}
async function updateManagedOverlay(resolve, { contextId, syncMap, bundleDirectory, expectedItemId = null, referenceVideoTrackIndex = 1, widgets, layoutPreset, initialTimeOffsetSeconds = 0 }) {
  const context = await contextForResolve(resolve);
  invariant(context.contextId === contextId, 'The active project or timeline changed. Rescan before applying.');
  const { project, timeline } = context;
  invariant(!await project.IsRenderingInProgress(), 'Resolve is rendering. Wait for the export to finish before updating the overlay.');
  const owner = `running-overlay:v1:${contextId}`;
  const existing = await findManagedOverlay(timeline, owner, expectedItemId);
  const start = syncMap.timelineStartFrame;
  // Reference extent, not the managed overlay's previous end.
  const end = syncMap.timelineEndFrame;
  const duration = end - start;
  invariant(Number.isSafeInteger(duration) && duration > 0, 'Overlay duration must be positive.');
  if (existing) invariant(await timeline.GetIsTrackEnabled('video', existing.track) && await existing.item.GetClipEnabled(), 'Enable the Running Overlay track and clip before updating.');
  if (existing && Number(await existing.item.GetStart()) === start && Number(await existing.item.GetEnd()) === end) {
    invariant(await timeline.GetIsTrackEnabled('video', existing.track) && await existing.item.GetClipEnabled(), 'Enable the Running Overlay track and clip before updating.');
    invariant(Number(await existing.item.GetFusionCompCount()) === 1, 'The managed clip must contain exactly one Fusion composition.');
    const sourceStart = Number(await existing.item.GetSourceStartFrame());
    invariant(sourceStart === 0, 'The managed overlay was source-trimmed. Restore its original trim before updating.');
    const comp = await existing.item.GetFusionCompByIndex(1);
    await setDataInputs(comp, bundleDirectory, start, false, widgets, layoutPreset, initialTimeOffsetSeconds);
    return { managedItemId: String(await existing.item.GetUniqueId()), replaced: false };
  }

  const pool = await project.GetMediaPool();
  let item = null; let track = null; let media = null; let committed = false;
  const backup = path.join(bundleDirectory, 'previous.comp');
  if (existing) {
    invariant(Number(await existing.item.GetFusionCompCount()) === 1, 'The managed clip must contain exactly one Fusion composition.');
    invariant(await existing.item.ExportFusionComp(backup, 1), 'Could not preserve the existing overlay composition.');
  }
  try {
    media = await createCarrierPoolItem(project, timeline, bundleDirectory, duration, syncMap.frameRate.numerator / syncMap.frameRate.denominator);
    invariant(await timeline.AddTrack('video'), 'Could not add a dedicated overlay track.');
    track = Number(await timeline.GetTrackCount('video'));
    invariant(await timeline.SetTrackName('video', track, TRACK_NAME), 'Could not name the overlay track.');
    const placed = values(await pool.AppendToTimeline([{ mediaPoolItem: media, startFrame: 0, endFrame: duration, recordFrame: start, trackIndex: track, mediaType: 1 }]));
    invariant(placed.length === 1, 'Could not place the overlay Fusion clip.');
    item = placed[0];
    invariant(Number(await item.GetStart()) === start && Number(await item.GetEnd()) === end, 'Resolve changed the requested overlay range.');
    const comp = existing ? await item.ImportFusionComp(backup) : await item.AddFusionComp();
    invariant(comp, 'Could not initialize the overlay composition.');
    await setDataInputs(comp, bundleDirectory, start, !existing, widgets, layoutPreset, initialTimeOffsetSeconds);
    invariant(await item.AddMarker(0, 'Cyan', TRACK_NAME, 'Managed live activity overlay', 1, owner), 'Could not record overlay ownership.');
    if (existing) invariant(await timeline.DeleteClips([existing.item], false), 'Could not replace the previous managed overlay.');
    committed = true;
    // Only remove an empty, plugin-named old track after the replacement succeeded.
    if (existing && existing.track > referenceVideoTrackIndex && (await timeline.GetTrackName('video', existing.track)) === TRACK_NAME && values(await timeline.GetItemListInTrack('video', existing.track)).length === 0) await timeline.DeleteTrack('video', existing.track);
    return { managedItemId: String(await item.GetUniqueId()), replaced: Boolean(existing) };
  } catch (error) {
    if (committed) throw error;
    if (item) await timeline.DeleteClips([item], false);
    if (track && values(await timeline.GetItemListInTrack('video', track)).length === 0) await timeline.DeleteTrack('video', track);
    if (media) await pool.DeleteClips([media]);
    throw error;
  } finally { await fs.rm(backup, { force: true }); }
}
module.exports = { FUSE_ID, OVERLAY_SPLIT, OVERLAY_SPLIT_MESSAGE, OVERLAY_OFF_PIECE, carrierTimeline, transparentPNG, findManagedOverlay, managedOverlayIsCurrent, setDataInputs, overlayTimeOffset, offsetPieces, updateManagedOverlay };
