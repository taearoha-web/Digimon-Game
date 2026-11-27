class_name HeavenNaga
extends RefCounted
## พญานาคทองเทวาลัย (HeavenMonsters celestial_naga): the golden seven-headed naga of the
## celestial temple's stair (นาคเจ็ดเศียร), sculpted in code like the isle's eastern dragons
## (CelestialDragon): one long gold body in overlapping scales with a cream belly of plates
## and a saw of flame fins (ครีบกนก) down the spine, coiled on a bank of cloud and rising
## like a cobra into a hood of seven necks webbed together, each crowned head with an
## upturned snout (จมูกงอน), staring emerald eyes, fangs, a flame crest (หงอน) and flame
## frills (เครา) sweeping back from the jaw; the tallest, middle head wears a tiered gold
## crown (มงกุฎ).
##
## One mesh (vertex colours, built once; five heads and fewer sides at quality 0) and one
## shader (shaders/heaven_naga.gdshader). Every vertex says what it is (CUSTOM1.w): the body
## (0, laid along the coil's spline by its distance from the neck, VERTEX.z), the clouds (2,
## drifting where they are), the hood and its webs (9) and head i (10 + i), carried by the
## neck's end; each head sways round the foot of its neck (CUSTOM1.xyz) by its own weight
## (CUSTOM0.w), its jaw (COLOR.a 0) drops round its hinge (CUSTOM0.xyz). HeavenNagaVisual
## tweens a few scalars: the ripple, the neck's lean and reach, the gape, the mouths'
## light, the hit flash and the gold dissolve.
##
## Mesh metres: +Z is the front, the clouds sit on y = 0, the crown's tip at FIGURE_H.

const K := preload("res://combat/god_art/_kit_arcane.gd")
const SHADER := preload("res://shaders/heaven_naga.gdshader")
const MAX_PTS := 72

const GOLD := Color("ffd04a")
const GOLD_DK := Color("c47a18")
const GOLD_LT := Color("fff0a8")
const BELLY := Color("fff2c6")
const BELLY_DK := Color("efc266")
const FIN := Color("ff8a2e")
const FIN_TIP := Color("ffe9a0")
const CREST := Color("ff5232")
const EYE := Color("5affc8")
const MOUTH := Color("c8203e")
const IVORY := Color("fffbea")
const CLOUD := Color("ffffff")
const CLOUD_DK := Color("d6e6f2")
const GEM := Color("ff3a58")

## Parts (CUSTOM1.w).
const BODY := 0
const CLOUDS := 2
const HOOD := 9
const HEAD := 10
## The body: metres from the neck's top (s = 0) to the tail's tip.
const LENGTH := 11.0
## The hood frame's origin (the neck's top, at rest) and the heads: angle across the fan
## (radians), size, how high and far out the neck ends. The middle one is the king head.
const HEADS := [
	{"a": 0.0, "size": 0.5, "up": 1.0, "out": 0.0},
	{"a": 0.42, "size": 0.41, "up": 0.84, "out": 0.5},
	{"a": -0.42, "size": 0.41, "up": 0.84, "out": 0.5},
	{"a": 0.84, "size": 0.37, "up": 0.66, "out": 0.86},
	{"a": -0.84, "size": 0.37, "up": 0.66, "out": 0.86},
	{"a": 1.22, "size": 0.33, "up": 0.46, "out": 1.1},
	{"a": -1.22, "size": 0.33, "up": 0.46, "out": 1.1},
]
## The rest figure's height (the clouds' foot to the king head's crown tip) and its bounds
## (room above for the rear and the rise, round it for the strike and the sway).
const FIGURE_H := 5.0
const BOX := AABB(Vector3(-2.6, 0.0, -2.4), Vector3(5.2, 5.5, 5.2))

static var _meshes := {}
static var _pose := {}
static var _base: ShaderMaterial


static func has(kind: String) -> bool:
	return kind == "gold"


static func head_count() -> int:
	return 5 if VfxBudget.quality() == 0 else 7


