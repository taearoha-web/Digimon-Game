class_name GuildWarData
extends RefCounted
## Guild war: two guilds fight for 30 minutes. Alpha against Neverdie (roll_guild_match)
## is fought by everyone in the two guilds (the world players who have reached Lv.100),
## each as it really is (level, stars and the gear it found), the hero with its real character.
## Hired line-ups (roll_match: eight a side when there is no guild, and the ranked arena's
## rivals) are AI at Lv.100 with 200 stars, a random class and a gear grade from a plain
## 50-star set up to the class's divine set with wings, built from the same star gear a
## real player can wear; the rival line-up is picked so both sides field about the same
## total power.

const TEAM_SIZE := 8
## The war between the world's two guilds: everyone at Lv.100 fights, up to GUILD_SIDE a
## side (the hero counted on ours).
const GUILD_SIDE := 25
const DURATION := 1800.0
## A fallen fighter comes back at its base this many seconds later.
const RESPAWN := 8.0
const LEVEL := 100
const STARS := 200
## How sharp the AI plays (0..1, see Rival): quick to react, a few human slips.
const SKILL := 0.9
## Same class at most this many times in one guild (the hero counts for ours).
const MAX_SAME_CLASS := 2
## Every guild fields at least one of these (a healer, a summoner or a bard) so eight fighters
## are a team with support, not eight duelists.
const SUPPORT_CLASSES: Array[StringName] = [&"priest", &"summoner", &"bard"]
## Everything hurts this many times more in a war. A 200-star fighter's defence cuts almost
## all damage (against monsters that is what keeps the game steady), so between two such
## fighters a fall would take minutes; this brings a fall to about 15-30 seconds.
static var damage_scale := 6.0
## Total power of the two guilds may differ by at most this share.
const BALANCE_TOLERANCE := 0.06

## Gear grades, weakest first: stars of the star set, or DIVINE for the class's divine
## set. Everyone wears wings: the class's Lv.100 wings on the 50-star grade, the
## star wings from 100 stars up (they unlock there).
const DIVINE := 300
const GRADES: Array[int] = [50, 100, 150, 200, DIVINE]
const GRADE_NAMES := {50: "ชุด 50★ + ปีก Lv.100", 100: "ชุด 100★ + ปีก", 150: "ชุด 150★ + ปีก", 200: "ชุด 200★ + ปีก", DIVINE: "ชุดประจำอาชีพ + ปีก"}

const GUILDS := ["อัศวินอรุณ", "เงาจันทรา", "มังกรเพลิง", "สายฟ้าฟ้าคราม", "ราชสีห์ทอง", "หมาป่าพายุ", "ผีเสื้อราตรี", "ดาบนภา"]


## One fighter ready for GuildFighter.setup_fighter.
static func make_fighter(class_id: StringName, grade: int, name: String, rng: RandomNumberGenerator) -> Dictionary:
	var gear_rng := RandomNumberGenerator.new()
	gear_rng.seed = rng.randi()
	var equip := {}
	for slot in ItemData.SLOTS:
		if grade == DIVINE and slot in DivineGearData.SLOTS:
			equip[slot] = DivineGearData.item(class_id, slot, gear_rng)
		else:
			equip[slot] = StarProgression.item(class_id, mini(grade, STARS), slot, gear_rng)
	if grade >= StarWingData.REQUIRED_STARS:
		equip["wings"] = StarWingData.item(String(class_id), gear_rng)
	else:
		equip["wings"] = ItemData.wings(gear_rng, String(class_id), 3)
	var data := JobData.resolve(class_id, JobData.adv_for_level(LEVEL))
	# A full Lv.100 character: every stat point spent, 60% on the main stat, 40% vitality.
	var points := Game.STAT_POINTS_PER_LEVEL * (LEVEL - 1)
	var attrs := {"str": 0, "int": 0, "dex": 0, "vit": 0}
	attrs[String(data.main)] = int(points * 0.6)
	attrs["vit"] = int(points * 0.4)
	var profile := {"class": String(class_id), "level": LEVEL, "attrs": attrs, "equip": equip, "adv": JobData.adv_for_level(LEVEL),
			"paragon": {"level": STARS, "alloc": Game.party_star_alloc(STARS)}}
	return {
		"member": {"class": String(class_id), "name": name, "level": LEVEL},
		"profile": profile,
		"mults": {"hp": 1.0, "atk": 1.0, "def": 1.0},
		"difficulty": SKILL,
		"look": FaceKit.random_look(rng),
		"grade": grade,
		"power": power_of(HeroStats.compute(profile)),
	}


