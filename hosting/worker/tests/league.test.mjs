/** The guild league's official round results (/api/league/*, hosting/worker/league.mjs):
 * an ended round is stored once (first writer wins, later posts get the stored one back),
 * malformed posts are refused, rounds still running are refused, per-IP limits, and the
 * server's constants match the game's. Run: node hosting/worker/tests/league.test.mjs */
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import worker from '../worker.mjs';
import {handleLeagueRequest, firstRound, isSlot, cleanResult, DURATION, END_MARGIN, LIMITS, SLOTS, TZ, START_UNIX, MAX_RANGE} from '../league.mjs';
import {D1Sqlite} from '../../accounts/tests/d1-sqlite.mjs';

const ORIGIN = 'https://toon.example';
// A real round: the 18:00 Thai round of a day after the world opened.
const DAY = 86400;
const AT = (Math.floor((START_UNIX + TZ) / DAY) + 3) * DAY - TZ + SLOTS[1];
const AFTER = AT + DURATION + 5;

function result(at = AT, extra = {}) {
  return {at, g: [1, 2, 3, 4], k: [30, 12, 5, 8], c: [2, 0, 1, 0], held: 1, own: 3, ...extra};
}

function harness() {
  const DB = new D1Sqlite();
  const env = {DB};
  let ip = 0;
  return {
    DB, env,
    async post(body, {now = AFTER, from = '203.0.113.1', headers = {}} = {}) {
      const raw = typeof body === 'string' ? body : JSON.stringify(body);
      const request = new Request(`${ORIGIN}/api/league/round`, {method: 'POST', body: raw,
        headers: {'content-type': 'application/json', 'cf-connecting-ip': from, ...headers}});
      const answer = await handleLeagueRequest(request, env, {now});
      return {status: answer.status, body: await answer.json(), headers: answer.headers};
    },
    async get(query, {now = AFTER, from = '203.0.113.1'} = {}) {
      const request = new Request(`${ORIGIN}/api/league/rounds?${query}`, {headers: {'cf-connecting-ip': from}});
      const answer = await handleLeagueRequest(request, env, {now});
      return {status: answer.status, body: await answer.json()};
    },
    nextIp() {return `198.51.100.${++ip}`;},
  };
}

test('the server\'s league constants are the game\'s', () => {
  const league = readFileSync(new URL('../../../data/guild_league.gd', import.meta.url), 'utf8');
  const war = readFileSync(new URL('../../../data/guild_war_data.gd', import.meta.url), 'utf8');
  const players = readFileSync(new URL('../../../data/world_players.gd', import.meta.url), 'utf8');
  assert.match(league, /const SLOTS: Array\[int\] = \[12 \* 3600, 18 \* 3600, 21 \* 3600 \+ 30 \* 60\]/);
  assert.deepEqual(SLOTS, [12 * 3600, 18 * 3600, 21 * 3600 + 30 * 60]);
  assert.equal(Number(war.match(/const DURATION := ([\d.]+)/)[1]), DURATION);
  assert.equal(Number(players.match(/const START_UNIX := (\d+)/)[1]), START_UNIX);
  assert.equal(Number(players.match(/const TZ := 7 \* 3600/) ? 7 * 3600 : -1), TZ);
});

test('round starts: 12:00, 18:00 and 21:30 Thai from the world\'s first round only', () => {
  assert.ok(isSlot(AT));
  assert.ok(isSlot(AT - SLOTS[1] + SLOTS[0]) && isSlot(AT - SLOTS[1] + SLOTS[2]));
  assert.ok(!isSlot(AT + 60) && !isSlot(AT - 3600) && !isSlot(AT + 0.5) && !isSlot(String(AT)));
  assert.ok(firstRound() >= START_UNIX && isSlot(firstRound()) && !isSlot(firstRound() - DAY));
});

