class_name DungeonRanking
extends RefCounted
## The mechanics dungeon's weekly clear-time ranking (DungeonData; docs/ONLINE_PROTOCOL.md,
## "Dragon tomb: weekly clear times"): the best time of each party leader's account in a
## week (Monday 00:00 Thai, GuildLeague.week_of), the top TOP shown on the keeper's screen
## with the party's classes.
##
## Three sources, merged by board():
## - seeded: deterministic world-player parties of the week (seeded from the week alone,
##   so every device shows the same board and it is never empty). They post nothing.
## - local: this device's best clear a week (the hero's, record_clear), kept in PATH.
## - official: what the server keeps (/api/dungeon/times), the best time per leader.
## An entry is {leader (account key), name, secs, classes: [4 class ids], at (unix)}.
##
## Server (web build only; `transport` stands in for it in tests, null offline = skip):
## the week's times are fetched when the screen opens (at most every FETCH_SOON) and
## every FETCH_EVERY; the hero's clear is posted once (the server keeps the best); the
## answer is adopted. Nothing is sent offline or on native builds (LeagueRounds._link).

const PATH := "user://toon_tale_dungeon.json"
const API_TIMES := "/api/dungeon/times"
const API_TIME := "/api/dungeon/time"
const VERSION := 1
const TOP := 20
## Seeded world-player parties a week.
const SEEDED := 24
const MIN_SECS := 30
const MAX_SECS := 3600
const FETCH_EVERY := 600.0
const FETCH_SOON := 30.0
const RETRY := 300.0
const BACK_OFF := 600.0
const TICK := 1.0
const MAX_WEEKS_KEPT := 12
const LEADER_MAX := 64
const NAME_MAX := 32

## week -> Array[entry] from the server.
static var official := {}
## week -> the hero's best entry on this device.
static var local := {}
## Tests: an object with send(method, path, body) -> int and poll(id) -> String; null: the
## web page's fetch (LeagueRounds.WebLink), nothing on native builds.
static var transport: Object = null
static var persist := true
static var path := PATH
static var _loaded := false
static var _dirty := false
static var _tick := 0.0
## Request id -> {kind: "get" | "post", week}.
static var _pending := {}
## week -> when the local best was last posted (-1 never again, INF confirmed).
static var _posted := {}
static var _fetch_at := 0.0
static var _last_fetch := -INF
static var _quiet_until := 0.0
static var _seed_cache := {}
## Posts made (tests).
static var posts := 0


# --- The stores -----------------------------------------------------------------------

static func _ensure() -> void:
	if not _loaded:
		_loaded = true
		load_file()


static func now() -> float:
	return WorldPresence.clock()


static func week_of(t := -1.0) -> int:
	return GuildLeague.week_of(t if t >= 0.0 else now())


## The hero's account key: the signed-in account ("u:<user>"), else the online id, else
## this device's hero ("local:<name>").
static func leader_key() -> String:
	if Online.is_online():
		var me := Online.player(Online.my_id())
		var user := str(me.get("user", "")).strip_edges()
		if user != "":
			return ("u:" + user).left(LEADER_MAX)
		if Online.my_id() != "":
			return ("id:" + Online.my_id()).left(LEADER_MAX)
	return ("local:" + (String(Game.profile.get("name", "")) if Game.has_profile else "")).left(LEADER_MAX)


## The hero's best time this week on this device ({} when none).
static func local_best(week := -1) -> Dictionary:
	_ensure()
	return local.get(week if week >= 0 else week_of(), {})


## The hero cleared the dungeon in `secs` with a party of `classes`: kept when it beats
## this device's best of the week and posted to the server (once, the server keeps the
## best). Returns true when it is a new best on this device.
static func record_clear(secs: int, classes: Array, t := -1.0) -> bool:
	_ensure()
	var at := t if t >= 0.0 else now()
	var week := week_of(at)
	var entry := clean({"leader": leader_key(), "name": String(Game.profile.get("name", "")) if Game.has_profile else "", "secs": secs, "classes": classes, "at": int(at)})
	if entry.is_empty():
		return false
	var best: Dictionary = local.get(week, {})
	var improved := best.is_empty() or int(entry.secs) < int(best.secs)
	if improved:
		local[week] = entry
		_dirty = true
	# A new best (or one never posted) goes to the server.
	if improved or not _posted.has(week):
		_posted.erase(week)
	return improved


## Takes the server's entries of `week`.
static func adopt(week: int, entries: Variant) -> void:
	_ensure()
	if not entries is Array:
		return
	var out: Array = []
	for e in entries:
		var c := clean(e)
		if not c.is_empty():
			out.append(c)
	official[week] = out
	_dirty = true


