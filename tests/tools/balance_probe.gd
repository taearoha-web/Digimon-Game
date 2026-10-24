extends Node
## Damage balance report across the whole game, using the real formulas:
## HeroStats.compute, MonsterData.stats_for, HeroStats.mitigate and the skill
## rank multiplier. For every class at checkpoints from Lv.10 to the 200-star
## Lotus Sanctum, a hero wearing gear fit for that point fights a field's
## normal monster and its boss.
##   godot --headless --path . res://tests/tools/balance_probe.tscn [-- check]
## With "check" it fails (exit code = failures) when a field leaves its band.
## Columns: basic = basic hits to kill a normal monster, skill% = the best
## skill hit (rank 5, no crit) as a share of a normal monster's HP,
## boss = best-skill hits to kill the boss, die_n / die_b = normal / boss hits
## to kill the hero.

const CHECKPOINTS := [
	# [label, hero level, stars, zone, gear: "lv" | star tier | "divine"]
	# The hero sits in the middle of each field's level range, wearing rare
	# (+5) gear of that level, or the previous region's star set.
	["meadow", 4, 0, &"meadow", "lv"],
	["dark_forest", 10, 0, &"dark_forest", "lv"],
	["desert", 18, 0, &"desert", "lv"],
	["snow", 26, 0, &"snow", "lv"],
	["volcano", 35, 0, &"volcano", "lv"],
	["graveyard", 46, 0, &"graveyard", "lv"],
	["swamp", 58, 0, &"swamp", "lv"],
	["storm", 70, 0, &"storm", "lv"],
	["sky", 82, 0, &"sky", "lv"],
	["abyss", 94, 0, &"abyss", "lv"],
	["void", 100, 0, &"void", "lv"],
	["dawn_forest", 100, 25, &"dawn_forest", "lv"],
	["crystal_valley", 100, 75, &"crystal_valley", 50],
	["sky_citadel", 100, 125, &"sky_citadel", 100],
	["eclipse_realm", 100, 175, &"eclipse_realm", 150],
	["lotus_sanctum", 100, 200, &"lotus_sanctum", 200],
	["lotus_divine", 100, 200, &"lotus_sanctum", "divine"],
]

var rng := RandomNumberGenerator.new()
var failures := 0
## Basic hits for a normal monster and strongest-skill hits for the boss, per
## field, that ZONE_TUNING aims at (checked within 30%).
const AIM := {
	"meadow": [3, 12], "dark_forest": [4, 15], "desert": [5, 18], "snow": [6, 20],
	"volcano": [7, 22], "graveyard": [8, 24], "swamp": [9, 26], "storm": [10, 28],
	"sky": [11, 30], "abyss": [12, 32], "void": [28, 80], "dawn_forest": [62, 150],
	"crystal_valley": [84, 195], "sky_citadel": [105, 245], "eclipse_realm": [120, 285],
	"lotus_sanctum": [175, 450],
}
## Fields from Lv.100 whose monsters carry x2..x5 health (MonsterData.LATE_HP):
## their aims above are the earlier ones times that, and a skill takes a smaller
## share of a monster's health.
const LATE := ["void", "dawn_forest", "crystal_valley", "sky_citadel", "eclipse_realm", "lotus_sanctum", "lotus_divine"]


func _ready() -> void:
	rng.seed = 4242
	Game.set_process(false)
	var rows: Array = []
	for cp in CHECKPOINTS:
		for cls in ClassData.IDS:
			rows.append(_measure(cls, cp))
	_print(rows)
	_arena()
	if "check" in OS.get_cmdline_user_args():
		print("BALANCE CHECK: %s | %d failures" % ["PASS" if failures == 0 else "FAIL", failures])
		get_tree().quit(failures)
	else:
		get_tree().quit()