test('an ended round is stored once: first writer wins, later posts get the stored one', async () => {
  const h = harness();
  const first = await h.post({at: AT, result: result()});
  assert.equal(first.status, 201);
  assert.equal(first.body.stored, true);
  assert.deepEqual(first.body.round, {at: AT, result: result()});
  const other = result(AT, {held: 2, c: [0, 2, 0, 0]});
  const second = await h.post({at: AT, result: other}, {from: h.nextIp()});
  assert.equal(second.status, 200);
  assert.equal(second.body.stored, false);
  assert.deepEqual(second.body.round.result, result(), 'the stored result comes back, unchanged');
  const list = await h.get(`from=${AT - DAY}&to=${AT + DAY}`);
  assert.equal(list.status, 200);
  assert.deepEqual(list.body.rounds, [{at: AT, result: result()}]);
  assert.equal(list.body.now, AFTER);
  assert.equal(h.DB.sqlite.prepare('SELECT count(*) AS n FROM toon_league_rounds').get().n, 1);
});

test('the deciding round (Sunday 21:30, ×2 in the game) is stored raw like any other round', async () => {
  // The game doubles its placement and capture points when it scores the round
  // (GuildLeague.side_points / mult_of); the server keeps the falls and captures as fought.
  const league = readFileSync(new URL('../../../data/guild_league.gd', import.meta.url), 'utf8');
  assert.match(league, /const FINAL_MULT := 2/);
  assert.match(league, /\* m\b/, 'the multiplier is applied when scoring');
  const h = harness();
  // Sunday of the week AT falls in: Thai day of the epoch's day 0 was a Thursday, so
  // (day + 3) % 7 === 6 is a Sunday.
  let day = Math.floor((AT + TZ) / DAY);
  while ((day + 3) % 7 !== 6) day += 1;
  const at = day * DAY - TZ + SLOTS[2];
  assert.ok(isSlot(at));
  const raw = result(at, {c: [1, 0, 2, 0]});
  const answer = await h.post({at, result: raw}, {now: at + DURATION + 5});
  assert.equal(answer.status, 201);
  assert.deepEqual(answer.body.round.result, raw, 'nothing doubled in the stored result');
  assert.equal(cleanResult(at, {...raw, mult: 2}), 'unknown key mult', 'no multiplier is accepted from a device');
});

test('a round nobody could fight (no guild at Lv.100) is stored too', async () => {
  const h = harness();
  const at = firstRound();
  const empty = {at, g: [], k: [], c: [], held: 0, own: 0};
  const answer = await h.post({at, result: empty}, {now: at + DURATION});
  assert.equal(answer.status, 201);
  assert.deepEqual(answer.body.round.result, empty);
});

test('a round still being fought (or in the future) is refused; a small clock margin is allowed', async () => {
  const h = harness();
  assert.equal((await h.post({at: AT, result: result()}, {now: AT + 60})).status, 409);
  assert.equal((await h.post({at: AT, result: result()}, {now: AT - DAY})).body.error.code, 'round_not_over');
  assert.equal((await h.post({at: AT, result: result()}, {now: AT + DURATION - END_MARGIN})).status, 201);
});

test('malformed posts are refused and store nothing', async () => {
  const h = harness();
  const bad = [
    ['not json', '{at:'],
    ['array', []],
    ['extra key', {at: AT, result: result(), x: 1}],
    ['not a slot', {at: AT + 60, result: result(AT + 60)}],
    ['before the world', {at: firstRound() - DAY, result: result(firstRound() - DAY)}],
    ['at as text', {at: String(AT), result: result()}],
    ['result.at differs', {at: AT, result: result(AT - DAY)}],
    ['no result', {at: AT}],
    ['guild 5', {at: AT, result: result(AT, {g: [1, 2, 3, 5]})}],
    ['guild 0', {at: AT, result: result(AT, {g: [0, 2, 3, 4]})}],
    ['twice the same guild', {at: AT, result: result(AT, {g: [1, 1, 3, 4]})}],
    ['one guild', {at: AT, result: result(AT, {g: [1], k: [1], c: [0], held: 1})}],
    ['five guilds', {at: AT, result: result(AT, {g: [1, 2, 3, 4, 1], k: [1, 1, 1, 1, 1], c: [0, 0, 0, 0, 0]})}],
    ['short k', {at: AT, result: result(AT, {k: [1, 2, 3]})}],
    ['negative falls', {at: AT, result: result(AT, {k: [-1, 2, 3, 4]})}],
    ['huge falls', {at: AT, result: result(AT, {k: [1e9, 2, 3, 4]})}],
    ['fractional captures', {at: AT, result: result(AT, {c: [0.5, 0, 0, 0]})}],
    ['huge captures', {at: AT, result: result(AT, {c: [5000, 0, 0, 0]})}],
    ['holder not in the round', {at: AT, result: result(AT, {g: [2, 3, 4], k: [1, 1, 1], c: [0, 0, 0], held: 1})}],
    ['holder 9', {at: AT, result: result(AT, {held: 9})}],
    ['own 7', {at: AT, result: result(AT, {own: 7})}],
    ['unknown result key', {at: AT, result: {...result(), real: true}}],
    ['numbers as text', {at: AT, result: result(AT, {k: ['1', '2', '3', '4']})}],
  ];
  for (const [name, body] of bad) {
    const answer = await h.post(body, {from: h.nextIp()});
    assert.equal(answer.status, 400, name);
    assert.ok(answer.body.error?.code, name);
  }
  assert.equal((await h.post(JSON.stringify({at: AT, result: result()}), {headers: {'content-type': 'text/plain'}})).status, 415);
  assert.equal((await h.post({at: AT, result: {...result(), pad: 'x'.repeat(4000)}})).status, 413);
  assert.equal(h.DB.sqlite.prepare('SELECT count(*) AS n FROM toon_league_rounds').get().n, 0);
  assert.equal(typeof cleanResult(AT, result()), 'object');
});

