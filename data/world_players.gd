class_name WorldPlayers
extends RefCounted
## The other players of the world: 54 people with fixed names, classes and guilds (27 go to
## Alpha, 27 to Neverdie; each joins its guild on reaching Lv.100, like the hero must).
## Nobody runs them on a server. Each keeps a daily play
## schedule set by its play style (Thai time, the same on every device), and what it
## has reached is the EXP a real player earns in the hours it played: the auto-hunt rates
## tests/tools/pace_probe.gd measured in the real fields, times the player's own
## efficiency (deaths, trips to town, slower hands than the probe's). So levels, stars,
## whereabouts and who is online are the same for everyone at a given moment, from Lv.1
## on the day the world opened up to Lv.100 ★200. While online a player stands in the
## village at the start and end of a session and otherwise hunts in the field that fits
## its level (WorldPresence shows it there, fighting the field's monsters for real).

## The world opened here (unix seconds; 26 Oct 2026, 07:00 Thai time): every world
## player started at Lv.1.
const START_UNIX := 1792972800
## Schedules run on Thai time.
const TZ := 7 * 3600
const DAY := 86400

const ALPHA := 1
const NEVERDIE := 2
const GUILD_NAMES := {ALPHA: "Alpha", NEVERDIE: "Neverdie"}
const GUILD_COLORS := {ALPHA: Color("ffd24a"), NEVERDIE: Color("ff6f8e")}

