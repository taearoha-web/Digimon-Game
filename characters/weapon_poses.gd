class_name WeaponPoses
extends RefCounted
## Load equipment-aware upper-body clips baked offline for each rig/class.
## Runtime animation remains AnimationPlayer interpolation, without runtime IK.
## Legs, root motion, length and skill release times remain those of the source.

const SAMPLES := 30.0
const DIRECTORY := "res://assets/animations/weapon_poses/"
## Set only by tools/bake_weapon_poses.gd. Shipping builds load small baked
## arm tracks; creating a hero never performs animation sampling or IK.
static var authoring := false
static var _libraries: Dictionary = {}


static func install(player: AnimationPlayer, skeleton: Skeleton3D, family: StringName, cache_key: String, corrections: Dictionary, gear_scale: float) -> void:
	var key := cache_key + ":" + String(family)
	if not _libraries.has(key):
		var original := player.get_animation_library("")
		var library := AnimationLibrary.new()
		var rig_name := "boy" if cache_key.contains("chibi_boy") else "girl" if cache_key.contains("chibi_girl") else "kaykit"
		var path := DIRECTORY + rig_name + "_" + String(family) + ".res"
		var overlay: AnimationLibrary
		if authoring:
			overlay = _bake(original, skeleton, family, _rig(skeleton, corrections, gear_scale))
			DirAccess.make_dir_recursive_absolute(DIRECTORY)
			var saved := ResourceSaver.save(overlay, path, ResourceSaver.FLAG_COMPRESS)
			assert(saved == OK, "Could not save weapon poses: " + path)
		else:
			overlay = load(path) as AnimationLibrary
			if overlay == null:
				push_error("Missing weapon poses: " + path)
				return
		for name in original.get_animation_list():
			var source := original.get_animation(name)
			if overlay.has_animation(name):
				var merged := source.duplicate() as Animation
				var arms := overlay.get_animation(name)
				for track in arms.get_track_count():
					var old := merged.find_track(arms.track_get_path(track), arms.track_get_type(track))
					if old >= 0:
						merged.remove_track(old)
					arms.copy_track(track, merged)
				library.add_animation(name, merged)
			else:
				library.add_animation(name, source)
		_libraries[key] = library
	player.remove_animation_library("")
	player.add_animation_library("", _libraries[key])


static func _bake(original: AnimationLibrary, skeleton: Skeleton3D, family: StringName, rig: Dictionary) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for name in original.get_animation_list():
		var source := original.get_animation(name)
		var carry := String(name) in ["Idle", "Running_A", "Running_B", "Walking_A", "Walking_B", "Fly_Hover", "Fly_Forward"] or (family == &"lancer" and String(name) == "2H_Melee_Idle")
		var bow_shot := family == &"archer" and String(name) in ["2H_Ranged_Shoot", "2H_Ranged_Shooting"]
		var spear := family == &"lancer" and (String(name).begins_with("2H_Melee_") or String(name).begins_with("Martial_") or String(name) in ["Block_Attack", "Blocking"])
		if carry or bow_shot or spear:
			library.add_animation(name, _build(source, original, skeleton, family, rig, String(name), carry, bow_shot, spear))
	return library


static func _rig(skeleton: Skeleton3D, corrections: Dictionary, gear_scale: float) -> Dictionary:
	var chibi := skeleton.find_bone("RightHand") >= 0
	var rig := {"scale": gear_scale, "chest": skeleton.find_bone("Chest" if chibi else "chest")}
	for side in ["r", "l"]:
		var prefix := "Right" if side == "r" else "Left"
		var arm := {
			"upper": skeleton.find_bone(prefix + "UpperArm" if chibi else "upperarm." + side),
			"lower": skeleton.find_bone(prefix + "LowerArm" if chibi else "lowerarm." + side),
			"hand": skeleton.find_bone(prefix + "Hand" if chibi else "wrist." + side),
			"slot": skeleton.find_bone("handslot." + side),
		}
		arm["slot_local"] = skeleton.get_bone_global_rest(arm.hand).affine_inverse() * skeleton.get_bone_global_rest(arm.slot)
		arm["correction"] = corrections.get(side, Basis.IDENTITY)
		arm["side"] = -1.0 if side == "r" else 1.0
		arm["length"] = skeleton.get_bone_rest(arm.lower).origin.length() + skeleton.get_bone_rest(arm.hand).origin.length()
		rig[side] = arm
	return rig