## The shared mesh (a lighter one at quality 0).
static func mesh() -> ArrayMesh:
	var lite := VfxBudget.quality() == 0
	if not _meshes.has(lite):
		var built := _build(lite)
		built.custom_aabb = BOX
		_meshes[lite] = built
	return _meshes[lite]


## The coil's spline (the shader's "pts", "count", "spacing", "head"): from the tail's end
## round a cloud-borne coil, then up like a cobra to the neck's top (the hood's foot).
static func pose() -> Dictionary:
	if not _pose.is_empty():
		return _pose
	var ctrl := []
	var n := 16
	for i in n + 1:
		var f := float(i) / float(n)
		var a := lerpf(PI * 0.5 - TAU * 1.12, PI * 0.5 - 0.32, f)
		var r := lerpf(1.62, 1.2, f)
		ctrl.append(Vector3(cos(a) * r, lerpf(0.62, 0.88, f) + 0.08 * sin(f * TAU * 2.0), -0.5 + sin(a) * r))
	ctrl.append_array([Vector3(0.3, 1.3, 0.8), Vector3(0.06, 1.95, 0.62), Vector3(0.0, 2.45, 0.48), Vector3(0.0, 2.72, 0.44)])
	var line := K.smooth(ctrl, 8)
	var total := 0.0
	for i in range(1, line.size()):
		total += line[i].distance_to(line[i - 1])
	var spacing := maxf(0.15, total / float(MAX_PTS - 2))
	var points := K.resample(line, spacing)
	if points.size() > MAX_PTS:
		points.resize(MAX_PTS)
	var count := points.size()
	var pts := PackedVector3Array()
	pts.resize(MAX_PTS)
	for i in MAX_PTS:
		pts[i] = points[mini(i, count - 1)]
	_pose = {"pts": pts, "count": count, "spacing": spacing, "head": float(count - 1) * spacing, "neck": points[count - 1], "length": total}
	return _pose


## A fresh material for one naga.
static func material() -> ShaderMaterial:
	if _base == null:
		var p := pose()
		_base = ShaderMaterial.new()
		_base.shader = SHADER
		_base.set_shader_parameter("pts", p.pts)
		_base.set_shader_parameter("count", p.count)
		_base.set_shader_parameter("spacing", p.spacing)
		_base.set_shader_parameter("head", p.head)
		_base.set_shader_parameter("neck", p.neck)
	return _base.duplicate() as ShaderMaterial


## A naga ready to place: the body at mesh scale (scale it yourself), its own material.
static func body() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "NagaBody"
	mi.mesh = mesh()
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0
	return mi


## Where the neck's top is at rest (the hood frame's origin), mesh metres.
static func neck() -> Vector3:
	return pose().neck


## Where the king head's snout is at rest, mesh metres.
static func nose() -> Vector3:
	var h: Dictionary = HEADS[0]
	return neck() + _head_at(h) + Vector3(0, 0.1, 1.1) * float(h.size)


