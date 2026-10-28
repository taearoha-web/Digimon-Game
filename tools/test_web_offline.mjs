/** Offline web app test on the real packaged build (docs/play, or the folder
 * given as the first argument). A local server stands in for the host and a
 * small mock of /api/account/*. It checks, in Chromium:
 *  - the service worker caches the whole build in the background while the
 *    first game loads from the network, and reports "พร้อมเล่นออฟไลน์ ✓";
 *  - with the network gone (browser offline AND the server refusing every
 *    request), a reload boots the engine from the cache without a login wall,
 *    shows the offline line and makes no failed request;
 *  - a save made offline survives a reload and is uploaded when back online;
 *  - with the network up but the account server failing, the last account's
 *    local save starts by itself after a short countdown;
 *  - a new build installs beside the old one, is offered with
 *    "มีเวอร์ชันใหม่ แตะเพื่ออัปเดต", swaps in one step (no file of the old build
 *    is served afterwards), deletes the old cache and also boots offline;
 *  - a build deployed while the game was closed is taken at the next launch.
 * CHROMIUM_PATH picks the browser (default: Playwright's Chromium). About a
 * minute with software WebGL. */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import {createRequire} from 'node:module';
const require = createRequire(import.meta.url);
let chromium;
try { ({chromium} = require('playwright')); }
catch { ({chromium} = require('/opt/codex/runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright')); }

const root = path.resolve(process.argv[2] || new URL('../docs/play', import.meta.url).pathname);
if (!fs.existsSync(path.join(root, 'sw.js'))) {
  // The published site is rebuilt from a Godot export; until then there is nothing to test.
  console.log('::warning::' + root + ' has no sw.js yet: run tools/package_web.py --pages docs/play. Offline test skipped.');
  process.exit(0);
}
const swSource = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
const BUILD = swSource.match(/const BUILD = '([0-9a-f]+)'/)[1];
const NEXT = 'next' + BUILD.slice(4), AGAIN = 'again' + BUILD.slice(5);
const TYPES = {'.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.wasm': 'application/wasm',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.ttf': 'font/ttf', '.webmanifest': 'application/manifest+json'};
const net = {down: false, next: '', apiDown: false, served: []};
const users = new Map([['pilot', {id: 'u-pilot', username: 'pilot', password: 'airplane-mode-10', revision: 0, bundle: {slots: {}, selectedSlot: 1}}]]);
const sessions = new Map();
const posts = [];
let checks = 0;
function ok(value, message) { assert.ok(value, message); checks++; console.log('  ok', checks, message); }

const server = http.createServer(async (req, res) => {
  if (net.down) { req.socket.destroy(); return; }
  const url = new URL(req.url, 'http://x');
  net.served.push(url.pathname + url.search);
  if (url.pathname.startsWith('/api/account/')) {
    if (net.apiDown) { res.writeHead(503, {'Content-Type': 'application/json'}); res.end('{"error":{"code":"service_unavailable","message":"Down"}}'); return; }
    return api(req, res, url.pathname.slice(13));
  }
  const name = url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname.slice(1));
  const file = path.join(root, name);
  if (!file.startsWith(root) || !fs.existsSync(file) || !fs.statSync(file).isFile()) { res.writeHead(404); res.end(); return; }
  let body = fs.readFileSync(file);
  // The "next" build: a new build id (new cache) and a visible marker; every
  // content-named file keeps its name, so the update reuses them.
  if (net.next && (name === 'index.html' || name === 'sw.js')) {
    let text = body.toString('utf8').replaceAll(BUILD, net.next);
    if (name === 'index.html') text = text.replace('<title>Toon Tale</title>', '<title>Toon Tale</title><meta name="toon-test-build" content="' + net.next + '">');
    body = Buffer.from(text);
  }
  res.writeHead(200, {'Content-Type': TYPES[path.extname(name)] || 'application/octet-stream',
    'Cache-Control': name === 'sw.js' || name === 'index.html' ? 'no-cache' : 'public, max-age=0, must-revalidate'});
  res.end(body);
});
async function api(req, res, route) {
  const json = (status, data, headers = {}) => { res.writeHead(status, {'Content-Type': 'application/json', ...headers}); res.end(JSON.stringify(data)); };
  let raw = ''; for await (const chunk of req) raw += chunk;
  const data = raw ? JSON.parse(raw) : {};
  const sid = (req.headers.cookie || '').match(/sid=([^;]+)/), user = sid && [...users.values()].find(u => u.username === sessions.get(sid[1]));
  if (route === 'session') return json(200, {user: user ? {id: user.id, username: user.username} : null});
  if (route === 'login') {
    const found = users.get(data.username);
    if (!found || found.password !== data.password) return json(401, {error: {code: 'invalid_credentials', message: 'Wrong'}});
    const token = 's' + sessions.size; sessions.set(token, found.username);
    return json(200, {user: {id: found.id, username: found.username}}, {'Set-Cookie': `sid=${token}; HttpOnly; SameSite=Strict; Path=/`});
  }
  if (!user) return json(401, {error: {code: 'unauthorized', message: 'Expired'}});
  if (req.headers['x-toon-account-id'] !== user.id) return json(409, {error: {code: 'account_changed', message: 'Changed'}});
  if (route === 'save' && req.method === 'GET') return json(200, {userId: user.id, revision: user.revision, bundle: user.bundle});
  if (route === 'save') {
    posts.push(data);
    if (data.expectedRevision !== user.revision) return json(409, {error: {code: 'save_conflict', message: 'Newer'}});
    user.bundle = data.bundle; user.revision++;
    return json(200, {revision: user.revision});
  }
  json(404, {error: {code: 'missing', message: 'Missing'}});
}
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = 'http://127.0.0.1:' + server.address().port;

