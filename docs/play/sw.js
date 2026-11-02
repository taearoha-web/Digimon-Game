/* Toon Tale offline service worker. tools/package_web.py writes docs/play/sw.js
 * from this template with the build id and file list baked in.
 *
 * One cache per build ("toon-tale-<build>") holds every file that boots the
 * game: the page, scripts, styles, fonts, icons, manifest, engine and every
 * game part. This worker answers only from its own build's cache, so a page
 * never mixes files of two builds; the next build installs beside it, waits,
 * and takes over when the player taps "update" or opens the game again.
 *
 * First install: only the small files are cached before the worker takes
 * control, so the first play is not held back by a 76 MB download. The game's
 * own requests are copied into the cache as they stream in, and the page fills
 * whatever is still missing in the background (tools/web/offline.js).
 * Update: the new build caches everything (reusing unchanged, content-named
 * files from the old cache) before it can replace the build in use. */
'use strict';
const BUILD = '5cd6c12114af';
const PREFIX = 'toon-tale-';
const CACHE = PREFIX + BUILD;
// [path relative to the scope, bytes (0 = unknown), content-addressed, small/core]
const FILES = [["./",0,false,true],["accounts.de8668e7e537.js",66951,true,true],["accounts.e72d966b1892.css",7674,true,true],["apple-touch-icon.png?v=1196b39e2aea",82955,true,true],["engine.d0b30e03.gz.wasm",7975981,true,false],["font-fredoka.2ba02e68b152.ttf",159184,true,true],["font-mitr.847340933424.ttf",222116,true,true],["font-noto-sans-thai.5a1c559bb539.ttf",218652,true,true],["game.2f1a7845.part001.gz.wasm",16777216,true,false],["game.2f1a7845.part002.gz.wasm",16777216,true,false],["game.2f1a7845.part003.gz.wasm",16777216,true,false],["game.2f1a7845.part004.gz.wasm",16777216,true,false],["game.2f1a7845.part005.gz.wasm",6905289,true,false],["icon-512.png?v=1196b39e2aea",567887,true,true],["icon-maskable-192.png?v=1196b39e2aea",74556,true,true],["icon-maskable-512.png?v=1196b39e2aea",430809,true,true],["icon.png?v=1196b39e2aea",93421,true,true],["index.audio.worklet.js",7298,false,true],["index.js",331495,false,true],["manifest.webmanifest?v=23f2bff9c6ec",1298,true,true],["offline.a055cf702a50.js",15173,true,true],["session.efd8d5072c18.js",19536,true,true]];
const SCOPE = new URL(self.registration.scope);
const INDEX = new URL('./', SCOPE).href;
const BY_URL = new Map(), BY_PATH = new Map();
for (const file of FILES) {
  const url = new URL(file[0], SCOPE);
  const entry = {url: url.href, size: file[1], immutable: file[2], core: file[3]};
  BY_URL.set(url.href, entry);
  BY_PATH.set(url.origin + url.pathname, entry);
}

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

// Copy only what describes the bytes: the body is already decoded, so a
// Content-Encoding / Content-Length from the network would be wrong here.
function cleanHeaders(source) {
  const headers = new Headers();
  for (const name of ['content-type', 'last-modified', 'etag']) {
    const value = source.get(name);
    if (value) headers.set(name, value);
  }
  return headers;
}

// Streams into the cache; a short or failed body rejects instead of storing a
// truncated game part.
function store(cache, entry, response) {
  let body = response.body, count = 0;
  if (body && entry.size) {
    body = body.pipeThrough(new TransformStream({
      transform(chunk, controller) { count += chunk.byteLength; controller.enqueue(chunk); },
      flush() { if (count !== entry.size) throw new Error('incomplete ' + entry.url + ' ' + count + '/' + entry.size); },
    }));
  }
  return cache.put(entry.url, new Response(body, {status: 200, headers: cleanHeaders(response.headers)}));
}

