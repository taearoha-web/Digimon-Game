extends Node
## Reward-shop costumes as items (RewardShop.costume_item, the costume slot): bought into
## the bag with its own icon; put in the costume slot it dresses the hero in the world,
## the turntable in the bag screen and the HUD portrait, taken off they all come back;
## one hero puts it in the shared storage and another wears it, through a save and a
## reload; no merchant, stall, consignment, trade or auto-sell takes it and it adds no
## stats; costumes bought before they were items become items once per hero, exactly
## (the worn one in the slot, the rest in the bag or the storage), never twice on a
## reload; the save check accepts them and refuses broken ones.
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/integration/costume_item_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	_reset()
	_buying()
	await _looks()
	_storage_between_heroes()
	_refusals()
	_migration()
	_saves()
	_reset()
	print("COSTUME ITEMS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _reset() -> void:
	Game.has_profile = false
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	SharedStorage.items().clear()
	SharedStorage.migrated().clear()
	SharedStorage.store()


func _hero(slot: int, cls: StringName, hero_name: String) -> void:
	Game.slot = slot
	Game.new_profile(cls, hero_name, FaceKit.default_look())
	Game.profile.level = 100
	RewardShop.add_coins(20000)
	RewardShop.add_points(20000)


func _count(list: Array, id: String) -> int:
	return list.filter(func(x): return ItemData.is_costume(x) and String(x.get("id", "")) == id).size()


func _body_material(v: HeroVisual) -> ShaderMaterial:
	for node in v.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.skin != null and mi.material_override is ShaderMaterial:
			return mi.material_override
	return null


func _buying() -> void:
	_hero(1, &"warrior", "Fox QA")
	check(RewardShop.buy("costume", "kitsune") == "ok", "the kitsune costume is bought")
	var at := RewardShop.bag_index("kitsune")
	check(at >= 0, "it lands in the bag as an item")
	var item: Dictionary = Game.profile.inv[at] if at >= 0 else {}
	check(item == {"kind": "costume", "id": "kitsune", "rarity": RewardShop.costume_rarity("kitsune")}, "{kind costume, id, rarity}: %s" % [item])
	check(ItemLook.icon(item) != null and ItemLook.icon(item) != ItemLook.icon(RewardShop.costume_item("royal")), "with its own icon")
	check(ItemData.name_of(item) == String(RewardShop.COSTUMES.kitsune.name) and ItemData.color_of(item) == ItemData.RARITY_COLORS[int(item.rarity)], "its name and grade colour")
	var lines := ItemData.detail_lines(item)
	check(lines.has(String(RewardShop.COSTUMES.kitsune.desc)) and lines.has(ItemData.COSTUME_NOTE), "its detail names the pieces and the costume slot (%s)" % [lines])
	check(not ItemData.is_stackable(item) and ItemData.tile_text(item) == "คอสตูม", "one piece, no level on its tile")
	check(RewardShop.buy("costume", "kitsune") == "มีแล้ว", "one purchase a hero")
	check(RewardShop.active("costume") == "", "nothing worn yet")
	# A full bag: the next costume goes to the storage.
	var keep: Array = Game.profile.inv.duplicate()
	var rng := RandomNumberGenerator.new()
	while Game.inventory_free() > 0:
		Game.profile.inv.append(ItemData.generate(10, &"warrior", rng, 0, "ring"))
	check(RewardShop.buy("costume", "sakura") == "ok" and _count(SharedStorage.items(), "sakura") == 1, "a full bag: the costume goes to the storage")
	Game.profile.inv = keep
	Game.withdraw_item(SharedStorage.items().find(RewardShop.costume_item("sakura")))
	check(RewardShop.bag_index("sakura") >= 0 and _count(SharedStorage.items(), "sakura") == 0, "and comes out of it")


func _looks() -> void:
	# The hero in the world.
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	await get_tree().process_frame
	check(hero.visual.costume == "", "no costume before")
	# The HUD's portrait.
	var hud := HUD.new()
	add_child(hud)
	await get_tree().process_frame
	hud._refresh_portrait()
	var portrait: HeroPortrait = hud._portrait
	check(portrait != null and String(portrait._pending_profile.get("costume", "x")) == "", "the HUD portrait: no costume before")
	var key_before := HeroPortrait.appearance_key(Game.profile)
	check(Game.equip_from_bag(RewardShop.bag_index("kitsune")), "put in the costume slot from the bag")
	await get_tree().process_frame
	check(RewardShop.active("costume") == "kitsune" and RewardShop.bag_index("kitsune") < 0, "worn, gone from the bag")
	check(Game.equipped(Game.COSTUME_SLOT) == RewardShop.costume_item("kitsune"), "the costume slot holds the item")
	check(not Game.profile.equip.has(Game.COSTUME_SLOT) and not ItemData.EQUIP_SLOTS.has(Game.COSTUME_SLOT), "kept out of the gear slots")
	check(hero.visual.costume == "kitsune" and _body_material(hero.visual).get_shader_parameter("outfit_color") == RewardShop.COSTUMES.kitsune.cloth, "the hero in the world wears it")
	check(hero.visual.model.find_child("ChibiCostume", true, false) != null, "with its pieces")
	check(String(portrait._pending_profile.get("costume", "")) == "kitsune" and portrait._wanted_key != key_before and portrait._wanted_key.ends_with("kitsune"), "the HUD portrait is redrawn in it")
	check(String(Game.hero_look().cos) == "kitsune", "the look sent online carries it")
	# The bag screen's turntable and the slot.
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"inventory")
	await get_tree().process_frame
	var preview := menu.find_child("HeroPreview", true, false) as HeroPreview
	check(preview != null and preview.visual.costume == "kitsune", "the bag screen's hero wears it")
	var slot := menu.find_child("Slot_costume", true, false) as Button
	check(slot != null and slot.icon == ItemLook.icon(RewardShop.costume_item("kitsune")), "the costume slot shows its icon")
	menu._selected_slot = Game.COSTUME_SLOT
	menu._refresh_detail()
	var off := menu.find_child("CostumeWear", true, false) as Button
	check(off != null and off.text == "ถอด", "the slot's take-off button")
	if off:
		off.pressed.emit()
	await get_tree().process_frame
	check(RewardShop.active("costume") == "" and RewardShop.bag_index("kitsune") >= 0, "taken off into the bag")
	preview = menu.find_child("HeroPreview", true, false) as HeroPreview
	check(preview != null and preview.visual.costume == "", "the bag screen's hero is back in its own clothes")
	check(hero.visual.costume == "" and _body_material(hero.visual).get_shader_parameter("outfit_color") != RewardShop.COSTUMES.kitsune.cloth, "so is the hero in the world")
	check(String(portrait._pending_profile.get("costume", "x")) == "" and portrait._wanted_key == key_before, "and the HUD portrait")
	slot = menu.find_child("Slot_costume", true, false) as Button
	check(slot != null and slot.icon == null and slot.text == "คอสตูม", "the empty slot is named")
	# Worn again from the bag through the detail's button.
	menu._selected_index = RewardShop.bag_index("kitsune")
	menu._selected_slot = ""
	menu._refresh_detail()
	var on := menu.find_child("CostumeWear", true, false) as Button
	check(on != null and on.text == "ใส่", "a costume in the bag: the put-on button")
	check(menu.find_child("StallItem", true, false) == null, "and no stall button")
	for b in menu.find_children("*", "Button", true, false):
		check(not String((b as Button).text).begins_with("ขาย +"), "and no sell button")
	if on:
		on.pressed.emit()
	await get_tree().process_frame
	check(RewardShop.active("costume") == "kitsune", "worn again")
	# Another costume over it: the first goes back to the bag.
	check(RewardShop.wear("costume", "sakura") == "ok" and RewardShop.active("costume") == "sakura" and RewardShop.bag_index("kitsune") >= 0, "one costume at a time: the other goes back")
	await get_tree().process_frame
	check(hero.visual.costume == "sakura" and String(portrait._pending_profile.get("costume", "")) == "sakura", "everything follows the swap")
	RewardShop.wear("costume", "kitsune")
	menu.close_menu()
	menu.free()
	get_tree().paused = false
	hud.queue_free()
	field.queue_free()
	await get_tree().process_frame


