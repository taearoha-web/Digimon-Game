/** The online world of Toon Tale (docs/ONLINE_PROTOCOL.md), without any Cloudflare API so
 * plain node can test it. hosting/worker/online/world_room.mjs wraps it in the Durable
 * Object `WorldRoom`.
 *
 * A connection is a `key` (unique per socket) plus a socket object with send(text) and
 * close(code, reason). The account (`id`, `user`) comes from the Worker's session check;
 * every `from` / `user` / `id` the room sends out is taken from the connection, never
 * from the frame. The room keeps who is online, their last hello / state / look, the
 * parties and their zone hosts, trades, duels, guild-war invites and the players' stalls.
 *
 * Persistence: the wrapper reads `takeDirty()` after each call and stores
 * `exportSession(key)` with the socket (hibernation); `restore()` + `finishRestore()`
 * rebuild the room from those records when the object wakes up. */

export const MAX_FRAME_BYTES = 8192;
export const FRAMES_PER_SECOND = 30;
export const IDLE_MS = 30_000;
export const CHAT_MAX = 120;
export const NAME_MAX = 16;
export const PARTY_MAX = 5;
export const ASK_MS = 60_000;          // party invites, trade and duel requests stay valid this long
export const VIEW_MS = 5 * 60_000;     // a stall viewer gets pushed updates this long
export const BUY_MS = 60_000;          // a stall purchase waits this long for the seller
const MAX_LOTS = 40;
const MAX_TRADE_ITEMS = 30;
const MAX_GOLD = 1_000_000_000_000;
const TICK_EVERY_MS = 5_000;

export const CLOSE_ELSEWHERE = 4000;
export const CLOSE_IDLE = 4001;

const ERRORS = {
  not_online: 'ผู้เล่นคนนี้ไม่ได้ออนไลน์อยู่',
  self: 'ทำกับตัวเองไม่ได้',
  no_party: 'ยังไม่ได้อยู่ในปาร์ตี้',
  party_full: `ปาร์ตี้เต็มแล้ว (${PARTY_MAX} คน)`,
  in_party: 'ผู้เล่นคนนี้อยู่ในปาร์ตี้อื่นอยู่แล้ว',
  same_party: 'ผู้เล่นคนนี้อยู่ในปาร์ตี้เดียวกันแล้ว',
  not_leader: 'เฉพาะหัวหน้าปาร์ตี้เท่านั้น',
  no_invite: 'คำเชิญหมดอายุแล้ว',
  no_request: 'คำขอหมดอายุแล้ว',
  busy: 'ผู้เล่นคนนี้กำลังเทรดหรือดวลอยู่',
  no_trade: 'ไม่ได้เทรดอยู่',
  not_locked: 'ต้องล็อกทั้งสองฝ่ายก่อนยืนยัน',
  no_duel: 'ไม่ได้ดวลกับผู้เล่นคนนี้',
  no_stall: 'ผู้เล่นคนนี้ไม่ได้เปิดแผงขายของ',
  too_large: 'ข้อมูลใหญ่เกินไป',
};

const dict = value => value !== null && typeof value === 'object' && !Array.isArray(value);

/** A string without control characters, trimmed, at most `max` characters. */
function str(value, max) {
  if (typeof value !== 'string') return '';
  // eslint-disable-next-line no-control-regex
  return [...value.replace(/[\u0000-\u001f\u007f]/g, ' ').trim()].slice(0, max).join('');
}

const finite = value => typeof value === 'number' && Number.isFinite(value);

function int(value, min, max, fallback) {
  return Number.isInteger(value) && value >= min && value <= max ? value : fallback;
}

function vec3(value) {
  return Array.isArray(value) && value.length === 3 && value.every(finite) ? value.slice() : null;
}

/** An id the client names (a player id, a lot): a short string or an integer. */
function ref(value) {
  if (typeof value === 'string') return str(value, 64);
  if (Number.isSafeInteger(value)) return value;
  return null;
}

const idOf = value => (typeof value === 'string' ? str(value, 64) : Number.isSafeInteger(value) ? String(value) : '');