static func triangles(m: ArrayMesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
	return n


# ---------------------------------------------------------------------------
# The mesh.
# ---------------------------------------------------------------------------

static func _part(b: K.Builder, part: int, pivot := Vector3.ZERO, hinge := Vector3.ZERO, sway := 0.0) -> void:
	b.customs = true
	b.pivot = pivot
	b.tumble = float(part)
	b.vel = hinge
	b.wait = sway


static func _girth(s: float) -> float:
	var f := s / LENGTH
	return 0.27 + 0.08 * smoothstep(0.0, 0.25, f) - 0.06 * smoothstep(0.35, 0.8, f) - 0.26 * smoothstep(0.72, 1.0, f)


static func _build(lite: bool) -> ArrayMesh:
	var b := K.Builder.new()
	_body(b, lite)
	_clouds(b, lite)
	_hood(b, lite)
	return b.mesh()


## The body along +Z (z = metres from the neck's top): gold scales over a cream belly of
## plates (UV2.y 1: the shader draws them), flame fins down the spine, a flame tuft at the tail.
static func _body(b: K.Builder, lite: bool) -> void:
	_part(b, BODY)
	var sides := 8 if lite else 11
	var path := []
	var radii := []
	var cols := []
	var s := -0.35
	var step := 0.34 if lite else 0.24
	while s <= LENGTH:
		path.append(Vector3(0, 0, s))
		radii.append(_girth(maxf(s, 0.0)))
		var f := clampf(s / LENGTH, 0.0, 1.0)
		cols.append([GOLD.lerp(GOLD_DK, 0.25 * f), BELLY.lerp(BELLY_DK, 0.4 * f)])
		s += step
	b.weight = 1.0
	b.tube(path, radii, sides, cols)
	b.weight = 0.0
	# ครีบกนก: flame fins down the spine, gold into a vermilion tip, curling back.
	s = 0.5
	var gap := 0.62 if lite else 0.42
	while s < LENGTH - 0.6:
		var r := _girth(s)
		var tall := (0.34 - 0.18 * s / LENGTH) * (0.6 + r * 1.4)
		_flame(b, Vector3(0, r * 0.86, s), Vector3(0, 1, 0.55).normalized(), Vector3(0, 0, 1), tall * 0.55, tall, 0.35, FIN, FIN_TIP, 3)
		s += gap
	# The tail's flame tuft.
	b.emit = 0.3
	for k in 3:
		var a := float(k - 1) * 0.55
		_flame(b, Vector3(0, 0.02, LENGTH - 0.25), Vector3(sin(a) * 0.6, cos(a) * 0.4 + 0.3, 1).normalized(), Vector3(cos(a), -sin(a), 0), 0.22, 0.75, 0.3, FIN, FIN_TIP, 4)
	b.emit = 0.0


## A kanok flame: a ribbon from [param base] along [param up] (its curl toward
## [param back]), [param width] wide at the root, tapering to a curled point; root colour
## to tip colour (one-sided: the shader draws both faces).
static func _flame(b: K.Builder, base: Vector3, up: Vector3, back: Vector3, width: float, tall: float, curl: float, root: Color, tip: Color, segs := 4) -> void:
	var side := up.cross(back).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var bend := (back - up * back.dot(up)).normalized()
	var prev := []
	for k in segs + 1:
		var t := float(k) / float(segs)
		var spine := base + up * tall * t + bend * tall * curl * t * t
		var half := width * 0.5 * pow(1.0 - t, 0.8) * (0.7 + 0.5 * sin(PI * minf(t * 1.4, 1.0)))
		var col := root.lerp(tip, smoothstep(0.2, 1.0, t))
		var ring := [b.pt(spine - side * half, bend, col), b.pt(spine + side * half, bend, col)]
		if not prev.is_empty():
			b.tri(prev[0], prev[1], ring[1])
			b.tri(prev[0], ring[1], ring[0])
		prev = ring


## The bank of cloud the coil rests on: soft domes, white over a cool shade, rimmed in gold
## where they meet the coil (UV2.y -2: the shader lights them as vapour).
static func _clouds(b: K.Builder, lite: bool) -> void:
	_part(b, CLOUDS)
	b.weight = -2.0
	var n := 5 if lite else 8
	for i in n:
		var a := TAU * float(i) / float(n) + 0.3
		var r := 1.35 + 0.25 * float(i % 2)
		var c := Vector3(cos(a) * r, 0.18, -0.5 + sin(a) * r)
		var size := Vector3(0.78, 0.42, 0.66) * (1.0 + 0.18 * float((i * 7) % 3 - 1))
		_puff(b, c, size, 8 if lite else 11, 3)
	_puff(b, Vector3(0, 0.12, -0.5), Vector3(1.2, 0.34, 1.1), 10 if lite else 14, 3)
	b.weight = 0.0


static func _puff(b: K.Builder, c: Vector3, r: Vector3, lon: int, lat: int) -> void:
	var base := b.v.size()
	var rows := lat + 1
	for i in rows + 1:
		var th := PI * 0.62 * float(mini(i, rows - 1)) / float(rows - 1)
		var inside := i < rows
		for j in lon + 1:
			var ph := TAU * float(j) / float(lon)
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) if inside else Vector3(0, -0.3, 0)
			var col := CLOUD_DK.lerp(CLOUD, clampf(d.y * 0.9 + 0.45, 0.0, 1.0))
			if i == rows - 1:
				col = GOLD.lerp(CLOUD, 0.45)
			b.pt(c + d * r, (d / r).normalized() if inside else Vector3.DOWN, col)
	for i in rows:
		for j in lon:
			var a := base + i * (lon + 1) + j
			var d := a + lon + 1
			if i == 0:
				b.tri(a, d + 1, d)
			else:
				b.tri(a, a + 1, d + 1); b.tri(a, d + 1, d)


