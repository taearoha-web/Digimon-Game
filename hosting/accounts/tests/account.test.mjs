import test from 'node:test';
import assert from 'node:assert/strict';
import {handleAccountRequest} from '../server/accounts.js';
import {D1Sqlite} from './d1-sqlite.mjs';

const ORIGIN = 'https://toon-tale.example';
const PASSWORD = 'CuteDragonPass2026!';
const OTHER_PASSWORD = 'AnotherStrongPassword2026!';
const sample = (level = 12, name = 'น้องแมว') => ({version: 1, class: 'mage', level, name,
  hp: 500, mp: 320, gold: 2000, attrs: {int: 15}, skills: {fireball: 2}, equip: {}, inv: [], storage: [],
  loadout: ['fireball', '', '', '', '', '', '', ''], zone: 'meadow', quests: {}, flags: {daily_last: '2026-10-11'},
  look: {skin: 1}, party: [], paragon: {}, play_time: 3200, future_field: {preserve: true},
});
const bundle = (profile = sample()) => ({slots: {'1': profile}, selectedSlot: 1});

function harness(t) {
  const DB = new D1Sqlite();
  const accountsByCookie = new Map();
  t.after(() => DB.close());
  async function call(path, {method = 'GET', body, cookie, origin = ORIGIN, type = 'application/json', ip = '203.0.113.20', raw, headers = {}} = {}) {
    const request = new Request(`${ORIGIN}/api/account/${path}`, {
      method, headers: {...(accountsByCookie.has(cookie) ? {'x-toon-account-id': accountsByCookie.get(cookie)} : {}),
        ...headers, ...(method === 'POST' ? {'content-type': type, origin} : {}),
        'cf-connecting-ip': ip, ...(cookie ? {cookie} : {})},
      body: method === 'POST' ? raw ?? JSON.stringify(body ?? {}) : undefined,
    });
    const response = await handleAccountRequest(request, {DB});
    const json = await response.json();
    const setCookie = response.headers.get('set-cookie');
    const responseCookie = setCookie?.split(';')[0];
    if (json.user?.id && responseCookie) accountsByCookie.set(responseCookie, json.user.id);
    return {status: response.status, body: json, headers: response.headers, cookie: responseCookie};
  }
  async function register(username = 'toonhero') {
    const created = await call('register', {method: 'POST', body: {username, password: PASSWORD}});
    assert.equal(created.status, 201, JSON.stringify(created.body));
    return created;
  }
  return {DB, call, register};
}

