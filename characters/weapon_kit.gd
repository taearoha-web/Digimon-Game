class_name WeaponKit
extends RefCounted
## Held weapons and shields: modelled GLBs, one per gear tier (Lv.1-10 of each
## kind). A look id is "<kind>_<tier>", e.g. "staff_7". Every weapon is placed
## with its grip at the origin and its tip along +Y (bows lie in the XZ plane),
## the same convention as the KayKit weapon models. A few code-built props stay
## (the priest's book) together with the mesh helpers other kits share.

## The mage carries the staff, the priest a short wand (with a matching book) and
## the summoner a lantern staff (with the grimoire of the same tier, see TOME).
const KINDS: Array[String] = ["sword", "bow", "staff", "wand", "lantern", "spear"]

const GOLD := Color("ffc93c")

## Modelled weapons (assets/models/weapons/<file>_<0-9>.glb), one per gear tier:
## Lv.1 is the starter weapon, Lv.10 the godly one. Each entry turns the model
## into this kit's convention (grip at the origin, blade along +Y, bows in XZ).
const MODEL_DIR := "res://assets/models/weapons/"
const MODEL_TIERS := 10
const MODELS := {
	"sword": {"file": "sword", "scale": 1.45, "offset": Vector3(0, -0.22, 0)},
	"staff": {"file": "staff", "scale": 2.0, "offset": Vector3(0, 0.1, 0)},
	"wand": {"file": "wand", "scale": 1.7, "offset": Vector3(0, 0.05, 0)},
	"lantern": {"file": "lantern", "scale": 1.9, "offset": Vector3(0, 0.1, 0)},
	# The summoner's grimoire: not an item, it follows the lantern's tier.
	"tome": {"file": "tome", "scale": 2.1, "offset": Vector3.ZERO},
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


## The priest's book follows the wand of the same tier: cover, metal trim and
## gem colours of that wand, and an emblem in the wand's shape (moon, sun,
## snowflake, eclipse, cross, star, lotus).
const BOOK_STYLES := [
	{"cover": Color("8a5a32"), "trim": Color("d8a640"), "gem": Color("8fd0ff"), "emblem": "ring"},
	{"cover": Color("7c8590"), "trim": Color("454b55"), "gem": Color("e04848"), "emblem": "plate"},
	{"cover": Color("9ed8cc"), "trim": Color("e6eef2"), "gem": Color("38e0e6"), "emblem": "moon"},
	{"cover": Color("eef0f4"), "trim": Color("e0b440"), "gem": Color("a04ae0"), "emblem": "ring"},
	{"cover": Color("6a1820"), "trim": Color("e0a838"), "gem": Color("ff9a28"), "emblem": "sun"},
	{"cover": Color("cfe6f6"), "trim": Color("ffffff"), "gem": Color("7ac8ff"), "emblem": "snow"},
	{"cover": Color("1c1824"), "trim": Color("5a3080"), "gem": Color("c45aff"), "emblem": "eclipse"},
	{"cover": Color("f2e2b8"), "trim": Color("e0b440"), "gem": Color("fffbe8"), "emblem": "cross"},
	{"cover": Color("1e2a5a"), "trim": Color("e8c040"), "gem": Color("fff060"), "emblem": "star"},
	{"cover": Color("6a3ab8"), "trim": Color("f0c850"), "gem": Color("8ff0ff"), "emblem": "lotus"},
]


static func book(tier := 0) -> Node3D:
	var style: Dictionary = BOOK_STYLES[clampi(tier, 0, BOOK_STYLES.size() - 1)]
	var cover: Color = style.cover
	var trim: Color = style.trim
	var gem: Color = style.gem
	var glow := 0.6 + 0.12 * tier
	var root := Node3D.new()
	_p(root, MeshKit.box(), cover, Vector3.ZERO, Vector3(0.42, 0.56, 0.12))
	_p(root, MeshKit.box(), Color("fff4d6"), Vector3(0.025, 0, 0), Vector3(0.38, 0.52, 0.1))
	_p(root, MeshKit.box(), trim, Vector3(-0.2, 0, 0), Vector3(0.05, 0.58, 0.14))
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			_p(root, MeshKit.box(), trim, Vector3(x * 0.18, y * 0.25, 0.0), Vector3(0.08, 0.08, 0.135))
	if tier >= 3:
		_p(root, MeshKit.box(), trim, Vector3(0.2, 0, 0), Vector3(0.05, 0.1, 0.14))
	var face := Vector3(0.0, 0.0, 0.065)
	match String(style.emblem):
		"plate":
			_p(root, MeshKit.box(), trim, face, Vector3(0.2, 0.26, 0.02))
			_p(root, MeshKit.sphere_low(), gem, face + Vector3(0, 0, 0.015), Vector3(0.07, 0.07, 0.04), Vector3.ZERO, glow)
		"moon":
			_p(root, MeshKit.torus(), trim, face, Vector3(0.2, 0.2, 0.2), Vector3(90, 0, 0))
			_p(root, MeshKit.sphere_low(), cover, face + Vector3(0.04, 0.03, 0.01), Vector3(0.16, 0.16, 0.03))
			_p(root, MeshKit.sphere_low(), gem, face + Vector3(-0.03, -0.02, 0.01), Vector3(0.06, 0.06, 0.04), Vector3.ZERO, glow)
		"sun":
			for k in 8:
				_p(root, MeshKit.prism(), trim, face + Vector3(cos(k * PI / 4.0), sin(k * PI / 4.0), 0) * 0.1, Vector3(0.04, 0.08, 0.02), Vector3(0, 0, rad_to_deg(k * PI / 4.0) - 90.0))
			_p(root, MeshKit.sphere_low(), gem, face, Vector3(0.12, 0.12, 0.05), Vector3.ZERO, glow)
		"snow":
			for k in 3:
				_p(root, MeshKit.box(), trim, face, Vector3(0.03, 0.26, 0.02), Vector3(0, 0, k * 60.0), 0.3)
			_p(root, MeshKit.sphere_low(), gem, face, Vector3(0.07, 0.07, 0.04), Vector3.ZERO, glow)
		"eclipse":
			_p(root, MeshKit.torus(), gem, face, Vector3(0.22, 0.22, 0.22), Vector3(90, 0, 0), glow)
			_p(root, MeshKit.sphere_low(), Color("0c0a12"), face + Vector3(0, 0, 0.01), Vector3(0.15, 0.15, 0.03))
		"cross":
			_p(root, MeshKit.box(), trim, face, Vector3(0.05, 0.3, 0.02))
			_p(root, MeshKit.box(), trim, face + Vector3(0, 0.05, 0), Vector3(0.2, 0.05, 0.02))
			_p(root, MeshKit.sphere_low(), gem, face + Vector3(0, 0.05, 0.015), Vector3(0.06, 0.06, 0.04), Vector3.ZERO, glow)
		"star":
			for k in 4:
				_p(root, MeshKit.prism(), trim, face + Vector3(cos(k * PI / 2.0), sin(k * PI / 2.0), 0) * 0.08, Vector3(0.05, 0.12, 0.02), Vector3(0, 0, rad_to_deg(k * PI / 2.0) - 90.0))
			_p(root, MeshKit.sphere_low(), gem, face, Vector3(0.08, 0.08, 0.05), Vector3.ZERO, glow)
		"lotus":
			for k in 5:
				var a := deg_to_rad(90.0 + (k - 2) * 32.0)
				_p(root, MeshKit.sphere_low(), gem.lerp(Color.WHITE, 0.3), face + Vector3(cos(a), sin(a) - 0.6, 0) * 0.1, Vector3(0.05, 0.12, 0.02), Vector3(0, 0, rad_to_deg(a) - 90.0), glow * 0.6)
			_p(root, MeshKit.sphere_low(), trim, face + Vector3(0, -0.07, 0.01), Vector3(0.08, 0.05, 0.03), Vector3.ZERO, 0.4)
		_:
			_p(root, MeshKit.torus(), trim, face, Vector3(0.18, 0.18, 0.18), Vector3(90, 0, 0))
			_p(root, MeshKit.sphere_low(), gem, face, Vector3(0.09, 0.09, 0.05), Vector3.ZERO, glow)
	return root
