extends RefCounted
## Lancer god skill "หอกเทพทะลวงฟ้า" (heavenrend_spear): the dragon-spear that rends heaven.
## Wind-up: the ground glows and cracks with heat, the sky tears open overhead. Four waves:
## rings of spears burst out of the earth round the caster, each ring wider than the last,
## throwing rock, dust and flame-red dragon scales. Finale: the giant dragon-spear drives
## down out of the torn sky in a drill of fire and leaves a crater ringed with broken rock.
## Red, orange and ember over dark rock.
const K := preload("res://combat/god_art/_kit_melee.gd")
const RED := Color("e0261c")
const ORANGE := Color("ff7a1c")
const EMBER := Color("ffc44a")
const IRON := Color("4a3a40")
const SHAFT := Color("2c1a1c")
const ROCK := Color("4a3a36")
const CREVICE := Color(0.16, 0.04, 0.02, 1.0)
const ID := "heavenrend_spear"
const RINGS := [0.3, 0.5, 0.72, 0.94]
const COUNTS := [6, 9, 12, 15]
## The god-spear's length: the dragon's head stays at eye level for the third-person camera.
const GIANT := 9.5
## How far beyond the caster (as the camera sees it) the god-spear lands.
const BEYOND := 4.0
static var _cache := {}


## A spear: butt on the origin, point at +Y 1. [param dragon]: the god-spear, a dragon
## coiled up the shaft with the blade in its jaws.
static func _spear(dragon := false) -> K.Part:
	var key := "spear_dragon" if dragon else "spear"
	if _cache.has(key):
		return _cache[key]
	var p := K.Part.new()
	p.ink(SHAFT, 0.3)
	p.tube(Vector3.ZERO, Vector3(0, 0.72, 0), 0.016, 0.015, 6)
	p.ink(EMBER, 0.9)
	for y in [0.18, 0.44, 0.64]:
		p.tube(Vector3(0, y, 0), Vector3(0, y + 0.018, 0), 0.023, 0.023, 6)
	# The collar: a red flare and four back-swept horns.
	p.ink(RED, 0.4)
	p.tube(Vector3(0, 0.66, 0), Vector3(0, 0.75, 0), 0.02, 0.055, 6)
	for i in 4:
		var a := PI / 4.0 + PI / 2.0 * float(i)
		var dir := Vector3(cos(a), 0, sin(a))
		p.ink(ORANGE, 0.6, 0.25)
		p.tube(dir * 0.04 + Vector3(0, 0.73, 0), dir * 0.12 + Vector3(0, 0.6, 0), 0.02, 0.0, 4)
	# The blade: dark iron, its spine burning.
	p.ink(IRON, 1.0)
	p.tube(Vector3(0, 0.74, 0), Vector3(0, 0.83, 0), 0.028, 0.068, 4, 0.28, false)
	p.tube(Vector3(0, 0.83, 0), Vector3(0, 1.0, 0), 0.068, 0.0, 4, 0.28, false)
	p.ink(ORANGE, 0.0, 1.0)
	p.box(Vector3(0, 0.85, 0), Vector3(0.016, 0.2, 0.046))
	if dragon:
		# The dragon: coils up the shaft, spines along its back.
		var last := Vector3.ZERO
		for i in 25:
			var t := float(i) / 24.0
			var a := t * TAU * 2.6
			var at := Vector3(cos(a) * 0.045, 0.2 + t * 0.46, sin(a) * 0.045)
			if i > 0:
				p.ink(RED.lerp(Color("8a1010"), 0.4 * float(i % 2)), 0.5)
				p.tube(last, at, 0.012 + 0.02 * t, 0.012 + 0.02 * (t + 0.04), 5)
				if i % 2 == 0:
					p.ink(EMBER, 0.6, 0.35)
					p.tube(at, at + Vector3(cos(a), 0.25, sin(a)) * (0.03 + 0.03 * t), 0.012, 0.0, 3)
			last = at
		# The head, jaws round the blade's root, long horns swept back down the shaft.
		p.ink(RED, 0.6)
		p.tube(Vector3(0, 0.66, 0.0), Vector3(0, 0.79, 0.0), 0.075, 0.045, 6)
		p.ink(Color("8a1010"), 0.4)
		for s in [-1.0, 1.0]:
			p.tube(Vector3(0, 0.77, s * 0.04), Vector3(0, 0.86, s * 0.075), 0.03, 0.0, 4, 0.5)
			for x in [-1.0, 1.0]:
				p.ink(EMBER, 0.8, 0.2)
				p.tube(Vector3(x * 0.05, 0.7, s * 0.03), Vector3(x * 0.2, 0.52, s * 0.07), 0.022, 0.0, 4)
				p.ink(Color(1.0, 0.95, 0.6), 0.0, 1.0)
				p.gem(Vector3(x * 0.055, 0.745, s * 0.045), Vector3.ONE * 0.014)
				p.ink(Color("8a1010"), 0.4)
	_cache[key] = p
	return p