func _storage_between_heroes() -> void:
	# Hero 1 (warrior, the kitsune worn, sakura in the bag) sends the sakura costume to hero 2.
	check(Game.save(), "the warrior saves")
	var at := RewardShop.bag_index("sakura")
	check(at >= 0 and Game.deposit_item(at), "the costume goes into the shared storage")
	check(_count(SharedStorage.items(), "sakura") == 1 and RewardShop.bag_index("sakura") < 0, "it is in the storage only")
	check(Game.storage_lock(RewardShop.costume_item("sakura")) == "", "any class may take it")
	_hero(2, &"mage", "Sakura QA")
	check(Game.save(), "a second hero")
	var i := SharedStorage.items().find(RewardShop.costume_item("sakura"))
	check(i >= 0 and Game.withdraw_item(i), "the mage takes it out")
	check(RewardShop.wear("costume", "sakura") == "ok" and RewardShop.active("costume") == "sakura", "and wears it (never bought by this hero)")
	check(not RewardShop.owns("sakura") and RewardShop.problem("costume", "sakura") == "", "this hero may still buy one of its own")
	check(Game.save(), "saved")
	SharedStorage.read_file()
	check(Game.load_game(1) and RewardShop.active("costume") == "kitsune" and RewardShop.bag_index("sakura") < 0, "the warrior: still the kitsune, the sakura gone")
	check(RewardShop.owns("sakura") and RewardShop.buy("costume", "sakura") == "มีแล้ว", "the warrior bought it once: not again")
	check(Game.load_game(2) and RewardShop.active("costume") == "sakura" and String(Game.hero_look().cos) == "sakura", "the mage reloads in it")
	check(Game._valid_profile(Game.profile), "its save passes the check")
	check(_count(SharedStorage.items(), "sakura") == 0, "nothing left behind or doubled")
	# Back through the storage the other way, from the slot.
	check(Game.unequip(Game.COSTUME_SLOT) and Game.deposit_item(RewardShop.bag_index("sakura")), "taken off and stored")
	check(Game.load_game(1) and Game.withdraw_item(SharedStorage.items().find(RewardShop.costume_item("sakura"))) and RewardShop.bag_index("sakura") >= 0, "the warrior has it back")


