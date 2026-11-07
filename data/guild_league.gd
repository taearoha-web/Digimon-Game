class_name GuildLeague
extends RefCounted
## Weekly guild league (ลีกกิลด์รายสัปดาห์): a season runs Monday 00:00 to Sunday 23:59
## Thai time (WorldEvents.day_of). Only the world's four guilds play (WorldPlayers.GUILDS:
## Alpha, Neverdie, Titan, 3DLnw). Guild wars happen on real time only, three rounds a day
## starting at SLOTS (12:00, 18:00, 21:30 Thai), each GuildWarData.DURATION long. Each
## round has two wars at once, so a day's three rounds meet all six pairs of guilds
## (MATCHINGS, rotated by the day: pairs_at). Each guild sends its GuildWarData.GUILD_SIDE
## strongest members (GuildWarData.side_ids).
##
## The hero (in a guild, Lv.100+) registers for the next round until REGISTER_CLOSE
## seconds before it starts (register); it fights only when it ranks among its guild's
## strongest GUILD_SIDE (hero_place), else it may watch (live_match_info). A round runs on
## time whether the hero registered or not. A war the hero did not fight gets a seeded
## result from both sides' real fighter power at its start (sim_war: the same on every
## device); a war the hero fought counts its live result (record_war, war_finished).
##
## Points a war (side_points): WIN or LOSS, CAPTURE per castle capture, HOLD for holding
## the castle at the bell, one per KILLS_PER_POINT falls. The castle holder is the guild that
## held it at the end of the latest war; the holder when the season ends is the week's
## champion (champion_of). For the next week every member of the champion (world players
## too) wears a gold crown plate, the hero earns EXP_BONUS more EXP (Game.add_exp, the HUD
## event chip) and may shop at the champion's secret shop (SHOP). The top three guilds'
## members claim REWARDS once (claim). Hired wars (GuildWarData.roll_match) are practice
## and count nothing here (ไม่นับคะแนนลีก).
##
## profile.league (valid / repair keep it safe in a save):
##   week, wars: the current season and the hero's real wars in it ({at (the round's
##   start), a, b, win, ca, cb, held, ka, kb}, ints); prev_week, prev_wars: the season
##   before; claimed: the season whose top-three reward was taken; ann: the season whose
##   end was announced; shop_week, shop: the season of the secret shop's buy counts
##   ({id: count}); reg: the start (unix) of the round the hero registered for; told: the
##   round whose start was told to the hero.

const KEY := "league"
## Seconds of the Thai day each round starts: 12:00, 18:00 and 21:30.
const SLOTS: Array[int] = [12 * 3600, 18 * 3600, 21 * 3600 + 30 * 60]
## Registration for a round closes this many seconds before it starts.
const REGISTER_CLOSE := 300
## The three ways to split the four guilds into two pairs; a day's three rounds take one
## each (pairs_at), so every pair meets once a day.
const MATCHINGS := [[[1, 2], [3, 4]], [[1, 3], [2, 4]], [[1, 4], [2, 3]]]
const DAY := 86400
const WIN := 30
const LOSS := 10
const CAPTURE := 5
const HOLD := 20
const KILLS_PER_POINT := 5
## A seeded war: the stronger side wins with share pa^K / (pa^K + pb^K) of total power.
const POWER_EDGE := 3.0
const EXP_BONUS := 0.1
const CROWN := "♛"
const CROWN_COLOR := Color("ffb81c")
const MAX_WARS := 64
const MAX_NUMBER := 1000000000000
## Rewards by final rank (1-3) of the season before, claimable once.
const REWARDS := {
	1: {"gold": 30000000, "jewels": {"pink": 20, "chaos": 10}},
	2: {"gold": 15000000, "jewels": {"pink": 10, "chaos": 5}},
	3: {"gold": 8000000, "jewels": {"pink": 5, "chaos": 2}},
}
## The champion's secret shop (ร้านลับแชมป์ปราสาท): gold, `limit` a season each.
## "crown" is the unique cosmetic: the title ราชันปราสาท (Achievements "t_castle_king").
const CROWN_FLAG := "lg_crown"
const SHOP: Array[Dictionary] = [
	{"id": "set_core", "kind": "jewel", "item": "set_core", "count": 1, "price": 20000000, "limit": 2},
	{"id": "chaos10", "kind": "jewel", "item": "chaos", "count": 10, "price": 3000000, "limit": 3},
	{"id": "pink20", "kind": "jewel", "item": "pink", "count": 20, "price": 2000000, "limit": 3},
	{"id": "feather3", "kind": "jewel", "item": "feather", "count": 3, "price": 4000000, "limit": 2},
	{"id": "hp_god20", "kind": "potion", "item": "hp_god", "count": 20, "price": 1000000, "limit": 5},
	{"id": "mp_xxl20", "kind": "potion", "item": "mp_xxl", "count": 20, "price": 500000, "limit": 5},
	{"id": "crown", "kind": "title", "item": "", "count": 1, "price": 50000000, "limit": 1},
]
const WAR_KEYS: Array[String] = ["at", "a", "b", "win", "ca", "cb", "held", "ka", "kb"]
const INT_KEYS: Array[String] = ["week", "prev_week", "claimed", "ann", "shop_week", "reg", "told"]

