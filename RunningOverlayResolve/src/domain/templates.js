'use strict';

// Built-in overlay templates, shared by the Node control plane and the
// sandboxed panel. Each element mirrors the Mac app's 1920×1080 template
// center; the Mac stores Y from the top, Fusion positions are bottom-up, so
// y = 1 - templateY at full precision.
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.RunningOverlayTemplates = api;
})(globalThis, function () {
  // Fuse input suffixes seeded once when an instance is first assigned. Mac
  // templates hide every label; the four left-column numerics also use the
  // template's teal label color and its stronger lower-right shadow. Sizes are
  // output pixels authored at 1920 pixels wide; Fusion Y points up.
  const NUMERIC_STYLE = Object.freeze({
    ShowLabel: 0,
    LabelR: 0.25, LabelG: 0.82, LabelB: 0.38,
    ShadowOpacity: 0.7, ShadowOffsetX: 4 / 1920, ShadowOffsetY: -4 / 1920,
  });
  const LABEL_HIDDEN = Object.freeze({ ShowLabel: 0 });
  const ROUTE_STYLE = Object.freeze({ ShadowOpacity: 0.95, ShadowBlur: 7 / 1920 });
  const TIMELINE_STYLE = Object.freeze({ ShadowOpacity: 0.9, ShadowBlur: 5 / 1920, ShadowThickness: 3 });
  const ZONE_STYLE = Object.freeze({ ShadowOpacity: 0.34, ShadowBlur: 8 / 1920 });
  const ELEVATION_STYLE = Object.freeze({ ShadowEnabled: 0 });
  const element = (metric, positionX, templateY, styles = LABEL_HIDDEN) => Object.freeze({
    metric, x: positionX, y: 1 - templateY, styles,
  });
  const easyRun = [
    element('pace', 0.030665921145385626, 0.7390206334260655, NUMERIC_STYLE),
    element('heartRate', 0.030598226300837895, 0.7921729713179458, NUMERIC_STYLE),
    element('cadence', 0.030463369683198994, 0.8468990093767548, NUMERIC_STYLE),
    element('routeMap', 0.879024248712692, 0.19476634960677427, ROUTE_STYLE),
    element('distanceTimeline', 0.5, 0.06896883363068688, TIMELINE_STYLE),
    element('elapsed', 0.8563774200948813, 0.843703791895823),
    element('realTime', 0.8563774200948813, 0.9013793825233812),
    element('power', 0.029313862326656028, 0.9045746000043129, NUMERIC_STYLE),
    element('weatherWidget', 0.8949036260318015, 0.7564232547646579),
  ];
  const TEMPLATES = Object.freeze([
    Object.freeze({
      id: 'easyRun',
      name: 'Easy Run',
      summary: 'Pace, heart rate, cadence and power on the left; route map and weather on the right; distance timeline across the top; clock and elapsed time at the bottom right.',
      elements: Object.freeze(easyRun),
    }),
    Object.freeze({
      id: 'race',
      name: 'Race',
      summary: 'Easy Run plus the centre HR zone bar and the bottom elevation chart.',
      elements: Object.freeze([...easyRun,
        element('zoneEdgeBar', 0.5, 0.5, ZONE_STYLE),
        element('elevationChart', 0.5, 0.9108545647558387, ELEVATION_STYLE),
      ]),
    }),
    Object.freeze({
      id: 'intervalWorkout',
      name: 'Interval Workout',
      summary: 'Route map, clock, elapsed time and weather with the interval HUD bar at the bottom and the interval timeline across the top.',
      elements: Object.freeze([
        element('routeMap', 0.110546875, 0.2043391181081142, ROUTE_STYLE),
        element('elapsed', 0.8563774200948813, 0.843703791895823),
        element('realTime', 0.8563774200948813, 0.9013793825233812),
        element('weatherWidget', 0.8949036260318015, 0.7564232547646579),
        element('intervalHUDBar', 0.5, 0.9000000000000001),
        element('intervalTimeline', 0.5, 0.08921639856575181),
      ]),
    }),
  ]);
  const DEFAULT_TEMPLATE_ID = 'easyRun';

  function normalizeTemplateId(value) {
    const id = value ?? DEFAULT_TEMPLATE_ID;
    if (!TEMPLATES.some((template) => template.id === id)) throw new Error('Choose a supported overlay template.');
    return id;
  }
  function templateById(value) {
    const id = normalizeTemplateId(value);
    return TEMPLATES.find((template) => template.id === id);
  }
  // Duplicate instances of a template metric fall back to a free placement.
  function templateElement(template, metric, occurrence = 0) {
    return template.elements.filter((entry) => entry.metric === metric)[occurrence] ?? null;
  }
  // A custom widget list no longer reproduces the selected template exactly.
  function templateMatches(template, widgets) {
    const expected = new Map();
    for (const entry of template.elements) expected.set(entry.metric, (expected.get(entry.metric) ?? 0) + 1);
    const actual = new Map();
    for (const widget of widgets) actual.set(widget.metric, (actual.get(widget.metric) ?? 0) + 1);
    if (expected.size !== actual.size) return false;
    for (const [metric, count] of expected) if (actual.get(metric) !== count) return false;
    return true;
  }
  // Deterministic placement for widgets the template does not position.
  function fallbackPosition(index) {
    return { x: 0.08 + (index % 4) * 0.23, y: 0.62 - Math.floor(index / 4) * 0.18 };
  }
  // The template positions the first instance of each metric; duplicates and
  // metrics the template does not place fall back to a free slot. Duplicates keep
  // the metric's template style even though they fall back to a free position.
  function resolvePlacements(template, widgets) {
    const occurrences = new Map();
    let fallback = 0;
    return widgets.map((widget) => {
      const occurrence = occurrences.get(widget.metric) ?? 0;
      occurrences.set(widget.metric, occurrence + 1);
      const entry = templateElement(template, widget.metric, occurrence);
      return { widget, position: entry ?? fallbackPosition(fallback++), styles: (entry ?? templateElement(template, widget.metric, 0))?.styles ?? {} };
    });
  }

  return Object.freeze({ TEMPLATES, DEFAULT_TEMPLATE_ID, normalizeTemplateId, templateById, templateElement, templateMatches, fallbackPosition, resolvePlacements });
});
