class_name HeavenFolk
extends RefCounted
## The folk of ดินแดนเทวาลัย (HeavenMonsters "folk"), sculpted in code like the sky isle's
## kirin (Kirin) and eastern dragons:
##   deva    เทวดาน้อยถือโคม: a chibi child deva in white silk worked with a gold ลาย
##           lattice, a tall gold ชฎา (brow band with its pointed กระบังหน้า, tiered spire,
##           lotus bud and needle, flame กรรเจียก at the ears), a gold petal กรองคอ collar,
##           crossed สังวาล chains, อินทรธนู flames on the shoulders, a rose stole fluttering
##           from her shoulders, a flame-tipped gold aureole behind the head; one hand in
##           จีบ, the other holding a curved gold pole from which a glowing Thai lantern
##           (ribbed paper with a red band, gold caps, fluttering red and gold tails) swings;
##           she floats on a small swirling cloud. Her charge: three light orbs.
##   hermit  พระฤๅษีนั่งเมฆ: an old ฤๅษี sitting cross-legged on a cloud, in a tiger-skin
##           wrap and a tiger-skin sash over one shoulder, a tall pointed tiger-skin ฤๅษี
##           hat banded in gold, a long white beard, moustache and bushy brows, eyes closed
##           in meditation, prayer beads round the neck; the right hand on a knotted
##           wooden staff with a gold crook, the left raised in blessing with a string of
##           beads. His charge: a gold ยันต์ mantra seal that grows in front of him and is
##           flung up to fall on the foe.
##
## One mesh per kind (vertex colours, built once; a lighter one at quality 0) and one shader
## (shaders/heaven_folk.gdshader, with its ink outline heaven_folk_line.gdshader) that poses
## it: every vertex knows its part (the body, the head, each arm's upper arm and forearm,
## the lantern, the cloud, the charge) and the shader turns the parts round the kind's pivots
## (uniforms of the kind's base material) from a few scalars HeavenFolkVisual tweens. No
## textures, lights or particles; each figure on the field has its own small material.
##
## Mesh metres: +Z is the front, the cloud's foot is at y = 0; HeavenFolkVisual scales the
## mesh to the template's height.

const K := preload("res://combat/god_art/_kit_arcane.gd")
const SHADER := preload("res://shaders/heaven_folk.gdshader")
const LINE_SHADER := preload("res://shaders/heaven_folk_line.gdshader")

## Parts (CUSTOM1.w in the shader).
const BODY := 0
const HEAD := 1
const UPPER_A := 2
const FORE_A := 3
const LANTERN := 4
const UPPER_B := 5
const FORE_B := 6
const CLOUD := 7
const CHARGE := 8
## Patterns (UV2.y).
const P_NONE := 0
const P_TIGER := 1
const P_GOLD := 2
const P_CLOUD := 3
const P_SILK := 4
const P_PAPER := 5
const P_SKIN := 6
## Added to a pattern: the piece wears no ink outline (open strips the hull would cover).
const NO_INK := 10

const GOLD := Color("ffcc48")
const GOLD_DK := Color("c98a1c")
const SILK := Color("fffaf0")
const SILK_DK := Color("efe2cf")
const RUBY := Color("e0304a")
const JADE := Color("3fd6a0")
const INK := Color("2b1a2a")
const CLOUD_HI := Color("ffffff")
const CLOUD_LO := Color("d8e4f6")
# The deva.
const SKIN := Color("ffe3cb")
const SKIN_DK := Color("f6c2a2")
const HAIR := Color("2e2236")
const ROSE := Color("ffb8cf")
const ROSE_DK := Color("f58cb0")
const PAPER := Color("fff0b4")
const LANTERN_RED := Color("d8343a")
const ORB := Color("ffd460")
# The hermit.
const TAN := Color("eab386")
const TAN_DK := Color("cf9264")
const TIGER := Color("f09a32")
const TIGER_DK := Color("d97a1e")
const BEARD := Color("fbfaf6")
const BEARD_DK := Color("d9e0ea")
const WOOD := Color("8a5630")
const WOOD_DK := Color("5c3418")
const BEAD := Color("6e3a1e")
const SEAL := Color("ffd65a")

## Each kind: its height (mesh metres, the crown's needle / the hat's tip), its pivots and
## charge (shader uniforms), the bounds (grown for the attack, the charge's flight and the
## death), where its parts are at rest (for dressing and tests) and its look.
const KINDS := {
	"deva": {"height": 2.14, "bob": 0.07,
		"neck": Vector3(0, 1.1, 0), "shoulder_a": Vector3(0.19, 0.99, 0.0), "elbow_a": Vector3(0.27, 0.83, 0.1),
		"shoulder_b": Vector3(-0.19, 0.99, 0.0), "elbow_b": Vector3(-0.28, 0.82, 0.06), "hook": Vector3(0.47, 1.37, 0.41),
		"cloud": Vector3(0, 0.2, 0), "seal_pivot": Vector3(0, 1.08, 0.12), "seal_axis": Vector3(0, 1, 0),
		"seal_fly": Vector3(0, 0.35, 0.9), "seal_spin": 3.2, "seal_spread": 1.8,
		"head": Vector3(0, 1.36, 0.02), "mouth": Vector3(0.47, 1.08, 0.41), "chest": Vector3(0, 0.9, 0.1),
		"box": AABB(Vector3(-1.3, -0.5, -1.3), Vector3(2.6, 3.6, 3.2)),
		"rim": Color("fff0c8"), "shadow": Color(0.8, 0.74, 0.84)},
	"hermit": {"height": 2.34, "bob": 0.05,
		"neck": Vector3(0, 1.15, 0), "shoulder_a": Vector3(0.23, 1.06, 0.0), "elbow_a": Vector3(0.4, 0.84, 0.08),
		"shoulder_b": Vector3(-0.23, 1.06, 0.0), "elbow_b": Vector3(-0.4, 0.84, 0.1), "hook": Vector3(0, 0, 0),
		"cloud": Vector3(0, 0.22, 0), "seal_pivot": Vector3(0, 1.95, 0.62), "seal_axis": Vector3(0, 0, 1),
		"seal_fly": Vector3(0, 1.3, 1.1), "seal_spin": 1.6, "seal_spread": 0.35,
		"head": Vector3(0, 1.36, 0.02), "mouth": Vector3(0, 1.95, 0.62), "chest": Vector3(0, 0.85, 0.15),
		"box": AABB(Vector3(-1.4, -0.5, -1.4), Vector3(2.8, 4.4, 3.6)),
		"rim": Color("ffe6c0"), "shadow": Color(0.8, 0.72, 0.76)},
}

static var _meshes := {}
static var _bases := {}
static var _lines := {}


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func spec(kind: String) -> Dictionary:
	return KINDS.get(kind, KINDS.deva)


## The kind's shared mesh (a lighter one at quality 0), built once.
static func mesh(kind: String) -> ArrayMesh:
	var lite := VfxBudget.quality() == 0
	var key := "%s|%d" % [kind, int(lite)]
	if not _meshes.has(key):
		var b := K.Builder.new()
		if kind == "hermit":
			_hermit(b, lite)
		else:
			_deva(b, lite)
		var built := b.mesh()
		built.custom_aabb = spec(kind).box
		_meshes[key] = built
	return _meshes[key]


