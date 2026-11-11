extends RefCounted
## Assassin 150 stars "Veil of Night": night falls on the party alone. Wind-up (the assassin
## springs back): a dome of dusk settles round the assassin (local, thin: the fight stays in
## view), stars prick out inside it and a thin crescent moon rises behind. Release: the
## stars flare, a ring of crescent shadow-blades sweeps round the party, the moon blazes and
## a ring of indigo night rolls out over the allies the veil reaches. The dusk then lifts and
## the stars drift away. Indigo, starlight lilac and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const INDIGO := Color("6a5cff")
const STAR := Color("cfc4ff")
const DUSK := Color(0.05, 0.03, 0.16)
const MOON := Color("a898ff")
const ID := "veil_of_night"
const DOME := 4.2


## The dusk: a low dome thinning upward (radius 1), its own colour edge to edge.
static func _veil() -> ArrayMesh:
	if M.has("night_veil"):
		return M.get_mesh("night_veil")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_uv2(Vector2.ZERO)
	st.set_uv(Vector2(0.5, -1.0))
	var rings := 5
	for k in rings:
		var h0 := float(k) / float(rings) * 0.5 * PI
		var h1 := float(k + 1) / float(rings) * 0.5 * PI
		var c0 := M.a(DUSK, 0.32 * pow(1.0 - float(k) / float(rings), 1.3))
		var c1 := M.a(DUSK, 0.32 * pow(1.0 - float(k + 1) / float(rings), 1.3))
		for i in 28:
			var a0 := TAU * float(i) / 28.0
			var a1 := TAU * float(i + 1) / 28.0
			var p00 := Vector3(sin(a0) * cos(h0), sin(h0), cos(a0) * cos(h0))
			var p01 := Vector3(sin(a1) * cos(h0), sin(h0), cos(a1) * cos(h0))
			var p10 := Vector3(sin(a0) * cos(h1), sin(h1), cos(a0) * cos(h1))
			var p11 := Vector3(sin(a1) * cos(h1), sin(h1), cos(a1) * cos(h1))
			for item in [[p00, c0], [p01, c0], [p11, c1], [p00, c0], [p11, c1], [p10, c1]]:
				st.set_color(item[1])
				st.add_vertex(item[0])
	K.ring(st, 1.0, 0.03, M.a(INDIGO, 1.0), 0.005, 72)
	return M.keep("night_veil", K.finish(st, Vector3.ONE * 0.2, false))


## The stars inside the veil: little four-point sparkles hanging in the air (radius 1).
static func _stars() -> ArrayMesh:
	if M.has("night_stars"):
		return M.get_mesh("night_stars")
	var rng := RandomNumberGenerator.new()
	rng.seed = 161
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 30:
		var ang := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.95
		var at := Vector3(sin(ang) * d, rng.randf_range(0.15, 0.75) * (1.0 - d * 0.6), cos(ang) * d)
		var size := rng.randf_range(0.018, 0.04)
		var delay := rng.randf() * 0.5
		K.ribbon(st, PackedVector3Array([at - Vector3.RIGHT * size, at + Vector3.RIGHT * size]), size * 0.8, M.a(STAR, 1.0), delay, 0.0, Vector3.BACK, 1.0)
		K.ribbon(st, PackedVector3Array([at - Vector3.UP * size * 1.4, at + Vector3.UP * size * 1.4]), size * 0.8, M.a(STAR, 1.0), delay, 0.0, Vector3.BACK, 1.0)
	return M.keep("night_stars", K.finish(st, Vector3.ONE * 0.2, false))


## A thin crescent moon in the XY plane (radius 1).
static func _moon() -> ArrayMesh:
	if M.has("night_moon"):
		return M.get_mesh("night_moon")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.5, M.a(INDIGO, 0.4), 0.0, 32, 0.0, Vector3.BACK, Vector3(0, 0, -0.03), M.a(INDIGO, 0.0), 0.0, true)
	var pts := PackedVector3Array()
	for i in 25:
		var t := float(i) / 24.0
		var ang := lerpf(-1.9, 1.9, t) + PI * 0.5
		var w := sin(t * PI)
		pts.append(Vector3(sin(ang), cos(ang), 0) * (1.0 - w * 0.18) + Vector3(-w * 0.18, 0, 0))
	K.ribbon(st, pts, 0.42, M.a(MOON, 1.0), 0.0, 0.0, Vector3.BACK, 1.0)
	return M.keep("night_moon", K.finish(st, Vector3.ONE * 0.3, false))


