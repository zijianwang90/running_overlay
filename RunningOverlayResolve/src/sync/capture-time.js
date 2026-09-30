'use strict';

// Shared by the Node control plane and sandboxed panel; no host-local time parsing.
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.RunningOverlayTime = api;
})(globalThis, function () {
  const formatters = new Map();
  const pad = (value, length = 2) => String(value).padStart(length, '0');
  function wallMilliseconds(parts) {
    const date = new Date(0);
    date.setUTCFullYear(parts.year, parts.month - 1, parts.day);
    date.setUTCHours(parts.hour, parts.minute, parts.second, parts.millisecond ?? 0);
    const value = date.getTime();
    if (parts.year < 1 || parts.year > 9999 || date.getUTCFullYear() !== parts.year ||
        date.getUTCMonth() + 1 !== parts.month || date.getUTCDate() !== parts.day ||
        date.getUTCHours() !== parts.hour || date.getUTCMinutes() !== parts.minute ||
        date.getUTCSeconds() !== parts.second || date.getUTCMilliseconds() !== (parts.millisecond ?? 0)) {
      throw new Error('Choose a valid date and time.');
    }
    return value;
  }
  function filenameCaptureTime(name) {
    const basename = String(name ?? '').split(/[\\/]/).pop();
    const matches = [...basename.matchAll(/(?:^|[_-])(\d{4})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})(?=[_.-]|$)/g)];
    if (matches.length !== 1) return null;
    const [, year, month, day, hour, minute, second] = matches[0];
    const parts = { year: Number(year), month: Number(month), day: Number(day), hour: Number(hour), minute: Number(minute), second: Number(second), millisecond: 0 };
    if (parts.year < 1970) return null;
    try { wallMilliseconds(parts); return parts; } catch { return null; }
  }
  function fixedOffsetMinutes(zone) {
    if (zone === 'UTC') return 0;
    const match = /^UTC([+-])(\d{2}):(\d{2})$/.exec(zone ?? '');
    if (!match) return null;
    const hours = Number(match[2]); const minutes = Number(match[3]);
    if (hours > 14 || minutes > 59 || (hours === 14 && minutes !== 0)) throw new Error('Invalid timezone offset.');
    return (match[1] === '-' ? -1 : 1) * (hours * 60 + minutes);
  }
  function validateTimeZone(zone) {
    if (typeof zone !== 'string' || !zone) throw new Error('Choose the recording timezone.');
    if (fixedOffsetMinutes(zone) === null) {
      try { new Intl.DateTimeFormat('en', { timeZone: zone }); }
      catch { throw new Error('Choose a supported timezone.'); }
    }
    return zone;
  }
  function formatOffset(minutes) {
    const seconds = Math.round(Math.abs(minutes) * 60);
    return `UTC${minutes < 0 ? '-' : '+'}${pad(Math.floor(seconds / 3600))}:${pad(Math.floor(seconds % 3600 / 60))}${seconds % 60 ? `:${pad(seconds % 60)}` : ''}`;
  }
  function offsetZoneForISO(value) {
    if (/Z$/i.test(value)) return 'UTC';
    const match = /([+-]\d{2}:\d{2})$/.exec(value ?? '');
    if (!match) throw new Error('Saved time needs an explicit timezone.');
    return validateTimeZone(`UTC${match[1]}`);
  }
  function partsAt(milliseconds, zone) {
    validateTimeZone(zone);
    const fixed = fixedOffsetMinutes(zone);
    if (fixed !== null) {
      const date = new Date(milliseconds + fixed * 60000);
      return { year: date.getUTCFullYear(), month: date.getUTCMonth() + 1, day: date.getUTCDate(), hour: date.getUTCHours(), minute: date.getUTCMinutes(), second: date.getUTCSeconds(), millisecond: date.getUTCMilliseconds() };
    }
    if (!formatters.has(zone)) formatters.set(zone, new Intl.DateTimeFormat('en-CA', {
      timeZone: zone, calendar: 'iso8601', numberingSystem: 'latn', hourCycle: 'h23',
      year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit',
    }));
    const result = {};
    for (const part of formatters.get(zone).formatToParts(new Date(milliseconds))) {
      if (['year', 'month', 'day', 'hour', 'minute', 'second'].includes(part.type)) result[part.type] = Number(part.value);
    }
    result.millisecond = ((milliseconds % 1000) + 1000) % 1000;
    return result;
  }
  function offsetAt(milliseconds, zone) {
    return (wallMilliseconds(partsAt(milliseconds, zone)) - milliseconds) / 60000;
  }
  function possibleInstants(parts, zone) {
    validateTimeZone(zone);
    const wall = wallMilliseconds(parts);
    const fixed = fixedOffsetMinutes(zone);
    const offsets = fixed !== null ? new Set([fixed]) : new Set();
    // Probe both sides of nearby transitions; round-trip every candidate rather
    // than normalizing skipped hours or choosing a repeated hour implicitly.
    if (fixed === null) for (const hours of [-48, -24, -6, 0, 6, 24, 48]) {
      offsets.add(offsetAt(wall + hours * 3600000, zone));
    }
    return [...offsets].map((offsetMinutes) => ({ milliseconds: wall - offsetMinutes * 60000, offsetMinutes }))
      .filter(({ milliseconds }) => wallMilliseconds(partsAt(milliseconds, zone)) === wall)
      .sort((a, b) => a.milliseconds - b.milliseconds);
  }
  function toISO(parts, zone, offsetMinutes) {
    const candidates = possibleInstants(parts, zone);
    if (!candidates.length) throw new Error('This local time does not exist because the clocks move forward. Choose another time.');
    const selected = candidates.length === 1 ? candidates[0] : candidates.find((candidate) => candidate.offsetMinutes === offsetMinutes);
    if (!selected) throw new Error('This local time occurs twice. Choose its UTC offset.');
    return new Date(selected.milliseconds).toISOString();
  }
  function dateValue(parts) { return `${pad(parts.year, 4)}-${pad(parts.month)}-${pad(parts.day)}`; }
  function partsFromDate(date, hour, minute, second, millisecond = 0) {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date ?? '');
    if (!match) throw new Error('Choose a date.');
    const parts = { year: Number(match[1]), month: Number(match[2]), day: Number(match[3]), hour: Number(hour), minute: Number(minute), second: Number(second), millisecond };
    wallMilliseconds(parts);
    return parts;
  }
  function timeZones(extra = []) {
    const common = ['UTC', 'America/Toronto', 'America/New_York', 'America/Los_Angeles', 'Europe/London', 'Europe/Paris', 'Asia/Shanghai', 'Asia/Tokyo', 'Australia/Sydney'];
    const named = typeof Intl.supportedValuesOf === 'function' ? Intl.supportedValuesOf('timeZone') : common;
    const fixed = Array.from({ length: 105 }, (_, index) => formatOffset(-720 + index * 15));
    return [...new Set([...extra.filter(Boolean), ...common, ...named, ...fixed])].filter((zone) => {
      try { validateTimeZone(zone); return true; } catch { return false; }
    });
  }
  return { filenameCaptureTime, validateTimeZone, formatOffset, offsetZoneForISO, partsAt, offsetAt, possibleInstants, toISO, dateValue, partsFromDate, timeZones };
});
