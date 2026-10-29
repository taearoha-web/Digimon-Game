import test from 'node:test';
import assert from 'node:assert/strict';
import Anthropic from '@anthropic-ai/sdk';
import {handleAccountRequest} from '../../accounts/server/accounts.js';
import {D1Sqlite} from '../../accounts/tests/d1-sqlite.mjs';
import {handleChat, chatRequest, readChat, readReply, userTurn, LIMITS, DEFAULT_MODEL} from '../chat.mjs';

const ORIGIN = 'https://toon-tale.example';
const PASSWORD = 'CuteDragonPass2026!';
const PLAYER = {name: 'Kaito', class: 'warrior', level: 34, stars: 0, style: 'ว่างกลางวัน', doing: 'hunt', place: 'ป่าเห็ด', guild: '', gender: 0, inParty: false, divine: false};
const HERO = {name: 'น้องแมว', class: 'mage', level: 30, stars: 0, guild: ''};

/** A stand-in for the Claude client: records each request, answers with `answer`. */
function fakeClient(answer) {
  const calls = [];
  return {calls, beta: {messages: {create: async request => {
    calls.push(request);
    if (answer instanceof Error) throw answer;
    return typeof answer === 'function' ? answer(request) : answer;
  }}}};
}

const textMessage = (json, stop = 'end_turn') => ({stop_reason: stop, content: [{type: 'thinking', thinking: ''}, {type: 'text', text: JSON.stringify(json)}]});

function harness(t) {
  const DB = new D1Sqlite();
  t.after(() => DB.close());
  let cookie = '';
  let userId = '';
  async function register() {
    const response = await handleAccountRequest(new Request(`${ORIGIN}/api/account/register`, {
      method: 'POST', headers: {'content-type': 'application/json', origin: ORIGIN, 'cf-connecting-ip': '203.0.113.9'},
      body: JSON.stringify({username: 'chathero', password: PASSWORD}),
    }), {DB});
    const json = await response.json();
    assert.equal(response.status, 201, JSON.stringify(json));
    cookie = response.headers.get('set-cookie').split(';')[0];
    userId = json.user.id;
  }
  async function chat(body, {client, env = {}, origin = ORIGIN, signedIn = true, method = 'POST'} = {}) {
    const headers = {'content-type': 'application/json', origin, 'cf-connecting-ip': '203.0.113.9'};
    if (signedIn) {headers.cookie = cookie; headers['x-toon-account-id'] = userId;}
    const response = await handleChat(new Request(`${ORIGIN}/api/account/chat`, {
      method, headers, body: method === 'POST' ? JSON.stringify(body) : undefined,
    }), {DB, ...env}, client ? {client} : {});
    return {status: response.status, body: await response.json()};
  }
  return {register, chat};
}

const ask = (text, extra = {}) => ({text, player: PLAYER, hero: HERO, history: [], channel: 'direct', ...extra});

test('a signed-in hero gets the player\'s reply and action', async t => {
  const h = harness(t);
  await h.register();
  const client = fakeClient(textMessage({reply: 'ได้เลย ไปล่าด้วยกัน!', action: 'join_party'}));
  const result = await h.chat(ask('ไปปาร์ตี้กันไหม'), {client});
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.deepEqual(result.body, {reply: 'ได้เลย ไปล่าด้วยกัน!', action: 'join_party'});
  const request = client.calls[0];
  assert.equal(request.model, DEFAULT_MODEL);
  assert.equal(request.output_config.effort, 'low');
  assert.equal(request.output_config.format.type, 'json_schema');
  assert.deepEqual(request.betas, ['server-side-fallback-2026-07-01']);
  assert.equal(request.fallbacks, 'default');
  assert.equal(request.system[0].cache_control.type, 'ephemeral');
  assert.match(request.messages[0].content, /You are Kaito, a boy warrior player, Lv\.34/);
  assert.match(request.messages[0].content, /<hero_message>\nไปปาร์ตี้กันไหม\n<\/hero_message>/);
});

test('the chat needs a signed-in account, a POST from the game and a message', async t => {
  const h = harness(t);
  await h.register();
  const client = fakeClient(textMessage({reply: 'สวัสดี', action: 'none'}));
  assert.equal((await h.chat(ask('สวัสดี'), {client, signedIn: false})).status, 401);
  assert.equal((await h.chat(ask('สวัสดี'), {client, origin: 'https://evil.example'})).status, 403);
  assert.equal((await h.chat(undefined, {client, method: 'GET'})).status, 405);
  const empty = await h.chat(ask('   '), {client});
  assert.equal(empty.status, 400);
  assert.equal(empty.body.error.code, 'invalid_chat');
  assert.equal(client.calls.length, 0, 'nothing is sent to the model for a refused request');
});

