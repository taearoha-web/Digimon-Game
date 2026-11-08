import {handleAccountRequest} from '../accounts/server/accounts.js';
import {serveStatic} from '../accounts/server/static.js';
import {handleOnlineRequest} from './online/route.mjs';
import {handleLeagueRequest} from './league.mjs';
import {WorldRoom} from './online/world_room.mjs';

// The Durable Object class of online play (binding WORLD) must be exported by the main module.
export {WorldRoom};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api/account/')) {
      return handleAccountRequest(request, env);
    }
    if (url.pathname.startsWith('/api/online/')) {
      return handleOnlineRequest(request, env);
    }
    if (url.pathname.startsWith('/api/league/')) {
      return handleLeagueRequest(request, env);
    }
    // sw.js, the page and the manifest come here (run_worker_first) so their
    // cache headers are exact; every other file is answered by Cloudflare
    // directly, using docs/play/_headers.
    return serveStatic(request, env);
  },
};