const ROSTER: Array[Dictionary] = [
	{"name": "Kaito", "class": &"warrior", "guild": ALPHA, "gender": 0, "style": "hardcore"},
	{"name": "Shadow_Fang", "class": &"assassin", "guild": ALPHA, "gender": 0, "style": "hardcore"},
	{"name": "น้องแพรวา", "class": &"priest", "guild": ALPHA, "gender": 1, "style": "regular"},
	{"name": "LanceKung", "class": &"lancer", "guild": ALPHA, "gender": 0, "style": "regular"},
	{"name": "SkyArrow", "class": &"archer", "guild": ALPHA, "gender": 0, "style": "student"},
	{"name": "Mintty", "class": &"mage", "guild": ALPHA, "gender": 1, "style": "student"},
	{"name": "Rinrada", "class": &"summoner", "guild": ALPHA, "gender": 1, "style": "night_owl"},
	{"name": "ป้อมปราการ", "class": &"defender", "guild": ALPHA, "gender": 0, "style": "weekend"},
	{"name": "เมจิกหมูกรอบ", "class": &"mage", "guild": ALPHA, "gender": 0, "style": "casual"},
	{"name": "ข้าวเหนียวมะม่วง", "class": &"archer", "guild": ALPHA, "gender": 1, "style": "casual"},
	{"name": "Zerox", "class": &"warrior", "guild": NEVERDIE, "gender": 0, "style": "hardcore"},
	{"name": "BlackLotus", "class": &"assassin", "guild": NEVERDIE, "gender": 1, "style": "hardcore"},
	{"name": "TonkatsuX", "class": &"defender", "guild": NEVERDIE, "gender": 0, "style": "regular"},
	{"name": "นักล่าตะวัน", "class": &"archer", "guild": NEVERDIE, "gender": 0, "style": "regular"},
	{"name": "Fiora", "class": &"lancer", "guild": NEVERDIE, "gender": 1, "style": "student"},
	{"name": "Yoyo", "class": &"priest", "guild": NEVERDIE, "gender": 1, "style": "student"},
	{"name": "แม่หมอมิว", "class": &"priest", "guild": NEVERDIE, "gender": 1, "style": "night_owl"},
	{"name": "PhantomZ", "class": &"summoner", "guild": NEVERDIE, "gender": 0, "style": "weekend"},
	{"name": "ไฟร์บอลเด้ง", "class": &"mage", "guild": NEVERDIE, "gender": 0, "style": "casual"},
	{"name": "Raijin", "class": &"warrior", "guild": NEVERDIE, "gender": 0, "style": "casual"},
	{"name": "Ryuu", "class": &"warrior", "guild": ALPHA, "gender": 0, "style": "student"},
	{"name": "ขุนศึกหน้าหวาน", "class": &"warrior", "guild": ALPHA, "gender": 1, "style": "weekend"},
	{"name": "ปีศาจสีเงิน", "class": &"assassin", "guild": ALPHA, "gender": 0, "style": "regular"},
	{"name": "Gekko", "class": &"assassin", "guild": ALPHA, "gender": 0, "style": "night_owl"},
	{"name": "Momo", "class": &"priest", "guild": ALPHA, "gender": 1, "style": "casual"},
	{"name": "นางฟ้าตาหวาน", "class": &"priest", "guild": ALPHA, "gender": 1, "style": "regular"},
	{"name": "หอกทะลวงฟ้า", "class": &"lancer", "guild": ALPHA, "gender": 0, "style": "hardcore"},
	{"name": "Valkyrie", "class": &"lancer", "guild": ALPHA, "gender": 1, "style": "regular"},
	{"name": "NightHawk", "class": &"archer", "guild": ALPHA, "gender": 0, "style": "night_owl"},
	{"name": "ไอซ์ซี่", "class": &"archer", "guild": ALPHA, "gender": 1, "style": "casual"},
	{"name": "พ่อมดน้อยฟ้าใส", "class": &"mage", "guild": ALPHA, "gender": 0, "style": "student"},
	{"name": "Luna_Mew", "class": &"summoner", "guild": ALPHA, "gender": 1, "style": "weekend"},
	{"name": "หมอผีหมูเด้ง", "class": &"summoner", "guild": ALPHA, "gender": 0, "style": "student"},
	{"name": "BearTank", "class": &"defender", "guild": ALPHA, "gender": 0, "style": "student"},
	{"name": "ShieldMaiden", "class": &"defender", "guild": ALPHA, "gender": 1, "style": "hardcore"},
	{"name": "Ragnar", "class": &"warrior", "guild": NEVERDIE, "gender": 0, "style": "hardcore"},
	{"name": "เสือดาวดำ", "class": &"warrior", "guild": NEVERDIE, "gender": 0, "style": "regular"},
	{"name": "Kurogane", "class": &"assassin", "guild": NEVERDIE, "gender": 0, "style": "student"},
	{"name": "จิ้งจอกเงา", "class": &"assassin", "guild": NEVERDIE, "gender": 1, "style": "night_owl"},
	{"name": "Seraphine", "class": &"priest", "guild": NEVERDIE, "gender": 1, "style": "regular"},
	{"name": "หอกพยัคฆ์", "class": &"lancer", "guild": NEVERDIE, "gender": 0, "style": "regular"},
	{"name": "Akane", "class": &"lancer", "guild": NEVERDIE, "gender": 1, "style": "weekend"},
	{"name": "ArrowRain", "class": &"archer", "guild": NEVERDIE, "gender": 0, "style": "hardcore"},
	{"name": "ลูกศรสีชมพู", "class": &"archer", "guild": NEVERDIE, "gender": 1, "style": "student"},
	{"name": "บะหมี่เวทมนตร์", "class": &"mage", "guild": NEVERDIE, "gender": 0, "style": "casual"},
	{"name": "Nebula", "class": &"mage", "guild": NEVERDIE, "gender": 1, "style": "regular"},
	{"name": "อสูรน้อยหลับยาก", "class": &"summoner", "guild": NEVERDIE, "gender": 1, "style": "night_owl"},
	{"name": "Wyvern", "class": &"summoner", "guild": NEVERDIE, "gender": 0, "style": "casual"},
	{"name": "IronWall", "class": &"defender", "guild": NEVERDIE, "gender": 0, "style": "weekend"},
	{"name": "โล่ทองคำ", "class": &"defender", "guild": NEVERDIE, "gender": 0, "style": "casual"},
	# Dark Lords (scepter and raven), added with the class.
	{"name": "DarkKaiser", "class": &"darklord", "guild": ALPHA, "gender": 0, "style": "hardcore"},
	{"name": "ราชันอีกา", "class": &"darklord", "guild": NEVERDIE, "gender": 0, "style": "regular"},
	{"name": "LordRaven", "class": &"darklord", "guild": ALPHA, "gender": 1, "style": "night_owl"},
	{"name": "จักรพรรดิมืด", "class": &"darklord", "guild": NEVERDIE, "gender": 0, "style": "weekend"},
]

