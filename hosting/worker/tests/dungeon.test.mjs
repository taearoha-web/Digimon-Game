/** The dragon tomb's weekly clear times (/api/dungeon/*, hosting/worker/dungeon.mjs): a
 * leader's best time a week is kept (a slower post changes nothing and gets the stored one
 * back, a faster one replaces it), the week's list comes back fastest first, malformed
 * posts are refused, per-IP limits, routing, and the server's constants match the game's.
 * Run: node hosting/worker/tests/dungeon.test.mjs */
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import worker from '../worker.mjs';
import {handleDungeonRequest, cleanTime, weekOf, firstWeek, CLASSES, LIMITS, PARTY_SIZE, MIN_SECS, MAX_SECS, LEADER_MAX, NAME_MAX, TZ, START_UNIX, TOP} from '../dungeon.mjs';
import {D1Sqlite} from '../../accounts/tests/d1-sqlite.mjs';

const ORIGIN = 'https://toon.example';
// A week after the world opened, and a moment inside it.
const NOW = START_UNIX + 10 * 86400;
const WEEK = weekOf(NOW);

function time(extra = {}) {
  return {week: WEEK, leader: 'u:somebody', name: 'น้องแมว', secs: 271, classes: ['warrior', 'defender', 'priest', 'mage'], ...extra};
}

function harness() {
  const DB = new D1Sqlite();
  const env = {DB};
  let ip = 0;
  return {
    DB, env,
    async post(body, {now = NOW, from = '203.0.113.1', headers = {}} = {}) {
      const raw = typeof body === 'string' ? body : JSON.stringify(body);
      const request = new Request(`${ORIGIN}/api/dungeon/time`, {method: 'POST', body: raw,
        headers: {'content-type': 'application/json', 'cf-connecting-ip': from, ...headers}});
      const answer = await handleDungeonRequest(request, env, {now});
      return {status: answer.status, body: await answer.json(), headers: answer.headers};
    },
    async get(query, {now = NOW, from = '203.0.113.1'} = {}) {
      const request = new Request(`${ORIGIN}/api/dungeon/times?${query}`, {headers: {'cf-connecting-ip': from}});
      const answer = await handleDungeonRequest(request, env, {now});
      return {status: answer.status, body: await answer.json()};
    },
    nextIp() {return `198.51.100.${++ip}`;},
  };
}

test('the server\'s dungeon constants are the game\'s', () => {
  const ranking = readFileSync(new URL('../../../data/dungeon_ranking.gd', import.meta.url), 'utf8');
  const dungeon = readFileSync(new URL('../../../data/dungeon_data.gd', import.meta.url), 'utf8');
  const classes = readFileSync(new URL('../../../data/class_data.gd', import.meta.url), 'utf8');
  const players = readFileSync(new URL('../../../data/world_players.gd', import.meta.url), 'utf8');
  const league = readFileSync(new URL('../../../data/guild_league.gd', import.meta.url), 'utf8');
  assert.equal(Number(dungeon.match(/const PARTY_SIZE := (\d+)/)[1]), PARTY_SIZE);
  assert.equal(Number(ranking.match(/const MIN_SECS := (\d+)/)[1]), MIN_SECS);
  assert.equal(Number(ranking.match(/const MAX_SECS := (\d+)/)[1]), MAX_SECS);
  assert.equal(Number(ranking.match(/const LEADER_MAX := (\d+)/)[1]), LEADER_MAX);
  assert.equal(Number(ranking.match(/const NAME_MAX := (\d+)/)[1]), NAME_MAX);
  assert.match(ranking, /const API_TIMES := "\/api\/dungeon\/times"/);
  assert.match(ranking, /const API_TIME := "\/api\/dungeon\/time"/);
  assert.equal(Number(players.match(/const START_UNIX := (\d+)/)[1]), START_UNIX);
  assert.ok(/const TZ := 7 \* 3600/.test(players) && TZ === 7 * 3600);
  // The week numbering is the guild league's: weeks from Monday 00:00 Thai (day 0 a Thursday).
  assert.match(league, /return floori\(float\(WorldEvents\.day_of\(t\) \+ 3\) \/ 7\.0\)/);
  const ids = classes.match(/const IDS: Array\[StringName\] = \[([^\]]+)\]/)[1].match(/&"(\w+)"/g).map(s => s.slice(2, -1));
  assert.deepEqual(CLASSES, ['vagabond', ...ids]);
});

