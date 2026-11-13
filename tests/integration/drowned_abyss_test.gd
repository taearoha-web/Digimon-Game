extends Node3D
## ห้วงสมุทรอสูร (DrownedAbyssData), the 200★-300★ levelling field: the 200★
## gate (and that it stays open at any higher star count), the travel chain
## and warp list, the all-new bestiary and its field boss, music, scenery,
## monster strength and EXP in the same band as the Lotus Sanctum
## (EndgameFields), and the drop table both fields share (purple 3%, pink 1%,
## chaos 3%, the set material 0.1%, Lotus Scales, divine pieces, 200★
## jewellery, gems, hp_god, wings, gold and the mount materials) checked
## statistically with seeded dice.
## godot --headless --path . res://tests/integration/drowned_abyss_test.tscn
var checks := 0
var failures := 0

const ID := DrownedAbyssData.ID


class RecordingZone:
	extends Zone
	var items: Array[Dictionary] = []
	var gold := 0
	var kills_with_gold := 0
	# Only the drop path is under test: no field is built.
	func _ready() -> void: pass
	func _spawn_loot(item: Dictionary, coins: int, _from: Vector3) -> void:
		if coins > 0:
			gold += coins
			kills_with_gold += 1
		if not item.is_empty():
			items.append(item)


class QuietMob:
	extends Mob
	func _ready() -> void: pass


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func near(value: float, want: float, tolerance: float) -> bool:
	return absf(value - want) <= tolerance


