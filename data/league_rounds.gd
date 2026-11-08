class_name LeagueRounds
extends RefCounted
## The guild league's past rounds, frozen (docs/ONLINE_PROTOCOL.md, "Guild league:
## official round results"). A round that has ended never changes again, on any device:
##
## - official: the round's result as the server keeps it (/api/league/*, the first result
##   any device posted for it). Every device reads the same one.
## - seen: this device's own record of each ended round, kept the first time it worked the
##   round out (its seeded result, or the hero's fought or watched one). Used when the
##   server has none or cannot be reached; a code update that changes fighter power can
##   not rewrite it.
##
## GuildLeague reads a round here before it seeds one (round_results, holder_after), so the
## castle's chain of holders continues from the frozen rounds. Both kinds are cached in
## PATH (not in the save profile), so offline play keeps the frozen history too.
##
## The server (web build only; `transport` stands in for it in tests): the ended rounds of
## this season and the last are fetched on startup, when the league page opens, every
## FETCH_EVERY and after each round's bell; an ended round the server has none of is
## posted with this device's result (at once for a round the hero fought or watched, else
## POST_DELAY after the bell, so the fighters' results come first), and whatever the server
## answers is adopted.
##
## A result is the shape GuildLeague.sim_round makes: {at, g: guilds, k: falls, c: captures,
## held: the holder at the bell (0 nobody), own: the holder when it began}; a round nobody
## could fight has g = [].

const PATH := "user://toon_tale_league.json"
const API_ROUNDS := "/api/league/rounds"
const API_ROUND := "/api/league/round"
const VERSION := 1
## Seconds after a round's bell before a device that did not take part posts its seeded
## result (the hero's fought or watched result goes at once).
const POST_DELAY := 90.0
## The server takes a round this long before its bell at the earliest (league.mjs END_MARGIN).
const SERVER_MARGIN := 60.0
const FETCH_EVERY := 600.0
## The league page asks for a fetch at most this often.
const FETCH_SOON := 30.0
## A post the server did not answer is tried again after this long.
const RETRY := 300.0
## After a 429 from the server nothing is sent for this long.
const BACK_OFF := 600.0
const TICK := 1.0
## Rounds kept in PATH (about three years of three a day).
const MAX_KEPT := 3000
const MAX_KILLS := 100000
const MAX_CAPTURES := 1000

## at -> result from the server.
static var official := {}
## at -> this device's frozen result.
static var seen := {}
## Bumps whenever a stored result changes what GuildLeague reads (its caches key on it).
static var revision := 0
## Tests: an object with send(method, path, body) -> int and poll(id) -> String
## ('{"status": int, "body": String}', "" while waiting). null: the web page's fetch.
static var transport: Object = null
## false: nothing is written to PATH (tests).
static var persist := true
## Writes PATH (and reads its future rounds back) even with the world clock moved
## (WorldPresence.clock_offset: TOON_WORLD_DAYS or a test); tests only.
static var persist_moved_clock := false
static var path := PATH
static var _loaded := false
static var _dirty := false
static var _tick := 0.0
## Request id -> {kind: "get" | "post", at}.
static var _pending := {}
## at -> when it was last posted (now()); -1 never again (the server refused it).
static var _posted := {}
## Rounds this device fought or watched to the end: posted without waiting.
static var _real := {}
static var _fetched := false
static var _fetch_at := 0.0
static var _last_fetch := -INF
static var _quiet_until := 0.0
static var _web_ready := false


# --- The stores -----------------------------------------------------------------------

static func _ensure() -> void:
	if not _loaded:
		_loaded = true
		load_file()


## The frozen result of round `at` ({} when none): the server's, else this device's.
static func result_of(at: int) -> Dictionary:
	_ensure()
	if official.has(at):
		return official[at]
	return seen.get(at, {})


static func official_of(at: int) -> Dictionary:
	_ensure()
	return official.get(at, {})


static func seen_of(at: int) -> Dictionary:
	_ensure()
	return seen.get(at, {})


static func is_official(at: int) -> bool:
	_ensure()
	return official.has(at)


## Keeps this device's result of the ended round `at` the first time it is worked out;
## a round already kept (or official) keeps what it has.
static func freeze(at: int, result: Dictionary) -> void:
	_ensure()
	if official.has(at) or seen.has(at):
		return
	var r := clean(at, result)
	if r.is_empty():
		return
	seen[at] = r
	_dirty = true


## The hero fought or watched round `at` to the end: its result replaces this device's
## (not the server's) and is posted at once.
static func record_real(at: int, result: Dictionary) -> void:
	_ensure()
	var r := clean(at, result)
	if r.is_empty():
		return
	_real[at] = true
	_posted.erase(at)
	if official.has(at):
		return
	if seen.get(at, {}) != r:
		seen[at] = r
		revision += 1
		_dirty = true


## Takes the server's result of round `at`. False when it is malformed.
static func adopt(at: int, result: Variant) -> bool:
	_ensure()
	var r := clean(at, result)
	if r.is_empty():
		return false
	if official.get(at, {}) != r:
		official[at] = r
		revision += 1
		_dirty = true
	return true


