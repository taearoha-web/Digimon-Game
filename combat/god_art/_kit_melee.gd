extends RefCounted
## Shared kit of the melee god skills (divine_edict, heavenrend_spear, pantheon_bastion,
## death_gods_eclipse): solid set pieces, light / shadow strokes and debris bursts.
##
## Every piece is ONE layer of a StarSkillArt root (so the 2/4/6 layer cap, the VfxBudget
## decoration count, the root's clock and its clean-up all still apply) whose material is
## swapped for one of three small shaders:
##   SOLID  opaque cel-shaded bodies with a rim light; a whole formation falls or rises
##          in the vertex stage (per-piece delay and distance in UV2)
##   FLAT   light and shadow strokes (pre-multiplied: bright adds, dark covers)
##   BITS   a burst of debris / embers / feathers thrown, spun and landed in the vertex stage
## Meshes are built once from code and shared by every cast (cached statics).
const SOLID := preload("res://shaders/god_melee_solid.gdshader")
const FLAT := preload("res://shaders/god_melee_flat.gdshader")
const BITS := preload("res://shaders/god_melee_bits.gdshader")
const WHITE := {"primary": Color.WHITE, "accent": Color.WHITE, "shade": Color.WHITE}
const KEY_LIGHT := Vector3(-0.35, 0.8, 0.5)
static var _meshes := {}


## A soup of coloured triangles under a transform: the building block of every solid.
class Part:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var g := PackedFloat32Array()
	var x := Transform3D.IDENTITY
	var col := Color.WHITE
	var glow := 0.0

	## Colour of what follows; [param shine] is the specular glint, [param inlay] how much it glows.
	func ink(color: Color, shine := 0.0, inlay := 0.0) -> Part:
		col = Color(color.r, color.g, color.b, shine)
		glow = inlay
		return self

	func tri(a: Vector3, b: Vector3, d: Vector3) -> void:
		if a.is_equal_approx(b) or b.is_equal_approx(d) or a.is_equal_approx(d):
			return
		for p in [a, b, d]:
			v.append(x * p)
			c.append(col)
			g.append(glow)

	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3) -> void:
		tri(a, b, d)
		tri(a, d, e)

	## An n-sided frustum from p0 (radius r0) to p1 (radius r1); flat squashes its section.
	func tube(p0: Vector3, p1: Vector3, r0: float, r1: float, sides := 6, flat := 1.0, caps := true, roll := 0.0) -> void:
		var axis := (p1 - p0).normalized()
		var u := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
		var w := axis.cross(u)
		var a0: Array[Vector3] = []
		var a1: Array[Vector3] = []
		for i in sides:
			var a := TAU * float(i) / float(sides) + roll
			var d := u * cos(a) + w * sin(a) * flat
			a0.append(p0 + d * r0)
			a1.append(p1 + d * r1)
		for i in sides:
			var j := (i + 1) % sides
			quad(a0[i], a0[j], a1[j], a1[i])
			if caps:
				tri(p0, a0[j], a0[i])
				tri(p1, a1[i], a1[j])

	func box(center: Vector3, size: Vector3) -> void:
		var h := size * 0.5
		var p: Array[Vector3] = []
		for i in 8:
			p.append(center + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
		quad(p[0], p[1], p[3], p[2])
		quad(p[4], p[6], p[7], p[5])
		quad(p[0], p[4], p[5], p[1])
		quad(p[2], p[3], p[7], p[6])
		quad(p[0], p[2], p[6], p[4])
		quad(p[1], p[5], p[7], p[3])

	## An octahedron.
	func gem(center: Vector3, size: Vector3) -> void:
		var top := center + Vector3.UP * size.y
		var bottom := center - Vector3.UP * size.y
		var ring: Array[Vector3] = [center + Vector3(size.x, 0, 0), center + Vector3(0, 0, size.z), center - Vector3(size.x, 0, 0), center - Vector3(0, 0, size.z)]
		for i in 4:
			tri(top, ring[i], ring[(i + 1) % 4])
			tri(bottom, ring[(i + 1) % 4], ring[i])

	## A low-poly ball.
	func ball(center: Vector3, size: Vector3, sides := 7, rings := 4) -> void:
		for r in rings:
			var a0 := PI * float(r) / float(rings)
			var a1 := PI * float(r + 1) / float(rings)
			for s in sides:
				var b0 := TAU * float(s) / float(sides)
				var b1 := TAU * float(s + 1) / float(sides)
				var p00 := center + Vector3(sin(a0) * cos(b0), cos(a0), sin(a0) * sin(b0)) * size
				var p01 := center + Vector3(sin(a0) * cos(b1), cos(a0), sin(a0) * sin(b1)) * size
				var p10 := center + Vector3(sin(a1) * cos(b0), cos(a1), sin(a1) * sin(b0)) * size
				var p11 := center + Vector3(sin(a1) * cos(b1), cos(a1), sin(a1) * sin(b1)) * size
				quad(p00, p01, p11, p10)

	## A polygon in the XY plane (fanned from its centroid) extruded from z0 to z1.
	func slab(outline: PackedVector2Array, z0: float, z1: float) -> void:
		var mid := Vector2.ZERO
		for p in outline:
			mid += p
		mid /= float(outline.size())
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			tri(Vector3(mid.x, mid.y, z1), Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z1))
			tri(Vector3(mid.x, mid.y, z0), Vector3(b.x, b.y, z0), Vector3(a.x, a.y, z0))
			quad(Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1))

	func add(other: Part, xf := Transform3D.IDENTITY) -> void:
		for i in other.v.size():
			v.append(x * (xf * other.v[i]))
			c.append(other.c[i])
			g.append(other.g[i])