const browser = await chromium.launch({headless: true, ...(process.env.CHROMIUM_PATH ? {executablePath: process.env.CHROMIUM_PATH} : {channel: 'chromium'}),
  args: ['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl']});
const context = await browser.newContext({viewport: {width: 640, height: 360}});
const page = await context.newPage();
const failures = [], errors = [];
page.on('requestfailed', request => { if (request.url().startsWith(origin)) failures.push(request.url() + ' ' + (request.failure() || {}).errorText); });
page.on('response', response => { if (response.url().startsWith(origin) && response.status() >= 400) failures.push(response.url() + ' HTTP ' + response.status()); });
page.on('pageerror', error => errors.push(error.message));
const consoleErrors = [];
page.on('console', message => { if (message.type() === 'error') consoleErrors.push(message.text()); });

const hero = (name, level, saved_at) => ({version: 1, name, class: 'mage', level, gold: 100, equip: {}, inv: [], saved_at});
const bundle = (name, level, saved_at) => JSON.stringify({slots: {'1': hero(name, level, saved_at)}, selectedSlot: 1});
const offline = () => page.evaluate(() => JSON.parse(window.toonOffline.status()));
const cloud = () => page.evaluate(() => JSON.parse(window.toonCloudStatus()));
async function poll(fn, label, ms = 240000) {
  const deadline = Date.now() + ms;
  for (;;) {
    try { if (await fn()) return; } catch (_) { /* page navigating */ }
    if (Date.now() > deadline) throw new Error('Timeout: ' + label);
    await new Promise(resolve => setTimeout(resolve, 250));
  }
}
async function draft(key) {
  return page.evaluate(key => new Promise((resolve, reject) => {
    const req = indexedDB.open('toon_tale_accounts_v1');
    req.onsuccess = () => { const r = req.result.transaction('records').objectStore('records').get(key); r.onsuccess = () => { req.result.close(); resolve(r.result); }; r.onerror = reject; };
    req.onerror = reject;
  }), key);
}
async function localSlot() {
  return page.evaluate(() => new Promise((resolve, reject) => {
    const req = indexedDB.open('/userfs');
    req.onsuccess = () => {
      const r = req.result.transaction('FILE_DATA').objectStore('FILE_DATA').get('/userfs/godot/app_userdata/Toon Tale/toon_tale_slot_1.json');
      r.onsuccess = () => { req.result.close(); resolve(r.result ? JSON.parse(new TextDecoder().decode(r.result.contents)) : null); };
      r.onerror = reject;
    };
    req.onerror = reject;
  }));
}
async function play(label) {
  const started = Date.now();
  await page.locator('#play').click();
  await poll(() => page.evaluate(() => document.body.classList.contains('playing') && !document.getElementById('loader')), label + ': engine started');
  const canvas = await page.evaluate(() => { const c = document.getElementById('canvas'); return c && c.width > 0 && c.height > 0; });
  ok(canvas, label + ': the engine started and the canvas is drawn (' + Math.round((Date.now() - started) / 1000) + ' s)');
}
const cacheNames = () => page.evaluate(() => caches.keys());

