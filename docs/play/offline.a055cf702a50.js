/* Toon Tale offline play (installed web app).
 * - Registers sw.js and fills this build's cache in the background, so the
 *   whole game (page, engine, every game part) opens without a network.
 * - Shows a small Thai status: download progress, ready, offline, syncing.
 * - Offers a new build ("มีเวอร์ชันใหม่ แตะเพื่ออัปเดต"); a waiting build is
 *   also applied by itself on the next launch, before the game starts.
 * - Asks for persistent storage and shows the iPhone "add to home screen" hint once.
 * window.TOON_OFFLINE = {build, files: [[path, bytes, contentNamed, core]], total}
 * is written into the page by tools/package_web.py (null for builds without sw.js). */
(function () {
  'use strict';
  const CONFIG = window.TOON_OFFLINE;
  const netFetch = window.fetch.bind(window);
  const CACHE = CONFIG ? 'toon-tale-' + CONFIG.build : '';
  const HINT_KEY = 'toon_install_hint_v1';
  const state = {phase: CONFIG ? 'idle' : 'unsupported', done: 0, total: 0, ready: false, online: navigator.onLine !== false,
    update: false, game: 'menu', paused: false, persisted: null, sync: '', error: '', shown: []};
  let pill, pillText, updateButton, hideTimer, resumeFill = null, abortFill = null, registration = null;
  let hadController = false, applying = false, interacted = false, wasPending = false;

  function safe(fn, fallback) { try { return fn(); } catch (_) { return fallback; } }
  function el(tag, attrs, text) {
    const node = document.createElement(tag);
    for (const key of Object.keys(attrs || {})) node.setAttribute(key, attrs[key]);
    if (text) node.textContent = text;
    return node;
  }
  function ui() {
    if (pill || !document.body) return;
    pill = el('div', {id: 'toon-offline', role: 'status', 'aria-live': 'polite', hidden: ''});
    pillText = el('span');
    pill.appendChild(pillText);
    updateButton = el('button', {id: 'toon-update', type: 'button', hidden: ''}, 'มีเวอร์ชันใหม่ แตะเพื่ออัปเดต');
    updateButton.addEventListener('click', () => applyUpdate());
    document.body.append(pill, updateButton);
  }

  // ----- status line -------------------------------------------------------
  function cloud() {
    return safe(() => window.toonCloudStatus ? JSON.parse(window.toonCloudStatus()) : null, null);
  }
  function message() {
    const account = cloud();
    if (!state.online || (account && account.offline && account.pending)) {
      if (!state.ready && state.game !== 'playing' && CONFIG) return 'ออฟไลน์ – ยังโหลดเกมไม่ครบ ต่ออินเทอร์เน็ตเพื่อโหลดต่อ';
      return 'ออฟไลน์ – เซฟไว้ในเครื่อง จะซิงก์เมื่อออนไลน์';
    }
    if (state.sync) return state.sync;
    if (state.phase === 'filling' && state.total) {
      return 'กำลังเตรียมเล่นออฟไลน์ ' + Math.min(99, Math.floor(state.done * 100 / state.total)) + '%';
    }
    if (state.ready) return 'พร้อมเล่นออฟไลน์ ✓';
    return '';
  }
  let lastText = '';
  function render() {
    ui();
    if (!pill) return;
    const text = message();
    pill.dataset.state = !state.online ? 'offline' : state.ready ? 'ready' : state.phase;
    if (text !== lastText) {
      lastText = text;
      if (text) { state.shown.push(text); if (state.shown.length > 30) state.shown.shift(); }
      pillText.textContent = text;
      pill.hidden = !text;
      // While playing, a change is shown for a few seconds and then gets out of
      // the way; on the start screen the line stays.
      clearTimeout(hideTimer);
      if (text && state.game === 'playing') hideTimer = setTimeout(() => { pill.hidden = true; }, state.online ? 4000 : 8000);
    }
    updateButton.hidden = !state.update || applying;
  }
  function pollCloud() {
    const account = cloud();
    if (!account) return;
    const pending = !!(account.user && account.pending && !account.conflict);
    if (pending && state.online && account.syncing) state.sync = 'กำลังซิงก์เซฟ…';
    else if (!pending && wasPending && state.online) {
      state.sync = 'ซิงก์เซฟแล้ว ✓';
      setTimeout(() => { if (state.sync === 'ซิงก์เซฟแล้ว ✓') { state.sync = ''; render(); } }, 4000);
    } else if (state.sync === 'กำลังซิงก์เซฟ…' && !account.syncing) state.sync = '';
    wasPending = pending;
    render();
  }

  // ----- background fill ---------------------------------------------------
  function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }
  function waitOnline() {
    return state.online ? Promise.resolve() : new Promise(resolve => window.addEventListener('online', resolve, {once: true}));
  }
  function waitResume() {
    return state.paused ? new Promise(resolve => { resumeFill = resolve; }) : Promise.resolve();
  }
  async function download(cache, path, size) {
    const controller = new AbortController();
    abortFill = () => controller.abort();
    try {
      const response = await netFetch(path, {cache: 'reload', credentials: 'same-origin', signal: controller.signal, headers: {'X-Toon-Precache': '1'}});
      if (!response.ok || !response.body) throw new Error('HTTP ' + response.status);
      const base = state.done;
      let count = 0;
      const counted = response.body.pipeThrough(new TransformStream({
        transform(chunk, out) { count += chunk.byteLength; state.done = base + Math.min(count, size || count); render(); out.enqueue(chunk); },
        flush() { if (size && count !== size) throw new Error('ไฟล์ไม่ครบ'); },
      }));
      const headers = new Headers();
      const type = response.headers.get('content-type');
      if (type) headers.set('content-type', type);
      await cache.put(path, new Response(counted, {status: 200, headers}));
      state.done = base + (size || count);
    } finally { abortFill = null; }
  }
  async function swBuild(worker) {
    if (!worker) return '';
    return new Promise(resolve => {
      const channel = new MessageChannel();
      const timer = setTimeout(() => resolve(''), 3000);
      channel.port1.onmessage = event => { clearTimeout(timer); resolve(event.data && event.data.build || ''); };
      worker.postMessage({type: 'BUILD'}, [channel.port2]);
    });
  }
  async function fill() {
    const ready = await navigator.serviceWorker.ready;
    if (await swBuild(ready.active) !== CONFIG.build) { state.phase = 'other-build'; render(); return; }
    const cache = await caches.open(CACHE);
    state.total = CONFIG.total;
    async function scan() {
      const missing = [];
      let done = 0;
      for (const [path, size] of CONFIG.files) {
        if (await cache.match(path)) done += size; else missing.push([path, size]);
      }
      state.done = done;
      return missing;
    }
    for (;;) {
      const missing = await scan();
      if (!missing.length) break;
      state.phase = 'filling';
      render();
      for (const [path, size] of missing) {
        if (state.update) { state.phase = 'update'; render(); return; }
        if (state.paused) {
          // The game is downloading these files itself and the worker copies
          // them into the cache as they arrive: follow that, then look again.
          const timer = setInterval(() => { scan().then(render, () => {}); }, 1500);
          await waitResume();
          clearInterval(timer);
          break;
        }
        await waitOnline();
        if (await cache.match(path)) { state.done += size; continue; }
        for (let attempt = 0; ; attempt++) {
          try { await download(cache, path, size); break; }
          catch (error) {
            state.error = String(error && error.message || error);
            if (state.paused || state.update) break;
            await sleep(Math.min(30000, 2000 * 2 ** attempt));
            await waitOnline();
          }
        }
        render();
      }
    }
    state.phase = 'ready';
    state.ready = true;
    render();
  }
  function pauseFill() {
    state.paused = true;
    if (abortFill) abortFill();
  }
  function resume() {
    state.paused = false;
    if (resumeFill) { const go = resumeFill; resumeFill = null; go(); }
  }

  // ----- updates -----------------------------------------------------------
  function watch(worker) {
    if (!worker) return;
    const check = () => {
      if (worker.state === 'installed' && registration && registration.waiting === worker && hadController) offerUpdate();
    };
    worker.addEventListener('statechange', check);
    check();
  }
  function offerUpdate() {
    state.update = true;
    pauseFill();
    // Nothing is running yet (the start button was not tapped): take the new
    // build straight away instead of opening an old one.
    if (state.game === 'menu' && !interacted) { applyUpdate(); return; }
    render();
  }
  async function applyUpdate() {
    if (applying) return;
    const waiting = registration && registration.waiting;
    if (!waiting) { location.reload(); return; }
    applying = true;
    render();
    if (state.game !== 'menu') {
      // The game saves when it loses focus; give it and the save queue a moment.
      window.dispatchEvent(new Event('blur'));
      await sleep(1200);
      if (window.toonAccountsSettle) { try { await window.toonAccountsSettle(); } catch (_) {} }
    }
    waiting.postMessage({type: 'SKIP_WAITING'});
    setTimeout(() => location.reload(), 4000); // in case controllerchange never arrives
  }
  async function checkForUpdate() {
    if (!registration) return false;
    try { await registration.update(); } catch (_) {}
    return !!(registration.installing || registration.waiting);
  }

  // ----- storage -----------------------------------------------------------
  async function persist() {
    if (!navigator.storage || !navigator.storage.persist) return;
    try {
      state.persisted = await navigator.storage.persisted();
      if (!state.persisted) state.persisted = await navigator.storage.persist();
    } catch (_) {}
  }

  // ----- install hints -----------------------------------------------------
  function standalone() {
    return navigator.standalone === true || safe(() => matchMedia('(display-mode: standalone)').matches || matchMedia('(display-mode: fullscreen)').matches, false);
  }
  function iosHint() {
    const ua = navigator.userAgent || '';
    const ios = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    if (!ios || standalone() || safe(() => localStorage.getItem(HINT_KEY), '1')) return;
    safe(() => localStorage.setItem(HINT_KEY, String(Date.now())));
    const hint = el('div', {id: 'toon-install-hint', role: 'note'});
    hint.append(el('b', {}, 'เล่นได้แม้ไม่มีเน็ต (เช่นบนเครื่องบิน)'),
      el('span', {}, 'แตะปุ่มแชร์ของ Safari (สี่เหลี่ยมมีลูกศรขึ้น) แล้วเลือก “เพิ่มไปยังหน้าจอโฮม”'),
      // iOS keeps a home-screen app's files, login and saves apart from Safari's.
      el('span', {}, 'จากนั้นเปิดเกมจากไอคอนตอนยังมีเน็ต ล็อกอิน แล้วเปิดค้างไว้จนขึ้น “พร้อมเล่นออฟไลน์ ✓”'));
    const close = el('button', {type: 'button'}, 'เข้าใจแล้ว');
    close.addEventListener('click', () => hint.remove());
    hint.appendChild(close);
    document.body.appendChild(hint);
  }
  let installPrompt = null;
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    installPrompt = event;
    const card = document.querySelector('#loader .progress');
    if (!card || document.getElementById('toon-install')) return;
    const button = el('button', {id: 'toon-install', type: 'button'}, 'ติดตั้งลงเครื่อง (เล่นออฟไลน์ได้)');
    button.addEventListener('click', async () => {
      if (!installPrompt) return;
      installPrompt.prompt();
      try { await installPrompt.userChoice; } catch (_) {}
      installPrompt = null;
      button.remove();
    });
    card.appendChild(button);
  });

  // ----- start -------------------------------------------------------------
  function setOnline(online) {
    state.online = online;
    render();
  }
  window.addEventListener('online', () => setOnline(true));
  window.addEventListener('offline', () => setOnline(false));
  ['pointerdown', 'keydown'].forEach(name => document.addEventListener(name, () => { interacted = true; }, {capture: true, passive: true, once: true}));

  async function boot() {
    render();
    iosHint();
    setInterval(pollCloud, 1500);
    if (!CONFIG || !('serviceWorker' in navigator) || !window.isSecureContext || !('caches' in window)) { render(); return; }
    hadController = !!navigator.serviceWorker.controller;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      // First install: the worker only took control; that is not an update.
      if (!hadController) { hadController = true; return; }
      if (applying || state.game === 'menu') location.reload();
      else { state.update = true; render(); }
    });
    try {
      registration = await navigator.serviceWorker.register('sw.js', {scope: './', updateViaCache: 'none'});
    } catch (error) { state.phase = 'unsupported'; state.error = String(error); render(); return; }
    registration.addEventListener('updatefound', () => watch(registration.installing));
    if (registration.waiting && hadController) offerUpdate();
    watch(registration.installing);
    persist();
    // A home-screen app can stay open for days: look for a new build now and then.
    setInterval(() => { if (state.online && !state.update) checkForUpdate(); }, 30 * 60 * 1000);
    document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible' && state.online && !state.update) checkForUpdate(); });
    try { await fill(); }
    catch (error) { state.phase = 'error'; state.error = String(error && error.message || error); render(); }
  }

  window.toonOffline = {
    status: () => JSON.stringify(Object.assign({}, state, {build: CONFIG ? CONFIG.build : '', text: message()})),
    gameLoading() { state.game = 'loading'; interacted = true; pauseFill(); persist(); render(); },
    gameStarted() { state.game = 'playing'; lastText = ''; if (!state.update) resume(); render(); },
    gameStopped() { state.game = 'menu'; if (!state.update) resume(); render(); },
    checkForUpdate,
    applyUpdate,
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, {once: true});
  else boot();
}());
