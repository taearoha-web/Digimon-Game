extends Node3D
## Exercises all 102 catalogue skills at low/medium/high, then overlapping
## ultimates. Every temporary effect is freed while its delayed callbacks exist.
## godot --headless --path . res://tests/integration/skill_presentation_test.tscn

var failures: Array[String] = []
var cast_count := 0
var node_totals: Array[int] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _ready() -> void:
	await get_tree().process_frame
	GameSettings.load_settings()
	VfxArt.warm_up()
	var original_quality := GameSettings.quality
	for quality in 3:
		GameSettings.quality = quality
		var total := 0
		for family in SkillShow.FAMILY_COLORS:
			for skill in ClassData.pool(StringName(family)):
				var before: Dictionary = skill.duplicate(true)
				var look := SkillShow.profile_for(skill)
				check(look.mapped and look.family == family, "catalogue identity: " + String(skill.id))
				check(String(look.motif) != "", "missing motif: " + String(skill.id))
				var fx := Node3D.new()
				add_child(fx)
				SkillShow._recent_shows.clear()
				SkillShow.anticipate(fx, skill, Vector3.ZERO, float(skill.hit_delay))
				SkillShow.play(fx, skill, Vector3(3, 0, 0), Vector3.ZERO)
				# Core emitters share the same budget, including legacy monster hits.
				VfxKit.impact(fx, Vector3(3, 1, 0), skill.color)
				BattleVfx.play_impact(fx, skill.vfx, Vector3(3, 1, 0))
				check(fx.get_child_count() > 0, "no visuals: " + String(skill.id))
				check(skill == before, "presentation changed skill data: " + String(skill.id))
				check(is_equal_approx(Engine.time_scale, 1.0), "VFX changed gameplay time")
				check(int(VfxBudget.counters().decorations) <= VfxBudget.decoration_limit(), "decoration cap")
				total += fx.get_child_count()
				cast_count += 1
				fx.queue_free()
				await get_tree().process_frame
				check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "reservations leaked on scene exit")
		node_totals.append(total)
	check(node_totals[0] < node_totals[2], "low quality must create fewer effect nodes")
	for quality in 3:
		GameSettings.quality = quality
		var crowd := Node3D.new()
		add_child(crowd)
		SkillShow._recent_shows.clear()
		for i in 32:
			var family: StringName = ClassData.IDS[i % 4]
			var pool := ClassData.pool(family)
			SkillShow.play(crowd, pool.back(), Vector3.ZERO, Vector3.ZERO)
		check(int(VfxBudget.counters().decorations) <= VfxBudget.decoration_limit(), "overlapping ultimate cap")
		# Give delayed flourishes time to run and verify they also honor the budget.
		await get_tree().create_timer(0.3).timeout
		check(int(VfxBudget.counters().decorations) <= VfxBudget.decoration_limit(), "delayed decoration cap")
		crowd.queue_free()
		# SceneTreeTimer callbacks run after process_frame on Godot 4.3. Wait
		# for the actual exit, not a frame signal before deferred frees flush.
		await crowd.tree_exited
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "crowd reservations leaked q%d: %s" % [quality, VfxBudget.counters()])
		var saturated := Node3D.new()
		add_child(saturated)
		var disabled := 0
		for i in 64:
			var emitter := VfxKit._particles(saturated, Vector3.ZERO, Color.WHITE, 80, 1.0)
			if not emitter.emitting:
				disabled += 1
			check(int(VfxBudget.counters().particles) <= VfxBudget.particle_limit(), "strict particle saturation cap")
		check(disabled > 0, "saturation disables cosmetic emitters")
		var hit_state := {"called": false}
		VfxKit.meteor(saturated, Vector3.ZERO, Color.WHITE, 0.05, 1.0, func(): hit_state.called = true)
		await get_tree().create_timer(0.12).timeout
		check(hit_state.called, "saturated VFX must preserve meteor gameplay callback")
		check(int(VfxBudget.counters().particles) <= VfxBudget.particle_limit(), "delayed saturated particle cap")
		saturated.queue_free()
		await saturated.tree_exited
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "saturated reservations leaked")
	GameSettings.quality = original_quality
	print("SKILL PRESENTATION: %s | %d casts, low/medium/high nodes %s, %d failures" % ["PASS" if failures.is_empty() else "FAIL", cast_count, node_totals, failures.size()])
	get_tree().quit(failures.size())
