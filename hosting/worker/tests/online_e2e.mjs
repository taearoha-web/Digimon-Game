/** End to end: the real Worker + WorldRoom Durable Object + D1 under `wrangler dev`
 * (fully local: workerd, a local D1 in a temp folder, no Cloudflare account).
 * Two accounts are registered through /api/account/register, then two WebSockets with
 * their cookies check join, chat and party over the wire.
 *
 *   cd hosting/worker && npm install && node tests/online_e2e.mjs
 *
 * Needs node >= 22 (global WebSocket with headers). */
import assert from 'node:assert/strict';
import http from 'node:http';
import {spawn, spawnSync} from 'node:child_process';
import {mkdtempSync, writeFileSync, readFileSync, mkdirSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const workerDir = resolve(here, '..');
const wrangler = join(workerDir, 'node_modules', '.bin', 'wrangler');
const PORT = 8700 + Math.floor(Math.random() * 200);
const BASE = `http://127.0.0.1:${PORT}`;
const PASSWORD = 'CuteDragonPass2026!';

const temp = mkdtempSync(join(tmpdir(), 'toon-online-e2e-'));
const assets = join(temp, 'assets');
mkdirSync(assets);
writeFileSync(join(assets, 'index.html'), '<!doctype html><title>Toon Tale</title>');
const config = JSON.parse(readFileSync(join(workerDir, 'wrangler.example.jsonc'), 'utf8'));
config.main = join(workerDir, 'worker.mjs');
config.assets.directory = assets;
config.d1_databases[0].database_id = '00000000-0000-0000-0000-000000000000';
config.d1_databases[0].migrations_dir = resolve(workerDir, '..', 'accounts', 'drizzle');
delete config.$schema;
const configPath = join(temp, 'wrangler.json');
writeFileSync(configPath, JSON.stringify(config, null, 2));
const persist = join(temp, 'state');
const env = {...process.env, WRANGLER_SEND_METRICS: 'false', CI: '1'};

let dev;
function cleanup() {
  if (dev && dev.exitCode === null) dev.kill('SIGINT');
  rmSync(temp, {recursive: true, force: true});
}

async function waitFor(check, ms, what) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (await check()) return;
    await new Promise(r => setTimeout(r, 200));
  }
  throw new Error(`timed out waiting for ${what}`);
}

async function register(username) {
  const response = await fetch(`${BASE}/api/account/register`, {
    method: 'POST', headers: {'content-type': 'application/json', origin: BASE}, body: JSON.stringify({username, password: PASSWORD}),
  });
  const body = await response.json();
  assert.equal(response.status, 201, JSON.stringify(body));
  return {id: body.user.id, cookie: response.headers.get('set-cookie').split(';')[0]};
}

/** A WebSocket with a frame inbox; next(type) waits for the next frame of that type. */
function open(cookie) {
  const ws = new WebSocket(`${BASE.replace('http', 'ws')}/api/online/ws`, {headers: {cookie, origin: BASE}});
  const inbox = [];
  const waiters = [];
  ws.addEventListener('message', event => {
    const frame = JSON.parse(event.data);
    inbox.push(frame);
    for (const w of [...waiters]) if (w.type === frame.t) {waiters.splice(waiters.indexOf(w), 1); w.resolve(frame);}
  });
  const opened = new Promise((resolveOpen, reject) => {
    ws.addEventListener('open', () => resolveOpen());
    ws.addEventListener('error', () => reject(new Error('websocket error')));
  });
  return {
    ws, inbox, opened,
    send(obj) {ws.send(JSON.stringify(obj));},
    next(type, ms = 5000) {
      const index = inbox.findIndex(f => f.t === type);
      if (index >= 0) return Promise.resolve(inbox.splice(index, 1)[0]);
      return new Promise((resolveFrame, reject) => {
        const w = {type, resolve: frame => {clearTimeout(timer); inbox.splice(inbox.indexOf(frame), 1); resolveFrame(frame);}};
        const timer = setTimeout(() => {waiters.splice(waiters.indexOf(w), 1); reject(new Error(`no ${type} frame`));}, ms);
        waiters.push(w);
      });
    },
  };
}

/** The HTTP status of a WebSocket upgrade request (fetch refuses to send one by hand). */
function upgradeStatus(cookie) {
  return new Promise((resolveStatus, reject) => {
    const headers = {upgrade: 'websocket', connection: 'Upgrade', 'sec-websocket-version': '13', 'sec-websocket-key': 'dGhlIHNhbXBsZSBub25jZQ==', origin: BASE};
    if (cookie) headers.cookie = cookie;
    const request = http.request(`${BASE}/api/online/ws`, {headers});
    request.on('response', response => {response.resume(); resolveStatus(response.statusCode);});
    request.on('upgrade', (response, socket) => {socket.destroy(); resolveStatus(101);});
    request.on('error', reject);
    request.end();
  });
}

