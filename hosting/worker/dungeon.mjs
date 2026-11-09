/** /api/dungeon/*: the dragon tomb's weekly clear times (docs/ONLINE_PROTOCOL.md,
 * "Dragon tomb: weekly clear times").
 *
 * The mechanics dungeon (data/dungeon_data.gd) ranks the best clear time of each party
 * leader's account a week (Monday 00:00 Thai, the guild league's week numbering). A clear
 * is posted by the leader's game; the server keeps the best time per (week, leader) and
 * hands the week's list back, fastest first.
 *
 *   GET  /api/dungeon/times?week=<n>                        -> {week, times: [entry...], now}
 *   POST /api/dungeon/time  {week, leader, name, secs, classes} -> 201 {stored: true,  time}
 *                                                              -> 200 {stored: false, time} (a faster time was kept)
 *
 * entry: {leader, name, secs, classes: [4 class ids], at}. Kept in the D1 table
 * toon_dungeon_times (hosting/accounts/drizzle/0002_dungeon_times.sql); per-IP limits use
 * toon_rate_limits like the account API. No account needed. */

// Mirrors of the game's constants (data/dungeon_ranking.gd, data/dungeon_data.gd,
// data/class_data.gd); tests/dungeon.test.mjs reads the .gd files to keep them equal.
export const TZ = 7 * 3600;
export const PARTY_SIZE = 4;
export const MIN_SECS = 30;
export const MAX_SECS = 3600;
export const LEADER_MAX = 64;
export const NAME_MAX = 32;
export const TOP = 50;
export const CLASSES = ['vagabond', 'warrior', 'archer', 'mage', 'priest', 'summoner', 'lancer', 'defender', 'assassin', 'darklord', 'bard'];
/** The first week anyone could clear (the world opened, WorldPlayers.START_UNIX). */
export const START_UNIX = 1793274300;
export const MAX_BODY_BYTES = 2048;
/** Per IP: [at most, window seconds]. */
export const LIMITS = {
  dungeon_get: [120, 600],
  dungeon_post: [60, 600],
};

const DAY = 86400;
const JSON_HEADERS = {'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store'};
const ENCODER = new TextEncoder();

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), {status, headers: {...JSON_HEADERS, ...extra}});
}

function failure(status, code, message, extra = {}) {
  return json({error: {code, message}}, status, extra);
}

async function sha256(value) {
  const digest = await crypto.subtle.digest('SHA-256', ENCODER.encode(value));
  return [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('');
}

function isInt(v, lo, hi) {
  return typeof v === 'number' && Number.isInteger(v) && v >= lo && v <= hi;
}

/** The week (GuildLeague.week_of) of unix `t`: weeks from Monday 00:00 Thai. */
export function weekOf(t) {
  return Math.floor((Math.floor((t + TZ) / DAY) + 3) / 7);
}

export function firstWeek() {
  return weekOf(START_UNIX);
}

/** A clean copy of a posted time, or a reason string when it is malformed. */
export function cleanTime(body, now) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'send an object';
  for (const key of Object.keys(body)) if (!['week', 'leader', 'name', 'secs', 'classes', 'at'].includes(key)) return `unknown key ${key}`;
  if (!isInt(body.week, firstWeek(), weekOf(now) + 1)) return 'week out of range';
  if (typeof body.leader !== 'string') return 'leader must be text';
  const leader = body.leader.trim();
  if (leader.length < 1 || leader.length > LEADER_MAX) return 'leader is too short or too long';
  const name = typeof body.name === 'string' ? body.name.trim().slice(0, NAME_MAX) : '';
  if (!isInt(body.secs, MIN_SECS, MAX_SECS)) return 'secs out of range';
  if (!Array.isArray(body.classes) || body.classes.length !== PARTY_SIZE) return `classes needs ${PARTY_SIZE} entries`;
  if (!body.classes.every(c => CLASSES.includes(c))) return 'unknown class';
  return {week: body.week, leader, name, secs: body.secs, classes: [...body.classes], at: now};
}

