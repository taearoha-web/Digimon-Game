extends Node
## Boss drop tables: slots, chase pieces, pity counter, save round trip.
var checks := 0
var failures := 0

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)

func _ready() -> void:
	Game.set_process(false)
	var bosses := [&"mush_king", &"fire_dragon", &"sand_dragon", &"yeti_king", &"magma_dragon", &"bone_lord",
		&"toad_king", &"storm_dragon", &"gold_dragon", &"abyss_dragon", &"void_emperor"]
	ZoneData.ensure()
	for zone_id in ZoneData.ZONES:
		var zone: Dictionary = ZoneData.ZONES[zone_id]
		if zone.has("boss") and MonsterData.MONSTERS.has(zone.boss.monster):
			check(BossLootData.has(zone.boss.monster), "field boss %s has a table" % zone.boss.monster)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for id in bosses:
		var table: Dictionary = BossLootData.TABLES[id]
		check(table.slots.size() >= 2 and table.slots.all(func(s): return ItemData.SLOTS.has(s)), "%s slots are valid" % id)
		check(ItemData.GEMS.has(table.gem), "%s favourite gem exists" % id)
		for chase in table.chase:
			var hard := int(chase.hard)
			# Chance never falls as misses pile up, and the hard pity is certain.
			var last := 0.0
			for misses in hard:
				var c := BossLootData.chance(chase, misses)
				check(c >= last and c <= 1.0, "%s/%s chance is monotone" % [id, chase.key])
				last = c
			check(BossLootData.chance(chase, hard - 1) == 1.0, "%s/%s hard pity guarantees" % [id, chase.key])
			check(BossLootData.chance(chase, 0) < 0.1, "%s/%s starts low" % [id, chase.key])
		# Farming: never more than `hard` kills between two chase pieces.
		var pity := {}
		var gap := 0
		var worst := 0
		var first: Dictionary = table.chase[0]
		var wins := 0
		for kill in 400:
			var won := BossLootData.roll_chases(id, pity, 50, &"warrior", rng)
			gap += 1
			var got := false
			for item in won:
				check(String(item.boss) == String(id) and table.slots.has(item.slot), "%s piece comes from its slots" % id)
				check(String(item.name).ends_with(table.epithet), "%s piece carries the epithet" % id)
				got = got or int(item.rarity) == int(first.rarity)
			if got:
				wins += 1
				worst = maxi(worst, gap)
				gap = 0
		check(wins > 0 and worst <= int(first.hard), "%s: at most %d kills between pieces (worst %d, %d wins)" % [id, first.hard, worst, wins])
		for key in pity:
			check(int(pity[key]) >= 0 and int(pity[key]) < 100, "%s counter %s stays in range" % [id, key])
	# Guaranteed pieces cycle through the boss's slots; gems prefer the favourite.
	check(BossLootData.slot_for(&"fire_dragon", 0) == "weapon" and BossLootData.slot_for(&"fire_dragon", 1) == "ring" and BossLootData.slot_for(&"fire_dragon", 2) == "weapon", "slots cycle")
	var fav := 0
	for i in 400:
		if BossLootData.gem_kind(&"fire_dragon", rng) == "ruby":
			fav += 1
	check(fav > 220 and fav < 340, "ruby is the favourite gem of the fire dragon (%d/400)" % fav)
	# Mythic chase exists only on the last three bosses.
	for id in bosses:
		var n: int = BossLootData.TABLES[id].chase.size()
		check(n == (2 if id in [&"gold_dragon", &"abyss_dragon", &"void_emperor"] else 1), "%s has %d chase pieces" % [id, n])
	# Save: new key on new profiles, tolerated when missing, repaired when odd, rejected when wrong.
	Game.new_profile(&"warrior", "pity")
	check(Game.profile.has("boss_pity") and Game.profile.boss_pity is Dictionary, "new profiles carry boss_pity")
	Game.boss_pity()["fire_dragon"] = 7
	Game.boss_pity()["gold_dragon:mythic"] = 12
	var code := Game.export_code()
	var preview := Game.preview_import(code)
	check(not preview.is_empty(), "profile with counters previews")
	var raw := JSON.parse_string(Marshalls.base64_to_utf8(code)) as Dictionary
	check(Game._valid_profile(raw), "profile with counters is valid")
	var repaired := Game._repair(raw.duplicate(true))
	check(int(repaired.boss_pity.fire_dragon) == 7 and int(repaired.boss_pity["gold_dragon:mythic"]) == 12, "counters survive a repair (floats from JSON become ints)")
	var old := raw.duplicate(true)
	old.erase("boss_pity")
	check(Game._valid_profile(old) and Game._repair(old).boss_pity == {}, "older saves without counters load with empty counters")
	var bad := raw.duplicate(true)
	bad["boss_pity"] = {"fire_dragon": "lots"}
	check(not Game._valid_profile(bad), "non-numeric counters are rejected")
	bad["boss_pity"] = [1]
	check(not Game._valid_profile(bad), "a list is not a counter table")
	var negative := raw.duplicate(true)
	negative["boss_pity"] = {"fire_dragon": -4}
	check(int(Game._repair(negative).boss_pity.fire_dragon) == 0, "negative counters are repaired to 0")
	# The tagged item passes the save validator.
	var piece := BossLootData.chase_item(&"fire_dragon", BossLootData.TABLES[&"fire_dragon"].chase[0], 50, &"warrior", rng)
	check(Game._valid_item(piece), "a chase piece is a valid save item")
	Game.has_profile = false
	print("BOSS LOOT: ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)
