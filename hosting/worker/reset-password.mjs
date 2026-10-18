// One-off owner tool used by .github/workflows/reset-account-password.yml.
// Reads NEW_PASSWORD (and optionally NEW_RECOVERY) from the environment, writes the SQL to argv[3].
// Same format as hosting/accounts/server/accounts.js: PBKDF2-SHA256, 100000 iterations, hex salt/hash;
// recovery hash = sha256("<user id>:<code upper-cased without spaces or dashes>").
import {webcrypto as crypto} from 'node:crypto';
import {writeFileSync} from 'node:fs';

const [userId, out] = [process.argv[2], process.argv[3]];
if (!/^[A-Za-z0-9_-]{8,64}$/.test(userId || '')) throw new Error('unexpected user id');
const enc = new TextEncoder();
const hex = bytes => Array.from(bytes, x => x.toString(16).padStart(2, '0')).join('');
const fromHex = value => Uint8Array.from(value.match(/../g), pair => parseInt(pair, 16));

const password = process.env.NEW_PASSWORD || '';
if (password.length < 10 || password.length > 128) throw new Error('RESET_PASSWORD must be 10-128 characters');
const salt = hex(crypto.getRandomValues(new Uint8Array(16)));
const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
const bits = await crypto.subtle.deriveBits({name: 'PBKDF2', hash: 'SHA-256', salt: fromHex(salt), iterations: 100000}, key, 256);
let sql = `UPDATE toon_users SET password_salt = '${salt}', password_hash = '${hex(new Uint8Array(bits))}', password_iterations = 100000`;
const recovery = (process.env.NEW_RECOVERY || '').toUpperCase().replace(/[\s-]/g, '');
if (recovery) {
  if (!/^[A-Z0-9]{12,64}$/.test(recovery)) throw new Error('RESET_RECOVERY_CODE must be 12-64 letters or digits');
  const digest = await crypto.subtle.digest('SHA-256', enc.encode(`${userId}:${recovery}`));
  sql += `, recovery_hash = '${hex(new Uint8Array(digest))}'`;
}
sql += ` WHERE id = '${userId}'; DELETE FROM toon_sessions WHERE user_id = '${userId}';`;
writeFileSync(out, sql);