static func reset() -> void:
	official.clear()
	local.clear()
	_pending.clear()
	_posted.clear()
	_seed_cache.clear()
	_fetch_at = 0.0
	_last_fetch = -INF
	_quiet_until = 0.0
	_dirty = false
	_loaded = true
	posts = 0


static func _is_int(v: Variant, lo: int, hi: int) -> bool:
	if not (v is int or v is float):
		return false
	var f := float(v)
	return is_finite(f) and f == floor(f) and f >= float(lo) and f <= float(hi)


## A well-formed copy of an entry, {} when it is not one (the server's checks,
## hosting/worker/dungeon.mjs cleanTime).
static func clean(v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {}
	var d: Dictionary = v
	var leader := str(d.get("leader", "")).strip_edges()
	if leader == "" or leader.length() > LEADER_MAX:
		return {}
	if not _is_int(d.get("secs"), MIN_SECS, MAX_SECS):
		return {}
	if not d.get("classes") is Array or (d.classes as Array).size() != DungeonData.PARTY_SIZE:
		return {}
	var classes: Array = []
	for c in d.classes:
		if not ClassData.CLASSES.has(StringName(str(c))):
			return {}
		classes.append(str(c))
	var at := int(d.get("at", 0)) if _is_int(d.get("at", 0), 0, 1 << 40) else 0
	return {"leader": leader, "name": str(d.get("name", "")).strip_edges().left(NAME_MAX), "secs": int(d.secs), "classes": classes, "at": at}


# --- The board ------------------------------------------------------------------------

## The week's board: the best entry per leader from the seeded parties, the server and
## this device, fastest first, at most TOP. Each entry also carries "rank" (1-based) and
## "mine" (the hero's own).
static func board(week := -1) -> Array:
	_ensure()
	var w := week if week >= 0 else week_of()
	var best := {}
	for e in seeded(w):
		_merge(best, e)
	for e in official.get(w, []):
		_merge(best, e)
	var mine_key := leader_key()
	var mine: Dictionary = local.get(w, {})
	if not mine.is_empty():
		var copy := mine.duplicate()
		copy["leader"] = mine_key
		_merge(best, copy)
	var out: Array = best.values()
	out.sort_custom(func(a, b):
		if int(a.secs) != int(b.secs):
			return int(a.secs) < int(b.secs)
		return int(a.at) < int(b.at))
	var ranked: Array = []
	for i in mini(TOP, out.size()):
		var e: Dictionary = (out[i] as Dictionary).duplicate()
		e["rank"] = i + 1
		e["mine"] = String(e.leader) == mine_key
		ranked.append(e)
	return ranked


## The hero's place on the week's full board (0 when it has no time yet).
static func my_rank(week := -1) -> int:
	for e in board(week):
		if bool(e.mine):
			return int(e.rank)
	return 0


static func _merge(best: Dictionary, e: Dictionary) -> void:
	var key := String(e.leader)
	if not best.has(key) or int(e.secs) < int(best[key].secs):
		best[key] = e


## The deterministic world-player parties of week `w` (the same on every device): SEEDED
## leaders at Lv.100 with DungeonData.MIN_STARS stars, each with three mates, their times
## from the party's stars (stronger parties clear faster) and a little luck.
static func seeded(w: int) -> Array:
	if _seed_cache.has(w):
		return _seed_cache[w]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("tomb|%d" % w)
	# Mid-week: who is strong enough then.
	var t := GuildLeague.week_start(w) + 3.5 * 86400.0
	var pool: Array = []
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if int(s.level) >= DungeonData.MIN_LEVEL and int(s.stars) >= DungeonData.MIN_STARS:
			pool.append(i)
	var out: Array = []
	var used := {}
	var tries := 0
	while out.size() < SEEDED and pool.size() >= DungeonData.PARTY_SIZE and tries < SEEDED * 4:
		tries += 1
		var lead: int = pool[rng.randi() % pool.size()]
		if used.has(lead):
			continue
		used[lead] = true
		var members: Array = [lead]
		var stars := 0
		var classes: Array = []
		var guard := 0
		while members.size() < DungeonData.PARTY_SIZE and guard < 40:
			guard += 1
			var m: int = pool[rng.randi() % pool.size()]
			if not members.has(m):
				members.append(m)
		if members.size() < DungeonData.PARTY_SIZE:
			break
		for m in members:
			var s := WorldPlayers.state(m, t)
			stars += int(s.stars)
			classes.append(String(s["class"]))
		var avg := float(stars) / float(DungeonData.PARTY_SIZE)
		# 20 stars: about 7 minutes; 300 stars: about 3 minutes; a Defender and a Priest help.
		var secs := 430.0 - avg * 0.7
		if classes.has("defender"):
			secs -= 25.0
		if classes.has("priest"):
			secs -= 15.0
		secs += rng.randf_range(-35.0, 55.0)
		var at := int(GuildLeague.week_start(w) + rng.randf_range(0.2, 6.5) * 86400.0)
		var s0 := WorldPlayers.state(lead, t)
		out.append({"leader": "w:" + String(s0.name), "name": String(s0.name), "secs": clampi(int(round(secs)), 150, MAX_SECS), "classes": classes, "at": at})
	_seed_cache[w] = out
	return out


# --- The file (PATH) ------------------------------------------------------------------

static func load_file() -> void:
	official.clear()
	local.clear()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if not parsed is Dictionary:
		return
	var src: Variant = (parsed as Dictionary).get("local")
	if src is Dictionary:
		for key in src:
			if String(key).is_valid_int():
				var e := clean(src[key])
				if not e.is_empty():
					local[int(String(key))] = e
	var off: Variant = (parsed as Dictionary).get("official")
	if off is Dictionary:
		for key in off:
			if String(key).is_valid_int() and off[key] is Array:
				var list: Array = []
				for e in off[key]:
					var c := clean(e)
					if not c.is_empty():
						list.append(c)
				official[int(String(key))] = list


static func _kept(store: Dictionary) -> Dictionary:
	var keys := store.keys()
	keys.sort()
	var out := {}
	for i in range(maxi(0, keys.size() - MAX_WEEKS_KEPT), keys.size()):
		out[str(keys[i])] = store[keys[i]]
	return out


static func save_file() -> void:
	_dirty = false
	if not persist:
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"v": VERSION, "local": _kept(local), "official": _kept(official)}))


