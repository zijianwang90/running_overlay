import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

// Inspect decoded pixels, not just a codec's advertised alpha capability.
export function inspectAlpha(pixels, expectation) {
  if (!pixels.length) throw new Error('No decoded alpha pixels.');
  if (!['visible', 'gap'].includes(expectation)) throw new Error('Unknown frame expectation.');
  let transparent = 0;
  let opaque = 0;
  let minimum = 255;
  let maximum = 0;
  for (const value of pixels) {
    minimum = Math.min(minimum, value);
    maximum = Math.max(maximum, value);
    if (value === 0) transparent++;
    if (value === 255) opaque++;
  }
  const passed = expectation === 'gap' ? maximum === 0 : transparent > 0 && opaque > 0;
  return { expectation, passed, minimum, maximum, transparent, opaque, pixels: pixels.length };
}

export function parseArguments(args) {
  const [file, ...options] = args;
  if (!file || file.startsWith('--')) throw new Error('Usage: node scripts/check-render-alpha.mjs FILE --visible-frame N [--gap-frame N ...]');
  const frames = [];
  for (let index = 0; index < options.length; index += 2) {
    const flag = options[index];
    const raw = options[index + 1];
    if (!['--visible-frame', '--gap-frame'].includes(flag) || !/^\d+$/.test(raw ?? '') || !Number.isSafeInteger(Number(raw))) {
      throw new Error('Specify nonnegative, zero-based frame numbers with --visible-frame or --gap-frame.');
    }
    const frame = Number(raw);
    if (frames.some((entry) => entry.frame === frame)) throw new Error('Each frame must have exactly one expectation.');
    frames.push({ frame, expectation: flag === '--gap-frame' ? 'gap' : 'visible' });
  }
  if (!frames.some((entry) => entry.expectation === 'visible')) throw new Error('At least one visible frame is required.');
  return { file: path.resolve(file), frames };
}

function run(command, args, maxBuffer = 1024 * 1024) {
  const result = spawnSync(command, args, { maxBuffer, timeout: 120000 });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed: ${result.stderr.toString().trim()}`);
  return result.stdout;
}

export function checkRender({ file, frames }) {
  const probe = JSON.parse(run('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,pix_fmt', '-of', 'json', file]));
  const stream = probe.streams?.[0];
  if (!stream) throw new Error('No video stream.');
  const pixelsPerFrame = stream.width * stream.height;
  if (!Number.isSafeInteger(pixelsPerFrame) || pixelsPerFrame <= 0 || pixelsPerFrame > 8192 * 8192) throw new Error('Unsupported video dimensions.');
  const results = frames.map(({ frame, expectation }) => {
    // alphaextract deliberately fails when there is no alpha plane. Converting
    // ordinary RGB to RGBA first would invent an opaque plane and hide that fact.
    const pixels = run('ffmpeg', ['-v', 'error', '-i', file, '-map', '0:v:0', '-vf', `select=eq(n\\,${frame}),alphaextract`, '-frames:v', '1', '-fps_mode', 'passthrough', '-pix_fmt', 'gray', '-f', 'rawvideo', 'pipe:1'], pixelsPerFrame + 1024);
    if (pixels.length !== pixelsPerFrame) throw new Error(`Frame ${frame} is absent or could not be fully decoded.`);
    return { frame, ...inspectAlpha(pixels, expectation) };
  });
  return { stream, passed: results.every((result) => result.passed), frames: results };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    const result = checkRender(parseArguments(process.argv.slice(2)));
    console.log(JSON.stringify(result, null, 2));
    if (!result.passed) process.exitCode = 1;
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
