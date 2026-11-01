'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { classifyLaps } = require('../src/activity/workout-structure');

const lap = (totalElapsedTime, totalDistanceMeters, startElapsedUs = 0) => ({
  startElapsedUs, startDistanceMeters: 0, endElapsedUs: startElapsedUs + totalElapsedTime * 1_000_000,
  totalElapsedTime, totalDistanceMeters,
});

test('repeated work laps separated by recovery are classified as intervals', () => {
  const { laps, structure } = classifyLaps([
    lap(600, 1800), lap(300, 1000), lap(300, 700), lap(300, 1000), lap(600, 1800),
  ]);
  assert.deepEqual(laps.map((entry) => entry.kind), ['warmup', 'active', 'rest', 'active', 'cooldown']);
  assert.equal(structure.kind, 'structured');
  assert.equal(structure.subtype, 'interval');
  assert.ok(structure.confidence > 0.5);
});

test('a short plan with one dominant block is a steady plan', () => {
  const { laps, structure } = classifyLaps([lap(300, 800), lap(2400, 8000), lap(300, 800)]);
  assert.deepEqual(laps.map((entry) => entry.kind), ['warmup', 'active', 'cooldown']);
  assert.equal(structure.subtype, 'steadyPlan');
});

test('equal auto laps and short lap lists stay normal', () => {
  for (const laps of [[lap(300, 1000), lap(300, 1000), lap(300, 1000), lap(300, 1000)],
    [lap(300, 1000), lap(300, 1000)]]) {
    const result = classifyLaps(laps);
    assert.equal(result.structure.kind, 'normal');
    assert.ok(result.laps.every((entry) => entry.kind === 'unknown'));
  }
});

test('duration patterns on uniform-distance auto laps are not intervals', () => {
  const { structure } = classifyLaps([lap(300, 2000), lap(300, 2000), lap(300, 2000), lap(300, 2000), lap(300, 2000)]);
  assert.notEqual(structure.subtype, 'interval');
});
