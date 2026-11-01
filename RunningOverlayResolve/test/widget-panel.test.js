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
  vm.runInContext(`state.configuration = { templateId: 'easyRun', widgets: [{id:'old', metric:'power'}] };
    renderWidgets();`, context);
  const rows = elements.get('metric-chips').children.at(-1).children;
  return { context, rows, run: (code) => vm.runInContext(code, context) };
}

test('duplicate and remove use the latest configuration after autosave replaces it', () => {
  const ui = panel();
  ui.run(`state.configuration = {...state.configuration, widgets:[...state.configuration.widgets]};`);
  ui.rows[0].children[1].children[0].listeners.click();
  assert.equal(ui.run('state.configuration.widgets.length'), 2);
  assert.equal(ui.run('state.configuration.widgets[1].metric'), 'power');
  ui.run('renderWidgets();');
  // A newer autosave response must also be respected by an old Remove handler.
  const handler = ui.run(`(() => { const node = byId('metric-chips').children.at(-1).children[0]; return node.children[1].children[1].listeners.click; })()`);
  ui.run(`state.configuration = {...state.configuration, widgets:[...state.configuration.widgets]};`);
  handler();
  assert.equal(ui.run('state.configuration.widgets.length'), 1);
  assert.equal(ui.run('state.configuration.widgets[0].id'), 'numeric-new-1');
});

test('choosing a template replaces the widget list and keeps shared instance identities', () => {
  const ui = panel();
  ui.run(`state.configuration = { templateId: 'easyRun', widgets: [
    { id: 'hr', metric: 'heartRate' }, { id: 'pace', metric: 'pace' }, { id: 'extra', metric: 'calories' }] };
    renderTemplates();`);
  const templates = ui.run('byId("template-options").children');
  templates[1].listeners.click(); // Race
  assert.equal(ui.run('state.configuration.templateId'), 'race');
  const widgets = ui.run('state.configuration.widgets');
  assert.equal(widgets.length, 11);
  assert.equal(widgets[0].id, 'pace');
  assert.equal(widgets[1].id, 'hr');
  assert.equal(widgets.some((widget) => widget.id === 'extra'), false);
  assert.equal(ui.run('state.configuration.widgets.slice(-2).map((widget) => widget.metric).join(",")'), 'zoneEdgeBar,elevationChart');
  assert.equal(new Set(widgets.map((widget) => widget.id)).size, 11);
  templates[0].listeners.click(); // Back to Easy Run
  assert.equal(ui.run('state.configuration.widgets.length'), 9);
  assert.equal(ui.run('state.configuration.widgets.some((widget) => widget.metric === "zoneEdgeBar")'), false);
  assert.match(ui.run('byId("template-note").textContent'), /Easy Run/);
});

test('a modified widget list is reported without changing the selected template', () => {
  const ui = panel();
  ui.run(`state.configuration = { templateId: 'easyRun', widgets: [{ id: 'hr', metric: 'heartRate' }] };
    renderWidgets();`);
  assert.match(ui.run('byId("template-note").textContent'), /modified/);
  assert.equal(ui.run('state.configuration.templateId'), 'easyRun');
});

test('duplicate handler enforces the capacity even when its row was created earlier', () => {
  const ui = panel();
  ui.run(`state.configuration.widgets = Array.from({length:16}, (_,i)=>({id:'w'+i,metric:'power'}));`);
  ui.rows[0].children[1].children[0].listeners.click();
  assert.equal(ui.run('state.configuration.widgets.length'), 16);
});
