class_name WeaponKit
extends RefCounted
## Procedural cartoon weapons: 12 designs per kind (two per gear tier).
## A look id is "<kind>_<index>", e.g. "staff_7". Every weapon is built with
## its grip at the origin and its tip along +Y (bows lie in the XZ plane),
## the same convention as the KayKit weapon models.

const KINDS: Array[String] = ["sword", "bow", "staff", "wand"]
const DESIGNS := 12

const WOOD := Color("b07a45")
const DARK_WOOD := Color("6e4526")
const IRON := Color("a9b2c0")
const STEEL := Color("d4dbe8")
const GOLD := Color("ffc93c")
const BRONZE := Color("c98a4a")

# blade length, blade width, blade colour, guard style, guard colour, grip colour, glow
const SWORDS := [
	{"len": 0.95, "w": 0.15, "blade": Color("c99a5e"), "guard": "bar", "gc": Color("7a4a26"), "grip": Color("5a3a22")},
	{"len": 1.05, "w": 0.16, "blade": Color("d8b070"), "guard": "bar", "gc": Color("c0392b"), "grip": Color("c0392b")},
	{"len": 1.0, "w": 0.17, "blade": Color("a9b2c0"), "guard": "bar", "gc": Color("6e7585"), "grip": Color("5a3a22")},
	{"len": 1.05, "w": 0.18, "blade": Color("d09a5a"), "guard": "cross", "gc": Color("a8632a"), "grip": Color("3e2a1a")},
	{"len": 1.25, "w": 0.2, "blade": Color("d4dbe8"), "guard": "cross", "gc": Color("7a8499"), "grip": Color("2c3a63")},
	{"len": 1.2, "w": 0.2, "blade": Color("e6ecf8"), "guard": "round", "gc": Color("4aa3ff"), "grip": Color("2c3a63"), "gem": Color("4aa3ff")},
	{"len": 1.35, "w": 0.22, "blade": Color("f1f4fb"), "guard": "cross", "gc": GOLD, "grip": Color("7a1f2b"), "gem": Color("ff4a5a")},
	{"len": 1.3, "w": 0.22, "blade": Color("c9d0e0"), "guard": "wings", "gc": Color("e8e8f4"), "grip": Color("2b2b3d"), "gem": Color("6ff0c0")},
	{"len": 1.4, "w": 0.24, "blade": Color("ff8a2a"), "guard": "wings", "gc": Color("7a1f10"), "grip": Color("3a1a10"), "glow": 1.4},
	{"len": 1.4, "w": 0.24, "blade": Color("7fe3ff"), "guard": "round", "gc": Color("2a6fb0"), "grip": Color("1f2f55"), "glow": 1.3},
	{"len": 1.55, "w": 0.28, "blade": Color("b8203a"), "guard": "wings", "gc": Color("26202e"), "grip": Color("26202e"), "glow": 0.9, "gem": Color("ffd23c")},
	{"len": 1.6, "w": 0.28, "blade": Color("fff3b8"), "guard": "wings", "gc": GOLD, "grip": Color("fff3b8"), "glow": 1.6, "gem": Color("ffffff")},
]

# shaft colour, head style, head colour, glow
const STAFFS := [
	{"shaft": WOOD, "head": "knob", "hc": DARK_WOOD},
	{"shaft": WOOD, "head": "orb", "hc": Color("7ad66b")},
	{"shaft": DARK_WOOD, "head": "crystal", "hc": Color("6fb8ff")},
	{"shaft": DARK_WOOD, "head": "leaf", "hc": Color("6fe07a")},
	{"shaft": Color("5b4a7a"), "head": "crescent", "hc": Color("b08aff")},
	{"shaft": Color("5b4a7a"), "head": "ring", "hc": Color("ff8fd0"), "glow": 1.0},
	{"shaft": Color("2f3a5a"), "head": "star", "hc": Color("ffd23c"), "glow": 1.1},
	{"shaft": Color("2f3a5a"), "head": "skull", "hc": Color("eae6d6")},
	{"shaft": Color("6e2a1a"), "head": "flame", "hc": Color("ff7a2a"), "glow": 1.5},
	{"shaft": Color("2a4a6e"), "head": "crystal", "hc": Color("7fe3ff"), "glow": 1.4},
	{"shaft": Color("26202e"), "head": "crescent", "hc": Color("ff4a5a"), "glow": 1.3},
	{"shaft": GOLD, "head": "ring", "hc": Color("fff3b8"), "glow": 1.8},
]

