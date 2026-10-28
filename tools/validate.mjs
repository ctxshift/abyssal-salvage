import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync, copyFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { rgbaToPng } from './png.mjs';
import assert from 'node:assert/strict';

const root = resolve(import.meta.dirname, '..');
const output = resolve(root, '.validation');
mkdirSync(output, { recursive: true });
const report = { status: 'running', checks: [] };
function save() {
  writeFileSync(resolve(output, 'report.json'), JSON.stringify(report, null, 2) + '\n');
}
function run(name, executable, args, cwd = root) {
  const start = Date.now();
  const result = spawnSync(executable, args, { cwd, encoding: 'utf8', timeout: 180000, maxBuffer: 32 * 1024 * 1024, windowsHide: true });
  writeFileSync(resolve(output, `${name}.log`), (result.stdout ?? '') + (result.stderr ?? '') + (result.error?.message ?? ''));
  report.checks.push({ name, exitCode: result.status, durationMs: Date.now() - start });
  save();
  if (result.status !== 0) throw new Error(`${name} failed; read .validation/${name}.log`);
  console.log(`PASS ${name} (${Date.now() - start} ms)`);
  return result.stdout;
}
try {
  save();
  const assets = JSON.parse(readFileSync(resolve(root, 'assets.json'), 'utf8'));
  assert.equal(assets.palette.length, 16);
  assert.equal(assets.sprites.length, 19);
  for (const character of 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:/+-%[]<>!., ') {
    assert.equal(assets.font[character]?.length, 7, `Missing font glyph ${character}`);
  }
  report.checks.push({ name: 'artwork-font', exitCode: 0 });
  console.log('PASS artwork and UI font');
  run('sdk-check', 'byt', ['check']);
  run('exports', 'byt', ['build', '--target', 'all']);
  const fixture = resolve(output, 'scenarios');
  mkdirSync(resolve(fixture, 'src'), { recursive: true });
  for (const file of ['bytorio.toml', 'bytorio.lock.toml', 'assets.json']) copyFileSync(resolve(root, file), resolve(fixture, file));
  for (const file of ['world.luau', 'art.luau']) copyFileSync(resolve(root, 'src', file), resolve(fixture, 'src', file));
  const source = readFileSync(resolve(root, 'src/main.luau'), 'utf8').trimEnd();
  if (!source.endsWith('return game')) throw new Error('Unexpected entrypoint footer');
  writeFileSync(resolve(fixture, 'src/main.luau'), source.slice(0, -'return game'.length) + readFileSync(resolve(root, 'tests/scenarios.luau.inc'), 'utf8'));
  run('gameplay-scenarios', 'byt', ['check', fixture]);
  const player = resolve(root, 'build/native', process.platform === 'win32' ? 'player.exe' : 'player');
  for (const [name, inputs] of [
    ['title', [0]],
    ['combat', [16, ...Array(700).fill(0), ...Array(50).fill(2), 0, 16, ...Array(18).fill(0)]],
    ['navigation', [16, ...Array(120).fill(2), ...Array(120).fill(4), 0, 2147483648, ...Array(20).fill(0)]],
  ]) {
    const replay = resolve(output, `${name}.txt`);
    writeFileSync(replay, inputs.join('\n'));
    const capture = resolve(output, `${name}.rgba`);
    const result = run(`replay-${name}`, player, ['--replay', replay, '--capture-rgba', capture], resolve(root, 'build/native'));
    const frames = result.trim().split(/\r?\n/).filter(line => line.startsWith('{')).map(line => JSON.parse(line));
    if (frames.length !== inputs.length) throw new Error(`${name}: incomplete replay`);
    rgbaToPng(capture, resolve(output, `${name}.png`));
  }
  report.status = 'passed';
} catch (error) {
  report.status = 'failed';
  console.error(error.message);
  process.exitCode = 1;
} finally {
  save();
}