static var _sim_cache := {}
static var _power_cache := {}
static var _champ_cache := {}
## The league war being fought now ({ours, theirs, at}; {} for a practice war). Set by
## GuildWarMatch when it builds a league war; war_finished records it and clears it.
static var current_match := {}


# --- Guilds and time ---------------------------------------------------------------

static func ids() -> Array[int]:
	return WorldPlayers.GUILDS.duplicate()


static func name_of(g: int) -> String:
	return WorldPlayers.guild_name(g)


static func color_of(g: int) -> Color:
	return WorldPlayers.GUILD_COLORS.get(g, Color.WHITE)


## Season index at t: weeks from Monday 00:00 Thai (day 0 of the epoch was a Thursday).
static func week_of(t: float) -> int:
	return floori(float(WorldEvents.day_of(t) + 3) / 7.0)


## Unix time the season `w` starts (Monday 00:00 Thai).
static func week_start(w: int) -> float:
	return float(w * 7 - 3) * float(DAY) - float(WorldPlayers.TZ)


static func week_end(w: int) -> float:
	return week_start(w + 1)


# --- The schedule ------------------------------------------------------------------

## Unix time round k (0-2) of Thai day `day` starts.
static func slot_start(day: int, k: int) -> int:
	return day * DAY - WorldPlayers.TZ + SLOTS[k]


## The two pairs that fight in round k of Thai day `day`: [[a, b], [c, d]].
static func pairs_on(day: int, k: int) -> Array:
	return MATCHINGS[posmod(day + k, MATCHINGS.size())]


## The pairs of the round starting at unix `at` ([] when no round starts then).
static func pairs_at(at: int) -> Array:
	var day := WorldEvents.day_of(float(at))
	for k in SLOTS.size():
		if slot_start(day, k) == at:
			return pairs_on(day, k)
	return []


## Who guild g meets in the round starting at `at` (0 when none).
static func opponent(g: int, at: int) -> int:
	for p in pairs_at(at):
		if int(p[0]) == g:
			return int(p[1])
		if int(p[1]) == g:
			return int(p[0])
	return 0


