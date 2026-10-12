import {handleAccountRequest} from '../accounts/server/accounts.js';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api/account/')) {
      return handleAccountRequest(request, env);
    }
    return env.ASSETS.fetch(request);
  },
};
