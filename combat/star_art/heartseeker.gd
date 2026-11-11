extends RefCounted
## Lancer 100 stars "Heartseeker": five lightning thrusts and the one that finds the heart.
## Wind-up: a crimson heart-sigil with a turning reticle locks onto the target's chest while
## the lance point gathers red light. Thrusts 1-5: needles of crimson light stab through the
## target from shifting angles, each leaving a burst of light on its chest and a crack in
## the sigil. The sixth: a great lance of light runs the target through and out the far
## side, the heart bursts into shards and petals and two rings of pressure blow out round
## the shaft. Crimson, rose and blush.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const RED := Color("ff2a4f")
const ROSE := Color("ff8aa6")
const BLUSH := Color("ffd6dc")
const WINE := Color("5a0a22")
const STEEL := Color("e8c8d0")
const ID := "heartseeker"
const CHEST := 1.25


## A heart outline (in the XY plane, 1 tall), a reticle round it.
static func _heart() -> ArrayMesh:
	if M.has("seeker_heart"):
		return M.get_mesh("seeker_heart")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	for i in 49:
		var t := TAU * float(i) / 48.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector3(x, y + 2.0, 0) / 34.0)
	K.disc(st, 0.42, M.a(RED, 0.45), 0.0, 24, 0.0, Vector3.BACK, Vector3(0, 0.05, -0.01), M.a(RED, 0.0), 0.0, true)
	K.ribbon(st, pts, 0.07, M.a(RED, 1.0), 0.0, 0.0, Vector3.BACK, 0.0)
	var ring := PackedVector3Array()
	for i in 49:
		var ang := TAU * float(i) / 48.0
		ring.append(Vector3(sin(ang), cos(ang), 0) * 0.75)
	K.ribbon(st, ring, 0.035, M.a(ROSE, 0.9), 0.0, 0.0, Vector3.BACK, 0.0)
	for i in 4:
		var ang := TAU * float(i) / 4.0
		var dir := Vector3(sin(ang), cos(ang), 0)
		K.ribbon(st, PackedVector3Array([dir * 0.62, dir * 0.95]), 0.06, M.a(BLUSH, 0.95), 0.0, 0.0, Vector3.BACK, 0.0)
	return M.keep("seeker_heart", K.finish(st, Vector3.ONE * 0.3, false))


## One thrust: a needle of light along +Z (from -1 to 0.35), crossed planes.
static func _needle() -> ArrayMesh:
	if M.has("seeker_needle"):
		return M.get_mesh("seeker_needle")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array([Vector3(0, 0, -1.0), Vector3(0, 0, -0.3), Vector3(0, 0, 0.35)])
	for up in [Vector3.UP, Vector3.RIGHT]:
		K.ribbon(st, pts, 0.3, M.a(RED, 0.95), 0.0, 0.0, up, 0.0, 0.0, 1.0, M.a(BLUSH, 1.0))
	return M.keep("seeker_needle", K.finish(st, Vector3.ONE * 0.3, false))


## A star of light where a thrust lands (XY plane).
static func _puncture() -> ArrayMesh:
	if M.has("seeker_puncture"):
		return M.get_mesh("seeker_puncture")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var ang := TAU * float(i) / 8.0 + 0.2
		var dir := Vector3(sin(ang), cos(ang), 0)
		K.ribbon(st, PackedVector3Array([dir * 0.1, dir * (1.0 if i % 2 == 0 else 0.6)]), 0.16, M.a(RED if i % 2 == 0 else ROSE, 0.95), 0.0, 0.0, Vector3.BACK, 1.0)
	return M.keep("seeker_puncture", K.finish(st, Vector3.ONE * 0.2, false))


