class_name ProceduralAnimator
extends RefCounted
## Builds real [Animation] resources from code for the placeholder rigs.
##
## The produced AnimationPlayer libraries follow the project's ANIMATION
## CONTRACT (names like "idle", "walk", "attack"…). Imported models only need
## an AnimationPlayer exposing the same names to plug into the game, and an
## AnimationTree state machine can use them directly.

## Helper that records keys per property and fills rest poses.
class AnimBuilder:
	var anim: Animation
	var rest: Dictionary

	func _init(length: float, loop: bool, p_rest: Dictionary) -> void:
		anim = Animation.new()
		anim.length = length
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		rest = p_rest

	## times/values pairs; values are OFFSETS added to the rest value.
	func offset(path: String, times: Array, offsets: Array, interp := Animation.INTERPOLATION_CUBIC) -> AnimBuilder:
		if not rest.has(path):
			return self
		var base = rest[path]
		var values: Array = []
		for o in offsets:
			values.append(base + o)
		return absolute(path, times, values, interp)

	func absolute(path: String, times: Array, values: Array, interp := Animation.INTERPOLATION_CUBIC) -> AnimBuilder:
		if not rest.has(path):
			return self
		var idx := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(idx, NodePath(path))
		anim.track_set_interpolation_type(idx, interp)
		anim.value_track_set_update_mode(idx, Animation.UPDATE_CONTINUOUS)
		for i in times.size():
			anim.track_insert_key(idx, times[i], values[i])
		return self

	## Adds a constant rest key for every property not animated yet so that
	## blending between animations always returns limbs to their rest pose.
	func finish() -> Animation:
		for path in rest.keys():
			if anim.find_track(NodePath(path), Animation.TYPE_VALUE) == -1:
				var idx := anim.add_track(Animation.TYPE_VALUE)
				anim.track_set_path(idx, NodePath(path))
				anim.track_insert_key(idx, 0.0, rest[path])
		return anim


## Records the rest value of "node_path:property" for every existing node.
static func capture_rest(root: Node, specs: Array) -> Dictionary:
	var rest := {}
	for spec in specs:
		var node_path: String = spec[0]
		var prop: String = spec[1]
		var node := root.get_node_or_null(node_path)
		if node:
			rest["%s:%s" % [node_path, prop]] = node.get(prop)
	return rest


static func attach_player(root: Node, library: AnimationLibrary, rest: Dictionary) -> AnimationPlayer:
	var reset := AnimBuilder.new(0.001, false, rest).finish()
	library.add_animation(&"RESET", reset)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.add_animation_library(&"", library)
	return player


# ---------------------------------------------------------------------------
# Humanoid (player / NPC chibi avatars)
# ---------------------------------------------------------------------------

const HUMAN_PARTS := [
	["Rig", "position"], ["Rig", "rotation"],
	["Rig/Hips/Torso", "rotation"],
	["Rig/Hips/Torso/Head", "rotation"],
	["Rig/Hips/Torso/ArmL", "rotation"], ["Rig/Hips/Torso/ArmR", "rotation"],
	["Rig/Hips/LegL", "rotation"], ["Rig/Hips/LegR", "rotation"],
]


