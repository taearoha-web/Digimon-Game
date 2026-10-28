import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {assetHeaders, serveStatic} from '../server/static.js';
import worker from '../../worker/worker.mjs';

const ORIGIN = 'https://toon-tale.example';

function assets(files) {
  const seen = [];
  return {
    seen,
    async fetch(request) {
      const path = new URL(request.url).pathname;
      seen.push(path);
      if (path === '/index.html') return new Response(null, {status: 307, headers: {location: '/'}});
      const file = files[path];
      if (!file) return new Response('Not found', {status: 404, headers: {'content-type': 'text/plain', 'cache-control': 'public, max-age=0'}});
      return new Response(file.body, {status: 200, headers: {'content-type': file.type, 'cache-control': 'public, max-age=0, must-revalidate', etag: '"x"'}});
    },
  };
}

const FILES = {
  '/sw.js': {body: 'self.addEventListener("fetch", () => {});', type: 'application/javascript'},
  '/': {body: '<!doctype html><title>Toon Tale</title>', type: 'text/html'},
  '/manifest.webmanifest': {body: '{"name":"Toon Tale"}', type: 'application/octet-stream'},
  '/game.c341e4a4.part001.gz.wasm': {body: new Uint8Array([0x1f, 0x8b, 8]), type: 'application/wasm'},
  '/accounts.ffdba3e2a484.js': {body: 'void 0', type: 'application/javascript'},
  '/index.js': {body: 'var Engine', type: 'application/javascript'},
};

test('sw.js is never cached, is JavaScript and may control the whole site', async () => {
  const env = {ASSETS: assets(FILES)};
  const response = await serveStatic(new Request(`${ORIGIN}/sw.js`), env);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-cache, no-store, must-revalidate');
  assert.equal(response.headers.get('content-type'), 'text/javascript; charset=utf-8');
  assert.equal(response.headers.get('service-worker-allowed'), '/');
  assert.equal(response.headers.get('etag'), '"x"');
  assert.match(await response.text(), /addEventListener/);
});

test('the page and manifest revalidate; content-named files are immutable; game parts are not re-encoded', async () => {
  const env = {ASSETS: assets(FILES)};
  const page = await serveStatic(new Request(`${ORIGIN}/`), env);
  assert.equal(page.headers.get('cache-control'), 'no-cache');
  assert.equal(page.headers.get('content-type'), 'text/html; charset=utf-8');
  const manifest = await serveStatic(new Request(`${ORIGIN}/manifest.webmanifest?v=23f2bff9c6ec`), env);
  assert.equal(manifest.headers.get('cache-control'), 'no-cache');
  assert.equal(manifest.headers.get('content-type'), 'application/manifest+json; charset=utf-8');
  const part = await serveStatic(new Request(`${ORIGIN}/game.c341e4a4.part001.gz.wasm`), env);
  assert.equal(part.headers.get('cache-control'), 'public, max-age=31536000, immutable, no-transform');
  assert.equal(part.headers.get('content-type'), 'application/wasm');
  assert.deepEqual(new Uint8Array(await part.arrayBuffer()), new Uint8Array([0x1f, 0x8b, 8]));
  const script = await serveStatic(new Request(`${ORIGIN}/accounts.ffdba3e2a484.js`), env);
  assert.equal(script.headers.get('cache-control'), 'public, max-age=31536000, immutable');
  const loader = await serveStatic(new Request(`${ORIGIN}/index.js`), env);
  assert.equal(loader.headers.get('cache-control'), 'no-cache');
});

test('missing files and redirects keep their own status and headers', async () => {
  const env = {ASSETS: assets(FILES)};
  const missing = await serveStatic(new Request(`${ORIGIN}/sw.js.map`), env);
  assert.equal(missing.status, 404);
  assert.equal(missing.headers.get('content-type'), 'text/plain');
  const redirect = await serveStatic(new Request(`${ORIGIN}/index.html`, {redirect: 'manual'}), env);
  assert.equal(redirect.status, 307);
  assert.equal(redirect.headers.get('location'), '/');
  assert.equal(redirect.headers.get('cache-control'), 'no-cache');
  assert.equal(redirect.headers.get('content-type'), null);
});

test('the Worker sends game files to the asset policy and /api/account/* to the account API', async () => {
  const env = {ASSETS: assets(FILES)};
  const sw = await worker.fetch(new Request(`${ORIGIN}/sw.js`), env);
  assert.equal(sw.headers.get('cache-control'), 'no-cache, no-store, must-revalidate');
  const api = await worker.fetch(new Request(`${ORIGIN}/api/account/session`), env);
  assert.equal(api.status, 503); // no DB binding in this test: the API, not a static file, answered
  assert.equal(api.headers.get('cache-control'), 'no-store, private');
  assert.deepEqual(env.ASSETS.seen, ['/sw.js']);
});

test('the policy names match what package_web.py publishes and its _headers file', () => {
  assert.deepEqual(assetHeaders('/font-mitr.847340933424.ttf'), {'cache-control': 'public, max-age=31536000, immutable'});
  assert.deepEqual(assetHeaders('/og.jpg'), {});
  const packager = readFileSync(new URL('../../../tools/package_web.py', import.meta.url), 'utf8');
  const rules = packager.slice(packager.indexOf('HEADERS = """'));
  for (const rule of ['/sw.js\n  Cache-Control: no-cache, no-store, must-revalidate', '/*.gz.wasm\n  Cache-Control: public, max-age=31536000, immutable, no-transform']) {
    assert.ok(rules.includes(rule), rule);
  }
  const config = JSON.parse(readFileSync(new URL('../../worker/wrangler.example.jsonc', import.meta.url), 'utf8'));
  for (const path of ['/api/account/*', '/sw.js', '/']) assert.ok(config.assets.run_worker_first.includes(path), path);
});
