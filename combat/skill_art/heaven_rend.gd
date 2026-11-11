extends RefCounted
## Lancer Lv.96 "Heaven Rend" (burst, stuns): the lance tears the sky open and brings it
## down. Wind-up: a jagged rift of gold light splits open in the sky behind the lancer (as
## the camera sees it) and faint fissures glow round his feet. Release: one colossal
## downward stroke of light falls from the rift to the ground in front of him, the rift
## flares wide, a ring sweeps the whole great area, fissures of light burst out to its
## edge, a crown of light columns stands up round him and rock is thrown. Aftermath: the
## rift closes, dust rolls out, motes drift. Gold, pale gold, dusk violet for depth.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const GOLD := Color("ffd85a")
const PALE := Color("fff3c0")
const DUSK := Color("6a4aa8")
const AMBER := Color("ffaa3a")
const ROCK := Color("6b5a4c")
const R := 9.0


## The rift: a jagged vertical tear of light (XY plane, facing +Z), 1 tall from y 0 to 1.
static func _rift() -> ArrayMesh:
	if M.has("hrend_rift"):
		return M.get_mesh("hrend_rift")
	var rng := RandomNumberGenerator.new()
	rng.seed = 241
	var st := B._st()
	var pts := PackedVector3Array()
	for i in 11:
		var t := float(i) / 10.0
		pts.append(Vector3(rng.randf_range(-0.07, 0.07) if i > 0 and i < 10 else 0.0, t, 0.0))
	K.ribbon(st, pts, 0.26, B.a(GOLD, 0.95), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, B.a(PALE, 0.95))
	K.ribbon(st, pts, 0.08, B.a(Color(0.18, 0.08, 0.3), 1.0), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	K.disc(st, 0.5, B.a(DUSK, 0.45), 0.0, 20, 0.0, Vector3.BACK, Vector3(0, 0.5, -0.02), B.a(DUSK, 0.0), 0.0, true)
	for k in 6:
		var y := rng.randf_range(0.15, 0.85)
		var s := -1.0 if k % 2 == 0 else 1.0
		K.ribbon(st, PackedVector3Array([Vector3(0, y, 0), Vector3(s * rng.randf_range(0.12, 0.25), y + rng.randf_range(-0.08, 0.08), 0)]), 0.05, B.a(PALE, 0.9), 0.0, 0.0, Vector3.BACK, 1.0)
	return B._done("hrend_rift", st)


## A crown of light columns in a ring of radius 1 (UV.y up).
static func _crown() -> ArrayMesh:
	if M.has("hrend_crown"):
		return M.get_mesh("hrend_crown")
	var st := B._st()
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var p := Vector3(sin(ang), 0, cos(ang))
		K.beam(st, p, 1.0, 0.16, B.a(GOLD, 0.85), 2, 0.025 * float(i), 0.0, 0.05)
		K.disc(st, 0.18, B.a(PALE, 0.8), 0.01, 12, 0.025 * float(i), Vector3.UP, p, B.a(GOLD, 0.0))
	return B._done("hrend_crown", st)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.15, duration)
	var s := float(skill.get("radius", R)) / R
	var at := B.ground(origin)
	var art := B.open(c, at, t + 0.05, "Windup")
	if art == null:
		return false
	var spot := K.beyond(art, 2.2)
	var h := B.sky(c, at + spot, 8.5)
	B.light(art, _rift(), "HRendRiftOpen", spot + Vector3.UP * (h * 0.35), Vector3(2.6, h * 0.62, 1.0), t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(PALE), "flick": 0.12, "add": 0.7}, {"initial": 0.4, "grow_time": 0.9, "fade_in": 0.05, "decay": 0.99, "face_camera": true})
	M.cracks(art, "hrend_omen", B.a(GOLD, 0.6), R * 0.55 * s, 0.0, t + 0.05, 10, 242)
	B.bits(art, B.gather("hrend_gather", "ember", 22, 3.6, 8.0, 2.5, [GOLD, PALE, AMBER], 0.13, 243, 0.3, 2.4), "HRendGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.13, "add": 0.8, "shrink": 0.4})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var radius := float(skill.get("radius", R))
	var s := radius / R
	var at := B.ground(origin)
	var art := B.open(c, at, 1.8, "Rend")
	if art == null:
		return false
	# The stroke: from high behind him down to the ground in front, in the plane of his facing.
	B.light(art, B.vslash("hrend_stroke", 4.2, 0.6, -2.5, 2.6, B.a(GOLD, 0.97), B.a(PALE, 0.9), B.a(DUSK, 0.8)), "HRendStroke", Vector3.UP * 1.6, Vector3.ONE, 0.55, {"sweep": 0.08, "tail": 3.5, "soft": 0.55, "hot": B.hot(PALE), "core": 0.3, "add": 0.75, "gain": 1.2}, {"fade_in": 0.01, "decay": 0.45}, Vector3(0, PI * 0.5, 0))
	M.shock(art, "hrend_shock", GOLD, radius, 0.06, 0.6, 0.2, 0.1)
	M.cracks(art, "hrend_cracks", GOLD, radius * 0.95, 0.06, 1.6, 12, 244)
	B.light(art, _crown(), "HRendCrown", Vector3.ZERO, Vector3(radius * 0.6, 6.0, radius * 0.6), 0.8, {"soft": 1.6, "hot": B.hot(PALE, 0.9), "core": 0.55, "flow": 2.5, "add": 0.7}, {"delay": 0.12, "initial": 0.5, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.35})
	M.flash(art, "hrend_flash", GOLD, radius * 0.4, 0.04, 0.4)
	M.rubble(art, "hrend_rubble", [ROCK, ROCK.lightened(0.14), ROCK.darkened(0.2)], 20, 1.0, radius * 0.6, 4.0, 7.0, 0.34, 0.06, 1.3, Vector3.ZERO, 245)
	var sky := B.open(c, at, 1.6, "Rift", 1)
	if sky:
		var spot := K.beyond(sky, 2.2)
		var h := B.sky(c, at + spot, 8.5)
		B.light(sky, _rift(), "HRendRift", spot + Vector3.UP * (h * 0.35), Vector3(2.6, h * 0.62, 1.0), 1.0, {"soft": 0.6, "hot": B.hot(PALE), "flick": 0.1, "add": 0.75}, {"initial": 1.0, "fade_in": 0.01, "decay": 0.3, "face_camera": true, "turn": Vector3(0, 0, 0)})
		M.dust(sky, "hrend_dust", Color("d8c8a8"), 18, radius * 0.5, radius * 0.95, 0.08, 1.4, Vector3.ZERO, 1.1, 246)
		M.sparks(sky, "hrend_motes", [GOLD, PALE], 26, 0.5, radius * 0.7, 0.8, 4.0, 0.13, 0.2, 1.5, Vector3.ZERO, -1.0, 247, 0.1, 0.6)
	return true
