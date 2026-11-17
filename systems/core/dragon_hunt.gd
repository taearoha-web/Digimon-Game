class_name DragonHunt
extends RefCounted
## ล่ามังกรแก้วเจ็ดสี, the rainbow dragon hunt week that follows the x5 festival: from
## START (20 Nov 2026 07:40 Thai time, WorldEvents.FESTIVAL5_END) for LENGTH (seven days),
## and again every EVERY (four weeks). Read off the clock like every world event, so
## every device runs the same hunts.
##
## - The rare dragon (WorldEvents.rare_*, RareDragon) comes twice as often: a Thai day
##   whose noon falls in a hunt has twice its windows (rare_mult, WorldEvents.rare_count).
## - Hunt points (แต้มล่า): the hero's side bringing the dragon down (the prize, RareDragon.died)
##   RARE_KILL, a hand in a fight someone else won RARE_HELP, once a window either way;
##   a golden monster (มอนทองคำ, Zone._on_golden_died) GOLDEN: the dragon lives on the
##   ★300 isle only (its zone flag; moved anywhere else it would bring the isle's loot
##   with it), so the heroes below ★300 hunt the golden monsters of every field instead.
## - MILESTONES: real rewards at set points, each claimed once (claim); the last grants the
##   title of Achievements TITLE_ID (flags[TOP_FLAG]). What is not claimed can still be
##   claimed until the next hunt starts; then the record starts over.
## - The world players hunt too (ai_points, top): the ones hunting on the isle when a
##   window is half over bring its dragon down (one slays, up to AI_HELPERS help; the
##   isle's own hunters, IsleLuck.hunters_at), and the ones below ★300 (not the stall keepers) farm golden
##   monsters at a pace of their own while they play. The server hears of each AI kill
##   when its window ends (tick, from Announcer.tick) and of the hunt opening.
##
## Saved as profile["dhunt"]: {n (the hunt, -1 none yet), pts, got (claimed milestones as
## bits), kills, golden}; all ints (valid / repair; the server checks the same shape).

const KEY := "dhunt"
const START := WorldEvents.FESTIVAL5_END
const LENGTH := 7 * WorldEvents.DAY
const EVERY := 28 * WorldEvents.DAY
const NAME := "ล่ามังกรแก้วเจ็ดสี"
const COLOR := Color("7dffd8")
const RARE_KILL := 100
const RARE_HELP := 40
const GOLDEN := 25
## [points, items ([ItemData.JEWELS id, count]), title].
const MILESTONES := [
	[100, [["chaos", 3]], false],
	[250, [["purple", 10], ["pink", 5]], false],
	[500, [["set_core", 1]], false],
	[800, [["dragon_chest", 2]], false],
	[1200, [["chaos", 10], ["set_core", 1]], false],
	[1600, [["dragon_fragment", 5]], false],
	[2000, [["sky_dragon_egg", 1], ["set_core", 2]], true],
]
const TOP_FLAG := "dhunt_top"
const TITLE_ID := "t_dragon_hunt"
const MAX_POINTS := 10000000
## World players: helpers beside the slayer of a window, and how many golden monsters an
## hour one below ★300 brings down (GOLDEN_AI_MIN..MAX by a hash of its name).
const AI_HELPERS := 2
const GOLDEN_AI_MIN := 0.4
const GOLDEN_AI_MAX := 1.4
const CATCH_UP := 90.0
const AI_SLAIN := "%s ปราบ%sได้ในศึกล่ามังกร! +%d แต้มล่า"
const OPENING := "ศึกล่ามังกรแก้วเจ็ดสีเริ่มแล้ว! มังกรมาสองเท่า สะสมแต้มล่าแลกรางวัล"

## false: no hunt at all (tests of the plain rare dragon schedule).
static var enabled := true
## Tests pin the clock here (>= 0); otherwise WorldPresence.clock().
static var test_time := -1.0
static var _windows := {}
static var _told_hunt := -1
static var _tick_t := -1.0


static func now() -> float:
	return test_time if test_time >= 0.0 else WorldPresence.clock()


static func _t(t: float) -> float:
	return now() if t < 0.0 else t


# --- The calendar -------------------------------------------------------------------

## The latest hunt started at or before `t` (0, 1, ...), -1 before the first.
static func index(t: float) -> int:
	if not enabled or t < float(START):
		return -1
	return int(floor((t - float(START)) / float(EVERY)))


static func start_of(n: int) -> float:
	return float(START) + float(n) * float(EVERY)


