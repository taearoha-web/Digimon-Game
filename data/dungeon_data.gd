class_name DungeonData
extends RefCounted
## The four-player mechanics dungeon "สุสานมังกรโบราณ" (zone DRAGON_TOMB): two packs of
## tomb guardians in one bone-strewn arena (DragonTombArt), then the Ancient Dragon King
## (DragonBoss) with three role mechanics the party must split between them:
## - กระจายตัว (spread): two players are marked with ดวงตาเพลิง and explode after
##   DragonBoss.MARK_TIME, hurting everyone within SPREAD_RADIUS; marked players move apart.
## - ล่อบอส (taunt): กรงเล็บทำลายล้าง, a telegraphed cone at its target that only a taunting
##   Defender (or a warded player, a Priest's buff) survives well; others side-step.
## - สลับเป้า (target switch): at 70% and 35% it is invulnerable behind two ศิลามังกร
##   crystals that must both fall within CRYSTAL_TIME or it heals and tries again.
## It enrages after DragonBoss.ENRAGE_TIME. A fallen member stands again at the next phase
## change; the run fails when all four are down.
##
## It takes a party of EXACTLY PARTY_SIZE (the hero and three: world players in the party,
## Game.world_party, and/or real online players of the hero's online party), Lv.100 with
## MIN_STARS stars ("เลเวล 120"), RUNS_PER_DAY entries a Thai day. Strength follows the
## party (RaidData.party_power / monster_stats with this dungeon's time-to-kill).
##
## Rewards: gold, EXP, forge jewels and the dungeon-only material เกล็ดมังกรโบราณ
## (SCALE: 1-3 a clear, FIRST_WEEK_SCALES for the week's first clear), exchanged at the
## keeper for dungeon-only gear anyone can wear (SHOP: the amulet เครื่องรางมังกร and the
## ring แหวนเขี้ยวมังกร, Lv.120 mythic, better than field drops of their level). A clear
## under FAST_SECONDS earns the title ผู้พิชิตสุสานมังกร (Achievements). The best clear
## time a week is ranked (DungeonRanking). Not in ZoneData.ZONES: entered from the keeper.

