extends RefCounted
## Summoner 100 stars: กระแสเลวีอาธาน. The sea answers the Summoner: a whirlpool opens
## at the feet and the ground ahead turns to dark rolling water. On each of three beats
## the Leviathan, a great sea serpent of teal scales and a pale belly (one mesh laid on
## a spline), breaches out of the sea in front, arcs over the field and dives back in,
## while a curling wave rushes out across the cone; where the serpent dives the sea
## bursts in spray and foam. The third breach is the crash: a column of water and a
## wide fan of foam. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const ID := "leviathan_surge"
const BODY := 11.0
const SPACING := 0.7
const LANES := [-2.3, 2.5, 0.0]
const TEAL := Color("12a8c0")
const TEAL_HI := Color("5ae8e8")
const DEEP := Color("0a4a7a")
const BELLY := Color("d8fff4")
const FOAM := Color("eafffc")
const GOLD := Color("ffd45a")
const SERPENT_LOOK := {"rim_color": Color("c8fff6"), "rim": 0.6, "shadow_tint": Color(0.45, 0.62, 0.82), "scales": 1.0, "girth": 1.0, "wave_amp": 0.25, "wave_len": 6.0, "wave_speed": 8.0}
static var _launched := 0
static var _courses := {}


static func _r(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 10.0)), 5.0, 10.0)


## The serpent's leap through lane [param k] (in a root at the caster facing forward):
## its points, where its head breaks the surface and where it dives back in (metres along).
static func course(k: int) -> Dictionary:
	if _courses.has(k):
		return _courses[k]
	var x0: float = LANES[k % 3]
	var way := [Vector3(x0 * 0.3, -5.0, -2.0), Vector3(x0 * 0.55, -1.2, 0.8), Vector3(x0 * 0.8, 1.9, 3.2), Vector3(x0, 3.3, 5.3), Vector3(x0 * 1.05, 2.2, 7.4), Vector3(x0 * 1.1, -0.2, 8.9), Vector3(x0 * 1.15, -5.0, 10.6), Vector3(x0 * 1.2, -11.0, 12.0)]
	var points := K.resample(K.smooth(way, 10), SPACING)
	var rise := 0
	while rise < points.size() - 1 and points[rise].y < 0.0: rise += 1
	var dive := rise + 1
	while dive < points.size() - 1 and points[dive].y > 0.0: dive += 1
	var c := {"points": points, "rise": float(rise) * SPACING, "dive": float(dive) * SPACING, "splash": Vector3(points[dive].x, 0, points[dive].z)}
	_courses[k] = c
	return c


static func _yaw(source: Vector3, point: Vector3) -> float:
	var f := S.forward_of(ID, source, point)
	return atan2(f.x, f.z)


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	_launched = 0
	var r := _r(skill)
	# (StarSignature has already turned the wind-up root to the cast's facing.)
	# A whirlpool opens at the feet; the ground ahead turns to dark rolling sea.
	K.put(art, K.VEIL, S.whirlpool("leviathan", DEEP, TEAL, FOAM), "SurgeWhirl", Vector3.UP * 0.05, Vector3.ONE * 1.8, Vector3.ZERO, time + 0.1, {"initial": 0.2, "grow_time": 0.6, "fade_in": 0.15, "spin": -5.0, "decay": 0.92})
	K.put(art, K.VEIL, sea_mesh(), "SurgeSea", Vector3.UP * 0.04, Vector3.ONE * r, Vector3.ZERO, time + 0.1, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.98, "priority": -2}, S.WATER_LOOK.merged({"flow": Vector2(0.0, -0.8), "bias": 0.5, "taper": 0.2}, true))
	K.put(art, K.VEIL, S.spray("surge_rise", [TEAL_HI, FOAM, TEAL], 18, 2.5, 1.2), "SurgeDrops", Vector3.UP * 0.2, Vector3.ONE * 0.8, Vector3.ZERO, time + 0.1, {"cull": 6.0, "decay": 0.85}, {"burst": 1.0, "gravity": 1.0, "drag": 2.0, "life": time + 0.1, "opacity": 0.85})
	K.put(art, K.VEIL, K.shock(TEAL, FOAM, DEEP), "SurgeCallRing", Vector3.UP * 0.08, Vector3.ONE * 2.2, Vector3.ZERO, time, {"initial": 0.4, "grow_time": 0.6, "spin": 1.5, "decay": 0.9}, {"opacity": 0.7})
	return true