/** Counts one call of `action` from the request's IP; a Response (429) when over the limit. */
async function limited(request, env, action, now) {
  const [limit, seconds] = LIMITS[action];
  // CF-Connecting-IP is set by Cloudflare; never trust X-Forwarded-For.
  const ip = request.headers.get('cf-connecting-ip') ?? 'unknown-platform-ip';
  const window = Math.floor(now / seconds);
  const bucket = `${action}:${window}:${await sha256(`ip:${ip}`)}`;
  const result = await env.DB.batch([
    env.DB.prepare(`INSERT INTO toon_rate_limits (bucket, count, expires_at)
      VALUES (?, 1, ?) ON CONFLICT(bucket) DO UPDATE SET count = MIN(count + 1, 1000000)
      RETURNING count`).bind(bucket, (window + 1) * seconds),
    env.DB.prepare('DELETE FROM toon_rate_limits WHERE bucket IN (SELECT bucket FROM toon_rate_limits WHERE expires_at <= ? LIMIT 100)').bind(now),
  ]);
  if (result[0].results[0].count > limit) {
    const retryAfter = (window + 1) * seconds - now;
    return failure(429, 'too_many_requests', 'Too many requests. Please try again later.', {'retry-after': String(retryAfter)});
  }
  return null;
}

function rowOf(row) {
  if (!row) return null;
  try {
    return {leader: String(row.leader), name: String(row.name ?? ''), secs: Number(row.secs), classes: JSON.parse(row.classes), at: Number(row.at)};
  } catch {
    return null;
  }
}

async function getTimes(request, env, url, now) {
  const week = Number(url.searchParams.get('week'));
  if (!isInt(week, firstWeek(), weekOf(now) + 1)) return failure(400, 'invalid_week', 'week must be a week number of the dungeon.');
  const busy = await limited(request, env, 'dungeon_get', now);
  if (busy) return busy;
  const rows = await env.DB.prepare('SELECT leader, name, secs, classes, at FROM toon_dungeon_times WHERE week = ? ORDER BY secs, at LIMIT ?').bind(week, TOP).all();
  const times = (rows.results ?? []).map(rowOf).filter(Boolean);
  return json({week, times, now});
}

async function postTime(request, env, now) {
  if ((request.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase() !== 'application/json') {
    return failure(415, 'unsupported_media_type', 'Send JSON.');
  }
  const declared = Number(request.headers.get('content-length') ?? 0);
  if (declared > MAX_BODY_BYTES) return failure(413, 'too_large', 'The time is too large.');
  const busy = await limited(request, env, 'dungeon_post', now);
  if (busy) return busy;
  let body;
  try {
    const text = await request.text();
    if (ENCODER.encode(text).byteLength > MAX_BODY_BYTES) return failure(413, 'too_large', 'The time is too large.');
    body = JSON.parse(text);
  } catch {
    return failure(400, 'invalid_json', 'The body is not JSON.');
  }
  const time = cleanTime(body, now);
  if (typeof time === 'string') return failure(400, 'invalid_time', time);
  // The best time wins: a slower post changes nothing, and the stored one comes back.
  const [upsert, read] = await env.DB.batch([
    env.DB.prepare(`INSERT INTO toon_dungeon_times (week, leader, name, secs, classes, at) VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(week, leader) DO UPDATE SET name = excluded.name, secs = excluded.secs, classes = excluded.classes, at = excluded.at
      WHERE excluded.secs < toon_dungeon_times.secs`).bind(time.week, time.leader, time.name, time.secs, JSON.stringify(time.classes), now),
    env.DB.prepare('SELECT leader, name, secs, classes, at FROM toon_dungeon_times WHERE week = ? AND leader = ?').bind(time.week, time.leader),
  ]);
  const stored = Number(upsert.meta?.changes ?? 0) > 0;
  return json({stored, time: rowOf(read.results[0])}, stored ? 201 : 200);
}

export async function handleDungeonRequest(request, env, {now = Math.floor(Date.now() / 1000)} = {}) {
  const url = new URL(request.url);
  if (!env?.DB) return failure(503, 'dungeon_unavailable', 'The dungeon ranking is temporarily unavailable.');
  try {
    if (url.pathname === '/api/dungeon/times') {
      if (request.method !== 'GET') return failure(405, 'method_not_allowed', 'Use GET.');
      return await getTimes(request, env, url, now);
    }
    if (url.pathname === '/api/dungeon/time') {
      if (request.method !== 'POST') return failure(405, 'method_not_allowed', 'Use POST.');
      // Browsers send Origin on a POST; another site's page may not write times.
      const origin = request.headers.get('origin');
      if (origin && origin !== url.origin) return failure(403, 'invalid_origin', 'This request must come from the game website.');
      return await postTime(request, env, now);
    }
  } catch {
    return failure(503, 'dungeon_unavailable', 'The dungeon ranking is temporarily unavailable.');
  }
  return failure(404, 'not_found', 'Endpoint not found.');
}
