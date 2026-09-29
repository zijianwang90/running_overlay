'use strict';
const state = { configuration: null, scan: null, fingerprint: null, busy: false, dirty: false, scanPaused: false };
const byId = (id) => document.getElementById(id);
const METRIC_NAMES = { heartRate: 'Heart rate', pace: 'Pace', distance: 'Distance', elapsed: 'Elapsed time' };
function status(id, text, tone = 'muted') { const element = byId(id); element.className = `status-card ${tone}`; element.textContent = text; }
function busy(value) {
  state.busy = value;
  for (const button of document.querySelectorAll('button, input, select')) button.disabled = value;
  byId('build-bundle').disabled = value || state.scanPaused || !state.configuration?.activity || !state.scan;
  if (!value && state.configuration) renderWidgets();
}
function input(value, placeholder, className) {
  const element = document.createElement('input'); element.type = 'text'; element.value = value ?? ''; element.placeholder = placeholder; element.className = className; return element;
}
function collect() {
  if (!state.configuration) return;
  const confirmed = { ...state.configuration.confirmedCaptureUtcByMediaId };
  for (const row of document.querySelectorAll('.clip-row')) {
    if (row.querySelector('.capture-confirmed').checked) confirmed[row.dataset.mediaId] = row.querySelector('.capture-input').value.trim();
    else delete confirmed[row.dataset.mediaId];
  }
  const anchors = { ...state.configuration.cameraAnchors };
  for (const row of document.querySelectorAll('.camera-row')) {
    anchors[row.dataset.cameraGroup] = [...row.querySelectorAll('.anchor-pair')].map((pair) => ({ cameraTime: pair.children[0].value.trim(), activityTime: pair.children[1].value.trim() })).filter((anchor) => anchor.cameraTime || anchor.activityTime);
  }
  Object.assign(state.configuration, { confirmedCaptureUtcByMediaId: confirmed, cameraAnchors: anchors, referenceVideoTrackIndex: Number(byId('track-index').value) });
}
function widgetsChanged() {
  state.dirty = true;
  status('build-status', 'Widget layout changed. Create / Update to apply it.', 'warning');
  renderWidgets();
}
function renderWidgets() {
  const widgets = state.configuration.widgets;
  byId('layout-preset').value = state.configuration.layoutPreset;
  const list = byId('widget-list'); list.replaceChildren();
  widgets.forEach((widget, index) => {
    const row = document.createElement('div'); row.className = 'widget-row'; row.dataset.widgetId = widget.id;
    const order = document.createElement('span'); order.className = 'widget-order'; order.textContent = String(index + 1);
    const name = document.createElement('span'); name.textContent = METRIC_NAMES[widget.metric];
    row.append(order, name);
    for (const [action, label, disabled] of [['up', '↑', index === 0], ['down', '↓', index === widgets.length - 1], ['remove', 'Remove', widgets.length === 1]]) {
      const button = document.createElement('button'); button.type = 'button'; button.className = 'secondary';
      button.dataset.action = action; button.textContent = label; button.disabled = disabled; row.appendChild(button);
    }
    list.appendChild(row);
  });
  const available = Object.entries(METRIC_NAMES).filter(([metric]) => !widgets.some((widget) => widget.metric === metric));
  const picker = byId('add-widget-metric'); picker.replaceChildren();
  for (const [metric, name] of available) {
    const option = document.createElement('option'); option.value = metric; option.textContent = name; picker.appendChild(option);
  }
  picker.disabled = available.length === 0;
  byId('add-widget').disabled = available.length === 0;
}
function render() {
  const config = state.configuration;
  byId('track-index').value = config.referenceVideoTrackIndex;
  status('activity-status', config.activity ? `${config.activity.records.length} records · ${Math.round((config.activity.endUtcUs - config.activity.startUtcUs) / 60000000)} min` : 'No activity loaded', config.activity ? 'good' : 'muted');
  const list = byId('clip-list'); list.replaceChildren();
  const seen = new Set();
  for (const item of state.scan.timeline.items) {
    if (seen.has(item.mediaId)) continue;
    seen.add(item.mediaId);
    const media = state.scan.mediaById[item.mediaId];
    const row = document.createElement('div'); row.className = 'clip-row'; row.dataset.mediaId = item.mediaId;
    const name = document.createElement('div'); name.className = 'clip-name'; name.textContent = item.name;
    const candidate = media.captureTimeCandidates?.[0];
    const field = input(config.confirmedCaptureUtcByMediaId[item.mediaId] ?? (candidate ? new Date(candidate.instantUtcUs / 1000).toISOString() : ''), 'YYYY-MM-DDTHH:mm:ssZ', 'capture-input');
    const label = document.createElement('label'); const check = document.createElement('input'); check.type = 'checkbox'; check.className = 'capture-confirmed'; check.checked = Boolean(config.confirmedCaptureUtcByMediaId[item.mediaId]);
    label.append(check, document.createTextNode(' Confirm capture start'));
    const evidence = document.createElement('div'); evidence.className = 'clip-evidence'; evidence.textContent = item.mappingIssue ?? (candidate ? `Candidate: ${candidate.source}. Confirm its recording-time meaning.` : 'Enter the capture start of the original source, including its timezone.');
    row.append(name, field, label, evidence); list.appendChild(row);
  }
  const cameras = byId('camera-list'); cameras.replaceChildren();
  for (const group of new Set(state.scan.timeline.items.map((item) => item.cameraGroupId))) {
    const row = document.createElement('div'); row.className = 'camera-row'; row.dataset.cameraGroup = group;
    const label = document.createElement('div'); label.textContent = group; row.appendChild(label);
    for (let index = 0; index < 2; index++) {
      const pair = document.createElement('div'); pair.className = 'anchor-pair';
      const anchor = config.cameraAnchors[group]?.[index];
      pair.append(input(anchor?.cameraTime, 'Camera time (ISO + timezone)', ''), input(anchor?.activityTime, 'Matching activity time (ISO + timezone)', '')); row.appendChild(pair);
    }
    cameras.appendChild(row);
  }
  const errors = state.scan.diagnostics.filter((entry) => entry.severity !== 'info');
  status('timeline-status', `${state.scan.timeline.timelineName} · ${state.scan.timeline.items.length} clips${errors.length ? '\n' + errors.map((entry) => entry.message).join('\n') : ''}`, errors.length ? 'warning' : 'good');
  busy(false);
}
async function save() {
  collect();
  state.configuration = await window.runningOverlayAPI.saveConfiguration(state.configuration);
  state.dirty = false;
}
async function scan({ restore = false, silent = false } = {}) {
  if (state.busy) return;
  busy(true);
  try {
    if (state.configuration) collect();
    const result = await window.runningOverlayAPI.scanTimeline({ trackIndex: restore ? undefined : Number(byId('track-index').value), contextId: state.configuration?.contextId });
    if (result.paused) {
      state.scanPaused = true;
      status('build-status', 'Resolve is rendering. Synchronization checks resume after export.', 'warning');
      return;
    }
    const resumed = state.scanPaused;
    state.scanPaused = false;
    const changedContext = state.configuration?.contextId !== result.contextId;
    const changed = state.fingerprint !== result.fingerprint;
    if (changedContext || restore) state.configuration = result.configuration;
    state.scan = result.scan; state.fingerprint = result.fingerprint;
    if (!silent || changed || changedContext) render();
    if (changedContext) status('build-status', result.configuration.lastAppliedFingerprint ? 'Saved settings restored. Scan to check synchronization.' : 'Settings restored. Ready to synchronize.');
    if (result.stale || state.dirty) status('build-status', state.configuration.managedItemId ? 'Overlay needs synchronization. Create / Update refreshes its data and preserves its style.' : 'Ready to create a live overlay.', 'warning');
    else if (changed || !silent || resumed) status('build-status', 'Overlay is synchronized.', 'good');
  } catch (error) { state.scan = null; status('timeline-status', error.message, 'error'); }
  finally { busy(false); }
}
window.addEventListener('DOMContentLoaded', () => {
  byId('layout-preset').addEventListener('change', () => {
    state.configuration.layoutPreset = byId('layout-preset').value;
    widgetsChanged();
  });
  byId('add-widget').addEventListener('click', () => {
    const metric = byId('add-widget-metric').value;
    if (!metric) return;
    state.configuration.widgets.push({ id: `numeric-${crypto.randomUUID()}`, metric });
    widgetsChanged();
  });
  byId('widget-list').addEventListener('click', (event) => {
    const button = event.target.closest('button[data-action]');
    if (!button) return;
    const widgets = state.configuration.widgets;
    const index = widgets.findIndex((widget) => widget.id === button.closest('.widget-row').dataset.widgetId);
    if (index < 0) return;
    if (button.dataset.action === 'remove' && widgets.length > 1) widgets.splice(index, 1);
    else if (button.dataset.action === 'up' && index > 0) [widgets[index - 1], widgets[index]] = [widgets[index], widgets[index - 1]];
    else if (button.dataset.action === 'down' && index < widgets.length - 1) [widgets[index], widgets[index + 1]] = [widgets[index + 1], widgets[index]];
    else return;
    widgetsChanged();
  });
  byId('choose-activity').addEventListener('click', async () => {
    busy(true);
    try {
      const result = await window.runningOverlayAPI.chooseActivity();
      if (!result) return;
      if (!state.configuration) throw new Error('Scan an open Resolve timeline first.');
      collect();
      if (state.configuration.activity?.activityId !== result.activity.activityId) state.configuration.cameraAnchors = {};
      state.configuration.activity = result.activity;
      state.configuration = await window.runningOverlayAPI.saveConfiguration(state.configuration);
      render(); status('build-status', 'Activity saved. Create / Update to synchronize.', 'warning');
    } catch (error) { status('activity-status', error.message, 'error'); }
    finally { busy(false); }
  });
  byId('scan-timeline').addEventListener('click', () => scan());
  byId('save-settings').addEventListener('click', async () => {
    busy(true); try { await save(); status('build-status', 'Settings saved. Create / Update to apply changes.', 'warning'); }
    catch (error) { status('build-status', error.message, 'error'); } finally { busy(false); }
  });
  for (const id of ['clip-list', 'camera-list', 'track-index']) byId(id).addEventListener('input', () => {
    state.dirty = true; status('build-status', 'Settings changed. Save settings or Create / Update.', 'warning');
  });
  byId('build-bundle').addEventListener('click', async () => {
    busy(true);
    try {
      collect(); status('build-status', 'Checking the current timeline and updating the overlay…');
      const result = await window.runningOverlayAPI.applyOverlay({ configuration: state.configuration, expectedFingerprint: state.fingerprint });
      state.configuration = result.configuration; state.dirty = false;
      status('build-status', `${result.segmentCount} segments synchronized. Adjust widgets in Fusion; save your Resolve project to keep the composition.`, 'good');
    } catch (error) { status('build-status', error.message, 'error'); }
    finally { busy(false); }
  });
  // Read-only polling while the panel is open. Never rebuild or alter a timeline automatically.
  // Wait after completion: a slow host scan must not cause continuous scanning.
  async function poll() {
    try { if (!state.dirty && !document.hidden) await scan({ silent: true }); }
    finally { window.setTimeout(poll, 8000); }
  }
  scan({ restore: true }).finally(() => window.setTimeout(poll, 8000));
});
window.addEventListener('beforeunload', (event) => {
  if (state.dirty || state.busy) { event.preventDefault(); event.returnValue = false; }
});