const WANDS := [
	{"shaft": WOOD, "tip": "orb", "tc": Color("e6ecff")},
	{"shaft": WOOD, "tip": "star", "tc": Color("ffd23c")},
	{"shaft": Color("c4cbe0"), "tip": "orb", "tc": Color("8fd0ff")},
	{"shaft": Color("c4cbe0"), "tip": "heart", "tc": Color("ff6f9a")},
	{"shaft": Color("f1f4fb"), "tip": "crystal", "tc": Color("fff3b8"), "glow": 1.0},
	{"shaft": Color("f1f4fb"), "tip": "feather", "tc": Color("ffffff")},
	{"shaft": GOLD, "tip": "star", "tc": Color("fff3b8"), "glow": 1.2},
	{"shaft": GOLD, "tip": "heart", "tc": Color("ff4a7a"), "glow": 1.0},
	{"shaft": Color("7a3a1a"), "tip": "flame", "tc": Color("ff7a2a"), "glow": 1.4},
	{"shaft": Color("2a4a6e"), "tip": "crystal", "tc": Color("7fe3ff"), "glow": 1.3},
	{"shaft": Color("fff3b8"), "tip": "feather", "tc": Color("ffe27a"), "glow": 1.2},
	{"shaft": Color("fff3b8"), "tip": "star", "tc": Color("ffffff"), "glow": 2.0},
]

# wood colour, limb style, size, string colour, gem colour (or transparent)
const BOWS := [
	{"wood": Color("b88a50"), "style": "plain", "size": 1.0},
	{"wood": Color("d0a060"), "style": "plain", "size": 1.1, "gem": Color("c0392b")},
	{"wood": Color("8a5a30"), "style": "recurve", "size": 1.1},
	{"wood": Color("6e8a3a"), "style": "recurve", "size": 1.15, "gem": Color("ffd23c")},
	{"wood": Color("5a4a6e"), "style": "leaf", "size": 1.2},
	{"wood": Color("3e7a5a"), "style": "leaf", "size": 1.25, "gem": Color("9fffd0")},
	{"wood": Color("d4dbe8"), "style": "horn", "size": 1.25},
	{"wood": Color("e8d8a0"), "style": "horn", "size": 1.3, "gem": Color("ff4a5a")},
	{"wood": Color("7a2a1a"), "style": "recurve", "size": 1.35, "glow": Color("ff7a2a")},
	{"wood": Color("2a4a6e"), "style": "leaf", "size": 1.35, "glow": Color("7fe3ff")},
	{"wood": Color("26202e"), "style": "horn", "size": 1.4, "glow": Color("ff4a5a")},
	{"wood": GOLD, "style": "leaf", "size": 1.5, "glow": Color("fff3b8")},
]


static func build(look: String) -> Node3D:
	var parts := look.rsplit("_", true, 1)
	var kind := parts[0]
	var index := clampi(int(parts[1]), 0, DESIGNS - 1) if parts.size() > 1 else 0
	var root := Node3D.new()
	root.name = look
	match kind:
		"sword": _sword(root, SWORDS[index])
		"bow": _bow(root, BOWS[index])
		"staff": _staff(root, STAFFS[index])
		"wand": _wand(root, WANDS[index])
		_: _sword(root, SWORDS[0])
	return root


static func look_for(kind: String, tier: int, variant: int) -> String:
	return "%s_%d" % [kind, clampi(tier * 2 + variant, 0, DESIGNS - 1)]


