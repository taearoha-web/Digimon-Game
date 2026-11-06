class_name DailyPass
extends RefCounted
## Daily / weekly quests and the free monthly reward pass (บัตรสะสมแต้ม).
##
## Every Thai day (WorldEvents.day_of, Thai midnight) each character draws DAILY_COUNT
## quests from DAILY_POOL, every Thai week (Monday 00:00) WEEKLY_COUNT bigger ones from
## WEEKLY_POOL. The draw is fixed by the character (name + class) and the day / week, so
## it is the same on every device all day. Targets scale with the level at the draw and
## are kept in the entry. Game.daily_progress(kind, amount) is the one call the game makes
## where something happens (kills, skill casts, trades, enhancing, party minutes, chat,
## the party raid, guild wars, guild-league points...); a finished quest is claimed once
## for pass points (แต้มบัตร) plus a little gold and EXP.
##
## The pass: TIERS tiers a calendar month (Thai time), one every TIER_POINTS points; each
## tier is claimed once (claim_tier / claim_all). On a new month the points and the
## claims start over; WARN_DAYS before that the hero is told once to claim what is left.
## The top tier also grants the title of Achievements "t_pass" (flags[TOP_FLAG]).
##
## Saved as profile["dpass"]: {day, dq: [{id, p, t, c}], week, wq: [...], month, pts,
## got (claimed tiers as bits, tier n = bit n-1), warn (the month already warned)}.
## Everything but the ids is an int or a bool (valid / repair).

const KEY := "dpass"
const DAILY_COUNT := 5
const WEEKLY_COUNT := 3
const TIERS := 30
const TIER_POINTS := 60
const WARN_DAYS := 3
## flags[TOP_FLAG]: how many times the top tier was claimed (the title's counter).
const TOP_FLAG := "pass_top"
const TITLE_ID := "t_pass"
const MAX_TARGET := 1000000000

