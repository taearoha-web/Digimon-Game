import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, writeFileSync, readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {handleAccountRequest} from '../server/accounts.js';
import {D1Sqlite} from './d1-sqlite.mjs';

// hosting/worker/boost-character.mjs against the production schema, with the Cloudflare
// REST API answered by the same SQLite D1 stand-in the account tests use.
const ORIGIN = 'https://toon-tale.example';
const hero = (name, cls, level) => ({version: 1, class: cls, level, name, hp: 500, mp: 320, gold: 2000, attrs: {},
  skills: {}, equip: {}, inv: [], storage: [], loadout: ['', '', '', '', '', '', '', ''], zone: 'town', quests: {},
  flags: {}, look: {}, party: [], paragon: {}, play_time: 10});
let runs = 0;

async function script(DB, ...args) {
  process.env.CLOUDFLARE_API_TOKEN = 'test-token';
  process.env.CLOUDFLARE_ACCOUNT_ID = 'acc';
  process.env.DB_NAME = 'toon-tale-accounts';
  globalThis.fetch = async (url, init) => {
    assert.equal(init?.headers?.authorization, 'Bearer test-token');
    if (String(url).includes('/d1/database?name=')) return Response.json({success: true, result: [{name: 'toon-tale-accounts', uuid: 'db1'}]});
    assert.match(String(url), /\/accounts\/acc\/d1\/database\/db1\/query$/);
    const {sql, params} = JSON.parse(init.body);
    return Response.json({success: true, result: [await DB.prepare(sql).bind(...params).all()]});
  };
  process.argv = [process.argv[0], 'boost-character.mjs', ...args];
  await import(`../../worker/boost-character.mjs?run=${++runs}`);
}

test('the owner boost replaces one slot with compare-and-swap and keeps a snapshot', async t => {
  const fetchBefore = globalThis.fetch, argvBefore = process.argv;
  const DB = new D1Sqlite();
  t.after(() => { DB.close(); globalThis.fetch = fetchBefore; process.argv = argvBefore; });
  let accountId;
  const call = async (path, body, cookie) => {
    const response = await handleAccountRequest(new Request(`${ORIGIN}/api/account/${path}`, {method: body ? 'POST' : 'GET',
      headers: {'cf-connecting-ip': '203.0.113.9', ...(body ? {'content-type': 'application/json', origin: ORIGIN} : {}), ...(cookie ? {cookie, 'x-toon-account-id': accountId} : {})},
      body: body ? JSON.stringify(body) : undefined}), {DB});
    return {status: response.status, body: await response.json(), cookie: response.headers.get('set-cookie')?.split(';')[0]};
  };
  const created = await call('register', {username: 'tataemong', password: 'CuteDragonPass2026!'});
  const cookie = created.cookie;
  accountId = created.body.user.id;
  const other = hero('Other', 'warrior', 40);
  const saved = await call('save', {expectedRevision: 0, bundle: {slots: {'1': other, '2': hero('Assotix', 'defender', 23)}, selectedSlot: 2}}, cookie);
  assert.equal(saved.status, 200, JSON.stringify(saved.body));
  const dir = mkdtempSync(join(tmpdir(), 'boost-'));
  await script(DB, 'fetch', 'tataemong', dir);
  const meta = JSON.parse(readFileSync(join(dir, 'meta.json'), 'utf8'));
  assert.equal(meta.revision, 1);
  const boosted = {...hero('Assotix', 'defender', 100), paragon: {level: 200, points: 200}};
  writeFileSync(join(dir, 'boosted.json'), JSON.stringify({slot: '2', profile: boosted}));

  // A save from the game in between wins: nothing is written.
  const raced = await call('save', {expectedRevision: 1, bundle: {slots: {'1': other, '2': hero('Assotix', 'defender', 24)}, selectedSlot: 2}}, cookie);
  assert.equal(raced.body.revision, 2);
  await assert.rejects(script(DB, 'apply', dir, join(dir, 'boosted.json')), /changed while boosting/);
  assert.equal((await call('save', undefined, cookie)).body.bundle.slots['2'].level, 24);

  await script(DB, 'fetch', 'tataemong', dir);
  await script(DB, 'apply', dir, join(dir, 'boosted.json'));
  const after = (await call('save', undefined, cookie)).body;
  assert.equal(after.revision, 3);
  assert.equal(after.bundle.slots['2'].level, 100);
  assert.equal(after.bundle.slots['2'].paragon.level, 200);
  assert.deepEqual(after.bundle.slots['1'], other);
  const snapshots = (await call('save/history', undefined, cookie)).body.snapshots.map(s => s.revision);
  assert.ok(snapshots.includes(2) && snapshots.includes(3), JSON.stringify(snapshots));
  // A game tab still on revision 2 gets the conflict screen instead of overwriting the boost.
  assert.equal((await call('save', {expectedRevision: 2, bundle: {slots: {'1': other}, selectedSlot: 1}}, cookie)).status, 409);

  // An invalid result is refused by the server's own rules.
  writeFileSync(join(dir, 'bad.json'), JSON.stringify({slot: '2', profile: {...boosted, level: 101}}));
  await script(DB, 'fetch', 'tataemong', dir);
  await assert.rejects(script(DB, 'apply', dir, join(dir, 'bad.json')), /level|invalid/i);
});