function frameTooLarge(text) {
  if (text.length > MAX_FRAME_BYTES) return true;          // every UTF-16 unit is >= 1 UTF-8 byte
  if (text.length * 3 <= MAX_FRAME_BYTES) return false;    // and at most 3
  return new TextEncoder().encode(text).length > MAX_FRAME_BYTES;
}

function randomId() {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
}

export class Room {
  constructor({now = () => Date.now()} = {}) {
    this.now = now;
    this.byKey = new Map();      // key -> session
    this.byId = new Map();       // account id -> session
    this.parties = new Map();    // party id -> {id, leader, members:[id], gw}
    this.invites = new Map();    // target id -> Map(from id -> time)   party invites
    this.tradeAsks = new Map();  // target id -> Map(from id -> time)
    this.duelAsks = new Map();   // target id -> Map(from id -> time)
    this.trades = new Map();     // id -> trade (both sides point at the same object)
    this.duels = new Map();      // id -> opponent id
    this.stalls = new Map();     // seller id -> lots
    this.viewers = new Map();    // seller id -> Map(viewer id -> time)
    this.buys = new Map();       // seller id -> Map(buyer + lot -> {buyer, lot, price, at})
    this.dirty = new Set();      // keys whose exported record changed
    this.seq = 0;
    this.lastTick = 0;
  }

  /** Connected sockets (one per account). */
  get count() {return this.byKey.size;}

  // ---------------------------------------------------------------- connections

  connect(key, socket, {id, user}) {
    id = String(id);
    const old = this.byId.get(id);
    const session = {
      key, socket, id, user: String(user), at: this.now(), lastSeen: this.now(), rate: {sec: -1, count: 0},
      player: null, partyId: null, zoneSeq: 0, sentHost: {zone: null, id: null},
    };
    if (old) {
      // Same account on a new socket: the old one is told and closed; the player keeps
      // its place, party and stall, but trades, duels and purchases in flight end.
      this.send(old, {t: 'kicked', reason: 'elsewhere'});
      this.endActivities(old);
      this.byKey.delete(old.key);
      this.dirty.delete(old.key);
      try {old.socket.close(CLOSE_ELSEWHERE, 'elsewhere');} catch {}
      Object.assign(session, {player: old.player, partyId: old.partyId, zoneSeq: old.zoneSeq});
    }
    this.byKey.set(key, session);
    this.byId.set(id, session);
    this.dirty.add(key);
    this.send(session, {t: 'welcome', you: {id, user: session.user}, players: this.playerList(id), party: this.partyView(session.partyId)});
    if (old) this.syncHosts();
    return session;
  }

  /** The socket closed (or errored): everything the player had going ends. */
  close(key) {
    const session = this.byKey.get(key);
    if (session) this.drop(session);
  }

  /** Drops sockets silent for IDLE_MS. Called by the wrapper's alarm and on traffic. */
  tick() {
    const now = this.now();
    this.lastTick = now;
    let dropped = 0;
    for (const session of [...this.byKey.values()]) {
      if (now - session.lastSeen <= IDLE_MS) continue;
      try {session.socket.close(CLOSE_IDLE, 'idle');} catch {}
      this.drop(session);
      dropped++;
    }
    this.prune(now);
    return dropped;
  }

  /** Keys whose record (exportSession) changed since the last call. */
  takeDirty() {
    const keys = [...this.dirty].filter(key => this.byKey.has(key));
    this.dirty.clear();
    return keys;
  }

  /** What must survive hibernation for one connection (JSON-able). */
  exportSession(key) {
    const s = this.byKey.get(key);
    if (!s) return null;
    const party = this.parties.get(s.partyId);
    return {
      k: s.key, id: s.id, user: s.user, at: s.at, p: s.player, zs: s.zoneSeq, host: s.sentHost,
      party: party ? {id: party.id, leader: party.leader, members: party.members.slice()} : null,
      stall: this.stalls.get(s.id) ?? null,
    };
  }

