class_name MazeWar
extends RefCounted
## เขาวงกตหนึ่งในใต้หล้า: the labyrinth (MazeLayout) where everyone is everyone's enemy,
## open at any hour from Lv.MIN_LEVEL (the guild's level: the world players who go in are
## all Lv.100 and up, and a lower hero would only be a free kill). Only kills between
## players count (the hero, real online players and the world players; there are no
## monsters), one board a week on the guild league's week (Monday 00:00 Thai time,
## GuildLeague.week_of), ranked by kills alone, ties to whoever reached the count first.
## The week's first holds the title หนึ่งในใต้หล้า and the costume เทพราชันหนึ่งในใต้หล้า
## for the next week (MazeCrown, team crown).
##
## Where a week's kills come from (standings):
## - the hero's: counted by the zone (MazeMatch) as they happen, kept in the save (KEY:
##   per week, with when the count was reached);
## - real online players': the server's board (`maze_board` / `maze_kill`, receive);
## - the world players': worked out from the clock and the roster alone, the same on
##   every device (sim). The "interested" ones (interest: by the way they play and their
##   class; never a stall keeper) spend a share of their sessions in the maze, in blocks
##   of BLOCK real seconds (in_maze, also where WorldPlayers.state puts them). Time is cut
##   in slots of SLOT seconds; in each slot the players in the maze meet in fights
##   (FIGHTS_PER_MIN each, fewer with few people in so big a maze), the stronger one
##   (power: its real gear and stats at the start of the Thai day, HeroStats) usually
##   wins, never always (UPSET); a fight is a kill for the winner at its own moment.
## - Live: while the hero is inside, the world players in the maze then fight there for
##   real (MazeMatch). A world player fighting live holds its slots (hold): the fights the
##   simulation gave it in those slots are dropped on this device and its live kills
##   (record_kill) count instead, so nothing is counted twice.
##
## Fair play (MazeMatch, documented in the zone): a shrine (ที่หลบภัย, ten of them,
## MazeLayout.SAFE_CELLS) keeps whoever stands in its circle from harm and from striking
## out for SAFE_MAX seconds a visit, then its blessing wears off and that shrine will not
## take the same player again for SAFE_COOLDOWN (no camping in safety); leaving one
## protects for SAFE_LEAVE more seconds while one cannot strike yet (no swinging out of a
## shrine). Everyone comes back from a fall after RESPAWN seconds at a random spot of the
## maze (MazeLayout.spawn_point: not in a shrine, away from everyone), untouchable for
## SPAWN_GUARD seconds; the same killer gets one kill of the same victim at most once in
## REKILL_GAP seconds (no farming somebody's spawn).

const ID := &"maze_war"
const TITLE := "เขาวงกตหนึ่งในใต้หล้า"
const KEY := "mazew"
## The maze is open from the world's (re)opening (WorldPlayers.START_UNIX: 22 Nov 2026,
## 06:00 Thai time; it first opened 19 Nov, before the reopening): the world players'
## fights, the week's kills and the champions start here, nothing from before it.
const OPEN_UNIX := WorldPlayers.START_UNIX
const MIN_LEVEL := 100
const SLOT := 600.0
const BLOCK := 1800.0
const RESPAWN := 6.0
const SPAWN_GUARD := 3.0
const SAFE_MAX := 30.0
const SAFE_COOLDOWN := 45.0
const SAFE_LEAVE := 1.5
## HP and MP a second in a shrine (of the maximum).
const SAFE_REGEN := 0.03
const REKILL_GAP := 60.0
## World players fighting live in the hero's maze at once (phones), the rest stay simulated.
const MAX_LIVE := 14
## Fights a minute for each player in the maze once it is busy (CROWD of them or more).
const FIGHTS_PER_MIN := 0.12
const CROWD := 8.0
## The weaker one's least chance to win a fight.
const UPSET := 0.12
## How much power counts in a fight (the chance goes with power ^ EDGE).
const EDGE := 3.0
const NAME_MAX := 24
const KILLS_MAX := 100000
const LIVE_MAX := 64
const WEEKS_KEPT := 2
const CHAMPS_KEPT := 26
## The HUD's board: the top rows, then the hero's own.
const HUD_ROWS := 5
const COLOR := Color("ffd25a")