## Where head [param h]'s neck ends (its skull's centre), in the hood frame.
static func _head_at(h: Dictionary) -> Vector3:
	var a := float(h.a)
	return Vector3(sin(a) * (0.4 + 0.82 * float(h.out)), 0.46 + 0.92 * float(h.up), 0.12 - 0.14 * float(h.out))


## The hood: seven necks fanning out of the neck's top (the hood frame: origin there, +Y
## up, +Z forward), webbed together by a hood of scales over cream plates, a crowned
## head on each.
static func _hood(b: K.Builder, lite: bool) -> void:
	var heads := []
	for i in HEADS.size():
		if lite and i >= 5:
			continue
		heads.append(i)
	var sides := 6 if lite else 8
	var feet := {}
	var tops := {}
	for i in heads:
		var h: Dictionary = HEADS[i]
		var a := float(h.a)
		var foot := Vector3(sin(a) * 0.12, 0.06, 0.0)
		var top := _head_at(h)
		feet[i] = foot
		tops[i] = top
		# The neck: out of the hood's foot, up and over to the skull (it sways from its foot).
		_part(b, HEAD + i, foot, Vector3.ZERO, 0.0)
		var mid := foot.lerp(top, 0.5) + Vector3(sin(a) * 0.12, 0.08, -0.08)
		var pts := [foot + Vector3(0, -0.25, 0), foot, mid, top + Vector3(0, -0.05, -0.12) * float(h.size) * 3.0]
		var path := Array(K.smooth(pts, 2))
		var rr := []
		var cc := []
		for k in path.size():
			var u := float(k) / float(path.size() - 1)
			rr.append(Vector2(lerpf(0.2, float(h.size) * 0.5, u), lerpf(0.17, float(h.size) * 0.46, u)))
			cc.append([GOLD, BELLY])
		_sway_tube(b, path, rr, sides, cc, foot, top, i)
	# The web between neighbours: a hood of scales, cream plates in front.
	var order := heads.duplicate()
	order.sort_custom(func(x, y): return float(HEADS[x].a) < float(HEADS[y].a))
	_part(b, HOOD)
	b.weight = 0.7
	for k in order.size() - 1:
		var i: int = order[k]
		var j: int = order[k + 1]
		var rows := 3
		var base := b.v.size()
		for r in rows + 1:
			var f := float(r) / float(rows)
			var lip := 0.72 - 0.08 * sin(f * PI)
			var pa: Vector3 = (feet[i] as Vector3).lerp(tops[i], f * lip)
			var pb: Vector3 = (feet[j] as Vector3).lerp(tops[j], f * lip)
			var back := Vector3(0, 0, -0.06 - 0.04 * sin(f * PI))
			b.pt(pa + back, Vector3(0, 0.2, 1).normalized(), GOLD.lerp(GOLD_DK, 0.3), Vector2(f * 1.5, 0.0))
			b.pt((pa + pb) * 0.5 + back + Vector3(0, -0.03, -0.05), Vector3(0, 0.2, 1).normalized(), GOLD, Vector2(f * 1.5, 0.5))
			b.pt(pb + back, Vector3(0, 0.2, 1).normalized(), GOLD.lerp(GOLD_DK, 0.3), Vector2(f * 1.5, 1.0))
		for r in rows:
			for c in 2:
				var q := base + r * 3 + c
				b.tri(q, q + 1, q + 4); b.tri(q, q + 4, q + 3)
	b.weight = 0.0
	# A collar of gold where the necks part, a red jewel in front.
	_part(b, HOOD)
	b.emit = 0.25
	b.tube([Vector3(-0.3, 0.06, 0.12), Vector3(0, 0.0, 0.3), Vector3(0.3, 0.06, 0.12)], [0.06], 5, [GOLD_LT], Vector3.UP, false)
	b.emit = 1.0
	b.ball(Vector3(0, 0.02, 0.34), Vector3(0.08, 0.1, 0.06), Color.WHITE, GEM, 6, 4)
	b.emit = 0.0
	for i in heads:
		_head(b, i, HEADS[i], tops[i], feet[i], lite)


