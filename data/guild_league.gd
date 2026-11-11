class_name GuildLeague
extends RefCounted
## Weekly guild league (ลีกกิลด์รายสัปดาห์): a season runs Monday 00:00 to Sunday 23:59
## Thai time (WorldEvents.day_of). Only the world's four guilds play (WorldPlayers.GUILDS:
## Alpha, Neverdie, Titan, 3DLnw). Guild wars happen on real time only, three rounds a day
## starting at SLOTS (12:00, 18:00, 20:30 Thai; 21:30 before EARLY_FINAL_DAY), each GuildWarData.DURATION long. Each
## round is ONE castle war of all four guilds at once (every guild against every other;
## a guild with nobody at Lv.100 sits it out). Each guild sends its GuildWarData.GUILD_SIDE
## strongest members (GuildWarData.side_ids).
##
## The castle carries over: the guild holding it at a round's bell holds it when the next
## round begins (and the one after, across days and weeks) until another guild takes it in
## a war (start_holder / holder_after: a chain of holders from the world's first round).
##
## A round that has ended is frozen (LeagueRounds): the server's official result when
## known (the same on every device), else this device's own record of it, kept the first
## time it was worked out. Only a round nobody has a result of yet is seeded (sim_round),
## so a code update that changes fighter power can not rewrite the past, and the chain
## goes on from the last frozen holder. A round still running or yet to come is never
## shown as decided: the table, the holder, the champion and the desk count ended rounds
## only (and the hero's own recorded round), and a round begins with the holder after the
## latest ended round.
## The holder starts inside the castle and defends (GuildWarMatch); the seeded rounds give
## it DEFEND_EDGE.
##
## The hero (in a guild, Lv.100+) registers for the next round until REGISTER_CLOSE
## seconds before it starts (register); it fights only when it ranks among its guild's
## strongest GUILD_SIDE (hero_place), else it may watch (live_match_info). A round runs on
## time whether the hero registered or not. A war the hero did not fight gets a seeded
## result from both sides' real fighter power at its start (sim_war: the same on every
## device); a war the hero fought counts its live result (record_war, war_finished).
##
## Points a war (side_points): WIN or LOSS, CAPTURE per castle capture, HOLD for holding
## the castle at the bell, one per KILLS_PER_POINT falls. The season's last round (Sunday
## 20:30, รอบชี้ขาด: is_final) counts its placement and capture points FINAL_MULT times;
## HOLD and the falls count once. The server keeps every round's raw result: the doubling
## is applied here, when a round is scored, never stored.
##
## Two titles a week:
##   แชมป์ลีก (League Champion, league_champion_of): first in the table by points. The top
##   three guilds' members claim REWARDS once (claim).
##   ราชันปราสาท (Castle King, champion_of): the castle holder after the season's last round.
##   For the next week every member of the Castle King (world players too) wears a gold
##   crown plate, the hero earns EXP_BONUS more EXP (Game.add_exp, the HUD event chip) and
##   may shop at the Castle King's secret shop (SHOP).
## A guild that is both (emperor_of) is จักรพรรดิแห่งสัปดาห์: its members claim EMPEROR_BONUS
## and the title (Achievements "t_week_emperor") once with the weekly reward.
## Hired wars (GuildWarData.roll_match) are practice and count nothing here (ไม่นับคะแนนลีก).
##
## profile.league (valid / repair keep it safe in a save):
##   week, wars: the current season and the hero's real wars in it, ints: a round's
##   {at (its start), g1..g4 (guilds by side), k1..k4 (falls), c1..c4 (captures), held,
##   own (the holder when it began)}, or an old war's {at, a, b, win, ca, cb, held, ka, kb}; prev_week, prev_wars: the season
##   before; claimed: the season whose top-three reward was taken; emp_claimed: the season
##   whose emperor bonus was taken; ann: the season whose
##   end was announced; shop_week, shop: the season of the secret shop's buy counts
##   ({id: count}); reg: the start (unix) of the round the hero registered for; told: the
##   round whose start was told to the hero.

const KEY := "league"
## Seconds of the Thai day each round starts: 12:00, 18:00 and 20:30 (slot_start).
const SLOTS: Array[int] = [12 * 3600, 18 * 3600, 20 * 3600 + 30 * 60]
## The last round of the day moved from 21:30 to 20:30 Thai from this Thai day on
## (WorldEvents.day_of; 11 Nov 2026): rounds of earlier days stay at 21:30 so their
## stored results still match.
const EARLY_FINAL_DAY := 20768
const OLD_LAST_SLOT := 21 * 3600 + 30 * 60
## Registration for a round closes this many seconds before it starts.
const REGISTER_CLOSE := 300
## The registered line-up may wait in the arena from this long before a round starts
## (the moment registration closes; GuildWarMatch's waiting room).
const LOBBY_OPEN := REGISTER_CLOSE
## Before the four-guild rounds: the three ways to split the four guilds into two pairs
## (old records name their round's pair; pairs_at).
const MATCHINGS := [[[1, 2], [3, 4]], [[1, 3], [2, 4]], [[1, 4], [2, 3]]]
const DAY := 86400
## A round's placement points, 1st to 4th.
const PLACE_POINTS: Array[int] = [40, 25, 15, 10]
## Old two-guild wars: a win's and a loss's points.
const WIN := 30
const LOSS := 10
const CAPTURE := 5
const HOLD := 20
const KILLS_PER_POINT := 5
## A seeded war: the stronger side wins with share pa^K / (pa^K + pb^K) of total power.
const POWER_EDGE := 3.0
## The seeded rounds: the castle's holder defends with its might's weight times this, and a
## round begun with no holder ends with nobody holding it this often.
const DEFEND_EDGE := 2.0
const NOBODY_TAKES := 0.2
const EXP_BONUS := 0.1
## The deciding round (รอบชี้ขาด, is_final): the season's last round counts its placement
## and capture points this many times, from season FINAL_FROM_WEEK on (the seasons before
## were scored without it and stay as they were).
const FINAL_MULT := 2
const FINAL_FROM_WEEK := 2967
const FINAL_TAG := "รอบชี้ขาด ×2"
## The week's two titles and the emperor's, who holds both.
const LEAGUE_TITLE := "แชมป์ลีก"
const CASTLE_TITLE := "ราชันปราสาท"
const EMPEROR_TITLE := "จักรพรรดิแห่งสัปดาห์"
## The emperor's bonus, claimed once a season with the top-three reward (claim), and the
## flag of its title (Achievements "t_week_emperor").
const EMPEROR_BONUS := {"chaos": 10}
const EMPEROR_FLAG := "lg_emperor"
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
## The Castle King's secret shop (ร้านลับราชันปราสาท): gold, `limit` a season each.
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
const ROUND_KEYS: Array[String] = ["at", "g1", "g2", "g3", "g4", "k1", "k2", "k3", "k4", "c1", "c2", "c3", "c4", "held", "own"]
const INT_KEYS: Array[String] = ["week", "prev_week", "claimed", "emp_claimed", "ann", "shop_week", "reg", "told"]