test('GET checks its range', async () => {
  const h = harness();
  assert.equal((await h.get('from=abc&to=1')).status, 400);
  assert.equal((await h.get(`from=${AT}&to=${AT - 1}`)).status, 400);
  assert.equal((await h.get(`from=${AT}&to=${AT + MAX_RANGE + 1}`)).status, 400);
  assert.deepEqual((await h.get(`from=${AT}&to=${AT + MAX_RANGE}`)).body.rounds, []);
});

test('per-IP rate limits on posts and reads', async () => {
  const h = harness();
  const [postLimit] = LIMITS.league_post;
  for (let i = 0; i < postLimit; i++) {
    const answer = await h.post({at: AT, result: result()}, {from: '192.0.2.7'});
    assert.ok(answer.status === 201 || answer.status === 200, `post ${i}`);
  }
  const over = await h.post({at: AT, result: result()}, {from: '192.0.2.7'});
  assert.equal(over.status, 429);
  assert.ok(Number(over.headers.get('retry-after')) > 0);
  assert.equal((await h.post({at: AT, result: result()}, {from: '192.0.2.8'})).status, 200, 'another IP is not limited');
  const [getLimit] = LIMITS.league_get;
  for (let i = 0; i < getLimit; i++) assert.equal((await h.get(`from=${AT}&to=${AT}`, {from: '192.0.2.9'})).status, 200);
  assert.equal((await h.get(`from=${AT}&to=${AT}`, {from: '192.0.2.9'})).status, 429);
});

test('worker: /api/league/* is routed, methods and origin are checked, no DB is 503', async () => {
  const DB = new D1Sqlite();
  const call = (path, init = {}) => worker.fetch(new Request(`${ORIGIN}${path}`, init), {DB});
  assert.equal((await call('/api/league/rounds?from=1&to=2')).status, 200);
  assert.equal((await call('/api/league/rounds?from=1&to=2', {method: 'POST'})).status, 405);
  assert.equal((await call('/api/league/round')).status, 405);
  assert.equal((await call('/api/league/nope')).status, 404);
  const foreign = await call('/api/league/round', {method: 'POST', body: '{}', headers: {'content-type': 'application/json', origin: 'https://evil.example'}});
  assert.equal(foreign.status, 403);
  const none = await worker.fetch(new Request(`${ORIGIN}/api/league/rounds?from=1&to=2`), {});
  assert.equal(none.status, 503);
});

test('wrangler config sends /api/league/* to the Worker', () => {
  const config = JSON.parse(readFileSync(new URL('../wrangler.example.jsonc', import.meta.url), 'utf8'));
  assert.ok(config.assets.run_worker_first.includes('/api/league/*'));
  const migration = readFileSync(new URL('../../accounts/drizzle/0001_league_rounds.sql', import.meta.url), 'utf8');
  assert.match(migration, /CREATE TABLE `toon_league_rounds`/);
});
