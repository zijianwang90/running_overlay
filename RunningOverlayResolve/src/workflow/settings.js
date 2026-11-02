'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const { invariant } = require('../domain/validation');
const { validToken } = require('../map/mapbox');

// User-level settings are deliberately separate from per-project configuration:
// a token belongs to the person, not to one Resolve timeline, and the product
// never ships or embeds one.
const SCHEMA_VERSION = 1;

function defaultSettings() {
  return { schemaVersion: SCHEMA_VERSION, mapboxToken: null };
}

function validateSettings(value) {
  invariant(value && typeof value === 'object' && !Array.isArray(value), 'Invalid settings file.');
  invariant(value.schemaVersion === SCHEMA_VERSION, 'Unsupported settings version.');
  const mapboxToken = value.mapboxToken ?? null;
  invariant(mapboxToken === null || validToken(mapboxToken), 'Enter a Mapbox public access token (pk.*).');
  return { schemaVersion: SCHEMA_VERSION, mapboxToken };
}

class SettingsStore {
  constructor(filePath) {
    invariant(typeof filePath === 'string' && filePath.length > 0, 'Settings file path is required.');
    this.filePath = filePath;
  }
  // A missing file is the first-run state. A corrupt file is an error: silently
  // replacing it could hide a bad edit and lose a token the user pasted.
  async load() {
    let text;
    try { text = await fs.readFile(this.filePath, 'utf8'); }
    catch (error) { if (error.code === 'ENOENT') return defaultSettings(); throw error; }
    let parsed;
    try { parsed = JSON.parse(text); }
    catch { throw new Error('Settings file is not valid JSON. Fix or delete it, then try again.'); }
    return validateSettings(parsed);
  }
  // Write a temp file in the same directory and rename it, so a crash leaves
  // either the old complete file or the new complete file, never a partial one.
  async save(value) {
    const normalized = validateSettings(value);
    const directory = path.dirname(this.filePath);
    await fs.mkdir(directory, { recursive: true, mode: 0o700 });
    const temporary = `${this.filePath}.${crypto.randomUUID()}.tmp`;
    try {
      await fs.writeFile(temporary, `${JSON.stringify(normalized, null, 2)}\n`, { mode: 0o600 });
      await fs.rename(temporary, this.filePath);
    } finally { await fs.rm(temporary, { force: true }); }
    return normalized;
  }
}

// The service defaults to memory so tests and one-off callers never touch the
// user's real settings file; the panel wires the real store in main.js.
class MemorySettingsStore {
  constructor(initial = {}) { this.value = validateSettings({ ...defaultSettings(), ...initial }); }
  async load() { return { ...this.value }; }
  async save(value) { this.value = validateSettings(value); return { ...this.value }; }
}

module.exports = { SCHEMA_VERSION, defaultSettings, validateSettings, SettingsStore, MemorySettingsStore };
