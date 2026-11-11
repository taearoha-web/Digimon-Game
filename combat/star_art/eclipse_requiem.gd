extends RefCounted
## Assassin 200 stars "Eclipse Requiem": the requiem under a dark moon. Wind-up (the assassin
## rises on the wings into a darkening sky): the requiem circle, ink with magenta runes,
## spreads over the field, and above it a magenta crescent eclipses a dark moon while a
## ring of shadow daggers gathers round it, points down. Four rains: the daggers fall in a
## new formation each time (ring, cross, spiral, scatter), each landing in a magenta spark
## and a cut in the ground. The fifth: the crescent itself sweeps the whole circle like a
## scythe, black with a magenta-hot edge, leaving a crescent scar; shadow petals burst and
## two rings of night roll out. Magenta, violet and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const MAGENTA := Color("e04dff")
const VIOLET := Color("7a2cd8")
const PINK := Color("ffd6ff")
const INK := Color(0.05, 0.01, 0.08)
const ID := "eclipse_requiem"


## The requiem circle on the ground (radius 1).
static func _circle() -> ArrayMesh:
	if M.has("requiem_circle"):
		return M.get_mesh("requiem_circle")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.05, M.a(INK, 0.45), 0.0, 48, 0.0, Vector3.UP, Vector3.ZERO, M.a(INK, 0.0), 0.0, true)
	K.ring(st, 1.0, 0.035, M.a(MAGENTA, 1.0), 0.003, 72)
	K.ring(st, 0.88, 0.012, M.a(PINK, 0.8), 0.003, 72)
	for i in 12:
		var ang := TAU * float(i) / 12.0
		var dir := Vector3(sin(ang), 0.004, cos(ang))
		var side := Vector3(cos(ang), 0, -sin(ang))
		# A crescent rune between the rings.
		K.ribbon(st, M.arc(dir * 0.94, 0.035, ang + 1.0, ang + 5.3, 0.004, 0.004, 8), 0.014, M.a(MAGENTA, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
		K.ribbon(st, PackedVector3Array([dir * 0.5 - side * 0.02, dir * 0.84]), 0.012, M.a(VIOLET, 0.8), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("requiem_circle", K.finish(st, Vector3.ONE * 0.2, false))


## The eclipse in the XY plane (radius 1): a dark moon, a magenta crescent over its edge.
static func _eclipse() -> ArrayMesh:
	if M.has("requiem_eclipse"):
		return M.get_mesh("requiem_eclipse")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.9, M.a(VIOLET, 0.45), 0.0, 36, 0.0, Vector3.BACK, Vector3(0, 0, -0.04), M.a(VIOLET, 0.0), 0.0, true)
	K.disc(st, 1.0, Color(0.06, 0.02, 0.12, 1.0), 0.0, 40, 0.0, Vector3.BACK, Vector3(0, 0, -0.02), Color(0.12, 0.04, 0.22, 1.0), 0.0, true)
	var pts := PackedVector3Array()
	for i in 29:
		var t := float(i) / 28.0
		var ang := lerpf(-2.6, 2.6, t) + PI * 0.5
		var w := sin(t * PI)
		pts.append(Vector3(sin(ang), cos(ang), 0) * (1.06 + w * 0.1))
	K.ribbon(st, pts, 0.38, M.a(MAGENTA, 1.0), 0.0, 0.0, Vector3.BACK, 1.0)
	return M.keep("requiem_eclipse", K.finish(st, Vector3.ONE * 0.3, false))


static func _dagger() -> K.Part:
	return M.dagger(Color("3a2050"), INK, MAGENTA)


## The ring of daggers round the eclipse, points down (radius 1).
static func _crown() -> ArrayMesh:
	if M.has("requiem_crown"):
		return M.get_mesh("requiem_crown")
	var st := K.begin()
	var part := _dagger()
	for i in 12:
		var ang := TAU * float(i) / 12.0
		K.stamp(st, part, Transform3D(Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, PI).scaled(Vector3.ONE * 0.5), Vector3(sin(ang), 0.5, cos(ang))), 0.03 * float(i), 1.0)
	return M.keep("requiem_crown", K.finish(st, Vector3(0.5, 4.0, 0.5)))


## Where a rain's daggers land (radius 1): ring, cross, spiral, scatter.
static func _spots(index: int) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 170 + index
	match index % 4:
		0:
			for i in 10:
				var ang := TAU * float(i) / 10.0
				out.append(Vector3(sin(ang), 0, cos(ang)) * 0.7)
		1:
			for i in 10:
				var ang := PI * 0.25 + PI * 0.5 * float(i % 4)
				out.append(Vector3(sin(ang), 0, cos(ang)) * (0.25 + 0.22 * float(i / 4)))
		2:
			for i in 12:
				var ang := float(i) * 0.9
				out.append(Vector3(sin(ang), 0, cos(ang)) * (0.12 + 0.07 * float(i)))
		3:
			for i in 12:
				var ang := rng.randf() * TAU
				out.append(Vector3(sin(ang), 0, cos(ang)) * sqrt(rng.randf()) * 0.85)
	return out


## One rain: [daggers SOLID, landing light FLAT, sparks BITS].
static func _rain(index: int) -> Array:
	var key := "requiem_rain%d" % (index % 4)
	if M._m.has(key):
		return M._m[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 180 + index
	var solid := K.begin()
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bits := SurfaceTool.new()
	bits.begin(Mesh.PRIMITIVE_TRIANGLES)
	var part := _dagger()
	var flight := 0.18
	var spots := _spots(index)
	for i in spots.size():
		var at: Vector3 = spots[i] * 6.0
		var delay := 0.025 * float(i)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI + rng.randf_range(-0.15, 0.15))
		K.stamp(solid, part, Transform3D(basis.scaled(Vector3.ONE * 1.9), at + Vector3.UP * 1.5), delay, 1.0)
		K.beam(flat, at + Vector3.UP * 1.2, 4.0, 0.3, M.a(MAGENTA, 0.75), 2, delay, 1.0, 0.05)
		K.disc(flat, 0.9, M.a(MAGENTA, 0.85), 0.07, 12, delay + flight, Vector3.UP, at, M.a(VIOLET, 0.0), -1.0)
		var side := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		K.ribbon(flat, PackedVector3Array([at - side * 0.6 + Vector3.UP * 0.06, at + side * 0.6 + Vector3.UP * 0.06]), 0.12, M.a(MAGENTA, 0.9), delay + flight, 0.0, Vector3.UP, 1.0)
		K.burst_at(bits, rng, "ember", 4, at, 0.0, 0.3, 2.5, 3.5, [MAGENTA, PINK, VIOLET], 0.13, delay + flight, 0.04)
	var out := [K.finish(solid, Vector3(0.5, 14.0, 0.5)), K.finish(flat, Vector3(0.5, 14.0, 0.5), false), K.finish(bits, Vector3(6, 6, 6), false)]
	M._m[key] = out
	return out


## The crescent's sweep round the circle and the scar it leaves (radius 1).
static func _reap() -> Array:
	if M._m.has("requiem_reap"):
		return M._m["requiem_reap"]
	var wake := SurfaceTool.new()
	wake.begin(Mesh.PRIMITIVE_TRIANGLES)
	var scar := SurfaceTool.new()
	scar.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := M.arc(Vector3.ZERO, 0.85, 0.0, TAU * 0.92, 0.2, 0.2, 48)
	K.ribbon(wake, pts, 0.32, M.a(MAGENTA, 0.95), 0.0, 0.0, Vector3.UP, 0.6, 0.0, 1.0, M.a(PINK, 0.9))
	K.ribbon(wake, M.arc(Vector3.ZERO, 0.78, 0.0, TAU * 0.92, 0.2, 0.2, 48), 0.09, M.a(INK, 1.0), 0.0, 0.0, Vector3.UP, 0.6, 0.0, 1.0, Color(0, 0, 0, -1), true)
	var c := M.arc(Vector3.ZERO, 0.6, -2.2, 2.2, 0.0, 0.0, 30)
	K.ribbon(scar, c, 0.14, M.a(MAGENTA, 0.9), 0.0, 0.0, Vector3.UP, 1.0)
	K.ribbon(scar, c, 0.05, M.a(INK, 1.0), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	var out := [K.finish(wake, Vector3.ONE * 0.3, false), K.finish(scar, Vector3.ONE * 0.2, false)]
	M._m["requiem_reap"] = out
	return out


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := clampf(float(skill.get("radius", 6.5)), 4.0, 9.0)
	var parent := art.get_parent() as Node3D
	var center := Vector3(point.x, 0, point.z)
	var hold := time + 1.36 + 0.6
	var ground := K.extra(parent, center, hold, "StarGround_" + ID, caster.global_position)
	if ground:
		K.put(ground, K.FLAT, _circle(), "RequiemCircle", Vector3.UP * 0.06, Vector3.ONE * r, hold, {"sweep": time * 0.6, "soft": 0.45, "hot": M.hot(MAGENTA, 0.8), "core": 0.5, "flick": 0.08, "add": 0.5}, {"initial": 0.6, "grow_time": 0.5, "fade_in": 0.1, "spin": 0.15, "decay": 0.9})
		K.put(ground, K.BITS, K.burst("requiem_drift", "feather", 22, 0.5, r * 0.8, 0.4, -1.0, [INK, Color(0.14, 0.04, 0.2)], 0.36, 1.2, 171, 3.0, 7.0), "RequiemDrift", Vector3.ZERO, Vector3.ONE, hold, {"life": 2.2, "gravity": 1.2, "drag": 0.8, "piece": 0.36, "sway": 0.5, "spin": 3.0, "floor_y": 0.08, "shrink": 0.9}, {"decay": 0.9})
		ground._draw()
	M.sparks(art, "requiem_lift", [MAGENTA, PINK, VIOLET], 20, 0.2, 1.1, 0.5, 3.5, 0.12, 0.0, 1.3, Vector3.ZERO, -2.0, 172, 0.1, 1.0)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	# The eclipse and its crown of daggers over the field, behind the rising assassin.
	var sky := K.extra(parent, center, hold, "StarSky_" + ID, caster.global_position)
	if sky:
		var spot := K.beyond(sky, 4.5)
		var room := K.sky(sky, spot, 11.0)
		var y := maxf(5.5, room - 2.3)
		K.put(sky, K.FLAT, _eclipse(), "RequiemEclipse", spot + Vector3.UP * y, Vector3.ONE * 1.35, hold, {"soft": 0.7, "hot": M.hot(PINK), "core": 0.5, "flick": 0.08, "add": 0.55}, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.15, "decay": 0.9, "face_camera": true}, Vector3(-0.3, 0, 0))
		K.put(sky, K.SOLID, _crown(), "RequiemDaggers", spot + Vector3.UP * (y - 0.3), Vector3(2.6, 1.6, 2.6), time + 1.0, {"drop": 2.0, "flight": time * 0.7, "ease": 1.0, "rim_color": MAGENTA, "rim": 1.0, "glow_color": PINK}, {"fade_in": 0.1, "spin": 0.9, "decay": 0.9})
		sky._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := clampf(float(skill.get("radius", 6.5)), 4.0, 9.0)
	var s := Vector3.ONE * (r / 6.0)
	if index < 4:
		var rain := _rain(index)
		K.put(art, K.SOLID, rain[0], "RequiemRain", Vector3.ZERO, s, 0.75, {"drop": 9.0, "flight": 0.18, "heat": 0.5, "rim_color": MAGENTA, "rim": 1.0, "glow_color": PINK}, {"decay": 0.75})
		K.put(art, K.FLAT, rain[1], "RequiemRainLight", Vector3.ZERO, s, 0.8, {"drop": 9.0, "flight": 0.18, "after": 0.12, "flash": 0.3, "soft": 0.6, "hot": M.hot(PINK), "core": 0.4, "add": 0.6}, {"decay": 0.75})
		K.put(art, K.BITS, rain[2], "RequiemRainSparks", Vector3.ZERO, s, 0.9, {"life": 0.6, "gravity": 6.0, "drag": 1.6, "piece": 0.13, "add": 0.7, "shrink": 0.25}, {"decay": 0.8})
		return true
	# The fifth: the crescent sweeps the circle like a scythe.
	var reap := _reap()
	var swing := 0.4
	K.put(art, K.FLAT, reap[0], "RequiemReap", Vector3(0, 0.6, 0), Vector3(r, 4.0, r), swing + 0.3, {"sweep": swing, "tail": 0.6, "soft": 0.7, "hot": M.hot(PINK), "core": 0.4, "add": 0.65, "gain": 1.15}, {"fade_in": 0.01, "decay": 0.7})
	K.put(art, K.FLAT, reap[1], "RequiemScar", Vector3.UP * 0.07, Vector3.ONE * r, 2.0, {"sweep": swing, "soft": 0.5, "hot": M.hot(MAGENTA), "core": 0.4, "flick": 0.12, "add": 0.6}, {"delay": 0.05, "decay": 0.7}, Vector3(0, K.facing(art) + PI, 0))
	K.put(art, K.BITS, K.burst("requiem_petals", "feather", 60, 0.5, r * 0.9, 1.4, 3.0, [INK, Color(0.14, 0.04, 0.2), MAGENTA.darkened(0.3), PINK], 0.55, 0.3, 173, 0.5, 2.0), "RequiemPetals", Vector3.ZERO, Vector3.ONE, 2.0, {"life": 1.8, "gravity": 1.8, "drag": 1.0, "piece": 0.55, "sway": 0.5, "spin": 4.0, "floor_y": 0.08, "shrink": 0.9}, {"delay": 0.1, "decay": 0.85})
	M.shock(art, "requiem_ring", MAGENTA, r * 1.25, swing * 0.5, 0.6, 0.16)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var after := K.extra(parent, Vector3(point.x, 0, point.z), 2.0, "StarAfter_" + ID, source)
	if after:
		M.shock(after, "requiem_ring_b", VIOLET, r * 1.6, swing * 0.5 + 0.12, 0.8, 0.12)
		M.sparks(after, "requiem_sparks", [MAGENTA, PINK, VIOLET], 50, r * 0.5, r * 0.85, 4.0, 3.0, 0.17, 0.05, 1.2, Vector3.ZERO, 5.0, 174, 0.6, 1.6)
		M.pillar(after, "requiem_column", MAGENTA, 2.0, 9.0, 0.05, 0.7)
		after._draw()
	return true
