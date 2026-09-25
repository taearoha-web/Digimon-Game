class_name PlaceholderDigimonFactory
extends RefCounted
## Builds ORIGINAL placeholder creatures from primitive shapes.
##
## These are development stand-ins only — deliberately simple, distinct
## silhouettes (ears, tails, horns, wings, proportions) that do not reproduce
## any commercial model. Each body plan exposes the same rig node names so
## ProceduralAnimator can animate every plan:
##   Rig, Rig/Body, Rig/Body/Head, Rig/Body/ArmL|ArmR, Rig/LegL|LegR,
##   Rig/LegFL|FR|BL|BR (quadrupeds), Rig/Body/Tail, Rig/Body/WingL|WingR,
##   Rig/Body/Head/EarL|EarR
##
## Replace with real art by setting DigimonSpecies.model_path.

const DEFAULT_COLORS := [Color(0.9, 0.9, 0.95), Color(0.6, 0.7, 0.9), Color(1, 1, 1), Color(0.1, 0.1, 0.1)]

var _c: Array = []
var _opts: Dictionary = {}


## Returns a Node3D whose metadata "height" is the approximate model height.
static func build(species: DigimonSpecies) -> Node3D:
	var factory := PlaceholderDigimonFactory.new()
	return factory._build(species)


func _build(species: DigimonSpecies) -> Node3D:
	_c = []
	for i in 4:
		_c.append(species.get_color(i, DEFAULT_COLORS[i]) if species else DEFAULT_COLORS[i])
	_opts = species.placeholder_options if species else {}
	var root := Node3D.new()
	root.name = "PlaceholderModel"
	var rig := MeshKit.pivot(root, "Rig")
	var body_plan: StringName = species.placeholder_body if species else &"blob"
	var height := 1.0
	match body_plan:
		&"dino": height = _dino(rig, 1.0, false)
		&"big_dino": height = _dino(rig, 1.75, true)
		&"beast": height = _beast(rig)
		&"winged": height = _winged(rig)
		&"wolf": height = _wolf(rig)
		&"angel": height = _angel(rig)
		&"larva": height = _larva(rig)
		&"goblin": height = _goblin(rig)
		&"plant": height = _plant(rig)
		&"critter": height = _critter(rig)
		&"bird": height = _bird(rig)
		_: height = _blob(rig)
	var hover := 0.0
	if species and species.hovers:
		hover = 0.35 if height < 1.4 else 0.5
		rig.position.y = hover
	root.set_meta("height", (height + hover) * (species.model_scale if species else 1.0))
	root.set_meta("hover", hover)
	MeshKit.blob_shadow(root, clampf(height * 0.42, 0.3, 1.3))
	return root


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _p(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scale: Vector3, rot := Vector3.ZERO, part_name := "") -> MeshInstance3D:
	return MeshKit.part(parent, mesh, MeshKit.toon(color), pos, scale, rot, part_name)


