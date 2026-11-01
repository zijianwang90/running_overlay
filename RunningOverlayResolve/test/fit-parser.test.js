'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { FIT_TO_UNIX_SECONDS, parseFitBuffer } = require('../src/activity/fit-parser');
const { sampleActivity } = require('../src/domain/activity');

function uint16(value) {
  const buffer = Buffer.alloc(2);
  buffer.writeUInt16LE(value);
  return buffer;
}

function uint32(value) {
  const buffer = Buffer.alloc(4);
  buffer.writeUInt32LE(value);
  return buffer;
}

function definition(localMessageType, globalMessageNumber, fields) {
  return Buffer.concat([
    Buffer.from([0x40 | localMessageType, 0, 0]),
    uint16(globalMessageNumber),
    Buffer.from([fields.length]),
    ...fields.map((field) => Buffer.from([field.number, field.size, field.baseType])),
  ]);
}

function record(localMessageType, fields) {
  return Buffer.concat([Buffer.from([localMessageType]), ...fields]);
}

function syntheticFit() {
  const startUnixSeconds = 1_767_254_400;
  const startFitSeconds = startUnixSeconds - FIT_TO_UNIX_SECONDS;
  const recordFields = [
    { number: 253, size: 4, baseType: 0x86 },
    { number: 5, size: 4, baseType: 0x86 },
    { number: 3, size: 1, baseType: 0x02 },
    { number: 6, size: 2, baseType: 0x84 },
    { number: 4, size: 1, baseType: 0x02 },
    { number: 2, size: 2, baseType: 0x84 },
    { number: 7, size: 2, baseType: 0x84 },
  ];
  const eventFields = [
    { number: 253, size: 4, baseType: 0x86 },
    { number: 0, size: 1, baseType: 0x02 },
    { number: 1, size: 1, baseType: 0x02 },
  ];
  const sessionFields = [
    { number: 2, size: 4, baseType: 0x86 },
    { number: 7, size: 4, baseType: 0x86 },
  ];
  const lapFields = [
    { number: 253, size: 4, baseType: 0x86 },
    { number: 2, size: 4, baseType: 0x86 },
    { number: 9, size: 4, baseType: 0x86 },
  ];
  const data = Buffer.concat([
    definition(0, 20, recordFields),
    record(0, [uint32(startFitSeconds), uint32(0), Buffer.from([120]), uint16(3_000), Buffer.from([80]), uint16(3_000), uint16(210)]),
    record(0, [uint32(startFitSeconds + 600), uint32(100_000), Buffer.from([150]), uint16(3_000), Buffer.from([88]), uint16(3_050), uint16(260)]),
    definition(1, 21, eventFields),
    record(1, [uint32(startFitSeconds + 300), Buffer.from([0]), Buffer.from([1])]),
    record(1, [uint32(startFitSeconds + 330), Buffer.from([0]), Buffer.from([0])]),
    definition(2, 18, sessionFields),
    record(2, [uint32(startFitSeconds), uint32(600_000)]),
    definition(3, 19, lapFields),
    record(3, [uint32(startFitSeconds + 300), uint32(startFitSeconds), uint32(50_000)]),
    record(3, [uint32(startFitSeconds + 600), uint32(startFitSeconds + 300), uint32(100_000)]),
  ]);
  const header = Buffer.alloc(14);
  header[0] = 14;
  header[1] = 0x20;
  header.writeUInt16LE(100, 2);
  header.writeUInt32LE(data.length, 4);
  header.write('.FIT', 8, 'ascii');
  return Buffer.concat([header, data]);
}

