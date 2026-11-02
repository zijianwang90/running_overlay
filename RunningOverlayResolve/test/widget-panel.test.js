'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Run the actual panel handlers without Electron. Autosave replaces configuration
// objects, so clicking an existing row must resolve the current configuration.
function panel() {
  const elements = new Map();
  function element() {
    return { children: [], listeners: {}, classList: { toggle() {} },
      setAttribute() {}, append(...children) { this.children.push(...children); },
      appendChild(child) { this.children.push(child); }, replaceChildren() { this.children = []; },
      addEventListener(name, handler) { this.listeners[name] = handler; } };
  }
  const document = { getElementById(id) { if (!elements.has(id)) elements.set(id, element()); return elements.get(id); },
    createElement: element, querySelectorAll: () => [] };
  let ids = 0;
  const context = vm.createContext({ document, crypto: { randomUUID: () => `new-${++ids}` },
    window: { runningOverlayAPI: {}, runningOverlayPickers: {}, addEventListener() {}, clearTimeout() {}, setTimeout: () => 1 } });
  const templates = fs.readFileSync(path.join(__dirname, '../src/domain/templates.js'), 'utf8');
  vm.runInContext(templates, context);
  vm.runInContext('window.RunningOverlayTemplates = RunningOverlayTemplates;', context);
  const source = fs.readFileSync(path.join(__dirname, '../workflow-plugin/renderer.js'), 'utf8');
  vm.runInContext(source, context);
  vm.runInContext(`state.configuration = { templateId: 'easyRun', widgets: [{id:'old', metric:'power'}, {id:'other', metric:'pace'}] };
    renderWidgets();`, context);
  return { context, elements, run: (code) => vm.runInContext(code, context) };
}
const apply = (row) => row.children[0].listeners.click();
const rows = (ui) => ui.elements.get('template-list').children.filter((node) => node.className === 'template-row');
const confirmReplace = (ui) => ui.elements.get('template-confirm').children[1].children[1].listeners.click();

test('remove uses the latest configuration after autosave replaces it', () => {
  const ui = panel();
  const handler = ui.elements.get('widget-list').children[0].children[1].listeners.click;
  ui.run(`state.configuration = {...state.configuration, widgets:[...state.configuration.widgets]};`);
  handler();
  assert.deepEqual(ui.run('state.configuration.widgets.map((widget) => widget.id).join()'), 'other');
});

test('the picker adds repeat instances, groups widgets like the Mac palette, and enforces the capacity', () => {
  const ui = panel();
  ui.run(`addWidget('power'); renderWidgets();`);
  assert.equal(ui.run('state.configuration.widgets.at(-1).metric'), 'power');
  assert.equal(ui.run('state.configuration.widgets.at(-1).id'), 'numeric-new-1');
  assert.deepEqual([...ui.elements.get('add-widget').children.slice(1).map((group) => group.label)], ['Metrics', 'Visuals', 'Decor']);
  assert.equal(ui.run('WIDGET_GROUPS.flatMap(([, entries]) => entries).length'), 34);
  ui.run(`state.configuration.widgets = Array.from({length:16}, (_,i)=>({id:'w'+i,metric:'power'})); addWidget('pace'); renderWidgets();`);
  assert.equal(ui.run('state.configuration.widgets.length'), 16);
  assert.equal(ui.elements.get('add-widget').disabled, true);
});

test('every panel widget is a metric the control plane accepts', () => {
  const ui = panel();
  const { METRICS } = require('../src/domain/widgets');
  assert.deepEqual(ui.run('METRICS.map(([metric]) => metric).sort().join()'), Object.keys(METRICS).sort().join());
});

test('choosing a built-in template asks first, replaces the list and keeps shared instance identities', () => {
  const ui = panel();
  ui.run(`state.configuration = { templateId: 'easyRun', widgets: [
    { id: 'hr', metric: 'heartRate' }, { id: 'pace', metric: 'pace' }, { id: 'extra', metric: 'calories' }] };
    renderTemplates();`);
  apply(rows(ui)[1]); // Race
  assert.equal(ui.run('state.configuration.templateId'), 'easyRun');
  confirmReplace(ui);
  assert.equal(ui.run('state.configuration.templateId'), 'race');
  const widgets = ui.run('state.configuration.widgets');
  assert.equal(widgets.length, 11);
  assert.equal(widgets[0].id, 'pace');
  assert.equal(widgets[1].id, 'hr');
  assert.equal(widgets.some((widget) => widget.id === 'extra'), false);
  assert.equal(ui.run('state.configuration.widgets.slice(-2).map((widget) => widget.metric).join(",")'), 'zoneEdgeBar,elevationChart');
  assert.equal(new Set(widgets.map((widget) => widget.id)).size, 11);
  apply(rows(ui)[0]); // An untouched template on a panel without an overlay applies directly.
  assert.equal(ui.run('state.configuration.widgets.length'), 9);
  assert.equal(ui.run('state.configuration.widgets.some((widget) => widget.metric === "zoneEdgeBar")'), false);
  assert.match(ui.elements.get('template-badge').textContent, /^Easy Run$/);
});

test('an existing overlay always confirms before its widgets are replaced', () => {
  const ui = panel();
  ui.run(`applyTemplate('easyRun'); state.configuration.managedItemId = 'item'; renderTemplates();`);
  apply(rows(ui)[1]);
  assert.equal(ui.run('state.configuration.templateId'), 'easyRun');
  assert.equal(ui.elements.get('template-confirm').hidden, false);
});

test('a modified widget list is reported without changing the selected template', () => {
  const ui = panel();
  ui.run(`state.configuration = { templateId: 'easyRun', widgets: [{ id: 'hr', metric: 'heartRate' }] };
    renderWidgets();`);
  assert.match(ui.elements.get('template-badge').textContent, /Modified/);
  assert.equal(ui.run('state.configuration.templateId'), 'easyRun');
});

test('saved templates list under the built-ins and apply as new instances with a configuration copy', () => {
  const ui = panel();
  ui.run(`state.templates = [{ id: 'mine', name: 'Long run', elements: [{ metric: 'pace', x: 0.2, y: 0.3, styles: { Font: 'Inter' } }] }];
    applyTemplate('easyRun'); renderTemplates();`);
  assert.equal(rows(ui).length, 4);
  assert.equal(rows(ui)[3].children[0].children[0].textContent, 'Long run');
  apply(rows(ui)[3]);
  assert.equal(ui.run('state.configuration.templateId'), 'mine');
  assert.equal(ui.run('state.configuration.customTemplate.name'), 'Long run');
  assert.equal(ui.run('state.configuration.widgets.length'), 1);
  assert.match(ui.run('state.configuration.widgets[0].id'), /^numeric-new-/);
  ui.run(`state.templates = []; renderTemplates();`); // Deleting it leaves this timeline valid.
  assert.equal(ui.elements.get('template-badge').textContent, 'Long run');
  ui.run(`applyTemplate('race');`);
  assert.equal(ui.run('state.configuration.customTemplate'), null);
});
