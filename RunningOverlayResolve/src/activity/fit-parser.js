'use strict';

const path = require('node:path');
const { invariant } = require('../domain/validation');
const { validateActivity } = require('../domain/activity');

const FIT_TO_UNIX_SECONDS = 631_065_600;

class FitReader {
  constructor(buffer) {
    invariant(Buffer.isBuffer(buffer), 'FIT input must be a Buffer');
    this.buffer = buffer;
    this.offset = 0;
    this.dataEnd = 0;
    this.definitions = new Map();
    this.records = [];
    this.timerEvents = [];
    this.laps = [];
    this.sessionStartFitSeconds = null;
    this.sessionElapsedUs = null;
    this.previousTimestampFitSeconds = null;
  }

  parse(options = {}) {
    this.readHeader();
    while (this.offset < this.dataEnd) this.readMessage();

    const recordStarts = this.records.map((record) => record.timestampFitSeconds);
    const startFitSeconds = this.sessionStartFitSeconds ?? Math.min(...recordStarts);
    invariant(Number.isFinite(startFitSeconds), 'FIT file has no activity timestamp');
    const startUtcUs = (startFitSeconds + FIT_TO_UNIX_SECONDS) * 1_000_000;
    const records = this.records
      .map((record) => ({
        elapsedUs: (record.timestampFitSeconds - startFitSeconds) * 1_000_000,
        latitude: record.latitude,
        longitude: record.longitude,
        distanceMeters: record.distanceMeters,
        heartRateBpm: record.heartRateBpm,
        paceSecondsPerKilometer: record.paceSecondsPerKilometer,
        cadenceSpm: record.cadenceSpm,
        elevationMeters: record.elevationMeters,
        powerWatts: record.powerWatts,
        calories: record.calories,
        verticalOscillationMm: record.verticalOscillationMm,
        groundContactTimeMs: record.groundContactTimeMs,
        strideLengthMeters: record.strideLengthMeters,
        groundContactBalanceLeftPercent: record.groundContactBalanceLeftPercent,
        temperatureCelsius: record.temperatureCelsius,
        gradePercent: record.gradePercent,
      }))
      .sort((left, right) => left.elapsedUs - right.elapsedUs);
    // A missing/invalid pair ends the route run, even if numeric metrics continue.
    let routeSegment = -1;
    let previousHasPosition = false;
    for (const record of records) {
      const hasPosition = record.latitude !== null && record.longitude !== null;
      if (hasPosition) {
        if (!previousHasPosition) routeSegment++;
        record.routeSegment = routeSegment;
      } else {
        delete record.latitude;
        delete record.longitude;
      }
      previousHasPosition = hasPosition;
    }
    invariant(records.every((record) => record.elapsedUs >= 0), 'FIT records precede the session start');

    if (records.length === 0) {
      records.push({ elapsedUs: 0 });
    }
    const lastRecordElapsedUs = records[records.length - 1].elapsedUs;
    const lastTimerEventElapsedUs = this.timerEvents.reduce((latest, event) => Math.max(latest,
      (event.timestampFitSeconds - startFitSeconds) * 1_000_000), 0);
    const durationUs = Math.max(this.sessionElapsedUs ?? 0, lastRecordElapsedUs, lastTimerEventElapsedUs);
    const endUtcUs = startUtcUs + durationUs;
    const activityId = options.activityId
      ?? `fit-${startFitSeconds}`;

    return validateActivity({
      schemaVersion: 1,
      activityId,
      startUtcUs,
      endUtcUs,
      records,
      annotations: this.buildPauseAnnotations(startFitSeconds, durationUs),
      laps: this.buildLaps(startFitSeconds, durationUs, records),
    });
  }

  readHeader() {
    invariant(this.buffer.length >= 12, 'FIT file is shorter than its minimum header');
    const headerSize = this.buffer[0];
    invariant(headerSize === 12 || headerSize === 14, `Unsupported FIT header size ${headerSize}`);
    invariant(this.buffer.length >= headerSize, 'FIT header is truncated');
    invariant(this.buffer.subarray(8, 12).toString('ascii') === '.FIT', 'FIT signature is missing');
    const dataSize = this.buffer.readUInt32LE(4);
    this.offset = headerSize;
    this.dataEnd = headerSize + dataSize;
    invariant(this.dataEnd <= this.buffer.length, 'FIT data section exceeds the file length');
  }

