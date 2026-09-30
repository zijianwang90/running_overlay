'use strict';

window.runningOverlayPickers = (() => {
  const time = window.RunningOverlayTime;
  let nextId = 0;
  function zoneSelect(value, label) {
    const select = document.createElement('select'); select.className = 'timezone-select'; select.setAttribute('aria-label', label);
    const empty = document.createElement('option'); empty.value = ''; empty.textContent = 'Choose timezone'; select.appendChild(empty);
    for (const zone of time.timeZones([value])) {
      const option = document.createElement('option'); option.value = zone; option.textContent = zone.replaceAll('_', ' '); select.appendChild(option);
    }
    select.value = value ?? ''; return select;
  }
  function createTimePicker({ label, iso, zone, parts, draft, onChange = () => {} }) {
    const initialZone = draft?.zone ?? zone ?? (iso ? time.offsetZoneForISO(iso) : '');
    const initial = draft?.parts ?? parts ?? (iso ? time.partsAt(Date.parse(iso), initialZone) : null);
    let millisecond = initial?.millisecond ?? 0;
    let selectedOffset = draft?.offsetMinutes;
    if (selectedOffset === undefined && iso) selectedOffset = time.offsetAt(Date.parse(iso), initialZone);
    const root = document.createElement('fieldset'); root.className = 'time-picker';
    const legend = document.createElement('legend'); legend.textContent = label; root.appendChild(legend);
    const date = document.createElement('input'); date.type = 'date'; date.min = '1970-01-01'; date.max = '9999-12-31'; date.className = 'date-select'; date.value = initial ? time.dateValue(initial) : ''; date.setAttribute('aria-label', `${label} date`);
    const clock = document.createElement('div'); clock.className = 'clock-select';
    const fields = {};
    for (const [key, count, title] of [['hour', 24, 'Hour'], ['minute', 60, 'Minute'], ['second', 60, 'Second']]) {
      const select = document.createElement('select'); select.setAttribute('aria-label', `${label} ${title.toLowerCase()}`);
      const empty = document.createElement('option'); empty.value = ''; empty.textContent = '--'; select.appendChild(empty);
      for (let value = 0; value < count; value++) { const option = document.createElement('option'); option.value = String(value); option.textContent = String(value).padStart(2, '0'); select.appendChild(option); }
      select.value = initial ? String(initial[key]) : ''; fields[key] = select;
      const field = document.createElement('label'); field.textContent = title; field.appendChild(select); clock.appendChild(field);
    }
    const zonePicker = zoneSelect(initialZone, `${label} timezone`);
    const fold = document.createElement('select'); fold.setAttribute('aria-label', `${label} repeated-hour offset`); fold.className = 'offset-select'; fold.hidden = true;
    const feedback = document.createElement('div'); feedback.className = 'time-feedback'; feedback.setAttribute('aria-live', 'polite');
    const dateClock = document.createElement('div'); dateClock.className = 'date-clock'; dateClock.append(date, clock);
    root.append(dateClock, zonePicker, fold, feedback);
    let candidates = [];
    function readParts() {
      if (Object.values(fields).some((field) => field.value === '')) throw new Error('Choose the hour, minute and second.');
      return time.partsFromDate(date.value, fields.hour.value, fields.minute.value, fields.second.value, millisecond);
    }
    function refresh() {
      candidates = []; fold.replaceChildren(); fold.hidden = true; feedback.className = 'time-feedback';
      if (isEmpty()) { feedback.textContent = 'Choose a date and time.'; return; }
      try {
        const parts = readParts(); candidates = time.possibleInstants(parts, zonePicker.value);
        if (!candidates.length) throw new Error('This time is skipped by daylight saving. Choose another time.');
        if (candidates.length > 1) {
          fold.hidden = false;
          const empty = document.createElement('option'); empty.value = ''; empty.textContent = 'Repeated hour — choose UTC offset'; fold.appendChild(empty);
          for (const candidate of candidates) { const option = document.createElement('option'); option.value = String(candidate.offsetMinutes); option.textContent = time.formatOffset(candidate.offsetMinutes); fold.appendChild(option); }
          fold.value = candidates.some((candidate) => candidate.offsetMinutes === selectedOffset) ? String(selectedOffset) : '';
          if (fold.value === '') throw new Error('The clocks move back: choose which occurrence.');
        }
        const selected = candidates.find((candidate) => candidate.offsetMinutes === selectedOffset) ?? candidates[0];
        feedback.textContent = `${time.formatOffset(selected.offsetMinutes)} on this date${millisecond ? ` · ${millisecond} ms retained` : ''}`;
      } catch (error) { feedback.textContent = error.message; feedback.classList.add('warning'); }
    }
    function changed(resetMilliseconds = false) {
      if (resetMilliseconds) millisecond = 0;
      selectedOffset = undefined; refresh(); onChange(api);
    }
    for (const field of [date, ...Object.values(fields)]) field.addEventListener('change', () => changed(true));
    zonePicker.addEventListener('change', () => changed());
    fold.addEventListener('change', () => { selectedOffset = fold.value === '' ? undefined : Number(fold.value); refresh(); onChange(api); });
    function isEmpty() { return !date.value && Object.values(fields).every((field) => field.value === ''); }
    const api = { element: root, isEmpty,
      readISO: () => time.toISO(readParts(), zonePicker.value, selectedOffset),
      readTimeZone: () => time.validateTimeZone(zonePicker.value),
      valid: () => { try { api.readISO(); return true; } catch { return false; } },
      draft: () => ({ zone: zonePicker.value, parts: { year: Number(date.value.slice(0, 4)), month: Number(date.value.slice(5, 7)), day: Number(date.value.slice(8, 10)), hour: fields.hour.value === '' ? null : Number(fields.hour.value), minute: fields.minute.value === '' ? null : Number(fields.minute.value), second: fields.second.value === '' ? null : Number(fields.second.value), millisecond }, dateValue: date.value, offsetMinutes: selectedOffset }),
      setZone: (zone) => { zonePicker.value = zone; changed(); },
      hasZone: () => Boolean(zonePicker.value),
      clear: () => { date.value = ''; for (const field of Object.values(fields)) field.value = ''; millisecond = 0; changed(); },
    };
    // Partial drafts must survive unrelated scans without becoming zero times.
    if (draft) { date.value = draft.dateValue; for (const key of Object.keys(fields)) fields[key].value = draft.parts[key] == null ? '' : String(draft.parts[key]); }
    root.id = `time-picker-${++nextId}`;
    refresh(); return api;
  }
  return { zoneSelect, createTimePicker };
})();
