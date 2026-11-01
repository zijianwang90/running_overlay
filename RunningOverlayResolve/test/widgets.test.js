'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { normalizeWidgets, normalizeLayout, positionFor } = require('../src/domain/widgets');
const { validateConfiguration } = require('../src/workflow/configuration');
const { dataUpdateScript, validClockOffsetHours } = require('../src/resolve/fusion-script');
const { clockUtcOffsetHours } = require('../src/workflow/service');

const contextId = 'b'.repeat(64);

test('legacy saved timelines gain one stable widget without changing their configuration version', () => {
  const restored = validateConfiguration({ schemaVersion: 1, contextId, referenceVideoTrackIndex: 1 });
  assert.deepEqual(restored.widgets, [{ id: 'numeric-1', metric: 'heartRate' }]);
  assert.equal(restored.layoutPreset, 'vertical');
  assert.deepEqual(validateConfiguration(restored).widgets, restored.widgets);
});

test('widget choices and preset positions are deterministic and reject duplicate or unsafe identities', () => {
  const widgets = normalizeWidgets([
    { id: 'hr', metric: 'heartRate' }, { id: 'pace', metric: 'pace' },
    { id: 'distance', metric: 'distance' }, { id: 'elapsed', metric: 'elapsed' },
  ]);
  assert.deepEqual(widgets.map((widget) => widget.metric), ['heartRate', 'pace', 'distance', 'elapsed']);
  assert.deepEqual(positionFor('grid', 2), { x: 0.08, y: 0.62 });
  assert.deepEqual(positionFor('horizontal', 3), { x: 0.77, y: 0.84 });
  assert.throws(() => normalizeWidgets([]), /one and sixteen/);
  assert.equal(normalizeWidgets([{ id: 'a', metric: 'pace' }, { id: 'b', metric: 'pace' }]).length, 2);
  assert.throws(() => normalizeWidgets([{ id: 'a', metric: 'pace' }, { id: 'a', metric: 'power' }]), /unique/);
  assert.throws(() => normalizeWidgets([{ id: 'a\n); os.execute', metric: 'pace' }]), /identity/);
  assert.throws(() => normalizeLayout('diagonal'), /layout/);
});

test('Fusion scene transaction enables metrics in one renderer and preserves styles on resync', () => {
  const script = dataUpdateScript({ bundleDirectory: '/tmp/synthetic', origin: 0, token: 'test',
    widgets: [{ id: 'hr', metric: 'heartRate' }, { id: 'pace', metric: 'pace' }], layoutPreset: 'vertical' });
  assert.match(script, /id=string\.sub\(\[\[xhr\]\], 2\), metric=string\.sub\(\[\[xheartRate\]\], 2\)/);
  assert.match(script, /id=string\.sub\(\[\[xpace\]\], 2\), metric=string\.sub\(\[\[xpace\]\], 2\)/);
  assert.match(script, /update\(key, used\[slot\] and 1 or 0\)/);
  assert.match(script, /output:ConnectInput\("Input", node\)/);
  assert.match(script, /previous_layout ~= layout_signature/);
  assert.match(script, /comp:EndUndo\(ok\)/);
  assert.match(script, /RunningOverlay\.ManagedNumeric/);
});


test('new numeric fields survive configuration round trips as independent instances', () => {
  const widgets = ['elevation', 'cadence', 'power', 'calories', 'power'].map((metric, index) => ({ id: `widget-${index}`, metric }));
  const configuration = validateConfiguration({ schemaVersion: 1, contextId, referenceVideoTrackIndex: 1, widgets });
  assert.deepEqual(validateConfiguration(JSON.parse(JSON.stringify(configuration))).widgets, widgets);
  assert.throws(() => normalizeWidgets(Array.from({ length: 17 }, (_, index) => ({ id: `w${index}`, metric: 'power' }))), /sixteen/);
  const positions = new Set();
  for (let index = 0; index < 16; index++) {
    const position = positionFor('grid', index, 16);
    positions.add(JSON.stringify(position));
    assert.ok(position.x >= 0 && position.x <= 1 && position.y >= 0 && position.y <= 1);
  }
  assert.equal(positions.size, 16);
});

test('Real Time instances start on the activity clock and keep their Fusion offset on resync', () => {
  const script = dataUpdateScript({ bundleDirectory: '/tmp/synthetic', origin: 0, token: 't',
    widgets: [{ id: 'clock', metric: 'realTime' }], layoutPreset: 'vertical', clockUtcOffsetHours: -4 });
  assert.match(script, /metric_index=16/);
  assert.match(script, /if fresh or not slots\[widget\.id\] then\n\s+if node:GetInput\(prefix \.\. "ClockUtcOffset"\) ~= nil then update\(prefix \.\. "ClockUtcOffset", -4\)/);
  assert.equal(validClockOffsetHours(5.75), 5.75);
  assert.equal(validClockOffsetHours(5.7501), 5.75);
  assert.throws(() => validClockOffsetHours(15), /between -12 and \+14/);
  assert.throws(() => dataUpdateScript({ bundleDirectory: 'x', origin: 0, token: 't', clockUtcOffsetHours: Number.NaN }), /Clock UTC offset/);
});

test('the clock offset comes from the recording timezone at activity start, else the computer zone', () => {
  const july = { activity: { startUtcUs: Date.UTC(2026, 6, 2, 22, 47, 3) * 1000 } };
  const january = { activity: { startUtcUs: Date.UTC(2026, 0, 2, 12, 0, 0) * 1000 } };
  assert.equal(clockUtcOffsetHours({ ...july, captureTimeZone: 'America/New_York' }), -4);
  assert.equal(clockUtcOffsetHours({ ...january, captureTimeZone: 'America/New_York' }), -5);
  assert.equal(clockUtcOffsetHours({ ...july, captureTimeZone: 'UTC+05:45' }), 5.75);
  assert.equal(clockUtcOffsetHours({ ...july, captureTimeZone: null }, 'Asia/Shanghai'), 8);
});
