extends Node3D
## Real Hero/Companion casts plus the shared gameplay clock. Use isolated user data.
## godot --headless --fixed-fps 60 --path . res://tests/integration/armageddon_test.tscn
## Rendered GL verification: omit --headless, retaining --fixed-fps 60.
## This accelerated fixture uses time_scale 8. A variable software-render frame
## can otherwise skip an entire assertion window while all damage remains valid.
## Fixed 60 FPS bounds simulation steps to 0.133 s and preserves every assertion.

class RecordingMob extends Mob:
	var amounts: Array[int] = []
	var burn_applications := 0

	func take_hit(amount: int, critical: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		amounts.append(amount)
		return super.take_hit(amount, critical, color, attacker)

	func apply_burn(dps: float, seconds: float) -> void:
		burn_applications += 1
		super.apply_burn(dps, seconds)

	func knock_back(_from: Vector3, _strength := 2.5) -> void:
		pass # A stationary training dummy makes every overlapping hit observable.


class ClockCaster extends Node3D:
	var dead := false

	func is_dead() -> bool:
		return dead


class ObservedCamera extends ThirdPersonCamera:
	var sampled_frames := 0
	var disturbed_frames := 0

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		sampled_frames += 1
		if not is_equal_approx(camera.fov, base_fov) or not is_zero_approx(camera.h_offset) or not is_zero_approx(camera.v_offset) or not is_equal_approx(_arm.spring_length, distance):
			disturbed_frames += 1


var checks := 0
var failures: Array[String] = []
var sequence_hits := 0


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		printerr("FAIL: ", detail)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	var old_quality := GameSettings.quality
	var old_time_scale := Engine.time_scale
	# Only accelerates this test fixture. Cadence is measured on the game's clock.
	Engine.time_scale = 8.0
	await _actual_cast(false, 1, false)
	await _actual_cast(false, 5, false)
	await _actual_cast(true, 1, false)
	await _actual_cast(false, 5, true)
	await _actual_death(false, false)
	await _actual_death(false, true)
	await _actual_death(true, false)
	await _actual_death(true, true)
	await _windup_lifecycle(false)
	await _windup_lifecycle(true)
	await _clock_and_pause()
	await _unload_and_reparent()
	GameSettings.quality = old_quality
	Engine.time_scale = old_time_scale
	get_tree().paused = false
	_stop_audio()
	check(_empty_budget(), "all test fields release temporary visual reservations")
	print("ARMAGEDDON: %s | %d checks, %d observed sequence hits, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, sequence_hits, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)


func _fixture(rank := 1) -> Dictionary:
	Game.new_profile(&"mage", "Armageddon QA", {"gender": 0})
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.skills["armageddon"] = rank
	Game.profile.loadout[0] = "armageddon"
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	var field := Node3D.new()
	field.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.position = Vector3(-5, 0, 0)
	hero.set_physics_process(false)
	hero.stats.atk = 100.0
	hero.stats.crit = 0.0
	hero.stats.haste = 0.0
	var near := _dummy(field, hero, Vector3.ZERO)
	var outside := _dummy(field, hero, Vector3(50, 0, 0))
	hero.target = near
	var camera := ObservedCamera.new()
	camera.target = hero
	camera.combat_focus = near
	field.add_child(camera)
	hero.camera_rig = camera
	return {"field": field, "hero": hero, "near": near, "outside": outside, "camera": camera}


func _dummy(field: Node3D, hero: Hero, at: Vector3) -> RecordingMob:
	var mob := RecordingMob.new()
	mob.setup(&"pink_slime", 1, at, hero)
	field.add_child(mob)
	mob.position = at
	mob.hp = 10000000
	mob.max_hp = 10000000
	mob.stats.def = 0.0
	mob.set_physics_process(false)
	return mob


func _companion(fixture: Dictionary) -> Companion:
	var companion := Companion.new()
	companion.setup({"class": "mage", "name": "QA mage", "level": 100, "exp": 0, "gender": 0}, 0, fixture.hero, fixture.field)
	fixture.field.add_child(companion)
	companion.position = Vector3(-5, 0, 1)
	companion.set_physics_process(false)
	companion.target = fixture.near
	companion.stats.atk = 100.0
	companion.stats.crit = 0.0
	companion.mp = 100000.0
	return companion


func _actual_cast(use_companion: bool, rank: int, saturated: bool) -> void:
	GameSettings.quality = 0 if saturated else 2
	var fixture := _fixture(rank)
	var caster: Variant = _companion(fixture) if use_companion else fixture.hero
	var field: Node3D = fixture.field
	var near: RecordingMob = fixture.near
	var outside: RecordingMob = fixture.outside
	var label := "%s rank %d%s" % ["companion" if use_companion else "hero", rank, " saturated low" if saturated else ""]
	if saturated:
		for i in VfxBudget.decoration_limit():
			var reservation := Node.new()
			field.add_child(reservation)
			VfxBudget.track_decoration(reservation)
		for i in 8:
			VfxKit._particles(field, Vector3.ZERO, Color.WHITE, 80, 30.0)
	var skill := ClassData.find_skill(&"mage", "armageddon")
	var expected_mp := 100000.0 - (float(skill.mp) if use_companion else float(fixture.hero.mp_cost(skill)))
	var expected_cd := float(skill.cd) * 1.15 if use_companion else float(fixture.hero.cooldown_of(skill))
	var fired := {"count": 0}
	if not use_companion:
		fixture.hero.skill_fired.connect(func(_index: int): fired.count += 1)
	caster._cast(skill)
	check(is_equal_approx(float(caster.mp) if use_companion else float(Game.profile.mp), expected_mp), label + ": MP charged once at cast")
	check(is_equal_approx(float(caster.cooldowns.get("armageddon", 0.0)), expected_cd), label + ": correct initial cooldown")
	if not use_companion:
		check(fixture.hero.use_skill(0) == "cooldown", label + ": repeated button press blocked by cooldown")
	if saturated:
		await get_tree().create_timer(float(skill.hit_delay) + 0.2).timeout
		for essential_name in ["EssentialMeteorBody", "EssentialLandingWarning"]:
			var essential := field.find_child(essential_name, true, false) as MeshInstance3D
			check(essential != null, label + ": cosmetic saturation preserves " + essential_name)
			if essential:
				check(essential.visible and essential.mesh != null and essential.material_override != null,
					label + ": saturated " + essential_name + " remains renderable")
		check(int(VfxBudget.counters().decorations) == VfxBudget.decoration_limit(), label + ": essential meteor does not consume cosmetic slots")
		await get_tree().create_timer(9.5 - float(skill.hit_delay) - 0.2).timeout
	else:
		await get_tree().create_timer(9.5).timeout
	check(near.amounts.size() == 11, label + ": stationary target receives eleven real damage events, got %d" % near.amounts.size())
	check(fixture.camera.sampled_frames > 0 and fixture.camera.disturbed_frames == 0, label + ": every camera frame keeps its zoom and zero shake through all eleven impacts and target focus")
	check(outside.amounts.is_empty(), label + ": outside target receives no damage")
	check(near.burn_applications == 11, label + ": each hit applies the existing fire status")
	check(near.hp == 10000000 - _sum(near.amounts), label + ": all damage reaches real Mob HP")
	var expected_main := 100.0 * float(skill.mult) * (1.0 if use_companion else 1.0 + 0.15 * float(rank - 1))
	for i in near.amounts.size():
		var expected := expected_main * (1.0 if i == 0 else 0.12)
		check(float(near.amounts[i]) >= expected * 0.92 - 1.0 and float(near.amounts[i]) <= expected * 1.08 + 1.0,
			label + ": hit %d respects damage/rank scaling (%d, expected %.1f ±8%%)" % [i, near.amounts[i], expected])
	check(is_equal_approx(float(caster.mp) if use_companion else float(Game.profile.mp), expected_mp), label + ": fragments never charge additional MP")
	check(is_equal_approx(float(caster.cooldowns.get("armageddon", 0.0)), expected_cd), label + ": fragments never reset or extend cooldown")
	if not use_companion:
		check(fired.count == 1, label + ": exactly one skill activation")
	check(get_tree().get_nodes_in_group("armageddon_sequences").is_empty(), label + ": completed sequence retires")
	check(int(VfxBudget.counters().decorations) <= VfxBudget.decoration_limit(), label + ": decoration ceiling")
	sequence_hits += near.amounts.size()
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(_empty_budget(), label + ": unload releases all reservations")


func _actual_death(use_companion: bool, after_main: bool) -> void:
	var fixture := _fixture()
	var caster: Variant = _companion(fixture) if use_companion else fixture.hero
	var near: RecordingMob = fixture.near
	var field: Node3D = fixture.field
	var label := "%s death %s" % ["companion" if use_companion else "hero", "after impact" if after_main else "during wind-up"]
	caster._cast(ClassData.find_skill(&"mage", "armageddon"))
	if after_main:
		await get_tree().create_timer(2.2).timeout
		check(near.amounts.size() == 1, label + ": main hit happens before cancellation")
	else:
		await get_tree().create_timer(0.03).timeout
	caster._dead = true
	var count := near.amounts.size()
	await get_tree().create_timer(3.0).timeout
	check(near.amounts.size() == count, label + ": no delayed damage after caster death")
	check(get_tree().get_nodes_in_group("armageddon_sequences").is_empty(), label + ": no remaining sequence")
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame


func _clock_and_pause() -> void:
	var field := Node3D.new()
	field.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(field)
	var caster := ClockCaster.new()
	field.add_child(caster)
	var events: Array[Dictionary] = []
	var sequence := ArmageddonSequence.launch(field, caster, Vector3.ZERO, 11.0, 20.0,
		func(index: int, point: Vector3, radius: float, multiplier: float):
			events.append({"index": index, "point": point, "radius": radius, "multiplier": multiplier}), false)
	var seen_times: Array[float] = []
	sequence.impact.connect(func(_index: int, _point: Vector3, _radius: float, _multiplier: float): seen_times.append(sequence.elapsed))
	await get_tree().create_timer(0.6).timeout
	get_tree().paused = true
	var stopped_at := sequence.elapsed
	await get_tree().create_timer(0.22, true, false, true).timeout
	check(events.is_empty(), "pause before landing prevents all damage callbacks")
	check(is_equal_approx(sequence.elapsed, stopped_at), "pause freezes the gameplay sequence clock")
	get_tree().paused = false
	await sequence.impact
	check(events.size() == 1, "unpause completes main impact without skipping ahead")
	get_tree().paused = true
	stopped_at = sequence.elapsed
	await get_tree().create_timer(0.22, true, false, true).timeout
	check(events.size() == 1 and is_equal_approx(sequence.elapsed, stopped_at), "pause between hits freezes fragments")
	get_tree().paused = false
	await get_tree().create_timer(5.5).timeout
	check(events.size() == 11, "shared clock emits giant meteor and ten fragments")
	for i in events.size():
		check(int(events[i].index) == i, "impact events remain strictly ordered")
		check(absf(seen_times[i] - (1.25 + float(i) * 0.5)) < 0.2, "impact %d occurs at the designed half-second cadence (%.3f)" % [i, seen_times[i]])
		check(is_equal_approx(float(events[i].multiplier), 20.0 if i == 0 else 2.4), "main/splinter damage factors reach callback")
		check((events[i].point as Vector3).length() <= float(events[i].radius), "center target overlaps fragment area %d" % i)
	sequence_hits += events.size()
	await get_tree().create_timer(2.0).timeout
	check(not is_instance_valid(sequence), "shared sequence releases itself after the visual tail")
	field.queue_free()
	await field.tree_exited


func _windup_lifecycle(use_companion: bool) -> void:
	var fixture := _fixture()
	var field: Node3D = fixture.field
	var caster: Variant = _companion(fixture) if use_companion else fixture.hero
	var label := "companion" if use_companion else "hero"
	var replacement := _dummy(field, fixture.hero, Vector3(0.15, 0, 0))
	caster._cast(ClassData.find_skill(&"mage", "armageddon"))
	get_tree().paused = true
	await get_tree().create_timer(0.22, true, false, true).timeout
	check(get_tree().get_nodes_in_group("armageddon_sequences").is_empty(), label + ": paused wind-up never creates a running sequence")
	check(replacement.amounts.is_empty(), label + ": paused wind-up cannot deal damage")
	get_tree().paused = false
	# Targets may despawn while the cast animation is running. A weak snapshot
	# must retain the aimed point without passing a freed typed Mob to _resolve.
	fixture.near.queue_free()
	await get_tree().create_timer(9.5).timeout
	check(replacement.amounts.size() == 11, label + ": despawned target still lands all hits at the original aim")
	sequence_hits += replacement.amounts.size()
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(_empty_budget(), label + ": target-despawn cast releases visuals")
	fixture = _fixture()
	field = fixture.field
	caster = _companion(fixture) if use_companion else fixture.hero
	caster._cast(ClassData.find_skill(&"mage", "armageddon"))
	field.queue_free()
	await field.tree_exited
	await get_tree().create_timer(2.5).timeout
	check(get_tree().get_nodes_in_group("armageddon_sequences").is_empty(), label + ": unloading the field during wind-up cannot launch a stale sequence")
	check(_empty_budget(), label + ": wind-up unload releases all visuals")


func _unload_and_reparent() -> void:
	for mode in ["field", "caster", "reparent"]:
		var field := Node3D.new()
		field.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(field)
		var caster := ClockCaster.new()
		field.add_child(caster)
		var state := {"hits": 0}
		var sequence := ArmageddonSequence.launch(field, caster, Vector3.ZERO, 11.0, 20.0,
			func(_index: int, _point: Vector3, _radius: float, _multiplier: float): state.hits += 1)
		var sequence_ref: WeakRef = weakref(sequence)
		await get_tree().create_timer(0.4).timeout
		var resources: Array[WeakRef] = []
		for mesh_node in sequence.find_children("*", "MeshInstance3D", true, false):
			if mesh_node.material_override:
				resources.append(weakref(mesh_node.material_override))
		match mode:
			"field": field.queue_free()
			"caster": caster.queue_free()
			"reparent": caster.reparent(self)
		await get_tree().create_timer(3.0).timeout
		check(state.hits == 0, mode + ": no callbacks into an obsolete field/caster")
		check(sequence_ref.get_ref() == null, mode + ": cancelled sequence releases its node")
		for ref in resources:
			var resource := ref.get_ref() as Material
			check(resource == null or resource.resource_path != "", mode + ": interrupted meteor does not retain transient materials")
		if is_instance_valid(field):
			field.queue_free()
		if mode == "reparent" and is_instance_valid(caster):
			caster.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		check(_empty_budget(), mode + ": no leaked reservations")


func _sum(values: Array[int]) -> int:
	var result := 0
	for value in values:
		result += value
	return result


func _empty_budget() -> bool:
	return VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}


func _stop_audio() -> void:
	AudioManager.stop_music(0.0)
	AudioManager.play_ambient(&"")
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
