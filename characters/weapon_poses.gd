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
	var rig := {"scale": gear_scale, "chest": skeleton.find_bone("Chest" if chibi else "chest"),
		"hips": skeleton.find_bone("Hips" if chibi else "hips"), "neck": skeleton.find_bone("Neck" if chibi else "head")}
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
		# The bones from the hand slot up to (not including) the wrist: KayKit
		# animates its hand and slot separately from the wrist.
		var chain: Array[int] = []
		var link: int = arm.slot
		while link >= 0 and link != int(arm.hand):
			chain.append(link)
			link = skeleton.get_bone_parent(link)
		arm["chain"] = chain if link == int(arm.hand) else []
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
	# Swing both bones so that the elbow's hinge axis follows the idle one: a
	# shortest arc alone rolls the elbow over (and the wrist with it) between
	# two neighbouring frames once the arm swings nearly opposite its idle
	# direction, as the KayKit rig's overhead chop and throw do.
	var hinge := (elbow_target - shoulder).cross(wrist_target - elbow_target)
	_rotation(skeleton, local, arm.upper, _swing(arm.upper_direction, arm.hinge, (elbow_target - shoulder).normalized(), hinge) * (arm.upper_basis as Basis))
	global = _globals(skeleton, local)
	_rotation(skeleton, local, arm.lower, _swing(arm.lower_direction, arm.hinge, (wrist_target - global[arm.lower].origin).normalized(), hinge) * (arm.lower_basis as Basis))
	_rotation(skeleton, local, arm.hand, hand_basis)


## Rotation taking the unit direction [param from] to [param to] whose roll
## also takes the bend-plane normal [param from_hinge] onto [param to_hinge].
## Fully determined by the two bend planes, so it stays continuous where a
## shortest arc would not; a straight (hinge-less) arm keeps the shortest arc.
static func _swing(from: Vector3, from_hinge: Vector3, to: Vector3, to_hinge: Vector3) -> Basis:
	var start := _bend_frame(from, from_hinge)
	var finish := _bend_frame(to, to_hinge)
	if start == Basis.IDENTITY or finish == Basis.IDENTITY:
		return Basis(Quaternion(from, to))
	return finish * start.inverse()


static func _bend_frame(direction: Vector3, hinge: Vector3) -> Basis:
	var x := direction.normalized()
	var y := hinge - x * hinge.dot(x)
	if y.length() < 0.001:
		return Basis.IDENTITY
	y = y.normalized()
	return Basis(x, y, x.cross(y))


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

## Shaft clearance (in torso radii) wanted when baking, and the most the spear
## may turn further across the body to get it.
const SPEAR_CLEARANCE := 1.15