## kind: what Game.daily_progress counts; base + per_level x level = the target;
## min: the lowest level it is drawn at; guild: drawn only for a guild member.
const DAILY_POOL := [
	{"id": "d_kills", "kind": "kills", "name": "ล่าประจำวัน", "desc": "ปราบมอนสเตอร์ %d ตัว", "base": 30, "per_level": 0.6},
	{"id": "d_boss", "kind": "boss", "name": "ล้มบอส", "desc": "ปราบบอส %d ตัว", "base": 1, "per_level": 0.0},
	{"id": "d_golden", "kind": "golden", "name": "ล่ามอนทองคำ", "desc": "ปราบมอนทองคำ %d ตัว", "base": 1, "per_level": 0.0},
	{"id": "d_skills", "kind": "skills", "name": "ฝึกวิชา", "desc": "ใช้สกิล %d ครั้ง", "base": 30, "per_level": 0.5},
	{"id": "d_trade", "kind": "trade", "name": "นักช้อป", "desc": "ซื้อหรือขายของกับร้านค้าและแผง %d ครั้ง", "base": 3, "per_level": 0.0},
	{"id": "d_stall", "kind": "stall_sell", "name": "พ่อค้าแผงลอย", "desc": "ขายของจากแผงของฉันได้ %d ชิ้น", "base": 1, "per_level": 0.0},
	{"id": "d_enhance", "kind": "enhance", "name": "ช่างตีเหล็ก", "desc": "ตีบวกไอเทม %d ครั้ง", "base": 1, "per_level": 0.0, "min": 10},
	{"id": "d_party", "kind": "party_min", "name": "ล่าด้วยกัน", "desc": "ล่ามอนสเตอร์เป็นปาร์ตี้ %d นาที", "base": 10, "per_level": 0.0},
	{"id": "d_raid", "kind": "raid", "name": "บุกเรด", "desc": "ผ่านเรดปาร์ตี้ %d ครั้ง", "base": 1, "per_level": 0.0, "min": 20},
	{"id": "d_guild_war", "kind": "guild_war", "name": "ศึกกิลด์", "desc": "ร่วมสงครามกิลด์ %d ครั้ง", "base": 1, "per_level": 0.0, "guild": true},
	{"id": "d_league", "kind": "league", "name": "แต้มลีก", "desc": "ทำแต้มลีกกิลด์ %d แต้ม", "base": 30, "per_level": 0.0, "guild": true},
	{"id": "d_chat", "kind": "chat", "name": "ทักทายเพื่อน", "desc": "พิมพ์คุยในแชท %d ครั้ง", "base": 3, "per_level": 0.0},
	{"id": "d_gold", "kind": "gold", "name": "เก็บเหรียญ", "desc": "เก็บเหรียญจากพื้น %d เหรียญ", "base": 500, "per_level": 80.0},
]
const WEEKLY_POOL := [
	{"id": "w_kills", "kind": "kills", "name": "นักล่าแห่งสัปดาห์", "desc": "ปราบมอนสเตอร์ %d ตัว", "base": 600, "per_level": 8.0},
	{"id": "w_boss", "kind": "boss", "name": "ผู้ล้มยักษ์ประจำสัปดาห์", "desc": "ปราบบอส %d ตัว", "base": 8, "per_level": 0.0},
	{"id": "w_golden", "kind": "golden", "name": "ล่าขุมทอง", "desc": "ปราบมอนทองคำ %d ตัว", "base": 5, "per_level": 0.0},
	{"id": "w_world_boss", "kind": "world_boss", "name": "ศึกบอสโลก", "desc": "ร่วมล้มบอสโลก %d ครั้ง", "base": 1, "per_level": 0.0},
	{"id": "w_enhance", "kind": "enhance", "name": "ช่างเทพประจำสัปดาห์", "desc": "ตีบวกไอเทม %d ครั้ง", "base": 10, "per_level": 0.0, "min": 10},
	{"id": "w_party", "kind": "party_min", "name": "เพื่อนร่วมศึก", "desc": "ล่ามอนสเตอร์เป็นปาร์ตี้ %d นาที", "base": 60, "per_level": 0.0},
	{"id": "w_raid", "kind": "raid", "name": "นักบุกเรด", "desc": "ผ่านเรดปาร์ตี้ %d ครั้ง", "base": 3, "per_level": 0.0, "min": 20},
	{"id": "w_guild_war", "kind": "guild_war", "name": "ทหารกิลด์", "desc": "ร่วมสงครามกิลด์ %d ครั้ง", "base": 3, "per_level": 0.0, "guild": true},
	{"id": "w_league", "kind": "league", "name": "ดาวเด่นลีก", "desc": "ทำแต้มลีกกิลด์ %d แต้ม", "base": 150, "per_level": 0.0, "guild": true},
	{"id": "w_skills", "kind": "skills", "name": "ปรมาจารย์สกิล", "desc": "ใช้สกิล %d ครั้ง", "base": 400, "per_level": 4.0},
	{"id": "w_dailies", "kind": "daily_done", "name": "ขยันทั้งสัปดาห์", "desc": "รับรางวัลภารกิจรายวัน %d ภารกิจ", "base": 20, "per_level": 0.0},
]
const DAILY_POINTS := 10
const WEEKLY_POINTS := 60

## Tier n (1-30) pays REWARDS[n - 1]: gold (in gold units, gold_unit), potion (bottles of
## the hero's level, potion_id), jewel ([ItemData.JEWELS id, count]), title.
const REWARDS := [
	{"gold": 1}, {"potion": 10}, {"jewel": ["purple", 2]}, {"gold": 2}, {"jewel": ["wolf_fang", 2]},
	{"jewel": ["pink", 1]}, {"potion": 20}, {"jewel": ["chaos", 1]}, {"gold": 3}, {"jewel": ["set_core", 1]},
	{"jewel": ["purple", 4]}, {"jewel": ["stag_antler", 2]}, {"jewel": ["feather", 1]}, {"gold": 4}, {"jewel": ["chaos", 2]},
	{"potion": 30}, {"jewel": ["pink", 3]}, {"jewel": ["griffin_plume", 2]}, {"gold": 5}, {"jewel": ["set_core", 1]},
	{"jewel": ["purple", 6]}, {"jewel": ["feather", 2]}, {"jewel": ["chaos", 3]}, {"jewel": ["drake_scale", 1]}, {"gold": 8},
	{"jewel": ["pink", 5]}, {"jewel": ["feather", 3]}, {"jewel": ["chaos", 5]}, {"gold": 10}, {"jewel": ["set_core", 2], "gold": 15, "title": true},
]
const PARTY_TICK := 60.0
const CHECK_EVERY := 30.0

