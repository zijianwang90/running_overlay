'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  captureCandidatesFromProperties,
  normalizeEndExclusive,
  parseFrameRate,
  scanCurrentTimeline,
} = require('../src/resolve/resolve-adapter');

function methodMap(values) {
  return Object.fromEntries(Object.entries(values).map(([name, value]) => [name, async (...args) => (
    typeof value === 'function' ? value(...args) : value
  )]));
}

test('Resolve frame-rate strings become authoritative rationals', () => {
  assert.deepEqual(parseFrameRate('29.97 DF'), { numerator: 30_000, denominator: 1_001 });
  assert.deepEqual(parseFrameRate('59.94'), { numerator: 60_000, denominator: 1_001 });
  assert.deepEqual(parseFrameRate('25'), { numerator: 25, denominator: 1 });
});

test('timeline end normalization detects inclusive and exclusive host conventions', () => {
  assert.equal(normalizeEndExclusive(100, 200, 100), 200);
  assert.equal(normalizeEndExclusive(100, 199, 100), 200);
  assert.equal(normalizeEndExclusive(100, 500, 96), 196);
});

test('only capture dates with an explicit timezone become automatic candidates', () => {
  const candidates = captureCandidatesFromProperties({
    'Date Created': '2026-01-01T08:05:10Z',
    'Date Recorded': '2026-01-01 08:05:10',
  }, {});
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].instantUtcUs, 1_767_254_710_000_000);
  assert.equal(candidates[0].evidenceGroup, 'container-created');
});

test('adapter scans a reference video track without mutating Resolve', async () => {
  const mediaPoolItem = methodMap({
    GetUniqueId: 'media-1',
    GetClipProperty: {
      'File Path': '/synthetic/PRO_VID_20260702_184703_00_009.mp4',
      'Date Created': '2026-01-01T08:05:10Z',
      FPS: '30',
      'Reel Name': 'Camera A',
    },
    GetMetadata: {},
  });
  const timelineItem = methodMap({
    GetUniqueId: 'item-1',
    GetName: 'Renamed timeline clip',
    GetStart: 100,
    GetEnd: 200,
    GetDuration: 100,
    GetSourceStartFrame: 360,
    GetMediaPoolItem: mediaPoolItem,
    GetClipEnabled: true,
  });
  const timeline = methodMap({
    GetUniqueId: 'timeline-1',
    GetName: 'Run Edit',
    GetStartFrame: 0,
    GetEndFrame: 1_000,
    GetSetting: (key) => key === 'timelineFrameRate' ? '29.97' : '',
    GetTrackCount: 1,
    GetTrackName: 'V1',
    GetIsTrackEnabled: true,
    GetItemListInTrack: [timelineItem],
  });
  const project = methodMap({ GetCurrentTimeline: timeline });
  const projectManager = methodMap({ GetCurrentProject: project });
  const resolve = methodMap({ GetProjectManager: projectManager });

  const { carrierTimeline } = require('../src/resolve/managed-overlay');
  const otio = carrierTimeline('/synthetic/PRO_VID_20260702_184703_00_009.mp4', 100, 30000 / 1001);
  const clip = otio.tracks.children[0].children[0];
  clip.source_range.start_time = { OTIO_SCHEMA: 'RationalTime.1', value: 360, rate: 30 };
  otio.tracks.children[0].children.unshift({ OTIO_SCHEMA: 'Gap.1', source_range: { duration: { value: 100, rate: 30000 / 1001 } } });
  const scan = await scanCurrentTimeline(resolve, { referenceVideoTrackIndex: 1, exportInspection: async () => otio });
  assert.equal(scan.timeline.timelineId, 'timeline-1');
  assert.equal(scan.timeline.items[0].timelineEndFrameExclusive, 200);
  assert.deepEqual(scan.timeline.items[0].sourceFrameRate, { numerator: 30, denominator: 1 });
  assert.equal(scan.mediaById['media-1'].captureTimeCandidates.length, 1);
  assert.equal(scan.mediaById['media-1'].filenameCaptureTime.hour, 18);
  assert.equal(scan.mediaById['media-1'].filenameCaptureTime.second, 3);
  assert.deepEqual(scan.diagnostics, []);
});