  readMessage() {
    const header = this.readUInt8();
    if ((header & 0x80) !== 0) {
      const localMessageType = (header >> 5) & 0x03;
      const offset = header & 0x1f;
      invariant(this.previousTimestampFitSeconds !== null, 'Compressed FIT timestamp has no preceding full timestamp');
      const base = Math.floor(this.previousTimestampFitSeconds / 32) * 32;
      const timestamp = base + offset + (offset < (this.previousTimestampFitSeconds % 32) ? 32 : 0);
      invariant(timestamp <= 0xffffffff, 'Compressed FIT timestamp exceeds the FIT range');
      this.readData(localMessageType, timestamp);
      return;
    }
    const localMessageType = header & 0x0f;
    if ((header & 0x40) !== 0) {
      this.readDefinition(localMessageType, (header & 0x20) !== 0);
    } else {
      this.readData(localMessageType);
    }
  }

  readDefinition(localMessageType, hasDeveloperFields) {
    this.readUInt8();
    const architecture = this.readUInt8() === 0 ? 'little' : 'big';
    const globalMessageNumber = this.readUInt16(architecture);
    const fieldCount = this.readUInt8();
    const fields = [];
    for (let index = 0; index < fieldCount; index += 1) {
      fields.push({
        number: this.readUInt8(),
        size: this.readUInt8(),
        baseType: this.readUInt8(),
      });
    }
    const developerFields = [];
    if (hasDeveloperFields) {
      const developerFieldCount = this.readUInt8();
      for (let index = 0; index < developerFieldCount; index += 1) {
        developerFields.push({
          number: this.readUInt8(),
          size: this.readUInt8(),
          developerDataIndex: this.readUInt8(),
        });
      }
    }
    this.definitions.set(localMessageType, { architecture, globalMessageNumber, fields, developerFields });
  }

  readData(localMessageType, compressedTimestamp = null) {
    const definition = this.definitions.get(localMessageType);
    invariant(definition, `FIT local message ${localMessageType} has no definition`);
    const values = new Map();
    for (const field of definition.fields) {
      if (compressedTimestamp !== null && field.number === 253) {
        invariant(field.size === 4 && field.baseType === 0x86, 'Compressed FIT timestamp field has an unsupported definition');
        continue; // Timestamp is encoded in the header, not the data payload.
      }
      values.set(field.number, this.readBytes(field.size));
    }
    for (const field of definition.developerFields) this.readBytes(field.size);

    const fullTimestamp = this.uint32(values.get(253), definition.architecture);
    if (compressedTimestamp !== null) this.previousTimestampFitSeconds = compressedTimestamp;
    else if (fullTimestamp !== null) this.previousTimestampFitSeconds = fullTimestamp;

    if (definition.globalMessageNumber === 20) this.readRecord(values, definition.architecture, compressedTimestamp);
    else if (definition.globalMessageNumber === 18) this.readSession(values, definition.architecture);
    else if (definition.globalMessageNumber === 19) this.readLap(values, definition.architecture, compressedTimestamp);
    else if (definition.globalMessageNumber === 21) this.readEvent(values, definition.architecture, compressedTimestamp);
  }