static func end_of(n: int) -> float:
	return start_of(n) + float(LENGTH)


static func is_on(t: float) -> bool:
	var n := index(t)
	return n >= 0 and t < end_of(n)


## The next hunt's start after `t` (the running one's when one runs).
static func next_start(t: float) -> float:
	if t < float(START):
		return float(START)
	return start_of(index(t) + 1)


## 2 on a Thai day whose noon falls in a hunt (twice the rare dragon's windows), else 1.
static func rare_mult(day: int) -> int:
	var noon := float(day) * float(WorldEvents.DAY) - float(WorldPlayers.TZ) + 12.0 * 3600.0
	return 2 if is_on(noon) else 1


## The HUD chip's line while a hunt runs ("" otherwise).
static func chip_text(t: float) -> String:
	if not is_on(t):
		return ""
	var left := end_of(index(t)) - t
	var span := "%d วัน" % int(ceil(left / float(WorldEvents.DAY))) if left > 2.0 * float(WorldEvents.DAY) else WorldEvents._span(left)
	var pts := " · แต้มล่า %d" % int(peek(t).pts) if Game.has_profile else ""
	return "%s (มังกรมา x2) เหลือ %s%s" % [NAME, span, pts]


## "20 พ.ย. 07:40" (Thai time).
static func date_text(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t) + WorldPlayers.TZ)
	var months := ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
	return "%d %s %02d:%02d" % [int(d.day), months[int(d.month) - 1], int(d.hour), int(d.minute)]


# --- The hero's record ----------------------------------------------------------------

## The hero's record for the hunt of `t` (a fresh one, saved, when a new hunt has started).
static func state(t := -1.0) -> Dictionary:
	var s := peek(t)
	Game.profile[KEY] = s
	return s


## The same without writing to the profile (what the screens read).
static func peek(t := -1.0) -> Dictionary:
	var n := index(_t(t))
	var s: Variant = Game.profile.get(KEY)
	if not s is Dictionary or int((s as Dictionary).get("n", -2)) != n:
		return {"n": n, "pts": 0, "got": 0, "kills": 0, "golden": 0}
	return s


static func milestone_items(k: int) -> Array:
	var out: Array = []
	for pair in MILESTONES[k][1]:
		if ItemData.JEWELS.has(String(pair[0])):
			out.append(ItemData.jewel(String(pair[0]), int(pair[1])))
	return out


static func milestone_text(k: int) -> String:
	var parts: Array[String] = []
	for item in milestone_items(k):
		parts.append("%s ×%d" % [ItemData.name_of(item), int(item.count)])
	if bool(MILESTONES[k][2]):
		parts.append("ตำแหน่ง \"%s\"" % String(Achievements.entry(TITLE_ID).get("title", "")))
	return " + ".join(parts)


static func is_claimed(s: Dictionary, k: int) -> bool:
	return int(s.get("got", 0)) & (1 << k) != 0


## Milestones reached and not claimed yet.
static func claimable(t := -1.0) -> int:
	if not Game.has_profile:
		return 0
	var s := peek(t)
	var n := 0
	for k in MILESTONES.size():
		if int(s.pts) >= int(MILESTONES[k][0]) and not is_claimed(s, k):
			n += 1
	return n


## Claims milestone `k` (0-based) once: "ok" or the reason it cannot.
static func claim(k: int, t := -1.0) -> String:
	if not Game.has_profile:
		return "ไม่มีตัวละคร"
	if k < 0 or k >= MILESTONES.size():
		return "ไม่มีรางวัลขั้นนี้"
	var s := state(t)
	if int(s.n) < 0:
		return "ศึกล่ามังกรยังไม่เริ่ม"
	if is_claimed(s, k):
		return "รับรางวัลขั้นนี้ไปแล้ว"
	if int(s.pts) < int(MILESTONES[k][0]):
		return "แต้มล่ายังไม่ถึง"
	s["got"] = int(s.got) | (1 << k)
	for item in milestone_items(k):
		Game.give_or_store(item)
	if bool(MILESTONES[k][2]):
		Game.flag_add(TOP_FLAG)
		Game._check_achievements()
		Game.say("ได้ตำแหน่งใหม่ \"%s\" — ใส่ได้ที่เมนูตำแหน่ง" % String(Achievements.entry(TITLE_ID).get("title", "")), &"success")
	Game.mark_dirty()
	Game.quest_changed.emit()
	return "ok"