test('registration stores salted PBKDF2 hashes and hash-only secrets, cookie flags and no caching', async t => {
  const {DB, register, call} = harness(t);
  const account = await register(' ToonHero ');
  assert.equal(account.body.user.username, 'toonhero');
  assert.match(account.body.recoveryCode, /^(?:[A-F0-9]{5}-){7}[A-F0-9]{5}$/);
  assert.match(account.headers.get('set-cookie'), /^__Host-toon_session=[A-Za-z0-9_-]{43}; Path=\//);
  for (const flag of ['HttpOnly', 'Secure', 'SameSite=Strict', 'Max-Age=2592000']) assert.ok(account.headers.get('set-cookie').includes(flag));
  assert.equal(account.headers.get('cache-control'), 'no-store, private');
  const stored = DB.sqlite.prepare('SELECT * FROM toon_users').get();
  assert.equal(stored.password_iterations, 100000);
  assert.match(stored.password_salt, /^[a-f0-9]{32}$/);
  assert.match(stored.password_hash, /^[a-f0-9]{64}$/);
  assert.notEqual(stored.password_hash, PASSWORD);
  assert.notEqual(stored.recovery_hash, account.body.recoveryCode);
  const session = DB.sqlite.prepare('SELECT * FROM toon_sessions').get();
  assert.match(session.token_hash, /^[a-f0-9]{64}$/);
  assert.ok(!account.cookie.includes(session.token_hash));
  assert.equal(session.expires_at - session.created_at, 2592000);
  const state = await call('session', {cookie: account.cookie});
  assert.deepEqual(state.body, {user: account.body.user});
  const second = await register('another_id');
  const secondUser = DB.sqlite.prepare('SELECT * FROM toon_users WHERE username = ?').get('another_id');
  assert.notEqual(stored.password_salt, secondUser.password_salt);
  assert.notEqual(stored.password_hash, secondUser.password_hash);
  assert.notEqual(account.body.user.id, second.body.user.id);
});

test('existing IDs collide safely, concurrent duplicate register is atomic and malformed credentials rejected', async t => {
  const {DB, register, call} = harness(t);
  await register();
  const duplicate = await call('register', {method: 'POST', body: {username: 'TOONHERO', password: PASSWORD}});
  assert.equal(duplicate.status, 409);
  assert.equal(duplicate.body.error.code, 'id_unavailable');
  assert.equal(DB.sqlite.prepare('SELECT count(*) AS n FROM toon_sessions').get().n, 1);
  for (const username of ['ab', 'space name', 'ผู้เล่น', '__proto__!', 'a'.repeat(25)]) {
    const result = await call('register', {method: 'POST', body: {username, password: PASSWORD}});
    assert.equal(result.status, 400);
  }
  for (const password of ['short', 'x'.repeat(129), 12345]) {
    const result = await call('register', {method: 'POST', body: {username: 'validid', password}});
    assert.equal(result.status, 400);
  }
  const attempts = await Promise.all([0, 1].map(() => call('register', {method: 'POST', body: {username: 'race_id', password: PASSWORD}})));
  assert.deepEqual(attempts.map(attempt => attempt.status).sort(), [201, 409]);
  assert.equal(DB.sqlite.prepare("SELECT count(*) AS n FROM toon_users WHERE username = 'race_id'").get().n, 1);
});

test('login works across independent devices, wrong and missing IDs have identical errors', async t => {
  const {register, call} = harness(t);
  const account = await register();
  const wrong = await call('login', {method: 'POST', body: {username: 'toonhero', password: OTHER_PASSWORD}});
  const absent = await call('login', {method: 'POST', body: {username: 'absenthero', password: OTHER_PASSWORD}});
  assert.equal(wrong.status, 401);
  assert.deepEqual(wrong.body, absent.body);
  const device2 = await call('login', {method: 'POST', body: {username: 'TOONHERO', password: PASSWORD}});
  assert.equal(device2.status, 200);
  assert.notEqual(device2.cookie, account.cookie);
  assert.deepEqual((await call('session', {cookie: device2.cookie})).body.user, account.body.user);
});

test('unauthenticated, spoofed account and cross-account access cannot access saves', async t => {
  const {register, call} = harness(t);
  const a = await register('account_a');
  const b = await register('account_b');
  assert.equal((await call('save')).status, 401);
  assert.equal((await call('save', {cookie: '__Host-toon_session=not-a-token'})).status, 401);
  assert.equal((await call('save', {cookie: `${a.cookie}; ${b.cookie}`})).status, 401);
  const write = await call('save', {method: 'POST', cookie: a.cookie, body: {expectedRevision: 0, bundle: bundle(), userId: b.body.user.id}});
  assert.equal(write.status, 200);
  assert.equal((await call(`save?userId=${a.body.user.id}`, {cookie: b.cookie})).body.revision, 0);
  assert.equal((await call('save', {cookie: a.cookie})).body.bundle.slots['1'].name, 'น้องแมว');
  const otherHistory = await call('save/history', {cookie: b.cookie});
  assert.deepEqual(otherHistory.body.snapshots, []);
  assert.equal((await call('save/restore', {method: 'POST', cookie: b.cookie, body: {expectedRevision: 0, revision: 1, userId: a.body.user.id}})).status, 404);
});

test('shared-cookie account switches reject stale-tab save/read/history/restore/logout even at matching revisions', async t => {
  const {register, call} = harness(t);
  const a = await register('tab_account_a');
  const b = await register('tab_account_b');
  for (const account of [a, b]) {
    assert.equal((await call('save', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 0, bundle: bundle(sample(account === a ? 80 : 20))}})).status, 200);
  }
  // Browser tab A still believes A is signed in but the shared browser cookie
  // was replaced with B's cookie by tab B. The server must detect that switch.
  const staleHeader = {'x-toon-account-id': a.body.user.id};
  for (const path of ['save', 'save/history']) {
    const result = await call(path, {cookie: b.cookie, headers: staleHeader});
    assert.equal(result.status, 409);
    assert.equal(result.body.error.code, 'account_changed');
  }
  const staleSave = await call('save', {method: 'POST', cookie: b.cookie, headers: staleHeader, body: {expectedRevision: 1, bundle: bundle(sample(99))}});
  assert.equal(staleSave.status, 409);
  assert.equal(staleSave.body.error.code, 'account_changed');
  assert.equal((await call('save/restore', {method: 'POST', cookie: b.cookie, headers: staleHeader, body: {expectedRevision: 1, revision: 1}})).status, 409);
  assert.equal((await call('logout', {method: 'POST', cookie: b.cookie, headers: staleHeader})).status, 409);
  const bSave = await call('save', {cookie: b.cookie});
  assert.equal(bSave.body.userId, b.body.user.id);
  assert.equal(bSave.body.revision, 1);
  assert.equal(bSave.body.bundle.slots['1'].level, 20);
  assert.ok((await call('session', {cookie: b.cookie})).body.user);
  assert.equal((await call('save', {cookie: b.cookie, headers: {'x-toon-account-id': ''}})).status, 409);
  assert.equal((await call('save', {cookie: a.cookie})).body.bundle.slots['1'].level, 80);
});

