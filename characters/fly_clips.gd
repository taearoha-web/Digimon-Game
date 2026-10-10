class_name FlyClips
extends RefCounted
## Flying body clips for the chibi rig, built from its Idle clip:
##   Fly_Hover   legs bent and dangling, arms held a little out, gentle sway
##   Fly_Forward legs trailing back, arms swept back, chest lifted
## Each limb gets a turn in model space (x = the hero's left, z = forward) on top
## of the Idle pose, keyed over one Idle loop so the breathing still plays.

## bone -> [base turn (degrees, model-space x/y/z), sway (degrees), sway phase (turns)]
const HOVER := {
	"LeftUpperLeg": [Vector3(-18, 0, 4), Vector3(7, 0, 0), 0.0],
	"RightUpperLeg": [Vector3(-8, 0, -4), Vector3(7, 0, 0), 0.5],
	"LeftLowerLeg": [Vector3(42, 0, 0), Vector3(6, 0, 0), 0.1],
	"RightLowerLeg": [Vector3(30, 0, 0), Vector3(6, 0, 0), 0.6],
	"LeftFoot": [Vector3(35, 0, 0), Vector3.ZERO, 0.0],
	"RightFoot": [Vector3(35, 0, 0), Vector3.ZERO, 0.0],
	"LeftUpperArm": [Vector3(8, 0, 26), Vector3(0, 0, 5), 0.25],
	"RightUpperArm": [Vector3(8, 0, -26), Vector3(0, 0, -5), 0.25],
}
const FORWARD := {
	"Chest": [Vector3(-12, 0, 0), Vector3.ZERO, 0.0],
	"LeftUpperLeg": [Vector3(22, 0, 3), Vector3(5, 0, 0), 0.0],
	"RightUpperLeg": [Vector3(30, 0, -3), Vector3(5, 0, 0), 0.5],
	"LeftLowerLeg": [Vector3(38, 0, 0), Vector3(5, 0, 0), 0.15],
	"RightLowerLeg": [Vector3(30, 0, 0), Vector3(5, 0, 0), 0.65],
	"LeftFoot": [Vector3(40, 0, 0), Vector3.ZERO, 0.0],
	"RightFoot": [Vector3(40, 0, 0), Vector3.ZERO, 0.0],
	"LeftUpperArm": [Vector3(38, 0, 16), Vector3(4, 0, 0), 0.0],
	"RightUpperArm": [Vector3(38, 0, -16), Vector3(4, 0, 0), 0.5],
}
const KEYS := 8


## Adds Fly_Hover and Fly_Forward to [param player] (once per loaded model).
static func add_to(player: AnimationPlayer, skeleton: Skeleton3D) -> void:
	if player == null or skeleton == null or not player.has_animation("Idle") or player.has_animation("Fly_Hover"):
		return
	var library := player.get_animation_library("")
	if library == null:
		return
	var idle := player.get_animation("Idle")
	library.add_animation("Fly_Hover", _build(idle, skeleton, HOVER))
	library.add_animation("Fly_Forward", _build(idle, skeleton, FORWARD))


static func _build(idle: Animation, skeleton: Skeleton3D, turns: Dictionary) -> Animation:
	var clip := idle.duplicate(true) as Animation
	clip.loop_mode = Animation.LOOP_LINEAR
	var length := idle.length
	# Rotation track of every bone in the Idle clip.
	var idle_track := {}
	var prefix := ""
	for t in idle.get_track_count():
		if idle.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var path := idle.track_get_path(t)
		idle_track[skeleton.find_bone(String(path.get_concatenated_subnames()))] = t
		prefix = String(path).split(":")[0]
	var out_track := {}
	for bone_name in turns:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var t: int = clip.find_track(NodePath("%s:%s" % [prefix, bone_name]), Animation.TYPE_ROTATION_3D)
		if t < 0:
			t = clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(t, NodePath("%s:%s" % [prefix, bone_name]))
		while clip.track_get_key_count(t) > 0:
			clip.track_remove_key(t, 0)
		out_track[bone] = t
	for k in KEYS + 1:
		var time := length * float(k) / float(KEYS)
		var globals := {}
		for bone in skeleton.get_bone_count():
			var parent := skeleton.get_bone_parent(bone)
			var local := Basis(_idle_rotation(idle, idle_track, skeleton, bone, time))
			var parent_basis: Basis = globals.get(parent, Basis.IDENTITY)
			var global := parent_basis * local
			var name := skeleton.get_bone_name(bone)
			if turns.has(name):
				var spec: Array = turns[name]
				var sway := sin(TAU * (float(k) / float(KEYS) + float(spec[2])))
				var deg: Vector3 = (spec[0] as Vector3) + (spec[1] as Vector3) * sway
				var turn := Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)))
				global = turn * global
				local = parent_basis.inverse() * global
				clip.rotation_track_insert_key(out_track[bone], time, local.get_rotation_quaternion())
			globals[bone] = global
	return clip


static func _idle_rotation(idle: Animation, tracks: Dictionary, skeleton: Skeleton3D, bone: int, time: float) -> Quaternion:
	if tracks.has(bone):
		return idle.rotation_track_interpolate(tracks[bone], time)
	return skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