# ---------------------------------------------------------------------------
# Mesh building
# ---------------------------------------------------------------------------
## A SOLID mesh: faceted like cut steel and stone, or [param smooth] for clouds and smoke.
static func begin(smooth := false) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if not smooth:
		st.set_smooth_group(-1)
	return st


## Adds a Part to a SOLID mesh; the piece starts moving at [param delay] and travels
## [param fall] times the layer's `drop`.
static func stamp(st: SurfaceTool, part: Part, xf := Transform3D.IDENTITY, delay := 0.0, fall := 1.0) -> void:
	st.set_uv2(Vector2(delay, fall))
	for i in part.v.size():
		st.set_color(part.c[i])
		st.set_uv(Vector2(part.g[i], 0.0))
		st.add_vertex(xf * part.v[i])


## Commits a SOLID mesh (flat normals); the bounds are padded for what the shader moves.
static func finish(st: SurfaceTool, pad := Vector3.ZERO, normals := true) -> ArrayMesh:
	if normals:
		st.generate_normals()
	var mesh := st.commit()
	var box := mesh.get_aabb()
	box.position -= pad
	box.size += pad * 2.0
	mesh.custom_aabb = box
	return mesh


## A FLAT stroke along [param pts]: UV.x across, UV.y along (v0..v1). [param plain]: it
## keeps its own colour edge to edge (a black slash over its white-hot edge).
static func ribbon(st: SurfaceTool, pts: PackedVector3Array, width: float, color: Color, delay := 0.0, fall := 0.0, up := Vector3.UP, taper := 1.0, v0 := 0.0, v1 := 1.0, end_color := Color(0, 0, 0, -1), plain := false) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv2(Vector2(delay, fall))
	var n := pts.size()
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in n:
		var dir := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := dir.cross(up).normalized()
		var t := float(i) / float(n - 1)
		var w := width * 0.5 * lerpf(1.0, sin(t * PI) * 0.85 + 0.15, taper)
		left.append(pts[i] - side * w)
		right.append(pts[i] + side * w)
	for i in n - 1:
		var ta := float(i) / float(n - 1)
		var tb := float(i + 1) / float(n - 1)
		var ca := color if end_color.a < 0.0 else color.lerp(end_color, ta)
		var cb := color if end_color.a < 0.0 else color.lerp(end_color, tb)
		var va := lerpf(v0, v1, ta)
		var vb := lerpf(v0, v1, tb)
		if plain:
			va = -1.0 - va
			vb = -1.0 - vb
		for item in [[left[i], 0.0, va, ca], [right[i], 1.0, va, ca], [right[i + 1], 1.0, vb, cb], [left[i], 0.0, va, ca], [right[i + 1], 1.0, vb, cb], [left[i + 1], 0.0, vb, cb]]:
			st.set_color(item[3])
			st.set_uv(Vector2(item[1], item[2]))
			st.add_vertex(item[0])