## The great lance of light, along +Z, 1 long, point forward.
static func _lance() -> ArrayMesh:
	if M.has("seeker_lance"):
		return M.get_mesh("seeker_lance")
	var st := K.begin()
	K.stamp(st, M.lance(WINE, STEEL, RED), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	return M.keep("seeker_lance", K.finish(st, Vector3.ONE * 0.5))


## Rings of pressure round the shaft (XY plane, radius 1).
static func _rings() -> ArrayMesh:
	if M.has("seeker_rings"):
		return M.get_mesh("seeker_rings")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var pts := PackedVector3Array()
		for i in 33:
			var ang := TAU * float(i) / 32.0
			pts.append(Vector3(cos(ang), sin(ang), 1.2 + 1.3 * float(k)) * Vector3(1.0 - 0.3 * float(k), 1.0 - 0.3 * float(k), 1))
		K.ribbon(st, pts, 0.18, M.a(RED if k == 0 else ROSE, 0.95), 0.06 * float(k), 0.0, Vector3.BACK, 0.0)
	return M.keep("seeker_rings", K.finish(st, Vector3.ONE * 0.5, false))


## The heart bursting: heart-shaped pieces and petals.
static func _burst() -> ArrayMesh:
	if M.has("seeker_burst"):
		return M.get_mesh("seeker_burst")
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heart := K.Part.new()
	heart.ink(RED, 0.6)
	heart.ball(Vector3(-0.2, 0.12, 0), Vector3(0.26, 0.26, 0.12), 6, 3)
	heart.ball(Vector3(0.2, 0.12, 0), Vector3(0.26, 0.26, 0.12), 6, 3)
	heart.tri(Vector3(-0.45, 0.08, 0), Vector3(0.45, 0.08, 0), Vector3(0, -0.5, 0))
	heart.tri(Vector3(0.45, 0.08, 0), Vector3(-0.45, 0.08, 0), Vector3(0, -0.5, 0))
	for i in 10:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(0.2, 1.2)).normalized()
		K.bit(st, heart, dir * 0.2, dir * rng.randf_range(3.0, 6.0) + Vector3.UP * 2.0, rng.randf() * 0.04, 0.5, Basis().scaled(Vector3.ONE * rng.randf_range(0.35, 0.6)))
	K.burst_at(st, rng, "feather", 26, Vector3.ZERO, 0.0, 0.4, 3.5, 4.0, [ROSE, BLUSH, RED], 0.35, 0.0, 0.08, -0.2, 0.3)
	return M.keep("seeker_burst", K.finish(st, Vector3(7, 7, 7), false))


