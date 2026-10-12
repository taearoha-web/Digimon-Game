extends Node3D
class Dummy extends Mob:
	var hits := 0
	func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		hits += 1
		return super.take_hit(amount, crit, color, attacker)
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
	Game.set_process(false)
	Game.new_profile(&"mage", "Thunder Storm QA", {"gender": 0})
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	var skill := ClassData.find_skill(&"mage", "thunder_storm")
	var ice := ClassData.find_skill(&"mage", "ice_storm")
	check(skill.shape == "blast" and skill.radius == ice.radius, "storm is area skill with Ice Storm radius")
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector3(-12, 0, 0)
	hero.stats.atk = 100
	hero.stats.crit = 0
	for rank in [1, 3, 5]:
		Game.profile.skills["thunder_storm"] = rank
		Game.profile.skills["ice_storm"] = rank
		check(hero._ranked(skill).radius == hero._ranked(ice).radius, "matching ranked radius %d" % rank)
	var mobs: Array[Dummy] = []
	for i in 9:
		var mob := Dummy.new()
		mob.setup(&"forest_orc", 100, Vector3.ZERO, hero)
		field.add_child(mob)
		mob.position = Vector3(sin(i) * 5, 0, cos(i) * 5) if i < 8 else Vector3(30, 0, 0)
		mob.hp = 10000000
		mob.max_hp = mob.hp
		mob.stats.def = 0
		mob.set_physics_process(false)
		mobs.append(mob)
	Game.profile.skills["thunder_storm"] = 1
	# Real hero path, no generic blast/chain damage is allowed in addition.
	hero._resolve(skill, mobs[0], Vector3.ZERO)
	var seq: ThunderStormSequence = get_tree().get_first_node_in_group("thunder_storm_sequences")
	seq.set_process(false)
	seq._rng.seed = 42
	seq.center = Vector3.ZERO
	var waves: Array = []
	seq.wave_fired.connect(func(index, selected): waves.append({"index": index, "targets": selected.duplicate(), "time": seq.elapsed}))
	seq._process(0.54)
	check(waves.is_empty(), "no damage before cloud forms")
	seq._process(0.01)
	seq._process(0.75)
	seq._process(0.75)
	check(waves.size() == 3, "exactly three waves")
	var hits := 0
	for wave in waves:
		check(wave.targets.size() == 5, "five selected per wave")
		var ids := {}
		for target in wave.targets:
			ids[target.get_instance_id()] = true
		check(ids.size() == 5, "no duplicate targets within a wave")
	check(waves[0].targets != waves[1].targets, "later wave resamples instead of reusing selection")
	for mob in mobs:
		hits += mob.hits
	check(hits == 15 and mobs[8].hits == 0, "fifteen real hits total; outside enemy untouched")
	check(is_equal_approx(waves[1].time - waves[0].time, 0.75) and is_equal_approx(waves[2].time - waves[1].time, 0.75), "exact 0.75 second wave cadence")
	check(seq._art.find_children("ThunderStormCloud", "MeshInstance3D", true, false).size() == 1, "one single connected grey cloud")
	check(seq._art.find_children("*", "CPUParticles3D", true, false).is_empty() and seq._art.find_children("*", "Light3D", true, false).is_empty(), "cloud adds no lights or particles")
	check(VfxBudget.counters().decorations <= VfxBudget.decoration_limit(), "simultaneous storm waves obey shared decoration cap")
	# Fill remaining capacity with tracked nodes to exercise the hard limit.
	while VfxBudget.can_decorate():
		var reservation := Node.new()
		seq.add_child(reservation)
		VfxBudget.track_decoration(reservation)
	var visual_count := seq._art.get_child_count()
	seq._art.strike(Vector3.ZERO, 99)
	check(seq._art.get_child_count() == visual_count + 1, "essential lightning remains visible when all decorative capacity is used")
	var art_age := float(seq._art._mat.get_shader_parameter("age"))
	get_tree().paused = true
	await get_tree().create_timer(0.1, true).timeout
	check(float(seq._art._mat.get_shader_parameter("age")) == art_age, "pause freezes authored cloud motion")
	get_tree().paused = false
	seq.queue_free()
	await seq.tree_exited
	# Move/death/new entrants are considered on every wave, fewer than five means
	# fewer hits, never repeated damage to fill missing slots.
	for i in 9:
		mobs[i].position = Vector3(30, 0, 0)
	mobs[0].position = Vector3.ZERO
	mobs[1].position = Vector3(1, 0, 0)
	mobs[2].position = Vector3(2, 0, 0)
	var received: Array = []
	seq = ThunderStormSequence.launch(field, hero, Vector3.ZERO, 9, hero._storm_candidates, func(v): received.append(v), false)
	seq.set_process(false)
	seq._process(0.55)
	check(received.size() == 3, "three enemies produce three strikes, no filler hits")
	mobs[0]._dead = true
	mobs[1].position = Vector3(30, 0, 0)
	mobs[3].position = Vector3(1, 0, 0)
	received.clear()
	seq._process(0.75)
	check(received.size() == 2 and received.has(mobs[2]) and received.has(mobs[3]), "wave resamples death, exit and new entrant")
	received.clear()
	seq.set_process(true)
	get_tree().paused = true
	var before := seq.elapsed
	await get_tree().create_timer(0.1, true).timeout
	check(seq.elapsed == before and received.is_empty(), "pause freezes wave clock")
	get_tree().paused = false
	seq.set_process(false)
	hero._dead = true
	seq._process(0.75)
	check(received.is_empty() and seq.is_queued_for_deletion(), "caster death cancels future strikes")
	await seq.tree_exited
	hero._dead = false
	seq = ThunderStormSequence.launch(field, hero, Vector3.ZERO, 9, hero._storm_candidates, func(v): received.append(v), false)
	seq.set_process(false)
	hero.reparent(self)
	seq._process(1.5)
	check(seq.is_queued_for_deletion() and received.is_empty(), "zone change cancels stale storm")
	await seq.tree_exited
	hero.reparent(field)
	# Companion uses the same three-wave gameplay path.
	var buddy := Companion.new()
	buddy.setup({"class": "mage", "name": "Storm ally", "level": 100, "exp": 0, "gender": 0}, 0, hero, field)
	field.add_child(buddy)
	buddy.set_physics_process(false)
	buddy.stats.atk = 100
	buddy.stats.crit = 0
	buddy._resolve(skill, mobs[2], Vector3.ZERO)
	seq = get_tree().get_first_node_in_group("thunder_storm_sequences")
	seq.set_process(false)
	var previous := mobs[2].hits
	seq._process(2.06)
	check(mobs[2].hits == previous + 3, "companion also makes three real waves")
	seq.queue_free()
	await seq.tree_exited
	hero.position = Vector3(-5, 0, 0)
	hero.target = mobs[2]
	Game.profile.loadout[0] = "thunder_storm"
	hero.cooldowns.clear()
	var mana_before := int(Game.profile.mp)
	var mana_cost := hero.mp_cost(skill)
	check(hero.use_skill(0) == "", "real player skill button queues a storm")
	hero._combat_step(1.0 / 60.0)
	check(hero.use_skill(0) == "cooldown", "repeat button blocked by cooldown")
	await get_tree().create_timer(3.7).timeout
	check(int(Game.profile.mp) == mana_before - mana_cost, "all three waves charge MP only once")
	check(get_tree().get_nodes_in_group("thunder_storm_sequences").is_empty(), "normal completion removes storm and cloud")
	field.queue_free()
	await field.tree_exited
	await settle()
	check(get_tree().get_nodes_in_group("thunder_storm_sequences").is_empty(), "unload removes cloud and callbacks")
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "no visual reservation leaks")
	print("THUNDER STORM: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
