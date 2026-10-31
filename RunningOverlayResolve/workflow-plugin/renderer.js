'use strict';
const state = {
  configuration: null, scan: null, tracks: [], fingerprint: null, stale: true,
  timeOffset: { seconds: 0, source: 'draft', animated: false },
  busy: false, scanning: false, dirty: false, scanPaused: false, allowClose: false, autoTrackTried: false,
  zoneInferred: false, saveTimer: null, captureDrafts: new Map(), anchorDrafts: new Map(),
  offset: { pending: null, inFlight: false, activeUntil: 0 },
};
const api = window.runningOverlayAPI;
const time = window.RunningOverlayTime;
const alignment = window.RunningOverlayAlignment;
const { createTimePicker, zoneSelect } = window.runningOverlayPickers;
const byId = (id) => document.getElementById(id);
const METRICS = [['heartRate', 'Heart rate'], ['pace', 'Pace'], ['distance', 'Distance'], ['elapsed', 'Time'], ['elevation', 'Elevation'], ['cadence', 'Cadence'], ['power', 'Power'], ['calories', 'Calories']];
const OVERLAY_TRACK = 'Running Overlay';
const plural = (count, word) => `${count} ${word}${count === 1 ? '' : 's'}`;

function setStatus(text, tone = '') { const element = byId('build-status'); element.className = `note ${tone}`; element.textContent = text; }
function setBusy(value) {
  state.busy = value;
  for (const id of ['primary-action', 'choose-activity', 'refresh']) byId(id).disabled = value;
}
function offsetBusy() { return state.offset.inFlight || state.offset.pending !== null || Date.now() < state.offset.activeUntil; }

// ---- Configuration persistence -------------------------------------------------
// Edits save automatically; the primary button only applies them to Resolve.
function collect(strict = false) {
  const config = state.configuration;
  if (!config || !state.scan) return;
  const confirmed = { ...config.confirmedCaptureUtcByMediaId };
  const zones = { ...config.captureTimeZonesByMediaId };
  for (const row of document.querySelectorAll('.clip-row')) {
    if (row.querySelector('.capture-confirmed').checked) confirmed[row.dataset.mediaId] = row.timePicker.readISO();
    else delete confirmed[row.dataset.mediaId];
    if (row.timePicker.hasZone()) zones[row.dataset.mediaId] = row.timePicker.readTimeZone();
    else delete zones[row.dataset.mediaId];
  }
  const anchors = { ...config.cameraAnchors };
  for (const row of document.querySelectorAll('.camera-row')) {
    try {
      anchors[row.dataset.cameraGroup] = [...row.querySelectorAll('.anchor-pair')].filter((pair) => !pair.cameraPicker.isEmpty() || !pair.activityPicker.isEmpty()).map((pair) => ({
        cameraTime: pair.cameraPicker.readISO(), activityTime: pair.activityPicker.readISO(),
        cameraTimeZone: pair.cameraPicker.readTimeZone(), activityTimeZone: pair.activityPicker.readTimeZone(),
      }));
    } catch (error) { if (strict) throw new Error(`${row.dataset.cameraGroup} clock pair: ${error.message}`); }
  }
  Object.assign(config, { confirmedCaptureUtcByMediaId: confirmed, captureTimeZonesByMediaId: zones, cameraAnchors: anchors });
}
function scheduleSave(delay = 500) {
  if (!state.configuration) return;
  state.dirty = true; window.clearTimeout(state.saveTimer);
  state.saveTimer = window.setTimeout(saveNow, delay);
  renderPrimary();
}
async function saveNow() {
  state.saveTimer = null;
  if (!state.configuration) return;
  try {
    collect();
    const saved = await api.saveConfiguration(state.configuration);
    // A newer edit is already queued; it will save the current panel state.
    if (state.saveTimer) return;
    state.configuration = saved; state.dirty = false;
    if (!saved.lastAppliedFingerprint) state.stale = true;
  } catch (error) { setStatus(error.message, 'error'); }
  renderPrimary();
}

