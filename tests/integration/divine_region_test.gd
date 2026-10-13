extends Node3D
var checks := 0
var failures := 0

class RecordingZone:
	extends Zone
	var items: Array[Dictionary] = []
	func _ready() -> void: pass
	func _spawn_loot(item: Dictionary, _gold: int, _from: Vector3) -> void:
		if item.get("kind", "") == "equip": items.append(item)

class QuietMob:
	extends Mob
	func _ready() -> void: pass

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ", note)

func profile(cls: StringName) -> void:
	Game.new_profile(cls, "Divine collection QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.paragon = {"level":200,"exp":0,"points":200,"spent":0,"alloc":{}}
	Game.profile.inv = []
	Game.profile.equip = {}

func _ready() -> void:
	Game.set_process(false)
	ZoneData.ensure()
	check(ZoneData.access_reason(DivineRegionData.ID, 100, 199) != "", "199 stars cannot enter")
	check(ZoneData.access_reason(DivineRegionData.ID, 99, 200) != "", "level 99 cannot enter")
	check(ZoneData.access_reason(DivineRegionData.ID, 100, 200) == "", "200 stars enter")
	var route := WarpScreen.destinations()
	check(route[-1] == DivineRegionData.ID and route[-2] == &"eclipse_realm", "warp chain includes post-story sanctuary")
	check(StarProgression.REGIONS.size() == 4, "four milestone regions retained")
	check(StarWingData.drop_chance(DivineRegionData.ID, true, false) == 0, "new map adds no wing tiers or wing drops")
	var new_zone := ZoneData.get_zone(DivineRegionData.ID)
	check(new_zone.camps.size() == 5 and new_zone.boss.monster == &"lotus_seraph", "five farm camps and boss definitions")
	for camp in new_zone.camps:
		check(int(camp.count) == 10, "ten monsters per farm camp")
	for id in DivineRegionData.MONSTERS:
		var data := MonsterData.get_monster(id)
		check(data.name == DivineRegionData.MONSTERS[id].name, "monster dispatch " + String(id))
		check(ResourceLoader.exists("res://assets/models/monsters/%s.glb" % data.model) or ResourceLoader.exists("res://assets/models/monsters/%s.gltf" % data.model), "monster model " + String(id))
		check(is_equal_approx(float(data.hp), float(DivineRegionData.MONSTERS[id].hp) * 10.0), "ten times health " + String(id))
		var stats := MonsterData.stats_for(id, 160)
		check(stats.hp > 0 and stats.atk > 0 and stats.def > 0, "valid battle stats")
	var rng := RandomNumberGenerator.new()
	rng.seed = 93617
	var looks := {}
	for cls in ClassData.IDS:
		profile(cls)
		for slot in DivineGearData.SLOTS:
			var item := DivineGearData.item(cls, slot, rng)
			check(Game._valid_item(item), "valid uploaded collection item")
			check(item.level == 300 and item.star_tier == 200 and item.rarity == 4, "correct gate and mythic grade")
			check(item["class"] == String(cls), "own class equipment")
			check(ItemLook.look_of(item).begins_with("divine_"), "uploaded visual dispatch")
			check(ItemLook.icon(item) != null, "unique model icon")
			looks[ItemLook.look_of(item)] = true
			check(ItemData.set_label(item.set) == DivineGearData.set_label(String(cls)), "named set detail")
			check(Game.equip_problem(item).is_empty(), "200-star item equippable")
			Game.paragon().level = 199
			check(not Game.equip_problem(item).is_empty(), "199-star gear locked")
			Game.paragon().level = 200
			Game.profile["class"] = String(ClassData.IDS[(ClassData.IDS.find(cls) + 1) % 6])
			check(not Game.equip_problem(item).is_empty(), "other class blocked")
			Game.profile["class"] = String(cls)
			Game.profile.inv.append(item)
			check(Game.equip_from_bag(0), "equip actual bag item")
			if slot == "weapon":
				check(item.stats.has("matk" if cls in [&"mage",&"priest",&"summoner"] else "atk"), "class damage stat")
			var damaged := item.duplicate(true)
			damaged.level = 200
			check(not Game._valid_item(damaged), "import cannot bypass collection gate")
		check(StarProgression.has_full_set(Game.profile, String(cls)), "four uploaded pieces activate class bonus")
		var uploaded_boots: Dictionary = Game.profile.equip.boots
		Game.profile.equip.boots = StarProgression.item(cls, 200, "boots", rng)
		check(not StarProgression.has_full_set(Game.profile, String(cls)), "mixing crafted set does not complete new collection")
		Game.profile.equip.boots = uploaded_boots
		Game.profile.equip.weapon.plus = 7
		Game.profile.equip.weapon.gems = ["ruby_0"]
		Game.profile.inv.append(ItemData.wings(rng, String(cls), 3))
		Game.profile.inv.append(StarWingData.item(String(cls), rng, 3))
		Game.profile.storage.append(DivineGearData.item(cls, "armor", rng))
		Game.profile.zone = String(DivineRegionData.ID)
		var before := Game.profile.duplicate(true)
		check(Game.save_code_roundtrip(), "save transfer validates class collection")
		var repaired := Game._repair(JSON.parse_string(JSON.stringify(before)))
		check(repaired.equip.weapon.collection == DivineGearData.COLLECTION and repaired.equip.weapon.plus == 7 and repaired.equip.weapon.gems == ["ruby_0"], "reload retains collection and investment")
		check(repaired.storage[-1].collection == DivineGearData.COLLECTION and repaired.zone == String(DivineRegionData.ID), "storage and destination survive reload")
		check(int(repaired.inv[0].level) == 100 and int(repaired.inv[1].level) == 200, "both wing generations survive")
		var zone := RecordingZone.new()
		zone.zone_id = DivineRegionData.ID
		zone.data = new_zone
		zone.rng.seed = 93617
		add_child(zone)
		zone.set_process(false)
		var mob := QuietMob.new()
		mob.stats = {"gold":1}
		mob.template = {}
		mob.is_boss = true
		zone.add_child(mob)
		mob.set_physics_process(false)
		for i in 100:
			zone.items.clear()
			zone._drop_loot(mob)
			check(zone.items.size() == 2, "actual boss loot guarantees two")
			check(zone.items[0].slot != zone.items[1].slot, "boss slots distinct")
			for item in zone.items:
				check(item.collection == DivineGearData.COLLECTION and item["class"] == String(cls), "actual own-class drop routes correctly")
		mob.is_boss = false
		zone.items.clear()
		for i in 1200: zone._drop_loot(mob)
		check(zone.items.size() > 20 and zone.items.size() < 80, "ordinary drops are rolled")
		mob.template.elite = true
		zone.items.clear()
		for i in 1200: zone._drop_loot(mob)
		check(zone.items.size() > 140 and zone.items.size() < 290, "elite drops are more frequent")
		zone.free()
	check(looks.size() == 24, "24 unique equipment icons across six classes")
	check(DivineGearData.item(&"mage", "wings", rng).is_empty(), "no unrequested 200-star wings")
	Game.has_profile = false
	print("DIVINE REGION: ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)