## A FLAT ring on the ground (soft across its width); UV.y runs round it.
static func ring(st: SurfaceTool, radius: float, width: float, color: Color, y := 0.0, sides := 48, delay := 0.0, arc := TAU, start := 0.0) -> void:
	var pts := PackedVector3Array()
	for i in sides + 1:
		var a := start + arc * float(i) / float(sides)
		pts.append(Vector3(sin(a) * radius, y, cos(a) * radius))
	ribbon(st, pts, width, color, delay, 0.0, Vector3.UP, 0.0)


## A FLAT disc: full at the centre, soft to the rim. A negative [param fall] makes it a
## flash; [param plain] keeps its own colour (no hot core) and ignores the reveal.
static func disc(st: SurfaceTool, radius: float, color: Color, y := 0.0, sides := 32, delay := 0.0, normal := Vector3.UP, center := Vector3.ZERO, rim_color := Color(0, 0, 0, -1), fall := 0.0, plain := false) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv2(Vector2(delay, fall))
	var u := normal.cross(Vector3.FORWARD if absf(normal.z) < 0.9 else Vector3.RIGHT).normalized()
	var w := normal.cross(u)
	var mid := center + normal * y
	var edge := color if rim_color.a < 0.0 else rim_color
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		st.set_color(color)
		st.set_uv(Vector2(0.5, -1.0 if plain else 0.0))
		st.add_vertex(mid)
		st.set_color(edge)
		# With its own rim colour the disc is filled edge to edge (the colours do the falloff).
		st.set_uv(Vector2(0.0 if rim_color.a < 0.0 else 0.5, -1.0 if plain else 1.0))
		st.add_vertex(mid + (u * cos(a0) + w * sin(a0)) * radius)
		st.add_vertex(mid + (u * cos(a1) + w * sin(a1)) * radius)


## A FLAT upright beam: crossed quads, UV.x across, UV.y up.
static func beam(st: SurfaceTool, base: Vector3, height: float, width: float, color: Color, planes := 2, delay := 0.0, fall := 0.0, top_width := -1.0) -> void:
	var tw := width if top_width < 0.0 else top_width
	for k in planes:
		var a := PI * float(k) / float(planes)
		var side := Vector3(cos(a), 0, sin(a))
		var pts := PackedVector3Array([base, base + Vector3.UP * height])
		st.set_normal(Vector3.UP)
		st.set_uv2(Vector2(delay, fall))
		var p := [[base - side * width * 0.5, 0.0, 0.0], [base + side * width * 0.5, 1.0, 0.0], [pts[1] + side * tw * 0.5, 1.0, 1.0], [base - side * width * 0.5, 0.0, 0.0], [pts[1] + side * tw * 0.5, 1.0, 1.0], [pts[1] - side * tw * 0.5, 0.0, 1.0]]
		for item in p:
			st.set_color(color)
			st.set_uv(Vector2(item[1], item[2]))
			st.add_vertex(item[0])