// ---- Capture times -------------------------------------------------------------
function uniqueMedia() {
  const seen = new Map();
  for (const item of state.scan?.timeline.items ?? []) if (!seen.has(item.mediaId)) seen.set(item.mediaId, item);
  return [...seen.values()];
}
function zoneFor(mediaId) { return state.configuration.captureTimeZonesByMediaId[mediaId] ?? state.configuration.captureTimeZone; }
function candidateISO(mediaId) {
  const media = state.scan.mediaById[mediaId];
  const absolute = media.captureTimeCandidates?.[0];
  if (absolute) return new Date(absolute.instantUtcUs / 1000).toISOString();
  const zone = zoneFor(mediaId);
  if (!media.filenameCaptureTime || !zone) return null;
  try { return time.toISO(media.filenameCaptureTime, zone); } catch { return null; }
}
function captureState() {
  const result = { confirmed: 0, available: 0, missing: 0, total: 0, captureMs: {} };
  for (const item of uniqueMedia()) {
    result.total++;
    const saved = state.configuration.confirmedCaptureUtcByMediaId[item.mediaId];
    const iso = saved ?? candidateISO(item.mediaId);
    if (saved) result.confirmed++; else if (iso) result.available++; else result.missing++;
    if (iso) result.captureMs[item.mediaId] = Date.parse(iso);
  }
  return result;
}
// Accepting file times is an explicit, reviewable coarse alignment; the data
// timing offset then corrects the shared camera clock difference.
function useFileTimes() {
  collect();
  const config = state.configuration; let skipped = 0;
  for (const item of uniqueMedia()) {
    if (config.confirmedCaptureUtcByMediaId[item.mediaId]) continue;
    const iso = candidateISO(item.mediaId);
    if (iso) config.confirmedCaptureUtcByMediaId[item.mediaId] = iso; else skipped++;
  }
  state.captureDrafts.clear();
  renderClipDetails(); renderAlignment(); scheduleSave(0);
  if (skipped) { byId('clip-details').open = true; setStatus(`${plural(skipped, 'file')} still need a recording time in Clip details.`, 'warning'); }
  else setStatus('File times accepted as a starting point. Create the overlay, then fine-tune Data timing.', 'good');
}
function ensureZone() {
  const config = state.configuration;
  if (!config?.activity || config.captureTimeZone || !state.scan) return;
  const wallParts = uniqueMedia().map((item) => state.scan.mediaById[item.mediaId].filenameCaptureTime).filter(Boolean);
  const zone = alignment.inferRecordingZone({ wallParts, activityStartMs: config.activity.startUtcUs / 1000, activityEndMs: config.activity.endUtcUs / 1000,
    preferredZones: [Intl.DateTimeFormat().resolvedOptions().timeZone] });
  if (!zone) return;
  config.captureTimeZone = zone; state.zoneInferred = true; scheduleSave();
}
function renderZone() {
  const config = state.configuration;
  const select = zoneSelect(config.captureTimeZone, 'Recording timezone'); select.id = 'capture-zone';
  byId('capture-zone').replaceWith(select);
  select.addEventListener('change', () => {
    collect();
    // Saves replace the configuration object, so never use a captured reference here.
    const zone = select.value || null;
    state.configuration.captureTimeZone = zone; state.zoneInferred = false;
    if (zone) for (const row of document.querySelectorAll('.clip-row')) {
      if (row.dataset.timeKind !== 'absolute' && !row.querySelector('.capture-confirmed').checked) row.timePicker.setZone(zone);
    }
    renderZoneNote(); renderAlignment(); scheduleSave();
  });
  renderZoneNote();
}
function renderZoneNote() {
  const config = state.configuration; const note = byId('zone-note');
  const hasFilenameTimes = uniqueMedia().some((item) => state.scan.mediaById[item.mediaId].filenameCaptureTime);
  if (!hasFilenameTimes) note.textContent = '';
  else if (state.zoneInferred) note.textContent = 'Detected from your activity. Change it if the camera clock used another zone.';
  else if (!config.captureTimeZone) note.textContent = 'Choose the zone the camera clock was set to.';
  else note.textContent = '';
}
function renderClipDetails() {
  const config = state.configuration;
  const list = byId('clip-list'); list.replaceChildren();
  const media = uniqueMedia();
  if (!media.length) { const empty = document.createElement('div'); empty.className = 'empty-state'; empty.textContent = 'No clips on this track.'; list.appendChild(empty); }
  for (const item of media) {
    const source = state.scan.mediaById[item.mediaId];
    const row = document.createElement('div'); row.className = 'clip-row'; row.dataset.mediaId = item.mediaId;
    const name = document.createElement('div'); name.className = 'clip-name'; name.textContent = item.name;
    const saved = config.confirmedCaptureUtcByMediaId[item.mediaId];
    const candidate = source.captureTimeCandidates?.[0];
    const draft = state.captureDrafts.get(item.mediaId);
    const iso = saved ?? (candidate ? new Date(candidate.instantUtcUs / 1000).toISOString() : undefined);
    row.dataset.timeKind = draft?.kind ?? (iso ? 'absolute' : source.filenameCaptureTime ? 'filename' : 'manual');
    const label = document.createElement('label'); label.className = 'confirm-label';
    const check = document.createElement('input'); check.type = 'checkbox'; check.className = 'capture-confirmed'; check.checked = Boolean(saved);
    const picker = createTimePicker({ label: 'Original recording start', iso, parts: !iso ? source.filenameCaptureTime : undefined,
      zone: config.captureTimeZonesByMediaId[item.mediaId] ?? (saved ? time.offsetZoneForISO(saved) : config.captureTimeZone), draft: draft?.picker,
      onChange: (value) => {
        check.checked = false; check.disabled = !value.valid();
        row.dataset.timeKind = row.dataset.timeKind === 'filename' ? 'filename' : 'manual';
        state.captureDrafts.set(item.mediaId, { kind: row.dataset.timeKind, picker: value.draft() });
        collect(); renderAlignment(); scheduleSave();
      },
    });
    row.timePicker = picker; check.disabled = !picker.valid();
    check.addEventListener('change', () => { collect(); renderAlignment(); scheduleSave(); });
    label.append(check, document.createTextNode(' Use this recording start'));
    const evidence = document.createElement('div'); evidence.className = 'clip-evidence';
    evidence.textContent = item.mappingIssue ?? (saved ? 'In use.' : candidate ? `Time from ${candidate.source}; verify its recording-time meaning.` : source.filenameCaptureTime ? 'Clock time from the file name.' : 'No time found. Choose the original recording date, time and timezone.');
    row.append(name, picker.element, label, evidence); list.appendChild(row);
  }
  renderCameraAnchors();
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
      const changed = () => { state.anchorDrafts.set(draftKey, { camera: pair.cameraPicker.draft(), activity: pair.activityPicker.draft() }); scheduleSave(); };
      pair.cameraPicker = createTimePicker({ label: 'Camera clock', iso: anchor?.cameraTime, zone: anchor?.cameraTimeZone ?? (anchor ? undefined : config.captureTimeZone), draft: draft?.camera, onChange: changed });
      pair.activityPicker = createTimePicker({ label: 'Activity clock — same instant', iso: anchor?.activityTime, zone: anchor?.activityTimeZone ?? (anchor ? undefined : config.captureTimeZone ?? 'UTC'), draft: draft?.activity, onChange: changed });
      const clear = document.createElement('button'); clear.className = 'secondary'; clear.type = 'button'; clear.textContent = 'Clear pair'; clear.addEventListener('click', () => { pair.cameraPicker.clear(); pair.activityPicker.clear(); });
      heading.appendChild(clear); pair.append(heading, pair.cameraPicker.element, pair.activityPicker.element); row.appendChild(pair);
    }
    cameras.appendChild(row);
  }
}

