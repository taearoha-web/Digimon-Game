class_name ChibiAvatar
extends Node3D
## ORIGINAL stylised chibi human built from primitives.
##
## One builder for every body type: male/female (and future types) only
## change proportion parameters from the CustomizationCatalog. Call
## [method apply_appearance] to rebuild; animations follow the humanoid
## contract (idle, walk, run, interact, battle_idle, attack, hurt, victory).
##
## To replace with a real model later, swap this node for a scene exposing
## the same `play_animation(name)` API (see docs/ASSET_REPLACEMENT.md).

signal rebuilt()

const HEAD_Y := 0.44

var appearance: CharacterAppearance = CharacterAppearance.new()
var current_animation: StringName = &""

var _rig: Node3D
var _anim: AnimationPlayer
var _body_params: Dictionary = {}


func _ready() -> void:
	if _rig == null:
		apply_appearance(appearance)


func apply_appearance(new_appearance: CharacterAppearance) -> void:
	appearance = new_appearance if new_appearance else CharacterAppearance.new()
	var previous_anim := current_animation
	_clear()
	_body_params = _get_body_params()
	_build()
	_anim = ProceduralAnimator.build_humanoid(self)
	current_animation = &""
	play_animation(previous_anim if previous_anim != &"" else &"idle", 0.0)
	rebuilt.emit()


func play_animation(anim_name: StringName, blend := 0.2) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if current_animation == anim_name and _anim.is_playing():
		return
	current_animation = anim_name
	_anim.play(anim_name, blend)


## Plays a one-shot animation then returns to [param then_anim].
func play_once(anim_name: StringName, then_anim: StringName = &"idle") -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	current_animation = anim_name
	_anim.play(anim_name, 0.1)
	await _anim.animation_finished
	if current_animation == anim_name:
		play_animation(then_anim)


func get_animation_player() -> AnimationPlayer:
	return _anim


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rig = null
	_anim = null


func _get_body_params() -> Dictionary:
	var defaults := {"shoulder": 1.0, "hip": 0.92, "torso": 1.0, "head": 1.0, "height": 1.0, "eyelashes": false}
	var catalog: CustomizationCatalog = _catalog()
	if catalog:
		var option := catalog.find_option(&"body_type", appearance.body_type)
		for key in option.keys():
			defaults[key] = option[key]
	return defaults


