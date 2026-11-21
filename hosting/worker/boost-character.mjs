// One-off owner tool used by .github/workflows/boost-character.yml. Talks to D1 through the
// Cloudflare REST API (bound parameters, so a full save never hits the SQL statement size limit).
//   node boost-character.mjs fetch <username> <dir>      writes <dir>/bundle.json and <dir>/meta.json
//   node boost-character.mjs apply <dir> <boosted.json>   (boosted.json = {slot, profile, created} from tools/boost_character.tscn)
//   node boost-character.mjs apply-slots <dir> <slots.json>  (slots.json = {slots} from tools/guild_setup.tscn: existing slots replaced)
//   node boost-character.mjs apply-bundle <dir> <slots.json>  (slots.json = {slots, selectedSlot}: every slot replaced, tools/move_characters.tscn)
//   node boost-character.mjs wipe <dir>                   every character of the fetched save removed (a fresh start)
//   node boost-character.mjs remove <dir> <names>         only the named characters removed (names comma-separated, each must match one slot)
//   node boost-character.mjs reopen-all [--apply]         the world reopening (accounts.js WORLD_EPOCH): every account's characters and
//                                                         shared storage from before it removed; without --apply it only lists what it would do
// apply checks the save with the same rules as the game server, keeps a snapshot of the save it
// replaces, and only writes if nobody saved in between (compare-and-swap on the revision).
import {readFileSync, writeFileSync} from 'node:fs';
import {validateBundle, currentWorld, WORLD_EPOCH, SNAPSHOT_PRUNE_SQL} from '../accounts/server/accounts.js';

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
} else if (command === 'apply' || command === 'apply-slots' || command === 'apply-bundle' || command === 'wipe' || command === 'remove') {
  const meta = JSON.parse(readFileSync(`${a}/meta.json`, 'utf8'));
  const next = JSON.parse(readFileSync(`${a}/bundle.json`, 'utf8'));
  const boosted = command !== 'wipe' && command !== 'remove' ? JSON.parse(readFileSync(b, 'utf8')) : {};
  if (command === 'apply-bundle') {
    if (!boosted.slots || typeof boosted.slots !== 'object') throw new Error('No slots to write');
    next.slots = boosted.slots;
    next.selectedSlot = boosted.selectedSlot ?? 1;
  } else if (command === 'apply-slots') {
    for (const [slot, profile] of Object.entries(boosted.slots ?? {})) {
      if (!next.slots?.[slot]) throw new Error(`Slot ${slot} is not in the fetched save`);
      next.slots[slot] = profile;
    }
  } else if (command === 'remove') {
    // Only the named characters go; the others, the account and its shared storage stay.
    const names = String(b || '').split(',').map((n) => n.trim()).filter(Boolean);
    if (!names.length) throw new Error('Name the characters to remove');
    for (const name of names) {
      const hits = Object.entries(next.slots ?? {}).filter(([, p]) => p && p.name === name);
      if (hits.length !== 1) throw new Error(`Expected exactly one character named ${name}, found ${hits.length}`);
      delete next.slots[hits[0][0]];
      console.log(`Removing slot ${hits[0][0]}: ${name}`);
    }
    if (!next.slots[String(next.selectedSlot)]) {
      const left = Object.keys(next.slots).map(Number).sort((x, y) => x - y);
      next.selectedSlot = left.length ? left[0] : 1;
    }
  } else if (command === 'wipe') {
    // A fresh start: no character left, slot 1 selected, the shared storage emptied (the
    // old save stays as a snapshot).
    next.slots = {};
    next.selectedSlot = 1;
    next.storage = [];
    next.storageMigrated = {};
    next.storageEpoch = WORLD_EPOCH;
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
  await query(id, SNAPSHOT_PRUNE_SQL, [meta.userId, meta.userId, meta.userId]);
  console.log(`Saved revision ${rows[0].revision} (was ${meta.revision})${command === 'wipe' ? ', every character removed' : command === 'remove' ? `, removed ${b}` : boosted.created ? `, new character in slot ${boosted.slot}` : ''}. The previous save is kept as a snapshot.`);
} else if (command === 'reopen-all') {
  // Every account in turn (by user id, one save at a time: a save may be close to 2 MB):
  // its characters and shared storage from before WORLD_EPOCH removed, the account, its
  // password and recovery code untouched, characters made since the reopening kept. Each
  // save it changes is kept as a snapshot first (the last five revisions are kept, like the
  // game's own uploads) and written only if nobody saved in between; run it again for any
  // it skips. The game already drops those characters on its own (Game.WORLD_EPOCH); this
  // empties them online at once.
  const apply = a === '--apply';
  const now = Math.floor(Date.now() / 1000);
  let after = '', seen = 0, changed = 0, skipped = 0, removed = 0;
  for (;;) {
    const [row] = await query(id, 'SELECT s.user_id AS userId, s.revision, s.bundle, u.username FROM toon_saves s JOIN toon_users u ON u.id = s.user_id WHERE s.user_id > ? ORDER BY s.user_id LIMIT 1', [after]);
    if (!row) break;
    after = row.userId;
    seen += 1;
    const old = JSON.parse(row.bundle);
    const {bundle: next, changed: differs} = currentWorld(old);
    if (!differs) continue;
    const gone = Object.keys(old.slots ?? {}).length - Object.keys(next.slots).length;
    removed += gone;
    console.log(`${row.username}: ${gone} character(s), ${(old.storage ?? []).length} stored item(s) from before the reopening`);
    if (!apply) { changed += 1; continue; }
    const text = validateBundle(next);
    await query(id, `INSERT OR IGNORE INTO toon_save_snapshots (user_id, revision, bundle, updated_at)
      SELECT user_id, revision, bundle, COALESCE(updated_at, ?) FROM toon_saves WHERE user_id = ? AND revision = ?`, [now, row.userId, row.revision]);
    const rows = await query(id, `UPDATE toon_saves SET revision = revision + 1, bundle = ?, updated_at = ?
      WHERE user_id = ? AND revision = ? RETURNING revision`, [text, now, row.userId, row.revision]);
    if (!rows.length) { skipped += 1; console.log(`  ${row.username} saved in between: skipped (run again)`); continue; }
    await query(id, SNAPSHOT_PRUNE_SQL, [row.userId, row.userId, row.userId]);
    changed += 1;
  }
  console.log(`${seen} online save(s) read; ${changed} ${apply ? 'reset' : 'would be reset'} (${removed} character(s)); ${skipped} skipped.${apply ? '' : ' Dry run: nothing written (add --apply).'}`);
} else {
  throw new Error('usage: fetch <username> <dir> | apply <dir> <boosted.json> | apply-slots <dir> <slots.json> | apply-bundle <dir> <slots.json> | wipe <dir> | remove <dir> <names> | reopen-all [--apply]');
}
