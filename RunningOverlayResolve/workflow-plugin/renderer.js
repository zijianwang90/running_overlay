'use strict';
const state = { configuration: null, scan: null, fingerprint: null, busy: false, dirty: false, scanPaused: false, allowClose: false, captureDrafts: new Map(), anchorDrafts: new Map() };
const time = window.RunningOverlayTime;
const { createTimePicker, zoneSelect } = window.runningOverlayPickers;
const byId = (id) => document.getElementById(id);
const METRIC_NAMES = { heartRate: 'Heart rate', pace: 'Pace', distance: 'Distance', elapsed: 'Elapsed time' };
function status(id, text, tone = 'muted') { const element = byId(id); element.className = `status-card ${tone}`; element.textContent = text; }
function busy(value) {
  state.busy = value;
  for (const button of document.querySelectorAll('button, input, select')) button.disabled = value;
  byId('build-bundle').disabled = value || state.scanPaused || !state.configuration?.activity || !state.scan;
  if (!value && state.configuration) renderWidgets();
  if (!value) for (const row of document.querySelectorAll('.clip-row')) row.querySelector('.capture-confirmed').disabled = !row.timePicker.valid();
  byId('use-capture-zone').disabled = value || !state.configuration?.captureTimeZone;
}
function markDirty(message = 'Settings changed. Save settings or Create / Update.') {
  state.dirty = true; status('build-status', message, 'warning');
}
function collect(strict = false) {
  if (!state.configuration) return;
  const confirmed = { ...state.configuration.confirmedCaptureUtcByMediaId };
  const zones = { ...state.configuration.captureTimeZonesByMediaId };
  for (const row of document.querySelectorAll('.clip-row')) {
    if (row.querySelector('.capture-confirmed').checked) confirmed[row.dataset.mediaId] = row.timePicker.readISO();
    else delete confirmed[row.dataset.mediaId];
    if (row.timePicker.hasZone()) zones[row.dataset.mediaId] = row.timePicker.readTimeZone();
    else delete zones[row.dataset.mediaId];
  }
  const anchors = { ...state.configuration.cameraAnchors };
  for (const row of document.querySelectorAll('.camera-row')) {
    try {
      anchors[row.dataset.cameraGroup] = [...row.querySelectorAll('.anchor-pair')].filter((pair) => !pair.cameraPicker.isEmpty() || !pair.activityPicker.isEmpty()).map((pair) => ({
        cameraTime: pair.cameraPicker.readISO(), activityTime: pair.activityPicker.readISO(),
        cameraTimeZone: pair.cameraPicker.readTimeZone(), activityTimeZone: pair.activityPicker.readTimeZone(),
      }));
    } catch (error) { if (strict) throw new Error(`${row.dataset.cameraGroup} clock pair: ${error.message}`); }
  }
  Object.assign(state.configuration, { confirmedCaptureUtcByMediaId: confirmed, captureTimeZonesByMediaId: zones, cameraAnchors: anchors, referenceVideoTrackIndex: Number(byId('track-index').value) });
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
function renderCaptureTimes() {
  const config = state.configuration;
  const recordingZone = zoneSelect(config.captureTimeZone, 'Recording timezone for filename dates'); recordingZone.id = 'capture-zone';
  byId('capture-zone').replaceWith(recordingZone);
  recordingZone.addEventListener('change', () => {
    config.captureTimeZone = recordingZone.value || null;
    if (config.captureTimeZone) for (const row of document.querySelectorAll('.clip-row')) {
      if (row.dataset.timeKind !== 'absolute' && !row.timePicker.hasZone() && !row.querySelector('.capture-confirmed').checked) row.timePicker.setZone(config.captureTimeZone);
    }
    byId('use-capture-zone').disabled = !config.captureTimeZone; markDirty();
  });
  const list = byId('clip-list'); list.replaceChildren();
  const seen = new Set();
  for (const item of state.scan.timeline.items) {
    if (seen.has(item.mediaId)) continue;
    seen.add(item.mediaId);
    const media = state.scan.mediaById[item.mediaId];
    const row = document.createElement('div'); row.className = 'clip-row'; row.dataset.mediaId = item.mediaId;
    const name = document.createElement('div'); name.className = 'clip-name'; name.textContent = item.name;
    const saved = config.confirmedCaptureUtcByMediaId[item.mediaId];
    const candidate = media.captureTimeCandidates?.[0];
    const draft = state.captureDrafts.get(item.mediaId);
    const iso = saved ?? (candidate ? new Date(candidate.instantUtcUs / 1000).toISOString() : undefined);
    row.dataset.timeKind = draft?.kind ?? (iso ? 'absolute' : media.filenameCaptureTime ? 'filename' : 'manual');
    const label = document.createElement('label'); label.className = 'confirm-label';
    const check = document.createElement('input'); check.type = 'checkbox'; check.className = 'capture-confirmed'; check.checked = Boolean(saved);
    const picker = createTimePicker({ label: 'Original recording start', iso, parts: !iso ? media.filenameCaptureTime : undefined,
      zone: config.captureTimeZonesByMediaId[item.mediaId] ?? (saved ? time.offsetZoneForISO(saved) : config.captureTimeZone), draft: draft?.picker,
      onChange: (value) => {
        check.checked = false; check.disabled = !value.valid();
        row.dataset.timeKind = row.dataset.timeKind === 'filename' ? 'filename' : 'manual';
        state.captureDrafts.set(item.mediaId, { kind: row.dataset.timeKind, picker: value.draft() });
        markDirty('Capture time changed. Review and confirm it before applying.');
      },
    });
    row.timePicker = picker; check.disabled = !picker.valid();
    check.addEventListener('change', () => markDirty());
    label.append(check, document.createTextNode(' Confirm capture start'));
    const evidence = document.createElement('div'); evidence.className = 'clip-evidence';
    evidence.textContent = item.mappingIssue ?? (saved ? 'Saved confirmed capture time.' : candidate ? `Time from ${candidate.source}; verify its recording-time meaning.` : media.filenameCaptureTime ? 'Date and clock time detected in the source filename. Choose its timezone and confirm this is the start of recording.' : 'No filename date found. Choose the original recording date, time and timezone.');
    row.append(name, picker.element, label, evidence); list.appendChild(row);
  }
}
function renderCameraAnchors() {
  const config = state.configuration;
  const cameras = byId('camera-list'); cameras.replaceChildren();
  for (const group of new Set(state.scan.timeline.items.map((item) => item.cameraGroupId))) {
    const row = document.createElement('div'); row.className = 'camera-row'; row.dataset.cameraGroup = group;
    const label = document.createElement('div'); label.className = 'camera-name'; label.textContent = group; row.appendChild(label);
    for (let index = 0; index < 2; index++) {
      const pair = document.createElement('div'); pair.className = 'anchor-pair';
      const heading = document.createElement('div'); heading.className = 'anchor-heading'; heading.textContent = `Clock pair ${index + 1}`;
      const anchor = config.cameraAnchors[group]?.[index]; const draftKey = JSON.stringify([group, index]); const draft = state.anchorDrafts.get(draftKey);
      const changed = () => { state.anchorDrafts.set(draftKey, { camera: pair.cameraPicker.draft(), activity: pair.activityPicker.draft() }); markDirty(); };
      pair.cameraPicker = createTimePicker({ label: 'Camera clock', iso: anchor?.cameraTime, zone: anchor?.cameraTimeZone ?? (anchor ? undefined : config.captureTimeZone), draft: draft?.camera, onChange: changed });
      pair.activityPicker = createTimePicker({ label: 'Activity clock — same instant', iso: anchor?.activityTime, zone: anchor?.activityTimeZone ?? (anchor ? undefined : config.captureTimeZone ?? 'UTC'), draft: draft?.activity, onChange: changed });
      const clear = document.createElement('button'); clear.className = 'secondary'; clear.type = 'button'; clear.textContent = 'Clear pair'; clear.addEventListener('click', () => { pair.cameraPicker.clear(); pair.activityPicker.clear(); });
      heading.appendChild(clear); pair.append(heading, pair.cameraPicker.element, pair.activityPicker.element); row.appendChild(pair);
    }
    cameras.appendChild(row);
  }
}
function render() {
  const config = state.configuration;
  byId('track-index').value = config.referenceVideoTrackIndex;
  status('activity-status', config.activity ? `${config.activity.records.length} records · ${Math.round((config.activity.endUtcUs - config.activity.startUtcUs) / 60000000)} min` : 'No activity loaded', config.activity ? 'good' : 'muted');
  renderCaptureTimes(); renderCameraAnchors();
  const errors = state.scan.diagnostics.filter((entry) => entry.severity !== 'info');
  status('timeline-status', `${state.scan.timeline.timelineName} · ${state.scan.timeline.items.length} clips${errors.length ? '\n' + errors.map((entry) => entry.message).join('\n') : ''}`, errors.length ? 'warning' : 'good');
  busy(false);
}
async function save() {
  collect(true);
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
    if (changedContext || restore) { state.configuration = result.configuration; state.captureDrafts.clear(); state.anchorDrafts.clear(); state.dirty = false; }
    state.scan = result.scan; state.fingerprint = result.fingerprint;
    if (!silent || changed || changedContext) render();
    if (changedContext) status('build-status', result.configuration.lastAppliedFingerprint ? 'Saved settings restored. Scan to check synchronization.' : 'Settings restored. Ready to synchronize.');
    if (result.stale || state.dirty) status('build-status', state.configuration.managedItemId ? 'Overlay needs synchronization. Create / Update refreshes its data and preserves its style.' : 'Ready to create a live overlay.', 'warning');
    else if (changed || !silent || resumed) status('build-status', 'Overlay is synchronized.', 'good');
  } catch (error) { state.scan = null; status('timeline-status', error.message, 'error'); }
  finally { busy(false); }
}
window.addEventListener('DOMContentLoaded', () => {
  byId('minimize-window').addEventListener('click', () => window.runningOverlayAPI.minimizeWindow());
  byId('close-window').addEventListener('click', async () => {
    if (state.busy || (state.dirty && !window.confirm('Close without saving your panel changes?'))) return;
    state.allowClose = true; await window.runningOverlayAPI.closeWindow();
  });
  byId('use-capture-zone').addEventListener('click', () => {
    const zone = state.configuration.captureTimeZone; if (!zone) return;
    for (const row of document.querySelectorAll('.clip-row')) {
      if (row.dataset.timeKind !== 'absolute' && !row.querySelector('.capture-confirmed').checked) row.timePicker.setZone(zone);
    }
  });
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
      collect(true);
      if (state.configuration.activity?.activityId !== result.activity.activityId) { state.configuration.cameraAnchors = {}; state.anchorDrafts.clear(); }
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
  byId('track-index').addEventListener('input', () => markDirty());
  byId('build-bundle').addEventListener('click', async () => {
    busy(true);
    try {
      collect(true); status('build-status', 'Checking the current timeline and updating the overlay…');
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
  if (!state.allowClose && (state.dirty || state.busy)) { event.preventDefault(); event.returnValue = false; }
});
