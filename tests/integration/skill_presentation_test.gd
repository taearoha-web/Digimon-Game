extends Node3D
## Exercises every runtime catalogue skill at low/medium/high, then overlapping
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
	var families: Array[StringName] = [&"vagabond"]
	families.append_array(ClassData.IDS)
	for quality in 3:
		GameSettings.quality = quality
		var total := 0
		for family in families:
			for skill in ClassData.pool(family):
				var before: Dictionary = skill.duplicate(true)
				var look := SkillShow.profile_for(skill)
				check(look.mapped and String(look.family) == String(family), "catalogue identity: " + String(skill.id))
				check(String(look.motif) != "", "missing motif: " + String(skill.id))
				var fx := Node3D.new()
				add_child(fx)
				SkillShow._recent_shows.clear()
				SkillShow.anticipate(fx, skill, Vector3.ZERO, float(skill.hit_delay))
				SkillShow.play(fx, skill, Vector3(3, 0, 0), Vector3.ZERO)
				# Inspect the authored presentation before generic hit emitters can
				# accidentally make an empty or disconnected skill look covered.
				if String(skill.id) == "judgment_ray":
					var art := JudgmentRayArt.new()
					fx.add_child(art)
					art.draw_stage(1.0, 0.05)
					check(art.has_node("JudgmentEssentialColumn"), "single celestial column")
				elif String(skill.id) == "thunder_storm":
					var caster := Node3D.new()
					fx.add_child(caster)
					ThunderStormSequence.launch(fx, caster, Vector3.ZERO, float(skill.radius), func(): return [], func(_victim): pass)
					check(fx.find_children("ThunderStormCloud", "MeshInstance3D", true, false).size() == 1, "one connected storm cloud")
				elif String(skill.id) == "armageddon":
					var caster := Node3D.new()
					fx.add_child(caster)
					var sequence := ArmageddonSequence.launch(fx, caster, Vector3(3, 0, 0), float(skill.radius), float(skill.mult),
						func(_index: int, _point: Vector3, _radius: float, _multiplier: float): pass)
					check(sequence != null, "Armageddon launches its dedicated presentation")
					_check_essential_meteor(fx, "catalogue q%d" % quality)
				elif StarSkillArt.handles(skill):
					var art := fx.get_node_or_null("StarContact_"+String(skill.id)) as StarSkillArt
					check(art!=null and not art.layers.is_empty(),"star silhouette exists: "+String(skill.id))
				elif EliteSkillArt.handles(skill):
					var art := fx.get_node_or_null("EliteSkill_" + String(skill.id)) as EliteSkillArt
					check(art != null and not art.layers.is_empty(), "elite silhouette exists: " + String(skill.id))
					if art:
						if String(skill.get("special", "")) in ["meteor", "rain"]:
							for layer in art.layers:
								if not bool(layer.get("style",{}).get("airborne",false)):
									check(not layer.node.visible, "elite impact hidden until real landing: " + String(skill.id))
							await get_tree().create_timer(0.60).timeout
						for layer in art.layers:
							var mesh: MeshInstance3D = layer.node
							var active := art.age >= float(layer.start) and art.age < float(layer.start)+float(layer.seconds)
							check(mesh.visible == active and mesh.mesh != null and mesh.material_override != null, "elite layer follows its authored phase: " + String(skill.id))
							var saved_age := art.age
							art.age=float(layer.start)+float(layer.seconds)*0.4
							art._draw()
							check(mesh.visible,"elite layer appears during its active phase: "+String(skill.id))
							check(float((mesh.material_override as ShaderMaterial).get_shader_parameter("fade"))>0.1,"elite shader visible at phase midpoint: "+String(skill.id))
							art.age=saved_age
							art._draw()
							check(mesh.transform.is_finite() and mesh.mesh.get_aabb().size.length_squared() > 0.000001, "valid elite geometry: " + String(skill.id))
				else:
					# Ordinary meteors reveal their authored form on landing.
					if String(skill.get("special", "")) in ["meteor", "rain"]:
						check(fx.get_node_or_null("SpellSpectacle_" + String(skill.id)) == null, "area impact must wait for damage: " + String(skill.id))
						await get_tree().create_timer(0.60).timeout
					var presentation := fx.get_node_or_null("SpellSpectacle_" + String(skill.id))
					check(presentation != null, "missing authored skill presentation: " + String(skill.id))
					if presentation:
						var meshes := presentation.find_children("*", "MeshInstance3D", true, false)
						check(not meshes.is_empty(), "empty authored skill silhouette: " + String(skill.id))
						for child in meshes:
							var mesh := child as MeshInstance3D
							check(mesh.visible and mesh.mesh != null and mesh.material_override != null,
								"unrenderable authored skill geometry: " + String(skill.id))
							check(mesh.transform.is_finite() and mesh.mesh != null and mesh.mesh.get_aabb().size.length_squared() > 0.000001,
								"invalid authored skill geometry: " + String(skill.id))
				# Core emitters share the same budget, including legacy monster hits.
				VfxKit.impact(fx, Vector3(3, 1, 0), skill.color)
				BattleVfx.play_impact(fx, skill.vfx, Vector3(3, 1, 0))
				check(skill == before, "presentation changed skill data: " + String(skill.id))
				check(is_equal_approx(Engine.time_scale, 1.0), "VFX changed gameplay time")
				check(int(VfxBudget.counters().decorations) <= VfxBudget.decoration_limit(), "decoration cap")
				total += fx.get_child_count()
				cast_count += 1
				fx.queue_free()
				await fx.tree_exited
				await get_tree().process_frame
				check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "reservations leaked on %s scene exit: %s" % [skill.id, VfxBudget.counters()])
		node_totals.append(total)
	check(node_totals[0] < node_totals[2], "low quality must create fewer effect nodes")
	for quality in 3:
		GameSettings.quality = quality
		var crowd := Node3D.new()
		add_child(crowd)
		SkillShow._recent_shows.clear()
		for i in 32:
			var family: StringName = ClassData.IDS[i % ClassData.IDS.size()]
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
		while VfxBudget.can_decorate():
			var reservation := Node.new()
			saturated.add_child(reservation)
			VfxBudget.track_decoration(reservation)
		MeteorArt.descent(saturated, Vector3.ZERO, 11.0)
		_check_essential_meteor(saturated, "saturated q%d" % quality)
		check(int(VfxBudget.counters().decorations) == VfxBudget.decoration_limit(), "essential meteor preserves the cosmetic ceiling q%d" % quality)
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


func _check_essential_meteor(parent: Node, context: String) -> void:
	for label in ["EssentialMeteorBody", "EssentialLandingWarning"]:
		var mesh := parent.find_child(label, true, false) as MeshInstance3D
		check(mesh != null, "%s: missing %s" % [context, label])
		if mesh:
			check(mesh.visible and mesh.mesh != null and mesh.material_override != null,
				"%s: unrenderable %s" % [context, label])
