extends RefCounted
## Shared by the arcane star signatures (Summoner, Dark Lord, Bard; combat/star_art).
## Built on the god kit (combat/god_art/_kit_arcane.gd: its four shaders, its Builder
## and its cached meshes): every piece is still a StarSkillArt layer with one clock, the
## 2/4/6 layer cap and a VfxBudget decoration, freed with its root. This file only adds
## the meshes the star set pieces share (flames, stars, notes, feathers, clouds, spray)
## in colours given by the caller, each built once per palette and cached.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const DS := preload("res://combat/god_art/divine_symphony.gd")


## An extra root of the cast of [param id] (its label carries the id, so the cast binds
## it), scaled by [param fit] (what the field camera shows of the sky there).
static func root(parent: Node3D, point: Vector3, seconds: float, label: String, source: Vector3, owner: StarSkillArt = null, fit := 1.0) -> StarSkillArt:
	var art := K.root(parent, point, seconds, label, source, owner)
	if art:
		art.scale = Vector3.ONE * fit
	return art


## Turns a root so its local +Z points away from the field camera (a backdrop set on +Z
## stands behind the caster); no camera: away from [param fallback]'s facing.
static func face_away(art: StarSkillArt) -> void:
	if art == null or not art.is_inside_tree():
		return
	var camera := art.get_viewport().get_camera_3d()
	if camera == null:
		return
	var d := art.global_position - camera.global_position
	if Vector2(d.x, d.z).length_squared() > 0.01:
		art.rotation.y = atan2(d.x, d.z)


## Turns a root so its local +Z points at [param point] (flat).
static func face_target(art: StarSkillArt, point: Vector3) -> void:
	if art == null:
		return
	var d := point - art.global_position
	if Vector2(d.x, d.z).length_squared() > 0.01:
		art.rotation.y = atan2(d.x, d.z)


## The quality tier (0 low .. 2 high), and whether this frame may add a rich detail.
static func rich() -> bool:
	return VfxBudget.quality() == 2 and MemoryGuard.pressure == 0


## The running cast of [param id] (its StarSkillSequence) or null.
static func cast_of(id: String) -> StarSkillSequence:
	var ref: WeakRef = GodSkillArt._casts.get(id)
	return ref.get_ref() as StarSkillSequence if ref else null


## The direction the running cast faces (its forward), or along source -> point.
static func forward_of(id: String, source: Vector3, point: Vector3) -> Vector3:
	var cast := cast_of(id)
	if is_instance_valid(cast) and cast.forward.length_squared() > 0.01:
		return cast.forward
	var d := (point - source) * Vector3(1, 0, 1)
	return d.normalized() if d.length_squared() > 0.01 else Vector3.FORWARD


# ---------------------------------------------------------------------------
# Fire
# ---------------------------------------------------------------------------
## A tongue of fire: a lathe whose colour runs through [param stops] (5 colours, the
## last fading out) from its foot to its tip.
static func flame(b: K.Builder, at: Vector3, wide: float, high: float, stops: Array, lean := Vector3.ZERO, segs := 9) -> void:
	b.xf = Transform3D(Basis.IDENTITY, at)
	b.lathe([[wide, 0.0, stops[0]], [wide * 0.84, high * 0.06, stops[1]], [wide * 0.58, high * 0.3, stops[2]], [wide * 0.34, high * 0.58, stops[3]], [wide * 0.14, high * 0.84, stops[4]], [0.0, high, Color(stops[4], 0.0)]], segs, 0.0, TAU, lean * high)
	b.xf = Transform3D.IDENTITY


## A ring of [param count] tongues of fire on radius 1 (scale the layer to place it),
## alternately tall and short, leaning outward.
static func flame_ring(key: String, stops: Array, count := 10, wide := 0.14, tall := 0.9, short := 0.6) -> ArrayMesh:
	return K.cached("star_flame_ring_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 19
		for i in count:
			var a := TAU * i / float(count) + rng.randf_range(-0.12, 0.12)
			var out := Vector3(sin(a), 0, cos(a))
			flame(b, out * rng.randf_range(0.92, 1.04), wide * rng.randf_range(0.85, 1.15), (tall if i % 2 == 0 else short) * rng.randf_range(0.85, 1.1), stops, out * 0.18)
		return b.mesh())


