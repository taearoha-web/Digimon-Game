extends RefCounted
## Shared kit of the melee star signatures (Warrior, Lancer, Defender, Assassin at 50 / 100 /
## 150 / 200 stars), on top of the god melee kit (combat/god_art/_kit_melee.gd, its three
## shaders and mesh builders): arcs and strokes, the recurring impact layers (shock ring,
## ground flash, fissures, sparks, rubble, dust) and the solid parts several skills share
## (lance, shield, dagger, crown, a shadow figure). Everything is one StarSkillArt layer
## (the root's 2/4/6 cap and the VfxBudget decoration count apply); meshes are cached
## statics shared by every cast. Light is tinted with the skill's own colours: no white
## flash ever covers the fight.
const K := preload("res://combat/god_art/_kit_melee.gd")
static var _m := {}


static func a(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


## A hot core in the skill's colour: bright, never plain white.
static func hot(color: Color, alpha := 1.0) -> Color:
	var c := color.lerp(Color.WHITE, 0.4)
	return Color(c.r, c.g, c.b, alpha)


static func has(key: String) -> bool:
	return _m.has(key)


static func keep(key: String, mesh: Mesh) -> Mesh:
	_m[key] = mesh
	return mesh


static func get_mesh(key: String) -> Mesh:
	return _m.get(key)


## Points round [param center] on a level arc: angle 0 is +Z, PI/2 is +X. The radius runs
## from r to r1 (a spiral when they differ) and the height from y0 to y1.
static func arc(center: Vector3, r: float, a0: float, a1: float, y0: float, y1: float, n := 18, r1 := -1.0) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var rr := r if r1 < 0.0 else r1
	for i in n + 1:
		var t := float(i) / float(n)
		var ang := lerpf(a0, a1, t)
		var rad := lerpf(r, rr, t)
		pts.append(center + Vector3(sin(ang) * rad, lerpf(y0, y1, t), cos(ang) * rad))
	return pts


## Points on an arc in the plane of [param u] and [param v] round [param center].
static func arc_in(center: Vector3, u: Vector3, v: Vector3, r: float, a0: float, a1: float, n := 18) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in n + 1:
		var ang := lerpf(a0, a1, float(i) / float(n))
		pts.append(center + (u * cos(ang) + v * sin(ang)) * r)
	return pts


## A thrown burst in a fan along +Z ([param half] radians either side): one BITS mesh.
static func fan(key: String, shape: String, count: int, r0: float, r1: float, half: float, out: float, up: float, colors: Array, piece: float, seed_value := 1, y0 := 0.1, y1 := 0.4, spread := 0.0) -> ArrayMesh:
	if _m.has(key):
		return _m[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var ang := rng.randf_range(-half, half)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var origin := dir * lerpf(r0, r1, sqrt(rng.randf())) + Vector3.UP * rng.randf_range(y0, y1)
		var vel := dir * out * rng.randf_range(0.45, 1.0) + Vector3.UP * up * rng.randf_range(0.4, 1.0)
		var color: Color = colors[rng.randi() % colors.size()]
		var size := piece * rng.randf_range(0.45, 1.0)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * size)
		K.bit(st, K._bit_shape(shape, rng, color), origin, vel, rng.randf() * spread, piece, basis)
	return keep(key, K.finish(st, Vector3(out + r1 + 6.0, up * 0.2 + 8.0, out + r1 + 6.0), false))


## A root of the cast beside the wind-up root [param art], facing the same way, for what
## outlives the wind-up: the wind-up root is bound to the hero's skill motion and is
## freed the moment that motion ends (HeroVisual.skill_generation), while this one is
## bound only to the cast itself (StarSignature ties it by [param label], which must
## carry the skill id). Never subject to extra_roots: it carries the core of the show.
static func stage(art: StarSkillArt, seconds: float, label: String, at := Vector3.INF) -> StarSkillArt:
	if art == null or not art.is_inside_tree():
		return null
	var root := StarSkillArt._root(art.get_parent() as Node3D, art.global_position if at == Vector3.INF else at, seconds, label)
	if root:
		root.global_rotation = art.global_rotation
	return root


# ---------------------------------------------------------------------------
# The recurring layers of an impact
# ---------------------------------------------------------------------------
## An expanding ring of [param r] metres, tinted.
static func shock(art: StarSkillArt, key: String, color: Color, r: float, delay := 0.0, seconds := 0.55, width := 0.18, y := 0.1) -> void:
	K.put(art, K.FLAT, K.shock(key, a(color, 1.0), width), key, Vector3.UP * y, Vector3.ONE * r, seconds, {"soft": 1.2, "hot": hot(color, 0.9), "core": 0.5, "add": 0.55}, {"delay": delay, "initial": 0.08, "grow_time": 0.75, "fade_in": 0.02, "decay": 0.3})


## A soft glow on the ground where it struck, gone in [param seconds].
static func flash(art: StarSkillArt, key: String, color: Color, r: float, delay := 0.0, seconds := 0.4, y := 0.09) -> void:
	K.put(art, K.FLAT, K.glow_disc(key, a(color, 0.85), a(color, 0.0)), key, Vector3.UP * y, Vector3.ONE * r, seconds, {"soft": 0.6, "add": 0.75, "gain": 1.1}, {"delay": delay, "initial": 0.35, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.35})


## Fissures of light opening out from the centre.
static func cracks(art: StarSkillArt, key: String, color: Color, r: float, delay := 0.0, seconds := 1.2, rays := 7, seed_value := 3, y := 0.07) -> void:
	K.put(art, K.FLAT, K.cracks(key, rays, 0.08, 1.0, 0.08, Color(0.16, 0.06, 0.03, 1.0), seed_value, 1, 0.28), key, Vector3.UP * y, Vector3.ONE * r, seconds, {"sweep": 0.22, "soft": 0.4, "hot": a(color.lerp(Color.WHITE, 0.2), 1.0), "core": 0.45, "flick": 0.1, "add": 0.65, "gain": 1.1}, {"delay": delay, "decay": 0.7})


## Embers or sparks: light that is thrown and burns out.
static func sparks(art: StarSkillArt, key: String, colors: Array, count: int, r0: float, r1: float, out: float, up: float, piece := 0.16, delay := 0.0, seconds := 0.9, at := Vector3.ZERO, gravity := 5.0, seed_value := 7, y0 := 0.2, y1 := 1.4) -> void:
	K.put(art, K.BITS, K.burst(key, "ember", count, r0, r1, out, up, colors, piece, 0.08, seed_value, y0, y1), key, at, Vector3.ONE, seconds, {"life": seconds * 0.8, "gravity": gravity, "drag": 1.6, "piece": piece, "add": 0.75, "shrink": 0.25, "spin": 6.0}, {"delay": delay, "decay": 0.8})


## Rock and earth thrown out of the ground.
static func rubble(art: StarSkillArt, key: String, colors: Array, count: int, r0: float, r1: float, out: float, up: float, piece := 0.35, delay := 0.0, seconds := 1.3, at := Vector3.ZERO, seed_value := 9) -> void:
	K.put(art, K.BITS, K.burst(key, "rock", count, r0, r1, out, up, colors, piece, 0.05, seed_value), key, at, Vector3.ONE, seconds, {"life": seconds * 0.85, "gravity": 18.0, "piece": piece, "floor_y": 0.06, "shrink": 0.8, "spin": 7.0, "hot": Color(1.0, 0.7, 0.3, 0.3)}, {"delay": delay, "decay": 0.9})


## A ring of dust rolling out over the ground.
static func dust(art: StarSkillArt, key: String, color: Color, count: int, r0: float, r1: float, delay := 0.0, seconds := 1.2, at := Vector3.ZERO, piece := 0.9, seed_value := 5) -> void:
	K.put(art, K.BITS, K.burst(key, "puff", count, r0, r1, 3.2, 1.2, [color, color.lightened(0.12), color.darkened(0.1)], piece, 0.08, seed_value, 0.1, 0.4), key, at, Vector3.ONE, seconds, {"life": seconds * 0.9, "gravity": -0.4, "drag": 2.2, "piece": piece, "swell": 1.9, "alpha": 0.55, "shrink": 0.35, "spin": 1.2}, {"delay": delay, "decay": 0.85})


## The readable hit area: a thin ticked double ring.
static func area(art: StarSkillArt, key: String, color: Color, r: float, seconds: float, spin := 0.25, y := 0.06) -> void:
	K.put(art, K.FLAT, K.area_ring(key, a(color, 1.0)), key, Vector3.UP * y, Vector3.ONE * r, seconds, {"soft": 0.5, "hot": hot(color, 0.8), "core": 0.5, "add": 0.35}, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.08, "spin": spin, "decay": 0.9})