test('four-slot saves preserve profiles and CAS prevents stale and concurrent device overwrite', async t => {
  const {register, call, DB} = harness(t);
  const account = await register();
  const other = await call('login', {method: 'POST', body: {username: 'toonhero', password: PASSWORD}});
  assert.deepEqual((await call('save', {cookie: account.cookie})).body, {userId: account.body.user.id, revision: 0, bundle: {slots: {}, selectedSlot: 1}, updatedAt: null});
  const full = {slots: Object.fromEntries([1, 2, 3, 4].map(n => [n, sample(n * 10, `Hero ${n}`)])), selectedSlot: 4};
  const first = await call('save', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 0, bundle: full}});
  assert.equal(first.status, 200);
  assert.equal(first.body.revision, 1);
  assert.match(first.body.updatedAt, /^\d{4}-\d{2}-\d{2}T/);
  assert.deepEqual((await call('save', {cookie: other.cookie})).body.bundle, full);
  const stale = await call('save', {method: 'POST', cookie: other.cookie, body: {expectedRevision: 0, bundle: bundle(sample(1))}});
  assert.equal(stale.status, 409);
  assert.equal(stale.body.revision, 1);
  assert.deepEqual((await call('save', {cookie: account.cookie})).body.bundle, full);
  const race = await Promise.all([account.cookie, other.cookie].map((cookie, i) => call('save', {method: 'POST', cookie, body: {expectedRevision: 1, bundle: bundle(sample(50 + i))}})));
  assert.deepEqual(race.map(result => result.status).sort(), [200, 409]);
  const newest = await call('save', {cookie: account.cookie});
  assert.equal(newest.body.revision, 2);
  const winner = race.findIndex(result => result.status === 200);
  assert.equal(newest.body.bundle.slots['1'].level, 50 + winner);
  assert.equal(DB.sqlite.prepare('SELECT count(*) AS n FROM toon_save_snapshots').get().n, 2);
});

test('last five snapshots are bounded; restoring creates a new revision and stale restore is rejected', async t => {
  const {register, call, DB} = harness(t);
  const account = await register();
  for (let i = 0; i < 8; i++) {
    const saved = await call('save', {method: 'POST', cookie: account.cookie, body: {expectedRevision: i, bundle: bundle(sample(i + 1))}});
    assert.equal(saved.status, 200);
  }
  assert.equal(DB.sqlite.prepare('SELECT count(*) AS n FROM toon_save_snapshots').get().n, 5);
  const history = await call('save/history', {cookie: account.cookie});
  assert.deepEqual(history.body.snapshots.map(snapshot => snapshot.revision), [8, 7, 6, 5, 4]);
  assert.equal((await call('save/restore', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 8, revision: 1}})).status, 404);
  const restored = await call('save/restore', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 8, revision: 4}});
  assert.equal(restored.status, 200);
  assert.equal(restored.body.revision, 9);
  assert.equal(restored.body.bundle.slots['1'].level, 4);
  const stale = await call('save/restore', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 8, revision: 7}});
  assert.equal(stale.status, 409);
  assert.equal(stale.body.revision, 9);
  assert.equal((await call('save', {cookie: account.cookie})).body.bundle.slots['1'].level, 4);
  assert.equal(DB.sqlite.prepare('SELECT count(*) AS n FROM toon_save_snapshots').get().n, 5);
});

test('logout revokes current device only; expired sessions are rejected', async t => {
  const {register, call, DB} = harness(t);
  const account = await register();
  const other = await call('login', {method: 'POST', body: {username: 'toonhero', password: PASSWORD}});
  const loggedOut = await call('logout', {method: 'POST', cookie: account.cookie});
  assert.equal(loggedOut.status, 200);
  assert.match(loggedOut.headers.get('set-cookie'), /Max-Age=0/);
  assert.equal((await call('session', {cookie: account.cookie})).body.user, null);
  assert.equal((await call('save', {cookie: account.cookie})).status, 401);
  assert.ok((await call('session', {cookie: other.cookie})).body.user);
  DB.sqlite.prepare('UPDATE toon_sessions SET expires_at = 1').run();
  assert.equal((await call('session', {cookie: other.cookie})).body.user, null);
});