## A cluster of fire tongues round the origin (about 1 m wide, 1 m tall at scale 1).
static func flame_cluster(key: String, stops: Array) -> ArrayMesh:
	return K.cached("star_flame_cluster_" + key, func():
		var b := K.Builder.new()
		flame(b, Vector3.ZERO, 0.42, 1.0, stops, Vector3(0.04, 0, 0.02))
		flame(b, Vector3(-0.36, 0, 0.18), 0.26, 0.66, stops, Vector3(-0.2, 0, 0.08))
		flame(b, Vector3(0.34, 0, -0.16), 0.28, 0.74, stops, Vector3(0.2, 0, -0.08))
		flame(b, Vector3(0.08, 0, 0.36), 0.2, 0.5, stops, Vector3(0.05, 0, 0.22))
		return b.mesh())


# ---------------------------------------------------------------------------
# Light
# ---------------------------------------------------------------------------
## A four-pointed twinkle in XY (radius 1): a tinted heart and long soft points.
static func twinkle(key: String, core: Color, tip: Color) -> ArrayMesh:
	return K.cached("star_twinkle_" + key, func():
		var b := K.Builder.new()
		var pts := [Vector3.ZERO]
		for j in 17:
			var a := TAU * j / 16.0
			var r := 1.0 if j % 4 == 0 else (0.16 if j % 2 == 0 else 0.26)
			if j % 4 == 2: r = 0.42
			pts.append(Vector3(sin(a) * r, cos(a) * r, 0))
		b.fan(pts, core, Color(tip, 0.0))
		b.fan([Vector3.ZERO, Vector3(0, -0.28, 0), Vector3(0.28, 0, 0), Vector3(0, 0.28, 0), Vector3(-0.28, 0, 0), Vector3(0, -0.28, 0)], core.lerp(Color.WHITE, 0.25), core)
		return b.mesh())


## Small twinkles thrown up and drifting (burst, GLOW): sparkles in [param tones].
static func sparkles(key: String, tones: Array, count := 26, rise := 5.0, spread := 3.0) -> ArrayMesh:
	return K.cached("star_sparkles_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 53
		for i in count:
			var a := rng.randf() * TAU
			var out := Vector3(sin(a), 0, cos(a))
			var tone: Color = tones[i % tones.size()]
			var s := rng.randf_range(0.14, 0.3)
			b.piece(out * rng.randf_range(0.2, 2.0) + Vector3.UP * rng.randf_range(0.0, 0.8), out * rng.randf_range(0.6, spread) + Vector3.UP * rng.randf_range(0.5, 1.3) * rise, rng.randf_range(0.0, 0.2), rng.randf_range(-3.0, 3.0), Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)))
			for plane in 2:
				var side := Vector3.RIGHT if plane == 0 else Vector3.BACK
				b.fan([Vector3.ZERO, Vector3.UP * -s * 1.6, side * s * 0.35, Vector3.UP * s * 1.6, -side * s * 0.35, Vector3.UP * -s * 1.6], tone, Color(tone, 0.0))
				b.fan([Vector3.ZERO, side * -s * 1.2, Vector3.UP * s * 0.3, side * s * 1.2, Vector3.UP * -s * 0.3, side * -s * 1.2], tone, Color(tone, 0.0))
		return b.mesh())