const ID: StringName = &"dragon_tomb"
const TITLE := "ดันเจี้ยนกลไก · สุสานมังกรโบราณ"
const SHORT := "สุสานมังกรโบราณ"
const KEEPER := "ผู้เฝ้าสุสานมังกร"
const MIN_LEVEL := 100
## Lv.100 with this many stars: shown as "เลเวล 120" (ItemData.level_text).
const MIN_STARS := 20
const SHOWN_MIN_LEVEL := MIN_LEVEL + MIN_STARS
const PARTY_SIZE := 4
const RUNS_PER_DAY := 2
## Trash packs before the boss (the boss is "floor" PACKS + 1).
const PACKS := 2
const PACK_SIZE := [5, 6]
const BOSS_NAME := "ราชันมังกรโบราณ"
const CRYSTAL_NAME := "ศิลามังกร"
const BOSS_MODEL: StringName = &"abyss_dragon"
const BOSS_TINT := Color(0.9, 1.6, 1.1)
const BOSS_COLOR := Color("5cf28a")
## Seconds a party of its power needs for the boss / a crystal / a pack monster.
const BOSS_TTK := 150.0
const BOSS_HP_MULT := 3.0
const CRYSTAL_TTK := 7.0
const TRASH_TTK := 6.0
## A clear this fast earns the title (Achievements "tomb_fast").
const FAST_SECONDS := 300
## The material: a clear drops SCALE_MIN..SCALE_MAX, the week's first clear FIRST_WEEK_SCALES.
const SCALE := "dragon_scale"
const SCALE_MIN := 1
const SCALE_MAX := 3
const FIRST_WEEK_SCALES := 5
## Flags in the profile (Game.profile.flags).
const F_DAY := "tomb_day"
const F_RUNS := "tomb_runs"
const F_OPEN := "tomb_open"
const F_WEEK := "tomb_week"
const F_CLEARS := "tomb_clears"
const F_BEST := "tomb_best"
const F_FAST := "tomb_fast"
const F_SHOP := "tomb_shop"
## Dungeon gear carries this key (ItemData gear of any class).
const GEAR_KEY := "dungeon"
const GEAR_LEVEL := SHOWN_MIN_LEVEL
## What the keeper exchanges scales for: {id, name, cost (scales), kind}.
const SHOP := [
	{"id": "charm", "name": "เครื่องรางมังกร", "cost": 12, "kind": "gear", "slot": "amulet", "desc": "สร้อยเครื่องรางจากเกล็ดมังกรโบราณ ใส่ได้ทุกอาชีพ (Lv.100 ★20) HP/MP/ATK/DEF สูงกว่าของดรอปเลเวลเดียวกัน"},
	{"id": "fang", "name": "แหวนเขี้ยวมังกร", "cost": 10, "kind": "gear", "slot": "ring", "desc": "แหวนเขี้ยวมังกรโบราณ ใส่ได้ทุกอาชีพ (Lv.100 ★20) ATK และคริติคอลสูงกว่าของดรอปเลเวลเดียวกัน"},
	{"id": "feather", "name": "ขนนก x2", "cost": 3, "kind": "jewel", "jewel": "feather", "count": 2, "desc": "ขนนกสำหรับตีปีก 100 ดาว"},
	{"id": "chaos", "name": "เพชรชาออส x3", "cost": 2, "kind": "jewel", "jewel": "chaos", "count": 3, "desc": "เพชรชาออสสำหรับตีบวก +10 ขึ้นไป"},
]
## The dungeon gear is this much better than a mythic field drop of its level.
const GEAR_EDGE := 1.35
const TRASH_POOL: Array[StringName] = [&"void_golem", &"rift_stalker", &"tentacle_horror", &"nova_drake"]


static func zone() -> Dictionary:
	return {
		"name": TITLE, "scene": "field", "level": [MIN_LEVEL, 100], "star": MIN_STARS, "music": &"guildwar", "theme": &"graveyard", "weather": &"",
		"ambience": &"hum", "tree_density": 0.0, "camps": [], "tower": true, "dungeon": true,
		"loot": {"gear": 0.0, "potion": 0.2, "gem": 0.04, "boss_items": 0},
		"sky": Color("0a1a14"), "ground": Color("2a3a2e"), "fog": Color("254a38"), "ambient": Color(0.6, 0.9, 0.75), "sun": Color(0.7, 1.0, 0.8),
		"path_color": Color("3a4a3c"), "seed": 73, "prev": &"town", "next": &"",
		"sky_palette": [Color("040a08"), Color("0e2a1c"), Color("2a6a44")], "sun_size": 0.0, "moon": true,
	}


# --- Who goes in --------------------------------------------------------------------

## Real online players of the hero's online party (the hero not counted).
static func online_members() -> int:
	if not Online.in_party():
		return 0
	var members: Array = Online.party().get("members", [])
	return maxi(0, members.size() - 1)


## The hero, the world players in the party and the real online party members.
static func party_size() -> int:
	return 1 + Game.world_party.size() + online_members()


## Entries left today (resets when the Thai day changes).
static func runs_left(today := "") -> int:
	if not Game.has_profile:
		return 0
	var day := today if today != "" else GoalsData.today()
	var flags: Dictionary = Game.profile.flags
	if String(flags.get(F_DAY, "")) != day:
		return RUNS_PER_DAY
	return clampi(RUNS_PER_DAY - int(flags.get(F_RUNS, 0)), 0, RUNS_PER_DAY)


static func runs_text(today := "") -> String:
	return "เหลือ %d/%d รอบวันนี้" % [runs_left(today), RUNS_PER_DAY]


