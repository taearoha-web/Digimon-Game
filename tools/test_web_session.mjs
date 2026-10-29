import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Run the actual diagnostic/lifecycle script with deterministic browser events.
// This verifies contracts; it is not an iPhone/WebKit playtest.
const source = readFileSync(new URL('./web/session.js', import.meta.url), 'utf8');
let checks = 0;
function check(condition, message) { assert.ok(condition, message); checks++; }
function boot(storage = new Map(), options = {}) {
  let now = 100000, callback, frameCallback, released = 0, requests = 0;
  const events = new Map(), canvasEvents = new Map(), docEvents = new Map();
  const elements = [];
  function element(tag) {
    return { tag, children: [], style: {}, append(...children) { this.children.push(...children); },
      setAttribute() {}, focus() {}, select() {}, remove() { this.removed = true; }, addEventListener(name, cb) { this[name] = cb; } };
  }
  const canvas = { width: 1920, height: 884, addEventListener: (name, cb) => canvasEvents.set(name, cb) };
  const button = element('button');
  const document = { visibilityState: 'visible', body: element('body'),
    getElementById: id => id === 'canvas' ? canvas : button,
    addEventListener: (name, cb) => docEvents.set(name, cb),
    createElement: tag => { const e = element(tag); elements.push(e); return e; } };
  const window = { matchMedia: () => ({matches: true}), toonCloudModalOpen: () => false,
    performance: { getEntriesByType: () => [{type: 'reload'}] },
    requestAnimationFrame: cb => { frameCallback = cb; return 1; },
    cancelAnimationFrame: () => { frameCallback = null; },
    addEventListener: (name, cb) => events.set(name, cb) };
  const navigator = { standalone: true, userAgent: 'iPhone OS 19_1 Safari',
    clipboard: { writeText: async text => { navigator.copied = text; } },
    wakeLock: { request: async () => { requests++; if (options.deniedWake) throw Error('Denied');
      return { addEventListener() {}, release: async () => { released++; } }; } } };
  vm.runInNewContext(source, { window, document, navigator, localStorage: {
    getItem: key => { if (options.storageDenied) throw Error('Denied'); return storage.get(key) ?? null; },
    setItem: (key, value) => { if (options.storageDenied) throw Error('Denied'); storage.set(key, value); },
  }, Date: { now: () => now }, setInterval: cb => { callback = cb; return 1; }, clearInterval: () => { callback = null; } });
  return { window, document, navigator, button, elements, events, canvasEvents,
    tick(seconds = 30) { now += seconds * 1000; callback?.(); },
    frame(milliseconds) { frameCallback?.(milliseconds); },
    visibility(state) { document.visibilityState = state; docEvents.get('visibilitychange')(); },
    requests: () => requests, releases: () => released };
}
const settle = () => new Promise(resolve => setImmediate(resolve));
const storage = new Map(), b = boot(storage);
check(b.button.hidden && !storage.size, 'opening the loader does not overwrite previous-session evidence');
b.window.toonSession.begin('0.7.8', () => 512 * 1048576);
await settle();
check(b.requests() === 1, 'a supported screen wake lock is requested while playing');
b.window.toonSession.sample({ staticBytes: 100000, auto: true, audioStreamMode: true, soundPlayRequests: 1000, pressure: 1, pressureRaises: 2, heapMB: 199.25, zone: 'meadow', class: 'mage', username: 'secret-user', password: 'secret-password', inv: ['secret-item'] });
for (let i = 0; i < 400; i++) b.tick();
let record = JSON.parse(storage.get('toon_session_v1'));
check(record.samples.length === 60 && record.samples.at(-1).seconds === 12000, 'hours of play retain only sixty recent samples');
check(record.samples.at(-1).wasmBytes === 512 * 1048576 && record.samples.at(-1).auto && record.samples.at(-1).audioStreamMode && record.samples.at(-1).soundPlayRequests === 1000, 'heap, auto-hunt and observed audio-mode metrics persist');
check(record.samples.at(-1).pressure === 1 && record.samples.at(-1).pressureRaises === 2 && record.samples.at(-1).heapMB === 199.25, 'the memory guard level, its raises and heap reading reach the report');
check(!JSON.stringify(record).includes('secret'), 'account/save fields never enter the report');
check(storage.get('toon_session_v1').length <= 24000, 'the persisted diagnostic record has a fixed size budget');
b.visibility('hidden'); await settle();
check(b.window.toonRuntimePauseMask() === 1 && b.releases() === 1, 'hidden pages pause the runtime and release the wake lock');
b.window.toonCloudModalOpen = () => true;
check(b.window.toonRuntimePauseMask() === 3, 'hidden and account pause reasons compose');
b.visibility('visible'); await settle();
check(b.window.toonRuntimePauseMask() === 2 && b.requests() === 2, 'returning reacquires a lock but preserves account pause');
b.window.toonCloudModalOpen = () => false;
b.canvasEvents.get('webglcontextlost')();
check(JSON.parse(storage.get('toon_session_v1')).events.at(-1).type === 'webgl_context_lost', 'context loss is recorded before any reload');
b.events.get('error')({message: 'out of memory secret-password'});
check(JSON.parse(storage.get('toon_session_v1')).events.at(-1).type === 'memory_allocation_error', 'fatal errors are classified without storing raw private text');
for (let i = 0; i < 100; i++) b.window.toonSession.error('ordinary error');
check(JSON.parse(storage.get('toon_session_v1')).events.length <= 24 && JSON.parse(storage.get('toon_session_v1')).events.at(-1).count === 100, 'repeated errors coalesce and cannot grow the event ring');
const reopened = boot(storage);
check(!reopened.button.hidden, 'an interrupted session has a report button on the next loader');
reopened.window.toonSession.showReport();
check(reopened.window.toonRuntimePauseMask() === 4, 'a report pauses gameplay');
const textarea = reopened.elements.find(e => e.tag === 'textarea');
check(JSON.parse(textarea.value).previousSession.samples.length === 60, 'the previous report survives until it can be shared');
const pasted = JSON.parse(textarea.value);
check(Object.keys(pasted)[1] === 'previousSummary' && pasted.previousSummary.status === 'running' && pasted.previousSummary.lastSamples.length === 5 &&
  pasted.previousSummary.events.length === pasted.previousSession.events.length && pasted.previousSummary.growth.seconds > 0 &&
  pasted.previousSummary.timeline.length === 60 && /^\d+s wasm=\d+M video=/.test(pasted.previousSummary.timeline[0]),
  'the summary (how it ended, errors, last minutes) comes first so a cut-off paste still explains the interruption');
