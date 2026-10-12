extends Node3D
## Real rig/socket correspondence, equipment changes, pause/cancel ownership and
## all authored materials. Run with native GL to also compile the changed shaders.
var checks := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 740
	for rig in 3:
		for family in SkillShow.FAMILY_COLORS:
			var visual := HeroVisual.new()
			add_child(visual)
			visual.setup(StringName(family), "", true, {}, {} if rig == 2 else {"gender": rig})
			visual.set_process(false)
			visual.position = Vector3(3, 0, -2)
			visual.rotation.y = 0.8
			for tier in [0, 4, 9]:
				visual.equip = {"weapon": ItemData.generate(tier * 10 + 5, StringName(family), rng, 0, "weapon")}
				visual.equip.weapon.plus = 0
				visual.refresh()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var skill: Dictionary = ClassData.pool(StringName(family)).back()
				visual.skill_action(skill, 0.5)
				visual.set_process(false)
				visual._advance_skill_motion(0.25)
				visual._skeleton.force_update_all_bone_transforms()
				await RenderingServer.frame_post_draw
				var actual := visual._emission_grip.to_global(visual._emission_point)
				var sampled := visual.skill_emission_position()
				check(sampled.is_finite() and sampled.distance_to(visual.global_position) < 6.0, "finite local weapon tip %s tier%d rig%d" % [family, tier, rig])
				check(actual.distance_to(sampled) < 0.02, "sample matches rendered attachment %s tier%d rig%d: %.4f" % [family, tier, rig, actual.distance_to(sampled)])
				var look := SkillShow.profile_for(skill)
				var charge := SkillCharge.launch(self, visual, look, 0.5)
				check(charge != null, "charge available " + family)
				if charge:
					charge.set_process(false)
					visual.position.x += 0.75
					visual._advance_skill_motion(0.1)
					charge._process(0.1)
					check(charge.global_position.distance_to(visual.skill_emission_position()) < 0.001, "charge follows moving animated weapon")
					visual.release()
					charge._process(0.01)
					check(charge.is_queued_for_deletion(), "interrupted windup cancels charge")
					await charge.tree_exited
			visual.queue_free()
			await visual.tree_exited
	# Shader materials must be independent per cast; finishing one never fades another.
	for family in SkillShow.FAMILY_COLORS:
		for skill in ClassData.pool(StringName(family)):
			var look := SkillShow.profile_for(skill)
			var first := SpellSpectacle._material(look)
			var second := SpellSpectacle._material(look)
			first.set_shader_parameter("fade", 0.0)
			check(first != second and second.get_shader_parameter("fade") != 0.0, "independent dissolve " + String(skill.id))
	# Scene pause freezes charge life and its source animation together.
	var visual := HeroVisual.new()
	add_child(visual)
	visual.setup(&"mage", "", true, {}, {"gender": 1})
	var spell := ClassData.find_skill(&"mage", "armageddon")
	visual.skill_action(spell, 0.8)
	var charge := SkillCharge.launch(self, visual, SkillShow.profile_for(spell), 0.8)
	var before := charge.elapsed
	get_tree().paused = true
	await get_tree().create_timer(0.1, true).timeout
	check(is_equal_approx(before, charge.elapsed), "pause preserves charge clock")
	get_tree().paused = false
	visual.queue_free()
	await visual.tree_exited
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(charge), "deleted caster removes charge")
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "no socket or material reservations leaked")
	print("SKILL CRAFT: %s | %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