## How keen each voice (the way a player plays and talks) is on a fight, and each class.
const INTEREST := {"hardcore": 0.6, "night_owl": 0.55, "student": 0.5, "regular": 0.4, "overseas": 0.4,
	"weekend": 0.35, "daytime": 0.35, "early": 0.35, "casual": 0.2}
const CLASS_KEEN := {"assassin": 0.12, "warrior": 0.08, "lancer": 0.08, "archer": 0.04, "mage": 0.02,
	"summoner": 0.0, "defender": -0.05, "bard": -0.08, "priest": -0.12}
## Of a session, the share an interested player spends in the maze (by name, in between).
const SHARE_MIN := 0.18
const SHARE_MAX := 0.4
## The maze race makes the interested ones keener at the forge (WorldGear): more jewels
## bought and traded for, and more of the gems they find kept, fused and socketed.
const JEWEL_DRIVE := 1.3
const GEM_DRIVE := 1.2

## -1: the world players' fights follow WorldPresence.enabled (off headless: tests turn
## them on); 0 off; 1 on.
static var ai_mode := -1
## The maze race's drive at the forge (tests turn it off to compare; WorldGear.clear after).
static var drive_on := true

static var _interest := {}
static var _ready := {}
static var _power := {}
static var _cands: Array[int] = []
static var _cands_n := -1
static var _slots := {}
static var _sums := {}
## The real players' boards heard from the server: week -> {name: {kills, at}}.
static var _real := {}
## Champions worked out for ended weeks (also in the save).
static var _champs := {}
## Bumped whenever a count changes (the HUD and the boards redraw).
static var revision := 0


## The zone (ZoneData.get_zone; not in ZONES: no camps, no field boss, no warp chain).
static func zone() -> Dictionary:
	return {
		"name": TITLE, "scene": "field", "level": [MIN_LEVEL, 100], "music": &"guildwar", "pvp": true, "maze": true,
		"tree_density": 0.0, "camps": [], "sky": Color("1d4fb4"), "ground": Color("5d7d5b"), "prev": &"town", "next": &"",
		# A golden afternoon over the isle (MazeArena): a deep blue sky going gold at the
		# horizon, a low warm sun, a cool blue fill.
		"sky_palette": [Color("1d4fb4"), Color("7aa2e2"), Color("ffc890")], "fog": Color("b9c6ec"),
		"ambient": Color("98a2dc"), "sun": Color("ffd59a"), "sun_size": 1.6,
	}


static func ai_on() -> bool:
	return ai_mode == 1 or (ai_mode == -1 and WorldPresence.enabled)


# --- The week -----------------------------------------------------------------------

static func week_of(t: float) -> int:
	return GuildLeague.week_of(t)


static func week_start(week: int) -> float:
	return GuildLeague.week_start(week)


static func week_end(week: int) -> float:
	return GuildLeague.week_end(week)


static func now() -> float:
	return WorldPresence.clock()


## "เหลือ 3 วัน 4 ชม." to the week's end.
static func left_text(t: float = -1.0) -> String:
	if t < 0.0:
		t = now()
	var left := maxi(0, int(week_end(week_of(t)) - t))
	var days := left / 86400
	var hours := (left % 86400) / 3600
	var minutes := (left % 3600) / 60
	if days > 0:
		return "ตัดรอบใน %d วัน %d ชม." % [days, hours]
	if hours > 0:
		return "ตัดรอบใน %d ชม. %d นาที" % [hours, minutes]
	return "ตัดรอบใน %d นาที" % maxi(1, minutes)


# --- Who goes in --------------------------------------------------------------------

## How keen world player i is on the maze (0 never: a stall keeper, a calm voice and
## class may still be drawn in by its own roll, see interested).
static func interest(i: int) -> float:
	var e := WorldPlayers.entry(i)
	if String(e.get("style", "")) == "afk":
		return 0.0
	var voice := String(e.get("voice", e.get("style", "hardcore")))
	var base := float(INTEREST.get(voice, 0.35))
	return clampf(base + float(CLASS_KEEN.get(String(e.get("class", "")), 0.0)), 0.0, 0.9)