## Forgets every stored result (tests).
static func reset() -> void:
	official.clear()
	seen.clear()
	_pending.clear()
	_posted.clear()
	_real.clear()
	_fetched = false
	_fetch_at = 0.0
	_last_fetch = -INF
	_quiet_until = 0.0
	_dirty = false
	_loaded = true
	revision += 1


static func _is_int(v: Variant, lo: int, hi: int) -> bool:
	if not (v is int or v is float):
		return false
	var f := float(v)
	return is_finite(f) and f == floor(f) and f >= float(lo) and f <= float(hi)


## A well-formed copy of a round result for `at` with int numbers, {} when it is not one
## (the server's checks, hosting/worker/league.mjs cleanResult).
static func clean(at: int, v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {}
	var d: Dictionary = v
	for key in ["g", "k", "c"]:
		if not d.get(key) is Array:
			return {}
	if not _is_int(d.get("at"), 0, 1 << 40) or int(d.at) != at:
		return {}
	var g: Array = d.g
	var k: Array = d.k
	var c: Array = d.c
	if g.size() == 1 or g.size() > 4 or k.size() != g.size() or c.size() != g.size():
		return {}
	var gs: Array = []
	var ks: Array = []
	var cs: Array = []
	for i in g.size():
		if not _is_int(g[i], 1, 4) or gs.has(int(g[i])) or not _is_int(k[i], 0, MAX_KILLS) or not _is_int(c[i], 0, MAX_CAPTURES):
			return {}
		gs.append(int(g[i]))
		ks.append(int(k[i]))
		cs.append(int(c[i]))
	if not _is_int(d.get("held"), 0, 4) or not _is_int(d.get("own"), 0, 4):
		return {}
	var held := int(d.held)
	if held != 0 and not gs.has(held):
		return {}
	return {"at": at, "g": gs, "k": ks, "c": cs, "held": held, "own": int(d.own)}


# --- The file (PATH) ------------------------------------------------------------------

static func _clock_moved() -> bool:
	return WorldPresence.clock_offset != 0.0 and not persist_moved_clock


static func load_file() -> void:
	official.clear()
	seen.clear()
	revision += 1
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if not parsed is Dictionary:
		return
	# A round in the real future was kept with a moved clock: not real history.
	var latest := INF if persist_moved_clock else WorldPlayers.now()
	for pair in [["official", official], ["seen", seen]]:
		var src: Variant = (parsed as Dictionary).get(pair[0])
		if not src is Dictionary:
			continue
		for key in src:
			if not String(key).is_valid_int():
				continue
			var at := int(String(key))
			if float(at) + GuildWarData.DURATION > latest + SERVER_MARGIN:
				continue
			var r := clean(at, src[key])
			if not r.is_empty():
				(pair[1] as Dictionary)[at] = r


static func _kept(store: Dictionary) -> Dictionary:
	var keys := store.keys()
	keys.sort()
	var out := {}
	for i in range(maxi(0, keys.size() - MAX_KEPT), keys.size()):
		out[str(keys[i])] = store[keys[i]]
	return out


## Writes the stores to PATH (only with the real world clock: a moved one is no history).
static func save_file() -> void:
	_dirty = false
	if not persist or _clock_moved():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"v": VERSION, "official": _kept(official), "seen": _kept(seen)}))


static func flush() -> void:
	if _dirty:
		save_file()


# --- The server -----------------------------------------------------------------------

static func now() -> float:
	return WorldPresence.clock()


## The way to the server: the test transport, else the web page's fetch; null offline.
static func _link() -> Object:
	if transport != null:
		return transport
	if OS.has_feature("web") and not _clock_moved():
		return WebLink.new()
	return null


## The league page opened: fetch soon.
static func want_fetch() -> void:
	_fetch_at = minf(_fetch_at, maxf(now(), _last_fetch + FETCH_SOON))


## The ended rounds the server is asked for: this season's and the last's.
static func window(t: float) -> Vector2i:
	var from := maxi(int(GuildLeague.week_start(GuildLeague.week_of(t) - 1)), WorldPlayers.START_UNIX)
	return Vector2i(from, int(t))


## Game._process: saves what changed, answers the server, fetches and posts when due.
static func process(delta: float) -> void:
	_tick += delta
	if _tick < TICK:
		return
	_tick = 0.0
	poll()
	flush()


## One step of the server's work (process calls it every TICK; tests call it directly).
static func poll() -> void:
	_ensure()
	var link := _link()
	if link == null:
		return
	for id in _pending.keys():
		var raw := str(link.call("poll", int(id)))
		if raw == "":
			continue
		var job: Dictionary = _pending[id]
		_pending.erase(id)
		_answer(job, raw)
	var t := now()
	if t < _quiet_until:
		return
	if t >= _fetch_at and not _busy("get"):
		_fetch(link, t)
	elif _fetched and not _busy("post"):
		_post_due(link, t)


