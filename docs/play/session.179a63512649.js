/* Small, local-only session record. Never stores accounts, inventory or saves. */
(function () {
  'use strict';
  const KEY = 'toon_session_v1', PREVIOUS = KEY + '_previous';
  const MAX_SAMPLES = 60, MAX_EVENTS = 24, MAX_BYTES = 24000;
  let current = null, timer = null, heap = () => null, metrics = {}, wake = null;
  let wakePending = false, reportOpen = false, metricsAt = 0, pendingError = null;
  let previousFrame = null, raf = null, lastWasm = null;
  let frames = {count: 0, over50: 0, over100: 0, maxMs: 0};
  function read(key) {
    try {
      const raw = localStorage.getItem(key);
      if (!raw || raw.length > MAX_BYTES) return null;
      const data = JSON.parse(raw);
      return data.schema === 1 && Array.isArray(data.samples) && Array.isArray(data.events) ? data : null;
    } catch (_) { return null; }
  }
  const interrupted = read(KEY);
  let previous = interrupted && ['running', 'hidden', 'page_hidden'].includes(interrupted.status) ? interrupted : read(PREVIOUS);
  function persist() {
    if (!current) return;
    try {
      let raw = JSON.stringify(current);
      while (raw.length > MAX_BYTES && current.samples.length > 1) {
        current.samples.shift(); raw = JSON.stringify(current);
      }
      if (raw.length <= MAX_BYTES) localStorage.setItem(KEY, raw);
    } catch (_) { /* Storage restrictions must never stop gameplay. */ }
  }
  function event(type, details = {}) {
    if (!current) return;
    const item = { seconds: Math.round((Date.now() - current.startedAt) / 1000), type, ...details };
    current.events.push(item);
    if (current.events.length > MAX_EVENTS) current.events.shift();
    return item;
  }
  function snapshot() {
    if (!current) return;
    let wasmBytes = null;
    try { const n = heap(); if (Number.isFinite(n) && n > 0) wasmBytes = n; } catch (_) {}
    // The game's memory only grows (an iPhone report closed soon after 166 -> 199 MB):
    // each step is kept as an event with what the game was doing.
    if (wasmBytes !== null && lastWasm !== null && wasmBytes > lastWasm)
      event('wasm_grow', { fromMB: Math.round(lastWasm / 1048576), toMB: Math.round(wasmBytes / 1048576), ...(metrics.zone ? { zone: metrics.zone } : {}) });
    if (wasmBytes !== null) lastWasm = wasmBytes;
    const canvas = document.getElementById('canvas');
    current.samples.push({ seconds: Math.round((Date.now() - current.startedAt) / 1000),
      visibility: document.visibilityState, wasmBytes, width: canvas.width, height: canvas.height, ...metrics,
      metricsAgeSeconds: metricsAt ? Math.round((Date.now() - metricsAt) / 1000) : null,
      frameCount: frames.count, framesOver50: frames.over50, framesOver100: frames.over100,
      maxFrameMs: Math.round(frames.maxMs) });
    frames = {count: 0, over50: 0, over100: 0, maxMs: 0};
    if (current.samples.length > MAX_SAMPLES) current.samples.shift();
    current.lastSeenAt = Date.now();
    persist();
  }
  // Store a fixed category, never error text that could contain credentials or save data.
  function errorCategory(value) {
    const message = String(value || '');
    if (/out of memory|cannot enlarge memory|allocation failed/i.test(message)) return 'memory_allocation_error';
    if (/memory access out of bounds/i.test(message)) return 'wasm_bounds_error';
    if (/unreachable|runtimeerror|abort\(/i.test(message)) return 'runtime_abort';
    if (/^\s*WARNING:/i.test(message)) return 'engine_warning';
    if (/^\s*(?:USER )?SCRIPT ERROR:/i.test(message)) return 'script_error';
    // Release builds prefix a script's own runtime faults with "USER ERROR:".
    if (/^\s*USER ERROR:/i.test(message)) return 'script_runtime_error';
    if (/^\s*ERROR:/i.test(message)) return 'engine_error';
    return 'runtime_error';
  }
  // Keep only fixed issue codes and engine/project source locations. Never
  // store raw messages, identifiers, URLs, query strings, stacks or save data.
  function safeIssue(message) {
    for (const [pattern, code] of [
      [/Lambda capture .{0,20} was freed/i, 'freed_capture'],
      [/previously freed|freed instance/i, 'freed_instance'],
      [/!is_inside_tree|outside.*scene tree/i, 'outside_tree'],
      [/null instance|Parameter .{0,40} is null/i, 'null_instance'],
      [/invalid (?:access|assignment).*?(?:index|key|property)/i, 'invalid_property'],
      [/invalid call|nonexistent function/i, 'invalid_call'],
      [/shader.*(?:error|failed)|failed.*shader/i, 'shader_error'],
      [/WebGL|GL_INVALID|Framebuffer/i, 'graphics_error'],
    ]) if (pattern.test(message)) return code;
    return null;
  }
  function safeLocation(message) {
    const path = message.match(/res:\/\/((?:characters|combat|data|monsters|scenes|systems|ui|vfx|world)\/[a-z0-9_\/]{1,120}\.gd):([0-9]{1,6})/i);
    if (path) return {file: 'res://' + path[1], line: Number(path[2])};
    const native = message.match(/\(((?:scene|servers|core|drivers|platform|modules|main)\/[a-z0-9_\/]{1,160}\.(?:cpp|h)):([0-9]{1,6})\)/i);
    return native ? {file: native[1], line: Number(native[2])} : {};
  }
  // Engine function that reported the fault ("at: get_path (scene/main/node.cpp:835)"):
  // a fixed identifier of the engine, never a message, node name or save value.
  function safeFunction(message) {
    const m = message.match(/^\s*at:\s+([A-Za-z_][A-Za-z0-9_:~]{0,60})\s*\(/);
    return m ? m[1] : null;
  }
  function recordError(value) {
    if (!current) return;
    const message = String(value || '').slice(0, 4096), location = safeLocation(message);
    // Godot prints a fault and its "at:" location as separate callbacks.
    if (/^\s*at:/.test(message) && pendingError && Date.now() - pendingError.at <= 2000) {
      Object.assign(pendingError.item, location);
      const fn = safeFunction(message);
      if (fn) pendingError.item.fn = fn;
      persist(); return;
    }
    // A GDScript backtrace line ("[0] func _x (res://combat/a.gd:12)") names the game
    // code that triggered the fault. Keep only the first one: file and line.
    if (/^\s*(?:GDScript backtrace.*|\[\d+\]\s+.*)$/.test(message) && pendingError && Date.now() - pendingError.at <= 2000) {
      if (!pendingError.item.script && location.file && location.file.startsWith('res://')) {
        pendingError.item.script = {file: location.file, line: location.line}; persist();
      }
      return;
    }
    const category = errorCategory(message), issue = safeIssue(message);
    // A shader that failed to compile is named in the engine's own message (the shader's
    // name and the GLSL line): keep the first few such lines, nothing else.
    if ((issue === 'shader_error' || issue === 'graphics_error') && current) {
      const line = message.replace(/\s+/g, ' ').replace(/[^\x20-\x7E]/g, '?').slice(0, 220);
      current.graphicsErrors = current.graphicsErrors || [];
      if (current.graphicsErrors.length < 8 && !current.graphicsErrors.includes(line)) current.graphicsErrors.push(line);
    }
    if (category === 'engine_warning') current.warningCount = (current.warningCount || 0) + 1;
    else { current.lastErrorCategory = category; current.errorCount = (current.errorCount || 0) + 1; }
    const last = current.events.at(-1);
    let item;
    if (last && last.type === category && (last.issue || null) === issue &&
        (last.file || null) === (location.file || null) && last.seconds === Math.round((Date.now() - current.startedAt) / 1000)) {
      item = last; item.count = (item.count || 1) + 1;
    } else item = event(category, {...(issue ? {issue} : {}), ...location});
    pendingError = {item, at: Date.now()};
    persist();
  }
  function frame(timestamp) {
    if (!current || current.status === 'ended') return;
    if (document.visibilityState === 'visible' && !reportOpen &&
        !(typeof window.toonCloudModalOpen === 'function' && window.toonCloudModalOpen())) {
      if (previousFrame !== null) {
        const delta = timestamp - previousFrame;
        if (Number.isFinite(delta) && delta >= 0) {
          frames.count++; frames.maxMs = Math.max(frames.maxMs, delta);
          if (delta > 50) frames.over50++;
          if (delta > 100) frames.over100++;
        }
      }
      previousFrame = timestamp;
    } else previousFrame = null;
    raf = window.requestAnimationFrame(frame);
  }
  async function keepAwake() {
    if (!current || current.status !== 'running' || document.visibilityState !== 'visible' || wake || wakePending || !navigator.wakeLock) return;
    wakePending = true;
    try {
      const requested = await navigator.wakeLock.request('screen');
      if (document.visibilityState !== 'visible' || current.status !== 'running') { await requested.release(); return; }
      wake = requested;
      wake.addEventListener('release', () => { if (wake === requested) wake = null; });
    } catch (_) { /* Optional: battery policy and older iOS may deny a wake lock. */ }
    finally { wakePending = false; }
  }
  function releaseWake() {
    if (wake) { const held = wake; wake = null; held.release().catch(() => {}); }
  }
  // Pasted reports get cut short by chat apps, so the facts that explain an
  // interruption come first: how it ended, its errors, and its last minutes.
  const mb = (bytes) => Number.isFinite(bytes) ? Math.round(bytes / 1048576) + 'M' : '-';
  // The device's WebGL limits and renderer name (a flat 3D world on one phone and not
  // another is often a limit the scene shader runs into there).
  function webglFacts() {
    try {
      const probe = document.createElement('canvas');
      const gl = probe.getContext('webgl2');
      if (!gl) return { webgl2: false };
      const info = gl.getExtension('WEBGL_debug_renderer_info');
      const facts = { webgl2: true,
        renderer: String(info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER)).slice(0, 80),
        maxTextureSize: gl.getParameter(gl.MAX_TEXTURE_SIZE), maxTextureUnits: gl.getParameter(gl.MAX_TEXTURE_IMAGE_UNITS),
        maxVertexTextureUnits: gl.getParameter(gl.MAX_VERTEX_TEXTURE_IMAGE_UNITS),
        maxVaryings: gl.getParameter(gl.MAX_VARYING_VECTORS), maxVertexUniforms: gl.getParameter(gl.MAX_VERTEX_UNIFORM_VECTORS),
        maxFragmentUniforms: gl.getParameter(gl.MAX_FRAGMENT_UNIFORM_VECTORS), maxUniformBlockSize: gl.getParameter(gl.MAX_UNIFORM_BLOCK_SIZE),
        maxSamples: gl.getParameter(gl.MAX_SAMPLES), maxRenderbufferSize: gl.getParameter(gl.MAX_RENDERBUFFER_SIZE),
        floatColorBuffer: !!gl.getExtension('EXT_color_buffer_float'), floatLinear: !!gl.getExtension('OES_texture_float_linear') };
      const lose = gl.getExtension('WEBGL_lose_context');
      if (lose) lose.loseContext();
      return facts;
    } catch (_) { return { webgl2: null }; }
  }
  function summary(record) {
    if (!record) return null;
    const last = record.samples.at(-1), first = record.samples[0];
    return { version: record.version, ios: record.ios, standalone: record.standalone, status: record.status,
      webgl: record.webgl || null, graphicsErrors: record.graphicsErrors || [],
      seconds: Math.round((record.lastSeenAt - record.startedAt) / 1000),
      errorCount: record.errorCount || 0, warningCount: record.warningCount || 0, lastErrorCategory: record.lastErrorCategory || null,
      contextLost: record.contextLost === true, events: record.events,
      firstSample: first || null, lastSamples: record.samples.slice(-5),
      // One short line per sample: the whole session's trend in a few hundred bytes.
      timeline: record.samples.map(s => `${s.seconds}s wasm=${mb(s.wasmBytes)} video=${mb(s.videoBytes)} obj=${s.objects ?? '-'} nodes=${s.nodes ?? '-'} fps=${s.fps ?? '-'} maxMs=${s.maxFrameMs ?? '-'} p=${s.pressure ?? '-'} ${s.flatScreens || s.starvedFrames ? 'flat=' + (s.flatScreens ?? 0) + ' starved=' + (s.starvedFrames ?? 0) + ' fb=' + (s.renderFallback ?? 0) + ' ' : ''}${s.camOwn === 0 ? 'cam=foreign ' : ''}${s.hot ? 'hot ' : ''}${s.paused ? 'paused ' : ''}${s.heroDead ? 'dead ' : ''}${s.screenOpen ? 'screen ' : ''}${s.audioStallSeconds > 1 ? 'nosound ' : ''}${s.visibility === 'visible' ? '' : s.visibility + ' '}${s.zone || ''}`),
      pressureRaises: last ? (last.pressureRaises ?? null) : null,
      growth: first && last && last !== first ? { seconds: last.seconds - first.seconds, wasmBytes: (last.wasmBytes || 0) - (first.wasmBytes || 0),
        videoBytes: (last.videoBytes || 0) - (first.videoBytes || 0), nodes: (last.nodes || 0) - (first.nodes || 0),
        objects: (last.objects || 0) - (first.objects || 0), resources: (last.resources || 0) - (first.resources || 0) } : null };
  }
  function report() {
    return JSON.stringify({ note: 'An interrupted record does not prove an out-of-memory crash. Reports stay on this device until shared.',
      previousSummary: summary(previous), previousSession: previous, currentSession: current }, null, 2);
  }
  function showReport() {
    if (reportOpen) return;
    reportOpen = true;
    const overlay = document.createElement('div');
    overlay.className = 'toon-report';
    const panel = document.createElement('div');
    const title = document.createElement('h2');
    title.textContent = 'รายงานการหลุด';
    const note = document.createElement('p');
    note.textContent = 'เก็บข้อมูลการทำงานบนเครื่องนี้ ไม่มีรหัสผ่านหรือข้อมูลตัวละคร กดคัดลอกแล้วส่งรายงานนี้ให้ผู้พัฒนา';
    const text = document.createElement('textarea');
    text.readOnly = true; text.value = report(); text.setAttribute('aria-label', 'รายงานการทำงาน');
    const copy = document.createElement('button');
    copy.textContent = 'คัดลอกรายงาน';
    copy.onclick = async () => {
      try { await navigator.clipboard.writeText(text.value); copy.textContent = 'คัดลอกแล้ว'; }
      catch (_) { text.focus(); text.select(); copy.textContent = 'กดค้างที่ข้อความเพื่อคัดลอก'; }
    };
    const close = document.createElement('button');
    close.textContent = 'ปิด';
    close.onclick = () => { overlay.remove(); reportOpen = false; };
    panel.append(title, note, text, copy, close); overlay.append(panel); document.body.append(overlay);
    overlay.setAttribute('role', 'dialog'); overlay.setAttribute('aria-modal', 'true');
    close.focus();
  }
  window.toonSession = {
    begin(version, readHeap) {
      if (current) return;
      heap = readHeap;
      if (previous) { try { localStorage.setItem(PREVIOUS, JSON.stringify(previous)); } catch (_) {} }
      const ios = (navigator.userAgent || '').match(/OS (\d+[_\.]\d+(?:[_\.]\d+)?)/);
      current = { schema: 1, version, startedAt: Date.now(), lastSeenAt: Date.now(), status: document.visibilityState === 'hidden' ? 'hidden' : 'running',
        ios: ios ? ios[1].replaceAll('_', '.') : null,
        standalone: navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches,
        samples: [], events: [] };
      const navigation = window.performance?.getEntriesByType?.('navigation')?.[0]?.type;
      if (['navigate', 'reload', 'back_forward'].includes(navigation)) current.navigationType = navigation;
      current.wasDiscarded = document.wasDiscarded === true;
      current.diagnostics = 3;
      current.webgl = webglFacts();
      event('started'); snapshot(); timer = setInterval(snapshot, 30000); keepAwake();
      if (window.requestAnimationFrame) raf = window.requestAnimationFrame(frame);
    },
    sample(raw) {
      try {
        const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
        // An allowlist prevents this hook from copying any player/profile data.
        metrics = {}; metricsAt = Date.now();
        for (const key of ['staticBytes', 'videoBytes', 'nodes', 'objects', 'resources', 'orphans', 'loot', 'quality', 'fps', 'auto', 'kills', 'saveAgeSeconds', 'drawCalls', 'triangles', 'renderObjects', 'processMs', 'physicsMs', 'soundPlayRequests', 'audioStreamMode', 'audioStallSeconds', 'paused', 'heroDead', 'screenOpen', 'hot']) {
          if (typeof data[key] === 'boolean' || (typeof data[key] === 'number' && Number.isFinite(data[key]) && data[key] >= 0)) metrics[key] = data[key];
        }
        for (const key of ['towerFloor', 'pendingSpawns', 'spawnWorkMs', 'spawnPeakMs', 'saveWorkMs', 'savePeakMs', 'pressure', 'pressureRaises', 'heapMB', 'scale3d', 'particles', 'decorations', 'lights', 'emitters', 'renderFallback', 'flatScreens', 'starvedFrames', 'stallSaves', 'hotSeconds']) {
          if (typeof data[key] === 'number' && Number.isFinite(data[key]) && data[key] >= 0) metrics[key] = Math.round(data[key] * 100) / 100;
        }
        // The drawing camera (RenderWatchdog.camera_report): height and pitch can be negative.
        for (const key of ['camOwn', 'camY', 'camPitch', 'camDist', 'camFar']) {
          if (typeof data[key] === 'number' && Number.isFinite(data[key])) metrics[key] = Math.round(data[key] * 10) / 10;
        }
        for (const key of ['zone', 'class', 'towerState', 'lastSkill', 'audioState']) if (typeof data[key] === 'string' && /^[a-z_]{1,48}$/.test(data[key])) metrics[key] = data[key];
      } catch (_) {}
    },
    error: recordError,
    // Game-side moments worth a timestamp (fixed names only, never free text).
    mark(type) { if (['audio_stall', 'audio_back', 'hot'].includes(type)) { event(type); snapshot(); } },
    end() { if (current) { current.status = 'ended'; event('engine_exit'); snapshot(); } clearInterval(timer); if (raf !== null) window.cancelAnimationFrame?.(raf); releaseWake(); },
    report, showReport,
  };
  // A primitive boolean avoids serializing the full account state five times per second.
  window.toonRuntimePauseMask = () => (document.visibilityState === 'hidden' ? 1 : 0) |
    (typeof window.toonCloudModalOpen === 'function' && window.toonCloudModalOpen() ? 2 : 0) | (reportOpen ? 4 : 0);
  document.addEventListener('visibilitychange', () => {
    if (!current || current.status === 'ended') return;
    const hidden = document.visibilityState === 'hidden';
    previousFrame = null;
    current.status = hidden ? 'hidden' : 'running'; event(hidden ? 'hidden' : 'visible'); snapshot();
    if (hidden) releaseWake(); else keepAwake();
  });
  window.addEventListener('pagehide', () => {
    if (current && current.status !== 'ended') { current.status = 'page_hidden'; event('pagehide'); snapshot(); }
    releaseWake();
  });
  window.addEventListener('pageshow', () => {
    if (current && current.status !== 'ended') { current.status = document.visibilityState === 'hidden' ? 'hidden' : 'running'; event('pageshow'); snapshot(); keepAwake(); }
  });
  window.addEventListener('error', (e) => window.toonSession.error(e.message));
  window.addEventListener('unhandledrejection', (e) => window.toonSession.error(e.reason));
  document.getElementById('canvas').addEventListener('webglcontextlost', () => { if (current) current.contextLost = true; event('webgl_context_lost'); snapshot(); });
  document.getElementById('canvas').addEventListener('webglcontextrestored', () => { event('webgl_context_restored'); previousFrame = null; snapshot(); });
  const button = document.getElementById('session-report');
  if (button) { button.hidden = !previous; button.addEventListener('click', showReport); }
})();