static func _track_map(animation: Animation, skeleton: Skeleton3D) -> Dictionary:
	var tracks := {}
	for t in animation.get_track_count():
		var path := animation.track_get_path(t)
		var index := skeleton.find_bone(String(path.get_concatenated_subnames()))
		if index < 0:
			continue
		if not tracks.has(index):
			tracks[index] = {}
		tracks[index][animation.track_get_type(t)] = t
	return tracks


static func _frame(animation: Animation, skeleton: Skeleton3D, tracks: Dictionary, time: float) -> Array[Transform3D]:
	var local: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		var pose := skeleton.get_bone_rest(bone)
		var bone_tracks: Dictionary = tracks.get(bone, {})
		if bone_tracks.has(Animation.TYPE_ROTATION_3D):
			pose.basis = Basis(animation.rotation_track_interpolate(bone_tracks[Animation.TYPE_ROTATION_3D], time))
		if bone_tracks.has(Animation.TYPE_POSITION_3D):
			pose.origin = animation.position_track_interpolate(bone_tracks[Animation.TYPE_POSITION_3D], time)
		local.append(pose)
	return local


static func _globals(skeleton: Skeleton3D, local: Array[Transform3D]) -> Array[Transform3D]:
	var global: Array[Transform3D] = []
	for bone in local.size():
		var parent := skeleton.get_bone_parent(bone)
		global.append(global[parent] * local[bone] if parent >= 0 else local[bone])
	return global


static func _rotation(skeleton: Skeleton3D, local: Array[Transform3D], bone: int, rotation: Basis) -> void:
	var global := _globals(skeleton, local)
	var parent := skeleton.get_bone_parent(bone)
	local[bone].basis = (global[parent].basis.inverse() * rotation if parent >= 0 else rotation).orthonormalized()


## Offline two-bone solve in model space, with a stable outward elbow hint.
## Targets refer to the centre of the closed hand's grip, not the wrist joint.
static func _hold(skeleton: Skeleton3D, local: Array[Transform3D], arm: Dictionary, target: Vector3, item_basis: Basis, kind: String) -> void:
	var global := _globals(skeleton, local)
	# KayKit animates its hand-slot axes separately from its wrist. Evaluate
	# that chain for this frame, including the small hand bone between them.
	var slot_local := global[arm.hand].affine_inverse() * global[arm.slot]
	var hand_basis := item_basis * (slot_local.basis * (arm.correction as Basis) * WeaponGrip.mount(kind)).inverse()
	var wrist := target - hand_basis * slot_local.origin
	var shoulder: Vector3 = global[arm.upper].origin
	var elbow: Vector3 = global[arm.lower].origin
	var old_wrist: Vector3 = global[arm.hand].origin
	var first := shoulder.distance_to(elbow)
	var second := elbow.distance_to(old_wrist)
	var offset := wrist - shoulder
	var distance := clampf(offset.length(), absf(first - second) + 0.0001, (first + second) * 0.985)
	var forward := offset.normalized()
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var bend: Vector3 = arm.get("pole", elbow - shoulder)
	bend -= forward * bend.dot(forward)
	if bend.length_squared() < 0.000001:
		bend = Vector3.DOWN - forward * Vector3.DOWN.dot(forward)
	bend = bend.normalized()
	var elbow_target := shoulder + forward * along + bend * sqrt(maxf(0.0, first * first - along * along))
	var wrist_target := shoulder + forward * distance
	var upper_turn := Quaternion(arm.upper_direction, (elbow_target - shoulder).normalized())
	_rotation(skeleton, local, arm.upper, Basis(upper_turn) * (arm.upper_basis as Basis))
	global = _globals(skeleton, local)
	var lower_turn := Quaternion(arm.lower_direction, (wrist_target - global[arm.lower].origin).normalized())
	_rotation(skeleton, local, arm.lower, Basis(lower_turn) * (arm.lower_basis as Basis))
	_rotation(skeleton, local, arm.hand, hand_basis)