## A breach: the serpent leaps through its lane and a wave rushes out across the cone.
static func launch(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, flight: float) -> bool:
	var k := _launched
	_launched += 1
	var r := _r(skill)
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	var c := course(k)
	var gone := flight + 0.55
	var breach := S.root(parent, Vector3(origin.x, 0, origin.z), gone + 0.1, "StarSurgeBreach_" + ID, origin)
	if not breach:
		return true
	breach.rotation.y = _yaw(origin, point)
	var keys := [[0.0, float(c.rise) + 0.5], [flight, float(c.dive)], [gone, float(c.dive) + BODY + 1.0]]
	var params := K.path_params(c.points, SPACING, 0, 9999, keys)
	params.merge(SERPENT_LOOK)
	K.put(breach, K.PATH, serpent_mesh(), "LeviathanSerpent", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, gone, {"fade_in": 0.03, "decay": 0.97, "front": true, "cull": 30.0}, params)
	K.put(breach, K.VEIL, S.wave("leviathan", DEEP, TEAL, FOAM, 1.05), "SurgeWave", Vector3.ZERO, Vector3(r, 1.9 - 0.2 * float(k % 2), r), Vector3(0, 0.25 * (float(k % 3) - 1.0), 0), flight + 0.45, {"initial": 0.12, "grow_time": 0.85, "fade_in": 0.05, "decay": 0.6}, S.WATER_LOOK)
	K.put(breach, K.VEIL, S.spout("surge_rise", TEAL, FOAM), "SurgeBreachSplash", Vector3(c.points[int(float(c.rise) / SPACING)].x, 0, c.points[int(float(c.rise) / SPACING)].z), Vector3(1.4, 2.2, 1.4), Vector3.ZERO, 0.5, {"initial": 0.3, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.4}, S.WATER_LOOK.merged({"flow": Vector2(0.2, -3.0)}, true))
	breach._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := _r(skill)
	art.rotation.y = _yaw(source, point)
	var c := course(index)
	var spot: Vector3 = c.splash
	var final := index >= 2
	var s := 1.5 if final else 1.0
	# The serpent dives: the sea bursts where it goes in.
	K.put(art, K.VEIL, S.spout("surge_splash", TEAL, FOAM), "SurgeSplash", spot, Vector3(1.5 * s, 3.4 * s, 1.5 * s), Vector3.ZERO, 0.7, {"initial": 0.25, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.45, "front": true}, S.WATER_LOOK.merged({"flow": Vector2(0.2, -3.5)}, true))
	K.put(art, K.VEIL, S.spray("surge", [TEAL_HI, FOAM, TEAL, BELLY], 34, 9.0, 4.5), "SurgeSpray", spot + Vector3.UP * 0.3, Vector3.ONE * s, Vector3.ZERO, 1.2, {"cull": 12.0, "decay": 0.8}, {"burst": 1.0, "gravity": 14.0, "drag": 1.0, "life": 1.2, "opacity": 0.9})
	K.put(art, K.VEIL, K.shock(TEAL, FOAM, DEEP), "SurgeFoamRing", spot + Vector3.UP * 0.1, Vector3.ONE * 3.2 * s, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.35}, {"opacity": 0.85})
	K.put(art, K.VEIL, S.whirlpool("leviathan", DEEP, TEAL, FOAM), "SurgeEddy", spot + Vector3.UP * 0.04, Vector3.ONE * 1.8 * s, Vector3.ZERO, 1.3, {"initial": 0.4, "grow_time": 0.3, "fade_in": 0.02, "spin": 4.0, "decay": 0.6, "priority": -1})
	if final:
		# The crash: a wide fan of foam over the whole cone.
		K.put(art, K.VEIL, S.wave("leviathan_crash", TEAL, TEAL_HI, FOAM, 1.25), "SurgeCrash", Vector3.ZERO, Vector3(r * 1.02, 1.1, r * 1.02), Vector3.ZERO, 0.8, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.02, "decay": 0.45}, S.WATER_LOOK)
		K.put(art, K.GLOW, K.sprite(), "SurgeShimmer", spot + Vector3.UP * 0.15, Vector3.ONE * 4.0, Vector3(-PI / 2, 0, 0), 0.7, {"initial": 0.4, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.35}, {"radial": 1.4, "tint": Color("30d0e0"), "opacity": 0.45})
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
static func _girth(z: float) -> float:
	if z < 0.5: return lerpf(0.22, 0.5, z / 0.5)
	if z < 1.3: return lerpf(0.5, 0.6, (z - 0.5) / 0.8)
	if z < 2.0: return lerpf(0.6, 0.46, (z - 1.3) / 0.7)
	if z < 4.0: return lerpf(0.46, 0.62, (z - 2.0) / 2.0)
	return lerpf(0.62, 0.06, pow((z - 4.0) / (BODY - 4.0), 1.3))


