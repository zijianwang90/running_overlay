'use strict';

const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { fileURLToPath } = require('node:url');
const { invariant } = require('../domain/validation');

// Resolve 21 SDK EXPORT_OTIO. Workflow remote objects expose methods, not constants.
const EXPORT_OTIO = 15;
const VISUAL_EFFECTS = new Set(['Transform', 'Source Transform', 'Immersive Transform', 'Cropping',
  'Source Cropping', 'Source Looks', 'Lens Correction', 'Dynamic Zoom', 'Composite', 'Video Faders', 'Immersive Output Transform']);
const schema = (object, name) => String(object?.OTIO_SCHEMA ?? '').startsWith(`${name}.`);
const seconds = (time) => {
  invariant(Number.isFinite(time?.value) && Number.isFinite(time?.rate) && time.rate > 0, 'Invalid OTIO time');
  return time.value / time.rate;
};
const filePath = (url) => url?.startsWith('file:') ? fileURLToPath(url) : url;

async function exportTimelineInspection(timeline) {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'running-overlay-scan-'));
  try {
    const destination = path.join(directory, 'timeline.otio');
    invariant(await timeline.Export(destination, EXPORT_OTIO), 'Resolve could not export timing evidence. Synchronization is blocked.');
    return JSON.parse(await fs.readFile(destination, 'utf8'));
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
}

function inspectReferenceTrack(otio, trackIndex, timelineStartFrame, frameRate) {
  invariant(schema(otio, 'Timeline'), 'Unsupported Resolve timeline export');
  const track = otio.tracks?.children?.filter((child) => child.kind === 'Video')[trackIndex - 1];
  invariant(track && schema(track, 'Track'), 'Reference track missing from Resolve timing evidence');
  const fps = frameRate.numerator / frameRate.denominator;
  invariant(Math.abs(seconds(otio.global_start_time) * fps - timelineStartFrame) < 0.01, 'Timeline start changed during scan');
  invariant(!track.source_range && !(track.effects?.length) && !(otio.tracks.effects?.length), 'Nested or affected reference tracks are not supported');
  let cursor = timelineStartFrame;
  return (track.children ?? []).map((child) => {
    const duration = seconds(child.source_range?.duration) * fps;
    invariant(Math.abs(duration - Math.round(duration)) < 0.01, 'Subframe reference edits are not supported');
    const start = cursor;
    cursor += Math.round(duration);
    if (schema(child, 'Gap')) return null;
    let issue = null;
    if (!schema(child, 'Clip')) issue = 'Compound, multicam, transition, or nested clips are not supported.';
    const reference = child.media_references?.[child.active_media_reference_key] ?? child.media_reference;
    if (!schema(reference, 'ExternalReference') || !reference.target_url) issue = 'The clip does not have an ordinary external media source.';
    for (const effect of child.effects ?? []) {
      const metadata = effect.metadata?.Resolve_OTIO;
      if (metadata?.Enabled === false) continue;
      // Resolve exports this default inspector section even on ordinary clips.
      if (schema(effect, 'Effect') && metadata?.['Effect Name'] === 'Retime and Scaling' && Array.isArray(metadata.Parameters) && metadata.Parameters.length === 0) continue;
      if (!schema(effect, 'Effect') || effect.effect_name !== 'Resolve Effect' || !VISUAL_EFFECTS.has(metadata?.['Effect Name'])) {
        issue = 'Retime, freeze, reverse, or an unverified clip effect is present. Use an ordinary-speed source clip.';
      }
    }
    const availableStart = reference?.available_range?.start_time;
    const sourceSeconds = seconds(child.source_range.start_time) - (availableStart ? seconds(availableStart) : 0);
    return { start, end: cursor, sourceSeconds, sourceQuantum: 1 / child.source_range.start_time.rate, path: filePath(reference?.target_url), enabled: child.enabled !== false, issue };
  }).filter(Boolean);
}

// Resolve 21 GetSourceStartFrame can truncate one frame low at fractional rates
// (1003 for 1004 at 29.97) while GetLeftOffset and the OTIO export stay correct.
function correctedSourceStartFrame(evidence, item) {
  const { numerator, denominator } = item.sourceFrameRate;
  const matches = evidence.filter((entry) => entry.start === item.timelineStartFrame && entry.end === item.timelineEndFrameExclusive);
  if (denominator === 1 || matches.length !== 1) return item.sourceStartFrame;
  const frames = matches[0].sourceSeconds * numerator / denominator;
  const nearest = Math.round(frames);
  return Math.abs(frames - nearest) < 0.000001 && nearest === item.sourceStartFrame + 1 ? nearest : item.sourceStartFrame;
}

function mappingIssueForItem(evidence, item, sourcePath) {
  const matches = evidence.filter((entry) => entry.start === item.timelineStartFrame && entry.end === item.timelineEndFrameExclusive);
  if (matches.length !== 1) return 'Clip geometry could not be matched to Resolve timing evidence. Rescan the timeline.';
  const entry = matches[0];
  if (entry.issue) return entry.issue;
  if (entry.path !== sourcePath || entry.enabled !== item.clipEnabled) return 'Source identity or enabled state changed during scanning.';
  const sourceSeconds = item.sourceStartFrame * item.sourceFrameRate.denominator / item.sourceFrameRate.numerator;
  // Resolve truncates OTIO source starts to integer timeline-rate frames when
  // source and timeline rates differ. The source API remains the frame authority.
  if (sourceSeconds < entry.sourceSeconds - 0.00001 || sourceSeconds >= entry.sourceSeconds + entry.sourceQuantum - 0.00000001) return 'Source trim disagrees with Resolve timing evidence.';
  return null;
}

module.exports = { exportTimelineInspection, inspectReferenceTrack, mappingIssueForItem, correctedSourceStartFrame };
