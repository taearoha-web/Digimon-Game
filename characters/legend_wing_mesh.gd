class_name LegendWingMesh
extends RefCounted
## The meshes of the Legendary Guild Wings (LegendWingArt), built in code once per
## session and shared by every wearer: the right upper wing (the left one is the same
## mesh mirrored), the small lower wing and the guild's halo.
##
## Authored in metres at the hero's size with the origin on the wing's pivot: x out to
## the side, y up, z to the front (the wings spread behind, toward -z). Every feather is
## a three-column strip (edge, raised shaft, edge) whose UV runs across (u) and along
## (v, 0 at the root, 1 at the tip), so legend_wing.gdshader can ink its outline, light
## its shaft and make its tip glow without a texture. UV2 carries the part
## (floor(UV2.x), see ROW_*), a per-feather phase (fract(UV2.x)) and how far out the
## vertex sits (UV2.y, 0 at the pivot, 1 at the farthest tip: how much it ripples).
## COLOR is the tint (white, or the guild's colour on the gems).

const ROW_PRIMARY := 0
const ROW_SECONDARY := 1
const ROW_COVERT := 2
const ROW_LOWER := 3
const ROW_RING := 4
const ROW_RAYS := 5
const ROW_GEM := 6
## Rings along a feather (each ring: three vertices, four triangles to the next).
const STEPS := 9
## The upper wing's reach (the farthest tip), for UV2.y.
const REACH := 2.5
const LOWER_REACH := 0.9

## The upper wing's arm: a cubic curve from the shoulder up and out to the hand.
const ARM := [Vector2(0.0, -0.02), Vector2(0.44, 0.02), Vector2(0.86, 0.4), Vector2(1.1, 0.86)]
## Primaries from the hand outward: [arm position, angle (deg), length, width].
const PRIMARIES := [
	[1.0, 82.0, 1.3, 0.23], [0.965, 70.0, 1.48, 0.235], [0.925, 58.0, 1.56, 0.235], [0.88, 46.0, 1.5, 0.235],
	[0.83, 34.0, 1.38, 0.23], [0.78, 22.0, 1.22, 0.225], [0.73, 10.0, 1.06, 0.22], [0.68, -1.0, 0.92, 0.22],
	[0.63, -12.0, 0.8, 0.21]]
## Secondaries along the forearm, hanging down and out.
const SECONDARIES := [
	[0.58, -22.0, 0.86, 0.22], [0.52, -32.0, 0.84, 0.22], [0.46, -42.0, 0.8, 0.22], [0.4, -52.0, 0.74, 0.21],
	[0.34, -61.0, 0.66, 0.2], [0.28, -70.0, 0.56, 0.19]]
## The lower wing: [root, angle, length, width].
const LOWER := [[Vector2(0.06, 0.02), -6.0, 0.5, 0.15], [Vector2(0.07, 0.0), -19.0, 0.6, 0.16],
	[Vector2(0.07, -0.02), -32.0, 0.56, 0.15], [Vector2(0.06, -0.04), -45.0, 0.44, 0.14]]

static var _cache := {}


static func wing() -> ArrayMesh:
	if not _cache.has("wing"):
		_cache["wing"] = _build_wing()
	return _cache["wing"]


static func lower() -> ArrayMesh:
	if not _cache.has("lower"):
		_cache["lower"] = _build_lower()
	return _cache["lower"]


## The halo with the gems in guild g's colour.
static func halo(g: int) -> ArrayMesh:
	var key := "halo_%d" % g
	if not _cache.has(key):
		_cache[key] = _build_halo(GuildLeague.color_of(g) if g > 0 else Color("ffcf4a"))
	return _cache[key]


static func triangles(mesh: Mesh) -> int:
	var total := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		total += (idx as PackedInt32Array).size() / 3 if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


static func _arm(s: float) -> Vector2:
	var a: Vector2 = ARM[0]
	var b: Vector2 = ARM[1]
	var c: Vector2 = ARM[2]
	var d: Vector2 = ARM[3]
	var k := 1.0 - s
	return a * k * k * k + b * 3.0 * k * k * s + c * 3.0 * k * s * s + d * s * s * s


static func _arm_angle(s: float) -> float:
	var t := _arm(minf(s + 0.02, 1.0)) - _arm(maxf(s - 0.02, 0.0))
	return rad_to_deg(t.angle())