func _catalog() -> CustomizationCatalog:
	var loop := Engine.get_main_loop()
	var reg: Node = (loop as SceneTree).root.get_node_or_null("GameData") if loop is SceneTree else null
	return reg.customization_catalog if reg else null


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build() -> void:
	var a := appearance
	var shoulder: float = _body_params.shoulder
	var hip: float = _body_params.hip
	var torso_h: float = _body_params.torso
	var head_s: float = _body_params.head
	var height: float = _body_params.height

	var skin := MeshKit.toon(a.skin_tone)
	var top_mat := MeshKit.toon(a.top_color)
	var bottom_mat := MeshKit.toon(a.bottom_color)
	var shoe_mat := MeshKit.toon(a.shoes_color)
	var sphere := MeshKit.sphere()
	var capsule := MeshKit.capsule()
	var cyl := MeshKit.cylinder()

	MeshKit.blob_shadow(self, 0.42)
	_rig = MeshKit.pivot(self, "Rig")
	_rig.scale = Vector3.ONE * height
	var hips := MeshKit.pivot(_rig, "Hips", Vector3(0, 0.5, 0))

	# Pelvis
	MeshKit.part(hips, sphere, bottom_mat, Vector3(0, 0.02, 0), Vector3(0.32 * hip, 0.2, 0.24), Vector3.ZERO, "Pelvis")

	# Legs
	for side in [-1, 1]:
		var leg := MeshKit.pivot(hips, "LegL" if side < 0 else "LegR", Vector3(0.085 * side * hip, -0.02, 0))
		var thigh_mat := bottom_mat
		var shin_mat := skin if a.bottom == &"shorts" else bottom_mat
		MeshKit.part(leg, cyl, thigh_mat, Vector3(0, -0.1, 0), Vector3(0.12, 0.2, 0.12), Vector3.ZERO, "Thigh")
		MeshKit.part(leg, cyl, shin_mat, Vector3(0, -0.28, 0), Vector3(0.1, 0.2, 0.1), Vector3.ZERO, "Shin")
		if a.bottom == &"adventure_pants":
			MeshKit.part(leg, sphere, MeshKit.toon(a.bottom_color.darkened(0.3)), Vector3(0, -0.22, 0.05), Vector3(0.09, 0.08, 0.05))
			MeshKit.part(leg, MeshKit.box(), MeshKit.toon(a.bottom_color.darkened(0.2)), Vector3(0.065 * side, -0.1, 0), Vector3(0.03, 0.09, 0.08))
		_build_shoe(leg, a, shoe_mat, side)

	# Torso
	var torso := MeshKit.pivot(hips, "Torso", Vector3(0, 0.06, 0))
	MeshKit.part(torso, sphere, top_mat, Vector3(0, 0.17, 0), Vector3(0.34 * shoulder, 0.4 * torso_h, 0.25), Vector3.ZERO, "Chest")
	_build_top_details(torso, a, shoulder, torso_h)
	if a.has_accessory(&"backpack"):
		_build_backpack(torso, a)

	# Arms
	for side in [-1, 1]:
		var arm := MeshKit.pivot(torso, "ArmL" if side < 0 else "ArmR", Vector3(0.19 * side * shoulder, 0.3 * torso_h, 0))
		arm.rotation_degrees = Vector3(0, 0, 4 * side)
		var sleeve_long := a.top != &"t_shirt"
		var upper_mat := top_mat
		var lower_mat := top_mat if (sleeve_long and a.top != &"adventure_shirt") else skin
		MeshKit.part(arm, capsule, upper_mat, Vector3(0, -0.08, 0), Vector3(0.1, 0.07, 0.1), Vector3.ZERO, "UpperArm")
		MeshKit.part(arm, capsule, lower_mat, Vector3(0, -0.2, 0), Vector3(0.085, 0.065, 0.085), Vector3.ZERO, "LowerArm")
		if a.top == &"adventure_shirt":
			MeshKit.part(arm, cyl, MeshKit.toon(a.top_color.darkened(0.15)), Vector3(0, -0.14, 0), Vector3(0.105, 0.035, 0.105))
		MeshKit.part(arm, sphere, skin, Vector3(0, -0.3, 0), Vector3(0.1, 0.1, 0.1), Vector3.ZERO, "Hand")

	# Head
	var head := MeshKit.pivot(torso, "Head", Vector3(0, HEAD_Y * torso_h, 0))
	var head_root := MeshKit.pivot(head, "HeadRoot")
	head_root.scale = Vector3.ONE * head_s
	MeshKit.part(head_root, cyl, skin, Vector3(0, 0.01, 0), Vector3(0.1, 0.08, 0.1), Vector3.ZERO, "Neck")
	MeshKit.part(head_root, sphere, skin, Vector3(0, 0.2, 0), Vector3(0.5, 0.46, 0.46), Vector3.ZERO, "Skull")
	MeshKit.part(head_root, sphere, skin, Vector3(-0.245, 0.18, 0), Vector3(0.06, 0.09, 0.06))
	MeshKit.part(head_root, sphere, skin, Vector3(0.245, 0.18, 0), Vector3(0.06, 0.09, 0.06))
	_build_face(head_root, a)
	_build_hair(head_root, a)
	if a.has_accessory(&"glasses"):
		_build_glasses(head_root, a)
	if a.has_accessory(&"hat"):
		_build_hat(head_root, a)


