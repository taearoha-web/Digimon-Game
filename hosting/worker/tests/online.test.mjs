/** Online play server (docs/ONLINE_PROTOCOL.md): the room logic with fake sockets, the
 * Durable Object wrapper with a fake hibernation context, and the Worker's /api/online
 * routes with the real account code on SQLite. Run: node hosting/worker/tests/online.test.mjs */
import test from 'node:test';
import assert from 'node:assert/strict';
import {Room, CLOSE_ELSEWHERE, CLOSE_IDLE, PARTY_GRACE_MS, INSTANCED_ZONES} from '../online/room.mjs';
import {WorldRoom, fitAttachment} from '../online/world_room.mjs';
import worker from '../worker.mjs';
import {handleAccountRequest} from '../../accounts/server/accounts.js';
import {D1Sqlite} from '../../accounts/tests/d1-sqlite.mjs';

// ------------------------------------------------------------------ harness

function fakeSocket() {
  return {
    sent: [], closed: null,
    send(text) {if (this.closed) throw new Error('closed'); this.sent.push(JSON.parse(text));},
    close(code, reason) {this.closed = {code, reason};},
  };
}

function world() {
  const clock = {t: 1_000_000};
  const room = new Room({now: () => clock.t});
  let n = 0;
  function connect(id, user = `user_${id}`) {
    const socket = fakeSocket();
    const key = `k${++n}`;
    room.connect(key, socket, {id, user});
    const client = {
      id, user, key, socket,
      /** Sends a frame; the clock moves 40 ms so normal tests stay under the rate limit. */
      send(obj) {clock.t += 40; room.message(key, typeof obj === 'string' ? obj : JSON.stringify(obj));},
      hello(extra = {}) {
        client.send({t: 'hello', name: `Hero ${id}`, cls: 'mage', level: 10, stars: 0, look: {class: 'mage'}, zone: 'meadow', pos: [1, 0, 2], yaw: 0, hp: 100, max_hp: 100, mount: '', ...extra});
        return client;
      },
      frames(type) {return socket.sent.filter(f => !type || f.t === type);},
      last(type) {return client.frames(type).at(-1);},
      clear() {socket.sent.length = 0;},
      zone(zone) {client.send({t: 'state', pos: [0, 0, 0], yaw: 0, anim: 'idle', hp: 100, max_hp: 100, zone, mount: ''});},
      close() {room.close(key);},
    };
    return client;
  }
  return {room, clock, connect};
}

function clearAll(...clients) {for (const c of clients) c.clear();}

/** a invites b, b accepts. */
function partyUp(a, b) {
  a.send({t: 'party_invite', to: b.id});
  b.send({t: 'party_answer', from: a.id, ok: true});
}

// ------------------------------------------------------------------ room

test('welcome, join on hello, who, leave on close', () => {
  const {connect} = world();
  const a = connect('1');
  assert.deepEqual(a.last('welcome'), {t: 'welcome', you: {id: '1', user: 'user_1'}, players: [], party: null});
  a.hello();
  const b = connect('2');
  const welcome = b.last('welcome');
  assert.equal(welcome.players.length, 1);
  assert.equal(welcome.players[0].id, '1');
  assert.equal(welcome.players[0].user, 'user_1');
  assert.equal(welcome.players[0].name, 'Hero 1');
  assert.deepEqual(welcome.players[0].pos, [1, 0, 2]);
  assert.equal(welcome.players[0].party, null);
  b.hello({name: 'ชื่อยาวมากเกินสิบหกตัวอักษรแน่นอน', user: 'spoof', id: '99'});
  const join = a.last('join');
  assert.equal(join.player.id, '2');
  assert.equal(join.player.user, 'user_2');
  assert.equal([...join.player.name].length, 16);
  assert.equal(b.frames('join').length, 0, 'no join echo to yourself');
  b.send({t: 'who'});
  assert.deepEqual(b.last('players').players.map(p => p.id), ['1']);
  // A frame before hello other than who is ignored.
  const c = connect('3');
  c.send({t: 'chat', ch: 'world', text: 'hi'});
  assert.equal(a.frames('chat').length, 0);
  b.close();
  assert.deepEqual(a.last('leave'), {t: 'leave', id: '2'});
  c.close();
  assert.equal(a.frames('leave').length, 1, 'a socket that never said hello leaves quietly');
});

test('state and look go to everyone else (clients filter by zone)', () => {
  const {connect} = world();
  const a = connect('1').hello();
  const b = connect('2').hello({zone: 'forest'});
  clearAll(a, b);
  a.send({t: 'state', pos: [5, 0, 6], yaw: 1.5, anim: 'run', hp: 90, max_hp: 100, zone: 'meadow', mount: 'horse', id: 'spoof'});
  assert.deepEqual(b.last('state'), {t: 'state', id: '1', pos: [5, 0, 6], yaw: 1.5, anim: 'run', hp: 90, max_hp: 100, zone: 'meadow', mount: 'horse'});
  assert.equal(a.frames('state').length, 0);
  a.send({t: 'look', look: {class: 'mage', wings: 3}, level: 11, stars: 2});
  assert.deepEqual(b.last('look'), {t: 'look', id: '1', look: {class: 'mage', wings: 3}, level: 11, stars: 2, pet: ''});
  b.send({t: 'who'});
  const me = b.last('players').players[0];
  assert.deepEqual(me.pos, [5, 0, 6]);
  assert.equal(me.level, 11);
  assert.equal(me.look.wings, 3);
});

test('the pet a player shows: hello and look carry it, only the three pets pass, a look without one keeps it', () => {
  const {connect} = world();
  const a = connect('1').hello({pet: 'fire'});
  const b = connect('2').hello({pet: 'dragon'});
  b.send({t: 'who'});
  assert.equal(b.last('players').players.find(p => p.id === '1').pet, 'fire', 'the hello carries the pet');
  assert.equal(a.last('join').player.pet, '', 'an unknown pet is dropped');
  clearAll(a, b);
  a.send({t: 'look', look: {class: 'mage'}, level: 12, stars: 0, pet: 'water'});
  assert.equal(b.last('look').pet, 'water');
  a.send({t: 'look', look: {class: 'mage'}, level: 13, stars: 0});
  assert.equal(b.last('look').pet, 'water', 'a look without a pet keeps the one shown');
  for (const bad of [5, ['fire'], {id: 'fire'}, 'x'.repeat(40), null]) {
    a.send({t: 'look', look: {class: 'mage'}, level: 13, stars: 0, pet: bad});
    assert.equal(b.last('look').pet, '', `a malformed pet (${JSON.stringify(bad)}) shows none`);
  }
  a.send({t: 'look', look: {class: 'mage'}, level: 13, stars: 0, pet: 'earth'});
  b.send({t: 'who'});
  assert.equal(b.last('players').players.find(p => p.id === '1').pet, 'earth', 'who lists the pet');
});

