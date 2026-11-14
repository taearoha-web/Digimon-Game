extends Node
## Every item the game hands out has an icon and a sensible bag tile (ItemLook.icon,
## ItemData.tile_text): every forge jewel and material (ItemData.JEWELS: the dragon tomb's
## เกล็ดมังกรโบราณ too), every gem of every size, every potion, every reward-shop costume
## item, the Legendary Guild Wings of every guild, and what every shop sells (the
## merchant at every level, the tomb keeper, the guild quest shop, the league's secret
## shop, the reward shop's stones, the AI stalls of every kind and level) plus the reward
## pass, the party raid, chapter 2, the star gear, the divine and endgame drops and the
## boss chase pieces. A tile reads "×N" for a stack, the level for gear and never
## "Lv.0" (a thing without a level shows its short name or nothing).
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/integration/item_icons_test.tscn
var failures := 0
var checks := 0
var _seen := {}


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## One item: its icon, its tile text and its name.
func _item(source: String, item: Variant) -> void:
	if not item is Dictionary or (item as Dictionary).is_empty():
		return
	var key := "%s|%s|%s" % [source, String(item.get("kind", "")), String(item.get("id", ItemLook.look_of(item)))]
	if _seen.has(key):
		return
	_seen[key] = true
	var text := ItemData.tile_text(item)
	check(ItemLook.icon(item) != null, "%s: %s has an icon (%s)" % [source, ItemData.name_of(item), JSON.stringify(item).left(160)])
	check(not text.begins_with("Lv.0") and text != "Lv.0", "%s: %s never reads Lv.0 (%s)" % [source, ItemData.name_of(item), text])
	if ItemData.is_stackable(item):
		check(text == "×%d" % int(item.get("count", 1)), "%s: a stack reads its count (%s)" % [source, text])
	elif item.get("kind", "") == "equip":
		check(text != "" and int(item.get("level", 0)) >= 1, "%s: gear reads its level (%s)" % [source, text])
	check(ItemData.name_of(item) != "" and ItemData.name_of(item) != "?", "%s: a name (%s)" % [source, ItemData.name_of(item)])


