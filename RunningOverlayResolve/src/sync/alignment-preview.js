'use strict';

// Shared by the Node control plane and sandboxed panel. Preview only: the
// authoritative mapping is still compiled from confirmed capture times.
(function (root, factory) {
  const api = factory(typeof module === 'object' && module.exports ? require('./capture-time') : root.RunningOverlayTime);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.RunningOverlayAlignment = api;
})(globalThis, function (time) {
  const MARGIN_MS = 30 * 60 * 1000;

  function firstInstant(parts, zone) {
    try { return time.possibleInstants(parts, zone)[0]?.milliseconds ?? null; } catch { return null; }
  }

  // Chooses the zone that places the most filename clocks inside the activity.
  // Preferred zones (saved choice, system zone) win ties, then whole-hour offsets
  // closest to the activity start. Returns null when no zone gives any overlap.
  function inferRecordingZone({ wallParts, activityStartMs, activityEndMs, preferredZones = [] }) {
    if (!wallParts.length) return null;
    const fixed = Array.from({ length: 105 }, (_, index) => time.formatOffset(-720 + index * 15));
    const candidates = [...new Set([...preferredZones.filter(Boolean), ...fixed])];
    let best = null;
    for (const [rank, zone] of candidates.entries()) {
      const instants = wallParts.map((parts) => firstInstant(parts, zone)).filter((value) => value !== null);
      const inside = instants.filter((value) => value >= activityStartMs - MARGIN_MS && value <= activityEndMs + MARGIN_MS).length;
      if (!inside) continue;
      const preferred = rank < preferredZones.filter(Boolean).length;
      const wholeHour = /:00$/.test(zone) || zone === 'UTC' || preferred;
      const distance = Math.min(...instants.map((value) => Math.abs(value - activityStartMs)));
      const score = [inside, preferred ? 1 : 0, wholeHour ? 1 : 0, -distance];
      if (!best || compare(score, best.score) > 0) best = { zone, score };
    }
    return best?.zone ?? null;
  }
  function compare(left, right) {
    for (let index = 0; index < left.length; index++) if (left[index] !== right[index]) return left[index] - right[index];
    return 0;
  }

  // Seconds relative to activity start for each enabled timeline item, using the
  // same source-in rule as the sync compiler plus the user's data time offset.
  function clipSpans({ items, captureMsByMediaId, activityStartMs, activityEndMs, frameRate, offsetSeconds = 0 }) {
    const activitySeconds = (activityEndMs - activityStartMs) / 1000;
    return items.filter((item) => item.clipEnabled !== false).map((item) => {
      const captureMs = captureMsByMediaId[item.mediaId];
      if (captureMs == null) return { timelineItemId: item.timelineItemId, mediaId: item.mediaId, name: item.name, known: false };
      const sourceSeconds = item.sourceStartFrame * item.sourceFrameRate.denominator / item.sourceFrameRate.numerator;
      const durationSeconds = (item.timelineEndFrameExclusive - item.timelineStartFrame) * frameRate.denominator / frameRate.numerator;
      const start = (captureMs - activityStartMs) / 1000 + sourceSeconds + offsetSeconds;
      const end = start + durationSeconds;
      return { timelineItemId: item.timelineItemId, mediaId: item.mediaId, name: item.name, known: true, start, end,
        overlapsActivity: end > 0 && start < activitySeconds };
    });
  }

  return { inferRecordingZone, clipSpans };
});