test('chat: world to all, party to members, whisper to sender and target, trimmed, spoofed from ignored', () => {
  const {connect} = world();
  const a = connect('1').hello();
  const b = connect('2').hello();
  const c = connect('3').hello();
  clearAll(a, b, c);
  a.send({t: 'chat', ch: 'world', text: '  สวัสดี '.padEnd(300, 'x'), from: '3', user: 'evil', name: 'evil'});
  for (const x of [a, b, c]) {
    const line = x.last('chat');
    assert.equal(line.from, '1');
    assert.equal(line.user, 'user_1');
    assert.equal(line.name, 'Hero 1');
    assert.equal(line.ch, 'world');
    assert.equal([...line.text].length, 120);
    assert.ok(line.text.startsWith('สวัสดี'));
  }
  clearAll(a, b, c);
  a.send({t: 'chat', ch: 'whisper', to: '2', text: 'psst'});
  assert.deepEqual(b.last('chat'), {t: 'chat', ch: 'whisper', from: '1', user: 'user_1', name: 'Hero 1', text: 'psst', to: '2'});
  assert.equal(a.last('chat').text, 'psst');
  assert.equal(c.frames('chat').length, 0);
  a.send({t: 'chat', ch: 'whisper', to: '42', text: 'hello?'});
  assert.equal(a.last('error').code, 'not_online');
  a.send({t: 'chat', ch: 'party', text: 'anyone'});
  assert.equal(a.last('error').code, 'no_party');
  partyUp(a, b);
  clearAll(a, b, c);
  b.send({t: 'chat', ch: 'party', text: 'ไปกัน'});
  assert.equal(a.last('chat').ch, 'party');
  assert.equal(b.last('chat').text, 'ไปกัน');
  assert.equal(c.frames('chat').length, 0);
  a.send({t: 'chat', ch: 'world', text: '   '});
  assert.equal(b.frames('chat').length, 1, 'empty lines are dropped');
});

test('party: invite, answer, max 5, leader-only kick, leader handover, dissolve', () => {
  const {room, clock, connect} = world();
  const [a, b, c, d, e, f] = ['1', '2', '3', '4', '5', '6'].map(id => connect(id).hello());
  a.send({t: 'party_invite', to: '2'});
  assert.deepEqual(b.last('party_invite'), {t: 'party_invite', from: '1', name: 'Hero 1'});
  b.send({t: 'party_answer', from: '3', ok: true});
  assert.equal(b.last('error').code, 'no_invite', 'cannot accept an invite nobody sent');
  b.send({t: 'party_answer', from: '1', ok: true});
  const party = a.last('party').party;
  assert.equal(party.leader, '1');
  assert.deepEqual(party.members, ['1', '2']);
  assert.deepEqual(b.last('party').party, party);
  assert.deepEqual(a.last('party_answer'), {t: 'party_answer', from: '2', ok: true});
  // A refused invite.
  a.send({t: 'party_invite', to: '3'});
  c.send({t: 'party_answer', from: '1', ok: false});
  assert.deepEqual(a.last('party_answer'), {t: 'party_answer', from: '3', ok: false});
  assert.equal(c.frames('party').length, 0);
  // Any member may invite; the party fills at 5.
  b.send({t: 'party_invite', to: '3'});
  c.send({t: 'party_answer', from: '2', ok: true});
  partyUp(a, d);
  partyUp(a, e);
  assert.deepEqual(a.last('party').party.members, ['1', '2', '3', '4', '5']);
  a.send({t: 'party_invite', to: '6'});
  assert.equal(a.last('error').code, 'party_full');
  // Leader only kick.
  b.send({t: 'party_kick', who: '3'});
  assert.equal(b.last('error').code, 'not_leader');
  a.send({t: 'party_kick', who: '3'});
  assert.deepEqual(c.last('party'), {t: 'party', party: null});
  assert.deepEqual(a.last('party').party.members, ['1', '2', '4', '5']);
  // The party field of the player list follows.
  f.send({t: 'who'});
  const list = Object.fromEntries(f.last('players').players.map(p => [p.id, p.party]));
  assert.equal(list['1'], party.id);
  assert.equal(list['3'], null);
  // The leader leaves: the next member leads.
  a.send({t: 'party_leave'});
  assert.deepEqual(a.last('party'), {t: 'party', party: null});
  assert.equal(b.last('party').party.leader, '2');
  assert.deepEqual(b.last('party').party.members, ['2', '4', '5']);
  // The leader drops: handover again, but it keeps its place (away) for the grace.
  b.close();
  assert.equal(d.last('party').party.leader, '4');
  assert.deepEqual(d.last('party').party.away, ['2']);
  assert.deepEqual(d.last('party').party.members, ['2', '4', '5']);
  e.send({t: 'party_leave'});
  assert.deepEqual(d.last('party').party.members, ['2', '4'], 'an away member still counts');
  // Back within the grace: in the party again, without a new invite.
  const b2 = connect('2').hello();
  assert.deepEqual(b2.last('welcome').party.members, ['2', '4']);
  assert.deepEqual(d.last('party').party.away, [], 'everyone is back');
  assert.equal(b2.last('party').party.leader, '4', 'the lead stays where it went');
  // Gone past the grace: out of the party, and a party of one ends.
  b2.close();
  clock.t += PARTY_GRACE_MS + 1000;
  d.send({t: 'who'});   // d's own traffic keeps it online and runs the room's tick
  assert.deepEqual(d.last('party'), {t: 'party', party: null}, 'a party of one ends');
  // Someone in a party cannot be invited into another (fresh players: the 15 minutes
  // above left everyone else idle and dropped).
  const [g, h, k] = ['7', '8', '9'].map(id => connect(id).hello());
  partyUp(g, h);
  k.send({t: 'party_invite', to: '8'});
  assert.equal(k.last('error').code, 'in_party');
  k.send({t: 'party_invite', to: '9'});
  assert.equal(k.last('error').code, 'self');
});

test('instanced zones: host per (party, zone), leader when present, else first arrival; re-elected on zone change and drop', () => {
  const {connect} = world();
  const a = connect('1').hello({zone: 'tower'});               // leader
  const b = connect('2').hello({zone: 'tower'});
  const c = connect('3').hello({zone: 'arena'});
  const x = connect('9').hello({zone: 'tower'});                // not in the party
  assert.deepEqual(a.frames('host'), [{t: 'host', zone: 'tower', id: null}], 'no party in an instanced zone: nobody shares');
  partyUp(a, b);
  assert.deepEqual(a.last('host'), {t: 'host', zone: 'tower', id: '1'});
  assert.deepEqual(b.last('host'), {t: 'host', zone: 'tower', id: '1'});
  partyUp(a, c);
  assert.deepEqual(c.last('host'), {t: 'host', zone: 'arena', id: null}, 'alone in its zone: nobody shares');
  assert.deepEqual(x.frames('host'), [{t: 'host', zone: 'tower', id: null}], 'an outsider in an instanced zone is never served');
  // c joins the tower: the leader still hosts it.
  clearAll(a, b, c);
  c.zone('tower');
  assert.deepEqual(c.last('host'), {t: 'host', zone: 'tower', id: '1'});
  assert.equal(a.frames('host').length, 0, 'unchanged host: no frame');
  // The leader goes to the arena: b arrived before c, so b hosts the tower; the leader is alone.
  clearAll(a, b, c);
  a.zone('arena');
  assert.deepEqual(b.last('host'), {t: 'host', zone: 'tower', id: '2'});
  assert.deepEqual(c.last('host'), {t: 'host', zone: 'tower', id: '2'});
  assert.deepEqual(a.last('host'), {t: 'host', zone: 'arena', id: null});
  // c follows the leader: the leader hosts the arena, b is alone in the tower.
  clearAll(a, b, c);
  c.zone('arena');
  assert.deepEqual(a.last('host'), {t: 'host', zone: 'arena', id: '1'});
  assert.deepEqual(c.last('host'), {t: 'host', zone: 'arena', id: '1'});
  assert.deepEqual(b.last('host'), {t: 'host', zone: 'tower', id: null});
  // b comes to the arena as well, then the leader drops: b (joined the party before c) leads and hosts.
  b.zone('arena');
  assert.deepEqual(b.last('host'), {t: 'host', zone: 'arena', id: '1'});
  clearAll(a, b, c);
  a.close();
  assert.equal(b.last('party').party.leader, '2', 'b joined before c, so b leads');
  assert.deepEqual(b.last('host'), {t: 'host', zone: 'arena', id: '2'});
  assert.deepEqual(c.last('host'), {t: 'host', zone: 'arena', id: '2'});
  // b leaves the party: c is the only member left in the arena, the host clears for both.
  clearAll(b, c);
  b.send({t: 'party_leave'});
  assert.deepEqual(c.last('host'), {t: 'host', zone: 'arena', id: null});
  assert.deepEqual(b.last('host'), {t: 'host', zone: 'arena', id: null});
  assert.equal(x.frames('host').length, 1);
});

