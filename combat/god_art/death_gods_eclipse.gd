extends RefCounted
## Assassin god skill "สุริยคราสเทพมรณะ" (death_gods_eclipse): the Death God's eclipse.
## Wind-up: the light goes out of the hit area (a disc of shadow on the ground, a veil of
## dusk in the air: local, never the whole screen) and a black sun with a thin crimson
## corona rises behind the caster. Four waves: shadow slashes cross the circle, black
## with white-hot edges, an afterimage of the assassin at each end. Finale: the Death God
## stands up out of the dark and a crescent-moon scythe reaps the whole circle, leaving
## a red scar and falling black feathers. Black, crimson and violet.
const K := preload("res://combat/god_art/_kit_melee.gd")
const BLACK := Color(0.035, 0.02, 0.06)
const CRIMSON := Color("e8102e")
const VIOLET := Color("7a2cff")
const HOT := Color("fff0f2")
const ID := "death_gods_eclipse"
## The Death God's height: its eyes stay inside the third-person camera's frame.
const REAPER := 5.7
## How far beyond the caster (as the camera sees it) the Death God rises.
const BEYOND := 4.4
static var _cache := {}


static func _c(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


## The eclipse on the ground (radius 1 = the hit area): shadow, and the corona at its rim.
static func _ground() -> ArrayMesh:
	if not _cache.has("ground"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 6
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		K.disc(st, 1.14, Color(0.02, 0.0, 0.05, 0.5), 0.0, 48, 0.0, Vector3.UP, Vector3.ZERO, Color(0.02, 0.0, 0.05, 0.0), 0.0, true)
		K.disc(st, 1.0, Color(0.02, 0.0, 0.05, 0.4), 0.002, 48, 0.0, Vector3.UP, Vector3.ZERO, Color(0.02, 0.0, 0.05, 0.62), 0.0, true)
		for i in 36:
			var a := TAU * float(i) / 36.0 + rng.randf_range(-0.05, 0.05)
			var dir := Vector3(sin(a), 0, cos(a))
			K.ribbon(st, PackedVector3Array([dir * 0.99 + Vector3.UP * 0.004, dir * rng.randf_range(1.05, 1.16) + Vector3.UP * 0.004]), 0.035, _c(CRIMSON, 0.9), 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0, _c(CRIMSON, 0.0))
		K.ring(st, 1.0, 0.045, _c(CRIMSON, 1.0), 0.005, 72)
		_cache.ground = K.finish(st, Vector3.ONE * 0.2, false)
	return _cache.ground


## The dusk in the air: a low dome of shadow over the hit area (radius 1), thinning upward.
static func _veil() -> ArrayMesh:
	if not _cache.has("veil"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		st.set_uv2(Vector2.ZERO)
		st.set_uv(Vector2(0.5, -1.0))
		var rings := 5
		for k in rings:
			var h0 := float(k) / float(rings) * 0.5 * PI
			var h1 := float(k + 1) / float(rings) * 0.5 * PI
			var c0 := Color(0.03, 0.0, 0.08, 0.2 * pow(1.0 - float(k) / float(rings), 1.6))
			var c1 := Color(0.03, 0.0, 0.08, 0.2 * pow(1.0 - float(k + 1) / float(rings), 1.6))
			for i in 28:
				var a0 := TAU * float(i) / 28.0
				var a1 := TAU * float(i + 1) / 28.0
				var p00 := Vector3(sin(a0) * cos(h0), sin(h0), cos(a0) * cos(h0))
				var p01 := Vector3(sin(a1) * cos(h0), sin(h0), cos(a1) * cos(h0))
				var p10 := Vector3(sin(a0) * cos(h1), sin(h1), cos(a0) * cos(h1))
				var p11 := Vector3(sin(a1) * cos(h1), sin(h1), cos(a1) * cos(h1))
				for item in [[p00, c0], [p01, c0], [p11, c1], [p00, c0], [p11, c1], [p10, c1]]:
					st.set_color(item[1])
					st.add_vertex(item[0])
		_cache.veil = K.finish(st, Vector3.ONE * 0.2, false)
	return _cache.veil


## The black sun in the XY plane (radius 1): violet haze, crimson corona, the black disc.
static func _sun() -> ArrayMesh:
	if not _cache.has("sun"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 2
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		K.disc(st, 2.1, _c(VIOLET, 0.55), 0.0, 36, 0.0, Vector3.BACK, Vector3(0, 0, -0.02), _c(VIOLET, 0.0), 0.0, true)
		for i in 28:
			var a := TAU * float(i) / 28.0 + rng.randf_range(-0.06, 0.06)
			var dir := Vector3(sin(a), cos(a), 0)
			var reach := rng.randf_range(1.2, 1.75) if i % 2 == 0 else rng.randf_range(1.1, 1.3)
			K.ribbon(st, PackedVector3Array([dir * 0.96, dir * reach]), 0.1, _c(CRIMSON, 0.95), 0.0, 0.0, Vector3.BACK, 0.0, 0.0, 1.0, _c(CRIMSON, 0.0))
		var rim := PackedVector3Array()
		for i in 49:
			var a := TAU * float(i) / 48.0
			rim.append(Vector3(sin(a), cos(a), 0) * 1.02)
		K.ribbon(st, rim, 0.14, _c(CRIMSON, 1.0), 0.0, 0.0, Vector3.BACK, 0.0)
		K.disc(st, 1.0, Color(0.01, 0.0, 0.02, 1.0), 0.0, 40, 0.0, Vector3.BACK, Vector3(0, 0, 0.02), Color(0.01, 0.0, 0.02, 1.0), 0.0, true)
		_cache.sun = K.finish(st, Vector3.ONE * 0.3, false)
	return _cache.sun


## The assassin's afterimage: a figure in a lunge, facing +Z, 1.9 tall, daggers out.
static func _figure() -> K.Part:
	if _cache.has("figure"):
		return _cache.figure
	var p := K.Part.new()
	p.ink(BLACK, 0.2)
	p.tube(Vector3(0, 1.0, 0), Vector3(0, 1.5, 0.2), 0.2, 0.25, 5)
	p.ball(Vector3(0, 1.7, 0.3), Vector3(0.18, 0.2, 0.18), 6, 4)
	p.tube(Vector3(0, 1.78, 0.24), Vector3(0, 1.95, -0.12), 0.13, 0.0, 4)
	p.tube(Vector3(-0.1, 1.02, 0), Vector3(-0.18, 0.52, 0.42), 0.12, 0.09, 4)
	p.tube(Vector3(-0.18, 0.52, 0.42), Vector3(-0.2, 0.0, 0.32), 0.09, 0.07, 4)
	p.tube(Vector3(0.1, 1.02, 0), Vector3(0.16, 0.56, -0.42), 0.12, 0.09, 4)
	p.tube(Vector3(0.16, 0.56, -0.42), Vector3(0.2, 0.06, -0.85), 0.09, 0.07, 4)
	p.tube(Vector3(0.22, 1.44, 0.2), Vector3(0.3, 1.32, 0.72), 0.08, 0.06, 4)
	p.tube(Vector3(-0.22, 1.44, 0.12), Vector3(-0.4, 1.3, -0.4), 0.08, 0.06, 4)
	# The scarf streams behind.
	p.ink(Color(0.2, 0.06, 0.4), 0.2)
	p.tube(Vector3(0, 1.56, 0.1), Vector3(0.12, 1.8, -1.0), 0.1, 0.0, 3, 0.25)
	p.tube(Vector3(0, 1.54, 0.1), Vector3(-0.15, 1.55, -0.8), 0.08, 0.0, 3, 0.25)
	# Eyes and blades burn.
	p.ink(CRIMSON, 0.0, 1.0)
	for x in [-0.07, 0.07]:
		p.gem(Vector3(x, 1.71, 0.46), Vector3(0.035, 0.02, 0.02))
	p.ink(HOT, 0.0, 0.9)
	p.tube(Vector3(0.3, 1.32, 0.72), Vector3(0.33, 1.34, 1.35), 0.055, 0.0, 4, 0.3)
	p.tube(Vector3(-0.4, 1.3, -0.4), Vector3(-0.52, 1.14, -0.95), 0.05, 0.0, 4, 0.3)
	_cache.figure = p
	return p


## The cuts of one wave, as [from, to, delay]: chords across the circle, never the same twice.
static func _chords(index: int, r: float) -> Array:
	var out := []
	var base := [0.35, 1.25, 2.3, 0.85][index % 4] as float
	var count := 3 if index % 2 == 0 else 4
	for k in count:
		var a := base + PI * float(k) / float(count) + (0.2 if k % 2 == 1 else 0.0)
		var dir := Vector3(sin(a), 0, cos(a))
		var side := Vector3(cos(a), 0, -sin(a))
		var shift: float = [0.0, 0.28, -0.3, 0.14][(k + index) % 4]
		var off := side * r * shift
		var reach := r * 0.9
		var flip := -1.0 if k % 2 == 1 else 1.0
		out.append([off - dir * reach * flip, off + dir * reach * flip, 0.075 * float(k)])
	return out


## One wave: [slashes FLAT, afterimages SOLID, feathers BITS, sparks BITS].
static func _wave_meshes(index: int, r: float) -> Array:
	var key := "wave%d" % (index % 4)
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 90 + index
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solid := K.begin()
	var bits := SurfaceTool.new()
	bits.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sparks := SurfaceTool.new()
	sparks.begin(Mesh.PRIMITIVE_TRIANGLES)
	for chord in _chords(index, r):
		var from: Vector3 = chord[0]
		var to: Vector3 = chord[1]
		var delay: float = chord[2]
		var dir := (to - from).normalized()
		var side := Vector3(dir.z, 0, -dir.x)
		var height := rng.randf_range(1.1, 1.6)
		var bow := rng.randf_range(-1.2, 1.2)
		var pts := PackedVector3Array()
		var low := PackedVector3Array()
		for i in 13:
			var t := float(i) / 12.0
			var at := from.lerp(to, t) + side * sin(t * PI) * bow
			pts.append(at + Vector3.UP * (height + sin(t * PI) * 0.35))
			low.append(at + Vector3.UP * 0.06)
		# The scar it leaves on the ground, then the cut itself: a white-hot edge under black.
		K.ribbon(flat, low, 0.5, _c(CRIMSON, 0.85), delay, 0.0, Vector3.UP, 1.0)
		for up in [Vector3.UP, side]:
			K.ribbon(flat, pts, 2.3, _c(CRIMSON, 0.95), delay, 0.0, up, 1.0)
			K.ribbon(flat, pts, 0.9, Color(0.0, 0.0, 0.02, 1.0), delay, 0.0, up, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
		var yaw := Basis(Vector3.UP, atan2(dir.x, dir.z))
		K.stamp(solid, _figure(), Transform3D(yaw.scaled(Vector3.ONE * 1.5), from + dir * 0.8), delay, 0.0)
		K.stamp(solid, _figure(), Transform3D(yaw.scaled(Vector3.ONE * 1.5), to - dir * 0.6), delay + 0.09, 0.0)
		for i in 5:
			var at := from.lerp(to, rng.randf_range(0.15, 0.85)) + Vector3.UP * height
			K.burst_at(bits, rng, "feather", 2, at, 0.0, 0.6, 1.4, 1.5, [BLACK, Color(0.1, 0.03, 0.12), Color(0.25, 0.02, 0.08)], 0.6, delay + 0.05, 0.08, -0.2, 0.3)
			K.burst_at(sparks, rng, "ember", 3, at, 0.0, 0.4, 2.6, 2.0, [CRIMSON, HOT, VIOLET.lightened(0.3)], 0.16, delay + 0.04, 0.05, -0.2, 0.3)
	_cache[key] = [K.finish(flat, Vector3.ONE * 0.5, false), K.finish(solid, Vector3.ONE * 0.5), K.finish(bits, Vector3(5, 6, 5), false), K.finish(sparks, Vector3(5, 6, 5), false)]
	return _cache[key]


## The crescent-moon scythe, lying level round the origin: the shaft runs out along +Z,
## the blade curves on from its end (towards +X), spine outside, edge inside.
static func _scythe(r: float) -> ArrayMesh:
	if not _cache.has("scythe"):
		var st := K.begin()
		var p := K.Part.new()
		var reach := r * 0.6
		p.ink(Color(0.08, 0.05, 0.12), 0.4)
		p.tube(Vector3(0, 0, 0.8), Vector3(0, 0, reach + 0.4), 0.13, 0.11, 6)
		p.ink(VIOLET, 0.6, 0.3)
		for z in [1.6, reach * 0.55, reach - 0.3]:
			p.tube(Vector3(0, 0, z), Vector3(0, 0, z + 0.16), 0.17, 0.17, 6)
		p.ink(CRIMSON, 0.5, 0.6)
		p.gem(Vector3(0, 0, reach + 0.45), Vector3(0.26, 0.26, 0.26))
		var steps := 18
		var outer: Array[Vector3] = []
		var inner: Array[Vector3] = []
		for i in steps + 1:
			var t := float(i) / float(steps)
			var a := t * 1.5
			var out_r := reach + 0.5 + sin(t * PI) * r * 0.24
			var width := r * 0.2 * pow(1.0 - t, 0.75) * (0.55 + 0.45 * sin(minf(t * 5.0, 1.0) * PI * 0.5))
			outer.append(Vector3(sin(a), 0, cos(a)) * out_r)
			inner.append(Vector3(sin(a), 0, cos(a)) * (out_r - width))
		for i in steps:
			var up := Vector3.UP * 0.1
			# Spine (thick, outside) to edge (a line, inside): black steel, the edge white-hot.
			p.ink(BLACK, 0.9)
			p.quad(outer[i] + up, outer[i + 1] + up, inner[i + 1], inner[i])
			p.quad(outer[i] - up, inner[i], inner[i + 1], outer[i + 1] - up)
			p.ink(Color(0.2, 0.02, 0.08), 0.5)
			p.quad(outer[i] + up, outer[i] - up, outer[i + 1] - up, outer[i + 1] + up)
			p.ink(HOT, 0.0, 1.0)
			var e0 := inner[i].lerp(outer[i], 0.16)
			var e1 := inner[i + 1].lerp(outer[i + 1], 0.16)
			p.quad(e0 + up * 0.25, e1 + up * 0.25, inner[i + 1] + up * 0.02, inner[i] + up * 0.02)
			p.quad(e0 - up * 0.25, inner[i] - up * 0.02, inner[i + 1] - up * 0.02, e1 - up * 0.25)
			p.ink(CRIMSON, 0.0, 0.85)
			var s0 := inner[i].lerp(outer[i], 0.62)
			var s1 := inner[i + 1].lerp(outer[i + 1], 0.62)
			var s2 := inner[i + 1].lerp(outer[i + 1], 0.7)
			var s3 := inner[i].lerp(outer[i], 0.7)
			p.quad(s0 + up * 0.62, s1 + up * 0.62, s2 + up * 0.72, s3 + up * 0.72)
		K.stamp(st, p)
		_cache.scythe = K.finish(st, Vector3.ONE * 0.5)
	return _cache.scythe


## The Death God: a hooded figure on the origin, facing +Z, its hood 1 tall. One bone hand
## reaches out, the other holds a great scythe whose crescent blade arcs over the hood
## (to +Y 1.2). Violet cloth (it must read against its own black sun), a void for a face,
## two burning eyes.
static func _reaper() -> ArrayMesh:
	if not _cache.has("reaper"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 13
		var st := K.begin()
		var p := K.Part.new()
		var cloth := Color(0.17, 0.08, 0.34)
		var deep := Color(0.08, 0.035, 0.17)
		p.ink(deep, 0.1)
		p.tube(Vector3(0, 0.0, 0), Vector3(0, 0.34, 0), 0.27, 0.17, 9)
		p.ink(cloth, 0.1)
		p.tube(Vector3(0, 0.34, 0), Vector3(0, 0.66, 0), 0.17, 0.2, 9)
		# Tatters at the hem.
		for i in 11:
			var a := TAU * float(i) / 11.0
			var dir := Vector3(cos(a), 0, sin(a))
			p.ink(deep.lightened(0.05 * float(i % 3)), 0.1)
			p.tube(dir * 0.23 + Vector3.UP * 0.1, dir * rng.randf_range(0.3, 0.4) + Vector3.DOWN * rng.randf_range(0.02, 0.1), 0.08, 0.0, 3)
		# A crimson sash down the front, the mantle over the shoulders with its burning hem.
		p.ink(CRIMSON.darkened(0.25), 0.2, 0.25)
		p.box(Vector3(0, 0.36, 0.185), Vector3(0.07, 0.56, 0.03))
		p.ink(cloth.lightened(0.1), 0.2)
		p.ball(Vector3(0, 0.67, 0), Vector3(0.35, 0.085, 0.21), 8, 3)
		p.ink(CRIMSON, 0.2, 0.7)
		p.tube(Vector3(0, 0.635, 0), Vector3(0, 0.65, 0), 0.3, 0.33, 10, 0.62, false)
		# The hood, and the void where a face would be.
		p.ink(cloth.lightened(0.05), 0.2)
		p.ball(Vector3(0, 0.82, 0.0), Vector3(0.19, 0.2, 0.19), 8, 5)
		p.tube(Vector3(0, 0.96, -0.02), Vector3(0, 1.0, -0.2), 0.1, 0.0, 5)
		p.ink(Color(0.0, 0.0, 0.0), 0.0)
		p.ball(Vector3(0, 0.815, 0.09), Vector3(0.135, 0.15, 0.12), 7, 4)
		p.ink(Color(1.0, 0.16, 0.2), 0.0, 1.0)
		for x in [-0.058, 0.058]:
			p.gem(Vector3(x, 0.84, 0.2), Vector3(0.042, 0.024, 0.024))
		# One sleeve reaches out, bone fingers spread; the other holds the scythe.
		p.ink(cloth.lightened(0.04), 0.1)
		p.tube(Vector3(-0.24, 0.66, 0.0), Vector3(-0.46, 0.56, 0.1), 0.085, 0.1, 5)
		p.tube(Vector3(-0.46, 0.56, 0.1), Vector3(-0.62, 0.62, 0.2), 0.1, 0.07, 5)
		p.tube(Vector3(0.24, 0.66, 0.0), Vector3(0.36, 0.56, 0.08), 0.085, 0.1, 5)
		p.tube(Vector3(0.36, 0.56, 0.08), Vector3(0.42, 0.5, 0.12), 0.1, 0.07, 5)
		p.ink(Color(0.9, 0.88, 0.82), 0.3)
		for k in 3:
			var spread := (float(k) - 1.0) * 0.04
			p.tube(Vector3(-0.62, 0.62, 0.2), Vector3(-0.71 - absf(spread) * 0.2, 0.67 + spread, 0.28), 0.016, 0.005, 3)
		p.ball(Vector3(0.42, 0.5, 0.13), Vector3(0.035, 0.035, 0.035), 5, 3)
		# The scythe: a black shaft with bone rings, the crescent arcing over the hood.
		var foot := Vector3(0.34, 0.04, 0.13)
		var head := Vector3(0.5, 0.98, 0.1)
		p.ink(Color(0.1, 0.06, 0.16), 0.5)
		p.tube(foot, head, 0.022, 0.02, 5)
		p.ink(Color(0.9, 0.88, 0.82), 0.4)
		for t in [0.3, 0.62, 0.97]:
			var at := foot.lerp(head, t)
			p.tube(at, at + (head - foot).normalized() * 0.022, 0.032, 0.032, 5)
		var centre := head + Vector3(-0.45, -0.16, 0)
		var steps := 16
		var outer: Array[Vector3] = []
		var inner: Array[Vector3] = []
		for i in steps + 1:
			var t := float(i) / float(steps)
			var phi := 0.535 + 2.35 * t
			var reach := 0.523 * (1.0 + 0.13 * sin(t * PI))
			var out := Vector3(cos(phi), sin(phi) * 0.62, 0)
			var width := 0.23 * pow(1.0 - t, 0.7) * (0.5 + 0.5 * sin(minf(t * 5.0, 1.0) * PI * 0.5))
			outer.append(centre + out * reach)
			inner.append(centre + out * (reach - width))
		var thick := Vector3(0, 0, 0.014)
		for i in steps:
			# Black steel from the spine, a crimson line, the edge white-hot.
			for side in [1.0, -1.0]:
				var z: Vector3 = thick * side
				var mid0 := inner[i].lerp(outer[i], 0.3)
				var mid1 := inner[i + 1].lerp(outer[i + 1], 0.3)
				p.ink(Color(0.05, 0.03, 0.08), 0.9)
				p.quad(outer[i] + z, outer[i + 1] + z, mid1 + z, mid0 + z)
				p.ink(HOT, 0.6, 0.3)
				p.quad(mid0 + z, mid1 + z, inner[i + 1], inner[i])
				p.ink(CRIMSON, 0.0, 0.9)
				var c0 := inner[i].lerp(outer[i], 0.56)
				var c1 := inner[i + 1].lerp(outer[i + 1], 0.56)
				var d0 := inner[i].lerp(outer[i], 0.68)
				var d1 := inner[i + 1].lerp(outer[i + 1], 0.68)
				p.quad(c0 + z * 1.3, c1 + z * 1.3, d1 + z * 1.3, d0 + z * 1.3)
			p.ink(Color(0.2, 0.02, 0.08), 0.5)
			p.quad(outer[i] + thick, outer[i] - thick, outer[i + 1] - thick, outer[i + 1] + thick)
		K.stamp(st, p)
		_cache.reaper = K.finish(st, Vector3(0.3, 1.5, 0.3))
	return _cache.reaper


## The reaping: the crescent's wake round the circle, and the scar it leaves (radius 1).
static func _reap() -> Array:
	if not _cache.has("reap"):
		var wake := SurfaceTool.new()
		wake.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in 2:
			var pts := PackedVector3Array()
			for i in 73:
				var a := 1.5 + TAU * 1.05 * float(i) / 72.0
				pts.append(Vector3(sin(a), 0, cos(a)) * (0.82 - 0.03 * float(k)) + Vector3.UP * 0.02 * float(k))
			if k == 0:
				K.ribbon(wake, pts, 0.36, _c(CRIMSON, 0.95), 0.0, 0.0, Vector3.UP, 0.0)
			else:
				K.ribbon(wake, pts, 0.13, Color(0.0, 0.0, 0.02, 1.0), 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		var scar := SurfaceTool.new()
		scar.begin(Mesh.PRIMITIVE_TRIANGLES)
		# One great slash through the middle, and the reaped rim.
		var gash := PackedVector3Array()
		for i in 15:
			var t := float(i) / 14.0
			gash.append(Vector3(lerpf(-0.95, 0.95, t), 0, lerpf(0.35, -0.3, t) + sin(t * PI) * 0.22))
		K.ribbon(scar, gash, 0.3, _c(CRIMSON, 1.0), 0.0, 0.0, Vector3.UP, 1.0)
		K.ring(scar, 0.84, 0.09, _c(CRIMSON, 0.95), 0.0, 72)
		for i in 14:
			var a := rng.randf() * TAU
			var dir := Vector3(sin(a), 0, cos(a))
			var side := Vector3(dir.z, 0, -dir.x)
			var from := dir * 0.84
			K.ribbon(scar, PackedVector3Array([from, from + dir * rng.randf_range(0.06, 0.2) + side * rng.randf_range(-0.08, 0.08)]), 0.03, _c(CRIMSON, 0.9), 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0, _c(CRIMSON, 0.0))
		_cache.reap = [K.finish(wake, Vector3.ONE * 0.2, false), K.finish(scar, Vector3.ONE * 0.2, false)]
	return _cache.reap


## The Death God in [param root]: near enough, and no taller than the camera shows, so
## that hood, eyes, scythe and the black sun at its back all stay in frame. It leans back
## a little, its face to the camera.
static func _death_god(root: StarSkillArt, shroud: bool) -> void:
	var spot := K.beyond(root, BEYOND)
	var face := K.facing(root)
	var tall := REAPER * GodSkillArt.fit(root, root.to_global(spot), REAPER * 1.22, 0.6)
	var back := spot * (1.0 + (tall * 0.19 + 0.7) / BEYOND)
	K.put(root, K.SOLID, _reaper(), "EclipseDeathGod", spot, Vector3(tall * 1.1, tall, tall * 1.1), 2.0, {"drop": -0.75, "flight": 0.3, "ease": 1.0, "rim_color": Color("b070ff"), "rim": 0.75, "glow_color": Color("ff4a56")}, {"fade_in": 0.1, "decay": 0.72}, Vector3(-0.24, face, 0))
	K.put(root, K.FLAT, _sun(), "EclipseTotal", back + Vector3.UP * tall * 0.8, Vector3.ONE * tall * 0.31, 2.1, {"soft": 0.7, "hot": Color(1, 0.94, 0.95, 1.0), "core": 0.5, "flick": 0.14, "add": 0.55, "gain": 1.2, "priority": -1}, {"initial": 0.68, "grow_time": 0.12, "fade_in": 0.02, "decay": 0.7, "face_camera": true}, Vector3(-0.3, 0, 0))
	if shroud:
		K.put(root, K.BITS, K.burst("eclipse_shroud", "puff", 30, 0.5, 3.2, 1.2, 1.6, [Color(0.05, 0.02, 0.1), Color(0.12, 0.03, 0.2), Color(0.02, 0.01, 0.04)], 1.3, 0.3, 43, 0.1, 1.2), "EclipseShroud", spot, Vector3.ONE, 1.9, {"life": 1.5, "gravity": -0.8, "drag": 1.4, "piece": 1.3, "swell": 1.8, "alpha": 0.6, "shrink": 0.4, "spin": 1.5}, {"decay": 0.8})


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := K.radius(skill)
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	# The caster: shadow boils up round the feet.
	K.put(art, K.BITS, K.burst("eclipse_smoke", "puff", 22, 0.2, 1.3, 0.3, 2.2, [Color(0.05, 0.02, 0.1), Color(0.12, 0.03, 0.2), Color(0.02, 0.01, 0.04)], 0.7, 1.0, 3, 0.05, 0.4), "EclipseSmoke", Vector3.ZERO, Vector3.ONE, time + 0.2, {"life": 1.0, "gravity": -1.0, "drag": 1.5, "piece": 0.7, "swell": 1.6, "alpha": 0.6, "shrink": 0.4, "spin": 2.0}, {"fade_in": 0.05, "decay": 0.9})
	# The eclipse stays on the ground until the reaping is done.
	var hold := time + 1.5 + 1.5
	var ground := K.extra(parent, Vector3(point.x, 0, point.z), hold, "StarGodGround_" + ID, origin)
	if ground:
		K.put(ground, K.FLAT, _ground(), "EclipseGround", Vector3.UP * 0.05, Vector3.ONE * r, hold, {"soft": 0.6, "hot": Color(1, 0.75, 0.8, 0.9), "core": 0.5, "flick": 0.1, "add": 0.5}, {"initial": 0.25, "grow_time": 0.22, "fade_in": 0.1, "decay": 0.9})
		K.put(ground, K.FLAT, _veil(), "EclipseVeil", Vector3.UP * 0.05, Vector3(r * 1.02, 6.0, r * 1.02), hold, {"soft": 0.01, "add": 0.0}, {"initial": 0.25, "grow_time": 0.22, "fade_in": 0.14, "decay": 0.88})
		ground._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var sky := K.extra(parent, Vector3(point.x, 0, point.z), time + 1.5, "StarGodSky_" + ID, origin)
	if sky:
		# The black sun climbs behind the caster and hangs there through the waves.
		var spot := K.beyond(sky, BEYOND)
		# It stops where the camera still shows its whole corona.
		var rise := clampf(K.sky(sky, spot, 9.0) - 2.8 - 3.4, 0.4, 2.2)
		K.put(sky, K.FLAT, _sun(), "EclipseSun", spot + Vector3.UP * 2.8, Vector3.ONE * 1.7, time + 1.5, {"soft": 0.7, "hot": Color(1, 0.9, 0.92, 1.0), "core": 0.55, "flick": 0.12, "add": 0.5}, {"initial": 0.3, "grow_time": 0.3, "fade_in": 0.08, "travel": Vector3.UP * rise, "decay": 0.93, "face_camera": true}, Vector3(-0.3, 0, 0))
		K.put(sky, K.BITS, K.burst("eclipse_drift", "feather", 26, 0.5, r * 0.8, 0.4, -1.0, [BLACK, Color(0.1, 0.03, 0.12)], 0.36, 1.2, 4, 3.0, 7.0), "EclipseDrift", Vector3.ZERO, Vector3.ONE, time + 1.2, {"life": 2.2, "gravity": 1.2, "drag": 0.8, "piece": 0.36, "sway": 0.5, "spin": 3.0, "floor_y": 0.08, "shrink": 0.9}, {"decay": 0.9})
		sky._draw()
	return true


static func wave(art: StarSkillArt, _parent: Node3D, skill: Dictionary, index: int, _point: Vector3, _source: Vector3) -> bool:
	var r := K.radius(skill)
	var meshes := _wave_meshes(index, r)
	K.put(art, K.FLAT, meshes[0], "EclipseSlashes", Vector3.ZERO, Vector3.ONE, 0.85, {"sweep": 0.09, "soft": 0.75, "hot": Color(1, 0.96, 0.97, 1.0), "core": 0.42, "add": 0.6, "gain": 1.1}, {"fade_in": 0.01, "decay": 0.45})
	K.put(art, K.SOLID, meshes[1], "EclipseAfterimages", Vector3.ZERO, Vector3.ONE, 0.75, {"rim_color": CRIMSON, "rim": 1.3, "glow_color": Color("ff6a7a"), "dim": 0.8}, {"fade_in": 0.01, "decay": 0.4})
	K.put(art, K.BITS, meshes[2], "EclipseFeathers", Vector3.ZERO, Vector3.ONE, 1.6, {"life": 1.4, "gravity": 2.4, "drag": 1.4, "piece": 0.6, "sway": 0.4, "spin": 5.0, "floor_y": 0.08, "shrink": 0.85}, {"decay": 0.9})
	K.put(art, K.BITS, meshes[3], "EclipseSparks", Vector3.ZERO, Vector3.ONE, 0.9, {"life": 0.6, "gravity": 4.0, "drag": 2.0, "piece": 0.16, "add": 0.7, "shrink": 0.2}, {"decay": 0.8})
	return true


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	var r := K.radius(skill)
	var reap := _reap()
	var swing := 0.62
	# The crescent reaps the whole circle once, level with the neck.
	K.put(art, K.SOLID, _scythe(r), "EclipseScythe", Vector3.UP * 1.5, Vector3.ONE, swing, {"rim_color": CRIMSON, "rim": 0.9, "glow_color": HOT}, {"fade_in": 0.02, "turn": Vector3(0, TAU * 1.05, 0), "decay": 0.78}, Vector3(0, 1.5, 0))
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		# A phone has no room for the avatar's own root: the Death God stands in this one,
		# straight after the scythe (the layers a low quality drops are the trimmings).
		_death_god(art, false)
	K.put(art, K.FLAT, reap[0], "EclipseWake", Vector3.UP * 1.5, Vector3.ONE * r, swing + 0.25, {"sweep": swing * 0.62, "tail": 0.9, "soft": 0.7, "hot": Color(1, 0.96, 0.97, 1.0), "core": 0.4, "add": 0.6, "gain": 1.15}, {"fade_in": 0.01, "decay": 0.7})
	K.put(art, K.FLAT, reap[1], "EclipseScar", Vector3.UP * 0.07, Vector3.ONE * r, 2.3, {"sweep": swing * 0.6, "soft": 0.6, "hot": Color(1, 0.85, 0.88, 1.0), "core": 0.45, "flick": 0.14, "add": 0.6, "gain": 1.15}, {"delay": 0.05, "decay": 0.7})
	K.put(art, K.BITS, K.burst("eclipse_feathers", "feather", 80, 0.5, r * 0.95, 0.5, -1.2, [BLACK, Color(0.1, 0.03, 0.12), Color(0.3, 0.02, 0.08)], 0.75, 0.5, 41, 2.0, 7.5), "EclipseFeatherFall", Vector3.ZERO, Vector3.ONE, 2.4, {"life": 2.2, "gravity": 1.5, "drag": 0.8, "piece": 0.75, "sway": 0.55, "spin": 3.5, "floor_y": 0.08, "shrink": 0.9}, {"delay": 0.12, "decay": 0.85})
	K.put(art, K.FLAT, K.shock("eclipse_shock", _c(CRIMSON, 1.0), 0.16), "EclipseShock", Vector3.UP * 0.12, Vector3.ONE * r * 1.2, 0.6, {"soft": 1.2, "hot": Color(1, 0.9, 0.92, 1.0), "core": 0.55, "add": 0.6}, {"delay": swing * 0.5, "initial": 0.08, "grow_time": 0.75, "fade_in": 0.02, "decay": 0.3})
	K.put(art, K.BITS, K.burst("eclipse_sparks", "ember", 70, r * 0.5, r * 0.85, 4.5, 3.0, [CRIMSON, HOT, VIOLET.lightened(0.25)], 0.2, 0.36, 42, 1.0, 1.9), "EclipseReapSparks", Vector3.ZERO, Vector3.ONE, 1.4, {"life": 0.9, "gravity": 5.0, "drag": 1.6, "piece": 0.2, "add": 0.7, "shrink": 0.25}, {"delay": 0.03, "decay": 0.8})
	if extras < 1:
		return true
	# The Death God stands up out of the dark behind the caster, the eclipse at its back.
	var avatar := K.extra(parent, point, 2.2, "StarGodAvatar_" + ID, source)
	if avatar:
		_death_god(avatar, true)
		avatar._draw()
	if extras < 2:
		return true
	# Every shadow the assassin left closes on the centre at once.
	var temple := K.extra(parent, point, 2.2, "StarGodTemple_" + ID, source)
	if temple:
		if not _cache.has("court"):
			var st := K.begin()
			for i in 8:
				var a := TAU * (float(i) + 0.5) / 8.0
				var at := Vector3(sin(a), 0, cos(a)) * r * 0.9
				K.stamp(st, _figure(), Transform3D(Basis(Vector3.UP, a + PI).scaled(Vector3.ONE * 1.6), at), 0.02 * float(i), 1.0)
			_cache.court = K.finish(st, Vector3.ONE * 3.0)
		K.put(temple, K.SOLID, _cache.court, "EclipseCourt", Vector3.ZERO, Vector3.ONE, 0.8, {"from": Vector3.ZERO, "rim_color": CRIMSON, "rim": 1.3, "glow_color": Color("ff6a7a"), "dim": 0.8}, {"fade_in": 0.01, "decay": 0.5})
		K.put(temple, K.FLAT, K.shock("eclipse_shock2", _c(VIOLET, 0.9), 0.1), "EclipseShock2", Vector3.UP * 0.1, Vector3.ONE * r * 1.6, 0.9, {"soft": 1.2, "add": 0.6}, {"delay": swing * 0.5 + 0.12, "initial": 0.1, "grow_time": 0.8, "decay": 0.3})
		temple._draw()
	return true
