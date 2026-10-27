extends Node3D
## Exercise rendered weapon geometry against posed hand bones, across all
## equipment tiers and all three rigs. Uses an isolated test data directory.
var checks := 0
var failures: Array[String] = []
var max_grip_error := 0.0
var max_support_error := 0.0
var min_torso_clearance := 9.0
var min_pole_up := 1.0
var _source_grips: Dictionary = {}


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		if failures.size() <= 30:
			printerr("FAIL: ", message)


func pose(hero: HeroVisual, clip: String, fraction: float) -> void:
	hero.release()
	hero.play(clip, 0.0)
	hero.anim.seek(hero.anim.get_animation(hero.current).length * fraction, true)
	hero.anim.pause()
	hero._skeleton.force_update_all_bone_transforms()


## Smallest distance from the spear's shaft line (butt to tip) to the hips-neck
## axis, in units of a conservative torso radius (0.3 x shoulder span). Below 1
## means the shaft passes through the body.
func torso_clearance(hero: HeroVisual, asset: Node3D) -> float:
	var s := hero._skeleton
	var chibi := s.find_bone("RightHand") >= 0
	var bone := func(n: String) -> Vector3:
		return s.global_transform * s.get_bone_global_pose(s.find_bone(n)).origin
	var low: Vector3 = bone.call("Hips" if chibi else "hips")
	var high: Vector3 = bone.call("Neck" if chibi else "head")
	var radius := 0.3 * (bone.call("LeftUpperArm" if chibi else "upperarm.l") as Vector3).distance_to(bone.call("RightUpperArm" if chibi else "upperarm.r"))
	var span := Vector2(INF, -INF)
	for mi in asset.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := asset.global_transform.affine_inverse() * m.global_transform
		var b := t * m.get_aabb()
		span = Vector2(minf(span.x, b.position.y), maxf(span.y, b.end.y))
	var transform := posed_transform(asset)
	var best := INF
	for k in 41:
		var p := transform * Vector3(0, lerpf(span.x, span.y, float(k) / 40.0), 0)
		var on_axis := Geometry3D.get_closest_point_to_segment(p, low, high)
		best = minf(best, p.distance_to(on_axis) / radius)
	return best


func palm(hero: HeroVisual, side: String) -> Vector3:
	return hero._skeleton.global_transform * hero._skeleton.get_bone_global_pose(hero._skeleton.find_bone("handslot." + side)).origin


func held(hero: HeroVisual, kind: String) -> Node3D:
	return hero._skeleton.find_child("Held_" + kind + "_*", true, false) as Node3D


## BoneAttachment updates at the render boundary. Use the bone's current pose
## here so hundreds of deterministic samples need not wait hundreds of frames.
## Actual attachment updates are also checked in the rendered review fixture.
func posed_transform(node: Node3D) -> Transform3D:
	var attachment: Node = node
	while not attachment is BoneAttachment3D:
		attachment = attachment.get_parent()
	var skeleton := attachment.get_parent() as Skeleton3D
	var relative := (attachment as Node3D).global_transform.affine_inverse() * node.global_transform
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(attachment.bone_name)) * relative


func grip(item: Node3D, kind: String) -> Vector3:
	# Merging removes individual handle nodes. Read the reference grip from the
	# unchanged source GLB, then use the actual held model's current bone pose.
	# field_efficiency_test separately checks every triangle/material survives merging.
	var look := String(item.name).trim_prefix("Held_")
	if not _source_grips.has(look):
		var source := (load(WeaponKit.MODEL_DIR + look + ".glb") as PackedScene).instantiate() as Node3D
		_source_grips[look] = _source_grip(source, kind)
		source.free()
	var model := item.get_child(0).get_child(0).get_child(0) as Node3D
	return posed_transform(model) * (_source_grips[look] as Vector3)


