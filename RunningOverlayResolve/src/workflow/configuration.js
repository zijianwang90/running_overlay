'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const { validateActivity } = require('../domain/activity');
const { invariant } = require('../domain/validation');
const { buildCameraClockModel } = require('../sync/clock-model');
const { normalizeWidgets, normalizeLayout } = require('../domain/widgets');
const { validateTimeZone } = require('../sync/capture-time');

function parseConfirmedDate(value) {
  invariant(typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/i.test(value), 'Capture times and anchors must include a timezone (Z or ±HH:mm).');
  const milliseconds = Date.parse(value);
  invariant(Number.isFinite(milliseconds) && Number.isSafeInteger(milliseconds * 1000), 'Invalid capture time or anchor.');
  // Reject normalized invalid calendar days such as February 30.
  const date = value.slice(0, 10);
  invariant(new Date(`${date}T00:00:00Z`).toISOString().slice(0, 10) === date, 'Invalid calendar date.');
  return milliseconds * 1000;
}
function validateConfiguration(value) {
  invariant(value?.schemaVersion === 1, 'Unsupported saved configuration version.');
  invariant(typeof value.contextId === 'string' && /^[a-f0-9]{64}$/.test(value.contextId), 'Invalid project/timeline identity.');
  invariant(Number.isSafeInteger(value.referenceVideoTrackIndex) && value.referenceVideoTrackIndex > 0, 'Choose a reference track.');
  const confirmedCaptureUtcByMediaId = {};
  const captureTimeZonesByMediaId = {};
  for (const [id, zone] of Object.entries(value.captureTimeZonesByMediaId ?? {})) {
    Object.defineProperty(captureTimeZonesByMediaId, id, { value: validateTimeZone(zone), enumerable: true });
  }
  for (const [id, date] of Object.entries(value.confirmedCaptureUtcByMediaId ?? {})) {
    parseConfirmedDate(date);
    Object.defineProperty(confirmedCaptureUtcByMediaId, id, { value: date, enumerable: true });
  }
  const cameraAnchors = {};
  for (const [group, anchors] of Object.entries(value.cameraAnchors ?? {})) {
    invariant(Array.isArray(anchors) && anchors.length <= 2, 'Use one or two anchors per camera.');
    const normalized = anchors.map((anchor) => ({ cameraUtcUs: parseConfirmedDate(anchor.cameraTime), fitUtcUs: parseConfirmedDate(anchor.activityTime) }));
    if (normalized.length) buildCameraClockModel(group, normalized);
    Object.defineProperty(cameraAnchors, group, { value: anchors.map(({ cameraTime, activityTime, cameraTimeZone, activityTimeZone }) => ({
      cameraTime, activityTime,
      ...(cameraTimeZone ? { cameraTimeZone: validateTimeZone(cameraTimeZone) } : {}),
      ...(activityTimeZone ? { activityTimeZone: validateTimeZone(activityTimeZone) } : {}),
    })), enumerable: true });
  }
  return { schemaVersion: 1, contextId: value.contextId, referenceVideoTrackIndex: value.referenceVideoTrackIndex,
    activity: value.activity ? validateActivity(value.activity) : null,
    widgets: normalizeWidgets(value.widgets), layoutPreset: normalizeLayout(value.layoutPreset),
    captureTimeZone: value.captureTimeZone == null ? null : validateTimeZone(value.captureTimeZone), captureTimeZonesByMediaId,
    confirmedCaptureUtcByMediaId, cameraAnchors,
    lastAppliedFingerprint: typeof value.lastAppliedFingerprint === 'string' ? value.lastAppliedFingerprint : null,
    managedItemId: typeof value.managedItemId === 'string' ? value.managedItemId : null,
    bundleDirectory: typeof value.bundleDirectory === 'string' ? value.bundleDirectory : null };
}
function cameraModels(configuration) {
  return Object.fromEntries(Object.entries(configuration.cameraAnchors).filter(([, anchors]) => anchors.length).map(([group, anchors]) => [group,
    buildCameraClockModel(group, anchors.map((anchor) => ({ cameraUtcUs: parseConfirmedDate(anchor.cameraTime), fitUtcUs: parseConfirmedDate(anchor.activityTime) })))]));
}
function applyConfirmedCaptureTimes(mediaById, confirmed) {
  const result = structuredClone(mediaById);
  for (const [id, date] of Object.entries(confirmed)) {
    const instant = parseConfirmedDate(date);
    if (!Object.hasOwn(result, id)) continue;
    Object.assign(result[id], { captureStartUtcUs: instant, captureConfidence: 'locked', captureEvidenceSources: ['user-confirmed'] });
  }
  return result;
}
async function contextForResolve(resolve) {
  const manager = await resolve.GetProjectManager();
  const project = await manager.GetCurrentProject();
  invariant(project, 'Open a Resolve project first.');
  const timeline = await project.GetCurrentTimeline();
  invariant(timeline, 'Open a Resolve timeline first.');
  const projectId = String(await project.GetUniqueId());
  const timelineId = String(await timeline.GetUniqueId());
  const contextId = crypto.createHash('sha256').update(JSON.stringify([projectId, timelineId])).digest('hex');
  return { project, timeline, contextId, timelineId };
}
class ConfigurationStore {
  constructor(directory) { this.directory = directory; }
  file(id) { invariant(/^[a-f0-9]{64}$/.test(id), 'Invalid configuration identity'); return path.join(this.directory, `${id}.json`); }
  async load(id) {
    try { const value = validateConfiguration(JSON.parse(await fs.readFile(this.file(id), 'utf8'))); invariant(value.contextId === id, 'Configuration identity mismatch'); return value; }
    catch (error) { if (error.code === 'ENOENT') return null; throw error; }
  }
  async save(value) {
    const normalized = validateConfiguration(value);
    await fs.mkdir(this.directory, { recursive: true, mode: 0o700 });
    const target = this.file(normalized.contextId);
    const temporary = `${target}.${crypto.randomUUID()}.tmp`;
    try { await fs.writeFile(temporary, `${JSON.stringify(normalized)}\n`, { mode: 0o600 }); await fs.rename(temporary, target); }
    finally { await fs.rm(temporary, { force: true }); }
    return normalized;
  }
}
module.exports = { parseConfirmedDate, validateConfiguration, cameraModels, applyConfirmedCaptureTimes, contextForResolve, ConfigurationStore };