test('recovery resets password, rotates single-use recovery code and revokes all existing sessions', async t => {
  const {register, call} = harness(t);
  const account = await register();
  const other = await call('login', {method: 'POST', body: {username: 'toonhero', password: PASSWORD}});
  await call('save', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 0, bundle: bundle(sample(87))}});
  const incorrect = await call('reset-password', {method: 'POST', body: {username: 'toonhero', recoveryCode: 'WRONG', password: OTHER_PASSWORD}});
  assert.equal(incorrect.status, 401);
  const recovered = await call('reset-password', {method: 'POST', body: {username: 'toonhero', recoveryCode: account.body.recoveryCode.toLowerCase(), password: OTHER_PASSWORD}});
  assert.equal(recovered.status, 200);
  assert.notEqual(recovered.body.recoveryCode, account.body.recoveryCode);
  assert.equal((await call('session', {cookie: account.cookie})).body.user, null);
  assert.equal((await call('session', {cookie: other.cookie})).body.user, null);
  assert.equal((await call('save', {cookie: recovered.cookie})).body.bundle.slots['1'].level, 87);
  assert.equal((await call('reset-password', {method: 'POST', body: {username: 'toonhero', recoveryCode: account.body.recoveryCode, password: PASSWORD}})).status, 401);
  assert.equal((await call('login', {method: 'POST', body: {username: 'toonhero', password: PASSWORD}})).status, 401);
  assert.equal((await call('login', {method: 'POST', body: {username: 'toonhero', password: OTHER_PASSWORD}})).status, 200);
});

test('persistent atomic IP rate limits apply to signup/login/reset without targeted ID lockout', async t => {
  const {register, call, DB} = harness(t);
  await register();
  for (let i = 0; i < 30; i++) assert.equal((await call('login', {method: 'POST', body: {username: 'toonhero', password: OTHER_PASSWORD}})).status, 401);
  const limited = await call('login', {method: 'POST', body: {username: 'toonhero', password: OTHER_PASSWORD}});
  assert.equal(limited.status, 429);
  assert.ok(Number(limited.headers.get('retry-after')) > 0);
  assert.equal((await call('login', {method: 'POST', body: {username: 'toonhero', password: PASSWORD}, ip: '203.0.113.99'})).status, 200);
  for (let i = 0; i < 30; i++) assert.equal((await call('reset-password', {method: 'POST', body: {username: 'toonhero', recoveryCode: 'bad', password: PASSWORD}})).status, 401);
  assert.equal((await call('reset-password', {method: 'POST', body: {username: 'toonhero', recoveryCode: 'bad', password: PASSWORD}})).status, 429);
  for (let i = 0; i < 4; i++) assert.equal((await call('register', {method: 'POST', body: {username: `other_${i}`, password: PASSWORD}})).status, 201);
  assert.equal((await call('register', {method: 'POST', body: {username: 'too_many', password: PASSWORD}})).status, 429);
  DB.sqlite.prepare("INSERT INTO toon_rate_limits VALUES ('oldbucket',1,1)").run();
  await call('login', {method: 'POST', body: {username: 'differenthero', password: PASSWORD}, ip: '203.0.113.21'});
  assert.equal(DB.sqlite.prepare("SELECT count(*) AS n FROM toon_rate_limits WHERE bucket = 'oldbucket'").get().n, 0);
});

test('same-origin JSON-only writes block CSRF; request sizes, malformed JSON and unsupported methods bounded', async t => {
  const {register, call} = harness(t);
  const account = await register();
  assert.equal((await call('logout', {method: 'POST', cookie: account.cookie, origin: 'https://attacker.example'})).status, 403);
  assert.equal((await call('save', {method: 'POST', cookie: account.cookie, origin: 'null', body: {expectedRevision: 0, bundle: bundle()}})).status, 403);
  assert.equal((await call('login', {method: 'POST', type: 'text/plain', body: {username: 'toonhero', password: PASSWORD}})).status, 415);
  assert.equal((await call('login', {method: 'POST', raw: '{bad'})).status, 400);
  assert.equal((await call('login', {method: 'POST', raw: '[]'})).status, 400);
  assert.equal((await call('login', {method: 'POST', raw: '{}', headers: {'content-length': '10000000'}})).status, 413);
  assert.equal((await call('login', {method: 'POST', raw: 'x'.repeat(4097)})).status, 413);
  const request = new Request(`${ORIGIN}/api/account/save`, {method: 'DELETE', headers: {cookie: account.cookie, origin: ORIGIN}});
  assert.equal((await handleAccountRequest(request, {DB: new D1Sqlite()})).status, 405);
  assert.equal((await call('reserved-signin')).status, 404);
  assert.equal((await call('session', {cookie: account.cookie})).status, 200);
});