test('FIT GPS signed semicircles preserve zero, reject invalid pairs, and split route runs', () => {
  const start = 1_136_188_800;
  for (const architecture of ['little', 'big']) {
    const int32 = (value) => {
      const bytes = Buffer.alloc(4);
      if (architecture === 'little') bytes.writeInt32LE(value);
      else bytes.writeInt32BE(value);
      return bytes;
    };
    const timestamp = (value) => {
      const bytes = Buffer.alloc(4);
      if (architecture === 'little') bytes.writeUInt32LE(value);
      else bytes.writeUInt32BE(value);
      return bytes;
    };
    const fields = [{ number: 253, size: 4, baseType: 0x86 },
      { number: 0, size: 4, baseType: 0x85 }, { number: 1, size: 4, baseType: 0x85 }];
    const gpsDefinition = definition(0, 20, fields);
    if (architecture === 'big') { gpsDefinition[2] = 1; gpsDefinition.writeUInt16BE(20, 3); }
    const pairs = [[0, 0], [-(2 ** 29), 2 ** 30], [0x7fffffff, 0],
      [0, 0x7fffffff], [2 ** 30 + 1, 0], [0, -(2 ** 31)], [0, -(2 ** 30)]];
    const activity = parseFitBuffer(withHeader(Buffer.concat([gpsDefinition,
      ...pairs.map(([lat, lon], index) => record(0, [timestamp(start + index), int32(lat), int32(lon)])),
      // A later definition without GPS fields must also end the route run.
      definition(1, 20, [{ number: 253, size: 4, baseType: 0x86 }]),
      record(1, [uint32(start + 7)]),
    ])));
    assert.equal(activity.records[0].latitude, 0);
    assert.equal(activity.records[0].longitude, 0);
    assert.equal(activity.records[1].latitude, -45);
    assert.equal(activity.records[1].longitude, 90);
    assert.deepEqual(activity.records.map((entry) => entry.routeSegment), [0, 0, undefined, undefined, undefined, 1, 1, undefined]);
    for (const index of [2, 3, 4, 7]) {
      assert.equal(activity.records[index].latitude, undefined);
      assert.equal(activity.records[index].longitude, undefined);
    }
    assert.equal(activity.records[5].longitude, -180);
    for (const elapsedUs of [1_500_000, 2_500_000, 4_500_000, 6_500_000]) {
      assert.equal(sampleActivity(activity, elapsedUs).latitude, null);
      assert.equal(sampleActivity(activity, elapsedUs).longitude, null);
    }
  }
});

test('independent FIT parser produces portable activity records and real-time pauses', () => {
  const activity = parseFitBuffer(syntheticFit(), { activityId: 'synthetic-fit' });
  assert.equal(activity.startUtcUs, 1_767_254_400_000_000);
  assert.equal(activity.endUtcUs, 1_767_255_000_000_000);
  assert.equal(activity.records.length, 2);
  assert.equal(activity.records[1].elapsedUs, 600_000_000);
  assert.equal(activity.records[1].distanceMeters, 1_000);
  assert.equal(activity.records[1].heartRateBpm, 150);
  assert.equal(activity.records[1].cadenceSpm, 176);
  assert.equal(activity.records[1].elevationMeters, 110);
  assert.equal(Math.round(activity.records[1].paceSecondsPerKilometer), 333);
  assert.deepEqual(activity.annotations, [{
    kind: 'timerPaused',
    startElapsedUs: 300_000_000,
    endElapsedUs: 330_000_000,
  }]);
  assert.deepEqual(activity.laps, [
    { startElapsedUs: 0, startDistanceMeters: 0 },
    { startElapsedUs: 300_000_000, startDistanceMeters: 500 },
  ]);
});

function withHeader(data) {
  const header = Buffer.alloc(14);
  header[0] = 14;
  header[1] = 0x20;
  header.writeUInt16LE(100, 2);
  header.writeUInt32LE(data.length, 4);
  header.write('.FIT', 8, 'ascii');
  return Buffer.concat([header, data]);
}

test('compressed FIT timestamps reconstruct rollover, omitted timestamp fields, and timer pauses', () => {
  const start = 1_136_188_800; // 2026-01-01T08:00:00Z, divisible by 32.
  const fullRecord = [{ number: 253, size: 4, baseType: 0x86 }, { number: 3, size: 1, baseType: 0x02 }];
  const shortRecord = [{ number: 5, size: 4, baseType: 0x86 }, { number: 3, size: 1, baseType: 0x02 }];
  const eventFields = [{ number: 0, size: 1, baseType: 0x02 }, { number: 1, size: 1, baseType: 0x02 }];
  const sessionFields = [{ number: 2, size: 4, baseType: 0x86 }, { number: 7, size: 4, baseType: 0x86 }];
  const data = Buffer.concat([
    definition(0, 20, fullRecord),
    record(0, [uint32(start + 29), Buffer.from([120])]),
    Buffer.from([0x80 | 2, 130]), // 29 -> 34, wraps the 5-bit offset.
    definition(1, 20, shortRecord),
    Buffer.concat([Buffer.from([0x80 | (1 << 5) | 5]), uint32(500), Buffer.from([140])]),
    record(0, [uint32(start + 70), Buffer.from([150])]), // Full timestamp resets the reference.
    definition(2, 21, eventFields),
    Buffer.from([0x80 | (2 << 5) | 10, 0, 1]), // 70 -> 74, timer stop.
    Buffer.from([0x80 | (2 << 5) | 15, 0, 0]), // 74 -> 79, timer start.
    definition(3, 18, sessionFields),
    record(3, [uint32(start + 29), uint32(60_000)]),
  ]);
  const activity = parseFitBuffer(withHeader(data));
  assert.deepEqual(activity.records.map((entry) => entry.elapsedUs), [0, 5_000_000, 8_000_000, 41_000_000]);
  assert.deepEqual(activity.records.map((entry) => entry.heartRateBpm), [120, 130, 140, 150]);
  assert.equal(activity.records[2].distanceMeters, 5);
  assert.equal(activity.endUtcUs - activity.startUtcUs, 60_000_000);
  assert.deepEqual(activity.annotations, [{ kind: 'timerPaused', startElapsedUs: 45_000_000, endElapsedUs: 50_000_000 }]);
});