## A column of light rising from the ground ([param r] wide, [param height] tall).
static func pillar(art: StarSkillArt, key: String, color: Color, r: float, height: float, delay := 0.0, seconds := 0.7, at := Vector3.ZERO) -> void:
	if not _m.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		K.beam(st, Vector3.ZERO, 1.0, 0.3, a(color, 0.7), 3, 0.0, 0.0, 0.12)
		K.disc(st, 0.36, a(color.lightened(0.25), 0.85), 0.01, 24, 0.0, Vector3.UP, Vector3.ZERO, a(color, 0.0))
		keep(key, K.finish(st, Vector3.ONE * 0.2, false))
	K.put(art, K.FLAT, _m[key], key, at + Vector3.UP * 0.08, Vector3(r, height, r), seconds, {"soft": 1.8, "hot": hot(color, 0.8), "core": 0.6, "flow": 2.5, "add": 0.7}, {"delay": delay, "initial": 0.45, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.25})


# ---------------------------------------------------------------------------
# Shared solid parts
# ---------------------------------------------------------------------------
## A lance: butt on the origin, point at +Y 1. Shaft, collar, a long leaf blade with
## glowing edges, two side barbs.
static func lance(shaft: Color, metal: Color, glow: Color) -> K.Part:
	var p := K.Part.new()
	p.ink(shaft, 0.2)
	p.tube(Vector3.ZERO, Vector3(0, 0.66, 0), 0.016, 0.02, 6)
	p.ink(metal, 0.9)
	p.tube(Vector3(0, 0.62, 0), Vector3(0, 0.68, 0), 0.034, 0.034, 6)
	p.tube(Vector3(0, -0.02, 0), Vector3(0, 0.03, 0), 0.026, 0.022, 6)
	for s in [-1.0, 1.0]:
		p.tube(Vector3(0, 0.68, 0), Vector3(s * 0.085, 0.71, 0), 0.02, 0.012, 4, 0.6)
		p.tube(Vector3(s * 0.085, 0.71, 0), Vector3(s * 0.1, 0.65, 0), 0.012, 0.0, 4, 0.6)
	p.ink(metal, 1.0)
	p.tube(Vector3(0, 0.68, 0), Vector3(0, 0.79, 0), 0.03, 0.05, 4, 0.3, false)
	p.tube(Vector3(0, 0.79, 0), Vector3(0, 1.0, 0), 0.05, 0.0, 4, 0.3, false)
	p.ink(glow, 0.0, 1.0)
	p.box(Vector3(0, 0.82, 0), Vector3(0.012, 0.22, 0.018))
	return p


