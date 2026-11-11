extends RefCounted
## Warrior 50 stars "Lionfang Cleave": the lion's fang. Wind-up: a lion's head with a mane of
## fire flares up behind the warrior while three claw marks smoulder in the cone ahead.
## Hit 1: a great orange crescent cleaves the front from left to right. Hit 2: the return
## stroke crosses it (the "fang" cross-cut) and the lion pounces through the cone, raking
## three glowing claw gouges into the ground and throwing rock and embers forward.
## Compact: everything stays in the front cone (where the hits land). Orange, gold, ember red.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const ORANGE := Color("ff9a1f")
const GOLD := Color("ffd36b")
const EMBER := Color("ff5a1f")
const DEEP := Color("8a2a10")
const ROCK := Color("6b5a4c")
## The cone the hits land in (StarSkillSequence: dot >= 0.25 with the facing).
const HALF := 1.25
const REACH := 6.6


## The omen and the scars: the cone's rim and three claw marks across it.
static func _claws(key: String, glow: Color, trench: Color, width: float, reach: float) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var off := (float(k) - 1.0) * 0.95
		var pts := PackedVector3Array()
		for i in 9:
			var t := float(i) / 8.0
			var z := lerpf(1.1, reach, t)
			pts.append(Vector3(off * (0.55 + t * 0.6) + sin(t * PI) * 0.35, 0.0, z))
		K.ribbon(st, pts, width, glow, 0.03 * float(k), 0.0, Vector3.UP, 1.0)
		K.ribbon(st, pts, width * 0.38, trench, 0.03 * float(k), 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.3, false))


## The cone's rim (where the cleave reaches) as a thin arc and its two edges.
static func _cone() -> ArrayMesh:
	if M.has("lion_cone"):
		return M.get_mesh("lion_cone")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.ribbon(st, M.arc(Vector3.ZERO, REACH, -HALF, HALF, 0.0, 0.0, 30), 0.14, M.a(ORANGE, 0.95), 0.0, 0.0, Vector3.UP, 0.0)
	K.ribbon(st, M.arc(Vector3.ZERO, REACH * 0.94, -HALF, HALF, 0.0, 0.0, 30), 0.05, M.a(GOLD, 0.6), 0.0, 0.0, Vector3.UP, 0.0)
	for s in [-1.0, 1.0]:
		var dir := Vector3(sin(HALF * s), 0, cos(HALF * s))
		K.ribbon(st, PackedVector3Array([dir * 0.8, dir * REACH]), 0.08, M.a(ORANGE, 0.7), 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0, M.a(ORANGE, 0.95))
	return M.keep("lion_cone", K.finish(st, Vector3.ONE * 0.3, false))


## The lion's mane of fire: tongues of flame round a disc, in the XY plane (faces the camera).
static func _mane() -> ArrayMesh:
	if M.has("lion_mane"):
		return M.get_mesh("lion_mane")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 0.85, M.a(EMBER, 0.55), 0.0, 28, 0.0, Vector3.BACK, Vector3(0, 0, -0.05), M.a(EMBER, 0.0), 0.0, true)
	for i in 18:
		var ang := TAU * float(i) / 18.0 + rng.randf_range(-0.08, 0.08)
		var dir := Vector3(sin(ang), cos(ang), 0)
		var side := Vector3(cos(ang), -sin(ang), 0)
		var reach := rng.randf_range(1.05, 1.45) * (1.15 if absf(ang - PI) > 1.2 else 0.85)
		var pts := PackedVector3Array([dir * 0.42, dir * 0.75 + side * 0.08, dir * reach + side * 0.18])
		K.ribbon(st, pts, 0.32, M.a(ORANGE if i % 2 == 0 else EMBER, 0.9), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, M.a(GOLD, 0.0))
	return M.keep("lion_mane", K.finish(st, Vector3.ONE * 0.3, false))


