extends Node
## Guild war rosters: 5 v 5 (hero + 4 allies against 5), every AI Lv.100 with 200 stars,
## gear from a 50-star set up to the divine class set, wings from 100 stars, both guilds
## about equally strong, no class stacked.
## godot --headless --path . res://tests/integration/guild_war_data_test.tscn
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	for cls in [&"warrior", &"mage"]:
		Game.new_profile(cls, "GW")
		Game.profile.level = 100
		Game.profile.adv = 4
		Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + hash(cls)
		var grades_seen := {}
		var worst_gap := 0.0
		var sum_gap := 0.0
		var rolls := 12
		for i in rolls:
			var m := GuildWarData.roll_match(rng)
			check(m.ally.size() == 4 and m.enemy.size() == 5, "4 allies (+ the hero) against 5")
			check(m.ally_name != m.enemy_name, "the guilds have different names")
			var names := {}
			for side in [m.ally, m.enemy]:
				var counts := {}
				for f in side:
					check(int(f.member.level) == 100 and int(f.profile.paragon.level) == 200, "every fighter is Lv.100 with 200 stars")
					var grade := int(f.grade)
					grades_seen[grade] = true
					var equip: Dictionary = f.profile.equip
					check(equip.has("weapon") and equip.has("armor") and equip.has("helm") and equip.has("boots"), "full gear")
					check(equip.has("wings") == (grade >= 100), "wings exactly from the 100-star grade up (grade %d)" % grade)
					check(DivineGearData.is_item(equip.weapon) == (grade == GuildWarData.DIVINE), "divine set exactly at the top grade")
					if grade < GuildWarData.DIVINE:
						check(StarGearData.item_tier(equip.weapon) == grade, "weapon matches the grade")
					check(float(f.power) > 0.0, "has power")
					counts[f.member["class"]] = int(counts.get(f.member["class"], 0)) + 1
					check(not names.has(f.member.name), "names are unique")
					names[f.member.name] = true
				for id in counts:
					check(int(counts[id]) <= GuildWarData.MAX_SAME_CLASS + (1 if side == m.ally and id == String(Game.class_id()) else 0), "no class stacked (%s)" % id)
			var gap := absf(float(m.ally_power) - float(m.enemy_power)) / float(m.enemy_power)
			worst_gap = maxf(worst_gap, gap)
			sum_gap += gap
		check(worst_gap < 0.12, "guilds are within 12%% of each other in power (worst %.1f%%)" % [worst_gap * 100.0])
		check(sum_gap / rolls < GuildWarData.BALANCE_TOLERANCE, "typical power gap under %d%% (%.1f%%)" % [int(GuildWarData.BALANCE_TOLERANCE * 100.0), sum_gap / rolls * 100.0])
		check(grades_seen.size() == GuildWarData.GRADES.size(), "every gear grade shows up (%s)" % [grades_seen.keys()])
		print("class %s: worst gap %.1f%% mean %.1f%%, hero power %.0f" % [cls, worst_gap * 100.0, sum_gap / rolls * 100.0, GuildWarData.hero_power()])
	print("GUILD WAR DATA: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)