func _hero(cls: StringName, level: int, stars: int, gear: Variant) -> Dictionary:
	Game.new_profile(cls, "Balance")
	var p := Game.profile
	p.level = level
	p.adv = JobData.adv_for_level(level)
	var main := String(JobData.resolve(cls, int(p.adv)).main)
	# A reasonable build: two thirds of the points into the main stat, the rest into VIT.
	var points := Game.STAT_POINTS_PER_LEVEL * (level - 1)
	p.attrs = {"str": 0, "int": 0, "dex": 0, "vit": 0}
	p.attrs[main] = int(points * 2 / 3)
	p.attrs["vit"] = points - int(points * 2 / 3)
	var para := Game.paragon()
	para.level = stars
	var spend := stars
	for key in ["atk", "hp", "def", "crit"]:
		var put := mini(spend / 2 if key == "atk" else spend, int(Game.PARAGON_STATS[key][2]))
		para.alloc[key] = put
		spend -= put
	p.equip = {}
	for slot in ItemData.SLOTS:
		var item: Dictionary
		if typeof(gear) == TYPE_STRING and gear == "divine":
			item = DivineGearData.item(cls, slot, rng) if DivineGearData.SLOTS.has(slot) else StarProgression.item(cls, 200, slot, rng)
		elif typeof(gear) == TYPE_INT:
			item = StarProgression.item(cls, int(gear), slot, rng)
		else:
			item = ItemData.generate(level, cls, rng, 2, slot)
		item.plus = 5
		p.equip[slot] = item
	return HeroStats.compute(p)


func _measure(cls: StringName, cp: Array) -> Dictionary:
	var level: int = cp[1]
	var stars: int = cp[2]
	var stats := _hero(cls, level, stars, cp[4])
	var zone := ZoneData.get_zone(cp[3])
	var normal := {"hp": 0.0, "def": 0.0, "atk": 0.0}
	for camp in zone.camps:
		var mob_level := int((int(camp.levels[0]) + int(camp.levels[1])) / 2)
		var one := MonsterData.stats_for(StringName(camp.monsters[0]), mob_level)
		for key in normal:
			normal[key] += float(one[key]) / float(zone.camps.size())
	var boss_id := StringName(zone.boss.monster)
	var boss := MonsterData.stats_for(boss_id, int(zone.boss.level))
	var best := 1.0
	var tier := ClassData.tier_of(cls, JobData.adv_for_level(level))
	for skill in ClassData.pool(cls):
		if int(skill.level) <= level and ClassData.skill_tier(skill) <= tier and int(skill.get("star", 0)) <= stars:
			best = maxf(best, float(skill.mult) * 1.6 * HeroStats.SKILL_POWER)
	var basic := HeroStats.mitigate(float(stats.atk), float(normal.def))
	var skill_hit := HeroStats.mitigate(float(stats.atk) * best, float(normal.def))
	var skill_boss := HeroStats.mitigate(float(stats.atk) * best, float(boss.def))
	var hurt_n := HeroStats.mitigate(float(normal.atk), float(stats.def))
	var hurt_b := HeroStats.mitigate(float(boss.atk) * 1.6, float(stats.def))
	return {"cp": cp[0], "cls": String(cls), "atk": int(stats.atk), "hp": int(stats.max_hp), "def": int(stats.def), "dodge": float(stats.dodge),
		"mob_hp": int(normal.hp), "boss_hp": int(boss.hp),
		"basic": float(normal.hp) / maxf(basic, 1.0), "skill_pct": 100.0 * skill_hit / float(normal.hp),
		"boss": float(boss.hp) / maxf(skill_boss, 1.0), "max_hit": int(skill_hit * HeroStats.CRIT_DAMAGE),
		"die_n": float(stats.max_hp) / maxf(hurt_n, 1.0), "die_b": float(stats.max_hp) / maxf(hurt_b, 1.0)}


func _print(rows: Array) -> void:
	# Per field: the median class, which tuning aims at.
	var by_zone := {}
	for r in rows:
		if not by_zone.has(r.cp): by_zone[r.cp] = []
		by_zone[r.cp].append(r)
	for cp in by_zone:
		var line := "ZONE %s" % cp
		for key in ["basic", "skill_pct", "boss", "die_n", "die_b", "max_hit"]:
			var values: Array = by_zone[cp].map(func(r): return float(r[key]))
			values.sort()
			var half := values.size() / 2
			var median: float = float(values[half]) if values.size() % 2 == 1 else (float(values[half - 1]) + float(values[half])) * 0.5
			line += " %s=%.2f" % [key, median]
			_band(cp, key, median)
		print(line)
	print("BALANCE checkpoint | class | atk | hp | def | dodge | mob_hp | basic | skill% | max_hit | boss | die_n | die_b")
	for r in rows:
		print("BALANCE %s | %s | %d | %d | %d | %.0f%% | %d | %.1f | %.0f%% | %d | %.1f | %.1f | %.1f" % [r.cp, r.cls, r.atk, r.hp, r.def, r.dodge * 100.0, r.mob_hp,
			r.basic, r.skill_pct, r.max_hit, r.boss, r.die_n, r.die_b])


