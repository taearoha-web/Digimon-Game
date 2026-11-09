class_name LegendWingMesh
extends RefCounted
## The meshes of the Legendary Guild Wings (LegendWingArt), built in code once per
## session and shared by every wearer: the right great wing and the right lower wing
## set (the middle and the small low tier; the left ones are the same meshes mirrored),
## the guild's floating crest crown and the royal sashes.
##
## No class pair looks like it: every feather is a faceted golden-crystal blade (a gold
## body, a white-hot middle, a flared crystal shoulder and a prismatic pointed tip that
## curls like a flame tongue), fanned out in three stacked tiers like a sunburst.
##
## Authored in metres at the hero's size with the origin on the piece's pivot: x out to
## the side, y up, z to the front (the wings spread behind, toward -z). Every blade is a
## three-column strip (edge, raised ridge, edge) whose UV runs across (u) and along
## (v, 0 at the root, 1 at the tip; the crystal shoulder sits at SHOULDER), so
## legend_wing.gdshader can ink, facet and colour it without a texture. UV2 carries the
## part (floor(UV2.x), see ROW_*), a per-piece phase (fract(UV2.x)) and how far out the
## vertex sits (UV2.y, 0 at the pivot, 1 at the farthest tip: how much it ripples or
## sways). COLOR is the tint (white, or the guild's colours on the crest).

const ROW_BLADE := 0
const ROW_SHARD := 1
const ROW_RIBBON := 3
const ROW_SPIKE := 4
const ROW_ENAMEL := 5
const ROW_GEM := 6
const ROW_TRIM := 7
## Where along a blade (v) the gold body ends and the crystal tip begins.
const SHOULDER := 0.6
## The rings along a blade (v) and its half-width there: a slim root, a full body, the
## flared crystal shoulder, then a straight taper to a sharp point.
const RINGS := [0.0, 0.14, 0.3, 0.46, 0.57, 0.6, 0.64, 0.78, 0.9, 1.0]
const PROFILE := [0.3, 0.66, 0.9, 0.94, 0.86, 1.14, 1.1, 0.66, 0.3, 0.0]
## The farthest tips (for UV2.y).
const REACH := 3.3
const LOWER_REACH := 2.7

## The great wing's arm: a cubic from the shoulder up and out to the hand.
const ARM := [Vector2(0.0, 0.0), Vector2(0.34, 0.08), Vector2(0.66, 0.5), Vector2(0.8, 1.12)]
## Its blades from the hand down the arm: [arm position, angle (deg), length, width].
const BLADES := [
	[1.0, 98.0, 1.7, 0.27], [0.95, 87.0, 2.05, 0.29], [0.89, 76.0, 2.2, 0.3], [0.82, 65.0, 2.15, 0.3],
	[0.74, 54.0, 2.0, 0.29], [0.66, 44.0, 1.82, 0.28], [0.57, 34.0, 1.6, 0.27], [0.47, 25.0, 1.36, 0.26]]
## The middle tier fans straight out to the side: [arm x, angle, length, width].
const MID := [[0.86, 30.0, 1.75, 0.27], [0.78, 18.0, 1.95, 0.28], [0.68, 6.0, 1.95, 0.28], [0.57, -6.0, 1.8, 0.27],
	[0.46, -18.0, 1.6, 0.26], [0.35, -30.0, 1.36, 0.25], [0.24, -42.0, 1.1, 0.23]]
## The small low tier hangs down and out under it: [root, angle, length, width].
const LOW := [[Vector2(0.32, -0.2), -48.0, 0.74, 0.19], [Vector2(0.25, -0.24), -61.0, 0.76, 0.19],
	[Vector2(0.18, -0.26), -74.0, 0.66, 0.18], [Vector2(0.11, -0.26), -86.0, 0.52, 0.16]]

static var _cache := {}


## The right great wing (the top tier).
static func wing() -> ArrayMesh:
	if not _cache.has("wing"):
		_cache["wing"] = _build_wing()
	return _cache["wing"]