func _source_grip(item: Node3D, kind: String) -> Vector3:
	match kind:
		"dagger", "greatshield", "scepter", "lute":
			# Authored / imported with the grip at the origin.
			return Vector3.ZERO
		"sword":
			for node in item.find_children("*", "MeshInstance3D", true, false):
				var mesh := node as MeshInstance3D
				var box := mesh.get_aabb()
				if box.size.y > 0.16 and box.size.y < 0.19 and box.size.x < 0.05 and box.get_center().length() < 0.01:
					return MeshMerge._relative(mesh, item) * box.get_center()
			assert(false, "sword grip missing")
		"bow":
			for node in item.find_children("*", "MeshInstance3D", true, false):
				var mesh := node as MeshInstance3D
				var box := mesh.get_aabb()
				if box.size.y > 0.10 and box.size.y < 0.14 and box.size.x < 0.055 and box.size.x > 0.03 and box.get_center().length() < 0.005:
					return MeshMerge._relative(mesh, item) * box.get_center()
			assert(false, "bow grip missing")
		"shield":
			for node in item.find_children("*", "MeshInstance3D", true, false):
				var mesh := node as MeshInstance3D
				var box := mesh.get_aabb()
				if box.size.x > 0.18 and box.size.x < 0.23 and box.size.y < 0.05 and box.get_center().z < -0.055:
					return MeshMerge._relative(mesh, item) * box.get_center()
			assert(false, "shield handle missing")
	var bottom: MeshInstance3D
	var top: MeshInstance3D
	for node in item.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box := mesh.get_aabb()
		var centre := box.get_center()
		if box.size.y < 0.013 and box.size.x > 0.035 and box.size.x < 0.07 and absf(centre.y) < 0.096 and absf(centre.x) < 0.005 and absf(centre.z) < 0.005:
			if bottom == null or centre.y < bottom.get_aabb().get_center().y:
				bottom = mesh
			if top == null or centre.y > top.get_aabb().get_center().y:
				top = mesh
	assert(bottom != null and top != null, "grip wraps missing: " + kind)
	return (MeshMerge._relative(bottom, item) * bottom.get_aabb().get_center() + MeshMerge._relative(top, item) * top.get_aabb().get_center()) * 0.5


