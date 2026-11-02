// One-off owner tool used by .github/workflows/boost-character.yml. Talks to D1 through the
// Cloudflare REST API (bound parameters, so a full save never hits the SQL statement size limit).
//   node boost-character.mjs fetch <username> <dir>      writes <dir>/bundle.json and <dir>/meta.json
//   node boost-character.mjs apply <dir> <boosted.json>   (boosted.json = {slot, profile, created} from tools/boost_character.tscn)
//   node boost-character.mjs wipe <dir>                   every character of the fetched save removed (a fresh start)
// apply checks the save with the same rules as the game server, keeps a snapshot of the save it
// replaces, and only writes if nobody saved in between (compare-and-swap on the revision).
import {readFileSync, writeFileSync} from 'node:fs';
import {validateBundle} from '../accounts/server/accounts.js';

const {CLOUDFLARE_API_TOKEN: token, CLOUDFLARE_ACCOUNT_ID: account, DB_NAME: dbName} = process.env;
if (!token || !account || !dbName) throw new Error('CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID and DB_NAME are required');
const base = `https://api.cloudflare.com/client/v4/accounts/${account}/d1/database`;

async function call(url, init = {}) {
  const response = await fetch(url, {...init, headers: {authorization: `Bearer ${token}`, 'content-type': 'application/json'}});
  const body = await response.json().catch(() => ({}));
  if (!response.ok || body.success === false) throw new Error(`Cloudflare API ${response.status}: ${JSON.stringify(body.errors ?? body)}`);
  return body.result;
}

async function databaseId() {
  const list = await call(`${base}?name=${encodeURIComponent(dbName)}`);
  const db = list.find(entry => entry.name === dbName);
  if (!db) throw new Error(`Database ${dbName} not found`);
  return db.uuid;
}

async function query(id, sql, params = []) {
  const result = await call(`${base}/${id}/query`, {method: 'POST', body: JSON.stringify({sql, params})});
  return result[0]?.results ?? [];
}

const [command, a, b] = process.argv.slice(2);
const id = await databaseId();
if (command === 'fetch') {
  if (!/^[a-z0-9_]{3,24}$/.test(a || '')) throw new Error('invalid game ID');
  const [user] = await query(id, 'SELECT id FROM toon_users WHERE username = ?', [a]);
  if (!user) throw new Error(`No account named ${a}`);
  const [save] = await query(id, 'SELECT revision, bundle, updated_at FROM toon_saves WHERE user_id = ?', [user.id]);
  if (!save) throw new Error(`${a} has no online save yet`);
  writeFileSync(`${b}/bundle.json`, save.bundle);
  writeFileSync(`${b}/meta.json`, JSON.stringify({userId: user.id, revision: save.revision, updatedAt: save.updated_at}));
  const slots = JSON.parse(save.bundle).slots ?? {};
  console.log(`Online save revision ${save.revision}: ` + Object.entries(slots).map(([slot, p]) => `slot ${slot} ${p.name} (${p.class} Lv.${p.level})`).join(', '));
} else if (command === 'apply' || command === 'wipe') {
  const meta = JSON.parse(readFileSync(`${a}/meta.json`, 'utf8'));
  const next = JSON.parse(readFileSync(`${a}/bundle.json`, 'utf8'));
  const boosted = command === 'apply' ? JSON.parse(readFileSync(b, 'utf8')) : {};
  if (command === 'wipe') {
    // A fresh start: no character left, slot 1 selected (the old save stays as a snapshot).
    next.slots = {};
    next.selectedSlot = 1;
  } else {
    if (!/^(?:[1-9]|10)$/.test(String(boosted.slot))) throw new Error('The boosted slot must be 1 to 10');
    // A created character fills a slot that was free when the save was fetched; any other boost replaces one.
    if (boosted.created ? next.slots?.[boosted.slot] : !next.slots?.[boosted.slot])
      throw new Error(boosted.created ? 'The slot for the new character is no longer free' : 'The boosted slot is not in the fetched save');
    next.slots[boosted.slot] = boosted.profile;
    // Replaced gear past a full bag went to the account's shared storage.
    if (Array.isArray(boosted.storage)) next.storage = boosted.storage;
  }
  const bundle = validateBundle(next);
  const now = Math.floor(Date.now() / 1000);
  await query(id, `INSERT OR IGNORE INTO toon_save_snapshots (user_id, revision, bundle, updated_at)
    SELECT user_id, revision, bundle, updated_at FROM toon_saves WHERE user_id = ? AND revision = ? AND updated_at IS NOT NULL`, [meta.userId, meta.revision]);
  const rows = await query(id, `UPDATE toon_saves SET revision = revision + 1, bundle = ?, updated_at = ?
    WHERE user_id = ? AND revision = ? RETURNING revision`, [bundle, now, meta.userId, meta.revision]);
  if (!rows.length) throw new Error('The save changed while boosting (the game saved in between). Nothing was written; run the workflow again.');
  await query(id, `INSERT OR IGNORE INTO toon_save_snapshots (user_id, revision, bundle, updated_at)
    SELECT user_id, revision, bundle, updated_at FROM toon_saves WHERE user_id = ? AND revision = ?`, [meta.userId, rows[0].revision]);
  await query(id, `DELETE FROM toon_save_snapshots WHERE user_id = ? AND revision NOT IN
    (SELECT revision FROM toon_save_snapshots WHERE user_id = ? ORDER BY revision DESC LIMIT 5)`, [meta.userId, meta.userId]);
  console.log(`Saved revision ${rows[0].revision} (was ${meta.revision})${command === 'wipe' ? ', every character removed' : boosted.created ? `, new character in slot ${boosted.slot}` : ''}. The previous save is kept as a snapshot.`);
} else {
  throw new Error('usage: fetch <username> <dir> | apply <dir> <boosted.json> | wipe <dir>');
}
