class_name GuildLeague
extends RefCounted
## Weekly guild league (ลีกกิลด์รายสัปดาห์): a season runs Monday 00:00 to Sunday 23:59
## Thai time (WorldEvents.day_of). Six guilds play: the world's two (Alpha, Neverdie) and
## four guilds the hero meets in hired wars (GuildWarData.GUILDS). Three times a day
## (SLOTS) two of them fight a simulated castle war, drawn from the week index and the
## roster alone (sim_wars), so every device sees the same table move. The hero's real guild
## wars (record_war) add to its guild and to the rival's.
##
## Points a war (side_points): WIN or LOSS, CAPTURE per castle capture, HOLD for holding
## the castle at the bell, one per KILLS_PER_POINT falls. The castle holder is the guild that
## held it at the end of the latest war; the holder when the season ends is the week's
## champion (champion_of). For the next week every member of the champion (world players
## too) wears a gold crown plate, the hero earns EXP_BONUS more EXP (Game.add_exp, the HUD
## event chip) and may shop at the champion's secret shop (SHOP). The top three guilds'
## members claim REWARDS once (claim).
##
## profile.league (valid / repair keep it safe in a save):
##   week, wars: the current season and the hero's real wars in it ({at, a, b, win, ca, cb,
##   held, ka, kb}, ints); prev_week, prev_wars: the season before; claimed: the season whose
##   top-three reward was taken; ann: the season whose end was announced; shop_week, shop:
##   the season of the secret shop's buy counts ({id: count}).

const KEY := "league"
## League guild ids: WorldPlayers' guilds keep theirs, the hired guilds HIRED_BASE + k.
const HIRED_BASE := 10
const HIRED: Array[String] = ["อัศวินอรุณ", "เงาจันทรา", "มังกรเพลิง", "ราชสีห์ทอง"]
const HIRED_COLORS: Array[Color] = [Color("8fd3ff"), Color("b59cff"), Color("ff8a5c"), Color("e8c66a")]
## Seconds of the Thai day a simulated war ends.
const SLOTS: Array[int] = [12 * 3600, 18 * 3600, 21 * 3600 + 30 * 60]
const DAY := 86400
const WIN := 30
const LOSS := 10
const CAPTURE := 5
const HOLD := 20
const KILLS_PER_POINT := 5
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
const INT_KEYS: Array[String] = ["week", "prev_week", "claimed", "ann", "shop_week"]

static var _sim_cache := {}
static var _champ_cache := {}


# --- Guilds and time ---------------------------------------------------------------

static func ids() -> Array[int]:
	var out: Array[int] = [WorldPlayers.ALPHA, WorldPlayers.NEVERDIE]
	for k in HIRED.size():
		out.append(HIRED_BASE + 1 + k)
	return out


static func name_of(g: int) -> String:
	if WorldPlayers.GUILD_NAMES.has(g):
		return WorldPlayers.guild_name(g)
	var k := g - HIRED_BASE - 1
	return HIRED[k] if k >= 0 and k < HIRED.size() else ""


static func color_of(g: int) -> Color:
	if WorldPlayers.GUILD_COLORS.has(g):
		return WorldPlayers.GUILD_COLORS[g]
	var k := g - HIRED_BASE - 1
	return HIRED_COLORS[k] if k >= 0 and k < HIRED_COLORS.size() else Color.WHITE


## Season index at t: weeks from Monday 00:00 Thai (day 0 of the epoch was a Thursday).
static func week_of(t: float) -> int:
	return floori(float(WorldEvents.day_of(t) + 3) / 7.0)


## Unix time the season `w` starts (Monday 00:00 Thai).
static func week_start(w: int) -> float:
	return float(w * 7 - 3) * float(DAY) - float(WorldPlayers.TZ)


static func week_end(w: int) -> float:
	return week_start(w + 1)


## A guild's standing strength for the simulation: the world's guilds by their roster,
## the hired guilds by name. The week adds its own swing (sim_wars).
static func base_strength(g: int) -> float:
	if WorldPlayers.GUILD_NAMES.has(g):
		return 1.0 + float(WorldPlayers.members(g).size()) / 60.0
	return 0.95 + float(absi(hash("league_guild|" + name_of(g))) % 40) / 100.0


# --- The simulated season ---------------------------------------------------------