## The week (GuildLeague.week_of, Monday 00:00 Thai) at t.
static func week_of(t := -1.0) -> int:
	return GuildLeague.week_of(t if t >= 0.0 else WorldPresence.clock())


## Whether this week's first clear (its extra scales) is still waiting.
static func first_of_week_ready(t := -1.0) -> bool:
	return Game.has_profile and int(Game.profile.flags.get(F_WEEK, -1)) != week_of(t)


## "" when the party may go in now, otherwise why not (Thai).
static func entry_block(today := "") -> String:
	if not Game.has_profile:
		return "ยังไม่มีตัวละคร"
	if int(Game.profile.level) < MIN_LEVEL or int(Game.paragon().level) < MIN_STARS:
		return "ต้องเลเวล %d ขึ้นไป (Lv.%d ★%d)" % [SHOWN_MIN_LEVEL, MIN_LEVEL, MIN_STARS]
	var n := party_size()
	if n != PARTY_SIZE:
		if n < PARTY_SIZE:
			return "ต้องมีปาร์ตี้ครบ %d คนพอดี (ตอนนี้ %d คน) ชวนผู้เล่นเข้าปาร์ตี้อีก %d คน" % [PARTY_SIZE, n, PARTY_SIZE - n]
		return "สุสานรับปาร์ตี้ %d คนพอดี (ตอนนี้ %d คน) ให้ใครออกก่อน %d คน" % [PARTY_SIZE, n, n - PARTY_SIZE]
	if runs_left(today) <= 0:
		return "วันนี้เข้าครบ %d รอบแล้ว พรุ่งนี้มาใหม่นะ" % RUNS_PER_DAY
	return ""


## Spends one of today's entries and opens a run (a clear of it pays once, claim).
## Returns "" or why not.
static func enter(today := "") -> String:
	var why := entry_block(today)
	if why != "":
		return why
	var day := today if today != "" else GoalsData.today()
	var flags: Dictionary = Game.profile.flags
	if String(flags.get(F_DAY, "")) != day:
		flags[F_DAY] = day
		flags[F_RUNS] = 0
	flags[F_RUNS] = int(flags.get(F_RUNS, 0)) + 1
	flags[F_OPEN] = "%s#%d" % [day, int(flags[F_RUNS])]
	Game.mark_dirty()
	Game.save()
	return ""


## The run in progress ("" when none is open, or it was paid).
static func open_run() -> String:
	return String(Game.profile.flags.get(F_OPEN, "")) if Game.has_profile else ""


## Invites online world players (Game.party_invite) until the party has PARTY_SIZE
## people: a Defender first if the party has none, then a Priest, then whoever is
## closest in level (Lv.100 players first). Returns how many joined.
static func recruit(t: float = -1.0) -> int:
	if not Game.has_profile:
		return 0
	var now := t if t >= 0.0 else WorldPresence.clock()
	var joined := 0
	for want in [&"defender", &"priest", &""]:
		if party_size() >= PARTY_SIZE or Game.world_party.size() >= Game.PARTY_MAX:
			break
		if want != &"" and has_class(want):
			continue
		# The closest in level first; one who says no (busy with its own party) is passed over.
		for pick in candidates(want, now):
			if party_size() >= PARTY_SIZE or Game.world_party.size() >= Game.PARTY_MAX:
				break
			if Game.party_invite(pick) == "":
				joined += 1
				if want != &"":
					break
	return joined


## Whether the hero or a party member is of `cls`.
static func has_class(cls: StringName) -> bool:
	if Game.has_profile and Game.class_id() == cls:
		return true
	for m in Game.party():
		if StringName(m.get("class", "")) == cls:
			return true
	return false