static func build_humanoid(root: Node3D) -> AnimationPlayer:
	var rest := capture_rest(root, HUMAN_PARTS)
	var lib := AnimationLibrary.new()
	var D := deg_to_rad(1.0)
	var rig_p := "Rig:position"
	var rig_r := "Rig:rotation"
	var torso := "Rig/Hips/Torso:rotation"
	var head := "Rig/Hips/Torso/Head:rotation"
	var arm_l := "Rig/Hips/Torso/ArmL:rotation"
	var arm_r := "Rig/Hips/Torso/ArmR:rotation"
	var leg_l := "Rig/Hips/LegL:rotation"
	var leg_r := "Rig/Hips/LegR:rotation"
	var Z := Vector3.ZERO

	lib.add_animation(&"idle", AnimBuilder.new(2.4, true, rest)
		.offset(rig_p, [0.0, 1.2, 2.4], [Z, Vector3(0, 0.012, 0), Z])
		.offset(torso, [0.0, 1.2, 2.4], [Z, Vector3(-2 * D, 0, 0), Z])
		.offset(head, [0.0, 0.8, 1.6, 2.4], [Z, Vector3(0, 0, 3 * D), Vector3(0, 0, -2 * D), Z])
		.offset(arm_l, [0.0, 1.2, 2.4], [Vector3(0, 0, -4 * D), Vector3(0, 0, -7 * D), Vector3(0, 0, -4 * D)])
		.offset(arm_r, [0.0, 1.2, 2.4], [Vector3(0, 0, 4 * D), Vector3(0, 0, 7 * D), Vector3(0, 0, 4 * D)])
		.finish())

	var w := 0.8
	lib.add_animation(&"walk", AnimBuilder.new(w, true, rest)
		.offset(rig_p, [0.0, w * 0.25, w * 0.5, w * 0.75, w], [Z, Vector3(0, 0.03, 0), Z, Vector3(0, 0.03, 0), Z])
		.offset(torso, [0.0, w * 0.5, w], [Vector3(4 * D, 5 * D, 0), Vector3(4 * D, -5 * D, 0), Vector3(4 * D, 5 * D, 0)])
		.offset(leg_l, [0.0, w * 0.5, w], [Vector3(-30 * D, 0, 0), Vector3(30 * D, 0, 0), Vector3(-30 * D, 0, 0)])
		.offset(leg_r, [0.0, w * 0.5, w], [Vector3(30 * D, 0, 0), Vector3(-30 * D, 0, 0), Vector3(30 * D, 0, 0)])
		.offset(arm_l, [0.0, w * 0.5, w], [Vector3(28 * D, 0, -6 * D), Vector3(-28 * D, 0, -6 * D), Vector3(28 * D, 0, -6 * D)])
		.offset(arm_r, [0.0, w * 0.5, w], [Vector3(-28 * D, 0, 6 * D), Vector3(28 * D, 0, 6 * D), Vector3(-28 * D, 0, 6 * D)])
		.finish())

	var r := 0.5
	lib.add_animation(&"run", AnimBuilder.new(r, true, rest)
		.offset(rig_p, [0.0, r * 0.25, r * 0.5, r * 0.75, r], [Z, Vector3(0, 0.07, 0), Z, Vector3(0, 0.07, 0), Z])
		.offset(torso, [0.0, r * 0.5, r], [Vector3(14 * D, 7 * D, 0), Vector3(14 * D, -7 * D, 0), Vector3(14 * D, 7 * D, 0)])
		.offset(head, [0.0, r], [Vector3(-8 * D, 0, 0), Vector3(-8 * D, 0, 0)])
		.offset(leg_l, [0.0, r * 0.5, r], [Vector3(-55 * D, 0, 0), Vector3(50 * D, 0, 0), Vector3(-55 * D, 0, 0)])
		.offset(leg_r, [0.0, r * 0.5, r], [Vector3(50 * D, 0, 0), Vector3(-55 * D, 0, 0), Vector3(50 * D, 0, 0)])
		.offset(arm_l, [0.0, r * 0.5, r], [Vector3(55 * D, 0, -10 * D), Vector3(-60 * D, 0, -10 * D), Vector3(55 * D, 0, -10 * D)])
		.offset(arm_r, [0.0, r * 0.5, r], [Vector3(-60 * D, 0, 10 * D), Vector3(55 * D, 0, 10 * D), Vector3(-60 * D, 0, 10 * D)])
		.finish())

	lib.add_animation(&"interact", AnimBuilder.new(0.7, false, rest)
		.offset(arm_r, [0.0, 0.2, 0.5, 0.7], [Z, Vector3(-85 * D, 0, 8 * D), Vector3(-80 * D, 0, 8 * D), Z])
		.offset(head, [0.0, 0.25, 0.45, 0.7], [Z, Vector3(10 * D, 0, 0), Vector3(-4 * D, 0, 0), Z])
		.offset(torso, [0.0, 0.25, 0.7], [Z, Vector3(6 * D, 0, 0), Z])
		.finish())

	var b := 1.2
	lib.add_animation(&"battle_idle", AnimBuilder.new(b, true, rest)
		.offset(rig_p, [0.0, b * 0.5, b], [Vector3(0, -0.02, 0), Vector3(0, 0.01, 0), Vector3(0, -0.02, 0)])
		.offset(torso, [0.0, b * 0.5, b], [Vector3(8 * D, 0, 0), Vector3(5 * D, 0, 0), Vector3(8 * D, 0, 0)])
		.offset(leg_l, [0.0, b], [Vector3(0, 0, -9 * D), Vector3(0, 0, -9 * D)])
		.offset(leg_r, [0.0, b], [Vector3(0, 0, 9 * D), Vector3(0, 0, 9 * D)])
		.offset(arm_l, [0.0, b * 0.5, b], [Vector3(-40 * D, 0, -18 * D), Vector3(-46 * D, 0, -18 * D), Vector3(-40 * D, 0, -18 * D)])
		.offset(arm_r, [0.0, b * 0.5, b], [Vector3(-40 * D, 0, 18 * D), Vector3(-46 * D, 0, 18 * D), Vector3(-40 * D, 0, 18 * D)])
		.finish())

	lib.add_animation(&"attack", AnimBuilder.new(0.7, false, rest)
		.offset(torso, [0.0, 0.15, 0.45, 0.7], [Vector3(8 * D, 0, 0), Vector3(-6 * D, 12 * D, 0), Vector3(16 * D, -8 * D, 0), Vector3(8 * D, 0, 0)])
		.offset(arm_r, [0.0, 0.15, 0.45, 0.7], [Vector3(-40 * D, 0, 18 * D), Vector3(-150 * D, 0, 20 * D), Vector3(-95 * D, 0, 5 * D), Vector3(-40 * D, 0, 18 * D)])
		.offset(arm_l, [0.0, 0.7], [Vector3(-30 * D, 0, -25 * D), Vector3(-40 * D, 0, -18 * D)])
		.finish())

	lib.add_animation(&"hurt", AnimBuilder.new(0.5, false, rest)
		.offset(rig_p, [0.0, 0.12, 0.5], [Z, Vector3(0, 0, -0.08), Z])
		.offset(torso, [0.0, 0.12, 0.5], [Z, Vector3(-16 * D, 0, 0), Z])
		.offset(head, [0.0, 0.12, 0.5], [Z, Vector3(-14 * D, 0, 0), Z])
		.offset(arm_l, [0.0, 0.12, 0.5], [Z, Vector3(20 * D, 0, -35 * D), Z])
		.offset(arm_r, [0.0, 0.12, 0.5], [Z, Vector3(20 * D, 0, 35 * D), Z])
		.finish())

	lib.add_animation(&"victory", AnimBuilder.new(1.0, true, rest)
		.offset(rig_p, [0.0, 0.25, 0.5, 1.0], [Z, Vector3(0, 0.22, 0), Z, Z])
		.offset(arm_l, [0.0, 0.25, 0.5, 1.0], [Vector3(0, 0, -150 * D), Vector3(0, 0, -165 * D), Vector3(0, 0, -150 * D), Vector3(0, 0, -150 * D)])
		.offset(arm_r, [0.0, 0.25, 0.5, 1.0], [Vector3(0, 0, 150 * D), Vector3(0, 0, 165 * D), Vector3(0, 0, 150 * D), Vector3(0, 0, 150 * D)])
		.offset(leg_l, [0.0, 0.25, 0.5], [Z, Vector3(-20 * D, 0, 0), Z])
		.offset(leg_r, [0.0, 0.25, 0.5], [Z, Vector3(20 * D, 0, 0), Z])
		.offset(head, [0.0, 0.25, 1.0], [Vector3(-10 * D, 0, 0), Vector3(-18 * D, 0, 0), Vector3(-10 * D, 0, 0)])
		.finish())

	# "wave" is used on menus/intro; not part of the core contract.
	lib.add_animation(&"wave", AnimBuilder.new(1.2, true, rest)
		.offset(arm_r, [0.0, 0.3, 0.6, 0.9, 1.2], [Vector3(0, 0, 150 * D), Vector3(0, 0, 125 * D), Vector3(0, 0, 150 * D), Vector3(0, 0, 125 * D), Vector3(0, 0, 150 * D)])
		.offset(head, [0.0, 0.6, 1.2], [Vector3(0, 0, 5 * D), Vector3(0, 0, -5 * D), Vector3(0, 0, 5 * D)])
		.offset(rig_p, [0.0, 0.6, 1.2], [Z, Vector3(0, 0.015, 0), Z])
		.finish())

	return attach_player(root, lib, rest)