try {
  // 1. Online, first visit: sign in, play from the network, cache in the background.
  await page.goto(origin + '/');
  await page.locator('#play').click();
  await page.locator('#ta-username').waitFor();
  await page.locator('#ta-username').fill('pilot');
  await page.locator('#ta-password').fill('airplane-mode-10');
  await page.locator('.ta-submit').click();
  await poll(() => page.evaluate(() => document.body.classList.contains('playing')), 'first online boot');
  ok(true, 'first visit: signed in and the engine started from the network');
  await poll(async () => (await offline()).ready, 'offline cache complete');
  let status = await offline();
  ok(status.build === BUILD && status.shown.some(text => /^กำลังเตรียมเล่นออฟไลน์ \d+%$/.test(text)), 'download progress was shown: ' + status.shown.find(text => text.startsWith('กำลัง')));
  ok(status.shown.includes('พร้อมเล่นออฟไลน์ ✓'), 'ready line shown when every file is cached');
  ok(JSON.stringify(await cacheNames()) === JSON.stringify(['toon-tale-' + BUILD]), 'one cache, named for this build');
  const missing = await page.evaluate(async () => {
    const cache = await caches.open('toon-tale-' + window.TOON_OFFLINE.build);
    const out = [];
    for (const [file, size] of window.TOON_OFFLINE.files) {
      const hit = await cache.match(file);
      if (!hit || (size && (await hit.arrayBuffer()).byteLength !== size)) out.push(file);
    }
    return out;
  });
  ok(missing.length === 0, 'every file of the build is cached at its full size' + (missing.length ? ': missing ' + missing : ''));
  ok(await page.evaluate(() => !!navigator.serviceWorker.controller), 'the page is controlled by the service worker');
  await page.evaluate(b => window.toonCloudSave(b), bundle('Pilot', 5, 100));
  await poll(() => users.get('pilot').bundle.slots['1'] && users.get('pilot').bundle.slots['1'].level === 5, 'online save uploaded', 15000);
  await poll(async () => !(await cloud()).pending, 'online save acknowledged', 15000);

  // 2. Airplane mode: no network at all. The game must boot from the cache.
  net.down = true;
  await context.setOffline(true);
  failures.length = 0;
  await page.reload();
  await page.locator('#play').waitFor();
  await poll(async () => (await offline()).text === 'ออฟไลน์ – เซฟไว้ในเครื่อง จะซิงก์เมื่อออนไลน์', 'offline line on the start screen', 15000);
  ok(await page.locator('#toon-offline').isVisible(), 'offline status is visible: ' + (await page.locator('#toon-offline').innerText()));
  await play('offline boot');
  ok(!(await page.locator('#ta-username').count()), 'no login wall while offline');
  let account = await cloud();
  ok(account.user && account.user.username === 'pilot' && account.offline, 'continues as the last signed-in account, marked offline');
  ok(failures.length === 0, 'no failed requests while offline' + (failures.length ? ': ' + failures.join(', ') : ''));

  // 3. A save made offline persists (reload, still offline) and syncs later.
  await page.evaluate(b => window.toonCloudSave(b), bundle('Pilot', 7, 200));
  await poll(async () => { const d = await draft('account:u-pilot'); return d && d.dirty && d.bundle.slots['1'].level === 7; }, 'offline draft stored', 15000);
  ok(users.get('pilot').bundle.slots['1'].level === 5, 'the offline save is queued, not reported as uploaded');
  await page.reload();
  await play('second offline boot');
  ok((await localSlot()).level === 7, 'the offline save is still there after reopening offline');
  ok((await cloud()).pending, 'the upload is still queued');
  net.down = false;
  await context.setOffline(false);
  await poll(() => users.get('pilot').bundle.slots['1'].level === 7, 'queued save uploaded after reconnecting', 30000);
  await poll(async () => !(await cloud()).pending, 'queued save acknowledged', 15000);
  ok(posts.at(-1).expectedRevision === 1 && users.get('pilot').revision === 2, 'synced with compare-and-swap at the right revision');
  await poll(async () => (await offline()).shown.includes('ซิงก์เซฟแล้ว ✓'), 'sync line', 10000);
  ok(true, 'sync confirmation shown after reconnecting');
  ok(failures.length === 0, 'no failed requests after reconnecting' + (failures.length ? ': ' + failures.join(', ') : ''));

  // 3b. Online, but the account server is down: no wall, a short countdown.
  net.apiDown = true;
  await page.reload();
  await page.locator('#play').click();
  await page.getByRole('heading', {name: 'เล่นต่อขณะออฟไลน์'}).waitFor();
  const countdown = Date.now();
  await poll(() => page.evaluate(() => document.body.classList.contains('playing')), 'auto start while the API is down', 120000);
  ok(Date.now() - countdown >= 3000, 'account server down: the local save of the last account starts by itself after the countdown');
  ok((await localSlot()).level === 7 && (await cloud()).user.username === 'pilot', 'it is the same account and save');
  net.apiDown = false;
  failures.length = 0;
  consoleErrors.length = 0; // the 503 answers above were on purpose

  // 4. A new build is deployed: installs in the background, offered, swapped.
  net.next = NEXT;
  net.served.length = 0;
  await page.evaluate(() => window.toonOffline.checkForUpdate());
  await page.locator('#toon-update').waitFor({state: 'visible', timeout: 120000});
  ok((await page.locator('#toon-update').innerText()) === 'มีเวอร์ชันใหม่ แตะเพื่ออัปเดต', 'update offered while playing');
  const fetchedForUpdate = net.served.filter(url => url.endsWith('.gz.wasm'));
  ok(fetchedForUpdate.length === 0, 'unchanged game parts are reused from the old cache, not downloaded again');
  ok((await cacheNames()).length === 2, 'the new build waits in its own cache beside the one in use');
  await Promise.all([page.waitForEvent('load'), page.locator('#toon-update').click()]);
  await poll(() => page.evaluate(() => !!document.querySelector('meta[name="toon-test-build"]')), 'new build page', 30000);
  ok(true, 'tapping the offer reloads into the new build');
  await poll(async () => JSON.stringify(await cacheNames()) === JSON.stringify(['toon-tale-' + NEXT]), 'old cache deleted', 15000);
  ok(true, 'the old build cache is deleted on activation');
  status = await offline();
  ok(status.build === NEXT, 'the page and the service worker are the same new build');
  await page.locator('#play').click();
  await page.getByRole('button', {name: 'เล่นต่อจากเซฟออนไลน์'}).click();
  await poll(() => page.evaluate(() => document.body.classList.contains('playing')), 'new build boots online');
  ok((await localSlot()).level === 7, 'the update kept the save');
  await poll(async () => (await offline()).ready, 'new build ready offline', 30000);
  // 5. The new build also boots without a network.
  net.down = true;
  await context.setOffline(true);
  failures.length = 0;
  await page.reload();
  ok(await page.evaluate(() => !!document.querySelector('meta[name="toon-test-build"]')), 'offline reload opens the new build');
  await play('offline boot of the new build');
  ok(failures.length === 0, 'no failed requests in the new build offline' + (failures.length ? ': ' + failures.join(', ') : ''));
  // 6. Deployed while the game was closed: the next launch takes it before play.
  net.down = false;
  await context.setOffline(false);
  net.next = AGAIN;
  await page.reload();
  await poll(() => page.evaluate(v => { const m = document.querySelector('meta[name="toon-test-build"]'); return m && m.content === v; }, AGAIN), 'next launch takes the newer build', 60000);
  ok(true, 'a build deployed while closed is applied at the next launch, before play');
  await poll(async () => JSON.stringify(await cacheNames()) === JSON.stringify(['toon-tale-' + AGAIN]), 'only the newest cache', 15000);
  ok((await offline()).build === AGAIN, 'only the newest build remains cached');
  ok(errors.length === 0, 'no page errors' + (errors.length ? ': ' + errors.join(' | ') : ''));
  const network = consoleErrors.filter(text => /net::|Failed to load|Failed to fetch|service ?worker/i.test(text));
  ok(network.length === 0, 'no network or service worker errors in the console' + (network.length ? ': ' + network.join(' | ') : ''));
  console.log(`Web offline: ${checks} checks passed`);
} catch (error) {
  console.error('UI at failure:', await page.locator('body').innerText().catch(() => ''));
  console.error('offline status:', await page.evaluate(() => window.toonOffline && window.toonOffline.status()).catch(() => ''));
  console.error('failed requests:', failures, 'page errors:', errors, 'console errors:', consoleErrors.slice(-20));
  throw error;
} finally {
  await browser.close();
  server.close();
}