static var _sim_cache := {}
static var _power_cache := {}
static var _champ_cache := {}
## The chain of castle holders: round start -> holder after it, for the records read.
static var _chain := {}
static var _chain_key := ""
static var _chain_last := 0
## Tests: added to the seeded rounds' seed (a code update that changes the seeded results).
static var sim_salt := ""
## The league round being fought now ({guilds (team order), at, owner}; {} for a practice
## war). Set by GuildWarMatch when it builds a league war; war_finished records it.
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
	var second := SLOTS[k]
	if k == SLOTS.size() - 1 and day < EARLY_FINAL_DAY:
		second = OLD_LAST_SLOT
	return day * DAY - WorldPlayers.TZ + second


## Every league guild, in id order: a round is one castle war of all of them.
static func guilds_at(_at: int) -> Array[int]:
	return ids()


## Whether a round starts at unix `at`.
static func is_round(at: int) -> bool:
	var day := WorldEvents.day_of(float(at))
	for k in SLOTS.size():
		if slot_start(day, k) == at:
			return true
	return false


## Before the four-guild war: the two pairs that fought in round k of Thai day `day`
## (records of those wars are still read and scored as they were).
static func pairs_on(day: int, k: int) -> Array:
	return MATCHINGS[posmod(day + k, MATCHINGS.size())]


## The old pairs of the round starting at unix `at` ([] when no round starts then).
static func pairs_at(at: int) -> Array:
	var day := WorldEvents.day_of(float(at))
	for k in SLOTS.size():
		if slot_start(day, k) == at:
			return pairs_on(day, k)
	return []


## Who guild g met in the old pairs of round `at` (0 when none); kept for old records.
static func opponent(g: int, at: int) -> int:
	for p in pairs_at(at):
		if int(p[0]) == g:
			return int(p[1])
		if int(p[1]) == g:
			return int(p[0])
	return 0