static func _pose_params(m: ShaderMaterial, s: Dictionary) -> void:
	for key in ["neck", "shoulder_a", "elbow_a", "shoulder_b", "elbow_b", "hook", "seal_pivot", "seal_axis", "seal_fly", "seal_spin", "seal_spread"]:
		m.set_shader_parameter(key, s[key])
	m.set_shader_parameter("cloud_pivot", s.cloud)
	m.set_shader_parameter("bob_amp", s.bob)


## A fresh body material for one figure of [param kind].
static func material(kind: String) -> ShaderMaterial:
	if not _bases.has(kind):
		var s := spec(kind)
		var m := ShaderMaterial.new()
		m.shader = SHADER
		_pose_params(m, s)
		m.set_shader_parameter("rim_color", s.rim)
		m.set_shader_parameter("shadow_tint", s.shadow)
		m.set_shader_parameter("gold", GOLD)
		m.set_shader_parameter("lantern_red", LANTERN_RED)
		_bases[kind] = m
	return (_bases[kind] as ShaderMaterial).duplicate() as ShaderMaterial


## A fresh ink outline for one figure, [param width] in mesh metres.
static func line_material(kind: String, width: float) -> ShaderMaterial:
	if not _lines.has(kind):
		var m := ShaderMaterial.new()
		m.shader = LINE_SHADER
		_pose_params(m, spec(kind))
		_lines[kind] = m
	var out := (_lines[kind] as ShaderMaterial).duplicate() as ShaderMaterial
	out.set_shader_parameter("width", width)
	return out