## One adjustment per clip, (extra turn across the body in degrees, extra lift
## of the spear head in degrees, outward shift of the main hand in arm units,
## grip width in arm lengths):
## the smallest change that keeps the whole shaft out of the torso in every
## sampled frame, or the clearest one when none fully does.
static func _spear_tune(source: Animation, skeleton: Skeleton3D, tracks: Dictionary, rig: Dictionary, idle_globals: Array[Transform3D], name: String, steps: int, carry: bool, spear: bool) -> Vector4:
	var best := Vector4(0, 0, 0, 0.62)
	var best_cost := INF
	var clearest := Vector4(0, 0, 0, 0.62)
	var clearest_value := -INF
	var stride := 1 if name.begins_with("Martial_") else 3
	var arm_bones: Array[int] = []
	for side in ["r", "l"]:
		for key in ["upper", "lower", "hand"]:
			arm_bones.append(int(rig[side][key]))
	for turn in [0.0, 10.0, 20.0, 30.0, 40.0]:
		for lift in [0.0, 10.0, -10.0, 20.0]:
			for out in [0.0, 0.1, 0.2, 0.3]:
				for grip in [0.62, 0.5, 0.4]:
					var tune := Vector4(float(turn), float(lift), float(out), float(grip))
					var worst := INF
					var steady := true
					var last: Array[Quaternion] = []
					for k in range(0, steps + 1, stride):
						var time := source.length * float(k) / float(steps)
						var local := _frame(source, skeleton, tracks, time)
						var global := _globals(skeleton, local)
						var chest: Transform3D = global[rig.chest]
						var body := (chest.basis * skeleton.get_bone_global_rest(rig.chest).basis.inverse()).orthonormalized()
						_prepare_arms(rig, body, chest.basis * idle_globals[rig.chest].basis.inverse(), idle_globals)
						var result := _spear_hold(skeleton, local, rig, body, chest, name, time, float(k) / float(steps), source.length, carry, spear, tune)
						worst = minf(worst, result.x)
						# The support hand must stay on the shaft and no elbow may
						# flip between neighbouring samples.
						if result.y > 0.05:
							steady = false
						var now: Array[Quaternion] = []
						for bone in arm_bones:
							now.append(local[bone].basis.get_rotation_quaternion())
						if not last.is_empty():
							for i in now.size():
								if absf(now[i].dot(last[i])) < cos(0.45 / 2.0) * (1.0 if stride == 1 else 0.0):
									steady = false
						last = now
					if not steady:
						continue
					if worst > clearest_value:
						clearest_value = worst
						clearest = tune
					var cost: float = turn + absf(lift) + out * 100.0 + (0.62 - grip) * 60.0
					if worst >= SPEAR_CLEARANCE and cost < best_cost:
						best_cost = cost
						best = tune
	if best_cost == INF and clearest_value == -INF:
		# Every adjustment flipped an elbow or lost the support hand: the baked
		# clip will fail weapon_motion_test, so say so at bake time.
		push_warning("WeaponPoses: no steady spear hold for %s on this rig" % name)
	return best if best_cost < INF else clearest


static func _prepare_arms(rig: Dictionary, body: Basis, reference_turn: Basis, idle_globals: Array[Transform3D]) -> void:
	for side in ["r", "l"]:
		var arm: Dictionary = rig[side]
		arm["pole"] = body * Vector3(float(arm.side), -0.7, -0.6)
		# A stable reference twist prevents the shortest-arc solve from
		# rolling an elbow when the original attack crosses 180 degrees.
		arm["upper_basis"] = reference_turn * idle_globals[arm.upper].basis
		arm["lower_basis"] = reference_turn * idle_globals[arm.lower].basis
		arm["upper_direction"] = reference_turn * (idle_globals[arm.lower].origin - idle_globals[arm.upper].origin).normalized()
		arm["lower_direction"] = reference_turn * (idle_globals[arm.hand].origin - idle_globals[arm.lower].origin).normalized()
		# The idle elbow's hinge axis (its arm bends 30-55 degrees on every rig).
		arm["hinge"] = reference_turn * (idle_globals[arm.lower].origin - idle_globals[arm.upper].origin).cross(idle_globals[arm.hand].origin - idle_globals[arm.lower].origin).normalized()