func _ready() -> void:
	Game.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261114
	# Stackables, every one of them.
	for id in ItemData.JEWELS:
		_item("jewel", ItemData.jewel(id, 5))
	check(ResourceLoader.exists("res://assets/icons/ui/jewel_dragon_scale.svg"), "the dragon tomb's scale has its own icon")
	for id in ItemData.POTIONS:
		_item("potion", ItemData.potion(id, 3))
	for g in ItemData.GEMS:
		for size in ItemData.GEM_MAX_SIZE + 1:
			_item("gem", ItemData.gem(g, size, 2))
	# Reward-shop costumes are items with their own icon (one per costume).
	var costume_icons := {}
	for id in RewardShop.COSTUMES:
		var item := RewardShop.costume_item(id)
		_item("costume", item)
		check(ItemData.tile_text(item) == "คอสตูม", "a costume tile names it, no level")
		costume_icons[ItemLook.icon(item)] = true
	check(costume_icons.size() == RewardShop.COSTUMES.size(), "every costume has an icon of its own")
	for g in range(1, 5):
		_item("legend_wings", LegendWings.item(LegendWings.FROM_WEEK, g))
	# A thing of no known kind: an icon all the same and no level.
	var odd := {"kind": "ticket", "id": "x"}
	check(ItemLook.icon(odd) != null and ItemData.tile_text(odd) == "", "an unknown thing shows a plain icon and no Lv.0")
	check(ItemData.tile_text({"kind": "equip", "slot": "ring"}) == "", "gear without a level reads nothing, not Lv.0")
	# The shops, every one of them, at every level band, for every class.
	for e in DungeonData.SHOP:
		_item("tomb keeper", DungeonData.shop_item(String(e.id), rng))
	for e in GuildQuestData.SHOP:
		_item("guild quest shop", GuildQuestData.shop_item(e))
	for e in GuildLeague.SHOP:
		_item("league shop", GuildLeague.shop_item(e))
	for e in RewardShop.STONES:
		_item("reward stones", RewardShop.stone_item(e))
	var shop := ShopScreen.new()
	for cls in ClassData.IDS:
		Game.new_profile(cls, "Icon QA", FaceKit.default_look())
		for level in [1, 7, 16, 40, 70, 100]:
			Game.profile.level = level
			for item in shop._stock():
				_item("merchant Lv.%d" % level, item)
		for spec in StallStock.KINDS:
			for level in [5, 40, 100]:
				for lot in StallStock.lots_for("icons|%s|%d" % [spec, level], spec, level, 200 if level == 100 else 0, cls):
					_item("stall %s" % spec, lot.get("item", lot))
		for r in 5:
			_item("wings", ItemData.wings(rng, String(cls), r))
			for slot in ItemData.SLOTS:
				_item("drop", ItemData.generate(1 + r * 24, cls, rng, r, slot))
		for stars in StarProgression.TIERS:
			_item("star gear", StarProgression.random_item(cls, stars, rng))
		for boss in [false, true]:
			for x in DivineGearData.drops(cls, boss, true, rng):
				_item("divine", x)
			for x in EndgameFields.kill_drops(cls, boss, true, 1.0, rng):
				_item("endgame", x)
			for x in EndgameFields.supply_drops(boss, true, 1.0, rng):
				_item("endgame supply", x)
		for boss_id in BossLootData.TABLES:
			for x in BossLootData.roll_chases(boss_id, {}, 100, cls, rng):
				_item("boss chase", x)
		for piece in SetGearData.catalogue():
			if String(piece.get("set_gear", "")) == String(cls):
				_item("set 250", piece)
	shop.free()
	for i in 24:
		for lot in StallStock.full_stock(i):
			_item("world stall", lot.get("item", lot))
	for tier in range(1, DailyPass.TIERS + 1):
		for x in DailyPass.tier_reward(tier, Game.profile).items:
			_item("reward pass", x)
	for level in [20, 60, 100]:
		for first in [false, true]:
			for x in RaidData.rewards(level, 150, first, rng).items:
				_item("raid", x)
	for id in StoryChapter2.ORDER:
		for x in StoryChapter2.reward(id, rng).get("items", []):
			_item("chapter 2", x)
	# The bag grid itself: a costume and the dragon scale render icon and text.
	await _bag_tiles()
	print("ITEM ICONS: %s | %d checks, %d failures (%d items)" % ["PASS" if failures == 0 else "FAIL", checks, failures, _seen.size()])
	get_tree().quit(0 if failures == 0 else 1)


func _bag_tiles() -> void:
	Game.new_profile(&"darklord", "Bag QA", FaceKit.default_look())
	Game.profile.level = 60
	Game.profile.inv = [ItemData.jewel("dragon_scale", 5), RewardShop.costume_item("kitsune"), ItemData.generate(55, &"darklord", RandomNumberGenerator.new(), 2, "ring"), {"kind": "ticket", "id": "x"}]
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"inventory")
	await get_tree().process_frame
	var tiles: Array[Button] = []
	for entry in menu._item_buttons:
		if int(entry.index) >= 0:
			tiles.append(entry.button)
	check(tiles.size() == 4, "four bag tiles (%d)" % tiles.size())
	if tiles.size() == 4:
		check(tiles[0].icon != null and tiles[0].text == "×5", "the dragon scale tile: its icon and ×5")
		check(tiles[1].icon != null and tiles[1].text == "คอสตูม", "the costume tile: its icon, no level (%s)" % tiles[1].text)
		check(tiles[2].icon != null and tiles[2].text == "Lv.55", "gear reads its level")
		check(tiles[3].icon != null and tiles[3].text == "", "an unknown thing: an icon and no Lv.0")
	for b in tiles:
		check(not b.text.contains("Lv.0"), "no tile reads Lv.0")
	menu.close_menu()
	menu.free()
	get_tree().paused = false
