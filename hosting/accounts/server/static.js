/** Cache policy for the game files the Worker serves (docs/play as static assets).
 *
 * The offline web app relies on three rules:
 * - sw.js is always fetched fresh (no-store), served as JavaScript, so a new
 *   build is noticed on the next launch; it controls the whole site ("/").
 * - The page, manifest and Godot's unhashed loader files are revalidated.
 * - Content-named files (engine / game parts, account scripts, fonts) never
 *   change under the same name: cache them for a year and never re-encode the
 *   already gzip-compressed game parts.
 * tools/package_web.py writes the same rules into docs/play/_headers for
 * requests that Cloudflare answers without running the Worker. */
const REVALIDATE = 'no-cache';
const IMMUTABLE = 'public, max-age=31536000, immutable';
const CONTENT_NAMED = /\.[0-9a-f]{8,}\.[a-z0-9.]+$/;

export function assetHeaders(pathname) {
  const name = pathname.slice(pathname.lastIndexOf('/') + 1);
  if (name === 'sw.js') {
    return {
      'cache-control': 'no-cache, no-store, must-revalidate',
      'content-type': 'text/javascript; charset=utf-8',
      'service-worker-allowed': '/',
      'x-content-type-options': 'nosniff',
    };
  }
  if (name === '' || name === 'index.html') return {'cache-control': REVALIDATE, 'content-type': 'text/html; charset=utf-8'};
  if (name === 'manifest.webmanifest') return {'cache-control': REVALIDATE, 'content-type': 'application/manifest+json; charset=utf-8'};
  if (name.endsWith('.gz.wasm')) {
    // Already gzip data (inflated by the page); a second encoding only costs time.
    return {'cache-control': CONTENT_NAMED.test(name) ? `${IMMUTABLE}, no-transform` : REVALIDATE, 'content-type': 'application/wasm'};
  }
  if (CONTENT_NAMED.test(name)) return {'cache-control': IMMUTABLE};
  if (name === 'index.js' || name === 'index.audio.worklet.js') return {'cache-control': REVALIDATE};
  return {};
}

/** Serves a static file through the ASSETS binding with the policy above. */
export async function serveStatic(request, env) {
  const response = await env.ASSETS.fetch(request);
  if (response.status >= 400) return response;
  const policy = assetHeaders(new URL(request.url).pathname);
  if (!Object.keys(policy).length) return response;
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(policy)) {
    // A redirect or 304 keeps its own (empty) body type.
    if (name === 'content-type' && response.status !== 200) continue;
    headers.set(name, value);
  }
  return new Response(response.body, {status: response.status, statusText: response.statusText, headers});
}
