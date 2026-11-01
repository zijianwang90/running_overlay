'use strict';

// Ports the Mac workout-structure analyzer's automatic path. Lap positions are
// array indexes; each lap carries its total distance, elapsed time and average
// pace so repeated work laps can be detected without a plan file.
const UNKNOWN = 'unknown';
const ACTIVE = 'active';
const REST = 'rest';
const WARMUP = 'warmup';
const COOLDOWN = 'cooldown';

function effectivePace(lap) {
  if (Number.isFinite(lap.avgPaceSecondsPerKilometer) && lap.avgPaceSecondsPerKilometer > 0) return lap.avgPaceSecondsPerKilometer;
  if (lap.totalElapsedTime > 0 && lap.totalDistanceMeters > 0) return lap.totalElapsedTime / (lap.totalDistanceMeters / 1000);
  return null;
}

function meanPace(indexes, laps) {
  const paces = [...indexes].map((index) => effectivePace(laps[index])).filter((pace) => pace !== null && Number.isFinite(pace));
  if (!paces.length) return null;
  return paces.reduce((sum, pace) => sum + pace, 0) / paces.length;
}

function nonZeroMean(values) {
  const positive = values.filter((value) => value > 0);
  return positive.length ? positive.reduce((sum, value) => sum + value, 0) / positive.length : null;
}

function repeatedGroup(internal, valueOf, minimumValue, absoluteTolerance, relativeTolerance, basis) {
  const candidates = internal
    .map((lap, position) => ({ lap, position: position + 1 }))
    .filter((entry) => valueOf(entry.lap) >= minimumValue)
    .sort((left, right) => valueOf(right.lap) - valueOf(left.lap));
  let best = null;
  for (const seed of candidates) {
    const seedValue = valueOf(seed.lap);
    const tolerance = Math.max(absoluteTolerance, seedValue * relativeTolerance);
    const group = candidates.filter((entry) => Math.abs(valueOf(entry.lap) - seedValue) <= tolerance);
    if (group.length < 2) continue;
    const mean = group.reduce((sum, entry) => sum + valueOf(entry.lap), 0) / group.length;
    const variance = group.reduce((sum, entry) => sum + (valueOf(entry.lap) - mean) ** 2, 0) / group.length;
    const score = group.length - Math.sqrt(variance) / Math.max(mean, 1);
    if (!best || group.length > best.indexes.length || (group.length === best.indexes.length && score > best.score)) {
      best = { indexes: group.map((entry) => entry.position), score, basis };
    }
  }
  return best;
}

function isWorkLike(lap, referencePace) {
  if (lap.totalElapsedTime < 20 || lap.totalDistanceMeters < 100) return false;
  const pace = effectivePace(lap);
  if (pace === null || !(referencePace > 0)) return false;
  return Math.abs(pace - referencePace) <= Math.max(45, referencePace * 0.22);
}

function expandedWorkIndexes(group, laps) {
  const indexes = new Set(group.indexes);
  if (indexes.size < 2) return indexes;
  const first = Math.min(...indexes);
  const last = Math.max(...indexes);
  const referencePace = meanPace(indexes, laps);
  if (referencePace === null) return indexes;
  for (let index = 0; index < laps.length; index += 1) {
    if (index <= first || index >= laps.length - 1 || indexes.has(index) || index <= last) continue;
    if (isWorkLike(laps[index], referencePace)) indexes.add(index);
  }
  return indexes;
}

function uniformDistanceAutoLapDurationPattern(group, workIndexes, laps) {
  if (group.basis !== 'duration' || workIndexes.size < 2) return false;
  const first = Math.min(...workIndexes);
  const last = Math.max(...workIndexes);
  const distances = [];
  for (let index = first; index <= last; index += 1) distances.push(laps[index].totalDistanceMeters);
  const meanDistance = nonZeroMean(distances);
  if (meanDistance === null || meanDistance < 800) return false;
  const tolerance = Math.max(40, meanDistance * 0.08);
  return distances.every((distance) => Math.abs(distance - meanDistance) <= tolerance);
}