static func telegraph(art: StarSkillArt, caster: Node3D, _skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	M.sparks(art, "seeker_gather", [RED, ROSE, BLUSH], 18, 0.1, 0.7, 0.4, 1.6, 0.12, 0.0, time + 0.1, Vector3(0.3, 0, 0.9), -1.0, 72, 0.8, 1.5)
	K.put(art, K.FLAT, K.glow_disc("seeker_tip", M.a(RED, 0.8), M.a(RED, 0.0)), "SeekerTip", Vector3(0.3, 1.25, 1.2), Vector3.ONE * 0.6, time + 0.1, {"soft": 0.6, "add": 0.8, "flick": 0.2}, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.1, "decay": 0.9, "face_camera": true}, Vector3(PI * 0.5, 0, 0))
	# The heart-sigil locks on and stays through all six thrusts.
	var hold := time + 1.12 + 0.1
	var mark := K.extra(parent, Vector3(point.x, 0, point.z), hold, "StarMark_" + ID, caster.global_position)
	if mark:
		K.put(mark, K.FLAT, _heart(), "SeekerHeart", Vector3.UP * (CHEST + 0.15), Vector3.ONE * 1.4, hold, {"soft": 0.5, "hot": M.hot(ROSE), "core": 0.5, "flick": 0.1, "add": 0.6, "gain": 1.1}, {"initial": 2.2, "grow_time": 0.35, "fade_in": 0.1, "decay": 0.93, "face_camera": true, "pulse": true})
		M.area(mark, "seeker_area", RED, 1.3, hold, -0.8)
		mark._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, _skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	if index < 5:
		# A needle from a shifting angle, through the chest.
		var yaw := [0.0, 0.28, -0.3, 0.14, -0.12][index] as float
		var pitch := [0.05, -0.12, 0.1, -0.06, 0.14][index] as float
		var at := Vector3(0, CHEST + [0.0, 0.2, -0.1, 0.3, 0.1][index] as float, 0)
		K.put(art, K.FLAT, _needle(), "SeekerNeedle", at, Vector3(1.0, 1.0, 3.6), 0.22, {"sweep": 0.04, "tail": 3.0, "soft": 0.8, "hot": M.hot(BLUSH), "core": 0.4, "add": 0.7, "gain": 1.1}, {"fade_in": 0.01, "decay": 0.4}, Vector3(pitch, yaw, 0))
		K.put(art, K.FLAT, _puncture(), "SeekerPuncture", at + Vector3(0, 0, -0.35), Vector3.ONE * (0.75 + 0.08 * float(index)), 0.25, {"soft": 0.7, "hot": M.hot(BLUSH), "core": 0.4, "add": 0.7}, {"initial": 0.3, "grow_time": 0.25, "fade_in": 0.01, "decay": 0.4, "face_camera": true})
		M.sparks(art, "seeker_sparks", [RED, ROSE, BLUSH], 10, 0.05, 0.3, 3.5, 2.0, 0.1, 0.0, 0.45, at, 6.0, 73, -0.1, 0.1)
		return true
	# The sixth: run through, and out the far side.
	K.put(art, K.SOLID, _lance(), "SeekerLance", Vector3(0, CHEST, -4.0), Vector3(3.2, 3.2, 6.5), 0.32, {"rim_color": ROSE, "rim": 0.9, "glow_color": BLUSH, "heat": 0.6}, {"travel": Vector3(0, 0, 3.6), "fade_in": 0.01, "decay": 0.97})
	K.put(art, K.FLAT, _needle(), "SeekerSpike", Vector3(0, CHEST, 4.5), Vector3(3.2, 3.2, 6.5), 0.6, {"sweep": 0.06, "tail": 9.0, "soft": 0.8, "hot": M.hot(BLUSH), "core": 0.4, "add": 0.7, "gain": 1.2}, {"fade_in": 0.01, "decay": 0.45})
	K.put(art, K.FLAT, _rings(), "SeekerRings", Vector3(0, CHEST, -0.3), Vector3.ONE * 1.5, 0.6, {"soft": 1.0, "hot": M.hot(BLUSH), "core": 0.5, "add": 0.6}, {"initial": 0.2, "grow_time": 0.6, "fade_in": 0.01, "decay": 0.35})
	K.put(art, K.BITS, _burst(), "SeekerBurst", Vector3(0, CHEST, 0.2), Vector3.ONE, 1.4, {"life": 1.2, "gravity": 5.0, "drag": 1.0, "piece": 0.5, "sway": 0.3, "floor_y": 0.08 - CHEST, "shrink": 0.85, "spin": 6.0}, {"decay": 0.85})
	M.shock(art, "seeker_ground_ring", RED, 3.0, 0.02, 0.45, 0.16)
	K.put(art, K.FLAT, _puncture(), "SeekerHeartBurst", Vector3(0, CHEST, -0.4), Vector3.ONE * 2.2, 0.45, {"soft": 0.7, "hot": M.hot(BLUSH), "core": 0.4, "add": 0.7}, {"initial": 0.3, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.4, "face_camera": true})
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var far := K.extra(parent, art.to_global(Vector3(0, 0, 2.6)), 1.3, "StarFar_" + ID, source)
	if far:
		M.sparks(far, "seeker_far_sparks", [RED, ROSE, BLUSH], 26, 0.1, 0.5, 4.0, 3.5, 0.14, 0.03, 0.9, Vector3.UP * CHEST, 5.0, 74, -0.2, 0.2)
		M.flash(far, "seeker_far_flash", RED, 1.8, 0.03, 0.35)
		M.cracks(far, "seeker_far_cracks", RED, 1.8, 0.03, 1.0, 6, 75)
		far._draw()
	return true