## The right middle and low tiers, one mesh.
static func lower() -> ArrayMesh:
	if not _cache.has("lower"):
		_cache["lower"] = _build_lower()
	return _cache["lower"]


## The floating crest crown in guild g's colours (CREST).
static func crown(g: int) -> ArrayMesh:
	var key := "crown_%d" % g
	if not _cache.has(key):
		var colors := crest_colors(g)
		_cache[key] = _build_crown(colors[0], colors[1])
	return _cache[key]


## Both sides' sashes of golden light, one mesh.
static func ribbons() -> ArrayMesh:
	if not _cache.has("ribbons"):
		_cache["ribbons"] = _build_ribbons()
	return _cache["ribbons"]


## The crest's [enamel field, emblem gem] for guild g: a deep jewel field under the
## guild's own bright colour. Alpha's gold would vanish on gold, so its sun-gold gem
## sits on royal purple.
static func crest_colors(g: int) -> Array[Color]:
	var bright: Color = GuildLeague.color_of(g) if g > 0 else Color("ffd24a")
	if g <= 0 or g == WorldPlayers.ALPHA:
		return [Color("3b1468"), Color("ffcf2e")]
	return [Color.from_hsv(bright.h, 0.95, 0.42), bright]


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
	# Back to front: the long blades, then crystal shards over their roots along the arm
	# (each row a little further back, so it lies on top seen from behind). The tips
	# curl up like flame tongues.
	for i in BLADES.size():
		var p: Array = BLADES[i]
		_blade(st, _arm(p[0]), p[1], p[2], p[3], 0.07, -0.008 * i, ROW_BLADE, REACH, float(i) / 10.0)
	var n := 8
	for i in n:
		var f := float(i) / float(n - 1)
		var s := lerpf(0.06, 0.98, f)
		var along := _arm_angle(s)
		_blade(st, _arm(s), along - 58.0 - 10.0 * f, lerpf(0.42, 0.6, f), 0.2, 0.05, -0.1 - 0.006 * i, ROW_SHARD, REACH, f)
	return _commit(st)


static func _build_lower() -> ArrayMesh:
	var st := _begin()
	for i in MID.size():
		var p: Array = MID[i]
		var x: float = p[0]
		_blade(st, Vector2(x, 0.03 * x), p[1], p[2], p[3], 0.06, -0.008 * i, ROW_BLADE, LOWER_REACH, 0.05 + float(i) / 8.0)
	for i in LOW.size():
		var p: Array = LOW[i]
		_blade(st, p[0], p[1], p[2], p[3], -0.08, -0.07 - 0.006 * i, ROW_BLADE, LOWER_REACH, 0.55 + float(i) / 9.0)
	for i in 5:
		var f := float(i) / 4.0
		_blade(st, Vector2(lerpf(0.04, 0.8, f), 0.02), lerpf(-24.0, -40.0, f), lerpf(0.36, 0.5, f), 0.19, 0.04, -0.12 - 0.006 * i, ROW_SHARD, LOWER_REACH, f)
	return _commit(st)