## Online world players of `cls` (any class for &"") not in the party, the closest in
## level to the hero first (Lv.100 ones ahead).
static func candidates(cls: StringName, now: float) -> Array[int]:
	var level := int(Game.profile.level)
	var list: Array = []
	for i in WorldPlayers.size():
		if Game.in_party(i):
			continue
		var s := WorldPlayers.state(i, now)
		if not bool(s.online):
			continue
		if cls != &"" and StringName(s["class"]) != cls:
			continue
		list.append([float(absi(int(s.level) - level)) - (0.5 if int(s.level) >= MIN_LEVEL else 0.0), i])
	list.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var out: Array[int] = []
	for entry in list:
		out.append(int(entry[1]))
	return out


# --- How strong ---------------------------------------------------------------------

## {hp, atk, def, level} of a dungeon monster of `role` ("trash", "crystal", "boss"):
## RaidData's scaling with this dungeon's time-to-kill.
static func monster_stats(power: Dictionary, role: String) -> Dictionary:
	var base := RaidData.monster_stats(power, "boss" if role == "boss" else "trash")
	var dps := HeroStats.mitigate(float(power.get("atk_sum", 10.0)) * RaidData.DPS_PER_ATK, float(base.def))
	match role:
		"boss":
			base["hp"] = maxi(50, int(round(dps * BOSS_TTK * BOSS_HP_MULT)))
		"crystal":
			base["hp"] = maxi(50, int(round(dps * CRYSTAL_TTK)))
			base["atk"] = 1
		_:
			base["hp"] = maxi(50, int(round(dps * TRASH_TTK)))
	return base