func _build_shoe(leg: Node3D, a: CharacterAppearance, shoe_mat: Material, _side: int) -> void:
	var sphere := MeshKit.sphere()
	if a.shoes == &"boots":
		MeshKit.part(leg, MeshKit.cylinder(), shoe_mat, Vector3(0, -0.33, 0), Vector3(0.125, 0.14, 0.125), Vector3.ZERO, "BootShaft")
		MeshKit.part(leg, sphere, shoe_mat, Vector3(0, -0.42, 0.035), Vector3(0.15, 0.1, 0.22), Vector3.ZERO, "Shoe")
		MeshKit.part(leg, MeshKit.box(), MeshKit.toon(Color("3a2a22")), Vector3(0, -0.465, 0.035), Vector3(0.15, 0.03, 0.22))
		MeshKit.part(leg, MeshKit.torus(), MeshKit.toon(a.shoes_color.darkened(0.3)), Vector3(0, -0.27, 0), Vector3(0.13, 0.08, 0.13))
	else:
		MeshKit.part(leg, sphere, shoe_mat, Vector3(0, -0.41, 0.03), Vector3(0.14, 0.11, 0.22), Vector3.ZERO, "Shoe")
		MeshKit.part(leg, MeshKit.box(), MeshKit.toon(Color("f4f4f4")), Vector3(0, -0.46, 0.03), Vector3(0.145, 0.035, 0.22))
		MeshKit.part(leg, sphere, MeshKit.toon(a.shoes_color.lightened(0.35)), Vector3(0, -0.395, 0.1), Vector3(0.08, 0.04, 0.06))


func _build_top_details(torso: Node3D, a: CharacterAppearance, shoulder: float, torso_h: float) -> void:
	var sphere := MeshKit.sphere()
	var box := MeshKit.box()
	match a.top:
		&"t_shirt":
			MeshKit.part(torso, MeshKit.torus(), MeshKit.toon(a.top_color.darkened(0.2)), Vector3(0, 0.34 * torso_h, 0), Vector3(0.16, 0.08, 0.14))
			MeshKit.part(torso, MeshKit.box(), MeshKit.toon(a.top_color.darkened(0.12)), Vector3(0, 0.02, 0.0), Vector3(0.3, 0.035, 0.235))
		&"jacket":
			var inner := MeshKit.toon(Color("f4f4f4") if a.top_color.get_luminance() < 0.7 else Color("3a3f4b"))
			MeshKit.part(torso, box, inner, Vector3(0, 0.17, 0.112), Vector3(0.09, 0.3 * torso_h, 0.03))
			MeshKit.part(torso, box, MeshKit.toon(a.top_color.darkened(0.25)), Vector3(-0.055, 0.17, 0.118), Vector3(0.018, 0.3 * torso_h, 0.02))
			MeshKit.part(torso, box, MeshKit.toon(a.top_color.darkened(0.25)), Vector3(0.055, 0.17, 0.118), Vector3(0.018, 0.3 * torso_h, 0.02))
			MeshKit.part(torso, MeshKit.torus(), MeshKit.toon(a.top_color.darkened(0.15)), Vector3(0, 0.34 * torso_h, 0), Vector3(0.2, 0.12, 0.17), Vector3(-10, 0, 0))
		&"hoodie":
			MeshKit.part(torso, sphere, MeshKit.toon(a.top_color.darkened(0.12)), Vector3(0, 0.34 * torso_h, -0.1), Vector3(0.26 * shoulder, 0.16, 0.14), Vector3.ZERO, "Hood")
			MeshKit.part(torso, box, MeshKit.toon(a.top_color.darkened(0.18)), Vector3(0, 0.07, 0.118), Vector3(0.18, 0.08, 0.03))
			for side in [-1, 1]:
				MeshKit.part(torso, MeshKit.cylinder(), MeshKit.toon(Color("f4f4f4")), Vector3(0.035 * side, 0.26, 0.12), Vector3(0.012, 0.1, 0.012))
		&"adventure_shirt":
			var strap := MeshKit.toon(Color("7a4e2e"))
			MeshKit.part(torso, box, strap, Vector3(0, 0.19, 0.0), Vector3(0.05, 0.46 * torso_h, 0.27), Vector3(0, 0, 38))
			MeshKit.part(torso, MeshKit.cylinder(), strap, Vector3(0, -0.02, 0), Vector3(0.3 * shoulder, 0.05, 0.24))
			MeshKit.part(torso, box, MeshKit.toon(Color("d9b25a")), Vector3(0, -0.02, 0.12), Vector3(0.05, 0.045, 0.02))
			MeshKit.part(torso, MeshKit.torus(), MeshKit.toon(a.top_color.darkened(0.2)), Vector3(0, 0.34 * torso_h, 0.01), Vector3(0.17, 0.1, 0.15), Vector3(-12, 0, 0))