## Adds one thrown piece to a BITS mesh: [param shape] (centred on its origin) starts at
## [param origin] with [param vel] after [param delay]; `piece` is the layer's piece size.
static func bit(st: SurfaceTool, shape: Part, origin: Vector3, vel: Vector3, delay: float, piece: float, xf := Basis.IDENTITY, tint := Color.WHITE) -> void:
	st.set_uv(Vector2(vel.x, vel.z))
	st.set_uv2(Vector2(vel.y, delay))
	for i in range(0, shape.v.size(), 3):
		var a := xf * shape.v[i]
		var b := xf * shape.v[i + 1]
		var d := xf * shape.v[i + 2]
		var shade := 0.62 + 0.38 * absf((b - a).cross(d - a).normalized().dot(KEY_LIGHT.normalized()))
		for k in 3:
			var off: Vector3 = [a, b, d][k]
			var length := off.length()
			var col := shape.c[i + k] * tint
			st.set_normal(off / length if length > 0.0001 else Vector3.UP)
			st.set_color(Color(col.r * shade, col.g * shade, col.b * shade, clampf(length / piece, 0.0, 1.0)))
			st.add_vertex(origin)


# ---------------------------------------------------------------------------
# Shared parts and meshes
# ---------------------------------------------------------------------------
## An irregular rock about 1 unit across.
static func rock(rng: RandomNumberGenerator, color: Color, light := 0.25) -> Part:
	var p := Part.new()
	var top := Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.35, 0.6), rng.randf_range(-0.15, 0.15))
	var bottom := Vector3(rng.randf_range(-0.1, 0.1), -rng.randf_range(0.3, 0.5), rng.randf_range(-0.1, 0.1))
	var around: Array[Vector3] = []
	for i in 5:
		var a := TAU * float(i) / 5.0 + rng.randf_range(-0.3, 0.3)
		around.append(Vector3(cos(a), rng.randf_range(-0.15, 0.15), sin(a)) * rng.randf_range(0.38, 0.6))
	for i in 5:
		p.ink(color.lightened(light * rng.randf()))
		p.tri(top, around[i], around[(i + 1) % 5])
		p.ink(color.darkened(0.25 * rng.randf()))
		p.tri(bottom, around[(i + 1) % 5], around[i])
	return p


## A jagged spike of rock standing on the origin, about 1 tall.
static func spike(rng: RandomNumberGenerator, color: Color, lean := 0.3) -> Part:
	var p := Part.new()
	var tip := Vector3(rng.randf_range(-lean, lean), 1.0, rng.randf_range(-lean, lean))
	var sides := 4 + rng.randi() % 2
	var base: Array[Vector3] = []
	for i in sides:
		var a := TAU * float(i) / float(sides) + rng.randf_range(-0.3, 0.3)
		base.append(Vector3(cos(a), -0.15, sin(a)) * Vector3(0.3, 1, 0.3) * rng.randf_range(0.8, 1.2))
	for i in sides:
		p.ink(color.lightened(0.22 * rng.randf()) if i % 2 == 0 else color.darkened(0.2 * rng.randf()))
		var j := (i + 1) % sides
		var knee := (base[i] + base[j]) * 0.5 * 0.9 + tip * 0.45
		p.tri(base[i], base[j], knee)
		p.tri(base[i], knee, tip)
		p.tri(knee, base[j], tip)
	return p


## A burst of debris thrown outward and up from a ring: one BITS mesh.
## colors: the chunks' colours; shape: "rock", "shard" (flat plates), "ember" (tiny gems),
## "puff" (dust balls), "scale" or "feather".
static func burst(key: String, shape: String, count: int, r0: float, r1: float, out: float, up: float, colors: Array, piece: float, spread := 0.0, seed_value := 1, y0 := 0.1, y1 := 0.3) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	burst_at(st, rng, shape, count, Vector3.ZERO, r0, r1, out, up, colors, piece, 0.0, spread, y0, y1)
	var mesh := finish(st, Vector3(out + r1 + 6.0, up * 0.2 + 8.0, out + r1 + 6.0), false)
	_meshes[key] = mesh
	return mesh