## The crest crown, facing back: a curved gold circlet with four crystal spikes tipped
## with gems, and at its centre the guild's crest, a white-gold-rimmed shield of deep
## jewel enamel holding a big cut gem in the guild's colour.
static func _build_crown(field: Color, gem: Color) -> ArrayMesh:
	var st := _begin()
	# The circlet: a band whose ends sweep up, as a ring seen a little from below.
	var seg := 14
	var base := 0
	for i in seg + 1:
		var f := float(i) / float(seg) * 2.0 - 1.0
		var x := f * 0.46
		var y := 0.09 * f * f
		for k in 2:
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(float(k), absf(f)))
			st.set_uv2(Vector2(ROW_TRIM + 0.5, 0.0))
			st.set_normal(Vector3(0.0, 0.25 * float(k * 2 - 1), -1.0).normalized())
			st.add_vertex(Vector3(x, y + 0.13 * float(k), -0.02 * (1.0 - f * f)))
	for i in seg:
		_quad(st, base + i * 2, base + i * 2 + 1, base + i * 2 + 3, base + i * 2 + 2)
	st.set_meta("count", (seg + 1) * 2)
	# Spikes: the circlet's points, crystal blades like the wings' (a family look).
	for spec in [[-0.4, 0.2, 104.0, 0.3], [-0.2, 0.15, 96.0, 0.42], [0.2, 0.15, 84.0, 0.42], [0.4, 0.2, 76.0, 0.3]]:
		var x: float = spec[0]
		_blade(st, Vector2(x, spec[1] - 0.04), spec[2], spec[3], 0.13, 0.0, 0.01, ROW_SPIKE, 1.0, 0.25 + x)
		var tip := Vector2(x, spec[1] - 0.04) + Vector2.from_angle(deg_to_rad(spec[2])) * float(spec[3])
		_gem(st, Vector3(tip.x, tip.y + 0.02, -0.03), 0.045, gem)
	# The crest: rim, field, gem, each a little nearer the back.
	var shield := [Vector2(0, 0.22), Vector2(0.11, 0.17), Vector2(0.18, 0.2), Vector2(0.17, 0.0), Vector2(0.11, -0.14),
		Vector2(0.0, -0.24), Vector2(-0.11, -0.14), Vector2(-0.17, 0.0), Vector2(-0.18, 0.2), Vector2(-0.11, 0.17)]
	var centre := Vector3(0.0, 0.42, 0.0)
	_fan(st, centre + Vector3(0, 0.0, -0.035), shield, 1.32, ROW_TRIM, Color.WHITE)
	_fan(st, centre + Vector3(0, 0.0, -0.06), shield, 1.0, ROW_ENAMEL, field)
	_gem(st, centre + Vector3(0, 0.01, -0.085), 0.12, gem)
	# The same face toward the front, so the crest reads from both sides.
	_fan(st, centre + Vector3(0, 0.0, -0.01), shield, 1.0, ROW_ENAMEL, field)
	_gem(st, centre + Vector3(0, 0.01, 0.02), 0.1, gem)
	# Two small gems on the band.
	for x in [-0.28, 0.28]:
		_gem(st, Vector3(x, 0.07 + 0.09 * pow(x / 0.46, 2.0), -0.05), 0.04, gem)
	return _commit(st)


## A flat fan over a closed outline (UV.x 0.5 at the centre, 0 at the rim: the shader
## inks the rim), scaled by `scale`.
static func _fan(st: SurfaceTool, centre: Vector3, outline: Array, scale: float, row: int, tint: Color) -> void:
	var base := st.get_meta("count", 0) as int
	st.set_color(tint)
	st.set_uv(Vector2(0.5, 0.5))
	st.set_uv2(Vector2(row + 0.5, 0.0))
	st.set_normal(Vector3(0, 0, -1))
	st.add_vertex(centre)
	for i in outline.size():
		var p: Vector2 = outline[i] * scale
		st.set_color(tint)
		st.set_uv(Vector2(0.0, float(i) / float(outline.size())))
		st.set_uv2(Vector2(row + 0.5, 1.0))
		st.set_normal(Vector3(p.x, p.y, -1.6).normalized())
		st.add_vertex(centre + Vector3(p.x, p.y, 0.0))
	for i in outline.size():
		st.add_index(base); st.add_index(base + 1 + i); st.add_index(base + 1 + (i + 1) % outline.size())
	st.set_meta("count", base + 1 + outline.size())