## One stroke of the cleave: a crescent from angle a0 to a1, drawn flat and upright.
static func _stroke(key: String, a0: float, a1: float, y0: float, y1: float, r: float) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := M.arc(Vector3.ZERO, r, a0, a1, y0, y1, 26, r * 1.12)
	# A wide orange blade of light (flat, and standing up for depth), its ember-red back edge.
	K.ribbon(st, pts, 2.6, M.a(ORANGE, 0.95), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, M.a(EMBER, 0.6))
	var up := PackedVector3Array()
	for p in pts:
		up.append(p)
	K.ribbon(st, up, 0.9, M.a(ORANGE, 0.8), 0.0, 0.0, Vector3(pts[13].x, 0, pts[13].z).normalized(), 1.0)
	var back := M.arc(Vector3.ZERO, r * 0.86, a0, a1, y0, y1, 26, r * 0.96)
	K.ribbon(st, back, 0.35, M.a(DEEP, 0.9), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.5, false))


## The lion's paw raking forward: three tall claw strokes standing up through the cone.
static func _rake() -> ArrayMesh:
	if M.has("lion_rake"):
		return M.get_mesh("lion_rake")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var off := (float(k) - 1.0) * 0.9
		var pts := PackedVector3Array()
		for i in 13:
			var t := float(i) / 12.0
			# Down out of the air in front of the warrior, then along the ground and up again.
			pts.append(Vector3(off * (0.7 + t * 0.5), 2.6 * (1.0 - sin(t * PI)) * 0.85 + 0.25, lerpf(0.8, REACH * 0.95, t)))
		K.ribbon(st, pts, 0.55, M.a(ORANGE, 0.95), 0.025 * float(k), 0.0, Vector3.RIGHT, 1.0, 0.0, 1.0, M.a(GOLD, 0.9))
		K.ribbon(st, pts, 0.16, M.a(DEEP, 0.9), 0.025 * float(k), 0.0, Vector3.RIGHT, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return M.keep("lion_rake", K.finish(st, Vector3.ONE * 0.5, false))


## A fan-shaped shockwave (radius 1) over the cone.
static func _fan_shock() -> ArrayMesh:
	if M.has("lion_fan_shock"):
		return M.get_mesh("lion_fan_shock")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.ring(st, 0.92, 0.16, M.a(ORANGE, 1.0), 0.0, 32, 0.0, HALF * 2.0, -HALF)
	K.ring(st, 0.8, 0.06, M.a(GOLD, 0.7), 0.0, 32, 0.0, HALF * 2.0, -HALF)
	return M.keep("lion_fan_shock", K.finish(st, Vector3.ONE * 0.2, false))


## A roaring cartoon lion's head in the XY plane (facing +Z), about 2 across: a mane of
## flame tongues, a gold face, fierce eyes, an open mouth with fangs.
static func _head() -> ArrayMesh:
	if M.has("lion_head"):
		return M.get_mesh("lion_head")
	var p := K.Part.new()
	for i in 16:
		var ang := TAU * float(i) / 16.0
		var dir := Vector3(sin(ang), cos(ang), 0)
		var side := Vector3(cos(ang), -sin(ang), 0)
		p.ink(EMBER if i % 2 == 0 else ORANGE, 0.3)
		p.tube(dir * 0.35 + Vector3(0, 0, -0.08), dir * (0.98 if i % 2 == 0 else 0.82) + side * 0.12 + Vector3(0, 0, -0.12), 0.2, 0.0, 4, 0.35)
	p.ink(GOLD, 0.4)
	p.ball(Vector3(0, 0, 0.0), Vector3(0.5, 0.52, 0.28), 9, 5)
	for s in [-1.0, 1.0]:
		p.ball(Vector3(s * 0.38, 0.42, -0.02), Vector3(0.13, 0.13, 0.08), 6, 3)
	p.ink(Color("fff0c8"), 0.3)
	p.ball(Vector3(0, -0.17, 0.2), Vector3(0.27, 0.19, 0.15), 8, 4)
	p.ink(Color("3a1206"), 0.6)
	p.gem(Vector3(0, -0.04, 0.35), Vector3(0.09, 0.06, 0.05))
	p.box(Vector3(0, -0.31, 0.27), Vector3(0.24, 0.1, 0.06))
	for s in [-1.0, 1.0]:
		p.ink(Color("3a1206"), 0.2, 0.0)
		p.box(Vector3(s * 0.17, 0.2, 0.24), Vector3(0.16, 0.035, 0.04))
		p.ink(Color("fff6c0"), 0.0, 1.0)
		p.gem(Vector3(s * 0.16, 0.11, 0.26), Vector3(0.06, 0.045, 0.03))
		p.ink(Color("fffaf0"), 0.8)
		p.tube(Vector3(s * 0.08, -0.27, 0.3), Vector3(s * 0.08, -0.38, 0.3), 0.025, 0.0, 4)
	return M.solid("lion_head", p)


static func _lion(art: StarSkillArt, label: String, at: Vector3, size: float, seconds: float, style: Dictionary) -> void:
	K.put(art, K.SOLID, _head(), label, at, Vector3.ONE * size, seconds, {"rim_color": Color("ffe9a0"), "rim": 0.55, "glow_color": Color("fff0a0")}, style)


static func telegraph(art: StarSkillArt, _caster: Node3D, _skill: Dictionary, _point: Vector3, time: float) -> bool:
	# The lion rises behind the shoulder, its mane of fire flaring round it.
	_lion(art, "LionHead", Vector3(0, 2.9, -0.9), 1.1, time + 0.08, {"initial": 0.3, "grow_time": 0.55, "fade_in": 0.2, "decay": 0.8, "face_camera": true, "travel": Vector3.UP * 0.3})
	K.put(art, K.FLAT, _mane(), "LionMane", Vector3(0, 2.95, -1.7), Vector3.ONE * 1.0, time + 0.1, {"soft": 0.8, "hot": M.hot(GOLD), "core": 0.45, "flow": 2.2, "flick": 0.12, "add": 0.7}, {"initial": 0.2, "grow_time": 0.6, "fade_in": 0.2, "decay": 0.8, "face_camera": true, "travel": Vector3.UP * 0.3})
	# The cone it will cleave, and the claw marks smouldering in it.
	K.put(art, K.FLAT, _cone(), "LionCone", Vector3.UP * 0.06, Vector3.ONE, time + 0.35, {"sweep": time * 0.6, "soft": 0.5, "hot": M.hot(ORANGE, 0.7), "core": 0.5, "add": 0.4}, {"fade_in": 0.08, "decay": 0.85})
	K.put(art, K.FLAT, _claws("lion_omen", M.a(ORANGE, 0.75), Color(0.18, 0.06, 0.02, 0.6), 0.7, REACH * 0.92), "LionOmen", Vector3.UP * 0.05, Vector3.ONE, time + 0.1, {"sweep": time * 0.85, "soft": 0.7, "flick": 0.15, "add": 0.5}, {"fade_in": 0.1, "decay": 0.85})
	M.sparks(art, "lion_gather", [ORANGE, GOLD, EMBER], 22, 0.3, 1.1, 0.6, 2.6, 0.13, 0.0, time + 0.15, Vector3.ZERO, -1.5, 13, 0.1, 1.6)
	return true


static func strike(art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _point: Vector3, index: int, _source: Vector3) -> bool:
	if index == 0:
		# Left to right, falling: the first fang.
		K.put(art, K.FLAT, _stroke("lion_stroke_a", -HALF, HALF, 1.7, 0.7, 3.5), "LionFangA", Vector3.ZERO, Vector3.ONE, 0.42, {"sweep": 0.1, "tail": 0.9, "soft": 0.7, "hot": M.hot(GOLD), "core": 0.4, "add": 0.65, "gain": 1.1}, {"fade_in": 0.01, "decay": 0.5})
		K.put(art, K.FLAT, _claws("lion_scar_a", M.a(ORANGE, 0.75), Color(0.16, 0.05, 0.02, 0.9), 0.55, REACH), "LionScarA", Vector3.UP * 0.06, Vector3.ONE, 0.9, {"sweep": 0.12, "soft": 0.6, "hot": M.hot(ORANGE), "core": 0.4, "add": 0.6}, {"decay": 0.6}, Vector3(0, -0.12, 0))
		K.put(art, K.BITS, M.fan("lion_sparks_a", "ember", 30, 1.0, 3.5, HALF, 6.5, 3.5, [ORANGE, GOLD, EMBER], 0.17, 21, 0.6, 1.6), "LionSparksA", Vector3.ZERO, Vector3.ONE, 0.75, {"life": 0.6, "gravity": 6.0, "drag": 1.8, "piece": 0.17, "add": 0.75, "shrink": 0.3}, {"decay": 0.8})
		K.put(art, K.FLAT, _fan_shock(), "LionShockA", Vector3.UP * 0.1, Vector3.ONE * REACH, 0.45, {"soft": 1.2, "hot": M.hot(ORANGE, 0.9), "core": 0.5, "add": 0.55}, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.02, "decay": 0.35})
		K.put(art, K.BITS, M.fan("lion_dust_a", "puff", 12, 1.0, 4.5, HALF, 2.5, 0.8, [Color("c9a27a"), Color("b48c66")], 0.8, 22, 0.1, 0.3), "LionDustA", Vector3.ZERO, Vector3.ONE, 1.0, {"life": 0.9, "gravity": -0.4, "drag": 2.2, "piece": 0.8, "swell": 1.8, "alpha": 0.45, "shrink": 0.35, "spin": 1.2}, {"decay": 0.85})
		return true
	# The return stroke crosses the first (the fang's cross-cut) and the lion pounces through.
	K.put(art, K.FLAT, _stroke("lion_stroke_b", HALF, -HALF, 0.6, 1.8, 4.1), "LionFangB", Vector3.ZERO, Vector3.ONE, 0.45, {"sweep": 0.1, "tail": 0.9, "soft": 0.7, "hot": M.hot(GOLD), "core": 0.4, "add": 0.65, "gain": 1.15}, {"fade_in": 0.01, "decay": 0.5})
	K.put(art, K.FLAT, _rake(), "LionRake", Vector3.ZERO, Vector3.ONE, 0.5, {"sweep": 0.1, "tail": 3.0, "soft": 0.6, "hot": M.hot(GOLD), "core": 0.4, "add": 0.65, "gain": 1.1}, {"fade_in": 0.01, "decay": 0.5})
	K.put(art, K.FLAT, _claws("lion_scar_b", M.a(ORANGE, 0.9), Color(0.14, 0.04, 0.02, 1.0), 0.75, REACH * 1.05), "LionScarB", Vector3.UP * 0.07, Vector3.ONE, 1.5, {"sweep": 0.14, "soft": 0.55, "hot": M.hot(GOLD), "core": 0.35, "flick": 0.08, "add": 0.65, "gain": 1.1}, {"decay": 0.55}, Vector3(0, 0.1, 0))
	K.put(art, K.BITS, M.fan("lion_rubble", "rock", 22, 1.2, 5.0, HALF, 4.5, 6.5, [ROCK, ROCK.lightened(0.15), ROCK.darkened(0.2)], 0.32, 23), "LionRubble", Vector3.ZERO, Vector3.ONE, 1.3, {"life": 1.1, "gravity": 18.0, "piece": 0.32, "floor_y": 0.06, "shrink": 0.8, "spin": 7.0, "hot": Color(1.0, 0.6, 0.2, 0.4)}, {"decay": 0.9})
	K.put(art, K.FLAT, _fan_shock(), "LionShockB", Vector3.UP * 0.11, Vector3.ONE * REACH * 1.12, 0.5, {"soft": 1.2, "hot": M.hot(GOLD, 0.9), "core": 0.5, "add": 0.6}, {"initial": 0.15, "grow_time": 0.8, "fade_in": 0.02, "decay": 0.35})
	M.sparks(art, "lion_embers", [ORANGE, GOLD, EMBER], 40, 0.5, REACH * 0.4, 0.8, 3.0, 0.15, 0.05, 1.4, Vector3(0, 0, REACH * 0.5), -1.0, 24, 0.1, 1.2)
	return true
