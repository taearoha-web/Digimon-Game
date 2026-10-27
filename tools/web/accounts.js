/* Toon Tale accounts. Passwords stay in the form; sessions use server cookies.
 * Godot is started only after toonAccountsReady resolves. Game progress is
 * copied byte-for-byte as JSON, with compare-and-swap cloud revisions. */
(function () {
  'use strict';
  const FILE_ROOT = '/userfs/godot/app_userdata/Toon Tale';
  const CACHE_DB = 'toon_tale_accounts_v1';
  const CLASS_NAMES = {vagabond:'นักเดินทาง', warrior:'นักรบ', archer:'นักธนู', mage:'นักเวท', priest:'นักบวช', summoner:'นักอัญเชิญ', lancer:'นักหอก', lance:'นักหอก', defender:'สายโล่', assassin:'นักฆ่า', darklord:'ดาร์กลอร์ด'};
  // A request waits longer the more it carries: a full four-character save is
  // close to 1 MB and mobile uplinks are slow. 15 s, plus 1 s per 10 kB, at most 60 s.
  const REQUEST_TIMEOUT_MS = 15000, REQUEST_TIMEOUT_MAX_MS = 60000;
  const state = {user:null, revision:0, pending:false, conflict:false, offline:false, syncing:false, error:'', accountChanged:false, authExpired:false, panelOpen:false};
  let cacheDB, userFS, overlay, readyPromise, readyResolve, started = false;
  let draft = null, conflictSave = null, uploadPromise = null, saveTimer, initDone = false;
  let writeChain = Promise.resolve();
  let transitioning = false;
  const copy = value => JSON.parse(JSON.stringify(value));
  // Character slots per account (Game.SLOT_COUNT in the game, MAX_SLOTS on the server).
  const SLOT_COUNT = 10;
  const blank = () => ({slots:{}, selectedSlot:1});
  const identity = user => user ? 'account:' + user.id : 'guest';
  const equal = (a,b) => JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
  function canonical(value) {
    if (Array.isArray(value)) return value.map(canonical);
    if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
    return value;
  }
  function bundleOf(value) {
    if (typeof value === 'string') value = JSON.parse(value);
    if (!value || !value.slots || typeof value.slots !== 'object' || Array.isArray(value.slots)) throw new Error('รูปแบบเซฟไม่ถูกต้อง');
    const bundle = blank();
    for (let n = 1; n <= SLOT_COUNT; n++) {
      if (Object.prototype.hasOwnProperty.call(value.slots, String(n))) {
        const profile = value.slots[String(n)];
        if (!profile || typeof profile !== 'object' || Array.isArray(profile)) throw new Error('ข้อมูลตัวละครไม่ถูกต้อง');
        bundle.slots[String(n)] = copy(profile);
      }
    }
    if (Number.isInteger(value.selectedSlot) && value.selectedSlot >= 1 && value.selectedSlot <= SLOT_COUNT) bundle.selectedSlot = value.selectedSlot;
    return bundle;
  }
  function escaped(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  }
  function hasHeroes(bundle) { return Object.keys(bundle.slots).length > 0; }
  function newest(bundle) { return Math.max(0, ...Object.values(bundle.slots).map(p => Number(p.saved_at) || 0)); }
  function request(req) { return new Promise((resolve,reject) => { req.onsuccess = () => resolve(req.result); req.onerror = () => reject(req.error); }); }
  function completed(tx) { return new Promise((resolve,reject) => { tx.oncomplete = resolve; tx.onerror = () => reject(tx.error); tx.onabort = () => reject(tx.error || new Error('บันทึกในเครื่องไม่สำเร็จ')); }); }
  function openDB(name, version, upgrade) {
    return new Promise((resolve,reject) => {
      const req = version ? indexedDB.open(name,version) : indexedDB.open(name);
      req.onupgradeneeded = () => upgrade(req.result);
      req.onsuccess = () => { req.result.onversionchange = () => req.result.close(); resolve(req.result); };
      req.onerror = () => reject(req.error);
      req.onblocked = () => reject(new Error('กรุณาปิดเกมในแท็บอื่นแล้วเปิดใหม่'));
    });
  }
  async function storage(needFiles = false) {
    if (!cacheDB) cacheDB = await openDB(CACHE_DB,1,db => db.createObjectStore('records'));
    if (needFiles && !userFS) userFS = await openDB('/userfs',undefined,db => {
      const files = db.createObjectStore('FILE_DATA');
      files.createIndex('timestamp','timestamp',{unique:false});
    });
    if (needFiles && !userFS.objectStoreNames.contains('FILE_DATA')) throw new Error('ไม่พบพื้นที่เก็บเซฟของเกม');
  }
  async function read(key) {
    await storage();
    return request(cacheDB.transaction('records','readonly').objectStore('records').get(key));
  }
  async function write(key,value) {
    await storage();
    const tx = cacheDB.transaction('records','readwrite');
    tx.objectStore('records').put(copy(value),key);
    await completed(tx);
  }
  function queueWrite(key,value) {
    const snapshot = copy(value);
    writeChain = writeChain.catch(() => {}).then(() => write(key,snapshot));
    return writeChain;
  }
  async function getLocalBundle() {
    await storage(true);
    const names = Array.from({length:SLOT_COUNT},(_,i) => 'toon_tale_slot_' + (i+1) + '.json').concat('toon_tale_meta.json','toon_tale_save.json');
    const tx = userFS.transaction('FILE_DATA','readonly'), store = tx.objectStore('FILE_DATA');
    const rows = await Promise.all(names.map(name => request(store.get(FILE_ROOT + '/' + name))));
    const decoder = new TextDecoder(), bundle = blank();
    rows.slice(0,SLOT_COUNT).forEach((row,i) => {
      if (!row || !row.contents) return;
      try { const p = JSON.parse(decoder.decode(row.contents)); if (p && typeof p === 'object' && !Array.isArray(p)) bundle.slots[String(i+1)] = p; } catch (_) { /* Keep unreadable local files untouched until a choice is made. */ }
    });
    if (!bundle.slots['1'] && rows[SLOT_COUNT + 1] && rows[SLOT_COUNT + 1].contents) {
      try { bundle.slots['1'] = JSON.parse(decoder.decode(rows[SLOT_COUNT + 1].contents)); } catch (_) {}
    }
    try { const meta = JSON.parse(decoder.decode(rows[SLOT_COUNT].contents)); if (meta.slot >= 1 && meta.slot <= SLOT_COUNT) bundle.selectedSlot = meta.slot; } catch (_) {}
    return bundleOf(bundle);
  }
  async function installBundle(bundle) {
    // Only before Godot starts (or after a full page reload). Its in-memory
    // filesystem must never be changed beneath a running game.
    if (started) throw new Error('ต้องเปิดเกมใหม่เพื่อเปลี่ยนเซฟ');
    await storage(true);
    const tx = userFS.transaction('FILE_DATA','readwrite'), store = tx.objectStore('FILE_DATA');
    const now = new Date(), encoder = new TextEncoder();
    for (const path of ['/userfs','/userfs/godot','/userfs/godot/app_userdata',FILE_ROOT]) store.put({timestamp:now,mode:16877},path);
    for (let n = 1; n <= SLOT_COUNT; n++) {
      const path = FILE_ROOT + '/toon_tale_slot_' + n + '.json';
      if (bundle.slots[String(n)]) store.put({timestamp:now,mode:33188,contents:encoder.encode(JSON.stringify(bundle.slots[String(n)]))},path);
      else store.delete(path);
      store.delete(path + '.tmp');
    }
    store.delete(FILE_ROOT + '/toon_tale_save.json');
    store.put({timestamp:now,mode:33188,contents:encoder.encode(JSON.stringify({slot:bundle.selectedSlot}))},FILE_ROOT + '/toon_tale_meta.json');
    await completed(tx);
  }
  async function preserveActiveFiles() {
    const local = await getLocalBundle();
    const active = (await read('activeIdentity')) || 'guest';
    const old = await read(active);
    // The latest queued cloud draft may be ahead of Godot's asynchronous IDB
    // flush. Only recover files that are demonstrably newer than that draft.
    if (!old || (hasHeroes(local) && newest(local) > newest(old.bundle || blank()))) {
      await write(active,{bundle:local,revision:old ? old.revision : 0,dirty:active !== 'guest',savedAt:Date.now()});
    }
  }
  async function backup(owner,bundle,label) {
    const backups = (await read('backups:' + owner)) || [];
    backups.push({bundle:copy(bundle),label,savedAt:Date.now()});
    await write('backups:' + owner,backups.slice(-12));
  }
  async function acquireSaveLock() {
    if (!navigator.locks || !navigator.locks.request) return false;
    return new Promise(resolve => {
      navigator.locks.request('toon-tale-userfs',{ifAvailable:true},async lock => {
        if (!lock) { resolve(false); return; }
        resolve(true);
        // A live Godot instance owns one origin-wide IDB filesystem. Hold the
        // lock for this document's full lifetime, including background time.
        await new Promise(release => window.addEventListener('unload',release,{once:true}));
      }).catch(() => resolve(false));
    });
  }
  function accountChanged() {
    state.accountChanged = true; state.conflict = true; state.pending = !!(draft && draft.dirty);
    state.error = 'บัญชีถูกเปลี่ยนในอีกแท็บ เซฟของคุณยังเก็บไว้ในเครื่อง';
    panel('บัญชีเปลี่ยนในอีกแท็บ','<p class="ta-intro">' + escaped(state.error) + ' ปิดแท็บเกมอื่น แล้วเปิดหน้าล็อกอินใหม่เพื่อเลือกบัญชีที่ถูกต้อง</p>',[
      {label:'เปิดหน้าล็อกอินใหม่',run:async () => { transitioning = true; await writeChain; await write('forceGate',true); location.reload(); }},
      ...(started ? [{label:'กลับเข้าเกม เก็บเซฟไว้ในเครื่อง',kind:'secondary',run:closePanel}] : [])
    ]);
  }
  function sessionExpired() {
    state.authExpired = true; state.conflict = true; state.pending = !!(draft && draft.dirty);
    panel('เข้าสู่ระบบอีกครั้ง','<p class="ta-intro">หมดเวลาล็อกอินแล้ว ความคืบหน้าของคุณเก็บไว้ในเครื่อง เข้าบัญชีเดิมเพื่อส่งเซฟออนไลน์ต่อ</p>',[
      {label:'เข้าสู่ระบบอีกครั้ง',run:() => credentialsScreen()},
      ...(started ? [{label:'กลับเข้าเกม เก็บเซฟไว้ในเครื่อง',kind:'secondary',run:closePanel}] : [])
    ]);
  }
  async function api(path,options = {}) {
    const controller = new AbortController();
    const bodyBytes = typeof options.body === 'string' ? options.body.length : 0;
    const timeout = setTimeout(() => controller.abort(),Math.min(REQUEST_TIMEOUT_MAX_MS,REQUEST_TIMEOUT_MS + Math.ceil(bodyBytes / 10000) * 1000));
    try {
      const ownerHeader = /^(save|history|restore|logout)(?:\/|$)/.test(path) && state.user ? {'X-Toon-Account-ID':String(state.user.id)} : {};
      const response = await fetch('/api/account/' + path,{credentials:'same-origin',cache:'no-store',...options,signal:controller.signal,headers:{'Content-Type':'application/json',...ownerHeader,...(options.headers || {})}});
      const type = response.headers.get('content-type') || '';
      const data = type.includes('application/json') ? await response.json() : {};
      if (!response.ok) {
        const detail = data.error && typeof data.error === 'object' ? data.error : {};
        const serverMessage = detail.message || data.message || (typeof data.error === 'string' ? data.error : '');
        const error = new Error(serverMessage || 'ระบบบัญชีไม่พร้อมใช้งาน');
        error.status = response.status;
        error.code = detail.code || data.code || '';
        error.serverMessage = serverMessage;
        error.data = data;
        if (error.code === 'account_changed') accountChanged();
        else if (response.status === 401 && /^(save|history|restore|logout)(?:\/|$)/.test(path) && state.user) sessionExpired();
        throw error;
      }
      if (!type.includes('application/json')) throw new Error('ระบบบัญชีออนไลน์ยังไม่พร้อมใช้งาน');
      if (path === 'save' && (!options.method || options.method === 'GET') && state.user && String(data.userId) !== String(state.user.id)) {
        accountChanged(); const error = new Error(state.error); error.code = 'account_changed'; error.status = 409; throw error;
      }
      state.offline = false;
      return data;
    } catch (error) {
      if (!error.status && (error.name === 'AbortError' || error instanceof TypeError)) state.offline = true;
      throw error;
    } finally { clearTimeout(timeout); }
  }
  // "HTTP 400 invalid_save: The character field hp is invalid." — the server's
  // own words, so a refused save can be reported and fixed instead of guessed at.
  function serverDetail(error) {
    if (!error || !error.status) return '';
    return ' (HTTP ' + error.status + (error.code ? ' ' + error.code : '') + (error.serverMessage ? ': ' + error.serverMessage : '') + ')';
  }
  function thaiError(error) {
    if (!error) return 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ';
    if (error.name === 'QuotaExceededError') return 'พื้นที่เก็บข้อมูลในเครื่องไม่พอ กรุณาเพิ่มพื้นที่แล้วลองใหม่ เซฟเดิมจะไม่ถูกลบ';
    if (error.code === 'account_changed') return 'บัญชีถูกเปลี่ยนในอีกแท็บ เซฟในเครื่องยังอยู่ กรุณาเปิดหน้าล็อกอินใหม่';
    if (error.code === 'username_taken' || error.code === 'id_unavailable') return 'ไอดีนี้ถูกใช้แล้ว กรุณาเลือกไอดีอื่น';
    if (error.code === 'invalid_recovery') return 'ไอดีหรือรหัสกู้บัญชีไม่ถูกต้อง';
    if (error.code === 'invalid_credentials') return 'ไอดีหรือรหัสผ่านไม่ถูกต้อง';
    if (error.code === 'invalid_username') return 'ไอดีใช้ได้เฉพาะ a–z, 0–9 และ _ จำนวน 3–24 ตัว';
    if (error.code === 'invalid_password') return 'รหัสผ่านต้องยาว 10–128 ตัว';
    if (error.code === 'save_too_large') return 'เซฟมีขนาดเกินที่ระบบออนไลน์รองรับ เซฟในเครื่องยังอยู่' + serverDetail(error);
    if (error.code === 'invalid_save' || error.code === 'invalid_revision') return 'เซิร์ฟเวอร์ไม่รับเซฟนี้ เซฟในเครื่องยังอยู่ กรุณาแจ้งเจ้าของเกมพร้อมข้อความนี้' + serverDetail(error);
    if (error.code === 'save_conflict') return 'มีเซฟใหม่จากอีกเครื่อง เซฟในเครื่องยังอยู่' + serverDetail(error);
    if (error.status === 401) return 'ไอดีหรือรหัสผ่านไม่ถูกต้อง หรือหมดเวลาล็อกอินแล้ว';
    if (error.status === 409) return 'ไอดีนี้ถูกใช้แล้ว หรือมีเซฟใหม่จากอีกเครื่อง' + serverDetail(error);
    if (error.status === 429) return 'ลองบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่';
    if (error.status === 403) return 'เซิร์ฟเวอร์ไม่รับคำขอจากหน้านี้ กรุณาเปิดเกมจากเว็บไซต์หลัก' + serverDetail(error);
    if (error.status === 400) return 'เซิร์ฟเวอร์ไม่รับข้อมูลนี้' + serverDetail(error);
    if (error.status >= 500) return 'เซิร์ฟเวอร์ไม่พร้อม กรุณาลองอีกครั้ง เซฟในเครื่องยังอยู่' + serverDetail(error);
    if (error.status) return 'ระบบบัญชีตอบกลับผิดพลาด เซฟในเครื่องยังอยู่' + serverDetail(error);
    if (error.name === 'AbortError') return 'รอเซิร์ฟเวอร์นานเกินไป (เครือข่ายช้า) เซฟในเครื่องยังอยู่ กรุณาลองใหม่';
    if (state.offline || !navigator.onLine) return 'เชื่อมต่อไม่ได้ เซฟในเครื่องยังอยู่ กรุณาตรวจอินเทอร์เน็ต';
    return error.message || 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ';
  }
  function panel(title,body,buttons = [],opts = {}) {
    if (!overlay) {
      overlay = document.createElement('div'); overlay.id = 'toon-account-layer';
      document.body.appendChild(overlay);
      overlay.addEventListener('keydown',trapFocus);
    }
    state.panelOpen = true;
    window.dispatchEvent(new CustomEvent('toonaccountpanelchange',{detail:{open:true}}));
    overlay.hidden = false;
    overlay.innerHTML = '<section class="ta-card" role="dialog" aria-modal="true" aria-labelledby="ta-title">' +
      '<div class="ta-brand"><img src="./icon-512.png" alt="Toon Tale"><div><span class="ta-eyebrow">TOON TALE</span><p>การผจญภัยของคุณ ไปได้ทุกเครื่อง</p></div></div>' +
      '<h2 id="ta-title">' + escaped(title) + '</h2><div class="ta-body">' + body + '</div>' +
      '<p class="ta-feedback" role="status" aria-live="polite"></p><div class="ta-actions"></div>' +
      (opts.foot ? '<p class="ta-foot">' + opts.foot + '</p>' : '') + '</section>';
    const actions = overlay.querySelector('.ta-actions');
    buttons.forEach(spec => {
      const button = document.createElement('button'); button.type = 'button'; button.textContent = spec.label;
      button.className = 'ta-button ' + (spec.kind || 'primary');
      button.addEventListener('pointerdown',clearSelection); button.addEventListener('click',() => action(spec.run)); actions.appendChild(button);
    });
    requestAnimationFrame(() => { const el = overlay.querySelector(opts.focus || 'button,input'); if (el) el.focus({preventScroll:true}); });
    return overlay;
  }
  function trapFocus(event) {
    if (event.key !== 'Tab') return;
    const list = Array.from(overlay.querySelectorAll('button,input,select,textarea,[tabindex="0"]')).filter(el => !el.disabled && !el.hidden);
    if (list.length) {
      if (event.shiftKey && document.activeElement === list[0]) { event.preventDefault(); list[list.length-1].focus(); }
      else if (!event.shiftKey && document.activeElement === list[list.length-1]) { event.preventDefault(); list[0].focus(); }
    }
  }
  function feedback(text,isError = true) {
    const el = overlay && overlay.querySelector('.ta-feedback');
    if (el) { el.textContent = text; el.classList.toggle('error',isError); }
  }
  // iOS keeps a text selection alive over the dialog; its first tap on a button only
  // dismisses it, so drop any selection before running an action.
  function clearSelection() { const sel = window.getSelection && window.getSelection(); if (sel && sel.rangeCount) sel.removeAllRanges(); }
  async function action(fn) {
    const current = overlay;
    if (current) current.querySelectorAll('button').forEach(el => el.disabled = true);
    try { await fn(); }
    catch (error) { transitioning = false; state.error = thaiError(error); feedback(state.error); }
    finally { if (overlay === current && current) current.querySelectorAll('button').forEach(el => el.disabled = false); }
  }
  function closePanel() {
    if (overlay) overlay.hidden = true;
    state.panelOpen = false;
    window.dispatchEvent(new CustomEvent('toonaccountpanelchange',{detail:{open:false}}));
    const canvas = document.getElementById('canvas'); if (started && canvas) canvas.focus({preventScroll:true});
  }
  function summaries(bundle) {
    if (!hasHeroes(bundle)) return '<p class="ta-empty">ยังไม่มีตัวละคร</p>';
    return '<div class="ta-heroes">' + Object.entries(bundle.slots).map(([slot,p]) => '<div class="ta-hero"><span class="ta-slot">' + escaped(slot) + '</span><div><strong>' + escaped(p.name || 'นักผจญภัย') + '</strong><small>' + escaped(CLASS_NAMES[p.class] || p.class || 'ตัวละคร') + ' · เลเวล ' + escaped(p.level || 1) + '</small></div></div>').join('') + '</div>';
  }
  async function finish(user,bundle,revision,pending = false) {
    state.user = user; state.revision = revision; state.pending = pending; state.conflict = false; state.authExpired = false; state.accountChanged = false; state.error = '';
    draft = {bundle:copy(bundle),revision,dirty:pending,savedAt:Date.now()};
    await write(identity(user),draft);
    await write('stagedSwitch',{identity:identity(user),bundle});
    await installBundle(bundle);
    await write('activeIdentity',identity(user));
    await write('stagedSwitch',null);
    await write('lastUser',user);
    await write('guestMode',!user);
    await write('forceGate',false);
    if (userFS) { userFS.close(); userFS = null; }
    closePanel(); started = true;
    readyResolve();
    if (pending && navigator.onLine) scheduleUpload(500);
  }
  async function guest() {
    const cached = await read('guest');
    await finish(null,cached ? cached.bundle : blank(),0);
  }
  function credentialsScreen(mode = 'login') {
    const create = mode === 'register', reset = mode === 'reset-password';
    const title = create ? 'สร้างบัญชีผจญภัย' : reset ? 'ตั้งรหัสผ่านใหม่' : 'เข้าสู่เกมด้วยบัญชี';
    panel(title,'<p class="ta-intro">' + (create ? 'ใช้บัญชีนี้เล่นตัวละครเดิมต่อได้ทุกเครื่อง' : reset ? 'ใช้รหัสกู้บัญชีที่ได้รับตอนสมัคร' : 'ล็อกอินแล้วเล่นตัวละครเดิมต่อจากเซฟออนไลน์') + '</p>' +
      '<form id="ta-auth-form" autocomplete="on"><label class="ta-label" for="ta-username">ไอดี</label><input id="ta-username" name="username" autocomplete="username" autocapitalize="none" autocorrect="off" spellcheck="false" minlength="3" maxlength="24" required placeholder="เช่น toonhero17">' +
      (reset ? '<label class="ta-label" for="ta-recovery">รหัสกู้บัญชี</label><input id="ta-recovery" name="recoveryCode" autocomplete="off" autocapitalize="none" spellcheck="false" required>' : '') +
      '<label class="ta-label" for="ta-password">' + (reset ? 'รหัสผ่านใหม่' : 'รหัสผ่าน') + '</label><div class="ta-password"><input id="ta-password" name="password" type="password" autocomplete="' + (create || reset ? 'new-password' : 'current-password') + '" minlength="10" maxlength="128" required><button type="button" class="ta-eye" aria-label="แสดงรหัสผ่าน">แสดง</button></div>' +
      (create || reset ? '<label class="ta-label" for="ta-confirm">ยืนยันรหัสผ่าน</label><input id="ta-confirm" type="password" autocomplete="new-password" minlength="10" maxlength="128" required>' : '') +
      '<p class="ta-hint">ไอดี 3–24 ตัว: a–z, 0–9 หรือ _ · รหัสผ่านอย่างน้อย 10 ตัว</p><button class="ta-button primary ta-submit" type="submit">' + (create ? 'สร้างบัญชี' : reset ? 'บันทึกรหัสผ่านใหม่' : 'เข้าสู่ระบบ') + '</button></form>' +
      '<div class="ta-auth-links"><button type="button" data-screen="' + (create || reset ? 'login' : 'register') + '">' + (create || reset ? 'กลับเข้าสู่ระบบ' : 'สร้างบัญชีใหม่') + '</button>' + (!reset ? '<button type="button" data-screen="reset-password">ลืมรหัสผ่าน</button>' : '') + '</div>',
      [{label:started ? 'กลับเข้าเกม' : 'เล่นในเครื่องนี้ก่อน',kind:'secondary',run:started ? closePanel : guest}],
      {focus:'#ta-username',foot:'การเล่นในเครื่องเก็บตัวละครไว้ที่เครื่องนี้ คุณสามารถนำเข้าบัญชีภายหลังได้'});
    const form = overlay.querySelector('form');
    form.addEventListener('submit',event => { event.preventDefault(); action(async () => {
      if (!form.reportValidity()) return;
      const username = form.username.value.trim().toLowerCase(), password = form.password.value;
      if (!/^[a-z0-9_]{3,24}$/.test(username)) throw new Error('ไอดีใช้ได้เฉพาะ a–z, 0–9 และ _ จำนวน 3–24 ตัว');
      const confirm = form.querySelector('#ta-confirm');
      if (confirm && confirm.value !== password) throw new Error('รหัสผ่านทั้งสองช่องไม่ตรงกัน');
      feedback('กำลังเชื่อมต่อบัญชี…',false);
      const payload = {username,password}; if (reset) payload.recoveryCode = form.recoveryCode.value.trim();
      if (started) { transitioning = true; await writeChain; if (uploadPromise) await uploadPromise; }
      const result = await api(mode,{method:'POST',body:JSON.stringify(payload)});
      form.password.value = ''; if (confirm) confirm.value = '';
      if (result.recoveryCode) return showRecovery(result.user,result.recoveryCode);
      await authenticated(result.user);
    }); });
    overlay.querySelector('.ta-eye').addEventListener('click',event => { const input = form.password; input.type = input.type === 'password' ? 'text' : 'password'; event.target.textContent = input.type === 'password' ? 'แสดง' : 'ซ่อน'; event.target.setAttribute('aria-label',input.type === 'password' ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน'); });
    overlay.querySelectorAll('[data-screen]').forEach(button => button.addEventListener('click',() => credentialsScreen(button.dataset.screen)));
  }
  function showRecovery(user,code) {
    panel('เก็บรหัสกู้บัญชีของคุณ','<p class="ta-intro">บัญชี <strong>' + escaped(user.username) + '</strong> พร้อมแล้ว รหัสนี้ใช้ตั้งรหัสผ่านใหม่เมื่อลืมรหัสผ่าน ให้เก็บไว้ในที่ส่วนตัว</p><label class="ta-label" for="ta-code">รหัสกู้บัญชี (แสดงครั้งเดียว)</label><input id="ta-code" class="ta-recovery" readonly value="' + escaped(code) + '"><label class="ta-check"><input type="checkbox" id="ta-kept"> ฉันเก็บรหัสกู้บัญชีแล้ว</label>',[
      {label:'คัดลอกรหัส',kind:'secondary',run:async () => { const input = overlay.querySelector('#ta-code'); input.select(); if (navigator.clipboard && window.isSecureContext) await navigator.clipboard.writeText(code); else if (!document.execCommand('copy')) throw new Error('แตะรหัสค้างไว้แล้วเลือกคัดลอก'); const kept = overlay.querySelector('#ta-kept'); if (kept) kept.checked = true; feedback('คัดลอกแล้ว เก็บไว้ในที่ส่วนตัว',false); }},
      {label:'ไปต่อ',run:async () => { clearSelection(); if (!overlay.querySelector('#ta-kept').checked) throw new Error('กรุณาเก็บรหัสกู้บัญชี และติ๊กช่องยืนยันก่อน'); await authenticated(user); }}
    ]);
  }
  async function authenticated(user) {
    if (!user || !user.id || !user.username) throw new Error('ข้อมูลบัญชีไม่ถูกต้อง');
    user = {id:String(user.id),username:String(user.username)};
    if (started) { transitioning = true; await write('forceGate',false); await write('guestMode',false); location.reload(); return; }
    state.user = user;
    const cloud = await api('save');
    await chooseAccountSave(user,cloud);
  }
  async function chooseAccountSave(user,cloud) {
    const serverBundle = bundleOf(cloud.bundle || blank()), revision = Number(cloud.revision) || 0;
    const cached = await read(identity(user));
    state.user = user; state.revision = revision;
    if (cached && cached.dirty) {
      draft = cached;
      if (equal(cached.bundle,serverBundle)) return finish(user,serverBundle,revision);
      if (cached.revision === revision) {
        try {
          const result = await api('save',{method:'POST',body:JSON.stringify({expectedRevision:revision,bundle:cached.bundle})});
          return finish(user,cached.bundle,result.revision);
        } catch (error) {
          if (error.code === 'account_changed' || error.status === 401) return;
          if (error.status === 409) return showConflict(await api('save'),true);
          if (state.offline) return offerOffline(user,cached);
          // A refused upload (e.g. 400 invalid_save) must not strand the player
          // at the login form: show both saves with the server's reason, so they
          // can retry, keep playing from the online copy or report the message.
          return showConflict(cloud,true,thaiError(error));
        }
      }
      return showConflict(cloud,true);
    }
    const guestDraft = await read('guest'), guestBundle = guestDraft ? guestDraft.bundle : blank();
    if (!hasHeroes(serverBundle) && hasHeroes(guestBundle)) {
      panel('นำตัวละครเดิมเข้าบัญชี','<p class="ta-intro">บัญชี <strong>' + escaped(user.username) + '</strong> ยังไม่มีตัวละคร เลือกนำตัวละครในเครื่องนี้เข้าไป หรือเริ่มบัญชีใหม่ เซฟในเครื่องจะมีสำเนาแยกไว้</p>' + summaries(guestBundle),[
        {label:'นำตัวละครเหล่านี้เข้าบัญชี',run:async () => {
          await backup('guest',guestBundle,'นำเข้าบัญชี ' + user.username);
          try { const result = await api('save',{method:'POST',body:JSON.stringify({expectedRevision:revision,bundle:guestBundle})}); await finish(user,guestBundle,result.revision); }
          catch (error) { if (error.code === 'account_changed' || error.status === 401) return; if (error.status === 409) return chooseAccountSave(user,await api('save')); throw error; }
        }},
        {label:'เริ่มตัวละครใหม่ในบัญชีนี้',kind:'secondary',run:() => finish(user,serverBundle,revision)}
      ]);
      return;
    }
    if (hasHeroes(serverBundle)) {
      const buttons = [{label:'เล่นต่อจากเซฟออนไลน์',run:() => finish(user,serverBundle,revision)}];
      if (hasHeroes(guestBundle) && Object.keys(serverBundle.slots).length < SLOT_COUNT) buttons.push({label:'นำตัวละครในเครื่องเข้าช่องว่าง',kind:'secondary',run:() => importGuest(user,serverBundle,revision,guestBundle)});
      panel('ยินดีต้อนรับ ' + user.username,'<p class="ta-intro">ตัวละครในบัญชี พร้อมเล่นต่อบนเครื่องนี้</p>' + summaries(serverBundle),buttons,{foot:'เซฟในเครื่องและของบัญชีอื่นยังเก็บแยกไว้'});
      return;
    }
    await finish(user,serverBundle,revision);
  }
  function importGuest(user,serverBundle,revision,guestBundle) {
    const empty = Array.from({length:SLOT_COUNT},(_,i) => i + 1).filter(n => !serverBundle.slots[String(n)]);
    panel('เลือกตัวละครจากเครื่องนี้','<p class="ta-intro">นำเข้าได้ทีละตัว โดยใส่ช่องว่างของบัญชี ตัวละครออนไลน์เดิมจะไม่ถูกเขียนทับ</p>' + '<label class="ta-label" for="ta-import-source">ตัวละครในเครื่อง</label><select id="ta-import-source">' + Object.entries(guestBundle.slots).map(([slot,p]) => '<option value="' + slot + '">' + escaped(p.name || 'นักผจญภัย') + ' · เลเวล ' + escaped(p.level || 1) + '</option>').join('') + '</select><label class="ta-label" for="ta-import-target">ช่องว่างในบัญชี</label><select id="ta-import-target">' + empty.map(n => '<option value="' + n + '">ช่อง ' + n + '</option>').join('') + '</select>',[
      {label:'นำเข้าตัวละครที่เลือก',run:async () => {
        const source = overlay.querySelector('#ta-import-source').value, target = overlay.querySelector('#ta-import-target').value;
        const next = copy(serverBundle); next.slots[target] = copy(guestBundle.slots[source]); next.selectedSlot = Number(target);
        await backup(identity(user),serverBundle,'ก่อนนำเข้าตัวละคร');
        try { const result = await api('save',{method:'POST',body:JSON.stringify({expectedRevision:revision,bundle:next})}); await finish(user,next,result.revision); }
        catch (error) { if (error.code === 'account_changed') return; if (error.status === 409) { draft = {bundle:next,revision,dirty:true,savedAt:Date.now()}; await write(identity(user),draft); return showConflict(await api('save'),true); } throw error; }
      }},
      {label:'กลับ',kind:'secondary',run:() => chooseAccountSave(user,{bundle:serverBundle,revision})}
    ]);
  }
  function offerOffline(user,cached) {
    panel('เล่นต่อขณะออฟไลน์','<p class="ta-intro">เชื่อมต่อเซฟออนไลน์ไม่ได้ แต่เครื่องนี้มีตัวละครของ <strong>' + escaped(user.username) + '</strong> เมื่อออนไลน์จะตรวจเซฟจากอีกเครื่องก่อนอัปโหลด</p>' + summaries(cached.bundle),[
      {label:'เล่นเซฟของบัญชีในเครื่องนี้',run:() => finish(user,cached.bundle,cached.revision,!!cached.dirty)},
      {label:'ลองเชื่อมต่ออีกครั้ง',kind:'secondary',run:() => authenticated(user)},
      {label:'ใช้บัญชีอื่น / เล่นในเครื่อง',kind:'quiet',run:() => credentialsScreen()}
    ]);
  }
  // `note` is shown under the buttons: why the previous attempt did not go
  // through. Every failure here leaves the local save and its draft untouched.
  async function showConflict(cloud,beforeStart = false,note = '') {
    state.conflict = true; state.pending = true; conflictSave = cloud;
    if (note) state.error = note;
    const local = copy(draft.bundle), server = bundleOf(cloud.bundle || blank()), revision = Number(cloud.revision) || 0;
    panel('พบเซฟใหม่จากอีกเครื่อง','<p class="ta-intro">มีความคืบหน้าสองชุด กรุณาเลือกชุดที่จะเล่นต่อ ตัวละครและไอเทมจะใช้ทั้งชุด ไม่มีการรวมข้อมูลอัตโนมัติ สำเนาอีกชุดจะเก็บในเครื่องนี้</p><div class="ta-compare"><div><h3>ในเครื่องนี้</h3>' + summaries(local) + '</div><div><h3>ออนไลน์ล่าสุด</h3>' + summaries(server) + '</div></div>',[
      {label:'ใช้เซฟออนไลน์ล่าสุด',run:async () => {
        if (started) transitioning = true;
        await backup(identity(state.user),local,'ก่อนเลือกเซฟออนไลน์');
        draft = {bundle:server,revision,dirty:false,savedAt:Date.now()}; await write(identity(state.user),draft);
        state.conflict = false; state.pending = false; state.error = '';
        if (beforeStart) await finish(state.user,server,revision); else { await write('stagedSwitch',{identity:identity(state.user),bundle:server}); location.reload(); }
      }},
      {label:'ยืนยันใช้เซฟในเครื่องแทนออนไลน์',kind:'secondary',run:async () => {
        if (started) transitioning = true;
        feedback('กำลังส่งเซฟในเครื่องขึ้นออนไลน์…',false);
        await backup(identity(state.user),server,'ก่อนแทนเซฟออนไลน์ด้วยเซฟในเครื่อง');
        let result;
        try { result = await api('save',{method:'POST',body:JSON.stringify({expectedRevision:revision,bundle:local})}); }
        catch (error) {
          transitioning = false;
          if (error.code === 'account_changed' || error.status === 401) return;
          if (error.status === 409) {
            // The online copy moved again (another device is still uploading, or
            // this screen was stale). Re-read it and say so instead of a silent redraw.
            return showConflict(await api('save'),beforeStart,'ยังส่งไม่ได้: ออนไลน์มีเซฟใหม่กว่าอีกครั้ง ' + serverDetail(error).trim() + ' ถ้าอีกเครื่องยังเปิดเกมอยู่ ให้ปิดก่อน แล้วตรวจรายการด้านบนและกดยืนยันอีกครั้ง');
          }
          throw error;
        }
        draft = {bundle:local,revision:result.revision,dirty:false,savedAt:Date.now()}; await write(identity(state.user),draft);
        state.conflict = false; state.pending = false; state.error = '';
        if (beforeStart) await finish(state.user,local,result.revision); else { await write('stagedSwitch',{identity:identity(state.user),bundle:local}); location.reload(); }
      }},
      ...(beforeStart ? [{label:'เล่นเซฟในเครื่องก่อน ค่อยส่งออนไลน์ภายหลัง',kind:'quiet',run:() => finish(state.user,local,revision,true)}]
        : [{label:'กลับเข้าเกม เก็บเซฟไว้ในเครื่องก่อน',kind:'quiet',run:closePanel}])
    ],{foot:'เลือกเซฟในเครื่องจะแทนข้อมูลออนไลน์ล่าสุด โปรดตรวจชื่อและเลเวลก่อนยืนยัน'});
    if (note) feedback(note);
  }
  function scheduleUpload(delay = 1200) {
    clearTimeout(saveTimer);
    if (state.user && state.pending && !state.conflict) saveTimer = setTimeout(() => { flush().catch(() => {}); },delay);
  }
  async function flush() {
    clearTimeout(saveTimer);
    if (uploadPromise) return uploadPromise;
    if (!state.user || !state.pending || state.conflict || !draft || !navigator.onLine) { if (!navigator.onLine) state.offline = true; return; }
    uploadPromise = (async () => {
      state.syncing = true;
      let lastOutgoing = null;
      try {
        while (state.pending && !state.conflict && navigator.onLine) {
          const outgoing = copy(draft.bundle), expectedRevision = state.revision;
          lastOutgoing = outgoing;
          await writeChain;
          const result = await api('save',{method:'POST',body:JSON.stringify({expectedRevision,bundle:outgoing})});
          state.revision = result.revision; state.error = '';
          const unchanged = equal(outgoing,draft.bundle);
          draft = {bundle:copy(draft.bundle),revision:result.revision,dirty:!unchanged,savedAt:Date.now()};
          state.pending = !unchanged;
          await queueWrite(identity(state.user),draft);
        }
      } catch (error) {
        state.error = thaiError(error);
        if (error.code === 'account_changed' || error.status === 401) return;
        if (error.status === 409) {
          try {
            const latest = await api('save');
            const server = bundleOf(latest.bundle || blank());
            if (equal(server,draft.bundle) || (lastOutgoing && equal(server,lastOutgoing))) {
              const same = equal(server,draft.bundle);
              state.revision = latest.revision; state.pending = !same; state.error = '';
              draft = {bundle:copy(draft.bundle),revision:latest.revision,dirty:!same,savedAt:Date.now()};
              await queueWrite(identity(state.user),draft);
              if (!same) scheduleUpload(100);
            } else { state.conflict = true; await showConflict(latest); }
          } catch (_) { state.conflict = true; conflictSave = null; }
        }
        if (state.pending && !state.conflict) scheduleUpload(30000);
        // Network failures retain the draft and retry on reconnect, never with
        // a server revision that was not actually acknowledged.
      } finally { state.syncing = false; uploadPromise = null; }
    })();
    return uploadPromise;
  }
  window.toonCloudSave = function (serializedBundle) {
    try {
      const bundle = bundleOf(serializedBundle);
      if (!initDone || transitioning) return;
      if (!state.user) { draft = {bundle,revision:0,dirty:false,savedAt:Date.now()}; queueWrite('guest',draft).catch(error => { state.error = thaiError(error); }); return; }
      draft = {bundle,revision:state.revision,dirty:true,savedAt:Date.now()};
      state.pending = true;
      queueWrite(identity(state.user),draft).catch(error => { state.error = thaiError(error); });
      scheduleUpload();
    } catch (error) { state.error = thaiError(error); }
  };
  async function logout() {
    feedback('กำลังบันทึกก่อนออกจากบัญชี…',false);
    await writeChain;
    if (state.pending && !state.conflict && navigator.onLine) await flush();
    if (state.pending || state.conflict) {
      panel('มีเซฟที่ยังไม่ส่งออนไลน์','<p class="ta-intro">ความคืบหน้าของ <strong>' + escaped(state.user.username) + '</strong> เก็บอยู่ในเครื่องนี้ หากออกตอนนี้ เครื่องอื่นจะยังไม่เห็นเซฟล่าสุด ล็อกอินบัญชีเดิมบนเครื่องนี้เพื่อส่งเซฟภายหลังได้</p>',[
        {label:'กลับเข้าเกม รอส่งเซฟก่อน',run:closePanel},
        {label:'ออกโดยเก็บเซฟค้างส่งไว้ในเครื่อง',kind:'secondary',run:() => completeLogout(true)}
      ]); return;
    }
    await completeLogout(false);
  }
  async function completeLogout(allowOffline) {
    transitioning = true;
    await writeChain;
    try { await api('logout',{method:'POST',body:'{}'}); }
    catch (error) { if (!allowOffline) throw error; }
    await write('forceGate',true);
    await write('lastUser',null);
    location.reload();
  }
  async function backupPanel() {
    const owner = identity(state.user), copies = (await read('backups:' + owner)) || [];
    if (!copies.length) {
      panel('สำเนาเซฟในเครื่อง','<p class="ta-intro">ยังไม่มีสำเนาย้อนหลัง สำเนาจะเก็บเมื่อเลือกแก้เซฟสองชุดหรือนำเข้าตัวละคร</p>',[{label:'กลับ',run:window.toonOpenAccountPanel}]);
      return;
    }
    const buttons = copies.slice().reverse().map(entry => ({
      label:entry.label + ' · ' + new Date(entry.savedAt).toLocaleDateString('th-TH'),kind:'secondary',
      run:async () => {
        if (uploadPromise) await uploadPromise;
        let current = draft ? draft.bundle : blank(), revision = state.revision;
        if (state.user && navigator.onLine) {
          const cloud = await api('save'); current = bundleOf(cloud.bundle || blank()); revision = cloud.revision;
        }
        panel('ตรวจสำเนาก่อนนำกลับมาใช้','<p class="ta-intro">เลือกสำเนานี้จะแทนตัวละครทั้ง ' + SLOT_COUNT + ' ช่องของ ' + escaped(state.user ? state.user.username : 'เซฟในเครื่อง') + ' จะเก็บชุดปัจจุบันเป็นสำเนาก่อน แล้วเปิดเกมใหม่</p><div class="ta-compare"><div><h3>ชุดปัจจุบัน</h3>' + summaries(current) + '</div><div><h3>สำเนาที่เลือก</h3>' + summaries(entry.bundle) + '</div></div>',[
          {label:'ยืนยันใช้สำเนานี้และเปิดใหม่',run:async () => {
            transitioning = true; await writeChain;
            await backup(owner,current,'ก่อนนำสำเนากลับมาใช้');
            const selected = bundleOf(entry.bundle);
            await write(owner,{bundle:selected,revision,dirty:!!state.user,savedAt:Date.now()});
            await write('stagedSwitch',{identity:owner,bundle:selected});
            // On the next gate, the normal revision check handles an update
            // made on another device while this review was open.
            location.reload();
          }},
          {label:'กลับ',kind:'secondary',run:backupPanel}
        ]);
      }
    }));
    panel('สำเนาเซฟในเครื่อง','<p class="ta-intro">เลือกดูตัวละครก่อนนำกลับมาใช้ สำเนาแยกตามบัญชี และเก็บล่าสุดได้ 12 ชุดบนเครื่องนี้</p>',buttons.concat([{label:'กลับ',kind:'quiet',run:window.toonOpenAccountPanel}]));
  }
  window.toonOpenAccountPanel = function () {
    if (!initDone || transitioning) return;
    if (state.accountChanged) { accountChanged(); return; }
    if (state.authExpired) { sessionExpired(); return; }
    const current = state.user;
    const status = state.conflict ? 'มีเซฟสองชุด รอเลือกความคืบหน้า' : state.pending ? (state.offline ? 'ออฟไลน์ · เก็บเซฟไว้ในเครื่อง รอส่งออนไลน์' : 'กำลังรอส่งเซฟล่าสุดออนไลน์') : current ? 'เซฟออนไลน์พร้อมเล่นต่อบนเครื่องอื่น' : 'เซฟอยู่ในเครื่องนี้';
    panel(current ? 'บัญชี ' + current.username : 'เล่นในเครื่องนี้','<p class="ta-status-line"><span class="ta-status-dot ' + (state.conflict || state.pending ? 'pending' : '') + '"></span>' + escaped(status) + '</p>' + (state.error ? '<p class="ta-hint">' + escaped(state.error) + '</p>' : '') + (draft ? summaries(draft.bundle) : ''),[
      {label:'กลับเข้าเกม',run:closePanel},
      {label:'สำเนาเซฟในเครื่อง',kind:'secondary',run:backupPanel},
      ...(current ? [
        {label:state.conflict ? 'เลือกเซฟที่จะใช้' : 'ส่งเซฟออนไลน์ตอนนี้',kind:'secondary',run:async () => { if (state.conflict) await showConflict(conflictSave || await api('save')); else { await flush(); if (!state.panelOpen || state.conflict) return; feedback(state.pending ? state.error || 'ยังส่งไม่ได้ เซฟในเครื่องยังอยู่' : 'บันทึกออนไลน์แล้ว',state.pending); } }},
        {label:'ออกจากบัญชี / เปลี่ยนบัญชี',kind:'quiet',run:logout}
      ] : [{label:'เข้าสู่ระบบ / สร้างบัญชี',kind:'secondary',run:() => credentialsScreen()}])
    ]);
  };
  window.toonCloudStatus = () => JSON.stringify({...state,modalOpen:state.panelOpen,user:state.user ? {id:state.user.id,username:state.user.username} : null});
  window.toonCloudModalOpen = () => state.panelOpen;
  window.toonAccountsReady = function () {
    if (readyPromise) return readyPromise;
    readyPromise = new Promise(resolve => { readyResolve = resolve; });
    (async () => {
      panel('เตรียมการผจญภัย','<p class="ta-intro">กำลังตรวจบัญชีและสำรองตัวละครในเครื่อง…</p>');
      try {
        if (!await acquireSaveLock()) {
          panel('เกมเปิดอยู่ในแท็บอื่น','<p class="ta-intro">กรุณาปิดเกมในแท็บหรือหน้าต่างอื่นก่อน เพื่อป้องกันตัวละครของแต่ละบัญชีเขียนทับกัน หากเบราว์เซอร์นี้ไม่รองรับระบบล็อกเซฟ ให้เปิดด้วย Safari รุ่นปัจจุบัน</p>',[{label:'ปิดแท็บอื่นแล้ว ลองใหม่',run:() => location.reload()}]);
          return;
        }
        await storage();
        const staged = await read('stagedSwitch');
        if (staged) { await installBundle(bundleOf(staged.bundle)); await write('activeIdentity',staged.identity); await write('stagedSwitch',null); }
        await preserveActiveFiles(); initDone = true;
        if (await read('forceGate') || await read('guestMode')) return credentialsScreen();
        try {
          const session = await api('session');
          if (session.user) return await authenticated(session.user);
          credentialsScreen();
        } catch (error) {
          if (error.code === 'account_changed') return;
          state.error = thaiError(error);
          const last = await read('lastUser');
          const cached = last && await read(identity(last));
          if (state.offline && last && cached) offerOffline(last,cached);
          else { credentialsScreen(); feedback(state.error); }
        }
      } catch (error) {
        panel('ยังเปิดเซฟในเครื่องไม่ได้','<p class="ta-intro">' + escaped(thaiError(error)) + '</p><p class="ta-hint">เซฟเดิมจะไม่ถูกลบ กรุณาปิดแท็บเกมอื่น ตรวจว่าพื้นที่จัดเก็บของ Safari เปิดใช้งาน แล้วลองใหม่</p>',[{label:'ลองใหม่',run:() => location.reload()}]);
      }
    })();
    return readyPromise;
  };
  window.addEventListener('online',() => { state.offline = false; scheduleUpload(100); });
  window.addEventListener('offline',() => { state.offline = true; });
  document.addEventListener('visibilitychange',() => { if (document.visibilityState === 'hidden') flush().catch(() => {}); });
})();
