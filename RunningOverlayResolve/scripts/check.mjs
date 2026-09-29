import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { validateActivity } = require('../src/domain/activity');
const { validateTimelineScan } = require('../src/sync/compile-sync-map');

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function filesUnder(directory) {
  const result = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) result.push(...filesUnder(fullPath));
    else result.push(fullPath);
  }
  return result;
}

const sourceFiles = [
  ...filesUnder(path.join(root, 'src')),
  ...filesUnder(path.join(root, 'scripts')),
  ...filesUnder(path.join(root, 'workflow-plugin')),
  ...filesUnder(path.join(root, 'test')),
];

for (const file of sourceFiles.filter((candidate) => /\.(?:js|mjs)$/.test(candidate))) {
  const result = spawnSync(process.execPath, ['--check', file], { encoding: 'utf8' });
  if (result.status !== 0) {
    process.stderr.write(result.stderr);
    process.exit(result.status ?? 1);
  }
}

for (const file of filesUnder(root).filter((candidate) => candidate.endsWith('.json'))) {
  JSON.parse(fs.readFileSync(file, 'utf8'));
}

validateActivity(JSON.parse(fs.readFileSync(path.join(root, 'fixtures/activity.synthetic.json'), 'utf8')));
validateTimelineScan(JSON.parse(fs.readFileSync(path.join(root, 'fixtures/timeline.synthetic.json'), 'utf8')));

const fusePath = path.join(root, 'fusion/Fuses/RunningOverlayNumeric.fuse');
const fuse = fs.readFileSync(fusePath, 'utf8');
for (const marker of [
  'FuRegisterClass',
  'CT_SourceTool',
  'REG_TimeVariant = true',
  'CrosshairControl',
  'function Process(req)',
  'Composition Start Frame (0 = Sync Start)',
  'Choose sync.rosync, not sync-map.json',
  'RUNNING OVERLAY DATA ERROR',
  'Reload Data',
]) {
  if (!fuse.includes(marker)) throw new Error(`Numeric Fuse is missing required marker: ${marker}`);
}

const trackedSource = sourceFiles.map((file) => fs.readFileSync(file, 'utf8')).join('\n');
if (/\/Users\/[^/]+\//.test(trackedSource)) throw new Error('Resolve subproject contains a machine-specific user path');
if (fs.existsSync(path.join(root, 'workflow-plugin/WorkflowIntegration.node'))) {
  throw new Error('WorkflowIntegration.node must be copied from the installed Resolve SDK during assembly, not committed');
}

const assembleScript = fs.readFileSync(path.join(root, 'scripts/assemble.mjs'), 'utf8');
if (/fs\.rm\(dist\s*,/.test(assembleScript)) {
  throw new Error('Assembly must preserve generated .roresolve bundles under dist');
}

console.log('RunningOverlayResolve static checks passed.');