## Sessions as [start hour, hours] on weekdays and at weekends (Saturday, Sunday). Each day
## moves every start by up to ±jitter hours and stretches every length by 0.7-1.3; skip is
## the chance a day is missed. eff: how much of the probe's EXP rate the style earns.
const STYLES := {
	"hardcore": {"weekday": [[12.0, 1.5], [18.5, 5.5]], "weekend": [[10.0, 4.5], [18.0, 6.0]], "jitter": 1.0, "skip": 0.03, "eff": 0.18, "label": "ขาโหด"},
	"regular": {"weekday": [[20.0, 3.0]], "weekend": [[14.0, 2.0], [20.0, 3.5]], "jitter": 1.0, "skip": 0.08, "eff": 0.15, "label": "เล่นประจำ"},
	"student": {"weekday": [[16.5, 1.5], [20.5, 2.0]], "weekend": [[10.0, 3.0], [19.0, 3.0]], "jitter": 0.8, "skip": 0.06, "eff": 0.15, "label": "นักเรียน"},
	"night_owl": {"weekday": [[22.0, 4.0]], "weekend": [[21.0, 5.5]], "jitter": 1.2, "skip": 0.08, "eff": 0.16, "label": "สายนอนดึก"},
	"weekend": {"weekday": [[21.0, 1.0]], "weekend": [[10.0, 4.0], [19.0, 4.0]], "jitter": 1.0, "skip": 0.35, "eff": 0.15, "label": "สายเสาร์อาทิตย์"},
	"casual": {"weekday": [[20.0, 1.5]], "weekend": [[15.0, 2.5]], "jitter": 1.5, "skip": 0.25, "eff": 0.13, "label": "เล่นชิลล์"},
}
## Minutes of every session spent in the village: shopping before, selling after.
const TOWN_BEFORE := 6.0
const TOWN_AFTER := 4.0

## EXP per minute of auto-hunting (pace_probe, warrior/mage mean, 60 s each) at each
## level in its field, and at Lv.100 by stars in the star fields.
const LEVEL_RATE := [[1, 900], [3, 1146], [10, 2465], [18, 5498], [26, 12453], [35, 14066], [46, 18823], [58, 21692], [70, 29115], [82, 26128], [94, 36727], [100, 36727]]
const STAR_RATE := [[0, 56160], [25, 26488], [75, 46653], [125, 38994], [175, 41755], [200, 41755]]
## Potions a world player carries out of the village.
const POTIONS := 20
const MP_POTIONS := 10
## Hours of play after ★200 before the class's divine set is complete.
const DIVINE_HOURS := 20.0

static var _table: PackedFloat64Array = PackedFloat64Array()
static var _minutes_cache := {}


static func size() -> int:
	return ROSTER.size()


static func now() -> float:
	return Time.get_unix_time_from_system()


static func entry(i: int) -> Dictionary:
	return ROSTER[i]


static func guild_name(guild: int) -> String:
	return String(GUILD_NAMES.get(guild, ""))


## Everyone who joins `guild` once at Lv.100 (the roster's side, whatever their level now).
static func members(guild: int) -> Array[int]:
	var out: Array[int] = []
	for i in ROSTER.size():
		if int(ROSTER[i].guild) == guild:
			out.append(i)
	return out


## The guild player i is in at `level`: its roster guild from Lv.100 (Game.GUILD_LEVEL), none before.
static func guild_at(i: int, level: int) -> int:
	return int(ROSTER[i].guild) if level >= Game.GUILD_LEVEL else 0


## Who is in `guild` at time t: the members who have reached Lv.100.
static func members_at(guild: int, t: float) -> Array[int]:
	var out: Array[int] = []
	for i in members(guild):
		if int(state(i, t).level) >= Game.GUILD_LEVEL:
			out.append(i)
	return out


## The first world player of a class (for tools and tests), -1 if none.
static func first_of(cls: StringName) -> int:
	for i in ROSTER.size():
		if StringName(ROSTER[i]["class"]) == cls:
			return i
	return -1


static func other_guild(guild: int) -> int:
	return NEVERDIE if guild == ALPHA else ALPHA


# --- Schedule -------------------------------------------------------------------

## Local day number (Thai time) of a unix time.
static func day_of(t: float) -> int:
	return int(floor((t + TZ) / DAY))


## The sessions player i plays on local day `day`: [[start, end], ...] in unix seconds.
static func sessions_on(i: int, day: int) -> Array:
	var style: Dictionary = STYLES[String(ROSTER[i].style)]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [ROSTER[i].name, day])
	if rng.randf() < float(style.skip):
		return []
	# 1970-01-01 was a Thursday: weekday 0 = Monday.
	var weekday := (day + 3) % 7
	var plan: Array = style.weekend if weekday >= 5 else style.weekday
	var out := []
	var midnight := float(day) * DAY - TZ
	var last_end := -INF
	for slot in plan:
		var start := midnight + (float(slot[0]) + rng.randf_range(-1.0, 1.0) * float(style.jitter)) * 3600.0
		var length := float(slot[1]) * rng.randf_range(0.7, 1.3) * 3600.0
		start = maxf(start, last_end + 900.0)
		out.append([start, start + length])
		last_end = start + length
	return out