// ---- Alignment preview and timing offset ---------------------------------------
function formatClock(seconds) {
  const sign = seconds < 0 ? '−' : ''; const total = Math.round(Math.abs(seconds));
  return `${sign}${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}
function renderStrip() {
  const config = state.configuration; const activity = config?.activity;
  const activityBar = byId('strip-activity'); const clips = byId('strip-clips'); clips.replaceChildren();
  if (!activity || !state.scan) { activityBar.style.width = '0'; return []; }
  const spans = alignment.clipSpans({ items: state.scan.timeline.items, captureMsByMediaId: captureState().captureMs,
    activityStartMs: activity.startUtcUs / 1000, activityEndMs: activity.endUtcUs / 1000,
    frameRate: state.scan.timeline.frameRate, offsetSeconds: state.timeOffset.seconds }).filter((span) => span.known);
  const duration = (activity.endUtcUs - activity.startUtcUs) / 1e6;
  let low = 0; let high = duration;
  for (const span of spans) { low = Math.min(low, span.start); high = Math.max(high, span.end); }
  const pad = (high - low) * 0.02 || 1; low -= pad; high += pad;
  const percent = (value) => `${((value - low) / (high - low) * 100).toFixed(3)}%`;
  activityBar.style.left = percent(0); activityBar.style.width = `${(duration / (high - low) * 100).toFixed(3)}%`;
  activityBar.title = `Activity · ${formatClock(duration)}`;
  for (const span of spans) {
    const block = document.createElement('div'); block.className = `strip-clip${span.overlapsActivity ? '' : ' outside'}`;
    block.style.left = percent(span.start); block.style.width = `${((span.end - span.start) / (high - low) * 100).toFixed(3)}%`;
    block.title = `${span.name} · activity ${formatClock(span.start)}–${formatClock(span.end)}`;
    clips.appendChild(block);
  }
  byId('strip-caption').textContent = `Clips on V${state.scan.timeline.referenceVideoTrackIndex}`;
  return spans;
}
function renderAlignment() {
  const config = state.configuration;
  if (!config || !state.scan) return;
  const captures = captureState(); const spans = renderStrip();
  const outside = spans.filter((span) => !span.overlapsActivity).length;
  let badge = ['Matched', 'good']; let summary;
  if (!config.activity) { badge = ['Waiting', 'muted']; summary = 'Choose an activity to compare times.'; }
  else if (!captures.total) { badge = ['No clips', 'muted']; summary = 'Choose a video track with clips.'; }
  else if (captures.available) { badge = ['Review', 'warning']; summary = `${captures.available} of ${plural(captures.total, 'file')} have a detected time. Check the timezone and the strip below, then choose Use file times.`; }
  else if (captures.missing) { badge = ['Needs times', 'warning']; summary = `${captures.missing} of ${plural(captures.total, 'file')} have no recording time. Set them in Clip details.`; }
  else if (outside) { badge = ['Check', 'warning']; summary = `${plural(outside, 'clip')} fall outside the activity. Check the timezone or date.`; }
  else summary = `All ${plural(captures.total, 'file')} sit inside the activity. Fine-tune with Data timing.`;
  const element = byId('align-badge'); element.textContent = badge[0]; element.className = `badge ${badge[1]}`;
  byId('align-summary').textContent = summary;
  byId('clip-count').textContent = `(${captures.total})`;
  renderPrimary();
}
function renderOffset() {
  const offset = state.timeOffset; const seconds = offset.seconds;
  byId('offset-value').textContent = `${seconds > 0 ? '+' : ''}${seconds.toFixed(3)} s`;
  if (document.activeElement !== byId('offset-slider')) byId('offset-slider').value = String(Math.max(-30, Math.min(30, seconds)));
  if (document.activeElement !== byId('offset-input')) byId('offset-input').value = seconds.toFixed(3);
  const locked = offset.animated || offset.source === 'unavailable';
  byId('offset-group').classList.toggle('disabled', locked);
  for (const element of byId('offset-group').querySelectorAll('button, input')) element.disabled = locked;
  const hint = byId('offset-hint');
  hint.className = locked ? 'note warning' : 'note';
  if (offset.animated) hint.textContent = 'This offset is animated in Fusion. Edit its keyframes there.';
  else if (offset.source === 'unavailable') hint.textContent = `Timing can't be read from the overlay: ${offset.error}`;
  else if (offset.piece) hint.textContent = `Adjusting piece ${offset.piece.index} of ${offset.piece.count}, under the playhead. Other pieces keep their own timing.`;
  else if (offset.source === 'draft') hint.textContent = 'This starting offset is used when the overlay is created. After that, adjust it while watching the overlay in Resolve.';
  else hint.textContent = 'Play or park the playhead in Resolve on a clear moment, such as the start or a stop, and nudge until the numbers change when it happens on screen. The same offset is in the overlay\'s Fusion inspector.';
}
function setOffset(seconds) {
  if (!Number.isFinite(seconds)) return;
  const value = Math.round(Math.max(-86400, Math.min(86400, seconds)) * 1000) / 1000;
  state.timeOffset = { ...state.timeOffset, seconds: value };
  state.offset.activeUntil = Date.now() + 3000;
  renderOffset(); renderStrip();
  if (state.timeOffset.source === 'overlay') { state.offset.pending = value; pumpOffset(); }
  else { state.configuration.draftTimeOffsetMs = Math.round(value * 1000); scheduleSave(); }
}
// Latest value wins and only one write is in flight, so dragging never queues
// a backlog of Resolve calls.
// Scans are too slow to follow the playhead, so a cut overlay gets its own light poll.
async function followPlayhead() {
  try {
    const config = state.configuration;
    if (state.splitOverlay && !state.busy && !document.hidden && !offsetBusy()) {
      const result = await api.readPieceOffset({ contextId: config.contextId, managedItemId: config.managedItemId, pieceId: state.timeOffset.piece?.id ?? null });
      if (result && state.splitOverlay && !offsetBusy()) { state.timeOffset = result; renderOffset(); }
    }
  } catch { /* The next scan reports host errors. */ }
  finally { window.setTimeout(followPlayhead, 500); }
}
async function pumpOffset() {
  const offset = state.offset;
  if (offset.inFlight || offset.pending === null) return;
  const seconds = offset.pending; offset.pending = null; offset.inFlight = true;
  try {
    const config = state.configuration;
    const result = await api.setTimeOffset({ contextId: config.contextId, managedItemId: config.managedItemId, seconds });
    if (offset.pending === null) { state.timeOffset = result; renderOffset(); }
  } catch (error) { setStatus(error.message, 'error'); }
  finally {
    offset.inFlight = false; offset.activeUntil = Date.now() + 3000;
    if (offset.pending !== null) pumpOffset();
  }
}