test('compressed FIT timestamp needs a full timestamp reference and a valid omitted field definition', () => {
  const fullRecord = [{ number: 253, size: 4, baseType: 0x86 }, { number: 3, size: 1, baseType: 0x02 }];
  const noReference = withHeader(Buffer.concat([definition(0, 20, fullRecord), Buffer.from([0x80, 120])]));
  assert.throws(() => parseFitBuffer(noReference), /preceding full timestamp/);
  const malformed = withHeader(Buffer.concat([
    definition(0, 20, fullRecord), record(0, [uint32(1_136_188_800), Buffer.from([120])]),
    definition(1, 20, [{ number: 253, size: 2, baseType: 0x84 }]), Buffer.from([0x80 | (1 << 5) | 1]),
  ]));
  assert.throws(() => parseFitBuffer(malformed), /unsupported definition/);
});

test('compressed FIT rollover remains unsigned beyond the 32-bit sign boundary', () => {
  const start = 0x8000001d;
  const fields = [{ number: 253, size: 4, baseType: 0x86 }, { number: 3, size: 1, baseType: 0x02 }];
  const data = Buffer.concat([
    definition(0, 20, fields), record(0, [uint32(start), Buffer.from([120])]),
    Buffer.from([0x80 | 2, 130]),
  ]);
  const activity = parseFitBuffer(withHeader(data));
  assert.deepEqual(activity.records.map((entry) => entry.elapsedUs), [0, 5_000_000]);
});

test('timer events after the final FIT record still preserve the paused interval', () => {
  const start = 1_136_188_800;
  const data = Buffer.concat([
    definition(0, 20, [{ number: 253, size: 4, baseType: 0x86 }]),
    record(0, [uint32(start)]),
    definition(1, 21, [{ number: 0, size: 1, baseType: 0x02 }, { number: 1, size: 1, baseType: 0x02 }]),
    Buffer.from([0x80 | (1 << 5) | 5, 0, 1]),
    Buffer.from([0x80 | (1 << 5) | 10, 0, 0]),
  ]);
  const activity = parseFitBuffer(withHeader(data));
  assert.equal(activity.endUtcUs - activity.startUtcUs, 10_000_000);
  assert.deepEqual(activity.annotations, [{ kind: 'timerPaused', startElapsedUs: 5_000_000, endElapsedUs: 10_000_000 }]);
});

test('FIT running dynamics, temperature and grade keep their units, signs and sentinels', () => {
  const start = 1_136_188_800;
  const fields = [
    { number: 253, size: 4, baseType: 0x86 }, { number: 39, size: 2, baseType: 0x84 },
    { number: 41, size: 2, baseType: 0x84 }, { number: 84, size: 2, baseType: 0x84 },
    { number: 30, size: 1, baseType: 0x02 }, { number: 13, size: 1, baseType: 0x01 },
    { number: 9, size: 2, baseType: 0x83 },
  ];
  const sint16 = (value) => { const buffer = Buffer.alloc(2); buffer.writeInt16LE(value); return buffer; };
  const data = Buffer.concat([
    definition(0, 20, fields),
    record(0, [uint32(start), uint16(853), uint16(2_455), uint16(12_340), Buffer.from([49]), Buffer.from([0xfb]), sint16(-250)]),
    // Bit 7 marks a right-side balance; 0x7f, 0x7fff and 0xffff are invalid.
    record(0, [uint32(start + 1), uint16(0xffff), uint16(0xffff), uint16(0xffff), Buffer.from([0x80 | 52]), Buffer.from([0x7f]), sint16(0x7fff)]),
  ]);
  const [first, second] = parseFitBuffer(withHeader(data)).records;
  assert.equal(first.verticalOscillationMm, 85.3);
  assert.equal(first.groundContactTimeMs, 245.5);
  assert.equal(first.strideLengthMeters, 1.234);
  assert.equal(first.groundContactBalanceLeftPercent, 49);
  assert.equal(first.temperatureCelsius, -5);
  assert.equal(first.gradePercent, -2.5);
  assert.equal(second.groundContactBalanceLeftPercent, 48);
  for (const field of ['verticalOscillationMm', 'groundContactTimeMs', 'strideLengthMeters', 'temperatureCelsius', 'gradePercent']) {
    assert.equal(second[field], null, field);
  }
});