## Minutes player i has played between the world's opening and t.
static func played_minutes(i: int, t: float) -> float:
	if t <= START_UNIX:
		return 0.0
	var key := "%d|%d" % [i, int(t / 60.0)]
	if _minutes_cache.has(key):
		return _minutes_cache[key]
	if _minutes_cache.size() > 4000:
		_minutes_cache.clear()
	var total := 0.0
	# A session can run past midnight, so the day before the opening counts too.
	for day in range(day_of(START_UNIX) - 1, day_of(t) + 1):
		for s in sessions_on(i, day):
			var a := maxf(float(s[0]), float(START_UNIX))
			var b := minf(float(s[1]), t)
			if b > a:
				total += (b - a) / 60.0
	_minutes_cache[key] = total
	return total


## The session player i is in at t, or [] when offline.
static func session_at(i: int, t: float) -> Array:
	if t < START_UNIX:
		return []
	for day in [day_of(t) - 1, day_of(t)]:
		for s in sessions_on(i, day):
			if t >= float(s[0]) and t < float(s[1]):
				return s
	return []


# --- Progress -------------------------------------------------------------------

## Probe EXP per minute at a level (and at Lv.100, at a star count).
static func rate(level: int, stars: int) -> float:
	if level >= Game.MAX_LEVEL:
		return _lerp_table(STAR_RATE, stars)
	return _lerp_table(LEVEL_RATE, level)


static func _lerp_table(table: Array, x: int) -> float:
	for k in range(1, table.size()):
		if x <= int(table[k][0]):
			var a: Array = table[k - 1]
			var b: Array = table[k]
			var f := clampf(float(x - int(a[0])) / float(maxi(1, int(b[0]) - int(a[0]))), 0.0, 1.0)
			# Rates grow by factors, so they are blended in log space.
			return exp(lerpf(log(float(a[1])), log(float(b[1])), f))
	return float(table[-1][1])


## Probe minutes from Lv.1 to step k: steps 0..99 are Lv.1..100, steps 100..300 are ★0..200.
static func _steps() -> PackedFloat64Array:
	if not _table.is_empty():
		return _table
	var table := PackedFloat64Array()
	var total := 0.0
	table.append(0.0)
	for level in range(1, Game.MAX_LEVEL):
		total += float(HeroStats.exp_to_next(level)) / rate(level, 0)
		table.append(total)
	for star in Game.PARAGON_MAX:
		total += float(HeroStats.star_need(star)) / rate(Game.MAX_LEVEL, star)
		table.append(total)
	_table = table
	return table