// ---- Tracks, activity, widgets -------------------------------------------------
function renderActivity() {
  const config = state.configuration; const activity = config?.activity;
  byId('activity-name').textContent = activity ? (config.activityLabel || 'Activity') : 'No activity';
  byId('activity-meta').textContent = activity
    ? `${Math.round((activity.endUtcUs - activity.startUtcUs) / 60000000)} min · ${activity.records.length.toLocaleString()} records · starts ${new Date(activity.startUtcUs / 1000).toLocaleString()}`
    : 'Choose the FIT or GPX file recorded with this video.';
  byId('choose-activity').textContent = activity ? 'Change' : 'Choose';
}
function renderTracks() {
  const box = byId('track-chips'); box.replaceChildren();
  const selected = state.scan?.timeline.referenceVideoTrackIndex ?? state.configuration?.referenceVideoTrackIndex;
  for (const track of state.tracks) {
    const chip = document.createElement('button'); chip.type = 'button'; chip.className = 'chip'; chip.setAttribute('role', 'radio');
    const checked = track.index === selected; chip.setAttribute('aria-checked', String(checked));
    const custom = track.name && !/^Video \d+$/.test(track.name) ? ` · ${track.name}` : '';
    chip.textContent = `V${track.index}${custom} · ${plural(track.clipCount, 'clip')}`;
    chip.disabled = track.name === OVERLAY_TRACK && !checked;
    if (track.name === OVERLAY_TRACK) chip.title = 'This is the generated overlay track.';
    chip.addEventListener('click', () => {
      if (checked) return;
      state.configuration.referenceVideoTrackIndex = track.index; scheduleSave(); scan({ trackIndex: track.index });
    });
    box.appendChild(chip);
  }
  const status = byId('timeline-status');
  if (!state.scan) return;
  const errors = state.scan.diagnostics.filter((entry) => entry.severity !== 'info');
  status.className = errors.length ? 'note warning' : 'note';
  status.textContent = `${state.scan.timeline.timelineName}${errors.length ? `\n${errors.map((entry) => entry.message).join('\n')}` : ''}`;
}
function renderWidgets() {
  const config = state.configuration; const box = byId('metric-chips'); box.replaceChildren();
  for (const [metric, label] of METRICS) {
    const chip = document.createElement('button'); chip.type = 'button'; chip.className = 'chip'; chip.textContent = label;
    chip.setAttribute('aria-pressed', String(config.widgets.some((widget) => widget.metric === metric)));
    chip.addEventListener('click', () => toggleMetric(metric));
    box.appendChild(chip);
  }
  const list = document.createElement('div'); list.className = 'widget-instances';
  for (const widget of config.widgets) {
    const row = document.createElement('div'); row.className = 'card-row';
    const label = document.createElement('span'); label.textContent = METRICS.find(([metric]) => metric === widget.metric)[1];
    const actions = document.createElement('div');
    const duplicate = document.createElement('button'); duplicate.type = 'button'; duplicate.className = 'secondary'; duplicate.textContent = 'Duplicate'; duplicate.disabled = config.widgets.length >= 16;
    duplicate.addEventListener('click', () => {
      const current = state.configuration;
      if (current.widgets.length >= 16) return;
      current.widgets.push({ id: `numeric-${crypto.randomUUID()}`, metric: widget.metric });
      renderWidgets(); scheduleSave(); widgetsChanged();
    });
    const remove = document.createElement('button'); remove.type = 'button'; remove.className = 'secondary'; remove.textContent = 'Remove'; remove.disabled = config.widgets.length === 1;
    remove.addEventListener('click', () => {
      const current = state.configuration;
      if (current.widgets.length === 1) return;
      current.widgets = current.widgets.filter((candidate) => candidate.id !== widget.id);
      renderWidgets(); scheduleSave(); widgetsChanged();
    });
    actions.append(duplicate, remove); row.append(label, actions); list.appendChild(row);
  }
  box.appendChild(list);
  for (const button of document.querySelectorAll('[data-layout]')) {
    button.setAttribute('role', 'radio'); button.setAttribute('aria-checked', String(button.dataset.layout === config.layoutPreset));
  }
}
function toggleMetric(metric) {
  const config = state.configuration; const existing = config.widgets.find((widget) => widget.metric === metric);
  if (!existing && config.widgets.length >= 16) { setStatus('Keep at most sixteen widgets.', 'warning'); return; }
  if (existing && config.widgets.filter((widget) => widget.metric !== metric).length === 0) { setStatus('Keep at least one metric.', 'warning'); return; }
  const order = METRICS.map(([key]) => key);
  config.widgets = (existing ? config.widgets.filter((widget) => widget !== existing) : [...config.widgets, { id: `numeric-${crypto.randomUUID()}`, metric }])
    .sort((left, right) => order.indexOf(left.metric) - order.indexOf(right.metric));
  renderWidgets(); scheduleSave(); widgetsChanged();
}
function widgetsChanged() { if (state.configuration.managedItemId) setStatus('Widgets changed. Update the overlay to apply them.', 'warning'); }

