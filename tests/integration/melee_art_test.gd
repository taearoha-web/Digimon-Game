extends Node3D
## The Warrior / Lancer / Defender class layers (MeleeArt): every Lv.10-100
## skill and every star skill builds its signature layers at high quality,
## fewer under memory pressure and at low quality (pressure 2 / low: the core
## only), never touches combat data, gives every budget reservation back and
## keeps a bounded pool: 150 casts grow no nodes.
## godot --headless --path . res://tests/integration/melee_art_test.tscn
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _skills() -> Array:
	var out: Array = []
	for cls in [&"warrior", &"lancer", &"defender"]:
		# The class pools carry the five star skills after the 25 levelled ones.
		out.append_array(ClassData.pool(cls))
	return out


## Builds one cast (wind-up and release, or a star beat) and returns the layers it made.
func _cast(field: Node3D, skill: Dictionary) -> Array:
	var before_layers := MeleeArt.built_layers
	var before_parts := MeleeArt.built_particles
	if skill.has("star"):
		MeleeArt.star(field, skill, Vector3(0, 0, 3), int(skill.get("star", 50)) / 300 * 4, Vector3.ZERO)
	else:
		MeleeArt.anticipate(field, skill, Vector3.ZERO, Vector3(0, 0, 3), 0.4)
		MeleeArt.play(field, skill, Vector3(0, 0, 3), Vector3.ZERO)
	return [MeleeArt.built_layers - before_layers, MeleeArt.built_particles - before_parts]


func _rigs() -> Array:
	var viewport := get_viewport()
	if not viewport.has_meta(MeleeArt.HOLDER):
		return []
	return (viewport.get_meta(MeleeArt.HOLDER) as Node).get_children().filter(func(n: Node) -> bool: return n is MeleeArt)


func _settle(_field: Node3D) -> void:
	for rig in _rigs():
		if (rig as MeleeArt).busy:
			(rig as MeleeArt).finish()