func _build_backpack(torso: Node3D, a: CharacterAppearance) -> void:
	var mat := MeshKit.toon(a.accessory_color)
	var dark := MeshKit.toon(a.accessory_color.darkened(0.3))
	MeshKit.part(torso, MeshKit.sphere(), mat, Vector3(0, 0.18, -0.16), Vector3(0.26, 0.3, 0.16), Vector3.ZERO, "Backpack")
	MeshKit.part(torso, MeshKit.sphere(), dark, Vector3(0, 0.25, -0.2), Vector3(0.22, 0.12, 0.1))
	MeshKit.part(torso, MeshKit.sphere(), dark, Vector3(0, 0.09, -0.225), Vector3(0.14, 0.1, 0.06))
	for side in [-1, 1]:
		MeshKit.part(torso, MeshKit.box(), dark, Vector3(0.09 * side, 0.2, 0.0), Vector3(0.035, 0.34, 0.26), Vector3(0, 0, 0))


func _build_face(head: Node3D, a: CharacterAppearance) -> void:
	var catalog := _catalog()
	var face_def := catalog.find_option(&"face", a.face) if catalog else {}
	var eyes: StringName = face_def.get("eyes", &"round")
	var mouth: StringName = face_def.get("mouth", &"smile")
	var brows: StringName = face_def.get("brows", &"soft")
	var sphere := MeshKit.sphere()
	var dark := MeshKit.toon(a.eye_color.darkened(0.55), {"rim": false})
	var iris := MeshKit.toon(a.eye_color, {"rim": false})
	var shine := MeshKit.toon(Color.WHITE, {"unshaded": true})
	var face := MeshKit.pivot(head, "Face", Vector3(0, 0.17, 0.2))

	var eye_h := 0.105
	var eye_w := 0.075
	var tilt := 0.0
	match eyes:
		&"sharp":
			eye_h = 0.075
			tilt = 12.0
		&"sleepy":
			eye_h = 0.05
		&"sparkle":
			eye_h = 0.12
			eye_w = 0.085
	for side in [-1, 1]:
		var x: float = 0.092 * side
		MeshKit.part(face, sphere, dark, Vector3(x, 0.0, 0.0), Vector3(eye_w, eye_h, 0.04), Vector3(0, 0, -tilt * side), "Eye")
		MeshKit.part(face, sphere, iris, Vector3(x, -eye_h * 0.18, 0.012), Vector3(eye_w * 0.72, eye_h * 0.62, 0.03))
		MeshKit.part(face, sphere, shine, Vector3(x - 0.015 * side, eye_h * 0.2, 0.026), Vector3(0.028, 0.03, 0.012))
		if eyes == &"sparkle":
			MeshKit.part(face, sphere, shine, Vector3(x + 0.018 * side, -eye_h * 0.25, 0.026), Vector3(0.015, 0.016, 0.01))
		if eyes == &"sleepy":
			MeshKit.part(face, MeshKit.box(), MeshKit.toon(a.skin_tone.darkened(0.12)), Vector3(x, eye_h * 0.45, 0.012), Vector3(0.085, 0.03, 0.03))
		if _body_params.get("eyelashes", false):
			MeshKit.part(face, MeshKit.box(), MeshKit.toon(Color("241a1a")), Vector3(x + 0.035 * side, eye_h * 0.42, 0.012), Vector3(0.035, 0.012, 0.012), Vector3(0, 0, 30 * side))
		# Brows
		var brow_rot := 0.0
		var brow_y := eye_h * 0.5 + 0.045
		match brows:
			&"angled":
				brow_rot = -14.0 * side
			&"raised":
				brow_y += 0.02
				brow_rot = 8.0 * side
		MeshKit.part(face, MeshKit.box(), MeshKit.toon(a.hair_color.darkened(0.2)), Vector3(x, brow_y, 0.004), Vector3(0.06, 0.014, 0.012), Vector3(0, 0, brow_rot))
		# Blush
		MeshKit.part(face, sphere, MeshKit.toon(a.skin_tone.lerp(Color("ff7a8a"), 0.35), {"rim": false}), Vector3(0.13 * side, -0.065, -0.012), Vector3(0.05, 0.022, 0.02))

	var mouth_mat := MeshKit.toon(Color("7a2b2b"), {"rim": false})
	match mouth:
		&"open":
			MeshKit.part(face, sphere, mouth_mat, Vector3(0, -0.085, 0.0), Vector3(0.05, 0.045, 0.02))
			MeshKit.part(face, sphere, MeshKit.toon(Color("ff8a8a")), Vector3(0, -0.097, 0.006), Vector3(0.03, 0.018, 0.01))
		&"smirk":
			MeshKit.part(face, MeshKit.box(), mouth_mat, Vector3(0.01, -0.08, 0.0), Vector3(0.045, 0.012, 0.012), Vector3(0, 0, 10))
		&"small":
			MeshKit.part(face, sphere, mouth_mat, Vector3(0, -0.08, 0.0), Vector3(0.022, 0.014, 0.012))
		_:
			MeshKit.part(face, MeshKit.torus(), mouth_mat, Vector3(0, -0.07, -0.002), Vector3(0.06, 0.03, 0.035), Vector3(90, 0, 0))
			# Hide the upper half of the torus ring with a skin patch to read as a smile.
			MeshKit.part(face, sphere, MeshKit.toon(a.skin_tone), Vector3(0, -0.058, 0.002), Vector3(0.065, 0.028, 0.02))


