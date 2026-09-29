'use strict';

const { assertSafeInteger, invariant } = require('../domain/validation');

const RELIABILITY_SCORE = {
  strong: 70,
  medium: 45,
  weak: 10,
};

function rankCaptureTimeCandidates(candidates, activity, options = {}) {
  invariant(Array.isArray(candidates), 'capture-time candidates must be an array');
  assertSafeInteger(activity.startUtcUs, 'activity.startUtcUs');
  assertSafeInteger(activity.endUtcUs, 'activity.endUtcUs');

  const toleranceUs = options.toleranceUs ?? 30 * 60 * 1_000_000;
  const agreementUs = options.agreementUs ?? 2 * 1_000_000;
  const usable = candidates
    .filter((candidate) => Number.isSafeInteger(candidate.instantUtcUs))
    .map((candidate) => ({ ...candidate }));

  for (const candidate of usable) {
    let score = RELIABILITY_SCORE[candidate.reliability] ?? 0;
    if (candidate.recordingRole === 'start') score += 10;
    if (candidate.timezone === 'explicit') score += 10;
    if (
      candidate.instantUtcUs >= activity.startUtcUs - toleranceUs
      && candidate.instantUtcUs <= activity.endUtcUs + toleranceUs
    ) {
      score += 10;
    } else {
      score -= 40;
    }

    const agreeingSources = new Set(
      usable
        .filter((other) => Math.abs(other.instantUtcUs - candidate.instantUtcUs) <= agreementUs)
        .map((other) => other.evidenceGroup ?? other.source),
    );
    if (agreeingSources.size >= 2) score += 15;
    candidate.score = score;
    candidate.agreeingSourceCount = agreeingSources.size;
  }

  usable.sort((left, right) => right.score - left.score || left.instantUtcUs - right.instantUtcUs);
  const best = usable[0] ?? null;
  if (!best) {
    return { selected: null, confidence: 'low', reason: 'No absolute capture-time candidate' };
  }

  let confidence = 'low';
  if (best.score >= 90 && best.agreeingSourceCount >= 2) {
    confidence = 'high';
  } else if (best.score >= 55) {
    confidence = 'review';
  }

  return {
    selected: best,
    confidence,
    reason: confidence === 'high'
      ? `${best.agreeingSourceCount} independent time sources agree`
      : confidence === 'review'
        ? 'A plausible time exists but needs confirmation'
        : 'Available time evidence is too weak to apply automatically',
    ranked: usable,
  };
}

module.exports = {
  rankCaptureTimeCandidates,
};