  /** Rebuilds one connection from its record after a wake-up (no frames are sent). */
  restore(key, socket, record) {
    const id = String(record.id);
    const old = this.byId.get(id);
    if (old) {
      // Two sockets of one account (the old one was closing): the newer wins.
      if ((old.at ?? 0) > (record.at ?? 0)) {try {socket.close(CLOSE_ELSEWHERE, 'elsewhere');} catch {} return;}
      this.byKey.delete(old.key);
      try {old.socket.close(CLOSE_ELSEWHERE, 'elsewhere');} catch {}
    }
    const now = this.now();
    const session = {
      key, socket, id, user: String(record.user ?? ''), at: record.at ?? now, lastSeen: now, rate: {sec: -1, count: 0},
      player: dict(record.p) ? {...record.p, id, user: String(record.user ?? '')} : null,
      partyId: null, zoneSeq: Number(record.zs) || 0,
      sentHost: dict(record.host) ? {zone: record.host.zone ?? null, id: record.host.id ?? null} : {zone: null, id: null},
    };
    this.seq = Math.max(this.seq, session.zoneSeq);
    if (dict(record.party) && typeof record.party.id === 'string' && Array.isArray(record.party.members)) {
      session.partyId = record.party.id;
      if (!this.parties.has(record.party.id)) {
        this.parties.set(record.party.id, {id: record.party.id, leader: String(record.party.leader), members: record.party.members.map(String), gw: null});
      }
    }
    if (Array.isArray(record.stall)) this.stalls.set(id, record.stall);
    this.byKey.set(key, session);
    this.byId.set(id, session);
  }

  /** After every restore(): parties keep only members that came back, then hosts are checked. */
  finishRestore() {
    for (const party of [...this.parties.values()]) {
      const before = party.members.join();
      party.members = party.members.filter(id => this.byId.get(id)?.partyId === party.id);
      if (party.members.length < 2) {this.dissolve(party); continue;}
      if (!party.members.includes(party.leader)) party.leader = party.members[0];
      for (const id of party.members) {
        const s = this.byId.get(id);
        if (s.player) s.player.party = party.id;
      }
      if (party.members.join() !== before) this.sendParty(party);
    }
    for (const s of this.byKey.values()) if (s.player && !s.partyId) s.player.party = null;
    this.syncHosts();
  }

  // ---------------------------------------------------------------- frames

  message(key, text) {
    const s = this.byKey.get(key);
    if (!s) return;
    const now = this.now();
    s.lastSeen = now;
    if (now - this.lastTick >= TICK_EVERY_MS) this.tick();
    if (!this.byKey.has(key)) return;
    const sec = Math.floor(now / 1000);
    if (s.rate.sec !== sec) {s.rate.sec = sec; s.rate.count = 0;}
    if (++s.rate.count > FRAMES_PER_SECOND) return;
    if (typeof text !== 'string') return;
    if (frameTooLarge(text)) {this.error(s, 'too_large'); return;}
    let msg;
    try {msg = JSON.parse(text);} catch {return;}
    if (!dict(msg) || typeof msg.t !== 'string' || !Object.hasOwn(HANDLERS, msg.t)) return;
    if (!s.player && msg.t !== 'hello' && msg.t !== 'who') return;
    HANDLERS[msg.t].call(this, s, msg);
  }

  // ---------------------------------------------------------------- helpers

  send(s, obj) {
    if (!s) return;
    try {s.socket.send(typeof obj === 'string' ? obj : JSON.stringify(obj));} catch {}
  }

  sendTo(id, obj) {this.send(this.byId.get(id), obj);}

  broadcast(obj, exceptId = null) {
    const text = JSON.stringify(obj);
    for (const s of this.byKey.values()) if (s.id !== exceptId) this.send(s, text);
  }

  error(s, code) {this.send(s, {t: 'error', code, text: ERRORS[code] ?? code});}

  /** Online, has said hello, and is not me. Sends the error otherwise. */
  target(s, id) {
    if (!id) return null;
    if (id === s.id) {this.error(s, 'self'); return null;}
    const other = this.byId.get(id);
    if (!other?.player) {this.error(s, 'not_online'); return null;}
    return other;
  }

  playerList(exceptId) {
    const list = [];
    for (const s of this.byKey.values()) if (s.player && s.id !== exceptId) list.push(s.player);
    return list;
  }

  partyView(partyId) {
    const party = this.parties.get(partyId);
    return party ? {id: party.id, leader: party.leader, members: party.members.slice()} : null;
  }

  sendParty(party) {
    const text = JSON.stringify({t: 'party', party: this.partyView(party.id)});
    for (const id of party.members) {
      const s = this.byId.get(id);
      this.send(s, text);
      if (s) this.dirty.add(s.key);
    }
  }

