/** Portable Cloudflare Worker / Vinext account API. No framework dependencies. */
const ITERATIONS = 100_000;
const SESSION_SECONDS = 30 * 24 * 60 * 60;
const COOKIE = '__Host-toon_session';
const MAX_PROFILE_BYTES = 1_048_576;
// Character slots per account (Game.SLOT_COUNT in the game).
const MAX_SLOTS = 10;
// The storage every character shares (SharedStorage in the game): a top-level list of
// items. SharedStorage.SIZE (150) is the room for deposits; the game moves the old
// per-character storages (80 each) in without losing any, so it may hold up to
// 150 + 10 * 80. "storageMigrated" records the moved items ({key: count}).
const MAX_SHARED_STORAGE = 950;
const MAX_STORAGE_KEYS = 4000;
// D1 limits each row / string to approximately 2 MB. Leave space for revision,
// user ID and timestamp columns, and return an explicit size error beforehand.
const MAX_BUNDLE_BYTES = 1_800_000;
const MAX_REQUEST_BYTES = MAX_BUNDLE_BYTES + 8192;
const ENCODER = new TextEncoder();
const EMPTY_BUNDLE = JSON.stringify({slots: {}, selectedSlot: 1});
const CLASSES = new Set(['vagabond', 'warrior', 'archer', 'mage', 'priest', 'summoner', 'lancer', 'defender', 'assassin', 'darklord', 'bard']);
// Game.PARAGON_MAX (the star cap) and JobData: four level advancements, then the
// God promotion (adv 5, "เทพเจ้าแห่ง<อาชีพ>") that needs Lv.100 and 300 stars.
const MAX_STARS = 300;
const MAX_ADV = 5;
const GOD_ADV = 5;
const GOD_STARS = 300;
const COMMON_HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store, private',
  'pragma': 'no-cache',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer',
};

class ApiError extends Error {
  constructor(status, code, message, details = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function response(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), {status, headers: {...COMMON_HEADERS, ...extra}});
}

function fail(status, code, message, details) {
  throw new ApiError(status, code, message, details);
}

function randomBytes(length) {
  return crypto.getRandomValues(new Uint8Array(length));
}

function hex(bytes) {
  return Array.from(bytes, byte => byte.toString(16).padStart(2, '0')).join('');
}

function fromHex(value) {
  if (typeof value !== 'string' || !/^[0-9a-f]+$/.test(value) || value.length % 2) return new Uint8Array();
  return Uint8Array.from(value.match(/../g), pair => parseInt(pair, 16));
}

