class_name SaddlePose
extends SkeletonModifier3D
## Fighting from the saddle (Hero.ride): the rider's clips play on the upper body only.
## Runs after the animation each frame while HeroVisual.seated: the hips, the legs (and
## the skirt) take the floor-sit clip's pose, so the ready stance (Hero.RIDE_UPPER), a
## swing, a cast or a recoil turns the spine, arms, head and weapon while the rider
## stays sat on the mount instead of standing up through it.
## (Godot 4.3 restores the animated pose after drawing, like ShieldAside.)

const CLIP := "Sit_Floor_Idle"

var visual: HeroVisual
## Bones held in the seated pose, and that pose (bone-local position / rotation / scale).
var bones := PackedInt32Array()
var _position: Array[Vector3] = []
var _rotation: Array[Quaternion] = []
var _scale: Array[Vector3] = []
var _hips := -1
## Indexes into [member bones] from the top of the skeleton down to the hips.
var _chain: Array[int] = []


func setup(p_visual: HeroVisual, skeleton: Skeleton3D, player: AnimationPlayer) -> void:
	visual = p_visual
	bones = PackedInt32Array()
	_position.clear()
	_rotation.clear()
	_scale.clear()
	_chain.clear()
	var hips := skeleton.find_bone("Hips")
	if hips < 0:
		hips = skeleton.find_bone("hips")
	if hips < 0 or player == null or not player.has_animation(CLIP):
		return
	_hips = hips
	# The hips, whatever carries them (a root bone), and everything hanging off the
	# hips except the spine: the upper body stays free for the action.
	var parent := skeleton.get_bone_parent(hips)
	while parent >= 0:
		bones.append(parent)
		parent = skeleton.get_bone_parent(parent)
	var open: Array[int] = [hips]
	while not open.is_empty():
		var bone: int = open.pop_back()
		bones.append(bone)
		for child in skeleton.get_bone_children(bone):
			if bone == hips and skeleton.get_bone_name(child).to_lower().begins_with("spine"):
				continue
			open.append(child)
	for i in bones.size():
		if bones[i] == hips:
			break
		_chain.push_front(i)
	_chain.append(bones.find(hips))
	var at := {}
	for i in bones.size():
		var rest := skeleton.get_bone_rest(bones[i])
		_position.append(rest.origin)
		_rotation.append(rest.basis.get_rotation_quaternion())
		_scale.append(rest.basis.get_scale())
		at[skeleton.get_bone_name(bones[i])] = i
	var clip := player.get_animation(CLIP)
	for track in clip.get_track_count():
		var bone_name := String(clip.track_get_path(track).get_concatenated_subnames())
		if not at.has(bone_name):
			continue
		var i: int = at[bone_name]
		match clip.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				_position[i] = clip.position_track_interpolate(track, 0.0)
			Animation.TYPE_ROTATION_3D:
				_rotation[i] = clip.rotation_track_interpolate(track, 0.0)
			Animation.TYPE_SCALE_3D:
				_scale[i] = clip.scale_track_interpolate(track, 0.0)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not is_instance_valid(visual) or not visual.seated:
		return
	for i in bones.size():
		skeleton.set_bone_pose_position(bones[i], _position[i])
		skeleton.set_bone_pose_rotation(bones[i], _rotation[i])
		skeleton.set_bone_pose_scale(bones[i], _scale[i])


## Turns a skeleton-space point of the animated (standing) pose into where it is
## drawn on the seat: the hips sit lower than the swing's clip puts them. Identity
## when not seated. (Outside skeleton_updated the bones read back unmodified.)
func seat_offset(skeleton: Skeleton3D) -> Transform3D:
	if _hips < 0 or not is_instance_valid(visual) or not visual.seated:
		return Transform3D.IDENTITY
	var seated := Transform3D.IDENTITY
	for i in _chain:
		seated = seated * Transform3D(Basis(_rotation[i]) * Basis.from_scale(_scale[i]), _position[i])
	return seated * skeleton.get_bone_global_pose(_hips).affine_inverse()