## Whether world player i takes part in the maze race at all (fixed by its name).
static func interested(i: int) -> bool:
	var hit: Variant = _interest.get(i)
	if hit != null:
		return bool(hit)
	var e := WorldPlayers.entry(i)
	var roll := float(hash("maze_keen|%s" % e.name) % 10000) / 10000.0
	var yes := roll < interest(i)
	_interest[i] = yes
	return yes


## The work (WorldGear's probe minutes) from which the maze race drives world player i at
## the forge: where its own schedule stood when the maze opened (INF for one not in it).
static func drive_from(i: int) -> float:
	if not drive_on or not interested(i) or WorldPlayers.in_town_style(i):
		return INF
	return WorldPlayers.played_minutes(i, float(OPEN_UNIX)) * WorldPlayers.efficiency(i) + WorldPlayers.head_work(i)


## The share of its sessions an interested player spends in the maze.
static func share(i: int) -> float:
	var e := WorldPlayers.entry(i)
	return lerpf(SHARE_MIN, SHARE_MAX, float(hash("maze_share|%s" % e.name) % 1000) / 999.0)


## The level world player i stands at real time t on its own schedule alone (the same
## on every device: no party EXP of this device's hero).
static func _sheet_at(i: int, t: float) -> Dictionary:
	var p := WorldPlayers.progress_for(WorldPlayers.played_minutes(i, t), WorldPlayers.efficiency(i), WorldPlayers.head_work(i))
	var e := WorldPlayers.entry(i)
	return {"class": String(e["class"]), "name": String(e.name), "level": int(p.level), "stars": int(p.stars), "frac": float(p.frac),
		"divine_frac": float(p.divine_frac), "after": float(p.get("after", 0.0))}


## When world player i reached Lv.MIN_LEVEL on its own schedule (INF not yet by t).
static func ready_at(i: int, t: float) -> float:
	var hit: Variant = _ready.get(i)
	if hit != null:
		var at := float(hit[1])
		if at < INF or t <= float(hit[0]):
			return at
	var lo := WorldPlayers.joined_at(i)
	var hi := maxf(t, lo)
	if int(_sheet_at(i, hi).level) < MIN_LEVEL:
		_ready[i] = [hi, INF]
		return INF
	for k in 24:
		var mid := (lo + hi) * 0.5
		if int(_sheet_at(i, mid).level) >= MIN_LEVEL:
			hi = mid
		else:
			lo = mid
		if hi - lo < 60.0:
			break
	_ready[i] = [hi, hi]
	return hi


## Whether world player i is in the maze at real time t: an interested player online,
## Lv.MIN_LEVEL by then, in one of the blocks of its session it gives to the maze.
static func in_maze(i: int, t: float) -> bool:
	if t < OPEN_UNIX or i < 0 or not interested(i) or WorldPlayers.in_town_style(i):
		return false
	var s := WorldPlayers.session_at(i, t)
	if s.is_empty():
		return false
	if t < ready_at(i, t):
		return false
	var s0 := float(s[0])
	var block := int((t - s0) / BLOCK)
	var roll := float(hash("maze_block|%s|%d|%d" % [WorldPlayers.entry(i).name, int(s0 / 60.0), block]) % 1000) / 1000.0
	return roll < share(i)


## Every world player who may ever come in (interested and no stall keeper), by index.
static func candidates() -> Array[int]:
	var n := WorldPlayers.size()
	if n != _cands_n:
		_cands_n = n
		_cands.clear()
		for i in n:
			if interested(i) and not WorldPlayers.in_town_style(i):
				_cands.append(i)
	return _cands


## The world players in the maze at real time t.
static func inside_at(t: float) -> Array[int]:
	var out: Array[int] = []
	for i in candidates():
		if in_maze(i, t):
			out.append(i)
	return out


## How strong world player i is at real time t for the fights: GuildWarData.power_of its
## real stats (its gear, stats, stars and skills on its own schedule), read once a Thai day.
static func power(i: int, t: float) -> float:
	var day := WorldEvents.day_of(t)
	var key := day * 4096 + i
	var hit: Variant = _power.get(key)
	if hit != null:
		return float(hit)
	var start := maxf(float(day) * 86400.0 - float(WorldPlayers.TZ), WorldPlayers.joined_at(i))
	var sheet := WorldPlayers.profile(_sheet_at(i, start))
	var p := maxf(1.0, GuildWarData.power_of(HeroStats.compute(sheet)))
	if _power.size() > 4096:
		_power.clear()
	_power[key] = p
	return p