## Every round of Thai day `day`: [{at, k, guilds}], in time order.
static func rounds_on(day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in SLOTS.size():
		var at := slot_start(day, k)
		out.append({"at": at, "k": k, "guilds": guilds_at(at)})
	return out


## Every round of season w: [{at, guilds}] in time order (7 days x 3 rounds).
static func schedule(w: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var first := WorldEvents.day_of(week_start(w))
	for d in 7:
		for r in rounds_on(first + d):
			out.append({"at": int(r.at), "guilds": r.guilds})
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


## The start of the last round that started before `at`.
static func prev_slot(at: int) -> int:
	var day := WorldEvents.day_of(float(at))
	for d in [day, day - 1, day - 2]:
		for k in range(SLOTS.size() - 1, -1, -1):
			var s := slot_start(d, k)
			if s < at:
				return s
	return at - DAY


## The round starting `at` is over at `t` (now when -1): its bell rang.
static func ended(at: int, t := -1.0) -> bool:
	if t < 0.0:
		t = now()
	return float(at) + GuildWarData.DURATION <= t


## The start of the latest round over by t (its bell rang); before the world's first
## round is over, a time before WorldPlayers.START_UNIX.
static func last_ended(t: float) -> int:
	var at := prev_slot(next_slot(t))
	if not ended(at, t):
		at = prev_slot(at)
	return at


## The start of season w's last round (Sunday 20:30 Thai): the deciding round.
static func final_slot(w: int) -> int:
	return prev_slot(int(week_end(w)))


## The round starting `at` is a deciding round (รอบชี้ขาด ×2): its season's last, from
## FINAL_FROM_WEEK on.
static func is_final(at: int) -> bool:
	var w := week_of(float(at))
	return w >= FINAL_FROM_WEEK and at == final_slot(w)


## What the round starting `at` multiplies its placement and capture points by.
static func mult_of(at: int) -> int:
	return FINAL_MULT if is_final(at) else 1


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


## A guild's might for the seeded rounds of the season `at` falls in: side_power at the
## season's start (one reckoning a guild a week keeps the castle's chain of holders cheap
## to follow from the world's first day; 0 with nobody at Lv.100 then). A guild with
## nobody then but members at Lv.100 by the round counts its might at the round.
static func week_power(g: int, at: int) -> float:
	var start := int(week_start(week_of(float(at))))
	var p := side_power(g, maxi(start, WorldPlayers.START_UNIX))
	if p <= 0.0:
		p = side_power(g, at)
	return p


# --- Rounds: one castle war of every guild -----------------------------------------

## The points of a war's falls and captures (the placement and HOLD come on top).
static func round_points(kills: int, caps: int) -> int:
	return maxi(0, kills) / KILLS_PER_POINT + CAPTURE * maxi(0, caps)


## The seeded result of the round starting `at`, fought without the hero, with the castle
## held by `own` when it began (0 nobody): from every guild's might (week_power) and a seed
## of the round and its holder alone, so every device agrees. The holder defends with
## DEFEND_EDGE: it keeps the castle with its edged share of all the guilds' might, else a
## guild (weighted by might) takes it; with no holder, now and then nobody takes it.
## {at, g: guilds, k: falls, c: captures, held, own}; {} when fewer than two guilds have
## anyone at Lv.100.
static func sim_round(at: int, own: int) -> Dictionary:
	var key := "%d|%d%s" % [at, own, sim_salt]
	if _sim_cache.has(key):
		return _sim_cache[key]
	if _sim_cache.size() > 400:
		_sim_cache.clear()
	var gs: Array = []
	var weight: Array = []
	var total := 0.0
	for g in guilds_at(at):
		var p := week_power(g, at)
		if p <= 0.0:
			continue
		gs.append(g)
		var e := pow(p, POWER_EDGE) * (DEFEND_EDGE if g == own else 1.0)
		weight.append(e)
		total += e
	var out := {}
	if gs.size() >= 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("guild_league_round|%d|%d%s" % [at, own, sim_salt])
		var held := 0
		var keeper := gs.find(own)
		if keeper >= 0 and rng.randf() < float(weight[keeper]) / total:
			held = own
		elif keeper < 0 and rng.randf() < NOBODY_TAKES:
			held = 0
		else:
			var rest := 0.0
			for i in gs.size():
				rest += 0.0 if i == keeper else float(weight[i])
			var pick := rng.randf() * rest
			for i in gs.size():
				if i == keeper:
					continue
				pick -= float(weight[i])
				if pick <= 0.0:
					held = int(gs[i])
					break
			if held == 0:
				held = int(gs[gs.size() - 1 if keeper != gs.size() - 1 else 0])
		var k: Array = []
		var c: Array = []
		for i in gs.size():
			var share := float(weight[i]) / total
			k.append(int(round(rng.randf_range(12.0, 28.0) + 55.0 * share)))
			var caps := 0
			if int(gs[i]) == held and held != own:
				caps = rng.randi_range(1, 2)
			elif int(gs[i]) != own and rng.randf() < 0.3 * share:
				caps = 1  # took it once and lost it again
			c.append(caps)
		out = {"at": at, "g": gs, "k": k, "c": c, "held": held, "own": own}
	_sim_cache[key] = out
	return out


## A recorded round (the flat ints of profile.league) as a round result.
static func _round_of(e: Dictionary) -> Dictionary:
	var gs: Array = []
	var k: Array = []
	var c: Array = []
	for i in 4:
		var g := int(e.get("g%d" % (i + 1), 0))
		if g <= 0:
			continue
		gs.append(g)
		k.append(int(e.get("k%d" % (i + 1), 0)))
		c.append(int(e.get("c%d" % (i + 1), 0)))
	return {"at": int(e.at), "g": gs, "k": k, "c": c, "held": int(e.held), "own": int(e.get("own", 0)), "real": true}


## True for a four-guild round record (profile.league), false for an old two-guild war's.
static func is_round_record(e: Variant) -> bool:
	return e is Dictionary and (e as Dictionary).has("g1")


## The hero's real round at `at` in `real` ({} when none).
static func _real_round(real: Array, at: int) -> Dictionary:
	for e in real:
		if is_round_record(e) and int(e.get("at", -1)) == at:
			return _round_of(e)
	return {}


## The hero's old two-guild wars recorded at round `at`.
static func _legacy_at(real: Array, at: int) -> Array:
	var out: Array = []
	for e in real:
		if e is Dictionary and not is_round_record(e) and int(e.get("at", -1)) == at:
			out.append(e)
	return out


## The hero's real war of round `at` between a and b in `real` ({} when none; old records).
static func _real_for(real: Array, at: int, a: int, b: int) -> Dictionary:
	for e in real:
		if e is Dictionary and not is_round_record(e) and int(e.get("at", -1)) == at and ((int(e.a) == a and int(e.b) == b) or (int(e.a) == b and int(e.b) == a)):
			return e
	return {}


## The old seeded result of the war a vs b in the round starting `at` (two guilds; it
## completes a round the hero fought as one of the old pairs).
static func sim_war(at: int, a: int, b: int) -> Dictionary:
	var key := "%d|%d|%d" % [at, a, b]
	if _sim_cache.has(key):
		return _sim_cache[key]
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


## A frozen round result (LeagueRounds) as round_results gives it: [] when nobody fought.
## The server's carries "official" (its `own` then is the holder it leaves when nobody
## holds the castle at the bell, _after).
static func _frozen(r: Dictionary, official := false) -> Array:
	if (r.get("g", []) as Array).is_empty():
		return []
	var e := r.duplicate(true)
	if official:
		e["official"] = true
	return [e]


## The results of round `at` begun with the castle held by `own`. An ended round: the
## server's official result, else the hero's real one (or, for a round the hero fought in
## the old pairs, its old wars: the real ones and the seeded other pair), else this
## device's frozen one, else the seeded one, which is then frozen (LeagueRounds.freeze:
## never worked out again). A round not over: the hero's real one, else the seeded one
## (never shown as a result; see events, holder_after). [] when nobody could fight.
static func round_results(at: int, own: int, real: Array) -> Array:
	var over := ended(at)
	if over:
		var off := LeagueRounds.official_of(at)
		if not off.is_empty():
			return _frozen(off, true)
	var mine := _real_round(real, at)
	if not mine.is_empty():
		return [mine]
	var old := _legacy_at(real, at)
	if not old.is_empty():
		var out: Array = []
		for p in pairs_at(at):
			var e := _real_for(old, at, int(p[0]), int(p[1]))
			if e.is_empty():
				e = sim_war(at, int(p[0]), int(p[1]))
			else:
				e = e.duplicate()
				e["real"] = true
			if not e.is_empty():
				out.append(e)
		return out
	if over:
		var kept := LeagueRounds.seen_of(at)
		if not kept.is_empty():
			return _frozen(kept)
	var sim := sim_round(at, own)
	if over:
		LeagueRounds.freeze(at, sim if not sim.is_empty() else {"at": at, "g": [], "k": [], "c": [], "held": 0, "own": own})
	return [] if sim.is_empty() else [sim]


## Who holds the castle after a round's results begun with `own`: only a capture changes
## it (a round's holder at the bell; nobody at the bell leaves it with `own`, or with the
## official round's own); old pairs: the holder who earned more in its war.
static func _after(results: Array, own: int) -> int:
	var best := 0
	var best_key := -1
	for e in results:
		var held := int(e.get("held", 0))
		if (e as Dictionary).has("g"):
			if held > 0:
				return held
			return int(e.get("own", own)) if bool(e.get("official", false)) else own
		if held <= 0:
			continue
		var key := side_points(e, held) * 1000 + int(e.ca if int(e.a) == held else e.cb) * 10 + (9 - held)
		if key > best_key:
			best = held
			best_key = key
	return best if best > 0 else own


## The hero's real records the chain of holders reads: `real` and, with a profile, both
## seasons it keeps.
static func _chain_real(real: Array) -> Array:
	var out: Array = real.duplicate()
	if Game.has_profile:
		var d: Variant = Game.profile.get(KEY)
		if d is Dictionary:
			for key in ["prev_wars", "wars"]:
				for e in (d as Dictionary).get(key, []):
					if not out.has(e):
						out.append(e)
	return out


static func _chain_sig(real: Array) -> String:
	var last := 0
	for e in real:
		if e is Dictionary:
			last = maxi(last, int(e.get("at", 0)) + int(e.get("held", 0)) * 7 + int(e.get("k1", e.get("ka", 0))))
	return "%d|%d|%d|%s" % [real.size(), last, LeagueRounds.revision, sim_salt]


## Who holds the castle after the round starting `at` (its bell): the chain of holders
## from the world's first round (WorldPlayers.START_UNIX), round by round, each begun with
## the one before's holder, every round's result frozen once over (round_results). Cached
## (followed on from the last round worked out). A round not over yet has no result: the
## holder then is the one after the latest round over (nothing is foretold).
static func holder_after(at: int, real: Array = []) -> int:
	if at < WorldPlayers.START_UNIX:
		return 0
	if not ended(at):
		return holder_after(last_ended(now()), real)
	var all := _chain_real(real)
	var sig := _chain_sig(all)
	if sig != _chain_key:
		_chain_key = sig
		_chain.clear()
		_chain_last = 0
	if _chain.has(at):
		return int(_chain[at])
	# Walk on from the last round worked out before `at` (or the first round).
	var r := _chain_last if _chain_last > 0 and _chain_last < at else next_slot(float(WorldPlayers.START_UNIX) - 1.0)
	var own := int(_chain.get(r, 0)) if _chain.has(r) else 0
	if not _chain.has(r):
		own = _after(round_results(r, 0, all), 0)
		_chain[r] = own
	while r < at:
		r = next_slot(float(r))
		own = _after(round_results(r, own, all), own)
		_chain[r] = own
	if r > _chain_last:
		_chain_last = r
	return int(_chain.get(at, own))


## Who holds the castle when the round starting `at` begins (0 nobody): the holder after
## the round before. It starts there inside the castle and defends (GuildWarMatch).
static func start_holder(at: int, real: Array = []) -> int:
	var prev := prev_slot(at)
	if prev < WorldPlayers.START_UNIX:
		return 0
	return holder_after(prev, real)


## Points guild g earns from a war: a round's placement (PLACE_POINTS) + HOLD for the
## holder at the bell + its falls and captures (round_points), the placement and the
## captures times mult_of (the deciding round's ×2; HOLD and falls count once); an old
## two-guild war's WIN or LOSS + CAPTURE per capture + HOLD + falls.
static func side_points(e: Dictionary, g: int) -> int:
	if e.has("g"):
		var i := (e.g as Array).find(g)
		if i < 0:
			return 0
		var place := placement(e).find(g)
		var m := mult_of(int(e.get("at", 0)))
		return int(PLACE_POINTS[clampi(place, 0, PLACE_POINTS.size() - 1)]) * m + (HOLD if int(e.held) == g else 0) \
			+ maxi(0, int(e.k[i])) / KILLS_PER_POINT + CAPTURE * maxi(0, int(e.c[i])) * m
	if int(e.a) != g and int(e.b) != g:
		return 0
	var ours := int(e.a) == g
	var p := WIN if int(e.win) == g else LOSS
	p += CAPTURE * int(e.ca if ours else e.cb)
	p += HOLD if int(e.held) == g else 0
	p += int(e.ka if ours else e.kb) / KILLS_PER_POINT
	return p


## A round's guilds, best first: the castle's holder at the bell, then by round_points,
## then falls dealt, then the lower guild id.
static func placement(e: Dictionary) -> Array[int]:
	var gs: Array = e.get("g", [])
	var order: Array[int] = []
	for g in gs:
		order.append(int(g))
	var held := int(e.get("held", 0))
	order.sort_custom(func(a, b):
		if (a == held) != (b == held):
			return a == held
		var ia := gs.find(a)
		var ib := gs.find(b)
		var pa := round_points(int(e.k[ia]), int(e.c[ia]))
		var pb := round_points(int(e.k[ib]), int(e.c[ib]))
		if pa != pb:
			return pa > pb
		if int(e.k[ia]) != int(e.k[ib]):
			return int(e.k[ia]) > int(e.k[ib])
		return a < b)
	return order


## Kept for the screens and tests: every seeded round of season w (begun with the chain's
## holder) that has a result, in time order.
static func sim_wars(w: int) -> Array:
	var out: Array = []
	for m in schedule(w):
		var e := sim_round(int(m.at), start_holder(int(m.at)))
		if not e.is_empty():
			out.append(e)
	return out


## The wars of season w over by `until` (and by now: a round still running or yet to come
## is never counted), time order: the hero's real round in place of its seeded one
## (counted as soon as it is recorded), every other round once it has ended (its frozen
## result, round_results), each begun with the castle's holder of the round before
## (start_holder). An old two-guild record keeps its round in the old pairs.
static func events(w: int, real: Array, until := INF) -> Array:
	var out: Array = []
	until = minf(until, now())
	for m in schedule(w):
		var at := int(m.at)
		if float(at) > until:
			break
		var over := float(at) + GuildWarData.DURATION <= until
		if not over and _real_round(real, at).is_empty() and _legacy_at(real, at).is_empty():
			continue
		var own := start_holder(at, real)
		var results := round_results(at, own, real)
		for e in results:
			if bool(e.get("real", false)) or over:
				out.append(e)
	return out


## The table of season w at `until`: [{rank, g, name, points, wins, losses, captures, held,
## kills}], best first (points, wins, captures). wins: rounds placed first (old wars won).
static func table(w: int, real: Array, until := INF) -> Array[Dictionary]:
	var rows := {}
	for g in ids():
		rows[g] = {"g": g, "name": name_of(g), "points": 0, "wins": 0, "losses": 0, "captures": 0, "held": 0, "kills": 0}
	for e in events(w, real, until):
		var sides: Array = []
		if (e as Dictionary).has("g"):
			var first := placement(e)[0] if not (e.g as Array).is_empty() else 0
			for i in (e.g as Array).size():
				sides.append([int(e.g[i]), int(e.c[i]), int(e.k[i]), int(e.g[i]) == first])
		else:
			sides = [[int(e.a), int(e.ca), int(e.ka), int(e.win) == int(e.a)], [int(e.b), int(e.cb), int(e.kb), int(e.win) == int(e.b)]]
		for sd in sides:
			var g := int(sd[0])
			if not rows.has(g):
				continue
			var r: Dictionary = rows[g]
			r.points = int(r.points) + side_points(e, g)
			if bool(sd[3]):
				r.wins = int(r.wins) + 1
			else:
				r.losses = int(r.losses) + 1
			r.captures = int(r.captures) + int(sd[1])
			r.kills = int(r.kills) + int(sd[2])
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


## Who holds the castle at `until` (in season w's view; never later than now): the holder
## after the latest round over by then (the chain carries across days and weeks); 0
## before anyone took it.
static func holder(w: int, real: Array, until := INF) -> int:
	var t := minf(minf(until, week_end(w) - 1.0), now())
	var at := live_slot(t)
	if at < 0:
		at = prev_slot(next_slot(t))
	elif float(at) + GuildWarData.DURATION > t:
		return start_holder(at, real)
	return holder_after(at, real)


## The Castle King (ราชันปราสาท) of season w: the castle holder after its last round
## (Sunday 20:30; the top guild if nobody held it). Before the season ends: the holder (and
## table) so far.
static func champion_of(w: int, real: Array) -> int:
	var last_at := 0
	for e in real:
		if e is Dictionary:
			last_at = maxi(last_at, int(e.get("at", 0)))
	var key := "%d|%d|%d|%d|%d|%s" % [w, real.size(), last_at, LeagueRounds.revision, mini(last_ended(now()), int(week_end(w))), sim_salt]
	if _champ_cache.has(key):
		return int(_champ_cache[key])
	if _champ_cache.size() > 16:
		_champ_cache.clear()
	var last := prev_slot(int(week_end(w)))
	var champ := holder_after(last, real)
	if champ == 0:
		champ = int(table(w, real)[0].g)
	_champ_cache[key] = champ
	return champ


## The League Champion (แชมป์ลีก) of season w: first in the table by points (0 while no
## guild has any).
static func league_champion_of(w: int, real: Array) -> int:
	var last_at := 0
	for e in real:
		if e is Dictionary:
			last_at = maxi(last_at, int(e.get("at", 0)))
	var key := "L|%d|%d|%d|%d|%d|%s" % [w, real.size(), last_at, LeagueRounds.revision, mini(last_ended(now()), int(week_end(w))), sim_salt]
	if _champ_cache.has(key):
		return int(_champ_cache[key])
	if _champ_cache.size() > 16:
		_champ_cache.clear()
	var top: Dictionary = table(w, real)[0]
	var g := int(top.g) if int(top.points) > 0 else 0
	_champ_cache[key] = g
	return g


## The emperor (จักรพรรดิแห่งสัปดาห์) of season w: the guild that is both its League Champion
## and its Castle King (holding the castle after the last round); 0 when none is both.
static func emperor_of(w: int, real: Array) -> int:
	var king := holder_after(final_slot(w), real)
	return king if king > 0 and league_champion_of(w, real) == king else 0


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


## Last season's Castle King as this device sees it (the hero's real wars of that season in).
static func champion_now(t := -1.0) -> int:
	if t < 0.0:
		t = now()
	var w := week_of(t) - 1
	return champion_of(w, real_wars(w) if Game.has_profile else [])


## Last season's League Champion (0 when nobody scored).
static func league_champion_now(t := -1.0) -> int:
	if t < 0.0:
		t = now()
	var w := week_of(t) - 1
	return league_champion_of(w, real_wars(w) if Game.has_profile else [])


## Last season's emperor (0 when no guild was both).
static func emperor_now(t := -1.0) -> int:
	if t < 0.0:
		t = now()
	var w := week_of(t) - 1
	return emperor_of(w, real_wars(w) if Game.has_profile else [])


## The hero's guild is last season's Castle King.
static func hero_champion(t := -1.0) -> bool:
	var g := Game.guild()
	return g > 0 and champion_now(t) == g


## A world guild (WorldPlayers) whose members wear the crown plate this week.
static func crowned(g: int) -> bool:
	return g > 0 and champion_now() == g


## The EXP multiplier of the Castle King's members (Game.add_exp).
static func exp_mult(t := -1.0) -> float:
	return 1.0 + EXP_BONUS if hero_champion(t) else 1.0


## The HUD event chip's line ("" when the hero's guild is not the Castle King).
static func chip_text(t := -1.0) -> String:
	if t < 0.0:
		t = now()
	if not hero_champion(t):
		return ""
	var left := week_end(week_of(t)) - t
	var span := "%d วัน" % int(ceil(left / float(DAY))) if left > float(DAY) else "%d ชม." % maxi(1, int(ceil(left / 3600.0)))
	return "%s %s EXP +%d%% เหลือ %s" % [CROWN, CASTLE_TITLE, int(EXP_BONUS * 100.0), span]


## Records the hero's real round (a castle war of every guild): `guilds` in team order
## (team 0 the hero's), each team's captures and falls dealt, the team holding the castle
## at the bell (-1 nobody), `t` the round's start (it takes that round's place in the
## table; a time that is no round counts nothing) and `own` the guild that held the castle
## when it began; `spectating` for a round the hero only watched (no league coins).
## Returns the league points `guilds[0]` earned (0 outside a guild).
static func record_round(guilds: Array, caps: Array, kills: Array, held: int, t := -1.0, own := 0, spectating := false) -> int:
	if not Game.has_profile or guilds.is_empty():
		return 0
	var ours := int(guilds[0])
	if ours <= 0 or not WorldPlayers.GUILD_NAMES.has(ours):
		return 0
	if t < 0.0:
		t = now()
	var d := data(t)
	var e := {"at": int(t), "held": int(guilds[held]) if held >= 0 and held < guilds.size() else 0, "own": maxi(0, own)}
	for i in 4:
		var g := int(guilds[i]) if i < guilds.size() else 0
		var ok := g > 0 and WorldPlayers.GUILD_NAMES.has(g)
		e["g%d" % (i + 1)] = g if ok else 0
		e["k%d" % (i + 1)] = maxi(0, int(kills[i])) if ok and i < kills.size() else 0
		e["c%d" % (i + 1)] = maxi(0, int(caps[i])) if ok and i < caps.size() else 0
	var wars: Array = d.get("wars", [])
	# One result a round: fighting (or watching) the same round again replaces it.
	for old in wars.duplicate():
		if old is Dictionary and int(old.get("at", -1)) == int(t):
			wars.erase(old)
	wars.append(e)
	while wars.size() > MAX_WARS:
		wars.pop_front()
	d["wars"] = wars
	Game.mark_dirty()
	var r := _round_of(e)
	if is_round(int(t)):
		# This device's record of the round, sent to the server as the round's result.
		r.erase("real")
		LeagueRounds.record_real(int(t), r)
	# League coins for the round, once (RewardShop).
	if not spectating:
		RewardShop.round_fought(e, ours)
	return side_points(r, ours)


## Records an old two-guild war (kept for old callers): `ours` / `theirs`, captures and
## falls of each side, who held the castle at the bell (-1 nobody, 0 ours, 1 theirs).
static func record_war(ours: int, theirs: int, won: bool, caps_us: int, caps_them: int, held: int, kills_us: int, kills_them: int, t := -1.0, spectating := false) -> int:
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
	var same := _real_for(wars, int(t), ours, theirs)
	if not same.is_empty():
		wars.erase(same)
	wars.append(e)
	while wars.size() > MAX_WARS:
		wars.pop_front()
	d["wars"] = wars
	Game.mark_dirty()
	if not spectating:
		RewardShop.round_fought(e, ours)
	return side_points(e, ours)


## A guild war just ended (GuildWarMatch): the league round being fought (current_match:
## {guilds (team order), at, owner}) counts its live result; a practice war counts nothing
## here; every war counts for the daily quests ("guild_war", and "league" when the guild
## earned points). `caps` / `score` one entry a team, `held` the team holding the castle.
## Puts the points in result.league.
static func war_finished(result: Dictionary, real_guilds: bool, caps: Array, held: int, score: Array) -> int:
	var pts := 0
	var m := current_match
	current_match = {}
	if real_guilds and not m.is_empty() and Game.guild() > 0:
		if m.has("guilds") and int((m.guilds as Array)[0]) == Game.guild():
			pts = record_round(m.guilds, caps, score, held, float(m.at), int(m.get("owner", 0)))
		elif m.has("ours") and int(m.ours) == Game.guild():
			pts = record_war(int(m.ours), int(m.theirs), bool(result.get("won", false)),
				int(caps[0]), int(caps[1]), held, int(score[0]), int(score[1]), float(m.at))
	result["league"] = pts
	if Game.has_method("daily_progress"):
		Game.call("daily_progress", "guild_war", 1)
		if pts > 0:
			Game.call("daily_progress", "league", pts)
	return pts


## A league round the hero watched to the end (GuildWarSpectate): its live result takes
## the seeded round's place (match_info.league_round: the guilds in side order,
## slot_start), the way the hero's own war does. An older two-side match_info
## (league_match [a, b]) is recorded as an old war. Nothing is paid and no daily quest
## moves. Returns the league points the first side earned (0 when it is no round).
static func spectated_result(match_info: Dictionary, result: Dictionary) -> int:
	var at := int(match_info.get("slot_start", 0))
	var order: Variant = match_info.get("league_round", [])
	if order is Array and (order as Array).size() >= 2:
		if at <= 0 or not is_round(at):
			return 0
		for g in order:
			if not (typeof(g) in [TYPE_INT, TYPE_FLOAT]) or int(g) <= 0:
				return 0
		var gs: Array = []
		for g in order:
			gs.append(int(g))
		var own_team := int(result.get("start_owner", match_info.get("owner", -1)))
		var own: int = int(gs[own_team]) if own_team >= 0 and own_team < gs.size() else 0
		return record_round(gs, result.get("captures", []), result.get("score", []), int(result.get("castle_owner", -1)), float(at), own, true)
	var pair: Variant = match_info.get("league_match", [])
	if not (pair is Array) or (pair as Array).size() != 2:
		return 0
	var a := int(pair[0]) if typeof(pair[0]) in [TYPE_INT, TYPE_FLOAT] else 0
	var b := int(pair[1]) if typeof(pair[1]) in [TYPE_INT, TYPE_FLOAT] else 0
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
	return record_war(a, b, winner == 0, int(caps[0]), int(caps[1]), int(result.get("castle_owner", -1)),
		int(score[0]), int(score[1]), float(at), true)


## What the hero may claim now of last season: the top-three reward (ranked: true, unless
## taken: claimed) and, for the emperor's members, its bonus (emperor: true, unless taken:
## emp_claimed). {rank, week, gold, jewels (both together), ranked, emperor} or {}.
static func claimable(t := -1.0) -> Dictionary:
	var g := Game.guild()
	if g <= 0:
		return {}
	var d := data(t)
	var w := week_of(now() if t < 0.0 else t) - 1
	var real := real_wars(w)
	var out := {}
	if int(d.get("claimed", -1)) != w:
		var rank := rank_of(w, real, g)
		if REWARDS.has(rank):
			out = (REWARDS[rank] as Dictionary).duplicate(true)
			out["rank"] = rank
			out["ranked"] = true
	if int(d.get("emp_claimed", -1)) != w and emperor_of(w, real) == g:
		if out.is_empty():
			out = {"rank": 1, "gold": 0, "jewels": {}, "ranked": false}
		var jewels: Dictionary = out.jewels
		for id in EMPEROR_BONUS:
			jewels[id] = int(jewels.get(id, 0)) + int(EMPEROR_BONUS[id])
		out["emperor"] = true
	if out.is_empty():
		return {}
	out["week"] = w
	out["emperor"] = bool(out.get("emperor", false))
	return out


## Takes last season's top-three reward and, for the emperor's members, its bonus (10 chaos
## jewels and the title จักรพรรดิแห่งสัปดาห์), each once. "ok" or a reason.
static func claim(t := -1.0) -> String:
	if Game.guild() <= 0:
		return "ต้องอยู่ในกิลด์ก่อน"
	var d := data(t)
	var w := week_of(now() if t < 0.0 else t) - 1
	var reward := claimable(t)
	if reward.is_empty():
		if int(d.get("claimed", -1)) == w:
			return "รับรางวัลลีกของฤดูกาลที่แล้วไปแล้ว"
		return "กิลด์ของคุณไม่ติด 3 อันดับแรกเมื่อฤดูกาลที่แล้ว"
	if bool(reward.ranked):
		d["claimed"] = w
	if bool(reward.emperor):
		d["emp_claimed"] = w
		Game.profile["flags"][EMPEROR_FLAG] = 1
	if int(reward.gold) > 0:
		Game.add_gold(int(reward.gold))
	for id in reward.jewels:
		Game.give_or_store(ItemData.jewel(String(id), int(reward.jewels[id])))
	if bool(reward.emperor):
		# The titled achievements only (the emperor's title), not the goal rewards.
		Game._check_achievements()
		Game.title_changed.emit(Achievements.title_of(Game.profile))
	Game.mark_dirty()
	Game.save()
	return "ok"


static func reward_text(reward: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(reward.get("gold", 0)) > 0:
		parts.append("%s ทอง" % GuildScreen._num(int(reward.get("gold", 0))))
	var jewels: Dictionary = reward.get("jewels", {})
	for id in jewels:
		parts.append("%s ×%d" % [ItemData.JEWELS[id].name, int(jewels[id])])
	if bool(reward.get("emperor", false)):
		parts.append("ตำแหน่ง \"%s\"" % EMPEROR_TITLE)
	return " · ".join(parts)


# --- The Castle King's secret shop ------------------------------------------------

static func shop_entry(id: String) -> Dictionary:
	for e in SHOP:
		if String(e.id) == id:
			return e
	return {}


static func shop_name(e: Dictionary) -> String:
	if String(e.kind) == "title":
		return "ตำแหน่ง \"ราชันปราสาท\" (ของสะสมเฉพาะกิลด์ราชันปราสาท)"
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
		return "ร้านลับเปิดให้สมาชิกกิลด์ราชันปราสาทเท่านั้น"
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

## The season-end announcement of season w: "แชมป์ลีกสัปดาห์นี้: X · ราชันปราสาท: Y",
## then the emperor's line when one guild won both ([line] or [line, emperor line]).
static func announce_lines(w: int, real: Array) -> PackedStringArray:
	var league := league_champion_of(w, real)
	var king := champion_of(w, real)
	var out := PackedStringArray(["%sสัปดาห์นี้: %s · %s: %s" % [LEAGUE_TITLE, name_of(league) if league > 0 else "-", CASTLE_TITLE, name_of(king) if king > 0 else "-"]])
	var emperor := emperor_of(w, real)
	if emperor > 0:
		out.append("%s กิลด์ %s เป็นทั้ง%sและ%s: %s!" % [CROWN, name_of(emperor), LEAGUE_TITLE, CASTLE_TITLE, EMPEROR_TITLE])
	return out


## Once a season (the first time the game notices it ended: ann): tells the hero who won
## the last one's two titles (toast and world chat), the emperor too, and what it means for
## the hero. True when it announced now.
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
	# The week's placement bonus in league coins (RewardShop), once.
	RewardShop.week_closed(w - 1)
	for line in announce_lines(w - 1, real_wars(w - 1)):
		Game.say(line, &"quest")
		Game.post_chat("world", "ประกาศลีกกิลด์", line, CROWN_COLOR)
	if hero_champion(t):
		Game.say("%s กิลด์ของคุณเป็น%s: EXP +%d%% ทั้งสัปดาห์ และร้านลับ%sเปิดแล้ว" % [CROWN, CASTLE_TITLE, int(EXP_BONUS * 100.0), CASTLE_TITLE], &"success")
	if Game.guild() > 0 and emperor_now(t) == Game.guild():
		Game.say("กิลด์ของคุณเป็น%s! รับโบนัสเพชรเคออสและตำแหน่งได้ที่หน้าลีกกิลด์" % EMPEROR_TITLE, &"success")
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
	if not is_round(at) or not guilds_at(at).has(Game.guild()):
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


## The other guilds of round `at` that can fight in it (someone at Lv.100), in id order.
static func rivals_of(g: int, at: int) -> Array[int]:
	var out: Array[int] = []
	for o in guilds_at(at):
		if o != g and not WorldPlayers.members_at(o, float(at)).is_empty():
			out.append(o)
	return out


## Why the hero cannot go into the war being fought at t ("" when it can): a round must
## be on, the hero registered for it, in the line-up (top GUILD_SIDE), not done with it.
static func enter_problem(t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var g := Game.guild()
	if g <= 0:
		return "เข้ากิลด์ที่นายทะเบียนกิลด์ก่อน"
	var at := entry_slot(t)
	if at < 0:
		var nxt := next_slot(t)
		return "ยังไม่ถึงเวลาสงคราม (รอบถัดไป %s) · เปิดให้เข้ารอได้ตอน %s" % [clock_text(nxt), clock_text(nxt - LOBBY_OPEN)]
	if not registered(at):
		return "ไม่ได้สมัครรอบนี้ — ชมการแข่งขันได้"
	if not hero_makes_side(at):
		return "อันดับในกิลด์ #%d ไม่ติด %d อันดับ — ชมการแข่งขันได้" % [hero_place(at), GuildWarData.GUILD_SIDE]
	if not _real_round(real_wars(week_of(float(at))), at).is_empty():
		return "ลงสงครามรอบนี้ไปแล้ว"
	var rivals := rivals_of(g, at)
	if rivals.is_empty():
		return "ยังไม่มีกิลด์อื่นที่มีสมาชิกถึงเลเวล %d" % Game.GUILD_LEVEL
	var blocked := GuildWarData.guild_war_blocked(g, rivals[0], float(at))
	if blocked != "":
		return blocked
	return ""


## Online: the shared arena of round `at` for guild `g` ("guildwar_<at>_<g>", the zone the
## server hears; party-scoped like "guildwar", docs/ONLINE_PROTOCOL.md "Guild league
## rounds together"). Party members of one guild in one round meet only there: a practice
## war ("guildwar") or another round / guild is another room.
const ROOM_PREFIX := "guildwar_"


static func war_room(at: int, g: int) -> StringName:
	return StringName("%s%d_%d" % [ROOM_PREFIX, at, g])


## {at, guild} of a room war_room made ({} for anything else).
static func room_round(room: Variant) -> Dictionary:
	var text := String(room) if (room is String or room is StringName) else ""
	if not text.begins_with(ROOM_PREFIX):
		return {}
	var parts := text.substr(ROOM_PREFIX.length()).split("_")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return {}
	var at := parts[0].to_int()
	var g := parts[1].to_int()
	if at <= 0 or g <= 0:
		return {}
	return {"at": at, "guild": g}


## The round whose waiting room is open at t (from LOBBY_OPEN seconds before its start,
## when registration closes, until it starts; GuildWarMatch.lobby_until), else -1.
static func lobby_slot(t := -1.0) -> int:
	if t < 0.0:
		t = now()
	if live_slot(t) >= 0:
		return -1
	var nxt := next_slot(t)
	return nxt if t >= float(nxt - LOBBY_OPEN) else -1


## The round the hero may go into at t: the one being fought, else the one whose waiting
## room is open (-1 for none).
static func entry_slot(t := -1.0) -> int:
	if t < 0.0:
		t = now()
	var at := live_slot(t)
	return at if at >= 0 else lobby_slot(t)


## "m:ss" to the start of the round `at` from t (0:00 once it started).
static func until_text(at: int, t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var left := maxi(0, int(ceil(float(at) - t)))
	return "%d:%02d" % [left / 60, left % 60]


## The league round the hero goes into now: {guilds: [ours, the others...], at} ({} when it
## cannot). Everyone fights everyone in one castle war.
static func enter_match(t := -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	if enter_problem(t) != "":
		return {}
	var at := entry_slot(t)
	var order: Array = [Game.guild()]
	order.append_array(rivals_of(Game.guild(), at))
	return {"guilds": order, "at": at}


## "ปราสาทเป็นของกิลด์ X" / "กิลด์ของคุณครองปราสาท — ..." / nobody, for the round starting `at`.
static func owner_text(at: int) -> String:
	var own := start_holder(at)
	if own <= 0:
		return "ยังไม่มีใครครองปราสาท — ทุกกิลด์เริ่มนอกปราสาท"
	if own == Game.guild():
		return "กิลด์ของคุณครองปราสาท — ป้องกันประตูและแท่นประทับ"
	return "ปราสาทเป็นของกิลด์ %s" % name_of(own)


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
	var line := "สงครามกิลด์รอบ %s เริ่มแล้ว: 4 กิลด์ชิงปราสาท · %s" % [clock_text(at), owner_text(at)]
	if is_final(at):
		line += " · %s: ใครครองปราสาทตอนจบเป็น%s" % [FINAL_TAG, CASTLE_TITLE]
	if GuildWarMatch.in_war() and not GuildWarMatch.current.spectating():
		Game.say(line, &"quest")
	elif hero_makes_side(at):
		Game.say(line + " — ไปที่ผู้บัญชาการสงครามกิลด์แล้วกด เข้าสู่สงคราม (มาสายก็เข้าได้จนจบรอบ)", &"quest")
	else:
		Game.say(line + " — อันดับในกิลด์ไม่ติด %d อันดับ ไปชมการแข่งขันได้" % GuildWarData.GUILD_SIDE, &"quest")
	Game.post_chat("guild", "ประกาศสงครามกิลด์", line, CROWN_COLOR)
	return true


## The state of round `at` at time t: "wait", "live" or "done" (with "war": its result as
## events gives it, {} when nobody could fight; "real" when the hero fought or watched it).
## Never later than now: a round not over is not shown as decided (unless the hero's own).
static func round_state(at: int, t := -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	t = minf(t, now())
	if t < float(at):
		return {"state": "wait", "owner": start_holder(at)}
	var real := real_wars(week_of(float(at)))
	var mine := _real_round(real, at)
	if ended(at, t) and LeagueRounds.is_official(at):
		var off := round_results(at, start_holder(at), real)
		return {"state": "done", "war": off[0] if not off.is_empty() else {}, "real": not mine.is_empty(), "official": true, "owner": start_holder(at)}
	if not mine.is_empty():
		return {"state": "done", "war": mine, "real": true, "owner": start_holder(at)}
	if t < float(at) + GuildWarData.DURATION:
		return {"state": "live", "owner": start_holder(at)}
	var results := round_results(at, start_holder(at), real)
	return {"state": "done", "war": results[0] if not results.is_empty() else {}, "owner": start_holder(at)}


## Kept for old callers: the state of the round `at` (the pair is not looked at).
static func match_state(at: int, _a: int, _b: int, t := -1.0) -> Dictionary:
	return round_state(at, t)


## What a spectator needs to watch the round live at t (GuildWarSpectate): roll_guild_war's
## shape (every guild that can fight, in id order, the hero not in it) plus elapsed
## (seconds since the round began), owner (the side holding the castle when it began, -1
## nobody), league_round (the guilds in side order) and slot_start. {} when no round is on
## or fewer than two guilds can fight.
static func live_round_info(t := -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	var at := live_slot(t)
	if at < 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("guild_league_live4|%d" % at)
	var info := GuildWarData.roll_guild_war(rng, guilds_at(at), float(at), -1.0, false)
	if info.is_empty():
		return {}
	var order: Array = []
	for sd in info.sides:
		order.append(int(sd.guild))
	info["elapsed"] = t - float(at)
	info["league_round"] = order
	info["owner"] = order.find(start_holder(at))
	info["slot_start"] = at
	return info


## Kept for old callers: the round live at t when guilds a and b both fight in it.
static func live_match_info(a: int, b: int, t := -1.0) -> Dictionary:
	var info := live_round_info(t)
	if info.is_empty():
		return {}
	var order: Array = info.league_round
	if (a > 0 and not order.has(a)) or (b > 0 and not order.has(b)):
		return {}
	return info


## The guilds g meets next (every other guild that can fight; the round live at t, else
## the next one); [] outside a guild.
static func next_rivals(g: int, t := -1.0) -> Array[int]:
	var out: Array[int] = []
	if g <= 0:
		return out
	if t < 0.0:
		t = now()
	var at := live_slot(t)
	return rivals_of(g, at if at >= 0 else next_slot(t))


## Kept for old callers: the first of next_rivals (0 for none).
static func next_rival(g: int, t := -1.0) -> int:
	var list := next_rivals(g, t)
	return list[0] if not list.is_empty() else 0


## A rival guild of the war on now (GuildWarMatch.current's team 1), else the next one's.
static func war_rival() -> int:
	var m := GuildWarMatch.current
	if m != null and is_instance_valid(m):
		return m.team_guilds[1] if m.team_guilds.size() > 1 else 0
	return next_rival(Game.guild())


# --- Save safety (Game._valid_profile / _repair) ------------------------------------

static func _int_ok(v: Variant, lo := 0.0, hi := float(MAX_NUMBER)) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floor(float(v)) and float(v) >= lo and float(v) <= hi


## A war record: an old two-guild war's (WAR_KEYS) or a round's (ROUND_KEYS), all ints.
static func _record_ok(e: Variant) -> bool:
	if not e is Dictionary:
		return false
	var keys: Array[String] = ROUND_KEYS if (e as Dictionary).has("g1") else WAR_KEYS
	if (e as Dictionary).size() != keys.size():
		return false
	for k in e:
		if not k is String or not keys.has(String(k)) or not _int_ok(e[k]):
			return false
	return true


static func _wars_ok(list: Variant) -> bool:
	if not list is Array or (list as Array).size() > MAX_WARS:
		return false
	for e in list:
		if not _record_ok(e):
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