## Adds a burst round [param center] to a BITS mesh, thrown from [param delay].
static func burst_at(st: SurfaceTool, rng: RandomNumberGenerator, shape: String, count: int, center: Vector3, r0: float, r1: float, out: float, up: float, colors: Array, piece: float, delay := 0.0, spread := 0.0, y0 := 0.1, y1 := 0.3) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var dir := Vector3(sin(a), 0, cos(a))
		var origin := center + dir * lerpf(r0, r1, sqrt(rng.randf())) + Vector3.UP * rng.randf_range(y0, y1)
		var swirl := Vector3(dir.z, 0, -dir.x) * rng.randf_range(-0.3, 0.3)
		var vel := (dir + swirl) * out * rng.randf_range(0.45, 1.0) + Vector3.UP * up * rng.randf_range(0.5, 1.0)
		var color: Color = colors[rng.randi() % colors.size()]
		var size := piece * rng.randf_range(0.45, 1.0)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * size)
		bit(st, _bit_shape(shape, rng, color), origin, vel, delay + rng.randf() * spread, piece, basis)


static func _bit_shape(shape: String, rng: RandomNumberGenerator, color: Color) -> Part:
	var p := Part.new()
	match shape:
		"rock":
			return rock(rng, color)
		"puff":
			p.ink(color)
			p.ball(Vector3.ZERO, Vector3(0.5, 0.42, 0.5), 6, 3)
		"ember":
			p.ink(color)
			p.gem(Vector3.ZERO, Vector3(0.22, 0.5, 0.22))
		"shard":
			p.ink(color)
			p.tri(Vector3(-0.3, -0.4, 0), Vector3(0.35, -0.2, 0.04), Vector3(0.05, 0.5, 0))
			p.ink(color.darkened(0.3))
			p.tri(Vector3(-0.3, -0.4, -0.08), Vector3(0.05, 0.5, -0.08), Vector3(0.35, -0.2, -0.04))
		"scale":
			p.ink(color)
			p.tri(Vector3(0, 0.5, 0), Vector3(-0.3, 0, 0.06), Vector3(0, -0.5, 0))
			p.ink(color.lightened(0.25))
			p.tri(Vector3(0, 0.5, 0), Vector3(0, -0.5, 0), Vector3(0.3, 0, 0.06))
		"feather":
			# A quill with two vanes, a notch near the tip.
			p.ink(color)
			p.tri(Vector3(0, -0.5, 0), Vector3(-0.16, 0.0, 0.03), Vector3(0, 0.5, 0))
			p.tri(Vector3(0, -0.42, 0), Vector3(0, 0.5, 0), Vector3(0.14, 0.1, 0.03))
			p.ink(color.lightened(0.12))
			p.tri(Vector3(-0.16, 0.0, 0.03), Vector3(-0.1, 0.34, 0.02), Vector3(0, 0.5, 0))
	return p


## Fissures running out from the centre: FLAT strokes, UV.y = distance (the reveal runs outward).
static func cracks(key: String, rays: int, r0: float, r1: float, width: float, color: Color, seed_value := 1, branches := 2, jitter := 0.22) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	crack_star(st, rng, Vector3.ZERO, rays, r0, r1, width, color, 0.0, branches, jitter)
	var mesh := finish(st, Vector3.ONE * 0.5, false)
	_meshes[key] = mesh
	return mesh


## One star of fissures round [param center], lit from [param delay].
static func crack_star(st: SurfaceTool, rng: RandomNumberGenerator, center: Vector3, rays: int, r0: float, r1: float, width: float, color: Color, delay := 0.0, branches := 1, jitter := 0.22) -> void:
	for i in rays:
		var a := TAU * float(i) / float(rays) + rng.randf_range(-0.25, 0.25)
		var reach := lerpf(r0, r1, rng.randf_range(0.6, 1.0))
		_crack(st, rng, center, a, a, r0, reach, width, color, jitter, r1, delay)
		for b in branches:
			var from := lerpf(r0, reach, rng.randf_range(0.3, 0.7))
			_crack(st, rng, center, a, a + rng.randf_range(-0.6, 0.6), from, minf(r1, from + (reach - r0) * rng.randf_range(0.25, 0.5)), width * 0.6, color, jitter, r1, delay)


