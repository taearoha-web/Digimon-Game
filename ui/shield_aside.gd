class_name ShieldAside
extends SkeletonModifier3D
## Character select only: a Defender faces the viewer like everyone else, but carries
## its great shield out at its left side instead of square in front of its body (the
## battle idle), so the face and the armour show. Runs after the animation each frame:
## the left arm hangs a little out from the body, and the shield turns its face out to
## the hero's left, carried along the side. A cheer (or any other clip) plays untouched.
## (Godot 4.3 restores the animated pose after drawing, so read the modified pose in
## Skeleton3D.skeleton_updated.)

## Where the arm points in the skeleton's space (+Z front, +X the hero's left, +Y up).
const ASIDE := Vector3(0.42, -0.88, 0.2)
## The shield's face turns this far from forward toward the hero's left (degrees).
const SHIELD_YAW := 52.0

var visual: HeroVisual
var _upper := -1
var _hand := -1


func setup(p_visual: HeroVisual, skeleton: Skeleton3D) -> void:
	visual = p_visual
	var chibi := skeleton.find_bone("LeftHand") >= 0
	_upper = skeleton.find_bone("LeftUpperArm" if chibi else "upperarm.l")
	_hand = skeleton.find_bone("LeftHand" if chibi else "wrist.l")


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _upper < 0 or _hand < 0:
		return
	if is_instance_valid(visual) and visual.current != "" and visual.current != "Idle" and visual.current != "2H_Melee_Idle":
		return
	var upper_global := skeleton.get_bone_global_pose(_upper)
	var hand_global := skeleton.get_bone_global_pose(_hand)
	var reach := hand_global.origin - upper_global.origin
	if reach.length() < 0.0001:
		return
	var turn := Quaternion(reach.normalized(), ASIDE.normalized())
	# The upper arm swings about the shoulder; everything below it follows.
	var parent := skeleton.get_bone_parent(_upper)
	var parent_global := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var swung := Basis(turn) * upper_global.basis
	skeleton.set_bone_pose_rotation(_upper, (parent_global.basis.inverse() * swung).get_rotation_quaternion())
	# The hand turns the shield from facing forward to facing out along the side.
	var hand_parent := skeleton.get_bone_parent(_hand)
	var hand_parent_global := skeleton.get_bone_global_pose(hand_parent)
	var carried := Basis(Vector3.UP, deg_to_rad(SHIELD_YAW)) * hand_global.basis
	skeleton.set_bone_pose_rotation(_hand, (hand_parent_global.basis.inverse() * carried).get_rotation_quaternion())
