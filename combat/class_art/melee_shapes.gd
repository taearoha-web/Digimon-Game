class_name MeleeShapes
extends RefCounted
## Unit geometry for the Warrior / Lancer / Defender class layers (MeleeArt).
## Built once per kind and shared by every cast. The UV / COLOR conventions are
## the ones shaders/melee_art.gdshader reads (see its header):
##   flat ground pieces lie in XZ at y = 0, silhouettes lie in XY pointing +X,
##   upright pieces stand on y = 0, rings and arcs turn around +Y.

const KINDS := "arc150 arc220 arc330 streak ring cracks cracks_b cross light_cross hexplate hexwall hexdome aura spiral spear blade dragon banner chain rock spark shard sigil runes"
static var _meshes: Dictionary = {}


static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"arc150": _arc(st, deg_to_rad(150.0))
		"arc220": _arc(st, deg_to_rad(220.0))
		"arc330": _arc(st, deg_to_rad(330.0))
		"streak": _streak(st)
		"ring": _ring(st)
		"cracks": _cracks(st, 31, 7)
		"cracks_b": _cracks(st, 77, 9)
		"cross": _ground_cross(st)
		"light_cross": _light_cross(st)
		"hexplate": _hex(st, Vector3.ZERO, Basis.IDENTITY, 1.0, 0.0)
		"hexwall": _hexwall(st)
		"hexdome": _hexdome(st)
		"aura": _aura(st)
		"spiral": _spiral(st)
		"spear": _spear(st)
		"blade": _blade(st)
		"dragon": _dragon(st)
		"banner": _banner(st)
		"chain": _chain(st)
		"rock": _rock(st)
		"spark": _spark(st)
		"shard": _shard(st)
		"sigil": _sigil(st)
		"runes": _runes(st)
	var built := st.commit()
	_meshes[kind] = built
	return built


static func warm() -> void:
	for kind in KINDS.split(" "):
		mesh(kind)


static func _v(st: SurfaceTool, p: Vector3, uv: Vector2, core := 0.0, n := Vector3.UP) -> void:
	st.set_color(Color(core, 1.0, 1.0, 1.0))
	st.set_uv(uv)
	st.set_normal(n)
	st.add_vertex(p)


static func _quad(st: SurfaceTool, a: Array, b: Array, c: Array, d: Array) -> void:
	# Each corner: [position, uv, core]
	for k in [a, b, c, a, c, d]:
		_v(st, k[0], k[1], float(k[2]) if k.size() > 2 else 0.0)


## A crescent turning around +Y from -span/2 to +span/2 (0 = +Z). UV.x runs
## along the sweep, UV.y from the inner (0) to the cutting edge (1).
static func _arc(st: SurfaceTool, span: float) -> void:
	var seg := 40
	for i in seg:
		var a0 := -span * 0.5 + span * float(i) / seg
		var a1 := -span * 0.5 + span * float(i + 1) / seg
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		_quad(st, [d0 * 0.42, Vector2(u0, 0)], [d1 * 0.42, Vector2(u1, 0)], [d1, Vector2(u1, 1)], [d0, Vector2(u0, 1)])


## A cross of two quads along +Z (0..1), one flat and one upright, so a streak
## reads from any camera. UV.y across.
static func _streak(st: SurfaceTool) -> void:
	for side in [Vector3.RIGHT, Vector3.UP]:
		var s: Vector3 = side * 0.5
		_quad(st, [-s, Vector2(0, 0)], [-s + Vector3.BACK, Vector2(1, 0)], [s + Vector3.BACK, Vector2(1, 1)], [s, Vector2(0, 1)])


static func _ring(st: SurfaceTool) -> void:
	var seg := 48
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		_quad(st, [d0 * 0.62, Vector2(float(i) / seg, 0)], [d1 * 0.62, Vector2(float(i + 1) / seg, 0)], [d1, Vector2(float(i + 1) / seg, 1)], [d0, Vector2(float(i) / seg, 1)])