## A neck tube whose rings carry more of its head's sway toward the skull.
static func _sway_tube(b: K.Builder, path: Array, radii: Array, sides: int, cols: Array, foot: Vector3, top: Vector3, i: int) -> void:
	var start := b.v.size()
	b.weight = 0.8
	b.tube(path, radii, sides, cols, Vector3.BACK, false)
	b.weight = 0.0
	var span := maxf(foot.distance_to(top), 0.01)
	for k in range(start, b.v.size()):
		var w := clampf((b.v[k] - foot).dot((top - foot) / span) / span, 0.0, 1.0)
		b.c0[k * 4 + 3] = w * w
	_part(b, HEAD + i, foot, Vector3.ZERO, 1.0)


## One head in its own frame (+Z the snout, +Y over the brow) at [param at] in the hood
## frame, [param h.size] metres to a unit: skull and upturned snout, the jaw (COLOR.a 0,
## dropping round its hinge), fangs, emerald eyes under gold brows, the flame crest (the
## king head: a tiered crown) and flame frills sweeping back from the jaw.
static func _head(b: K.Builder, i: int, h: Dictionary, at: Vector3, foot: Vector3, lite: bool) -> void:
	var size := float(h.size)
	var a := float(h.a)
	var yaw := a * 0.35
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.12) * Basis().scaled(Vector3.ONE * size)
	var hinge := at + Basis(Vector3.UP, yaw) * Vector3(0, -0.12, -0.1) * size
	_part(b, HEAD + i, foot, hinge, 1.0)
	b.xf = Transform3D(basis, at)
	var sides := 6 if lite else 8
	b.weight = 0.6
	b.tube([Vector3(0, 0.08, -0.62), Vector3(0, 0.12, -0.2), Vector3(0, 0.06, 0.3), Vector3(0, 0.02, 0.72), Vector3(0, 0.1, 1.0), Vector3(0, 0.3, 1.14), Vector3(0, 0.46, 1.06)],
		[Vector2(0.42, 0.4), Vector2(0.56, 0.5), Vector2(0.44, 0.34), Vector2(0.32, 0.22), Vector2(0.22, 0.16), Vector2(0.12, 0.1), Vector2(0.03, 0.03)], sides,
		[[GOLD, BELLY], [GOLD, BELLY], [GOLD, BELLY], [GOLD, BELLY], [GOLD_LT, BELLY], [GOLD_LT, GOLD_LT], [GOLD_LT, GOLD_LT]])
	b.weight = 0.0
	# The jaw, open a little at rest (the shader drops it further), its inside alight.
	var jaw := Color(BELLY, 0.0)
	var jaw_dk := Color(BELLY_DK, 0.0)
	b.tube([Vector3(0, -0.2, -0.3), Vector3(0, -0.3, 0.2), Vector3(0, -0.3, 0.6), Vector3(0, -0.2, 0.92)],
		[Vector2(0.36, 0.1), Vector2(0.36, 0.12), Vector2(0.27, 0.1), Vector2(0.16, 0.07)], 5 if lite else 6, [[jaw, jaw_dk]])
	b.emit = 2.0
	b.quad(Vector3(-0.3, -0.16, -0.1), Vector3(0.3, -0.16, -0.1), Vector3(0.2, -0.18, 0.9), Vector3(-0.2, -0.18, 0.9), Color(MOUTH, 0.0), Color(MOUTH.darkened(0.4), 0.0))
	b.emit = 0.0
	for side in [-1.0, 1.0]:
		b.cone(Vector3(side * 0.16, -0.04, 0.78), Vector3(side * 0.15, -0.3, 0.8), 0.06, 4, IVORY)
		b.cone(Vector3(side * 0.12, -0.24, 0.64), Vector3(side * 0.11, -0.06, 0.66), 0.05, 4, Color(IVORY, 0.0))
		# Gold brow ridge over the lit eye, the eye with a slit pupil.
		b.emit = 0.3
		b.tube([Vector3(side * 0.16, 0.42, 0.32), Vector3(side * 0.36, 0.48, 0.06), Vector3(side * 0.44, 0.42, -0.24)], [0.07, 0.09, 0.03], 4, [[GOLD_LT, GOLD_DK]])
		b.emit = 1.0
		b.ball(Vector3(side * 0.32, 0.27, 0.12), Vector3(0.12, 0.12, 0.15), Color("f4fff8"), EYE, 5 if lite else 6, 4)
		b.emit = 0.0
		b.ball(Vector3(side * 0.43, 0.27, 0.12), Vector3(0.025, 0.09, 0.06), Color("0e2420"), Color("0e2420"), 4, 2)
		# เครา: flame frills sweeping back from the jaw's corner.
		b.emit = 0.2
		for k in (1 if lite else 2):
			var dn := float(k) * 0.28
			_flame(b, Vector3(side * 0.34, -0.1 - dn, -0.12), Vector3(side * 0.85, -0.25 - dn, -0.5).normalized(), Vector3(0, 0.3, -1), 0.3, 0.85 - 0.2 * k, 0.4, GOLD, FIN, 3)
		b.emit = 0.0
	if i == 0:
		_crown(b, lite)
	else:
		# หงอน: the flame crest standing up from the brow and curling back.
		b.emit = 0.25
		for k in (2 if lite else 3):
			var z := 0.2 - 0.32 * float(k)
			_flame(b, Vector3(0, 0.46 - 0.04 * k, z), Vector3(0, 1, -0.35 - 0.2 * k).normalized(), Vector3(0, 0, -1), 0.34, 0.95 - 0.18 * k, 0.5, CREST, FIN_TIP, 4)
		b.emit = 0.0
	b.xf = Transform3D.IDENTITY