func _refusals() -> void:
	var at := RewardShop.bag_index("sakura")
	var item: Dictionary = Game.profile.inv[at]
	var gold := int(Game.profile.gold)
	Game.sell_item(at)
	check(RewardShop.bag_index("sakura") == at and int(Game.profile.gold) == gold, "the merchant does not buy it")
	check(ItemData.sell_price(item) == 0 and ItemData.unit_sell_price(item) == 0, "it has no price")
	check(not StallStock.sell(at) and RewardShop.bag_index("sakura") == at and int(Game.profile.gold) == gold, "a stall keeper does not buy it")
	check(not StallStock.consign(at) and RewardShop.bag_index("sakura") == at, "nor takes it on consignment")
	check(PlayerStall.list_item(at, 100) < 0 and PlayerStall.lots().is_empty(), "the hero's own stall refuses it")
	check(not OnlineTrade.tradable(item), "no trade with other players")
	var stall_save := PlayerStall.empty()
	stall_save["lots"] = [{"lot": 1, "item": item.duplicate(), "price": 100, "listed_at": 0.0}]
	check(not PlayerStall.valid(stall_save), "a stall save holding a costume is refused")
	# Auto-sell at every grade and level never picks it, nor the worn one.
	for mask in [31, 1 << int(item.rarity)]:
		check(not Game.auto_sell_indices(mask, 0).has(at), "auto-sell (mask %d) never picks the costume" % mask)
	Game.auto_sell(31, 0)
	check(RewardShop.bag_index("sakura") >= 0 and RewardShop.active("costume") == "kitsune", "after auto-selling everything the costumes are still there")
	at = RewardShop.bag_index("sakura")
	check(Game.keeps_loot(item), "the loot filter has nothing to say about it")
	check(Game.enhance_item(item) != "ok" and Game.equip_problem(item) == "", "the forge refuses it, the costume slot takes it")
	# No stats: worn or not, the hero's numbers are the same.
	var with := HeroStats.compute(Game.profile)
	var cos := String(Game.profile[RewardShop.KEY].cos)
	Game.profile[RewardShop.KEY]["cos"] = ""
	var without := HeroStats.compute(Game.profile)
	Game.profile[RewardShop.KEY]["cos"] = cos
	check(JSON.stringify(with) == JSON.stringify(without), "a costume adds no stats")
	check(HeroStats.gear_bonus(Game.profile) == HeroStats.gear_bonus({"equip": Game.profile.equip}), "nor gear bonus")


