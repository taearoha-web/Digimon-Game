extends RefCounted
## Lancer Lv.80 "Dragon Lance" (single, pierces 8, burns): a fire dragon rides the thrust.
## Wind-up: fire licks up the line ahead and gathers at the lance point where a dragon's
## head of flame forms. Release: the dragon charges down the whole line, its body of fire
## weaving behind its head, every foe on the line flares, and the ground burns behind it:
## a row of flames kindles along the line from the lancer outward and keeps burning (the
## burn), embers rising, a ring at the end of the charge. Flame orange, red, gold.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const FLAME := Color("ff6a2a")
const RED := Color("d8261a")
const GOLD := Color("ffc84a")
const DEEP := Color("5a1408")
const L := 14.0
const CHARGE := 0.3


static func _head() -> ArrayMesh:
	return M.get_mesh("dlance_head") if M.has("dlance_head") else M.solid("dlance_head", B.dragon_head(FLAME, GOLD, Color("fff0c0"), Color("fff6a0")), Vector3.ONE * 2.0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var reach := float((skill.get("pierce", {}) as Dictionary).get("len", L))
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.lane("dlance_lane", 0.6, L, 2.0, B.a(DEEP, 0.35), B.a(FLAME, 0.9), 7), "DLanceLane", Vector3.UP * 0.06, Vector3(1, 1, reach / L), t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(GOLD, 0.7), "flick": 0.1, "add": 0.5}, {"fade_in": 0.05, "decay": 0.95})
	B.body(art, _head(), "DLanceForm", Vector3(0, 1.3, 1.3), Vector3.ONE * 1.3, t + 0.05, {"rim_color": GOLD, "rim": 0.9, "glow_color": Color("fff6a0")}, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.4, "decay": 0.99})
	B.light(art, B.flames("dlance_lick", 10, 1.0, 0.4, B.a(FLAME, 0.95), B.a(GOLD, 0.0), 201), "DLanceLick", Vector3(0, 0.05, 1.3), Vector3(0.6, 1.0, 0.6), t + 0.05, {"soft": 0.7, "hot": B.hot(GOLD), "flow": 3.5, "flick": 0.15, "add": 0.7}, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.1, "decay": 0.95})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, center)
	var line := B.pierce_line(c)
	var reach: float = line[0]
	var k := reach / L
	var at := B.ground(origin)
	var art := B.open(c, at, 1.4, "Dragon")
	if art == null:
		return false
	# The dragon charges: its head down the line, its body of fire weaving after it.
	B.body(art, _head(), "DLanceHead", Vector3(0, 1.4, 1.3), Vector3.ONE * 2.4, CHARGE, {"rim_color": GOLD, "rim": 0.9, "glow_color": Color("fff6a0")}, {"fade_in": 0.01, "decay": 0.85, "travel": Vector3(0, 0, reach - 1.3)})
	B.light(art, B.serpent("dlance_body", 0.4, L, 0.55, 2.5, 1.5, B.a(FLAME, 0.97), B.a(RED, 0.5), 1.3), "DLanceBody", Vector3.ZERO, Vector3(1, 1, k), CHARGE + 0.45, {"sweep": CHARGE, "tail": 0.9, "soft": 0.6, "hot": B.hot(GOLD), "core": 0.35, "flow": 3.0, "add": 0.7, "gain": 1.1}, {"fade_in": 0.01, "decay": 0.5})
	B.light(art, B.flame_line("dlance_fire", 34, 0.8, L, 0.9, 1.7, 0.55, B.a(FLAME, 0.95), B.a(GOLD, 0.0), CHARGE / L, 202), "DLanceFire", Vector3.UP * 0.04, Vector3(1, 1, k), 1.35, {"soft": 0.7, "hot": B.hot(GOLD), "flow": 3.5, "flick": 0.15, "add": 0.7}, {"fade_in": 0.01, "decay": 0.6})
	B.light(art, B.lane("dlance_scorch", 0.6, L, 1.5, B.a(DEEP, 0.75), B.a(FLAME, 0.9), 0), "DLanceScorch", Vector3.UP * 0.05, Vector3(1, 1, k), 1.35, {"sweep": CHARGE, "soft": 0.6, "hot": B.hot(GOLD, 0.7), "flick": 0.08, "add": 0.5}, {"fade_in": 0.01, "decay": 0.6})
	B.bits(art, B.line_burst("dlance_embers", "ember", 30, 0.8, L, 0.9, 1.0, 4.0, [FLAME, GOLD, RED], 0.14, 203, 0.5, CHARGE), "DLanceEmbers", Vector3.ZERO, 1.35, {"life": 1.0, "gravity": -1.0, "drag": 1.2, "piece": 0.14, "add": 0.8, "shrink": 0.3}, {}, Vector3(1, 1, k))
	M.shock(art, "dlance_burst", FLAME, 2.8, 0.0, 0.45, 0.24, 0.1)
	var hits := B.open(c, at, 1.3, "Hits", 1)
	if hits:
		hits.rotation = Vector3.ZERO
		B.pierce_hits(hits, c, line[1], origin, FLAME, GOLD, reach / CHARGE, 1.2)
	return true
