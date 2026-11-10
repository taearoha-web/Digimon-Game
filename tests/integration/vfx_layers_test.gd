extends Node3D
## The shared skill layer stack (SkillLayers / SkillLayerPool):
## - every authored recipe, every star and god skill gets all five layers at high quality,
##   with a known silhouette family, element and particle kinds, and a real cast of
##   each shows its secondary, environment and afterglow emitters;
## - memory pressure 1 drops environment + afterglow and halves the particles, pressure 2
##   keeps the core and one secondary emitter, low quality keeps core + anticipation;
## - 200 casts reuse the pool (no node growth), budget reservations return to zero;
## - a zone change (the field freed) ends every borrowed slot at once, nothing leaks;
## - it never touches skill data or the game clock.
## godot --headless --path . res://tests/integration/vfx_layers_test.tscn
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _all_skills() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for family in SkillShow.FAMILY_COLORS:
		for skill in ClassData.pool(StringName(family)):
			if not seen.has(String(skill.id)):
				seen[String(skill.id)] = true
				out.append(skill)
		for star in StarSkillData.pool(StringName(family)):
			if not seen.has(String(star.id)):
				seen[String(star.id)] = true
				out.append(star)
	return out


func _cast(field: Node3D, skill: Dictionary) -> Dictionary:
	SkillLayers.reset_crowd()
	if skill.has("star"):
		SkillLayers.star_beat(field, skill, Vector3(3, 0, 0), 0, 1, Vector3.ZERO)
	else:
		SkillLayers.release(field, skill, Vector3(3, 0, 0), Vector3.ZERO)
	return SkillLayers.last.duplicate(true)


