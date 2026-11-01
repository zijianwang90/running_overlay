'use strict';

const { invariant } = require('./validation');

const METRICS = Object.freeze({ heartRate: 0, pace: 1, distance: 2, elapsed: 3, elevation: 4, cadence: 5, power: 6, calories: 7,
  avgPace: 8, verticalOscillation: 9, groundContactTime: 10, strideLength: 11,
  verticalRatio: 12, groundContactBalance: 13, temperature: 14, grade: 15 });
const LAYOUTS = Object.freeze(['vertical', 'horizontal', 'grid']);
const DEFAULT_WIDGETS = Object.freeze([{ id: 'numeric-1', metric: 'heartRate' }]);

function normalizeWidgets(value) {
  const widgets = value === undefined ? DEFAULT_WIDGETS : value;
  invariant(Array.isArray(widgets) && widgets.length >= 1 && widgets.length <= 16,
    'Choose between one and sixteen overlay widgets.');
  const ids = new Set();
  return widgets.map((widget) => {
    invariant(widget && typeof widget.id === 'string' && /^[a-zA-Z0-9_-]{1,64}$/.test(widget.id), 'Invalid widget identity.');
    invariant(Object.hasOwn(METRICS, widget.metric), 'Choose a supported widget metric.');
    invariant(!ids.has(widget.id), 'Each widget identity must be unique.');
    ids.add(widget.id);
    return { id: widget.id, metric: widget.metric };
  });
}

function normalizeLayout(value) {
  const layout = value ?? 'vertical';
  invariant(LAYOUTS.includes(layout), 'Choose a supported overlay layout.');
  return layout;
}

function positionFor(layout, index, count = 4) {
  if (count > 4) return { x: 0.05 + (index % 4) * 0.24, y: 0.86 - Math.floor(index / 4) * 0.22 };
  if (index >= 4) return { x: 0.08 + (index % 4) * 0.23, y: 0.84 - Math.floor(index / 4) * 0.20 };
  if (layout === 'horizontal') return { x: 0.08 + index * 0.23, y: 0.84 };
  if (layout === 'grid') return { x: 0.08 + (index % 2) * 0.46, y: 0.84 - Math.floor(index / 2) * 0.22 };
  return { x: 0.08, y: 0.84 - index * 0.16 };
}

module.exports = { METRICS, LAYOUTS, normalizeWidgets, normalizeLayout, positionFor };