## A jagged ground strip from a to b (XZ); UV.y is the distance from the origin
## (radius 1), UV.x across the seam.
static func _seam(st: SurfaceTool, a: Vector3, b: Vector3, wa: float, wb: float) -> void:
	var dir := (b - a)
	dir.y = 0.0
	var side := dir.normalized().cross(Vector3.UP)
	var da := Vector2(a.x, a.z).length()
	var db := Vector2(b.x, b.z).length()
	_quad(st, [a - side * wa, Vector2(0, da)], [b - side * wb, Vector2(0, db)], [b + side * wb, Vector2(1, db)], [a + side * wa, Vector2(1, da)])


static func _cracks(st: SurfaceTool, seed_value: int, branches: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for b in branches:
		var angle := TAU * float(b) / branches + rng.randf_range(-0.25, 0.25)
		var p := Vector3.ZERO
		var length := rng.randf_range(0.75, 1.0)
		var steps := 6
		var heading := angle
		for s in steps:
			heading += rng.randf_range(-0.45, 0.45)
			var q := p + Vector3(sin(heading), 0, cos(heading)) * length / steps
			var w0 := lerpf(0.055, 0.012, float(s) / steps)
			var w1 := lerpf(0.055, 0.012, float(s + 1) / steps)
			_seam(st, p, q, w0, w1)
			if s in [1, 3] and rng.randf() < 0.8:
				var fork := heading + rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
				var f0 := q
				for k in 3:
					fork += rng.randf_range(-0.3, 0.3)
					var f1 := f0 + Vector3(sin(fork), 0, cos(fork)) * length * 0.09
					_seam(st, f0, f1, lerpf(w1 * 0.8, 0.008, float(k) / 3.0), lerpf(w1 * 0.8, 0.006, float(k + 1) / 3.0))
					f0 = f1
			p = q


## The Grand Cross carved into the ground: two long seams through the centre and
## a broken ring, all burning outward from the centre.
static func _ground_cross(st: SurfaceTool) -> void:
	for axis in [Vector3.BACK, Vector3.RIGHT]:
		for sgn in [-1.0, 1.0]:
			var d: Vector3 = axis * sgn
			var steps := 6
			for s in steps:
				var a := d * float(s) / steps
				var b := d * float(s + 1) / steps
				var w0 := lerpf(0.11, 0.05, float(s) / steps)
				var w1 := lerpf(0.11, 0.05, float(s + 1) / steps)
				_seam(st, a, b, w0, w1)
			# The flared serif at each arm's end.
			var tip := d * 0.98
			var side := d.cross(Vector3.UP)
			_seam(st, tip - side * 0.16, tip + side * 0.16, 0.035, 0.035)
	var seg := 32
	for i in seg:
		if i % 4 == 3:
			continue
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var p0 := Vector3(sin(a0), 0, cos(a0)) * 0.62
		var p1 := Vector3(sin(a1), 0, cos(a1)) * 0.62
		_seam(st, p0, p1, 0.025, 0.025)


## An upright cross of light (XY, standing on y = 0), core along the bars.
static func _light_cross(st: SurfaceTool) -> void:
	_bar(st, Vector3(0, 0, 0), Vector3(0, 1, 0), 0.075)
	_bar(st, Vector3(-0.36, 0.68, 0), Vector3(0.36, 0.68, 0), 0.07)


## A flat glowing bar in XY: edges dark (core 0), centre line hot (core 1).
static func _bar(st: SurfaceTool, a: Vector3, b: Vector3, w: float) -> void:
	var dir := (b - a).normalized()
	var side := Vector3(-dir.y, dir.x, 0) * w
	var ua := a.length()
	var ub := b.length()
	_quad(st, [a - side, Vector2(ua, 0), 0.0], [b - side, Vector2(ub, 0), 0.0], [b, Vector2(ub, 0.5), 1.0], [a, Vector2(ua, 0.5), 1.0])
	_quad(st, [a, Vector2(ua, 0.5), 1.0], [b, Vector2(ub, 0.5), 1.0], [b + side, Vector2(ub, 1), 0.0], [a + side, Vector2(ua, 1), 0.0])


## One hexagonal panel of radius r in the plane of basis (x, y), facing basis.z.
## UV.y = 0 centre -> 1 rim, COLOR.r = stagger.
static func _hex(st: SurfaceTool, at: Vector3, basis: Basis, r: float, stagger: float) -> void:
	var centre := at
	for i in 6:
		var a0 := TAU * float(i) / 6.0 + PI / 6.0
		var a1 := TAU * float(i + 1) / 6.0 + PI / 6.0
		var p0 := at + (basis.x * cos(a0) + basis.y * sin(a0)) * r
		var p1 := at + (basis.x * cos(a1) + basis.y * sin(a1)) * r
		st.set_color(Color(stagger, 1, 1, 1))
		st.set_normal(basis.z)
		st.set_uv(Vector2(float(i) / 6.0, 0.0))
		st.add_vertex(centre)
		st.set_uv(Vector2(float(i) / 6.0, 1.0))
		st.add_vertex(p0)
		st.set_uv(Vector2(float(i + 1) / 6.0, 1.0))
		st.add_vertex(p1)


## A curved wall of hexagonal panels standing on y = 0 in front of +Z, about
## 2 wide and 1.5 tall at radius 1; panels light from the centre outward.
static func _hexwall(st: SurfaceTool) -> void:
	var r := 0.2
	for row in 4:
		var cols := 6 if row % 2 == 0 else 5
		for c in cols:
			var x := (float(c) - float(cols - 1) * 0.5) * r * 1.73
			var a := x / 1.0
			var y := 0.18 + float(row) * r * 1.5
			var at := Vector3(sin(a), y, cos(a))
			var basis := Basis(Vector3(cos(a), 0, -sin(a)), Vector3.UP, Vector3(sin(a), 0, cos(a)))
			var stagger := clampf((absf(x) * 0.8 + float(row) * 0.12), 0.0, 1.0)
			_hex(st, at, basis, r * 0.94, stagger)


## A dome of hexagonal panels round the caster (radius 1), lit from the ground up.
static func _hexdome(st: SurfaceTool) -> void:
	var rings := [[0.12, 12, 0.22], [0.5, 11, 0.21], [0.88, 9, 0.2], [1.22, 6, 0.18]]
	for ri in rings.size():
		var elev: float = rings[ri][0]
		var count: int = rings[ri][1]
		for i in count:
			var az := TAU * (float(i) + 0.5 * float(ri % 2)) / count
			var normal := Vector3(sin(az) * cos(elev), sin(elev), cos(az) * cos(elev))
			var x := Vector3(cos(az), 0, -sin(az))
			var basis := Basis(x, normal.cross(x).normalized() * -1.0, normal)
			_hex(st, normal, basis, float(rings[ri][2]), float(ri) / rings.size())
	_hex(st, Vector3.UP, Basis(Vector3.RIGHT, Vector3.BACK, Vector3.UP), 0.2, 1.0)


## An open cylinder (radius 1, height 1) whose top flares out slightly.
static func _aura(st: SurfaceTool) -> void:
	var seg := 28
	var rows := 6
	for j in rows:
		var h0 := float(j) / rows
		var h1 := float(j + 1) / rows
		for i in seg:
			var a0 := TAU * float(i) / seg
			var a1 := TAU * float(i + 1) / seg
			var r0 := 1.0 + h0 * h0 * 0.18
			var r1 := 1.0 + h1 * h1 * 0.18
			_quad(st, [Vector3(sin(a0) * r0, h0, cos(a0) * r0), Vector2(float(i) / seg, h0)], [Vector3(sin(a1) * r0, h0, cos(a1) * r0), Vector2(float(i + 1) / seg, h0)], [Vector3(sin(a1) * r1, h1, cos(a1) * r1), Vector2(float(i + 1) / seg, h1)], [Vector3(sin(a0) * r1, h1, cos(a0) * r1), Vector2(float(i) / seg, h1)])


## A ribbon winding 2.5 times round +Y, rising 0 -> 1 and tightening to 0.7.
static func _spiral(st: SurfaceTool) -> void:
	var seg := 72
	var turns := 2.5
	for i in seg:
		var t0 := float(i) / seg
		var t1 := float(i + 1) / seg
		var pts: Array = []
		for t in [t0, t1]:
			var a: float = TAU * turns * t
			var r: float = lerpf(1.0, 0.7, t)
			var c := Vector3(sin(a) * r, t, cos(a) * r)
			var out := Vector3(sin(a), 0, cos(a))
			pts.append([c - out * 0.12 - Vector3.UP * 0.05, c + out * 0.12 + Vector3.UP * 0.05])
		_quad(st, [pts[0][0], Vector2(t0, 0)], [pts[1][0], Vector2(t1, 0)], [pts[1][1], Vector2(t1, 1)], [pts[0][1], Vector2(t0, 1)])


## A spear of light pointing +X (length 1): shaft, guard and a leaf blade.
static func _spear(st: SurfaceTool) -> void:
	_bar(st, Vector3(0, 0, 0), Vector3(0.72, 0, 0), 0.05)
	_bar(st, Vector3(0.7, -0.12, 0), Vector3(0.7, 0.12, 0), 0.035)
	_layered(st, PackedVector2Array([Vector2(0.7, 0), Vector2(0.79, -0.1), Vector2(0.9, -0.07), Vector2(1.0, 0), Vector2(0.9, 0.07), Vector2(0.79, 0.1)]), 0.02)


## A greatsword of light pointing +X: grip, guard and a long tapering blade.
static func _blade(st: SurfaceTool) -> void:
	_bar(st, Vector3(0, 0, 0), Vector3(0.2, 0, 0), 0.03)
	_bar(st, Vector3(0.2, -0.11, 0), Vector3(0.2, 0.11, 0), 0.03)
	_layered(st, PackedVector2Array([Vector2(0.21, -0.065), Vector2(0.88, -0.05), Vector2(1.0, 0), Vector2(0.88, 0.05), Vector2(0.21, 0.065)]), 0.016)


## A dragon's head in profile, snout toward +X (about 1 long): an open jaw,
## two horns swept back and a mane of spikes, as one glowing silhouette.
static func _dragon(st: SurfaceTool) -> void:
	var outline := PackedVector2Array([
		Vector2(1.0, 0.04), Vector2(0.96, 0.1), Vector2(0.88, 0.1), Vector2(0.8, 0.13),
		Vector2(0.66, 0.2), Vector2(0.56, 0.24), Vector2(0.3, 0.46), Vector2(0.02, 0.56),
		Vector2(0.24, 0.42), Vector2(0.44, 0.24), Vector2(0.4, 0.22), Vector2(0.1, 0.32),
		Vector2(0.32, 0.17), Vector2(0.12, 0.16), Vector2(0.3, 0.08), Vector2(0.06, 0.02),
		Vector2(0.28, -0.04), Vector2(0.08, -0.14), Vector2(0.3, -0.14), Vector2(0.36, -0.26),
		Vector2(0.56, -0.24), Vector2(0.78, -0.2), Vector2(0.94, -0.17), Vector2(0.86, -0.12),
		Vector2(0.66, -0.08), Vector2(0.62, -0.04), Vector2(0.9, -0.01)])
	_layered(st, outline, 0.035)


## A filled outline (XY) drawn three times, each inset further and nudged toward
## +Z: a dark rim, a palette body and a hot core (COLOR.r 0 / 0.6 / 1).
static func _layered(st: SurfaceTool, outline: PackedVector2Array, inset: float) -> void:
	var shells: Array = [[outline, 0.0, 0.0]]
	for k in [1, 2]:
		for poly in Geometry2D.offset_polygon(outline, -inset * k, Geometry2D.JOIN_ROUND):
			shells.append([poly, 0.6 if k == 1 else 1.0, 0.004 * k])
	for shell in shells:
		var poly: PackedVector2Array = shell[0]
		var tris := Geometry2D.triangulate_polygon(poly)
		for idx in tris:
			var p := poly[idx]
			_v(st, Vector3(p.x, p.y, float(shell[2])), Vector2(p.x, 0.5), float(shell[1]), Vector3.BACK)


## A war banner on its pole (XY, standing on y = 0): a swallow-tailed cloth that
## waves away from the pole (melee_art's wave), an emblem burning in its middle.
static func _banner(st: SurfaceTool) -> void:
	_bar(st, Vector3(0, 0, 0), Vector3(0, 1.7, 0), 0.025)
	var cols := 8
	var rows := 4
	for i in cols:
		for j in rows:
			var x0 := 0.03 + 0.8 * float(i) / cols
			var x1 := 0.03 + 0.8 * float(i + 1) / cols
			var corners: Array = []
			for k in [[x0, j], [x1, j], [x1, j + 1], [x0, j + 1]]:
				var x: float = k[0]
				var bottom := 0.98 + maxf(0.0, x - 0.5) * 0.75
				var p := Vector3(x, lerpf(1.62, bottom, float(k[1]) / rows), 0)
				var emblem := clampf(1.0 - (absf(p.x - 0.34) + absf(p.y - 1.3)) * 4.5, 0.0, 1.0) * 0.75 + 0.25
				corners.append([p, Vector2(x, float(k[1]) / rows), emblem])
			_quad(st, corners[0], corners[1], corners[2], corners[3])


## Ten interlocking links along +X (0..1), alternately flat and upright.
static func _chain(st: SurfaceTool) -> void:
	var links := 10
	var seg := 12
	for l in links:
		var cx := (float(l) + 0.5) / links
		var rx := 0.6 / links
		var ry := 0.35 / links
		var upright := l % 2 == 1
		for i in seg:
			var a0 := TAU * float(i) / seg
			var a1 := TAU * float(i + 1) / seg
			var pts: Array = []
			for a in [a0, a1]:
				var row: Array = []
				for k in [1.0, 0.72, 0.45]:
					var off := Vector3(cos(a) * rx * (0.75 + 0.25 * k), sin(a) * ry * k, 0)
					if upright:
						off = Vector3(off.x, 0, off.y)
					row.append(Vector3(cx, 0, 0) + off)
				pts.append(row)
			_quad(st, [pts[0][0], Vector2(cx, 0), 0.0], [pts[1][0], Vector2(cx, 0), 0.0], [pts[1][1], Vector2(cx, 0.5), 1.0], [pts[0][1], Vector2(cx, 0.5), 1.0])
			_quad(st, [pts[0][1], Vector2(cx, 0.5), 1.0], [pts[1][1], Vector2(cx, 0.5), 1.0], [pts[1][2], Vector2(cx, 1), 0.0], [pts[0][2], Vector2(cx, 1), 0.0])


## A faceted rock chip (unit size), flat-shaded.
static func _rock(st: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var t := (1.0 + sqrt(5.0)) * 0.5
	var verts := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in verts.size():
		verts[i] = (verts[i] as Vector3).normalized() * rng.randf_range(0.7, 1.1) * Vector3(1.0, 0.7, 0.9) * 0.5
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for f in faces:
		var a: Vector3 = verts[f[0]]
		var b: Vector3 = verts[f[1]]
		var c: Vector3 = verts[f[2]]
		var n := (c - a).cross(b - a).normalized()
		for p in [a, c, b]:
			_v(st, p, Vector2.ZERO, 1.0, n)


## A particle card: x -0.5..0.5, y 0 (tail) .. 1 (head), facing +Z.
static func _spark(st: SurfaceTool) -> void:
	_quad(st, [Vector3(-0.5, 0, 0), Vector2(0, 0), 1.0], [Vector3(0.5, 0, 0), Vector2(1, 0), 1.0], [Vector3(0.5, 1, 0), Vector2(1, 1), 1.0], [Vector3(-0.5, 1, 0), Vector2(0, 1), 1.0])


## A mirror sliver: a thin kite, y 0..1.
static func _shard(st: SurfaceTool) -> void:
	var a := [Vector3(0, 0, 0), Vector2(0.5, 0), 1.0]
	var b := [Vector3(0.5, 0.35, 0), Vector2(1, 0.35), 1.0]
	var c := [Vector3(0, 1, 0), Vector2(0.5, 1), 1.0]
	var d := [Vector3(-0.4, 0.4, 0), Vector2(0, 0.4), 1.0]
	_quad(st, a, b, c, d)


## A flat line of light in XZ from a to b, w wide: UV.y across (0 -> 1, the hot
## centre at 0.5, as the ring mode reads it), UV.x along (for its flicker).
static func _flat_line(st: SurfaceTool, a: Vector3, b: Vector3, w: float, u0 := 0.0, u1 := 1.0) -> void:
	var dir := b - a
	dir.y = 0.0
	if dir.length_squared() < 0.000001:
		return
	var side := Vector3(-dir.z, 0, dir.x).normalized() * w * 0.5
	_quad(st, [a - side, Vector2(u0, 0)], [b - side, Vector2(u1, 0)], [b + side, Vector2(u1, 1)], [a + side, Vector2(u0, 1)])


static func _flat_circle(st: SurfaceTool, r: float, w: float, seg := 56) -> void:
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		_flat_line(st, Vector3(sin(a0), 0, cos(a0)) * r, Vector3(sin(a1), 0, cos(a1)) * r, w, float(i) / seg, float(i + 1) / seg)


## One small rune: two or three strokes inside a cell at angle a, between radii r0 and r1.
static func _glyph(st: SurfaceTool, rng: RandomNumberGenerator, a: float, half: float, r0: float, r1: float, w: float) -> void:
	var at := func(f_angle: float, f_radius: float) -> Vector3:
		var ang := a + (f_angle * 2.0 - 1.0) * half
		var rr := lerpf(r0, r1, f_radius)
		return Vector3(sin(ang), 0, cos(ang)) * rr
	# A spine across the band, then one or two branches off it.
	var spine := rng.randf_range(0.3, 0.7)
	_flat_line(st, at.call(spine, 0.0), at.call(spine, 1.0), w)
	for k in rng.randi_range(1, 2):
		var f := rng.randf_range(0.15, 0.85)
		var side := 0.0 if rng.randf() < 0.5 else 1.0
		_flat_line(st, at.call(spine, f), at.call(side, clampf(f + rng.randf_range(-0.35, 0.35), 0.0, 1.0)), w * 0.85)


## A magic circle on the ground (XZ, radius 1): a double rim, a ring of runes,
## a hexagram and an inner seal, with ticks out past the rim. Drawn in the ring
## mode (each stroke a soft line of light).
static func _sigil(st: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	_flat_circle(st, 1.0, 0.045, 64)
	_flat_circle(st, 0.9, 0.025, 64)
	_flat_circle(st, 0.62, 0.03, 48)
	_flat_circle(st, 0.2, 0.03, 24)
	for k in 2:
		var pts: Array = []
		for j in 3:
			var a := TAU * float(j) / 3.0 + PI * float(k) / 3.0
			pts.append(Vector3(sin(a), 0, cos(a)) * 0.62)
		for j in 3:
			_flat_line(st, pts[j], pts[(j + 1) % 3], 0.028)
	for k in 18:
		_glyph(st, rng, TAU * float(k) / 18.0, TAU / 18.0 * 0.32, 0.67, 0.86, 0.022)
	for k in 12:
		var a := TAU * (float(k) + 0.5) / 12.0
		var d := Vector3(sin(a), 0, cos(a))
		_flat_line(st, d * 1.03, d * (1.12 if k % 3 == 0 else 1.07), 0.03)
	for k in 6:
		var a := TAU * float(k) / 6.0
		var d := Vector3(sin(a), 0, cos(a))
		_flat_line(st, d * 0.2, d * 0.62, 0.02)


## A thin band of runes turning round +Y (radius 1): a rim, a finer inner rim
## and a dozen glyphs between them. Tilted and spun it reads as an orbiting
## rune ring; stood up (rot.x = PI / 2) it is a launch circle.
static func _runes(st: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	_flat_circle(st, 1.0, 0.07, 56)
	_flat_circle(st, 0.78, 0.045, 48)
	for k in 12:
		_glyph(st, rng, TAU * float(k) / 12.0, TAU / 12.0 * 0.3, 0.82, 0.96, 0.05)