test('the owner wipe empties every slot with compare-and-swap and keeps the old save as a snapshot', async t => {
  const fetchBefore = globalThis.fetch, argvBefore = process.argv;
  const DB = new D1Sqlite();
  t.after(() => { DB.close(); globalThis.fetch = fetchBefore; process.argv = argvBefore; });
  let accountId;
  const call = async (path, body, cookie) => {
    const response = await handleAccountRequest(new Request(`${ORIGIN}/api/account/${path}`, {method: body ? 'POST' : 'GET',
      headers: {'cf-connecting-ip': '203.0.113.10', ...(body ? {'content-type': 'application/json', origin: ORIGIN} : {}), ...(cookie ? {cookie, 'x-toon-account-id': accountId} : {})},
      body: body ? JSON.stringify(body) : undefined}), {DB});
    return {status: response.status, body: await response.json(), cookie: response.headers.get('set-cookie')?.split(';')[0]};
  };
  const created = await call('register', {username: 'freshstart', password: 'CuteDragonPass2026!'});
  const cookie = created.cookie;
  accountId = created.body.user.id;
  const slots = {'1': hero('Wardermor', 'darklord', 100), '3': hero('Melody', 'bard', 64)};
  assert.equal((await call('save', {expectedRevision: 0, bundle: {slots, selectedSlot: 3}}, cookie)).status, 200);
  const dir = mkdtempSync(join(tmpdir(), 'wipe-'));
  await script(DB, 'fetch', 'freshstart', dir);
  // A save from the game in between wins: nothing is removed.
  await call('save', {expectedRevision: 1, bundle: {slots, selectedSlot: 1}}, cookie);
  await assert.rejects(script(DB, 'wipe', dir), /changed while/);
  assert.equal(Object.keys((await call('save', undefined, cookie)).body.bundle.slots).length, 2);

  await script(DB, 'fetch', 'freshstart', dir);
  await script(DB, 'wipe', dir);
  const after = (await call('save', undefined, cookie)).body;
  assert.equal(after.revision, 3);
  assert.deepEqual(after.bundle.slots, {});
  assert.equal(after.bundle.selectedSlot, 1);
  const snapshots = (await call('save/history', undefined, cookie)).body.snapshots.map(s => s.revision);
  assert.ok(snapshots.includes(2), JSON.stringify(snapshots));
  // The account itself still signs in.
  assert.equal((await call('login', {username: 'freshstart', password: 'CuteDragonPass2026!'})).status, 200);
});