async function download(cache, entry, attempts = 4) {
  let lastError;
  for (let attempt = 0; attempt < attempts; attempt++) {
    try {
      const response = await fetch(entry.url, {cache: 'reload', credentials: 'same-origin'});
      if (!response.ok) throw new Error('HTTP ' + response.status + ' ' + entry.url);
      await store(cache, entry, response);
      return;
    } catch (error) {
      lastError = error;
      if (attempt + 1 < attempts) await sleep(1000 * 3 ** attempt);
    }
  }
  throw lastError;
}

// Content-named files (hash in the name or ?v=hash) are identical in every
// build that lists them: take them from an older build's cache when present.
async function reuse(cache, entry) {
  if (!entry.immutable) return false;
  for (const key of await caches.keys()) {
    if (!key.startsWith(PREFIX) || key === CACHE) continue;
    const old = await (await caches.open(key)).match(entry.url);
    if (old) { await cache.put(entry.url, old); return true; }
  }
  return false;
}

async function fill(cache, entries, parallel) {
  const queue = entries.slice();
  async function worker() {
    while (queue.length) {
      const entry = queue.shift();
      if (await cache.match(entry.url)) continue;
      if (await reuse(cache, entry)) continue;
      await download(cache, entry);
    }
  }
  await Promise.all(Array.from({length: parallel}, worker));
}

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    const entries = Array.from(BY_URL.values());
    const firstInstall = !self.registration.active;
    await fill(cache, entries.filter(entry => entry.core), 4);
    if (firstInstall) { await self.skipWaiting(); return; }
    // An update must hold the complete build before it may replace the one in
    // use. A failed install is retried by the browser later and resumes here.
    await fill(cache, entries.filter(entry => !entry.core), 1);
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith(PREFIX) && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('message', event => {
  const data = event.data || {};
  if (data.type === 'SKIP_WAITING') self.skipWaiting();
  else if (data.type === 'BUILD' && event.ports && event.ports[0]) event.ports[0].postMessage({build: BUILD});
});

const OFFLINE_PAGE = '<!doctype html><html lang="th"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
  '<title>Toon Tale</title><body style="margin:0;display:grid;place-items:center;min-height:100vh;background:#0c1230;color:#f4f7ff;font-family:system-ui,sans-serif;text-align:center;padding:16px">' +
  '<div><h1>Toon Tale</h1><p>ออฟไลน์อยู่ และเครื่องนี้ยังไม่ได้เก็บเกมไว้เล่นออฟไลน์</p><p>ต่ออินเทอร์เน็ตแล้วเปิดเกมอีกครั้ง</p>' +
  '<button onclick="location.reload()" style="min-height:44px;padding:0 20px;border:0;border-radius:999px;background:#ff7a3d;font-size:16px">ลองใหม่</button></div></body></html>';

async function navigation(request) {
  const cache = await caches.open(CACHE);
  const page = await cache.match(INDEX);
  if (page) return page;
  try { return await fetch(request); }
  catch (_) { return new Response(OFFLINE_PAGE, {status: 503, headers: {'content-type': 'text/html; charset=utf-8'}}); }
}

async function cached(event, request, entry) {
  const cache = await caches.open(CACHE);
  const hit = await cache.match(request.url) || await cache.match(entry.url);
  if (hit) return hit;
  const response = await fetch(request);
  // Copy the game's own download into the cache while it streams to the page.
  if (response.status === 200 && response.type === 'basic' && response.body && request.url === entry.url) {
    const [page, copy] = response.body.tee();
    event.waitUntil(store(cache, entry, new Response(copy, {headers: response.headers})).catch(() => {}));
    return new Response(page, {status: response.status, statusText: response.statusText, headers: response.headers});
  }
  return response;
}

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== SCOPE.origin || !url.pathname.startsWith(SCOPE.pathname)) return;
  // The page's background download goes straight to the network.
  if (request.headers.get('x-toon-precache')) return;
  const path = url.pathname.slice(SCOPE.pathname.length);
  if (path.startsWith('api/')) return;
  if (request.mode === 'navigate') {
    if (path === '' || path === 'index.html') event.respondWith(navigation(request));
    return;
  }
  const entry = BY_URL.get(url.href) || BY_PATH.get(url.origin + url.pathname);
  if (entry) event.respondWith(cached(event, request, entry));
});