  setParty(s, partyId) {
    s.partyId = partyId;
    if (s.player) s.player.party = partyId;
    this.dirty.add(s.key);
  }

  dissolve(party) {
    this.parties.delete(party.id);
    for (const id of party.members) {
      const s = this.byId.get(id);
      if (s && s.partyId === party.id) {
        this.setParty(s, null);
        this.send(s, {t: 'party', party: null});
      }
    }
  }

  /** Removes a member; the next member leads when the leader goes; a party of one ends. */
  removeFromParty(s) {
    const party = this.parties.get(s.partyId);
    this.setParty(s, null);
    if (!party) return;
    party.members = party.members.filter(id => id !== s.id);
    party.gw?.accepted.delete(s.id);
    this.send(s, {t: 'party', party: null});
    if (party.members.length < 2) {this.dissolve(party); return;}
    if (party.leader === s.id) {party.leader = party.members[0]; party.gw = null;}
    this.sendParty(party);
  }

  /** Who simulates the shared entities of this player's party in its zone: the leader if
   * it is there, else the member who arrived first; null with no party or alone there. */
  hostFor(s) {
    const party = this.parties.get(s.partyId);
    const zone = s.player?.zone;
    if (!party || !zone) return null;
    const here = this.membersInZone(party, zone);
    if (here.length < 2) return null;
    if (here.some(m => m.id === party.leader)) return party.leader;
    return here.reduce((a, b) => (b.zoneSeq < a.zoneSeq ? b : a)).id;
  }

  membersInZone(party, zone) {
    const here = [];
    for (const id of party.members) {
      const m = this.byId.get(id);
      if (m?.player && m.player.zone === zone) here.push(m);
    }
    return here;
  }

  /** Sends `host` to every player whose zone host changed (or who changed zone in a party). */
  syncHosts() {
    for (const s of this.byKey.values()) {
      if (!s.player) continue;
      const id = this.hostFor(s);
      const zone = s.player.zone;
      const sent = s.sentHost;
      if (sent.id === id && (sent.zone === zone || (!s.partyId && id === null))) continue;
      s.sentHost = {zone, id};
      this.dirty.add(s.key);
      this.send(s, {t: 'host', zone, id});
    }
  }

  ask(map, to, from) {
    if (!map.has(to)) map.set(to, new Map());
    map.get(to).set(from, this.now());
  }

  /** Takes a pending ask from `from` to `to`; false when there is none or it expired. */
  takeAsk(map, to, from) {
    const asks = map.get(to);
    const at = asks?.get(from);
    if (at === undefined) return false;
    asks.delete(from);
    if (!asks.size) map.delete(to);
    return this.now() - at <= ASK_MS;
  }

  busy(id) {return this.trades.has(id) || this.duels.has(id);}

  endTrade(id, notify) {
    const trade = this.trades.get(id);
    if (!trade) return;
    this.trades.delete(trade.a);
    this.trades.delete(trade.b);
    if (notify) this.sendTo(trade.a === id ? trade.b : trade.a, {t: 'trade_cancel', from: id});
  }

  /** Trades, duels and stall purchases end when a player leaves or reconnects elsewhere. */
  endActivities(s) {
    this.endTrade(s.id, true);
    const foe = this.duels.get(s.id);
    if (foe) {
      this.duels.delete(s.id);
      this.duels.delete(foe);
      this.sendTo(foe, {t: 'duel_over', from: s.id, loser: s.id});
    }
    for (const map of [this.tradeAsks, this.duelAsks, this.invites]) {
      map.delete(s.id);
      for (const asks of map.values()) asks.delete(s.id);
    }
    const buys = this.buys.get(s.id);
    if (buys) {
      for (const buy of buys.values()) this.sendTo(buy.buyer, {t: 'stall_refuse', from: s.id, lot: buy.lot});
      this.buys.delete(s.id);
    }
    for (const sellerBuys of this.buys.values()) {
      for (const [k, buy] of sellerBuys) if (buy.buyer === s.id) sellerBuys.delete(k);
    }
  }