## A figure ready to place: the body at mesh scale (scale it yourself), its own material.
static func body(kind: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "FolkBody"
	mi.mesh = mesh(kind)
	mi.material_override = material(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0
	return mi


static func triangles(m: ArrayMesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
	return n


# ---------------------------------------------------------------------------
# Kit.
# ---------------------------------------------------------------------------
static func _part(b: K.Builder, part: int, flutter := 0.0) -> void:
	b.customs = true
	b.pivot = Vector3.ZERO
	b.vel = Vector3.ZERO
	b.tumble = float(part)
	b.wait = flutter


static func _look(b: K.Builder, emit: float, pattern: int) -> void:
	b.emit = emit
	b.weight = float(pattern)


## A surface of revolution round the vertical through [param at] (profile [r, y, colour],
## y absolute), squeezed front to back by [param depth].
static func _lathe(b: K.Builder, at: Vector3, profile: Array, segs: int, depth := 1.0) -> void:
	b.xf = Transform3D(Basis.from_scale(Vector3(1, 1, depth)), Vector3(at.x, 0, at.z))
	b.lathe(profile, segs)
	b.xf = Transform3D.IDENTITY


## A ring (a torus) of radius [param big] round [param c], in the plane across [param axis].
static func _ring(b: K.Builder, c: Vector3, axis: Vector3, big: float, small: float, segs: int, col: Color, depth := 1.0) -> void:
	var u := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.UP).normalized()
	var w := axis.cross(u).normalized()
	var path := []
	for i in segs + 1:
		var a := TAU * float(i) / float(segs)
		var off := u * cos(a) * big + w * sin(a) * big
		off.z *= depth
		path.append(c + off)
	path[segs] = path[0]
	b.tube(path, [small], 3, [col], axis, false)


## An ellipsoid coloured by [param tone] (unit direction -> colour).
static func _ball_fn(b: K.Builder, c: Vector3, r: Vector3, lon: int, lat: int, tone: Callable) -> void:
	var base := b.v.size()
	for i in lat + 1:
		var th := PI * float(i) / float(lat)
		for j in lon + 1:
			var ph := TAU * float(j) / float(lon)
			var d := Vector3(sin(th) * sin(ph), cos(th), sin(th) * cos(ph))
			b.pt(c + d * r, (d / r).normalized(), tone.call(d), Vector2(float(j) / lon, float(i) / lat))
	for i in lat:
		for j in lon:
			var a := base + i * (lon + 1) + j
			var d := a + lon + 1
			# Wound as K.Builder.ball winds (this one runs round the other way).
			b.tri(a, d + 1, a + 1); b.tri(a, d, d + 1)


## A point on the ellipsoid (c, r) toward [param dir], [param out] metres proud of it.
static func _on(c: Vector3, r: Vector3, dir: Vector3, out := 0.0) -> Vector3:
	var d := dir.normalized()
	return c + d * r + d * out


## A cloud puff: a dome (no hidden underside) with smooth normals, bright on top, shaded
## round its foot, the biggest one rimmed in gold.
static func _puff(b: K.Builder, c: Vector3, r: Vector3, lon: int, lat: int, gilt := false) -> void:
	var base := b.v.size()
	var rows := lat + 1
	for i in rows + 1:
		var th := PI * 0.62 * float(mini(i, rows - 1)) / float(rows - 1)
		var inside := i < rows
		for j in lon + 1:
			var ph := TAU * float(j) / float(lon)
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) if inside else Vector3(0, -0.3, 0)
			var col := CLOUD_LO.lerp(CLOUD_HI, clampf(d.y * 0.9 + 0.45, 0.0, 1.0))
			if gilt and i == rows - 1:
				col = GOLD.lerp(CLOUD_HI, 0.3)
			b.pt(c + d * r, (d / r).normalized() if inside else Vector3.DOWN, col)
	for i in rows:
		for j in lon:
			var a := base + i * (lon + 1) + j
			var d := a + lon + 1
			if i == 0:
				b.tri(a, d + 1, d)
			else:
				b.tri(a, a + 1, d + 1); b.tri(a, d + 1, d)


## The cloud a figure rides: a big puff ringed with smaller ones and a curling tail.
static func _cloud(b: K.Builder, c: Vector3, size: float, lite: bool) -> void:
	_part(b, CLOUD)
	_look(b, 0.0, P_CLOUD)
	_puff(b, c, Vector3(0.66, 0.24, 0.58) * size, 8 if lite else 11, 2 if lite else 3, true)
	var n := 3 if lite else 5
	for k in n:
		var a := TAU * float(k) / float(n) + 0.4
		var rr := (0.5 + 0.08 * float(k % 2)) * size
		var at := c + Vector3(cos(a) * rr, -0.03 * size + 0.04 * size * float(k % 3), sin(a) * rr * 0.9)
		_puff(b, at, Vector3(0.3, 0.18, 0.28) * size * (1.0 - 0.12 * float(k % 2)), 6 if lite else 7, 2)
	if lite:
		return
	# The tail curling away behind, thinning to a wisp.
	var tail := []
	var radii := []
	for k in 7:
		var u := float(k) / 6.0
		var a := 1.3 * u * PI
		tail.append(c + Vector3((0.35 + 0.25 * u) * cos(a) * size, (0.02 + 0.12 * u) * size, -(0.55 + 0.25 * u) * size + 0.2 * sin(a) * size))
		radii.append(lerpf(0.13, 0.015, u) * size)
	b.tube(tail, radii, 5, [CLOUD_HI], Vector3.UP)


## A flame (กนก) outline: a leaf that curls over at its tip, [param lean] to the side.
static func _flame(width: float, height: float, lean: float, curl := 0.25, n := 8) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in n + 1:
		var t := float(k) / float(n)
		var half := width * 0.5 * pow(sin(PI * minf(t * 0.92 + 0.08, 1.0)), 0.8) * (1.0 - t * 0.35)
		var x := lean * height * t * t + curl * height * pow(t, 4.0)
		left.append(Vector2(x - half, height * t))
		right.append(Vector2(x + half, height * t))
	var out := PackedVector2Array()
	for p in right:
		out.append(p)
	out.append(Vector2(lean * height + curl * height * 1.35, height * 1.06))
	for k in range(left.size() - 1, -1, -1):
		out.append(left[k])
	return out


## An extruded plate of [param poly] (its own XY plane) [param thick] deep, placed by [param xf].
static func _plate(b: K.Builder, poly: PackedVector2Array, thick: float, xf: Transform3D, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		return
	var keep := b.xf
	b.xf = keep * xf
	var h := thick * 0.5
	for side in [1.0, -1.0]:
		var base := b.v.size()
		for p in poly:
			b.pt(Vector3(p.x, p.y, h * side), Vector3(0, 0, side), col, p)
		for k in range(0, tris.size(), 3):
			if side > 0.0:
				b.tri(base + tris[k], base + tris[k + 1], base + tris[k + 2])
			else:
				b.tri(base + tris[k], base + tris[k + 2], base + tris[k + 1])
	var edge := col.darkened(0.2)
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		b.quad(Vector3(p.x, p.y, -h), Vector3(q.x, q.y, -h), Vector3(q.x, q.y, h), Vector3(p.x, p.y, h), edge)
	b.xf = keep


## One lock of hair: a ribbon folded along its spine (so it has volume), root to tip in a
## soft S, tapering to a point, [param root_col] into [param tip_col]; its flutter grows to
## the tip (COLOR.a).
static func _lock(b: K.Builder, root: Vector3, tip: Vector3, width: float, curl: Vector3, face: Vector3, root_col: Color, tip_col: Color, segs := 3, phase := 0.0) -> void:
	var d := tip - root
	var pts := []
	for k in segs + 1:
		var u := float(k) / float(segs)
		pts.append(root + d * u + curl * sin(u * PI) - curl * 0.3 * sin(u * TAU + phase))
	var prev := []
	for k in pts.size():
		var u := float(k) / float(segs)
		var tangent: Vector3 = (pts[mini(k + 1, segs)] - pts[maxi(k - 1, 0)]).normalized()
		var across := tangent.cross(face).normalized()
		var up := across.cross(tangent).normalized()
		var w := width * 0.5 * pow(1.0 - u, 0.6) * (0.8 + 0.45 * sin(PI * minf(u * 1.6, 1.0)))
		var col := root_col.lerp(tip_col, u)
		col.a = 1.0 - u
		var ring := [
			b.pt(pts[k] - across * w, (up * 0.45 - across).normalized(), col),
			b.pt(pts[k] + up * w * 0.5, up, col),
			b.pt(pts[k] + across * w, (up * 0.45 + across).normalized(), col)]
		if not prev.is_empty():
			b.tri(prev[0], prev[1], ring[1]); b.tri(prev[0], ring[1], ring[0])
			b.tri(prev[1], prev[2], ring[2]); b.tri(prev[1], ring[2], ring[1])
		prev = ring


## A flat ribbon along [param pts], [param widths] wide across [param side] (its flat face),
## fluttering more toward its end; [param edge] lines both borders.
static func _strip(b: K.Builder, pts: Array, widths: Array, side: Vector3, col: Color, edge: Color) -> void:
	var prev := []
	for k in pts.size():
		var u := float(k) / float(pts.size() - 1)
		var tangent: Vector3 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var across := tangent.cross(side).normalized()
		var w := float(widths[mini(k, widths.size() - 1)]) * 0.5
		var c := col
		var e := edge
		c.a = 1.0 - u
		e.a = 1.0 - u
		var p: Vector3 = pts[k]
		var ring := [b.pt(p - across * w, side, e), b.pt(p - across * w * 0.6, side, c), b.pt(p + across * w * 0.6, side, c), b.pt(p + across * w, side, e)]
		if not prev.is_empty():
			for j in 3:
				b.tri(prev[j], prev[j + 1], ring[j + 1]); b.tri(prev[j], ring[j + 1], ring[j])
		prev = ring


## A limb segment: a tube from [param a] to [param b2] with a rounded joint at [param a].
static func _limb(b: K.Builder, a: Vector3, b2: Vector3, r0: float, r1: float, sides: int, col: Color, dark: Color, joint := true) -> void:
	b.tube([a, b2], [r0, r1], sides, [[col, dark]], Vector3.UP, false)
	if joint:
		b.ball(a, Vector3.ONE * r0, col, dark, sides, 3)


## The spire of a ชฎา: tapering tiers of rings, a lotus bud, a fine needle (profile [r, y, colour]).
static func _spire(y0: float, r0: float, y1: float, tiers: int, tip: float) -> Array:
	var prof: Array = []
	var span := (y1 - y0) / float(tiers)
	for k in tiers:
		var r := r0 * (1.0 - 0.7 * float(k) / float(tiers))
		var y := y0 + span * float(k)
		prof.append([r, y, GOLD_DK.lerp(GOLD, 0.5)])
		prof.append([r * 1.12, y + span * 0.35, GOLD])
		prof.append([r * 0.86, y + span * 0.9, GOLD_DK.lerp(GOLD, 0.4)])
	var rb := r0 * 0.3
	prof.append([rb * 1.3, y1 + 0.012, GOLD])
	prof.append([rb * 1.6, y1 + 0.04, GOLD])
	prof.append([rb * 0.9, y1 + 0.075, GOLD])
	prof.append([rb * 0.45, y1 + 0.1, GOLD])
	prof.append([rb * 0.25, tip - 0.03, GOLD])
	prof.append([0.0, tip, GOLD])
	return prof


# ---------------------------------------------------------------------------
# เทวดาน้อยถือโคม: the child deva with her lantern.
# ---------------------------------------------------------------------------
static func _deva(b: K.Builder, lite: bool) -> void:
	var s: Dictionary = KINDS.deva
	var seg := 7 if lite else 11
	var limb := 4 if lite else 5
	_cloud(b, s.cloud, 0.72, lite)
	# The skirt (ผ้านุ่ง) in white silk worked with gold, a gold hem band, a gold belt.
	_part(b, BODY)
	_look(b, 0.0, P_SILK)
	_lathe(b, Vector3.ZERO, [[0.3, 0.36, SILK_DK], [0.268, 0.45, SILK], [0.222, 0.55, SILK], [0.186, 0.64, SILK], [0.166, 0.71, SILK]], seg, 0.88)
	_look(b, 0.15, P_GOLD)
	_lathe(b, Vector3.ZERO, [[0.0, 0.3, GOLD_DK], [0.29, 0.3, GOLD_DK], [0.318, 0.32, GOLD], [0.318, 0.35, GOLD], [0.298, 0.372, GOLD_DK]], seg, 0.88)
	_ring(b, Vector3(0, 0.71, 0), Vector3.UP, 0.168, 0.026, 10, GOLD, 0.86)
	# The front panel (ชายไหว): red silk in a gold border hanging from the belt.
	_part(b, BODY, 0.25)
	_look(b, 0.1, P_NONE)
	var panel := []
	for k in 5:
		var u := float(k) / 4.0
		var y := lerpf(0.69, 0.34, u)
		var r := lerpf(0.166, 0.3, pow(u, 1.3)) * 0.88
		panel.append(Vector3(0, y, r + 0.014))
	_strip(b, panel, [0.1, 0.11, 0.12, 0.13, 0.14], Vector3.BACK, LANTERN_RED, GOLD)
	_part(b, BODY)
	_look(b, 0.5, P_NONE)
	b.ball(Vector3(0, 0.71, 0.162), Vector3(0.032, 0.032, 0.022), RUBY.lightened(0.3), RUBY, 6, 3)
	# The torso in the gold-worked silk jacket.
	_look(b, 0.0, P_SILK)
	b.tube([Vector3(0, 0.69, 0), Vector3(0, 0.8, 0.005), Vector3(0, 0.92, 0.01), Vector3(0, 1.02, 0), Vector3(0, 1.08, 0)],
		[Vector2(0.14, 0.165), Vector2(0.145, 0.17), Vector2(0.14, 0.168), Vector2(0.11, 0.14), Vector2(0.07, 0.08)], seg, [[SILK, SILK_DK]], Vector3.UP, false)
	_look(b, 0.0, P_SKIN)
	b.tube([Vector3(0, 1.04, 0), Vector3(0, 1.18, 0.0)], [0.058, 0.055], limb, [[SKIN, SKIN_DK]], Vector3.UP, false)
	# The สังวาล: two fine gold chains crossed over the chest, a gem where they cross.
	_look(b, 0.3, P_GOLD)
	for side in [-1.0, 1.0]:
		var chain := []
		for k in 6:
			var u := float(k) / 5.0
			var y := lerpf(1.0, 0.73, u)
			var x: float = lerpf(-0.12, 0.15, u) * side
			var xr := lerpf(0.14, 0.165, u)
			var zr := lerpf(0.11, 0.142, u)
			chain.append(Vector3(x, y, zr * sqrt(maxf(0.05, 1.0 - pow(x / xr, 2.0))) + 0.012))
		b.tube(chain, [0.011], 4, [GOLD], Vector3.UP, false)
	_look(b, 0.6, P_NONE)
	b.ball(Vector3(0, 0.866, 0.153), Vector3(0.028, 0.03, 0.018), JADE.lightened(0.3), JADE, 6, 3)
	# The กรองคอ: a gold collar flaring over the shoulders, ending in lotus petals.
	_look(b, 0.15, P_GOLD)
	_lathe(b, Vector3.ZERO, [[0.07, 1.1, GOLD], [0.12, 1.085, GOLD], [0.19, 1.05, GOLD], [0.215, 1.03, GOLD_DK]], seg, 0.8)
	var petals := 6 if lite else 10
	for k in petals:
		var a := TAU * float(k) / float(petals)
		var d := Vector3(sin(a), 0, cos(a) * 0.8)
		var d0 := Vector3(sin(a - 0.24), 0, cos(a - 0.24) * 0.8)
		var d1 := Vector3(sin(a + 0.24), 0, cos(a + 0.24) * 0.8)
		var tipp := d * 0.205 + Vector3(0, 0.955, 0)
		b.tri3(d0 * 0.215 + Vector3(0, 1.03, 0), d1 * 0.215 + Vector3(0, 1.03, 0), tipp, GOLD, GOLD, GOLD_DK)
	# Shoulder caps and the อินทรธนู flames over them.
	_look(b, 0.0, P_SILK)
	for sh in [s.shoulder_a, s.shoulder_b]:
		b.ball(sh + Vector3(0, 0.01, 0), Vector3(0.078, 0.07, 0.072), SILK, SILK_DK, limb + 1, 3)
	_look(b, 0.2, P_GOLD)
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 0.2, 1.04, -0.01)
		var basis := Basis(Vector3.BACK, -side * 0.5) * Basis.from_scale(Vector3(side, 1, 1))
		_plate(b, _flame(0.07, 0.16, 0.1, 0.32, 6), 0.012, Transform3D(basis, at), GOLD)
	# The stole: two rose ribbons from the shoulders, floating out behind her.
	_part(b, BODY, 1.0)
	_look(b, 0.25, P_NONE)
	for side in [-1.0, 1.0]:
		var ctrl := [Vector3(side * 0.15, 1.04, -0.1), Vector3(side * 0.3, 0.92, -0.2), Vector3(side * 0.37, 0.7, -0.28), Vector3(side * 0.34, 0.5, -0.25), Vector3(side * 0.43, 0.36, -0.36), Vector3(side * 0.6, 0.32, -0.52)]
		var path := Array(K.smooth(ctrl, 1 if lite else 2))
		_strip(b, path, [0.06, 0.08, 0.085, 0.08, 0.07, 0.04], Vector3(side, 0, -0.25).normalized(), ROSE, ROSE_DK)
	_deva_arms(b, s, limb, lite)
	_deva_head(b, s, seg, limb, lite)
	_deva_lantern(b, s, seg, lite)
	# The charge: three light orbs that gather round her and fly off.
	_part(b, CHARGE)
	_look(b, 2.0, P_NONE)
	for k in 3:
		var a := TAU * float(k) / 3.0
		b.ball(s.seal_pivot + Vector3(cos(a) * 0.5, 0.06 * float(k % 2), sin(a) * 0.5), Vector3.ONE * 0.11, ORB.lightened(0.4), ORB, 7, 4)


static func _deva_arms(b: K.Builder, s: Dictionary, limb: int, lite: bool) -> void:
	var hand_a := Vector3(0.31, 0.88, 0.27)
	var hand_b := Vector3(-0.2, 0.96, 0.2)
	for arm in [[UPPER_A, FORE_A, s.shoulder_a, s.elbow_a, hand_a], [UPPER_B, FORE_B, s.shoulder_b, s.elbow_b, hand_b]]:
		var sh: Vector3 = arm[2]
		var el: Vector3 = arm[3]
		var wr: Vector3 = arm[4]
		_part(b, arm[0])
		_look(b, 0.0, P_SKIN)
		_limb(b, sh, el, 0.046, 0.041, limb, SKIN, SKIN_DK, false)
		_look(b, 0.0, P_SILK)
		b.tube([sh + Vector3(0, 0.01, 0), sh.lerp(el, 0.5)], [0.075, 0.064], limb, [[SILK, SILK_DK]], Vector3.UP, false)
		_look(b, 0.2, P_GOLD)
		_ring(b, sh.lerp(el, 0.5), (el - sh).normalized(), 0.064, 0.012, 6, GOLD)
		_part(b, arm[1])
		_look(b, 0.0, P_SKIN)
		_limb(b, el, wr, 0.041, 0.034, limb, SKIN, SKIN_DK)
		_look(b, 0.25, P_GOLD)
		_ring(b, el.lerp(wr, 0.82), (wr - el).normalized(), 0.04, 0.011, 6, GOLD)
		_look(b, 0.0, P_SKIN)
		b.ball(wr + (wr - el).normalized() * 0.03, Vector3(0.042, 0.04, 0.046), SKIN, SKIN_DK, limb, 3)
	# จีบ: the fingers of the free hand bent back, thumb and forefinger touching.
	_part(b, FORE_B)
	var palm: Vector3 = hand_b + (hand_b - s.elbow_b).normalized() * 0.04
	for k in 3:
		var f := float(k) - 1.0
		b.cone(palm + Vector3(f * 0.018, 0.02, 0.0), palm + Vector3(f * 0.03 - 0.01, 0.085, -0.035), 0.012, 4, SKIN, SKIN_DK)
	b.ball(palm + Vector3(0.03, 0.01, 0.03), Vector3.ONE * 0.016, SKIN, SKIN_DK, 4, 2)
	# The lantern pole: curved gold, a flame finial at the top.
	_part(b, FORE_A)
	_look(b, 0.3, P_GOLD)
	var pole := [hand_a + Vector3(-0.01, -0.16, -0.03), hand_a + Vector3(0, 0.0, 0.0), Vector3(0.33, 1.14, 0.32), Vector3(0.39, 1.36, 0.37), Vector3(0.46, 1.43, 0.405), Vector3(0.49, 1.4, 0.41)]
	b.tube(Array(K.smooth(pole, 1 if lite else 2)), [0.016], 4, [GOLD], Vector3.UP, false)
	b.ball(pole[0], Vector3.ONE * 0.024, GOLD, GOLD_DK, 5, 3)
	b.ball(Vector3(0.45, 1.44, 0.405), Vector3.ONE * 0.022, GOLD, GOLD_DK, 5, 3)
	if not lite:
		_plate(b, _flame(0.05, 0.11, -0.2, -0.3, 6), 0.01, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.44, 1.445, 0.405)), GOLD)