test('without the Worker secret the chat says it is not switched on', async t => {
  const h = harness(t);
  await h.register();
  const result = await h.chat(ask('สวัสดี'));
  assert.equal(result.status, 503);
  assert.equal(result.body.error.code, 'chat_unavailable');
});

test('each account is limited per minute', async t => {
  const h = harness(t);
  await h.register();
  const client = fakeClient(textMessage({reply: 'จ้า', action: 'none'}));
  const perMinute = LIMITS.find(limit => limit[0] === 'minute')[1];
  for (let i = 0; i < perMinute; i++) assert.equal((await h.chat(ask(`ข้อความ ${i}`), {client})).status, 200);
  const over = await h.chat(ask('อีกข้อความ'), {client});
  assert.equal(over.status, 429);
  assert.equal(over.body.error.code, 'too_many_messages');
  assert.equal(client.calls.length, perMinute);
});

test('API errors become short game errors, refusals an in-character line', async t => {
  const h = harness(t);
  await h.register();
  const busy = new Anthropic.RateLimitError(429, {type: 'error', error: {type: 'rate_limit_error', message: 'slow down'}}, 'slow down', new Headers());
  const r1 = await h.chat(ask('สวัสดี'), {client: fakeClient(busy)});
  assert.equal(r1.status, 503);
  assert.equal(r1.body.error.code, 'chat_busy');
  const bad = new Anthropic.AuthenticationError(401, {type: 'error', error: {type: 'authentication_error', message: 'bad key'}}, 'bad key', new Headers());
  const r2 = await h.chat(ask('สวัสดี'), {client: fakeClient(bad)});
  assert.equal(r2.status, 503);
  assert.equal(r2.body.error.code, 'chat_unavailable');
  assert.doesNotMatch(JSON.stringify(r2.body), /bad key/);
  const refused = await h.chat(ask('สวัสดี'), {client: fakeClient({stop_reason: 'refusal', content: []})});
  assert.equal(refused.status, 200);
  assert.equal(refused.body.action, 'none');
  assert.ok(refused.body.reply.length > 0);
});

test('requests are cut to size and the talk so far is kept in order', () => {
  const long = 'ก'.repeat(500);
  const chat = readChat({
    text: `${long}\u0000`, channel: 'world',
    player: {...PLAYER, name: 'N'.repeat(60), level: 999, doing: 'dance'},
    hero: HERO,
    history: Array.from({length: 20}, (_, i) => ({who: i % 2 ? 'player' : 'hero', text: `บรรทัด ${i}`})),
  });
  assert.equal([...chat.line].length, 200);
  assert.equal(chat.player.name.length, 24);
  assert.equal(chat.player.level, 1, 'an impossible level falls back');
  assert.equal(chat.player.doing, '');
  assert.equal(chat.history.length, 8);
  assert.equal(chat.history[0].text, 'บรรทัด 12');
  assert.equal(chat.channel, 'world');
  const turn = userTurn(chat);
  assert.match(turn, /public world chat/);
  assert.ok(turn.indexOf('บรรทัด 12') < turn.indexOf('บรรทัด 19'));
});

test('replies are read from the JSON answer and cut to size', () => {
  assert.deepEqual(readReply(textMessage({reply: 'ร้านเปิดอยู่ ดูของได้เลย', action: 'open_stall'})), {reply: 'ร้านเปิดอยู่ ดูของได้เลย', action: 'open_stall'});
  assert.equal(readReply(textMessage({reply: 'จ้า', action: 'fly'})).action, 'none');
  assert.equal([...readReply(textMessage({reply: 'ข'.repeat(400), action: 'none'})).reply].length, 160);
  assert.deepEqual(readReply({stop_reason: 'end_turn', content: [{type: 'text', text: 'ไม่ใช่ JSON'}]}), {reply: 'ไม่ใช่ JSON', action: 'none'});
  assert.equal(readReply({stop_reason: 'end_turn', content: []}).reply, '...');
});

test('a model without server-side fallbacks is asked without them', () => {
  const chat = readChat(ask('สวัสดี'));
  const request = chatRequest(chat, 'claude-haiku-5-5');
  assert.equal(request.model, 'claude-haiku-5-5');
  assert.equal(request.fallbacks, undefined);
  assert.equal(request.betas, undefined);
});