## A heater shield standing on its point at the origin, face to +Z, 1 tall: steel field,
## rim, a boss, both faces dressed.
static func shield(field: Color, rim: Color, boss: Color) -> K.Part:
	var p := K.Part.new()
	var outline := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var ang := lerpf(-PI * 0.5, PI * 0.5, t)
		outline.append(Vector2(sin(ang) * 0.42, 0.78 - (1.0 - cos(ang)) * 0.05))
	outline.append(Vector2(0.4, 0.42))
	outline.append(Vector2(0.24, 0.16))
	outline.append(Vector2(0.0, 0.0))
	outline.append(Vector2(-0.24, 0.16))
	outline.append(Vector2(-0.4, 0.42))
	var rim_line := PackedVector2Array()
	var inner := PackedVector2Array()
	for q in outline:
		var c := Vector2(0, 0.46)
		inner.append(c + (q - c) * 0.84)
		rim_line.append(q)
	p.ink(rim, 0.8)
	p.slab(rim_line, -0.05, 0.05)
	p.ink(field, 0.5)
	p.slab(inner, -0.07, 0.07)
	p.ink(boss, 0.9, 0.35)
	p.gem(Vector3(0, 0.5, 0.08), Vector3(0.11, 0.13, 0.07))
	p.gem(Vector3(0, 0.5, -0.08), Vector3(0.09, 0.11, 0.05))
	p.ink(rim, 0.8)
	p.box(Vector3(0, 0.5, 0.075), Vector3(0.05, 0.62, 0.02))
	p.box(Vector3(0, 0.58, 0.075), Vector3(0.6, 0.05, 0.02))
	return p


## A dagger: point at +Y 1, hilt at the origin, a curved blade with a glowing edge.
static func dagger(blade: Color, grip: Color, edge: Color) -> K.Part:
	var p := K.Part.new()
	p.ink(grip, 0.2)
	p.tube(Vector3.ZERO, Vector3(0, 0.26, 0), 0.04, 0.035, 5)
	p.ink(blade.darkened(0.3), 0.6)
	p.box(Vector3(0, 0.28, 0), Vector3(0.26, 0.04, 0.06))
	p.ink(blade, 1.0)
	var out := PackedVector2Array([Vector2(-0.07, 0.3), Vector2(0.07, 0.3), Vector2(0.09, 0.55), Vector2(0.05, 0.8), Vector2(-0.03, 1.0), Vector2(-0.02, 0.75), Vector2(-0.06, 0.5)])
	p.slab(out, -0.018, 0.018)
	p.ink(edge, 0.0, 1.0)
	p.tube(Vector3(0.075, 0.33, 0), Vector3(0.085, 0.56, 0), 0.012, 0.012, 3, 0.5)
	p.tube(Vector3(0.085, 0.56, 0), Vector3(-0.03, 1.0, 0), 0.012, 0.004, 3, 0.5)
	return p