## Every round of Thai day `day`: [{at, k, pairs}], in time order.
static func rounds_on(day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in SLOTS.size():
		out.append({"at": slot_start(day, k), "k": k, "pairs": pairs_on(day, k)})
	return out


## Every war of season w: [{at, a, b}] in time order (7 days x 3 rounds x 2 wars).
static func schedule(w: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var first := WorldEvents.day_of(week_start(w))
	for d in 7:
		for r in rounds_on(first + d):
			for p in r.pairs:
				out.append({"at": int(r.at), "a": int(p[0]), "b": int(p[1])})
	return out


## The start of the round being fought at t (start <= t < start + DURATION), else -1.
static func live_slot(t: float) -> int:
	var day := WorldEvents.day_of(t)
	for d in [day - 1, day]:
		for k in SLOTS.size():
			var at := slot_start(d, k)
			if t >= float(at) and t < float(at) + GuildWarData.DURATION:
				return at
	return -1


## The start of the first round that starts after t.
static func next_slot(t: float) -> int:
	var day := WorldEvents.day_of(t)
	for d in [day, day + 1]:
		for k in SLOTS.size():
			var at := slot_start(d, k)
			if float(at) > t:
				return at
	return slot_start(day + 2, 0)


## "12:00" for a round's start.
static func clock_text(at: int) -> String:
	var s := posmod(at + WorldPlayers.TZ, DAY)
	return "%02d:%02d" % [s / 3600, (s % 3600) / 60]


## A guild's might at the round starting `at`: the summed fighter power of its
## GUILD_SIDE strongest members then (WorldPlayers.fighter), 0 with nobody at Lv.100.
static func side_power(g: int, at: int) -> float:
	var key := "%d|%d" % [g, at]
	if _power_cache.has(key):
		return float(_power_cache[key])
	if _power_cache.size() > 400:
		_power_cache.clear()
	var total := 0.0
	for i in GuildWarData.best_members(g, float(at), GuildWarData.GUILD_SIDE):
		total += float(WorldPlayers.fighter(i, float(at)).power)
	_power_cache[key] = total
	return total


## The seeded result of the war a vs b in the round starting `at`, fought without the
## hero: from both sides' real power then and a seed of the round alone, so every device
## agrees. {} when a side has nobody at Lv.100 yet (no war).
static func sim_war(at: int, a: int, b: int) -> Dictionary:
	var key := "%d|%d|%d" % [at, a, b]
	if _sim_cache.has(key):
		return _sim_cache[key]
	if _sim_cache.size() > 200:
		_sim_cache.clear()
	var pa := side_power(a, at)
	var pb := side_power(b, at)
	var out := {}
	if pa > 0.0 and pb > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("guild_league_war|%d|%d|%d" % [at, a, b])
		var ea := pow(pa, POWER_EDGE)
		var eb := pow(pb, POWER_EDGE)
		var win := a if rng.randf() < ea / (ea + eb) else b
		var held := win if rng.randf() < 0.7 else 0
		var cw := rng.randi_range(1, 3) if held > 0 else rng.randi_range(0, 1)
		var cl := rng.randi_range(0, 1 if held > 0 else 2)
		var kw := rng.randi_range(25, 70)
		var kl := rng.randi_range(10, kw)
		out = {"at": at, "a": a, "b": b, "win": win, "held": held,
			"ca": cw if win == a else cl, "cb": cw if win == b else cl, "ka": kw if win == a else kl, "kb": kw if win == b else kl}
	_sim_cache[key] = out
	return out


## The hero's real war of round `at` between a and b in `real` ({} when none).
static func _real_for(real: Array, at: int, a: int, b: int) -> Dictionary:
	for e in real:
		if e is Dictionary and int(e.get("at", -1)) == at and ((int(e.a) == a and int(e.b) == b) or (int(e.a) == b and int(e.b) == a)):
			return e
	return {}


## Kept for the screens and tests: every seeded war of season w that has a result (both
## sides had someone at Lv.100), in time order.
static func sim_wars(w: int) -> Array:
	var out: Array = []
	for m in schedule(w):
		var e := sim_war(int(m.at), int(m.a), int(m.b))
		if not e.is_empty():
			out.append(e)
	return out


## Points guild g earns from war e.
static func side_points(e: Dictionary, g: int) -> int:
	if int(e.a) != g and int(e.b) != g:
		return 0
	var ours := int(e.a) == g
	var p := WIN if int(e.win) == g else LOSS
	p += CAPTURE * int(e.ca if ours else e.cb)
	p += HOLD if int(e.held) == g else 0
	p += int(e.ka if ours else e.kb) / KILLS_PER_POINT
	return p


## The wars of season w over by `until`, time order: the hero's real war of a round in
## place of its seeded one (counted as soon as it is recorded), every other war once its
## round has ended. A real war that is not on the schedule counts nothing.
static func events(w: int, real: Array, until := INF) -> Array:
	var out: Array = []
	for m in schedule(w):
		var at := int(m.at)
		if float(at) > until:
			break
		var mine := _real_for(real, at, int(m.a), int(m.b))
		if not mine.is_empty():
			var copy: Dictionary = mine.duplicate()
			copy["real"] = true
			out.append(copy)
		elif float(at) + GuildWarData.DURATION <= until:
			var e := sim_war(at, int(m.a), int(m.b))
			if not e.is_empty():
				out.append(e)
	return out


## The table of season w at `until`: [{rank, g, name, points, wins, losses, captures, held,
## kills}], best first (points, wins, captures).
static func table(w: int, real: Array, until := INF) -> Array[Dictionary]:
	var rows := {}
	for g in ids():
		rows[g] = {"g": g, "name": name_of(g), "points": 0, "wins": 0, "losses": 0, "captures": 0, "held": 0, "kills": 0}
	for e in events(w, real, until):
		for side in [[int(e.a), "ca", "ka"], [int(e.b), "cb", "kb"]]:
			var g := int(side[0])
			if not rows.has(g):
				continue
			var r: Dictionary = rows[g]
			r.points = int(r.points) + side_points(e, g)
			if int(e.win) == g:
				r.wins = int(r.wins) + 1
			else:
				r.losses = int(r.losses) + 1
			r.captures = int(r.captures) + int(e[side[1]])
			r.kills = int(r.kills) + int(e[side[2]])
			if int(e.held) == g:
				r.held = int(r.held) + 1
	var out: Array[Dictionary] = []
	for g in rows:
		out.append(rows[g])
	out.sort_custom(func(x, y):
		if int(x.points) != int(y.points):
			return int(x.points) > int(y.points)
		if int(x.wins) != int(y.wins):
			return int(x.wins) > int(y.wins)
		if int(x.captures) != int(y.captures):
			return int(x.captures) > int(y.captures)
		return int(x.g) < int(y.g))
	for k in out.size():
		out[k]["rank"] = k + 1
	return out


## Who holds the castle at `until` in season w: the guild that held it at the end of the
## latest war, else last season's champion (on the seeded wars alone).
static func holder(w: int, real: Array, until := INF) -> int:
	var held := _last_holder(w, real, until)
	return held if held > 0 else champion_of(w - 1, [])


## The guild holding the castle after the latest round of season w over by `until` in
## which a guild held it at the bell (0 when none did). Both wars of a round end at once:
## if both ended with a holder, the one that earned more in its war takes the castle (then
## more captures, then the lower guild id). Walks back from the latest round, so only the
## last few wars are worked out (each a seeded result from fighter power).
static func _last_holder(w: int, real: Array, until := INF) -> int:
	var list := schedule(w)
	var k := list.size() - 1
	while k >= 0:
		var at := int(list[k].at)
		var best := 0
		var best_key := -1
		while k >= 0 and int(list[k].at) == at:
			var m: Dictionary = list[k]
			k -= 1
			if float(at) > until:
				continue
			var e := _real_for(real, at, int(m.a), int(m.b))
			if e.is_empty() and float(at) + GuildWarData.DURATION <= until:
				e = sim_war(at, int(m.a), int(m.b))
			if e.is_empty() or int(e.held) <= 0:
				continue
			var g := int(e.held)
			var key := side_points(e, g) * 1000 + int(e.ca if int(e.a) == g else e.cb) * 10 + (9 - g)
			if key > best_key:
				best = g
				best_key = key
		if best > 0:
			return best
	return 0


## The champion of season w: the castle holder when it ended (the top guild if nobody held it).
static func champion_of(w: int, real: Array) -> int:
	var last_at := 0
	for e in real:
		if e is Dictionary:
			last_at = maxi(last_at, int(e.get("at", 0)))
	var key := "%d|%d|%d" % [w, real.size(), last_at]
	if _champ_cache.has(key):
		return int(_champ_cache[key])
	if _champ_cache.size() > 16:
		_champ_cache.clear()
	var champ := _last_holder(w, real)
	if champ == 0:
		champ = int(table(w, real)[0].g)
	_champ_cache[key] = champ
	return champ


static func rank_of(w: int, real: Array, g: int) -> int:
	for r in table(w, real):
		if int(r.g) == g:
			return int(r.rank)
	return 0


# --- The hero's league record (Game.profile.league) -------------------------------

static func now() -> float:
	return WorldPresence.clock()


## The hero's league record, moved on to the season of t (the old season's real wars
## become prev_wars). {} without a profile.
static func data(t := -1.0) -> Dictionary:
	if not Game.has_profile:
		return {}
	if t < 0.0:
		t = now()
	var w := week_of(t)
	var d: Variant = Game.profile.get(KEY)
	if not d is Dictionary:
		d = {"week": w, "wars": [], "prev_week": w - 1, "prev_wars": []}
		Game.profile[KEY] = d
	var old := int(d.get("week", w))
	if old != w:
		d["prev_week"] = w - 1
		d["prev_wars"] = d.get("wars", []) if old == w - 1 else []
		d["wars"] = []
		d["week"] = w
		Game.mark_dirty()
	return d


## The hero's real wars of season w ([] when not kept).
static func real_wars(w: int) -> Array:
	var d := data()
	if d.is_empty():
		return []
	if int(d.get("week", 0)) == w:
		return d.get("wars", [])
	if int(d.get("prev_week", 0)) == w:
		return d.get("prev_wars", [])
	return []


## Last season's champion as this device sees it (the hero's real wars of that season in).
static func champion_now(t := -1.0) -> int:
	if t < 0.0:
		t = now()
	var w := week_of(t) - 1
	return champion_of(w, real_wars(w) if Game.has_profile else [])


## The hero's guild won last season's castle.
static func hero_champion(t := -1.0) -> bool:
	var g := Game.guild()
	return g > 0 and champion_now(t) == g


## A world guild (WorldPlayers) whose members wear the crown plate this week.
static func crowned(g: int) -> bool:
	return g > 0 and champion_now() == g


## The EXP multiplier of the champion's members (Game.add_exp).
static func exp_mult(t := -1.0) -> float:
	return 1.0 + EXP_BONUS if hero_champion(t) else 1.0


## The HUD event chip's line ("" when the hero is not a champion).
static func chip_text(t := -1.0) -> String:
	if t < 0.0:
		t = now()
	if not hero_champion(t):
		return ""
	var left := week_end(week_of(t)) - t
	var span := "%d วัน" % int(ceil(left / float(DAY))) if left > float(DAY) else "%d ชม." % maxi(1, int(ceil(left / 3600.0)))
	return "%s แชมป์ปราสาท EXP +%d%% เหลือ %s" % [CROWN, int(EXP_BONUS * 100.0), span]


## Records the hero's real guild war: `ours` / `theirs` are the guilds (WorldPlayers),
## captures and falls of each side, who held the castle at the bell (-1 nobody, 0 ours,
## 1 theirs), `t` the start of the round it was (it takes that war's place in the table;
## a war off the schedule counts nothing). Returns the league points our guild earned (0
## outside a guild or without a rival).
static func record_war(ours: int, theirs: int, won: bool, caps_us: int, caps_them: int, held: int, kills_us: int, kills_them: int, t := -1.0) -> int:
	if ours <= 0 or not WorldPlayers.GUILD_NAMES.has(ours) or not Game.has_profile:
		return 0
	if theirs <= 0 or theirs == ours or not WorldPlayers.GUILD_NAMES.has(theirs):
		return 0
	if t < 0.0:
		t = now()
	var d := data(t)
	var e := {"at": int(t), "a": ours, "b": theirs, "win": ours if won else theirs,
		"ca": maxi(0, caps_us), "cb": maxi(0, caps_them), "held": ours if held == 0 else (theirs if held == 1 else 0),
		"ka": maxi(0, kills_us), "kb": maxi(0, kills_them)}
	var wars: Array = d.get("wars", [])
	# One result a war: fighting the same round again (a rejoin) replaces it.
	var same := _real_for(wars, int(t), ours, theirs)
	if not same.is_empty():
		wars.erase(same)
	wars.append(e)
	while wars.size() > MAX_WARS:
		wars.pop_front()
	d["wars"] = wars
	Game.mark_dirty()
	return side_points(e, ours)


## A guild war just ended (GuildWarMatch): the league war being fought (current_match)
## counts its live result for the hero's guild and its rival; a practice war counts
## nothing here; every war counts for the daily quests ("guild_war", and "league" when the
## guild earned points). Puts the points in result.league.
static func war_finished(result: Dictionary, real_guilds: bool, caps: Array, held: int, score: Array) -> int:
	var pts := 0
	var m := current_match
	current_match = {}
	if real_guilds and not m.is_empty() and Game.guild() > 0 and int(m.ours) == Game.guild():
		pts = record_war(int(m.ours), int(m.theirs), bool(result.get("won", false)),
			int(caps[0]), int(caps[1]), held, int(score[0]), int(score[1]), float(m.at))
	result["league"] = pts
	if Game.has_method("daily_progress"):
		Game.call("daily_progress", "guild_war", 1)
		if pts > 0:
			Game.call("daily_progress", "league", pts)
	return pts


## A league war the hero watched to the end (GuildWarSpectate): its live result takes the
## seeded war's place for that round (match_info.league_match [a, b], slot_start), the way
## the hero's own war does (record_war: a rewatch of the round replaces it). Side A of
## the match_info is a (ally), side B is b. Nothing is paid and no daily quest moves.
## Returns the league points a earned (0 when [a, b] is not on the schedule at slot_start).
static func spectated_result(match_info: Dictionary, result: Dictionary) -> int:
	var pair: Variant = match_info.get("league_match", [])
	if not (pair is Array) or (pair as Array).size() != 2:
		return 0
	var a := int(pair[0]) if typeof(pair[0]) in [TYPE_INT, TYPE_FLOAT] else 0
	var b := int(pair[1]) if typeof(pair[1]) in [TYPE_INT, TYPE_FLOAT] else 0
	var at := int(match_info.get("slot_start", 0))
	if a <= 0 or b <= 0 or at <= 0:
		return 0
	var scheduled := false
	for p in pairs_at(at):
		if (int(p[0]) == a and int(p[1]) == b) or (int(p[0]) == b and int(p[1]) == a):
			scheduled = true
	if not scheduled:
		return 0
	var caps: Array = result.get("captures", [0, 0])
	var score: Array = result.get("score", [0, 0])
	var winner := int(result.get("winner", -1))
	# A level bell (no holder, the same falls) is not a win for a.
	return record_war(a, b, winner == 0, int(caps[0]), int(caps[1]), int(result.get("castle_owner", -1)),
		int(score[0]), int(score[1]), float(at))


## The top-three reward the hero may claim now: {rank, gold, jewels, week} or {}.
static func claimable(t := -1.0) -> Dictionary:
	var g := Game.guild()
	if g <= 0:
		return {}
	var d := data(t)
	var w := week_of(now() if t < 0.0 else t) - 1
	if int(d.get("claimed", -1)) == w:
		return {}
	var rank := rank_of(w, real_wars(w), g)
	if not REWARDS.has(rank):
		return {}
	var out: Dictionary = (REWARDS[rank] as Dictionary).duplicate(true)
	out["rank"] = rank
	out["week"] = w
	return out


## Takes last season's top-three reward once. "ok" or a reason.
static func claim(t := -1.0) -> String:
	if Game.guild() <= 0:
		return "ต้องอยู่ในกิลด์ก่อน"
	var d := data(t)
	var w := week_of(now() if t < 0.0 else t) - 1
	if int(d.get("claimed", -1)) == w:
		return "รับรางวัลลีกของฤดูกาลที่แล้วไปแล้ว"
	var reward := claimable(t)
	if reward.is_empty():
		return "กิลด์ของคุณไม่ติด 3 อันดับแรกเมื่อฤดูกาลที่แล้ว"
	d["claimed"] = w
	Game.add_gold(int(reward.gold))
	for id in reward.jewels:
		Game.give_or_store(ItemData.jewel(String(id), int(reward.jewels[id])))
	Game.mark_dirty()
	Game.save()
	return "ok"


static func reward_text(reward: Dictionary) -> String:
	var parts: PackedStringArray = ["%s ทอง" % GuildScreen._num(int(reward.get("gold", 0)))]
	var jewels: Dictionary = reward.get("jewels", {})
	for id in jewels:
		parts.append("%s ×%d" % [ItemData.JEWELS[id].name, int(jewels[id])])
	return " · ".join(parts)


# --- The champion's secret shop ---------------------------------------------------

static func shop_entry(id: String) -> Dictionary:
	for e in SHOP:
		if String(e.id) == id:
			return e
	return {}


static func shop_name(e: Dictionary) -> String:
	if String(e.kind) == "title":
		return "ตำแหน่ง \"ราชันปราสาท\" (ของสะสมเฉพาะแชมป์)"
	var item := shop_item(e)
	return "%s ×%d" % [ItemData.name_of(item), int(e.count)]


static func shop_item(e: Dictionary) -> Dictionary:
	match String(e.kind):
		"potion": return ItemData.potion(String(e.item), int(e.count))
		"jewel": return ItemData.jewel(String(e.item), int(e.count))
	return {}


## How many of entry `id` the hero bought this season.
static func shop_bought(id: String, t := -1.0) -> int:
	var d := data(t)
	if d.is_empty() or int(d.get("shop_week", -1)) != week_of(now() if t < 0.0 else t):
		return 0
	return int((d.get("shop", {}) as Dictionary).get(id, 0))


## Why entry e cannot be bought now ("" when it can).
static func shop_problem(e: Dictionary, t := -1.0) -> String:
	if not hero_champion(t):
		return "ร้านลับเปิดให้สมาชิกกิลด์แชมป์ปราสาทเท่านั้น"
	if String(e.kind) == "title" and int(Game.profile["flags"].get(CROWN_FLAG, 0)) > 0:
		return "มีตำแหน่งนี้แล้ว"
	if shop_bought(String(e.id), t) >= int(e.limit):
		return "ซื้อครบ %d ครั้งของสัปดาห์นี้แล้ว" % int(e.limit)
	if int(Game.profile.gold) < int(e.price):
		return "ทองไม่พอ"
	return ""


## Buys from the secret shop. "ok" or a reason.
static func shop_buy(id: String, t := -1.0) -> String:
	var e := shop_entry(id)
	if e.is_empty():
		return "ไม่มีสินค้านี้"
	var problem := shop_problem(e, t)
	if problem != "":
		return problem
	if String(e.kind) == "title":
		if not Game.spend_gold(int(e.price)):
			return "ทองไม่พอ"
		Game.profile["flags"][CROWN_FLAG] = 1
		Game.check_achievements()
	else:
		var item := shop_item(e)
		if Game.inventory_free() <= 0 and Game.storage().size() >= Game.STORAGE_SIZE:
			return "กระเป๋าและคลังเต็ม"
		if not Game.spend_gold(int(e.price)):
			return "ทองไม่พอ"
		Game.give_or_store(item)
	var d := data(t)
	var w := week_of(now() if t < 0.0 else t)
	if int(d.get("shop_week", -1)) != w:
		d["shop_week"] = w
		d["shop"] = {}
	var bought: Dictionary = d.get("shop", {})
	bought[id] = int(bought.get(id, 0)) + 1
	d["shop"] = bought
	Game.mark_dirty()
	return "ok"


# --- Week-end announcement (Game._process) ------------------------------------------

## Once a season: tells the hero who won the last one (toast and world chat), and what it
## means for the hero. True when it announced now.
static func tick(t := -1.0) -> bool:
	if not Game.has_profile:
		return false
	if t < 0.0:
		t = now()
	var d := data(t)
	tell_round(t)
	var w := week_of(t)
	if int(d.get("ann", -1)) == w:
		return false
	d["ann"] = w
	Game.mark_dirty()
	var champ := champion_now(t)
	var line := "กิลด์ %s ครองปราสาทประจำสัปดาห์!" % name_of(champ)
	Game.say(line, &"quest")
	Game.post_chat("world", "ประกาศลีกกิลด์", line, CROWN_COLOR)
	if hero_champion(t):
		Game.say("%s กิลด์ของคุณเป็นแชมป์: EXP +%d%% ทั้งสัปดาห์ และร้านลับแชมป์เปิดแล้ว" % [CROWN, int(EXP_BONUS * 100.0)], &"success")
	if not claimable(t).is_empty():
		Game.say("กิลด์ของคุณติด 3 อันดับแรก! รับรางวัลได้ที่หน้าลีกกิลด์", &"success")
	# The hero's name plate wears (or drops) the crown.
	Game.title_changed.emit(Achievements.title_of(Game.profile))
	return true


# --- Registration and the live rounds -----------------------------------------------

## Why the hero cannot register for the round starting `at` at time t ("" when it can).
static func register_problem(at: int, t := -1.0) -> String:
	if t < 0.0:
		t = now()
	if not Game.has_profile or int(Game.profile.level) < Game.GUILD_LEVEL:
		return "ต้องเลเวล %d ขึ้นไป" % Game.GUILD_LEVEL
	if Game.guild() <= 0:
		return "เข้ากิลด์ที่นายทะเบียนกิลด์ก่อน"
	if t >= float(at - REGISTER_CLOSE):
		return "ปิดรับสมัครแล้ว (ปิดก่อนเริ่ม %d นาที)" % (REGISTER_CLOSE / 60)
	if opponent(Game.guild(), at) <= 0:
		return "ไม่มีรอบนี้"
	return ""


## Registers the hero for the next round (the first to start after t). "ok" or a reason.
static func register(t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var at := next_slot(t)
	var problem := register_problem(at, t)
	if problem != "":
		return problem
	var d := data(t)
	d["reg"] = at
	Game.mark_dirty()
	return "ok"


## Takes the hero off the next round's list (before registration closes). "ok" or a reason.
static func unregister(t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var at := next_slot(t)
	if not registered(at):
		return "ยังไม่ได้สมัครรอบนี้"
	if t >= float(at - REGISTER_CLOSE):
		return "ปิดรับสมัครแล้ว"
	data(t)["reg"] = -1
	Game.mark_dirty()
	return "ok"


## The hero registered for the round starting `at`.
static func registered(at: int) -> bool:
	var d := data()
	return not d.is_empty() and int(d.get("reg", -1)) == at


## The hero's place in its guild for the round starting `at` (1 = strongest, by the same
## measure as the world players: GuildWarData.hero_rank_point / rank_point); 0 outside a guild.
static func hero_place(at: int) -> int:
	var g := Game.guild()
	if g <= 0:
		return 0
	return GuildWarData.hero_rank(g, float(at), GuildWarData.hero_rank_point())


## The hero ranks among its guild's GuildWarData.GUILD_SIDE strongest for round `at`.
static func hero_makes_side(at: int) -> bool:
	var place := hero_place(at)
	return place > 0 and place <= GuildWarData.GUILD_SIDE


## Why the hero cannot go into the war being fought at t ("" when it can): a round must
## be on, the hero registered for it, in the line-up (top GUILD_SIDE), not done with it.
static func enter_problem(t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var g := Game.guild()
	if g <= 0:
		return "เข้ากิลด์ที่นายทะเบียนกิลด์ก่อน"
	var at := live_slot(t)
	if at < 0:
		return "ยังไม่ถึงเวลาสงคราม (รอบถัดไป %s)" % clock_text(next_slot(t))
	if not registered(at):
		return "ไม่ได้สมัครรอบนี้ — ชมการแข่งขันได้"
	if not hero_makes_side(at):
		return "อันดับในกิลด์ #%d ไม่ติด %d อันดับ — ชมการแข่งขันได้" % [hero_place(at), GuildWarData.GUILD_SIDE]
	var rival := opponent(g, at)
	if not _real_for(real_wars(week_of(float(at))), at, g, rival).is_empty():
		return "ลงสงครามรอบนี้ไปแล้ว"
	var blocked := GuildWarData.guild_war_blocked(g, rival, float(at))
	if blocked != "":
		return blocked
	return ""


## The league war the hero goes into now: {ours, theirs, at} ({} when it cannot).
static func enter_match(t := -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	if enter_problem(t) != "":
		return {}
	var at := live_slot(t)
	return {"ours": Game.guild(), "theirs": opponent(Game.guild(), at), "at": at}


## Tells the hero once when the round it registered for begins (toast and war chat).
static func tell_round(t := -1.0) -> bool:
	if t < 0.0:
		t = now()
	var at := live_slot(t)
	if at < 0 or not registered(at):
		return false
	var d := data(t)
	if int(d.get("told", -1)) == at:
		return false
	d["told"] = at
	Game.mark_dirty()
	var rival := opponent(Game.guild(), at)
	var line := "สงครามกิลด์รอบ %s เริ่มแล้ว: %s ปะทะ %s" % [clock_text(at), name_of(Game.guild()), name_of(rival)]
	if hero_makes_side(at):
		Game.say(line + " — ไปที่ผู้บัญชาการสงครามกิลด์แล้วกด เข้าสู่สงคราม (มาสายก็เข้าได้จนจบรอบ)", &"quest")
	else:
		Game.say(line + " — อันดับในกิลด์ไม่ติด %d อันดับ ไปชมการแข่งขันได้" % GuildWarData.GUILD_SIDE, &"quest")
	Game.post_chat("guild", "ประกาศสงครามกิลด์", line, CROWN_COLOR)
	return true


## The state of war a vs b in the round starting `at` at time t: "wait", "live" or
## "done" (with "war": its result, {} when nobody fought for want of members).
static func match_state(at: int, a: int, b: int, t := -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	if t < float(at):
		return {"state": "wait"}
	var real := _real_for(real_wars(week_of(float(at))), at, a, b)
	if not real.is_empty():
		return {"state": "done", "war": real, "real": true}
	if t < float(at) + GuildWarData.DURATION:
		return {"state": "live"}
	return {"state": "done", "war": sim_war(at, a, b)}


## What a spectator needs to watch war a vs b of the round live at t (GuildWarSpectate):
## the shape of GuildWarData.roll_guild_match (a as "ally", b as "enemy", GUILD_SIDE each,
## the hero not in it) plus elapsed (seconds since the round began), league_match [a, b]
## and slot_start. {} when no round is on or a side has nobody at Lv.100.
static func live_match_info(a: int, b: int, t := -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	var at := live_slot(t)
	if at < 0 or opponent(a, at) != b:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("guild_league_live|%d|%d|%d" % [at, a, b])
	var info := GuildWarData.roll_guild_match(rng, a, b, float(at), -1.0, false)
	if info.is_empty():
		return {}
	info["elapsed"] = t - float(at)
	info["league_match"] = [a, b]
	info["slot_start"] = at
	return info


## The guild g meets next (in the round live at t, else the next one); 0 outside a guild.
static func next_rival(g: int, t := -1.0) -> int:
	if g <= 0:
		return 0
	if t < 0.0:
		t = now()
	var at := live_slot(t)
	return opponent(g, at if at >= 0 else next_slot(t))


## The rival guild of the war on now (GuildWarMatch.current's), else the next one's.
static func war_rival() -> int:
	var m := GuildWarMatch.current
	if m != null and is_instance_valid(m):
		return int(m.roster.get("enemy_guild", 0))
	return next_rival(Game.guild())


# --- Save safety (Game._valid_profile / _repair) ------------------------------------

static func _int_ok(v: Variant, lo := 0.0, hi := float(MAX_NUMBER)) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floor(float(v)) and float(v) >= lo and float(v) <= hi


static func _wars_ok(list: Variant) -> bool:
	if not list is Array or (list as Array).size() > MAX_WARS:
		return false
	for e in list:
		if not e is Dictionary or (e as Dictionary).size() != WAR_KEYS.size():
			return false
		for k in e:
			if not k is String or not WAR_KEYS.has(String(k)) or not _int_ok(e[k]):
				return false
	return true


## A save's profile.league is well formed.
static func valid(v: Variant) -> bool:
	if not v is Dictionary or (v as Dictionary).size() > 16:
		return false
	for k in v:
		if not k is String:
			return false
		var key := String(k)
		if key in INT_KEYS:
			if not _int_ok(v[k], -1.0):
				return false
		elif key == "wars" or key == "prev_wars":
			if not _wars_ok(v[k]):
				return false
		elif key == "shop":
			if not v[k] is Dictionary or (v[k] as Dictionary).size() > 16:
				return false
			for id in v[k]:
				if not id is String or not _int_ok(v[k][id], 0.0, 1000.0):
					return false
		else:
			return false
	return true


## Numbers back to ints (JSON reads them as floats); a broken record is dropped.
static func repair(profile: Dictionary) -> void:
	if not profile.has(KEY):
		return
	if not valid(profile[KEY]):
		profile.erase(KEY)
		return
	var d: Dictionary = profile[KEY]
	for key in INT_KEYS:
		if d.has(key):
			d[key] = int(d[key])
	for key in ["wars", "prev_wars"]:
		for e in d.get(key, []):
			for k in e:
				e[k] = int(e[k])
	var shop: Dictionary = d.get("shop", {})
	for id in shop:
		shop[id] = int(shop[id])