test('instanced zones: a non-leader first arrival keeps hosting until the leader comes', () => {
  const {connect} = world();
  const a = connect('1').hello({zone: 'pvp'});
  const b = connect('2').hello({zone: 'guildwar'});
  const c = connect('3').hello({zone: 'arena'});
  partyUp(a, b);
  partyUp(a, c);
  c.zone('guildwar');                     // b arrived first
  assert.deepEqual(c.last('host'), {t: 'host', zone: 'guildwar', id: '2'});
  a.zone('guildwar');                     // the leader arrives and takes over
  assert.deepEqual(b.last('host'), {t: 'host', zone: 'guildwar', id: '1'});
  b.close();                              // host unchanged when a non-host drops
  assert.deepEqual(c.last('host'), {t: 'host', zone: 'guildwar', id: '1'});
});

test('open zones: one host for everyone in the zone, party or not; first arrival; re-elected on zone change and drop', () => {
  assert.deepEqual([...INSTANCED_ZONES].sort(), ['arena', 'guildwar', 'pvp', 'raid', 'tower']);
  const {connect} = world();
  const a = connect('1').hello();                    // meadow, first
  assert.deepEqual(a.frames('host'), [{t: 'host', zone: 'meadow', id: null}], 'alone: play alone');
  const b = connect('2').hello();                    // meadow, no party
  assert.deepEqual(a.last('host'), {t: 'host', zone: 'meadow', id: '1'});
  assert.deepEqual(b.last('host'), {t: 'host', zone: 'meadow', id: '1'});
  const c = connect('3').hello({zone: 'forest'});
  assert.deepEqual(c.frames('host'), [{t: 'host', zone: 'forest', id: null}]);
  // A party arriving later does not take the zone over, even with its leader there.
  const d = connect('4').hello();
  assert.deepEqual(d.last('host'), {t: 'host', zone: 'meadow', id: '1'});
  clearAll(a, b, c, d);
  partyUp(d, b);
  assert.equal(a.frames('host').length + b.frames('host').length + d.frames('host').length, 0, 'a party changes nothing in an open zone');
  // The host walks to the forest: b (next arrival) hosts the meadow; c (there first) hosts the forest.
  a.zone('forest');
  assert.deepEqual(b.last('host'), {t: 'host', zone: 'meadow', id: '2'});
  assert.deepEqual(d.last('host'), {t: 'host', zone: 'meadow', id: '2'});
  assert.deepEqual(a.last('host'), {t: 'host', zone: 'forest', id: '3'});
  assert.deepEqual(c.last('host'), {t: 'host', zone: 'forest', id: '3'});
  // Back to the meadow: a is now the latest arrival there.
  clearAll(a, b, c, d);
  a.zone('meadow');
  assert.deepEqual(a.last('host'), {t: 'host', zone: 'meadow', id: '2'});
  assert.equal(b.frames('host').length + d.frames('host').length, 0, 'unchanged host: no frame');
  assert.deepEqual(c.last('host'), {t: 'host', zone: 'forest', id: null});
  // The host drops: the next arrival takes over.
  clearAll(a, b, c, d);
  b.close();
  assert.deepEqual(d.last('host'), {t: 'host', zone: 'meadow', id: '4'});
  assert.deepEqual(a.last('host'), {t: 'host', zone: 'meadow', id: '4'});
  d.close();
  assert.deepEqual(a.last('host'), {t: 'host', zone: 'meadow', id: null}, 'alone again');
  // An instanced zone next door is not part of the open zone.
  c.zone('tower');
  a.zone('tower');
  assert.deepEqual(a.last('host'), {t: 'host', zone: 'tower', id: null});
});

test('instanced zones: ent_snap / ent_event go from the host to the party in that zone only; ent_hit to the host', () => {
  const {connect} = world();
  const a = connect('1').hello({zone: 'tower'});               // leader, host of the tower
  const b = connect('2').hello({zone: 'tower'});
  const c = connect('3').hello({zone: 'arena'});
  const x = connect('9').hello({zone: 'tower'});                // outsider in the tower
  partyUp(a, b);
  partyUp(a, c);
  clearAll(a, b, c, x);
  const snap = {t: 'ent_snap', zone: 'tower', ents: [[1, 2.5, 3.5, 0, 50, 100, 0]]};
  a.send({...snap, from: '9', user: 'admin'});
  assert.deepEqual(b.last('ent_snap'), {...snap, from: '1'}, 'from is the sender, a spoofed user is dropped');
  assert.equal(c.frames('ent_snap').length, 0, 'another zone');
  assert.equal(x.frames('ent_snap').length, 0, 'not in the party');
  assert.equal(a.frames('ent_snap').length, 0, 'no echo');
  a.send({t: 'ent_event', zone: 'tower', eid: 1, ev: 'dead', data: {killer: '2', share: {'2': 50}}});
  assert.deepEqual(b.last('ent_event'), {t: 'ent_event', zone: 'tower', eid: 1, ev: 'dead', data: {killer: '2', share: {'2': 50}}, from: '1'});
  assert.equal(x.frames('ent_event').length, 0);
  // A member that is not the host cannot snap; a wrong zone is dropped.
  b.send({t: 'ent_snap', zone: 'tower', ents: []});
  a.send({t: 'ent_snap', zone: 'arena', ents: []});
  assert.equal(a.frames('ent_snap').length, 0);
  assert.equal(c.frames('ent_snap').length, 0);
  assert.equal(b.frames('ent_snap').length, 1);
  // Hits go to the host only.
  b.send({t: 'ent_hit', zone: 'tower', eid: 1, dmg: 120, crit: true, from: '3'});
  assert.deepEqual(a.last('ent_hit'), {t: 'ent_hit', zone: 'tower', eid: 1, dmg: 120, crit: true, from: '2'});
  assert.equal(x.frames('ent_hit').length + c.frames('ent_hit').length, 0);
  // An outsider's hits and snaps go nowhere.
  x.send({t: 'ent_hit', zone: 'tower', eid: 1, dmg: 1, crit: false});
  x.send({t: 'ent_snap', zone: 'tower', ents: []});
  assert.equal(a.frames('ent_hit').length, 1);
  assert.equal(b.frames('ent_snap').length, 1);
  // Alone in a zone: no host, nothing relayed.
  c.send({t: 'ent_snap', zone: 'arena', ents: []});
  c.send({t: 'ent_hit', zone: 'arena', eid: 1, dmg: 1, crit: false});
  assert.equal(a.frames('ent_snap').length + b.frames('ent_snap').length, 1);
});