# ---------------------------------------------------------------------------
# Creatures (placeholder Digimon)
# ---------------------------------------------------------------------------

const CREATURE_PARTS := [
	["Rig", "position"], ["Rig", "rotation"],
	["Rig/Body", "rotation"], ["Rig/Body/Head", "rotation"],
	["Rig/Body/ArmL", "rotation"], ["Rig/Body/ArmR", "rotation"],
	["Rig/LegL", "rotation"], ["Rig/LegR", "rotation"],
	["Rig/LegFL", "rotation"], ["Rig/LegFR", "rotation"],
	["Rig/LegBL", "rotation"], ["Rig/LegBR", "rotation"],
	["Rig/Body/Tail", "rotation"],
	["Rig/Body/WingL", "rotation"], ["Rig/Body/WingR", "rotation"],
	["Rig/Body/Head/EarL", "rotation"], ["Rig/Body/Head/EarR", "rotation"],
]


static func build_creature(root: Node3D, flyer: bool) -> AnimationPlayer:
	var rest := capture_rest(root, CREATURE_PARTS)
	var lib := AnimationLibrary.new()
	var D := deg_to_rad(1.0)
	var Z := Vector3.ZERO
	var rig_p := "Rig:position"
	var rig_r := "Rig:rotation"
	var body := "Rig/Body:rotation"
	var head := "Rig/Body/Head:rotation"
	var arm_l := "Rig/Body/ArmL:rotation"
	var arm_r := "Rig/Body/ArmR:rotation"
	var leg_l := "Rig/LegL:rotation"
	var leg_r := "Rig/LegR:rotation"
	var fl := "Rig/LegFL:rotation"
	var fr := "Rig/LegFR:rotation"
	var bl := "Rig/LegBL:rotation"
	var br := "Rig/LegBR:rotation"
	var tail := "Rig/Body/Tail:rotation"
	var wing_l := "Rig/Body/WingL:rotation"
	var wing_r := "Rig/Body/WingR:rotation"
	var ear_l := "Rig/Body/Head/EarL:rotation"
	var ear_r := "Rig/Body/Head/EarR:rotation"
	var bob := 0.08 if flyer else 0.025
	var flap := 35.0 if flyer else 10.0

	# idle
	var i := 1.6
	lib.add_animation(&"idle", AnimBuilder.new(i, true, rest)
		.offset(rig_p, [0.0, i * 0.5, i], [Z, Vector3(0, bob, 0), Z])
		.offset(body, [0.0, i * 0.5, i], [Z, Vector3(-3 * D, 0, 0), Z])
		.offset(head, [0.0, i * 0.3, i * 0.7, i], [Z, Vector3(0, 0, 5 * D), Vector3(0, 0, -4 * D), Z])
		.offset(tail, [0.0, i * 0.5, i], [Vector3(0, -12 * D, 0), Vector3(0, 12 * D, 0), Vector3(0, -12 * D, 0)])
		.offset(wing_l, [0.0, i * 0.25, i * 0.5, i * 0.75, i], [Z, Vector3(0, 0, flap * D), Z, Vector3(0, 0, flap * D), Z])
		.offset(wing_r, [0.0, i * 0.25, i * 0.5, i * 0.75, i], [Z, Vector3(0, 0, -flap * D), Z, Vector3(0, 0, -flap * D), Z])
		.offset(ear_l, [0.0, i * 0.5, i], [Z, Vector3(0, 0, 8 * D), Z])
		.offset(ear_r, [0.0, i * 0.5, i], [Z, Vector3(0, 0, -8 * D), Z])
		.offset(arm_l, [0.0, i * 0.5, i], [Z, Vector3(-8 * D, 0, 0), Z])
		.offset(arm_r, [0.0, i * 0.5, i], [Z, Vector3(-8 * D, 0, 0), Z])
		.finish())

	# walk / run share a gait with different speeds.
	for gait in [[&"walk", 0.6, 28.0, 0.05], [&"run", 0.4, 45.0, 0.1]]:
		var t: float = gait[1]
		var swing: float = gait[2] * D
		var bounce: float = gait[3] + (0.04 if flyer else 0.0)
		var flap_fast := (50.0 if flyer else 15.0) * D
		lib.add_animation(gait[0], AnimBuilder.new(t, true, rest)
			.offset(rig_p, [0.0, t * 0.25, t * 0.5, t * 0.75, t], [Z, Vector3(0, bounce, 0), Z, Vector3(0, bounce, 0), Z])
			.offset(body, [0.0, t], [Vector3(8 * D, 0, 0), Vector3(8 * D, 0, 0)])
			.offset(leg_l, [0.0, t * 0.5, t], [Vector3(-swing, 0, 0), Vector3(swing, 0, 0), Vector3(-swing, 0, 0)])
			.offset(leg_r, [0.0, t * 0.5, t], [Vector3(swing, 0, 0), Vector3(-swing, 0, 0), Vector3(swing, 0, 0)])
			.offset(fl, [0.0, t * 0.5, t], [Vector3(-swing, 0, 0), Vector3(swing, 0, 0), Vector3(-swing, 0, 0)])
			.offset(br, [0.0, t * 0.5, t], [Vector3(-swing, 0, 0), Vector3(swing, 0, 0), Vector3(-swing, 0, 0)])
			.offset(fr, [0.0, t * 0.5, t], [Vector3(swing, 0, 0), Vector3(-swing, 0, 0), Vector3(swing, 0, 0)])
			.offset(bl, [0.0, t * 0.5, t], [Vector3(swing, 0, 0), Vector3(-swing, 0, 0), Vector3(swing, 0, 0)])
			.offset(arm_l, [0.0, t * 0.5, t], [Vector3(swing * 0.7, 0, 0), Vector3(-swing * 0.7, 0, 0), Vector3(swing * 0.7, 0, 0)])
			.offset(arm_r, [0.0, t * 0.5, t], [Vector3(-swing * 0.7, 0, 0), Vector3(swing * 0.7, 0, 0), Vector3(-swing * 0.7, 0, 0)])
			.offset(tail, [0.0, t * 0.5, t], [Vector3(0, -20 * D, 0), Vector3(0, 20 * D, 0), Vector3(0, -20 * D, 0)])
			.offset(wing_l, [0.0, t * 0.5, t], [Vector3(0, 0, -flap_fast * 0.3), Vector3(0, 0, flap_fast), Vector3(0, 0, -flap_fast * 0.3)])
			.offset(wing_r, [0.0, t * 0.5, t], [Vector3(0, 0, flap_fast * 0.3), Vector3(0, 0, -flap_fast), Vector3(0, 0, flap_fast * 0.3)])
			.offset(ear_l, [0.0, t * 0.5, t], [Vector3(0, 0, -6 * D), Vector3(0, 0, 10 * D), Vector3(0, 0, -6 * D)])
			.offset(ear_r, [0.0, t * 0.5, t], [Vector3(0, 0, 6 * D), Vector3(0, 0, -10 * D), Vector3(0, 0, 6 * D)])
			.finish())

	# attack: lunge forward (+Z is the model's front).
	lib.add_animation(&"attack", AnimBuilder.new(0.65, false, rest)
		.offset(rig_p, [0.0, 0.15, 0.3, 0.65], [Z, Vector3(0, 0.05, -0.15), Vector3(0, 0.1, 0.7), Z])
		.offset(body, [0.0, 0.15, 0.3, 0.65], [Z, Vector3(-12 * D, 0, 0), Vector3(22 * D, 0, 0), Z])
		.offset(head, [0.0, 0.3, 0.65], [Z, Vector3(10 * D, 0, 0), Z])
		.offset(arm_l, [0.0, 0.15, 0.3, 0.65], [Z, Vector3(40 * D, 0, 0), Vector3(-80 * D, 0, 0), Z])
		.offset(arm_r, [0.0, 0.15, 0.3, 0.65], [Z, Vector3(40 * D, 0, 0), Vector3(-80 * D, 0, 0), Z])
		.offset(tail, [0.0, 0.3, 0.65], [Z, Vector3(-25 * D, 0, 0), Z])
		.offset(wing_l, [0.0, 0.15, 0.3, 0.65], [Z, Vector3(0, 0, 40 * D), Vector3(0, 0, -30 * D), Z])
		.offset(wing_r, [0.0, 0.15, 0.3, 0.65], [Z, Vector3(0, 0, -40 * D), Vector3(0, 0, 30 * D), Z])
		.finish())

	# skill: rear up, charge, release.
	lib.add_animation(&"skill", AnimBuilder.new(0.8, false, rest)
		.offset(rig_p, [0.0, 0.35, 0.5, 0.8], [Z, Vector3(0, 0.18, -0.1), Vector3(0, 0.05, 0.15), Z])
		.offset(body, [0.0, 0.35, 0.5, 0.8], [Z, Vector3(-18 * D, 0, 0), Vector3(15 * D, 0, 0), Z])
		.offset(head, [0.0, 0.35, 0.5, 0.8], [Z, Vector3(-15 * D, 0, 0), Vector3(12 * D, 0, 0), Z])
		.offset(arm_l, [0.0, 0.35, 0.5, 0.8], [Z, Vector3(-40 * D, 0, -30 * D), Vector3(-70 * D, 0, 0), Z])
		.offset(arm_r, [0.0, 0.35, 0.5, 0.8], [Z, Vector3(-40 * D, 0, 30 * D), Vector3(-70 * D, 0, 0), Z])
		.offset(wing_l, [0.0, 0.35, 0.8], [Z, Vector3(0, 0, 55 * D), Z])
		.offset(wing_r, [0.0, 0.35, 0.8], [Z, Vector3(0, 0, -55 * D), Z])
		.offset(tail, [0.0, 0.35, 0.8], [Z, Vector3(20 * D, 0, 0), Z])
		.finish())

	lib.add_animation(&"hurt", AnimBuilder.new(0.45, false, rest)
		.offset(rig_p, [0.0, 0.1, 0.45], [Z, Vector3(0, 0.05, -0.3), Z])
		.offset(body, [0.0, 0.1, 0.45], [Z, Vector3(-20 * D, 0, 8 * D), Z])
		.offset(head, [0.0, 0.1, 0.45], [Z, Vector3(-15 * D, 0, 0), Z])
		.finish())

	lib.add_animation(&"defeat", AnimBuilder.new(0.9, false, rest)
		.offset(rig_p, [0.0, 0.3, 0.9], [Z, Vector3(0, 0.1, -0.2), Vector3(0, -0.15 - (0.3 if flyer else 0.0), -0.3)])
		.offset(rig_r, [0.0, 0.3, 0.9], [Z, Vector3(-10 * D, 0, 20 * D), Vector3(0, 0, 80 * D)])
		.offset(wing_l, [0.0, 0.9], [Z, Vector3(0, 0, -20 * D)])
		.offset(wing_r, [0.0, 0.9], [Z, Vector3(0, 0, 20 * D)])
		.finish())

	var v := 0.9
	lib.add_animation(&"victory", AnimBuilder.new(v, true, rest)
		.offset(rig_p, [0.0, v * 0.25, v * 0.5, v], [Z, Vector3(0, 0.3, 0), Z, Z])
		.offset(rig_r, [0.0, v * 0.5, v], [Z, Vector3(0, TAU, 0), Vector3(0, TAU, 0)], Animation.INTERPOLATION_LINEAR)
		.offset(arm_l, [0.0, v * 0.25, v * 0.5], [Z, Vector3(-120 * D, 0, 0), Z])
		.offset(arm_r, [0.0, v * 0.25, v * 0.5], [Z, Vector3(-120 * D, 0, 0), Z])
		.offset(wing_l, [0.0, v * 0.25, v * 0.5], [Z, Vector3(0, 0, 50 * D), Z])
		.offset(wing_r, [0.0, v * 0.25, v * 0.5], [Z, Vector3(0, 0, -50 * D), Z])
		.offset(tail, [0.0, v * 0.5, v], [Vector3(0, -25 * D, 0), Vector3(0, 25 * D, 0), Vector3(0, -25 * D, 0)])
		.finish())

	return attach_player(root, lib, rest)
