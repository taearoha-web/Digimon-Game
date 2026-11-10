extends RefCounted
## Shared by the arcane god-tier signatures (celestial_dragon_emperor, abyssal_throne,
## divine_symphony). Cosmetic only. Every piece is still a StarSkillArt layer (one
## clock, the 2/4/6 layer cap, a VfxBudget decoration, freed with its root); the kit
## only swaps the layer's material for one of its own shaders:
##   SOLID  opaque vertex-coloured toon bodies (throne, crown, clouds, instruments)
##   PATH   a solid body laid along a spline (the dragon, chains, the staff ribbon)
##   GLOW   additive light (cores, shock rings, sprites)
##   VEIL   alpha-mixed smoke, dark fire, decals, pastel light
## Meshes are built once (Builder) and shared.
const SOLID := preload("res://shaders/god_arcane_solid.gdshader")
const PATH := preload("res://shaders/god_arcane_path.gdshader")
const GLOW := preload("res://shaders/god_arcane_glow.gdshader")
const VEIL := preload("res://shaders/god_arcane_veil.gdshader")
const DUMMY := {"primary": Color.WHITE, "accent": Color.WHITE, "shade": Color.BLACK}
const MAX_PTS := 72
const MAX_KEYS := 8
static var _cache := {}


static func cached(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


## Adds a layer to a StarSkillArt root drawn with one of the kit's shaders. Returns its
## material (null when the root's cap or the budget refused the layer).
static func put(art: StarSkillArt, shader: Shader, mesh: Mesh, label: String, at: Vector3, size: Vector3, angles: Vector3, seconds: float, style := {}, params := {}) -> ShaderMaterial:
	if art == null or mesh == null:
		return null
	var before := art.layers.size()
	var st := style.duplicate()
	if not st.has("initial"): st["initial"] = 1.0
	if not st.has("decay"): st["decay"] = 0.86
	art.add_mesh(mesh, label, DUMMY, at, size, angles, seconds, st)
	if art.layers.size() == before:
		return null
	var node: MeshInstance3D = art.layers[before].node
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.render_priority = (node.material_override as ShaderMaterial).render_priority
	mat.set_shader_parameter("t0", art.age + float(st.get("delay", 0.0)))
	mat.set_shader_parameter("fade", 0.0)
	for key in params:
		mat.set_shader_parameter(key, params[key])
	node.material_override = mat
	if st.has("cull"): node.extra_cull_margin = float(st.cull)
	return mat


## An extra root of the cast at [param point], facing away from [param source].
static func root(parent: Node3D, point: Vector3, seconds: float, label: String, source: Vector3, owner: StarSkillArt = null) -> StarSkillArt:
	return GodSkillArt._extra(parent, point, seconds, label, source, owner)


static func quality() -> int:
	return VfxBudget.quality()


## Evenly spaced points along a polyline, [param spacing] metres apart.
static func resample(line: PackedVector3Array, spacing: float) -> PackedVector3Array:
	var out := PackedVector3Array([line[0]])
	var carry := 0.0
	for i in range(1, line.size()):
		var a := line[i - 1]
		var b := line[i]
		var length := a.distance_to(b)
		while carry + length >= spacing:
			var f := (spacing - carry) / length
			a = a.lerp(b, f)
			out.append(a)
			length = a.distance_to(b)
			carry = 0.0
		carry += length
	return out


## Shader parameters of a PATH layer: [param points] evenly [param spacing] apart
## (resample), the slice [first, last] of them, and the head's (time, metres from the
## slice's first point) keys.
static func path_params(points: PackedVector3Array, spacing: float, first: int, last: int, keys: Array) -> Dictionary:
	first = clampi(first, 0, points.size() - 2)
	last = clampi(last, first + 1, mini(points.size() - 1, first + MAX_PTS - 1))
	var pts := PackedVector3Array()
	pts.resize(MAX_PTS)
	for i in MAX_PTS:
		pts[i] = points[mini(first + i, last)]
	var key_t := PackedFloat32Array()
	var key_h := PackedFloat32Array()
	key_t.resize(MAX_KEYS)
	key_h.resize(MAX_KEYS)
	for i in MAX_KEYS:
		var key: Array = keys[mini(i, keys.size() - 1)]
		key_t[i] = float(key[0]) + (0.0 if i < keys.size() else 1000.0 + i)
		key_h[i] = float(key[1]) - float(first) * spacing
	return {"pts": pts, "count": last - first + 1, "spacing": spacing, "key_t": key_t, "key_h": key_h, "keys": mini(keys.size(), MAX_KEYS)}


# ---------------------------------------------------------------------------
# Shared light pieces
# ---------------------------------------------------------------------------
## A unit quad in XY (billboards, soft sprites with the shader's radial falloff).
static func sprite() -> ArrayMesh:
	return cached("sprite", func():
		var b := Builder.new()
		b.quad(Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(1, 1, 0), Vector3(-1, 1, 0), Color.WHITE)
		return b.mesh())


## A flat soft ring of radius 1 on the ground: clear inside, a bright crest, a soft skirt.
static func shock(inner: Color, crest: Color, outer: Color) -> ArrayMesh:
	return cached("shock_%s_%s_%s" % [inner.to_html(), crest.to_html(), outer.to_html()], func():
		var b := Builder.new()
		var clear := Color(inner, 0.0)
		b.annulus(0.55, 0.8, 40, clear, inner)
		b.annulus(0.8, 0.93, 40, inner, crest)
		b.annulus(0.93, 1.0, 40, crest, outer)
		b.annulus(1.0, 1.12, 40, outer, Color(outer, 0.0))
		return b.mesh())


## The small ground indicator of the hit area (radius 1): a thin bright line, a faint
## skirt inside it and a ring of tick marks.
static func area_mark(line: Color, wash: Color) -> ArrayMesh:
	return cached("area_%s_%s" % [line.to_html(), wash.to_html()], func():
		var b := Builder.new()
		b.annulus(0.80, 0.965, 48, Color(wash, 0.0), Color(wash, 0.34))
		b.annulus(0.965, 0.985, 48, Color(line, 0.9), Color(line, 1.0))
		b.annulus(0.985, 1.0, 48, Color(line, 1.0), Color(line, 0.0))
		for i in 24:
			var a := TAU * i / 24.0
			var out := Vector3(sin(a), 0, cos(a))
			var side := Vector3(out.z, 0, -out.x)
			var long := 0.07 if i % 6 == 0 else 0.035
			b.quad(out * (1.02) - side * 0.008, out * (1.02) + side * 0.008, out * (1.02 + long) + side * 0.002, out * (1.02 + long) - side * 0.002, Color(line, 0.95), Color(line, 0.5))
		return b.mesh())


## An open column of radius 1 and height 1 (fire pillars, beams): the colours run up it.
static func column(key: String, stops: Array, top_radius := 1.0, segs := 14) -> ArrayMesh:
	return cached("column_" + key, func():
		var b := Builder.new()
		var profile := []
		for i in stops.size():
			var f := float(i) / float(stops.size() - 1)
			profile.append([lerpf(1.0, top_radius, f), f, stops[i]])
		b.lathe(profile, segs)
		return b.mesh())


## Mesh builder: positions, explicit normals, vertex colours, UV, UV2 (emission, flap
## weight) and the two burst attributes.
class Builder:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var ix := PackedInt32Array()
	## Applied to everything added.
	var xf := Transform3D.IDENTITY
	var emit := 0.0
	var weight := 0.0
	## >= 0: stored in the colour's alpha (the flap phase of SOLID pieces).
	var phase := -1.0
	var vel := Vector3.ZERO
	var wait := 0.0
	var pivot := Vector3.ZERO
	var tumble := 0.0
	var customs := false

	## The next primitives are one burst piece centred on [param at].
	func piece(at: Vector3, velocity: Vector3, delay := 0.0, spin := 0.0, basis := Basis.IDENTITY) -> void:
		xf = Transform3D(basis, at)
		pivot = at
		vel = velocity
		wait = delay
		tumble = spin
		customs = true

	func pt(pos: Vector3, nor: Vector3, col: Color, tex := Vector2.ZERO) -> int:
		v.append(xf * pos)
		n.append((xf.basis * nor).normalized())
		if phase >= 0.0: col.a = phase
		c.append(col)
		uv.append(tex)
		uv2.append(Vector2(emit, weight))
		c0.append(vel.x); c0.append(vel.y); c0.append(vel.z); c0.append(wait)
		c1.append(pivot.x); c1.append(pivot.y); c1.append(pivot.z); c1.append(tumble)
		return v.size() - 1

	func tri(a: int, b: int, d: int) -> void:
		ix.append(a); ix.append(b); ix.append(d)

	## p0 p1 along the bottom, p2 p3 back along the top; col1 colours the top edge.
	func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col0: Color, col1: Variant = null) -> void:
		var nor := (p1 - p0).cross(p3 - p0).normalized()
		var top: Color = col0 if col1 == null else col1
		var a := pt(p0, nor, col0, Vector2(0, 0))
		var b := pt(p1, nor, col0, Vector2(1, 0))
		var d := pt(p2, nor, top, Vector2(1, 1))
		var e := pt(p3, nor, top, Vector2(0, 1))
		tri(a, b, d); tri(a, d, e)

	func tri3(p0: Vector3, p1: Vector3, p2: Vector3, col0: Color, col1: Variant = null, col2: Variant = null) -> void:
		var nor := (p1 - p0).cross(p2 - p0).normalized()
		var a := pt(p0, nor, col0, Vector2(0, 0))
		var b := pt(p1, nor, col0 if col1 == null else col1, Vector2(1, 0))
		var d := pt(p2, nor, col0 if col2 == null else col2, Vector2(0.5, 1))
		tri(a, b, d)

	## A flat fan polygon (points in order round the hub points[0]).
	func fan(points: Array, col: Color, rim: Variant = null) -> void:
		var edge: Color = col if rim == null else rim
		var nor := ((points[1] as Vector3) - (points[0] as Vector3)).cross((points[2] as Vector3) - (points[0] as Vector3)).normalized()
		var hub := pt(points[0], nor, col, Vector2(0.5, 0.5))
		var prev := pt(points[1], nor, edge)
		for i in range(2, points.size()):
			var next := pt(points[i], nor, edge)
			tri(hub, prev, next)
			prev = next

	static func _frame(tangent: Vector3, up: Vector3) -> Array:
		var ref := up
		if absf(tangent.dot(ref)) > 0.95: ref = Vector3.RIGHT if absf(tangent.x) < 0.9 else Vector3.BACK
		var side := ref.cross(tangent).normalized()
		return [side, tangent.cross(side).normalized()]

	## A tube along [param path]. radii[i]: float or Vector2(side, up). cols[i]: Color or
	## [top, bottom]. flat: faceted. UV = (metres along, angle / TAU).
	func tube(path: Array, radii: Array, sides: int, cols: Array, up := Vector3.UP, caps := true, flat := false) -> void:
		var rings := []
		var along := 0.0
		for i in path.size():
			var here: Vector3 = path[i]
			var prev: Vector3 = path[maxi(i - 1, 0)]
			var next: Vector3 = path[mini(i + 1, path.size() - 1)]
			if i > 0: along += here.distance_to(prev)
			var frame := _frame((next - prev).normalized(), up)
			var r: Variant = radii[mini(i, radii.size() - 1)]
			var rx := float(r.x) if r is Vector2 else float(r)
			var ry := float(r.y) if r is Vector2 else float(r)
			var col: Variant = cols[mini(i, cols.size() - 1)]
			var ring := []
			for j in sides + 1:
				var a := TAU * j / float(sides)
				var pos: Vector3 = here + frame[0] * cos(a) * rx + frame[1] * sin(a) * ry
				var nor: Vector3 = (frame[0] * cos(a) * maxf(ry, 0.001) + frame[1] * sin(a) * maxf(rx, 0.001)).normalized()
				var tone: Color = (col[1] as Color).lerp(col[0], smoothstep(-0.55, 0.1, sin(a))) if col is Array else col
				ring.append([pos, nor, tone, Vector2(along, float(j) / sides)])
			rings.append(ring)
		for i in rings.size() - 1:
			if flat:
				for j in sides:
					var a0: Array = rings[i][j]
					var a1: Array = rings[i][j + 1]
					var b0: Array = rings[i + 1][j]
					var b1: Array = rings[i + 1][j + 1]
					if (b0[0] as Vector3).distance_to(b1[0]) < 0.0005:
						tri3(a0[0], a1[0], b0[0], a0[2], a1[2], b0[2])
					else:
						quad(a0[0], a1[0], b1[0], b0[0], a0[2], b0[2])
			else:
				var base := v.size()
				for ring in [rings[i], rings[i + 1]]:
					for q in ring:
						pt(q[0], q[1], q[2], q[3])
				for j in sides:
					var a := base + j
					var b := base + sides + 1 + j
					tri(a, a + 1, b + 1); tri(a, b + 1, b)
		if caps:
			for end in [0, rings.size() - 1]:
				var ring: Array = rings[end]
				if (ring[0][0] as Vector3).distance_to(path[end]) < 0.01: continue
				var points := [path[end]]
				for q in ring: points.append(q[0])
				fan(points, ring[0][2])

	func cone(base: Vector3, tip: Vector3, radius: Variant, sides: int, col_base: Color, col_tip: Variant = null, up := Vector3.UP, flat := false) -> void:
		tube([base, tip], [radius, 0.0], sides, [col_base, col_base if col_tip == null else col_tip], up, true, flat)

	## An axis-aligned box (use xf to turn it); top: the colour of its upper face ring.
	func box(center: Vector3, size: Vector3, col: Color, top: Variant = null) -> void:
		var h := size * 0.5
		var hi: Color = col if top == null else top
		var p := []
		for s in [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1], [-1, 1, -1], [1, 1, -1], [1, 1, 1], [-1, 1, 1]]:
			p.append(center + Vector3(s[0], s[1], s[2]) * h)
		quad(p[3], p[2], p[1], p[0], col)
		quad(p[4], p[5], p[6], p[7], hi)
		quad(p[0], p[1], p[5], p[4], col, hi)
		quad(p[1], p[2], p[6], p[5], col, hi)
		quad(p[2], p[3], p[7], p[6], col, hi)
		quad(p[3], p[0], p[4], p[7], col, hi)

	func ball(center: Vector3, radius: Vector3, top: Color, bottom: Color, lon := 8, lat := 5) -> void:
		var base := v.size()
		for i in lat + 1:
			var th := PI * i / float(lat)
			for j in lon + 1:
				var ph := TAU * j / float(lon)
				var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				pt(center + d * radius, (d / radius).normalized(), bottom.lerp(top, d.y * 0.5 + 0.5), Vector2(float(j) / lon, float(i) / lat))
		for i in lat:
			for j in lon:
				var a := base + i * (lon + 1) + j
				var b := a + lon + 1
				tri(a, a + 1, b + 1); tri(a, b + 1, b)

	## A flat ring in XZ at height y, from angle a0 to a1. UV = (turn, 0 inner .. 1 outer).
	func annulus(r0: float, r1: float, segs: int, col0: Color, col1: Color, y := 0.0, a0 := 0.0, a1 := TAU) -> void:
		var base := v.size()
		for j in segs + 1:
			var f := float(j) / segs
			var a := lerpf(a0, a1, f)
			var d := Vector3(sin(a), 0, cos(a))
			pt(d * r0 + Vector3.UP * y, Vector3.UP, col0, Vector2(f, 0))
			pt(d * r1 + Vector3.UP * y, Vector3.UP, col1, Vector2(f, 1))
		for j in segs:
			var a := base + j * 2
			tri(a, a + 1, a + 3); tri(a, a + 3, a + 2)

	## A surface of revolution round Y. profile[i] = [radius, y, Color]. UV = (turn, row).
	## bend: the top leans this far over (flames).
	func lathe(profile: Array, segs: int, a0 := 0.0, a1 := TAU, bend := Vector3.ZERO) -> void:
		var base := v.size()
		var rows := profile.size()
		var tall := maxf(0.001, absf(float(profile[rows - 1][1]) - float(profile[0][1])))
		for i in rows:
			var here: Array = profile[i]
			var prev: Array = profile[maxi(i - 1, 0)]
			var next: Array = profile[mini(i + 1, rows - 1)]
			var slope := Vector2(float(next[1]) - float(prev[1]), -(float(next[0]) - float(prev[0]))).normalized()
			for j in segs + 1:
				var f := float(j) / segs
				var a := lerpf(a0, a1, f)
				var d := Vector3(sin(a), 0, cos(a))
				var lean := bend * pow(absf(float(here[1]) - float(profile[0][1])) / tall, 1.6)
				pt(d * float(here[0]) + Vector3.UP * float(here[1]) + lean, (d * slope.x + Vector3.UP * slope.y).normalized(), here[2], Vector2(f, float(i) / float(rows - 1)))
		for i in rows - 1:
			for j in segs:
				var a := base + i * (segs + 1) + j
				var b := a + segs + 1
				tri(a, a + 1, b + 1); tri(a, b + 1, b)

	## A faceted double pyramid (shards, gems, embers).
	func gem(center: Vector3, half: Vector3, col: Color, tip: Variant = null, sides := 4) -> void:
		var up: Color = col if tip == null else tip
		for j in sides:
			var a := TAU * j / float(sides)
			var b := TAU * (j + 1) / float(sides)
			var p := center + Vector3(cos(a) * half.x, 0, sin(a) * half.z)
			var q := center + Vector3(cos(b) * half.x, 0, sin(b) * half.z)
			tri3(p, q, center + Vector3.UP * half.y, col, col, up)
			tri3(q, p, center - Vector3.UP * half.y, col, col, col.darkened(0.25))

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_INDEX] = ix
		var flags := 0
		if customs:
			arrays[Mesh.ARRAY_CUSTOM0] = c0
			arrays[Mesh.ARRAY_CUSTOM1] = c1
			flags = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		return out


