extends RefCounted
## Warrior Lv.64 "Brandish" (single target): one huge sweeping cut. Wind-up: the blade is
## drawn back, its edge leaving a smouldering red trace at the warrior's side while the arc
## of the coming sweep glows faintly on the ground ahead. Release: a broad crescent of
## red-orange light sweeps through the target from the left, a thinner gold after-image
## follows it; at the target sparks fly forward, a ring snaps out and a burning slash is
## scored across the ground. Compact: everything stays between the warrior and his target.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const RED := Color("ff5a3a")
const GOLD := Color("ffc25a")
const EMBER := Color("ff8a3a")
const DEEP := Color("6a1408")
const HALF := 1.25


## The ground scar of the cut: a long tapering gash across +X, glowing at its core.
static func _scar() -> ArrayMesh:
	if M.has("brandish_scar"):
		return M.get_mesh("brandish_scar")
	var st := B._st()
	var pts := PackedVector3Array()
	for i in 9:
		var t := float(i) / 8.0
		pts.append(Vector3(lerpf(-1.6, 1.6, t), 0.0, sin(t * PI) * 0.25 - 0.1))
	K.ribbon(st, pts, 1.0, B.a(RED, 0.9), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, B.a(GOLD, 0.7))
	K.ribbon(st, pts, 0.3, B.a(DEEP, 0.95), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return B._done("brandish_scar", st)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	# The edge drawn back: a smouldering trace behind the right shoulder.
	B.light(art, B.slash("brandish_trace", 1.4, PI * 0.5, PI * 1.25, 1.6, 0.8, 0.9, B.a(RED, 0.95), B.a(GOLD, 0.7), Color(0, 0, 0, 0), -1.0, 0.8), "BrandishTrace", Vector3.ZERO, Vector3.ONE, t + 0.05, {"sweep": t * 0.6, "soft": 0.7, "hot": B.hot(GOLD), "flick": 0.15, "flow": 3.0, "add": 0.65}, {"fade_in": 0.1, "decay": 0.92})
	# The arc it will sweep, glowing faintly on the ground ahead.
	B.light(art, B.slash("brandish_omen", 2.9, -HALF, HALF, 0.0, 0.0, 0.3, B.a(RED, 0.7), B.a(GOLD, 0.5), Color(0, 0, 0, 0), -1.0, 0.0), "BrandishOmen", Vector3.UP * 0.06, Vector3.ONE, t + 0.05, {"sweep": t * 0.9, "soft": 0.5, "hot": B.hot(RED, 0.6), "add": 0.4}, {"fade_in": 0.15, "decay": 0.9})
	B.bits(art, B.gather("brandish_gather", "ember", 14, 1.6, 4.0, 1.0, [RED, GOLD, EMBER], 0.12, 71, 0.6, 1.8), "BrandishGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.12, "add": 0.8, "shrink": 0.4})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, center)
	var reach := clampf(B.flat(center - origin).length(), 2.0, 4.2)
	var s := reach / 3.0
	var art := B.open(c, B.ground(origin), 1.0, "Sweep")
	if art == null:
		return false
	# The sweep: left to right, falling a little, a heavy red blade with a gold edge.
	B.light(art, B.slash("brandish_sweep", 2.2, -HALF - 0.4, HALF + 0.3, 1.5, 0.8, 2.8, B.a(RED, 0.97), B.a(GOLD, 0.85), B.a(DEEP, 0.95), 3.4, 0.7), "BrandishSweep", Vector3.ZERO, Vector3.ONE * s, 0.5, {"sweep": 0.08, "tail": 3.5, "soft": 0.6, "hot": B.hot(GOLD), "core": 0.3, "add": 0.7, "gain": 1.2}, {"fade_in": 0.01, "decay": 0.45})
	B.light(art, B.slash("brandish_after", 3.0, -HALF, HALF + 0.4, 1.9, 1.2, 1.1, B.a(GOLD, 0.95), B.a(EMBER, 0.5), Color(0, 0, 0, 0), 3.6, 0.4), "BrandishAfter", Vector3.ZERO, Vector3.ONE * s, 0.5, {"sweep": 0.09, "tail": 3.5, "soft": 0.7, "hot": B.hot(GOLD), "add": 0.75}, {"delay": 0.05, "fade_in": 0.01, "decay": 0.45})
	# The cut's wave runs on past the foe and thins out.
	B.light(art, B.slash("brandish_wave", 1.6, -1.0, 1.0, 1.1, 1.1, 1.3, B.a(RED, 0.9), B.a(GOLD, 0.6), B.a(DEEP, 0.7), -1.0, 0.6), "BrandishWave", Vector3(0, 0, reach - 0.6), Vector3.ONE * s, 0.42, {"soft": 0.6, "hot": B.hot(GOLD), "core": 0.35, "add": 0.7}, {"delay": 0.06, "fade_in": 0.02, "decay": 0.3, "travel": Vector3(0, 0, 4.0), "initial": 0.7, "grow_time": 0.5})
	K.put(art, K.BITS, M.fan("brandish_spray", "ember", 26, 1.2, 3.0, HALF, 7.0, 3.0, [RED, GOLD, EMBER], 0.15, 72, 0.6, 1.5), "BrandishSpray", Vector3.ZERO, Vector3.ONE, 0.8, {"life": 0.65, "gravity": 6.0, "drag": 1.8, "piece": 0.15, "add": 0.75, "shrink": 0.3}, {"delay": 0.04, "decay": 0.8})
	# Where it bites: a ring, a flash and the burning gash across the ground.
	var hit := B.open(c, B.ground(center), 1.2, "Bite")
	if hit:
		B.light(hit, _scar(), "BrandishScar", Vector3(0, 0.06, 0.9), Vector3.ONE * s * 1.3, 1.25, {"sweep": 0.1, "soft": 0.55, "hot": B.hot(GOLD), "core": 0.4, "flick": 0.1, "add": 0.6}, {"delay": 0.03, "decay": 0.55})
		B.impact(hit, "brandish_hit", RED, GOLD, 2.8, 0.04, 22, Vector3.UP * 1.0)
	return true