## An old save: costumes bought before they were items (rshop.own) and one worn (rshop.cos).
func _migration() -> void:
	_hero(3, &"archer", "Old QA")
	var d := RewardShop.data()
	d["own"] = ["kitsune", "royal", "sakura", "sparkle"]
	d["cos"] = "royal"
	d["trail"] = "sparkle"
	Game.profile.flags.erase(RewardShop.ITEM_FLAG + "kitsune")
	check(Game.save(), "the old hero saves")
	var bag_before: int = Game.profile.inv.size()
	check(Game.load_game(3), "and loads")
	check(RewardShop.active("costume") == "royal" and _count(Game.profile.inv, "royal") == 0, "the worn costume is in the costume slot")
	check(_count(Game.profile.inv, "kitsune") == 1 and _count(Game.profile.inv, "sakura") == 1, "the other two are items in the bag")
	check(Game.profile.inv.size() == bag_before + 2, "exactly two new items (%d -> %d)" % [bag_before, Game.profile.inv.size()])
	check(RewardShop.active("trail") == "sparkle", "the trail is untouched")
	for id in ["kitsune", "royal", "sakura"]:
		check(int(Game.profile.flags.get(RewardShop.ITEM_FLAG + id, 0)) == 1, "%s marked done" % id)
	for n in 2:
		check(Game.load_game(3) and _count(Game.profile.inv, "kitsune") == 1 and _count(Game.profile.inv, "sakura") == 1 and RewardShop.active("costume") == "royal", "reload %d: nothing made twice" % (n + 1))
	# A costume moved away (to the storage, to another hero) does not come back.
	Game.deposit_item(RewardShop.bag_index("kitsune"))
	check(Game.load_game(3) and _count(Game.profile.inv, "kitsune") == 0 and _count(SharedStorage.items(), "kitsune") == 1, "a costume stored away stays away")
	Game.withdraw_item(SharedStorage.items().find(RewardShop.costume_item("kitsune")))
	# A full bag: the old costume goes to the storage, once.
	_hero(4, &"priest", "Full QA")
	RewardShop.data()["own"] = ["celestial", "shadow"]
	while Game.inventory_free() > 0:
		Game.profile.inv.append(ItemData.generate(10, &"priest", RandomNumberGenerator.new(), 0, "ring"))
	check(Game.save() and Game.load_game(4), "a hero with a full bag loads")
	check(_count(SharedStorage.items(), "celestial") == 1 and _count(SharedStorage.items(), "shadow") == 1 and RewardShop.active("costume") == "", "its old costumes wait in the storage")
	check(Game.load_game(4) and _count(SharedStorage.items(), "celestial") == 1 and _count(SharedStorage.items(), "shadow") == 1, "once")
	# The storage file was written with them (a crash after the load loses nothing).
	SharedStorage.read_file()
	check(_count(SharedStorage.items(), "celestial") == 1, "the storage file has them")
	# A hero who already had the item (a later purchase) is only marked.
	_hero(5, &"bard", "Item QA")
	check(RewardShop.buy("costume", "midnight") == "ok", "bought as an item")
	check(Game.save() and Game.load_game(5) and _count(Game.profile.inv, "midnight") == 1, "a bought item is never made again by the migration")


func _saves() -> void:
	Game.load_game(3)
	var p: Dictionary = Game.profile.duplicate(true)
	check(Game._valid_profile(p), "a profile with costume items passes the check")
	var parsed: Variant = JSON.parse_string(JSON.stringify(p))
	check(parsed is Dictionary and Game._valid_profile(parsed), "after JSON too")
	var repaired := Game._repair((parsed as Dictionary).duplicate(true))
	check(_count(repaired.inv, "kitsune") == 1 and repaired.inv[repaired.inv.find(RewardShop.costume_item("kitsune"))].rarity is int, "the repair keeps the item, its grade an int")
	check(not (repaired.inv[repaired.inv.find(RewardShop.costume_item("kitsune"))] as Dictionary).has("count"), "and gives it no count")
	for bad in [{"kind": "costume", "id": "nope", "rarity": 1}, {"kind": "costume", "id": "royal", "rarity": 4, "count": 2},
			{"kind": "costume", "id": "royal", "rarity": 7}, {"kind": "costume", "id": 5}, {"kind": "costume", "id": "royal", "level": 1}]:
		var copy := p.duplicate(true)
		copy.inv.append(bad)
		check(not Game._valid_profile(copy), "a broken costume item is refused (%s)" % [bad])
		check(not SharedStorage.valid_items([bad]), "in the storage too (%s)" % [bad])
	var worn := p.duplicate(true)
	worn.equip[Game.COSTUME_SLOT] = RewardShop.costume_item("royal")
	check(not Game._valid_profile(worn), "a costume is never in profile.equip")
	check(SharedStorage.valid_items([RewardShop.costume_item("royal")]), "a costume in the storage is fine")
	check(Game.save_code_roundtrip(), "the save code round-trips with costume items")
	var bundle := Game.build_cloud_bundle()
	check(bundle.slots.has(String.num_int64(Game.slot)), "the cloud bundle carries the hero")
	# Another look from the wire: the costume id survives PlayerLook.clean.
	check(String(PlayerLook.clean(Game.hero_look()).cos) == "royal", "a remote player sees the worn costume")