## A dense Catmull-Rom polyline through [param points] ([param steps] per span).
static func smooth(points: Array, steps := 8) -> PackedVector3Array:
	var out := PackedVector3Array()
	var last := points.size() - 1
	for i in last:
		var p0: Vector3 = points[maxi(i - 1, 0)]
		var p1: Vector3 = points[i]
		var p2: Vector3 = points[i + 1]
		var p3: Vector3 = points[mini(i + 2, last)]
		for k in steps:
			var f := float(k) / steps
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f))
	out.append(points[last])
	return out


## A crescent in the builder's XZ plane: an arc of radius r from a0 to a1, widest
## ([param width]) in the middle, pointed at both ends; col_in at its inner edge.
static func crescent(b: Builder, r: float, width: float, a0: float, a1: float, col_in: Color, col_out: Color, segs := 14, y := 0.0) -> void:
	var base := b.v.size()
	for j in segs + 1:
		var f := float(j) / segs
		var a := lerpf(a0, a1, f)
		var w := sin(PI * f)
		var d := Vector3(sin(a), 0, cos(a))
		b.pt(d * (r - width * w) + Vector3.UP * y, Vector3.UP, col_in, Vector2(f, 0))
		b.pt(d * (r - width * w * 0.25) + Vector3.UP * y, Vector3.UP, col_out, Vector2(f, 0.7))
		b.pt(d * (r + width * w * 0.08) + Vector3.UP * y, Vector3.UP, Color(col_out, 0.0), Vector2(f, 1))
	for j in segs:
		var a := base + j * 3
		b.tri(a, a + 1, a + 4); b.tri(a, a + 4, a + 3)
		b.tri(a + 1, a + 2, a + 5); b.tri(a + 1, a + 5, a + 4)