## Stars of a constellation on a disc of radius 1 (XZ), joined by thin lines of light.
static func constellation(key: String, star: Color, line: Color, count := 9, seed_value := 7) -> ArrayMesh:
	return K.cached("star_constellation_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var pts := []
		for i in count:
			var a := TAU * i / float(count) + rng.randf_range(-0.3, 0.3)
			pts.append(Vector3(sin(a), 0, cos(a)) * rng.randf_range(0.35, 0.95) + Vector3.UP * rng.randf_range(-0.05, 0.05))
		pts.append(Vector3.ZERO)
		for i in pts.size():
			var p: Vector3 = pts[i]
			var q: Vector3 = pts[(i + 1) % count] if i < count else pts[0]
			if i == count: q = pts[count / 2]
			var side := (q - p).cross(Vector3.UP).normalized() * 0.012
			b.quad(p - side, p + side, q + side, q - side, Color(line, 0.75))
			b.quad(p - side * 3.0, p - side, q - side, q - side * 3.0, Color(line, 0.0), Color(line, 0.0))
			b.quad(p + side, p + side * 3.0, q + side * 3.0, q + side, Color(line, 0.3), Color(line, 0.3))
		for i in pts.size():
			var p: Vector3 = pts[i]
			var s := 0.07 if i % 3 else 0.11
			for plane in 2:
				var u := Vector3.RIGHT if plane == 0 else Vector3.BACK
				var v := Vector3.UP if plane == 0 else Vector3.RIGHT
				b.fan([p, p - u * s * 1.6, p + v * s * 0.3, p + u * s * 1.6, p - v * s * 0.3, p - u * s * 1.6], star, Color(star, 0.0))
				b.fan([p, p - v * s * 1.6, p + u * s * 0.3, p + v * s * 1.6, p - u * s * 0.3, p - v * s * 1.6], star, Color(star, 0.0))
			b.xf = Transform3D(Basis.IDENTITY, p)
			b.annulus(0.0, s * 0.55, 8, star.lerp(Color.WHITE, 0.3), Color(star, 0.0))
			b.xf = Transform3D.IDENTITY
		return b.mesh())


## A comet's tail of light standing up from the origin (1 m tall, two crossed ribbons):
## [param head] at the foot fading to nothing at the top.
static func tail(key: String, head: Color, end: Color) -> ArrayMesh:
	return K.cached("star_tail_" + key, func():
		var b := K.Builder.new()
		var rows := 8
		for plane in 2:
			var side := Vector3.RIGHT if plane == 0 else Vector3.BACK
			var base := b.v.size()
			for k in rows + 1:
				var f := float(k) / rows
				var w := 0.5 * (1.0 - f * 0.8)
				var c := head.lerp(end, f)
				c.a *= pow(1.0 - f, 1.3)
				var y := Vector3.UP * f
				b.pt(y - side * w, Vector3.BACK, Color(c, 0.0))
				b.pt(y, Vector3.BACK, c)
				b.pt(y + side * w, Vector3.BACK, Color(c, 0.0))
			for k in rows:
				var a := base + k * 3
				for j in 2:
					b.tri(a + j, a + j + 1, a + j + 4); b.tri(a + j, a + j + 4, a + j + 3)
		return b.mesh())


# ---------------------------------------------------------------------------
# Notes (the Bard)
# ---------------------------------------------------------------------------
## One eighth note in XY (head at the origin, stem up), in [param tone].
static func note(key: String, tone: Color) -> ArrayMesh:
	return K.cached("star_note_" + key, func():
		var b := K.Builder.new()
		b.emit = 0.7
		DS._note(b, tone)
		b.xf = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.02))
		DS._note(b, tone)
		return b.mesh())


## Notes thrown outward and up from a point (burst), in [param tones].
static func note_spray(key: String, tones: Array, count := 12, up := 6.0, out_speed := 4.0) -> ArrayMesh:
	return K.cached("star_note_spray_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 29
		b.emit = 0.7
		for i in count:
			var a := TAU * i / float(count) + rng.randf_range(-0.2, 0.2)
			var out := Vector3(sin(a), 0, cos(a))
			b.piece(out * rng.randf_range(0.2, 0.7) + Vector3.UP * 0.4, out * rng.randf_range(0.5, 1.0) * out_speed + Vector3.UP * rng.randf_range(0.6, 1.0) * up, rng.randf_range(0.0, 0.08), 0.0, Basis.from_euler(Vector3(0, a + PI, rng.randf_range(-0.5, 0.5))).scaled(Vector3.ONE * rng.randf_range(0.7, 1.2)))
			DS._note(b, tones[i % tones.size()])
		return b.mesh())