## Every simulated war of season `w`, in time order: 21 wars (SLOTS a day), the pairs taken
## from shuffled round-robins. Only the week and the roster decide it.
static func sim_wars(w: int) -> Array:
	if _sim_cache.has(w):
		return _sim_cache[w]
	if _sim_cache.size() > 6:
		_sim_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("guild_league|%d" % w)
	var guilds := ids()
	var strength := {}
	for g in guilds:
		strength[g] = base_strength(g) * rng.randf_range(0.8, 1.25)
	var pairs: Array = []
	for i in guilds.size():
		for j in range(i + 1, guilds.size()):
			pairs.append([guilds[i], guilds[j]])
	var order: Array = []
	var wars: Array = []
	var start := week_start(w)
	for day in 7:
		for s in SLOTS:
			if order.is_empty():
				order = pairs.duplicate()
				for i in range(order.size() - 1, 0, -1):
					var j := rng.randi_range(0, i)
					var keep: Variant = order[i]
					order[i] = order[j]
					order[j] = keep
			var p: Array = order.pop_back()
			var a := int(p[0])
			var b := int(p[1])
			var sa := float(strength[a])
			var sb := float(strength[b])
			var win := a if rng.randf() < sa / (sa + sb) else b
			var held := win if rng.randf() < 0.7 else 0
			var cw := rng.randi_range(1, 3) if held > 0 else rng.randi_range(0, 1)
			var cl := rng.randi_range(0, 1 if held > 0 else 2)
			var kw := rng.randi_range(25, 70)
			var kl := rng.randi_range(10, kw)
			wars.append({"at": int(start) + day * DAY + s, "a": a, "b": b, "win": win, "held": held,
				"ca": cw if win == a else cl, "cb": cw if win == b else cl, "ka": kw if win == a else kl, "kb": kw if win == b else kl})
	_sim_cache[w] = wars
	return wars


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


## The wars of season w fought by `until` (simulated and the hero's real ones), time order.
static func events(w: int, real: Array, until := INF) -> Array:
	var out: Array = []
	for e in sim_wars(w):
		if float(e.at) <= until:
			out.append(e)
	var lo := week_start(w)
	var hi := week_end(w)
	for e in real:
		if e is Dictionary and float(e.get("at", 0)) >= lo and float(e.get("at", 0)) < hi and float(e.get("at", 0)) <= until:
			var copy: Dictionary = (e as Dictionary).duplicate()
			copy["real"] = true
			out.append(copy)
	out.sort_custom(func(x, y): return int(x.at) < int(y.at))
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
## latest war, else last season's champion (on the sim alone).
static func holder(w: int, real: Array, until := INF) -> int:
	var list := events(w, real, until)
	for k in range(list.size() - 1, -1, -1):
		if int(list[k].held) > 0:
			return int(list[k].held)
	return champion_of(w - 1, [])


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
	var champ := 0
	var list := events(w, real)
	for k in range(list.size() - 1, -1, -1):
		if int(list[k].held) > 0:
			champ = int(list[k].held)
			break
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
## 1 theirs). Returns the league points our guild earned (0 outside a guild).
static func record_war(ours: int, theirs: int, won: bool, caps_us: int, caps_them: int, held: int, kills_us: int, kills_them: int, t := -1.0) -> int:
	if ours <= 0 or not WorldPlayers.GUILD_NAMES.has(ours) or not Game.has_profile:
		return 0
	if theirs <= 0 or theirs == ours:
		theirs = WorldPlayers.other_guild(ours)
	if t < 0.0:
		t = now()
	var d := data(t)
	var e := {"at": int(t), "a": ours, "b": theirs, "win": ours if won else theirs,
		"ca": maxi(0, caps_us), "cb": maxi(0, caps_them), "held": ours if held == 0 else (theirs if held == 1 else 0),
		"ka": maxi(0, kills_us), "kb": maxi(0, kills_them)}
	var wars: Array = d.get("wars", [])
	wars.append(e)
	while wars.size() > MAX_WARS:
		wars.pop_front()
	d["wars"] = wars
	Game.mark_dirty()
	return side_points(e, ours)


## A guild war just ended (GuildWarMatch): a war between the world's guilds counts for the
## hero's guild in the league; every war counts for the daily quests ("guild_war", and
## "league" when the guild earned points). Puts the points in result.league.
static func war_finished(result: Dictionary, real_guilds: bool, caps: Array, held: int, score: Array) -> int:
	var pts := 0
	if real_guilds and Game.guild() > 0:
		pts = record_war(Game.guild(), WorldPlayers.other_guild(Game.guild()), bool(result.get("won", false)),
			int(caps[0]), int(caps[1]), held, int(score[0]), int(score[1]))
	result["league"] = pts
	if Game.has_method("daily_progress"):
		Game.call("daily_progress", "guild_war", 1)
		if pts > 0:
			Game.call("daily_progress", "league", pts)
	return pts


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
