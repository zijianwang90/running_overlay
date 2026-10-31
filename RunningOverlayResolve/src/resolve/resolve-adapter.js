'use strict';

const path = require('node:path');
const { exportTimelineInspection, inspectReferenceTrack, mappingIssueForItem, correctedSourceStartFrame } = require('./otio-inspection');
const { invariant, reduceRational } = require('../domain/validation');
const { filenameCaptureTime } = require('../sync/capture-time');

const NTSC_RATES = new Map([
  ['23.976', { numerator: 24_000, denominator: 1_001 }],
  ['29.97', { numerator: 30_000, denominator: 1_001 }],
  ['47.952', { numerator: 48_000, denominator: 1_001 }],
  ['59.94', { numerator: 60_000, denominator: 1_001 }],
  ['119.88', { numerator: 120_000, denominator: 1_001 }],
]);

function parseFrameRate(value) {
  const normalized = String(value ?? '').trim().replace(/\s+DF$/i, '');
  if (NTSC_RATES.has(normalized)) return NTSC_RATES.get(normalized);
  const numeric = Number(normalized);
  invariant(Number.isFinite(numeric) && numeric > 0, `Unsupported frame rate: ${value}`);
  if (Number.isInteger(numeric)) return { numerator: numeric, denominator: 1 };
  const denominator = 1_000_000;
  return reduceRational(Math.round(numeric * denominator), denominator);
}

function normalizeEndExclusive(startFrame, endFrame, durationFrames) {
  const start = Number(startFrame);
  const end = Number(endFrame);
  const duration = Number(durationFrames);
  invariant(Number.isSafeInteger(start) && Number.isSafeInteger(end), 'timeline item frame positions must be integers');
  if (Number.isSafeInteger(duration) && duration > 0) {
    if (end - start === duration) return end;
    if (end - start + 1 === duration) return end + 1;
    return start + duration;
  }
  invariant(end > start, 'timeline item end must follow start');
  return end;
}

function hasExplicitTimezone(value) {
  return /(?:Z|[+-]\d{2}:?\d{2})$/i.test(String(value).trim());
}

function captureCandidatesFromProperties(clipProperties, metadata) {
  const candidates = [];
  const sources = [
    { namespace: 'clipProperty', values: clipProperties },
    { namespace: 'metadata', values: metadata },
  ];

  for (const source of sources) {
    for (const [key, rawValue] of Object.entries(source.values ?? {})) {
      if (!/(date.*created|creation.*date|date.*recorded|record.*date|capture.*date)/i.test(key)) continue;
      const value = String(rawValue ?? '').trim();
      if (!value || !hasExplicitTimezone(value)) continue;
      const milliseconds = Date.parse(value);
      if (!Number.isFinite(milliseconds)) continue;
      candidates.push({
        instantUtcUs: milliseconds * 1_000,
        source: `${source.namespace}.${key}`,
        evidenceGroup: /record|capture/i.test(key) ? 'recording-date' : 'container-created',
        reliability: /record|capture/i.test(key) ? 'strong' : 'medium',
        recordingRole: /record|capture/i.test(key) ? 'start' : 'unknown',
        timezone: 'explicit',
        rawValue: value,
      });
    }
  }
  return candidates;
}

function cameraGroupFromProperties(clipProperties, name) {
  for (const key of ['Camera #', 'Camera Type', 'Reel Name', 'Reel']) {
    const value = String(clipProperties?.[key] ?? '').trim();
    if (value) return value;
  }
  const stem = path.basename(name ?? 'Camera', path.extname(name ?? ''));
  return stem.split(/[_\- .]+/)[0] || 'Camera';
}

function sourceFrameRateFromProperties(clipProperties) {
  for (const key of ['FPS', 'Frame Rate', 'Video Frame Rate']) {
    const raw = clipProperties?.[key];
    if (raw !== undefined && String(raw).trim() !== '') {
      try {
        return parseFrameRate(raw);
      } catch {
        // Continue to the documented timeline-rate fallback.
      }
    }
  }
  return null;
}