func _ready() -> void:
	GameSettings.load_settings()
	var skills := _skills()
	check(skills.size() == 90, "75 class skills and 15 star skills (%d)" % skills.size())
	var field := Node3D.new()
	add_child(field)
	await get_tree().process_frame
	# Coverage and the budget ladder: high > medium / pressure 1 > low / pressure 2.
	var totals := {}
	for setting in [["high", 2, 0], ["pressure1", 2, 1], ["pressure2", 2, 2], ["low", 0, 0]]:
		GameSettings.quality = int(setting[1])
		MemoryGuard.force(int(setting[2]), get_tree())
		var layers := 0
		var parts := 0
		for skill in skills:
			check(MeleeArt.handles(skill) or MeleeArt.handles_star(skill), "covered: " + String(skill.id))
			# A god skill with its own signature art (GodSkillArt.owns) draws every beat itself.
			if GodSkillArt.owns(skill):
				check(int(_cast(field, skill)[0]) == 0, "%s: the class layers stay out of its own god art" % skill.id)
				continue
			var snapshot: Dictionary = skill.duplicate(true)
			var made := _cast(field, skill)
			if setting[0] == "high":
				check(int(made[0]) >= 3, "%s builds its class layers at high quality (%d)" % [skill.id, made[0]])
			elif setting[0] in ["pressure2", "low"]:
				check(int(made[1]) == 0, "%s throws no particles on %s" % [skill.id, setting[0]])
				check(int(made[0]) >= 1 and int(made[0]) <= int(MeleeArt.LAYER_CAP[0]) * 2, "%s keeps its core silhouette on %s (%d)" % [skill.id, setting[0], made[0]])
			check(skill == snapshot, "art preserves the combat data of " + String(skill.id))
			check(int(VfxBudget.counters().decorations) <= VfxBudget.decoration_limit(), "decoration cap")
			check(int(VfxBudget.counters().particles) <= VfxBudget.particle_limit(), "particle cap")
			layers += int(made[0])
			parts += int(made[1])
			_settle(field)
		totals[setting[0]] = [layers, parts]
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "%s reservations released: %s" % [setting[0], VfxBudget.counters()])
	print("MELEE ART layers/particles: ", totals)
	check(totals.high[0] > totals.pressure1[0] and totals.pressure1[0] > totals.pressure2[0], "pressure trims the layers")
	check(totals.high[1] > totals.pressure1[1] * 1.5 and totals.pressure2[1] == 0, "pressure 1 halves the particles, pressure 2 drops them")
	check(totals.low[0] < totals.high[0] and totals.low[1] == 0, "low quality keeps the core only")
	GameSettings.quality = 2
	MemoryGuard.force(0, get_tree())
	# A cancelled wind-up (new skill generation) is dropped at once.
	var visual := HeroVisual.new()
	field.add_child(visual)
	MeleeArt.anticipate(field, ClassData.find_skill(&"warrior", "grand_cross"), Vector3.ZERO, Vector3(0, 0, 3), 0.6, visual)
	var windup: MeleeArt = null
	for rig in _rigs():
		if (rig as MeleeArt).busy:
			windup = rig
	check(windup != null, "wind-up built")
	visual.skill_generation += 1
	await get_tree().process_frame
	check(windup == null or not windup.busy, "a cancelled wind-up is dropped")
	visual.queue_free()
	# The real pipeline routes the three lines here (SkillShow hooks).
	var before := MeleeArt.built_layers
	SkillShow.play(field, ClassData.find_skill(&"defender", "brace"), Vector3.ZERO, Vector3.ZERO)
	check(MeleeArt.built_layers > before, "SkillShow.play reaches the Defender's layers")
	before = MeleeArt.built_layers
	SkillShow.play(field, ClassData.find_skill(&"mage", "fire_ball") if not ClassData.find_skill(&"mage", "fire_ball").is_empty() else ClassData.pool(&"mage")[0], Vector3.ZERO, Vector3.ZERO)
	check(MeleeArt.built_layers == before, "other lines are left alone")
	# 150 casts run to their end on their own clock: the pool warms up to a fixed
	# ceiling (rigs x layer slots), then another 150 casts grow no nodes at all.
	var nodes_start := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var marks: Array[int] = []
	for round in 2:
		for i in 150:
			var skill: Dictionary = skills[(i * 7 + round) % skills.size()]
			_cast(field, skill)
			if i % 5 == 4:
				for f in 6:
					await get_tree().process_frame
		await get_tree().create_timer(3.0).timeout
		marks.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MELEE ART nodes: start %d, after 150 casts %d, after 300 casts %d, rigs %d" % [nodes_start, marks[0], marks[1], MeleeArt._rig_count])
	check(marks[1] <= marks[0], "150 more casts grow no nodes (%d -> %d)" % [marks[0], marks[1]])
	check(marks[0] - nodes_start <= MeleeArt.POOL_CAP * (int(MeleeArt.LAYER_CAP[2]) + 4) + 2, "the warm pool stays under its ceiling (+%d)" % (marks[0] - nodes_start))
	check(MeleeArt._rig_count <= MeleeArt.POOL_CAP, "the rig pool stays bounded (%d)" % MeleeArt._rig_count)
	check(field.get_children().filter(func(n: Node) -> bool: return n is MeleeArt).is_empty(), "rigs never sit in the field")
	var busy := _rigs().filter(func(n: Node) -> bool: return (n as MeleeArt).busy)
	check(busy.is_empty(), "every rig is back in the pool, idle (%d busy)" % busy.size())
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "reservations released after the run: %s" % VfxBudget.counters())
	# A field freed mid-cast gives its reservations back.
	_cast(field, ClassData.find_skill(&"warrior", "gladiator"))
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "a freed field releases its reservations: %s" % VfxBudget.counters())
	print("MELEE ART: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)
