extends Node3D
## The finisher ultimate (AscendSkillData.FINISHERS: the Muay Thai ★500 หมัดบรมครูเทวะ): one
## blow at the end of a longer wind-up instead of the god skill's four waves and finale,
## with the SAME total multiplier (the waves' 13% shares and the finale's rest together),
## the same stun / burn / combo power (a god skill's five contacts are the control: they
## add up to its whole multiplier too); the hero dashes in first, never more than its dash,
## never into the struck body, stopped by walls, and not at all with nothing aimed or once
## it has fallen. Every other ultimate keeps its waves. Its art draws and frees itself.
##   godot --headless --path . res://tests/integration/ascend_finisher_test.tscn
const ID := "heavenly_master_fist"
var checks := 0
var failures := 0


class RecHero:
	extends Hero
	## Per struck mob: the multipliers of its contacts.
	var log := {}
	func _deal(mob: Mob, mult: float, color: Color, vfx: StringName, melee: bool, skill := {}) -> void:
		var key := mob.get_instance_id()
		var list: Array = log.get(key, [])
		list.append(mult)
		log[key] = list
		super._deal(mob, mult, color, vfx, melee, skill)


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func profile(cls: StringName) -> void:
	Game.new_profile(cls, "Finisher QA")
	Game.profile.level = 100
	Game.profile.adv = JobData.ASCEND_ADV
	Game.profile.paragon = {"level": JobData.ASCEND_STARS, "points": JobData.ASCEND_STARS, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 0}
	Game.profile.party = []
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = StarProgression.item(cls, 100 if slot == "wings" else 200, slot, Game.rng)
	Game.profile.hp = 100000
	Game.profile.mp = 100000


func _ready() -> void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	GameSettings.ult_cutin = false
	ZoneData.ensure()
	_data()
	await _totals()
	await _dash()
	GameSettings.quality = 2
	Engine.time_scale = 1.0
	Game.has_profile = false
	print("ASCEND FINISHER: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


func _data() -> void:
	var ult := ClassData.find_skill(&"muaythai", ID)
	var god := ClassData.find_skill(&"muaythai", "three_realms_fist")
	check(AscendSkillData.is_finisher(ult) and StarSkillData.is_god(ult), "the ultimate is a god-tier finisher")
	check(AscendSkillData.god_beats(ult) == [0.0], "one beat")
	check(float(ult.hit_delay) >= 1.8 and float(ult.hit_delay) <= 2.2 and float(ult.hit_delay) > float(god.hit_delay), "a heavier, slower wind-up (%.2f s)" % float(ult.hit_delay))
	check(String(ult.shape) == "blast" and float(ult.radius) >= 10.0 and float(ult.get("dash", 0.0)) > 0.0, "lands on the aimed point, wide, with a dash")
	var base_god: Dictionary = StarSkillData.pool(&"muaythai")[4]
	check(absf(float(ult.mult) - float(base_god.mult) * AscendSkillData.ULT_POWER) < 0.001, "the same total multiplier as before (%.2f)" % float(ult.mult))
	check(float(ult.fx.stun) == 2.0 and ult.fx.burn == [0.5, 6.0] and float(ult.fx.combo_power) == 0.025, "stun 2 s, burn 6 s, combo power kept")
	check(not AscendSkillData.is_finisher(god) and not god.has("dash"), "the ★300 god skill is no finisher")
	for cls in ClassData.IDS:
		var other := ClassData.find_skill(cls, String(AscendSkillData.IDS[cls][0]))
		if String(other.id) == ID:
			continue
		check(not AscendSkillData.is_finisher(other) and AscendSkillData.god_beats(other) == StarSkillData.GOD_BEATS and not other.has("dash"), "%s keeps its waves" % other.id)


func _field(hero_at: Vector3, mob_spots: Array) -> Array:
	var field := Node3D.new()
	add_child(field)
	var camera := Camera3D.new()
	camera.fov = 40.0
	field.add_child(camera)
	camera.position = Vector3(0, 16, 15)
	camera.look_at(Vector3(0, 1, 0))
	camera.make_current()
	var hero := RecHero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.position = hero_at
	var mobs: Array[Mob] = []
	for spot in mob_spots:
		var mob := Mob.new()
		mob.setup(&"dawn_stag", 100, spot, hero)
		mob.position = spot
		field.add_child(mob)
		mob.set_physics_process(false)
		mob.hp = 100000000
		mob.max_hp = mob.hp
		mobs.append(mob)
	hero.target = mobs[0] if not mobs.is_empty() else null
	return [field, hero, mobs]


## Casts [param id] and runs it to its end; returns the cast's frames.
func _run(hero: Hero, id: String, cls: StringName, speed := 3.0) -> void:
	hero._cast(ClassData.find_skill(cls, id))
	var seq := hero.get_node_or_null("StarCast_" + id)
	check(seq != null, "%s cast starts" % id)
	Engine.time_scale = speed
	var frames := 0
	while is_instance_valid(seq) and not seq.is_queued_for_deletion() and frames < 3000:
		await get_tree().process_frame
		frames += 1
	Engine.time_scale = 1.0


## The single blow carries the full multiplier, once per foe: what the god skill's five
## contacts add up to (its control case below) and what the four waves and the finale of
## the ultimate added up to before.
func _totals() -> void:
	for pair in [[&"muaythai", ID, 1], [&"warrior", "divine_edict", 5], [&"warrior", "emperor_heavensword", 5]]:
		var cls: StringName = pair[0]
		var id: String = pair[1]
		profile(cls)
		var parts := _field(Vector3(-4, 0, 0), [Vector3(1.5, 0, 0), Vector3(2.5, 0, -1.6), Vector3(2.3, 0, 1.8)])
		var field: Node3D = parts[0]
		var hero: RecHero = parts[1]
		var mobs: Array = parts[2]
		if String(ClassData.find_skill(cls, id).shape) == "burst":
			hero.position = Vector3(0, 0, 0)
		await get_tree().process_frame
		var skill := hero._ranked(ClassData.find_skill(cls, id))
		var full := float(skill.mult) * hero.rank_mult(skill)
		await _run(hero, id, cls)
		for mob in mobs:
			var list: Array = hero.log.get(mob.get_instance_id(), [])
			var total := 0.0
			for m in list:
				total += float(m)
			check(list.size() == int(pair[2]), "%s: %d contact(s) on a foe (%d)" % [id, int(pair[2]), list.size()])
			check(absf(total - full) <= full * 0.01, "%s: the contacts add up to the whole multiplier (%.3f of %.3f)" % [id, total, full])
		if id == ID:
			# The old plan of the same ultimate: four 13% waves and the finale's rest.
			var old := full * (StarSkillSequence.GOD_WAVE_SHARE * 4.0 + (1.0 - StarSkillSequence.GOD_WAVE_SHARE * 4.0))
			var list: Array = hero.log.get(mobs[0].get_instance_id(), [0.0])
			check(absf(float(list[0]) - old) <= old * 0.01, "the one blow equals the old waves + finale total (%.3f vs %.3f)" % [float(list[0]), old])
		await get_tree().create_timer(2.0).timeout
		var left := 0
		for node in field.get_children():
			if (node is StarSkillArt or node is SculptureArt) and String(node.name).contains(id):
				left += 1
		check(left == 0, "%s art frees itself (%d left)" % [id, left])
		field.queue_free()
		await field.tree_exited
		await get_tree().process_frame
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "%s budget back %s" % [id, VfxBudget.counters()])


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