## One number for "how strong": attack times staying power.
static func power_of(stats: Dictionary) -> float:
	return sqrt(float(stats.atk) * float(stats.max_hp) * (1.0 + float(stats.def) / 100.0))


static func hero_power() -> float:
	return power_of(Game.stats_now())


## The two guilds: { ally: [TEAM_SIZE - 1 fighters], enemy: [TEAM_SIZE fighters], ally_name, enemy_name, ally_power, enemy_power }.
## Classes and grades are random; the rival line-up is picked to match our guild's total power.
static func roll_match(rng: RandomNumberGenerator, power_of_hero: float = -1.0) -> Dictionary:
	if power_of_hero < 0.0:
		power_of_hero = hero_power()
	var hero_class := Game.class_id()
	var names := PvpData.NAMES.duplicate()
	var used := {}
	var take_name := func() -> String:
		for i in 40:
			var name: String = names[rng.randi() % names.size()]
			if not used.has(name):
				used[name] = true
				return name
		return "%s%d" % [names[0], used.size()]
	# One candidate per (class, grade): same gear is reused wherever it is picked.
	var pool := {}
	var classes: Array[StringName] = []
	for id in StarGearData.CLASSES:
		classes.append(StringName(id))
	for id in classes:
		for grade in GRADES:
			pool["%s|%d" % [id, grade]] = make_fighter(id, grade, "", rng)
	# Our seven allies are random; the rival guild is the best of many random line-ups at
	# matching hero + allies in total power, so a match is never lopsided before it starts.
	# Line-ups are weighed as pool keys and only the chosen one is copied into fighters.
	var best: Array = _materialize(rng, pool, _pick_keys(rng, classes, TEAM_SIZE - 1, [hero_class]))
	var ally_power := power_of_hero
	for f in best:
		ally_power += float(f.power)
	var enemy_keys: Array[String] = []
	var enemy_power := 0.0
	var best_gap := INF
	for attempt in 300:
		var keys := _pick_keys(rng, classes, TEAM_SIZE, [])
		var total := 0.0
		for key in keys:
			total += float(pool[key].power)
		var gap := absf(total - ally_power) / ally_power
		if gap < best_gap:
			best_gap = gap
			enemy_keys = keys
			enemy_power = total
		if gap < BALANCE_TOLERANCE * 0.4:
			break
	var enemy: Array = _materialize(rng, pool, enemy_keys)
	var all_fighters := enemy + best
	for f in all_fighters:
		f.member["name"] = take_name.call()
	var guild_a: String = GUILDS[rng.randi() % GUILDS.size()]
	var guild_b: String = GUILDS[rng.randi() % GUILDS.size()]
	while guild_b == guild_a:
		guild_b = GUILDS[rng.randi() % GUILDS.size()]
	return {"ally": best, "enemy": enemy, "ally_name": guild_a, "enemy_name": guild_b, "ally_power": ally_power, "enemy_power": enemy_power}


