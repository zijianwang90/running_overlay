'use strict';

const { assertSafeInteger, roundRationalProduct } = require('../domain/validation');

function findSegment(syncMap, timelineFrame) {
  assertSafeInteger(timelineFrame, 'timelineFrame');
  const segments = syncMap.segments;
  let low = 0;
  let high = segments.length - 1;
  while (low <= high) {
    const middle = Math.floor((low + high) / 2);
    const segment = segments[middle];
    if (timelineFrame < segment.timelineStartFrame) {
      high = middle - 1;
    } else if (timelineFrame >= segment.timelineEndFrameExclusive) {
      low = middle + 1;
    } else {
      return segment;
    }
  }
  return null;
}

function activityElapsedUsAtFrame(syncMap, timelineFrame) {
  const segment = findSegment(syncMap, timelineFrame);
  if (!segment) return null;
  const deltaFrames = timelineFrame - segment.timelineStartFrame;
  return segment.activityStartUs + roundRationalProduct(deltaFrames, segment.activityUsPerTimelineFrame);
}

module.exports = {
  activityElapsedUsAtFrame,
  findSegment,
};