## The king head's crown: a jewelled band, tiers of gold rings to a fine spire, flame
## leaves at its foot.
static func _crown(b: K.Builder, lite: bool) -> void:
	b.emit = 0.3
	var prof := [[0.38, 0.38], [0.4, 0.48], [0.34, 0.56]]
	var tiers := 3 if lite else 5
	for k in tiers:
		var t := float(k) / float(tiers)
		var y := 0.56 + 0.17 * float(k)
		var r := 0.32 * (1.0 - 0.7 * t)
		prof.append([r * 1.12, y + 0.06])
		prof.append([r * 0.86, y + 0.17])
	prof.append([0.04, 0.56 + 0.17 * tiers + 0.1])
	prof.append([0.0, 0.56 + 0.17 * tiers + 0.45])
	var rows := []
	for pr in prof:
		rows.append([float(pr[0]), float(pr[1]), GOLD if rows.size() % 2 == 0 else GOLD_LT])
	var keep := b.xf
	b.xf = keep * Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, 0, -0.05))
	b.lathe(rows, 6 if lite else 10)
	b.emit = 1.0
	b.ball(Vector3(0, 0.46, 0.4), Vector3(0.09, 0.1, 0.06), Color.WHITE, GEM, 5, 3)
	b.emit = 0.3
	for k in 5:
		var a := float(k - 2) * 0.55
		_flame(b, Vector3(sin(a) * 0.36, 0.5, cos(a) * 0.3), Vector3(sin(a) * 0.5, 1, cos(a) * 0.2).normalized(), Vector3(0, 0, -1), 0.24, 0.42, 0.25, GOLD, GOLD_LT, 3)
	b.emit = 0.0
	b.xf = keep