## Tests pin the clock here (>= 0); otherwise WorldPresence.clock().
static var test_time := -1.0
static var _party_time := 0.0
static var _check_time := 0.0


static func now() -> float:
	return test_time if test_time >= 0.0 else WorldPresence.clock()


static func _t(t: float) -> float:
	return now() if t < 0.0 else t


# --- Calendar (Thai time) ----------------------------------------------------------

static func day_of(t: float) -> int:
	return WorldEvents.day_of(t)


## Thai week index, Monday to Sunday (day 0, 1 Jan 1970, was a Thursday).
static func week_of(t: float) -> int:
	return floori(float(day_of(t) + 3) / 7.0)


## year x 12 + month - 1 of the Thai calendar date.
static func month_of(t: float) -> int:
	var d := Time.get_datetime_dict_from_unix_time(int(floor(t)) + WorldPlayers.TZ)
	return int(d.year) * 12 + int(d.month) - 1


static func day_end(t: float) -> float:
	return float(day_of(t) + 1) * WorldEvents.DAY - WorldPlayers.TZ


static func week_end(t: float) -> float:
	return float((week_of(t) + 1) * 7 - 3) * WorldEvents.DAY - WorldPlayers.TZ


static func month_end(t: float) -> float:
	var m := month_of(t) + 1
	var start := Time.get_unix_time_from_datetime_dict({"year": floori(m / 12.0), "month": posmod(m, 12) + 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	return float(start - WorldPlayers.TZ)


## "5 ชม. 12 นาที" / "3 วัน 4 ชม." until [param end].
static func left_text(t: float, end: float) -> String:
	var s := maxi(0, int(end - t))
	var days := s / 86400
	var hours := (s % 86400) / 3600
	if days > 0:
		return "%d วัน %d ชม." % [days, hours]
	return "%d ชม. %d นาที" % [hours, (s % 3600) / 60]


# --- Quests ------------------------------------------------------------------------

static func template(id: String) -> Dictionary:
	for row in DAILY_POOL + WEEKLY_POOL:
		if row.id == id:
			return row
	return {}


static func target_for(row: Dictionary, level: int) -> int:
	return clampi(int(round(float(row.base) + float(row.per_level) * level)), 1, MAX_TARGET)


## The draw for a character and a day (scope "d") or week ("w"): template ids, all of
## different kinds, from the templates open to the level (and the guild).
static func roll(scope: String, seed_name: String, index: int, level: int, in_guild: bool) -> Array:
	var pool: Array = []
	for row in (DAILY_POOL if scope == "d" else WEEKLY_POOL):
		if level >= int(row.get("min", 1)) and (in_guild or not bool(row.get("guild", false))):
			pool.append(row)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s%d" % [seed_name, scope, index])
	var count := DAILY_COUNT if scope == "d" else WEEKLY_COUNT
	var out: Array = []
	var kinds := {}
	while out.size() < count and not pool.is_empty():
		var row: Dictionary = pool.pop_at(rng.randi() % pool.size())
		if kinds.has(row.kind):
			continue
		kinds[row.kind] = true
		out.append(String(row.id))
	return out


static func _seed_name(profile: Dictionary) -> String:
	return "%s|%s" % [String(profile.get("name", "")), String(profile.get("class", ""))]


static func _in_guild(profile: Dictionary) -> bool:
	return int(profile.get("flags", {}).get(Game.GUILD_FLAG, 0)) > 0


static func _entries(ids: Array, level: int) -> Array:
	var out: Array = []
	for id in ids:
		out.append({"id": id, "p": 0, "t": target_for(template(id), level), "c": false})
	return out


## The pass state of [param profile] at t, with the day's, week's and month's draws and
## resets done. Returns whether anything was reset in [param changed] (a Dictionary).
static func state_of(profile: Dictionary, t: float, changed := {}) -> Dictionary:
	if not profile.get(KEY) is Dictionary:
		profile[KEY] = {}
	var s: Dictionary = profile[KEY]
	var level := int(profile.get("level", 1))
	var day := day_of(t)
	if int(s.get("day", -1)) != day or not s.get("dq") is Array:
		s["day"] = day
		s["dq"] = _entries(roll("d", _seed_name(profile), day, level, _in_guild(profile)), level)
		changed["day"] = true
	var week := week_of(t)
	if int(s.get("week", -1)) != week or not s.get("wq") is Array:
		s["week"] = week
		s["wq"] = _entries(roll("w", _seed_name(profile), week, level, _in_guild(profile)), level)
		changed["week"] = true
	var month := month_of(t)
	if int(s.get("month", -1)) != month:
		s["month"] = month
		s["pts"] = 0
		s["got"] = 0
		changed["month"] = true
	for key in ["pts", "got", "warn"]:
		s[key] = int(s.get(key, 0))
	return s


static func state(t := -1.0) -> Dictionary:
	if not Game.has_profile:
		return {}
	var changed := {}
	var s := state_of(Game.profile, _t(t), changed)
	if not changed.is_empty():
		Game.mark_dirty()
	return s


## Counts [param amount] of [param kind] on today's and this week's open quests; tells
## the hero about each one it finishes.
static func progress(kind: String, amount := 1, t := -1.0) -> void:
	if not Game.has_profile or amount <= 0:
		return
	var s := state(t)
	for scope in ["dq", "wq"]:
		for entry in s[scope]:
			var row := template(String(entry.id))
			if row.get("kind", "") != kind or bool(entry.c) or int(entry.p) >= int(entry.t):
				continue
			entry["p"] = mini(int(entry.p) + amount, int(entry.t))
			Game.mark_dirty()
			if int(entry.p) >= int(entry.t):
				Game.say("ภารกิจ%sสำเร็จ: %s — รับแต้มบัตรที่เมนู \"ภารกิจ & บัตร\"" % ["รายวัน" if scope == "dq" else "รายสัปดาห์", row.name], &"quest")


static func quest_gold(level: int, weekly: bool) -> int:
	return (80 + level * 25) * (4 if weekly else 1)


static func quest_exp(level: int, weekly: bool) -> int:
	return (int(HeroStats.exp_to_next(level) * 0.04) + 30) * (4 if weekly else 1)


## Claims a finished quest once: pass points, gold and EXP. scope "d" or "w". "ok" or a reason.
static func claim_quest(scope: String, index: int, t := -1.0) -> String:
	if not Game.has_profile:
		return "ไม่มีตัวละคร"
	var s := state(t)
	var list: Array = s.dq if scope == "d" else s.wq
	if index < 0 or index >= list.size():
		return "ไม่มีภารกิจนี้"
	var entry: Dictionary = list[index]
	if bool(entry.c):
		return "รับรางวัลภารกิจนี้ไปแล้ว"
	if int(entry.p) < int(entry.t):
		return "ภารกิจยังไม่สำเร็จ"
	entry["c"] = true
	var weekly := scope == "w"
	var level := int(Game.profile.level)
	_add_points(s, WEEKLY_POINTS if weekly else DAILY_POINTS)
	Game.add_gold(quest_gold(level, weekly))
	Game.add_exp(quest_exp(level, weekly))
	if not weekly:
		progress("daily_done", 1, t)
	Game.mark_dirty()
	Game.quest_changed.emit()
	return "ok"


static func _add_points(s: Dictionary, points: int) -> void:
	var before := tiers_reached(int(s.pts))
	s["pts"] = mini(int(s.pts) + points, TIERS * TIER_POINTS)
	var after := tiers_reached(int(s.pts))
	if after > before:
		Game.say("บัตรสะสมแต้มถึงขั้น %d แล้ว! รับรางวัลได้เลย" % after, &"success")


# --- The pass ------------------------------------------------------------------------

static func tiers_reached(points: int) -> int:
	return clampi(points / TIER_POINTS, 0, TIERS)


static func is_claimed(s: Dictionary, tier: int) -> bool:
	return (int(s.get("got", 0)) >> (tier - 1)) & 1 == 1


static func gold_unit(profile: Dictionary) -> int:
	return 2000 + int(profile.get("level", 1)) * 500 + int(profile.get("paragon", {}).get("level", 0)) * 200


static func potion_id(level: int) -> String:
	if level < 15:
		return "hp_s"
	if level < 35:
		return "hp_m"
	if level < 60:
		return "hp_l"
	if level < 100:
		return "hp_xl"
	return "hp_xxl"


## The items and gold of a tier for this hero: {gold, items: [item], title}.
static func tier_reward(tier: int, profile: Dictionary) -> Dictionary:
	var row: Dictionary = REWARDS[clampi(tier, 1, TIERS) - 1]
	var items: Array = []
	if row.has("potion"):
		items.append(ItemData.potion(potion_id(int(profile.get("level", 1))), int(row.potion)))
	if row.has("jewel"):
		items.append(ItemData.jewel(String(row.jewel[0]), int(row.jewel[1])))
	return {"gold": int(row.get("gold", 0)) * gold_unit(profile), "items": items, "title": bool(row.get("title", false))}


static func reward_text(tier: int, profile: Dictionary) -> String:
	var r := tier_reward(tier, profile)
	var parts: PackedStringArray = []
	if int(r.gold) > 0:
		parts.append("เหรียญ %s" % PlayerStall.thousands(int(r.gold)))
	for item in r.items:
		parts.append("%s ×%d" % [ItemData.name_of(item), int(item.count)])
	if bool(r.title):
		parts.append("ตำแหน่ง \"%s\"" % String(Achievements.entry(TITLE_ID).get("title", "")))
	return " • ".join(parts)


## Claims tier [param tier] once (reached and not claimed). "ok" or a reason.
static func claim_tier(tier: int, t := -1.0) -> String:
	if not Game.has_profile:
		return "ไม่มีตัวละคร"
	var s := state(t)
	if tier < 1 or tier > TIERS:
		return "ไม่มีขั้นนี้"
	if is_claimed(s, tier):
		return "รับรางวัลขั้นนี้ไปแล้ว"
	if tier > tiers_reached(int(s.pts)):
		return "แต้มบัตรยังไม่ถึงขั้นนี้"
	var r := tier_reward(tier, Game.profile)
	for item in r.items:
		if not Game.give_or_store(item):
			return "กระเป๋าและคลังเต็ม"
	s["got"] = int(s.got) | (1 << (tier - 1))
	if int(r.gold) > 0:
		Game.add_gold(int(r.gold))
	if bool(r.title):
		Game.flag_add(TOP_FLAG)
		Game._check_achievements()
		Game.say("ได้ตำแหน่งใหม่ \"%s\" — ใส่ได้ที่เมนูตำแหน่ง" % String(Achievements.entry(TITLE_ID).get("title", "")), &"success")
	Game.mark_dirty()
	Game.quest_changed.emit()
	return "ok"


## Every finished quest and every reached tier at once; returns how many were claimed.
static func claim_all(t := -1.0) -> int:
	var n := 0
	var s := state(t)
	for scope in ["d", "w"]:
		var list: Array = s.dq if scope == "d" else s.wq
		for i in list.size():
			if claim_quest(scope, i, t) == "ok":
				n += 1
	for tier in range(1, TIERS + 1):
		if not is_claimed(s, tier) and tier <= tiers_reached(int(s.pts)):
			if claim_tier(tier, t) == "ok":
				n += 1
			else:
				break
	return n


## Quests and tiers waiting to be claimed (the HUD's red dot).
static func claimable(t := -1.0) -> int:
	if not Game.has_profile:
		return 0
	var s := state(t)
	var n := 0
	for scope in ["dq", "wq"]:
		for entry in s[scope]:
			if not bool(entry.c) and int(entry.p) >= int(entry.t):
				n += 1
	for tier in range(1, tiers_reached(int(s.pts)) + 1):
		if not is_claimed(s, tier):
			n += 1
	return n


## Unclaimed reached tiers (lost at the month's reset).
static func unclaimed_tiers(s: Dictionary) -> int:
	var n := 0
	for tier in range(1, tiers_reached(int(s.get("pts", 0))) + 1):
		if not is_claimed(s, tier):
			n += 1
	return n


## From Game._process: party minutes, the new day's and week's quests, the warning
## before the month's reset.
static func tick(delta: float) -> void:
	if not Game.has_profile:
		return
	if not Game.party().is_empty() and Game.current_zone != &"town":
		_party_time += delta
		if _party_time >= PARTY_TICK:
			_party_time -= PARTY_TICK
			progress("party_min", 1)
	_check_time += delta
	if _check_time < CHECK_EVERY:
		return
	_check_time = 0.0
	check()


## Rolls a new day / week / month and warns once a month, WARN_DAYS before the reset,
## while tiers are unclaimed. Returns the warning text ("" when none).
static func check(t := -1.0) -> String:
	if not Game.has_profile:
		return ""
	t = _t(t)
	var changed := {}
	var s := state_of(Game.profile, t, changed)
	if not changed.is_empty():
		Game.mark_dirty()
	if int(s.warn) == int(s.month) or month_end(t) - t > WARN_DAYS * WorldEvents.DAY or unclaimed_tiers(s) == 0:
		return ""
	s["warn"] = int(s.month)
	Game.mark_dirty()
	var text := "บัตรสะสมแต้มจะรีเซ็ตในอีก %s — รับรางวัลที่ค้างอยู่ %d ขั้นก่อนหมดเดือน!" % [left_text(t, month_end(t)), unclaimed_tiers(s)]
	Game.say(text, &"warning")
	return text


# --- Save checks ---------------------------------------------------------------------

static func _int_ok(v: Variant, lo := 0, hi := 1000000000000) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floor(float(v)) and float(v) >= lo and float(v) <= hi


## Whether a saved profile["dpass"] has the right shape (before _repair).
static func valid(v: Variant) -> bool:
	if not v is Dictionary:
		return false
	for key in v:
		if not key is String or key not in ["day", "week", "month", "pts", "got", "warn", "dq", "wq"]:
			return false
	for key in ["day", "week", "month", "pts", "warn"]:
		if v.has(key) and not _int_ok(v[key], -1):
			return false
	if v.has("got") and not _int_ok(v.got, 0, (1 << TIERS) - 1):
		return false
	for key in ["dq", "wq"]:
		if not v.has(key):
			continue
		if not v[key] is Array or (v[key] as Array).size() > 8:
			return false
		for e in v[key]:
			if not e is Dictionary or not e.get("id") is String or String(e.id).length() > 32:
				return false
			if not _int_ok(e.get("p", 0)) or not _int_ok(e.get("t", 1), 1, MAX_TARGET) or not e.get("c", false) is bool:
				return false
	return true


## Ints back from JSON floats; a list with a quest this game does not know is drawn again.
static func repair(data: Dictionary) -> void:
	if not data.has(KEY):
		return
	if not valid(data[KEY]):
		data.erase(KEY)
		return
	var s: Dictionary = data[KEY]
	for key in ["day", "week", "month", "pts", "got", "warn"]:
		if s.has(key):
			s[key] = int(s[key])
	for key in ["dq", "wq"]:
		if not s.has(key):
			continue
		for e in s[key]:
			if template(String(e.id)).is_empty():
				s.erase(key)
				s.erase("day" if key == "dq" else "week")
				break
			e["p"] = mini(int(e.get("p", 0)), int(e.get("t", 1)))
			e["t"] = int(e.get("t", 1))
			e["c"] = bool(e.get("c", false))