## The monsters of pack `pack_no` (1-based): ids from TRASH_POOL.
static func pack_plan(pack_no: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var out: Array[StringName] = []
	for i in PACK_SIZE[clampi(pack_no - 1, 0, PACK_SIZE.size() - 1)]:
		out.append(TRASH_POOL[rng.randi() % TRASH_POOL.size()])
	return out


# --- Rewards ------------------------------------------------------------------------

## The clear's rewards: {gold, exp, items: [item], first_week: bool, scales: int}.
static func rewards(level: int, stars: int, first_week: bool, rng: RandomNumberGenerator) -> Dictionary:
	var eff := float(level) + float(stars) * 0.45
	var gold := int(round((9000.0 + eff * eff * 6.0)))
	var exp_amount := int(round(float(HeroStats.star_need(clampi(stars, 0, Game.PARAGON_MAX - 1))) * 0.3))
	var scales := FIRST_WEEK_SCALES if first_week else rng.randi_range(SCALE_MIN, SCALE_MAX)
	var items: Array = [ItemData.jewel(SCALE, scales)]
	for id in {"purple": 4, "pink": 3, "chaos": 3}:
		items.append(ItemData.jewel(id, int({"purple": 4, "pink": 3, "chaos": 3}[id])))
	if first_week:
		items.append(ItemData.jewel("feather", 1))
	return {"gold": gold, "exp": maxi(1, exp_amount), "items": items, "first_week": first_week, "scales": scales}


## Pays the open run's clear once (gold, EXP, items into the bag or storage), records the
## best time and the fast-clear title flag, and returns what it paid ({} when nothing is
## open). `seconds` is the clear time.
static func claim(rng: RandomNumberGenerator, seconds: int, t := -1.0) -> Dictionary:
	if open_run() == "":
		return {}
	var flags: Dictionary = Game.profile.flags
	var week := week_of(t)
	var first_week := int(flags.get(F_WEEK, -1)) != week
	flags[F_OPEN] = ""
	flags[F_WEEK] = week
	var paid := rewards(int(Game.profile.level), int(Game.paragon().level), first_week, rng)
	Game.add_gold(int(paid.gold))
	Game.add_exp(int(paid.exp))
	for item in paid.items:
		Game.give_or_store(item)
	Game.flag_add(F_CLEARS)
	var best := int(flags.get(F_BEST, 0))
	if best <= 0 or seconds < best:
		flags[F_BEST] = seconds
	if seconds <= FAST_SECONDS:
		flags[F_FAST] = 1
	if Game.has_method("daily_progress"):
		Game.daily_progress("raid", 1)
	Game.mark_dirty()
	Game.save()
	return paid


## One line per reward (the result screen and the chat).
static func reward_lines(paid: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	if paid.is_empty():
		return out
	out.append("เหรียญ +%d · EXP +%d" % [int(paid.gold), int(paid.exp)])
	for item in paid.items:
		out.append("%s x%d" % [ItemData.name_of(item), int(item.get("count", 1))])
	return out


## "4:32" for a clear time.
static func time_text(seconds: int) -> String:
	return "%d:%02d" % [maxi(0, seconds) / 60, maxi(0, seconds) % 60]


# --- The keeper's exchange (SHOP) ---------------------------------------------------

## The hero's scales (เกล็ดมังกรโบราณ) in the bag.
static func scales() -> int:
	return Game.jewel_count(SCALE) if Game.has_profile else 0


static func shop_entry(id: String) -> Dictionary:
	for e in SHOP:
		if String(e.id) == id:
			return e
	return {}


## The item a SHOP entry gives (a fresh roll for gear).
static func shop_item(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var e := shop_entry(id)
	if e.is_empty():
		return {}
	if String(e.kind) == "jewel":
		return ItemData.jewel(String(e.jewel), int(e.count))
	return gear(id, rng)


## Dungeon-only gear anyone can wear: Lv.GEAR_LEVEL mythic (rarity 4) with the slot's
## stats and every bonus line at GEAR_EDGE above a field drop of the same level, three
## sockets, no class. "dungeon" names the piece (GEAR_KEY) so the shops and the bag can
## tell it.
static func gear(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var e := shop_entry(id)
	if e.is_empty() or String(e.kind) != "gear":
		return {}
	var slot := String(e.slot)
	var roll := 0.97 + rng.randf() * 0.06
	var stats := ItemData.tiered_stats(slot, GEAR_LEVEL, 4, 5.0, roll * GEAR_EDGE)
	if slot == "amulet":
		stats["atk"] = int(float(stats.get("atk", 0)) + ItemData.gear_power(GEAR_LEVEL) * 0.25 * GEAR_EDGE)
		stats["def"] = int(float(stats.get("def", 0)) + ItemData.gear_power(GEAR_LEVEL) * 0.25 * GEAR_EDGE)
	else:
		stats["crit"] = snappedf(float(stats.get("crit", 0.0)) + 0.02, 0.001)
		stats["hp"] = int(float(stats.get("hp", 0)) + GEAR_LEVEL * 3.0)
	return {"kind": "equip", "uid": ItemData.make_uid(), "slot": slot, "base": slot, "name": String(e.name), "rarity": 4,
		"level": GEAR_LEVEL, "class": "", "stats": stats, "price": 60000 if slot == "amulet" else 50000, "sockets": 3, "gems": [], "plus": 0,
		GEAR_KEY: String(ID)}


static func is_gear(item: Dictionary) -> bool:
	return item.get("kind", "") == "equip" and String(item.get(GEAR_KEY, "")) == String(ID)


## "" when the hero may buy SHOP entry `id` now, else why not.
static func buy_block(id: String) -> String:
	var e := shop_entry(id)
	if e.is_empty():
		return "ไม่มีของชิ้นนี้"
	if scales() < int(e.cost):
		return "เกล็ดมังกรโบราณไม่พอ (มี %d ต้องใช้ %d)" % [scales(), int(e.cost)]
	return ""


## Exchanges scales for SHOP entry `id` into the bag (or storage). Returns the item, or
## {} when it could not (buy_block).
static func buy(id: String, rng: RandomNumberGenerator) -> Dictionary:
	if buy_block(id) != "":
		return {}
	var e := shop_entry(id)
	var item := shop_item(id, rng)
	if item.is_empty():
		return {}
	Game._spend_jewels(SCALE, int(e.cost))
	Game.give_or_store(item)
	Game.flag_add(F_SHOP)
	Game.mark_dirty()
	Game.save()
	return item