## The chance that a player of power a beats one of power b.
static func win_chance(a: float, b: float) -> float:
	var pa := pow(maxf(a, 1.0), EDGE)
	var pb := pow(maxf(b, 1.0), EDGE)
	return clampf(pa / (pa + pb), UPSET, 1.0 - UPSET)


# --- The simulation -----------------------------------------------------------------

static func slot_of(t: float) -> int:
	return int(floor((t - float(OPEN_UNIX)) / SLOT))


static func slot_start(k: int) -> float:
	return float(OPEN_UNIX) + float(k) * SLOT


## The fights of slot k among the world players then in the maze, by time:
## [[at, winner, loser], ...] (indices). The same on every device.
static func slot_fights(k: int) -> Array:
	var hit: Variant = _slots.get(k)
	if hit != null:
		return hit
	var out: Array = []
	var t0 := slot_start(k)
	if k >= 0:
		var mid := t0 + SLOT * 0.5
		var people := inside_at(mid)
		var n := people.size()
		if n >= 2:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("maze_slot|%d" % k)
			var powers: Array[float] = []
			for i in people:
				powers.append(power(i, mid))
			# Each one meets others about FIGHTS_PER_MIN times a minute once the maze is busy.
			var crowd := clampf(float(n - 1) / CROWD, 0.3, 1.0)
			var mean := FIGHTS_PER_MIN * SLOT / 60.0 * float(n) * 0.5 * crowd
			var count := int(mean) + (1 if rng.randf() < mean - floor(mean) else 0)
			for f in count:
				var a := rng.randi() % n
				var b := rng.randi() % (n - 1)
				if b >= a:
					b += 1
				var at := t0 + rng.randf() * SLOT
				var a_wins := rng.randf() < win_chance(powers[a], powers[b])
				out.append([at, people[a] if a_wins else people[b], people[b] if a_wins else people[a]])
			out.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	if _slots.size() > 3000:
		_slots.clear()
		_sums.clear()
	_slots[k] = out
	return out


## The world players' simulated kills of week `week` up to real time t, this device's held
## slots left out: {index: [kills, at (the moment the count was reached)]}.
static func sim_kills(week: int, t: float) -> Dictionary:
	var out := {}
	if not ai_on():
		return out
	var from := maxf(week_start(week), float(OPEN_UNIX))
	var until := minf(t, week_end(week))
	if until <= from:
		return out
	var held := _held_set(week)
	var k1 := slot_of(until)
	var sum := _sum_of(week, held)
	var kills: Dictionary = sum.kills
	while int(sum.next) < k1:
		_add_slot(kills, int(sum.next), held, INF)
		sum.next = int(sum.next) + 1
	for i in kills:
		out[i] = (kills[i] as Array).duplicate()
	# The slot running now, up to t.
	_add_slot(out, k1, held, until)
	return out


## The whole slots of `week` summed so far (kept per week and held revision).
static func _sum_of(week: int, held: Dictionary) -> Dictionary:
	var key := "%d|%d" % [week, _held_rev(week)]
	var hit: Variant = _sums.get(key)
	if hit != null:
		return hit
	var sum := {"next": slot_of(maxf(week_start(week), float(OPEN_UNIX))), "kills": {}}
	if _sums.size() > 16:
		_sums.clear()
	_sums[key] = sum
	return sum


## Works the current week's slots out ahead, for at most `budget` microseconds (Game
## calls it each frame), so a board opened later is a look-up. True when up to date.
static func warm(budget: int) -> bool:
	if not ai_on():
		return true
	var t := now()
	if t < float(OPEN_UNIX):
		return true
	var week := week_of(t)
	var held := _held_set(week)
	var sum := _sum_of(week, held)
	var k1 := slot_of(t)
	var start := Time.get_ticks_usec()
	while int(sum.next) < k1:
		_add_slot(sum.kills, int(sum.next), held, INF)
		sum.next = int(sum.next) + 1
		if Time.get_ticks_usec() - start > budget:
			return false
	return true


