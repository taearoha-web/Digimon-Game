import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// Exercise the real shell controller at Retina phone and desktop dimensions.
const shell = readFileSync(new URL('./web/artifact_shell.html', import.meta.url), 'utf8');
const start = shell.search(/^  (?:async )?function start\(\)/m);
assert.ok(start > 0, 'Shell boot entrypoint exists');
const code = shell.slice(shell.indexOf('  let renderQuality ='), start);
const events = new Map();
const canvas = { width: 0, height: 0, style: {} };
const window = { innerWidth: 956, innerHeight: 440, devicePixelRatio: 3,
  addEventListener: (name, callback) => events.set(name, callback) };
new Function('window', 'document', code)(window, { getElementById: () => canvas });
window.toonSetRenderQuality(2);
assert.equal(canvas.width, 2560);
assert.equal(canvas.height, 1178);
assert.equal(canvas.style.width, '956px');
assert.equal(canvas.style.height, '440px');
const highPixels = canvas.width * canvas.height;
assert.ok(highPixels < 0.85 * (956 * 3) * (440 * 3));
window.toonSetRenderQuality(1);
assert.equal(canvas.width, 1600);
window.toonSetRenderQuality(0);
assert.equal(canvas.width, 1280);
window.toonSetRenderQuality(2);
window.innerWidth = 440;
window.innerHeight = 956;
events.get('resize')();
assert.equal(canvas.width, 1178);
assert.equal(canvas.height, 2560);
assert.equal(canvas.style.width, '440px');
window.innerWidth = 1280;
window.innerHeight = 720;
window.devicePixelRatio = 1;
events.get('pageshow')();
assert.equal(canvas.width, 1280);
assert.equal(canvas.height, 720);
console.log('Web resolution: Retina pixel budget, quality changes, rotation and restore passed');