function isRecoveryLike(lap, workIndexes, laps) {
  if (lap.totalElapsedTime < 20 || lap.totalDistanceMeters < 50) return false;
  const referencePace = meanPace(workIndexes, laps);
  const pace = effectivePace(lap);
  if (referencePace === null || pace === null || !(referencePace > 0)) return false;
  return pace >= referencePace * 1.35;
}

function intervalResult(laps, source) {
  const internal = laps.slice(1, -1);
  const groups = [
    repeatedGroup(internal, (lap) => lap.totalDistanceMeters, 100, 60, 0.18, 'distance'),
    repeatedGroup(internal, (lap) => lap.totalElapsedTime, 20, 8, 0.18, 'duration'),
  ].filter(Boolean).sort((left, right) => right.indexes.length - left.indexes.length || right.score - left.score);

  for (const group of groups) {
    if (group.indexes.length < 2) continue;
    const workIndexes = expandedWorkIndexes(group, laps);
    const sorted = [...workIndexes].sort((left, right) => left - right);
    if (!sorted.length) continue;
    const firstWork = sorted[0];
    const lastWork = sorted[sorted.length - 1];
    const hasGap = sorted.some((index, position) => position > 0 && index - sorted[position - 1] > 1);
    if (!hasGap || uniformDistanceAutoLapDurationPattern(group, workIndexes, laps)) continue;
    const classified = laps.map((lap, index) => {
      let kind = REST;
      if (workIndexes.has(index)) kind = ACTIVE;
      else if (index < firstWork) kind = WARMUP;
      else if (index > lastWork) kind = COOLDOWN;
      return { ...lap, kind };
    });
    if (lastWork + 1 < classified.length - 1 && isRecoveryLike(classified[lastWork + 1], workIndexes, laps)) {
      classified[lastWork + 1] = { ...classified[lastWork + 1], kind: REST };
    }
    if (!classified.some((lap) => lap.kind === REST)) continue;
    return {
      laps: classified,
      structure: { kind: 'structured', subtype: 'interval', source, confidence: Math.min(0.95, 0.55 + group.indexes.length * 0.05),
        reason: 'Detected repeated work laps separated by recovery laps.' },
    };
  }
  return null;
}

function steadyPlanResult(laps, source) {
  if (laps.length < 3 || laps.length > 5) return null;
  const totalDistance = laps.reduce((sum, lap) => sum + Math.max(lap.totalDistanceMeters, 0), 0);
  const totalDuration = laps.reduce((sum, lap) => sum + Math.max(lap.totalElapsedTime, 0), 0);
  if (!(totalDistance > 0 || totalDuration > 0)) return null;
  let mainIndex = 1;
  let mainShare = 0;
  for (let index = 1; index < laps.length - 1; index += 1) {
    const share = Math.max(laps[index].totalDistanceMeters / Math.max(totalDistance, 1), laps[index].totalElapsedTime / Math.max(totalDuration, 1));
    if (share > mainShare) { mainShare = share; mainIndex = index; }
  }
  if (mainShare < 0.55) return null;
  return {
    laps: laps.map((lap, index) => ({ ...lap, kind: index === mainIndex ? ACTIVE : index < mainIndex ? WARMUP : COOLDOWN })),
    structure: { kind: 'structured', subtype: 'steadyPlan', source, confidence: 0.72,
      reason: 'Detected warmup, one main workout block, and cooldown.' },
  };
}

function classifyLaps(laps, { source = 'auto' } = {}) {
  const allUnknown = () => laps.map((lap) => ({ ...lap, kind: UNKNOWN }));
  if (laps.length < 3) {
    return { laps: allUnknown(), structure: { kind: 'normal', subtype: 'none', source, confidence: 0.9,
      reason: 'No structured lap pattern detected.' } };
  }
  const interval = intervalResult(laps, source);
  if (interval) return interval;
  const steady = steadyPlanResult(laps, source);
  if (steady) return steady;
  return { laps: allUnknown(), structure: { kind: 'normal', subtype: 'none', source, confidence: 0.8,
    reason: 'No repeat or plan-like lap pattern detected.' } };
}

module.exports = { classifyLaps, effectivePace, LAP_KINDS: Object.freeze({ [WARMUP]: WARMUP, [ACTIVE]: ACTIVE, [REST]: REST, [COOLDOWN]: COOLDOWN, [UNKNOWN]: UNKNOWN }) };