  drop(s) {
    if (this.byKey.get(s.key) !== s) return;
    this.byKey.delete(s.key);
    this.dirty.delete(s.key);
    if (this.byId.get(s.id) !== s) return;
    this.byId.delete(s.id);
    this.endActivities(s);
    if (s.partyId) this.removeFromParty(s);
    if (this.stalls.delete(s.id)) this.pushStall(s.id, []);
    this.viewers.delete(s.id);
    for (const views of this.viewers.values()) views.delete(s.id);
    if (s.player) this.broadcast({t: 'leave', id: s.id});
    this.syncHosts();
  }

  pushStall(sellerId, lots) {
    const views = this.viewers.get(sellerId);
    if (!views) return;
    const now = this.now();
    const text = JSON.stringify({t: 'stall', seller: sellerId, lots});
    for (const [viewer, at] of views) {
      if (now - at > VIEW_MS) {views.delete(viewer); continue;}
      this.send(this.byId.get(viewer), text);
    }
  }

  /** Forgets expired asks, viewers and purchases. */
  prune(now) {
    for (const map of [this.invites, this.tradeAsks, this.duelAsks]) {
      for (const [to, asks] of map) {
        for (const [from, at] of asks) if (now - at > ASK_MS) asks.delete(from);
        if (!asks.size) map.delete(to);
      }
    }
    for (const [seller, views] of this.viewers) {
      for (const [viewer, at] of views) if (now - at > VIEW_MS) views.delete(viewer);
      if (!views.size) this.viewers.delete(seller);
    }
    for (const [seller, buys] of this.buys) {
      for (const [k, buy] of buys) if (now - buy.at > BUY_MS) buys.delete(k);
      if (!buys.size) this.buys.delete(seller);
    }
  }

  /** Copies the state fields of a hello / state frame; true when the zone changed. */
  applyState(s, msg) {
    const p = s.player;
    const pos = vec3(msg.pos);
    if (pos) p.pos = pos;
    if (finite(msg.yaw)) p.yaw = msg.yaw;
    if (typeof msg.anim === 'string') p.anim = str(msg.anim, 48);
    if (finite(msg.hp)) p.hp = msg.hp;
    if (finite(msg.max_hp)) p.max_hp = msg.max_hp;
    if (typeof msg.mount === 'string') p.mount = str(msg.mount, 48);
    else if (typeof msg.mount === 'boolean' || msg.mount === null || finite(msg.mount)) p.mount = msg.mount;
    const zone = typeof msg.zone === 'string' ? str(msg.zone, 64) : '';
    if (zone && zone !== p.zone) {
      p.zone = zone;
      s.zoneSeq = ++this.seq;
      this.dirty.add(s.key);
      return true;
    }
    return false;
  }
}

function sanitizeLots(value) {
  if (!Array.isArray(value)) return [];
  const lots = [];
  for (const entry of value.slice(0, MAX_LOTS)) {
    if (!dict(entry) || !dict(entry.item)) continue;
    const lot = ref(entry.lot);
    const price = int(entry.price, 0, MAX_GOLD, null);
    if (lot === null || lot === '' || price === null) continue;
    lots.push({lot, item: entry.item, price});
  }
  return lots;
}

const lotKey = (buyer, lot) => `${buyer}\u0000${String(lot)}`;

/** Relays a frame with `from` set by the server (whatever the client wrote in it). */
const relay = (msg, from) => ({...msg, from});