func _glow(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scale: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return MeshKit.part(parent, mesh, MeshKit.toon(color, {"emission": 1.2}), pos, scale, rot)


func _eyes(head: Node3D, y: float, z: float, spacing: float, size: float, color: Color, squash := 1.0) -> void:
	var sphere := MeshKit.sphere()
	for side in [-1, 1]:
		var x: float = spacing * side
		_p(head, sphere, Color(0.98, 0.98, 1.0), Vector3(x, y, z), Vector3(size, size * 1.15 * squash, size * 0.55))
		_p(head, sphere, color, Vector3(x, y - size * 0.05, z + size * 0.14), Vector3(size * 0.7, size * 0.85 * squash, size * 0.4))
		_p(head, sphere, Color(0.05, 0.05, 0.08), Vector3(x, y - size * 0.05, z + size * 0.22), Vector3(size * 0.38, size * 0.5 * squash, size * 0.3))
		MeshKit.part(head, sphere, MeshKit.toon(Color.WHITE, {"unshaded": true}), Vector3(x - size * 0.15 * side, y + size * 0.22, z + size * 0.3), Vector3(size * 0.22, size * 0.24, size * 0.12))


func _claws(parent: Node3D, pos: Vector3, count: int, size: float, color: Color, forward := Vector3(90, 0, 0)) -> void:
	for i in count:
		var t := (float(i) / maxf(1.0, count - 1.0)) - 0.5
		_p(parent, MeshKit.cone(), color, pos + Vector3(t * size * 2.2, 0, 0), Vector3(size, size * 1.6, size), forward)


func _opt(key: String, default_value: Variant) -> Variant:
	return _opts.get(key, _opts.get(StringName(key), default_value))


# ---------------------------------------------------------------------------
# Body plans
# ---------------------------------------------------------------------------

## Upright little dinosaur. [param big] adds a bony helmet, horns and stripes.
func _dino(rig: Node3D, s: float, big: bool) -> float:
	var main: Color = _c[0]
	var belly: Color = _c[1] if not big else main.lightened(0.35)
	var accent: Color = _c[2]
	var stripe: Color = _c[1]
	var sphere := MeshKit.sphere()
	for side in [-1, 1]:
		var leg := MeshKit.pivot(rig, "LegL" if side < 0 else "LegR", Vector3(0.17 * side, 0.34, 0) * s)
		_p(leg, sphere, main, Vector3(0, -0.08, 0) * s, Vector3(0.24, 0.3, 0.26) * s)
		_p(leg, sphere, main.darkened(0.08), Vector3(0, -0.28, 0.06) * s, Vector3(0.22, 0.12, 0.3) * s)
		_claws(leg, Vector3(0, -0.29, 0.2) * s, 3, 0.045 * s, accent)
		if big:
			_p(leg, MeshKit.box(), stripe, Vector3(0.12 * side, -0.05, 0) * s, Vector3(0.03, 0.18, 0.12) * s)
	var body := MeshKit.pivot(rig, "Body", Vector3(0, 0.34, 0) * s)
	_p(body, sphere, main, Vector3(0, 0.22, 0) * s, Vector3(0.54, 0.6, 0.48) * s, Vector3.ZERO, "Torso")
	_p(body, sphere, belly, Vector3(0, 0.18, 0.16) * s, Vector3(0.36, 0.44, 0.2) * s)
	if big:
		for i in 3:
			_p(body, MeshKit.box(), stripe, Vector3(0, 0.34 - i * 0.12, -0.2) * s, Vector3(0.42, 0.04, 0.12) * s, Vector3(-10, 0, 0))
	var head := MeshKit.pivot(body, "Head", Vector3(0, 0.52, 0.04) * s)
	_p(head, sphere, main, Vector3(0, 0.14, 0) * s, Vector3(0.48, 0.42, 0.46) * s, Vector3.ZERO, "Skull")
	_p(head, sphere, main.lightened(0.05), Vector3(0, 0.07, 0.2) * s, Vector3(0.38, 0.24, 0.38) * s, Vector3.ZERO, "Snout")
	_p(head, MeshKit.box(), main.darkened(0.45), Vector3(0, 0.03, 0.3) * s, Vector3(0.26, 0.015, 0.12) * s)
	for side in [-1, 1]:
		_p(head, sphere, main.darkened(0.4), Vector3(0.06 * side, 0.14, 0.38) * s, Vector3(0.03, 0.02, 0.02) * s)
		# Tiny teeth.
		_p(head, MeshKit.cone(), Color(0.98, 0.98, 0.95), Vector3(0.1 * side, 0.02, 0.3) * s, Vector3(0.03, 0.04, 0.03) * s, Vector3(180, 0, 0))
	_eyes(head, 0.21 * s, 0.17 * s, 0.12 * s, 0.1 * s, _c[3])
	if big:
		var helmet := MeshKit.pivot(head, "Helmet", Vector3(0, 0.26, 0.02) * s)
		_p(helmet, MeshKit.hemisphere(), accent, Vector3.ZERO, Vector3(0.52, 0.5, 0.52) * s, Vector3(-10, 0, 0))
		_p(helmet, MeshKit.cone(), Color(0.97, 0.95, 0.9), Vector3(0, 0.1, 0.18) * s, Vector3(0.08, 0.26, 0.08) * s, Vector3(60, 0, 0))
		for side in [-1, 1]:
			_p(helmet, MeshKit.cone(), Color(0.97, 0.95, 0.9), Vector3(0.2 * side, 0.02, 0.05) * s, Vector3(0.07, 0.22, 0.07) * s, Vector3(30, 0, -60 * side))
	for side in [-1, 1]:
		var arm := MeshKit.pivot(body, "ArmL" if side < 0 else "ArmR", Vector3(0.25 * side, 0.36, 0.06) * s)
		_p(arm, MeshKit.capsule(), main, Vector3(0.02 * side, -0.08, 0.04) * s, Vector3(0.1, 0.08, 0.1) * s, Vector3(-30, 0, 0))
		_claws(arm, Vector3(0.02 * side, -0.16, 0.12) * s, 3, 0.03 * s, accent, Vector3(120, 0, 0))
		if big:
			_p(arm, MeshKit.box(), stripe, Vector3(0.02 * side, -0.07, 0.04) * s, Vector3(0.11, 0.03, 0.11) * s, Vector3(-30, 0, 0))
	var tail := MeshKit.pivot(body, "Tail", Vector3(0, 0.12, -0.2) * s)
	_p(tail, sphere, main, Vector3(0, -0.02, -0.12) * s, Vector3(0.28, 0.26, 0.36) * s)
	_p(tail, sphere, main, Vector3(0, -0.08, -0.32) * s, Vector3(0.18, 0.17, 0.3) * s)
	_p(tail, MeshKit.cone(), main, Vector3(0, -0.12, -0.5) * s, Vector3(0.12, 0.2, 0.12) * s, Vector3(-100, 0, 0))
	if big:
		_p(tail, MeshKit.box(), stripe, Vector3(0, 0.08, -0.16) * s, Vector3(0.2, 0.03, 0.08) * s)
		_p(tail, MeshKit.box(), stripe, Vector3(0, 0.0, -0.34) * s, Vector3(0.14, 0.03, 0.07) * s)
	return 1.1 * s


## Bipedal horned beast. Options: pelt (hooded striped pelt), horn, mane.
func _beast(rig: Node3D) -> float:
	var body_c: Color = _c[0]
	var pelt: Color = _c[1]
	var stripe: Color = _c[2]
	var has_pelt: bool = _opt("pelt", true)
	var has_horn: bool = _opt("horn", true)
	var has_mane: bool = _opt("mane", false)
	var sphere := MeshKit.sphere()
	var fur: Color = pelt if has_pelt else body_c
	for side in [-1, 1]:
		var leg := MeshKit.pivot(rig, "LegL" if side < 0 else "LegR", Vector3(0.14 * side, 0.3, 0))
		_p(leg, sphere, fur, Vector3(0, -0.1, 0), Vector3(0.2, 0.3, 0.22))
		_p(leg, sphere, body_c, Vector3(0, -0.26, 0.05), Vector3(0.18, 0.1, 0.24))
		_claws(leg, Vector3(0, -0.27, 0.17), 3, 0.035, Color(0.95, 0.95, 0.95))
	var body := MeshKit.pivot(rig, "Body", Vector3(0, 0.3, 0))
	_p(body, sphere, body_c, Vector3(0, 0.22, 0), Vector3(0.46, 0.52, 0.42), Vector3.ZERO, "Torso")
	if has_pelt:
		_p(body, sphere, pelt, Vector3(0, 0.26, -0.06), Vector3(0.54, 0.6, 0.44))
		_p(body, sphere, body_c.lightened(0.2), Vector3(0, 0.2, 0.17), Vector3(0.3, 0.36, 0.14))
		for i in 3:
			_p(body, MeshKit.box(), stripe, Vector3(0, 0.42 - i * 0.12, -0.24), Vector3(0.38, 0.035, 0.1), Vector3(-15, 0, 0))
	var head := MeshKit.pivot(body, "Head", Vector3(0, 0.5, 0.02))
	_p(head, sphere, body_c, Vector3(0, 0.14, 0.02), Vector3(0.42, 0.38, 0.4), Vector3.ZERO, "Skull")
	_p(head, sphere, body_c.lightened(0.1), Vector3(0, 0.07, 0.18), Vector3(0.24, 0.16, 0.2), Vector3.ZERO, "Snout")
	_p(head, sphere, Color(0.12, 0.1, 0.12), Vector3(0, 0.1, 0.28), Vector3(0.06, 0.045, 0.04))
	_eyes(head, 0.19, 0.16, 0.1, 0.085, _c[3], 0.9)
	if has_pelt:
		_p(head, MeshKit.hemisphere(), pelt, Vector3(0, 0.2, -0.02), Vector3(0.52, 0.52, 0.52), Vector3(-25, 0, 0), "Hood")
		_p(head, MeshKit.box(), stripe, Vector3(0, 0.36, -0.04), Vector3(0.06, 0.04, 0.3), Vector3(-25, 0, 0))
	if has_horn:
		_p(head, MeshKit.cone(), Color(1.0, 0.95, 0.75), Vector3(0, 0.36, 0.14), Vector3(0.08, 0.2, 0.08), Vector3(25, 0, 0))
	if has_mane:
		for i in 10:
			var ang := i * TAU / 10.0
			_p(head, sphere, pelt, Vector3(cos(ang) * 0.26, 0.14 + sin(ang) * 0.26, -0.08), Vector3(0.18, 0.18, 0.14))
	for side in [-1, 1]:
		var ear := MeshKit.pivot(head, "EarL" if side < 0 else "EarR", Vector3(0.16 * side, 0.36, -0.04))
		_p(ear, MeshKit.cone(), fur, Vector3(0, 0.07, 0), Vector3(0.1, 0.18, 0.06), Vector3(0, 0, -20 * side))
	for side in [-1, 1]:
		var arm := MeshKit.pivot(body, "ArmL" if side < 0 else "ArmR", Vector3(0.24 * side, 0.34, 0.02))
		_p(arm, MeshKit.capsule(), fur, Vector3(0.02 * side, -0.1, 0), Vector3(0.11, 0.09, 0.11))
		_p(arm, sphere, body_c, Vector3(0.02 * side, -0.21, 0.02), Vector3(0.1, 0.09, 0.1))
	var tail := MeshKit.pivot(body, "Tail", Vector3(0, 0.08, -0.22))
	_p(tail, MeshKit.capsule(), fur, Vector3(0, 0.0, -0.12), Vector3(0.1, 0.09, 0.1), Vector3(-70, 0, 0))
	_p(tail, sphere, stripe if has_pelt else pelt, Vector3(0, -0.04, -0.24), Vector3(0.14, 0.14, 0.16))
	return 1.05


## Round flier with big ear-wings.
func _winged(rig: Node3D) -> float:
	var main: Color = _c[0]
	var cream: Color = _c[1]
	var inner: Color = _c[2]
	var sphere := MeshKit.sphere()
	for side in [-1, 1]:
		var leg := MeshKit.pivot(rig, "LegL" if side < 0 else "LegR", Vector3(0.12 * side, 0.1, 0.02))
		_p(leg, sphere, main, Vector3(0, -0.04, 0.02), Vector3(0.12, 0.1, 0.14))
	var body := MeshKit.pivot(rig, "Body", Vector3(0, 0.12, 0))
	_p(body, sphere, main, Vector3(0, 0.08, 0), Vector3(0.44, 0.34, 0.4), Vector3.ZERO, "Torso")
	_p(body, sphere, cream, Vector3(0, 0.06, 0.12), Vector3(0.32, 0.24, 0.2))
	var head := MeshKit.pivot(body, "Head", Vector3(0, 0.26, 0.02))
	_p(head, sphere, main, Vector3(0, 0.12, 0), Vector3(0.58, 0.48, 0.52), Vector3.ZERO, "Skull")
	_p(head, sphere, cream, Vector3(0, 0.04, 0.2), Vector3(0.3, 0.2, 0.16), Vector3.ZERO, "Muzzle")
	_p(head, sphere, Color(0.35, 0.2, 0.18), Vector3(0, 0.08, 0.28), Vector3(0.05, 0.035, 0.03))
	_eyes(head, 0.17, 0.2, 0.13, 0.1, _c[3])
	for side in [-1, 1]:
		var wing := MeshKit.pivot(body, "WingL" if side < 0 else "WingR", Vector3(0.24 * side, 0.46, -0.02))
		_p(wing, sphere, main, Vector3(0.24 * side, 0.05, 0), Vector3(0.5, 0.08, 0.3), Vector3(0, 0, 18 * side))
		_p(wing, sphere, inner, Vector3(0.24 * side, 0.02, 0.0), Vector3(0.4, 0.06, 0.22), Vector3(0, 0, 18 * side))
		_p(wing, sphere, main.darkened(0.1), Vector3(0.44 * side, 0.12, 0), Vector3(0.12, 0.07, 0.2), Vector3(0, 0, 18 * side))
		var arm := MeshKit.pivot(body, "ArmL" if side < 0 else "ArmR", Vector3(0.18 * side, 0.08, 0.12))
		_p(arm, sphere, main, Vector3(0, -0.02, 0.02), Vector3(0.1, 0.08, 0.1))
	var tail := MeshKit.pivot(body, "Tail", Vector3(0, 0.02, -0.2))
	_p(tail, MeshKit.capsule(), main, Vector3(0, 0, -0.08), Vector3(0.06, 0.06, 0.06), Vector3(-70, 0, 0))
	_p(tail, sphere, cream, Vector3(0, -0.02, -0.16), Vector3(0.08, 0.08, 0.08))
	return 0.85


## Quadruped wolf with stripes and a bushy tail.
func _wolf(rig: Node3D) -> float:
	var main: Color = _c[0]
	var stripe: Color = _c[1]
	var sphere := MeshKit.sphere()
	var legs := {"LegFL": Vector3(-0.22, 0.55, 0.42), "LegFR": Vector3(0.22, 0.55, 0.42),
		"LegBL": Vector3(-0.24, 0.55, -0.42), "LegBR": Vector3(0.24, 0.55, -0.42)}
	for leg_name in legs.keys():
		var leg := MeshKit.pivot(rig, leg_name, legs[leg_name])
		_p(leg, MeshKit.capsule(), main, Vector3(0, -0.24, 0), Vector3(0.18, 0.16, 0.2))
		_p(leg, sphere, main.lightened(0.1), Vector3(0, -0.5, 0.05), Vector3(0.2, 0.1, 0.26))
		_p(leg, MeshKit.box(), stripe, Vector3(0, -0.2, 0), Vector3(0.19, 0.04, 0.21))
		_claws(leg, Vector3(0, -0.5, 0.18), 3, 0.035, Color(0.95, 0.95, 1.0))
	var body := MeshKit.pivot(rig, "Body", Vector3(0, 0.8, 0))
	_p(body, sphere, main, Vector3(0, 0, 0), Vector3(0.62, 0.56, 1.25), Vector3.ZERO, "Torso")
	_p(body, sphere, Color(0.97, 0.98, 1.0), Vector3(0, 0.05, 0.42), Vector3(0.5, 0.5, 0.4))
	for i in 4:
		_p(body, MeshKit.box(), stripe, Vector3(0, 0.2, 0.3 - i * 0.2), Vector3(0.64, 0.05, 0.08), Vector3(0, 0, 0))
	var head := MeshKit.pivot(body, "Head", Vector3(0, 0.3, 0.62))
	_p(head, sphere, main, Vector3(0, 0.08, 0.05), Vector3(0.44, 0.4, 0.44), Vector3.ZERO, "Skull")
	_p(head, sphere, main.lightened(0.05), Vector3(0, -0.02, 0.28), Vector3(0.24, 0.2, 0.36), Vector3.ZERO, "Snout")
	_p(head, sphere, Color(0.1, 0.1, 0.14), Vector3(0, 0.03, 0.46), Vector3(0.08, 0.06, 0.05))
	_p(head, MeshKit.cone(), Color(0.9, 0.95, 1.0), Vector3(0, 0.3, 0.14), Vector3(0.08, 0.2, 0.08), Vector3(35, 0, 0))
	_eyes(head, 0.14, 0.2, 0.12, 0.08, _c[3], 0.75)
	for side in [-1, 1]:
		var ear := MeshKit.pivot(head, "EarL" if side < 0 else "EarR", Vector3(0.15 * side, 0.28, -0.02))
		_p(ear, MeshKit.cone(), main, Vector3(0, 0.1, 0), Vector3(0.12, 0.24, 0.08), Vector3(-10, 0, -12 * side))
		_p(ear, MeshKit.box(), stripe, Vector3(0, 0.05, 0.02), Vector3(0.1, 0.03, 0.06), Vector3(-10, 0, -12 * side))
	var tail := MeshKit.pivot(body, "Tail", Vector3(0, 0.12, -0.6))
	_p(tail, MeshKit.capsule(), main, Vector3(0, 0.1, -0.2), Vector3(0.2, 0.22, 0.2), Vector3(-50, 0, 0))
	_p(tail, sphere, Color(0.97, 0.98, 1.0), Vector3(0, 0.26, -0.4), Vector3(0.22, 0.22, 0.26))
	return 1.35


## Tall winged guardian with a helmet visor and a staff.
func _angel(rig: Node3D) -> float:
	var white: Color = _c[0]
	var blue: Color = _c[1]
	var gold: Color = _c[2]
	var skin := Color(0.98, 0.86, 0.74)
	var sphere := MeshKit.sphere()
	for side in [-1, 1]:
		var leg := MeshKit.pivot(rig, "LegL" if side < 0 else "LegR", Vector3(0.12 * side, 0.82, 0))
		_p(leg, MeshKit.capsule(), white, Vector3(0, -0.2, 0), Vector3(0.16, 0.2, 0.16))
		_p(leg, MeshKit.capsule(), blue, Vector3(0, -0.56, 0), Vector3(0.15, 0.2, 0.15))
		_p(leg, sphere, blue.darkened(0.2), Vector3(0, -0.78, 0.05), Vector3(0.14, 0.1, 0.24))
	var body := MeshKit.pivot(rig, "Body", Vector3(0, 0.82, 0))
	_p(body, MeshKit.capsule(), white, Vector3(0, 0.3, 0), Vector3(0.44, 0.24, 0.3), Vector3.ZERO, "Torso")
	_p(body, MeshKit.cylinder(), gold, Vector3(0, 0.08, 0), Vector3(0.42, 0.06, 0.3))
	_p(body, MeshKit.box(), blue, Vector3(0, 0.34, 0.14), Vector3(0.16, 0.3, 0.04))
	var head := MeshKit.pivot(body, "Head", Vector3(0, 0.66, 0))
	_p(head, sphere, skin, Vector3(0, 0.14, 0.02), Vector3(0.3, 0.34, 0.3), Vector3.ZERO, "Skull")
	_p(head, sphere, gold, Vector3(0, 0.18, -0.06), Vector3(0.34, 0.36, 0.32))
	_p(head, MeshKit.capsule(), gold, Vector3(0, -0.05, -0.12), Vector3(0.22, 0.14, 0.14), Vector3(10, 0, 0))
	_p(head, sphere, blue, Vector3(0, 0.2, 0.08), Vector3(0.32, 0.18, 0.26), Vector3.ZERO, "Visor")
	_p(head, MeshKit.box(), Color(0.95, 0.95, 1.0), Vector3(0, 0.2, 0.21), Vector3(0.2, 0.03, 0.02))
	_p(head, MeshKit.box(), Color(0.8, 0.4, 0.4), Vector3(0, 0.04, 0.16), Vector3(0.06, 0.012, 0.01))
	for side in [-1, 1]:
		var arm := MeshKit.pivot(body, "ArmL" if side < 0 else "ArmR", Vector3(0.28 * side, 0.46, 0))
		_p(arm, sphere, white, Vector3(0, 0, 0), Vector3(0.18, 0.16, 0.18))
		_p(arm, MeshKit.capsule(), skin, Vector3(0.02 * side, -0.24, 0), Vector3(0.1, 0.16, 0.1))
		_p(arm, MeshKit.capsule(), blue, Vector3(0.02 * side, -0.46, 0.02), Vector3(0.11, 0.1, 0.11))
		if side > 0:
			_p(arm, MeshKit.cylinder(), gold, Vector3(0.03, -0.5, 0.12), Vector3(0.04, 1.3, 0.04), Vector3(80, 0, 0), "Staff")
			_glow(arm, sphere, gold.lightened(0.3), Vector3(0.03, -0.39, 0.76), Vector3(0.1, 0.1, 0.1))
	for side in [-1, 1]:
		var wing := MeshKit.pivot(body, "WingL" if side < 0 else "WingR", Vector3(0.1 * side, 0.46, -0.16))
		for i in 3:
			var y := 0.18 - i * 0.2
			_p(wing, sphere, Color(1, 1, 1), Vector3((0.38 - i * 0.04) * side, y, -0.08), Vector3(0.62 - i * 0.1, 0.12, 0.2), Vector3(0, -15 * side, (22 - i * 18) * side))
	var tail := MeshKit.pivot(body, "Tail", Vector3(0, 0.0, -0.14))
	_p(tail, MeshKit.box(), blue.darkened(0.1), Vector3(0, -0.18, -0.02), Vector3(0.3, 0.36, 0.04), Vector3(8, 0, 0))
	return 1.95


## Segmented larva. Option "wings" adds translucent wings (flying form).
func _larva(rig: Node3D) -> float:
	var main: Color = _c[0]
	var stripe: Color = _c[1]
	var eye: Color = _c[2]
	var winged: bool = _opt("wings", false)
	var sphere := MeshKit.sphere()
	for side in [-1, 1]:
		var leg := MeshKit.pivot(rig, "LegL" if side < 0 else "LegR", Vector3(0.12 * side, 0.1, 0.12))
		_p(leg, sphere, stripe, Vector3(0, -0.04, 0), Vector3(0.08, 0.1, 0.08))
	var body := MeshKit.pivot(rig, "Body", Vector3(0, 0.2, 0.1))
	_p(body, sphere, main, Vector3(0, 0.02, 0), Vector3(0.36, 0.34, 0.36), Vector3.ZERO, "Torso")
	_p(body, MeshKit.torus(), stripe, Vector3(0, 0.02, 0), Vector3(0.36, 0.2, 0.36))
	var head := MeshKit.pivot(body, "Head", Vector3(0, 0.18, 0.14))
	_p(head, sphere, main, Vector3(0, 0.08, 0.02), Vector3(0.38, 0.34, 0.36), Vector3.ZERO, "Skull")
	for side in [-1, 1]:
		_p(head, sphere, eye, Vector3(0.1 * side, 0.12, 0.15), Vector3(0.14, 0.16, 0.1))
		MeshKit.part(head, sphere, MeshKit.toon(Color.WHITE, {"unshaded": true}), Vector3(0.08 * side, 0.16, 0.2), Vector3(0.04, 0.04, 0.02))
		var ant := MeshKit.pivot(head, "EarL" if side < 0 else "EarR", Vector3(0.08 * side, 0.22, 0.02))
		_p(ant, MeshKit.cylinder(), stripe, Vector3(0.04 * side, 0.1, 0), Vector3(0.02, 0.2, 0.02), Vector3(0, 0, -25 * side))
		_glow(ant, sphere, Color(1.0, 0.95, 0.3), Vector3(0.09 * side, 0.2, 0), Vector3(0.06, 0.06, 0.06))
		_p(head, MeshKit.cone(), stripe, Vector3(0.05 * side, -0.04, 0.17), Vector3(0.04, 0.08, 0.04), Vector3(160, 0, 20 * side))
	var tail := MeshKit.pivot(body, "Tail", Vector3(0, -0.02, -0.16))
	var colors := [stripe, main, stripe, main]
	for i in 4:
		var size := 0.32 - i * 0.05
		_p(tail, sphere, colors[i], Vector3(0, -0.02 + i * 0.015, -0.1 - i * 0.16), Vector3(size, size * 0.92, size))
	_p(tail, MeshKit.cone(), eye, Vector3(0, 0.04, -0.72), Vector3(0.06, 0.14, 0.06), Vector3(-110, 0, 0))
	if winged:
		for side in [-1, 1]:
			var wing := MeshKit.pivot(body, "WingL" if side < 0 else "WingR", Vector3(0.12 * side, 0.18, -0.05))
			MeshKit.part(wing, sphere, MeshKit.toon(Color(eye.r, eye.g, eye.b, 0.55), {"alpha": 0.55, "double_sided": true}),
				Vector3(0.34 * side, 0.08, -0.1), Vector3(0.6, 0.04, 0.3), Vector3(0, 20 * side, 15 * side))
	return 0.7


## Little goblin with a club. Bigger model_scale turns it into an ogre.
func _goblin(rig: Node3D) -> float:
	var skin: Color = _c[0]
	var cloth: Color = _c[1]
	var club: Color = _c[2]
	var sphere := MeshKit.sphere()
	for side in [-1, 1]:
		var leg := MeshKit.pivot(rig, "LegL" if side < 0 else "LegR", Vector3(0.11 * side, 0.3, 0))
		_p(leg, MeshKit.capsule(), skin, Vector3(0, -0.12, 0), Vector3(0.12, 0.12, 0.12))
		_p(leg, sphere, skin.darkened(0.15), Vector3(0, -0.27, 0.05), Vector3(0.14, 0.08, 0.22))
	var body := MeshKit.pivot(rig, "Body", Vector3(0, 0.3, 0))
	_p(body, sphere, skin, Vector3(0, 0.2, 0), Vector3(0.4, 0.44, 0.34), Vector3.ZERO, "Torso")
	_p(body, MeshKit.cylinder(), cloth, Vector3(0, 0.02, 0), Vector3(0.42, 0.14, 0.36))
	_p(body, MeshKit.prism(), cloth, Vector3(0, -0.08, 0.14), Vector3(0.18, 0.16, 0.04), Vector3(180, 0, 0))
	var head := MeshKit.pivot(body, "Head", Vector3(0, 0.44, 0.02))
	_p(head, sphere, skin, Vector3(0, 0.16, 0), Vector3(0.44, 0.4, 0.4), Vector3.ZERO, "Skull")
	_p(head, sphere, skin.lightened(0.08), Vector3(0, 0.1, 0.2), Vector3(0.12, 0.14, 0.14), Vector3.ZERO, "Nose")
	_p(head, MeshKit.box(), Color(0.3, 0.1, 0.1), Vector3(0, 0.0, 0.18), Vector3(0.16, 0.025, 0.04))
	_p(head, MeshKit.cone(), Color(1, 1, 0.95), Vector3(0.05, 0.02, 0.19), Vector3(0.03, 0.05, 0.03))
	_eyes(head, 0.2, 0.16, 0.1, 0.08, _c[3], 0.8)
	_p(head, MeshKit.box(), skin.darkened(0.3), Vector3(0, 0.27, 0.17), Vector3(0.26, 0.03, 0.04), Vector3(0, 0, 0))
	for i in 4:
		_p(head, MeshKit.cone(), Color(0.2, 0.15, 0.12), Vector3(0, 0.36, 0.08 - i * 0.08), Vector3(0.06, 0.16, 0.06), Vector3(-20 * i, 0, 0))
	for side in [-1, 1]:
		var ear := MeshKit.pivot(head, "EarL" if side < 0 else "EarR", Vector3(0.22 * side, 0.18, 0))
		_p(ear, MeshKit.cone(), skin, Vector3(0.08 * side, 0, 0), Vector3(0.08, 0.22, 0.05), Vector3(0, 0, -80 * side))
		var arm := MeshKit.pivot(body, "ArmL" if side < 0 else "ArmR", Vector3(0.22 * side, 0.32, 0))
		_p(arm, MeshKit.capsule(), skin, Vector3(0.02 * side, -0.12, 0), Vector3(0.1, 0.11, 0.1))
		_p(arm, sphere, skin, Vector3(0.02 * side, -0.25, 0.02), Vector3(0.11, 0.1, 0.11))
		if side > 0:
			_p(arm, MeshKit.cylinder(), club, Vector3(0.03, -0.25, 0.2), Vector3(0.05, 0.4, 0.05), Vector3(75, 0, 0), "Club")
			_p(arm, sphere, club.lightened(0.1), Vector3(0.03, -0.2, 0.42), Vector3(0.14, 0.14, 0.2), Vector3(75, 0, 0))
	return 0.95


## Plant creature with a flower head. Option "cactus" = big spiky form.
func _plant(rig: Node3D) -> float:
	var green: Color = _c[0]
	var petal: Color = _c[1]
	var center: Color = _c[2]
	var cactus: bool = _opt("cactus", false)
	var sphere := MeshKit.sphere()
	for side in [-1, 1]:
		var leg := MeshKit.pivot(rig, "LegL" if side < 0 else "LegR", Vector3(0.12 * side, 0.22, 0))
		_p(leg, MeshKit.capsule(), green.darkened(0.2), Vector3(0, -0.1, 0.02), Vector3(0.1, 0.1, 0.12))
		_claws(leg, Vector3(0, -0.2, 0.1), 3, 0.03, green.darkened(0.35))
	var body := MeshKit.pivot(rig, "Body", Vector3(0, 0.22, 0))
	if cactus:
		_p(body, MeshKit.capsule(), green, Vector3(0, 0.3, 0), Vector3(0.5, 0.3, 0.46), Vector3.ZERO, "Torso")
		for i in 14:
			var ang := i * TAU / 7.0
			var y := 0.12 + floorf(i / 7.0) * 0.3
			_p(body, MeshKit.cone(), Color(1, 0.98, 0.85), Vector3(cos(ang) * 0.24, y, sin(ang) * 0.22), Vector3(0.03, 0.08, 0.03), Vector3(0, -rad_to_deg(ang), -90))
	else:
		_p(body, sphere, green, Vector3(0, 0.16, 0), Vector3(0.36, 0.4, 0.32), Vector3.ZERO, "Torso")
	var head := MeshKit.pivot(body, "Head", Vector3(0, 0.62 if cactus else 0.38, 0.02))
	_p(head, sphere, green.lightened(0.1), Vector3(0, 0.1, 0.02), Vector3(0.4, 0.36, 0.36), Vector3.ZERO, "Skull")
	_eyes(head, 0.13, 0.16, 0.1, 0.08, _c[3], 0.9)
	_p(head, MeshKit.box(), Color(0.3, 0.12, 0.12), Vector3(0, 0.02, 0.18), Vector3(0.08, 0.015, 0.02))
	var flower := MeshKit.pivot(head, "EarL", Vector3(0, 0.28, 0))
	var petals := 5 if not cactus else 6
	var petal_size := 0.22 if not cactus else 0.14
	for i in petals:
		var ang := i * TAU / petals
		_p(flower, sphere, petal, Vector3(cos(ang) * 0.14, 0.02, sin(ang) * 0.14), Vector3(petal_size, 0.06, petal_size * 0.7), Vector3(0, -rad_to_deg(ang), 12))
	_p(flower, sphere, center, Vector3(0, 0.05, 0), Vector3(0.12, 0.08, 0.12))
	MeshKit.pivot(head, "EarR", Vector3(0, 0.28, 0))
	for side in [-1, 1]:
		var arm := MeshKit.pivot(body, "ArmL" if side < 0 else "ArmR", Vector3(0.2 * side, 0.26 if not cactus else 0.42, 0.02))
		if cactus:
			_p(arm, MeshKit.capsule(), green, Vector3(0.06 * side, -0.08, 0), Vector3(0.14, 0.12, 0.14))
			_p(arm, sphere, petal, Vector3(0.08 * side, -0.22, 0.04), Vector3(0.22, 0.22, 0.22), Vector3.ZERO, "Glove")
		else:
			_p(arm, MeshKit.capsule(), green.darkened(0.1), Vector3(0.04 * side, -0.14, 0.02), Vector3(0.06, 0.14, 0.06), Vector3(0, 0, 10 * side))
			_p(arm, sphere, green.lightened(0.2), Vector3(0.06 * side, -0.3, 0.04), Vector3(0.1, 0.05, 0.14), Vector3(0, 0, 30 * side))
	return 1.0 if cactus else 0.85


## Small quadruped with a fan of tails.
func _critter(rig: Node3D) -> float:
	var main: Color = _c[0]
	var stripe: Color = _c[1]
	var tails: Color = _c[2]
	var sphere := MeshKit.sphere()
	var legs := {"LegFL": Vector3(-0.12, 0.2, 0.16), "LegFR": Vector3(0.12, 0.2, 0.16),
		"LegBL": Vector3(-0.13, 0.2, -0.16), "LegBR": Vector3(0.13, 0.2, -0.16)}
	for leg_name in legs.keys():
		var leg := MeshKit.pivot(rig, leg_name, legs[leg_name])
		_p(leg, MeshKit.capsule(), main, Vector3(0, -0.1, 0), Vector3(0.09, 0.08, 0.1))
		_p(leg, sphere, Color(0.98, 0.98, 1.0), Vector3(0, -0.18, 0.03), Vector3(0.1, 0.06, 0.13))
	var body := MeshKit.pivot(rig, "Body", Vector3(0, 0.32, 0))
	_p(body, sphere, main, Vector3(0, 0, 0), Vector3(0.36, 0.3, 0.52), Vector3.ZERO, "Torso")
	_p(body, sphere, Color(0.98, 0.95, 0.9), Vector3(0, -0.05, 0.1), Vector3(0.26, 0.2, 0.3))
	for i in 3:
		_p(body, MeshKit.box(), stripe, Vector3(0, 0.12, 0.12 - i * 0.12), Vector3(0.3, 0.04, 0.05), Vector3(0, 0, 0))
	var head := MeshKit.pivot(body, "Head", Vector3(0, 0.12, 0.26))
	_p(head, sphere, main, Vector3(0, 0.1, 0.02), Vector3(0.36, 0.32, 0.32), Vector3.ZERO, "Skull")
	_p(head, sphere, Color(0.98, 0.95, 0.9), Vector3(0, 0.04, 0.14), Vector3(0.18, 0.12, 0.12))
	_p(head, sphere, Color(0.1, 0.08, 0.1), Vector3(0, 0.07, 0.21), Vector3(0.05, 0.035, 0.03))
	_p(head, MeshKit.box(), stripe, Vector3(0, 0.25, 0.08), Vector3(0.05, 0.02, 0.14))
	_eyes(head, 0.15, 0.14, 0.09, 0.075, Color(0.2, 0.5, 0.9), 0.9)
	for side in [-1, 1]:
		var ear := MeshKit.pivot(head, "EarL" if side < 0 else "EarR", Vector3(0.12 * side, 0.22, 0))
		_p(ear, MeshKit.cone(), main, Vector3(0.02 * side, 0.1, 0), Vector3(0.1, 0.22, 0.06), Vector3(0, 0, -20 * side))
		_p(ear, MeshKit.cone(), stripe, Vector3(0.02 * side, 0.09, 0.02), Vector3(0.06, 0.16, 0.03), Vector3(0, 0, -20 * side))
	var tail := MeshKit.pivot(body, "Tail", Vector3(0, 0.06, -0.24))
	for i in 7:
		var spread := (float(i) / 6.0 - 0.5) * 100.0
		var t_node := MeshKit.pivot(tail, "T%d" % i, Vector3.ZERO, Vector3(-40, spread, 0))
		_p(t_node, MeshKit.capsule(), tails, Vector3(0, 0, -0.16), Vector3(0.05, 0.1, 0.05), Vector3(-90, 0, 0))
		_glow(t_node, sphere, tails.lightened(0.4), Vector3(0, 0, -0.3), Vector3(0.05, 0.05, 0.05))
	return 0.72


## Round bird. Large model_scale makes a great bird.
func _bird(rig: Node3D) -> float:
	var main: Color = _c[0]
	var beak: Color = _c[1]
	var feather: Color = _c[2]
	var sphere := MeshKit.sphere()
	for side in [-1, 1]:
		var leg := MeshKit.pivot(rig, "LegL" if side < 0 else "LegR", Vector3(0.1 * side, 0.16, 0.02))
		_p(leg, MeshKit.cylinder(), beak, Vector3(0, -0.06, 0), Vector3(0.035, 0.14, 0.035))
		_claws(leg, Vector3(0, -0.13, 0.05), 3, 0.03, beak.darkened(0.1))
	var body := MeshKit.pivot(rig, "Body", Vector3(0, 0.2, 0))
	_p(body, sphere, main, Vector3(0, 0.14, 0), Vector3(0.44, 0.44, 0.42), Vector3.ZERO, "Torso")
	_p(body, sphere, main.lightened(0.3), Vector3(0, 0.1, 0.12), Vector3(0.3, 0.3, 0.22))
	var head := MeshKit.pivot(body, "Head", Vector3(0, 0.38, 0.04))
	_p(head, sphere, main, Vector3(0, 0.12, 0), Vector3(0.4, 0.38, 0.38), Vector3.ZERO, "Skull")
	_p(head, MeshKit.cone(), beak, Vector3(0, 0.08, 0.24), Vector3(0.12, 0.18, 0.1), Vector3(90, 0, 0), "Beak")
	_eyes(head, 0.16, 0.14, 0.1, 0.08, _c[3], 0.9)
	for i in 3:
		_p(head, sphere, feather, Vector3((i - 1) * 0.05, 0.34, -0.02 - i * 0.03), Vector3(0.06, 0.16, 0.06), Vector3(-20 - i * 15, 0, (i - 1) * 20))
	for side in [-1, 1]:
		var wing := MeshKit.pivot(body, "WingL" if side < 0 else "WingR", Vector3(0.2 * side, 0.24, -0.02))
		_p(wing, sphere, main.darkened(0.08), Vector3(0.14 * side, -0.04, 0), Vector3(0.3, 0.12, 0.26), Vector3(0, 0, 30 * side))
		_p(wing, sphere, feather, Vector3(0.26 * side, -0.1, -0.02), Vector3(0.16, 0.08, 0.2), Vector3(0, 0, 40 * side))
		MeshKit.pivot(body, "ArmL" if side < 0 else "ArmR", Vector3(0.2 * side, 0.24, 0))
	var tail := MeshKit.pivot(body, "Tail", Vector3(0, 0.08, -0.2))
	for i in 3:
		_p(tail, sphere, feather if i == 1 else main, Vector3((i - 1) * 0.06, 0, -0.12), Vector3(0.08, 0.04, 0.24), Vector3(10, (i - 1) * 20, 0))
	return 0.8


## Round baby blob. Options: ears (&"long"/&"short"), horn, feet.
func _blob(rig: Node3D) -> float:
	var main: Color = _c[0]
	var light: Color = _c[1]
	var accent: Color = _c[2]
	var sphere := MeshKit.sphere()
	var body := MeshKit.pivot(rig, "Body", Vector3(0, 0.0, 0))
	_p(body, sphere, main, Vector3(0, 0.24, 0), Vector3(0.52, 0.46, 0.48), Vector3.ZERO, "Torso")
	_p(body, sphere, light, Vector3(0, 0.18, 0.14), Vector3(0.34, 0.26, 0.24))
	var head := MeshKit.pivot(body, "Head", Vector3(0, 0.18, 0))
	_eyes(head, 0.14, 0.2, 0.1, 0.085, _c[3])
	_p(head, MeshKit.box(), Color(0.35, 0.1, 0.12), Vector3(0, 0.03, 0.235), Vector3(0.12, 0.02, 0.02))
	var ears: StringName = StringName(str(_opt("ears", "")))
	for side in [-1, 1]:
		var ear := MeshKit.pivot(head, "EarL" if side < 0 else "EarR", Vector3(0.16 * side, 0.28, -0.02))
		if ears == &"long":
			_p(ear, MeshKit.capsule(), main, Vector3(0.1 * side, 0.1, -0.02), Vector3(0.1, 0.18, 0.08), Vector3(0, 0, -45 * side))
		elif ears == &"short":
			_p(ear, sphere, main, Vector3(0.02 * side, 0.02, 0), Vector3(0.1, 0.12, 0.08))
	if _opt("horn", false):
		_p(head, MeshKit.cone(), accent, Vector3(0, 0.32, 0.04), Vector3(0.1, 0.2, 0.1), Vector3(10, 0, 0))
	for side in [-1, 1]:
		var leg := MeshKit.pivot(rig, "LegL" if side < 0 else "LegR", Vector3(0.12 * side, 0.06, 0.06))
		if _opt("feet", false):
			_p(leg, sphere, accent, Vector3(0, -0.02, 0.04), Vector3(0.12, 0.08, 0.14))
	return 0.55