await reopened.elements.find(e => e.textContent === 'คัดลอกรายงาน').onclick();
check(reopened.navigator.copied === textarea.value, 'the report copy button uses the full bounded report');
reopened.elements.find(e => e.textContent === 'ปิด').onclick();
check(reopened.window.toonRuntimePauseMask() === 0, 'closing the report clears only its own pause reason');
reopened.window.toonSession.begin('0.7.8', () => null);
reopened.window.toonSession.end(); await settle();
check(JSON.parse(storage.get('toon_session_v1')).status === 'ended', 'clean engine exit is distinguished from interruption');
check(JSON.parse(reopened.window.toonSession.report()).previousSession.samples.length === 60, 'starting or exiting does not destroy previous-session evidence');
const denied = boot(new Map(), {storageDenied: true, deniedWake: true});
denied.window.toonSession.begin('0.7.8', () => { throw Error('Heap unavailable'); });
denied.tick(); await settle();
check(JSON.parse(denied.window.toonSession.report()).currentSession.samples.at(-1).wasmBytes === null, 'unavailable storage, wake lock and memory metrics never crash gameplay');
const corrupt = boot(new Map([['toon_session_v1', 'bad json']]));
check(corrupt.button.hidden, 'corrupt local diagnostic data is ignored safely');
const giant = boot(new Map([['toon_session_v1', 'x'.repeat(30000)]]));
check(giant.button.hidden, 'oversized diagnostic storage is ignored');
const denseStorage = new Map(), dense = boot(denseStorage);
dense.window.toonSession.begin('0.7.8', () => 1073741824);
dense.window.toonSession.sample(Object.fromEntries(['staticBytes', 'videoBytes', 'nodes', 'objects', 'resources', 'orphans', 'loot', 'quality', 'fps', 'auto', 'kills', 'saveAgeSeconds', 'pressure', 'pressureRaises', 'heapMB'].map(k => [k, 999999999999])));
for (let i = 0; i < 100; i++) dense.tick();
check(denseStorage.get('toon_session_v1').length <= 24000 && JSON.parse(denseStorage.get('toon_session_v1')).lastSeenAt === 3100000, 'even dense metrics keep persisting the newest sample within the size budget');
const diagnosticStorage = new Map(), d = boot(diagnosticStorage);
d.window.toonSession.begin('0.9.1', () => 250085376);
d.window.toonSession.sample({towerFloor:12,towerState:'spawning',pendingSpawns:8,spawnWorkMs:7.331,lastSkill:'armageddon',saveWorkMs:15.5,password:'secret-password'});
d.frame(0);d.frame(16);d.frame(176);
d.tick();
let diagnostic = JSON.parse(diagnosticStorage.get('toon_session_v1'));
check(diagnostic.diagnostics === 2 && diagnostic.navigationType === 'reload', 'new report identifies diagnostic generation and navigation type without calling reload a crash');
check(diagnostic.samples.at(-1).framesOver100 === 1 && diagnostic.samples.at(-1).maxFrameMs === 160, 'animation-frame gaps catch stalls between thirty-second snapshots');
check(diagnostic.samples.at(-1).towerFloor === 12 && diagnostic.samples.at(-1).pendingSpawns === 8 && diagnostic.samples.at(-1).spawnWorkMs === 7.33, 'report retains bounded Tower and work timing fields');
check(diagnostic.samples.at(-1).metricsAgeSeconds === 30, 'stale engine metrics are explicitly marked');
d.visibility('hidden'); d.frame(20000);d.visibility('visible');d.frame(21000);d.frame(21016);d.tick();
diagnostic = JSON.parse(diagnosticStorage.get('toon_session_v1'));
check(diagnostic.samples.at(-1).maxFrameMs === 16, 'time hidden does not become a false long frame');
d.window.toonSession.error('SCRIPT ERROR: Invalid call on previously freed instance. secret-password');
d.window.toonSession.error('   at: _attack (res://characters/hero.gd:722)');
diagnostic = JSON.parse(diagnosticStorage.get('toon_session_v1'));
check(diagnostic.events.at(-1).issue === 'freed_instance' && diagnostic.events.at(-1).file === 'res://characters/hero.gd' && diagnostic.events.at(-1).line === 722, 'split engine error/location callbacks form one actionable record');
check(diagnostic.errorCount === 1, 'location lines are not counted as additional runtime faults');
d.window.toonSession.error('WARNING: driver warning secret-password');
diagnostic = JSON.parse(diagnosticStorage.get('toon_session_v1'));
check(diagnostic.warningCount === 1 && diagnostic.errorCount === 1 && diagnostic.lastErrorCategory === 'script_error', 'engine warnings do not masquerade as runtime faults');
d.window.toonSession.error('ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()');
d.window.toonSession.error('   at: get_global_transform (scene/3d/node_3d.cpp:345)');
diagnostic = JSON.parse(diagnosticStorage.get('toon_session_v1'));
check(diagnostic.events.at(-1).issue === 'outside_tree' && diagnostic.events.at(-1).file === 'scene/3d/node_3d.cpp', 'native engine locations are retained without arbitrary message text');
check(diagnostic.events.at(-1).fn === 'get_global_transform', 'the engine function that reported a fault is retained');
d.window.toonSession.error('USER ERROR: Condition "!is_inside_tree()" is true. Returning: NodePath() secret-password');
d.window.toonSession.error('   at: get_path (scene/main/node.cpp:835)');
d.window.toonSession.error('   GDScript backtrace (most recent call first):');
d.window.toonSession.error('       [0] _spawn (res://combat/skill_show.gd:88) secret-password');
d.window.toonSession.error('       [1] _cast (res://characters/hero.gd:301)');
diagnostic = JSON.parse(diagnosticStorage.get('toon_session_v1'));
check(diagnostic.events.at(-1).fn === 'get_path' && diagnostic.events.at(-1).script.file === 'res://combat/skill_show.gd' && diagnostic.events.at(-1).script.line === 88 && !JSON.stringify(diagnostic).includes('secret'), 'the first game-script backtrace line is retained as file and line only');
for (let i=0;i<100;i++) d.window.toonSession.error(`SCRIPT ERROR: Invalid call at res://combat/test_${i}.gd:42 password=secret-password https://example.test/?token=secret-token`);
diagnostic = JSON.parse(diagnosticStorage.get('toon_session_v1'));
check(diagnostic.events.length === 24 && !JSON.stringify(diagnostic).includes('secret') && !JSON.stringify(diagnostic).includes('example.test'), 'distinct errors are bounded and no raw message, token, URL or account data persists');
d.canvasEvents.get('webglcontextrestored')();
check(JSON.parse(diagnosticStorage.get('toon_session_v1')).events.at(-1).type === 'webgl_context_restored', 'successful GPU context restoration is recorded separately');
console.log(`Web session: ${checks} checks passed (mock browser events, not device QA)`);