func _ready() -> void:
	Game.set_process(false)
	GameSettings.quality = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 710
	var families: Array[StringName] = [ClassData.START]
	families.append_array(ClassData.IDS)
	for rig in 3:
		for family in families:
			var hero := HeroVisual.new()
			add_child(hero)
			hero.setup(family, "", true, {}, {} if rig == 2 else {"gender": rig})
			hero.set_process(false)
			var kind := String(ClassData.get_class_data(family).weapon_kind)
			var tag := "rig%d %s" % [rig, family]
			var attack := String(ClassData.get_class_data(family).attack.anims[0])
			for tier in 10:
				hero.equip = {"weapon": ItemData.generate(tier * 10 + 5, family, rng, 0, "weapon")}
				hero.equip.weapon["plus"] = 0
				hero.refresh()
				for clip in ["Idle", "Running_A", attack]:
					pose(hero, clip, 0.35)
					var error := grip(held(hero, kind), kind).distance_to(palm(hero, WeaponGrip.hand_for(kind).trim_prefix("handslot.")))
					max_grip_error = maxf(max_grip_error, error)
					check(error < 0.015, "%s tier%d %s actual grip %.4fm" % [tag, tier, clip, error])
					if family == &"warrior":
						error = grip(held(hero, "shield"), "shield").distance_to(palm(hero, "l"))
						check(error < 0.015, "%s tier%d shield back handle %.4fm" % [tag, tier, error])
			# Sample whole loops, not just a favourable screenshot phase.
			var clips := ["Idle", "Running_A", "Walking_A"]
			if rig != 2:
				clips.append_array(["Fly_Hover", "Fly_Forward"])
			if family in [&"archer", &"lancer"]:
				clips.append(attack)
			if family == &"lancer":
				for clip in hero.anim.get_animation_list():
					if (String(clip).begins_with("2H_Melee_") or String(clip).begins_with("Martial_") or clip in ["Blocking", "Block_Attack"]) and clip not in clips:
						clips.append(String(clip))
			if family == &"archer":
				clips.append("2H_Ranged_Shooting")
			if family == &"bard":
				# The lute stays on the neck through the stance and every clip it plays.
				for clip in ["Spellcasting"] + WeaponPoses.BARD_LEFT_CLIPS:
					if clip not in clips:
						clips.append(clip)
			for clip in clips:
				var last: Array[Quaternion] = []
				for frame in 61:
					pose(hero, clip, float(frame) / 60.0)
					var asset := held(hero, kind).get_child(0).get_child(0).get_child(0) as Node3D
					if family in [&"mage", &"summoner"]:
						var up := posed_transform(asset).basis.y.normalized().dot(Vector3.UP)
						min_pole_up = minf(min_pole_up, up)
						check(up > 0.94, "%s %s frame%d pole upright %.3f" % [tag, clip, frame, up])
						if family == &"summoner":
							check(posed_transform(asset).basis.x.normalized().z > 0.9, "%s %s lantern hangs in front" % [tag, clip])
					if family == &"warrior":
						var shield := held(hero, "shield").get_child(0).get_child(0).get_child(0) as Node3D
						check(posed_transform(shield).basis.z.normalized().x > 0.65, "%s %s shield face outward" % [tag, clip])
						check(posed_transform(shield).basis.y.normalized().y > 0.65, "%s %s shield top upright" % [tag, clip])
					if family == &"lancer":
						var offset := palm(hero, "l") - palm(hero, "r")
						var axis := posed_transform(asset).basis.y.normalized()
						var error := (offset - axis * offset.dot(axis)).length()
						max_support_error = maxf(max_support_error, error)
						check(error < 0.035, "%s %s frame%d support hand %.4fm from shaft" % [tag, clip, frame, error])
						# The whole shaft, tail included, must pass outside the torso.
						var clearance := torso_clearance(hero, asset)
						min_torso_clearance = minf(min_torso_clearance, clearance)
						# Walking, standing, thrusts and slashes must clear it fully; the
						# short guard/skill swings may graze the torso's edge.
						var needed := 0.55 if (String(clip).begins_with("Martial_") or String(clip).begins_with("Block")) else 1.0
						check(clearance > needed, "%s %s frame%d spear shaft clears the torso (%.2f)" % [tag, clip, frame, clearance])
					if family == &"archer" and String(clip).begins_with("2H_Ranged_"):
						var bow_basis := posed_transform(asset).basis.orthonormalized()
						check(bow_basis.y.dot(Vector3.UP) > 0.995 and bow_basis.z.dot(Vector3.BACK) > 0.995, tag + " bow stays upright and aims forward")
						var hands := palm(hero, "r") - palm(hero, "l")
						check(Vector2(hands.x, hands.y).length() < 0.035 and hands.z < -0.04, tag + " drawing hand aligned behind bow string")
					var rotations: Array[Quaternion] = []
					for bone in hero._skeleton.get_bone_count():
						var name := hero._skeleton.get_bone_name(bone)
						if name.contains("Arm") or name.contains("arm.") or name.contains("wrist.") or name in ["RightHand", "LeftHand", "hand.r", "hand.l"]:
							var rotation := hero._skeleton.get_bone_pose_rotation(bone)
							check(rotation.is_finite(), "%s %s finite arm pose" % [tag, clip])
							if not last.is_empty():
								check(absf(rotation.dot(last[rotations.size()])) > cos(0.65 / 2.0), "%s %s frame%d arm flip %s" % [tag, clip, frame, name])
							rotations.append(rotation)
					last = rotations
			pose(hero, "Running_A", 0.25)
			hero.play("Running_A", 0.0, 1.0)
			hero.play("Running_A", 0.0, 1.5)
			check(is_equal_approx(hero.anim.speed_scale, 1.5), tag + " running speed responds without restarting")
			var before: Array[Transform3D] = []
			for bone in hero._skeleton.get_bone_count():
				before.append(hero._skeleton.get_bone_pose(bone))
			var skill: Dictionary = ClassData.pool(family)[0]
			hero.skill_action(skill, 0.3)
			for bone in before.size():
				check(before[bone].is_equal_approx(hero._skeleton.get_bone_pose(bone)), tag + " no initial cast pop")
			hero._advance_skill_motion(0.3)
			var cast := hero.anim.get_animation(hero.current)
			var expected := WeaponPoses._frame(cast, hero._skeleton, WeaponPoses._track_map(cast, hero._skeleton), hero.anim.current_animation_position)
			for bone in before.size():
				var name := hero._skeleton.get_bone_name(bone)
				if name.contains("Leg") or name.contains("Foot") or name.contains("leg.") or name.contains("foot."):
					check(expected[bone].is_equal_approx(hero._skeleton.get_bone_pose(bone)), tag + " standing cast clears the running leg pose: " + name)
			hero.play("Running_A", 0.15, 1.2)
			hero._advance_skill_motion(float(SkillChoreography.cue_for(skill).recovery) + 0.01)
			check(hero.current == "Running_A" and is_equal_approx(hero.anim.speed_scale, 1.2), tag + " resumes latest movement after recovery")
			hero.free()
			print("CHECKED: ", tag)
	print("WEAPON MOTION: %s | %d checks, %d failures | max grip %.4fm, support %.4fm, min pole up %.4f, spear torso clearance %.2f" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), max_grip_error, max_support_error, min_pole_up, min_torso_clearance])
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		FileAccess.open(args[0], FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "grip_error": max_grip_error, "support_error": max_support_error, "pole_up": min_pole_up}, "\t"))
	get_tree().quit(0 if failures.is_empty() else 1)