## Out from the centre by [param lean] radians, for a piece standing at angle a.
static func _lean(a: float, lean: float, size: float) -> Basis:
	return Basis(Vector3(cos(a), 0, -sin(a)), lean).scaled(Vector3.ONE * size)


## One ring: [spears and rock SOLID, lava light FLAT, rock / scales BITS, embers BITS].
static func _ring_meshes(index: int, r: float) -> Array:
	var key := "ring%d" % (index % 4)
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 70 + index
	var radius := r * float(RINGS[index % 4])
	var count: int = COUNTS[index % 4]
	var solid := K.begin()
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bits := SurfaceTool.new()
	bits.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sparks := SurfaceTool.new()
	sparks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flight := 0.15
	var start := rng.randf() * TAU
	for i in count:
		var a := start + TAU * float(i) / float(count)
		var dir := Vector3(sin(a), 0, cos(a))
		var at := dir * radius * rng.randf_range(0.95, 1.05)
		var delay := 0.1 * float(i) / float(count)
		var length := (3.7 + 0.35 * float(index)) * rng.randf_range(0.85, 1.15)
		K.stamp(solid, _spear(), Transform3D(_lean(a + rng.randf_range(-0.25, 0.25), 0.3 + rng.randf_range(-0.1, 0.12), length), at + Vector3.DOWN * 0.5), delay, 1.0)
		# Broken ground heaved up round each shaft.
		for k in 3:
			var b := a + rng.randf_range(-1.4, 1.4)
			var off := Vector3(sin(b), 0, cos(b)) * rng.randf_range(0.3, 0.6)
			K.stamp(solid, K.spike(rng, ROCK, 0.35), Transform3D(_lean(b, 0.5, rng.randf_range(0.7, 1.3)), at + off + Vector3.DOWN * 0.1), delay, 0.22)
		K.disc(flat, 1.6, Color(1.0, 0.6, 0.15, 0.9), 0.08, 12, delay + 0.03, Vector3.UP, at, Color(1.0, 0.3, 0.05, 0.0), -1.0)
		K.crack_star(flat, rng, at + Vector3.UP * 0.05, 4, 0.1, 1.6, 0.22, CREVICE, delay + 0.03, 1, 0.3)
		K.burst_at(bits, rng, "rock", 4, at, 0.1, 0.5, 2.6, 6.5, [ROCK, ROCK.lightened(0.14), ROCK.darkened(0.2)], 0.36, delay + 0.02, 0.04)
		K.burst_at(bits, rng, "scale", 4, at, 0.1, 0.5, 2.2, 7.5, [RED, ORANGE, Color("b0120e")], 0.3, delay + 0.02, 0.06, 0.4, 1.6)
		K.burst_at(sparks, rng, "ember", 5, at, 0.1, 0.6, 1.6, 6.0, [EMBER, ORANGE, Color("ffe9a0")], 0.15, delay + 0.02, 0.1, 0.2, 1.2)
	# The ring itself glows through the ground as the spears come up.
	K.ring(flat, radius, 0.7, Color(1.0, 0.42, 0.08, 0.8), 0.06, 48, 0.0)
	_cache[key] = [K.finish(solid, Vector3(0.5, 7.0, 0.5)), K.finish(flat, Vector3.ONE * 0.5, false), K.finish(bits, Vector3(7, 9, 7), false), K.finish(sparks, Vector3(7, 9, 7), false)]
	return _cache[key]


static func _giant() -> ArrayMesh:
	if not _cache.has("giant"):
		var st := K.begin()
		# Point down on the origin.
		K.stamp(st, _spear(true), Transform3D(Basis(Vector3.RIGHT, PI), Vector3.UP))
		_cache.giant = K.finish(st, Vector3(0.5, 4.0, 0.5))
	return _cache.giant