static func _deva_head(b: K.Builder, s: Dictionary, seg: int, limb: int, lite: bool) -> void:
	var c: Vector3 = s.head
	var r := Vector3(0.27, 0.255, 0.25)
	_part(b, HEAD)
	_look(b, 0.0, P_SKIN)
	_ball_fn(b, c, r, 9 if lite else 12, 6 if lite else 9, func(d: Vector3) -> Color:
		var skin := SKIN_DK.lerp(SKIN, clampf(d.y * 0.5 + 0.7, 0.0, 1.0))
		return skin.lerp(HAIR, (1.0 - smoothstep(-0.05, 0.18, d.z)) * smoothstep(-0.75, -0.45, d.y)))
	# Ears with gold drops.
	for side in [-1.0, 1.0]:
		b.ball(c + Vector3(side * 0.262, -0.02, -0.01), Vector3(0.03, 0.058, 0.04), SKIN, SKIN_DK, 5, 3)
	_look(b, 0.4, P_GOLD)
	for side in [-1.0, 1.0]:
		b.ball(c + Vector3(side * 0.27, -0.1, 0.0), Vector3(0.018, 0.026, 0.018), GOLD, GOLD_DK, 5, 3)
	# The face: big round eyes with a light in each, fine
	# brows, a rosy blush, a small smile.
	_look(b, 0.0, P_NONE)
	for side in [-1.0, 1.0]:
		var eye := _on(c, r, Vector3(side * 0.36, -0.03, 0.93), -0.006)
		b.ball(eye, Vector3(0.046, 0.06, 0.022), Color("3a2448"), INK, 5 if lite else 6, 3)
		_look(b, 1.0, P_NONE)
		b.ball(eye + Vector3(side * 0.012, 0.022, 0.018), Vector3(0.017, 0.019, 0.008), Color.WHITE, Color.WHITE, 5, 2)
		if not lite:
			b.ball(eye + Vector3(-side * 0.01, -0.022, 0.016), Vector3(0.008, 0.008, 0.005), Color("c7b6ff"), Color("c7b6ff"), 4, 2)
		_look(b, 0.0, P_NONE)
		_look(b, 0.0, P_NONE + NO_INK)
		var brow := []
		for k in 3:
			var u := float(k) / 2.0
			brow.append(_on(c, r, Vector3(side * lerpf(0.18, 0.56, u), 0.48 + 0.05 * sin(u * PI) - 0.1 * u, 0.86 - 0.2 * u), 0.004))
		b.tube(brow, [0.007, 0.008, 0.004], 4, [Color("5a3a40")], Vector3.UP, false)
		_look(b, 0.35, P_NONE)
		b.ball(_on(c, r, Vector3(side * 0.56, -0.3, 0.77), -0.004), Vector3(0.048, 0.024, 0.014), Color("ffb2c2"), Color("ff9db2"), 5 if lite else 6, 2)
		_look(b, 0.0, P_NONE)
	var smile := []
	for k in 4:
		var u := float(k) / 3.0
		smile.append(_on(c, r, Vector3(lerpf(-0.12, 0.12, u), -0.44 - 0.05 * sin(u * PI), 0.9), 0.002))
	b.tube(smile, [0.006, 0.008, 0.008, 0.006], 4, [Color("c4404e")], Vector3.UP, false)
	_look(b, 0.0, P_SKIN)
	b.ball(_on(c, r, Vector3(0, -0.2, 1.0), -0.006), Vector3(0.016, 0.013, 0.012), SKIN, SKIN_DK, 4, 2)
	# The ชฎา: the brow band, the cap, the tiered spire with its lotus bud and needle.
	_look(b, 0.12, P_GOLD)
	_lathe(b, Vector3(0, 0, 0.015), [[0.255, 1.47, GOLD_DK], [0.268, 1.49, GOLD], [0.268, 1.55, GOLD], [0.25, 1.575, GOLD_DK]], seg, 0.93)
	_lathe(b, Vector3(0, 0, 0.01), [[0.25, 1.57, GOLD], [0.236, 1.62, GOLD], [0.196, 1.67, GOLD], [0.146, 1.7, GOLD_DK]], seg, 0.95)
	_lathe(b, Vector3(0, 0, 0.0), _spire(1.7, 0.145, 1.97, 2 if lite else 3, 2.14), 6 if lite else 8)
	# The กระบังหน้า: the band's pointed front plate with its ruby, gems round the band.
	var peak := PackedVector2Array([Vector2(-0.1, -0.03), Vector2(-0.075, 0.04), Vector2(-0.035, 0.075), Vector2(0, 0.155), Vector2(0.035, 0.075), Vector2(0.075, 0.04), Vector2(0.1, -0.03)])
	_plate(b, peak, 0.014, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 1.505, 0.262)), GOLD)
	_look(b, 0.7, P_NONE)
	b.ball(Vector3(0, 1.535, 0.276), Vector3(0.024, 0.028, 0.014), RUBY.lightened(0.35), RUBY, 6, 3)
	for k in (4 if lite else 6):
		var a := lerpf(-1.6, 1.6, float(k) / float((4 if lite else 6) - 1))
		if absf(a) < 0.3:
			continue
		b.ball(Vector3(sin(a) * 0.272, 1.52, cos(a) * 0.272 * 0.93 + 0.015), Vector3.ONE * 0.016, JADE.lightened(0.3) if k % 2 == 0 else RUBY.lightened(0.3), JADE if k % 2 == 0 else RUBY, 4, 2)
	# The กรรเจียก: gold flames rising back from the ears.
	_look(b, 0.2, P_GOLD)
	for side in [-1.0, 1.0]:
		var basis := Basis(Vector3(0, 0, -1), Vector3(0, cos(0.25), -sin(0.25)), Vector3(side, 0, 0))
		_plate(b, _flame(0.11, 0.23, 0.18, 0.28, 5 if lite else 7), 0.014, Transform3D(basis, c + Vector3(side * 0.265, 0.03, -0.03)), GOLD)
	# The aureole: a ring of gold light behind the head, its rim tipped with กนก flames.
	_look(b, 0.85, P_NONE)
	var halo := c + Vector3(0, 0.08, -0.22)
	b.xf = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), halo)
	b.annulus(0.39, 0.43, 16 if lite else 24, GOLD, GOLD.lightened(0.3))
	b.xf = Transform3D.IDENTITY
	var tips := 8 if lite else 12
	for k in tips:
		var a := TAU * float(k) / float(tips)
		var d := Vector3(sin(a), cos(a), 0)
		var t := Vector3(cos(a), -sin(a), 0)
		b.tri3(halo + d * 0.425 - t * 0.04, halo + d * 0.425 + t * 0.04, halo + d * 0.52 + t * 0.03, GOLD, GOLD, GOLD.lightened(0.45))