test('open zones: ent_* and wp_* go from the zone host to everyone in the zone, never to other zones; ent_hit to the host', () => {
  const {connect} = world();
  const a = connect('1').hello();                    // meadow host
  const b = connect('2').hello();                    // meadow, no party
  const c = connect('3').hello();                    // meadow, in a party with d
  const d = connect('4').hello({zone: 'forest'});
  const e = connect('5').hello({zone: 'tower'});
  partyUp(c, d);
  clearAll(a, b, c, d, e);
  const snap = {t: 'ent_snap', zone: 'meadow', ents: [[7, 1, 2, 0, 80, 100, 0]]};
  a.send(snap);
  for (const x of [b, c]) assert.deepEqual(x.last('ent_snap'), {...snap, from: '1'});
  assert.equal(a.frames('ent_snap').length + d.frames('ent_snap').length + e.frames('ent_snap').length, 0, 'no echo, no other zone');
  a.send({t: 'ent_event', zone: 'meadow', eid: 7, ev: 'dead', data: {killer: '2', share: {'2': 80}}});
  assert.equal(b.last('ent_event').from, '1');
  assert.equal(c.last('ent_event').ev, 'dead');
  assert.equal(d.frames('ent_event').length, 0);
  // AI world players: the same route.
  const ps = {t: 'wp_snap', zone: 'meadow', ps: [[3, 10.5, -4, 1.2, 'run', 1]]};
  a.send({...ps, user: 'spoof', from: '2'});
  assert.deepEqual(b.last('wp_snap'), {...ps, from: '1'});
  assert.deepEqual(c.last('wp_snap'), {...ps, from: '1'});
  a.send({t: 'wp_event', zone: 'meadow', index: 3, ev: 'skill', data: {id: 'fireball', eid: 7}});
  assert.deepEqual(b.last('wp_event'), {t: 'wp_event', zone: 'meadow', index: 3, ev: 'skill', data: {id: 'fireball', eid: 7}, from: '1'});
  assert.equal(d.frames('wp_snap').length + d.frames('wp_event').length + e.frames('wp_snap').length, 0);
  // Not the host, or a zone that is not the sender's: dropped.
  b.send({t: 'ent_snap', zone: 'meadow', ents: []});
  b.send({t: 'wp_snap', zone: 'meadow', ps: []});
  b.send({t: 'wp_event', zone: 'meadow', index: 1, ev: 'leave', data: {}});
  a.send({t: 'ent_snap', zone: 'forest', ents: []});
  a.send({t: 'wp_snap', zone: 'forest', ps: []});
  d.send({t: 'ent_snap', zone: 'forest', ents: []});          // alone in the forest
  assert.equal(c.frames('ent_snap').length, 1);
  assert.equal(c.frames('wp_snap').length, 1);
  assert.equal(c.frames('wp_event').length, 1);
  assert.equal(a.frames('ent_snap').length + d.frames('ent_snap').length + d.frames('wp_snap').length, 0);
  // Hits from anyone the host serves go to the host only.
  b.send({t: 'ent_hit', zone: 'meadow', eid: 7, dmg: 40, crit: false});
  c.send({t: 'ent_hit', zone: 'meadow', eid: 7, dmg: 60, crit: true, skill: 'slash'});
  assert.deepEqual(a.frames('ent_hit'), [
    {t: 'ent_hit', zone: 'meadow', eid: 7, dmg: 40, crit: false, from: '2'},
    {t: 'ent_hit', zone: 'meadow', eid: 7, dmg: 60, crit: true, skill: 'slash', from: '3'},
  ]);
  assert.equal(b.frames('ent_hit').length + c.frames('ent_hit').length + d.frames('ent_hit').length, 0);
  a.send({t: 'ent_hit', zone: 'meadow', eid: 7, dmg: 1, crit: false});   // the host itself
  b.send({t: 'ent_hit', zone: 'forest', eid: 7, dmg: 1, crit: false});   // not b's zone
  d.send({t: 'ent_hit', zone: 'forest', eid: 7, dmg: 1, crit: false});   // nobody hosts the forest
  assert.equal(a.frames('ent_hit').length, 2);
  // d walks into the meadow: served from now on.
  d.zone('meadow');
  assert.deepEqual(d.last('host'), {t: 'host', zone: 'meadow', id: '1'});
  a.send(snap);
  assert.equal(d.last('ent_snap').from, '1');
  assert.equal(e.frames('ent_snap').length, 0);
});

test('world host: the player online the longest; whost on connect and on change; ai_chat only from it, capped', () => {
  const {clock, connect} = world();
  const a = connect('1');
  assert.deepEqual(a.socket.sent.map(f => f.t), ['welcome', 'whost'], 'whost right after welcome');
  assert.deepEqual(a.last('whost'), {t: 'whost', id: null}, 'nobody has said hello yet');
  a.hello();
  assert.deepEqual(a.last('whost'), {t: 'whost', id: '1'});
  const b = connect('2');
  assert.deepEqual(b.socket.sent.map(f => f.t), ['welcome', 'whost']);
  assert.deepEqual(b.last('whost'), {t: 'whost', id: '1'});
  b.hello();
  const c = connect('3').hello({zone: 'forest'});
  assert.deepEqual(c.last('whost'), {t: 'whost', id: '1'});
  assert.equal(a.frames('whost').length + b.frames('whost').length, 3, 'no change: no frame');
  // ai_chat from the world host goes to everyone else, whatever the zone.
  clearAll(a, b, c);
  const lines = [{ch: 'world', speaker: 'Mira', text: 'ขาย ดาบ +7 ถูกๆ', color: '#ffcc00', index: 12}];
  a.send({t: 'ai_chat', lines, from: '3', user: 'spoof'});
  assert.deepEqual(b.last('ai_chat'), {t: 'ai_chat', lines, from: '1'});
  assert.deepEqual(c.last('ai_chat'), {t: 'ai_chat', lines, from: '1'});
  assert.equal(a.frames('ai_chat').length, 0, 'no echo');
  // Anyone else's ai_chat is dropped.
  b.send({t: 'ai_chat', lines});
  c.send({t: 'ai_chat', lines});
  assert.equal(a.frames('ai_chat').length, 0);
  assert.equal(b.frames('ai_chat').length, 1);
  assert.equal(c.frames('ai_chat').length, 1);
  // Caps: 8 lines a frame, text 200, speaker 24; bad lines are left out; nothing left: dropped.
  const many = Array.from({length: 12}, (_, i) => ({ch: 'world', speaker: 'ส'.repeat(40), text: `${i} ` + 'y'.repeat(300), color: [1, 0.5, 0], index: i}));
  many[1] = {ch: 'guild', speaker: 'x', text: 'guild talk'};
  many[2] = {speaker: 'x', text: '   '};
  many[3] = 'just a string';
  many[4] = {speaker: 'NoCh', text: 'ch defaults to world', color: {r: 1}, index: -1};
  a.send({t: 'ai_chat', lines: many});
  const out = b.last('ai_chat').lines;
  assert.equal(out.length, 5, 'only the first 8 lines are read, the 3 bad ones left out');
  assert.deepEqual(out.map(l => l.text.split(' ')[0]), ['0', 'ch', '5', '6', '7']);
  assert.equal([...out[0].text].length, 200);
  assert.equal([...out[0].speaker].length, 24);
  assert.deepEqual(out[0].color, [1, 0.5, 0]);
  assert.equal(out[0].index, 0);
  assert.deepEqual(out[1], {ch: 'world', speaker: 'NoCh', text: 'ch defaults to world'});
  b.clear();
  a.send({t: 'ai_chat', lines: [{ch: 'party', text: 'x'}, {text: ''}]});
  a.send({t: 'ai_chat', lines: 'hello'});
  a.send({t: 'ai_chat'});
  assert.equal(b.frames('ai_chat').length, 0);
  // A second socket of the world host keeps it world host.
  clearAll(a, b, c);
  const a2 = connect('1');
  assert.deepEqual(a2.socket.sent.map(f => f.t), ['welcome', 'whost', 'host']);
  assert.deepEqual(a2.last('whost'), {t: 'whost', id: '1'});
  assert.equal(b.frames('whost').length + c.frames('whost').length, 0);
  // The world host drops: the next longest online takes over, everyone is told.
  a2.close();
  assert.deepEqual(b.last('whost'), {t: 'whost', id: '2'});
  assert.deepEqual(c.last('whost'), {t: 'whost', id: '2'});
  b.send({t: 'ai_chat', lines});
  assert.equal(c.last('ai_chat').from, '2');
  // A newcomer does not take it over; an idle drop hands it on.
  const d = connect('4').hello();
  assert.deepEqual(d.last('whost'), {t: 'whost', id: '2'});
  clock.t += 20_000;
  c.send({t: 'state', zone: 'forest'});
  d.send({t: 'state', zone: 'meadow'});
  clock.t += 15_000;
  c.send({t: 'state', zone: 'forest'});             // runs the tick: b is silent for 35 s
  assert.deepEqual(b.socket.closed, {code: CLOSE_IDLE, reason: 'idle'});
  assert.deepEqual(c.last('whost'), {t: 'whost', id: '3'});
  assert.deepEqual(d.last('whost'), {t: 'whost', id: '3'});
});

