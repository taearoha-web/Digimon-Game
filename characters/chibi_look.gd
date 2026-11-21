class_name ChibiLook
extends RefCounted
## Looks of the chibi heroes: three ready-made characters (styles) per body. A style's
## skin tone, hair colour and eye colour recolour the body's own texture
## (shaders/chibi_outfit.gdshader with the baked hair/eye mask, tools/chibi_look_mask.py)
## and its accessory sits on the head bone. Players pick only the style (and the body);
## the parts cannot be set alone any more: a hero's look is {gender, style}
## (FaceKit.hero_look), and what it shows comes from the style's row (paint). The old
## top-level skin_tone / hair_tint / eye_tint / acc keys an old save or an old client
## may still carry are never read. A set NPC (the fairy) may carry its own paint under
## PAINT_KEY.
##
## paint keys: skin_tone, hair_tint, eye_tint, acc. 0 is the body's original texture
## (no accessory); colour n is entry n-1 of its palette.

## The look key a set NPC's own paint is under (never a player's).
const PAINT_KEY := "npc_paint"
const MASKS := ["res://assets/models/heroes/chibi_boy_look_mask.png", "res://assets/models/heroes/chibi_girl_look_mask.png"]

const SKIN_TONES: Array[Color] = [Color("fff0e8"), Color("ffe0cc"), Color("f6c8a4"), Color("dca274"), Color("b37a50"), Color("7f5236")]
const HAIR_TINTS: Array[Color] = [Color("2a2326"), Color("6b4128"), Color("e6c46a"), Color("e3e6ee"), Color("c8402e"), Color("f48cbf"), Color("5f9cf0"), Color("a083e6"), Color("62c99c")]
const EYE_TINTS: Array[Color] = [Color("6a4026"), Color("3f8ae8"), Color("3fb46a"), Color("e8a83a"), Color("9a5ae0"), Color("e0423a")]
## Accessories (0 is none).
const ACC_COUNT := 5

## [name, skin_tone, hair_tint, eye_tint, acc] per body (0 boy, 1 girl), values as
## stored in the look (0 = original). Style 0 is the original body.
const STYLES := [
	[["ฮีโร่ดั้งเดิม", 0, 0, 0, 0], ["นักล่าเงินจันทร์", 4, 4, 6, 0], ["อัศวินทองฟ้า", 2, 3, 2, 0]],
	[["นักผจญภัยดั้งเดิม", 0, 0, 0, 0], ["เจ้าหญิงซากุระ", 2, 6, 5, 1], ["ภูตป่าดำขลับ", 5, 1, 3, 2]],
]
const KEYS := ["skin_tone", "hair_tint", "eye_tint", "acc"]


## Number of values of a key, the original (0) included.
static func count(key: String) -> int:
	match key:
		"skin_tone": return SKIN_TONES.size() + 1
		"hair_tint": return HAIR_TINTS.size() + 1
		"eye_tint": return EYE_TINTS.size() + 1
		"acc": return ACC_COUNT
		"style": return 3
	return 0


static func style_name(gender: int, style: int) -> String:
	return String(STYLES[clampi(gender, 0, 1)][clampi(style, 0, 2)][0])


## Picks ready-made style [param style] for [param look] (its colours come with it).
static func apply_style(look: Dictionary, style: int) -> void:
	look["style"] = clampi(style, 0, count("style") - 1)


## What a look shows: a set NPC's own paint, else the row of its body's style.
static func paint(look: Dictionary) -> Dictionary:
	var own: Variant = look.get(PAINT_KEY)
	if own is Dictionary:
		return own
	# The other bodies (ChibiBodies) wear their own texture: the masks do not fit it.
	if ChibiBodies.index(look) != 0:
		return {"skin_tone": 0, "hair_tint": 0, "eye_tint": 0, "acc": 0}
	var row: Array = STYLES[clampi(int(look.get("gender", 0)), 0, 1)][clampi(int(look.get("style", 0)), 0, 2)]
	var out := {}
	for i in KEYS.size():
		out[KEYS[i]] = int(row[i + 1])
	return out


