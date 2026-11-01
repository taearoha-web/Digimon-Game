extends Node3D
## Loot magnet (LootDrop): every drop the hero earned flies to the hero from anywhere in
## the zone on a short arc (LootDrop.FLY_MIN-FLY_MAX seconds) and is collected; a world
## player's kill drops nothing for the hero; an item the full bag can't take waits on
## the ground (a throttled toast) and flies over once there is room; a stack of jewels
## still joins its stack; a dead hero is not served; sparkles and sounds are capped
## per moment (VfxBudget stays inside its limits with a pile of drops).
## godot --headless --path . res://tests/integration/loot_magnet_test.tscn
var checks := 0
var failures := 0
var zone: Zone
var toasts: Array = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "Magnet QA", FaceKit.default_look())
	Game.profile.level = 30
	Game.profile.party = []
	Game.toast.connect(func(text: String, _kind: StringName): toasts.append(text))
	zone = Zone.new()
	zone.zone_id = &"meadow"
	add_child(zone)
	await get_tree().process_frame
	zone.hero.set_physics_process(false)
	for node in get_tree().get_nodes_in_group("mobs"):
		(node as Node).queue_free()
	await get_tree().process_frame
	await _far_drops()
	await _pile()
	await _bag_full()
	await _dead_hero()
	_world_kill()
	_fx_cap()
	print("LOOT MAGNET: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func far_spot() -> Vector3:
	var r := float(zone.hero.field_radius) * 0.9
	return zone.hero.global_position + Vector3(r * 0.7, 0, -r * 0.7)


## The newest LootDrop children of the zone after a spawn.
func drops() -> Array:
	return zone.get_children().filter(func(c): return c is LootDrop and not c.is_queued_for_deletion())


## Waits until `drop` is gone (or `limit` seconds); returns [gone, seconds it flew].
func wait_collect(drop: LootDrop, limit := 4.0) -> Array:
	var ref: WeakRef = weakref(drop)
	var start := Time.get_ticks_msec()
	var lift := -1
	while Time.get_ticks_msec() - start < int(limit * 1000.0):
		await get_tree().process_frame
		var d := ref.get_ref() as LootDrop
		if d == null or d.is_queued_for_deletion():
			var flown := float(Time.get_ticks_msec() - lift) / 1000.0 if lift >= 0 else -1.0
			return [true, flown]
		if lift < 0 and d._magnet:
			lift = Time.get_ticks_msec()
	return [false, -1.0]


func _far_drops() -> void:
	var spot := far_spot()
	check(spot.distance_to(zone.hero.global_position) > 40.0, "the far spot is far (%.0f m)" % spot.distance_to(zone.hero.global_position))
	var item := ItemData.generate(30, &"warrior", RandomNumberGenerator.new(), 2, "armor")
	var bag: int = Game.profile.inv.size()
	zone._spawn_loot(item, 0, spot)
	var drop: LootDrop = drops().back()
	check(drop != null and drop.hero == zone.hero, "the drop belongs to the hero")
	var got := await wait_collect(drop)
	check(bool(got[0]), "gear dropped far away in the field reaches the hero and is collected")
	check(Game.profile.inv.size() == bag + 1 and Game.profile.inv.has(item), "the gear is in the bag")
	check(float(got[1]) > 0.0 and float(got[1]) <= LootDrop.FLY_MAX + 0.25, "the flight is short (%.2f s)" % float(got[1]))
	var gold := int(Game.profile.gold)
	zone._spawn_loot({}, 777, spot)
	got = await wait_collect(drops().back())
	check(bool(got[0]) and int(Game.profile.gold) == gold + 777, "far gold is collected (+777)")
	var chaos := Game.jewel_count("chaos")
	zone._spawn_loot(ItemData.jewel("chaos"), 0, spot)
	got = await wait_collect(drops().back())
	check(bool(got[0]) and Game.jewel_count("chaos") == chaos + 1, "a far chaos jewel is collected")
	zone._spawn_loot(ItemData.jewel("wolf_fang"), 0, spot)
	got = await wait_collect(drops().back())
	check(bool(got[0]) and Game.jewel_count("wolf_fang") == 1, "a far mount material is collected")


## A boss-sized pile at once: everything arrives, the effect budget holds.
func _pile() -> void:
	var spot := far_spot()
	var gold := int(Game.profile.gold)
	var purple := Game.jewel_count("purple")
	for i in 30:
		zone._spawn_loot(ItemData.jewel("purple"), 0, spot + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
		zone._spawn_loot({}, 10, spot)
	var peak := 0
	var start := Time.get_ticks_msec()
	while not drops().is_empty() and Time.get_ticks_msec() - start < 5000:
		peak = maxi(peak, int(VfxBudget.counters().particles))
		await get_tree().process_frame
	check(drops().is_empty(), "a pile of 60 drops is all collected")
	check(Game.jewel_count("purple") == purple + 30 and int(Game.profile.gold) == gold + 300, "every jewel and coin of the pile arrived")
	check(peak <= VfxBudget.particle_limit(), "the pile stays inside the particle budget (%d / %d)" % [peak, VfxBudget.particle_limit()])


func _bag_full() -> void:
	var rng := RandomNumberGenerator.new()
	Game.add_item(ItemData.jewel("pink"))
	while Game.inventory_free() > 0:
		Game.add_item(ItemData.generate(10, &"warrior", rng, 0, "boots"))
	toasts.clear()
	LootDrop._full_toast_at = -100.0
	var item := ItemData.generate(30, &"warrior", rng, 2, "helm")
	zone._spawn_loot(item, 0, far_spot())
	var drop: LootDrop = drops().back()
	var keep_ref: WeakRef = weakref(drop)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1800:
		await get_tree().process_frame
	check(keep_ref.get_ref() != null and not drop._magnet, "with the bag full the gear stays on the ground")
	check(not Game.profile.inv.has(item), "the gear is not in the full bag")
	check(toasts.any(func(t): return String(t).contains("กระเป๋าเต็ม")), "a bag-full toast says so (%s)" % str(toasts))
	var said := toasts.filter(func(t): return String(t).contains("กระเป๋าเต็ม")).size()
	check(said == 1, "the bag-full toast is not spammed (%d)" % said)
	# A stack the bag already holds still flies in.
	var pink := Game.jewel_count("pink")
	check(pink > 0 and Game.inventory_free() == 0, "the full bag holds a pink stack")
	zone._spawn_loot(ItemData.jewel("pink"), 0, far_spot())
	var got := await wait_collect(drops().back())
	check(bool(got[0]) and Game.jewel_count("pink") == pink + 1, "a jewel joins its stack in a full bag")
	# Room again: the waiting gear flies over.
	Game.profile.inv.remove_at(Game.profile.inv.size() - 1)
	got = await wait_collect(drop)
	check(bool(got[0]) and Game.profile.inv.has(item), "once a slot is free the waiting gear is collected")


func _dead_hero() -> void:
	zone.hero._dead = true
	zone._spawn_loot({}, 5, far_spot())
	var drop: LootDrop = drops().back()
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1500:
		await get_tree().process_frame
	check(is_instance_valid(drop) and not drop._magnet, "nothing flies to a fallen hero")
	zone.hero._dead = false
	var got := await wait_collect(drop)
	check(bool(got[0]), "back on its feet the hero gets the drop")


## A monster a world player mostly killed drops nothing for the hero.
func _world_kill() -> void:
	var mob := Mob.new()
	mob.setup(&"slime", 5, far_spot(), zone.hero)
	zone.add_child(mob)
	mob.party_damage = 10
	mob.others_damage = 90
	var before := drops().size()
	zone._on_mob_died(mob)
	check(drops().size() == before, "a world player's kill leaves no loot for the hero")
	mob.queue_free()


func _fx_cap() -> void:
	LootDrop._fx_window = Time.get_ticks_msec() * 0.001
	LootDrop._fx_used = 0
	var allowed := 0
	for i in 20:
		if LootDrop.take_fx():
			allowed += 1
	check(allowed == LootDrop.FX_PER_BURST, "pickup sparkles are capped per moment (%d)" % allowed)
