// Headless check of the receiver: screenshots at 1920 × 1080 (harness/shots/)
// and an audio transport test against the real MIDI and piano.
//
//   ./deploy.sh --no-upload && npx playwright install chromium && node harness/shots.mjs
//
// Serves the worktree root (so the harness reaches the app's Resources), opens
// dist/index.html?harness=1 and drives it with the protocol's own messages.

import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { extname, join, normalize, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
import { loadMessage } from './hymn-message.js';

const here = dirname(fileURLToPath(import.meta.url));
const root = normalize(join(here, '../../..'));
const resources = join(root, 'AdventPraise/Resources');
const shots = join(here, 'shots');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css',
  '.json': 'application/json', '.woff2': 'font/woff2', '.svg': 'image/svg+xml', '.png': 'image/png' };

const server = createServer(async (req, res) => {
  const path = normalize(join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname)));
  if (!path.startsWith(root)) { res.writeHead(403).end(); return; }
  try {
    const body = await readFile(path);
    res.writeHead(200, { 'content-type': types[extname(path)] ?? 'application/octet-stream' }).end(body);
  } catch {
    res.writeHead(404).end();
  }
});
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}/android/cast-receiver`;

const readJSON = async (path) => JSON.parse(await readFile(path, 'utf8'));
const hymnals = await readJSON(join(resources, 'Hymnals/hymnals.json'));
const manifest = await readJSON(join(resources, 'Midi/midi-manifest.json'));
const sdahTunes = await readJSON(join(resources, 'Extras/sdah_tunes.json'));
const english = await readJSON(join(resources, 'Hymnals/english.json'));
const info = hymnals.find((h) => h.key === 'english');
const hymn = (number, extra = {}) => loadMessage({ info, file: english, number, manifest, sdahTunes, ...extra });

await mkdir(shots, { recursive: true });
const browser = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required'] });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

const started = Date.now();
await page.goto(`${base}/dist/index.html?harness=1`);
await page.waitForFunction(() => window.__receiver);
const send = (message) => page.evaluate((m) => window.__receiver.onMessage(m), message);
const settle = () => page.waitForTimeout(700); // the 0.45 s cross-fade, and a little
const shot = async (name) => {
  await settle();
  await page.screenshot({ path: join(shots, `${name}.png`) });
  console.log(`shots/${name}.png`);
};
const outbox = () => page.evaluate(() => window.__receiver.outbox.splice(0));
const lastStatus = async () => (await page.evaluate(() => window.__receiver.outbox.filter((m) => m.type === 'status').at(-1)));

await shot('idle-dark');

// Hymn 191: Blessed Assurance (three verses, the chorus after each), as in the iOS renders.
await send(hymn(191, { pageIndex: 0, theme: { appearance: 'dark', worshipPointSize: 42, largePrint: false } }));
await shot('verse-dark');
await send({ v: 1, type: 'page', pageIndex: 1 });
await shot('chorus-dark');
await send({ v: 1, type: 'theme', appearance: 'light' });
await shot('chorus-light');
await send({ v: 1, type: 'page', pageIndex: 2 });
await shot('verse-light');
await send({ v: 1, type: 'theme', appearance: 'dark' });
await send({ v: 1, type: 'page', pageIndex: -1 });
await shot('title-dark');
await send({ v: 1, type: 'blank', on: true });
await shot('blank-dark');
await send({ v: 1, type: 'blank', on: false });

// The longest single block in the hymnal: shrinks to fit.
let longest = { lines: 0 };
for (const h of english.hymns) for (const b of h.blocks) {
  const chars = b.l.join('').length;
  if (chars > (longest.chars ?? 0)) longest = { number: h.number, chars, block: b };
}
const long = hymn(longest.number);
const longIndex = long.pages.findIndex((p) => p.lines.join('') === longest.block.l.join(''));
await send({ ...long, pageIndex: Math.max(0, longIndex) });
await shot('verse-long-dark');
await send({ v: 1, type: 'theme', worshipPointSize: 64 });
await send({ v: 1, type: 'load', ...hymn(191, { pageIndex: 2 }) });
await shot('verse-size64-dark');
await send({ v: 1, type: 'theme', worshipPointSize: 42 });
await send({ v: 1, type: 'special', announcement: 'Fellowship lunch in the hall after the service', imageId: null });
await shot('announcement-dark');
// A picture, in chunks like the phone sends it, with the announcement on its scrim.
const jpeg = await page.evaluate(async () => {
  const canvas = new OffscreenCanvas(1600, 1000);
  const g = canvas.getContext('2d');
  const grad = g.createLinearGradient(0, 0, 1600, 1000);
  grad.addColorStop(0, '#7a9cc6'); grad.addColorStop(1, '#e8c07a');
  g.fillStyle = grad; g.fillRect(0, 0, 1600, 1000);
  const bytes = new Uint8Array(await (await canvas.convertToBlob({ type: 'image/jpeg', quality: 0.85 })).arrayBuffer());
  let binary = '';
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
});
const chunks = Math.ceil(jpeg.length / 48000);
for (let i = 0; i < chunks; i++) {
  await send({ v: 1, type: 'imageChunk', imageId: 'test', index: i, count: chunks, mime: 'image/jpeg', data: jpeg.slice(i * 48000, (i + 1) * 48000) });
}
await send({ v: 1, type: 'special', announcement: 'Fellowship lunch in the hall after the service', imageId: 'test' });
await shot('image-dark');
await send({ v: 1, type: 'special', announcement: null, imageId: null });

// Audio: the TV is the clock.
const report = { errors: [] };
await outbox();
await send(hymn(1, { pageIndex: 0, autoplay: true }));
const t0 = Date.now();
await page.waitForFunction(() => window.__receiver.transport.state === 'playing', null, { timeout: 30000 });
report.firstPlayMs = Date.now() - t0;
const sample = async () => page.evaluate(() => ({ pos: window.__receiver.transport.position(), at: performance.now() }));
let a = await sample();
await page.waitForTimeout(2000);
let b = await sample();
report.clockRate = +(((b.pos - a.pos) * 1000) / (b.at - a.at)).toFixed(3);
const status = await lastStatus();
report.status = status;
const all = await outbox();
const statuses = all.filter((m) => m.type === 'status');
report.statusPerSecond = +(statuses.length / 2.3).toFixed(1);
report.voices = await page.evaluate(() => window.__receiver.transport.engineNow.synth.voiceCount);
// One pass: to End of Track (iOS) against the synth's own length (to the last note).
report.seqDurationMs = await page.evaluate(() => Math.round(window.__receiver.transport.seqDuration * 1000));

// Across a pass boundary: seek to half a second before the end of verse 1.
await send({ v: 1, type: 'seek', ms: status.passDurationMs - 500 });
await page.waitForTimeout(1200);
report.afterBoundary = await page.evaluate(() => {
  const t = window.__receiver.transport;
  return { pass: t.pass + 1, offsetMs: Math.round((t.position() - t.pass * t.passDuration) * 1000), state: t.state };
});

// Tempo: fast is 1.2× the clock.
await send({ v: 1, type: 'tempo', rate: 1.2 });
a = await sample();
await page.waitForTimeout(1500);
b = await sample();
report.clockRateFast = +(((b.pos - a.pos) * 1000) / (b.at - a.at)).toFixed(3);

// The last verse ends: back to 0, ended.
await send({ v: 1, type: 'tempo', rate: 1 });
await send({ v: 1, type: 'seek', ms: status.durationMs - 400 });
await page.waitForTimeout(1000);
report.atEnd = await page.evaluate(() => ({ state: window.__receiver.transport.state, pos: window.__receiver.transport.position() }));

await send({ v: 1, type: 'play' });
await page.waitForTimeout(300);
await send({ v: 1, type: 'pause' });
report.paused = await page.evaluate(() => window.__receiver.transport.state);
await send({ v: 1, type: 'stop' });
report.stopped = await page.evaluate(() => ({ state: window.__receiver.transport.state, pos: window.__receiver.transport.position() }));

// Errors come back as `error` messages.
await outbox();
await send({ v: 1, type: 'load', ...hymn(1), midi: 'hymn-999.mid' });
await page.waitForTimeout(500);
await send({ v: 1, type: 'nonsense' });
await send({ v: 2, type: 'page', pageIndex: 0 });
report.errorCodes = (await outbox()).filter((m) => m.type === 'error').map((m) => m.code);
report.pageErrors = errors;
report.totalSeconds = Math.round((Date.now() - started) / 1000);

// The harness page itself.
const harness = await browser.newPage({ viewport: { width: 1440, height: 900 } });
await harness.goto(`${base}/harness/index.html`);
await harness.waitForFunction(() => window.harness);
await harness.evaluate(() => window.harness.load());
await harness.waitForTimeout(1200);
await harness.screenshot({ path: join(shots, 'harness.png') });
console.log('shots/harness.png');

console.log(JSON.stringify(report, null, 2));
await browser.close();
server.close();