## A jagged bolt from [param from] to [param to]: two crossed ribbons, a hot core and soft edges.
static func bolt(b: Builder, from: Vector3, to: Vector3, width: float, core: Color, edge: Color, rng: RandomNumberGenerator, kinks := 7, jitter := 0.9) -> void:
	var pts := [from]
	var dir := to - from
	var side := dir.cross(Vector3.RIGHT if absf(dir.normalized().x) < 0.8 else Vector3.BACK).normalized()
	var other := dir.cross(side).normalized()
	for i in range(1, kinks):
		var f := float(i) / kinks
		pts.append(from + dir * f + (side * rng.randf_range(-1, 1) + other * rng.randf_range(-1, 1)) * jitter * (1.0 - absf(f - 0.5)))
	pts.append(to)
	for axis in [side, other]:
		for i in pts.size() - 1:
			var p: Vector3 = pts[i]
			var q: Vector3 = pts[i + 1]
			var w0 := width * (1.0 - 0.5 * float(i) / pts.size())
			var w1 := width * (1.0 - 0.5 * float(i + 1) / pts.size())
			for s in [-1.0, 1.0]:
				b.quad(p, q, q + axis * w1 * s, p + axis * w0 * s, core, Color(edge, 0.0))


## Small diamonds of light thrown up from a 2.6 m disc (burst): embers, sparks.
static func embers(key: String, tones: Array, count := 30, rise := 4.0, spread := 3.0) -> ArrayMesh:
	return cached("embers_" + key, func():
		var b := Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		for i in count:
			var a := rng.randf() * TAU
			var out := Vector3(sin(a), 0, cos(a))
			b.piece(out * rng.randf_range(0.3, 2.6) + Vector3.UP * rng.randf_range(0.0, 1.0), out * rng.randf_range(0.5, spread) + Vector3.UP * rng.randf_range(0.5, 1.5) * rise, rng.randf_range(0.0, 0.25), rng.randf_range(2.0, 6.0))
			var size := rng.randf_range(0.09, 0.2)
			var tone: Color = tones[i % tones.size()]
			b.gem(Vector3.ZERO, Vector3(size, size * 1.7, size), tone, tone.lerp(Color.WHITE, 0.5))
		return b.mesh())


