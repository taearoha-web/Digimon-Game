extends Node3D
## The Dark Lord's raven dresses for the scepter (DarkRaven.look_for): every weapon
## class gives its look, a weapon swap rebuilds the bird (and only a look change
## does), the quality setting turns the glow, extras and stardust on and off, and
## nothing is left behind: nodes, objects and VfxBudget reservations return to
## where they started. Also the real Hero (equip / unequip) and an AI Lord's raven
## (RivalVisual).

## Stands in for the Lord that owns the raven (DarkRaven reads `visual`).
class Lord extends Node3D:
	var visual: Node3D

	func raven_target() -> Mob:
		return null

	func raven_strike(_mob: Mob, _group := false) -> void:
		pass

	func is_dead() -> bool:
		return false

var failures := 0
var checks := 0


func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", why)


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	MemoryGuard.pressure = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a := &"darklord"
	var L := DarkRaven.Look
	# Every weapon class: the ten scepter tiers, the four star tiers, divine, none.
	var cases: Array = [[null, L.PLAIN]]
	for level in [1, 15, 25, 35, 45, 55, 65, 75, 85, 95, 100]:
		var tier := ItemData.tier_for(level)
		var want: int = L.PLAIN if tier < 4 else (L.CROWN if tier >= 9 else L.FIRE + tier - 4)
		cases.append([ItemData.generate(level, a, rng, 2, "weapon"), want])
	for stars in [50, 100, 150, 200]:
		cases.append([StarProgression.item(a, stars, "weapon", rng), L.STAR_50 + StarGearData.index(stars)])
	cases.append([DivineGearData.item(a, "weapon", rng), L.DIVINE])
	for c in cases:
		check(DarkRaven.look_for(c[0]) == int(c[1]), "look_for %s -> %s (got %s)" % [ItemLook.look_of(c[0]) if c[0] is Dictionary else "none", DarkRaven.LOOK_NAMES[c[1]], DarkRaven.LOOK_NAMES[DarkRaven.look_for(c[0])]])
	check(DarkRaven.look_for({}) == L.PLAIN, "an empty weapon slot is the plain raven")
	check(DarkRaven.LOOK_NAMES.size() == L.size(), "every look has a name")
	# A raven on a stand-in Lord, its weapon swapped through every class three times.
	var lord := Lord.new()
	add_child(lord)
	var hv := HeroVisual.new()
	lord.add_child(hv)
	hv.setup(a, "", true, {}, FaceKit.default_look())
	lord.visual = hv
	var raven := DarkRaven.ensure(lord)
	await get_tree().process_frame
	check(raven.look == L.PLAIN and raven.fancy, "starts as the plain raven at high quality")
	var plain_nodes := _count(raven)
	var nodes_per_look := {}
	var objects_after := []
	for cycle in 3:
		for c in cases:
			var before_root := raven._root
			var before_look := raven.look
			hv.set_equipment({"weapon": c[0]} if c[0] != null else {})
			await get_tree().process_frame
			var want := int(c[1])
			check(raven.look == want, "cycle %d: swap gives %s (got %s)" % [cycle, DarkRaven.LOOK_NAMES[want], DarkRaven.LOOK_NAMES[raven.look]])
			check((raven._root != before_root) == (want != before_look), "cycle %d: rebuilt only when the look changes (%s)" % [cycle, DarkRaven.LOOK_NAMES[want]])
			check(raven._wings.size() == 2 and raven._hands.size() == 2 and raven._feet.size() == 2 and raven._tail_feathers.size() == 5, "parts kept after a rebuild")
			check(raven.get_children().filter(func(n: Node): return n.name.begins_with("Raven")).size() == 1, "one bird after a rebuild")
			var n := _count(raven)
			if cycle == 0:
				nodes_per_look[want] = n
			else:
				check(int(nodes_per_look.get(want, -1)) == n, "cycle %d: %s rebuilds to the same %d nodes (got %d)" % [cycle, DarkRaven.LOOK_NAMES[want], int(nodes_per_look.get(want, -1)), n])
			var dust_wanted := int(DarkRaven.palette(want).dust) > 0
			check((raven._dust != null) == dust_wanted, "stardust only on star and divine looks (%s)" % DarkRaven.LOOK_NAMES[want])
			check(int(VfxBudget.counters().decorations) == (1 if dust_wanted else 0), "stardust holds one decoration while worn (%s): %s" % [DarkRaven.LOOK_NAMES[want], VfxBudget.counters()])
			# Every pose of the flight with this look: no errors, the extras animate.
			for pose in ["perch", "glide", "flap", "stoop", "strike", "land"]:
				raven._clock += 0.05
				raven._animate(0.05, pose)
		objects_after.append(Performance.get_monitor(Performance.OBJECT_COUNT))
		check(raven.look == L.DIVINE, "ends the cycle on the divine look")
	check(int(nodes_per_look[L.PLAIN]) == plain_nodes, "the plain raven has the same nodes as before any swap")
	check(int(nodes_per_look[L.DIVINE]) > int(nodes_per_look[L.CROWN]) and int(nodes_per_look[L.CROWN]) > plain_nodes, "the grander looks add parts")
	check(absf(float(objects_after[2]) - float(objects_after[1])) < 8.0, "objects stable across swap cycles: %s" % [objects_after])
	# The flight with stardust allocates no objects frame to frame.
	raven.state = DarkRaven.State.FLY
	for i in 30:
		raven._clock += 0.016
		raven.global_position += Vector3(0.15, 0, 0)
		raven._animate(0.016, "glide")
	var steady := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 120:
		raven._clock += 0.016
		raven.global_position += Vector3(0.15, 0, 0)
		raven._animate(0.016, "glide")
	check(Performance.get_monitor(Performance.OBJECT_COUNT) == steady, "no objects made while flying with stardust")
	raven.state = DarkRaven.State.RETURN
	# Low quality: the same look without glow, extras or stardust, back when it rises.
	GameSettings.quality = 0
	await get_tree().process_frame
	check(not raven.fancy and raven._dust == null and raven._glow == null and raven._fx.is_empty(), "low quality drops the glow, extras and stardust")
	check(int(VfxBudget.counters().decorations) == 0, "low quality frees the stardust decoration")
	check(raven.look == L.DIVINE, "low quality keeps the look")
	GameSettings.quality = 2
	await get_tree().process_frame
	check(raven.fancy and raven._dust != null and not raven._fx.is_empty(), "high quality brings them back")
	# Memory pressure counts as low.
	MemoryGuard.pressure = 2
	await get_tree().process_frame
	check(not raven.fancy and raven._dust == null, "memory pressure drops the stardust")
	MemoryGuard.pressure = 0
	await get_tree().process_frame
	# Budget spent: the bird is built without its stardust and picks it up later.
	hv.set_equipment({})
	await get_tree().process_frame
	var slots := Node.new()
	add_child(slots)
	while VfxBudget.can_decorate():
		var slot := Node.new()
		slots.add_child(slot)
		VfxBudget.track_decoration(slot)
	hv.set_equipment({"weapon": cases[cases.size() - 2][0]})
	await get_tree().process_frame
	check(raven.look == L.STAR_200 and raven._dust == null, "spent budget: no stardust")
	slots.free()
	for i in 3:
		raven._dust_retry = 0.0
		await get_tree().process_frame
	check(raven._dust != null, "the stardust comes once the budget frees up")
	lord.queue_free()
	await lord.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "budget released with the raven: %s" % [VfxBudget.counters()])
	# An AI Dark Lord (arena rival / guild fighter): the raven finds the HeroVisual in its RivalVisual.
	var ai := Lord.new()
	add_child(ai)
	var rv := RivalVisual.new()
	ai.add_child(rv)
	var star: Dictionary = cases[cases.size() - 2][0]
	rv.setup_rival(a, {"weapon": star}, FaceKit.default_look())
	ai.visual = rv
	var ai_raven := DarkRaven.ensure(ai)
	await get_tree().process_frame
	check(ai_raven.look == L.STAR_200, "an AI Lord's raven wears its scepter's look")
	check(ai_raven.global_position.distance_to(rv.hero_visual.perch_point()) < 0.05, "an AI Lord's raven sits on its arm")
	ai.queue_free()
	await ai.tree_exited
	# The real Hero: equip and unequip through the profile.
	Game.new_profile(a, "Raven Test", {"gender": 0})
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero._sync_raven()
	await get_tree().process_frame
	check(hero.raven != null, "the Dark Lord hero has a raven")
	for c in [cases[5], cases[cases.size() - 1], [null, L.PLAIN], cases[10]]:
		if c[0] == null:
			Game.profile.equip.erase("weapon")
		else:
			Game.profile.equip["weapon"] = c[0]
		hero._on_inventory_changed()
		await get_tree().process_frame
		check(hero.raven.look == int(c[1]), "hero equip gives %s (got %s)" % [DarkRaven.LOOK_NAMES[c[1]], DarkRaven.LOOK_NAMES[hero.raven.look]])
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("dark_ravens").is_empty(), "no raven left behind")
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "budget released at the end: %s" % [VfxBudget.counters()])
	print("RAVEN LOOKS: %s | %d looks, %d checks, %d failures, nodes plain %d crown %d divine %d" % ["PASS" if failures == 0 else "FAIL",
		nodes_per_look.size(), checks, failures, plain_nodes, int(nodes_per_look[L.CROWN]), int(nodes_per_look[L.DIVINE])])
	get_tree().quit(failures)


func _count(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _count(child)
	return n