static func _build_wing() -> ArrayMesh:
	var st := _begin()
	# Back to front: primaries, secondaries, then the coverts over their roots (the
	# rows sit a little further back each, so the coverts lie on top seen from behind).
	for i in PRIMARIES.size():
		var p: Array = PRIMARIES[i]
		var root := _arm(p[0])
		_feather(st, root, p[1], p[2], p[3], -0.14, -0.006 * i, ROW_PRIMARY, REACH, float(i) / 9.0, 0.82)
	for i in SECONDARIES.size():
		var p: Array = SECONDARIES[i]
		_feather(st, _arm(p[0]), p[1], p[2], p[3], 0.06, -0.06 - 0.006 * i, ROW_SECONDARY, REACH, 0.13 + float(i) / 7.0, 0.9)
	# Coverts: two rows of short rounded feathers along the arm, the lesser row on the
	# leading edge over the greater one.
	var n := 9
	for i in n:
		var f := float(i) / float(n - 1)
		var s := lerpf(0.03, 0.97, f)
		var along := _arm_angle(s)
		var root := _arm(s) + Vector2.from_angle(deg_to_rad(along + 90.0)) * 0.04
		_feather(st, root, along - 64.0 - 12.0 * f, lerpf(0.36, 0.46, f), 0.24, 0.06, -0.12 - 0.005 * i, ROW_COVERT, REACH, f * 0.9 + 0.05, 1.0)
	n = 7
	for i in n:
		var f := float(i) / float(n - 1)
		var s := lerpf(0.02, 0.95, f)
		var along := _arm_angle(s)
		var root := _arm(s) + Vector2.from_angle(deg_to_rad(along + 90.0)) * 0.09
		_feather(st, root, along - 50.0, lerpf(0.22, 0.27, f), 0.21, 0.05, -0.17 - 0.005 * i, ROW_COVERT, REACH, f * 0.9 + 0.5, 1.0)
	return _commit(st)


static func _build_lower() -> ArrayMesh:
	var st := _begin()
	for i in LOWER.size():
		var p: Array = LOWER[i]
		_feather(st, p[0], p[1], p[2], p[3], -0.12, -0.006 * i, ROW_LOWER, LOWER_REACH, float(i) / 4.0, 0.85)
	for i in 3:
		_feather(st, Vector2(0.03, -0.01 * i), -14.0 - 16.0 * i, 0.26, 0.14, 0.05, -0.04 - 0.005 * i, ROW_COVERT, LOWER_REACH, 0.3 + 0.2 * i, 1.0)
	return _commit(st)