## How much of the probe's rate player i earns: its style's efficiency and its own hands.
static func efficiency(i: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("eff|%s" % ROSTER[i].name)
	return float(STYLES[String(ROSTER[i].style)].eff) * rng.randf_range(0.88, 1.12)


## {level, stars, frac (0..1 to the next step), minutes (played), divine (bool),
## divine_frac (0..1 of the divine set's hours)} for `minutes` of play at efficiency
## `eff`, plus `extra` probe minutes earned in the hero's party (bonus_work).
static func progress_for(minutes: float, eff: float, extra := 0.0) -> Dictionary:
	var steps := _steps()
	var work := minutes * eff + maxf(0.0, extra)
	var k := steps.bsearch(work, false) - 1
	k = clampi(k, 0, steps.size() - 1)
	var frac := 0.0
	if k < steps.size() - 1:
		frac = clampf((work - steps[k]) / maxf(0.001, steps[k + 1] - steps[k]), 0.0, 0.999)
	var level := mini(k + 1, Game.MAX_LEVEL)
	var stars := clampi(k - (Game.MAX_LEVEL - 1), 0, Game.PARAGON_MAX)
	var divine_need := DIVINE_HOURS * 60.0 * eff
	var post := work - steps[steps.size() - 1]
	var divine_frac := clampf(post / maxf(0.001, divine_need), 0.0, 1.0) if stars >= Game.PARAGON_MAX else 0.0
	return {"level": level, "stars": stars, "frac": frac, "minutes": minutes, "divine": divine_frac >= 1.0, "divine_frac": divine_frac}


# --- Party EXP ----------------------------------------------------------------------

## What world players earned in the hero's party is kept with the world on this
## device, not with a character: a new character meets them as they were.
const BONUS_PATH := "user://toon_tale_world.json"
## Kept on disk except in headless runs (tests keep it in memory, so runs stay alike).
static var persist := DisplayServer.get_name() != "headless"
## Probe minutes of progress each player (by name) earned in parties.
static var bonus := {}
static var _bonus_loaded := false
static var _bonus_dirty := false


static func bonus_work(i: int) -> float:
	_load_bonus()
	return float(bonus.get(String(ROSTER[i].name), 0.0))


## Player i earns `amount` EXP at its level and stars (its share of a party kill).
static func add_exp(i: int, amount: float, level: int, stars: int) -> void:
	if amount <= 0.0 or i < 0 or i >= ROSTER.size():
		return
	_load_bonus()
	var key := String(ROSTER[i].name)
	bonus[key] = float(bonus.get(key, 0.0)) + amount / maxf(1.0, rate(level, stars))
	_bonus_dirty = true


## Writes the party EXP when it changed (Game.save calls this).
static func store() -> void:
	if not _bonus_dirty or not persist:
		return
	var file := FileAccess.open(BONUS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"bonus": bonus}))
		_bonus_dirty = false


