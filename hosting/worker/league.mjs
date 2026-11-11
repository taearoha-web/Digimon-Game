/** /api/league/*: the official results of the guild league's rounds
 * (docs/ONLINE_PROTOCOL.md, "Guild league: official round results").
 *
 * Every device used to work the castle's chain of holders out by itself from the world's
 * first round, so a code update that changed fighter power (or a device's own fought
 * rounds) rewrote past rounds. A round's result is now stored once, here, and every device
 * reads it back: the first result posted for an ended round wins and never changes.
 *
 *   GET  /api/league/rounds?from=<unix>&to=<unix>  -> {rounds: [{at, result}], now}
 *   POST /api/league/round  {at, result}           -> 201 {stored: true,  round}
 *                                                  -> 200 {stored: false, round} (already stored: the stored one)
 *
 * `result` is the shape GuildLeague.sim_round makes: {at, g: guilds, k: falls,
 * c: captures, held: holder at the bell (0 nobody), own: holder when it began}. Kept in
 * the D1 table toon_league_rounds (hosting/accounts/drizzle/0001_league_rounds.sql);
 * per-IP limits use toon_rate_limits like the account API. No account needed. */

// Mirrors of the game's constants (data/guild_league.gd, data/guild_war_data.gd,
// data/world_players.gd); tests/league.test.mjs reads the .gd files to keep them equal.
export const TZ = 7 * 3600;
export const SLOTS = [12 * 3600, 18 * 3600, 20 * 3600 + 30 * 60];
/** The last round moved from 21:30 to 20:30 Thai from this Thai day on (11 Nov 2026); earlier days keep 21:30 (as the game: GuildLeague.EARLY_FINAL_DAY). */
export const EARLY_FINAL_DAY = 20768;
const OLD_LAST_SLOT = 21 * 3600 + 30 * 60;
/** Seconds of Thai day `day` its round k starts. */
export function slotSecond(day, k) {
  return k === SLOTS.length - 1 && day < EARLY_FINAL_DAY ? OLD_LAST_SLOT : SLOTS[k];
}
export const DURATION = 1200;
export const START_UNIX = 1793274300;
export const GUILDS = [1, 2, 3, 4];
/** A round may be posted this many seconds before its bell (device clocks drift). */
export const END_MARGIN = 60;
/** The widest span one GET may ask for (two seasons and a margin). */
export const MAX_RANGE = 21 * 86400;
export const MAX_KILLS = 100000;
export const MAX_CAPTURES = 1000;
export const MAX_BODY_BYTES = 2048;
/** Per IP: [action, at most, window seconds]. */
export const LIMITS = {
  league_get: [120, 600],
  league_post: [120, 600],
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

/** The world's first round: the first slot starting after START_UNIX - 1. */
export function firstRound() {
  const day = Math.floor((START_UNIX - 1 + TZ) / DAY);
  for (const d of [day, day + 1]) {
    for (let k = 0; k < SLOTS.length; k++) {
      const at = d * DAY - TZ + slotSecond(d, k);
      if (at > START_UNIX - 1) return at;
    }
  }
  return 0;
}

/** True when a league round starts at unix `at` (12:00, 18:00 or 20:30 Thai; 21:30 before EARLY_FINAL_DAY). */
export function isSlot(at) {
  if (!Number.isSafeInteger(at) || at < firstRound()) return false;
  const second = ((at + TZ) % DAY + DAY) % DAY;
  const day = Math.floor((at + TZ) / DAY);
  return SLOTS.some((_, k) => slotSecond(day, k) === second);
}

/** A clean copy of a posted round result, or a reason string when it is malformed. */
export function cleanResult(at, result) {
  if (!result || typeof result !== 'object' || Array.isArray(result)) return 'result must be an object';
  const keys = Object.keys(result);
  for (const key of keys) if (!['at', 'g', 'k', 'c', 'held', 'own'].includes(key)) return `unknown key ${key}`;
  if (result.at !== at) return 'result.at must equal at';
  const {g, k, c} = result;
  if (!Array.isArray(g) || !Array.isArray(k) || !Array.isArray(c)) return 'g, k and c must be arrays';
  if (g.length === 1 || g.length > GUILDS.length) return 'a round has no guild or 2 to 4';
  if (k.length !== g.length || c.length !== g.length) return 'k and c need one entry a guild';
  if (!g.every(x => isInt(x, 1, 4))) return 'guild ids are 1 to 4';
  if (new Set(g).size !== g.length) return 'a guild appears once';
  if (!k.every(x => isInt(x, 0, MAX_KILLS))) return 'falls out of range';
  if (!c.every(x => isInt(x, 0, MAX_CAPTURES))) return 'captures out of range';
  if (!isInt(result.held, 0, 4) || (result.held !== 0 && !g.includes(result.held))) return 'held must be 0 or one of the round\'s guilds';
  if (!isInt(result.own, 0, 4)) return 'own must be 0 to 4';
  if (g.length === 0 && (result.held !== 0)) return 'a round nobody fought has no holder';
  return {at, g: [...g], k: [...k], c: [...c], held: result.held, own: result.own};
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
  try {
    return {at: Number(row.at), result: JSON.parse(row.result)};
  } catch {
    return null;
  }
}

async function getRounds(request, env, url, now) {
  const from = Number(url.searchParams.get('from'));
  const to = Number(url.searchParams.get('to'));
  if (!Number.isSafeInteger(from) || !Number.isSafeInteger(to) || from < 0 || to < from) {
    return failure(400, 'invalid_range', 'from and to must be unix seconds, from <= to.');
  }
  if (to - from > MAX_RANGE) return failure(400, 'invalid_range', `At most ${MAX_RANGE} seconds a request.`);
  const busy = await limited(request, env, 'league_get', now);
  if (busy) return busy;
  const rows = await env.DB.prepare('SELECT at, result FROM toon_league_rounds WHERE at >= ? AND at <= ? ORDER BY at LIMIT 200').bind(from, to).all();
  const rounds = (rows.results ?? []).map(rowOf).filter(Boolean);
  return json({rounds, now});
}

async function postRound(request, env, now) {
  if ((request.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase() !== 'application/json') {
    return failure(415, 'unsupported_media_type', 'Send JSON.');
  }
  const declared = Number(request.headers.get('content-length') ?? 0);
  if (declared > MAX_BODY_BYTES) return failure(413, 'too_large', 'The round is too large.');
  const busy = await limited(request, env, 'league_post', now);
  if (busy) return busy;
  let body;
  try {
    const text = await request.text();
    if (ENCODER.encode(text).byteLength > MAX_BODY_BYTES) return failure(413, 'too_large', 'The round is too large.');
    body = JSON.parse(text);
  } catch {
    return failure(400, 'invalid_json', 'The body is not JSON.');
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) return failure(400, 'invalid_round', 'Send {at, result}.');
  for (const key of Object.keys(body)) if (key !== 'at' && key !== 'result') return failure(400, 'invalid_round', `Unknown key ${key}.`);
  const at = body.at;
  if (!isSlot(at)) return failure(400, 'invalid_round', 'at must be the start of a league round (12:00, 18:00 or 20:30 Thai).');
  if (now < at + DURATION - END_MARGIN) return failure(409, 'round_not_over', 'The round has not ended yet.');
  const result = cleanResult(at, body.result);
  if (typeof result === 'string') return failure(400, 'invalid_round', result);
  // First writer wins: INSERT OR IGNORE, then read back whichever result is stored.
  const [insert, read] = await env.DB.batch([
    env.DB.prepare('INSERT OR IGNORE INTO toon_league_rounds (at, result, created_at) VALUES (?, ?, ?)').bind(at, JSON.stringify(result), now),
    env.DB.prepare('SELECT at, result FROM toon_league_rounds WHERE at = ?').bind(at),
  ]);
  const stored = Number(insert.meta?.changes ?? 0) > 0;
  const round = rowOf(read.results[0]);
  return json({stored, round}, stored ? 201 : 200);
}

export async function handleLeagueRequest(request, env, {now = Math.floor(Date.now() / 1000)} = {}) {
  const url = new URL(request.url);
  if (!env?.DB) return failure(503, 'league_unavailable', 'League results are temporarily unavailable.');
  try {
    if (url.pathname === '/api/league/rounds') {
      if (request.method !== 'GET') return failure(405, 'method_not_allowed', 'Use GET.');
      return await getRounds(request, env, url, now);
    }
    if (url.pathname === '/api/league/round') {
      if (request.method !== 'POST') return failure(405, 'method_not_allowed', 'Use POST.');
      // Browsers send Origin on a POST; another site's page may not write rounds.
      const origin = request.headers.get('origin');
      if (origin && origin !== url.origin) return failure(403, 'invalid_origin', 'This request must come from the game website.');
      return await postRound(request, env, now);
    }
  } catch {
    return failure(503, 'league_unavailable', 'League results are temporarily unavailable.');
  }
  return failure(404, 'not_found', 'Endpoint not found.');
}