# ---------------------------------------------------------------------------
# Feathers, leaves, spray, clouds
# ---------------------------------------------------------------------------
## Feathers torn loose (burst, SOLID), [param tones] dark to sheen.
static func feathers(key: String, tones: Array, count := 22, speed := 5.0) -> ArrayMesh:
	return K.cached("star_feathers_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 61
		for i in count:
			var a := rng.randf() * TAU
			var out := Vector3(sin(a), 0, cos(a))
			b.piece(out * rng.randf_range(0.1, 0.6) + Vector3.UP * rng.randf_range(0.6, 1.6), out * rng.randf_range(0.4, 1.0) * speed + Vector3.UP * rng.randf_range(1.0, 4.5), rng.randf_range(0.0, 0.1), rng.randf_range(3.0, 8.0), Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)))
			var tone: Color = tones[i % tones.size()]
			var l := rng.randf_range(0.35, 0.6)
			var w := l * 0.22
			b.fan([Vector3.ZERO, Vector3(0, -l * 0.5, 0), Vector3(w, -l * 0.1, 0.02), Vector3(w * 0.7, l * 0.35, 0.03), Vector3(0, l * 0.5, 0), Vector3(-w * 0.7, l * 0.35, 0.03), Vector3(-w, -l * 0.1, 0.02), Vector3(0, -l * 0.5, 0)], tone.lerp(Color.WHITE, 0.12), tone)
		return b.mesh())


## Leaves whirled up and out (burst, SOLID).
static func leaves(key: String, tones: Array, count := 26, speed := 6.0, rise := 5.0) -> ArrayMesh:
	return K.cached("star_leaves_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 71
		for i in count:
			var a := rng.randf() * TAU
			var out := Vector3(sin(a), 0, cos(a))
			var swirl := Vector3(cos(a), 0, -sin(a))
			b.piece(out * rng.randf_range(0.3, 1.4) + Vector3.UP * rng.randf_range(0.2, 2.0), (out * 0.6 + swirl) * rng.randf_range(0.5, 1.0) * speed + Vector3.UP * rng.randf_range(0.4, 1.0) * rise, rng.randf_range(0.0, 0.15), rng.randf_range(4.0, 9.0), Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)))
			var tone: Color = tones[i % tones.size()]
			var l := rng.randf_range(0.22, 0.38)
			b.fan([Vector3.ZERO, Vector3(0, -l, 0), Vector3(l * 0.45, -l * 0.2, 0), Vector3(l * 0.3, l * 0.5, 0), Vector3(0, l, 0), Vector3(-l * 0.3, l * 0.5, 0), Vector3(-l * 0.45, -l * 0.2, 0), Vector3(0, -l, 0)], tone.lerp(Color.WHITE, 0.15), tone.darkened(0.15))
		return b.mesh())


## Drops of water flung up and out (burst, VEIL/GLOW).
static func spray(key: String, tones: Array, count := 34, up := 9.0, out_speed := 5.0) -> ArrayMesh:
	return K.cached("star_spray_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 83
		for i in count:
			var a := rng.randf() * TAU
			var out := Vector3(sin(a), 0, cos(a))
			b.piece(out * rng.randf_range(0.2, 1.6), out * rng.randf_range(0.3, 1.0) * out_speed + Vector3.UP * rng.randf_range(0.5, 1.0) * up, rng.randf_range(0.0, 0.12), 0.0)
			var s := rng.randf_range(0.12, 0.3)
			var tone: Color = tones[i % tones.size()]
			b.ball(Vector3.ZERO, Vector3(s, s * 1.5, s), tone.lerp(Color.WHITE, 0.3), tone, 6, 4)
		return b.mesh())