test('malformed, oversized and dangerous save structures are rejected without changing previous save', async t => {
  const {register, call} = harness(t);
  const account = await register();
  await call('save', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 0, bundle: bundle()}});
  const invalid = [
    {slots: [], selectedSlot: 1}, {slots: {'5': sample()}, selectedSlot: 1}, {slots: {}, selectedSlot: 5},
    bundle({...sample(), class: 'unknown'}), bundle({...sample(), level: 101}), bundle({...sample(), level: '12'}),
    bundle({...sample(), version: 2}), bundle({...sample(), gold: -5}), bundle({...sample(), hp: []}),
    bundle({...sample(), attrs: {int: []}}), bundle({...sample(), inv: ['item']}), bundle({...sample(), equip: {weapon: null}}),
    bundle({...sample(), quests: []}), bundle({...sample(), loadout: [{}]}), bundle({...sample(), play_time: -1}),
    bundle({...sample(), bag_slots: 101}), bundle({...sample(), party: 'wrong'}),
  ];
  for (const bad of invalid) {
    const result = await call('save', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 1, bundle: bad}});
    assert.equal(result.status, 400, JSON.stringify(result.body));
  }
  const giant = bundle({...sample(), extra: 'x'.repeat(1_048_576)});
  assert.equal((await call('save', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 1, bundle: giant}})).status, 413);
  const d1Overflow = {slots: {'1': {...sample(), extra: 'x'.repeat(900_000)}, '2': {...sample(), extra: 'x'.repeat(900_000)}}, selectedSlot: 1};
  const oversizedBundle = await call('save', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 1, bundle: d1Overflow}});
  assert.equal(oversizedBundle.status, 413);
  assert.equal(oversizedBundle.body.error.code, 'save_too_large');
  const deep = {}; let tip = deep; for (let i = 0; i < 45; i++) {tip.inner = {}; tip = tip.inner;}
  assert.equal((await call('save', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 1, bundle: bundle({...sample(), extra: deep})}})).status, 400);
  const dangerous = JSON.parse('{"slots":{"1":{"class":"mage","level":1,"__proto__":{"bad":true}}},"selectedSlot":1}');
  assert.equal((await call('save', {method: 'POST', cookie: account.cookie, body: {expectedRevision: 1, bundle: dangerous}})).status, 400);
  const infinity = '{"expectedRevision":1,"bundle":{"slots":{"1":{"class":"mage","level":1,"gold":1e999}},"selectedSlot":1}}';
  assert.equal((await call('save', {method: 'POST', cookie: account.cookie, raw: infinity})).status, 400);
  const current = await call('save', {cookie: account.cookie});
  assert.equal(current.body.revision, 1);
  assert.deepEqual(current.body.bundle, bundle());
});

test('database failures return safe service unavailable JSON without leaking database or credentials', async () => {
  const request = new Request(`${ORIGIN}/api/account/login`, {method: 'POST', headers: {'content-type': 'application/json', origin: ORIGIN}, body: JSON.stringify({username: 'toonhero', password: PASSWORD})});
  const result = await handleAccountRequest(request, {DB: {prepare() {throw new Error(`SELECT password_hash ${PASSWORD}`);}}});
  assert.equal(result.status, 503);
  const body = JSON.stringify(await result.json());
  assert.ok(!body.includes(PASSWORD));
  assert.ok(!body.includes('SELECT'));
  assert.equal((await handleAccountRequest(new Request(`${ORIGIN}/api/account/session`), {})).status, 503);
});

test('every class the game ships (data/class_data.gd) can be saved online', async t => {
  const {readFile} = await import('node:fs/promises');
  const source = await readFile(new URL('../../../data/class_data.gd', import.meta.url), 'utf8');
  const ids = [...source.match(/^const IDS: Array\[StringName\] = \[(.*)\]$/m)[1].matchAll(/&"([a-z_]+)"/g)].map(m => m[1]);
  const start = source.match(/^const START(?:: StringName)? :?= &"([a-z_]+)"$/m)[1];
  assert.ok(ids.includes('defender') && ids.length >= 7, ids.join(','));
  const {register, call} = harness(t);
  const account = await register();
  let revision = 0;
  for (const cls of [start, ...ids]) {
    const saved = await call('save', {method: 'POST', cookie: account.cookie, body: {expectedRevision: revision, bundle: bundle({...sample(), class: cls})}});
    assert.equal(saved.status, 200, `${cls}: ${JSON.stringify(saved.body)}`);
    revision = saved.body.revision;
  }
});