test('export / restore rebuilds zone hosts from the players\' zones and the world host', () => {
  const {room, clock, connect} = world();
  const c = connect('3').hello();                    // first in the meadow, world host
  const a = connect('1').hello();
  const b = connect('2').hello();
  const d = connect('4').hello({zone: 'tower'});
  assert.deepEqual(b.last('host'), {t: 'host', zone: 'meadow', id: '3'});
  assert.deepEqual(b.last('whost'), {t: 'whost', id: '3'});
  room.takeDirty();
  const records = [a, b, d].map(x => JSON.parse(JSON.stringify(room.exportSession(x.key))));
  assert.equal(records[0].wh, '3');
  assert.ok(records[0].on > 0);
  // c's socket did not survive the sleep.
  const fresh = new Room({now: () => clock.t});
  const sockets = [fakeSocket(), fakeSocket(), fakeSocket()];
  [a, b, d].forEach((x, i) => fresh.restore(x.key, sockets[i], records[i]));
  fresh.finishRestore();
  const [sa, sb, sd] = sockets;
  assert.deepEqual(sa.sent, [{t: 'host', zone: 'meadow', id: '1'}, {t: 'whost', id: '1'}]);
  assert.deepEqual(sb.sent, [{t: 'host', zone: 'meadow', id: '1'}, {t: 'whost', id: '1'}]);
  assert.deepEqual(sd.sent, [{t: 'whost', id: '1'}], 'its tower host did not change');
  clock.t += 40;
  fresh.message(a.key, JSON.stringify({t: 'wp_snap', zone: 'meadow', ps: []}));
  assert.deepEqual(sb.sent.at(-1), {t: 'wp_snap', zone: 'meadow', ps: [], from: '1'});
  fresh.message(a.key, JSON.stringify({t: 'ai_chat', lines: [{speaker: 'Bo', text: 'hi'}]}));
  assert.equal(sd.sent.at(-1).t, 'ai_chat');
});

test('trade: request, offers unlock, lock, both confirm -> trade_done swapped', () => {
  const {connect} = world();
  const a = connect('1').hello();
  const b = connect('2').hello({zone: 'forest'});   // trades do not care about zones
  const c = connect('3').hello();
  a.send({t: 'trade_req', to: '2'});
  assert.deepEqual(b.last('trade_req'), {t: 'trade_req', from: '1'});
  b.send({t: 'trade_answer', from: '1', ok: true});
  assert.deepEqual(a.last('trade_answer'), {t: 'trade_answer', from: '2', ok: true});
  c.send({t: 'trade_req', to: '1'});
  assert.equal(c.last('error').code, 'busy');
  const sword = {id: 'sword', plus: 3};
  a.send({t: 'trade_offer', items: [sword], gold: 100, from: '3'});
  assert.deepEqual(b.last('trade_offer'), {t: 'trade_offer', from: '1', items: [sword], gold: 100});
  b.send({t: 'trade_offer', items: [], gold: 500});
  a.send({t: 'trade_lock'});
  assert.deepEqual(b.last('trade_lock'), {t: 'trade_lock', from: '1'});
  a.send({t: 'trade_confirm'});
  assert.equal(a.last('error').code, 'not_locked');
  b.send({t: 'trade_lock'});
  // A new offer unlocks both sides.
  b.send({t: 'trade_offer', items: [], gold: 400});
  a.send({t: 'trade_confirm'});
  assert.equal(a.last('error').code, 'not_locked');
  a.send({t: 'trade_lock'});
  b.send({t: 'trade_lock'});
  a.send({t: 'trade_confirm'});
  assert.deepEqual(b.last('trade_confirm'), {t: 'trade_confirm', from: '1'});
  assert.equal(a.frames('trade_done').length, 0);
  b.send({t: 'trade_confirm'});
  assert.deepEqual(a.last('trade_done'), {t: 'trade_done', with: '2', give: {items: [sword], gold: 100}, get: {items: [], gold: 400}});
  assert.deepEqual(b.last('trade_done'), {t: 'trade_done', with: '1', give: {items: [], gold: 400}, get: {items: [sword], gold: 100}});
  // The session is over.
  a.send({t: 'trade_offer', items: [], gold: 1});
  assert.equal(a.last('error').code, 'no_trade');
  assert.equal(c.frames('trade_offer').length + c.frames('trade_done').length, 0);
});

test('trade: cancel relays and ends, a drop cancels, refusing works, a stale answer fails', () => {
  const {connect} = world();
  const a = connect('1').hello();
  const b = connect('2').hello();
  const c = connect('3').hello();
  a.send({t: 'trade_req', to: '2'});
  b.send({t: 'trade_answer', from: '1', ok: false});
  assert.deepEqual(a.last('trade_answer'), {t: 'trade_answer', from: '2', ok: false});
  b.send({t: 'trade_answer', from: '1', ok: true});
  assert.equal(b.last('error').code, 'no_request');
  a.send({t: 'trade_req', to: '2'});
  b.send({t: 'trade_answer', from: '1', ok: true});
  b.send({t: 'trade_cancel'});
  assert.deepEqual(a.last('trade_cancel'), {t: 'trade_cancel', from: '2'});
  a.send({t: 'trade_req', to: '3'});
  c.send({t: 'trade_answer', from: '1', ok: true});
  c.send({t: 'trade_offer', items: [{id: 'gem'}], gold: 0});
  a.close();
  assert.deepEqual(c.last('trade_cancel'), {t: 'trade_cancel', from: '1'});
  c.send({t: 'trade_lock'});
  assert.equal(c.last('error').code, 'no_trade');
});