## The war between the two guilds of the world (WorldPlayers): the hero and its guild's
## members against the other guild's, up to GUILD_SIDE a side, each as it really is at time t
## (level, stars, stat points and the gear it found; WorldPlayers.fighter). Only players
## who reached Lv.100 are in a guild; online members go first, then the strongest.
## No rival member yet: {} (no war).
static func roll_guild_match(rng: RandomNumberGenerator, guild: int, t: float, power_of_hero: float = -1.0) -> Dictionary:
	if power_of_hero < 0.0:
		power_of_hero = hero_power()
	var ours: Array = []
	for i in WorldPlayers.members_at(guild, t):
		ours.append(WorldPlayers.fighter(i, t, rng))
	var theirs: Array = []
	for i in WorldPlayers.members_at(WorldPlayers.other_guild(guild), t):
		theirs.append(WorldPlayers.fighter(i, t, rng))
	if theirs.is_empty():
		return {}
	var order := func(a, b):
		if bool(a.online) != bool(b.online):
			return bool(a.online)
		return float(a.power) > float(b.power)
	theirs.sort_custom(order)
	# The hero's own party picks (GuildWarScreen) always come along.
	var picked := func(f) -> bool: return Game.guildwar_party_picks.has(String(f.member.name))
	ours.sort_custom(func(a, b):
		if picked.call(a) != picked.call(b):
			return picked.call(a)
		return order.call(a, b))
	# At most GUILD_SIDE a side (the hero counted on ours).
	ours.resize(mini(ours.size(), GUILD_SIDE - 1))
	theirs.resize(mini(theirs.size(), GUILD_SIDE))
	var ally_power := power_of_hero
	for f in ours:
		ally_power += float(f.power)
	var enemy_power := 0.0
	for f in theirs:
		enemy_power += float(f.power)
	return {"ally": ours, "enemy": theirs, "ally_name": WorldPlayers.guild_name(guild), "enemy_name": WorldPlayers.guild_name(WorldPlayers.other_guild(guild)),
		"ally_power": ally_power, "enemy_power": enemy_power, "guilds": true}


## Why the hero's guild cannot go to war at time t ("" when it can): the rival guild has
## nobody at Lv.100 yet.
static func guild_war_blocked(guild: int, t: float) -> String:
	var rival := WorldPlayers.other_guild(guild)
	if WorldPlayers.members_at(rival, t).is_empty():
		return "กิลด์ %s ยังไม่มีสมาชิกถึงเลเวล %d" % [WorldPlayers.guild_name(rival), Game.GUILD_LEVEL]
	return ""


## A line-up as pool keys ("class|grade"): random classes and grades, no class more than
## MAX_SAME_CLASS times (`already` holds classes that are on the team before the draw, the
## hero's for our guild) and at least one support class among the team and `already`.
static func _pick_keys(rng: RandomNumberGenerator, classes: Array[StringName], count: int, already: Array) -> Array[String]:
	var keys: Array[String] = []
	var counts := {}
	var has_support := false
	for id in already:
		counts[id] = int(counts.get(id, 0)) + 1
		has_support = has_support or StringName(id) in SUPPORT_CLASSES
	# One random slot is reserved for support unless the draw has brought some by then
	# (a support class with room is always there: none has been drawn yet).
	var support_at := rng.randi() % count
	for slot in count:
		var id: StringName
		while true:
			id = SUPPORT_CLASSES[rng.randi() % SUPPORT_CLASSES.size()] if slot == support_at and not has_support else classes[rng.randi() % classes.size()]
			if int(counts.get(id, 0)) < MAX_SAME_CLASS:
				break
		has_support = has_support or id in SUPPORT_CLASSES
		counts[id] = int(counts.get(id, 0)) + 1
		var grade: int = GRADES[rng.randi() % GRADES.size()]
		keys.append("%s|%d" % [id, grade])
	return keys


## Fighters for a line-up of pool keys: each a copy of the pool's candidate with its own face.
static func _materialize(rng: RandomNumberGenerator, pool: Dictionary, keys: Array[String]) -> Array:
	var team: Array = []
	for key in keys:
		var copy: Dictionary = (pool[key] as Dictionary).duplicate(true)
		copy["look"] = FaceKit.random_look(rng)
		team.append(copy)
	return team


static func is_support(class_id: StringName) -> bool:
	return class_id in SUPPORT_CLASSES


static func grade_label(grade: int) -> String:
	return String(GRADE_NAMES.get(grade, "ชุด %d★" % grade))


## Gold for a finished war: a flat sum, 1,000,000 for a win and 500,000 for a loss.
const GOLD_WIN := 1000000
const GOLD_LOSS := 500000
static func gold_reward(won: bool) -> int:
	return GOLD_WIN if won else GOLD_LOSS


## War rations: the hero starts every war with this many war potions (+5,000 HP each),
## topped up from the bag, and what is left is handed back when the war ends. Eight
## rivals focus the hero more often than five did, so the ration grew with the guilds.
const SUPPLY_POTION := "hp_war"
const SUPPLY_COUNT := 40


## EXP (stars at Lv.100) for a finished war.
static func exp_reward(level: int, won: bool) -> int:
	return int(HeroStats.exp_to_next(level) * (0.12 if won else 0.05))