func _ready() -> void:
	GameSettings.load_settings()
	GameSettings.quality = 2
	MemoryGuard.pressure = 0
	SkillLayers.enabled = true
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(8, 9, 12)
	camera.look_at(Vector3.ZERO)
	var field := Node3D.new()
	add_child(field)
	var skills := _all_skills()
	check(skills.size() > 300, "the catalogue holds every class's skills, stars and gods (%d)" % skills.size())
	# --- every recipe gets the full stack at high quality ---
	var recipe_ids := SkillArtDirection.RECIPES.keys()
	var covered := 0
	var full_layers: Array[String] = SkillLayers.LAYERS.duplicate()
	for skill in skills:
		var plan := SkillLayers.plan(skill)
		var id := String(skill.id)
		check(plan.layers == full_layers, "%s gets all five layers at high quality: %s" % [id, plan.layers])
		check(SkillLayers.ELEMENTS.has(plan.element), "%s has a known element (%s)" % [id, plan.element])
		check(String(plan.family) in ["ground", "burst", "slash", "swirl", "strike", "shot", "aura"], "%s has a silhouette family" % id)
		for kind in plan.secondary + plan.afterglow:
			check(SkillLayers.KINDS.has(kind), "%s uses a known particle kind %s" % [id, kind])
		if id in recipe_ids:
			covered += 1
	check(covered == recipe_ids.size(), "every recipe row is a real skill in a pool (%d / %d)" % [covered, recipe_ids.size()])
	for palette in SkillArtDirection.PALETTES:
		check(SkillLayers.PALETTE_ELEMENT.has(palette), "palette %s has an element flavour" % palette)
	for recipe in SkillArtDirection.RECIPES.values():
		check(SkillLayers.FAMILIES.has(String(recipe[0])), "silhouette %s has a layer family" % recipe[0])
	# --- a real cast of every skill shows its layers ---
	var high := {}
	var before_data := {}
	for skill in skills:
		before_data[String(skill.id)] = skill.duplicate(true)
		var shown := _cast(field, skill)
		high[String(skill.id)] = shown
		check(shown.emitters >= 4, "%s shows secondary, environment and afterglow emitters (%d)" % [skill.id, shown.emitters])
		check(shown.lights <= 1, "%s borrows at most one flash light" % skill.id)
		check(skill == before_data[String(skill.id)], "the layers left %s's data alone" % skill.id)
		check(is_equal_approx(Engine.time_scale, 1.0), "the layers never change the clock")
		if shown.particles > 0:
			await get_tree().process_frame
		if int(VfxBudget.counters().particles) > VfxBudget.particle_limit() - 120:
			await get_tree().create_timer(3.5).timeout
	# Anticipation: motes, a gathering ring, a charge light.
	var sample := ClassData.find_skill(&"mage", "meteo")
	SkillLayers.reset_crowd()
	SkillLayers.anticipate(field, sample, Vector3.ZERO, 0.9, Vector3(3, 0, 0))
	check(SkillLayers.last.emitters >= 2 and SkillLayers.last.rings == 1, "the wind-up gathers motes and a ring of light (%s)" % SkillLayers.last)
	await get_tree().create_timer(3.5).timeout
	# --- memory pressure and quality ---
	var probes := [ClassData.find_skill(&"mage", "meteo"), ClassData.find_skill(&"warrior", "sword_of_justice"),
		ClassData.find_skill(&"priest", "grand_healing"), ClassData.find_skill(&"bard", "resonance"), StarSkillData.pool(&"warrior")[3]]
	# The god skills with their own signature art (GodSkillArt.owns) draw every beat
	# themselves: the shared stack plays nothing under them.
	for cls in SkillShow.FAMILY_COLORS:
		var stars := StarSkillData.pool(StringName(cls))
		var god: Dictionary = stars[4] if stars.size() > 4 else {}
		if GodSkillArt.owns(god):
			var count := field.get_child_count()
			SkillLayers.reset_crowd()
			SkillLayers.star_beat(field, god, Vector3(3, 0, 0), 4, 5, Vector3.ZERO)
			SkillLayers.anticipate(field, god, Vector3.ZERO, 1.5, Vector3(3, 0, 0))
			check(field.get_child_count() == count, "%s: the shared stack stays out of its own god art" % god.id)
	for skill in probes:
		var full: Dictionary = _cast(field, skill)
		await get_tree().create_timer(3.0).timeout
		MemoryGuard.pressure = 1
		var p1 := _cast(field, skill)
		check(p1.layers == ["anticipation", "core", "secondary"], "pressure 1 drops environment and afterglow for %s: %s" % [skill.id, p1.layers])
		check(p1.emitters < full.emitters and p1.lights == 0 and p1.hazes == 0, "pressure 1 shows fewer emitters, no light, no haze for %s (%d < %d)" % [skill.id, p1.emitters, full.emitters])
		check(p1.particles * 2 <= full.particles + 8, "pressure 1 halves the particles for %s (%d vs %d)" % [skill.id, p1.particles, full.particles])
		MemoryGuard.pressure = 2
		var p2 := _cast(field, skill)
		check(p2.layers == ["core", "secondary"], "pressure 2 keeps the core and one secondary for %s" % skill.id)
		check(p2.emitters == 1 and p2.rings == 0 and p2.lights == 0, "pressure 2 shows one secondary emitter for %s (%s)" % [skill.id, p2])
		SkillLayers.reset_crowd()
		SkillLayers.anticipate(field, skill, Vector3.ZERO, 0.8, Vector3(3, 0, 0))
		check(SkillLayers.last.emitters == 0 and SkillLayers.last.rings == 0, "pressure 2 drops the wind-up layer")
		MemoryGuard.pressure = 0
		await get_tree().create_timer(4.5).timeout
		GameSettings.quality = 0
		var q0 := _cast(field, skill)
		check(q0.layers == ["anticipation", "core"] and q0.emitters == 0, "low quality keeps core + anticipation only for %s (%s)" % [skill.id, q0])
		SkillLayers.reset_crowd()
		SkillLayers.anticipate(field, skill, Vector3.ZERO, 0.8, Vector3(3, 0, 0))
		check(SkillLayers.last.emitters >= 1 and SkillLayers.last.lights == 0, "low quality still gathers its wind-up, without a light")
		GameSettings.quality = 1
		var q1 := _cast(field, skill)
		check(q1.particles < full.particles and q1.hazes == 0 and q1.lights == 0, "medium quality: fewer particles, no light or haze for %s" % skill.id)
		GameSettings.quality = 2
		await get_tree().create_timer(3.0).timeout
	# Many casts at once: the crowd thins the stack.
	SkillLayers.reset_crowd()
	for i in 6:
		SkillLayers.release(field, sample, Vector3(i, 0, 0), Vector3.ZERO)
	check(SkillLayers.last.layers.size() <= 3, "a crowd of casts in one second sheds the heavy layers (%s)" % [SkillLayers.last.layers])
	await get_tree().create_timer(5.0).timeout
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "every reservation is returned when the layers end: %s" % VfxBudget.counters())
	# --- 200 casts reuse the pool ---
	var pool := SkillLayerPool.existing(get_tree())
	check(pool != null, "the pool lives under the Game autoload")
	check(pool != null and pool.get_parent() != field, "the pool is never a child of a field")
	var nodes_at := []
	for i in 200:
		var skill: Dictionary = skills[(i * 7) % skills.size()]
		if i % 3 == 0:
			SkillLayers.anticipate(field, skill, Vector3.ZERO, 0.5, Vector3(3, 0, 0))
		_cast(field, skill)
		SkillLayers.contact(field, skill, Vector3(3, 1, 0))
		await get_tree().process_frame
		if i == 49 or i == 199:
			nodes_at.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	check(pool.node_count() <= SkillLayerPool.EMITTERS + SkillLayerPool.RINGS + SkillLayerPool.LIGHTS + SkillLayerPool.HAZES,
		"the pool never grows past its fixed size (%d)" % pool.node_count())
	check(nodes_at.size() == 2 and absi(nodes_at[1] - nodes_at[0]) <= 4, "node count is stable over 200 casts (%s)" % [nodes_at])
	check(field.get_child_count() == 0, "the layers add nothing to the field itself (%d)" % field.get_child_count())
	check(field.find_children("*", "CPUParticles3D", true, false).is_empty(), "no layer emitter lives under a field")
	check(int(VfxBudget.counters().particles) <= VfxBudget.particle_limit(), "the particle budget holds under 200 casts")
	# --- a zone change ---
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var pool_nodes := pool.node_count()
	check(pool.active_count() > 0, "layers are playing when the zone changes")
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	await get_tree().process_frame
	check(pool.active_count() == 0, "the layers of a freed field end at once (%d left)" % pool.active_count())
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "no reservation outlives the zone: %s" % VfxBudget.counters())
	check(pool.node_count() == pool_nodes, "the pool keeps its nodes for the next zone, no more")
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= nodes_before - 1, "freeing the field frees its nodes; the layers hold none of it")
	var next := Node3D.new()
	add_child(next)
	SkillLayers.release_cache(get_tree())
	SkillLayers.reset_crowd()
	SkillLayers.release(next, sample, Vector3(3, 0, 0), Vector3.ZERO)
	check(SkillLayers.last.emitters >= 4, "the next zone casts with the same pool")
	SkillLayers.release_cache(get_tree())
	check(pool.active_count() == 0 and VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "release_cache stops everything")
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "no orphan nodes")
	print("VFX LAYERS: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)