test('duel: relayed only between the two duelists of an accepted duel', () => {
  const {connect} = world();
  const a = connect('1').hello();
  const b = connect('2').hello();
  const c = connect('3').hello();
  a.send({t: 'pvp_hit', to: '2', dmg: 50, crit: false});
  assert.equal(b.frames('pvp_hit').length, 0, 'no duel yet');
  a.send({t: 'duel_req', to: '2'});
  assert.deepEqual(b.last('duel_req'), {t: 'duel_req', from: '1'});
  b.send({t: 'duel_answer', from: '1', ok: true});
  assert.deepEqual(a.last('duel_answer'), {t: 'duel_answer', from: '2', ok: true});
  a.send({t: 'pvp_hit', to: '2', dmg: 50, crit: true, skill: 'fireball', fx: 'burn', from: '3'});
  assert.deepEqual(b.last('pvp_hit'), {t: 'pvp_hit', to: '2', dmg: 50, crit: true, skill: 'fireball', fx: 'burn', from: '1'});
  a.send({t: 'pvp_hit', to: '3', dmg: 50, crit: false});
  c.send({t: 'pvp_hit', to: '2', dmg: 50, crit: false});
  assert.equal(c.frames('pvp_hit').length, 0);
  assert.equal(b.frames('pvp_hit').length, 1);
  c.send({t: 'duel_req', to: '1'});
  assert.equal(c.last('error').code, 'busy');
  b.send({t: 'duel_over', loser: '1'});
  assert.deepEqual(a.last('duel_over'), {t: 'duel_over', from: '2', loser: '2'}, 'the loser is the side that sent it');
  a.send({t: 'pvp_hit', to: '2', dmg: 50, crit: false});
  assert.equal(b.frames('pvp_hit').length, 1, 'over: no more hits');
  // A drop during a duel ends it for the other side.
  a.send({t: 'duel_req', to: '3'});
  c.send({t: 'duel_answer', from: '1', ok: true});
  c.close();
  assert.deepEqual(a.last('duel_over'), {t: 'duel_over', from: '3', loser: '3'});
});

test('guild war invite / answer / start stay within the party, start goes to accepted members', () => {
  const {connect} = world();
  const a = connect('1').hello();
  const b = connect('2').hello();
  const c = connect('3').hello();
  const x = connect('9').hello();
  partyUp(a, b);
  partyUp(a, c);
  b.send({t: 'gw_invite'});
  assert.equal(b.last('error').code, 'not_leader');
  a.send({t: 'gw_invite'});
  assert.deepEqual(b.last('gw_invite'), {t: 'gw_invite', from: '1'});
  assert.deepEqual(c.last('gw_invite'), {t: 'gw_invite', from: '1'});
  assert.equal(x.frames('gw_invite').length, 0);
  b.send({t: 'gw_answer', ok: true});
  c.send({t: 'gw_answer', ok: false});
  assert.deepEqual(a.last('gw_answer'), {t: 'gw_answer', from: '3', ok: false});
  assert.equal(a.frames('gw_answer').length, 2);
  a.send({t: 'gw_start', seed: 1234, plan: {side: 'alpha'}});
  assert.deepEqual(b.last('gw_start'), {t: 'gw_start', seed: 1234, plan: {side: 'alpha'}, from: '1'});
  assert.equal(c.frames('gw_start').length, 0);
  assert.equal(x.frames('gw_start').length, 0);
});

test('stalls: list, view, buy, sold -> bought, refuse, push to recent viewers, close on leave', () => {
  const {connect, clock} = world();
  const s = connect('1').hello();      // seller
  const b = connect('2').hello();      // buyer
  const v = connect('3').hello();      // a viewer from long ago
  const potion = {id: 'potion', count: 5};
  const ring = {id: 'ring'};
  s.send({t: 'stall_list', lots: [{lot: 1, item: potion, price: 300}, {lot: 2, item: ring, price: 9000}, {lot: 3, price: 1}]});
  b.send({t: 'stall_view', seller: '1'});
  assert.deepEqual(b.last('stall'), {t: 'stall', seller: '1', lots: [{lot: 1, item: potion, price: 300}, {lot: 2, item: ring, price: 9000}]});
  v.send({t: 'stall_view', seller: '1'});
  v.send({t: 'stall_view', seller: '2'});
  assert.deepEqual(v.last('stall'), {t: 'stall', seller: '2', lots: []});
  b.send({t: 'stall_buy', seller: '1', lot: 1, price: 300});
  assert.deepEqual(s.last('stall_buy'), {t: 'stall_buy', from: '2', seller: '1', lot: 1, price: 300});
  // The seller cannot charge more than the buyer agreed.
  s.send({t: 'stall_sold', to: '2', lot: 1, item: potion, price: 99999});
  assert.deepEqual(b.last('stall_bought'), {t: 'stall_bought', seller: '1', lot: 1, item: potion, price: 300});
  // A sale nobody asked for is ignored.
  s.send({t: 'stall_sold', to: '3', lot: 2, item: ring, price: 1});
  assert.equal(v.frames('stall_bought').length, 0);
  // Re-publishing pushes to viewers of the last 5 minutes only.
  for (let i = 0; i < 18; i++) {            // six minutes of heartbeats
    clock.t += 20_000;
    for (const x of [s, b, v]) x.send({t: 'state', zone: 'meadow'});
  }
  b.send({t: 'stall_view', seller: '1'});
  b.clear();
  v.clear();
  s.send({t: 'stall_list', lots: [{lot: 2, item: ring, price: 9000}]});
  assert.deepEqual(b.last('stall'), {t: 'stall', seller: '1', lots: [{lot: 2, item: ring, price: 9000}]});
  assert.equal(v.frames('stall').length, 0, 'viewed more than 5 minutes ago');
  b.send({t: 'stall_buy', seller: '1', lot: 2, price: 9000});
  s.send({t: 'stall_refuse', to: '2', lot: 2});
  assert.deepEqual(b.last('stall_refuse'), {t: 'stall_refuse', from: '1', lot: 2});
  s.send({t: 'stall_refuse', to: '2', lot: 2});
  assert.equal(b.frames('stall_refuse').length, 1, 'only an open purchase is refused');
  // Buying from a player without a stall.
  b.send({t: 'stall_buy', seller: '3', lot: 1, price: 5});
  assert.equal(b.last('error').code, 'no_stall');
  // An open purchase is refused when the seller drops, and viewers see the stall close.
  b.send({t: 'stall_buy', seller: '1', lot: 2, price: 9000});
  b.clear();
  s.close();
  assert.deepEqual(b.last('stall_refuse'), {t: 'stall_refuse', from: '1', lot: 2});
  assert.deepEqual(b.last('stall'), {t: 'stall', seller: '1', lots: []});
});