// ---- Primary action ------------------------------------------------------------
function primaryState() {
  const config = state.configuration;
  if (!config || !state.scan) return { label: 'Scan timeline', run: () => scan() };
  if (state.splitOverlay) return { label: 'Overlay is cut · timing follows the playhead', run: () => scan(), quiet: true };
  if (!config.activity) return { label: 'Choose activity', run: chooseActivity };
  if (state.scan.diagnostics.some((entry) => entry.severity === 'error')) return { label: 'Scan again after fixing the timeline', run: () => scan(), quiet: true };
  const captures = captureState();
  if (!captures.total) return { label: 'Choose a track with clips', run: () => scan(), quiet: true };
  if (captures.available) return { label: 'Use file times', run: useFileTimes };
  if (captures.missing) return { label: `Set ${plural(captures.missing, 'recording time')}`, run: () => { byId('clip-details').open = true; byId('clip-details').scrollIntoView({ behavior: 'smooth' }); } };
  if (!config.managedItemId) return { label: 'Create overlay', run: applyOverlay };
  if (state.stale || state.dirty || !config.lastAppliedFingerprint) return { label: 'Update overlay', run: applyOverlay };
  return { label: 'Up to date', run: () => scan(), quiet: true };
}
function renderPrimary() {
  const action = primaryState(); const button = byId('primary-action');
  button.textContent = action.label; button.classList.toggle('quiet', Boolean(action.quiet));
  button.onclick = () => { if (!state.busy) action.run(); };
}
async function applyOverlay() {
  setBusy(true);
  const created = !state.configuration.managedItemId;
  try {
    window.clearTimeout(state.saveTimer); state.saveTimer = null; collect(true);
    setStatus('Checking the timeline and updating the overlay…');
    const result = await api.applyOverlay({ configuration: state.configuration, expectedFingerprint: state.fingerprint });
    state.configuration = result.configuration; state.dirty = false; state.stale = false;
    setStatus(created
      ? `Overlay created · ${plural(result.segmentCount, 'segment')}. Play in Resolve and nudge Data timing until it matches.`
      : `Overlay updated · ${plural(result.segmentCount, 'segment')}. Your Fusion styles and timing were kept.`, 'good');
  } catch (error) { setStatus(error.message, 'error'); }
  finally { setBusy(false); }
  await scan({ silent: true });
  renderPrimary();
}
async function chooseActivity() {
  setBusy(true);
  try {
    const result = await api.chooseActivity();
    if (!result) return;
    if (!state.configuration) throw new Error('Open a Resolve timeline first.');
    collect();
    if (state.configuration.activity?.activityId !== result.activity.activityId) { state.configuration.cameraAnchors = {}; state.anchorDrafts.clear(); }
    if (state.zoneInferred) { state.configuration.captureTimeZone = null; state.zoneInferred = false; }
    Object.assign(state.configuration, { activity: result.activity, activityLabel: result.fileName });
    window.clearTimeout(state.saveTimer); state.saveTimer = null;
    state.configuration = await api.saveConfiguration(state.configuration);
    state.dirty = false; state.stale = true;
    render(); setStatus('Activity loaded.', 'good');
  } catch (error) { setStatus(error.message, 'error'); }
  finally { setBusy(false); }
}