function token() {
  return btoa(String.fromCharCode(...randomBytes(32))).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function recoveryCode() {
  return hex(randomBytes(20)).toUpperCase().match(/.{1,5}/g).join('-');
}

function cleanRecovery(value) {
  return typeof value === 'string' ? value.toUpperCase().replace(/[\s-]/g, '') : '';
}

async function sha256(value) {
  return hex(new Uint8Array(await crypto.subtle.digest('SHA-256', ENCODER.encode(value))));
}

async function passwordHash(password, salt, iterations = ITERATIONS) {
  const key = await crypto.subtle.importKey('raw', ENCODER.encode(password), 'PBKDF2', false, ['deriveBits']);
  const bytes = await crypto.subtle.deriveBits({name: 'PBKDF2', hash: 'SHA-256', salt: fromHex(salt), iterations}, key, 256);
  return hex(new Uint8Array(bytes));
}

function equalSecret(left, right) {
  // Always inspect a fixed 32-byte digest; no early exits on the first mismatch.
  const a = fromHex(left), b = fromHex(right);
  let difference = a.length ^ b.length;
  for (let i = 0; i < 32; i++) difference |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return difference === 0 && a.length === 32;
}

function setCookie(sessionToken) {
  return `${COOKIE}=${sessionToken}; Path=/; Max-Age=${SESSION_SECONDS}; HttpOnly; Secure; SameSite=Strict`;
}

function clearCookie() {
  return `${COOKIE}=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Strict`;
}

function readCookie(request) {
  const matches = (request.headers.get('cookie') ?? '').split(';').map(part => part.trim())
    .filter(part => part.startsWith(`${COOKIE}=`));
  if (matches.length !== 1) return null;
  const value = matches[0].slice(COOKIE.length + 1);
  return /^[A-Za-z0-9_-]{43}$/.test(value) ? value : null;
}

function dictionary(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function integer(value, minimum = 0, maximum = 1_000_000_000_000) {
  return Number.isSafeInteger(value) && value >= minimum && value <= maximum;
}

function credentials(body) {
  const username = typeof body.username === 'string' ? body.username.trim().toLowerCase() : '';
  if (!/^[a-z0-9_]{3,24}$/.test(username)) fail(400, 'invalid_username', 'Use 3–24 letters, digits or underscores for the ID.');
  if (typeof body.password !== 'string' || body.password.length < 10 || body.password.length > 128) {
    fail(400, 'invalid_password', 'The password must contain 10–128 characters.');
  }
  return {username, password: body.password};
}

async function jsonBody(request, maxBytes = 4096) {
  if (!/^application\/json(?:\s*;|\s*$)/i.test(request.headers.get('content-type') ?? '')) {
    fail(415, 'json_required', 'Send application/json.');
  }
  const length = request.headers.get('content-length');
  if (length && (!/^\d+$/.test(length) || Number(length) > maxBytes)) fail(413, 'request_too_large', 'The request is too large.');
  const reader = request.body?.getReader();
  if (!reader) fail(400, 'invalid_json', 'Send a JSON object.');
  let size = 0;
  const chunks = [];
  try {
    for (;;) {
      const {value, done} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBytes) {
        await reader.cancel();
        fail(413, 'request_too_large', 'The request is too large.');
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {bytes.set(chunk, offset); offset += chunk.byteLength;}
  let body;
  try {body = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(bytes));}
  catch {fail(400, 'invalid_json', 'Send valid JSON.');}
  if (!dictionary(body)) fail(400, 'invalid_json', 'Send a JSON object.');
  return body;
}

function validateJsonTree(value) {
  const pending = [[value, 0]];
  let visited = 0;
  while (pending.length) {
    const [node, depth] = pending.pop();
    if (++visited > 100_000 || depth > 40) fail(400, 'invalid_save', 'The save is too complex.');
    if (typeof node === 'number' && !Number.isFinite(node)) fail(400, 'invalid_save', 'Save numbers must be finite.');
    if (node && typeof node === 'object') {
      for (const [key, child] of Object.entries(node)) {
        if (key === '__proto__' || key === 'constructor' || key === 'prototype') fail(400, 'invalid_save', 'The save contains an invalid field.');
        pending.push([child, depth + 1]);
      }
    }
  }
}

function validateProfile(profile) {
  if (!dictionary(profile) || !CLASSES.has(profile.class) || !integer(profile.level, 1, 100)
      || !integer(profile.version ?? 1, 1, 1)) fail(400, 'invalid_save', 'The character class, level or save version is invalid.');
  for (const key of ['exp', 'points', 'skill_points', 'gold', 'hp', 'mp', 'kills', 'deaths', 'saved_at']) {
    if (key in profile && !integer(profile[key])) fail(400, 'invalid_save', `The character field ${key} is invalid.`);
  }
  if ('play_time' in profile && (typeof profile.play_time !== 'number' || profile.play_time < 0 || profile.play_time > 1e12)) fail(400, 'invalid_save', 'The character play time is invalid.');
  if ('adv' in profile && !integer(profile.adv, 0, MAX_ADV)) fail(400, 'invalid_save', 'The character advancement is invalid.');
  if ('bag_slots' in profile && !integer(profile.bag_slots, 40, 100)) fail(400, 'invalid_save', 'The bag capacity is invalid.');
  for (const key of ['name', 'zone', 'job', 'spawn_override', 'mount']) {
    if (key in profile && typeof profile[key] !== 'string') fail(400, 'invalid_save', `The character field ${key} must be text.`);
  }
  for (const key of ['resume', 'job3']) {
    if (key in profile && typeof profile[key] !== 'boolean') fail(400, 'invalid_save', `The character field ${key} must be boolean.`);
  }
  for (const key of ['attrs', 'skills', 'equip', 'quests', 'flags', 'boss_kills', 'pvp', 'tower', 'paragon', 'ach', 'look', 'daily']) {
    if (key in profile && !dictionary(profile[key])) fail(400, 'invalid_save', `The character field ${key} must be an object.`);
  }
  for (const key of ['inv', 'storage', 'loadout', 'party']) {
    if (key in profile && !Array.isArray(profile[key])) fail(400, 'invalid_save', `The character field ${key} must be a list.`);
  }
  const stars = profile.paragon?.level ?? 0;
  if (!integer(stars, 0, MAX_STARS)) fail(400, 'invalid_save', `The character stars must be 0 to ${MAX_STARS}.`);
  if ((profile.adv ?? 0) >= GOD_ADV && (profile.level !== 100 || stars < GOD_STARS)) fail(400, 'invalid_save', `The God promotion needs level 100 and ${GOD_STARS} stars.`);
  // Mounts: {id: level 0-5}; saves from before mount levels kept a list of owned ids.
  if ('mounts' in profile) {
    const mounts = profile.mounts;
    const ok = Array.isArray(mounts)
      ? mounts.length <= 64 && mounts.every(value => typeof value === 'string')
      : dictionary(mounts) && Object.keys(mounts).length <= 64 && Object.values(mounts).every(value => integer(value, 0, 5));
    if (!ok) fail(400, 'invalid_save', 'The character mounts are invalid.');
  }
  for (const key of ['attrs', 'skills', 'boss_kills', 'pvp', 'tower', 'look']) {
    if (Object.values(profile[key] ?? {}).some(value => !integer(value))) fail(400, 'invalid_save', `The character field ${key} has invalid values.`);
  }
  if ((profile.inv?.length ?? 0) > 100 || (profile.storage?.length ?? 0) > 80
      || (profile.loadout ?? []).some(value => typeof value !== 'string')
      || (profile.inv ?? []).some(value => !dictionary(value))
      || (profile.storage ?? []).some(value => !dictionary(value))
      || Object.values(profile.equip ?? {}).some(value => !dictionary(value))) fail(400, 'invalid_save', 'The inventory or skill loadout is invalid.');
  if (ENCODER.encode(JSON.stringify(profile)).byteLength > MAX_PROFILE_BYTES) fail(413, 'save_too_large', 'Each character save must be at most 1 MiB.');
}

function validateSharedStorage(bundle) {
  if ('storage' in bundle && (!Array.isArray(bundle.storage) || bundle.storage.length > MAX_SHARED_STORAGE
      || bundle.storage.some(item => !dictionary(item) || typeof item.kind !== 'string'))) {
    fail(400, 'invalid_save', `The shared storage must be a list of at most ${MAX_SHARED_STORAGE} items.`);
  }
  if ('storageMigrated' in bundle) {
    const record = bundle.storageMigrated;
    if (!dictionary(record) || Object.keys(record).length > MAX_STORAGE_KEYS
        || Object.entries(record).some(([key, count]) => key.length > 64 || !integer(count, 1, 100_000))) {
      fail(400, 'invalid_save', 'The shared storage record is invalid.');
    }
  }
}

export function validateBundle(bundle) {
  if (!dictionary(bundle) || !dictionary(bundle.slots) || !integer(bundle.selectedSlot, 1, MAX_SLOTS)) fail(400, 'invalid_save', `Send up to ${MAX_SLOTS} character slots and a selected slot from 1 to ${MAX_SLOTS}.`);
  validateJsonTree(bundle);
  for (const [slot, profile] of Object.entries(bundle.slots)) {
    if (!/^(?:[1-9]|10)$/.test(slot)) fail(400, 'invalid_save', `Character slots must be numbered 1 to ${MAX_SLOTS}.`);
    validateProfile(profile);
  }
  validateSharedStorage(bundle);
  const kept = {slots: bundle.slots, selectedSlot: bundle.selectedSlot};
  if ('storage' in bundle) kept.storage = bundle.storage;
  if ('storageMigrated' in bundle) kept.storageMigrated = bundle.storageMigrated;
  const serialized = JSON.stringify(kept);
  if (ENCODER.encode(serialized).byteLength > MAX_BUNDLE_BYTES) fail(413, 'save_too_large', 'The full save must be at most 1.8 MB.');
  return serialized;
}

async function rateLimit(db, request, username, action, now) {
  // CF-Connecting-IP is platform-authenticated on a Cloudflare Worker. Never
  // trust X-Forwarded-For. A platform without this header uses a global bucket.
  const source = request.headers.get('cf-connecting-ip') ?? 'unknown-platform-ip';
  const rules = action === 'register'
    ? [[`register:ip:${source}`, 5, 3600]]
    : [[`${action}:ip:${source}`, 30, 900]];
  const statements = [];
  for (const [subject, limit, seconds] of rules) {
    const window = Math.floor(now / seconds);
    const bucket = `${action}:${window}:${await sha256(subject)}`;
    statements.push(db.prepare(`INSERT INTO toon_rate_limits (bucket, count, expires_at)
      VALUES (?, 1, ?) ON CONFLICT(bucket) DO UPDATE SET count = MIN(count + 1, 1000000)
      RETURNING count`).bind(bucket, (window + 1) * seconds));
  }
  statements.push(db.prepare('DELETE FROM toon_rate_limits WHERE bucket IN (SELECT bucket FROM toon_rate_limits WHERE expires_at <= ? LIMIT 100)').bind(now));
  const result = await db.batch(statements);
  for (let i = 0; i < rules.length; i++) {
    if (result[i].results[0].count > rules[i][1]) {
      const retryAfter = (Math.floor(now / rules[i][2]) + 1) * rules[i][2] - now;
      fail(429, 'too_many_attempts', 'Too many attempts. Please try again later.', {retryAfter});
    }
  }
}

async function currentSession(request, db, now) {
  const raw = readCookie(request);
  if (!raw) return null;
  const tokenHash = await sha256(raw);
  const user = await db.prepare(`SELECT u.id, u.username FROM toon_sessions s JOIN toon_users u ON u.id = s.user_id
    WHERE s.token_hash = ? AND s.expires_at > ?`).bind(tokenHash, now).first();
  return user ? {user, tokenHash} : null;
}

async function requireSession(request, db, now) {
  const session = await currentSession(request, db, now);
  if (!session) fail(401, 'not_authenticated', 'Sign in to your game account.');
  // Cookies are shared between tabs: an A tab must never upload its save into B
  // after another tab signs in as B. This is a precondition, never an auth key.
  if (request.headers.get('x-toon-account-id') !== session.user.id) {
    fail(409, 'account_changed', 'The signed-in game account changed. Sign in again before continuing.', {userId: session.user.id});
  }
  return session;
}

function sessionPruning(db, userId, now) {
  return [
    db.prepare('DELETE FROM toon_sessions WHERE token_hash IN (SELECT token_hash FROM toon_sessions WHERE expires_at <= ? LIMIT 100)').bind(now),
    db.prepare(`DELETE FROM toon_sessions WHERE user_id = ? AND token_hash NOT IN
      (SELECT token_hash FROM toon_sessions WHERE user_id = ? ORDER BY created_at DESC, rowid DESC LIMIT 10)`).bind(userId, userId),
  ];
}

function snapshotStatements(db, userId, revision, now) {
  return [
    db.prepare(`INSERT OR IGNORE INTO toon_save_snapshots (user_id, revision, bundle, updated_at)
      SELECT user_id, revision, bundle, updated_at FROM toon_saves WHERE user_id = ? AND revision = ? AND updated_at = ?`).bind(userId, revision, now),
    db.prepare(`DELETE FROM toon_save_snapshots WHERE user_id = ? AND revision NOT IN
      (SELECT revision FROM toon_save_snapshots WHERE user_id = ? ORDER BY revision DESC LIMIT 5)`).bind(userId, userId),
  ];
}

async function conflict(db, userId) {
  const current = await db.prepare('SELECT revision, updated_at FROM toon_saves WHERE user_id = ?').bind(userId).first();
  fail(409, 'save_conflict', 'A newer save exists. Load it before saving again.', {
    revision: current?.revision ?? 0, updatedAt: current?.updated_at == null ? null : new Date(current.updated_at * 1000).toISOString(),
  });
}

async function route(request, env) {
  const url = new URL(request.url);
  const path = url.pathname;
  const method = request.method.toUpperCase();
  if (!path.startsWith('/api/account/')) fail(404, 'not_found', 'Endpoint not found.');
  if (!env?.DB) fail(503, 'service_unavailable', 'Game accounts are temporarily unavailable.');
  const db = env.DB;
  const now = Math.floor(Date.now() / 1000);
  if (method !== 'GET' && method !== 'POST') fail(405, 'method_not_allowed', 'Use GET or POST.');
  if (method === 'POST' && request.headers.get('origin') !== url.origin) fail(403, 'invalid_origin', 'This request must come from the game website.');

  if (path === '/api/account/session' && method === 'GET') {
    const session = await currentSession(request, db, now);
    return response({user: session?.user ?? null}, 200, session ? {} : {'set-cookie': clearCookie()});
  }
  if (path === '/api/account/logout' && method === 'POST') {
    await jsonBody(request);
    const session = await requireSession(request, db, now);
    await db.prepare('DELETE FROM toon_sessions WHERE token_hash = ?').bind(session.tokenHash).run();
    return response({ok: true}, 200, {'set-cookie': clearCookie()});
  }
  if (path === '/api/account/register' && method === 'POST') {
    const body = await jsonBody(request);
    const {username, password} = credentials(body);
    await rateLimit(db, request, username, 'register', now);
    const user = {id: crypto.randomUUID(), username};
    const salt = hex(randomBytes(16));
    const passwordDigest = await passwordHash(password, salt);
    const code = recoveryCode();
    const recoveryDigest = await sha256(`${user.id}:${cleanRecovery(code)}`);
    const raw = token();
    try {
      await db.batch([
        db.prepare(`INSERT INTO toon_users (id, username, password_salt, password_hash, password_iterations, recovery_hash, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)`).bind(user.id, username, salt, passwordDigest, ITERATIONS, recoveryDigest, now),
        db.prepare('INSERT INTO toon_sessions (token_hash, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)').bind(await sha256(raw), user.id, now, now + SESSION_SECONDS),
      ]);
    } catch (error) {
      if (/UNIQUE constraint failed: toon_users\.username/.test(String(error))) fail(409, 'id_unavailable', 'This game ID is already in use.');
      throw error;
    }
    return response({user, recoveryCode: code}, 201, {'set-cookie': setCookie(raw)});
  }
  if (path === '/api/account/login' && method === 'POST') {
    const body = await jsonBody(request);
    const {username, password} = credentials(body);
    await rateLimit(db, request, username, 'login', now);
    const stored = await db.prepare('SELECT * FROM toon_users WHERE username = ?').bind(username).first();
    const digest = await passwordHash(password, stored?.password_salt ?? '00000000000000000000000000000000', stored?.password_iterations ?? ITERATIONS);
    if (!stored || !equalSecret(digest, stored.password_hash)) fail(401, 'invalid_credentials', 'The game ID or password is incorrect.');
    const raw = token();
    const result = await db.batch([
      db.prepare(`INSERT INTO toon_sessions (token_hash, user_id, created_at, expires_at)
        SELECT ?, id, ?, ? FROM toon_users WHERE id = ? AND password_hash = ?
        RETURNING user_id`).bind(await sha256(raw), now, now + SESSION_SECONDS, stored.id, stored.password_hash),
      ...sessionPruning(db, stored.id, now),
    ]);
    if (!result[0].results.length) fail(401, 'invalid_credentials', 'The game ID or password is incorrect.');
    return response({user: {id: stored.id, username: stored.username}}, 200, {'set-cookie': setCookie(raw)});
  }
  if (path === '/api/account/reset-password' && method === 'POST') {
    const body = await jsonBody(request);
    const {username, password} = credentials(body);
    await rateLimit(db, request, username, 'reset', now);
    const stored = await db.prepare('SELECT id, username, recovery_hash FROM toon_users WHERE username = ?').bind(username).first();
    const candidateRecovery = await sha256(`${stored?.id ?? 'missing-user'}:${cleanRecovery(body.recoveryCode)}`);
    if (!stored || !equalSecret(candidateRecovery, stored.recovery_hash)) fail(401, 'invalid_credentials', 'The game ID or recovery code is incorrect.');
    const salt = hex(randomBytes(16));
    const digest = await passwordHash(password, salt);
    const code = recoveryCode();
    const recoveryDigest = await sha256(`${stored.id}:${cleanRecovery(code)}`);
    const raw = token();
    const result = await db.batch([
      db.prepare(`UPDATE toon_users SET password_salt = ?, password_hash = ?, password_iterations = ?, recovery_hash = ?
        WHERE id = ? AND recovery_hash = ? RETURNING id`).bind(salt, digest, ITERATIONS, recoveryDigest, stored.id, stored.recovery_hash),
      db.prepare(`DELETE FROM toon_sessions WHERE user_id = ? AND EXISTS
        (SELECT 1 FROM toon_users WHERE id = ? AND password_hash = ?)`).bind(stored.id, stored.id, digest),
      db.prepare(`INSERT INTO toon_sessions (token_hash, user_id, created_at, expires_at)
        SELECT ?, id, ?, ? FROM toon_users WHERE id = ? AND password_hash = ?`).bind(await sha256(raw), now, now + SESSION_SECONDS, stored.id, digest),
    ]);
    if (!result[0].results.length) fail(401, 'invalid_credentials', 'The game ID or recovery code is incorrect.');
    return response({user: {id: stored.id, username: stored.username}, recoveryCode: code}, 200, {'set-cookie': setCookie(raw)});
  }
  if (path === '/api/account/save' && method === 'GET') {
    const {user} = await requireSession(request, db, now);
    const save = await db.prepare('SELECT revision, bundle, updated_at FROM toon_saves WHERE user_id = ?').bind(user.id).first();
    return response(save ? {
      userId: user.id, revision: save.revision, bundle: JSON.parse(save.bundle),
      updatedAt: save.updated_at == null ? null : new Date(save.updated_at * 1000).toISOString(),
    } : {userId: user.id, revision: 0, bundle: JSON.parse(EMPTY_BUNDLE), updatedAt: null});
  }
  if (path === '/api/account/save' && method === 'POST') {
    const {user} = await requireSession(request, db, now);
    const body = await jsonBody(request, MAX_REQUEST_BYTES);
    if (!integer(body.expectedRevision, 0, Number.MAX_SAFE_INTEGER - 1)) fail(400, 'invalid_revision', 'Send the last loaded save revision.');
    const bundle = validateBundle(body.bundle);
    const revision = body.expectedRevision + 1;
    // A game from before the shared storage sends no "storage": it must never replace
    // a save that has one (that would drop every character's stored items).
    const sendsStorage = 'storage' in body.bundle ? 1 : 0;
    const result = await db.batch([
      db.prepare('INSERT INTO toon_saves (user_id, revision, bundle, updated_at) VALUES (?, 0, ?, NULL) ON CONFLICT(user_id) DO NOTHING').bind(user.id, EMPTY_BUNDLE),
      db.prepare(`UPDATE toon_saves SET revision = revision + 1, bundle = ?, updated_at = ?
        WHERE user_id = ? AND revision = ? AND (? = 1 OR json_type(bundle, '$.storage') IS NULL)
        RETURNING revision, updated_at`).bind(bundle, now, user.id, body.expectedRevision, sendsStorage),
      ...snapshotStatements(db, user.id, revision, now),
    ]);
    if (!result[1].results.length) {
      if (!sendsStorage) {
        const current = await db.prepare(`SELECT revision, json_type(bundle, '$.storage') AS storage FROM toon_saves WHERE user_id = ?`).bind(user.id).first();
        if (current?.revision === body.expectedRevision && current.storage != null) {
          fail(409, 'client_outdated', 'This save holds the shared storage, which this game version does not know. Reload the page to update the game.');
        }
      }
      await conflict(db, user.id);
    }
    return response({revision: result[1].results[0].revision, updatedAt: new Date(now * 1000).toISOString()});
  }
  if (path === '/api/account/save/history' && method === 'GET') {
    const {user} = await requireSession(request, db, now);
    const result = await db.prepare('SELECT revision, updated_at FROM toon_save_snapshots WHERE user_id = ? ORDER BY revision DESC LIMIT 5').bind(user.id).all();
    return response({userId: user.id, snapshots: result.results.map(row => ({revision: row.revision, updatedAt: new Date(row.updated_at * 1000).toISOString()}))});
  }
  if (path === '/api/account/save/restore' && method === 'POST') {
    const {user} = await requireSession(request, db, now);
    const body = await jsonBody(request);
    if (!integer(body.expectedRevision, 0, Number.MAX_SAFE_INTEGER - 1) || !integer(body.revision, 1)) fail(400, 'invalid_revision', 'Send the current revision and the snapshot revision.');
    const exists = await db.prepare('SELECT 1 FROM toon_save_snapshots WHERE user_id = ? AND revision = ?').bind(user.id, body.revision).first();
    if (!exists) fail(404, 'snapshot_not_found', 'This backup is no longer available.');
    const result = await db.batch([
      db.prepare(`UPDATE toon_saves SET revision = revision + 1, updated_at = ?, bundle =
        (SELECT bundle FROM toon_save_snapshots WHERE user_id = ? AND revision = ?)
        WHERE user_id = ? AND revision = ? AND EXISTS
        (SELECT 1 FROM toon_save_snapshots WHERE user_id = ? AND revision = ?)
        RETURNING revision, bundle, updated_at`).bind(now, user.id, body.revision, user.id, body.expectedRevision, user.id, body.revision),
      ...snapshotStatements(db, user.id, body.expectedRevision + 1, now),
    ]);
    if (!result[0].results.length) await conflict(db, user.id);
    const save = result[0].results[0];
    return response({userId: user.id, revision: save.revision, bundle: JSON.parse(save.bundle), updatedAt: new Date(save.updated_at * 1000).toISOString()});
  }
  fail(404, 'not_found', 'Endpoint not found.');
}

/** The account checks a feature outside this file (the AI chat, hosting/worker/chat.mjs)
 * runs before it spends anything: a POST from the game's own page, a signed-in session
 * owned by the account the page says it is, and per-account limits (each [subject, limit,
 * seconds]: at most `limit` calls in the window). Throws ApiError; answer it with
 * accountError(). Returns {user, now}. */
export async function accountGate(request, env, action, limits) {
  const url = new URL(request.url);
  if (!env?.DB) fail(503, 'service_unavailable', 'Game accounts are temporarily unavailable.');
  if (request.method.toUpperCase() !== 'POST') fail(405, 'method_not_allowed', 'Use POST.');
  if (request.headers.get('origin') !== url.origin) fail(403, 'invalid_origin', 'This request must come from the game website.');
  const now = Math.floor(Date.now() / 1000);
  const session = await requireSession(request, env.DB, now);
  const statements = [];
  for (const [subject, , seconds] of limits) {
    const window = Math.floor(now / seconds);
    const bucket = `${action}:${window}:${await sha256(`${subject}:${session.user.id}`)}`;
    statements.push(env.DB.prepare(`INSERT INTO toon_rate_limits (bucket, count, expires_at)
      VALUES (?, 1, ?) ON CONFLICT(bucket) DO UPDATE SET count = MIN(count + 1, 1000000)
      RETURNING count`).bind(bucket, (window + 1) * seconds));
  }
  statements.push(env.DB.prepare('DELETE FROM toon_rate_limits WHERE bucket IN (SELECT bucket FROM toon_rate_limits WHERE expires_at <= ? LIMIT 100)').bind(now));
  const result = await env.DB.batch(statements);
  for (let i = 0; i < limits.length; i++) {
    if (result[i].results[0].count > limits[i][1]) {
      const retryAfter = (Math.floor(now / limits[i][2]) + 1) * limits[i][2] - now;
      fail(429, 'too_many_messages', 'Too many messages. Please wait a little.', {retryAfter, limit: limits[i][0]});
    }
  }
  return {user: session.user, now};
}

/** The JSON answer for an error thrown by accountGate or a feature built on it. */
export function accountError(error) {
  if (error instanceof ApiError) {
    const extra = error.status === 429 ? {'retry-after': String(error.details.retryAfter)} : {};
    return response({error: {code: error.code, message: error.message}, ...error.details}, error.status, extra);
  }
  return response({error: {code: 'service_unavailable', message: 'The service is temporarily unavailable. Please try again.'}}, 503);
}

/** A JSON answer with the account API's headers. */
export function accountResponse(body, status = 200) {
  return response(body, status);
}

/** Throws the account API's error (status, code, message) from a feature built on it. */
export function accountFail(status, code, message, details) {
  fail(status, code, message, details);
}

/** A request body as JSON, at most maxBytes. */
export function accountJson(request, maxBytes) {
  return jsonBody(request, maxBytes);
}

export async function handleAccountRequest(request, env) {
  try {return await route(request, env);}
  catch (error) {
    if (error instanceof ApiError) {
      const extra = error.status === 429 ? {'retry-after': String(error.details.retryAfter)} : {};
      return response({error: {code: error.code, message: error.message}, ...error.details}, error.status, extra);
    }
    // Do not expose SQL, account existence, passwords, cookies or request bodies.
    return response({error: {code: 'service_unavailable', message: 'Game accounts are temporarily unavailable. Please try again.'}}, 503);
  }
}

export default {fetch: handleAccountRequest};
