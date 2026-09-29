import fs from 'node:fs/promises';
import fsSync from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dist = path.join(root, 'dist');
const workflowDist = path.join(dist, 'workflow-plugin');
const developerRoot = process.env.RESOLVE_DEVELOPER_ROOT
  ?? '/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer';
const workflowNode = process.env.RESOLVE_WORKFLOW_NODE
  ?? path.join(developerRoot, 'Workflow Integrations/Examples/SamplePromisePlugin/WorkflowIntegration.node');

if (!fsSync.existsSync(workflowNode)) {
  throw new Error('WorkflowIntegration.node was not found. Install the Resolve SDK or set RESOLVE_WORKFLOW_NODE.');
}

await fs.mkdir(dist, { recursive: true });
await Promise.all([
  fs.rm(workflowDist, { recursive: true, force: true }),
  fs.rm(path.join(dist, 'fusion'), { recursive: true, force: true }),
  fs.rm(path.join(dist, 'schemas'), { recursive: true, force: true }),
  fs.rm(path.join(dist, 'assembly.json'), { force: true }),
]);
await fs.cp(path.join(root, 'workflow-plugin'), workflowDist, { recursive: true });
await fs.cp(path.join(root, 'src'), path.join(workflowDist, 'lib'), { recursive: true });
await fs.copyFile(workflowNode, path.join(workflowDist, 'WorkflowIntegration.node'));
await fs.cp(path.join(root, 'fusion'), path.join(dist, 'fusion'), { recursive: true });
await fs.cp(path.join(root, 'schemas'), path.join(dist, 'schemas'), { recursive: true });

const summary = {
  assembledAt: new Date().toISOString(),
  platform: process.platform,
  architecture: process.arch,
  host: os.type(),
  workflowNodeSource: 'Resolve SDK (copied locally; not tracked)',
};
await fs.writeFile(path.join(dist, 'assembly.json'), `${JSON.stringify(summary, null, 2)}\n`, 'utf8');
console.log(`Assembled Resolve prototype at ${dist}`);