static func _deva_lantern(b: K.Builder, s: Dictionary, seg: int, lite: bool) -> void:
	var hook: Vector3 = s.hook
	var at := Vector3(hook.x, 0, hook.z)
	seg = 7 if lite else 10
	_part(b, LANTERN)
	_look(b, 0.3, P_GOLD)
	b.tube([hook, hook + Vector3(0, -0.1, 0)], [0.008], 4, [GOLD], Vector3.BACK, false)
	var top := hook.y - 0.08
	_lathe(b, at, [[0.0, top + 0.01, GOLD], [0.04, top, GOLD], [0.11, top - 0.045, GOLD], [0.132, top - 0.07, GOLD_DK]], seg)
	# The paper body, ribbed in gold with a red band, alight from within.
	_look(b, 2.0, P_PAPER)
	_lathe(b, at, [[0.125, top - 0.065, PAPER], [0.158, top - 0.11, PAPER], [0.172, top - 0.19, PAPER], [0.158, top - 0.27, PAPER], [0.115, top - 0.315, PAPER]], seg)
	_look(b, 0.3, P_GOLD)
	var low := top - 0.31
	_lathe(b, at, [[0.12, low, GOLD_DK], [0.095, low - 0.02, GOLD], [0.045, low - 0.035, GOLD], [0.0, low - 0.04, GOLD]], seg)
	b.ball(Vector3(hook.x, low - 0.05, hook.z), Vector3.ONE * 0.02, GOLD, GOLD_DK, 5, 3)
	# Its tails: red and gold paper streamers fluttering below.
	_part(b, LANTERN, 1.0)
	_look(b, 0.3, P_NONE)
	var n := 3 if lite else 6
	for k in n:
		var a := TAU * float(k) / float(n) + 0.3
		var d := Vector3(sin(a), 0, cos(a))
		var root := Vector3(hook.x, low + 0.005, hook.z) + d * 0.09
		var col := LANTERN_RED if k % 2 == 0 else GOLD
		_strip(b, [root, root + d * 0.02 + Vector3(0, -0.1, 0), root + d * 0.035 + Vector3(0, -0.2, 0), root + d * 0.05 + Vector3(0, -0.28 - 0.03 * float(k % 2), 0)], [0.04, 0.04, 0.035, 0.02], d, col, col.darkened(0.15))