## The Leviathan along +Z (the snout at 0, the tail fin at BODY); +Y is its back.
static func serpent_mesh() -> ArrayMesh:
	return K.cached("star_leviathan", func():
		var b := K.Builder.new()
		var path := []
		var radii := []
		var cols := []
		var z := 0.0
		while z <= BODY + 0.001:
			path.append(Vector3(0, 0, z))
			var g := _girth(z)
			radii.append(Vector2(g * 0.92, g))
			cols.append([TEAL.lerp(TEAL_HI, 0.15), BELLY])
			z += 0.35
		b.weight = 1.0
		b.tube(path, radii, 10, cols, Vector3.UP)
		b.weight = 0.0
		# Jaw and brow.
		b.cone(Vector3(0, -0.12, 0.45), Vector3(0, -0.22, -0.18), Vector2(0.3, 0.12), 6, BELLY, BELLY.darkened(0.1))
		for side in [-1.0, 1.0]:
			var s: float = side
			b.emit = 1.0
			b.gem(Vector3(s * 0.33, 0.24, 0.7), Vector3(0.09, 0.08, 0.09), GOLD, Color("fff6c0"))
			b.emit = 0.0
			# Swept horns and frills.
			b.cone(Vector3(s * 0.3, 0.38, 1.0), Vector3(s * 0.75, 0.7, 2.3), 0.12, 5, TEAL_HI, FOAM, Vector3.UP)
			b.tri3(Vector3(s * 0.45, 0.0, 1.0), Vector3(s * 0.5, 0.05, 1.9), Vector3(s * 1.2, 0.0, 1.7), TEAL, TEAL, TEAL_HI)
			# Side fins.
			b.tri3(Vector3(s * 0.5, -0.1, 3.0), Vector3(s * 0.5, -0.1, 3.9), Vector3(s * 1.5, -0.35, 4.0), TEAL, TEAL, TEAL_HI.lerp(FOAM, 0.4))
		# The dorsal fin, a row of spines along the back.
		b.emit = 0.15
		var zf := 1.9
		while zf < BODY - 1.5:
			var g := _girth(zf)
			var h := 0.55 * (1.0 - zf / BODY) + 0.15
			b.tri3(Vector3(0, g * 0.9, zf - 0.25), Vector3(0, g * 0.9, zf + 0.25), Vector3(0, g + h, zf + 0.35), TEAL_HI, TEAL_HI, FOAM)
			zf += 0.45
		b.emit = 0.0
		# The tail fin.
		b.tri3(Vector3(0, 0, BODY - 0.4), Vector3(0, 0.9, BODY + 0.6), Vector3(0, 0.0, BODY + 0.3), TEAL, TEAL_HI, FOAM)
		b.tri3(Vector3(0, 0, BODY - 0.4), Vector3(0, -0.9, BODY + 0.6), Vector3(0, 0.0, BODY + 0.3), TEAL, TEAL_HI, FOAM)
		return b.mesh())


## The sea that covers the cone ahead (radius 1, +-75 degrees round +Z): dark water,
## lines of foam rolling out (UV.y runs out from the caster).
static func sea_mesh() -> ArrayMesh:
	return K.cached("star_leviathan_sea", func():
		var b := K.Builder.new()
		var segs := 28
		var half := 1.31
		var rows := [[0.08, Color(DEEP, 0.0)], [0.25, Color(DEEP, 0.4)], [0.6, Color(TEAL.lerp(DEEP, 0.4), 0.42)], [0.95, Color(TEAL, 0.35)], [1.06, Color(FOAM, 0.0)]]
		var base := b.v.size()
		for i in rows.size():
			for j in segs + 1:
				var f := float(j) / segs
				var a := lerpf(-half, half, f)
				var c: Color = rows[i][1]
				c.a *= smoothstep(0.0, 0.12, f) * smoothstep(1.0, 0.88, f)
				b.pt(Vector3(sin(a), 0, cos(a)) * float(rows[i][0]), Vector3.UP, c, Vector2(f * 3.0, float(i) / (rows.size() - 1)))
		for i in rows.size() - 1:
			for j in segs:
				var a := base + i * (segs + 1) + j
				var c := a + segs + 1
				b.tri(a, a + 1, c + 1); b.tri(a, c + 1, c)
		for k in 4:
			var rr := 0.3 + 0.18 * k
			b.annulus(rr, rr + 0.015, 24, Color(FOAM, 0.55), Color(FOAM, 0.55), 0.004, -half * 0.9, half * 0.9)
		return b.mesh())
