'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const { validateActivity } = require('../domain/activity');
const { invariant } = require('../domain/validation');

const ACTIVITY_COLUMNS = [
  'elapsedUs',
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
  'latitude_deg',
  'longitude_deg',
  'route_segment',
];

const ROUTE_COLUMN_FIELDS = {
  latitude_deg: 'latitude',
  longitude_deg: 'longitude',
  route_segment: 'routeSegment',
};

function encodeCell(value) {
  if (value === null || value === undefined) return '';
  invariant(typeof value === 'number' && Number.isFinite(value), 'render-data cells must be finite numbers');
  return String(value);
}

function serializeActivityRenderData(activity) {
  validateActivity(activity);
  const lines = [
    'ROACTIVITY\t1',
    `activityId\t${activity.activityId}`,
    `startUtcUs\t${activity.startUtcUs}`,
    `endUtcUs\t${activity.endUtcUs}`,
    `columns\t${ACTIVITY_COLUMNS.join('\t')}`,
  ];
  for (const record of activity.records) {
    lines.push(`record\t${ACTIVITY_COLUMNS.map((column) => encodeCell(record[ROUTE_COLUMN_FIELDS[column] ?? column])).join('\t')}`);
  }
  for (const annotation of activity.annotations ?? []) {
    lines.push(`annotation\t${annotation.kind}\t${annotation.startElapsedUs}\t${annotation.endElapsedUs}`);
  }
  return `${lines.join('\n')}\n`;
}

function serializeSyncRenderData(syncMap) {
  invariant(syncMap.schemaVersion === 1, 'syncMap.schemaVersion must be 1');
  const lines = [
    'ROSYNC\t1',
    `activityId\t${syncMap.activityId}`,
    `timelineId\t${syncMap.timelineId}`,
    `timelineStartFrame\t${syncMap.timelineStartFrame}`,
    `timelineEndFrame\t${syncMap.timelineEndFrame}`,
    `frameRate\t${syncMap.frameRate.numerator}\t${syncMap.frameRate.denominator}`,
    `timelineFingerprint\t${syncMap.timelineFingerprint}`,
    'columns\ttimelineStartFrame\ttimelineEndFrameExclusive\tactivityStartUs\trateNumerator\trateDenominator',
  ];
  for (const segment of syncMap.segments) {
    lines.push([
      'segment',
      segment.timelineStartFrame,
      segment.timelineEndFrameExclusive,
      segment.activityStartUs,
      segment.activityUsPerTimelineFrame.numerator,
      segment.activityUsPerTimelineFrame.denominator,
    ].join('\t'));
  }
  return `${lines.join('\n')}\n`;
}

function parseTabLines(text) {
  return text
    .split(/\r?\n/)
    .filter((line) => line.length > 0)
    .map((line) => line.split('\t'));
}

function parseActivityRenderData(text) {
  const lines = parseTabLines(text);
  invariant(lines[0]?.[0] === 'ROACTIVITY' && lines[0]?.[1] === '1', 'unsupported activity render-data version');
  const activityId = lines.find((line) => line[0] === 'activityId')?.[1];
  const startUtcUs = Number(lines.find((line) => line[0] === 'startUtcUs')?.[1]);
  const endUtcUs = Number(lines.find((line) => line[0] === 'endUtcUs')?.[1]);
  const columns = lines.find((line) => line[0] === 'columns')?.slice(1) ?? [];
  const records = lines.filter((line) => line[0] === 'record').map((line) => {
    const record = {};
    for (let index = 0; index < columns.length; index += 1) {
      const column = columns[index];
      const field = ROUTE_COLUMN_FIELDS[column] ?? column;
      const cell = line[index + 1];
      if (ROUTE_COLUMN_FIELDS[column] && (cell === '' || cell === undefined)) continue;
      record[field] = cell === '' ? null : Number(cell);
    }
    return record;
  });
  const annotations = lines.filter((line) => line[0] === 'annotation').map((line) => ({
    kind: line[1],
    startElapsedUs: Number(line[2]),
    endElapsedUs: Number(line[3]),
  }));
  return validateActivity({ schemaVersion: 1, activityId, startUtcUs, endUtcUs, records, annotations });
}

function parseSyncRenderData(text) {
  const lines = parseTabLines(text);
  invariant(lines[0]?.[0] === 'ROSYNC' && lines[0]?.[1] === '1', 'unsupported sync render-data version');
  const value = (key) => lines.find((line) => line[0] === key)?.slice(1);
  const frameRate = value('frameRate');
  return {
    schemaVersion: 1,
    activityId: value('activityId')?.[0],
    timelineId: value('timelineId')?.[0],
    timelineStartFrame: Number(value('timelineStartFrame')?.[0]),
    timelineEndFrame: Number(value('timelineEndFrame')?.[0]),
    frameRate: { numerator: Number(frameRate?.[0]), denominator: Number(frameRate?.[1]) },
    timelineFingerprint: value('timelineFingerprint')?.[0],
    segments: lines.filter((line) => line[0] === 'segment').map((line, index) => ({
      segmentId: `render-segment-${index}`,
      timelineStartFrame: Number(line[1]),
      timelineEndFrameExclusive: Number(line[2]),
      activityStartUs: Number(line[3]),
      activityUsPerTimelineFrame: { numerator: Number(line[4]), denominator: Number(line[5]) },
    })),
  };
}

async function writeResolveBundle(outputDirectory, activity, syncMap) {
  validateActivity(activity);
  invariant(syncMap.activityId === activity.activityId, 'sync map and activity IDs do not match');
  const safeId = activity.activityId.replace(/[^a-zA-Z0-9._-]+/g, '-');
  const bundleDirectory = path.join(outputDirectory, `${safeId}.roresolve`);
  await fs.mkdir(bundleDirectory, { recursive: true });

  const manifest = {
    schemaVersion: 1,
    product: 'Running Overlay Resolve',
    activityId: activity.activityId,
    timelineId: syncMap.timelineId,
    timelineFingerprint: syncMap.timelineFingerprint,
    activityJson: 'activity.json',
    syncMapJson: 'sync-map.json',
    activityRenderData: 'activity.roactivity',
    syncRenderData: 'sync.rosync',
  };

  await Promise.all([
    fs.writeFile(path.join(bundleDirectory, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8'),
    fs.writeFile(path.join(bundleDirectory, 'activity.json'), `${JSON.stringify(activity, null, 2)}\n`, 'utf8'),
    fs.writeFile(path.join(bundleDirectory, 'sync-map.json'), `${JSON.stringify(syncMap, null, 2)}\n`, 'utf8'),
    fs.writeFile(path.join(bundleDirectory, 'activity.roactivity'), serializeActivityRenderData(activity), 'utf8'),
    fs.writeFile(path.join(bundleDirectory, 'sync.rosync'), serializeSyncRenderData(syncMap), 'utf8'),
  ]);
  return bundleDirectory;
}

module.exports = {
  ACTIVITY_COLUMNS,
  parseActivityRenderData,
  parseSyncRenderData,
  serializeActivityRenderData,
  serializeSyncRenderData,
  writeResolveBundle,
};