async function scanCurrentTimeline(resolve, options = {}) {
  invariant(resolve, 'Resolve connection is unavailable');
  const projectManager = await resolve.GetProjectManager();
  invariant(projectManager, 'Resolve project manager is unavailable');
  const project = await projectManager.GetCurrentProject();
  invariant(project, 'No Resolve project is open');
  const timeline = await project.GetCurrentTimeline();
  invariant(timeline, 'No Resolve timeline is active');

  const referenceVideoTrackIndex = Number(options.referenceVideoTrackIndex ?? 1);
  const trackCount = Number(await timeline.GetTrackCount('video'));
  invariant(Number.isSafeInteger(referenceVideoTrackIndex) && referenceVideoTrackIndex >= 1, 'reference track index must be positive');
  invariant(referenceVideoTrackIndex <= trackCount, `video track ${referenceVideoTrackIndex} does not exist`);

  const [timelineId, timelineName, timelineStartFrame, timelineEndFrame, rawTimelineFrameRate, trackName, trackEnabled, timelineItems] = await Promise.all([
    timeline.GetUniqueId(),
    timeline.GetName(),
    timeline.GetStartFrame(),
    timeline.GetEndFrame(),
    timeline.GetSetting('timelineFrameRate'),
    timeline.GetTrackName('video', referenceVideoTrackIndex),
    timeline.GetIsTrackEnabled('video', referenceVideoTrackIndex),
    timeline.GetItemListInTrack('video', referenceVideoTrackIndex),
  ]);
  const frameRate = parseFrameRate(rawTimelineFrameRate);
  // Lets the panel offer tracks by name and clip count instead of a bare index.
  const tracks = await Promise.all(Array.from({ length: trackCount }, async (_, offset) => {
    const index = offset + 1;
    const [name, trackItems] = await Promise.all([timeline.GetTrackName('video', index), timeline.GetItemListInTrack('video', index)]);
    return { index, name: String(name ?? `V${index}`), clipCount: Object.values(trackItems ?? {}).length };
  }));
  const otio = await (options.exportInspection ?? exportTimelineInspection)(timeline);
  const evidence = inspectReferenceTrack(otio, referenceVideoTrackIndex, Number(timelineStartFrame), frameRate);
  const mediaById = {};
  const diagnostics = [];

  const items = [];
  for (const item of timelineItems ?? []) {
    const [timelineItemId, name, start, end, duration, sourceStartFrame, mediaPoolItem, clipEnabled] = await Promise.all([
      item.GetUniqueId(),
      item.GetName(),
      item.GetStart(),
      item.GetEnd(),
      item.GetDuration(),
      item.GetSourceStartFrame(),
      item.GetMediaPoolItem(),
      item.GetClipEnabled(),
    ]);
    if (!mediaPoolItem) {
      diagnostics.push({ severity: clipEnabled === false ? 'info' : 'error', code: 'no-media-pool-item', timelineItemId, message: `${name} has no source MediaPoolItem.` });
      continue;
    }

    const [mediaId, clipProperties, metadata] = await Promise.all([
      mediaPoolItem.GetUniqueId(),
      mediaPoolItem.GetClipProperty(),
      mediaPoolItem.GetMetadata(),
    ]);
    const cameraGroupId = cameraGroupFromProperties(clipProperties, name);
    mediaById[mediaId] = {
      mediaId,
      name,
      cameraGroupId,
      filePath: clipProperties?.['File Path'] ?? null,
      clipProperties: clipProperties ?? {},
      metadata: metadata ?? {},
      captureTimeCandidates: captureCandidatesFromProperties(clipProperties, metadata),
      // Filename dates are wall-clock evidence only; timezone + confirmation
      // remain explicit panel choices before they become UTC authority.
      filenameCaptureTime: filenameCaptureTime(clipProperties?.['File Path'] || name),
    };
    const sourceFrameRate = sourceFrameRateFromProperties(clipProperties);
    const scannedItem = {
      timelineItemId,
      mediaId,
      name,
      cameraGroupId,
      timelineStartFrame: Number(start),
      timelineEndFrameExclusive: normalizeEndExclusive(start, end, duration),
      sourceStartFrame: Number(sourceStartFrame),
      sourceFrameRate: sourceFrameRate ?? frameRate,
      speed: { numerator: 1, denominator: 1 },
      clipEnabled: clipEnabled !== false,
    };
    if (sourceFrameRate) scannedItem.sourceStartFrame = correctedSourceStartFrame(evidence, scannedItem);
    scannedItem.mappingIssue = sourceFrameRate ? mappingIssueForItem(evidence, scannedItem, clipProperties?.['File Path']) : 'Source frame rate is missing or invalid; automatic fallback is not safe.';
    if (scannedItem.mappingIssue && scannedItem.clipEnabled) diagnostics.push({ severity: 'error', code: 'unsupported-source-mapping', timelineItemId, message: `${name}: ${scannedItem.mappingIssue}` });
    items.push(scannedItem);
  }

  return {
    timeline: {
      schemaVersion: 1,
      timelineId: String(timelineId),
      timelineName: String(timelineName),
      timelineStartFrame: Number(timelineStartFrame),
      timelineEndFrame: Math.max(Number(timelineStartFrame), ...items.map((item) => item.timelineEndFrameExclusive)),
      frameRate,
      referenceVideoTrackIndex,
      referenceVideoTrackName: String(trackName),
      referenceVideoTrackEnabled: trackEnabled !== false,
      items,
    },
    tracks,
    mediaById,
    diagnostics,
  };
}

module.exports = {
  cameraGroupFromProperties,
  captureCandidatesFromProperties,
  normalizeEndExclusive,
  parseFrameRate,
  scanCurrentTimeline,
  sourceFrameRateFromProperties,
};
