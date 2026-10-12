# Toon Tale game accounts

`account.mjs` exports `handleAccountRequest(request, env)`. Mount it before the
Sites/Vinext page handler for `/api/account/*` and bind the platform's D1 database
as `env.DB`. This is the game's username/password system, not a Sites OAuth flow.
The module is ordinary Worker-compatible ESM and has no runtime dependencies.

`schema.ts` provides the matching Drizzle definitions. Generate and ship schema
migrations through the hosting project's migration workflow. The SQL migration
under `migrations/` is a schema-only fixture for portable SQLite tests. The request
handler never runs DDL. Existing account and save data survives code deployments.

## Browser contract

All responses are JSON with `Cache-Control: no-store, private`. Errors have
`{error:{code,message}}`, sometimes with extra conflict/rate-limit details. Browser
requests use same-origin `fetch`, `credentials: 'same-origin'` and JSON POST bodies.
POST requests must include the website's exact `Origin`. Cross-origin/native HTTP
clients need a separate intentionally designed authentication adapter; do not
disable the Origin check for the browser endpoint.

Username: trim and lowercase; 3–24 ASCII letters/digits/underscores. Password:
10–128 characters. Neither username nor password is silently truncated.

| Method / path below `/api/account` | Body | Result |
| --- | --- | --- |
| POST `/register` | `{username,password}` | HTTP 201 `{user:{id,username},recoveryCode}` |
| POST `/login` | `{username,password}` | `{user:{id,username}}` |
| GET `/session` | — | `{user:{id,username}}` or `{user:null}` |
| POST `/logout` | `{}` | `{ok:true}` |
| POST `/reset-password` | `{username,recoveryCode,password}` | `{user,recoveryCode}` |
| GET `/save` | — | `{userId,revision,bundle,updatedAt}` |
| POST `/save` | `{expectedRevision,bundle}` | `{revision,updatedAt}` |
| GET `/save/history` | — | `{userId,snapshots:[{revision,updatedAt}]}` |
| POST `/save/restore` | `{expectedRevision,revision}` | `{userId,revision,bundle,updatedAt}` |

`user` contains only ID and username. Register/login/reset set the HttpOnly,
Secure, SameSite=Strict `__Host-toon_session` cookie. Raw session tokens remain in
the browser cookie, never JavaScript/localStorage/database. The DB stores token
hashes, expires sessions after 30 days, and retains at most 10 sessions per account.
Logout revokes only the current device. Password recovery revokes every previous
session, creates one replacement session, and rotates the recovery code.

**Required identity precondition:** send `X-Toon-Account-ID: <state.user.id>` on
all save/history/restore and logout requests. The server authenticates solely from
the cookie and then compares this header with that account. The header never
selects an account. A missing/mismatched identity returns HTTP 409
`account_changed`, preventing a stale tab from overwriting a different account
after another tab changes the shared browser cookie. GET `/session` remains
header-free so the client can revalidate. Validate returned `userId` before using
downloaded save/history data.

`bundle` is `{slots:{'1':profile,...},selectedSlot:1}` with slot keys 1–4; absent
slots are empty. Each profile must be a dictionary with a real class, integer
level 1–100 and save version 1 (omitting version supports the current legacy
profile validator). Common scalar/container fields are type checked. Additional
game fields are preserved. Each profile is at most 1 MiB; the total serialized
bundle is at most **1,800,000 bytes** so it fits D1's approximately 2 MB row/string
limit. Larger saves return HTTP 413 before a DB write. Normal game profiles are
much smaller. Clients should also use the game's complete profile validator
before applying downloaded character slots.

A new account has revision 0, empty slots, selected slot 1 and null update time.
Uploads use an atomic SQLite compare-and-swap against `expectedRevision`. Success
increments the revision. A stale upload returns HTTP 409 `save_conflict` with the
current `revision` and `updatedAt`; it never writes over the newer save. The client
must offer cloud reload/local backup instead of retrying against the new revision
automatically. Five newest snapshots are retained. Restoring an available snapshot
also requires the current revision and creates a **new** revision; CAS never moves
backwards.

Show the recovery code once at registration/recovery and offer an explicit copy
or download action. It is a random 160-bit secret and only its account-bound hash
is stored. Without this code or the password, there is no email-based recovery.
Do not place either secret in URLs, analytics events, console output or chat logs.

Passwords use random 128-bit salts, PBKDF2-SHA256 at 100,000 iterations, and a
fixed-length digest comparison. Unknown username login runs the same password
derivation and returns the same error as a wrong password. All SQL is prepared.
Register/reset/login have persistent atomic IP rate limits (5 signups/hour,
30 login attempts/15 minutes and 30 reset attempts/15 minutes). There is no ID-only
lockout that another IP could use to prevent a legitimate login. On Cloudflare,
`CF-Connecting-IP` is the platform-provided source; the module never trusts
`X-Forwarded-For`. A runtime without the trusted IP header shares a conservative
global bucket and should supply a platform-authenticated IP adapter.

## Verification

Run `npm test` with Node 24+. Tests use built-in SQLite and Web Crypto, executing
the production SQL directly, including transactional D1-style batches. They
cover password/secret storage, collision races, cross-device login, generic
credential errors, cookie flags, logout/expiry, single-use recovery, cross-account
access, shared-cookie stale tabs, simultaneous and stale CAS writes, bounded
snapshot restore, persistent IP throttling, CSRF, malformed/oversized JSON and
saves, and safe service errors. This adapter is deliberately not a query-matching
fake, which could mask transactional/constraint bugs.