static func _load_bonus() -> void:
	if _bonus_loaded:
		return
	_bonus_loaded = true
	if not persist or not FileAccess.file_exists(BONUS_PATH):
		return
	var file := FileAccess.open(BONUS_PATH, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("bonus") is Dictionary:
		return
	for key in parsed.bonus:
		var value: Variant = parsed.bonus[key]
		if (value is float or value is int) and float(value) >= 0.0 and float(value) < 1e9:
			bonus[String(key)] = float(value)


## Forgets every party EXP (tests).
static func clear_bonus() -> void:
	bonus.clear()
	_bonus_loaded = true
	_bonus_dirty = true


## Everything about player i at time t: the roster entry plus level, stars, online,
## place (the zone id it stands in, "" offline), its guild now (0 below Lv.100; the
## roster's side is in "joins") and the gear grade it wears.
static func state(i: int, t: float = -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	var e: Dictionary = ROSTER[i]
	var p := progress_for(played_minutes(i, t), efficiency(i), bonus_work(i))
	var s := session_at(i, t)
	var place := ""
	if not s.is_empty():
		var since := (t - float(s[0])) / 60.0
		var until := (float(s[1]) - t) / 60.0
		place = "town" if since < TOWN_BEFORE or until < TOWN_AFTER else String(hunting_zone(int(p.level), int(p.stars), bool(p.divine)))
	var out := e.duplicate()
	out.merge(p)
	out["index"] = i
	out["joins"] = int(e.guild)
	out["guild"] = guild_at(i, int(p.level))
	out["online"] = not s.is_empty()
	out["place"] = place
	out["grade"] = grade_of(int(p.level), int(p.stars), bool(p.divine))
	out["last_seen"] = _last_seen(i, t) if s.is_empty() else t
	return out


## When player i last logged off before t (0 if never).
static func _last_seen(i: int, t: float) -> float:
	var day := day_of(t)
	for back in 8:
		var list := sessions_on(i, day - back)
		for k in range(list.size() - 1, -1, -1):
			var end := float(list[k][1])
			if end <= t and end > START_UNIX:
				return end
	return 0.0


## The field a player hunts in: the one whose levels fit, then the star fields by stars,
## and the lotus sanctum (the divine set) from ★200.
static func hunting_zone(level: int, stars: int, _divine := false) -> StringName:
	if level >= Game.MAX_LEVEL:
		if stars >= Game.PARAGON_MAX:
			return DivineRegionData.ID
		var at: StringName = &"void"
		for k in StarProgression.REGIONS.size():
			if stars >= int(StarProgression.ENTRY[k]):
				at = StarProgression.REGIONS[k]
		return at
	ZoneData.ensure()
	for id in ZoneData.ZONES:
		var z: Dictionary = ZoneData.ZONES[id]
		if String(z.get("scene", "")) != "field" or z.get("pvp", false) or z.get("arena", false) or z.get("tower", false) or z.has("star"):
			continue
		var band: Array = z.get("level", [0, 0])
		if level >= int(band[0]) and level <= int(band[1]) and id != &"void":
			return id
	return &"meadow"


## Guild-war gear grade (GuildWarData.GRADES): the star set reached, the divine set once
## it is complete; below ★50 the plain 50-star set (war rules dress everyone).
static func grade_of(_level: int, stars: int, divine: bool) -> int:
	if divine:
		return GuildWarData.DIVINE
	var grade := 50
	for g in [100, 150, 200]:
		if stars >= g:
			grade = g
	return grade


# --- Looks and fighters ---------------------------------------------------------------

## Player i's face and hair, always the same.
static func look(i: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("look|%s" % ROSTER[i].name)
	var l := FaceKit.random_look(rng)
	var gender := int(ROSTER[i].gender)
	if int(l.gender) != gender:
		l["gender"] = gender
		l["hair"] = rng.randi() % FaceKit.option_count("hair", gender)
		ChibiLook.apply_style(l, int(l["hair"]) % ChibiLook.count("style"))
	return l


## A party-member dictionary for the field (Companion reads class, name, level, stars;
## the gear it found follows frac and divine_frac too).
static func member(i: int, t: float = -1.0) -> Dictionary:
	var s := state(i, t)
	return {"class": String(s["class"]), "name": String(s.name), "level": int(s.level), "stars": int(s.stars), "exp": 0,
		"frac": float(s.frac), "divine_frac": float(s.divine_frac),
		"stance": "aggressive", "trait": "brave", "gender": int(s.gender), "potions": POTIONS, "mp_potions": MP_POTIONS}


## Brings a member sheet up to state s; true when it found something new to wear.
static func sync_member(m: Dictionary, s: Dictionary) -> bool:
	var before := gear_signature(m)
	m["level"] = int(s.level)
	m["stars"] = int(s.stars)
	m["frac"] = float(s.frac)
	m["divine_frac"] = float(s.divine_frac)
	return gear_signature(m) != before


## The character sheet of a world player at its level and stars (for HeroStats): the
## gear it found and its job, plus every stat point spent like a player does (60% main
## stat, 40% vitality), its star points and its skills ranked up as it levels.
static func profile(m: Dictionary) -> Dictionary:
	var level := int(m.level)
	var stars := Game.party_stars(m)
	var p := {"class": m["class"], "level": level, "attrs": {}, "equip": equip(m), "adv": JobData.adv_for_level(level),
		"paragon": {"level": stars, "alloc": Game.party_star_alloc(stars)}}
	var points := Game.STAT_POINTS_PER_LEVEL * (level - 1)
	var main := String(JobData.resolve(StringName(m["class"]), int(p.adv)).main)
	var attrs := {"str": 0, "int": 0, "dex": 0, "vit": 0}
	attrs[main] = int(points * 0.6)
	attrs["vit"] = int(attrs["vit"]) + int(points * 0.4)
	p["attrs"] = attrs
	var skills := {}
	for skill in ClassData.pool(StringName(m["class"])):
		if int(skill.level) <= level:
			skills[String(skill.id)] = clampi(1 + (level - int(skill.level)) / 12, 1, SkillRank.MAX)
	p["skills"] = skills
	return p


# --- What they wear: what they found -----------------------------------------------

## A world player wears what it has picked up, slot by slot, like a player: every level
## band (10 levels) its monsters drop one piece per slot somewhere in the band, or none
## at all (MISS: it keeps the older piece through that band); a find has its own rarity
## and is enhanced a step at a time after it is found (common pieces less). The best piece
## found so far is worn, so a rare older piece can stay on over a plain newer one. Past
## Lv.100 the star fields drop the star tiers' pieces, worn some stars after the tier opens;
## a Lv.100 boss drops the class wings, the star wings come after ★100; in the lotus
## sanctum the divine pieces turn up one by one until the set is complete. All of it is
## seeded by the player's name: the same finds on every device at the same moment.
const FIND_LEVELS := 8.0
const FIND_STARS := 22.0
const MISS := 0.22
const STAR_MISS := 0.12
## Rarity of a find, common .. mythic (players keep the better drops).
const FIND_RARITY := [0.16, 0.36, 0.32, 0.13, 0.03]
## Levels of play per enhancement step after a find, and the step caps by rarity.
const PLUS_EVERY := 1.4
const PLUS_CAP := [2, 4, 6, 7, 8]
## Stars after the wing level the class wings drop, and after ★100 the star wings.
const WING_STARS := 35.0
const STAR_WING_STARS := 40.0

static var _gear := {}
static var _gear_sig := {}


## Where a member sheet is on the way, as one number: Lv.1-100 with the part of the
## level done, then 100 + stars (to 300).
static func point_of(m: Dictionary) -> float:
	var level := int(m.level)
	var frac := clampf(float(m.get("frac", 0.0)), 0.0, 0.999)
	if level < Game.MAX_LEVEL:
		return float(level) + frac
	var stars := clampi(int(m.get("stars", 0)), 0, Game.PARAGON_MAX)
	return float(Game.MAX_LEVEL + stars) + (frac if stars < Game.PARAGON_MAX else 0.0)


static func _find_rng(name: String, slot: String, what: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("find|%s|%s|%s" % [name, slot, what])
	return rng


static func _roll_find_rarity(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	for k in FIND_RARITY.size():
		r -= float(FIND_RARITY[k])
		if r <= 0.0:
			return k
	return 0


## The piece kept for one slot at point p: {} when nothing was found yet, otherwise
## {"key", "kind" (level / star / divine), "level", "rarity", "plus", "tier", "at"}.
static func _best_find(name: String, slot: String, p: float, divine_frac: float) -> Dictionary:
	var best := {}
	var best_score := -1.0
	for band in 10:
		var start := float(band * 10 + 1)
		if p < start:
			break
		var rng := _find_rng(name, slot, "b%d" % band)
		var at := start + rng.randf() * FIND_LEVELS
		var rarity := _roll_find_rarity(rng)
		var missed := rng.randf() < MISS
		if band == 0 and slot == "weapon":
			# Everyone sets out with the beginner's weapon.
			at = 1.0
			rarity = 0
			missed = false
		if missed or p < at:
			continue
		var level := clampi(int(at), int(start), int(start) + 9)
		var plus := mini(int(PLUS_CAP[rarity]), int((p - at) / PLUS_EVERY))
		var score := ItemData.gear_power(level) * ItemData.rarity_mult(rarity, 0.2) * (1.0 + 0.06 * plus)
		if score > best_score:
			best_score = score
			best = {"key": "b%d" % band, "kind": "level", "level": level, "rarity": rarity, "plus": plus, "at": at}
	for tier in StarProgression.TIERS:
		var start := float(Game.MAX_LEVEL + int(tier))
		if p < start:
			break
		var rng := _find_rng(name, slot, "s%d" % tier)
		var at := start + rng.randf() * FIND_STARS
		if rng.randf() < STAR_MISS or p < at:
			continue
		var score := ItemData.gear_power(Game.MAX_LEVEL + int(tier)) * ItemData.rarity_mult(3, 0.2)
		if score > best_score:
			best_score = score
			best = {"key": "s%d" % tier, "kind": "star", "tier": int(tier), "at": at}
	if divine_frac > 0.0 and slot in DivineGearData.SLOTS:
		var rng := _find_rng(name, slot, "divine")
		if divine_frac >= rng.randf_range(0.12, 1.0):
			best = {"key": "divine", "kind": "divine", "at": 300.0}
	return best


## The pair of wings found by point p ({} for none yet).
static func _wing_find(name: String, p: float) -> Dictionary:
	var start := float(ItemData.WING_DROP_LEVEL)
	if p < start:
		return {}
	var star_rng := _find_rng(name, "wings", "star")
	var star_at := float(Game.MAX_LEVEL + StarWingData.REQUIRED_STARS) + star_rng.randf() * STAR_WING_STARS
	if p >= star_at:
		return {"key": "star_wings", "at": star_at}
	var rng := _find_rng(name, "wings", "class")
	var at := start + rng.randf() * WING_STARS
	return {"key": "wings", "at": at} if p >= at else {}


static func _gear_key(m: Dictionary) -> String:
	return "%s|%d|%d" % [m.name, int(point_of(m) * 4.0), int(float(m.get("divine_frac", 0.0)) * 8.0)]


## Which pieces member sheet m wears, as one string (changes when it puts on a new find
## or enhances one).
static func gear_signature(m: Dictionary) -> String:
	var key := _gear_key(m)
	if not _gear_sig.has(key):
		equip(m)
	return String(_gear_sig.get(key, ""))


## What member sheet m wears now: its best find per slot (see above).
static func equip(m: Dictionary) -> Dictionary:
	var key := _gear_key(m)
	if _gear.has(key):
		return _gear[key]
	var name := String(m.name)
	var cls := StringName(m["class"])
	var p := point_of(m)
	var divine_frac := float(m.get("divine_frac", 0.0))
	var gear := {}
	var sig: PackedStringArray = []
	for slot in ItemData.SLOTS:
		var find := _best_find(name, slot, p, divine_frac)
		if find.is_empty():
			continue
		var rng := _find_rng(name, slot, "%s|item" % find.key)
		var item := {}
		match String(find.kind):
			"divine":
				item = DivineGearData.item(cls, slot, rng)
			"star":
				item = StarProgression.item(cls, int(find.tier), slot, rng)
			_:
				item = ItemData.generate(int(find.level), cls, rng, int(find.rarity), slot)
				if find.key == "b0" and slot == "weapon":
					item["name"] = "%s ของมือใหม่" % ItemData.NAMES[item.base][0]
				if EnhanceFx.can_enhance(item):
					item["plus"] = int(find.plus)
		if item.is_empty():
			continue
		gear[slot] = item
		sig.append("%s:%s+%d" % [slot, find.key, int(item.get("plus", 0))])
	var wings := _wing_find(name, p)
	if not wings.is_empty():
		var rng := _find_rng(name, "wings", "%s|item" % wings.key)
		gear["wings"] = StarWingData.item(String(cls), rng, 3) if wings.key == "star_wings" else ItemData.wings(rng, String(cls), 2 + rng.randi() % 2)
		sig.append(String(wings.key))
	if _gear.size() > 400:
		_gear.clear()
		_gear_sig.clear()
	_gear[key] = gear
	_gear_sig[key] = ",".join(sig)
	return gear


## The newest piece in `after` that `before` did not have (for "picked up" notes), or {}.
static func new_piece(before: Dictionary, after: Dictionary) -> Dictionary:
	for slot in after:
		var was: Variant = before.get(slot)
		var now_item: Dictionary = after[slot]
		if not was is Dictionary or String(was.get("name", "")) != String(now_item.get("name", "")) or int(was.get("plus", 0)) != int(now_item.get("plus", 0)):
			return now_item
	return {}


## How a player likes its wings (weights for stand / fly / fold), always the same.
static func wing_taste(i: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wings|%s" % ROSTER[i].name)
	return [rng.randf_range(0.2, 1.0), rng.randf_range(0.1, 1.4), rng.randf_range(0.05, 0.9)]


## Player i as a guild-war fighter at time t, as it really is then: its level, stars,
## stat points, skill ranks and the gear it found (WorldPlayers.profile), its own name and face.
static func fighter(i: int, t: float, _rng: RandomNumberGenerator = null) -> Dictionary:
	var s := state(i, t)
	var m := member(i, t)
	var sheet := profile(m)
	return {
		"member": {"class": String(s["class"]), "name": String(s.name), "level": int(s.level)},
		"profile": sheet,
		"mults": {"hp": 1.0, "atk": 1.0, "def": 1.0},
		"difficulty": GuildWarData.SKILL,
		"look": look(i),
		"grade": int(s.grade),
		"tag": level_text(s),
		"power": GuildWarData.power_of(HeroStats.compute(sheet)),
		"world": i,
		"online": bool(s.online),
	}


## Display line: "Lv.57" or "Lv.100 ★120".
static func level_text(s: Dictionary) -> String:
	return "Lv.%d%s" % [int(s.level), " ★%d" % int(s.stars) if int(s.stars) > 0 else ""]


## Where a player is, for the guild roster.
static func where_text(s: Dictionary, t: float = -1.0) -> String:
	if t < 0.0:
		t = now()
	if t < START_UNIX:
		return "รอเปิดโลก"
	if bool(s.online):
		var place := StringName(s.place)
		return "ออนไลน์ · %s" % (ZoneData.get_zone(place).name if place != &"town" else "หมู่บ้าน")
	var seen := float(s.get("last_seen", 0.0))
	if seen <= 0.0:
		return "ยังไม่เคยเข้าเกม"
	var ago := int((t - seen) / 60.0)
	if ago < 60:
		return "ออฟไลน์ · %d นาทีก่อน" % maxi(1, ago)
	if ago < 60 * 24:
		return "ออฟไลน์ · %d ชม.ก่อน" % (ago / 60)
	return "ออฟไลน์ · %d วันก่อน" % (ago / (60 * 24))
