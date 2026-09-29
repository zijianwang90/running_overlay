'use strict';

const {
  assertNonEmptyString,
  assertSafeInteger,
  invariant,
  reduceRational,
  roundRationalProduct,
} = require('../domain/validation');

function identityClockModel(cameraGroupId) {
  assertNonEmptyString(cameraGroupId, 'cameraGroupId');
  return {
    cameraGroupId,
    source: 'uncalibrated',
    referenceCameraUtcUs: 0,
    referenceFitUtcUs: 0,
    rate: { numerator: 1, denominator: 1 },
  };
}

function buildCameraClockModel(cameraGroupId, anchors, options = {}) {
  assertNonEmptyString(cameraGroupId, 'cameraGroupId');
  invariant(Array.isArray(anchors) && anchors.length > 0, 'at least one clock anchor is required');
  const ordered = [...anchors].sort((left, right) => left.cameraUtcUs - right.cameraUtcUs);
  for (const [index, anchor] of ordered.entries()) {
    assertSafeInteger(anchor.cameraUtcUs, `anchors[${index}].cameraUtcUs`);
    assertSafeInteger(anchor.fitUtcUs, `anchors[${index}].fitUtcUs`);
  }

  if (ordered.length === 1) {
    return {
      cameraGroupId,
      source: 'manual-one-point',
      referenceCameraUtcUs: ordered[0].cameraUtcUs,
      referenceFitUtcUs: ordered[0].fitUtcUs,
      rate: { numerator: 1, denominator: 1 },
    };
  }

  const first = ordered[0];
  const last = ordered[ordered.length - 1];
  const cameraDelta = last.cameraUtcUs - first.cameraUtcUs;
  const fitDelta = last.fitUtcUs - first.fitUtcUs;
  invariant(cameraDelta > 0 && fitDelta > 0, 'clock anchors must move forward in time');
  const rate = reduceRational(fitDelta, cameraDelta);
  const driftPpm = Math.abs((rate.numerator / rate.denominator - 1) * 1_000_000);
  const maximumDriftPpm = options.maximumDriftPpm ?? 5_000;
  invariant(driftPpm <= maximumDriftPpm, `clock drift ${driftPpm.toFixed(1)} ppm exceeds allowed ${maximumDriftPpm} ppm`);

  return {
    cameraGroupId,
    source: 'manual-two-point',
    referenceCameraUtcUs: first.cameraUtcUs,
    referenceFitUtcUs: first.fitUtcUs,
    rate,
  };
}

function mapCameraUtcUs(clockModel, cameraUtcUs) {
  assertSafeInteger(cameraUtcUs, 'cameraUtcUs');
  const delta = cameraUtcUs - clockModel.referenceCameraUtcUs;
  return clockModel.referenceFitUtcUs + roundRationalProduct(delta, clockModel.rate);
}

module.exports = {
  buildCameraClockModel,
  identityClockModel,
  mapCameraUtcUs,
};
