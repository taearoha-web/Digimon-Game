extends Node3D
## Mounts (สัตว์ขี่): bought with gold in the menu tab, one picked as active, saved and
## repaired with the profile. Riding adds the mount's speed and stows the weapon; an
## attack, a skill, a hit or a no-riding zone (guild war, ranked pvp, tower, arena) puts
## the hero back on foot. The HUD's "ขี่" button only shows while a mount is owned.
## godot --headless --path . res://tests/integration/mount_test.tscn
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func settle() -> void:
	for i in 3:
		await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "Mount QA", FaceKit.default_look())
	Game.profile.level = 60
	Game.profile.hp = 99999
	_data()
	_shop()
	_save()
	await _riding()
	await _menu()
	print("MOUNT: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func _data() -> void:
	check(MountData.ORDER.size() == 4, "four mounts in the shop")
	var last := 0
	for id in MountData.ORDER:
		var info := MountData.info(id)
		check(int(info.price) > last, "%s costs more than the one before" % id)
		last = int(info.price)
		check(float(info.speed) > 0.0 and float(info.speed) <= 0.5, "%s speed bonus in (0, 0.5]" % id)
		check(info.color is Color and String(info.name) != "", "%s has a name and a card colour" % id)
	for zone_id in [&"guildwar", &"pvp", &"tower", &"arena"]:
		check(not MountData.zone_allows(ZoneData.get_zone(zone_id)), "no riding in %s" % zone_id)
	for zone_id in [&"town", &"meadow"]:
		var zone := ZoneData.get_zone(zone_id)
		if not zone.is_empty():
			check(MountData.zone_allows(zone), "riding allowed in %s" % zone_id)


func _shop() -> void:
	check(Game.owned_mounts().is_empty() and Game.active_mount() == "", "a new hero owns no mount")
	Game.profile.gold = 300_000
	check(Game.buy_mount("glow_stag") != "", "500K stag refused with 300K gold")
	check(int(Game.profile.gold) == 300_000 and not Game.owns_mount("glow_stag"), "a refused buy spends nothing")
	check(Game.buy_mount("thunder_wolf") == "", "wolf bought")
	check(int(Game.profile.gold) == 100_000, "wolf cost 200K gold (left %d)" % int(Game.profile.gold))
	check(Game.active_mount() == "thunder_wolf", "the first mount bought becomes active")
	check(Game.buy_mount("thunder_wolf") != "" and int(Game.profile.gold) == 100_000, "an owned mount can't be bought twice")
	check(Game.buy_mount("no_such_mount") != "", "unknown id refused")
	Game.profile.gold = 600_000
	check(Game.buy_mount("glow_stag") == "" and int(Game.profile.gold) == 100_000, "stag bought for 500K")
	check(Game.active_mount() == "thunder_wolf", "buying a second mount keeps the active one")
	check(not Game.select_mount("griffin"), "can't pick a mount not owned")
	check(Game.select_mount("glow_stag") and Game.active_mount() == "glow_stag", "picked the stag")
	Game.select_mount("thunder_wolf")


func _save() -> void:
	var saved: Dictionary = Game.profile.duplicate(true)
	check(Game._valid_profile(saved.duplicate(true)), "a profile with mounts is a valid save")
	var bad: Dictionary = saved.duplicate(true)
	bad["mounts"] = "thunder_wolf"
	check(not Game._valid_profile(bad), "mounts must be a list")
	bad = saved.duplicate(true)
	bad["mount"] = 5
	check(not Game._valid_profile(bad), "mount must be a string")
	var odd: Dictionary = saved.duplicate(true)
	odd["mounts"] = ["thunder_wolf", "dragon_from_the_future", "thunder_wolf", "glow_stag"]
	odd["mount"] = "dragon_from_the_future"
	var fixed := Game._repair(odd)
	check(fixed.mounts == ["thunder_wolf", "glow_stag"], "repair drops unknown and doubled ids (%s)" % str(fixed.mounts))
	check(fixed.mount == "", "repair clears an active mount that isn't owned")
	var old: Dictionary = saved.duplicate(true)
	old.erase("mounts")
	old.erase("mount")
	check(Game._valid_profile(old.duplicate(true)), "an old save without mounts still loads")
	var old_fixed := Game._repair(old)
	check(old_fixed.mounts == [] and old_fixed.mount == "", "an old save gets no mounts")


func _riding() -> void:
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	await settle()
	var walk := hero.move_speed()
	check(hero.can_ride_here(), "the open field allows riding")
	check(hero.toggle_ride() and hero.is_riding(), "the ride button mounts the wolf")
	check(is_equal_approx(hero.move_speed(), walk * (1.0 + MountData.speed_bonus("thunder_wolf"))), "riding adds the wolf's +30%% (%.2f -> %.2f)" % [walk, hero.move_speed()])
	check(hero.visual.held_stowed, "the weapon is stowed while riding")
	var held_shown := 0
	for n in hero.visual._skeleton.get_children():
		if n.has_meta(&"held") and (n as Node3D).visible:
			held_shown += 1
	check(held_shown == 0, "no held piece is drawn while riding (%d)" % held_shown)
	hero._ride_step(4.0)
	check(hero.visual.current == Hero.RIDE_CLIP, "the rider sits (%s)" % hero.visual.current)
	check(hero.visual.anim.has_animation(Hero.RIDE_CLIP), "the riding clip exists on the hero model")
	Game.select_mount("glow_stag")
	check(hero.mount != null and hero.mount.id == "glow_stag", "picking another mount swaps the ridden body")
	check(is_equal_approx(hero.move_speed(), walk * 1.35), "the stag's +35%")
	check(not hero.toggle_ride() and not hero.is_riding(), "the ride button again gets off")
	check(is_equal_approx(hero.move_speed(), walk), "on foot the speed is back")
	check(not hero.visual.held_stowed, "the weapon comes back on foot")
	# Anything that fights puts the hero back on foot.
	hero.ride()
	hero.tap_attack()
	check(not hero.is_riding(), "attacking dismounts")
	hero.ride()
	hero.use_skill(0)
	check(not hero.is_riding(), "a skill dismounts")
	hero.ride()
	hero.take_damage(5.0)
	check(not hero.is_riding(), "a hit dismounts")
	hero.ride()
	hero.set_auto(true)
	check(not hero.is_riding(), "auto hunting dismounts")
	hero.set_auto(false)
	# No-riding zones: can't get on, and riding into one puts the hero down.
	for zone_id in [&"guildwar", &"pvp", &"tower", &"arena"]:
		hero.field = field
		hero.ride()
		check(hero.is_riding(), "riding before %s" % zone_id)
		var zone := Zone.new()
		zone.data = ZoneData.get_zone(zone_id)
		hero.field = zone
		check(not hero.can_ride_here(), "%s forbids riding" % zone_id)
		hero.set_physics_process(true)
		await get_tree().physics_frame
		await get_tree().physics_frame
		hero.set_physics_process(false)
		check(not hero.is_riding(), "entering %s dismounts" % zone_id)
		check(not hero.ride(true), "can't mount in %s" % zone_id)
		hero.field = field
		zone.free()
	# The HUD button: hidden without a mount, "ขี่" / "ลง" with one.
	var hud := HUD.new()
	add_child(hud)
	hud.set_process(false)
	hud.hero = hero
	hud._update_mount_row()
	check(hud.mount_chip_text() == "ขี่", "HUD shows ขี่ with a mount (%s)" % hud.mount_chip_text())
	hud.tap_mount()
	check(hero.is_riding() and hud.mount_chip_text() == "ลง", "tapping ขี่ rides, the chip says ลง")
	hud.tap_mount()
	check(not hero.is_riding() and hud.mount_chip_text() == "ขี่", "tapping ลง gets off")
	var keep: Dictionary = Game.profile.duplicate(true)
	Game.profile["mounts"] = []
	Game.profile["mount"] = ""
	hud._update_mount_row()
	check(hud.mount_chip_text() == "" and not hud._mount_row.visible, "HUD button hidden without a mount")
	Game.profile["mounts"] = keep.mounts
	Game.profile["mount"] = keep.mount
	hud.queue_free()
	field.queue_free()
	await settle()


func _menu() -> void:
	Game.profile["mounts"] = []
	Game.profile["mount"] = ""
	Game.profile.gold = 250_000
	var menu := GameMenu.new()
	add_child(menu)
	var ids: Array = []
	for tab in GameMenu.TABS:
		ids.append(String(tab[0]))
	check(ids.has("mounts"), "the menu has a สัตว์ขี่ tab")
	menu.open_menu(&"mounts")
	await settle()
	var cards: Array = []
	for id in MountData.ORDER:
		var card := menu._content.find_child("Mount_" + id, true, false)
		cards.append(card)
		check(card != null, "card for %s" % id)
	var wolf_buy := (cards[0] as Node).find_child("Buy", true, false) as Button
	var stag_buy := (cards[1] as Node).find_child("Buy", true, false) as Button
	check(wolf_buy != null and not wolf_buy.disabled, "the wolf can be bought with 250K")
	check(stag_buy != null and stag_buy.disabled, "the stag's buy button is off with too little gold")
	check((cards[0] as Node).find_child("Colour", true, false) is ColorRect, "each card has its colour")
	wolf_buy.pressed.emit()
	await settle()
	check(Game.owns_mount("thunder_wolf") and int(Game.profile.gold) == 50_000, "menu buy spends 200K and owns the wolf")
	var wolf_card := menu._content.find_child("Mount_thunder_wolf", true, false)
	check(wolf_card != null and wolf_card.find_child("Buy", true, false) == null and wolf_card.find_child("Select", true, false) == null, "the active wolf has no buy or pick button")
	Game.profile.gold = 600_000
	Game.buy_mount("glow_stag")
	menu._rebuild()
	await settle()
	var pick := menu._content.find_child("Mount_glow_stag", true, false).find_child("Select", true, false) as Button
	check(pick != null, "an owned, inactive mount has a pick button")
	if pick != null:
		pick.pressed.emit()
		await settle()
	check(Game.active_mount() == "glow_stag", "menu pick makes the stag active")
	menu.close_menu()
	menu.queue_free()
	await settle()