func _build_hair(head: Node3D, a: CharacterAppearance) -> void:
	var mat := MeshKit.toon(a.hair_color)
	var light := MeshKit.toon(a.hair_color.lightened(0.12))
	var sphere := MeshKit.sphere()
	var cone := MeshKit.cone()
	var hair := MeshKit.pivot(head, "Hair")
	# Base cap shared by every style (covers top and back of the skull).
	MeshKit.part(hair, sphere, mat, Vector3(0, 0.265, -0.035), Vector3(0.535, 0.47, 0.5), Vector3.ZERO, "Cap")
	var fringe := func(count: int, spread: float, y: float, size: float) -> void:
		for i in count:
			var t := (float(i) / maxf(1.0, count - 1.0)) - 0.5
			MeshKit.part(hair, sphere, light if i % 2 == 0 else mat, Vector3(t * spread, y - 0.03 - absf(t) * 0.06, 0.175 - absf(t) * 0.07),
				Vector3(size * 1.15, size * 1.35, size * 0.55), Vector3(28, 0, -t * 35))
	match a.hair_style:
		&"spiky":
			fringe.call(4, 0.3, 0.38, 0.13)
			var spikes := [[0.0, 0.5, -0.02, -10.0, 0.0], [-0.14, 0.46, -0.05, -15.0, 30.0], [0.14, 0.46, -0.05, -15.0, -30.0],
				[-0.08, 0.44, -0.2, -60.0, 20.0], [0.08, 0.44, -0.2, -60.0, -20.0], [0.0, 0.36, -0.28, -95.0, 0.0],
				[-0.22, 0.34, -0.1, -20.0, 65.0], [0.22, 0.34, -0.1, -20.0, -65.0]]
			for s in spikes:
				MeshKit.part(hair, cone, mat, Vector3(s[0], s[1], s[2]), Vector3(0.14, 0.22, 0.14), Vector3(s[3], 0, s[4]))
		&"short":
			fringe.call(5, 0.34, 0.37, 0.1)
			MeshKit.part(hair, sphere, mat, Vector3(0, 0.2, -0.12), Vector3(0.5, 0.36, 0.34))
		&"messy":
			fringe.call(5, 0.36, 0.38, 0.12)
			for i in 9:
				var ang := i * TAU / 9.0
				MeshKit.part(hair, sphere, light if i % 2 else mat, Vector3(cos(ang) * 0.2, 0.42 + sin(ang * 2.0) * 0.03, sin(ang) * 0.17 - 0.05),
					Vector3(0.14, 0.12, 0.14))
		&"bob":
			fringe.call(5, 0.38, 0.36, 0.12)
			for side in [-1, 1]:
				MeshKit.part(hair, sphere, mat, Vector3(0.21 * side, 0.12, -0.02), Vector3(0.16, 0.34, 0.3))
			MeshKit.part(hair, sphere, mat, Vector3(0, 0.12, -0.14), Vector3(0.46, 0.36, 0.28))
		&"long":
			fringe.call(5, 0.38, 0.36, 0.12)
			for side in [-1, 1]:
				MeshKit.part(hair, sphere, mat, Vector3(0.22 * side, 0.02, -0.03), Vector3(0.13, 0.5, 0.22))
			MeshKit.part(hair, MeshKit.capsule(), mat, Vector3(0, -0.05, -0.17), Vector3(0.44, 0.22, 0.2), Vector3.ZERO, "BackHair")
		&"ponytail":
			fringe.call(4, 0.34, 0.37, 0.12)
			MeshKit.part(hair, sphere, MeshKit.toon(a.accessory_color), Vector3(0, 0.36, -0.26), Vector3(0.09, 0.09, 0.09))
			MeshKit.part(hair, MeshKit.capsule(), mat, Vector3(0, 0.18, -0.34), Vector3(0.15, 0.16, 0.15), Vector3(-25, 0, 0), "Ponytail")
		&"twin_tails":
			fringe.call(5, 0.38, 0.36, 0.12)
			for side in [-1, 1]:
				MeshKit.part(hair, sphere, MeshKit.toon(a.accessory_color), Vector3(0.22 * side, 0.36, -0.1), Vector3(0.08, 0.08, 0.08))
				MeshKit.part(hair, MeshKit.capsule(), mat, Vector3(0.3 * side, 0.12, -0.12), Vector3(0.14, 0.16, 0.14), Vector3(0, 0, 18 * side))
		_:
			fringe.call(4, 0.34, 0.37, 0.12)