static func _crack(st: SurfaceTool, rng: RandomNumberGenerator, center: Vector3, a0: float, a1: float, from: float, to: float, width: float, color: Color, jitter: float, full: float, delay: float) -> void:
	var pts := PackedVector3Array()
	var steps := 6
	for i in steps + 1:
		var t := float(i) / float(steps)
		var r := lerpf(from, to, t)
		var a := lerpf(a0, a1, minf(1.0, t * 2.0)) + (0.0 if i == 0 else rng.randf_range(-jitter, jitter) / maxf(1.0, r * 0.7))
		pts.append(center + Vector3(sin(a) * r, 0, cos(a) * r))
	# Wide at the root, a hair at the far end.
	st.set_normal(Vector3.UP)
	st.set_uv2(Vector2(delay, 0.0))
	for i in steps:
		var ta := float(i) / float(steps)
		var tb := float(i + 1) / float(steps)
		var dir := (pts[i + 1] - pts[i]).normalized()
		var side := Vector3(dir.z, 0, -dir.x)
		var wa := width * 0.5 * (1.0 - ta * 0.85)
		var wb := width * 0.5 * (1.0 - tb * 0.85)
		var va := lerpf(from, to, ta) / full
		var vb := lerpf(from, to, tb) / full
		for item in [[pts[i] - side * wa, 0.0, va], [pts[i] + side * wa, 1.0, va], [pts[i + 1] + side * wb, 1.0, vb], [pts[i] - side * wa, 0.0, va], [pts[i + 1] + side * wb, 1.0, vb], [pts[i + 1] - side * wb, 0.0, vb]]:
			st.set_color(color)
			st.set_uv(Vector2(item[1], item[2]))
			st.add_vertex(item[0])


## A unit shock ring (radius 1): scale it up through the layer's "initial".
static func shock(key: String, color: Color, width := 0.22) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	ring(st, 1.0 - width * 0.5, width, color, 0.0, 56)
	var mesh := finish(st, Vector3.ONE * 0.2, false)
	_meshes[key] = mesh
	return mesh


## A soft disc of light or shadow of radius 1.
static func glow_disc(key: String, color: Color, rim_color := Color(0, 0, 0, -1)) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	disc(st, 1.0, color, 0.0, 40, 0.0, Vector3.UP, Vector3.ZERO, rim_color, 0.0, true)
	var mesh := finish(st, Vector3.ONE * 0.2, false)
	_meshes[key] = mesh
	return mesh


## The readable hit area: a thin double ring of radius 1 with ticks, in the skill's colour.
static func area_ring(key: String, color: Color, ticks := 24) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	ring(st, 1.0, 0.035, color, 0.0, 72)
	ring(st, 0.955, 0.012, Color(color.r, color.g, color.b, color.a * 0.6), 0.0, 72)
	for i in ticks:
		var a := TAU * float(i) / float(ticks)
		var dir := Vector3(sin(a), 0, cos(a))
		var long := 0.07 if i % 3 == 0 else 0.035
		ribbon(st, PackedVector3Array([dir * (0.94 - long), dir * 0.94]), 0.016, color, 0.0, 0.0, Vector3.UP, 0.0)
	var mesh := finish(st, Vector3.ONE * 0.2, false)
	_meshes[key] = mesh
	return mesh


