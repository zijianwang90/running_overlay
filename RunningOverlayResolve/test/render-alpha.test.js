'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');

test('render alpha validation rejects opaque backgrounds and empty visible frames', async () => {
  const { inspectAlpha } = await import('../scripts/check-render-alpha.mjs');
  assert.equal(inspectAlpha(Buffer.from([255, 255]), 'visible').passed, false);
  assert.equal(inspectAlpha(Buffer.from([0, 0]), 'visible').passed, false);
  assert.equal(inspectAlpha(Buffer.from([0, 128, 255]), 'visible').passed, true);
  assert.equal(inspectAlpha(Buffer.from([0, 0]), 'gap').passed, true);
  assert.equal(inspectAlpha(Buffer.from([0, 1]), 'gap').passed, false);
  assert.throws(() => inspectAlpha(Buffer.alloc(0), 'gap'), /No decoded/);
});

test('render alpha CLI requires explicit unambiguous frame expectations', async () => {
  const { parseArguments } = await import('../scripts/check-render-alpha.mjs');
  assert.deepEqual(parseArguments(['render.mov', '--visible-frame', '40', '--gap-frame', '150']).frames,
    [{ frame: 40, expectation: 'visible' }, { frame: 150, expectation: 'gap' }]);
  for (const args of [[], ['render.mov'], ['render.mov', '--gap-frame', '1'],
    ['render.mov', '--visible-frame', '-1'], ['render.mov', '--visible-frame', '1.5'],
    ['render.mov', '--visible-frame'], ['render.mov', '--visible-frame', '9007199254740992'],
    ['render.mov', '--visible-frame', '1', '--gap-frame', '1']]) assert.throws(() => parseArguments(args));
});
