'use strict';

const crypto = require('node:crypto');
const { validateActivity } = require('../domain/activity');
const {
  assertNonEmptyString,
  assertRational,
  assertSafeInteger,
  invariant,
  reduceRational,
  roundRationalProduct,
} = require('../domain/validation');
const { rankCaptureTimeCandidates } = require('./capture-evidence');
const { identityClockModel, mapCameraUtcUs } = require('./clock-model');

function validateTimelineScan(timeline) {
  invariant(timeline && typeof timeline === 'object', 'timeline must be an object');
  invariant(timeline.schemaVersion === 1, 'timeline.schemaVersion must be 1');
  assertNonEmptyString(timeline.timelineId, 'timeline.timelineId');
  assertSafeInteger(timeline.timelineStartFrame, 'timeline.timelineStartFrame');
  assertSafeInteger(timeline.timelineEndFrame, 'timeline.timelineEndFrame');
  invariant(timeline.timelineEndFrame >= timeline.timelineStartFrame, 'timeline end must not precede start');
  assertRational(timeline.frameRate, 'timeline.frameRate');
  invariant(Array.isArray(timeline.items), 'timeline.items must be an array');

  for (const [index, item] of timeline.items.entries()) {
    assertNonEmptyString(item.timelineItemId, `timeline.items[${index}].timelineItemId`);
    assertNonEmptyString(item.mediaId, `timeline.items[${index}].mediaId`);
    assertNonEmptyString(item.cameraGroupId, `timeline.items[${index}].cameraGroupId`);
    assertSafeInteger(item.timelineStartFrame, `timeline.items[${index}].timelineStartFrame`);
    assertSafeInteger(item.timelineEndFrameExclusive, `timeline.items[${index}].timelineEndFrameExclusive`);
    assertSafeInteger(item.sourceStartFrame, `timeline.items[${index}].sourceStartFrame`);
    invariant(item.sourceStartFrame >= 0, 'source start must not be negative');
    invariant(item.timelineEndFrameExclusive > item.timelineStartFrame, 'timeline item duration must be positive');
    assertRational(item.sourceFrameRate, `timeline.items[${index}].sourceFrameRate`);
    if (item.speed !== undefined) assertRational(item.speed, `timeline.items[${index}].speed`);
  }
  return timeline;
}

function timelineFingerprint(timeline) {
  validateTimelineScan(timeline);
  const normalized = timeline.items
    .map((item) => ({
      timelineItemId: item.timelineItemId,
      mediaId: item.mediaId,
      cameraGroupId: item.cameraGroupId,
      timelineStartFrame: item.timelineStartFrame,
      timelineEndFrameExclusive: item.timelineEndFrameExclusive,
      sourceStartFrame: item.sourceStartFrame,
      sourceFrameRate: item.sourceFrameRate,
      speed: item.speed ?? { numerator: 1, denominator: 1 },
      clipEnabled: item.clipEnabled !== false,
      mappingIssue: item.mappingIssue ?? null,
    }))
    .sort((left, right) => left.timelineStartFrame - right.timelineStartFrame || left.timelineItemId.localeCompare(right.timelineItemId));
  return crypto.createHash('sha256').update(JSON.stringify({ timelineId: timeline.timelineId, start: timeline.timelineStartFrame, end: timeline.timelineEndFrame, frameRate: timeline.frameRate, track: timeline.referenceVideoTrackIndex, enabled: timeline.referenceVideoTrackEnabled !== false, items: normalized })).digest('hex');
}

function resolveCaptureStart(media, activity) {
  if (Number.isSafeInteger(media.captureStartUtcUs)) {
    return {
      instantUtcUs: media.captureStartUtcUs,
      confidence: media.captureConfidence ?? 'locked',
      evidenceSources: media.captureEvidenceSources ?? ['manual'],
      reason: media.captureReason ?? 'Explicit capture start supplied',
    };
  }

  const ranked = rankCaptureTimeCandidates(media.captureTimeCandidates ?? [], activity);
  if (!ranked.selected) return null;
  return {
    instantUtcUs: ranked.selected.instantUtcUs,
    confidence: ranked.confidence,
    evidenceSources: ranked.ranked
      .filter((candidate) => Math.abs(candidate.instantUtcUs - ranked.selected.instantUtcUs) <= 2_000_000)
      .map((candidate) => candidate.source),
    reason: ranked.reason,
  };
}