func _ready() -> void:
	Game.set_process(false)
	# Drop rates are checked at their base odds, not the festival's.
	WorldEvents.festival_enabled = false
	ZoneData.ensure()
	_gate_and_travel()
	_bestiary()
	_drop_rates()
	await _field_drops()
	_scenery()
	print("DROWNED ABYSS: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _gate_and_travel() -> void:
	var z := ZoneData.get_zone(ID)
	check(ZoneData.ZONES.has(ID) and String(z.name) == "ห้วงสมุทรอสูร", "the field exists with its Thai name")
	check(ZoneData.access_reason(ID, 100, 199) != "", "199 stars cannot enter")
	check(ZoneData.access_reason(ID, 99, 300) != "", "below Lv.100 cannot enter")
	for stars in [200, 250, 299, 300, 400]:
		check(ZoneData.access_reason(ID, 100, stars) == "", "%d stars enter" % stars)
	check(ZoneData.access_reason(ID, 100, 150).contains("200"), "the lock names the 200 stars it needs")
	var route := WarpScreen.destinations()
	check(route[-1] == ID and route[-2] == DivineRegionData.ID, "the warp list ends with the sanctuary then this field")
	check(StringName(ZoneData.get_zone(DivineRegionData.ID).next) == ID and StringName(z.prev) == DivineRegionData.ID, "travel chain: sanctuary <-> drowned abyss")
	check(String(z.next) == "", "the chain ends here")
	# The gate reads the hero's stars the way the game does (Game.paragon().level).
	Game.new_profile(&"warrior", "Abyss QA")
	Game.profile.level = 100
	Game.paragon()["level"] = 199
	check(not WarpScreen.unlocked(ID, 100), "the warp list keeps it locked at 199 stars")
	Game.paragon()["level"] = 200
	check(WarpScreen.unlocked(ID, 100), "the warp list opens it at 200 stars")
	Game.paragon()["level"] = 280
	check(WarpScreen.unlocked(ID, 100), "and keeps it open past the old cap")
	check(StringName(z.music) == ID and AudioManager.has_music(ID), "its own music track")
	check(int(z.star) == DrownedAbyssData.ENTRY_STAR and int(z.boss.star) == 200, "entry and boss at 200 stars")


func _bestiary() -> void:
	var z := ZoneData.get_zone(ID)
	var seen := {}
	for camp in z.camps:
		for m in camp.monsters:
			seen[m] = true
			check(DrownedAbyssData.has_monster(m), "camp monster %s belongs to the field" % m)
		check(int(camp.levels[0]) >= 180 and int(camp.levels[1]) <= 200, "camp %s is Lv.180-200" % camp.name)
	check(z.camps.size() == 6, "six farm camps")
	check(DrownedAbyssData.NORMALS.size() >= 5 and DrownedAbyssData.ELITES.size() >= 2, "five kinds and two elites")
	var names := {}
	for id in DrownedAbyssData.MONSTERS:
		var data := MonsterData.get_monster(id)
		var raw: Dictionary = DrownedAbyssData.MONSTERS[id]
		check(not MonsterData.MONSTERS.has(id) and not StarMonsters.has(id) and not DivineRegionData.has_monster(id), "%s is a new monster" % id)
		check(data.name == raw.name and not names.has(raw.name), "%s dispatch and its own name" % id)
		names[raw.name] = true
		check(ResourceLoader.exists("res://assets/models/monsters/%s.glb" % data.model) or ResourceLoader.exists("res://assets/models/monsters/%s.gltf" % data.model), "%s model exists" % id)
		check(raw.has("aura") and raw.has("tint") and raw.has("color"), "%s is re-dressed (aura, tint, colour)" % id)
		check(is_equal_approx(float(data.hp), float(raw.hp) * 10.0), "%s ten times health" % id)
		check(seen.has(id) or id == DrownedAbyssData.BOSS, "%s lives in a camp" % id)
		check(MonsterData.home_zone(id) == ID, "%s is tuned as this field's" % id)
		if not bool(raw.get("boss", false)):
			check(MobAttack.knows(data), "%s has a MobAttack move" % id)
	# The field boss.
	var boss: Dictionary = z.boss
	check(StringName(boss.monster) == DrownedAbyssData.BOSS and bool(MonsterData.get_monster(boss.monster).get("boss", false)), "the tyrant is the field boss")
	check(BossAttack.has_moves(MonsterData.get_monster(boss.monster)), "the boss has signature moves")
	check(int(boss.level) > 200, "the boss outranks the camps")
	# The same band as the sanctuary (EndgameFields), EXP fit for 200★ -> 300★.
	var ours := MonsterData.stats_for(&"abyss_angler", 188)
	var lotus := MonsterData.stats_for(&"lotus_sprite", 188)
	check(ours == lotus, "a sanctuary sprite and an abyss angler of one level are equals (%s / %s)" % [ours, lotus])
	var tyrant := MonsterData.stats_for(DrownedAbyssData.BOSS, int(boss.level))
	var lotus_zone := ZoneData.get_zone(DivineRegionData.ID)
	var seraph := MonsterData.stats_for(&"lotus_seraph", int(lotus_zone.boss.level))
	check(tyrant.hp == seraph.hp and tyrant.atk == seraph.atk and tyrant.def == seraph.def and tyrant.exp == seraph.exp, "the tyrant and the sanctuary's boss are equals")
	_same_band(z, lotus_zone)
	var boost := 1.0 + float(z.gear_star) / 25.0
	for stars in [200, 250, 299]:
		var kills := float(HeroStats.star_need(stars)) / (float(ours.exp) * boost)
		check(kills > 6.0 and kills < 30.0, "a star at %d takes %.1f kills" % [stars, kills])
	var lotus_kills := float(HeroStats.star_need(200)) / (float(lotus.exp) * (1.0 + float(lotus_zone.gear_star) / 25.0))
	check(is_equal_approx(float(HeroStats.star_need(200)) / (float(ours.exp) * boost), lotus_kills), "it levels as fast as the sanctuary")


## Both ★200-300 fields: one gate, one level band, one tuning, and every role's
## monster multipliers (hp, atk, def, exp, gold) within the same range.
func _same_band(z: Dictionary, lotus: Dictionary) -> void:
	for key in ["star", "gear_star", "jewel_drop", "set_core_drop", "endgame_loot", "divine_region"]:
		check(z.get(key) == lotus.get(key), "%s is the same in both fields (%s / %s)" % [key, z.get(key), lotus.get(key)])
	check(int(z.star) == 200 and int(lotus.star) == 200 and int(z.boss.star) == 200 and int(lotus.boss.star) == 200, "entry at 200 stars in both")
	check(ZoneData.access_reason(ID, 100, 199) != "" and ZoneData.access_reason(DivineRegionData.ID, 100, 199) != "", "199 stars enter neither")
	check(ZoneData.access_reason(ID, 100, 200) == "" and ZoneData.access_reason(DivineRegionData.ID, 100, 200) == "", "200 stars enter both")
	check(MonsterData.ZONE_TUNING[ID] == MonsterData.ZONE_TUNING[DivineRegionData.ID] and MonsterData.LATE_HP[ID] == MonsterData.LATE_HP[DivineRegionData.ID], "one field tuning")
	check(int(z.boss.level) == int(lotus.boss.level) and is_equal_approx(float(z.boss.respawn), float(lotus.boss.respawn)), "bosses of one level and respawn")
	var levels := func(zone: Dictionary) -> Array:
		var lo := 999
		var hi := 0
		var sum := 0.0
		for camp in zone.camps:
			lo = mini(lo, int(camp.levels[0]))
			hi = maxi(hi, int(camp.levels[1]))
			sum += (float(camp.levels[0]) + float(camp.levels[1])) * 0.5
		return [lo, hi, sum / float(zone.camps.size())]
	var a: Array = levels.call(z)
	var b: Array = levels.call(lotus)
	check(a[0] == b[0] and a[1] == b[1] and a[0] == 180 and a[1] == 200 and absf(float(a[2]) - float(b[2])) < 2.0, "camps span Lv.180-200 in both (%s / %s)" % [a, b])
	var roles := func(table: Dictionary) -> Dictionary:
		var out := {}
		for id in table:
			var m: Dictionary = table[id]
			var role := "boss" if m.get("boss", false) else ("elite" if m.get("elite", false) else "normal")
			if not out.has(role): out[role] = {}
			for key in ["hp", "atk", "def", "exp", "gold"]:
				if not out[role].has(key): out[role][key] = []
				out[role][key].append(float(m.get(key, 1.0)))
		return out
	var deep: Dictionary = roles.call(DrownedAbyssData.MONSTERS)
	var holy: Dictionary = roles.call(DivineRegionData.MONSTERS)
	for role in ["normal", "elite", "boss"]:
		for key in ["hp", "atk", "def", "exp", "gold"]:
			var d: Array = deep[role][key]
			var h: Array = holy[role][key]
			var mean := func(v: Array) -> float: return v.reduce(func(acc, x): return acc + x, 0.0) / float(v.size())
			check(h.min() >= d.min() - 0.001 and h.max() <= d.max() + 0.001 and absf(mean.call(h) / mean.call(d) - 1.0) < 0.05, "%s %s in the same band (%s / %s)" % [role, key, h, d])


func _drop_rates() -> void:
	var z := ZoneData.get_zone(ID)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261102
	var n := 200000
	var counts := {}
	for i in n:
		for item in Zone.jewel_drops(z, 0.0, 1.0, rng):
			counts[item.id] = int(counts.get(item.id, 0)) + 1
	var rate := func(id: String) -> float: return float(counts.get(id, 0)) / float(n)
	check(near(rate.call("purple"), 0.03, 0.0025), "purple 3%% (%.4f)" % rate.call("purple"))
	check(near(rate.call("pink"), 0.01, 0.0012), "pink 1%% (%.4f)" % rate.call("pink"))
	check(near(rate.call("chaos"), 0.03, 0.0025), "chaos 3%% (%.4f)" % rate.call("chaos"))
	# The set material's own roll: 0.1% a kill, here only.
	var cores := 0
	rng.seed = 7
	for i in 400000:
		if Zone.set_core_roll(z, 0.0, rng):
			cores += 1
	check(cores > 320 and cores < 480, "set material 0.1%% (%d / 400000)" % cores)
	var lucky := 0
	rng.seed = 7
	for i in 400000:
		if Zone.set_core_roll(z, 1.0, rng):
			lucky += 1
	check(lucky > cores * 1.7, "fortune raises the set material's chance (%d vs %d)" % [lucky, cores])
	if ItemData.JEWELS.has(DrownedAbyssData.SET_CORE):
		check(int(counts.get(DrownedAbyssData.SET_CORE, 0)) > 120 and int(counts.get(DrownedAbyssData.SET_CORE, 0)) < 290, "jewel_drops hands out the set material (%d / 200000)" % int(counts.get(DrownedAbyssData.SET_CORE, 0)))
	else:
		check(not counts.has(DrownedAbyssData.SET_CORE), "no set material item before ItemData knows it")
	# Other fields: their own rates, no set material and no extra roll.
	var meadow := ZoneData.get_zone(&"meadow")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	var meadow_purple := 0
	for i in 50000:
		for item in Zone.jewel_drops(meadow, 0.0, 1.0, a):
			check(String(item.id) != DrownedAbyssData.SET_CORE, "no set material in the meadow")
			if item.id == "purple": meadow_purple += 1
		for id in ItemData.JEWEL_DROP: b.randf()
	check(a.state == b.state, "other fields draw exactly the dice they always did")
	check(near(float(meadow_purple) / 50000.0, ItemData.JEWEL_DROP.purple, 0.002), "the meadow keeps its 1% purple")
	check(not Zone.set_core_roll(meadow, 0.0, a), "set material never rolls elsewhere")
	# Weekend rush doubles the jewels, not the set material.
	rng.seed = 5
	var rush_purple := 0
	for i in 100000:
		for item in Zone.jewel_drops(z, 0.0, 2.0, rng):
			if item.id == "purple": rush_purple += 1
	check(near(float(rush_purple) / 100000.0, 0.06, 0.004), "the weekend rush doubles the purple (%.4f)" % (float(rush_purple) / 100000.0))
	# Gems and the 20,000 HP potion.
	rng.seed = 11
	var gems := 0
	var gods := 0
	for i in 40000:
		for item in DrownedAbyssData.kill_drops(false, false, 0.0, rng):
			if item.kind == "gem": gems += 1
			if item.kind == "potion" and item.id == "hp_god": gods += 1
	check(near(gems / 40000.0, DrownedAbyssData.GEM_NORMAL, 0.008), "gem ~10%% (%.4f)" % (gems / 40000.0))
	check(near(gods / 40000.0, DrownedAbyssData.POTION_NORMAL, 0.008), "hp_god ~8%% (%.4f)" % (gods / 40000.0))
	var boss_loot := DrownedAbyssData.kill_drops(true, false, 0.0, rng)
	check(boss_loot.filter(func(it): return it.kind == "gem").size() == DrownedAbyssData.GEM_BOSS, "the boss drops four gems")
	check(boss_loot.any(func(it): return it.kind == "potion" and it.id == "hp_god" and int(it.count) == DrownedAbyssData.POTION_BOSS), "the boss drops five hp_god")
	check(ItemData.POTIONS.hp_god.hp == 20000, "hp_god is the 20,000 HP potion")


## The real kill path (Zone._drop_loot -> _drop_jewels, mount_mat_drops, kill_drops).
func _field_drops() -> void:
	Game.new_profile(&"mage", "Abyss loot QA")
	Game.profile.level = 100
	Game.paragon()["level"] = 220
	var zone := RecordingZone.new()
	zone.zone_id = ID
	zone.data = ZoneData.get_zone(ID)
	zone.rng.seed = 4242
	zone._event_rng.seed = 4243
	add_child(zone)
	zone.set_process(false)
	var mob := QuietMob.new()
	mob.setup(&"reef_crab", 188, Vector3.ZERO, null)
	zone.add_child(mob)
	mob.set_physics_process(false)
	var kills := 20000
	for i in kills:
		zone._drop_loot(mob)
	var count := func(kind: String, id: String) -> int:
		var total := 0
		for it in zone.items:
			if it.get("kind", "") == kind and String(it.get("id", "")).begins_with(id):
				total += int(it.get("count", 1))
		return total
	var rush := WorldEvents.jewel_multiplier(WorldPresence.clock())
	check(zone.kills_with_gold == kills and zone.gold > kills * 1000, "every kill drops gold (%d)" % zone.gold)
	check(near(count.call("jewel", "purple") / float(kills), 0.03 * rush, 0.006 * rush), "field purple ~3%% (%d)" % count.call("jewel", "purple"))
	check(near(count.call("jewel", "pink") / float(kills), 0.01 * rush, 0.003 * rush), "field pink ~1%% (%d)" % count.call("jewel", "pink"))
	check(near(count.call("jewel", "chaos") / float(kills), 0.03 * rush, 0.006 * rush), "field chaos ~3%% (%d)" % count.call("jewel", "chaos"))
	check(count.call("gem", "") > kills * 0.08, "gems drop (%d)" % count.call("gem", ""))
	check(count.call("potion", "hp_god") > kills * 0.05, "hp_god drops (%d)" % count.call("potion", "hp_god"))
	for mount in MountData.ORDER:
		var mat := MountData.mat_of(mount)
		var want := float(MountData.info(mount).drop)
		var got: float = count.call("jewel", mat) / float(kills)
		check(near(got, want, maxf(want * 0.45, 0.0006)), "mount material %s at its usual %.2f%% (%.4f)" % [mat, want * 100.0, got])
	# The sanctuary's half of the shared table: divine pieces, 200★ jewellery, scales.
	check(zone.items.any(func(it): return DivineGearData.is_item(it)), "divine pieces drop here too")
	check(zone.items.any(func(it): return int(it.get("star_tier", 0)) == 200 and String(it.get("slot", "")) in ["ring", "amulet"]), "200★ rings and amulets drop here too")
	check(near(count.call("jewel", EndgameFields.SCALE) / float(kills), EndgameFields.SCALE_NORMAL, 0.002), "Lotus Scales ~0.5%% (%d)" % count.call("jewel", EndgameFields.SCALE))
	zone.free()


func _scenery() -> void:
	var layout := DrownedAbyssArt.layout()
	check(layout.camp_positions.size() == ZoneData.get_zone(ID).camps.size(), "a spot for every camp")
	for p in layout.camp_positions:
		check((p as Vector2).length() < 50.0, "camp inside the walkable disc")
	var holder := Node3D.new()
	add_child(holder)
	DrownedAbyssArt.build(holder)
	var art := holder.get_child(0)
	check(art != null and art.get_meta("zone_id", &"") == ID and art.get_child_count() > 5, "the scenery builds")
	check(art.find_children("*", "Light3D", true, false).is_empty(), "no dynamic lights in the scenery")
	holder.free()
	# The monsters wear their aura.
	var visual := Node3D.new()
	add_child(visual)
	DeepMonsterArt.attach(visual, DrownedAbyssData.monster(DrownedAbyssData.BOSS))
	check(visual.get_node_or_null("DeepAura") != null and visual.get_node("DeepAura").get_child_count() >= 7, "Poseidon wears the abyss aura")
	check(visual.get_child_count() > 1, "and his summon's own aura, no coral crown over his head")
	visual.free()