## Bands every field must stay in: nothing one-shots, nothing takes forever,
## monsters stay a threat and no hit is absurd.
func _band(cp: String, key: String, value: float) -> void:
	var ok := true
	match key:
		"basic": ok = not AIM.has(cp) or absf(value / float(AIM[cp][0]) - 1.0) <= 0.3
		"boss": ok = not AIM.has(cp) or absf(value / float(AIM[cp][1]) - 1.0) <= 0.3
		"skill_pct": ok = cp == "meadow" or (value >= (8.0 if cp in LATE else 25.0) and value <= 100.0)
		"die_n": ok = value >= 10.0 and value <= 40.0
		"die_b": ok = value >= 3.0 and value <= 15.0
		"max_hit": ok = value <= 120000.0
	if not ok:
		failures += 1
		printerr("FAIL %s %s = %.2f is out of its band" % [cp, key, value])


## Arena / ranked duel: the AI is a Lv.100 / 200-star player on every rank (only its gear
## grade differs), so the probe pits that opponent against a mirror of itself (same class and
## grade) at the bottom, middle and top of the ladder. Both sides use their strongest skill and
## basic attacks under the war's damage scale: duels last, no side falls to a couple of casts.
func _arena() -> void:
	for rp in [0, PvpData.STEP_RP * PvpData.MAX_STEP / 2, PvpData.STEP_RP * PvpData.MAX_STEP]:
		var skill_hits := []
		var basic_hits := []
		for cls in ClassData.IDS:
			var info := PvpData.make_opponent(100, rp, rng, cls)
			var mine := GuildWarData.make_fighter(cls, int(info.grade), "mirror", rng)
			var me := HeroStats.compute(mine.profile)
			var base := HeroStats.compute(info.profile)
			var theirs := _best_skill(StringName(info.member["class"]), 100, 1.0)
			var scale := GuildWarData.damage_scale
			var per_hit := func(atk: float, mult: float, def: float, hp: float) -> float:
				return hp / maxf(minf(HeroStats.mitigate(atk * mult, def) * scale, hp * BurstGuard.HIT_CAP), 1.0)
			skill_hits.append(per_hit.call(float(me.atk), _best_skill(cls, 100, 1.0), float(base.def), float(base.max_hp)))
			basic_hits.append(per_hit.call(float(me.atk), 1.0, float(base.def), float(base.max_hp)))
			var _unused: float = theirs
		skill_hits.sort()
		basic_hits.sort()
		var med_skill: float = (float(skill_hits[2]) + float(skill_hits[3])) * 0.5
		var med_basic: float = (float(basic_hits[2]) + float(basic_hits[3])) * 0.5
		var line := "ARENA rp%d grade=%d basic=%.1f skill=%.1f hits to fall" % [rp, PvpData.grade_of(rp), med_basic, med_skill]
		print(line)
		# 5 hits is the floor (hit cap 20%); a duel should not drag past ~25 skill casts.
		if med_skill < 5.0 or med_skill > 25.0 or med_basic < 5.0 or med_basic > 150.0:
			failures += 1
			printerr("FAIL arena out of band: " + line)


## Strongest unlocked skill multiplier as dealt in combat (rank multiplier,
## SKILL_POWER), at least a basic attack.
func _best_skill(cls: StringName, level: int, rank: float) -> float:
	var best := 1.0
	var tier := ClassData.tier_of(cls, JobData.adv_for_level(level))
	for skill in ClassData.pool(cls):
		if int(skill.level) <= level and ClassData.skill_tier(skill) <= tier and not skill.has("star"):
			best = maxf(best, float(skill.mult) * rank * HeroStats.SKILL_POWER)
	return best
