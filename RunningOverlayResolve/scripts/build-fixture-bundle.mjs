import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { compileSyncMap } = require('../src/sync/compile-sync-map');
const { writeResolveBundle } = require('../src/io/render-data');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

async function fixture(name) {
  return JSON.parse(await fs.readFile(path.join(root, 'fixtures', name), 'utf8'));
}

const activity = await fixture('activity.synthetic.json');
const syncMap = compileSyncMap({
  activity,
  timeline: await fixture('timeline.synthetic.json'),
  mediaById: await fixture('media.synthetic.json'),
});
const outputRoot = path.join(root, 'dist', 'fixture-bundle');
await fs.rm(outputRoot, { recursive: true, force: true });
await fs.mkdir(outputRoot, { recursive: true });
const bundle = await writeResolveBundle(outputRoot, activity, syncMap);
console.log(`Wrote synthetic live-data bundle to ${bundle}`);