function compileSyncMap({ activity, timeline, mediaById, cameraClockModels = {}, includeReviewCandidates = false }) {
  validateActivity(activity);
  validateTimelineScan(timeline);
  invariant(mediaById && typeof mediaById === 'object', 'mediaById must be an object');

  const diagnostics = [];
  const segments = [];
  if (timeline.referenceVideoTrackEnabled === false) {
    return { schemaVersion: 1, activityId: activity.activityId, timelineId: timeline.timelineId, timelineStartFrame: timeline.timelineStartFrame, timelineEndFrame: timeline.timelineEndFrame, frameRate: timeline.frameRate, timelineFingerprint: timelineFingerprint(timeline), segments, diagnostics: [{ severity: 'error', code: 'disabled-reference-track', message: 'Enable the reference video track before synchronizing.' }] };
  }
  const sortedItems = [...timeline.items].sort(
    (left, right) => left.timelineStartFrame - right.timelineStartFrame || left.timelineItemId.localeCompare(right.timelineItemId),
  );

  let previousEndFrame = null;
  for (const item of sortedItems) {
    if (item.clipEnabled === false) continue;
    if (item.mappingIssue || (item.speed && item.speed.numerator !== item.speed.denominator)) {
      diagnostics.push({ severity: 'error', code: 'unsupported-source-mapping', timelineItemId: item.timelineItemId, message: item.mappingIssue || 'Only verified ordinary-speed clips are supported.' });
      continue;
    }
    if (previousEndFrame !== null && item.timelineStartFrame < previousEndFrame) {
      diagnostics.push({
        severity: 'error',
        code: 'overlapping-reference-items',
        timelineItemId: item.timelineItemId,
        message: 'Reference-track clips overlap; choose a non-overlapping track or split the sync region.',
      });
      continue;
    }
    previousEndFrame = item.timelineEndFrameExclusive;

    const media = mediaById[item.mediaId];
    if (!media) {
      diagnostics.push({
        severity: 'error',
        code: 'missing-media',
        timelineItemId: item.timelineItemId,
        message: `No media metadata exists for ${item.mediaId}.`,
      });
      continue;
    }

    const capture = resolveCaptureStart(media, activity);
    if (!capture || capture.confidence === 'low') {
      diagnostics.push({
        severity: 'warning',
        code: 'capture-time-unresolved',
        timelineItemId: item.timelineItemId,
        message: 'A manual sync anchor is required for this clip.',
      });
      continue;
    }
    if (capture.confidence === 'review' && !includeReviewCandidates) {
      diagnostics.push({
        severity: 'warning',
        code: 'capture-time-needs-review',
        timelineItemId: item.timelineItemId,
        message: 'Capture time is plausible but must be confirmed before use.',
      });
      continue;
    }

    const sourceOffsetRate = reduceRational(
      1_000_000 * item.sourceFrameRate.denominator,
      item.sourceFrameRate.numerator,
    );
    const sourceOffsetUs = roundRationalProduct(item.sourceStartFrame, sourceOffsetRate);
    const rawCameraUtcUs = capture.instantUtcUs + sourceOffsetUs;
    assertSafeInteger(rawCameraUtcUs, 'rawCameraUtcUs');
    const clockModel = cameraClockModels[item.cameraGroupId] ?? identityClockModel(item.cameraGroupId);
    const correctedUtcUs = mapCameraUtcUs(clockModel, rawCameraUtcUs);
    const activityStartUs = correctedUtcUs - activity.startUtcUs;
    assertSafeInteger(activityStartUs, 'activityStartUs');

    const speed = item.speed ?? { numerator: 1, denominator: 1 };
    const rateNumerator = 1_000_000 * timeline.frameRate.denominator * speed.numerator * clockModel.rate.numerator;
    const rateDenominator = timeline.frameRate.numerator * speed.denominator * clockModel.rate.denominator;
    invariant(Number.isSafeInteger(rateNumerator), 'segment rate numerator exceeds safe integer precision');
    invariant(Number.isSafeInteger(rateDenominator), 'segment rate denominator exceeds safe integer precision');
    const activityUsPerTimelineFrame = reduceRational(rateNumerator, rateDenominator);

    segments.push({
      segmentId: item.timelineItemId,
      mediaId: item.mediaId,
      cameraGroupId: item.cameraGroupId,
      timelineStartFrame: item.timelineStartFrame,
      timelineEndFrameExclusive: item.timelineEndFrameExclusive,
      sourceStartFrame: item.sourceStartFrame,
      activityStartUs,
      activityUsPerTimelineFrame,
      confidence: capture.confidence,
      evidenceSources: [...new Set(capture.evidenceSources)].sort(),
      clockModelSource: clockModel.source,
    });
  }

  return {
    schemaVersion: 1,
    activityId: activity.activityId,
    timelineId: timeline.timelineId,
    timelineStartFrame: timeline.timelineStartFrame,
    timelineEndFrame: timeline.timelineEndFrame,
    frameRate: timeline.frameRate,
    timelineFingerprint: timelineFingerprint(timeline),
    segments,
    diagnostics,
  };
}

module.exports = {
  compileSyncMap,
  timelineFingerprint,
  validateTimelineScan,
};
