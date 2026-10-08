import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { gzipSync } from 'node:zlib';

// Exercise the actual browser streaming loader without starting Godot.
const shell = readFileSync(new URL('./web/artifact_shell.html', import.meta.url), 'utf8');
const code = shell.slice(shell.indexOf('  const nativeFetch ='), shell.indexOf('  // Fullscreen hides'));
const payload = new TextEncoder().encode('Toon Tale: streaming world assets '.repeat(4096));
const compressed = gzipSync(payload);
let checks = 0;
function loader(bytes, options = {}) {
  const calls = [];
  const loaded = {};
  const packed = { 'index.pck': ['game.hash.gz.wasm', bytes.length, 'application/octet-stream'] };
  const native = async (input, init) => {
    calls.push({ input, init });
    if (options.status) return new Response('', { status: options.status });
    let cursor = 0;
    return new Response(new ReadableStream({
      pull(controller) {
        if (cursor === bytes.length) { controller.close(); return; }
        const count = cursor === 0 && options.tinyFirst ? 1 : 3072;
        controller.enqueue(bytes.slice(cursor, cursor + count));
        cursor = Math.min(bytes.length, cursor + count);
      },
    }));
  };
  const window = { fetch: native };
  new Function('window', 'PACKED', 'loaded', 'showProgress', 'DecompressionStream', code)(
    window, packed, loaded, () => {}, options.noDecompression ? undefined : DecompressionStream,
  );
  return { fetch: window.fetch, calls, loaded };
}
for (const [bytes, tinyFirst] of [[compressed, false], [compressed, true], [payload, false]]) {
  const l = loader(bytes, { tinyFirst });
  const response = await l.fetch(new URL('https://example.test/index.pck?v=3'));
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), payload);
  assert.equal(l.loaded['index.pck'], bytes.length);
  assert.equal(response.headers.get('content-type'), 'application/octet-stream');
  checks += 3;
}
const pass = loader(payload);
const controller = new AbortController();
await pass.fetch('https://example.test/index.js', { signal: controller.signal });
assert.equal(pass.calls[0].input, 'https://example.test/index.js');
assert.equal(pass.calls[0].init.signal, controller.signal);
checks += 2;
await assert.rejects(loader(compressed, { status: 404 }).fetch('index.pck'), /404/);
await assert.rejects(loader(new Uint8Array([0])).fetch('index.pck'), /ไฟล์เกมไม่สมบูรณ์/);
await assert.rejects(loader(compressed, { noDecompression: true }).fetch('index.pck'), /iOS 16.4/);
const broken = loader(compressed.slice(0, 10));
await assert.rejects(async () => (await broken.fetch('index.pck')).arrayBuffer());
checks += 4;
console.log(`Web loader: ${checks} checks passed`);