  readRecord(values, architecture, compressedTimestamp = null) {
    const timestamp = compressedTimestamp ?? this.uint32(values.get(253), architecture);
    if (timestamp === null) return;
    const latitudeRaw = this.sint32(values.get(0), architecture);
    const longitudeRaw = this.sint32(values.get(1), architecture);
    const latitude = latitudeRaw === null ? null : latitudeRaw * 180 / 2 ** 31;
    const longitude = longitudeRaw === null ? null : longitudeRaw * 180 / 2 ** 31;
    const hasPosition = latitude !== null && longitude !== null && Math.abs(latitude) <= 90;
    const distanceRaw = this.uint32(values.get(5), architecture);
    const enhancedSpeedRaw = this.uint32(values.get(73), architecture);
    const speedRaw = this.uint16(values.get(6), architecture);
    const speedMetersPerSecond = enhancedSpeedRaw !== null
      ? enhancedSpeedRaw / 1_000
      : speedRaw !== null ? speedRaw / 1_000 : null;
    const enhancedAltitudeRaw = this.uint32(values.get(78), architecture);
    const altitudeRaw = this.uint16(values.get(2), architecture);
    const cadence = this.uint8(values.get(4));
    const cadenceFraction = this.uint8(values.get(53));
    const oscillationRaw = this.uint16(values.get(39), architecture);
    const contactTimeRaw = this.uint16(values.get(41), architecture);
    const strideRaw = this.uint16(values.get(84), architecture);
    const balanceRaw = this.uint8(values.get(30));
    const gradeRaw = this.sint16(values.get(9), architecture);

    this.records.push({
      timestampFitSeconds: timestamp,
      latitude: hasPosition ? latitude : null,
      longitude: hasPosition ? longitude : null,
      distanceMeters: distanceRaw === null ? null : distanceRaw / 100,
      heartRateBpm: this.uint8(values.get(3)),
      paceSecondsPerKilometer: speedMetersPerSecond && speedMetersPerSecond > 0
        ? 1_000 / speedMetersPerSecond
        : null,
      cadenceSpm: cadence === null ? null : Math.round((cadence + (cadenceFraction ?? 0) / 128) * 2),
      elevationMeters: enhancedAltitudeRaw !== null
        ? enhancedAltitudeRaw / 5 - 500
        : altitudeRaw !== null ? altitudeRaw / 5 - 500 : null,
      powerWatts: this.uint16(values.get(7), architecture),
      calories: this.uint16(values.get(33), architecture),
      verticalOscillationMm: oscillationRaw === null ? null : oscillationRaw / 10,
      groundContactTimeMs: contactTimeRaw === null ? null : contactTimeRaw / 10,
      strideLengthMeters: strideRaw === null ? null : strideRaw / 10_000,
      // Bit 7 marks a right-side percentage; normalize to the left side.
      groundContactBalanceLeftPercent: balanceRaw === null ? null
        : balanceRaw & 0x80 ? 100 - (balanceRaw & 0x7f) : balanceRaw & 0x7f,
      temperatureCelsius: this.sint8(values.get(13)),
      gradePercent: gradeRaw === null ? null : gradeRaw / 100,
    });
  }

  readSession(values, architecture) {
    const start = this.uint32(values.get(2), architecture);
    const elapsedMilliseconds = this.uint32(values.get(7), architecture);
    if (start !== null) this.sessionStartFitSeconds = start;
    if (elapsedMilliseconds !== null) this.sessionElapsedUs = elapsedMilliseconds * 1_000;
  }

  readEvent(values, architecture, compressedTimestamp = null) {
    const timestamp = compressedTimestamp ?? this.uint32(values.get(253), architecture);
    const event = this.uint8(values.get(0));
    const eventType = this.uint8(values.get(1));
    if (timestamp === null || event !== 0 || eventType === null) return;
    if (eventType === 0) this.timerEvents.push({ timestampFitSeconds: timestamp, type: 'start' });
    else if (eventType === 1 || eventType === 4) this.timerEvents.push({ timestampFitSeconds: timestamp, type: 'stop' });
  }

  readLap(values, architecture, compressedTimestamp = null) {
    const end = compressedTimestamp ?? this.uint32(values.get(253), architecture);
    if (end === null) return;
    const start = this.uint32(values.get(2), architecture);
    const distance = this.uint32(values.get(9), architecture);
    this.laps.push({
      startFitSeconds: start,
      endFitSeconds: end,
      distanceMeters: distance === null ? null : distance / 100,
    });
  }