test('weeks: Monday 00:00 Thai starts a new one', () => {
  const monday = Math.floor((NOW + TZ) / 86400);
  // Find the Monday on or after NOW's day: (day + 3) % 7 === 0 is a Monday.
  let day = monday;
  while ((day + 3) % 7 !== 0) day += 1;
  const start = day * 86400 - TZ;
  assert.equal(weekOf(start), weekOf(start - 1) + 1);
  assert.equal(weekOf(start + 6 * 86400 + 86399), weekOf(start));
  assert.ok(firstWeek() <= WEEK);
});

test('a leader\'s best time a week is kept: a slower post changes nothing, a faster one replaces it', async () => {
  const h = harness();
  const first = await h.post(time());
  assert.equal(first.status, 201);
  assert.equal(first.body.stored, true);
  const {week: _w, ...stored} = time();
  assert.deepEqual(first.body.time, {...stored, at: NOW});
  const slower = await h.post(time({secs: 300, name: 'ช้ากว่า'}), {now: NOW + 60});
  assert.equal(slower.status, 200);
  assert.equal(slower.body.stored, false);
  assert.deepEqual(slower.body.time, {...stored, at: NOW}, 'the stored (faster) time comes back unchanged');
  const faster = await h.post(time({secs: 240, classes: ['bard', 'defender', 'priest', 'mage']}), {now: NOW + 120});
  assert.equal(faster.status, 201);
  assert.equal(faster.body.stored, true);
  assert.equal(faster.body.time.secs, 240);
  assert.deepEqual(faster.body.time.classes, ['bard', 'defender', 'priest', 'mage']);
  assert.equal(faster.body.time.at, NOW + 120);
  assert.equal(h.DB.sqlite.prepare('SELECT count(*) AS n FROM toon_dungeon_times').get().n, 1, 'one row a leader a week');
  // Another leader and another week stand apart.
  assert.equal((await h.post(time({leader: 'u:other', secs: 200}), {from: h.nextIp()})).status, 201);
  assert.equal((await h.post(time({week: WEEK - 1, secs: 500}), {from: h.nextIp()})).status, 201);
  const list = await h.get(`week=${WEEK}`);
  assert.equal(list.status, 200);
  assert.equal(list.body.week, WEEK);
  assert.equal(list.body.now, NOW);
  assert.deepEqual(list.body.times.map(t => [t.leader, t.secs]), [['u:other', 200], ['u:somebody', 240]], 'fastest first');
  assert.deepEqual((await h.get(`week=${WEEK - 1}`)).body.times.map(t => t.secs), [500]);
  assert.deepEqual((await h.get(`week=${WEEK + 1}`)).body.times, []);
});

test('the week\'s list is capped and ordered by time, then by who posted first', async () => {
  const h = harness();
  for (let i = 0; i < TOP + 5; i++) {
    const answer = await h.post(time({leader: `u:p${i}`, secs: 600 - (i % 20)}), {now: NOW + i, from: h.nextIp()});
    assert.equal(answer.status, 201, `post ${i}`);
  }
  const list = await h.get(`week=${WEEK}`);
  assert.equal(list.body.times.length, TOP);
  for (let i = 1; i < list.body.times.length; i++) {
    const a = list.body.times[i - 1];
    const b = list.body.times[i];
    assert.ok(a.secs < b.secs || (a.secs === b.secs && a.at <= b.at), `ordered at ${i}`);
  }
});

