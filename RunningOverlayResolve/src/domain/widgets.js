'use strict';

const { invariant } = require('./validation');

const METRICS = Object.freeze({ heartRate: 0, pace: 1, distance: 2, elapsed: 3, elevation: 4, cadence: 5, power: 6, calories: 7,
  avgPace: 8, verticalOscillation: 9, groundContactTime: 10, strideLength: 11,
  verticalRatio: 12, groundContactBalance: 13, temperature: 14, grade: 15, realTime: 16,
  distanceTimeline: 17, routeMap: 18, zoneEdgeBar: 19, elevationChart: 20, weatherWidget: 21,
  date: 22, customNumeric: 23, heartRateZone: 24, runningGauge: 25, decorSolidColor: 26, decorIcon: 27, decorText: 28, lapPace: 29, intervalHUDBar: 30, intervalTimeline: 31, intervalCountdown: 32, intervalWorkSummary: 33 });
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

module.exports = { METRICS, normalizeWidgets };
