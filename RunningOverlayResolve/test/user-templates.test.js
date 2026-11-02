'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { lauxlib, lualib, lua, to_luastring, to_jsstring } = require('fengari');
const { TEMPLATES } = require('../src/domain/templates');
const { composeTemplateElements, normalizeUserTemplate, parseTemplateFile, serializeTemplateFile } = require('../src/domain/user-templates');
const { TemplateLibrary } = require('../src/workflow/template-library');
const { validateConfiguration } = require('../src/workflow/configuration');
const { dataUpdateScript, templateCaptureScript, pairCapturedSlots } = require('../src/resolve/fusion-script');

const element = { metric: 'pace', x: 0.2, y: 0.3, styles: { Font: 'Inter', ValueSize: 0.08, UnitPosition: [0.1, 0.2] } };
const template = { id: 'mine', name: 'Long run', elements: [element] };
const temporaryLibrary = async () => new TemplateLibrary(path.join(await fs.mkdtemp(path.join(os.tmpdir(), 'ro-templates-')), 'templates.json'));

// A minimal Fusion: a Numeric node with style inputs, driven by the generated Lua.
function runFusion(script, setup) {
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const source = `
inputs = {}
local data = {}
local list = {}
node = {}
function node:GetInput(key) return inputs[key] end
function node:SetInput(key, value) inputs[key] = value end
function node:GetData(key) return data[key] end
function node:SetData(key, value) data[key] = value end
function node:GetInputList() return list end
output = { FindMainInput = function() return { GetConnectedOutput = function() return nil end } end, ConnectInput = function() return true end }
comp_data = {}
comp = {}
function comp:GetData(key) return comp_data[key] end
function comp:SetData(key, value) comp_data[key] = value end
function comp:GetToolList() return { node } end
function comp:FindTool() return output end
function comp:StartUndo() end
function comp:EndUndo() end
${setup}
for key in pairs(inputs) do table.insert(list, { GetAttrs = function() return { INPS_ID = key } end }) end
${script}
return comp_data["RunningOverlay.Operation"]`;
  if (lauxlib.luaL_loadstring(L, to_luastring(source)) !== lua.LUA_OK || lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  const result = to_jsstring(lua.lua_tostring(L, -1)); lua.lua_close(L);
  return result;
}

test('saved templates accept only widget placement and supported style values', () => {
  assert.deepEqual(normalizeUserTemplate(template), template);
  assert.throws(() => normalizeUserTemplate({ ...template, elements: [] }), /one and sixteen/);
  assert.throws(() => normalizeUserTemplate({ ...template, name: '  ' }), /names/);
  assert.throws(() => normalizeUserTemplate({ ...template, elements: [{ ...element, metric: 'nope' }] }), /unsupported widget/);
  assert.throws(() => normalizeUserTemplate({ ...template, elements: [{ ...element, x: Infinity }] }), /position/);
  assert.throws(() => normalizeUserTemplate({ ...template, elements: [{ ...element, styles: { Font: {} } }] }), /style value/);
});

test('a template cannot redirect renderer data or carry instance state', () => {
  for (const key of ['ActivityFile', 'SyncFile', 'TimelineOriginFrame', 'TimeOffset', 'Metric', 'Enabled', 'Position', 'ClockUtcOffset']) {
    assert.throws(() => normalizeUserTemplate({ ...template, elements: [{ ...element, styles: { [key]: 1 } }] }), /style name/, key);
  }
});

test('live Fusion values override the template and pending widgets use its placement', () => {
  const widgets = [{ id: 'on-overlay', metric: 'pace' }, { id: 'pending', metric: 'heartRate' }];
  const elements = composeTemplateElements(widgets, TEMPLATES[0], { 'on-overlay': { x: 0.5, y: 0.6, styles: { ValueSize: 0.1 } } });
  assert.deepEqual(elements[0], { metric: 'pace', x: 0.5, y: 0.6, styles: { ValueSize: 0.1 } });
  const pending = TEMPLATES[0].elements.find((entry) => entry.metric === 'heartRate');
  assert.deepEqual(elements[1], { metric: 'heartRate', x: pending.x, y: pending.y, styles: pending.styles });
});

test('template files round-trip every value', () => {
  const { template: parsed, stylesImported } = parseTemplateFile(serializeTemplateFile(template));
  assert.equal(stylesImported, true);
  assert.deepEqual(parsed, { name: template.name, elements: template.elements });
  assert.throws(() => parseTemplateFile('not json'), /not a Running Overlay template/);
  assert.throws(() => parseTemplateFile('{"format":"running-overlay-resolve-template","schemaVersion":2}'), /newer version/);
});

test('Mac template files import the widget list and positions with Fusion Y', () => {
  const { template: parsed, stylesImported } = parseTemplateFile(JSON.stringify({ schemaVersion: 2, id: 'x', name: 'Mac layout', elements: [
    { type: 'elapsedTime', positionX: 0.25, positionY: 0.75, scale: 1, style: {} },
    { type: 'decorSolidColor', positionX: 0.5, positionY: 0.5, scale: 1, style: {} },
    { type: 'pace', positionX: 0, positionY: 0, scale: 1, isVisible: false, style: {} }] }));
  assert.equal(stylesImported, false);
  assert.equal(parsed.name, 'Mac layout');
  assert.deepEqual(parsed.elements, [{ metric: 'elapsed', x: 0.25, y: 0.25, styles: {} }, { metric: 'decorSolidColor', x: 0.5, y: 0.5, styles: {} }]);
  const crowded = { schemaVersion: 2, name: 'Crowded', elements: Array.from({ length: 17 }, () => ({ type: 'pace', positionX: 0, positionY: 0 })) };
  assert.throws(() => parseTemplateFile(JSON.stringify(crowded)), /supports? sixteen/);
});

test('the library saves, renames, duplicates, updates, exports, imports and deletes', async () => {
  const library = await temporaryLibrary();
  assert.deepEqual(await library.list(), []);
  const first = await library.add([element]);
  assert.equal(first.template.name, 'Template 1');
  assert.equal((await library.add([element])).template.name, 'Template 2');
  await library.rename(first.template.id, ' Long run ');
  let templates = await library.duplicate(first.template.id);
  assert.deepEqual(templates.map((entry) => entry.name), ['Long run', 'Long run Copy', 'Template 2']);
  assert.equal((await library.add([element])).template.name, 'Template 1');
  await library.update(first.template.id, [{ ...element, x: 0.9 }]);
  assert.equal((await library.list())[0].elements[0].x, 0.9);
  const file = path.join(path.dirname(library.file), 'export.rortemplate');
  await library.exportFile(first.template.id, file);
  const imported = await library.importFile(file);
  assert.equal(imported.template.name, 'Long run');
  assert.notEqual(imported.template.id, first.template.id);
  templates = await library.remove(first.template.id);
  assert.equal(templates.some((entry) => entry.id === first.template.id), false);
  await assert.rejects(library.rename(first.template.id, 'Gone'), /no longer in the library/);
});

test('a configuration keeps its applied template copy and legacy files still load', () => {
  const base = { schemaVersion: 1, contextId: 'b'.repeat(64), referenceVideoTrackIndex: 1 };
  const saved = validateConfiguration({ ...base, widgets: [{ id: 'a', metric: 'pace' }], templateId: 'mine', customTemplate: template });
  assert.equal(saved.templateId, 'mine');
  assert.deepEqual(saved.customTemplate, template);
  assert.equal(validateConfiguration({ ...base }).customTemplate, null);
  assert.throws(() => validateConfiguration({ ...base, templateId: 'mine' }), /template/);
});

test('capture reads each active slot, maps slot one colors, and skips instance state', () => {
  const payload = runFusion(templateCaptureScript({ token: 't' }), `
inputs = { Widget16Font = "x", Widget16R = 1, Widget16Metric = 0, Widget16Enabled = 0, Widget16Position = {0, 0}, Widget16CustomLabel = "", Widget16Grid = {0, 0},
  HeartRateEnabled = 1, Red = 0.25, Metric = 1, Position = {0.1, 0.2}, Font = 'A "quoted\\\\ font', CustomLabel = "line\\nbreak", Grid = {0.5, 0.75},
  Widget5Metric = 1, Widget5Enabled = 1, Widget5Position = {0.3, 0.4}, Widget5Font = "Inter", Widget5R = 0.5, Widget5CustomLabel = "", Widget5Grid = {1, 2},
  Widget6Metric = 0, Widget6Enabled = 0, Widget6Position = {0, 0} }
node:SetData("RunningOverlay.ManagedNumeric", true)
comp_data["RunningOverlay.WidgetSlots"] = { ignored = 1 }`);
  assert.match(payload, /^t\|ok\|/);
  const captured = JSON.parse(payload.slice('t|ok|'.length));
  assert.deepEqual(Object.keys(captured), ['1', '5']);
  assert.deepEqual(captured['1'], { metric: 1, position: [0.1, 0.2], styles: { R: 0.25, Font: 'A "quoted\\ font', CustomLabel: 'line\nbreak', Grid: [0.5, 0.75] } });
  assert.deepEqual(captured['5'], { metric: 1, position: [0.3, 0.4], styles: { R: 0.5, Font: 'Inter', CustomLabel: '', Grid: [1, 2] } });
});

test('capture failure is reported through the acknowledgment', () => {
  assert.match(runFusion(templateCaptureScript({ token: 't' }), ''), /^t\|error:.*no Numeric node/);
});

test('captured slots pair with panel widgets by metric and slot order', () => {
  const slots = {
    1: { metric: 1, position: [0.1, 0.2], styles: { R: 0.3 } },
    5: { metric: 1, position: [0.3, 0.4], styles: { R: 0.4 } },
    7: { metric: 0, position: [0.5, 0.6], styles: {} },
    9: { metric: 18, position: [0.7, 0.8], styles: {} },
  };
  const widgets = [{ id: 'pace-a', metric: 'pace' }, { id: 'hr', metric: 'heartRate' }, { id: 'pace-b', metric: 'pace' }, { id: 'not-on-overlay', metric: 'cadence' }];
  assert.deepEqual(pairCapturedSlots(widgets, slots), {
    'pace-a': { x: 0.1, y: 0.2, styles: { R: 0.3 } },
    hr: { x: 0.5, y: 0.6, styles: {} },
    'pace-b': { x: 0.3, y: 0.4, styles: { R: 0.4 } },
  });
});

test('a saved template seeds new instances with text, number and point styles, mapping slot one colors', () => {
  const customTemplate = { id: 'mine', name: 'Long run', elements: [
    { metric: 'pace', x: 0.2, y: 0.3, styles: { R: 0.25, Font: 'Inter', Grid: [0.5, 0.75], RemovedInput: 1 } }] };
  const script = dataUpdateScript({ bundleDirectory: '/tmp/synthetic', origin: 0, token: 't', templateId: 'mine', customTemplate, widgets: [{ id: 'a', metric: 'pace' }] });
  const read = `
return_value = table.concat({tostring(inputs.Red), tostring(inputs.PaceR), tostring(inputs.PaceFont), tostring(inputs.PaceGrid and inputs.PaceGrid[2]), tostring(inputs.PacePosition[1]), tostring(inputs.PaceRemovedInput)}, ",")
comp_data["RunningOverlay.Operation"] = comp_data["RunningOverlay.Operation"] .. "|" .. return_value`;
  const setup = `
inputs = { ActivityFile = "", SyncFile = "", TimelineOriginFrame = 0, AutomaticOrigin = 1, TimeOffset = 0, Red = 1, R = 0,
  PaceR = 1, PaceFont = "", PaceGrid = {0, 0}, PacePosition = {0, 0}, PaceMetric = 0, PaceEnabled = 0, PaceClockUtcOffset = 0 }
node:SetData("RunningOverlay.ManagedNumeric", true)
comp_data["RunningOverlay.WidgetSlots"] = {}
comp_data["RunningOverlay.TemplateSignature"] = "previous"`;
  const payload = runFusion(`${script}\n${read}`, setup);
  assert.equal(payload, 't|ok|1,0.25,Inter,0.75,0.2,nil');
});