## Puffs of cloud heaped on a disc of radius 1 (SOLID), [param top] lit, [param under] shaded.
static func cloud(key: String, top: Color, under: Color, count := 14, flat := 0.62, seed_value := 7) -> ArrayMesh:
	return K.cached("star_cloud_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in count:
			var a := TAU * i / float(count) + rng.randf_range(-0.25, 0.25)
			var d := rng.randf_range(0.25, 0.85) if i % 3 else rng.randf_range(0.0, 0.3)
			var p := rng.randf_range(0.28, 0.46)
			b.ball(Vector3(sin(a) * d, rng.randf_range(-0.05, 0.15), cos(a) * d), Vector3(p, p * flat * 1.2, p), top.lerp(top.lightened(0.2), rng.randf()), under, 10, 5)
		return b.mesh())


## Puffs of cloud thrown outward along the ground (burst, SOLID).
static func puffs(key: String, top: Color, under: Color, count := 10, speed := 7.0) -> ArrayMesh:
	return K.cached("star_puffs_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		for i in count:
			var a := TAU * i / float(count) + rng.randf_range(-0.2, 0.2)
			var out := Vector3(sin(a), 0, cos(a))
			b.piece(out * rng.randf_range(0.3, 0.8), out * rng.randf_range(0.6, 1.0) * speed + Vector3.UP * rng.randf_range(0.3, 1.4), rng.randf_range(0.0, 0.06), 0.0)
			var p := rng.randf_range(0.32, 0.55)
			b.ball(Vector3.ZERO, Vector3(p, p * 0.72, p), top, under, 9, 5)
		return b.mesh())


## A wreath of cloud puffs on radius 1 (SOLID).
static func cloud_ring(key: String, top: Color, under: Color, count := 18, puff := 0.17) -> ArrayMesh:
	return K.cached("star_cloud_ring_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in count:
			var a := TAU * i / float(count) + rng.randf_range(-0.08, 0.08)
			var p := puff * rng.randf_range(0.7, 1.2)
			b.ball(Vector3(sin(a), rng.randf_range(-0.05, 0.1), cos(a)) * rng.randf_range(0.9, 1.05), Vector3(p, p * 0.8, p), top, under, 9, 5)
		return b.mesh())


## A soft disc of colour on the ground (radius 1): a tinted wash under a set piece.
static func wash(key: String, inner: Color, outer: Color) -> ArrayMesh:
	return K.cached("star_wash_" + key, func():
		var b := K.Builder.new()
		b.annulus(0.0, 0.6, 28, inner, Color(outer, outer.a * 0.8))
		b.annulus(0.6, 1.0, 28, Color(outer, outer.a * 0.8), Color(outer, 0.0))
		return b.mesh())


## A rising spiral of thin ribbons round Y (radius 1 at the foot, height 1): wind, wisps.
static func spiral(key: String, foot: Color, top: Color, arms := 3, turns := 1.3, top_radius := 0.6) -> ArrayMesh:
	return K.cached("star_spiral_" + key, func():
		var b := K.Builder.new()
		var steps := 30
		for arm in arms:
			var prev_in := Vector3.ZERO
			var prev_out := Vector3.ZERO
			for k in steps + 1:
				var f := float(k) / steps
				var a := TAU * float(arm) / arms + f * TAU * turns
				var r := lerpf(1.0, top_radius, f)
				var d := Vector3(sin(a), 0, cos(a))
				var w := 0.09 * sin(PI * f) + 0.01
				var p_in := d * (r - w) + Vector3.UP * f
				var p_out := d * (r + w) + Vector3.UP * (f + 0.03)
				if k > 0:
					var c0 := foot.lerp(top, f - 1.0 / steps)
					var c1 := foot.lerp(top, f)
					c0.a *= sin(PI * (f - 1.0 / steps)) * 0.9 + 0.1
					c1.a *= sin(PI * f) * 0.9 + 0.1
					b.quad(prev_in, prev_out, p_out, p_in, c0, c1)
				prev_in = p_in
				prev_out = p_out
		return b.mesh())