## The dash: towards the aimed foe, stopping before it, capped, stopped by a wall, none
## with nothing aimed, none once the hero has fallen.
func _dash() -> void:
	var reach := float(ClassData.find_skill(&"muaythai", ID).dash)
	# An open field: the hero runs up to the foe and stops in front of it.
	profile(&"muaythai")
	var parts := _field(Vector3(-5, 0, 0), [Vector3(4, 0, 0)])
	var hero: RecHero = parts[1]
	var mob: Mob = parts[2][0]
	await get_tree().physics_frame
	var start := hero.global_position
	await _run(hero, ID, &"muaythai", 1.0)
	var moved := _flat(hero.global_position - start).length()
	var gap := _flat(mob.global_position - hero.global_position).length()
	check(moved > 4.0 and moved <= reach + 0.05, "the hero dashes in (%.2f m of at most %.1f)" % [moved, reach])
	check(gap >= 1.0, "and stops in front of the foe, not inside it (%.2f m)" % gap)
	check(absf(hero.global_position.z) < 0.1, "straight at the foe")
	check(hero.log.has(mob.get_instance_id()), "the blow lands")
	parts[0].queue_free()
	await parts[0].tree_exited
	# A foe far away: never more than the dash.
	profile(&"muaythai")
	parts = _field(Vector3(-12, 0, 0), [Vector3(12, 0, 0)])
	hero = parts[1]
	await get_tree().physics_frame
	start = hero.global_position
	await _run(hero, ID, &"muaythai", 2.0)
	moved = _flat(hero.global_position - start).length()
	check(moved <= reach + 0.05 and moved > reach - 0.5, "a far foe: the dash is capped (%.2f m)" % moved)
	parts[0].queue_free()
	await parts[0].tree_exited
	# A wall between: the hero stops at it, never through it.
	profile(&"muaythai")
	parts = _field(Vector3(-5, 0, 0), [Vector3(4, 0, 0)])
	hero = parts[1]
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 4.0, 8.0)
	shape.shape = box
	wall.add_child(shape)
	parts[0].add_child(wall)
	wall.global_position = Vector3(-1.0, 1.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _run(hero, ID, &"muaythai", 1.0)
	check(hero.global_position.x < -1.0, "a wall stops the dash (x %.2f)" % hero.global_position.x)
	parts[0].queue_free()
	await parts[0].tree_exited
	# Nothing aimed: no dash.
	profile(&"muaythai")
	parts = _field(Vector3(-5, 0, 0), [])
	hero = parts[1]
	await get_tree().physics_frame
	start = hero.global_position
	await _run(hero, ID, &"muaythai", 2.0)
	check(_flat(hero.global_position - start).length() < 0.05, "nothing aimed: the hero stays")
	parts[0].queue_free()
	await parts[0].tree_exited
	# The hero falls before the dash: it never moves, and the art goes at once.
	profile(&"muaythai")
	parts = _field(Vector3(-5, 0, 0), [Vector3(4, 0, 0)])
	hero = parts[1]
	await get_tree().physics_frame
	start = hero.global_position
	hero._cast(ClassData.find_skill(&"muaythai", ID))
	await get_tree().create_timer(0.8).timeout
	hero._dead = true
	await get_tree().create_timer(2.0).timeout
	check(_flat(hero.global_position - start).length() < 0.05, "a fallen hero does not dash")
	var left := 0
	for node in parts[0].get_children():
		if (node is StarSkillArt or node is SculptureArt) and String(node.name).contains(ID):
			left += 1
	check(left == 0, "the art leaves with the cut-short cast (%d left)" % left)
	hero._dead = false
	parts[0].queue_free()
	await parts[0].tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "dash cases: budget back %s" % VfxBudget.counters())