# ---------------------------------------------------------------------------
# Layers
# ---------------------------------------------------------------------------
## Adds [param mesh] to [param art] as one layer drawn with [param shader]. params are the
## shader's uniforms (plus "priority"); style is the StarSkillArt layer style (delay,
## travel, spin, turn, initial, grow_time, decay, face_camera ...). Returns the material,
## or null when the root's cap or the budget refused the layer.
static func put(art: StarSkillArt, shader: Shader, mesh: Mesh, label: String, at: Vector3, size: Vector3, seconds: float, params := {}, style := {}, angles := Vector3.ZERO) -> ShaderMaterial:
	if art == null or mesh == null:
		return null
	var n := art.layers.size()
	var opts := {"initial": 1.0, "grow_time": 0.01, "fade_in": 0.02, "decay": 0.85}
	opts.merge(style, true)
	art.add_mesh(mesh, label, WHITE, at, size, angles, seconds, opts)
	if art.layers.size() == n:
		return null
	var node: MeshInstance3D = art.layers[n].node
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("t0", float(opts.get("delay", 0.0)))
	for key in params:
		if key == "priority":
			mat.render_priority = int(params[key])
		else:
			mat.set_shader_parameter(key, params[key])
	node.material_override = mat
	return mat


## A further root of the cast (GodSkillArt's own rule for how many a beat may open).
static func extra(parent: Node3D, point: Vector3, seconds: float, label: String, source: Vector3, owner: StarSkillArt = null) -> StarSkillArt:
	return GodSkillArt._extra(parent, point, seconds, label, source, owner)


static func radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 9.0)), 4.0, 10.0)


## The flat direction from the camera to [param art], in the root's own space (FORWARD
## when there is no camera): where "behind the caster" is for whoever is watching.
static func away(art: Node3D) -> Vector3:
	var camera := art.get_viewport().get_camera_3d() if art.is_inside_tree() else null
	if camera == null:
		return Vector3.FORWARD
	var flat := (art.global_position - camera.global_position) * Vector3(1, 0, 1)
	if flat.length() < 0.1:
		return Vector3.FORWARD
	return art.global_basis.inverse() * flat.normalized()


## A spot [param distance] beyond the root as the camera sees it: a colossal piece lands
## there, so the caster stands in front of it (the hit area stays centred on the root).
static func beyond(art: Node3D, distance: float) -> Vector3:
	return away(art) * distance


## The yaw that turns a piece's +Z face to the camera.
static func facing(art: Node3D) -> float:
	var dir := -away(art)
	return atan2(dir.x, dir.z)


## How a tall piece ([param height] m) standing at [param spot] (root space) stays inside
## the camera's frame: [scale, lean]. It first leans sideways across the screen (its whole
## length stays readable, and the screen is wider than it is tall), then it shrinks.
static func framed(art: Node3D, spot: Vector3, height: float, max_lean := 0.55, least := 0.6) -> Array:
	var room := GodSkillArt.headroom(art, art.to_global(spot) if art.is_inside_tree() else spot)
	if room >= height:
		return [1.0, 0.0]
	var lean := minf(max_lean, acos(clampf(room / height, 0.0, 1.0)))
	return [clampf(room / (height * cos(lean)), least, 1.0), lean]


## Euler angles of a piece turned by [param yaw] and then leaned [param lean] radians to the
## side as the camera sees it ([param side] +1: its top goes to the screen's right).
static func leaned(art: Node3D, yaw: float, lean: float, side := 1.0) -> Vector3:
	return (Basis(away(art), lean * side) * Basis(Vector3.UP, yaw)).get_euler()


## The sky a piece may use over [param spot] (root space): never more than [param design].
static func sky(art: Node3D, spot: Vector3, design: float) -> float:
	return minf(design, GodSkillArt.headroom(art, art.to_global(spot) if art.is_inside_tree() else spot))


## Euler angles of a piece lying flat (its face up) tipped [param tilt] radians towards
## the camera, so that its face shows from high up.
static func tipped(art: Node3D, tilt: float) -> Vector3:
	var axis := away(art).cross(Vector3.UP)
	return Basis(axis.normalized(), tilt).get_euler() if axis.length() > 0.01 else Vector3.ZERO
