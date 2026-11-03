/** /api/online/*: the WebSocket of online play (docs/ONLINE_PROTOCOL.md) and a status probe.
 * The session cookie is checked here (the same D1 session as /api/account/*); the Durable
 * Object `world` only ever sees the account through x-toon-user-id / x-toon-username. */
import {currentSession} from '../../accounts/server/accounts.js';

const JSON_HEADERS = {'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store, private'};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {status, headers: JSON_HEADERS});
}

function onlineError(status, code, message) {
  return json({error: {code, message}}, status);
}

function world(env) {
  return env.WORLD.get(env.WORLD.idFromName('world'));
}

export async function handleOnlineRequest(request, env) {
  const url = new URL(request.url);
  if (!env?.WORLD) return onlineError(503, 'online_unavailable', 'Online play is not switched on.');
  if (url.pathname === '/api/online/status') {
    if (request.method !== 'GET') return onlineError(405, 'method_not_allowed', 'Use GET.');
    try {
      const answer = await world(env).fetch('https://world/status');
      const {online} = await answer.json();
      return json({online: Number(online) || 0});
    } catch {
      return onlineError(503, 'online_unavailable', 'Online play is temporarily unavailable.');
    }
  }
  if (url.pathname !== '/api/online/ws') return onlineError(404, 'not_found', 'Endpoint not found.');
  if (request.method !== 'GET' || (request.headers.get('upgrade') ?? '').toLowerCase() !== 'websocket') {
    return onlineError(426, 'upgrade_required', 'Open a WebSocket.');
  }
  // Browsers always send Origin with a WebSocket; another site's page must not ride on the cookie.
  const origin = request.headers.get('origin');
  if (origin && origin !== url.origin) return onlineError(403, 'invalid_origin', 'This request must come from the game website.');
  if (!env.DB) return onlineError(503, 'service_unavailable', 'Game accounts are temporarily unavailable.');
  let session;
  try {
    session = await currentSession(request, env.DB);
  } catch {
    return onlineError(503, 'service_unavailable', 'Game accounts are temporarily unavailable.');
  }
  if (!session) return onlineError(401, 'not_authenticated', 'Sign in to your game account.');
  const headers = new Headers(request.headers);
  headers.set('x-toon-user-id', String(session.user.id));
  headers.set('x-toon-username', String(session.user.username));
  headers.delete('cookie');
  return world(env).fetch(new Request(request.url, {method: 'GET', headers}));
}