## The palette colour of a tint value, or null for the original (0).
static func tint(key: String, value: int) -> Variant:
	if value <= 0:
		return null
	match key:
		"skin_tone": return SKIN_TONES[mini(value, SKIN_TONES.size()) - 1]
		"hair_tint": return HAIR_TINTS[mini(value, HAIR_TINTS.size()) - 1]
		"eye_tint": return EYE_TINTS[mini(value, EYE_TINTS.size()) - 1]
	return null


## The look uniforms of the chibi body material.
static func set_material(mat: ShaderMaterial, look: Dictionary, gender: int) -> void:
	var p := paint(look)
	var on := false
	for pair in [["skin_tone", "skin"], ["hair_tint", "hair"], ["eye_tint", "eye"]]:
		var color: Variant = tint(pair[0], int(p.get(pair[0], 0)))
		if color is Color:
			mat.set_shader_parameter(pair[1] + "_color", color)
			mat.set_shader_parameter(pair[1] + "_amount", 1.0)
			on = true
	if on:
		mat.set_shader_parameter("look_mask", load(MASKS[clampi(gender, 0, 1)]))
		mat.set_shader_parameter("look_enabled", true)


## The accessory on the head frame (head-bone space: +y up, +z the face; the head
## and hair span about x -0.21..0.18, y 0..0.335, z -0.22..0.15 on both bodies, the
## eyes sit at y 0.08 (boy) / 0.10 (girl), the ear lobes at x +-0.15, y 0.055).
static func build_accessory(root: Node3D, acc: int, gender: int) -> void:
	var g := clampi(gender, 0, 1)
	var eye_y := 0.082 if g == 0 else 0.1
	match acc:
		1:
			# A bow tied at the back of the head, below the crown, lying on the hair.
			var pink := Color("ff6fae")
			var knot := Vector3(0.0, 0.2, -0.215)
			_p(root, MeshKit.sphere_low(), pink.darkened(0.12), knot, Vector3(0.04, 0.04, 0.035))
			for side in [-1.0, 1.0]:
				_p(root, MeshKit.sphere_low(), pink, knot + Vector3(side * 0.065, 0.012, 0.012), Vector3(0.09, 0.055, 0.03), Vector3(-15, side * 20.0, side * -14.0))
				_p(root, MeshKit.box(), pink.darkened(0.06), knot + Vector3(side * 0.03, -0.07, -0.006), Vector3(0.028, 0.1, 0.008), Vector3(-10, 0, side * 16.0))
		2:
			# A white blossom clipped above the left ear, half sunk into the hair.
			var at := Vector3(0.162, 0.175, -0.035)
			for i in 5:
				var a := i * TAU / 5.0
				_p(root, MeshKit.sphere_low(), Color("fff1f6"), at + Vector3(0.0, sin(a) * 0.033, cos(a) * 0.033), Vector3(0.02, 0.046, 0.046))
			_p(root, MeshKit.sphere_low(), Color("ffd24a"), at + Vector3(0.012, 0, 0), Vector3.ONE * 0.028, Vector3.ZERO, 0.35)
			_p(root, MeshKit.sphere_low(), Color("ff9ccb"), at + Vector3(-0.005, -0.045, -0.055), Vector3(0.016, 0.03, 0.03))
		3:
			var frame := Color("2b2d38")
			var z := 0.148
			for side in [-1.0, 1.0]:
				_p(root, MeshKit.torus(), frame, Vector3(side * 0.047, eye_y, z), Vector3(0.08, 0.1, 0.068), Vector3(90, 0, 0))
				_p(root, MeshKit.box(), frame, Vector3(side * 0.09, eye_y + 0.008, z - 0.06), Vector3(0.007, 0.007, 0.12))
			_p(root, MeshKit.box(), frame, Vector3(0, eye_y + 0.004, z), Vector3(0.022, 0.007, 0.007))
		4:
			for side in [-1.0, 1.0]:
				var lobe := Vector3(side * 0.146, 0.052, -0.03)
				_p(root, MeshKit.sphere_low(), Color("ffd257"), lobe, Vector3.ONE * 0.014, Vector3.ZERO, 0.5)
				_p(root, MeshKit.sphere_low(), Color("ffd257"), lobe + Vector3(0, -0.026, 0), Vector3(0.012, 0.022, 0.012), Vector3.ZERO, 0.5)


static func _p(root: Node3D, mesh: Mesh, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO, glow := 0.0) -> void:
	GearKit._p(root, mesh, color, pos, size, rot, glow)