test('rate limit: at most 30 frames a second, the rest dropped silently', () => {
  const {room, clock, connect} = world();
  const a = connect('1').hello();
  const b = connect('2').hello();
  clock.t = Math.ceil(clock.t / 1000) * 1000 + 1000;
  b.clear();
  for (let i = 0; i < 50; i++) room.message(a.key, JSON.stringify({t: 'chat', ch: 'world', text: `m${i}`}));
  assert.equal(b.frames('chat').length, 30);
  assert.equal(a.frames('error').length, 0, 'silently');
  clock.t += 1000;
  room.message(a.key, JSON.stringify({t: 'chat', ch: 'world', text: 'next second'}));
  assert.equal(b.last('chat').text, 'next second');
});

test('a frame over 8 KB is refused; bad JSON and unknown types are ignored', () => {
  const {connect} = world();
  const a = connect('1').hello();
  const b = connect('2').hello();
  b.clear();
  a.send({t: 'chat', ch: 'world', text: 'ก'.repeat(3000)});    // 9 KB in UTF-8
  assert.equal(a.last('error').code, 'too_large');
  assert.equal(b.frames('chat').length, 0);
  a.send('{not json');
  a.send({t: 'teleport_everyone'});
  a.send([1, 2, 3]);
  assert.equal(b.frames().length, 0);
  a.send({t: 'chat', ch: 'world', text: 'ok'});
  assert.equal(b.last('chat').text, 'ok');
});

test('a second socket of the same account kicks the first and keeps the party', () => {
  const {connect} = world();
  const a = connect('1').hello();
  const b = connect('2').hello();
  const c = connect('3').hello();
  partyUp(a, b);
  a.send({t: 'trade_req', to: '3'});
  c.send({t: 'trade_answer', from: '1', ok: true});
  clearAll(b, c);
  const a2 = connect('1');
  assert.deepEqual(a.last('kicked'), {t: 'kicked', reason: 'elsewhere'});
  assert.deepEqual(a.socket.closed, {code: CLOSE_ELSEWHERE, reason: 'elsewhere'});
  assert.equal(b.frames('leave').length, 0, 'still online');
  assert.deepEqual(c.last('trade_cancel'), {t: 'trade_cancel', from: '1'});
  const welcome = a2.last('welcome');
  assert.equal(welcome.party.leader, '1');
  assert.deepEqual(a2.last('host'), {t: 'host', zone: 'meadow', id: '1'});
  // The old socket is dead: its frames and its late close do nothing.
  a.send({t: 'chat', ch: 'world', text: 'ghost'});
  assert.equal(b.frames('chat').length, 0);
  a.close();
  assert.equal(b.frames('leave').length, 0);
  a2.hello();
  assert.equal(b.last('join').player.id, '1');
  a2.send({t: 'chat', ch: 'party', text: 'back'});
  assert.equal(b.last('chat').text, 'back');
});

test('sockets silent for 30 s are dropped', () => {
  const {room, clock, connect} = world();
  const a = connect('1').hello();
  const b = connect('2').hello();
  clock.t += 20_000;
  b.send({t: 'state', zone: 'meadow'});
  clock.t += 15_000;
  room.tick();
  assert.deepEqual(a.socket.closed, {code: CLOSE_IDLE, reason: 'idle'});
  assert.equal(b.socket.closed, null);
  assert.deepEqual(b.last('leave'), {t: 'leave', id: '1'});
  assert.equal(room.count, 1);
});

test('export / restore keeps players, parties, hosts and stalls across a wake-up', () => {
  const {room, connect} = world();
  const a = connect('1').hello();
  const b = connect('2').hello();
  const c = connect('3').hello();
  partyUp(a, b);
  partyUp(a, c);
  c.send({t: 'stall_list', lots: [{lot: 1, item: {id: 'x'}, price: 5}]});
  room.takeDirty();
  const records = [a, b].map(x => JSON.parse(JSON.stringify(room.exportSession(x.key))));
  // c's socket did not survive the sleep.
  const fresh = new Room();
  const sa = fakeSocket(), sb = fakeSocket();
  fresh.restore(a.key, sa, records[0]);
  fresh.restore(b.key, sb, records[1]);
  fresh.finishRestore();
  const back = sa.sent.find(f => f.t === 'party').party;
  assert.deepEqual(back.members, ['1', '2', '3'], 'c keeps its place for the grace');
  assert.deepEqual(back.away, ['3'], 'c is away until it reconnects');
  assert.equal(sa.sent.filter(f => f.t === 'host').length, 0, 'host unchanged: nothing resent');
  fresh.message(b.key, JSON.stringify({t: 'chat', ch: 'party', text: 'still here'}));
  assert.equal(sa.sent.at(-1).text, 'still here');
  assert.equal(sa.sent.at(-1).name, 'Hero 2');
  fresh.message(a.key, JSON.stringify({t: 'ent_snap', zone: 'meadow', ents: []}));
  assert.equal(sb.sent.at(-1).t, 'ent_snap');
  fresh.message(b.key, JSON.stringify({t: 'who'}));
  assert.deepEqual(sb.sent.at(-1).players.map(p => p.id), ['1']);
});

// ------------------------------------------------------------------ Durable Object wrapper

function fakeWs() {
  return {
    sent: [], closed: null, attachment: null,
    send(text) {this.sent.push(JSON.parse(text));},
    close(code, reason) {this.closed = {code, reason};},
    serializeAttachment(value) {
      const text = JSON.stringify(value);
      if (new TextEncoder().encode(text).length > 2048) throw new Error('attachment too large');
      this.attachment = text;
    },
    deserializeAttachment() {return this.attachment === null ? null : JSON.parse(this.attachment);},
  };
}

function fakeCtx() {
  return {
    sockets: [], alarm: null,
    acceptWebSocket(ws) {this.sockets.push(ws);},
    getWebSockets() {return this.sockets.filter(ws => !ws.closed);},
    storage: {
      alarm: null,
      async getAlarm() {return this.alarm;},
      async setAlarm(at) {this.alarm = at;},
    },
  };
}