// ---- Scanning ------------------------------------------------------------------
function render() {
  if (!state.configuration) { renderPrimary(); return; }
  renderActivity(); renderTracks(); renderWidgets(); renderOffset();
  if (state.scan) { ensureZone(); renderZone(); renderClipDetails(); renderAlignment(); }
  renderPrimary();
}
async function scan({ restore = false, silent = false, trackIndex } = {}) {
  if (state.busy || state.scanning) return;
  state.scanning = true;
  if (!silent) setBusy(true);
  try {
    collect();
    const result = await api.scanTimeline({ trackIndex: restore ? undefined : trackIndex ?? state.configuration?.referenceVideoTrackIndex, contextId: state.configuration?.contextId });
    if (result.paused) { state.scanPaused = true; setStatus('Resolve is rendering. Checks resume after the export.', 'warning'); return; }
    const resumed = state.scanPaused; state.scanPaused = false;
    const changedContext = state.configuration?.contextId !== result.contextId;
    const changed = state.fingerprint !== result.fingerprint;
    if (changedContext || restore) {
      Object.assign(state, { configuration: result.configuration, dirty: false, zoneInferred: false, autoTrackTried: false });
      state.captureDrafts.clear(); state.anchorDrafts.clear();
    } else {
      // Keep unsaved panel edits; adopt the fields only the control plane writes.
      const { managedItemId, lastAppliedFingerprint, bundleDirectory } = result.configuration;
      Object.assign(state.configuration, { managedItemId, lastAppliedFingerprint, bundleDirectory });
      if (managedItemId) state.configuration.draftTimeOffsetMs = result.configuration.draftTimeOffsetMs;
    }
    const wasSplit = state.splitOverlay;
    Object.assign(state, { scan: result.scan, tracks: result.scan.tracks ?? [], fingerprint: result.fingerprint, stale: result.stale, splitOverlay: Boolean(result.splitOverlay) });
    if (!offsetBusy()) state.timeOffset = result.timeOffset ?? { seconds: state.configuration.draftTimeOffsetMs / 1000, source: 'draft', animated: false };
    if (!silent || changed || changedContext) render(); else { renderOffset(); renderPrimary(); }
    if (!state.autoTrackTried && !result.scan.timeline.items.length) {
      // A fresh timeline often keeps footage on another track; pick the first one once.
      state.autoTrackTried = true;
      const next = state.tracks.find((track) => track.clipCount > 0 && track.name !== OVERLAY_TRACK);
      if (next) { state.configuration.referenceVideoTrackIndex = next.index; scheduleSave(); state.scanning = false; if (!silent) setBusy(false); return await scan({ trackIndex: next.index }); }
    }
    if (result.splitOverlay && !wasSplit) setStatus('The overlay is cut. Each piece keeps its data and its own timing. Undo the cuts to update it as one clip.');
    else if (changedContext) setStatus(result.configuration.managedItemId ? 'Saved settings restored.' : 'Ready.');
    else if (result.stale && state.configuration.managedItemId && (changed || !silent)) setStatus('The timeline changed. Update the overlay to resync its data; your timing and styles stay.', 'warning');
    else if (resumed) setStatus('Export finished. Checks resumed.');
  } catch (error) {
    state.scan = null;
    const status = byId('timeline-status'); status.className = 'note error'; status.textContent = error.message;
    renderPrimary();
  } finally { state.scanning = false; if (!silent) setBusy(false); }
}