func _build_glasses(head: Node3D, a: CharacterAppearance) -> void:
	var frame := MeshKit.toon(a.accessory_color.darkened(0.3))
	var lens := MeshKit.toon(Color(0.75, 0.9, 1.0, 0.35), {"alpha": 0.35})
	for side in [-1, 1]:
		MeshKit.part(head, MeshKit.torus(), frame, Vector3(0.092 * side, 0.17, 0.235), Vector3(0.13, 0.08, 0.13), Vector3(90, 0, 0))
		MeshKit.part(head, MeshKit.sphere(), lens, Vector3(0.092 * side, 0.17, 0.232), Vector3(0.1, 0.1, 0.01))
	MeshKit.part(head, MeshKit.box(), frame, Vector3(0, 0.18, 0.238), Vector3(0.05, 0.012, 0.012))


func _build_hat(head: Node3D, a: CharacterAppearance) -> void:
	var mat := MeshKit.toon(a.accessory_color)
	var hat := MeshKit.pivot(head, "Hat", Vector3(0, 0.33, -0.01), Vector3(-8, 0, 0))
	MeshKit.part(hat, MeshKit.hemisphere(), mat, Vector3(0, 0.02, 0), Vector3(0.56, 0.5, 0.54))
	MeshKit.part(hat, MeshKit.cylinder(), MeshKit.toon(a.accessory_color.darkened(0.2)), Vector3(0, 0.02, 0.22), Vector3(0.34, 0.025, 0.26))
	MeshKit.part(hat, MeshKit.sphere(), MeshKit.toon(Color.WHITE), Vector3(0, 0.27, 0), Vector3(0.06, 0.06, 0.06))