## Crescent shadow-blades on a ring round the party (radius 1, level).
static func _blades() -> ArrayMesh:
	if M.has("night_blades"):
		return M.get_mesh("night_blades")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var ang := TAU * float(i) / 6.0
		var pts := M.arc(Vector3.ZERO, 1.0, ang - 0.45, ang + 0.45, 0.32, 0.32, 10)
		K.ribbon(st, pts, 0.2, M.a(INDIGO, 0.95), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, M.a(STAR, 0.95))
		K.ribbon(st, M.arc(Vector3.ZERO, 0.97, ang - 0.4, ang + 0.4, 0.32, 0.32, 10), 0.06, M.a(DUSK, 1.0), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return M.keep("night_blades", K.finish(st, Vector3.ONE * 0.2, false))


static func telegraph(art: StarSkillArt, _caster: Node3D, _skill: Dictionary, _point: Vector3, time: float) -> bool:
	var hold := M.stage(art, time + 1.5, "StarStage_" + ID)
	if hold == null:
		return false
	K.put(hold, K.FLAT, _veil(), "NightVeil", Vector3.UP * 0.04, Vector3(DOME, DOME * 0.8, DOME), time + 1.5, {"soft": 0.01, "add": 0.0, "hot": M.hot(INDIGO, 0.0)}, {"initial": 0.3, "grow_time": 0.5, "fade_in": 0.25, "decay": 0.75})
	K.put(hold, K.FLAT, _stars(), "NightStars", Vector3.ZERO, Vector3(DOME, DOME * 2.6, DOME), time + 1.3, {"soft": 0.6, "hot": M.hot(STAR, 0.6), "core": 0.6, "flick": 0.5, "add": 0.85}, {"fade_in": 0.2, "decay": 0.75})
	var spot := K.beyond(hold, 1.6)
	K.put(hold, K.FLAT, _moon(), "NightMoon", spot + Vector3.UP * 2.4, Vector3.ONE * 1.2, time + 1.2, {"soft": 0.6, "hot": M.hot(MOON, 0.6), "core": 0.6, "add": 0.65}, {"initial": 0.5, "grow_time": 0.5, "fade_in": 0.2, "decay": 0.8, "face_camera": true, "travel": Vector3.UP * 1.2})
	K.put(art, K.BITS, K.burst("night_smoke", "puff", 16, 0.2, 1.2, 0.5, 1.2, [DUSK, Color(0.12, 0.08, 0.3), Color(0.03, 0.02, 0.08)], 0.6, 0.4, 162, 0.05, 0.3), "NightSmoke", Vector3.ZERO, Vector3.ONE, time + 0.3, {"life": 0.9, "gravity": -0.8, "drag": 1.5, "piece": 0.6, "swell": 1.7, "alpha": 0.55, "shrink": 0.4, "spin": 2.0}, {"fade_in": 0.05, "decay": 0.9})
	hold._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	if index > 0:
		return true
	var reach := clampf(float(skill.get("radius", 8.0)), 4.0, 9.0)
	K.put(art, K.FLAT, _blades(), "NightBlades", Vector3.ZERO, Vector3(DOME * 0.85, 3.5, DOME * 0.85), 0.9, {"soft": 0.7, "hot": M.hot(STAR), "core": 0.45, "add": 0.6}, {"initial": 0.5, "grow_time": 0.4, "fade_in": 0.02, "decay": 0.5, "spin": 5.0})
	M.shock(art, "night_ring", INDIGO, reach * 1.35, 0.0, 0.8, 0.14)
	M.sparks(art, "night_flare", [STAR, INDIGO.lightened(0.3), MOON], 36, 0.3, DOME * 0.9, 0.8, 2.5, 0.13, 0.0, 1.3, Vector3.ZERO, -0.6, 163, 0.5, 2.5)
	M.shock(art, "night_ring_b", MOON, DOME + 0.4, 0.08, 0.5, 0.22)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var after := K.extra(parent, Vector3(point.x, 0, point.z), 1.8, "StarAfter_" + ID, source)
	if after:
		var spot := K.beyond(after, 1.6)
		K.put(after, K.FLAT, K.glow_disc("night_moon_glow", M.a(MOON, 0.7), M.a(INDIGO, 0.0)), "NightMoonBlaze", spot + Vector3.UP * 3.5, Vector3.ONE * 1.8, 0.7, {"soft": 0.6, "add": 0.85}, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.4, "face_camera": true}, Vector3(PI * 0.5, 0, 0))
		M.sparks(after, "night_drift", [STAR, MOON], 26, 0.5, DOME, 0.2, 1.4, 0.11, 0.3, 1.6, Vector3.ZERO, -0.7, 164, 0.6, 2.4)
		after._draw()
	return true