## A crown on the origin, radius 1, 0.9 tall: band, seven points, gems.
static func crown(gold: Color, gem: Color, points := 7) -> K.Part:
	var p := K.Part.new()
	p.ink(gold, 1.0)
	for i in points:
		var a0 := TAU * float(i) / float(points)
		var a1 := TAU * float(i + 1) / float(points)
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		p.quad(d0, d1, d1 + Vector3.UP * 0.32, d0 + Vector3.UP * 0.32)
		p.quad(d0 * 0.92, d0 * 0.92 + Vector3.UP * 0.32, d1 * 0.92 + Vector3.UP * 0.32, d1 * 0.92)
		var mid := Vector3(sin((a0 + a1) * 0.5), 0, cos((a0 + a1) * 0.5))
		p.tri(d0 + Vector3.UP * 0.3, d1 + Vector3.UP * 0.3, mid * 0.98 + Vector3.UP * 0.9)
		p.tri(d1 * 0.92 + Vector3.UP * 0.3, d0 * 0.92 + Vector3.UP * 0.3, mid * 0.9 + Vector3.UP * 0.9)
	p.ink(gem, 0.8, 0.6)
	for i in points:
		var am := TAU * (float(i) + 0.5) / float(points)
		var mid := Vector3(sin(am), 0, cos(am))
		p.gem(mid * 1.01 + Vector3.UP * 0.16, Vector3(0.09, 0.1, 0.09))
		p.ball(mid * 0.97 + Vector3.UP * 0.94, Vector3(0.07, 0.07, 0.07), 5, 3)
	return p


## A cloaked figure in a lunge, facing +Z, 1.9 tall, a blade in each hand.
static func figure(cloth: Color, trim: Color, eyes: Color) -> K.Part:
	var p := K.Part.new()
	p.ink(cloth, 0.2)
	p.tube(Vector3(0, 1.0, 0), Vector3(0, 1.5, 0.2), 0.2, 0.25, 5)
	p.ball(Vector3(0, 1.7, 0.3), Vector3(0.18, 0.2, 0.18), 6, 4)
	p.tube(Vector3(0, 1.78, 0.24), Vector3(0, 1.95, -0.12), 0.13, 0.0, 4)
	p.tube(Vector3(-0.1, 1.02, 0), Vector3(-0.18, 0.52, 0.42), 0.12, 0.09, 4)
	p.tube(Vector3(-0.18, 0.52, 0.42), Vector3(-0.2, 0.0, 0.32), 0.09, 0.07, 4)
	p.tube(Vector3(0.1, 1.02, 0), Vector3(0.16, 0.56, -0.42), 0.12, 0.09, 4)
	p.tube(Vector3(0.16, 0.56, -0.42), Vector3(0.2, 0.06, -0.85), 0.09, 0.07, 4)
	p.tube(Vector3(0.22, 1.44, 0.2), Vector3(0.3, 1.32, 0.72), 0.08, 0.06, 4)
	p.tube(Vector3(-0.22, 1.44, 0.12), Vector3(-0.4, 1.3, -0.4), 0.08, 0.06, 4)
	p.ink(trim, 0.2)
	p.tube(Vector3(0, 1.56, 0.1), Vector3(0.12, 1.8, -1.0), 0.1, 0.0, 3, 0.25)
	p.tube(Vector3(0, 1.54, 0.1), Vector3(-0.15, 1.55, -0.8), 0.08, 0.0, 3, 0.25)
	p.ink(eyes, 0.0, 1.0)
	for x in [-0.07, 0.07]:
		p.gem(Vector3(x, 1.71, 0.46), Vector3(0.035, 0.02, 0.02))
	p.tube(Vector3(0.3, 1.32, 0.72), Vector3(0.33, 1.34, 1.35), 0.055, 0.0, 4, 0.3)
	p.tube(Vector3(-0.4, 1.3, -0.4), Vector3(-0.52, 1.14, -0.95), 0.05, 0.0, 4, 0.3)
	return p


## One Part as a SOLID mesh (cached under [param key]).
static func solid(key: String, part: K.Part, pad := Vector3.ONE * 0.5) -> ArrayMesh:
	if _m.has(key):
		return _m[key]
	var st := K.begin()
	K.stamp(st, part)
	return keep(key, K.finish(st, pad))
