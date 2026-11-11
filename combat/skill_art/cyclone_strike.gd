extends RefCounted
## Warrior Lv.60 "Cyclone Strike" (burst, stun): a storm of blades whirled round the body.
## Wind-up: a copper wind spirals in along the ground and sparks are sucked towards the
## warrior. Release: three copper crescents are flung out round him, rising and widening
## as they spin, inside a tight ring of the blade's own circle and a funnel of wind; a
## shock ring marks the reach. Aftermath: a three-armed whirl is scored into the ground,
## dust rolls out and the funnel drifts up and thins. Copper, gold, ember brown.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const COPPER := Color("ff8a4a")
const GOLD := Color("ffc46a")
const DEEP := Color("7a2a10")
const DUST := Color("c9a27a")
## The design radius (the skill's own); a ranked-up radius scales the whole piece.
const R := 6.5


static func _crescents() -> ArrayMesh:
	if M.has("cyc_crescents"):
		return M.get_mesh("cyc_crescents")
	var st := B._st()
	for k in 3:
		var a0 := TAU * float(k) / 3.0
		var pts := M.arc(Vector3.ZERO, 4.2, a0, a0 + 1.9, 1.15, 0.85, 22, 4.7)
		K.ribbon(st, pts, 1.25, B.a(COPPER, 0.95), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, B.a(GOLD, 0.2))
		K.ribbon(st, pts, 0.5, B.a(COPPER, 0.75), 0.0, 0.0, B.flat(pts[11]).normalized(), 1.0, 0.0, 1.0, B.a(GOLD, 0.0))
		var back := M.arc(Vector3.ZERO, 3.75, a0 + 0.15, a0 + 1.9, 1.15, 0.85, 22, 4.2)
		K.ribbon(st, back, 0.16, B.a(DEEP, 0.85), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return B._done("cyc_crescents", st)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var s := float(skill.get("radius", R)) / R
	var t := maxf(0.15, duration)
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.spiral("cyc_wind_in", 3.6, 0.5, 1.4, 0.4, B.a(COPPER, 0.75), B.a(GOLD, 0.9), 2), "CycWindIn", Vector3.UP * 0.07, Vector3.ONE * s, t + 0.05, {"sweep": t * 0.8, "soft": 0.8, "hot": B.hot(GOLD, 0.8), "add": 0.55}, {"spin": -4.0, "fade_in": 0.1, "decay": 0.9})
	B.bits(art, B.gather("cyc_gather", "ember", 22, 3.2, 7.0, 1.2, [COPPER, GOLD, Color("ffd9a0")], 0.14, 61, 0.3, 1.8), "CycGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.2, "piece": 0.14, "add": 0.8, "shrink": 0.4, "spin": 5.0})
	# A ring tightening round the feet: the spin coiling up.
	B.light(art, K.shock("cyc_coil_ring", B.a(COPPER, 1.0), 0.3), "CycCoil", Vector3.UP * 0.08, Vector3.ONE * 1.1, t + 0.05, {"soft": 1.0, "hot": B.hot(GOLD, 0.9), "add": 0.6}, {"initial": 3.0, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.95})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var radius := float(skill.get("radius", R))
	var s := radius / R
	var at := B.ground(origin)
	var art := B.open(c, at, 1.6, "Spin")
	if art == null:
		return false
	# The storm of blades: three crescents flung out, rising as they widen.
	B.light(art, _crescents(), "CycBlades", Vector3.ZERO, Vector3.ONE * s, 0.6, {"soft": 0.65, "hot": B.hot(GOLD), "core": 0.35, "add": 0.65, "gain": 1.15}, {"initial": 0.5, "grow_time": 0.5, "fade_in": 0.01, "decay": 0.55, "spin": -9.0})
	B.light(art, B.funnel("cyc_funnel", 0.8, 2.7, 3.8, 1.3, 6, 0.5, B.a(COPPER, 0.9), B.a(GOLD, 0.1)), "CycFunnel", Vector3.ZERO, Vector3(s, 1.0, s), 1.0, {"soft": 0.8, "hot": B.hot(GOLD, 0.8), "flow": 2.4, "add": 0.6}, {"initial": 0.6, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.45, "spin": -6.0, "travel": Vector3.UP * 0.9})
	M.shock(art, "cyc_shock", COPPER, radius, 0.05, 0.5, 0.2)
	B.light(art, B.spiral("cyc_scar", 0.7, 5.6, 1.15, 0.42, B.a(COPPER, 0.85), B.a(DEEP, 0.5), 3), "CycScar", Vector3.UP * 0.06, Vector3.ONE * s, 1.55, {"sweep": 0.18, "soft": 0.5, "hot": B.hot(COPPER, 0.8), "core": 0.4, "flick": 0.08, "add": 0.55}, {"decay": 0.6})
	B.light(art, B.slash("cyc_inner", 1.7, 0.0, TAU, 0.8, 1.45, 0.85, B.a(GOLD, 0.9), B.a(COPPER, 0.6), Color(0, 0, 0, 0), -1.0, 0.0), "CycInner", Vector3.ZERO, Vector3.ONE, 0.32, {"sweep": 0.08, "tail": 1.2, "soft": 0.6, "hot": B.hot(GOLD), "add": 0.7}, {"fade_in": 0.01, "decay": 0.5, "spin": -14.0})
	B.bits(art, B.whirl("cyc_sparks", "ember", 30, 1.0, 3.0, 8.0, 2.5, [COPPER, GOLD, Color("ffe0b0")], 0.15, 62, -1.0), "CycSparks", Vector3.ZERO, 0.9, {"life": 0.75, "gravity": 6.0, "drag": 1.5, "piece": 0.15, "add": 0.75, "shrink": 0.3, "spin": 6.0})
	# The aftermath: dust rolling out and a flash under the storm.
	var after := B.open(c, at, 1.4, "Dust", 1)
	if after:
		M.dust(after, "cyc_dust", DUST, 14, radius * 0.5, radius * 0.85, 0.04, 1.3, Vector3.ZERO, 1.0, 63)
		M.flash(after, "cyc_flash", COPPER, radius * 0.55, 0.0, 0.35)
	return true