static func all_looks() -> Array[String]:
	var out: Array[String] = []
	for k in KINDS:
		for i in DESIGNS:
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
# Swords
# ---------------------------------------------------------------------------

static func _sword(root: Node3D, d: Dictionary) -> void:
	var glow := float(d.get("glow", 0.0))
	var blade_len: float = d.len
	var blade_w: float = d.w
	_p(root, MeshKit.cylinder(), d.grip, Vector3(0, 0.0, 0), Vector3(0.1, 0.36, 0.1))
	_p(root, MeshKit.sphere_low(), d.gc, Vector3(0, -0.22, 0), Vector3(0.17, 0.17, 0.17))
	var gy := 0.2
	match d.guard:
		"bar":
			_p(root, MeshKit.box(), d.gc, Vector3(0, gy, 0), Vector3(0.46, 0.07, 0.13))
		"cross":
			_p(root, MeshKit.box(), d.gc, Vector3(0, gy, 0), Vector3(0.5, 0.08, 0.14))
			for side in [-1.0, 1.0]:
				_p(root, MeshKit.sphere_low(), d.gc, Vector3(side * 0.26, gy, 0), Vector3(0.14, 0.14, 0.14))
		"round":
			_p(root, MeshKit.cylinder(), d.gc, Vector3(0, gy, 0), Vector3(0.38, 0.07, 0.38))
		"wings":
			_p(root, MeshKit.box(), d.gc, Vector3(0, gy, 0), Vector3(0.2, 0.1, 0.14))
			for side in [-1.0, 1.0]:
				_p(root, MeshKit.prism(), d.gc, Vector3(side * 0.26, gy + 0.12, 0), Vector3(0.34, 0.4, 0.08), Vector3(0, 0, side * -62.0))
	var by := gy + 0.04 + blade_len * 0.5
	_p(root, MeshKit.box(), d.blade, Vector3(0, by, 0), Vector3(blade_w, blade_len, 0.07), Vector3.ZERO, glow)
	_p(root, MeshKit.prism(), d.blade, Vector3(0, gy + 0.04 + blade_len + 0.13, 0), Vector3(blade_w, 0.3, 0.07), Vector3.ZERO, glow)
	var fuller: Color = (d.blade as Color).lightened(0.35)
	_p(root, MeshKit.box(), fuller, Vector3(0, by + 0.02, 0.04), Vector3(blade_w * 0.22, blade_len * 0.82, 0.03), Vector3.ZERO, glow)
	if d.has("gem"):
		_p(root, MeshKit.sphere_low(), d.gem, Vector3(0, gy + 0.0, 0.08), Vector3(0.1, 0.1, 0.1), Vector3.ZERO, 1.2)


# ---------------------------------------------------------------------------
# Staffs
# ---------------------------------------------------------------------------