## Three raking crescents (radius 1) standing on the ground along +Z: a claw or a gust.
static func rake(key: String, col_in: Color, col_out: Color, count := 3) -> ArrayMesh:
	return K.cached("star_rake_" + key, func():
		var b := K.Builder.new()
		for k in count:
			var off := (float(k) - float(count - 1) * 0.5) * 0.28
			b.xf = Transform3D(Basis(Vector3.BACK, PI / 2).rotated(Vector3.UP, 0.0), Vector3(off, 0.5, 0))
			K.crescent(b, 0.8, 0.22, -1.1, 1.1, col_in, col_out, 16)
		b.xf = Transform3D.IDENTITY
		return b.mesh())


# ---------------------------------------------------------------------------
# Water (the Summoner's sea creatures)
# ---------------------------------------------------------------------------
## The VEIL look of moving water: the noise tears foam and drives it along the mesh.
const WATER_LOOK := {"noise_amt": 0.7, "noise_scale": Vector2(6.0, 2.0), "flow": Vector2(0.4, -1.6), "bias": 0.35, "taper": 0.55}


## A curling wave crest standing on an arc of radius 1 (from -[param half] to +[param half]
## radians round +Z, or a full ring), about 1 m tall, its lip curling outward; deep at
## the foot, foam along the lip (UV.y runs foot to lip).
static func wave(key: String, deep: Color, body: Color, foam: Color, half := 0.9, ring := false) -> ArrayMesh:
	return K.cached("star_wave_" + key, func():
		var b := K.Builder.new()
		var profile := [[-0.08, 0.0, Color(deep, 0.0)], [0.0, 0.25, Color(deep, 0.75)], [0.06, 0.6, Color(body, 0.85)], [0.04, 0.9, Color(body.lerp(foam, 0.4), 0.9)], [0.14, 1.08, Color(foam, 0.95)], [0.3, 1.0, Color(foam, 0.85)], [0.36, 0.84, Color(foam, 0.0)]]
		var segs := 40 if ring else 26
		var a0 := -PI if ring else -half
		var a1 := PI if ring else half
		var rows := profile.size()
		var base := b.v.size()
		for i in rows:
			var q: Array = profile[i]
			for j in segs + 1:
				var f := float(j) / segs
				var a := lerpf(a0, a1, f)
				var d := Vector3(sin(a), 0, cos(a))
				var c: Color = q[2]
				if not ring: c.a *= smoothstep(0.0, 0.18, f) * smoothstep(1.0, 0.82, f)
				var tall := 1.0 if ring else 0.55 + 0.45 * sin(PI * f)
				b.pt(d * (1.0 + float(q[0])) + Vector3.UP * float(q[1]) * tall, d, c, Vector2(f * 4.0, float(i) / (rows - 1)))
		for i in rows - 1:
			for j in segs:
				var a := base + i * (segs + 1) + j
				var c := a + segs + 1
				b.tri(a, a + 1, c + 1); b.tri(a, c + 1, c)
		return b.mesh())