window.addEventListener('DOMContentLoaded', () => {
  byId('minimize-window').addEventListener('click', () => api.minimizeWindow());
  byId('close-window').addEventListener('click', async () => {
    if (state.busy) return;
    if (state.saveTimer) { window.clearTimeout(state.saveTimer); await saveNow(); }
    state.allowClose = true; await api.closeWindow();
  });
  byId('refresh').addEventListener('click', () => scan());
  byId('choose-activity').addEventListener('click', chooseActivity);
  for (const button of document.querySelectorAll('[data-layout]')) button.addEventListener('click', () => {
    if (!state.configuration || state.configuration.layoutPreset === button.dataset.layout) return;
    state.configuration.layoutPreset = button.dataset.layout; renderWidgets(); scheduleSave(); widgetsChanged();
  });
  for (const button of document.querySelectorAll('[data-nudge]')) button.addEventListener('click', () => setOffset(state.timeOffset.seconds + Number(button.dataset.nudge)));
  byId('offset-slider').addEventListener('input', (event) => setOffset(Number(event.target.value)));
  byId('offset-input').addEventListener('change', (event) => setOffset(Number(event.target.value)));
  // Read-only polling while the panel is open. Never rebuild or alter a timeline
  // automatically, and stay quiet while the user is adjusting timing.
  async function poll() {
    try { if (!state.dirty && !state.busy && !document.hidden && !offsetBusy()) await scan({ silent: true }); }
    finally { window.setTimeout(poll, 8000); }
  }
  scan({ restore: true }).finally(() => window.setTimeout(poll, 8000));
  followPlayhead();
});
window.addEventListener('beforeunload', (event) => {
  if (!state.allowClose && (state.saveTimer || state.busy)) { event.preventDefault(); event.returnValue = false; }
});
