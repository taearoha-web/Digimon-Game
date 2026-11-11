extends RefCounted
## Warrior Lv.80 "Grand Cross" (burst, stun): a great cross of holy light. Wind-up: the
## outline of a cross draws itself out along the ground to the edge of the area and light
## gathers on the raised sword. Release: the cross blazes: four walls of gold light run out
## along its arms, columns of light stand where they end, a ring sweeps the whole area and a
## tall cross of light rises in the sky behind the warrior. Aftermath: the cross stays
## burned into the ground, glowing out, while motes drift up. Gold, pale gold, amber.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const HOLY := Color("ffd85a")
const PALE := Color("fff3c0")
const AMBER := Color("ffaa3a")
const DEEP := Color("7a5010")
const R := 7.5


## The ground cross: four arms (+Z, +X, -Z, -X) from the centre to R, UV.y outward.
static func _cross(key: String, width: float, color: Color, edge: Color, inner := 0.5) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := B._st()
	for k in 4:
		var ang := PI * 0.5 * float(k)
		var dir := Vector3(sin(ang), 0, cos(ang))
		K.ribbon(st, PackedVector3Array([dir * inner, dir * (R * 0.5), dir * R]), width, color, 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0, edge)
	K.disc(st, inner + width * 0.5, color, 0.0, 20)
	return B._done(key, st)


## Walls of light standing along the four arms (UV.y outward).
static func _walls() -> ArrayMesh:
	if M.has("gcross_walls"):
		return M.get_mesh("gcross_walls")
	var st := B._st()
	for k in 4:
		var ang := PI * 0.5 * float(k)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var side := Vector3(dir.z, 0, -dir.x)
		var pts := PackedVector3Array()
		for i in 7:
			var t := float(i) / 6.0
			pts.append(dir * lerpf(0.8, R * 0.95, t) + Vector3.UP * (0.9 * (1.0 - t * 0.5)))
		K.ribbon(st, pts, 1.9, B.a(HOLY, 0.9), 0.0, 0.0, side, 0.0, 0.0, 1.0, B.a(PALE, 0.4))
	return B._done("gcross_walls", st)


## Columns where the arms end.
static func _columns() -> ArrayMesh:
	if M.has("gcross_columns"):
		return M.get_mesh("gcross_columns")
	var st := B._st()
	for k in 4:
		var ang := PI * 0.5 * float(k)
		var dir := Vector3(sin(ang), 0, cos(ang))
		K.beam(st, dir * R * 0.92, 4.2, 1.1, B.a(HOLY, 0.8), 2, 0.03 * float(k), 0.0, 0.3)
		K.disc(st, 1.0, B.a(PALE, 0.8), 0.02, 16, 0.03 * float(k), Vector3.UP, dir * R * 0.92, B.a(HOLY, 0.0))
	return B._done("gcross_columns", st)