## Two sashes per side hanging from the wing roots down the back to the heels and
## trailing back a little, each ending in a swallowtail; the shader sways them.
static func _build_ribbons() -> ArrayMesh:
	var st := _begin()
	var rows := 14
	# [root x, root y, length, width, outward drift, phase]
	var specs := [[0.17, 0.02, 1.36, 0.22, 0.22, 0.0], [0.36, -0.1, 1.16, 0.18, 0.5, 0.37]]
	for side in [1.0, -1.0]:
		for spec in specs:
			var base := st.get_meta("count", 0) as int
			var phase: float = spec[5] + (0.5 if side < 0.0 else 0.0)
			for r in rows + 1:
				var t := float(r) / float(rows)
				var x: float = side * (float(spec[0]) + float(spec[4]) * t * t + 0.035 * sin(t * PI * 1.6))
				var y: float = float(spec[1]) - float(spec[2]) * t
				var z := -0.06 - 0.32 * pow(t, 1.4)
				var half: float = float(spec[3]) * 0.5 * lerpf(1.0, 0.8, t)
				for k in 3:
					var off := float(k - 1)
					# The swallowtail: the middle of the end pulls up into a notch.
					var notch := 0.7 * float(spec[3]) if (r == rows and k == 1) else 0.0
					st.set_color(Color.WHITE)
					st.set_uv(Vector2(0.5 + 0.5 * off, t))
					st.set_uv2(Vector2(ROW_RIBBON + phase, t))
					st.set_normal(Vector3(0.0, 0.2, -1.0).normalized())
					st.add_vertex(Vector3(x + half * off * side, y + notch, z))
			for r in rows:
				var a := base + r * 3
				var b := a + 3
				_quad(st, a, a + 1, b + 1, b)
				_quad(st, a + 1, a + 2, b + 2, b + 1)
			st.set_meta("count", base + (rows + 1) * 3)
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


## One crystal blade from `root` (2D, in the wing plane at depth z) at `angle`
## degrees, `length` long and `width` wide; `bend` curls the tip toward the
## blade's left (up, on a wing spreading out to the right) like a flame tongue.
static func _blade(st: SurfaceTool, root: Vector2, angle: float, length: float, width: float, bend: float, z: float,
		row: int, reach: float, phase: float) -> void:
	var dir := Vector2.from_angle(deg_to_rad(angle))
	var side := Vector2(-dir.y, dir.x)
	var base := st.get_meta("count", 0) as int
	var ridge := width * 0.2
	for r in RINGS.size():
		var t: float = RINGS[r]
		var spine := root + dir * length * t + side * bend * length * t * t
		var tangent := (dir * length + side * 2.0 * bend * length * t).normalized()
		var across := Vector2(-tangent.y, tangent.x)
		var half: float = width * 0.5 * float(PROFILE[r])
		var across3 := Vector3(across.x, across.y, 0.0)
		var flex := clampf(spine.length() / reach, 0.0, 1.0)
		for k in 3:
			var off := float(k - 1)
			# The trailing edge is narrower: an asymmetric, flame-like blade.
			var w := half * (0.78 if k == 0 else 1.0) * absf(off)
			var p := spine + across * w * signf(off)
			var depth := z - (ridge * float(PROFILE[r]) if k == 1 else 0.0) - 0.05 * p.x * p.x
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(0.5 + 0.5 * off, t))
			st.set_uv2(Vector2(float(row) + clampf(phase, 0.0, 0.99), flex))
			st.set_normal((Vector3(0, 0, -1) + across3 * off * 0.6).normalized())
			st.add_vertex(Vector3(p.x, p.y, depth))
	for r in RINGS.size() - 1:
		var a := base + r * 3
		var b := a + 3
		_quad(st, a, a + 1, b + 1, b)
		_quad(st, a + 1, a + 2, b + 2, b + 1)
	st.set_meta("count", base + RINGS.size() * 3)


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
				st.set_uv2(Vector2(ROW_GEM + 0.5, float(i) / 4.0))
				st.set_normal(normal)
				st.add_vertex(at + v)
			st.add_index(base + verts); st.add_index(base + verts + 1); st.add_index(base + verts + 2)
			verts += 3
	st.set_meta("count", base + verts)
