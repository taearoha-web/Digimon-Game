// Shader-compile probe: runs a Godot web build in Chromium and counts every
// WebGL program link, per second and by whether the same shader source was
// linked before. A shader compiled again and again during play is a stall of
// tens of milliseconds on a phone; this is how the freed-and-recompiled effect
// shaders (see MaterialKeeper) were found.
//
//   1. Copy the project, point run/main_scene at tests/tools/zone_perf_probe.tscn
//      (it must live outside tests/ and tools/, which exports exclude) and
//      export the Web preset to a scratch folder.
//   2. VW=160 VH=90 node tools/web_shader_probe.mjs <export dir> "zone=abyss&cls=warrior&sec=60&q=1"
//      (VW/VH keep software GL cheap; CHROME=<path> picks the browser.)
// Healthy: a burst while the zone loads, then at most the odd first-use compile.
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
const root = process.argv[2];
const query = process.argv[3] || '';
const types = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(req.url.split('?')[0]) === '/' ? 'index.html' : decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, {'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp'});
    res.end(data);
  });
}).listen(0);
const port = server.address().port;
const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--disable-gpu-vsync', '--disable-frame-rate-limit'] });
const page0 = null;
const page = await browser.newPage({ viewport: { width: Number(process.env.VW || 640), height: Number(process.env.VH || 300) } });
let done = false;
page.on('console', m => { const t = m.text(); if (/PERF|ZONE|CENSUS|SPIKES|SCRIPT ERROR|PROFILE|LINK/.test(t)) console.log(t.slice(0, 700)); if (/ZONE /.test(t)) globalThis.__zoneAt = Date.now(); if (/PERF /.test(t)) done = true; });
page.on('pageerror', e => console.log('PAGEERROR', String(e).slice(0, 300)));
await page.addInitScript(() => {
  window.__links = [];
  const P = WebGL2RenderingContext.prototype;
  const sources = new WeakMap();
  const origSource = P.shaderSource;
  P.shaderSource = function (shader, src) { sources.set(shader, src); return origSource.call(this, shader, src); };
  const origAttach = P.attachShader;
  const attached = new WeakMap();
  P.attachShader = function (program, shader) { const l = attached.get(program) || []; l.push(shader); attached.set(program, l); return origAttach.call(this, program, shader); };
  const origLink = P.linkProgram;
  P.linkProgram = function (program) {
    const t = performance.now();
    const r = origLink.call(this, program);
    const srcs = (attached.get(program) || []).map(s => sources.get(s) || '');
    const frag = srcs.find(s => /precision.*\n[\s\S]*out vec4|FRAGMENT|frag_color/i.test(s)) || srcs[1] || '';
    const defs = (frag.match(/#define [A-Z0-9_]+/g) || []).slice(0, 40).join(' ');
    let h = 0; const all = srcs.join('|'); for (let i = 0; i < all.length; i += 7) h = (h * 31 + all.charCodeAt(i)) | 0;
    window.__seen = window.__seen || new Map();
    const repeat = window.__seen.has(h); window.__seen.set(h, (window.__seen.get(h) || 0) + 1);
    window.__links.push({ h, repeat, at: Date.now(), ms: Math.round(performance.now() - t), len: srcs.join('').length, defs: defs.slice(0, 260) });
    return r;
  };
});
const cdp = await page.context().newCDPSession(page);
await cdp.send('Profiler.enable');
await cdp.send('Profiler.setSamplingInterval', { interval: 400 });
await page.goto(`http://localhost:${port}/index.html?${query}`);
await new Promise(r => setTimeout(r, 12000));
await cdp.send('Profiler.start');
const t0 = Date.now();
while (!done && Date.now() - t0 < 240000) await new Promise(r => setTimeout(r, 500));
const links = await page.evaluate(() => window.__links);
console.log('LINKS total', links.length);
const zoneAt = globalThis.__zoneAt || 0;
const byWindow = { before: 0, after: 0 };
for (const l of links) (l.at < zoneAt ? byWindow.before++ : byWindow.after++);
console.log('LINKS before-measure', byWindow.before, 'after-measure-start', byWindow.after);
const hist = {};
for (const l of links) { const b = Math.floor((l.at - zoneAt) / 1000); hist[b] = (hist[b] || 0) + 1; }
console.log('LINKHIST', JSON.stringify(Object.entries(hist).filter(([k]) => Number(k) >= -3).map(([k, v]) => k + ':' + v).join(' ')));
const fragDefs = new Set(); for (const l of links) fragDefs.add(l.defs);
console.log('LINKS distinct define-sets', fragDefs.size);
const after = links.filter(l => l.at >= zoneAt);
console.log('LINKS repeats-after-start', after.filter(l => l.repeat).length, 'new-after-start', after.filter(l => !l.repeat).length);
const rep = {}; for (const l of after.filter(l => l.repeat)) rep[l.h] = (rep[l.h] || 0) + 1;
console.log('LINKS repeated sources', JSON.stringify(Object.entries(rep).slice(0, 8)));
for (const l of links.filter(l => l.at >= zoneAt + 5000).slice(0, 12)) console.log('LINK +' + ((l.at - zoneAt) / 1000).toFixed(1) + 's len=' + l.len + ' linkcall=' + l.ms + 'ms', l.defs.slice(0, 200));
const { profile } = await cdp.send('Profiler.stop');
const byId = new Map(profile.nodes.map(n => [n.id, n]));
const self = new Map();
let total = 0;
profile.samples.forEach((id, i) => {
  const dt = profile.timeDeltas[i] / 1000;
  const n = byId.get(id);
  const key = (n.callFrame.functionName || '(anon)') + ' ' + (n.callFrame.url.split('/').pop() || '');
  self.set(key, (self.get(key) || 0) + dt); total += dt;
});
const rows = [...self.entries()].sort((a, b) => b[1] - a[1]).slice(0, 28);
console.log('PROFILE total', Math.round(total), 'ms');
for (const [k, v] of rows) console.log('PROFILE', String(Math.round(v)).padStart(6), 'ms', (100 * v / total).toFixed(1) + '%', k);
console.log('elapsed', Math.round((Date.now() - t0) / 1000), 's done=', done);
await browser.close(); server.close();