## A whirlpool on the ground (radius 1): spiral bands of foam over deepening water.
static func whirlpool(key: String, deep: Color, body: Color, foam: Color) -> ArrayMesh:
	return K.cached("star_whirlpool_" + key, func():
		var b := K.Builder.new()
		b.annulus(0.0, 0.3, 24, Color(deep.darkened(0.3), 0.85), Color(deep, 0.75))
		b.annulus(0.3, 0.85, 32, Color(deep, 0.75), Color(body, 0.55))
		b.annulus(0.85, 1.05, 32, Color(body, 0.55), Color(body, 0.0))
		for arm in 5:
			var prev_a := Vector3.ZERO
			var prev_b := Vector3.ZERO
			for k in 25:
				var f := float(k) / 24.0
				var a := TAU * arm / 5.0 + f * 3.2
				var d := Vector3(sin(a), 0, cos(a))
				var rr := 0.12 + 0.88 * f
				var w := 0.07 * sin(PI * f) + 0.005
				var pa := d * (rr - w) + Vector3.UP * 0.01
				var pb := d * (rr + w) + Vector3.UP * 0.01
				if k > 0:
					var c := Color(foam, 0.85 * sin(PI * f) + 0.1)
					b.quad(prev_a, prev_b, pb, pa, c, c)
				prev_a = pa
				prev_b = pb
		return b.mesh())


## A rising spout of water (radius 1 at the foot, height 1), open, foam at the foot.
static func spout(key: String, body: Color, foam: Color) -> ArrayMesh:
	return K.cached("star_spout_" + key, func():
		var b := K.Builder.new()
		b.lathe([[1.25, 0.0, Color(foam, 0.0)], [1.0, 0.06, Color(foam, 0.9)], [0.85, 0.2, Color(body.lerp(foam, 0.4), 0.8)], [0.72, 0.5, Color(body, 0.7)], [0.62, 0.8, Color(body.lerp(foam, 0.3), 0.55)], [0.75, 1.0, Color(foam, 0.0)]], 20)
		return b.mesh())


## The sea king's trident (about 4.4 m, +Y up, tines at the top): gold, sea-blue gems.
static func trident(key: String, gold: Color, dark: Color, gem: Color) -> ArrayMesh:
	return K.cached("star_trident_" + key, func():
		var b := K.Builder.new()
		var hi := gold.lerp(Color.WHITE, 0.35)
		b.tube([Vector3(0, -0.2, 0), Vector3(0, 3.2, 0)], [0.07, 0.06], 8, [gold.darkened(0.15)])
		for y in [0.6, 1.6, 2.6]:
			b.tube([Vector3(0, y, 0), Vector3(0, y + 0.12, 0)], [0.1], 8, [dark])
		b.tube([Vector3(-0.62, 3.25, 0), Vector3(0.62, 3.25, 0)], [0.09], 6, [gold], Vector3.FORWARD)
		b.ball(Vector3(0, 3.2, 0), Vector3(0.2, 0.16, 0.2), hi, gold, 8, 5)
		for x in [-0.6, 0.0, 0.6]:
			var top := 4.4 if x == 0.0 else 4.0
			var foot := Vector3(x, 3.25, 0)
			b.tube([foot, Vector3(x * 1.05, top - 0.35, 0)], [0.07, 0.06], 6, [gold, hi])
			b.cone(Vector3(x * 1.05, top - 0.4, 0), Vector3(x * 1.05, top, 0), 0.15, 4, gold, hi, Vector3.FORWARD, true)
			if x != 0.0:
				b.cone(Vector3(x * 1.05, top - 0.55, 0), Vector3(x * 1.05 - signf(x) * 0.2, top - 0.75, 0), 0.06, 3, gold, hi, Vector3.FORWARD, true)
		b.emit = 0.9
		b.gem(Vector3(0, 3.2, -0.18), Vector3(0.12, 0.15, 0.06), gem, gem.lerp(Color.WHITE, 0.5))
		b.gem(Vector3(0, 3.2, 0.18), Vector3(0.12, 0.15, 0.06), gem, gem.lerp(Color.WHITE, 0.5))
		b.emit = 0.0
		return b.mesh())


## The newest creature of [param skill_id] the summoner just called (null if none).
static func newest_summon(parent: Node, skill_id: String) -> Node3D:
	if not is_instance_valid(parent):
		return null
	var found: Node3D = null
	for child in parent.get_children():
		if child is Summon and String(child.skill_id) == skill_id and not child.is_queued_for_deletion():
			found = child
	return found
