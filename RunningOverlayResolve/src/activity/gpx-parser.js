'use strict';

const { invariant } = require('../domain/validation');
const { validateActivity } = require('../domain/activity');

const MAX_GPX_BYTES = 64 * 1024 * 1024;
const XML_NAME = /^[A-Za-z_][\w.:-]*/;
const ENTITY = /&(#(?:x[0-9a-fA-F]+|[0-9]+)|[A-Za-z][A-Za-z0-9]*);/g;

function decodeXml(value) {
  const undecoded = value.replace(ENTITY, '');
  invariant(!undecoded.includes('&'), 'GPX contains an invalid XML entity');
  return value.replace(ENTITY, (_whole, name) => {
    const builtIn = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" }[name];
    if (builtIn) return builtIn;
    invariant(name.startsWith('#'), 'GPX contains an unsupported XML entity');
    const code = name[1].toLowerCase() === 'x' ? Number.parseInt(name.slice(2), 16) : Number.parseInt(name.slice(1), 10);
    invariant(code > 0 && code <= 0x10ffff && !(code >= 0xd800 && code <= 0xdfff), 'GPX contains an invalid XML character');
    return String.fromCodePoint(code);
  });
}

function parseTag(raw) {
  const name = XML_NAME.exec(raw)?.[0];
  invariant(name, 'GPX contains a malformed XML tag');
  const attributes = {};
  let remaining = raw.slice(name.length);
  while (remaining.trim()) {
    const match = /^\s+([A-Za-z_][\w.:-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')/.exec(remaining);
    invariant(match, `GPX contains a malformed attribute on ${name}`);
    invariant(!Object.hasOwn(attributes, match[1]), `GPX contains a duplicate ${match[1]} attribute`);
    attributes[match[1]] = decodeXml(match[2] ?? match[3]);
    remaining = remaining.slice(match[0].length);
  }
  return { name, attributes };
}

function xmlTokens(text, visit) {
  let position = 0;
  while (position < text.length) {
    if (text[position] !== '<') {
      const end = text.indexOf('<', position);
      visit({ kind: 'text', text: decodeXml(text.slice(position, end < 0 ? text.length : end)) });
      position = end < 0 ? text.length : end;
      continue;
    }
    if (text.startsWith('<!--', position)) {
      const end = text.indexOf('-->', position + 4);
      invariant(end >= 0, 'GPX contains an unclosed XML comment');
      position = end + 3;
      continue;
    }
    if (text.startsWith('<![CDATA[', position)) {
      const end = text.indexOf(']]>', position + 9);
      invariant(end >= 0, 'GPX contains an unclosed CDATA section');
      visit({ kind: 'text', text: text.slice(position + 9, end) });
      position = end + 3;
      continue;
    }
    if (text.startsWith('<?', position)) {
      const end = text.indexOf('?>', position + 2);
      invariant(end >= 0, 'GPX contains an unclosed XML instruction');
      position = end + 2;
      continue;
    }
    invariant(!text.startsWith('<!', position), 'GPX DTDs and external entities are not supported');
    let end = position + 1; let quote = null;
    for (; end < text.length; end++) {
      const character = text[end];
      if (quote) { if (character === quote) quote = null; }
      else if (character === '"' || character === "'") quote = character;
      else if (character === '>') break;
    }
    invariant(end < text.length, 'GPX contains an unclosed XML tag');
    const content = text.slice(position + 1, end).trim();
    if (content.startsWith('/')) {
      invariant(/^\/[A-Za-z_][\w.:-]*$/.test(content), 'GPX contains a malformed closing tag');
      visit({ kind: 'end', name: content.slice(1) });
    } else {
      const selfClosing = content.endsWith('/');
      const tag = parseTag(selfClosing ? content.slice(0, -1).trimEnd() : content);
      visit({ kind: 'start', ...tag });
      if (selfClosing) visit({ kind: 'end', name: tag.name });
    }
    position = end + 1;
  }
}

function utcMicroseconds(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|[+-]\d{2}:\d{2})$/.exec(value);
  invariant(match, `GPX track point time must be ISO 8601 with a timezone: ${value}`);
  const [year, month, day, hour, minute, second] = match.slice(1, 7).map(Number);
  const date = new Date(0);
  date.setUTCFullYear(year, month - 1, day);
  date.setUTCHours(hour, minute, second, 0);
  invariant(year >= 1970 && year <= 9999 && date.getUTCFullYear() === year && date.getUTCMonth() + 1 === month
    && date.getUTCDate() === day && date.getUTCHours() === hour && date.getUTCMinutes() === minute
    && date.getUTCSeconds() === second, `GPX track point time has an invalid calendar date: ${value}`);
  const zone = match[8];
  let offsetMinutes = 0;
  if (zone !== 'Z') {
    const zoneHour = Number(zone.slice(1, 3)); const zoneMinute = Number(zone.slice(4));
    invariant(zoneHour <= 14 && zoneMinute < 60 && (zoneHour < 14 || zoneMinute === 0), `GPX time has an invalid timezone: ${value}`);
    offsetMinutes = (zone[0] === '+' ? 1 : -1) * (zoneHour * 60 + zoneMinute);
  }
  const result = (date.getTime() - offsetMinutes * 60_000) * 1_000 + Number((match[7] ?? '').padEnd(6, '0'));
  invariant(Number.isSafeInteger(result), 'GPX time exceeds the supported microsecond range');
  return result;
}

function numberOrNull(text, { positive = false } = {}) {
  if (text === '') return null;
  const value = Number(text);
  return Number.isFinite(value) && (!positive || value > 0) ? value : null;
}

function haversineMeters(first, second) {
  const radians = Math.PI / 180;
  const dLatitude = (second.latitude - first.latitude) * radians;
  const dLongitude = (second.longitude - first.longitude) * radians;
  const latitude1 = first.latitude * radians;
  const latitude2 = second.latitude * radians;
  const a = Math.sin(dLatitude / 2) ** 2 + Math.cos(latitude1) * Math.cos(latitude2) * Math.sin(dLongitude / 2) ** 2;
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(Math.min(1, a)), Math.sqrt(Math.max(0, 1 - a)));
}

function parseGpxBuffer(input, options = {}) {
  invariant(Buffer.isBuffer(input) || typeof input === 'string', 'GPX input must be UTF-8 text or a Buffer');
  const bytes = Buffer.isBuffer(input) ? input : Buffer.from(input, 'utf8');
  invariant(bytes.length <= MAX_GPX_BYTES, 'GPX file exceeds the 64 MiB limit');
  let text;
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(bytes).replace(/^\uFEFF/, ''); }
  catch { throw new Error('GPX file must be valid UTF-8'); }
  const stack = []; const points = [];
  let rootSeen = false; let segment = -1; let point = null;
  xmlTokens(text, (token) => {
    if (token.kind === 'text') {
      if (stack.length) stack[stack.length - 1].text += token.text;
      else invariant(!token.text.trim(), 'GPX has text outside its root element');
      return;
    }
    if (token.kind === 'start') {
      const local = token.name.split(':').at(-1);
      if (!stack.length) {
        invariant(!rootSeen && local === 'gpx', 'GPX must contain exactly one gpx root element');
        rootSeen = true;
      }
      const parent = stack.at(-1)?.local;
      if (local === 'trkseg' && parent === 'trk') segment++;
      if (local === 'trkpt' && parent === 'trkseg') {
        const latitude = numberOrNull(token.attributes.lat);
        const longitude = numberOrNull(token.attributes.lon);
        invariant(latitude !== null && longitude !== null && Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180,
          'GPX track point needs valid latitude and longitude');
        point = { segment, latitude, longitude, index: points.length };
      }
      stack.push({ name: token.name, local, text: '' });
      return;
    }
    const entry = stack.pop();
    invariant(entry?.name === token.name, 'GPX has mismatched XML tags');
    if (!point) return;
    const parent = stack.at(-1)?.local;
    const value = entry.text.trim();
    if (parent === 'trkpt' && entry.local === 'time' && value) point.timestampUs = utcMicroseconds(value);
    else if (parent === 'trkpt' && entry.local === 'ele') point.elevationMeters = numberOrNull(value);
    else if (stack.some((ancestor) => ancestor.local === 'extensions')) {
      const numeric = numberOrNull(value);
      if (numeric !== null) {
        if (['hr', 'heartrate'].includes(entry.local)) point.heartRateBpm = numeric >= 0 ? Math.round(numeric) : null;
        else if (['cad', 'cadence'].includes(entry.local)) point.cadenceSpm = numeric >= 0 ? Math.round(numeric) : null;
        else if (['power', 'watts', 'powerinwatts'].includes(entry.local)) point.powerWatts = numeric >= 0 ? Math.round(numeric) : null;
        else if (['atemp', 'temp', 'temperature'].includes(entry.local)) point.temperatureCelsius = numeric;
        else if (entry.local === 'speed') point.speedMetersPerSecond = numeric > 0 ? numeric : null;
      }
    }
    if (entry.local === 'trkpt' && parent === 'trkseg') { points.push(point); point = null; }
  });
  invariant(rootSeen && stack.length === 0, 'GPX document is incomplete');
  invariant(points.length > 0, 'GPX contains no track points');
  const timed = points.filter((entry) => entry.timestampUs !== undefined)
    .sort((left, right) => left.timestampUs - right.timestampUs || left.index - right.index);
  invariant(timed.length >= 2 && timed.at(-1).timestampUs > timed[0].timestampUs,
    'GPX needs at least two timed track points with different timestamps');
  const startUtcUs = timed[0].timestampUs;
  let distanceMeters = 0; let previous = null;
  const records = timed.map((entry) => {
    let segmentDistance = 0;
    if (previous?.segment === entry.segment) {
      segmentDistance = haversineMeters(previous, entry);
      distanceMeters += segmentDistance;
    }
    const deltaUs = previous ? entry.timestampUs - previous.timestampUs : 0;
    const paceSecondsPerKilometer = entry.speedMetersPerSecond > 0 ? 1_000 / entry.speedMetersPerSecond
      : previous?.segment === entry.segment && deltaUs > 0 && segmentDistance > 0
        ? deltaUs / 1_000 / segmentDistance : null;
    const gradePercent = previous?.segment === entry.segment && segmentDistance > 0
      && typeof previous.elevationMeters === 'number' && typeof entry.elevationMeters === 'number'
      ? (entry.elevationMeters - previous.elevationMeters) / segmentDistance * 100 : null;
    previous = entry;
    return {
      elapsedUs: entry.timestampUs - startUtcUs,
      distanceMeters,
      heartRateBpm: entry.heartRateBpm ?? null,
      paceSecondsPerKilometer,
      cadenceSpm: entry.cadenceSpm ?? null,
      elevationMeters: entry.elevationMeters ?? null,
      powerWatts: entry.powerWatts ?? null,
      calories: null,
      temperatureCelsius: entry.temperatureCelsius ?? null,
      gradePercent,
    };
  });
  return validateActivity({ schemaVersion: 1, activityId: options.activityId ?? `gpx-${startUtcUs}`,
    startUtcUs, endUtcUs: timed.at(-1).timestampUs, records, annotations: [] });
}

module.exports = { parseGpxBuffer, utcMicroseconds };