# ---------------------------------------------------------------------------
# พระฤๅษีนั่งเมฆ: the hermit sage on his cloud.
# ---------------------------------------------------------------------------
static func _hermit(b: K.Builder, lite: bool) -> void:
	var s: Dictionary = KINDS.hermit
	var seg := 8 if lite else 11
	var limb := 4 if lite else 6
	_cloud(b, s.cloud, 1.0, lite)
	# Sitting cross-legged in a tiger-skin wrap, the shins bare.
	_part(b, BODY)
	_look(b, 0.0, P_TIGER)
	b.ball(Vector3(0, 0.48, 0.04), Vector3(0.38, 0.13, 0.32), TIGER, TIGER_DK, seg, 5)
	for side in [-1.0, 1.0]:
		var knee := Vector3(side * 0.44, 0.45, 0.25)
		b.tube([Vector3(side * 0.14, 0.5, 0.02), knee], [0.13, 0.105], limb, [[TIGER, TIGER_DK]], Vector3.UP, false)
		b.ball(knee, Vector3(0.105, 0.1, 0.105), TIGER, TIGER_DK, limb, 4)
	_look(b, 0.0, P_SKIN)
	for leg in [[1.0, 0.0], [-1.0, 0.04]]:
		var side: float = leg[0]
		var up: float = leg[1]
		var shin := [Vector3(side * 0.42, 0.43 + up, 0.29), Vector3(side * 0.08, 0.43 + up, 0.39 - up), Vector3(-side * 0.16, 0.45 + up, 0.36 - up)]
		b.tube(shin, [0.08, 0.072, 0.062], limb, [[TAN, TAN_DK]], Vector3.UP, false)
		b.ball(shin[2] + Vector3(-side * 0.04, 0.0, -0.02), Vector3(0.075, 0.05, 0.06), TAN, TAN_DK, limb, 3)
	# The torso: an old man's soft chest and round belly.
	var ys := [0.52, 0.7, 0.88, 1.02, 1.1, 1.17]
	var xr := [0.25, 0.27, 0.25, 0.22, 0.17, 0.08]
	var zr := [0.2, 0.23, 0.2, 0.16, 0.12, 0.07]
	var path := []
	var radii := []
	for k in ys.size():
		path.append(Vector3(0, ys[k], 0.02 if k == 1 else 0.0))
		radii.append(Vector2(zr[k], xr[k]))
	b.tube(path, radii, seg, [[TAN, TAN_DK]], Vector3.UP, false)
	b.tube([Vector3(0, 1.1, 0), Vector3(0, 1.22, 0.005)], [0.075, 0.07], limb, [[TAN, TAN_DK]], Vector3.UP, false)
	# The tiger-skin sash over the left shoulder, down across to the right hip (an open
	# strip: no ink).
	_look(b, 0.0, P_TIGER + NO_INK)
	var band := []
	var n := 14 if lite else 18
	for k in n + 1:
		var a := TAU * float(k) / float(n)
		var y := 0.84 - 0.25 * cos(a)
		var rx := _interp(ys, xr, y) + 0.025
		var rz := _interp(ys, zr, y) + 0.025
		band.append([Vector3(cos(a) * rx, y, sin(a) * rz), Vector3(cos(a) / rx, 0, sin(a) / rz).normalized()])
	var prev := []
	for k in band.size():
		var p: Vector3 = band[k][0]
		var nrm: Vector3 = band[k][1]
		var t: Vector3 = (band[(k + 1) % n][0] as Vector3) - (band[(k - 1 + n) % n][0] as Vector3)
		var w := nrm.cross(t).normalized() * 0.075
		var ring := [b.pt(p - w, nrm, TIGER), b.pt(p + nrm * 0.012, nrm, TIGER), b.pt(p + w, nrm, TIGER_DK)]
		if not prev.is_empty():
			b.tri(prev[0], prev[1], ring[1]); b.tri(prev[0], ring[1], ring[0])
			b.tri(prev[1], prev[2], ring[2]); b.tri(prev[1], ring[2], ring[1])
		prev = ring
	# Prayer beads round the neck, a gold amulet at the bottom.
	_look(b, 0.0, P_NONE)
	var beads := 8 if lite else 11
	for k in beads:
		var a := TAU * float(k) / float(beads)
		var front := maxf(0.0, cos(a))
		b.ball(Vector3(sin(a) * 0.2, 1.09 - 0.14 * front * front, cos(a) * 0.17 + 0.01 + 0.035 * front), Vector3.ONE * 0.03, BEAD.lightened(0.25), BEAD, 5, 2)
	_look(b, 0.4, P_GOLD)
	b.ball(Vector3(0, 0.91, 0.23), Vector3(0.04, 0.05, 0.025), GOLD, GOLD_DK, 6, 3)
	_hermit_arms(b, s, limb, lite)
	_hermit_head(b, s, seg, limb, lite)
	_hermit_seal(b, s, lite)


