import {handleAccountRequest} from '../accounts/server/accounts.js';
import {serveStatic} from '../accounts/server/static.js';
import {handleChat} from './chat.mjs';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    // Talking to the world players (Claude API): signed-in accounts only, see chat.mjs.
    if (url.pathname === '/api/account/chat') return handleChat(request, env);
    if (url.pathname.startsWith('/api/account/')) {
      return handleAccountRequest(request, env);
    }
    // sw.js, the page and the manifest come here (run_worker_first) so their
    // cache headers are exact; every other file is answered by Cloudflare
    // directly, using docs/play/_headers.
    return serveStatic(request, env);
  },
};