const HANDLERS = {
  hello(s, msg) {
    const p = s.player ?? {id: s.id, user: s.user, zone: '', pos: [0, 0, 0], yaw: 0, anim: 'idle', hp: 0, max_hp: 0, mount: ''};
    p.id = s.id;
    p.user = s.user;
    p.name = str(msg.name, NAME_MAX) || s.user;
    p.cls = str(msg.cls, 24) || 'vagabond';
    p.level = int(msg.level, 1, 1000, 1);
    p.stars = int(msg.stars, 0, 100_000, 0);
    p.look = dict(msg.look) ? msg.look : {};
    p.party = s.partyId;
    s.player = p;
    this.applyState(s, msg);
    this.dirty.add(s.key);
    this.broadcast({t: 'join', player: p}, s.id);
    this.syncHosts();
  },

  state(s, msg) {
    const zoneChanged = this.applyState(s, msg);
    const p = s.player;
    this.broadcast({t: 'state', id: s.id, pos: p.pos, yaw: p.yaw, anim: p.anim, hp: p.hp, max_hp: p.max_hp, zone: p.zone, mount: p.mount}, s.id);
    if (zoneChanged) this.syncHosts();
  },

  look(s, msg) {
    const p = s.player;
    if (dict(msg.look)) p.look = msg.look;
    p.level = int(msg.level, 1, 1000, p.level);
    p.stars = int(msg.stars, 0, 100_000, p.stars);
    this.dirty.add(s.key);
    this.broadcast({t: 'look', id: s.id, look: p.look, level: p.level, stars: p.stars}, s.id);
  },

  chat(s, msg) {
    const text = str(msg.text, CHAT_MAX);
    if (!text) return;
    const line = {t: 'chat', ch: 'world', from: s.id, user: s.user, name: s.player.name, text};
    if (msg.ch === 'party') {
      const party = this.parties.get(s.partyId);
      if (!party) {this.error(s, 'no_party'); return;}
      line.ch = 'party';
      const out = JSON.stringify(line);
      for (const id of party.members) this.send(this.byId.get(id), out);
    } else if (msg.ch === 'whisper') {
      const other = this.target(s, idOf(msg.to));
      if (!other) return;
      Object.assign(line, {ch: 'whisper', to: other.id});
      this.send(s, line);
      this.send(other, line);
    } else {
      this.broadcast(line);
    }
  },

  who(s) {
    this.send(s, {t: 'players', players: this.playerList(s.id)});
  },

  party_invite(s, msg) {
    const other = this.target(s, idOf(msg.to));
    if (!other) return;
    const mine = this.parties.get(s.partyId);
    if (other.partyId && other.partyId === s.partyId) {this.error(s, 'same_party'); return;}
    if (other.partyId) {this.error(s, 'in_party'); return;}
    if (mine && mine.members.length >= PARTY_MAX) {this.error(s, 'party_full'); return;}
    this.ask(this.invites, other.id, s.id);
    this.send(other, {t: 'party_invite', from: s.id, name: s.player.name});
  },

  party_answer(s, msg) {
    const fromId = idOf(msg.from);
    if (!this.takeAsk(this.invites, s.id, fromId)) {this.error(s, 'no_invite'); return;}
    const inviter = this.byId.get(fromId);
    const ok = msg.ok === true;
    if (!inviter?.player) {if (ok) this.error(s, 'not_online'); return;}
    if (!ok) {this.send(inviter, {t: 'party_answer', from: s.id, ok: false}); return;}
    if (s.partyId) {this.error(s, 'in_party'); return;}
    let party = this.parties.get(inviter.partyId);
    if (party && party.members.length >= PARTY_MAX) {this.error(s, 'party_full'); return;}
    if (!party) {
      party = {id: randomId(), leader: inviter.id, members: [inviter.id], gw: null};
      this.parties.set(party.id, party);
      this.setParty(inviter, party.id);
    }
    party.members.push(s.id);
    this.setParty(s, party.id);
    this.send(inviter, {t: 'party_answer', from: s.id, ok: true});
    this.sendParty(party);
    this.syncHosts();
  },

  party_leave(s) {
    if (!s.partyId) return;
    this.removeFromParty(s);
    this.syncHosts();
  },

  party_kick(s, msg) {
    const party = this.parties.get(s.partyId);
    if (!party) {this.error(s, 'no_party'); return;}
    if (party.leader !== s.id) {this.error(s, 'not_leader'); return;}
    const who = idOf(msg.who);
    if (!who || who === s.id || !party.members.includes(who)) return;
    this.removeFromParty(this.byId.get(who));
    this.syncHosts();
  },

  ent_snap(s, msg) {this.relayFromHost(s, msg);},
  ent_event(s, msg) {this.relayFromHost(s, msg);},

  ent_hit(s, msg) {
    if (typeof msg.zone !== 'string' || msg.zone !== s.player.zone) return;
    const host = this.hostFor(s);
    if (host && host !== s.id) this.sendTo(host, relay(msg, s.id));
  },

  trade_req(s, msg) {
    const other = this.target(s, idOf(msg.to));
    if (!other) return;
    if (this.busy(s.id) || this.busy(other.id)) {this.error(s, 'busy'); return;}
    this.ask(this.tradeAsks, other.id, s.id);
    this.send(other, {t: 'trade_req', from: s.id});
  },

  trade_answer(s, msg) {
    const fromId = idOf(msg.from);
    if (!this.takeAsk(this.tradeAsks, s.id, fromId)) {this.error(s, 'no_request'); return;}
    const asker = this.byId.get(fromId);
    if (!asker?.player) {this.error(s, 'not_online'); return;}
    const ok = msg.ok === true;
    if (ok && (this.busy(s.id) || this.busy(asker.id))) {this.error(s, 'busy'); this.send(asker, {t: 'trade_answer', from: s.id, ok: false}); return;}
    if (ok) {
      const trade = {a: asker.id, b: s.id, offer: {}, locked: new Set(), confirmed: new Set()};
      trade.offer[asker.id] = {items: [], gold: 0};
      trade.offer[s.id] = {items: [], gold: 0};
      this.trades.set(asker.id, trade);
      this.trades.set(s.id, trade);
    }
    this.send(asker, {t: 'trade_answer', from: s.id, ok});
  },

  trade_offer(s, msg) {
    const trade = this.trades.get(s.id);
    if (!trade) {this.error(s, 'no_trade'); return;}
    const items = (Array.isArray(msg.items) ? msg.items : []).filter(dict).slice(0, MAX_TRADE_ITEMS);
    const gold = int(msg.gold, 0, MAX_GOLD, 0);
    trade.offer[s.id] = {items, gold};
    trade.locked.clear();
    trade.confirmed.clear();
    this.sendTo(trade.a === s.id ? trade.b : trade.a, {t: 'trade_offer', from: s.id, items, gold});
  },

  trade_lock(s) {
    const trade = this.trades.get(s.id);
    if (!trade) {this.error(s, 'no_trade'); return;}
    trade.locked.add(s.id);
    this.sendTo(trade.a === s.id ? trade.b : trade.a, {t: 'trade_lock', from: s.id});
  },

  trade_confirm(s) {
    const trade = this.trades.get(s.id);
    if (!trade) {this.error(s, 'no_trade'); return;}
    if (trade.locked.size < 2) {this.error(s, 'not_locked'); return;}
    trade.confirmed.add(s.id);
    const other = trade.a === s.id ? trade.b : trade.a;
    this.sendTo(other, {t: 'trade_confirm', from: s.id});
    if (trade.confirmed.size < 2) return;
    this.endTrade(s.id, false);
    const {a, b} = trade;
    this.sendTo(a, {t: 'trade_done', with: b, give: trade.offer[a], get: trade.offer[b]});
    this.sendTo(b, {t: 'trade_done', with: a, give: trade.offer[b], get: trade.offer[a]});
  },

  trade_cancel(s) {
    this.endTrade(s.id, true);
  },

  duel_req(s, msg) {
    const other = this.target(s, idOf(msg.to));
    if (!other) return;
    if (this.busy(s.id) || this.busy(other.id)) {this.error(s, 'busy'); return;}
    this.ask(this.duelAsks, other.id, s.id);
    this.send(other, {t: 'duel_req', from: s.id});
  },

  duel_answer(s, msg) {
    const fromId = idOf(msg.from);
    if (!this.takeAsk(this.duelAsks, s.id, fromId)) {this.error(s, 'no_request'); return;}
    const asker = this.byId.get(fromId);
    if (!asker?.player) {this.error(s, 'not_online'); return;}
    const ok = msg.ok === true;
    if (ok && (this.busy(s.id) || this.busy(asker.id))) {this.error(s, 'busy'); this.send(asker, {t: 'duel_answer', from: s.id, ok: false}); return;}
    if (ok) {
      this.duels.set(asker.id, s.id);
      this.duels.set(s.id, asker.id);
    }
    this.send(asker, {t: 'duel_answer', from: s.id, ok});
  },

  pvp_hit(s, msg) {
    const foe = this.duels.get(s.id);
    if (!foe || foe !== idOf(msg.to)) return;
    this.sendTo(foe, relay(msg, s.id));
  },

  duel_over(s) {
    const foe = this.duels.get(s.id);
    if (!foe) return;
    this.duels.delete(s.id);
    this.duels.delete(foe);
    this.sendTo(foe, {t: 'duel_over', from: s.id, loser: s.id});
  },

  gw_invite(s) {
    const party = this.parties.get(s.partyId);
    if (!party) {this.error(s, 'no_party'); return;}
    if (party.leader !== s.id) {this.error(s, 'not_leader'); return;}
    party.gw = {accepted: new Set()};
    const out = JSON.stringify({t: 'gw_invite', from: s.id});
    for (const id of party.members) if (id !== s.id) this.send(this.byId.get(id), out);
  },

  gw_answer(s, msg) {
    const party = this.parties.get(s.partyId);
    if (!party?.gw || party.leader === s.id) return;
    const ok = msg.ok === true;
    if (ok) party.gw.accepted.add(s.id); else party.gw.accepted.delete(s.id);
    const out = JSON.stringify({t: 'gw_answer', from: s.id, ok});
    for (const id of party.members) if (id !== s.id) this.send(this.byId.get(id), out);
  },

  gw_start(s, msg) {
    const party = this.parties.get(s.partyId);
    if (!party?.gw || party.leader !== s.id) return;
    const out = JSON.stringify(relay(msg, s.id));
    for (const id of party.gw.accepted) if (party.members.includes(id)) this.send(this.byId.get(id), out);
    party.gw = null;
  },

  stall_list(s, msg) {
    const lots = sanitizeLots(msg.lots);
    if (lots.length) this.stalls.set(s.id, lots); else this.stalls.delete(s.id);
    this.dirty.add(s.key);
    this.pushStall(s.id, lots);
  },

  stall_view(s, msg) {
    const seller = idOf(msg.seller);
    if (!seller) return;
    if (seller !== s.id) {
      if (!this.viewers.has(seller)) this.viewers.set(seller, new Map());
      this.viewers.get(seller).set(s.id, this.now());
    }
    this.send(s, {t: 'stall', seller, lots: this.stalls.get(seller) ?? []});
  },

  stall_buy(s, msg) {
    const seller = this.target(s, idOf(msg.seller));
    if (!seller) return;
    const lot = ref(msg.lot);
    const price = int(msg.price, 0, MAX_GOLD, null);
    if (lot === null || lot === '' || price === null) return;
    if (!this.stalls.has(seller.id)) {this.error(s, 'no_stall'); return;}
    if (!this.buys.has(seller.id)) this.buys.set(seller.id, new Map());
    this.buys.get(seller.id).set(lotKey(s.id, lot), {buyer: s.id, lot, price, at: this.now()});
    this.send(seller, {t: 'stall_buy', from: s.id, seller: seller.id, lot, price});
  },

  stall_sold(s, msg) {
    const buyer = idOf(msg.to);
    const lot = ref(msg.lot);
    const buys = this.buys.get(s.id);
    const k = lotKey(buyer, lot);
    const buy = buys?.get(k);
    if (!buy) return;
    buys.delete(k);
    const listed = this.stalls.get(s.id)?.find(entry => String(entry.lot) === String(lot));
    const item = dict(msg.item) ? msg.item : listed?.item ?? {};
    // The buyer pays the price it agreed to, whatever the seller writes.
    this.sendTo(buyer, {t: 'stall_bought', seller: s.id, lot: buy.lot, item, price: buy.price});
  },

  stall_refuse(s, msg) {
    const buyer = idOf(msg.to);
    const lot = ref(msg.lot);
    const buys = this.buys.get(s.id);
    if (!buys?.delete(lotKey(buyer, lot))) return;
    this.sendTo(buyer, {t: 'stall_refuse', from: s.id, lot});
  },
};

/** ent_snap / ent_event: only the zone host, only to the other party members in that zone. */
Room.prototype.relayFromHost = function relayFromHost(s, msg) {
  if (typeof msg.zone !== 'string' || msg.zone !== s.player.zone) return;
  if (this.hostFor(s) !== s.id) return;
  const out = JSON.stringify(relay(msg, s.id));
  for (const m of this.membersInZone(this.parties.get(s.partyId), msg.zone)) if (m.id !== s.id) this.send(m, out);
};
