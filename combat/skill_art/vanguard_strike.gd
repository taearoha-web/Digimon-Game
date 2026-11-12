extends RefCounted
## Lancer Lv.68 "Vanguard Strike" (single, pierces 4): the spearhead of the charge. Wind-up:
## the line the thrust will pierce lights up on the ground and a wedge of blue light (the
## vanguard's shield-wall) forms at the lancer's front. Release: a great lance of blue light
## drives straight down the line, the wedge riding ahead of it; pressure rings stand round
## the thrust one after another, every foe on the line flares where it is run through, and
## the ground is scored along the line. Steel blue, sky blue, ice white.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const BLUE := Color("6ecbff")
const DEEP := Color("1f5aa8")
const ICE := Color("e0f6ff")
const STEEL := Color("b8d4ec")
## Seconds the thrust takes to the end of its line.
const DRIVE := 0.16


## The wedge: a broad arrowhead of light (flat, pointing +Z), 1 long.
static func _wedge() -> ArrayMesh:
	if M.has("vanguard_wedge"):
		return M.get_mesh("vanguard_wedge")
	var st := B._st()
	var tip := Vector3(0, 0, 0.6)
	for s in [-1.0, 1.0]:
		K.ribbon(st, PackedVector3Array([Vector3(s * 0.75, 0, -0.5), tip]), 0.32, B.a(BLUE, 0.95), 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0, B.a(ICE, 0.95))
		K.ribbon(st, PackedVector3Array([Vector3(s * 0.45, 0, -0.55), tip - Vector3(0, 0, 0.35)]), 0.16, B.a(ICE, 0.8), 0.0, 0.0, Vector3.UP, 0.0)
	K.disc(st, 0.55, B.a(BLUE, 0.4), 0.0, 3, 0.0, Vector3.UP, Vector3(0, 0, 0.0), B.a(BLUE, 0.0), 0.0, true)
	return B._done("vanguard_wedge", st)


static func _lance() -> ArrayMesh:
	return M.get_mesh("vanguard_lance") if M.has("vanguard_lance") else M.solid("vanguard_lance", M.lance(Color("2a3a5a"), STEEL, BLUE))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var reach := float((skill.get("pierce", {}) as Dictionary).get("len", 9.0))
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.lane("vanguard_lane", 0.6, 9.0, 2.6, B.a(DEEP, 0.3), B.a(BLUE, 0.9), 6), "VanguardLane", Vector3.UP * 0.06, Vector3(1, 1, reach / 9.0), t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(ICE, 0.7), "add": 0.5}, {"fade_in": 0.05, "decay": 0.95})
	B.light(art, _wedge(), "VanguardForm", Vector3(0, 1.0, 1.1), Vector3.ONE * 1.4, t + 0.05, {"soft": 0.6, "hot": B.hot(ICE), "flick": 0.1, "add": 0.65}, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.95}, Vector3(-0.35, 0, 0))
	B.bits(art, B.gather("vanguard_gather", "ember", 14, 1.8, 4.0, 0.6, [BLUE, ICE], 0.12, 171, 0.6, 1.6), "VanguardGather", Vector3(0, 0, 0.6), t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.12, "add": 0.8, "shrink": 0.4})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, center)
	var line := B.pierce_line(c)
	var reach: float = line[0]
	var at := B.ground(origin)
	var art := B.open(c, at, 1.2, "Thrust")
	if art == null:
		return false
	# The thrust: a lance of light three metres long driven to the end of the line.
	B.body(art, _lance(), "VanguardLance", Vector3(0, 1.1, 0.2), Vector3.ONE * 3.2, DRIVE + 0.12, {"rim_color": ICE, "rim": 0.9, "glow_color": BLUE}, {"fade_in": 0.01, "decay": 0.6, "travel": Vector3(0, 0, reach - 3.0)}, Vector3(PI * 0.5, 0, 0))
	B.light(art, B.streak("vanguard_streak", 1.0, B.a(BLUE, 0.9), B.a(ICE, 1.0)), "VanguardStreak", Vector3(0, 1.1, 0.4), Vector3(1, 1, reach), 0.55, {"sweep": DRIVE, "tail": 2.5, "soft": 1.0, "hot": B.warm(ICE), "core": 0.65, "add": 0.55, "gain": 1.0}, {"fade_in": 0.01, "decay": 0.5})
	B.light(art, _wedge(), "VanguardWedge", Vector3(0, 1.1, 1.0), Vector3.ONE * 2.0, DRIVE + 0.2, {"soft": 0.55, "hot": B.hot(ICE), "add": 0.75, "gain": 1.15}, {"fade_in": 0.01, "decay": 0.6, "travel": Vector3(0, 0, reach - 1.0)}, Vector3(-0.2, 0, 0))
	B.light(art, B.hoops("vanguard_hoops", 5, 1.5, 9.0, 0.7, 1.3, B.a(ICE, 0.95), DRIVE / 9.0, 1.1, 0.18), "VanguardHoops", Vector3.ZERO, Vector3(1, 1, reach / 9.0), 0.6, {"soft": 0.8, "hot": B.hot(ICE), "add": 0.65}, {"fade_in": 0.01, "decay": 0.5})
	B.light(art, B.lane("vanguard_scar", 0.6, 9.0, 1.4, B.a(DEEP, 0.55), B.a(BLUE, 0.95), 5), "VanguardScar", Vector3.UP * 0.06, Vector3(1, 1, reach / 9.0), 1.15, {"sweep": DRIVE, "soft": 0.6, "hot": B.hot(ICE, 0.8), "flick": 0.05, "add": 0.55}, {"fade_in": 0.01, "decay": 0.55})
	B.bits(art, B.line_burst("vanguard_chips", "ember", 24, 1.0, 9.0, 0.6, 2.0, 3.0, [BLUE, ICE, STEEL], 0.13, 172, 2.0, DRIVE), "VanguardChips", Vector3.ZERO, 0.9, {"life": 0.6, "gravity": 6.0, "drag": 1.5, "piece": 0.13, "add": 0.75, "shrink": 0.3}, {}, Vector3(1, 1, reach / 9.0))
	var hits := B.open(c, at, 1.3, "Hits", 1)
	if hits:
		hits.rotation = Vector3.ZERO
		B.pierce_hits(hits, c, line[1], origin, BLUE, ICE, reach / DRIVE, 1.2)
	return true