## A flat gold ring facing back with a crown of alternating long and short rays (the
## rays turn slowly in the shader), a big gem at the top and four small ones round it.
static func _build_halo(gem: Color) -> ArrayMesh:
	var st := _begin()
	var radius := 0.5
	var band := 0.06
	var seg := 40
	for i in seg + 1:
		var a := TAU * float(i) / float(seg)
		var dir := Vector3(cos(a), sin(a), 0.0)
		for k in 2:
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(float(k), float(i) / float(seg) * 6.0))
			st.set_uv2(Vector2(ROW_RING + 0.5, 0.5))
			st.set_normal(Vector3(0, 0, -1).lerp(dir * (1.0 if k == 1 else -1.0), 0.3).normalized())
			st.add_vertex(dir * (radius + (band * 0.5 if k == 1 else -band * 0.5)))
	for i in seg:
		var a0 := i * 2
		_quad(st, a0, a0 + 1, a0 + 3, a0 + 2)
	st.set_meta("count", (seg + 1) * 2)
	var rays := 16
	for i in rays:
		var a := TAU * (float(i) + 0.5) / float(rays)
		var long := i % 2 == 0
		var dir := Vector2.from_angle(a)
		_feather(st, dir * (radius + band * 0.3), rad_to_deg(a), 0.25 if long else 0.13, 0.085 if long else 0.065, 0.0, 0.004, ROW_RAYS, 1.0, float(i) / float(rays), 1.0, true)
	_gem(st, Vector3(0, radius + 0.02, -0.03), 0.09, gem)
	for a in [0.0, PI, -PI * 0.25, -PI * 0.75]:
		_gem(st, Vector3(cos(a), sin(a), 0) * radius + Vector3(0, 0, -0.025), 0.05, gem)
	return _commit(st)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _commit(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


static func _quad(st: SurfaceTool, a: int, b: int, c: int, d: int) -> void:
	st.add_index(a); st.add_index(b); st.add_index(c)
	st.add_index(a); st.add_index(c); st.add_index(d)


## One feather from `root` (2D, in the wing plane at depth z) at `angle` degrees,
## `length` long and `width` wide; `bend` curls the tip (negative: clockwise).
## `shape` < 1 makes the shaft side narrower toward the tip (a sharper feather).
static func _feather(st: SurfaceTool, root: Vector2, angle: float, length: float, width: float, bend: float, z: float,
		row: int, reach: float, phase: float, shape: float, pointed := false) -> void:
	var dir := Vector2.from_angle(deg_to_rad(angle))
	var side := Vector2(-dir.y, dir.x)
	var base := st.get_meta("count", 0) as int
	var ridge := width * (0.07 if row == ROW_COVERT else 0.16)
	var cup := 0.0 if row >= ROW_RING else 0.07
	for r in STEPS + 1:
		# Rings crowd toward the tip, so its curve stays round.
		var t := 1.0 - pow(1.0 - float(r) / float(STEPS), 1.5)
		var spine := root + dir * length * t + side * bend * length * t * t
		var tangent := (dir * length + side * 2.0 * bend * length * t).normalized()
		var across := Vector2(-tangent.y, tangent.x)
		var half := width * 0.5 * _profile(t, pointed)
		var across3 := Vector3(across.x, across.y, 0.0)
		var flex := clampf(spine.length() / reach, 0.0, 1.0)
		for k in 3:
			var off := float(k - 1)
			var w := half * (shape if k == 0 else 1.0) * absf(off)
			var p := spine + across * w * signf(off)
			var depth := z - (ridge * _profile(t, pointed) if k == 1 else 0.0) - cup * p.x * p.x
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(0.5 + 0.5 * off, t))
			st.set_uv2(Vector2(float(row) + clampf(phase, 0.0, 0.99), flex))
			st.set_normal((Vector3(0, 0, -1) + across3 * off * (0.25 if row == ROW_COVERT else 0.5)).normalized())
			st.add_vertex(Vector3(p.x, p.y, depth))
	for r in STEPS:
		var a := base + r * 3
		var b := a + 3
		_quad(st, a, a + 1, b + 1, b)
		_quad(st, a + 1, a + 2, b + 2, b + 1)
	st.set_meta("count", base + (STEPS + 1) * 3)


## Half-width along a feather: a slim quill, full by the middle, a rounded (or pointed) tip.
static func _profile(t: float, pointed: bool) -> float:
	if pointed:
		return clampf(1.0 - t, 0.0, 1.0) * (0.75 + 0.25 * (1.0 - t))
	var grow := lerpf(0.42, 1.0, smoothstep(0.0, 0.45, t))
	var tip := 1.0 if t < 0.64 else pow(maxf(0.0, 1.0 - pow((t - 0.64) / 0.36, 2.0)), 0.55)
	return grow * tip


## A cut gem: an eight-faced diamond facing back, coloured `color`.
static func _gem(st: SurfaceTool, at: Vector3, size: float, color: Color) -> void:
	var base := st.get_meta("count", 0) as int
	var pts := [Vector3(0, size, 0), Vector3(size * 0.75, 0, 0), Vector3(0, -size, 0), Vector3(-size * 0.75, 0, 0)]
	var apex := [Vector3(0, 0, -size * 0.6), Vector3(0, 0, size * 0.3)]
	var verts := 0
	for face in 2:
		for i in 4:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % 4]
			var c: Vector3 = apex[face]
			var normal := (a + b + c).normalized()
			for v in [a, b, c]:
				st.set_color(color)
				st.set_uv(Vector2(0.5, 0.5))
				st.set_uv2(Vector2(ROW_GEM + 0.5, 0.0))
				st.set_normal(normal)
				st.add_vertex(at + v)
			st.add_index(base + verts); st.add_index(base + verts + 1); st.add_index(base + verts + 2)
			verts += 3
	st.set_meta("count", base + verts)