static func _staff(root: Node3D, d: Dictionary) -> void:
	var glow := float(d.get("glow", 0.0))
	_p(root, MeshKit.cylinder(), d.shaft, Vector3(0, 0.1, 0), Vector3(0.1, 2.0, 0.1))
	_p(root, MeshKit.sphere_low(), (d.shaft as Color).darkened(0.2), Vector3(0, -0.92, 0), Vector3(0.14, 0.14, 0.14))
	var top := Vector3(0, 1.22, 0)
	var c: Color = d.hc
	match d.head:
		"knob":
			_p(root, MeshKit.sphere_low(), c, top + Vector3(0, 0.08, 0), Vector3(0.26, 0.26, 0.26))
		"orb":
			_p(root, MeshKit.torus(), Color("e7b64a"), top, Vector3(0.4, 0.3, 0.4), Vector3(90, 0, 0))
			_p(root, MeshKit.sphere(), c, top + Vector3(0, 0.1, 0), Vector3(0.3, 0.3, 0.3), Vector3.ZERO, 0.8 + glow)
		"crystal":
			_p(root, MeshKit.cone(), c, top + Vector3(0, 0.3, 0), Vector3(0.3, 0.5, 0.3), Vector3.ZERO, 0.8 + glow)
			_p(root, MeshKit.cone(), c.darkened(0.15), top + Vector3(0, -0.05, 0), Vector3(0.3, 0.3, 0.3), Vector3(180, 0, 0), 0.8 + glow)
			_p(root, MeshKit.torus(), Color("e7b64a"), top + Vector3(0, -0.2, 0), Vector3(0.28, 0.16, 0.28))
		"leaf":
			for side in [-1.0, 1.0]:
				_p(root, MeshKit.sphere(), c, top + Vector3(side * 0.13, 0.16, 0), Vector3(0.16, 0.5, 0.1), Vector3(0, 0, side * -22.0), glow)
			_p(root, MeshKit.sphere_low(), Color("ffd23c"), top + Vector3(0, 0.1, 0), Vector3(0.12, 0.12, 0.12), Vector3.ZERO, 1.0)
		"crescent":
			var pts := _arc(0.26, -50.0, 230.0, 16)
			var mi := _tube_part(root, pts, Vector3(0, 0, 1), 0.05, (d.shaft as Color).lightened(0.2))
			mi.position = top + Vector3(0, 0.18, 0)
			_p(root, MeshKit.sphere(), c, top + Vector3(0, 0.2, 0), Vector3(0.24, 0.24, 0.24), Vector3.ZERO, 0.9 + glow)
		"ring":
			_p(root, MeshKit.torus(), Color("e7b64a"), top + Vector3(0, 0.2, 0), Vector3(0.62, 0.62, 0.62), Vector3(90, 0, 0), 0.4)
			_p(root, MeshKit.sphere(), c, top + Vector3(0, 0.2, 0), Vector3(0.22, 0.22, 0.22), Vector3.ZERO, 0.9 + glow)
		"star":
			_p(root, MeshKit.sphere(), c, top + Vector3(0, 0.15, 0), Vector3(0.24, 0.24, 0.24), Vector3.ZERO, 0.9 + glow)
			for i in 6:
				var dir := Vector3(cos(i * PI / 3.0), sin(i * PI / 3.0), 0)
				_p(root, MeshKit.cone(), c, top + Vector3(0, 0.15, 0) + dir * 0.22, Vector3(0.1, 0.26, 0.1), Vector3(0, 0, rad_to_deg(atan2(dir.y, dir.x)) - 90.0), 0.9 + glow)
		"skull":
			_p(root, MeshKit.sphere(), c, top + Vector3(0, 0.15, 0), Vector3(0.34, 0.32, 0.32))
			_p(root, MeshKit.box(), c, top + Vector3(0, -0.03, 0.04), Vector3(0.18, 0.1, 0.16))
			for side in [-1.0, 1.0]:
				_p(root, MeshKit.sphere_low(), Color("2a1f30"), top + Vector3(side * 0.08, 0.17, 0.13), Vector3(0.09, 0.1, 0.06))
				_p(root, MeshKit.cone(), Color("5b4a7a"), top + Vector3(side * 0.2, 0.3, 0), Vector3(0.08, 0.22, 0.08), Vector3(0, 0, side * -35.0))
		"flame":
			_p(root, MeshKit.sphere_low(), Color("7a2a1a"), top + Vector3(0, 0.0, 0), Vector3(0.22, 0.22, 0.22))
			_p(root, MeshKit.cone(), c, top + Vector3(0, 0.3, 0), Vector3(0.3, 0.56, 0.3), Vector3.ZERO, 1.4)
			_p(root, MeshKit.cone(), Color("ffd23c"), top + Vector3(0, 0.24, 0), Vector3(0.16, 0.36, 0.16), Vector3.ZERO, 1.6)
			for side in [-1.0, 1.0]:
				_p(root, MeshKit.cone(), c, top + Vector3(side * 0.14, 0.16, 0), Vector3(0.14, 0.34, 0.14), Vector3(0, 0, side * -25.0), 1.4)