const hello = name => ({t: 'hello', name, cls: 'mage', level: 12, stars: 0, look: {class: 'mage'}, zone: 'meadow', pos: [0, 0, 0], yaw: 0, hp: 100, max_hp: 100, mount: ''});

try {
  const migrate = spawnSync(wrangler, ['d1', 'migrations', 'apply', 'DB', '--local', '--config', configPath, '--persist-to', persist], {env, encoding: 'utf8', input: 'y\n'});
  assert.equal(migrate.status, 0, migrate.stdout + migrate.stderr);

  let log = '';
  dev = spawn(wrangler, ['dev', '--config', configPath, '--persist-to', persist, '--port', String(PORT), '--ip', '127.0.0.1', '--local', '--show-interactive-dev-session=false'], {env});
  dev.stdout.on('data', d => {log += d;});
  dev.stderr.on('data', d => {log += d;});
  try {
    await waitFor(async () => {
      try {return (await fetch(`${BASE}/api/online/status`)).ok;} catch {return false;}
    }, 60_000, 'wrangler dev');
  } catch (error) {
    console.error(log);
    throw error;
  }

  assert.deepEqual(await (await fetch(`${BASE}/api/online/status`)).json(), {online: 0});
  const noUpgrade = await fetch(`${BASE}/api/online/ws`);
  assert.equal(noUpgrade.status, 426);
  assert.equal(await upgradeStatus(''), 401);

  const alice = await register('e2e_alice');
  const bob = await register('e2e_bob');

  const a = open(alice.cookie);
  await a.opened;
  const welcomeA = await a.next('welcome');
  assert.deepEqual(welcomeA.you, {id: alice.id, user: 'e2e_alice'});
  a.send(hello('Alice'));

  const b = open(bob.cookie);
  await b.opened;
  const welcomeB = await b.next('welcome');
  assert.equal(welcomeB.you.user, 'e2e_bob');
  assert.deepEqual(welcomeB.players.map(p => p.id), [alice.id]);
  b.send(hello('Bob'));
  const join = await a.next('join');
  assert.equal(join.player.id, bob.id);
  assert.equal(join.player.user, 'e2e_bob');
  assert.deepEqual(await (await fetch(`${BASE}/api/online/status`)).json(), {online: 2});

  b.send({t: 'chat', ch: 'world', text: 'สวัสดีทุกคน', from: alice.id});
  const line = await a.next('chat');
  assert.equal(line.from, bob.id);
  assert.equal(line.user, 'e2e_bob');
  assert.equal(line.name, 'Bob');
  assert.equal(line.text, 'สวัสดีทุกคน');

  a.send({t: 'party_invite', to: bob.id});
  const invite = await b.next('party_invite');
  assert.equal(invite.from, alice.id);
  b.send({t: 'party_answer', from: alice.id, ok: true});
  const party = (await a.next('party')).party;
  assert.equal(party.leader, alice.id);
  assert.deepEqual(party.members, [alice.id, bob.id]);
  assert.deepEqual((await b.next('party')).party, party);
  assert.deepEqual(await b.next('host'), {t: 'host', zone: 'meadow', id: alice.id});

  a.send({t: 'ent_snap', zone: 'meadow', ents: [[1, 0, 0, 0, 10, 10, 0]]});
  assert.equal((await b.next('ent_snap')).from, alice.id);
  b.send({t: 'chat', ch: 'party', text: 'ไปกัน'});
  assert.equal((await a.next('chat')).ch, 'party');

  // A second socket of bob's account kicks the first.
  const b2 = open(bob.cookie);
  await b2.opened;
  assert.deepEqual(await b.next('kicked'), {t: 'kicked', reason: 'elsewhere'});
  assert.equal((await b2.next('welcome')).party.leader, alice.id);

  b2.ws.close();
  assert.deepEqual(await a.next('leave'), {t: 'leave', id: bob.id});
  assert.deepEqual(await a.next('party'), {t: 'party', party: null});
  a.ws.close();
  await waitFor(async () => (await (await fetch(`${BASE}/api/online/status`)).json()).online === 0, 5000, 'everyone gone');
  console.log('online e2e: ok (wrangler dev, D1 accounts, two WebSockets: welcome, join, chat, party, host, ent_snap, kick, leave)');
} finally {
  cleanup();
}
