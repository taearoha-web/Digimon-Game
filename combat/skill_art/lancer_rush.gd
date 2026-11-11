extends RefCounted
## Lancer Lv.64 "Lancer Rush" (self: ATK, speed, crit up): the urge to charge. Wind-up: the
## lancer crouches; orange speed lines rush in at him and a row of arrowheads glows on the
## ground ahead. Release: a burst of speed: streaks of orange light stream back past his
## body, three great arrowheads race forward off his chest, a dash ring snaps out and a fan
## of sparks is kicked up behind him; a ring of short flames flickers at his heels.
## Orange, amber, hot gold.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const ORANGE := Color("ff9a5a")
const AMBER := Color("ffc04a")
const RED := Color("ff5a2a")
const PALE := Color("fff0c8")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.chevrons("rush_marks", 4, B.a(ORANGE, 0.95), 0.9, 0.28), "RushMarks", Vector3(0, 0.07, 1.2), Vector3.ONE * 1.3, t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(AMBER), "add": 0.55}, {"fade_in": 0.05, "decay": 0.95})
	B.light(art, B.speedlines("rush_in", 16, 2.4, B.a(ORANGE, 0.9), 161, 1.4, 0.3, 2.0), "RushIn", Vector3(0, 0, 2.6), Vector3.ONE, t + 0.05, {"sweep": t * 0.6, "soft": 0.8, "hot": B.hot(AMBER), "add": 0.6}, {"fade_in": 0.05, "decay": 0.9, "travel": Vector3(0, 0, -2.4)})
	B.bits(art, B.gather("rush_gather", "ember", 14, 2.0, 5.0, 0.8, [ORANGE, AMBER, PALE], 0.12, 162, 0.3, 1.6), "RushGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.12, "add": 0.8, "shrink": 0.4})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var at := B.ground(origin)
	var art := B.open(c, at, 1.5, "Rush")
	if art == null:
		return false
	B.follow(c, art)
	# The burst: streaks stream back past him while arrowheads race on ahead.
	B.light(art, B.speedlines("rush_out", 22, 3.4, B.a(ORANGE, 0.95), 163, 1.0, 0.2, 2.2), "RushStreaks", Vector3(0, 0, 0.6), Vector3.ONE, 0.8, {"sweep": 0.12, "tail": 2.0, "soft": 0.7, "hot": B.hot(AMBER), "add": 0.7}, {"fade_in": 0.01, "decay": 0.55, "travel": Vector3(0, 0, -1.5)})
	B.light(art, B.chevrons("rush_heads", 3, B.a(AMBER, 0.97), 0.7, 0.42), "RushHeads", Vector3(0, 1.2, 0.8), Vector3.ONE * 1.6, 0.55, {"sweep": 0.08, "soft": 0.6, "hot": B.hot(PALE), "add": 0.75, "gain": 1.15}, {"fade_in": 0.01, "decay": 0.4, "travel": Vector3(0, 0.1, 5.5), "initial": 0.6, "grow_time": 0.3})
	M.shock(art, "rush_shock", ORANGE, 3.4, 0.0, 0.45, 0.24, 0.1)
	K.put(art, K.BITS, M.fan("rush_kick", "ember", 26, 0.3, 1.4, 0.9, 6.5, 3.0, [ORANGE, AMBER, RED], 0.15, 164, 0.1, 0.6), "RushKick", Vector3.ZERO, Vector3.ONE, 0.8, {"life": 0.65, "gravity": 7.0, "drag": 1.6, "piece": 0.15, "add": 0.75, "shrink": 0.3}, {"decay": 0.8}, Vector3(0, PI, 0))
	B.light(art, B.flames("rush_heels", 12, 0.9, 0.4, B.a(ORANGE, 0.95), B.a(AMBER, 0.0), 165), "RushHeels", Vector3.UP * 0.05, Vector3(0.75, 1.0, 0.75), 1.3, {"soft": 0.7, "hot": B.hot(AMBER), "flow": 4.0, "flick": 0.15, "add": 0.7}, {"initial": 0.4, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.55})
	M.flash(art, "rush_flash", ORANGE, 2.0, 0.0, 0.3)
	return true