## Every reached milestone at once; how many were claimed.
static func claim_all(t := -1.0) -> int:
	var n := 0
	for k in MILESTONES.size():
		if claim(k, t) == "ok":
			n += 1
	return n


## Points for the hero while a hunt runs (0 outside one); what was added.
static func add_points(amount: int, why: String, t := -1.0) -> int:
	t = _t(t)
	if not Game.has_profile or not is_on(t) or amount <= 0:
		return 0
	var s := state(t)
	s["pts"] = mini(MAX_POINTS, int(s.pts) + amount)
	Game.say("%s +%d แต้มล่ามังกร (รวม %d)" % [why, amount, int(s.pts)], &"quest")
	Game.mark_dirty()
	Game.quest_changed.emit()
	return amount


## The rare dragon fell with the hero's side holding `share` of its damage (RareDragon.died,
## once a window): the prize-winner's points, or a helper's for a hand in it.
static func on_rare(share: float, t := -1.0) -> int:
	if share <= 0.0 or not Game.has_profile or not is_on(_t(t)):
		return 0
	var s := state(t)
	if share >= 0.5:
		s["kills"] = int(s.kills) + 1
		return add_points(RARE_KILL, "ปราบ%s" % WorldEvents.NAME_RARE, t)
	return add_points(RARE_HELP, "ช่วยล่า%s" % WorldEvents.NAME_RARE, t)


## The hero beat a golden monster (Zone._on_golden_died).
static func on_golden(t := -1.0) -> int:
	if not Game.has_profile or not is_on(_t(t)):
		return 0
	var s := state(t)
	s["golden"] = int(s.golden) + 1
	return add_points(GOLDEN, "ปราบ%s" % WorldEvents.NAME_GOLDEN, t)


# --- Saves --------------------------------------------------------------------------

static func _int_ok(v: Variant, lo := 0, hi := MAX_POINTS) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floor(float(v)) and float(v) >= lo and float(v) <= hi


## Whether a saved profile["dhunt"] has the right shape (before _repair).
static func valid(v: Variant) -> bool:
	if not v is Dictionary:
		return false
	for key in v:
		if not key is String or key not in ["n", "pts", "got", "kills", "golden"]:
			return false
	if v.has("n") and not _int_ok(v.n, -1, 100000):
		return false
	if v.has("got") and not _int_ok(v.got, 0, (1 << MILESTONES.size()) - 1):
		return false
	for key in ["pts", "kills", "golden"]:
		if v.has(key) and not _int_ok(v[key]):
			return false
	return true


## Ints back from JSON floats; a broken record is dropped (a fresh one is made on read).
static func repair(data: Dictionary) -> void:
	if not data.has(KEY):
		return
	if not valid(data[KEY]):
		data.erase(KEY)
		return
	var s: Dictionary = data[KEY]
	for key in ["n", "pts", "got", "kills", "golden"]:
		s[key] = int(s.get(key, -1 if key == "n" else 0))


# --- The world players ----------------------------------------------------------------

## The world players' part in rare dragon window `win` opening at `start`: {slayer
## (roster index, -1 none), helpers: [...]}: the isle's hunters at the window's middle.
static func window_hunters(win: int, start: float) -> Dictionary:
	if _windows.has(win):
		return _windows[win]
	if _windows.size() > 400:
		_windows.clear()
	var out := {"slayer": -1, "helpers": []}
	var there := IsleLuck.hunters_at(start + float(WorldEvents.RARE_LENGTH) * 0.5)
	if not there.is_empty():
		var first := WorldEvents.roll("dhunt|who|%d" % win) % there.size()
		out.slayer = int(there[first].index)
		for k in range(1, mini(there.size(), AI_HELPERS + 1)):
			out.helpers.append(int(there[(first + k) % there.size()].index))
	_windows[win] = out
	return out


## Every rare dragon window of hunt `n` that has ended by `t`: [{window, start, until}].
static func ended_windows(n: int, t: float) -> Array:
	var out: Array = []
	var a := start_of(n)
	var b := minf(t, end_of(n))
	if b <= a:
		return out
	for day in range(WorldEvents.day_of(a), WorldEvents.day_of(b) + 1):
		var starts := WorldEvents.rare_windows(day)
		for k in starts.size():
			var until := starts[k] + float(WorldEvents.RARE_LENGTH)
			if starts[k] >= a and until <= b:
				out.append({"window": day * WorldEvents.RARE_SLOTS + k, "start": starts[k], "until": until})
	return out


