'use strict';

const {
  assertFiniteNumber,
  assertNonEmptyString,
  assertSafeInteger,
  invariant,
} = require('./validation');

const OPTIONAL_RECORD_FIELDS = [
  'distanceMeters',
  'heartRateBpm',
  'paceSecondsPerKilometer',
  'cadenceSpm',
  'elevationMeters',
  'powerWatts',
  'calories',
  'verticalOscillationMm',
  'groundContactTimeMs',
  'strideLengthMeters',
  'groundContactBalanceLeftPercent',
  'temperatureCelsius',
  'gradePercent',
];

function validateActivity(activity) {
  invariant(activity && typeof activity === 'object', 'activity must be an object');
  invariant(activity.schemaVersion === 1, 'activity.schemaVersion must be 1');
  assertNonEmptyString(activity.activityId, 'activity.activityId');
  assertSafeInteger(activity.startUtcUs, 'activity.startUtcUs');
  assertSafeInteger(activity.endUtcUs, 'activity.endUtcUs');
  invariant(activity.endUtcUs >= activity.startUtcUs, 'activity end must not precede start');
  invariant(Array.isArray(activity.records) && activity.records.length > 0, 'activity.records must not be empty');

  let previousElapsedUs = -1;
  for (const [index, record] of activity.records.entries()) {
    assertSafeInteger(record.elapsedUs, `activity.records[${index}].elapsedUs`);
    invariant(record.elapsedUs >= 0, `activity.records[${index}].elapsedUs must be non-negative`);
    invariant(record.elapsedUs >= previousElapsedUs, 'activity records must be ordered by elapsedUs');
    previousElapsedUs = record.elapsedUs;

    const hasLatitude = record.latitude !== null && record.latitude !== undefined;
    const hasLongitude = record.longitude !== null && record.longitude !== undefined;
    const hasSegment = record.routeSegment !== null && record.routeSegment !== undefined;
    invariant(hasLatitude === hasLongitude && hasLatitude === hasSegment,
      'route position requires paired latitude, longitude and routeSegment');
    if (hasLatitude) {
      assertFiniteNumber(record.latitude, `activity.records[${index}].latitude`);
      assertFiniteNumber(record.longitude, `activity.records[${index}].longitude`);
      invariant(Math.abs(record.latitude) <= 90, 'latitude must be within [-90, 90] degrees');
      invariant(Math.abs(record.longitude) <= 180, 'longitude must be within [-180, 180] degrees');
      assertSafeInteger(record.routeSegment, `activity.records[${index}].routeSegment`);
      invariant(record.routeSegment >= 0, 'routeSegment must be non-negative');
    }

    for (const field of OPTIONAL_RECORD_FIELDS) {
      if (record[field] !== null && record[field] !== undefined) {
        assertFiniteNumber(record[field], `activity.records[${index}].${field}`);
      }
    }
  }

  const durationUs = activity.endUtcUs - activity.startUtcUs;
  invariant(
    activity.records[activity.records.length - 1].elapsedUs <= durationUs,
    'last activity record lies after activity.endUtcUs',
  );

  if (activity.annotations !== undefined) {
    invariant(Array.isArray(activity.annotations), 'activity.annotations must be an array');
    for (const [index, annotation] of activity.annotations.entries()) {
      assertNonEmptyString(annotation.kind, `activity.annotations[${index}].kind`);
      assertSafeInteger(annotation.startElapsedUs, `activity.annotations[${index}].startElapsedUs`);
      assertSafeInteger(annotation.endElapsedUs, `activity.annotations[${index}].endElapsedUs`);
      invariant(annotation.endElapsedUs >= annotation.startElapsedUs, 'annotation end must not precede start');
    }
  }

  return activity;
}

function sampleActivity(activity, elapsedUs) {
  validateActivity(activity);
  assertSafeInteger(elapsedUs, 'elapsedUs');

  const records = activity.records;
  if (elapsedUs < records[0].elapsedUs || elapsedUs > records[records.length - 1].elapsedUs) {
    return null;
  }

  let low = 0;
  let high = records.length - 1;
  while (low <= high) {
    const middle = Math.floor((low + high) / 2);
    const current = records[middle];
    if (current.elapsedUs === elapsedUs) {
      return { ...current };
    }
    if (current.elapsedUs < elapsedUs) {
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }

  const left = records[Math.max(0, high)];
  const right = records[Math.min(records.length - 1, low)];
  if (left.elapsedUs === right.elapsedUs) {
    return { ...left };
  }

  const progress = (elapsedUs - left.elapsedUs) / (right.elapsedUs - left.elapsedUs);
  const sampled = { elapsedUs };
  for (const field of OPTIONAL_RECORD_FIELDS) {
    const leftValue = left[field];
    const rightValue = right[field];
    if (typeof leftValue === 'number' && typeof rightValue === 'number') {
      sampled[field] = leftValue + (rightValue - leftValue) * progress;
    } else {
      sampled[field] = null;
    }
  }
  // Coordinates are one position: never interpolate axes or segment IDs independently.
  sampled.latitude = null;
  sampled.longitude = null;
  sampled.routeSegment = null;
  if (typeof left.latitude === 'number' && typeof right.latitude === 'number'
    && left.routeSegment === right.routeSegment) {
    const longitudeDelta = ((right.longitude - left.longitude + 540) % 360) - 180;
    sampled.latitude = left.latitude + (right.latitude - left.latitude) * progress;
    sampled.longitude = ((left.longitude + longitudeDelta * progress + 540) % 360) - 180;
    sampled.routeSegment = left.routeSegment;
  }
  return sampled;
}

module.exports = {
  OPTIONAL_RECORD_FIELDS,
  sampleActivity,
  validateActivity,
};