## The chibi has short arms. Project a shared weapon grip into both arms'
## reachable spheres before solving either arm, keeping the support hand on
## the spear shaft or bow string after the main hand reaches its target.
static func _shared_grip(skeleton: Skeleton3D, local: Array[Transform3D], rig: Dictionary, target: Vector3, bases: Dictionary, offsets: Dictionary, kinds: Dictionary) -> Vector3:
	var global := _globals(skeleton, local)
	for iteration in 12:
		for side in ["r", "l"]:
			var arm: Dictionary = rig[side]
			var slot_local := global[arm.hand].affine_inverse() * global[arm.slot]
			var hand_basis: Basis = bases[side] * (slot_local.basis * (arm.correction as Basis) * WeaponGrip.mount(kinds[side])).inverse()
			var centre: Vector3 = global[arm.upper].origin + hand_basis * slot_local.origin - offsets[side]
			var offset := target - centre
			var reach := float(arm.length) * 0.965
			if offset.length() > reach:
				target = centre + offset.normalized() * reach
	return target


static func _along(axis: Vector3, right := Vector3.RIGHT) -> Basis:
	var y := axis.normalized()
	var x := (right - y * right.dot(y)).normalized()
	return Basis(x, y, x.cross(y)).orthonormalized()


static func _build(source: Animation, library: AnimationLibrary, skeleton: Skeleton3D, family: StringName, rig: Dictionary, name: String, carry: bool, bow_shot: bool, spear: bool) -> Animation:
	var result := Animation.new()
	result.length = source.length
	result.loop_mode = source.loop_mode
	var tracks := _track_map(source, skeleton)
	var idle := library.get_animation("Idle")
	var idle_tracks := _track_map(idle, skeleton)
	var idle_globals := _globals(skeleton, _frame(idle, skeleton, idle_tracks, 0.25))
	var arm_bones: Array[int] = []
	for side in ["r", "l"]:
		for key in ["upper", "lower", "hand"]:
			arm_bones.append(int(rig[side][key]))
	var output_tracks := {}
	var prefix := String(source.track_get_path(0)).split(":")[0]
	for bone in arm_bones:
		var path := NodePath("%s:%s" % [prefix, skeleton.get_bone_name(bone)])
		var track := result.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = result.add_track(Animation.TYPE_ROTATION_3D)
			result.track_set_path(track, path)
		while result.track_get_key_count(track) > 0:
			result.track_remove_key(track, 0)
		output_tracks[bone] = track
	var steps := maxi(12, ceili(source.length * SAMPLES))
	var moving := name.begins_with("Running") or name.begins_with("Walking") or name == "Fly_Forward"
	for k in steps + 1:
		var time := source.length * float(k) / float(steps)
		var phase := float(k) / float(steps)
		var sway := sin(TAU * phase)
		var local := _frame(source, skeleton, tracks, time)
		var global := _globals(skeleton, local)
		var chest: Transform3D = global[rig.chest]
		var body := (chest.basis * skeleton.get_bone_global_rest(rig.chest).basis.inverse()).orthonormalized()
		var arm_length: float = rig.r.length
		var reference_turn := chest.basis * idle_globals[rig.chest].basis.inverse()
		for side in ["r", "l"]:
			var arm: Dictionary = rig[side]
			arm["pole"] = body * Vector3(float(arm.side), -0.7, -0.6)
			# A stable reference twist prevents the shortest-arc solve from
			# rolling an elbow when the original attack crosses 180 degrees.
			arm["upper_basis"] = reference_turn * idle_globals[arm.upper].basis
			arm["lower_basis"] = reference_turn * idle_globals[arm.lower].basis
			arm["upper_direction"] = reference_turn * (idle_globals[arm.lower].origin - idle_globals[arm.upper].origin).normalized()
			arm["lower_direction"] = reference_turn * (idle_globals[arm.hand].origin - idle_globals[arm.lower].origin).normalized()
		if carry:
			# Restrained arm swing leaves the original hips, breathing and gait.
			for side in ["r", "l"]:
				var arm: Dictionary = rig[side]
				var sign_side := -1.0 if side == "r" else 1.0
				var amplitude := 0.13 if moving else 0.015
				if side == "l" and family in [&"warrior", &"priest", &"summoner"]:
					amplitude *= 0.35
				for joint in ["upper", "lower", "hand"]:
					var bone: int = arm[joint]
					var turn := Basis(Vector3.RIGHT, sway * amplitude * sign_side)
					_rotation(skeleton, local, bone, turn * idle_globals[bone].basis)
			if family in [&"mage", &"summoner", &"priest"]:
				global = _globals(skeleton, local)
				var shoulder: Vector3 = global[rig.r.upper].origin
				var target := shoulder + Vector3(-0.16, -0.54, 0.60) * arm_length
				target.z += sway * arm_length * (0.045 if moving else 0.015)
				var pitch := deg_to_rad(12.0 if family != &"priest" else 30.0) + sway * 0.035
				var item_basis := _along(Vector3(0, cos(pitch), sin(pitch)), Vector3.FORWARD)
				_hold(skeleton, local, rig.r, target, item_basis, "wand" if family == &"priest" else "staff")
		if family == &"archer":
			global = _globals(skeleton, local)
			var shoulder: Vector3 = global[rig.l.upper].origin
			var target := shoulder + Vector3(-0.1, -0.45, 0.64) * arm_length
			var bow_basis := Basis(Vector3.BACK, -0.08 + sway * 0.03)
			if bow_shot:
				# The torso turns to draw, but the bow aims along the hero's
				# actual facing direction, rather than into the rotated torso.
				target = (shoulder + global[rig.r.upper].origin) * 0.5 + Vector3(0.08, -0.10, 0.86) * arm_length
				bow_basis = Basis.IDENTITY
				var pull := sin(PI * clampf(time / 0.46, 0.0, 1.0)) * arm_length * 0.20
				var draw := Vector3(0, 0, -0.095 * 2.2 * float(rig.scale) - pull)
				var right_item: Basis = global[rig.r.slot].basis * (rig.r.correction as Basis) * WeaponGrip.mount("sword")
				target = _shared_grip(skeleton, local, rig, target, {"r": right_item, "l": bow_basis}, {"r": draw, "l": Vector3.ZERO}, {"r": "sword", "l": "bow"})
				_hold(skeleton, local, rig.l, target, bow_basis, "bow")
				_hold(skeleton, local, rig.r, target + draw, right_item, "sword")
			else:
				_hold(skeleton, local, rig.l, target, bow_basis, "bow")
		if family == &"lancer":
			var pulse := sin(PI * phase) if spear and not carry else 0.0
			var axis := body * Vector3(0.13, 0.52 if carry else 0.10, 1.0).normalized()
			var right := chest.origin + body * Vector3(-0.08, -0.36, 0.25 + pulse * 0.10) * arm_length
			if name=="Martial_GroundSlam":
				var gather := smoothstep(0.0,0.25,time)
				var strike := smoothstep(0.25,0.46,time)
				var recover := smoothstep(0.55,source.length,time)
				var pitch := lerpf(1.25*gather,-0.75,strike)*(1.0-recover)
				axis=body*Vector3(0.13,sin(pitch),cos(pitch)).normalized()
				right=chest.origin+body*Vector3(-0.08,-0.16+0.48*gather*(1.0-strike),0.26+0.14*strike)*arm_length
			elif name=="Martial_SpearThrow":
				var gather := smoothstep(0.0,0.44,time)
				var strike := smoothstep(0.44,0.72,time)
				var recover := smoothstep(0.80,source.length,time)
				var pitch := lerpf(0.52*gather,0.04,strike)*(1.0-recover)
				axis=body*Vector3(0.13,sin(pitch),cos(pitch)).normalized()
				right=chest.origin+body*Vector3(-0.08,lerpf(-0.26+0.40*gather,-0.22,strike),lerpf(0.28-0.18*gather,0.45,strike))*arm_length
			var item_basis := _along(axis, body * Vector3.RIGHT)
			var spacing := arm_length * 0.28
			right = _shared_grip(skeleton, local, rig, right, {"r": item_basis, "l": item_basis}, {"r": Vector3.ZERO, "l": axis * spacing}, {"r": "spear", "l": "spear"})
			_hold(skeleton, local, rig.r, right, item_basis, "spear")
			# Resolve the support hand from the actual main grip after reach clamping.
			global = _globals(skeleton, local)
			var grip: Vector3 = global[rig.r.slot].origin
			var support := grip + axis * spacing
			_hold(skeleton, local, rig.l, support, item_basis, "spear")
		for bone in arm_bones:
			result.rotation_track_insert_key(output_tracks[bone], time, local[bone].basis.get_rotation_quaternion())
	return result