static func _interp(ys: Array, vals: Array, y: float) -> float:
	if y <= float(ys[0]):
		return float(vals[0])
	for k in ys.size() - 1:
		if y <= float(ys[k + 1]):
			return lerpf(float(vals[k]), float(vals[k + 1]), (y - float(ys[k])) / (float(ys[k + 1]) - float(ys[k])))
	return float(vals[-1])


static func _hermit_arms(b: K.Builder, s: Dictionary, limb: int, lite: bool) -> void:
	var hand_a := Vector3(0.5, 0.92, 0.25)
	var hand_b := Vector3(-0.32, 1.0, 0.3)
	for arm in [[UPPER_A, FORE_A, s.shoulder_a, s.elbow_a, hand_a], [UPPER_B, FORE_B, s.shoulder_b, s.elbow_b, hand_b]]:
		var sh: Vector3 = arm[2]
		var el: Vector3 = arm[3]
		var wr: Vector3 = arm[4]
		_part(b, arm[0])
		_look(b, 0.0, P_SKIN)
		_limb(b, sh, el, 0.074, 0.062, limb, TAN, TAN_DK, false)
		_part(b, arm[1])
		_limb(b, el, wr, 0.062, 0.05, limb, TAN, TAN_DK)
		_look(b, 0.0, P_NONE)
		_ring(b, el.lerp(wr, 0.8), (wr - el).normalized(), 0.054, 0.014, 8, BEAD)
		_look(b, 0.0, P_SKIN)
		b.ball(wr + (wr - el).normalized() * 0.035, Vector3(0.06, 0.058, 0.058), TAN, TAN_DK, limb, 3)
	# The blessing hand: fingers up, palm to the front, a string of beads hanging from it.
	_part(b, FORE_B)
	var palm: Vector3 = hand_b + (hand_b - s.elbow_b).normalized() * 0.05
	for k in 4:
		var f := float(k) - 1.5
		b.cone(palm + Vector3(f * 0.024, 0.04, 0.0), palm + Vector3(f * 0.03, 0.11 - 0.012 * absf(f), 0.01), 0.014, 4, TAN, TAN_DK)
	b.cone(palm + Vector3(0.04, 0.0, 0.01), palm + Vector3(0.09, 0.04, 0.02), 0.015, 4, TAN, TAN_DK)
	_look(b, 0.0, P_NONE)
	for k in (4 if lite else 7):
		var u := float(k) / 6.0
		b.ball(palm + Vector3(0.0 + 0.03 * sin(u * PI), -0.03 - 0.17 * sin(u * PI * 0.5), 0.02 + 0.02 * u), Vector3.ONE * 0.022, BEAD.lightened(0.25), BEAD, 4, 2)
	# The staff in the right hand: knotted wood, a gold band and a gold crook.
	_part(b, FORE_A)
	_look(b, 0.0, P_NONE)
	var staff := [Vector3(0.5, 0.16, 0.27), Vector3(0.5, 0.9, 0.255), Vector3(0.505, 1.5, 0.25), Vector3(0.5, 1.82, 0.25)]
	b.tube(staff, [0.024, 0.026, 0.025, 0.027], 6, [[WOOD, WOOD_DK]], Vector3.BACK, true)
	for y in ([0.6, 1.62] if lite else [0.55, 1.2, 1.62]):
		b.ball(Vector3(0.502, y, 0.252), Vector3(0.035, 0.03, 0.035), WOOD, WOOD_DK, 5, 3)
	_look(b, 0.35, P_GOLD)
	_ring(b, Vector3(0.5, 1.8, 0.25), Vector3.UP, 0.03, 0.012, 8, GOLD)
	var crook := [Vector3(0.5, 1.8, 0.25), Vector3(0.5, 1.92, 0.27), Vector3(0.49, 1.99, 0.35), Vector3(0.48, 1.96, 0.44), Vector3(0.485, 1.88, 0.45), Vector3(0.49, 1.85, 0.41)]
	var cr := Array(K.smooth(crook, 1 if lite else 2))
	var rr := []
	for k in cr.size():
		rr.append(lerpf(0.026, 0.012, float(k) / float(cr.size() - 1)))
	b.tube(cr, rr, 5, [GOLD], Vector3.UP, true)