static func _busy(kind: String) -> bool:
	for id in _pending:
		if String(_pending[id].kind) == kind:
			return true
	return false


static func _fetch(link: Object, t: float) -> void:
	var w := window(t)
	_last_fetch = t
	# Again every FETCH_EVERY, and soon after the next bell (when its result is posted).
	var live := GuildLeague.live_slot(t)
	var next_end := float(live if live >= 0 else GuildLeague.next_slot(t)) + GuildWarData.DURATION
	_fetch_at = minf(t + FETCH_EVERY, next_end + POST_DELAY + 30.0)
	var id := int(link.call("send", "GET", "%s?from=%d&to=%d" % [API_ROUNDS, w.x, w.y], ""))
	if id >= 0:
		_pending[id] = {"kind": "get", "at": 0}


## The rounds of the window the server has none of, that this device may post now.
static func due(t: float) -> Array[int]:
	var out: Array[int] = []
	var w := window(t)
	var at := GuildLeague.next_slot(float(w.x) - 1.0)
	while at <= w.y:
		var bell := float(at) + GuildWarData.DURATION
		var wait := -SERVER_MARGIN if _real.has(at) else POST_DELAY
		if t >= bell + wait and not official.has(at):
			var last := float(_posted.get(at, -INF))
			var never_tried := last == -INF
			var retry := last >= 0.0 and t - last >= RETRY
			if never_tried or retry:
				out.append(at)
		at = GuildLeague.next_slot(float(at))
	return out


static func _post_due(link: Object, t: float) -> void:
	var list := due(t)
	if list.is_empty():
		return
	var at: int = list[0]
	if not _real.has(at):
		# The hero's own rounds first.
		for a in list:
			if _real.has(a):
				at = a
				break
	var r := result_of(at)
	if r.is_empty():
		GuildLeague.holder_after(at)  # works the round out (and freezes it)
		r = result_of(at)
	if r.is_empty():
		_posted[at] = -1.0
		return
	_posted[at] = t
	var id := int(link.call("send", "POST", API_ROUND, JSON.stringify({"at": at, "result": r})))
	if id >= 0:
		_pending[id] = {"kind": "post", "at": at}


static func _answer(job: Dictionary, raw: String) -> void:
	var reply: Variant = JSON.parse_string(raw)
	if not reply is Dictionary:
		return
	var status := int((reply as Dictionary).get("status", 0))
	var body: Variant = JSON.parse_string(str((reply as Dictionary).get("body", "")))
	if status == 429:
		_quiet_until = now() + BACK_OFF
		return
	if String(job.kind) == "get":
		if status == 200 and body is Dictionary and (body as Dictionary).get("rounds") is Array:
			for e in body.rounds:
				if e is Dictionary and LeagueRounds._is_int(e.get("at"), 0, 1 << 40):
					adopt(int(e.at), e.get("result"))
			_fetched = true
		return
	var at := int(job.at)
	if (status == 200 or status == 201) and body is Dictionary and body.get("round") is Dictionary:
		var round: Dictionary = body.round
		if LeagueRounds._is_int(round.get("at"), 0, 1 << 40) and int(round.at) == at:
			adopt(at, round.get("result"))
		return
	if status == 400:
		_posted[at] = -1.0  # malformed for the server: never again
	# 409 (not over yet on the server's clock), 0 (offline), 5xx: tried again after RETRY.


## The web page's fetch (same origin), through JavaScriptBridge.
class WebLink:
	extends RefCounted

	const SCRIPT := """(function () {
  if (window.toonLeague) return;
  const replies = new Map();
  let seq = 0;
  window.toonLeague = {
    send(method, path, body) {
      const id = ++seq;
      replies.set(id, null);
      const init = {method, headers: {}, credentials: 'same-origin', cache: 'no-store'};
      if (body) { init.headers['content-type'] = 'application/json'; init.body = body; }
      const stop = new AbortController();
      const timer = setTimeout(() => stop.abort(), 15000);
      init.signal = stop.signal;
      fetch(path, init)
        .then(r => r.text().then(text => replies.set(id, JSON.stringify({status: r.status, body: text}))))
        .catch(() => replies.set(id, JSON.stringify({status: 0, body: ''})))
        .finally(() => clearTimeout(timer));
      return id;
    },
    poll(id) {
      const value = replies.get(Number(id));
      if (value == null) return '';
      replies.delete(Number(id));
      return value;
    },
  };
})();"""

	func send(method: String, path: String, body: String) -> int:
		if not LeagueRounds._web_ready:
			JavaScriptBridge.eval(SCRIPT, true)
			LeagueRounds._web_ready = true
		return int(JavaScriptBridge.eval("window.toonLeague ? window.toonLeague.send(%s, %s, %s) : -1" % [JSON.stringify(method), JSON.stringify(path), JSON.stringify(body)], true))

	func poll(id: int) -> String:
		if id < 0:
			return JSON.stringify({"status": 0, "body": ""})
		return str(JavaScriptBridge.eval("window.toonLeague ? window.toonLeague.poll(%d) : ''" % id, true))
