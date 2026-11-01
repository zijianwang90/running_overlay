'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { TEMPLATES, DEFAULT_TEMPLATE_ID, normalizeTemplateId, templateById, templateElement, templateMatches, fallbackPosition } = require('../src/domain/templates');
const { METRICS } = require('../src/domain/widgets');

const metrics = (template) => template.elements.map((element) => element.metric);
const byId = (id) => TEMPLATES.find((template) => template.id === id);

test('built-in templates mirror the Mac Easy Run, Race and Interval Workout templates', () => {
  assert.deepEqual(TEMPLATES.map((template) => [template.id, template.name]), [
    ['easyRun', 'Easy Run'], ['race', 'Race'], ['intervalWorkout', 'Interval Workout'],
  ]);
  assert.equal(DEFAULT_TEMPLATE_ID, 'easyRun');
  assert.deepEqual(metrics(byId('easyRun')), ['pace', 'heartRate', 'cadence', 'routeMap', 'distanceTimeline',
    'elapsed', 'realTime', 'power', 'weatherWidget']);
  assert.deepEqual(metrics(byId('intervalWorkout')), ['routeMap', 'elapsed', 'realTime', 'weatherWidget',
    'intervalHUDBar', 'intervalTimeline']);
  for (const template of TEMPLATES) {
    for (const element of template.elements) {
      assert.ok(Object.hasOwn(METRICS, element.metric), `${template.id}: ${element.metric}`);
      assert.ok(element.x >= 0 && element.x <= 1 && element.y >= 0 && element.y <= 1, `${template.id}: ${element.metric} position`);
    }
  }
});

test('Race is Easy Run plus the zone bar and elevation chart, with no duplicated metric', () => {
  assert.deepEqual(metrics(byId('race')), [...metrics(byId('easyRun')), 'zoneEdgeBar', 'elevationChart']);
  for (const template of TEMPLATES) assert.equal(new Set(metrics(template)).size, template.elements.length);
});

test('template positions are the Mac template centers flipped to Fusion coordinates', () => {
  const easy = byId('easyRun');
  assert.deepEqual(templateElement(easy, 'pace'), { metric: 'pace', x: 0.030665921145385626, y: 0.2609793665739345 });
  assert.deepEqual(templateElement(easy, 'heartRate'), { metric: 'heartRate', x: 0.030598226300837895, y: 0.20782702868205416 });
  assert.deepEqual(templateElement(easy, 'routeMap'), { metric: 'routeMap', x: 0.879024248712692, y: 0.8052336503932257 });
  assert.deepEqual(templateElement(easy, 'distanceTimeline'), { metric: 'distanceTimeline', x: 0.5, y: 0.9310311663693132 });
  assert.deepEqual(templateElement(easy, 'weatherWidget'), { metric: 'weatherWidget', x: 0.8949036260318015, y: 0.24357674523534212 });
  const race = byId('race');
  assert.deepEqual(templateElement(race, 'zoneEdgeBar'), { metric: 'zoneEdgeBar', x: 0.5, y: 0.5 });
  assert.deepEqual(templateElement(race, 'elevationChart'), { metric: 'elevationChart', x: 0.5, y: 0.0891454352441613 });
  const interval = byId('intervalWorkout');
  assert.deepEqual(templateElement(interval, 'routeMap'), { metric: 'routeMap', x: 0.110546875, y: 0.7956608818918858 });
  assert.deepEqual(templateElement(interval, 'intervalHUDBar'), { metric: 'intervalHUDBar', x: 0.5, y: 0.09999999999999987 });
  assert.deepEqual(templateElement(interval, 'intervalTimeline'), { metric: 'intervalTimeline', x: 0.5, y: 0.9107836014342482 });
});

test('template identity defaults to Easy Run and rejects unknown names', () => {
  assert.equal(normalizeTemplateId(undefined), 'easyRun');
  assert.equal(normalizeTemplateId('race'), 'race');
  assert.equal(templateById('intervalWorkout').name, 'Interval Workout');
  assert.throws(() => normalizeTemplateId('diagonal'), /supported overlay template/);
  assert.throws(() => templateById('stack'), /supported overlay template/);
});

test('duplicate metrics have no template element and fall back to deterministic free slots', () => {
  const easy = byId('easyRun');
  assert.equal(templateElement(easy, 'pace', 1), null);
  assert.equal(templateElement(easy, 'calories'), null);
  const positions = new Set();
  for (let index = 0; index < 16; index++) {
    const position = fallbackPosition(index);
    assert.ok(position.x >= 0 && position.x <= 1 && position.y >= 0 && position.y <= 1);
    positions.add(JSON.stringify(position));
  }
  assert.equal(positions.size, 16);
});

test('templateMatches compares metric occurrences, not order', () => {
  const easy = byId('easyRun');
  const widgets = metrics(easy).slice().reverse().map((metric, index) => ({ id: `w${index}`, metric }));
  assert.equal(templateMatches(easy, widgets), true);
  assert.equal(templateMatches(easy, [...widgets, { id: 'dup', metric: 'pace' }]), false);
  assert.equal(templateMatches(easy, widgets.filter((widget) => widget.metric !== 'pace')), false);
  assert.equal(templateMatches(easy, widgets.map((widget) => widget.metric === 'pace' ? { ...widget, metric: 'calories' } : widget)), false);
});
