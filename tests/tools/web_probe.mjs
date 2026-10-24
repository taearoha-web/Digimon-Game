import { chromium } from '/opt/node-tools/node_modules/playwright/index.mjs';
import http from 'node:http'; import fs from 'node:fs'; import path from 'node:path';
const root = process.argv[2], query = process.argv[3] || '', limit = Number(process.argv[4] || 200);
const types = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const server = http.createServer((req, res) => {
  const u = decodeURIComponent(req.url.split('?')[0]); const file = path.join(root, u === '/' ? 'index.html' : u);
  fs.readFile(file, (err, data) => { if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, {'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp'}); res.end(data); });
}).listen(0);
const port = server.address().port;
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', ...(process.env.SUSPENDED ? [] : ['--autoplay-policy=no-user-gesture-required'])] });
const page = await browser.newPage({ viewport: { width: Number(process.env.VW || 640), height: Number(process.env.VH || 300) } });
let done = false;
page.on('console', m => { const t = m.text(); if (/SWITCH|PROBE|PERF|SCRIPT ERROR|ERROR|SAMPLE|PHASE|ROUND|CENSUS|GROWTH|MODE SOAK|FAIL|PASS/.test(t)) console.log(t.slice(0, 1200)); if (/PERF done/.test(t)) done = true; });
page.on('pageerror', e => console.log('PAGEERROR', String(e).slice(0, 300)));
await page.goto(`http://localhost:${port}/index.html?${query}`);
const t0 = Date.now();
// Browser-side memory Godot cannot see: the renderer's and GPU process's resident
// size (from /proc, Linux only) and the JS heap. MEM lines every 30 s.
function rssOf(kind) {
  try {
    let total = 0;
    for (const pid of fs.readdirSync('/proc').filter(d => /^\d+$/.test(d))) {
      let cmd = ''; try { cmd = fs.readFileSync(`/proc/${pid}/cmdline`, 'utf8'); } catch (_) { continue; }
      if (!/chrom/i.test(cmd) || !cmd.includes(`--type=${kind}`)) continue;
      const m = fs.readFileSync(`/proc/${pid}/status`, 'utf8').match(/VmRSS:\s+(\d+)/);
      if (m) total += Number(m[1]) / 1024;
    }
    return Math.round(total);
  } catch (_) { return -1; }
}
let nextMem = 0;
while (!done && Date.now() - t0 < limit * 1000) {
  await new Promise(r => setTimeout(r, 500));
  if (Date.now() - t0 >= nextMem) {
    nextMem += 30000;
    const js = await page.evaluate(() => performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) : -1).catch(() => -1);
    console.log(`MEM wall=${Math.round((Date.now() - t0) / 1000)}s rendererMB=${rssOf('renderer')} gpuMB=${rssOf('gpu-process')} jsHeapMB=${js}`);
  }
}
console.log('finished', done, Math.round((Date.now() - t0) / 1000) + 's');
await browser.close(); server.close();
