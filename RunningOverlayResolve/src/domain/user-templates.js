'use strict';

const { invariant } = require('./validation');
const { METRICS } = require('./widgets');
const { resolvePlacements } = require('./templates');

const MAXIMUM_NAME_LENGTH = 80;
const MAXIMUM_STYLES = 512;
const MAXIMUM_TEXT_LENGTH = 1024;
const STYLE_KEY = /^[A-Za-z][A-Za-z0-9]{0,63}$/;
const TEMPLATE_ID = /^[a-zA-Z0-9_-]{1,64}$/;
// Portable file marker; Mac .rotemplate files use a different schema.
const TEMPLATE_FORMAT = 'running-overlay-resolve-template';
// Instance state and data bindings are never part of a reusable template, and a
// template file must not be able to redirect the renderer's data inputs.
const EXCLUDED_STYLE_KEYS = Object.freeze(['Metric', 'Enabled', 'HeartRateEnabled', 'Position', 'ClockUtcOffset',
  'TimeOffset', 'OffsetBackSecond', 'OffsetBackTenth', 'OffsetForwardTenth', 'OffsetForwardSecond', 'ShowSyncReadout',
  'ActivityFile', 'SyncFile', 'TimelineOriginFrame', 'AutomaticOrigin', 'ReloadData', 'ShowDiagnostics']);
const MAC_ELEMENT_METRICS = Object.freeze({ elapsedTime: 'elapsed' });

function normalizeStyleValue(value) {
  if (typeof value === 'number') { invariant(Number.isFinite(value), 'Invalid template style value.'); return value; }
  if (typeof value === 'string') { invariant(value.length <= MAXIMUM_TEXT_LENGTH, 'Template style text is too long.'); return value; }
  invariant(Array.isArray(value) && value.length === 2 && value.every(Number.isFinite), 'Invalid template style value.');
  return [value[0], value[1]];
}
function normalizeStyles(value = {}) {
  invariant(value && typeof value === 'object' && !Array.isArray(value), 'Invalid template styles.');
  const entries = Object.entries(value);
  invariant(entries.length <= MAXIMUM_STYLES, 'A template widget has too many styles.');
  return Object.fromEntries(entries.map(([key, style]) => {
    invariant(STYLE_KEY.test(key) && !EXCLUDED_STYLE_KEYS.includes(key), 'Invalid template style name.');
    return [key, normalizeStyleValue(style)];
  }));
}
function normalizeElement(value) {
  invariant(value && Object.hasOwn(METRICS, value.metric), 'A template uses an unsupported widget.');
  invariant(Number.isFinite(value.x) && Number.isFinite(value.y), 'Invalid template position.');
  return { metric: value.metric, x: value.x, y: value.y, styles: normalizeStyles(value.styles) };
}
function normalizeElements(value) {
  invariant(Array.isArray(value) && value.length >= 1 && value.length <= 16, 'A template needs between one and sixteen widgets.');
  return value.map(normalizeElement);
}
function normalizeTemplateName(value) {
  const name = typeof value === 'string' ? value.trim() : '';
  invariant(name.length >= 1 && name.length <= MAXIMUM_NAME_LENGTH, `Template names need 1 to ${MAXIMUM_NAME_LENGTH} characters.`);
  return name;
}
function normalizeUserTemplate(value) {
  invariant(value && typeof value.id === 'string' && TEMPLATE_ID.test(value.id), 'Invalid template identity.');
  return { id: value.id, name: normalizeTemplateName(value.name), elements: normalizeElements(value.elements) };
}
// Live Fusion values win; widgets not on the overlay yet use the template placement.
function composeTemplateElements(widgets, template, captured = {}) {
  return resolvePlacements(template, widgets).map(({ widget, position, styles }) => {
    const live = captured[widget.id];
    return { metric: widget.metric, x: live?.x ?? position.x, y: live?.y ?? position.y, styles: normalizeStyles(live?.styles ?? styles) };
  });
}
// Mac templates carry layout plus SwiftUI style models that have no Fuse mapping
// yet, so only the widget list and positions cross over. Y flips to Fusion's axis.
function fromMacTemplate(value) {
  const elements = value.elements.filter((element) => element.isVisible !== false);
  invariant(elements.length >= 1, 'This template has no visible widgets.');
  invariant(elements.length <= 16, `This template has ${elements.length} widgets. Resolve overlays support sixteen.`);
  return { name: normalizeTemplateName(value.name), elements: elements.map((element) => normalizeElement({
    metric: MAC_ELEMENT_METRICS[element.type] ?? element.type, x: element.positionX, y: 1 - element.positionY, styles: {},
  })) };
}
function parseTemplateFile(text) {
  let value;
  try { value = JSON.parse(text); }
  catch { throw new Error('This file is not a Running Overlay template.'); }
  if (value?.format === TEMPLATE_FORMAT) {
    invariant(value.schemaVersion === 1, 'This template needs a newer version of Running Overlay.');
    return { template: { name: normalizeTemplateName(value.name), elements: normalizeElements(value.elements) }, stylesImported: true };
  }
  invariant(Array.isArray(value?.elements) && typeof value?.name === 'string' && typeof value?.schemaVersion === 'number', 'This file is not a Running Overlay template.');
  return { template: fromMacTemplate(value), stylesImported: false };
}
function serializeTemplateFile(template) {
  return `${JSON.stringify({ format: TEMPLATE_FORMAT, schemaVersion: 1, name: template.name, elements: template.elements }, null, 2)}\n`;
}

module.exports = { EXCLUDED_STYLE_KEYS, normalizeTemplateName, normalizeElements, normalizeUserTemplate, composeTemplateElements, parseTemplateFile, serializeTemplateFile };
