/** The Durable Object `WorldRoom`: the one room every online player of Toon Tale is in
 * (docs/ONLINE_PROTOCOL.md). It wraps the pure room logic (room.mjs) with the WebSocket
 * Hibernation API, so an idle room costs nothing:
 *
 * - each socket is accepted with ctx.acceptWebSocket and carries an attachment
 *   (serializeAttachment) with its connection key, account and the player record the
 *   room exports (last hello / look / zone, party, host, stall), so it survives
 *   hibernation; positions come back with the next `state` frame;
 * - when the object wakes up (the constructor runs again) the room is rebuilt from
 *   ctx.getWebSockets() and their attachments;
 * - an alarm every 10 s while anyone is connected drops sockets silent for 30 s;
 * - the parties are also kept in storage (key PARTIES_KEY), so a party outlives the
 *   object restarting (a deploy, an eviction): its members are "away" until they
 *   reconnect (Room PARTY_GRACE_MS).
 *
 * A plain class (no `cloudflare:workers` import) so node can load worker.mjs and test it.
 * The Worker (worker.mjs) checks the session cookie and forwards the upgrade request with
 * x-toon-user-id / x-toon-username; nothing else reaches this object. */
import {Room} from './room.mjs';

export const ALARM_MS = 10_000;
export const PARTIES_KEY = 'parties';
// serializeAttachment holds at most 2,048 bytes.
const ATTACHMENT_BYTES = 2000;
const ENCODER = new TextEncoder();

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {status, headers: {'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store'}});
}

function socketOf(ws) {
  return {
    send(text) {ws.send(text);},
    close(code, reason) {ws.close(code, reason);},
  };
}

/** The record cut to the attachment limit: the stall goes first, then the look. */
export function fitAttachment(record) {
  const size = value => ENCODER.encode(JSON.stringify(value)).length;
  if (size(record) <= ATTACHMENT_BYTES) return record;
  const smaller = {...record, stall: null};
  if (size(smaller) <= ATTACHMENT_BYTES) return smaller;
  if (smaller.p) smaller.p = {...smaller.p, look: {}};
  if (size(smaller) <= ATTACHMENT_BYTES) return smaller;
  return {k: record.k, id: record.id, user: record.user, at: record.at, party: record.party, host: record.host};
}

export class WorldRoom {
  constructor(ctx, env, {now} = {}) {
    this.ctx = ctx;
    this.env = env;
    this.room = new Room(now ? {now} : {});
    this.sockets = new Map();   // key -> WebSocket
    this.keys = new WeakMap();  // WebSocket -> key
    if (typeof ctx.blockConcurrencyWhile === 'function' && ctx.storage?.get) {
      ctx.blockConcurrencyWhile(async () => {
        let saved = null;
        try {saved = await ctx.storage.get(PARTIES_KEY);} catch {}
        this.room.importParties(saved);
        this.wake();
      });
    } else {
      this.wake();
    }
  }

  /** Rebuilds the room from the sockets that survived (hibernation). */
  wake() {
    const ctx = this.ctx;
    for (const ws of ctx.getWebSockets()) {
      let record = null;
      try {record = ws.deserializeAttachment();} catch {}
      if (!record?.k || !record.id) {
        try {ws.close(1011, 'lost');} catch {}
        continue;
      }
      this.track(record.k, ws);
      this.room.restore(record.k, socketOf(ws), record);
    }
    this.room.finishRestore();
    this.flush();
  }

  track(key, ws) {
    this.sockets.set(key, ws);
    this.keys.set(ws, key);
  }

  keyOf(ws) {
    let key = this.keys.get(ws);
    if (key === undefined) {
      try {key = ws.deserializeAttachment()?.k;} catch {}
      if (key) this.keys.set(ws, key);
    }
    return key;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname.endsWith('/status')) return jsonResponse({online: this.room.count});
    if ((request.headers.get('upgrade') ?? '').toLowerCase() !== 'websocket') {
      return jsonResponse({error: {code: 'upgrade_required', message: 'Open a WebSocket.'}}, 426);
    }
    const id = request.headers.get('x-toon-user-id');
    const user = request.headers.get('x-toon-username');
    if (!id || !user) return jsonResponse({error: {code: 'not_authenticated', message: 'Sign in to your game account.'}}, 401);
    // eslint-disable-next-line no-undef
    const [client, server] = Object.values(new WebSocketPair());
    this.ctx.acceptWebSocket(server);
    this.accept(server, id, user);
    await this.ensureAlarm();
    return new Response(null, {status: 101, webSocket: client});
  }

  /** An accepted server-side socket joins the room. */
  accept(ws, id, user) {
    const key = crypto.randomUUID();
    ws.serializeAttachment({k: key, id, user, at: Date.now()});
    this.track(key, ws);
    this.room.connect(key, socketOf(ws), {id, user});
    this.flush();
  }

  async webSocketMessage(ws, message) {
    const key = this.keyOf(ws);
    if (!key) return;
    this.room.message(key, typeof message === 'string' ? message : null);
    this.flush();
  }

  async webSocketClose(ws, code, reason) {
    this.gone(ws);
    try {ws.close(code === 1005 || code === 1006 ? 1000 : code, reason);} catch {}
  }

  async webSocketError(ws) {
    this.gone(ws);
  }

  gone(ws) {
    const key = this.keyOf(ws);
    if (!key) return;
    this.room.close(key);
    this.sockets.delete(key);
    this.flush();
  }

  async alarm() {
    this.room.tick();
    this.flush();
    if (this.room.count || this.room.parties.size) await this.ctx.storage.setAlarm(Date.now() + ALARM_MS);
  }

  async ensureAlarm() {
    if (await this.ctx.storage.getAlarm() == null) await this.ctx.storage.setAlarm(Date.now() + ALARM_MS);
  }

  /** Stores the changed records with their sockets and forgets sockets the room closed. */
  flush() {
    for (const key of this.room.takeDirty()) {
      const ws = this.sockets.get(key);
      const record = this.room.exportSession(key);
      if (!ws || !record) continue;
      try {ws.serializeAttachment(fitAttachment(record));} catch {}
    }
    for (const key of this.sockets.keys()) if (!this.room.byKey.has(key)) this.sockets.delete(key);
    if (this.room.partiesChanged) {
      this.room.partiesChanged = false;
      try {this.ctx.storage?.put?.(PARTIES_KEY, this.room.exportParties())?.catch?.(() => {});} catch {}
    }
  }
}
