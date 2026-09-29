'use strict';

const { invariant } = require('./validation');

const METRICS = Object.freeze({ heartRate: 0, pace: 1, distance: 2, elapsed: 3 });
const LAYOUTS = Object.freeze(['vertical', 'horizontal', 'grid']);
const DEFAULT_WIDGETS = Object.freeze([{ id: 'numeric-1', metric: 'heartRate' }]);

function normalizeWidgets(value) {
  const widgets = value === undefined ? DEFAULT_WIDGETS : value;
  invariant(Array.isArray(widgets) && widgets.length >= 1 && widgets.length <= 4,
    'Choose between one and four overlay widgets.');
  const ids = new Set();
  const metrics = new Set();
  return widgets.map((widget) => {
    invariant(widget && typeof widget.id === 'string' && /^[a-zA-Z0-9_-]{1,64}$/.test(widget.id), 'Invalid widget identity.');
    invariant(Object.hasOwn(METRICS, widget.metric), 'Choose a supported widget metric.');
    invariant(!ids.has(widget.id) && !metrics.has(widget.metric), 'Each widget and metric must be unique.');
    ids.add(widget.id); metrics.add(widget.metric);
    return { id: widget.id, metric: widget.metric };
  });
}

function normalizeLayout(value) {
  const layout = value ?? 'vertical';
  invariant(LAYOUTS.includes(layout), 'Choose a supported overlay layout.');
  return layout;
}

function positionFor(layout, index) {
  if (layout === 'horizontal') return { x: 0.08 + index * 0.23, y: 0.84 };
  if (layout === 'grid') return { x: 0.08 + (index % 2) * 0.46, y: 0.84 - Math.floor(index / 2) * 0.22 };
  return { x: 0.08, y: 0.84 - index * 0.16 };
}

module.exports = { METRICS, LAYOUTS, normalizeWidgets, normalizeLayout, positionFor };
