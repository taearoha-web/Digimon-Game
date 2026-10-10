extends SceneTree
## Damage audit: hits-to-kill for every class at Lv.20-100 with three gear
## profiles, plus how much each damage source adds at Lv.100.
##   godot --headless --path . -s res://tools/damage_audit.gd
## fresh   = common gear of the level, no plus, skills 1 star
## farmed  = rare gear +5 with medium rubies, skills 3 stars, passives 3 stars
## maxed   = mythic gear (Lv.120 at 100) +10 with big rubies, wings, full set,
##           paragon ATK maxed, skills / passives 5 stars


func _init() -> void:
	var game: Node = root.get_node_or_null("/root/Game")
	print("class  Lv  gear    | ATK    | mob HP   | basic hits | best skill hits | AoE skill hits | all buffs ATK x")
	for c in ClassData.IDS:
		for level in [20, 40, 60, 80, 100]:
			for gear in ["fresh", "farmed", "maxed"]:
				var p := _profile(c, level, gear)
				var stats := HeroStats.compute(p)
				var buffs := _all_buffs(c, level, p)
				var buffed := HeroStats.compute(p, {"atk": buffs})
				var mon := _zone_monster(level)
				var mitig := 100.0 / (100.0 + float(mon.def))
				var crit := 1.0 + float(stats.crit) * (HeroStats.CRIT_DAMAGE - 1.0)
				var basic := float(stats.atk) * mitig * crit
				var best := _best(c, level, p, false)
				var aoe := _best(c, level, p, true)
				print("%-7s %3d %-7s | %6.0f | %8.0f | %10.1f | %15.2f | %14.2f | %.2f" % [String(c).left(7), level, gear,
					float(stats.atk), float(mon.hp), float(mon.hp) / maxf(basic, 1.0),
					float(mon.hp) / maxf(basic * best, 1.0), float(mon.hp) / maxf(basic * aoe, 1.0), float(buffed.atk) / float(stats.atk)])
	quit()


func _zone_monster(level: int) -> Dictionary:
	var zone := &"meadow"
	for id in [&"abyss", &"sky", &"storm", &"swamp", &"graveyard", &"volcano", &"snow", &"desert", &"dark_forest", &"meadow"]:
		if level >= int(ZoneData.get_zone(id).level[0]):
			zone = id
			break
	var info := ZoneData.get_zone(zone)
	var hp := 0.0
	var def := 0.0
	var n := 0
	for camp in info.camps:
		for m in camp.monsters:
			var s := MonsterData.stats_for(m, clampi(level, int(info.level[0]), int(info.level[1])))
			hp += float(s.hp)
			def += float(s.def)
			n += 1
	return {"hp": hp / n, "def": def / n}


func _profile(c: StringName, level: int, gear: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var data := ClassData.get_class_data(c)
	var points := (level - 1) * 3
	var attrs := {"str": 0, "int": 0, "dex": 0, "vit": 0}
	attrs[data.main] = int(points * 0.65)
	attrs["vit"] = int(points * 0.35)
	var rarity := {"fresh": 0, "farmed": 2, "maxed": 4}[gear] as int
	var plus := {"fresh": 0, "farmed": 5, "maxed": 10}[gear] as int
	var gem := {"fresh": "", "farmed": "ruby_1", "maxed": "ruby_2"}[gear] as String
	var gear_level := level + (20 if gear == "maxed" and level == 100 else 0)
	var equip := {}
	for slot in ItemData.SLOTS:
		var item := ItemData.generate(gear_level, c, rng, rarity, slot)
		item["plus"] = plus if not (slot in EnhanceFx.FIXED_SLOTS) else 0
		if gem != "":
			var g: Array = []
			for i in int(item.sockets):
				g.append(gem)
			item["gems"] = g
		equip[slot] = item
	if gear == "maxed" and level == 100:
		equip["wings"] = ItemData.wings(rng, "atk" if String(data.main) != "int" else "matk")
		equip["wings"]["plus"] = 10
	var stars := {"fresh": 1, "farmed": 3, "maxed": 5}[gear] as int
	var skills := {}
	for skill in ClassData.pool(c):
		skills[skill.id] = stars
	for passive in ClassData.PASSIVES.get(c, []):
		skills[passive.id] = stars
	var paragon := {"level": 0, "alloc": {}}
	if gear == "maxed" and level == 100:
		paragon = {"level": 200, "alloc": {"atk": 60, "crit": 50}}
	return {"class": String(c), "level": level, "attrs": attrs, "equip": equip, "adv": JobData.adv_for_level(level),
		"skills": skills, "paragon": paragon}


## Every self attack buff the class owns at this level, stacked the way the game does.
func _all_buffs(c: StringName, level: int, p: Dictionary) -> float:
	var values: Array = []
	for skill in ClassData.pool(c):
		if int(skill.level) <= level and skill.get("fx", {}).has("buff"):
			values.append(float(skill.fx.buff.get("atk", 0.0)))
	return BuffBook.stack(values)


## Damage multiplier of the strongest single-target (or area) skill usable at the level,
## with its star bonus (+15% per star above 1).
func _best(c: StringName, level: int, p: Dictionary, area: bool) -> float:
	var best := 1.0
	for skill in ClassData.pool(c):
		if int(skill.level) > level or float(skill.get("mult", 0.0)) <= 0.0:
			continue
		var is_area := String(skill.shape) in ["burst", "blast", "fan", "chain"]
		if is_area != area:
			continue
		var rank := int(p.skills.get(skill.id, 1))
		best = maxf(best, float(skill.mult) * (1.0 + 0.15 * float(rank - 1)))
	return best