test('malformed posts are refused and store nothing', async () => {
  const h = harness();
  const bad = [
    ['not json', '{week:'],
    ['array', []],
    ['extra key', time({x: 1})],
    ['no leader', {...time(), leader: undefined}],
    ['leader not text', time({leader: 7})],
    ['empty leader', time({leader: '   '})],
    ['long leader', time({leader: 'x'.repeat(LEADER_MAX + 1)})],
    ['week before the world', time({week: firstWeek() - 1})],
    ['week far ahead', time({week: WEEK + 2})],
    ['week as text', time({week: String(WEEK)})],
    ['too fast', time({secs: MIN_SECS - 1})],
    ['too slow', time({secs: MAX_SECS + 1})],
    ['fractional secs', time({secs: 200.5})],
    ['secs as text', time({secs: '200'})],
    ['three classes', time({classes: ['warrior', 'defender', 'priest']})],
    ['five classes', time({classes: ['warrior', 'defender', 'priest', 'mage', 'bard']})],
    ['unknown class', time({classes: ['warrior', 'defender', 'priest', 'ninja']})],
    ['classes not a list', time({classes: 'warrior'})],
  ];
  for (const [name, body] of bad) {
    const answer = await h.post(body, {from: h.nextIp()});
    assert.equal(answer.status, 400, name);
    assert.ok(answer.body.error?.code, name);
  }
  assert.equal((await h.post(JSON.stringify(time()), {headers: {'content-type': 'text/plain'}})).status, 415);
  assert.equal((await h.post(time({name: 'x'.repeat(4000)}))).status, 413);
  assert.equal(h.DB.sqlite.prepare('SELECT count(*) AS n FROM toon_dungeon_times').get().n, 0);
  assert.equal(typeof cleanTime(time(), NOW), 'object');
  assert.equal(cleanTime(time({name: 'ย'.repeat(NAME_MAX + 10)}), NOW).name.length, NAME_MAX, 'a long name is cut, not refused');
  assert.equal(cleanTime(time({leader: '  u:x  '}), NOW).leader, 'u:x', 'the leader key is trimmed');
  assert.equal(cleanTime({...time(), name: undefined}, NOW).name, '', 'no name is fine');
});

test('GET checks its week', async () => {
  const h = harness();
  assert.equal((await h.get('week=abc')).status, 400);
  assert.equal((await h.get('')).status, 400);
  assert.equal((await h.get(`week=${firstWeek() - 1}`)).status, 400);
  assert.equal((await h.get(`week=${WEEK + 2}`)).status, 400);
  assert.deepEqual((await h.get(`week=${WEEK + 1}`)).body.times, []);
});

test('per-IP rate limits on posts and reads', async () => {
  const h = harness();
  const [postLimit] = LIMITS.dungeon_post;
  for (let i = 0; i < postLimit; i++) {
    const answer = await h.post(time(), {from: '192.0.2.7'});
    assert.ok(answer.status === 201 || answer.status === 200, `post ${i}`);
  }
  const over = await h.post(time(), {from: '192.0.2.7'});
  assert.equal(over.status, 429);
  assert.ok(Number(over.headers.get('retry-after')) > 0);
  assert.equal((await h.post(time(), {from: '192.0.2.8'})).status, 200, 'another IP is not limited');
  const [getLimit] = LIMITS.dungeon_get;
  for (let i = 0; i < getLimit; i++) assert.equal((await h.get(`week=${WEEK}`, {from: '192.0.2.9'})).status, 200);
  assert.equal((await h.get(`week=${WEEK}`, {from: '192.0.2.9'})).status, 429);
});

test('worker: /api/dungeon/* is routed, methods and origin are checked, no DB is 503', async () => {
  const DB = new D1Sqlite();
  const call = (path, init = {}) => worker.fetch(new Request(`${ORIGIN}${path}`, init), {DB});
  const week = weekOf(Math.floor(Date.now() / 1000));
  assert.equal((await call(`/api/dungeon/times?week=${week}`)).status, 200);
  assert.equal((await call(`/api/dungeon/times?week=${week}`, {method: 'POST'})).status, 405);
  assert.equal((await call('/api/dungeon/time')).status, 405);
  assert.equal((await call('/api/dungeon/nope')).status, 404);
  const foreign = await call('/api/dungeon/time', {method: 'POST', body: '{}', headers: {'content-type': 'application/json', origin: 'https://evil.example'}});
  assert.equal(foreign.status, 403);
  const none = await worker.fetch(new Request(`${ORIGIN}/api/dungeon/times?week=${week}`), {});
  assert.equal(none.status, 503);
});

test('wrangler config sends /api/dungeon/* to the Worker and the migration creates the table', () => {
  const config = JSON.parse(readFileSync(new URL('../wrangler.example.jsonc', import.meta.url), 'utf8'));
  assert.ok(config.assets.run_worker_first.includes('/api/dungeon/*'));
  const migration = readFileSync(new URL('../../accounts/drizzle/0002_dungeon_times.sql', import.meta.url), 'utf8');
  assert.match(migration, /CREATE TABLE `toon_dungeon_times`/);
  assert.match(migration, /PRIMARY KEY\(`week`, `leader`\)/);
  const journal = JSON.parse(readFileSync(new URL('../../accounts/drizzle/meta/_journal.json', import.meta.url), 'utf8'));
  assert.ok(journal.entries.some(e => e.tag === '0002_dungeon_times'));
});
