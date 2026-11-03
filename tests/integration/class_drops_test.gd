extends Node3D
## Gear drops of every class (ItemData.drop_class): the hero's own class
## ItemData.OWN_CLASS_DROP (30%) of the time, the other nine evenly, checked with seeded
## dice on drop_class and on the real kill path (Zone._drop_loot: field monsters, the
## field boss, the star regions); boss chase pieces stay the hero's own class. Another
## class's piece shows "ของอาชีพ <ชื่อ>" (muted) in the bag, can be sold, stored and set
## out on the stall but never worn, and "ขายของอาชีพอื่นอัตโนมัติ" (off by default) is the
## only thing that sells it off on its own.
## godot --headless --path . res://tests/integration/class_drops_test.tscn
var checks := 0
var failures := 0


class RecordingZone:
	extends Zone
	var items: Array[Dictionary] = []
	func _ready() -> void: pass
	func _spawn_loot(item: Dictionary, _coins: int, _from: Vector3) -> void:
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


func _ready() -> void:
	Game.set_process(false)
	ZoneData.ensure()
	_split()
	_kill_path()
	_label_and_guard()
	_auto_sell()
	await _bag_tooltip()
	print("CLASS DROPS: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## drop_class: 30% own, 70% spread over the other nine (all ten for a Vagabond).
func _split() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 30070
	var n := 40000
	var counts := {}
	for i in n:
		var cls := ItemData.drop_class(&"warrior", rng)
		counts[cls] = int(counts.get(cls, 0)) + 1
	var own := float(counts.get(&"warrior", 0)) / n
	check(absf(own - ItemData.OWN_CLASS_DROP) < 0.01, "own class ~30%% (%.3f)" % own)
	check(counts.size() == ClassData.IDS.size() and not counts.has(ClassData.START), "every class drops, never the Vagabond's (%d kinds)" % counts.size())
	for cls in ClassData.IDS:
		if cls == &"warrior":
			continue
		var share := float(counts.get(cls, 0)) / n
		check(absf(share - 0.7 / 9.0) < 0.008, "%s ~7.8%% (%.3f)" % [cls, share])
	counts.clear()
	for i in 20000:
		var cls := ItemData.drop_class(ClassData.START, rng)
		counts[cls] = int(counts.get(cls, 0)) + 1
	check(absf(float(counts.get(ClassData.START, 0)) / 20000.0 - 0.3) < 0.015 and counts.size() == ClassData.IDS.size() + 1, "a Vagabond finds its own 30%% and every class's gear")


## The real drop paths: field monsters, the field boss, a star region.
func _kill_path() -> void:
	Game.new_profile(&"archer", "Drops QA")
	Game.profile.level = 40
	var zone := RecordingZone.new()
	zone.zone_id = &"volcano"
	zone.data = ZoneData.get_zone(&"volcano")
	zone.rng.seed = 7
	add_child(zone)
	zone.set_process(false)
	var mob := QuietMob.new()
	mob.setup(StringName(zone.data.camps[0].monsters[0]), 40, Vector3.ZERO, null)
	zone.add_child(mob)
	mob.set_physics_process(false)
	for i in 6000:
		zone._drop_loot(mob)
	var weapons := zone.items.filter(func(it): return it.get("kind", "") == "equip" and it.get("slot", "") == "weapon")
	var own := weapons.filter(func(it): return String(it["class"]) == "archer").size()
	var share := float(own) / maxf(1.0, weapons.size())
	check(weapons.size() > 150 and absf(share - 0.3) < 0.07, "field weapons: ~30%% the archer's (%d/%d)" % [own, weapons.size()])
	var kinds := {}
	for it in weapons:
		kinds[String(it["class"])] = true
	check(kinds.size() == ClassData.IDS.size(), "field weapons of all ten classes (%d)" % kinds.size())
	check(weapons.all(func(it): return String(it.base) == String(ClassData.get_class_data(StringName(it["class"])).weapon_kind)), "a weapon is its class's weapon kind")
	# The field boss: its pieces any class, its chase pieces always the hero's.
	zone.items.clear()
	var boss := QuietMob.new()
	boss.setup(StringName(zone.data.boss.monster), 42, Vector3.ZERO, null)
	boss.is_boss = true
	zone.add_child(boss)
	boss.set_physics_process(false)
	zone._boss = boss
	var chase := 0
	for i in 300:
		Game.boss_pity()[String(boss.monster_id)] = 999
		zone._drop_loot(boss)
	var classed := zone.items.filter(func(it): return it.get("kind", "") == "equip" and String(it.get("class", "")) != "" and not it.has("boss"))
	var boss_own := classed.filter(func(it): return String(it["class"]) == "archer").size()
	check(classed.size() > 30 and float(boss_own) / classed.size() < 0.5 and boss_own > 0, "boss pieces mostly other classes (%d/%d own)" % [boss_own, classed.size()])
	for it in zone.items:
		if it.has("boss"):
			chase += 1
			check(String(it.get("class", "archer")) in ["", "archer"], "a chase piece stays the hero's own class")
	check(chase > 0 or not BossLootData.has(boss.monster_id), "chase pieces still drop (%d)" % chase)
	# A ★ region: every piece class-bound, ~30% the hero's.
	Game.profile.level = 100
	Game.paragon()["level"] = 60
	var star_id := StringName()
	for id in ZoneData.ZONES:
		if StarProgression.is_region(id):
			star_id = id
			break
	zone.zone_id = star_id
	zone.data = ZoneData.get_zone(star_id)
	zone.items.clear()
	mob.is_boss = true
	for i in 400:
		zone._star_loot(mob, Vector3.ZERO)
	var star := zone.items.filter(func(it): return int(it.get("star_tier", 0)) > 0 and it.get("slot", "") != "wings")
	var star_own := star.filter(func(it): return String(it.star_class) == "archer").size()
	check(star.size() > 600 and absf(float(star_own) / star.size() - 0.3) < 0.06, "★ gear ~30%% the archer's (%d/%d)" % [star_own, star.size()])
	var wings := zone.items.filter(func(it): return it.get("slot", "") == "wings")
	check(wings.size() > 100 and wings.all(func(it): return ItemData.WING_INFO.has(String(it.wing)) and String(it["class"]) == String(it.wing)), "wings drop for any class (%d)" % wings.size())
	check(wings.any(func(it): return String(it["class"]) != "archer") and wings.any(func(it): return String(it["class"]) == "archer"), "wings of the hero's and other classes")
	zone.free()


## The "ของอาชีพ ..." label and the equip guard.
func _label_and_guard() -> void:
	Game.new_profile(&"warrior", "Guard QA")
	Game.profile.level = 60
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bow := ItemData.generate(50, &"archer", rng, 2, "weapon")
	var sword := ItemData.generate(50, &"warrior", rng, 2, "weapon")
	var armor := ItemData.generate(50, &"archer", rng, 2, "armor")
	check(ItemData.class_tag(bow, "warrior") == "ของอาชีพ " + String(ClassData.get_class_data(&"archer").name), "an archer bow reads ของอาชีพ <archer> (%s)" % ItemData.class_tag(bow, "warrior"))
	check(ItemData.class_tag(sword, "warrior") == "" and ItemData.class_tag(armor, "warrior") == "", "own and any-class gear carry no tag")
	var wings := ItemData.wings(rng, "mage", 1)
	check(ItemData.class_tag(wings, "warrior").ends_with(String(ClassData.get_class_data(&"mage").name)), "other-class wings are tagged")
	Game.profile.inv = [bow, sword, armor]
	check(Game.equip_problem(bow) == "สำหรับอาชีพอื่น" and not Game.equip_from_bag(0), "another class's weapon cannot be worn")
	check(Game.equip_problem(sword) == "" and Game.equip_problem(armor) == "", "own weapon and any-class armour can")
	var star := StarProgression.item(&"mage", 50, "helm", rng)
	Game.profile.level = 100
	Game.paragon()["level"] = 200
	check(Game.equip_problem(star) == "สำหรับอาชีพอื่น", "another class's ★ gear cannot be worn")
	# Sold at the merchant, a stall keeper, stored, stalled.
	var gold := int(Game.profile.gold)
	Game.sell_item(0)
	check(int(Game.profile.gold) == gold + ItemData.sell_price(bow) and Game.profile.inv.size() == 2, "the merchant buys another class's piece")
	Game.profile.inv.insert(0, bow)
	check(Game.deposit_item(0), "another class's piece goes into the storage")
	var stored := SharedStorage.items().size() - 1
	check(Game.storage_lock(SharedStorage.items()[stored]) != "", "and only an archer takes it back out")


## Auto-sell: other-class gear is kept unless "ขายของอาชีพอื่นอัตโนมัติ" is on.
func _auto_sell() -> void:
	Game.new_profile(&"warrior", "Autosell QA")
	Game.profile.level = 60
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var bow := ItemData.generate(20, &"archer", rng, 0, "weapon")
	var sword := ItemData.generate(20, &"warrior", rng, 0, "weapon")
	var cape := ItemData.wings(rng, "mage", 0)
	Game.profile.inv = [bow, sword, cape]
	check(not Game.sells_other_class(), "ขายของอาชีพอื่นอัตโนมัติ is off by default")
	check(Game.auto_sell_indices(31, 0) == [1], "bulk auto-sell keeps the other class's piece for the stall")
	check(Game.pickup_sale(bow) == 0, "nothing is sold on pickup while the option is off")
	Game.set_sells_other_class(true)
	check(Game.auto_sell_indices(31, 0) == [0, 1], "with the option on, bulk auto-sell takes it too")
	check(Game.pickup_sale(bow) == ItemData.sell_price(bow) and Game.pickup_sale(sword) == 0, "with the option on, another class's piece sells on pickup")
	check(Game.pickup_sale(cape) == 0, "wings are never sold off on their own")
	Game.set_sells_other_class(false)
	check(int(Game.profile.flags.get(Game.AUTOSELL_OTHER_FLAG, -1)) == 0, "the choice is kept in the flags")
	# The pickup filter applies to every class alike, it does not single them out.
	Game.set_loot_mask(31)
	check(Game.keeps_loot(bow), "another class's piece is picked up like any other")


## The bag's detail panel shows the tag in a muted colour, and the grid marks the slot.
func _bag_tooltip() -> void:
	Game.new_profile(&"warrior", "Tooltip QA")
	Game.profile.level = 60
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	Game.profile.inv = [ItemData.generate(50, &"bard", rng, 3, "weapon")]
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"inventory")
	await get_tree().process_frame
	menu._selected_index = 0
	menu._refresh_detail()
	var tag: Label = menu.find_child("ClassTag", true, false)
	check(tag != null and tag.text.begins_with("ของอาชีพ " + String(ClassData.get_class_data(&"bard").name)), "the detail panel names the bard's piece")
	check(tag != null and tag.get_theme_color("font_color") == ItemData.CLASS_TAG_COLOR, "in the muted colour")
	check(menu.find_child("ClassMark", true, false) != null, "the bag slot is marked อาชีพอื่น")
	var wear: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == "สำหรับอาชีพอื่น":
			wear = b
	check(wear != null and wear.disabled, "the wear button is disabled with the reason")
	check(menu.find_child("StallItem", true, false) != null, "and it can go on the stall")
	menu.close_menu()
	menu.free()
	get_tree().paused = false
