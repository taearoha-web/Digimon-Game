extends Node3D
## The 250★ set's recipe takes the sanctuary's gear (SetGearData.recipe): a
## weapon / armour / helm / boots piece needs the class's divine piece of that
## slot at +10 or more (any piece, from the bag or storage; the worn one only when
## nothing else fits and only once confirmed), a ring / amulet needs Lotus Scales
## (เกล็ดบัวดารา). A failed try loses the core and jewels but keeps the divine
## piece and the scales. Covers the recipe data, the refusals (+9, other class,
## other slot, no scales), what a success uses up, the +0 result and gems coming
## back, the pick order and the worn-piece confirmation, the forge's ผสมชุดเซต
## requirement lines, the shared drop table of the two ★200-300 fields (scales
## drop there and nowhere else) and save validation of the new jewel.
##   godot --headless --path . res://tests/integration/set_recipe_test.tscn
var checks := 0
var failures := 0
var rng := RandomNumberGenerator.new()


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


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func settle(frames := 3) -> void:
	for i in frames:
		await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	ZoneData.ensure()
	rng.seed = 5150
	_recipe()
	_refusals()
	_consumes()
	_failure()
	_picks()
	await _forge_ui()
	_drops()
	_save()
	print("SET RECIPE: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func _hero(cls: StringName) -> void:
	Game.new_profile(cls, "Recipe QA", FaceKit.default_look())
	Game.profile.level = Game.MAX_LEVEL
	Game.paragon()["level"] = SetGearData.STARS
	Game.profile["inv"] = []
	Game.profile["storage"] = []
	Game.profile["equip"] = {}
	Game.storage().clear()


func give(id: String, count: int) -> void:
	Game.add_item(ItemData.jewel(id, count))


func core_and_jewels(times := 1) -> void:
	for id in SetGearData.CRAFT_COST:
		give(id, int(SetGearData.CRAFT_COST[id]) * times)


func divine(cls: StringName, slot: String, plus: int, gems: Array = []) -> Dictionary:
	var piece := DivineGearData.item(cls, slot, rng)
	piece["plus"] = plus
	piece["gems"] = gems.duplicate()
	return piece


func _set_pieces(list: Array) -> Array:
	return list.filter(func(item): return SetGearData.is_item(item))


func _in(list: Array, item: Dictionary) -> bool:
	return list.any(func(x): return is_same(x, item))


func _recipe() -> void:
	for cls in StarGearData.CLASSES:
		for slot in SetGearData.SLOTS:
			var need := SetGearData.recipe(cls, slot)
			var divine_slot := DivineGearData.SLOTS.has(slot)
			check(int(need.core) == 1 and need.jewels == {"purple": 20, "pink": 20, "chaos": 20} and is_equal_approx(float(need.chance), SetGearData.CRAFT_CHANCE), "%s %s: core, jewels and chance (%s)" % [cls, slot, need])
			check(String(need.divine_slot) == (slot if divine_slot else "") and int(need.divine_plus) == (10 if divine_slot else 0), "%s %s: the divine piece of the same slot at +10" % [cls, slot])
			check(int(need.scales) == (0 if divine_slot else 5) and need.scale_id == "lotus_scale" and need.keep_on_fail == ["divine", "scales"], "%s %s: scales only for jewellery" % [cls, slot])
	check(SetGearData.recipe("vagabond", "weapon").is_empty() and SetGearData.recipe("warrior", "wings").is_empty(), "no recipe for a Vagabond or wings")
	# The old names stay.
	check(SetGearData.CRAFT_COST == {"set_core": 1, "purple": 20, "pink": 20, "chaos": 20} and SetGearData.CORE == "set_core" and SetGearData.cost_text().contains("แก่นเทพหลอมเซต 1"), "CRAFT_COST, CORE and cost_text unchanged")
	# The new jewel.
	var scale := ItemData.jewel("lotus_scale", 3)
	check(ItemData.JEWELS.has("lotus_scale") and ItemData.name_of(scale) == "เกล็ดบัวดารา" and ItemData.is_stackable(scale), "the Lotus Scale is a stackable jewel (%s)" % ItemData.name_of(scale))
	check(ItemLook.icon(scale) != null and ResourceLoader.exists("res://assets/icons/ui/jewel_lotus_scale.svg"), "it has its icon")
	check(SetGearData.requirement_text("warrior", "weapon").begins_with("ต้องมี: ดาบพันดาบเทวะ +10 (ชุดประจำอาชีพ ชิ้นใดก็ได้) + แก่นเทพหลอมเซต 1"), "requirement text (%s)" % SetGearData.requirement_text("warrior", "weapon"))
	check(SetGearData.requirement_text("mage", "ring").begins_with("ต้องมี: เกล็ดบัวดารา 5 + แก่นเทพหลอมเซต 1 + เพชรม่วง 20"), "ring requirement text (%s)" % SetGearData.requirement_text("mage", "ring"))


func _refusals() -> void:
	_hero(&"warrior")
	core_and_jewels(4)
	var cores := Game.jewel_count("set_core")
	check(Game.set_piece_problem("weapon").begins_with("ต้องมี ดาบพันดาบเทวะ +10"), "no divine sword: refused (%s)" % Game.set_piece_problem("weapon"))
	check(Game.craft_set_piece("weapon", 0.0) != "ok" and Game.jewel_count("set_core") == cores, "and nothing is spent")
	var nine := divine(&"warrior", "weapon", 9)
	Game.profile.inv.append(nine)
	check(Game.craft_set_piece("weapon", 0.0).begins_with("ต้องมี") and _in(Game.profile.inv, nine) and Game.jewel_count("set_core") == cores, "a +9 divine sword does not qualify")
	Game.profile.inv.append(divine(&"archer", "weapon", 12))
	Game.profile.inv.append(divine(&"warrior", "armor", 12))
	check(Game.craft_set_piece("weapon", 0.0).begins_with("ต้องมี"), "another class's or another slot's +12 piece does not qualify")
	nine["plus"] = 10
	check(Game.set_piece_problem("weapon") == "", "the same sword at +10 qualifies")
	check(Game.set_piece_problem("ring").begins_with("ต้องมี เกล็ดบัวดารา 5"), "a ring without scales: refused (%s)" % Game.set_piece_problem("ring"))
	give("lotus_scale", 4)
	check(Game.craft_set_piece("ring", 0.0) != "ok" and Game.jewel_count("lotus_scale") == 4 and Game.jewel_count("set_core") == cores, "four scales are not enough, nothing spent")
	give("lotus_scale", 1)
	check(Game.set_piece_problem("ring") == "" and Game.set_piece_problem("amulet") == "", "five scales make a ring or an amulet")


func _consumes() -> void:
	_hero(&"mage")
	core_and_jewels(2)
	var staff := divine(&"mage", "weapon", 13, ["ruby_2", "sapphire_1"])
	Game.profile.inv.append(staff)
	check(Game.craft_set_piece("weapon", 0.0) == "ok", "a +13 divine staff forges the set staff")
	var made := _set_pieces(Game.profile.inv)
	check(made.size() == 1 and made[0].slot == "weapon" and SetGearData.item_class(made[0]) == "mage", "the set staff is in the bag")
	check(made.size() == 1 and int(made[0].plus) == 0 and (made[0].gems as Array).is_empty(), "it comes out at +0 with no gems (the +13 does not carry over)")
	check(not _in(Game.profile.inv, staff) and not Game.profile.inv.any(func(it): return DivineGearData.is_item(it)), "the divine staff is used up")
	check(Game.jewel_count("set_core") == 1 and Game.jewel_count("purple") == 20 and Game.jewel_count("chaos") == 20, "one core and 20 of each jewel spent")
	var gem_ids: Array = Game.profile.inv.filter(func(it): return it.get("kind", "") == "gem").map(func(it): return String(it.id))
	check(gem_ids.has("ruby_2") and gem_ids.has("sapphire_1"), "the staff's gems come back to the bag (%s)" % [gem_ids])
	give("lotus_scale", 7)
	check(Game.craft_set_piece("amulet", 0.0) == "ok" and Game.jewel_count("lotus_scale") == 2 and Game.jewel_count("set_core") == 0, "an amulet uses five scales and a core")
	# From storage: the hero is saved with the new piece, the storage loses the old one.
	_hero(&"lancer")
	core_and_jewels()
	var spear := divine(&"lancer", "helm", 10)
	Game.storage().append(spear)
	check(Game.craft_set_piece("helm", 0.0) == "ok" and not _in(Game.storage(), spear) and _set_pieces(Game.profile.inv).size() == 1, "a divine helm in storage qualifies and is used up")


func _failure() -> void:
	_hero(&"priest")
	core_and_jewels()
	var boots := divine(&"priest", "boots", 11)
	Game.profile.inv.append(boots)
	check(Game.craft_set_piece("boots", 0.99) == "fail", "a high roll fails")
	check(_in(Game.profile.inv, boots) and int(boots.plus) == 11, "the divine boots stay (still +11)")
	check(Game.jewel_count("set_core") == 0 and Game.jewel_count("purple") == 0 and Game.jewel_count("pink") == 0 and Game.jewel_count("chaos") == 0, "the core and jewels are lost")
	check(_set_pieces(Game.profile.inv).is_empty(), "and nothing is made")
	core_and_jewels()
	give("lotus_scale", 5)
	check(Game.craft_set_piece("ring", 0.5) == "fail" and Game.jewel_count("lotus_scale") == 5 and Game.jewel_count("set_core") == 0, "a failed ring keeps the five scales")
	core_and_jewels()
	check(Game.craft_set_piece("ring", 0.4999) == "ok" and Game.jewel_count("lotus_scale") == 0, "the next try under 50% uses them")


func _picks() -> void:
	_hero(&"assassin")
	core_and_jewels(4)
	var worn := divine(&"assassin", "armor", 15)
	Game.profile.equip["armor"] = worn
	var bag := divine(&"assassin", "armor", 12)
	var stored := divine(&"assassin", "armor", 10)
	var low := divine(&"assassin", "armor", 9)
	Game.profile.inv.append(bag)
	Game.profile.inv.append(low)
	Game.storage().append(stored)
	var choices := Game.set_divine_choices("armor")
	check(choices.size() == 3 and is_same(choices[0].item, stored) and is_same(choices[1].item, bag) and choices[2].where == "equip", "choices: lowest + first, the worn one last, the +9 left out")
	check(Game.craft_set_piece("armor", 0.0, bag) == "ok" and not _in(Game.profile.inv, bag) and _in(Game.storage(), stored) and Game.profile.equip.armor == worn, "an explicit pick uses that piece only")
	check(Game.craft_set_piece("armor", 0.0) == "ok" and not _in(Game.storage(), stored) and Game.profile.equip.armor == worn, "the default is the lowest + piece, never the worn one")
	var cores := Game.jewel_count("set_core")
	check(Game.craft_set_piece("armor", 0.0) == Game.SET_WORN_CONFIRM and Game.profile.equip.armor == worn and Game.jewel_count("set_core") == cores, "only the worn piece left: refused until confirmed, nothing spent")
	check(Game.craft_set_piece("armor", 0.0, {}, true) == "ok" and not Game.profile.equip.has("armor") and _in(Game.profile.inv, low), "confirmed: the worn armour is used, the +9 stays")
	check(_set_pieces(Game.profile.inv).size() == 3, "three set armours made")
	var stranger := divine(&"assassin", "armor", 14)
	check(Game.craft_set_piece("armor", 0.0, stranger) != "ok", "a pick that is not the hero's own is refused")


func _forge_ui() -> void:
	_hero(&"warrior")
	var menu := GameMenu.new()
	add_child(menu)
	menu.forge_mode = true
	menu.open_menu(&"inventory")
	await settle()
	var toggle := menu.find_child("SetCraftToggle", true, false) as Button
	check(toggle != null, "the forge has ผสมชุดเซต")
	if toggle == null:
		menu.queue_free()
		return
	toggle.pressed.emit()
	await settle()
	var intro := menu.find_child("Intro", true, false) as Label
	check(intro != null and intro.text.contains("+10") and intro.text.contains("เกล็ดบัวดารา 5"), "the intro names the +10 divine piece and the scales (%s)" % (intro.text if intro else ""))
	var need := func(slot: String) -> String:
		var card := menu.find_child("SetPiece_" + slot, true, false)
		var label := card.find_child("Need", true, false) as RichTextLabel if card != null else null
		return label.get_parsed_text() if label != null else ""
	check(need.call("weapon").begins_with("ต้องมี: ดาบพันดาบเทวะ +10 (ชุดประจำอาชีพ ชิ้นใดก็ได้) + แก่นเทพหลอมเซต 1") and need.call("weapon").contains("✗"), "the sword card shows its need, unmet (%s)" % need.call("weapon"))
	check(need.call("ring").begins_with("ต้องมี: เกล็ดบัวดารา 5") and need.call("ring").contains("✗ มี 0/5"), "the ring card shows the scales (%s)" % need.call("ring"))
	core_and_jewels(2)
	give("lotus_scale", 5)
	var low := divine(&"warrior", "weapon", 10)
	var high := divine(&"warrior", "weapon", 14)
	Game.profile.inv.append(high)
	Game.profile.inv.append(low)
	Game.profile.equip["helm"] = divine(&"warrior", "helm", 12)
	menu._rebuild()
	await settle()
	check(need.call("weapon").contains("✓ มี 2 ชิ้น") and need.call("ring").contains("✓ มี 5/5"), "met needs turn green (%s | %s)" % [need.call("weapon"), need.call("ring")])
	var card := menu.find_child("SetPiece_weapon", true, false)
	var picker := card.find_child("DivinePick", true, false) as OptionButton
	check(picker != null and picker.item_count == 2 and picker.get_item_text(picker.selected).contains("+10"), "two swords: a picker defaulting to the +10")
	var craft := card.find_child("Craft", true, false) as Button
	check(craft != null and not craft.disabled, "ผสม is on")
	if picker != null:
		picker.select(1)
		picker.item_selected.emit(1)
		await settle()
	card = menu.find_child("SetPiece_weapon", true, false)
	picker = card.find_child("DivinePick", true, false) as OptionButton
	check(picker != null and picker.get_item_text(picker.selected).contains("+14"), "the pick holds after a rebuild")
	(card.find_child("Craft", true, false) as Button).pressed.emit()
	await settle()
	check(not _in(Game.profile.inv, high) and _in(Game.profile.inv, low) or (_in(Game.profile.inv, high) and _set_pieces(Game.profile.inv).is_empty()), "the press used the picked +14 (or failed and kept it)")
	# The worn helm is the only one: the button says so and asks first.
	var helm_card := menu.find_child("SetPiece_helm", true, false)
	var helm_button := helm_card.find_child("Craft", true, false) as Button if helm_card != null else null
	check(helm_button != null and helm_button.text.contains("ชิ้นที่สวม") and not helm_button.disabled, "a worn-only helm: ผสม (ใช้ชิ้นที่สวม)")
	if helm_button != null:
		helm_button.pressed.emit()
		await settle()
		var dialog := _dialog(menu)
		check(dialog != null and Game.profile.equip.has("helm"), "it asks before touching the worn helm")
		if dialog != null:
			dialog._close(false)
			await settle()
		check(Game.profile.equip.has("helm"), "cancel keeps the helm on")
	menu.close_menu()
	menu.queue_free()
	await settle()


func _dialog(root: Node) -> ModalDialog:
	for node in root.find_children("*", "ModalDialog", true, false):
		return node as ModalDialog
	return null


func _drops() -> void:
	# Only the two ★200-300 fields carry the shared table.
	var endgame: Array = []
	for id in ZoneData.ZONES:
		if bool(ZoneData.ZONES[id].get("endgame_loot", false)):
			endgame.append(String(id))
	endgame.sort()
	check(endgame == ["drowned_abyss", "lotus_sanctum"], "the shared table is on the sanctuary and the abyss only (%s)" % [endgame])
	# The table's own rates.
	var roll := RandomNumberGenerator.new()
	roll.seed = 77
	var n := 60000
	var normal := 0
	var elite := 0
	for i in n:
		normal += EndgameFields.scale_count(false, false, 0.0, roll)
		elite += EndgameFields.scale_count(false, true, 0.0, roll)
	check(absf(float(normal) / n - EndgameFields.SCALE_NORMAL) < 0.0012, "scales 0.5%% an ordinary kill (%d / %d)" % [normal, n])
	check(absf(float(elite) / n - EndgameFields.SCALE_ELITE) < 0.004, "scales 3%% an elite (%d / %d)" % [elite, n])
	check(EndgameFields.scale_count(true, false, 0.0, roll) == 2, "the boss gives two")
	# The real kill path: the same dice in both fields give the very same drops.
	_hero(&"bard")
	var seen := {}
	for zone_id in [DivineRegionData.ID, DrownedAbyssData.ID]:
		var keys: Array = []
		for boss in [false, true]:
			var zone := RecordingZone.new()
			zone.zone_id = zone_id
			zone.data = ZoneData.get_zone(zone_id)
			zone.rng.seed = 31337
			zone._event_rng.seed = 31338
			add_child(zone)
			zone.set_process(false)
			var mob := QuietMob.new()
			mob.stats = {"gold": 100}
			mob.template = {}
			mob.is_boss = boss
			zone.add_child(mob)
			mob.set_physics_process(false)
			for i in (300 if boss else 6000):
				zone._drop_loot(mob)
			for it in zone.items:
				keys.append("%s|%s|%s|%s|%d" % [it.get("kind", ""), it.get("id", ""), it.get("slot", ""), it.get("collection", it.get("star_tier", "")), int(it.get("count", 1))])
			zone.free()
		seen[zone_id] = keys
		var scales := keys.filter(func(k): return String(k).begins_with("jewel|lotus_scale|"))
		check(scales.size() > 300, "%s drops Lotus Scales (%d stacks)" % [zone_id, scales.size()])
		check(keys.any(func(k): return String(k).contains(DivineGearData.COLLECTION)), "%s drops divine pieces" % zone_id)
		check(keys.any(func(k): return String(k).begins_with("jewel|set_core|")), "%s drops set cores" % zone_id)
	check(seen[DivineRegionData.ID] == seen[DrownedAbyssData.ID], "the sanctuary and the abyss drop exactly the same table (%d / %d drops)" % [seen[DivineRegionData.ID].size(), seen[DrownedAbyssData.ID].size()])
	# Nowhere else.
	for zone_id in [&"meadow", &"void", &"eclipse_realm"]:
		var zone := RecordingZone.new()
		zone.zone_id = zone_id
		zone.data = ZoneData.get_zone(zone_id)
		zone.rng.seed = 4
		add_child(zone)
		zone.set_process(false)
		var mob := QuietMob.new()
		mob.stats = {"gold": 1}
		mob.template = {"elite": true}
		mob.level = 100
		zone.add_child(mob)
		mob.set_physics_process(false)
		for i in 3000:
			zone._drop_loot(mob)
		mob.is_boss = true
		for i in 100:
			zone._drop_loot(mob)
		check(not zone.items.any(func(it): return String(it.get("id", "")) == "lotus_scale"), "no Lotus Scale in %s" % zone_id)
		zone.free()
	for lvl in [100]:
		for stars in [0, 150, 199]:
			check(not StallStock.jewels_for(lvl, stars).has("lotus_scale"), "keepers below ★200 have no scales (★%d)" % stars)
	check(StallStock.jewels_for(100, 200).has("lotus_scale"), "a ★200 keeper may sell them, like the set core")


func _save() -> void:
	_hero(&"defender")
	give("lotus_scale", 3)
	give("set_core", 1)
	# A piece forged before the recipe changed stays as it is.
	var old := SetGearData.item("defender", "boots")
	old["plus"] = 6
	Game.profile.equip["boots"] = old
	Game.profile.inv.append(divine(&"defender", "weapon", 10))
	var saved: Dictionary = Game.profile.duplicate(true)
	saved.paragon["level"] = mini(int(saved.paragon.level), Game.PARAGON_MAX)
	check(Game._valid_item(ItemData.jewel("lotus_scale", 3)), "a scale stack is a valid item")
	check(not Game._valid_item({"kind": "jewel", "id": "lotus_scale", "count": 0}) and not Game._valid_item({"kind": "jewel", "id": "lotus_scales", "count": 1}), "an empty or misspelt stack is refused")
	check(not Game._valid_item({"kind": "jewel", "id": "lotus_scale", "count": 1, "plus": 3}), "a scale with gear fields is refused")
	check(Game._valid_profile(saved.duplicate(true)), "a profile with scales and an old set piece is valid")
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	check(parsed is Dictionary and Game._valid_profile((parsed as Dictionary).duplicate(true)), "the JSON round trip is valid")
	if parsed is Dictionary:
		var back := Game._repair(parsed)
		var scales: Array = back.inv.filter(func(it): return it.get("id", "") == "lotus_scale")
		check(scales.size() == 1 and int(scales[0].count) == 3, "the scales survive the repair")
		check(SetGearData.is_item(back.equip.boots) and int(back.equip.boots.plus) == 6 and back.equip.boots.stats == old.stats, "the old set boots survive unchanged")
	Game.paragon()["level"] = mini(SetGearData.STARS, Game.PARAGON_MAX)
	Game.slot = 9
	check(Game.save() and Game.load_game(9), "saved and loaded through the real slot")
	check(Game.jewel_count("lotus_scale") == 3 and SetGearData.is_item(Game.profile.equip.get("boots")), "scales and the old piece load")
	Game.delete_save(9)
