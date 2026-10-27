extends Node3D
## Contact frame, haste, cancellation, and both retargeted rigs. No real saves.
var failures: Array[String] = []
var checks := 0
var cases := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _ready() -> void:
	await get_tree().process_frame
	Game.set_process(false)
	var seen := {}
	for group in SkillChoreography.GROUPS:
		for id in String(SkillChoreography.GROUPS[group]).split(" ", false):
			check(not seen.has(id), "duplicate cue " + id)
			seen[id] = true
	var count := 0
	for family in SkillShow.FAMILY_COLORS:
		for skill in ClassData.pool(StringName(family)):
			# The 28 star skills sit in the pools too; StarSkillSequence choreographs those.
			if not skill.has("star"):
				count += 1
	check(seen.size() == count and count == 252, "exactly the complete 252-skill catalogue")
	for rig in 3:
		for family in SkillShow.FAMILY_COLORS:
			var visual := HeroVisual.new()
			add_child(visual)
			visual.setup(StringName(family), "", true, {}, {} if rig == 2 else {"gender": rig})
			visual.set_process(false)
			for skill in ClassData.pool(StringName(family)):
				var source: Dictionary = skill.duplicate(true)
				var cue := SkillChoreography.cue_for(skill)
				check(bool(cue.choreographed), "authored motion: " + String(skill.id))
				check(visual.has_clip(String(cue.clip)), "available clip rig%d %s" % [rig, skill.id])
				for haste in [0.0, 0.35, 0.60]:
					var release: float = float(skill.hit_delay) * (1.0 - haste)
					var rest := visual.model.transform
					var origin := visual.global_transform
					visual.skill_action(skill, release)
					var initial_bones: Array[Transform3D] = []
					for bone in visual._skeleton.get_bone_count():
						initial_bones.append(visual._skeleton.get_bone_pose(bone))
					visual._advance_skill_motion(release)
					check(is_equal_approx(visual.anim.current_animation_position, float(cue.contact)), "release/contact synchronized: rig%d %s haste%.2f" % [rig, skill.id, haste])
					check(visual.model.transform.is_finite(), "finite pose: " + String(skill.id))
					var moved_bones := 0
					for bone in initial_bones.size():
						if not visual._skeleton.get_bone_pose(bone).is_equal_approx(initial_bones[bone]):
							moved_bones += 1
					check(moved_bones >= 2, "skeleton actually animates, not only its clock: " + String(skill.id))
					check(visual.global_transform.is_equal_approx(origin), "motion must not move gameplay root")
					visual._advance_skill_motion(float(cue.recovery) + 0.01)
					check(visual._skill_pose.is_empty() and visual.model.transform.is_equal_approx(rest), "recovery restores pose: " + String(skill.id))
					check(visual.current in ["Idle", "2H_Melee_Idle"], "locomotion resumes")
					check(skill == source, "animation never mutates skill data")
					cases += 1
				visual.skill_action(skill, float(skill.hit_delay))
				visual._advance_skill_motion(float(skill.hit_delay) * 0.5)
				visual.action("Hit_A")
				check(visual._skill_pose.is_empty(), "being hit interrupts manual sampling")
				visual.skill_action(skill, float(skill.hit_delay))
				visual._advance_skill_motion(float(skill.hit_delay) * 0.5)
				visual.release()
				check(visual._skill_pose.is_empty() and visual.busy_until == 0, "release cancels motion")
			visual.queue_free()
			await visual.tree_exited
	# Optional marks cannot hide the actual projectile at any quality.
	for quality in 3:
		GameSettings.quality = quality
		var field := Node3D.new()
		add_child(field)
		while VfxBudget.can_decorate():
			var reservation := Node.new()
			field.add_child(reservation)
			VfxBudget.track_decoration(reservation)
		var skill: Dictionary = ClassData.find_skill(&"archer", "meteor_arrow")
		var range_cue := SkillInk.telegraph(field, skill, Vector3.ZERO, 5.0, 0.1)
		check(range_cue != null and is_equal_approx(range_cue.scale.x * 0.83, 5.0), "essential range matches true radius at saturation")
		var projectile := SkillTableau.flight(field, skill, Vector3(0, 1, 0), Vector3(3, 1, 0), 0.1)
		check(projectile.has_node("EssentialSkillProjectile"), "essential projectile survives q%d saturation" % quality)
		check(VfxBudget.counters().decorations == VfxBudget.decoration_limit(), "flight obeys optional cap")
		await get_tree().create_timer(0.16).timeout
		check(not is_instance_valid(projectile), "flight cleans up at contact")
		field.queue_free()
		await field.tree_exited
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "no reservations after exit")
	print("SKILL CHOREOGRAPHY: %s | %d cases, %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", cases, checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