## Faceted shards thrown up and tumbling from the centre (burst, SOLID).
static func debris(key: String, tones: Array, count := 30, size := 0.4) -> ArrayMesh:
	return cached("debris_" + key, func():
		var b := Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 31
		for i in count:
			var a := rng.randf() * TAU
			var out := Vector3(sin(a), 0, cos(a))
			b.piece(out * rng.randf_range(0.2, 1.2), out * rng.randf_range(2.5, 7.5) + Vector3.UP * rng.randf_range(6.0, 13.0), rng.randf_range(0.0, 0.1), rng.randf_range(5.0, 12.0), Basis(Vector3(1, 0.3, 0.2).normalized(), rng.randf() * TAU))
			var tone: Color = tones[i % tones.size()]
			var s := size * rng.randf_range(0.6, 1.2)
			b.gem(Vector3.ZERO, Vector3(s * 0.6, s * 1.4, s * 0.5), tone, tone.lerp(Color.WHITE, 0.35), 3)
		return b.mesh())


## Jagged cracks of reach 1 round a scorched bowl: dark with a lit heart.
static func cracks(key: String, dark: Color, lit: Color, rays := 11, bowl := 0.42) -> ArrayMesh:
	return cached("cracks_" + key, func():
		var b := Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 13
		if bowl > 0.0:
			b.annulus(0.0, bowl, 20, Color(dark, 0.8), Color(dark, 0.6))
			b.annulus(bowl, bowl * 1.7, 20, Color(dark, 0.6), Color(dark, 0.0))
		for i in rays:
			var a := TAU * i / float(rays) + rng.randf_range(-0.15, 0.15)
			var reach := rng.randf_range(0.6, 1.0)
			var here := Vector3(sin(a), 0, cos(a)) * 0.1
			var width := 0.055
			for k in 5:
				a += rng.randf_range(-0.3, 0.3)
				var next := here + Vector3(sin(a), 0, cos(a)) * reach / 5.0
				var side := Vector3(cos(a), 0, -sin(a))
				var thin := width * (1.0 - (k + 1) / 5.0)
				var up := Vector3.UP * 0.005
				b.quad(here - side * width + up, here + side * width + up, next + side * thin + up, next - side * thin + up, Color(dark, 0.95))
				b.quad(here - side * width * 0.45 + up * 2.4, here + side * width * 0.45 + up * 2.4, next + side * thin * 0.45 + up * 2.4, next - side * thin * 0.45 + up * 2.4, lit, Color(lit, 0.85))
				here = next
				width = thin
		return b.mesh())