static func _add_slot(kills: Dictionary, k: int, held: Dictionary, until: float) -> void:
	for f in slot_fights(k):
		var at := float(f[0])
		if at > until:
			break
		var w := int(f[1])
		var l := int(f[2])
		if held.has(w * 100000 + k) or held.has(l * 100000 + k):
			continue
		var row: Array = kills.get(w, [0, 0.0])
		row[0] = int(row[0]) + 1
		row[1] = at
		kills[w] = row


# --- The board ----------------------------------------------------------------------

## The week's board at real time t (now when < 0): [{name, kills, hero, index, at}], by
## kills (most first), ties to who reached the count first. Kills only; nobody without one.
static func standings(week: int, t: float = -1.0) -> Array:
	if t < 0.0:
		t = now()
	t = minf(t, week_end(week))
	var rows := {}
	var sim := sim_kills(week, t)
	for i in sim:
		var name := String(WorldPlayers.entry(int(i)).name)
		rows[name] = {"name": name, "kills": int(sim[i][0]), "hero": false, "index": int(i), "at": float(sim[i][1])}
	var book := week_book(week)
	# This device's live kills of the world players (their held slots were dropped above).
	var live: Dictionary = book.get("live", {})
	for name in live:
		var v: Array = live[name]
		if float(v[1]) > t:
			continue
		var i := WorldPlayers.index_of(String(name))
		var r: Dictionary = rows.get(String(name), {"name": String(name), "kills": 0, "hero": false, "index": i, "at": 0.0})
		r.kills = int(r.kills) + int(v[0])
		r.at = maxf(float(r.at), float(v[1]))
		rows[String(name)] = r
	# Real players (the server's board), the hero's own name aside.
	var me := hero_name()
	var real: Dictionary = _real.get(week, {})
	for name in real:
		if String(name) == me or rows.has(String(name)):
			continue
		var v: Dictionary = real[name]
		if float(v.at) > t + 5.0:
			continue
		rows[String(name)] = {"name": String(name), "kills": int(v.kills), "hero": false, "index": -1, "at": float(v.at)}
	if Game.has_profile and int(book.get("k", 0)) > 0 and float(book.get("at", 0)) <= t + 1.0:
		rows[me] = {"name": me, "kills": int(book.k), "hero": true, "index": -1, "at": float(book.at)}
	var out: Array = []
	for name in rows:
		if int(rows[name].kills) > 0:
			out.append(rows[name])
	out.sort_custom(_before)
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.kills) != int(b.kills):
		return int(a.kills) > int(b.kills)
	if float(a.at) != float(b.at):
		return float(a.at) < float(b.at)
	return String(a.name) < String(b.name)


static func hero_name() -> String:
	return String(Game.profile.get("name", "")) if Game.has_profile else ""


## The hero's place on the week's board (1 the first, 0 without a kill yet) and kills.
static func hero_rank(week: int, t: float = -1.0) -> Dictionary:
	var board := standings(week, t)
	for k in board.size():
		if bool(board[k].hero):
			return {"rank": k + 1, "kills": int(board[k].kills), "of": board.size()}
	return {"rank": 0, "kills": 0, "of": board.size()}


## World player i's place on the week's board: {rank (0 none), kills}.
static func rank_of(i: int, week: int, t: float = -1.0) -> Dictionary:
	var board := standings(week, t)
	for k in board.size():
		if int(board[k].index) == i and not bool(board[k].hero):
			return {"rank": k + 1, "kills": int(board[k].kills)}
	return {"rank": 0, "kills": 0}


## The week's champion, once the week has ended ({} before, or with nobody on the board):
## {name, kills, hero, index}. Kept once worked out (and in the save).
static func champion(week: int) -> Dictionary:
	if now() < week_end(week) or week_end(week) <= float(OPEN_UNIX):
		return {}
	var key := str(week)
	if Game.has_profile:
		var saved: Dictionary = _data().get("champs", {})
		if saved.has(key):
			return (saved[key] as Dictionary).duplicate()
	if _champs.has(week):
		return (_champs[week] as Dictionary).duplicate()
	var board := standings(week, week_end(week))
	var out := {}
	if not board.is_empty():
		var top: Dictionary = board[0]
		out = {"name": String(top.name), "kills": int(top.kills), "hero": bool(top.hero), "index": int(top.index)}
	_champs[week] = out
	if Game.has_profile and not out.is_empty():
		var champs: Dictionary = _data().get("champs", {})
		champs[key] = out.duplicate()
		while champs.size() > CHAMPS_KEPT:
			var oldest := ""
			for w in champs:
				if oldest == "" or int(w) < int(oldest):
					oldest = String(w)
			champs.erase(oldest)
		_data()["champs"] = champs
		Game.mark_dirty()
	return out


