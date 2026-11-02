'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { SettingsStore, validateSettings } = require('../src/workflow/settings');

const TOKEN = 'pk.eyJ1Ijoic3ludGhldGljIn0.test-signature-123456';
const OTHER_TOKEN = 'pk.eyJ1Ijoib3RoZXIifQ.other-signature-123456';

async function temporary(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ro-user-settings-'));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  return root;
}

test('missing settings return defaults and a saved token round-trips with private permissions', async (t) => {
  const root = await temporary(t);
  const file = path.join(root, 'nested', 'settings.json');
  const store = new SettingsStore(file);
  assert.deepEqual(await store.load(), { schemaVersion: 1, mapboxToken: null });
  assert.deepEqual(await store.save({ schemaVersion: 1, mapboxToken: TOKEN }), { schemaVersion: 1, mapboxToken: TOKEN });
  assert.equal((await fs.stat(file)).mode & 0o777, 0o600);
  assert.equal((await fs.stat(path.dirname(file))).mode & 0o777, 0o700);
  assert.deepEqual(await new SettingsStore(file).load(), { schemaVersion: 1, mapboxToken: TOKEN });
  await store.save({ schemaVersion: 1, mapboxToken: OTHER_TOKEN });
  assert.deepEqual(await new SettingsStore(file).load(), { schemaVersion: 1, mapboxToken: OTHER_TOKEN });
  await store.save({ schemaVersion: 1, mapboxToken: null });
  assert.deepEqual(await store.load(), { schemaVersion: 1, mapboxToken: null });
});

test('settings reject an invalid token or schema version without writing a file', async (t) => {
  const root = await temporary(t);
  const file = path.join(root, 'settings.json');
  const store = new SettingsStore(file);
  await assert.rejects(store.save({ schemaVersion: 1, mapboxToken: 'sk.secret-1234567890' }), /Mapbox/);
  await assert.rejects(store.save({ schemaVersion: 1, mapboxToken: 'pk.short' }), /Mapbox/);
  await assert.rejects(store.save({ schemaVersion: 1, mapboxToken: ` ${TOKEN}` }), /Mapbox/);
  await assert.rejects(store.save({ schemaVersion: 2, mapboxToken: null }), /version/);
  await assert.rejects(store.save(null), /Invalid settings/);
  assert.equal(await fs.readFile(file, 'utf8').catch(() => null), null);
  assert.deepEqual(validateSettings({ schemaVersion: 1, mapboxToken: TOKEN, extra: true }), { schemaVersion: 1, mapboxToken: TOKEN });
});

test('a malformed settings file is an error instead of being silently replaced', async (t) => {
  const root = await temporary(t);
  const file = path.join(root, 'settings.json');
  const contents = '{"schemaVersion": 1, "mapboxToken":';
  await fs.writeFile(file, contents);
  await assert.rejects(new SettingsStore(file).load(), /not valid JSON/);
  assert.equal(await fs.readFile(file, 'utf8'), contents);
});

test('saving is atomic: temp files are renamed, and a failed rename leaves no partial file', async (t) => {
  const root = await temporary(t);
  const file = path.join(root, 'settings.json');
  const store = new SettingsStore(file);
  await store.save({ schemaVersion: 1, mapboxToken: TOKEN });
  assert.deepEqual(await fs.readdir(root), ['settings.json']);
  await store.save({ schemaVersion: 1, mapboxToken: OTHER_TOKEN });
  assert.deepEqual(await fs.readdir(root), ['settings.json']);
  // Renaming onto a directory fails after the temp file was written; the temp
  // file must be removed and the stored settings must stay intact.
  const blocked = path.join(root, 'blocked.json');
  await fs.mkdir(blocked);
  await assert.rejects(new SettingsStore(blocked).save({ schemaVersion: 1, mapboxToken: TOKEN }));
  assert.deepEqual((await fs.readdir(root)).sort(), ['blocked.json', 'settings.json']);
  assert.deepEqual(await store.load(), { schemaVersion: 1, mapboxToken: OTHER_TOKEN });
});