## Golden monsters an hour world player i brings down while it plays (below ★300).
static func golden_pace(i: int) -> float:
	var r := float(WorldEvents.roll("dhunt|pace|%s" % String(WorldPlayers.entry(i).name)) % 1000) / 1000.0
	return lerpf(GOLDEN_AI_MIN, GOLDEN_AI_MAX, r)


## World player i's hunt points in hunt `n` by `t`: its dragon windows and, while below
## ★300, the golden monsters of the hours it played in the hunt.
static func ai_points(i: int, n: int, t: float, windows: Array = []) -> int:
	if n < 0:
		return 0
	var a := start_of(n)
	var b := minf(t, end_of(n))
	if b <= a or WorldPlayers.joined_at(i) > b:
		return 0
	var pts := 0
	if windows.is_empty():
		windows = ended_windows(n, b)
	for w in windows:
		var h := window_hunters(int(w.window), float(w.start))
		if int(h.slayer) == i:
			pts += RARE_KILL
		elif (h.helpers as Array).has(i):
			pts += RARE_HELP
	if not WorldPlayers.in_town_style(i) and int(WorldPlayers.progress_at(i, b).stars) < SkyIsleData.ENTRY_STAR:
		var hours := maxf(0.0, WorldPlayers.played_minutes(i, b) - WorldPlayers.played_minutes(i, a)) / 60.0
		pts += int(floor(hours * golden_pace(i))) * GOLDEN
	return pts


## The top `count` hunters of the hunt of `t`, the hero among them: [{name, pts, hero}],
## best first; the hero's own row is added after them when it is not in the top.
static func top(t := -1.0, count := 10) -> Array:
	t = _t(t)
	var n := index(t)
	var rows: Array = []
	if n < 0:
		return rows
	var windows := ended_windows(n, t)
	WorldPlayers.ensure_until(t)
	for i in WorldPlayers.size():
		var p := ai_points(i, n, t, windows)
		if p > 0:
			rows.append({"name": String(WorldPlayers.entry(i).name), "pts": p, "hero": false, "index": i})
	var me := {"name": String(Game.profile.get("name", "")), "pts": int(peek(t).pts), "hero": true, "index": -1} if Game.has_profile else {}
	if not me.is_empty():
		rows.append(me)
	rows.sort_custom(func(x, y): return int(x.pts) > int(y.pts) or (int(x.pts) == int(y.pts) and bool(x.hero) and not bool(y.hero)))
	for k in rows.size():
		rows[k]["rank"] = k + 1
	var out := rows.slice(0, count)
	if not me.is_empty() and not out.has(me):
		out.append(me)
	return out


# --- The server's news ------------------------------------------------------------------

## Once a second (Announcer.tick): the hunt's opening, once a hunt each run of the game,
## and each world player's dragon kill of a window that ended since the last look.
static func tick(t: float) -> void:
	if not is_on(t):
		_tick_t = t
		return
	var n := index(t)
	if _told_hunt != n:
		_told_hunt = n
		Announcer.show(Announcer.clean(OPENING), "rare")
	if _tick_t >= 0.0 and t > _tick_t and t - _tick_t <= CATCH_UP:
		for e in slain_between(_tick_t, t):
			if not WorldEvents.rare_done(int(e.window)):
				Announcer.show(Announcer.clean(AI_SLAIN % [String(e.name), WorldEvents.NAME_RARE, RARE_KILL]), "rare")
	_tick_t = t


## The world players' dragon kills of the hunt windows that ended in (from, to]:
## [{window, until, index, name}], oldest first.
static func slain_between(from: float, to: float) -> Array:
	var out: Array = []
	for day in range(WorldEvents.day_of(from - float(WorldEvents.RARE_LENGTH)), WorldEvents.day_of(to) + 1):
		var starts := WorldEvents.rare_windows(day)
		for k in starts.size():
			var until := starts[k] + float(WorldEvents.RARE_LENGTH)
			if until <= from or until > to or not is_on(starts[k]):
				continue
			var win := day * WorldEvents.RARE_SLOTS + k
			var h := window_hunters(win, starts[k])
			if int(h.slayer) >= 0:
				out.append({"window": win, "until": until, "index": int(h.slayer), "name": String(WorldPlayers.entry(int(h.slayer)).name)})
	return out


static func reset() -> void:
	_windows.clear()
	_told_hunt = -1
	_tick_t = -1.0