static func flush() -> void:
	if _dirty:
		save_file()


# --- The server -----------------------------------------------------------------------

## The way to the server: the test transport, else the web page's fetch; null offline.
static func _link() -> Object:
	if transport != null:
		return transport
	if OS.has_feature("web") and WorldPresence.clock_offset == 0.0:
		return LeagueRounds.WebLink.new()
	return null


## The keeper's screen opened: fetch soon.
static func want_fetch() -> void:
	_fetch_at = minf(_fetch_at, maxf(now(), _last_fetch + FETCH_SOON))


## Game._process: saves what changed, answers the server, fetches and posts when due.
static func process(delta: float) -> void:
	_tick += delta
	if _tick < TICK:
		return
	_tick = 0.0
	poll()
	flush()


## One step of the server's work (tests call it directly).
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
	elif not _busy("post"):
		_post_due(link, t)


static func _busy(kind: String) -> bool:
	for id in _pending:
		if String(_pending[id].kind) == kind:
			return true
	return false


static func _fetch(link: Object, t: float) -> void:
	var w := week_of(t)
	_last_fetch = t
	_fetch_at = t + FETCH_EVERY
	var id := int(link.call("send", "GET", "%s?week=%d" % [API_TIMES, w], ""))
	if id >= 0:
		_pending[id] = {"kind": "get", "week": w}


## The weeks whose local best is not on the server yet and may be posted now.
static func due(t: float) -> Array[int]:
	var out: Array[int] = []
	for w in local.keys():
		var last := float(_posted.get(w, -INF))
		if last == INF or last == -1.0:
			continue
		if last == -INF or t - last >= RETRY:
			out.append(int(w))
	out.sort()
	return out


static func _post_due(link: Object, t: float) -> void:
	var list := due(t)
	if list.is_empty():
		return
	var w: int = list[list.size() - 1]
	var e: Dictionary = local[w].duplicate()
	e["leader"] = leader_key()
	e["week"] = w
	_posted[w] = t
	posts += 1
	var id := int(link.call("send", "POST", API_TIME, JSON.stringify(e)))
	if id >= 0:
		_pending[id] = {"kind": "post", "week": w}


static func _answer(job: Dictionary, raw: String) -> void:
	var reply: Variant = JSON.parse_string(raw)
	if not reply is Dictionary:
		return
	var status := int((reply as Dictionary).get("status", 0))
	var body: Variant = JSON.parse_string(str((reply as Dictionary).get("body", "")))
	if status == 429:
		_quiet_until = now() + BACK_OFF
		return
	var w := int(job.week)
	if String(job.kind) == "get":
		if status == 200 and body is Dictionary and (body as Dictionary).get("times") is Array:
			adopt(w, body.times)
		return
	if (status == 200 or status == 201) and body is Dictionary:
		_posted[w] = INF
		var stored: Variant = (body as Dictionary).get("time")
		if stored is Dictionary:
			var c := clean(stored)
			if not c.is_empty():
				var list: Array = official.get(w, [])
				list = list.filter(func(e): return String(e.leader) != String(c.leader))
				list.append(c)
				official[w] = list
				_dirty = true
		return
	if status == 400:
		_posted[w] = -1.0  # malformed for the server: never again
	# 0 (offline), 5xx: tried again after RETRY.
