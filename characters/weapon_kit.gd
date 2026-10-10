class_name WeaponKit
extends RefCounted
## Held weapons and shields: modelled GLBs, one per gear tier (Lv.1-10 of each
## kind). A look id is "<kind>_<tier>", e.g. "staff_7". Every weapon is placed
## with its grip at the origin and its tip along +Y (bows lie in the XZ plane),
## the same convention as the KayKit weapon models. A few code-built props stay
## (the priest's book) together with the mesh helpers other kits share.

const KINDS: Array[String] = ["sword", "bow", "staff", "wand", "spear"]

const GOLD := Color("ffc93c")

## Modelled weapons (assets/models/weapons/<file>_<0-9>.glb), one per gear tier:
## Lv.1 is the starter weapon, Lv.10 the godly one. Each entry turns the model
## into this kit's convention (grip at the origin, blade along +Y, bows in XZ).
const MODEL_DIR := "res://assets/models/weapons/"
const MODEL_TIERS := 10
const MODELS := {
	"sword": {"file": "sword", "scale": 1.45, "offset": Vector3(0, -0.22, 0)},
	"staff": {"file": "staff", "scale": 2.0, "offset": Vector3(0, 0.1, 0)},
	"wand": {"file": "staff", "scale": 1.15, "offset": Vector3.ZERO},
	"bow": {"file": "bow", "scale": 2.2, "offset": Vector3(0, -0.25, 0), "basis": [Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)]},
	"shield": {"file": "shield", "scale": 1.0, "offset": Vector3.ZERO},
	"spear": {"file": "spear", "scale": 1.3, "offset": Vector3.ZERO},
}


static func has_model(kind: String) -> bool:
	return MODELS.has(kind)


## Number of looks of a kind: one model per gear tier.
static func designs(kind: String) -> int:
	return MODEL_TIERS if MODELS.has(kind) else 0


static func _model(kind: String, index: int) -> Node3D:
	var spec: Dictionary = MODELS[kind]
	var path := "%s%s_%d.glb" % [MODEL_DIR, spec.file, clampi(index, 0, MODEL_TIERS - 1)]
	var root := Node3D.new()
	var packed := load(path) as PackedScene
	if packed == null:
		return root
	var model := packed.instantiate() as Node3D
	var basis := Basis.IDENTITY
	if spec.has("basis"):
		var cols: Array = spec.basis
		basis = Basis(cols[0], cols[1], cols[2])
	model.transform = Transform3D(basis.scaled(Vector3.ONE * float(spec.scale)), basis * (spec.offset as Vector3) * float(spec.scale))
	root.add_child(model)
	return root


static func build(look: String) -> Node3D:
	var parts := look.rsplit("_", true, 1)
	var kind := parts[0] if MODELS.has(parts[0]) else "sword"
	var node := _model(kind, int(parts[1]) if parts.size() > 1 else 0)
	node.name = look
	return node


static func look_for(kind: String, tier: int, _variant := 0) -> String:
	return "%s_%d" % [kind, clampi(tier, 0, MODEL_TIERS - 1)]


static func all_looks() -> Array[String]:
	var out: Array[String] = []
	for k in KINDS:
		for i in designs(k):
			out.append("%s_%d" % [k, i])
	return out


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

static func _p(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	var opts := {}
	if glow > 0.0:
		opts["emission"] = glow
	var mi := MeshKit.part(parent, mesh, MeshKit.toon(color, opts), pos, size, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A tube following a planar polyline. plane_normal = axis the path is flat in.
static func tube(points: Array[Vector3], plane_normal: Vector3, radius: float, sides := 6) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in points.size():
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, points.size() - 1)]
		var tangent := (b - a).normalized()
		var normal := tangent.cross(plane_normal).normalized()
		var ring: Array[Vector3] = []
		var norms: Array[Vector3] = []
		for s in sides:
			var ang := TAU * s / sides
			var dir := normal * cos(ang) + plane_normal * sin(ang)
			ring.append(points[i] + dir * radius)
			norms.append(dir)
		rings.append([ring, norms])
	for i in points.size() - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			var r0: Array = rings[i]
			var r1: Array = rings[i + 1]
			var quad := [[r0[0][s], r0[1][s]], [r1[0][s], r1[1][s]], [r1[0][s2], r1[1][s2]], [r0[0][s2], r0[1][s2]]]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(quad[idx][1])
				st.add_vertex(quad[idx][0])
	return st.commit()


static func _arc(radius: float, from_deg: float, to_deg: float, steps := 14, squash := Vector2.ONE) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		pts.append(Vector3(cos(a) * radius * squash.x, sin(a) * radius * squash.y, 0))
	return pts


static func _tube_part(parent: Node3D, points: Array[Vector3], plane_normal: Vector3, radius: float, color: Color, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = tube(points, plane_normal, radius)
	var opts := {}
	if glow > 0.0:
		opts["emission"] = glow
	mi.material_override = MeshKit.toon(color, opts)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# Off-hand props
# ---------------------------------------------------------------------------

## Round shield, face towards +Z, built around its grip.
static func shield(look := "shield_0") -> Node3D:
	return _model("shield", int(look.rsplit("_", true, 1)[1]))


static func book(color := Color("ff5a9a")) -> Node3D:
	var root := Node3D.new()
	_p(root, MeshKit.box(), color, Vector3.ZERO, Vector3(0.42, 0.56, 0.12))
	_p(root, MeshKit.box(), Color("fff2c0"), Vector3(0.025, 0, 0), Vector3(0.38, 0.5, 0.1))
	_p(root, MeshKit.box(), GOLD, Vector3(-0.2, 0, 0), Vector3(0.04, 0.58, 0.14))
	_p(root, MeshKit.sphere_low(), GOLD, Vector3(0, 0, 0.07), Vector3(0.1, 0.1, 0.05), Vector3.ZERO, 0.8)
	return root