# ---------------------------------------------------------------------------
# Wands
# ---------------------------------------------------------------------------

static func _wand(root: Node3D, d: Dictionary) -> void:
	var glow := float(d.get("glow", 0.0))
	_p(root, MeshKit.cylinder(), d.shaft, Vector3(0, 0.2, 0), Vector3(0.07, 0.9, 0.07))
	_p(root, MeshKit.sphere_low(), (d.shaft as Color).darkened(0.15), Vector3(0, -0.27, 0), Vector3(0.11, 0.11, 0.11))
	_p(root, MeshKit.torus(), Color("e7b64a"), Vector3(0, 0.62, 0), Vector3(0.14, 0.08, 0.14))
	var top := Vector3(0, 0.82, 0)
	var c: Color = d.tc
	match d.tip:
		"orb":
			_p(root, MeshKit.sphere(), c, top + Vector3(0, 0.06, 0), Vector3(0.24, 0.24, 0.24), Vector3.ZERO, 0.8 + glow)
		"star":
			_p(root, MeshKit.sphere(), c, top + Vector3(0, 0.12, 0), Vector3(0.18, 0.18, 0.18), Vector3.ZERO, 1.0 + glow)
			for i in 5:
				var a := i * TAU / 5.0 + PI / 2.0
				var dir := Vector3(cos(a), sin(a), 0)
				_p(root, MeshKit.cone(), c, top + Vector3(0, 0.12, 0) + dir * 0.15, Vector3(0.1, 0.22, 0.06), Vector3(0, 0, rad_to_deg(a) - 90.0), 1.0 + glow)
		"heart":
			for side in [-1.0, 1.0]:
				_p(root, MeshKit.sphere(), c, top + Vector3(side * 0.07, 0.17, 0), Vector3(0.15, 0.17, 0.1), Vector3.ZERO, 0.8 + glow)
			_p(root, MeshKit.cone(), c, top + Vector3(0, 0.07, 0), Vector3(0.25, 0.2, 0.1), Vector3(0, 0, 180), 0.8 + glow)
		"crystal":
			_p(root, MeshKit.cone(), c, top + Vector3(0, 0.24, 0), Vector3(0.17, 0.34, 0.17), Vector3.ZERO, 0.9 + glow)
			_p(root, MeshKit.cone(), c.darkened(0.1), top + Vector3(0, 0.0, 0), Vector3(0.17, 0.2, 0.17), Vector3(180, 0, 0), 0.9 + glow)
		"feather":
			_p(root, MeshKit.sphere(), c, top + Vector3(0, 0.22, 0), Vector3(0.14, 0.5, 0.05), Vector3(0, 0, -10), glow)
			_p(root, MeshKit.sphere(), c.darkened(0.08), top + Vector3(-0.04, 0.2, 0.02), Vector3(0.1, 0.4, 0.04), Vector3(0, 0, 14), glow)
		"flame":
			_p(root, MeshKit.cone(), c, top + Vector3(0, 0.2, 0), Vector3(0.2, 0.4, 0.2), Vector3.ZERO, 1.4)
			_p(root, MeshKit.cone(), Color("ffd23c"), top + Vector3(0, 0.16, 0), Vector3(0.1, 0.24, 0.1), Vector3.ZERO, 1.6)


# ---------------------------------------------------------------------------
# Bows (flat in the XZ plane, belly towards -X like the KayKit bow)
# ---------------------------------------------------------------------------

