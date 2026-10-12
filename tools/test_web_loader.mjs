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
  const calls = [], events = [], progress = [];
  const loaded = {};
  const parts = options.parts || [bytes];
  const names = parts.map((_, i) => `game.hash.part${i + 1}.gz.wasm`);
  const file = options.parts ? names : names[0];
  const advertisedSize = options.advertisedSize ?? bytes.length;
  const packed = { 'index.pck': [file, advertisedSize, 'application/octet-stream'] };
  const native = async (input, init) => {
    calls.push({ input, init });
    const index = Math.max(0, names.indexOf(input));
    events.push(['open', index]);
    if (options.status && index === (options.statusPart ?? 0)) return new Response('', { status: options.status });
    let cursor = 0;
    const part = parts[index];
    return new Response(new ReadableStream({
      pull(controller) {
        if (cursor === part.length) { events.push(['done', index]); controller.close(); return; }
        const count = cursor === 0 && options.tinyFirst ? 1 : (options.networkChunk ?? 3072);
        controller.enqueue(part.slice(cursor, cursor + count));
        cursor = Math.min(part.length, cursor + count);
      },
      cancel() { events.push(['cancel', index]); },
    }, { highWaterMark: 0 }));
  };
  const window = { fetch: native };
  new Function('window', 'PACKED', 'loaded', 'showProgress', 'DecompressionStream', code)(
    window, packed, loaded, () => progress.push(loaded['index.pck'] || 0), options.noDecompression ? undefined : DecompressionStream,
  );
  return { fetch: window.fetch, calls, loaded, events, progress, names, advertisedSize };
}

for (const [bytes, tinyFirst] of [[compressed, false], [compressed, true], [payload, false]]) {
  const l = loader(bytes, { tinyFirst });
  const response = await l.fetch(new URL('https://example.test/index.pck?v=3'));
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), payload);
  assert.equal(l.loaded['index.pck'], bytes.length);
  assert.equal(response.headers.get('content-type'), 'application/octet-stream');
  checks += 3;
}

// A server may already decode the single gzip file, while the manifest still
// advertises compressed bytes. Progress must remain monotonic and bounded.
const decoded = loader(payload, { advertisedSize: compressed.length, tinyFirst: true });
assert.deepEqual(new Uint8Array(await (await decoded.fetch('index.pck')).arrayBuffer()), payload);
assert.equal(decoded.loaded['index.pck'], compressed.length);
assert.ok(decoded.progress.every((n, i, a) => n <= compressed.length && (!i || n >= a[i - 1])));
checks += 3;

// Boundaries inside the two-byte magic, ten-byte gzip header, deflate body and
// final checksum must all feed one inflater. Include very small network chunks.
const partitions = [
  [compressed.subarray(0, 1), compressed.subarray(1)],
  [compressed.subarray(0, 2), compressed.subarray(2, 10), compressed.subarray(10)],
  [compressed.subarray(0, 13), compressed.subarray(13, 41), compressed.subarray(41, -3), compressed.subarray(-3)],
  [new Uint8Array(0), compressed.subarray(0, 1), new Uint8Array(0), compressed.subarray(1)],
];
for (const parts of partitions) {
  const l = loader(compressed, { parts, tinyFirst: true, networkChunk: 7 });
  const signal = new AbortController().signal;
  const response = await l.fetch(new Request('https://example.test/index.pck?version=4'), { signal, cache: 'force-cache' });
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), payload);
  assert.deepEqual(l.calls.map(c => c.input), l.names);
  assert.ok(l.calls.every(c => c.init.signal === signal && c.init.cache === 'force-cache'));
  assert.equal(l.loaded['index.pck'], compressed.length);
  assert.ok(l.progress.every((n, i, a) => n <= compressed.length && (!i || n >= a[i - 1])));
  for (let i = 1; i < parts.length; ++i) {
    assert.ok(l.events.findIndex(e => e[0] === 'done' && e[1] === i - 1) < l.events.findIndex(e => e[0] === 'open' && e[1] === i));
  }
  checks += 5 + parts.length - 1;
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

const missingPart = loader(compressed, { parts: partitions[2], status: 404, statusPart: 1 });
await assert.rejects(async () => (await missingPart.fetch('index.pck')).arrayBuffer(), /404/);
assert.equal(missingPart.calls.length, 2); // Stop: never request later parts.
const truncatedPart = loader(compressed, { parts: [compressed.subarray(0, 10), compressed.subarray(10, -2)] });
await assert.rejects(async () => (await truncatedPart.fetch('index.pck')).arrayBuffer());
const unsupported = loader(compressed, { parts: partitions[0], noDecompression: true });
await assert.rejects(unsupported.fetch('index.pck'), /iOS 16.4/);
assert.ok(unsupported.events.some(e => e[0] === 'cancel'));
checks += 5;

// Consumer cancellation must stop before opening any later published parts.
// Plain bytes exercise cancellation without the inflater's internal prefetch.
const cancelled = loader(payload, { parts: [payload, payload], networkChunk: 7 });
const body = (await cancelled.fetch('index.pck')).body.getReader();
await body.read();
await body.cancel('test abort');
await new Promise(resolve => setTimeout(resolve, 0));
assert.equal(cancelled.calls.length, 1);
assert.ok(cancelled.events.some(e => e[0] === 'cancel'));
checks += 2;

console.log(`Web loader: ${checks} checks passed`);