## The cross in the sky: an upright cross of light in a ring (XY plane, facing +Z).
static func _sky_cross() -> ArrayMesh:
	if M.has("gcross_sky"):
		return M.get_mesh("gcross_sky")
	var st := B._st()
	K.ribbon(st, PackedVector3Array([Vector3(0, -1.4, 0), Vector3(0, 0, 0), Vector3(0, 1.0, 0)]), 0.42, B.a(HOLY, 0.95), 0.0, 0.0, Vector3.BACK, 0.0, 0.0, 1.0, B.a(PALE, 0.9))
	K.ribbon(st, PackedVector3Array([Vector3(-0.85, 0.2, 0), Vector3(0, 0.2, 0), Vector3(0.85, 0.2, 0)]), 0.42, B.a(HOLY, 0.95), 0.0, 0.0, Vector3.BACK, 0.0)
	var ring := PackedVector3Array()
	for i in 41:
		var ang := TAU * float(i) / 40.0
		ring.append(Vector3(sin(ang), cos(ang), 0) * 0.62 + Vector3(0, 0.2, 0))
	K.ribbon(st, ring, 0.1, B.a(PALE, 0.95), 0.0, 0.0, Vector3.BACK, 0.0)
	K.disc(st, 1.25, B.a(HOLY, 0.4), 0.0, 28, 0.0, Vector3.BACK, Vector3(0, 0.2, -0.02), B.a(HOLY, 0.0), 0.0, true)
	return B._done("gcross_sky", st)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.15, duration)
	var s := float(skill.get("radius", R)) / R
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, _cross("gcross_omen", 0.35, B.a(HOLY, 0.75), B.a(PALE, 0.9)), "GCrossOmen", Vector3.UP * 0.06, Vector3.ONE * s, t + 0.05, {"sweep": t * 0.85, "soft": 0.5, "hot": B.hot(PALE, 0.8), "add": 0.5}, {"fade_in": 0.05, "decay": 0.95})
	B.light(art, B.hoop("gcross_gleam", B.a(HOLY, 1.0), 0.2), "GCrossGleam", Vector3(0, 2.3, 0), Vector3.ONE * 0.4, t + 0.05, {"soft": 1.0, "hot": B.hot(PALE), "add": 0.7}, {"initial": 2.5, "grow_time": 0.95, "fade_in": 0.15, "decay": 0.95, "face_camera": true})
	B.bits(art, B.gather("gcross_gather", "ember", 16, 2.0, 4.0, 2.5, [HOLY, PALE], 0.12, 91, 0.4, 2.0), "GCrossGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.12, "add": 0.8, "shrink": 0.4})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var radius := float(skill.get("radius", R))
	var s := radius / R
	var at := B.ground(origin)
	var art := B.open(c, at, 1.8, "Cross")
	if art == null:
		return false
	B.light(art, _walls(), "GCrossWalls", Vector3.ZERO, Vector3.ONE * s, 0.55, {"sweep": 0.14, "tail": 1.6, "soft": 0.8, "hot": B.hot(PALE), "core": 0.4, "add": 0.7, "gain": 1.1}, {"fade_in": 0.01, "decay": 0.5})
	B.light(art, _cross("gcross_blaze", 1.1, B.a(HOLY, 0.95), B.a(AMBER, 0.6)), "GCrossBlaze", Vector3.UP * 0.07, Vector3.ONE * s, 1.75, {"sweep": 0.14, "soft": 0.55, "hot": B.hot(PALE), "core": 0.35, "flick": 0.06, "add": 0.6}, {"fade_in": 0.01, "decay": 0.55})
	M.shock(art, "gcross_shock", HOLY, radius, 0.04, 0.55, 0.2, 0.1)
	B.light(art, _columns(), "GCrossColumns", Vector3.ZERO, Vector3.ONE * s, 0.75, {"soft": 1.6, "hot": B.hot(PALE, 0.9), "core": 0.55, "flow": 2.5, "add": 0.7}, {"delay": 0.12, "initial": 0.4, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.35})
	M.flash(art, "gcross_flash", HOLY, radius * 0.45, 0.0, 0.35)
	M.sparks(art, "gcross_motes", [HOLY, PALE], 26, 0.5, radius * 0.8, 0.8, 4.0, 0.13, 0.15, 1.5, Vector3.ZERO, -1.0, 92, 0.1, 0.6)
	# The cross in the sky behind the warrior (as the camera sees it).
	var sky := B.open(c, at, 1.4, "SkyCross", 1)
	if sky:
		var spot := K.beyond(sky, 1.6)
		var h := B.sky(c, at + spot, 4.0)
		var size := clampf(h / 3.6, 0.6, 1.0) * 1.6
		B.light(sky, _sky_cross(), "GCrossSky", spot + Vector3.UP * maxf(1.9, h - size * 1.2), Vector3.ONE * size, 1.3, {"soft": 0.7, "hot": B.hot(PALE), "core": 0.4, "add": 0.65}, {"initial": 0.3, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.6, "face_camera": true, "travel": Vector3.UP * 0.3})
		M.pillar(sky, "gcross_pillar", HOLY, 1.3, 5.0, 0.0, 0.5)
	return true