static func _hermit_head(b: K.Builder, s: Dictionary, seg: int, limb: int, lite: bool) -> void:
	var c: Vector3 = s.head
	var r := Vector3(0.205, 0.215, 0.2)
	_part(b, HEAD)
	_look(b, 0.0, P_SKIN)
	_ball_fn(b, c, r, 11 if not lite else 8, 8 if not lite else 6, func(d: Vector3) -> Color:
		return TAN_DK.lerp(TAN, clampf(d.y * 0.5 + 0.65, 0.0, 1.0)))
	for side in [-1.0, 1.0]:
		b.ball(c + Vector3(side * 0.2, -0.03, -0.01), Vector3(0.035, 0.085, 0.05), TAN, TAN_DK, 5, 3)
	b.ball(_on(c, r, Vector3(0, -0.12, 1.0), 0.0), Vector3(0.045, 0.04, 0.042), TAN, TAN_DK, 6, 4)
	_look(b, 0.3, P_NONE)
	for side in [-1.0, 1.0]:
		b.ball(_on(c, r, Vector3(side * 0.55, -0.25, 0.78), -0.003), Vector3(0.04, 0.022, 0.012), Color("f0a07c"), Color("e88d6c"), 5, 3)
	# Eyes closed in meditation: two gentle arcs.
	_look(b, 0.0, P_NONE)
	for side in [-1.0, 1.0]:
		var arc := []
		for k in 4:
			var u := float(k) / 3.0
			arc.append(_on(c, r, Vector3(side * lerpf(0.14, 0.58, u), 0.14 - 0.06 * sin(u * PI), 0.95 - 0.25 * u), 0.006))
		b.tube(arc, [0.006, 0.009, 0.009, 0.005], 4, [Color("3a2216")], Vector3.UP, false)
	# Hair, brows, moustache and the long beard: soft white locks that flutter.
	_part(b, HEAD, 0.8)
	_look(b, 0.1, P_NONE)
	for side in [-1.0, 1.0]:
		for k in (1 if lite else 2):
			var f := float(k)
			var root := _on(c, r, Vector3(side * (0.2 + 0.18 * f), 0.36 - 0.06 * f, 0.92), 0.004)
			_lock(b, root, root + Vector3(side * (0.14 - 0.03 * f), -0.06 - 0.03 * f, -0.03), 0.07 - 0.015 * f, Vector3(0, 0.02, 0.01), Vector3(0, 0.3, 1).normalized(), BEARD, BEARD_DK, 2)
		var mroot := _on(c, r, Vector3(side * 0.12, -0.38, 0.93), 0.01)
		_lock(b, mroot, mroot + Vector3(side * 0.17, -0.1, -0.05), 0.075, Vector3(side * 0.01, -0.02, 0.02), Vector3(0, 0.2, 1).normalized(), BEARD, BEARD_DK, 3, 1.0)
		for k in (1 if lite else 2):
			var hroot := c + Vector3(side * (0.15 - 0.05 * float(k)), 0.08, -0.13 - 0.04 * float(k))
			_lock(b, hroot, hroot + Vector3(side * 0.05, -0.38, -0.08), 0.1, Vector3(side * 0.03, 0, -0.04), Vector3(side * 0.5, 0, -1).normalized(), BEARD, BEARD_DK, 3, float(k))
	var beard := 4 if lite else 6
	for k in beard:
		var f := float(k) / float(beard - 1) - 0.5
		var root := _on(c, r, Vector3(f * 0.9, -0.62, 0.78), -0.01)
		var tip := Vector3(f * 0.3, 0.72 + absf(f) * 0.18, 0.3 + 0.03 * (1.0 - absf(f)))
		_lock(b, root, tip, 0.12, Vector3(f * 0.05, 0.0, 0.07), Vector3(f * 0.6, 0.15, 1).normalized(), BEARD, BEARD_DK, 3 if lite else 4, f * 2.0)
	# The tall pointed ฤๅษี hat in tiger skin, banded in gold, the tip bent back.
	_part(b, HEAD)
	_look(b, 0.15, P_GOLD)
	_lathe(b, Vector3(0, 0, 0.01), [[0.198, 1.44, GOLD_DK], [0.214, 1.46, GOLD], [0.214, 1.505, GOLD], [0.2, 1.53, GOLD_DK]], seg)
	_look(b, 0.0, P_TIGER)
	var hat := Array(K.smooth([Vector3(0, 1.5, 0.01), Vector3(0, 1.74, -0.0), Vector3(0, 1.98, -0.04), Vector3(0, 2.18, -0.11), Vector3(0, 2.3, -0.2)], 1 if lite else 2))
	var hr := []
	for k in hat.size():
		var u := float(k) / float(hat.size() - 1)
		hr.append(lerpf(0.2, 0.012, pow(u, 0.85)))
	b.tube(hat, hr, seg - 1, [[TIGER, TIGER_DK]], Vector3.BACK, false)
	_look(b, 0.4, P_GOLD)
	b.ball(Vector3(0, 2.3, -0.2), Vector3.ONE * 0.03, GOLD, GOLD_DK, 5, 3)
	# A lotus petal of gold on the front of the band.
	_plate(b, _flame(0.09, 0.13, 0.0, 0.0, 6), 0.012, Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, 1.48, 0.218)), GOLD)


## The ยันต์ seal: rings, a square, flame spikes and the อุณาโลม at the heart, in light.
static func _hermit_seal(b: K.Builder, s: Dictionary, lite: bool) -> void:
	var c: Vector3 = s.seal_pivot
	_part(b, CHARGE)
	_look(b, 2.0, P_NONE)
	b.xf = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c)
	b.annulus(0.44, 0.48, 16 if lite else 24, SEAL, SEAL.lightened(0.3))
	b.annulus(0.29, 0.31, 12 if lite else 18, SEAL.lightened(0.3), SEAL)
	b.xf = Transform3D.IDENTITY
	var spikes := 8
	for k in spikes:
		var a := TAU * float(k) / float(spikes)
		var d := Vector3(sin(a), cos(a), 0)
		var t := Vector3(cos(a), -sin(a), 0)
		b.tri3(c + d * 0.47 - t * 0.06, c + d * 0.47 + t * 0.06, c + d * 0.62 + t * 0.03, SEAL, SEAL, SEAL.lightened(0.5))
		# The square's sides, corner to corner on the inner ring.
		var a2 := a + TAU / 8.0 * 2.0
		if k % 2 == 0:
			var p := c + Vector3(sin(a + PI * 0.25), cos(a + PI * 0.25), 0) * 0.3
			var q := c + Vector3(sin(a2 + PI * 0.25), cos(a2 + PI * 0.25), 0) * 0.3
			var w := (q - p).cross(Vector3.BACK).normalized() * 0.011
			b.quad(p - w, q - w, q + w, p + w, SEAL)
		if not lite:
			b.ball(c + d * 0.375, Vector3(0.022, 0.022, 0.01), SEAL.lightened(0.4), SEAL, 4, 2)
	# The อุณาโลม: a spiral and its stroke rising to a point.
	var spiral := []
	for k in (8 if lite else 12):
		var u := float(k) / float((8 if lite else 12) - 1)
		var a := u * TAU * 1.25
		spiral.append(c + Vector3(sin(a), -cos(a), 0) * lerpf(0.02, 0.09, u) + Vector3(0, -0.05, 0))
	spiral.append(c + Vector3(0.09, 0.05, 0))
	spiral.append(c + Vector3(0.0, 0.2, 0))
	b.tube(spiral, [0.016, 0.016, 0.018, 0.016, 0.01], 4, [SEAL.lightened(0.3)], Vector3.BACK, false)