## Two-handed spear hold for one frame. Returns (x) how far the whole shaft,
## tail included, stays from the hips-neck axis, in units of a torso radius
## (0.3 x shoulder span), and (y) how far the support hand is off the shaft,
## in arm lengths, so the bake can pick an adjustment that keeps both right.
static func _spear_hold(skeleton: Skeleton3D, local: Array[Transform3D], rig: Dictionary, body: Basis, chest: Transform3D, name: String, time: float, phase: float, length: float, carry: bool, spear: bool, tune: Vector4) -> Vector2:
	# Both hands close on the shaft: the source's one-handed hand and slot
	# twists (a sword chop snaps the slot 0.5 rad in one frame) would only
	# have to be undone at the wrist, flipping it and dragging the arm along.
	for side in ["r", "l"]:
		for bone in rig[side].chain:
			local[bone].basis = skeleton.get_bone_rest(bone).basis
	var global := _globals(skeleton, local)
	# Measured in the torso's size, not the arm's: a short-armed rig reaches
	# as far as it can rather than holding the spear closer to its chest.
	var arm_length: float = maxf(rig.r.length, 0.76 * global[rig.l.upper].origin.distance_to(global[rig.r.upper].origin))
	var extra_turn := tune.x
	var lift := tune.y
	# The chibi's arms are shorter than the spear's tail behind the main
	# grip, so a spear pointing straight ahead always ran through the
	# torso. Both holds turn the shaft across the body instead: the tail
	# passes the right hip, the head points forward-left, and the support
	# hand takes a wide grip further up the shaft.
	var shaft := func(yaw_deg: float, pitch_deg: float) -> Vector3:
		var yaw := deg_to_rad(yaw_deg)
		var pitch := deg_to_rad(pitch_deg)
		return (body * Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))).normalized()
	var pulse := sin(PI * phase) if spear and not carry else 0.0
	# Carry: a diagonal port-arms hold. Fight: a low forward guard.
	var axis: Vector3 = shaft.call(52.0 + extra_turn, 50.0 + lift) if carry else shaft.call(50.0 + extra_turn, 20.0 + lift)
	var right := chest.origin + body * (Vector3(-0.20, -0.25, 0.60) if carry else Vector3(-0.45, -0.18, 0.36)) * arm_length
	right += axis * pulse * 0.10 * arm_length
	if name=="Martial_GroundSlam":
		var gather := smoothstep(0.0,0.25,time)
		var strike := smoothstep(0.25,0.46,time)
		var recover := smoothstep(0.55,length,time)
		# Raised to head height, not overhead, and struck down at a shallow angle:
		# steeper swings brought the tail through the neck and flipped the elbows.
		var pitch := lerpf(0.85*gather,-0.30,strike)*(1.0-recover) + 0.35*recover
		axis=shaft.call(50.0 + extra_turn, rad_to_deg(pitch) + lift)
		right=chest.origin+body*Vector3(-0.45,-0.16+0.30*gather*(1.0-strike),0.30+0.10*strike)*arm_length
	elif name=="Martial_SpearThrow":
		var gather := smoothstep(0.0,0.44,time)
		var strike := smoothstep(0.44,0.72,time)
		var recover := smoothstep(0.80,length,time)
		var pitch := lerpf(0.52*gather,0.10,strike)*(1.0-recover) + 0.35*recover
		axis=shaft.call(lerpf(50.0, 42.0, strike*(1.0-recover)) + extra_turn, rad_to_deg(pitch) + lift)
		right=chest.origin+body*Vector3(-0.45,lerpf(-0.18+0.30*gather,-0.18,strike),lerpf(0.34-0.10*gather,0.48,strike))*arm_length
	right += body * Vector3(-tune.z, 0, 0) * arm_length
	var item_basis := _along(axis, body * Vector3.RIGHT)
	# The support hand slides up the shaft only as far as its own arm reaches.
	var spacing := float(rig.r.length) * tune.w
	right = _shared_grip(skeleton, local, rig, right, {"r": item_basis, "l": item_basis}, {"r": Vector3.ZERO, "l": axis * spacing}, {"r": "spear", "l": "spear"})
	_hold(skeleton, local, rig.r, right, item_basis, "spear")
	# Resolve the support hand from the actual main grip after reach clamping.
	global = _globals(skeleton, local)
	var grip: Vector3 = global[rig.r.slot].origin
	var support := grip + axis * spacing
	_hold(skeleton, local, rig.l, support, item_basis, "spear")
	global = _globals(skeleton, local)
	var low: Vector3 = global[rig.hips].origin
	var high: Vector3 = global[rig.neck].origin
	var radius := 0.3 * global[rig.l.upper].origin.distance_to(global[rig.r.upper].origin)
	var grip_now: Vector3 = global[rig.r.slot].origin
	var nearest := INF
	# Spear models: 0.65 (scaled) behind the grip, up to 2.0 ahead.
	for k in 41:
		var along := lerpf(-0.65, 2.0, float(k) / 40.0) * float(rig.scale)
		var p := grip_now + axis * along
		nearest = minf(nearest, p.distance_to(Geometry3D.get_closest_point_to_segment(p, low, high)) / radius)
	# How far the support hand ended up from the shaft line (reach clamping).
	var offset: Vector3 = global[rig.l.slot].origin - grip_now
	var miss := (offset - axis * offset.dot(axis)).length() / arm_length
	return Vector2(nearest, miss)


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
		if family == &"lancer":
			arm_bones.append_array(rig[side].chain)
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
	# The spear turns further across the body when this clip's torso motion
	# would bring the shaft through it. One turn per clip keeps the arms steady.
	var spear_tune := Vector4(0, 0, 0, 0.62)
	if family == &"lancer":
		spear_tune = _spear_tune(source, skeleton, tracks, rig, idle_globals, name, steps, carry, spear)
	for k in steps + 1:
		var time := source.length * float(k) / float(steps)
		var phase := float(k) / float(steps)
		var sway := sin(TAU * phase)
		var local := _frame(source, skeleton, tracks, time)
		var global := _globals(skeleton, local)
		var chest: Transform3D = global[rig.chest]
		var body := (chest.basis * skeleton.get_bone_global_rest(rig.chest).basis.inverse()).orthonormalized()
		var arm_length: float = rig.r.length
		_prepare_arms(rig, body, chest.basis * idle_globals[rig.chest].basis.inverse(), idle_globals)
		if carry:
			# Restrained arm swing leaves the original hips, breathing and gait.
			for side in ["r", "l"]:
				var arm: Dictionary = rig[side]
				var sign_side := -1.0 if side == "r" else 1.0
				var amplitude := 0.13 if moving else 0.015
				if side == "l" and family in [&"warrior", &"priest", &"summoner", &"defender", &"darklord"]:
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
		if family == &"darklord" and carry:
			# The scepter upright in the right hand like a staff; the left forearm
			# raised level across the body, fist closed: the raven's perch.
			global = _globals(skeleton, local)
			var shoulder: Vector3 = global[rig.r.upper].origin
			var target := shoulder + Vector3(-0.16, -0.54, 0.60) * arm_length
			target.z += sway * arm_length * (0.045 if moving else 0.015)
			var pitch := deg_to_rad(16.0) + sway * 0.035
			_hold(skeleton, local, rig.r, target, _along(Vector3(0, cos(pitch), sin(pitch)), Vector3.FORWARD), "staff")
			var left: Vector3 = global[rig.l.upper].origin
			var perch := left + Vector3(-0.22, -0.42, 0.62) * arm_length
			perch.y += sway * arm_length * (0.02 if moving else 0.008)
			_hold(skeleton, local, rig.l, perch, _along(Vector3(-0.9, 0.1, 0.4), Vector3.UP), "sword")
		if family == &"assassin" and carry:
			# Twin daggers held low in front, points forward and a little out,
			# edges up and down: the stance of a hunter ready to lunge.
			global = _globals(skeleton, local)
			for side in ["r", "l"]:
				var arm: Dictionary = rig[side]
				var out := -1.0 if side == "r" else 1.0
				var shoulder: Vector3 = global[arm.upper].origin
				var target := shoulder + Vector3(out * 0.08, -0.6, 0.48) * arm_length
				target.y += sway * out * arm_length * (0.04 if moving else 0.012)
				var blade_basis := _along(Vector3(out * 0.32, -0.18, 1.0), Vector3.UP)
				_hold(skeleton, local, arm, target, blade_basis, "dagger")
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
			_spear_hold(skeleton, local, rig, body, chest, name, time, phase, source.length, carry, spear, spear_tune)
		if family == &"defender" and carry:
			# The great shield is carried out in front of the left shoulder, its
			# face forward as at rest, so it never lies across the arm or the hip.
			global = _globals(skeleton, local)
			var shoulder: Vector3 = global[rig.l.upper].origin
			var target := shoulder + Vector3(0.12, -0.52, 0.64) * arm_length
			target.z += sway * arm_length * (0.03 if moving else 0.01)
			var shield_basis: Basis = idle_globals[rig.l.slot].basis * (rig.l.correction as Basis) * WeaponGrip.mount("greatshield")
			_hold(skeleton, local, rig.l, target, shield_basis, "greatshield")
		for bone in arm_bones:
			result.rotation_track_insert_key(output_tracks[bone], time, local[bone].basis.get_rotation_quaternion())
	return result