  buildLaps(startFitSeconds, durationUs, records) {
    if (this.laps.length === 0) return undefined;
    const distanceAt = (elapsedUs) => {
      let before = null;
      let after = null;
      for (const record of records) {
        if (record.distanceMeters === null || record.distanceMeters === undefined) continue;
        if (record.elapsedUs <= elapsedUs) before = record;
        else { after = record; break; }
      }
      if (before && after && after.elapsedUs > before.elapsedUs) {
        const progress = (elapsedUs - before.elapsedUs) / (after.elapsedUs - before.elapsedUs);
        return before.distanceMeters + (after.distanceMeters - before.distanceMeters) * progress;
      }
      return before?.distanceMeters ?? after?.distanceMeters ?? null;
    };
    let previousEnd = startFitSeconds;
    const laps = [];
    for (const lap of [...this.laps].sort((left, right) => left.endFitSeconds - right.endFitSeconds)) {
      const start = lap.startFitSeconds ?? previousEnd;
      previousEnd = lap.endFitSeconds;
      const startElapsedUs = Math.max(0, Math.min(durationUs, (start - startFitSeconds) * 1_000_000));
      const startDistanceMeters = distanceAt(startElapsedUs);
      if (startDistanceMeters === null) continue;
      laps.push({ startElapsedUs, startDistanceMeters });
    }
    // Consecutive duplicate boundaries add no information.
    return laps.filter((lap, index) => index === 0 || lap.startElapsedUs > laps[index - 1].startElapsedUs);
  }

  buildPauseAnnotations(startFitSeconds, durationUs) {
    const events = [...this.timerEvents].sort((left, right) => left.timestampFitSeconds - right.timestampFitSeconds);
    const annotations = [];
    let pauseStartUs = null;
    for (const event of events) {
      const elapsedUs = Math.max(0, Math.min(durationUs, (event.timestampFitSeconds - startFitSeconds) * 1_000_000));
      if (event.type === 'stop' && pauseStartUs === null) pauseStartUs = elapsedUs;
      if (event.type === 'start' && pauseStartUs !== null) {
        if (elapsedUs > pauseStartUs) annotations.push({ kind: 'timerPaused', startElapsedUs: pauseStartUs, endElapsedUs: elapsedUs });
        pauseStartUs = null;
      }
    }
    if (pauseStartUs !== null && durationUs > pauseStartUs) {
      annotations.push({ kind: 'timerPaused', startElapsedUs: pauseStartUs, endElapsedUs: durationUs });
    }
    return annotations;
  }

  readUInt8() {
    invariant(this.offset < this.dataEnd, 'Unexpected end of FIT data');
    const value = this.buffer[this.offset];
    this.offset += 1;
    return value;
  }

  readUInt16(architecture) {
    const bytes = this.readBytes(2);
    return architecture === 'little' ? bytes.readUInt16LE(0) : bytes.readUInt16BE(0);
  }

  readBytes(size) {
    invariant(this.offset + size <= this.dataEnd, `FIT field at ${this.offset} exceeds the data section`);
    const bytes = this.buffer.subarray(this.offset, this.offset + size);
    this.offset += size;
    return bytes;
  }

  uint8(bytes) {
    if (!bytes || bytes.length < 1 || bytes[0] === 0xff) return null;
    return bytes[0];
  }

  sint8(bytes) {
    if (!bytes || bytes.length < 1 || bytes[0] === 0x7f) return null;
    return bytes.readInt8(0);
  }

  sint16(bytes, architecture) {
    if (!bytes || bytes.length < 2) return null;
    const value = architecture === 'little' ? bytes.readInt16LE(0) : bytes.readInt16BE(0);
    return value === 0x7fff ? null : value;
  }

  uint16(bytes, architecture) {
    if (!bytes || bytes.length < 2) return null;
    const value = architecture === 'little' ? bytes.readUInt16LE(0) : bytes.readUInt16BE(0);
    return value === 0xffff ? null : value;
  }

  sint32(bytes, architecture) {
    if (!bytes || bytes.length < 4) return null;
    const value = architecture === 'little' ? bytes.readInt32LE(0) : bytes.readInt32BE(0);
    return value === 0x7fffffff ? null : value;
  }

  uint32(bytes, architecture) {
    if (!bytes || bytes.length < 4) return null;
    const value = architecture === 'little' ? bytes.readUInt32LE(0) : bytes.readUInt32BE(0);
    return value === 0xffffffff ? null : value;
  }
}

function parseFitBuffer(buffer, options = {}) {
  return new FitReader(buffer).parse(options);
}

function activityIdFromPath(filePath) {
  const stem = path.basename(filePath, path.extname(filePath)).replace(/[^a-zA-Z0-9._-]+/g, '-');
  return stem || 'fit-activity';
}

module.exports = {
  FIT_TO_UNIX_SECONDS,
  activityIdFromPath,
  parseFitBuffer,
};