test('WorldRoom: hibernation-safe attachments, wake-up rebuild, close, status', async () => {
  const ctx = fakeCtx();
  const dobj = new WorldRoom(ctx, {});
  const wa = fakeWs(), wb = fakeWs();
  ctx.acceptWebSocket(wa);
  dobj.accept(wa, '1', 'alice');
  ctx.acceptWebSocket(wb);
  dobj.accept(wb, '2', 'bob');
  const hello = name => JSON.stringify({t: 'hello', name, cls: 'mage', level: 5, stars: 0, look: {class: 'mage', big: 'x'.repeat(3000)}, zone: 'meadow', pos: [0, 0, 0], yaw: 0, hp: 1, max_hp: 1, mount: ''});
  await dobj.webSocketMessage(wa, hello('Alice'));
  await dobj.webSocketMessage(wb, hello('Bob'));
  await dobj.webSocketMessage(wa, JSON.stringify({t: 'party_invite', to: '2'}));
  await dobj.webSocketMessage(wb, JSON.stringify({t: 'party_answer', from: '1', ok: true}));
  assert.equal(wa.deserializeAttachment().party.members.length, 2);
  assert.deepEqual(wa.deserializeAttachment().p.look, {}, 'a look too big for the attachment is left out');
  assert.equal((await (await dobj.fetch(new Request('https://world/status'))).json()).online, 2);
  // Wake up: a new object over the same sockets.
  const woke = new WorldRoom(ctx, {});
  assert.equal(woke.room.count, 2);
  await woke.webSocketMessage(wa, JSON.stringify({t: 'chat', ch: 'party', text: 'hi again'}));
  assert.equal(wb.sent.at(-1).text, 'hi again');
  assert.equal(wb.sent.at(-1).from, '1');
  assert.equal(wb.sent.at(-1).user, 'alice');
  await woke.webSocketClose(wa, 1001, 'bye');
  assert.deepEqual(wb.sent.find(f => f.t === 'leave'), {t: 'leave', id: '1'});
  assert.deepEqual(wb.sent.filter(f => f.t === 'party').at(-1).party.away, ['1'], 'a dropped member is away, not out');
  assert.deepEqual(wb.sent.filter(f => f.t === 'host').at(-1), {t: 'host', zone: 'meadow', id: null});
  assert.deepEqual(wb.sent.at(-1), {t: 'whost', id: '2'}, 'the world host left: bob has been online the longest now');
  assert.equal(wb.deserializeAttachment().wh, '2', 'the attachment remembers the world host sent');
  assert.equal(woke.room.count, 1);
  const upgrade = await woke.fetch(new Request('https://world/api/online/ws'));
  assert.equal(upgrade.status, 426);
  await woke.alarm();
  assert.ok(ctx.storage.alarm > 0, 'the alarm keeps ticking while someone is online');
});

test('fitAttachment stays under 2 KB', () => {
  const record = {k: 'k', id: '1', user: 'u', at: 1, p: {look: {a: 'x'.repeat(5000)}, name: 'n'}, party: null, host: {zone: 'a', id: null}, stall: [{lot: 1, item: {d: 'y'.repeat(5000)}, price: 1}]};
  const fitted = fitAttachment(record);
  assert.ok(JSON.stringify(fitted).length <= 2000);
  assert.equal(fitted.p.name, 'n');
  assert.equal(fitted.stall, null);
});

// ------------------------------------------------------------------ Worker routes

const ORIGIN = 'https://toon-tale.example';

function fakeNamespace() {
  const calls = [];
  return {
    calls,
    idFromName(name) {return `id:${name}`;},
    get(id) {
      return {async fetch(input) {
        const request = typeof input === 'string' ? new Request(input) : input;
        calls.push({id, url: request.url, headers: Object.fromEntries(request.headers)});
        if (new URL(request.url).pathname === '/status') return Response.json({online: 3});
        return new Response('forwarded', {status: 200});
      }};
    },
  };
}

test('worker: /api/online/status, 426 without upgrade, 401 without a session, forwards with the account', async t => {
  const DB = new D1Sqlite();
  t.after(() => DB.close());
  const WORLD = fakeNamespace();
  const env = {DB, WORLD};
  let response = await worker.fetch(new Request(`${ORIGIN}/api/online/status`), env);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {online: 3});
  response = await worker.fetch(new Request(`${ORIGIN}/api/online/ws`), env);
  assert.equal(response.status, 426);
  const ws = {upgrade: 'websocket', connection: 'Upgrade'};
  response = await worker.fetch(new Request(`${ORIGIN}/api/online/ws`, {headers: ws}), env);
  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, 'not_authenticated');
  const register = await handleAccountRequest(new Request(`${ORIGIN}/api/account/register`, {
    method: 'POST', headers: {'content-type': 'application/json', origin: ORIGIN, 'cf-connecting-ip': '203.0.113.7'},
    body: JSON.stringify({username: 'onlinehero', password: 'CuteDragonPass2026!'}),
  }), {DB});
  assert.equal(register.status, 201);
  const cookie = register.headers.get('set-cookie').split(';')[0];
  const userId = (await register.json()).user.id;
  response = await worker.fetch(new Request(`${ORIGIN}/api/online/ws`, {headers: {...ws, cookie, origin: 'https://evil.example'}}), env);
  assert.equal(response.status, 403);
  response = await worker.fetch(new Request(`${ORIGIN}/api/online/ws`, {headers: {...ws, cookie, origin: ORIGIN, 'x-toon-user-id': 'spoof', 'x-toon-username': 'spoof'}}), env);
  assert.equal(response.status, 200);
  const forwarded = WORLD.calls.at(-1);
  assert.equal(forwarded.id, 'id:world');
  assert.equal(forwarded.headers['x-toon-user-id'], userId);
  assert.equal(forwarded.headers['x-toon-username'], 'onlinehero');
  assert.equal(forwarded.headers.upgrade, 'websocket');
  assert.equal(forwarded.headers.cookie, undefined, 'the session cookie stays at the Worker');
  response = await worker.fetch(new Request(`${ORIGIN}/api/online/status`), {DB});
  assert.equal(response.status, 503, 'no WORLD binding');
});

test('WorldRoom: parties outlive a restart (storage) and members rejoin on reconnect', async () => {
  const store = new Map();
  const pending = [];
  const ctxWith = () => ({
    ...fakeCtx(),
    storage: {
      alarm: null,
      async getAlarm() {return this.alarm;},
      async setAlarm(at) {this.alarm = at;},
      async get(k) {return store.get(k);},
      async put(k, v) {store.set(k, JSON.parse(JSON.stringify(v)));},
    },
    blockConcurrencyWhile(fn) {const p = fn(); pending.push(p); return p;},
  });
  const ctx = ctxWith();
  const dobj = new WorldRoom(ctx, {});
  await Promise.all(pending);
  const wa = fakeWs(), wb = fakeWs();
  ctx.acceptWebSocket(wa);
  dobj.accept(wa, '1', 'alice');
  ctx.acceptWebSocket(wb);
  dobj.accept(wb, '2', 'bob');
  const hello = name => JSON.stringify({t: 'hello', name, cls: 'mage', level: 5, stars: 0, look: {}, zone: 'meadow', pos: [0, 0, 0], yaw: 0, hp: 1, max_hp: 1, mount: ''});
  await dobj.webSocketMessage(wa, hello('Alice'));
  await dobj.webSocketMessage(wb, hello('Bob'));
  await dobj.webSocketMessage(wa, JSON.stringify({t: 'party_invite', to: '2'}));
  await dobj.webSocketMessage(wb, JSON.stringify({t: 'party_answer', from: '1', ok: true}));
  await Promise.resolve();
  assert.deepEqual(store.get('parties')[0].members, ['1', '2'], 'the party is stored');
  // The object restarts (a deploy): every socket is gone, the storage stays.
  const ctx2 = ctxWith();
  const again = new WorldRoom(ctx2, {});
  await Promise.all(pending);
  const wa2 = fakeWs();
  ctx2.acceptWebSocket(wa2);
  again.accept(wa2, '1', 'alice');
  const welcome = wa2.sent.find(f => f.t === 'welcome');
  assert.deepEqual(welcome.party.members, ['1', '2'], 'back in the party after the restart');
  assert.deepEqual(welcome.party.away, ['2'], 'bob is away until he reconnects');
  const wb2 = fakeWs();
  ctx2.acceptWebSocket(wb2);
  again.accept(wb2, '2', 'bob');
  assert.deepEqual(wb2.sent.find(f => f.t === 'welcome').party.away, [], 'both back');
});