static func _bow(root: Node3D, d: Dictionary) -> void:
	var s: float = d.size
	var wood: Color = d.wood
	var half := 0.95 * s
	var bulge := 0.42 * s
	var pts: Array[Vector3] = []
	var n := 16
	for i in n + 1:
		var t := lerpf(-1.0, 1.0, float(i) / n)
		var x := -bulge * (1.0 - t * t)
		var z := t * half
		match d.style:
			"recurve":
				x += 0.28 * s * pow(absf(t), 5.0)
			"leaf":
				x -= 0.1 * s * (1.0 - absf(t))
			"horn":
				x += 0.18 * s * pow(absf(t), 3.0) - 0.05 * s
		pts.append(Vector3(x, 0, z))
	var glow: Color = d.get("glow", Color(0, 0, 0, 0))
	var limb := _tube_part(root, pts, Vector3(0, 1, 0), 0.075 * s, wood, 0.0)
	limb.name = "Limb"
	if glow.a > 0.0:
		var rune := _tube_part(root, pts, Vector3(0, 1, 0), 0.04 * s, glow, 1.6)
		rune.position.y = 0.045
	var str_color := Color("f4efe0")
	var top: Vector3 = pts[n]
	var bottom: Vector3 = pts[0]
	var mid := (top + bottom) * 0.5
	_p(root, MeshKit.box(), str_color, mid, Vector3(0.012, 0.012, (top - bottom).length()))
	_p(root, MeshKit.cylinder(), wood.darkened(0.3), Vector3(pts[n / 2].x, 0, 0), Vector3(0.1, 0.14, 0.2), Vector3(90, 0, 0))
	for p in [top, bottom]:
		_p(root, MeshKit.sphere_low(), wood.lightened(0.2), p, Vector3(0.08, 0.08, 0.08))
	if d.has("gem"):
		_p(root, MeshKit.sphere_low(), d.gem, Vector3(pts[n / 2].x - 0.03, 0.06, 0), Vector3(0.1, 0.1, 0.1), Vector3.ZERO, 1.2)
	if d.style == "leaf":
		for side in [-1.0, 1.0]:
			_p(root, MeshKit.sphere(), wood.lightened(0.15), Vector3(pts[n / 2].x - 0.12, 0, side * 0.2), Vector3(0.18, 0.04, 0.34), Vector3(0, side * 20.0, 0))
	if d.style == "horn":
		for p in [top, bottom]:
			_p(root, MeshKit.cone(), wood.lightened(0.25), p + Vector3(0.05, 0, signf(p.z) * 0.1), Vector3(0.09, 0.28, 0.09), Vector3(0, 0, 90))


# ---------------------------------------------------------------------------
# Off-hand props
# ---------------------------------------------------------------------------

## Round shield, face towards +Z, built around its grip.
static func shield(look := "shield_0") -> Node3D:
	var idx := clampi(int(look.rsplit("_", true, 1)[1]), 0, 5)
	var colors := [Color("a9b2c0"), Color("c98a4a"), Color("4aa3ff"), Color("ffc93c"), Color("c0392b"), Color("c46bff")]
	var c: Color = colors[idx]
	var root := Node3D.new()
	_p(root, MeshKit.cylinder(), c.darkened(0.15), Vector3(0, 0, 0), Vector3(0.9, 0.12, 0.9), Vector3(90, 0, 0))
	_p(root, MeshKit.torus(), c.lightened(0.3), Vector3(0, 0, 0.04), Vector3(0.92, 0.1, 0.92), Vector3(90, 0, 0))
	_p(root, MeshKit.sphere_low(), c.lightened(0.45), Vector3(0, 0, 0.1), Vector3(0.28, 0.28, 0.18))
	return root


static func book(color := Color("ff5a9a")) -> Node3D:
	var root := Node3D.new()
	_p(root, MeshKit.box(), color, Vector3.ZERO, Vector3(0.42, 0.56, 0.12))
	_p(root, MeshKit.box(), Color("fff2c0"), Vector3(0.025, 0, 0), Vector3(0.38, 0.5, 0.1))
	_p(root, MeshKit.box(), GOLD, Vector3(-0.2, 0, 0), Vector3(0.04, 0.58, 0.14))
	_p(root, MeshKit.sphere_low(), GOLD, Vector3(0, 0, 0.07), Vector3(0.1, 0.1, 0.05), Vector3.ZERO, 0.8)
	return root