## The champions of the last `count` ended weeks, newest first: [{week, name, kills, hero, index}].
static func champions(count := 8) -> Array:
	var out: Array = []
	var w := week_of(now()) - 1
	while out.size() < count and week_end(w) > float(OPEN_UNIX):
		var c := champion(w)
		if not c.is_empty():
			var row := c.duplicate()
			row["week"] = w
			out.append(row)
		w -= 1
	return out


## The week's text for a board ("สัปดาห์ 16-22 พ.ย.").
static func week_text(week: int) -> String:
	var a := Time.get_datetime_dict_from_unix_time(int(week_start(week)) + WorldPlayers.TZ)
	var b := Time.get_datetime_dict_from_unix_time(int(week_end(week)) - 1 + WorldPlayers.TZ)
	const MONTHS := ["", "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
	return "%d %s – %d %s" % [int(a.day), MONTHS[int(a.month)], int(b.day), MONTHS[int(b.month)]]


# --- The hero's book (the save) -----------------------------------------------------

## The save's record: {weeks: {"<week>": {k, at, d, live: {name: [kills, at]}, held: {name:
## [slot, ...]}}}, champs: {"<week>": {name, kills, hero, index}}}.
static func _data() -> Dictionary:
	if not Game.has_profile:
		return {}
	if not Game.profile.get(KEY) is Dictionary:
		Game.profile[KEY] = {"weeks": {}, "champs": {}}
	var d: Dictionary = Game.profile[KEY]
	if not d.get("weeks") is Dictionary:
		d["weeks"] = {}
	if not d.get("champs") is Dictionary:
		d["champs"] = {}
	return d


## The hero's record of `week` (an empty one when none: not stored until something counts).
static func week_book(week: int) -> Dictionary:
	if not Game.has_profile:
		return {}
	var weeks: Dictionary = _data().weeks
	var b: Variant = weeks.get(str(week))
	return b if b is Dictionary else {}


static func _book_for(week: int) -> Dictionary:
	var weeks: Dictionary = _data().weeks
	var key := str(week)
	if not weeks.get(key) is Dictionary:
		weeks[key] = {"k": 0, "at": 0, "d": 0, "live": {}, "held": {}}
		# Two weeks are kept (this one and the last: the champion is worked out from it).
		while weeks.size() > WEEKS_KEPT:
			var oldest := ""
			for w in weeks:
				if oldest == "" or int(w) < int(oldest):
					oldest = String(w)
			weeks.erase(oldest)
	return weeks[key]


## A kill in the maze, at real time t: `killer` and `victim` each {kind: "hero" | "ai" |
## "real", name, index}. Only a kill between players counts; the hero's is saved, a live
## world player's counts for it on this device (its slot is held). True when it counted.
static func record_kill(killer: Dictionary, victim: Dictionary, t: float = -1.0) -> bool:
	if t < 0.0:
		t = now()
	var kk := String(killer.get("kind", ""))
	var vk := String(victim.get("kind", ""))
	if not (kk in ["hero", "ai", "real"]) or not (vk in ["hero", "ai", "real"]):
		return false
	if kk == vk and kk == "hero":
		return false
	if kk != "hero" and String(killer.get("name", "")) != "" and String(killer.get("name", "")) == String(victim.get("name", "")):
		return false
	if not Game.has_profile:
		return false
	var b := _book_for(week_of(t))
	if kk == "hero":
		b.k = mini(KILLS_MAX, int(b.get("k", 0)) + 1)
		b.at = int(t)
	elif kk == "ai":
		var name := String(killer.get("name", "")).left(NAME_MAX)
		var live: Dictionary = b.live
		if not live.has(name) and live.size() >= LIVE_MAX:
			return false
		var v: Array = live.get(name, [0, 0])
		live[name] = [mini(KILLS_MAX, int(v[0]) + 1), int(t)]
	else:
		return false
	if vk == "hero":
		b.d = mini(KILLS_MAX, int(b.get("d", 0)) + 1)
	revision += 1
	Game.mark_dirty()
	return true


## The hero fell (to someone it counted no kill for: a real player is the server's).
static func record_death(t: float = -1.0) -> void:
	if not Game.has_profile:
		return
	if t < 0.0:
		t = now()
	var b := _book_for(week_of(t))
	b.d = mini(KILLS_MAX, int(b.get("d", 0)) + 1)
	Game.mark_dirty()


## World player i fights live here at real time t: its slot's simulated fights are
## dropped on this device (its live kills count instead).
static func hold(i: int, t: float = -1.0) -> void:
	if t < 0.0:
		t = now()
	if not Game.has_profile or i < 0:
		return
	var k := slot_of(t)
	if k < 0:
		return
	var b := _book_for(week_of(t))
	var held: Dictionary = b.held
	var name := String(WorldPlayers.entry(i).name).left(NAME_MAX)
	if not held.has(name) and held.size() >= LIVE_MAX:
		return
	var list: Array = held.get(name, [])
	if list.has(k):
		return
	list.append(k)
	held[name] = list
	revision += 1
	Game.mark_dirty()


static func is_held(i: int, t: float) -> bool:
	return _held_set(week_of(t)).has(i * 100000 + slot_of(t))


static func _held_set(week: int) -> Dictionary:
	var out := {}
	var held: Dictionary = week_book(week).get("held", {})
	for name in held:
		var i := WorldPlayers.index_of(String(name))
		if i < 0:
			continue
		for k in held[name]:
			out[i * 100000 + int(k)] = true
	return out


static func _held_rev(week: int) -> int:
	var held: Dictionary = week_book(week).get("held", {})
	var n := 0
	for name in held:
		n += (held[name] as Array).size() * 31 + String(name).length()
	return n


## A save's record (Game._valid_profile; accounts.js validMaze keeps the same rules).
static func valid(v: Variant) -> bool:
	if not v is Dictionary:
		return false
	for key in v:
		if not key is String or not (key in ["weeks", "champs"]):
			return false
	var weeks: Variant = v.get("weeks", {})
	var champs: Variant = v.get("champs", {})
	if not weeks is Dictionary or (weeks as Dictionary).size() > 4 or not champs is Dictionary or (champs as Dictionary).size() > CHAMPS_KEPT + 4:
		return false
	for w in weeks:
		var b: Variant = weeks[w]
		if not w is String or not (w as String).is_valid_int() or not b is Dictionary:
			return false
		for key in b:
			if not (key in ["k", "at", "d", "live", "held"]):
				return false
		if not _int_ok(b.get("k", 0), 0, KILLS_MAX) or not _int_ok(b.get("d", 0), 0, KILLS_MAX) or not _int_ok(b.get("at", 0), 0, 100000000000):
			return false
		var live: Variant = b.get("live", {})
		var held: Variant = b.get("held", {})
		if not live is Dictionary or (live as Dictionary).size() > LIVE_MAX or not held is Dictionary or (held as Dictionary).size() > LIVE_MAX:
			return false
		for name in live:
			var e: Variant = live[name]
			if not name is String or (name as String).length() > NAME_MAX or not e is Array or (e as Array).size() != 2 \
					or not _int_ok(e[0], 0, KILLS_MAX) or not _int_ok(e[1], 0, 100000000000):
				return false
		for name in held:
			var e: Variant = held[name]
			if not name is String or (name as String).length() > NAME_MAX or not e is Array or (e as Array).size() > 1100:
				return false
			for k in e:
				if not _int_ok(k, 0, 10000000):
					return false
	for w in champs:
		var c: Variant = champs[w]
		if not w is String or not (w as String).is_valid_int() or not c is Dictionary:
			return false
		if not c.get("name", "") is String or String(c.get("name", "")).length() > 64 or not _int_ok(c.get("kills", 0), 0, KILLS_MAX) \
				or not c.get("hero", false) is bool or not _int_ok(c.get("index", -1), -1, 1000000):
			return false
	return true


static func _int_ok(v: Variant, lo: int, hi: int) -> bool:
	if not (v is int or v is float):
		return false
	var f := float(v)
	return f == floor(f) and f >= float(lo) and f <= float(hi)


## Ints back from JSON floats (Game._repair); a broken record is dropped.
static func repair(data: Dictionary) -> void:
	if not data.has(KEY):
		return
	if not valid(data[KEY]):
		data.erase(KEY)
		return
	var d: Dictionary = data[KEY]
	var weeks: Dictionary = d.get("weeks", {})
	for w in weeks:
		var b: Dictionary = weeks[w]
		for key in ["k", "at", "d"]:
			b[key] = int(b.get(key, 0))
		var live: Dictionary = b.get("live", {})
		for name in live:
			live[name] = [int(live[name][0]), int(live[name][1])]
		b["live"] = live
		var held: Dictionary = b.get("held", {})
		for name in held:
			held[name] = (held[name] as Array).map(func(k): return int(k))
		b["held"] = held
	d["weeks"] = weeks
	var champs: Dictionary = d.get("champs", {})
	for w in champs:
		var c: Dictionary = champs[w]
		champs[w] = {"name": String(c.get("name", "")), "kills": int(c.get("kills", 0)), "hero": bool(c.get("hero", false)), "index": int(c.get("index", -1))}
	d["champs"] = champs


# --- The server's board (real players) ---------------------------------------------

## A frame from the server (Online): `maze_board` {week, rows: [{name, kills, ago}]} on
## joining, `maze_kill` {week, name, kills, ago, by, ai} for a real player's kill. `ago`
## is milliseconds before now on the server's clock. Returns the kill frame's `by` (a
## player id, "" for none): the zone credits the hero when it is its own.
static func receive(msg: Dictionary) -> String:
	var t := now()
	var week := int(msg.get("week", week_of(t))) if (msg.get("week") is int or msg.get("week") is float) else week_of(t)
	if absi(week - week_of(t)) > 1:
		return ""
	var list: Array = msg.get("rows", []) if msg.get("rows") is Array else [msg]
	if not _real.has(week):
		_real[week] = {}
	var board: Dictionary = _real[week]
	for e in list.slice(0, 256):
		if not e is Dictionary:
			continue
		var name := str(e.get("name", "")).strip_edges().left(NAME_MAX) if e.get("name") is String else ""
		var kills: Variant = e.get("kills")
		if name == "" or not (kills is int or kills is float) or bool(e.get("ai", false)):
			continue
		var ago := float(e.get("ago", 0)) / 1000.0 if (e.get("ago") is int or e.get("ago") is float) else 0.0
		board[name] = {"kills": clampi(int(kills), 0, KILLS_MAX), "at": t - clampf(ago, 0.0, 8.0 * 86400.0)}
	for w in _real.keys():
		if int(w) < week_of(t) - 1:
			_real.erase(w)
	revision += 1
	return str(msg.get("by", "")) if String(msg.get("t", "")) == "maze_kill" else ""


# --- What the world players say -----------------------------------------------------

## The chat's facts about the race for world player i at t ({} when it says nothing of
## it): %mzlead the week's first, %mzleadk its kills, %mzrank / %mzkills the speaker's
## own place and kills, all read off standings.
static func chat_vars(i: int, t: float = -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	if t < float(OPEN_UNIX) or i < 0 or not interested(i):
		return {}
	var week := week_of(t)
	var board := standings(week, t)
	if board.is_empty():
		return {}
	var out := {"%mzlead": String(board[0].name), "%mzleadk": str(int(board[0].kills)), "%maze": TITLE}
	for k in board.size():
		if int(board[k].index) == i and not bool(board[k].hero):
			out["%mzrank"] = str(k + 1)
			out["%mzkills"] = str(int(board[k].kills))
			break
	return out


## Forgets everything worked out or heard (tests).
static func reset() -> void:
	_interest.clear()
	_ready.clear()
	_power.clear()
	_cands.clear()
	_cands_n = -1
	_slots.clear()
	_sums.clear()
	_real.clear()
	_champs.clear()
	revision += 1
