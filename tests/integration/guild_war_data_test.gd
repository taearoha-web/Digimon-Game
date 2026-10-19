extends Node
## Guild war rosters: 8 v 8 (hero + 7 allies against 8), every AI Lv.100 with 200 stars,
## gear from a 50-star set up to the divine class set, everyone in wings, both guilds
## about equally strong, no class stacked, a healer or summoner in every guild.
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
		var roll_ms := 0.0
		var n := GuildWarData.TEAM_SIZE
		check(n == 8, "a guild is eight strong")
		for i in rolls:
			var t0 := Time.get_ticks_usec()
			var m := GuildWarData.roll_match(rng)
			roll_ms += float(Time.get_ticks_usec() - t0) / 1000.0
			check(m.ally.size() == n - 1 and m.enemy.size() == n, "%d allies (+ the hero) against %d" % [n - 1, n])
			check(m.ally_name != m.enemy_name, "the guilds have different names")
			var names := {}
			for side in [m.ally, m.enemy]:
				var counts := {}
				var support: bool = side == m.ally and GuildWarData.is_support(Game.class_id())
				for f in side:
					support = support or GuildWarData.is_support(StringName(f.member["class"]))
					check(int(f.member.level) == 100 and int(f.profile.paragon.level) == 200, "every fighter is Lv.100 with 200 stars")
					var grade := int(f.grade)
					grades_seen[grade] = true
					var equip: Dictionary = f.profile.equip
					check(equip.has("weapon") and equip.has("armor") and equip.has("helm") and equip.has("boots"), "full gear")
					check(equip.has("wings") and StarWingData.is_wing(equip.wings) == (grade >= StarWingData.REQUIRED_STARS), "everyone wears wings: Lv.100 class wings below 100 stars, star wings from there (grade %d)" % grade)
					check(DivineGearData.is_item(equip.weapon) == (grade == GuildWarData.DIVINE), "divine set exactly at the top grade")
					if grade < GuildWarData.DIVINE:
						check(StarGearData.item_tier(equip.weapon) == grade, "weapon matches the grade")
					check(float(f.power) > 0.0, "has power")
					counts[f.member["class"]] = int(counts.get(f.member["class"], 0)) + 1
					check(not names.has(f.member.name), "names are unique")
					names[f.member.name] = true
				check(support, "every guild has a healer or a summoner (%s)" % ["ours" if side == m.ally else "theirs"])
				check(counts.size() >= 4, "eight fighters span at least four classes (%s)" % [counts.keys()])
				for id in counts:
					var total := int(counts[id]) + (1 if side == m.ally and id == String(Game.class_id()) else 0)
					check(total <= GuildWarData.MAX_SAME_CLASS, "no class more than %d times in a guild, the hero counted (%s x%d)" % [GuildWarData.MAX_SAME_CLASS, id, total])
			var gap := absf(float(m.ally_power) - float(m.enemy_power)) / float(m.enemy_power)
			worst_gap = maxf(worst_gap, gap)
			sum_gap += gap
		check(worst_gap < 0.12, "guilds are within 12%% of each other in power (worst %.1f%%)" % [worst_gap * 100.0])
		check(sum_gap / rolls < GuildWarData.BALANCE_TOLERANCE, "typical power gap under %d%% (%.1f%%)" % [int(GuildWarData.BALANCE_TOLERANCE * 100.0), sum_gap / rolls * 100.0])
		check(grades_seen.size() == GuildWarData.GRADES.size(), "every gear grade shows up (%s)" % [grades_seen.keys()])
		print("class %s: worst gap %.1f%% mean %.1f%%, hero power %.0f, roll %.0f ms" % [cls, worst_gap * 100.0, sum_gap / rolls * 100.0, GuildWarData.hero_power(), roll_ms / rolls])
	print("GUILD WAR DATA: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)
