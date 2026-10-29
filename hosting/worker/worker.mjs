import {handleAccountRequest} from '../accounts/server/accounts.js';
import {serveStatic} from '../accounts/server/static.js';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api/account/')) {
      return handleAccountRequest(request, env);
    }
    // sw.js, the page and the manifest come here (run_worker_first) so their
    // cache headers are exact; every other file is answered by Cloudflare
    // directly, using docs/play/_headers.
    return serveStatic(request, env);
  },
};