## The drill of fire: two flames wound round the spear, wider with height.
static func _drill() -> ArrayMesh:
	if not _cache.has("drill"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for strand in 3:
			var pts := PackedVector3Array()
			for i in 49:
				var t := float(i) / 48.0
				var a := t * TAU * 2.2 + TAU * float(strand) / 3.0
				var radius := 0.05 + 0.2 * t
				pts.append(Vector3(cos(a) * radius, t, sin(a) * radius))
			var color := [Color(1.0, 0.45, 0.08, 0.95), Color(1.0, 0.2, 0.05, 0.9), Color(1.0, 0.7, 0.2, 0.9)][strand] as Color
			K.ribbon(st, pts, 0.16, color, 0.0, 1.0, Vector3.UP, 0.6)
		_cache.drill = K.finish(st, Vector3(0.5, 4.0, 0.5), false)
	return _cache.drill


## The crater: a ring of slabs of ground heaved up and outward.
static func _crater() -> ArrayMesh:
	if not _cache.has("crater"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var st := K.begin()
		for i in 16:
			var a := TAU * float(i) / 16.0 + rng.randf_range(-0.12, 0.12)
			var dir := Vector3(sin(a), 0, cos(a))
			var size := rng.randf_range(1.3, 2.3)
			K.stamp(st, K.spike(rng, ROCK, 0.25), Transform3D(_lean(a, rng.randf_range(0.55, 0.95), 1.0) * Basis.from_scale(Vector3(1.9, 1.0, 1.9) * size), dir * rng.randf_range(2.6, 3.4) + Vector3.DOWN * 0.15), rng.randf() * 0.05, 1.0)
		for i in 10:
			var a := rng.randf() * TAU
			K.stamp(st, K.spike(rng, ROCK.darkened(0.15), 0.3), Transform3D(_lean(a, rng.randf_range(0.3, 0.7), 1.0) * Basis.from_scale(Vector3(1.6, 1.0, 1.6) * rng.randf_range(0.5, 0.9)), Vector3(sin(a), 0, cos(a)) * rng.randf_range(3.6, 4.6) + Vector3.DOWN * 0.1), 0.04 + rng.randf() * 0.06, 0.7)
		_cache.crater = K.finish(st, Vector3(0.5, 2.5, 0.5))
	return _cache.crater


## Scorch, lava and fissures under the crater: one FLAT mesh (radius 1 = the hit area).
static func _lava() -> ArrayMesh:
	if not _cache.has("lava"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 8
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		K.disc(st, 0.5, Color(0.07, 0.03, 0.03, 0.95), 0.0, 32, 0.0, Vector3.UP, Vector3.ZERO, Color(0.07, 0.03, 0.03, 0.0), 0.0, true)
		K.disc(st, 0.2, Color(1.0, 0.45, 0.08, 0.9), 0.004, 24, 0.0, Vector3.UP, Vector3.ZERO, Color(1.0, 0.2, 0.02, 0.0), 0.0, true)
		K.crack_star(st, rng, Vector3.UP * 0.008, 10, 0.2, 1.0, 0.05, CREVICE, 0.0, 1, 0.3)
		_cache.lava = K.finish(st, Vector3.ONE * 0.2, false)
	return _cache.lava


## The torn sky: a jagged black wound with burning lips, lying flat overhead (radius 1).
static func _rift() -> ArrayMesh:
	if not _cache.has("rift"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 12
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rim := PackedVector3Array()
		var n := 26
		for i in n + 1:
			var a := TAU * float(i % n) / float(n)
			var jag := 1.0 if i % 2 == 0 else rng.randf_range(0.5, 0.75)
			if i == n:
				rim.append(rim[0])
			else:
				rim.append(Vector3(sin(a) * jag, 0, cos(a) * 0.62 * jag))
		st.set_normal(Vector3.UP)
		st.set_uv2(Vector2.ZERO)
		for i in n:
			for item in [[Vector3.ZERO, 0.5], [rim[i], 0.5], [rim[i + 1], 0.5]]:
				st.set_color(Color(0.05, 0.0, 0.03, 0.97))
				st.set_uv(Vector2(item[1], -1.0))
				st.add_vertex(item[0])
		K.ribbon(st, rim, 0.2, Color(1.0, 0.35, 0.05, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
		for i in 9:
			var a := rng.randf() * TAU
			var from := Vector3(sin(a), 0, cos(a) * 0.62) * 0.95
			K.ribbon(st, PackedVector3Array([from, from * rng.randf_range(1.3, 1.8) + Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))]), 0.07, Color(1.0, 0.55, 0.12, 0.9), 0.0, 0.0, Vector3.UP, 1.0)
		_cache.rift = K.finish(st, Vector3.ONE * 0.2, false)
	return _cache.rift


## A wall of flame tongues on a ring of radius 1, 1 tall.
static func _flames() -> ArrayMesh:
	if not _cache.has("flames"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 4
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 30:
			var a := TAU * float(i) / 30.0 + rng.randf_range(-0.05, 0.05)
			var dir := Vector3(sin(a), 0, cos(a))
			var h := rng.randf_range(0.5, 1.0)
			var sway := Vector3(cos(a), 0, -sin(a)) * rng.randf_range(-0.05, 0.05)
			var color := Color(1.0, rng.randf_range(0.25, 0.6), 0.06, 0.9)
			K.ribbon(st, PackedVector3Array([dir, dir + sway + Vector3.UP * h * 0.5, dir - sway * 0.5 + Vector3.UP * h]), 0.16, color, rng.randf() * 0.12, 0.0, dir, 0.9)
		_cache.flames = K.finish(st, Vector3.ONE * 0.3, false)
	return _cache.flames


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := K.radius(skill)
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	# The caster: heat pours up round the planted feet.
	K.put(art, K.FLAT, _flames(), "SpearHeat", Vector3.UP * 0.05, Vector3(1.5, 2.6, 1.5), time, {"soft": 1.2, "flow": 3.0, "hot": Color(1, 0.9, 0.5, 0.9), "core": 0.5, "add": 0.7}, {"initial": 0.4, "grow_time": 0.9, "fade_in": 0.2, "spin": 1.2, "decay": 0.9})
	var ground := K.extra(parent, Vector3(point.x, 0, point.z), time, "StarGodGround_" + ID, origin, art)
	if ground:
		K.put(ground, K.FLAT, K.area_ring("spear_area", Color(1.0, 0.5, 0.1, 1.0), 18), "SpearArea", Vector3.UP * 0.07, Vector3.ONE * r, time + 0.25, {"soft": 0.5, "hot": Color(1, 0.85, 0.4, 0.8), "core": 0.5, "add": 0.35}, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.1, "spin": -0.2, "decay": 0.9})
		# The ground heats and splits from the middle outward.
		K.put(ground, K.FLAT, _lava(), "SpearOmen", Vector3.UP * 0.05, Vector3.ONE * r * 0.75, time + 0.1, {"soft": 0.4, "sweep": time * 0.95, "hot": Color(1, 0.6, 0.12, 1.0), "core": 0.25, "flick": 0.12, "add": 0.6}, {"fade_in": 0.3, "decay": 0.92})
		ground._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var sky := K.extra(parent, Vector3(point.x, 0, point.z), time, "StarGodSky_" + ID, origin, art)
	if sky:
		var spot := K.beyond(sky, BEYOND)
		# The wound hangs as high as the camera shows over that spot.
		var top := K.sky(sky, spot, 7.4) + 1.2
		# The wound opens beyond the field and tips its face to the camera: seen from high
		# up, anything hung over the fight would only hide it.
		var far := K.beyond(sky, BEYOND + 5.5)
		K.put(sky, K.FLAT, _rift(), "SpearRift", far + Vector3.UP * maxf(1.6, K.sky(sky, far, 8.6) - 1.2), Vector3.ONE * 3.6, time + 0.4, {"soft": 0.6, "hot": Color(1, 0.9, 0.5, 1.0), "core": 0.55, "flick": 0.15, "add": 0.5}, {"initial": 0.08, "grow_time": 0.85, "fade_in": 0.1, "decay": 0.9}, K.tipped(sky, 1.0))
		K.put(sky, K.SOLID, _giant(), "SpearOmenPoint", spot + Vector3.UP * (top - 1.0), Vector3(GIANT * 2.1, GIANT, GIANT * 2.1), time, {"rim_color": ORANGE, "rim": 0.6, "glow_color": EMBER}, {"fade_in": 0.5, "travel": Vector3.DOWN * 1.8, "decay": 0.97, "spin": 2.0, "delay": time * 0.35})
		K.put(sky, K.BITS, K.burst("spear_cinders", "ember", 50, 0.2, 3.0, 0.8, -2.5, [EMBER, ORANGE, RED], 0.2, 1.0, 14, 7.0, 8.4), "SpearCinders", spot + Vector3.UP * (top - 8.6), Vector3.ONE, time + 0.3, {"life": 1.6, "gravity": 3.0, "drag": 0.6, "piece": 0.2, "sway": 0.3, "add": 0.7, "shrink": 0.4}, {"delay": time * 0.3, "decay": 0.9})
		sky._draw()
	return true


static func wave(art: StarSkillArt, _parent: Node3D, skill: Dictionary, index: int, _point: Vector3, _source: Vector3) -> bool:
	var r := K.radius(skill)
	var meshes := _ring_meshes(index, r)
	# The rings stand until the god-spear has struck.
	# (the inner rings go down with the crater, the outer ones stand as its crown)
	var stay := (1.5 - 0.32 * float(index)) + (0.35 if index < 2 else 1.3)
	K.put(art, K.SOLID, meshes[0], "SpearRing", Vector3.ZERO, Vector3.ONE, stay, {"drop": -5.5, "flight": 0.15, "ease": 1.0, "heat": 0.8, "rim_color": ORANGE, "rim": 0.55, "glow_color": Color("ffb040")}, {"decay": 0.85})
	K.put(art, K.FLAT, meshes[1], "SpearRingLava", Vector3.ZERO, Vector3.ONE, stay, {"flash": 0.35, "sweep": 0.18, "soft": 0.45, "hot": Color(1, 0.62, 0.14, 1.0), "core": 0.28, "flick": 0.12, "add": 0.6}, {"decay": 0.6})
	K.put(art, K.BITS, meshes[2], "SpearRingRubble", Vector3.ZERO, Vector3.ONE, 1.6, {"life": 1.25, "gravity": 18.0, "piece": 0.36, "floor_y": 0.06, "shrink": 0.75, "hot": Color(1.0, 0.45, 0.1, 0.6)}, {"decay": 0.9})
	K.put(art, K.BITS, meshes[3], "SpearRingEmbers", Vector3.ZERO, Vector3.ONE, 1.4, {"life": 1.1, "gravity": 3.0, "drag": 1.2, "piece": 0.15, "sway": 0.2, "add": 0.7, "shrink": 0.3}, {"decay": 0.8})
	return true


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	var r := K.radius(skill)
	var flight := 0.22
	var spot := K.beyond(art, BEYOND)
	# It leans across the screen as far as it must for the dragon's head and the blade's
	# root to stay in the camera's frame, and is no longer than the frame allows.
	var pose := K.framed(art, spot, GIANT * 1.05, 0.85)
	var giant := GIANT * float(pose[0])
	var tilt := float(pose[1]) + 0.08
	var size := Vector3(giant * 2.3, giant, giant * 2.3)
	var lean := K.leaned(art, K.facing(art) + 0.4, tilt, 1.0)
	var tall := giant * 0.94 * cos(tilt)
	# The god-spear: out of the torn sky, point first, to the hilt of its blade in the ground.
	K.put(art, K.SOLID, _giant(), "SpearGod", spot + Vector3.DOWN * giant * 0.06, size, 2.4, {"drop": 30.0 / giant, "flight": flight, "heat": 0.9, "rim_color": ORANGE, "rim": 0.6, "glow_color": Color("ffb040")}, {"decay": 0.82}, lean)
	K.put(art, K.SOLID, _crater(), "SpearCrater", spot, Vector3.ONE, 2.3, {"drop": -1.6, "flight": 0.12, "ease": 1.0, "heat": 0.6, "rim_color": ORANGE, "rim": 0.35, "glow_color": Color("ff7a20")}, {"delay": flight, "decay": 0.85})
	K.put(art, K.FLAT, _lava(), "SpearLava", spot * 0.5 + Vector3.UP * 0.06, Vector3.ONE * r * 1.05, 2.3, {"sweep": 0.3, "soft": 0.4, "hot": Color(1, 0.62, 0.14, 1.0), "core": 0.25, "flick": 0.1, "add": 0.6, "gain": 1.15}, {"delay": flight, "decay": 0.7})
	K.put(art, K.FLAT, _drill(), "SpearDrill", spot + Vector3.UP * 0.2, Vector3(giant, giant * 0.9, giant), 1.1, {"drop": 30.0 / giant / 0.9, "flight": flight, "soft": 1.0, "flow": 5.0, "hot": Color(1, 0.95, 0.6, 0.9), "core": 0.5, "add": 0.75, "gain": 1.2}, {"decay": 0.45}, lean)
	K.put(art, K.BITS, K.burst("spear_rubble", "rock", 44, 1.0, 3.2, 8.0, 12.0, [ROCK, ROCK.lightened(0.15), ROCK.darkened(0.25)], 0.7, 0.05, 61), "SpearRubble", spot, Vector3.ONE, 2.2, {"life": 1.9, "gravity": 22.0, "piece": 0.7, "floor_y": 0.1, "shrink": 0.8, "spin": 7.0, "hot": Color(1.0, 0.4, 0.08, 0.9)}, {"delay": flight, "decay": 0.9})
	K.put(art, K.FLAT, K.shock("spear_shock", Color(1.0, 0.45, 0.1, 1.0), 0.22), "SpearShock", spot * 0.5 + Vector3.UP * 0.12, Vector3.ONE * r * 1.25, 0.6, {"soft": 1.2, "hot": Color(1, 0.95, 0.7, 1.0), "core": 0.5, "add": 0.6}, {"delay": flight, "initial": 0.06, "grow_time": 0.75, "fade_in": 0.02, "decay": 0.3})
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	# The wound in the sky it came through, raining cinders and scales.
	var avatar := K.extra(parent, point, 2.2, "StarGodAvatar_" + ID, source)
	if avatar:
		var far := K.beyond(avatar, BEYOND + 5.5)
		K.put(avatar, K.FLAT, _rift(), "SpearRiftOpen", far + Vector3.UP * maxf(1.6, K.sky(avatar, far, 8.6) - 1.4), Vector3.ONE * 4.4, 2.0, {"soft": 0.6, "hot": Color(1, 0.9, 0.5, 1.0), "core": 0.55, "flick": 0.15, "add": 0.5, "priority": -1}, {"initial": 0.75, "grow_time": 0.3, "decay": 0.65}, K.tipped(avatar, 1.0))
		K.put(avatar, K.BITS, K.burst("spear_scales", "scale", 60, 0.5, r * 0.8, 3.5, 9.0, [RED, ORANGE, Color("b0120e"), EMBER], 0.42, 0.25, 62, 0.3, 2.0), "SpearScales", spot * 0.5, Vector3.ONE, 2.2, {"life": 2.0, "gravity": 9.0, "drag": 0.7, "piece": 0.42, "sway": 0.3, "spin": 9.0, "floor_y": 0.08, "shrink": 0.85}, {"delay": flight, "decay": 0.85})
		K.put(avatar, K.BITS, K.burst("spear_embers", "ember", 80, 0.3, r * 0.8, 1.5, 5.5, [EMBER, ORANGE, Color("ffe9a0")], 0.2, 0.5, 63, 0.1, 1.5), "SpearEmbers", spot * 0.5, Vector3.ONE, 2.3, {"life": 1.9, "gravity": -1.5, "drag": 1.3, "piece": 0.2, "sway": 0.3, "add": 0.7, "shrink": 0.3}, {"delay": flight + 0.05, "decay": 0.8})
		avatar._draw()
	if extras < 2:
		return true
	# The rim of the hit area goes up in a wall of flame.
	var temple := K.extra(parent, point, 2.2, "StarGodTemple_" + ID, source)
	if temple:
		K.put(temple, K.FLAT, _flames(), "SpearFlameWall", Vector3.UP * 0.05, Vector3(r, 3.4, r), 1.7, {"soft": 1.0, "flow": 4.0, "sweep": 0.35, "hot": Color(1, 0.9, 0.5, 0.9), "core": 0.5, "add": 0.7}, {"delay": flight + 0.2, "initial": 0.7, "grow_time": 0.2, "spin": 0.4, "decay": 0.55})
		K.put(temple, K.FLAT, _flames(), "SpearFlameCore", spot + Vector3.UP * 0.05, Vector3(3.4, 5.5, 3.4), 1.6, {"soft": 1.0, "flow": 5.0, "sweep": 0.3, "hot": Color(1, 0.95, 0.6, 0.9), "core": 0.45, "add": 0.75}, {"delay": flight, "spin": -0.8, "decay": 0.5})
		K.put(temple, K.FLAT, K.shock("spear_shock2", Color(1.0, 0.3, 0.06, 0.85), 0.1), "SpearShock2", Vector3.UP * 0.1, Vector3.ONE * r * 1.6, 0.9, {"soft": 1.2, "add": 0.5}, {"delay": flight + 0.12, "initial": 0.1, "grow_time": 0.8, "decay": 0.3})
		temple._draw()
	return true
