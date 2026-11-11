extends RefCounted
## Lancer Lv.92 "Gungnir" (single, pierces 5 on a long line): the god's spear is thrown.
## Wind-up: a great runed spear of gold forms over the lancer's shoulder, point forward,
## turning rune rings round its shaft, and a circle of runes opens at his feet. Release:
## the spear is hurled down the whole line in an instant, a gold trail behind it; rune rings
## burst open along its path one after another, every foe on the line flares, and where its
## flight ends a column of gold stands and a rune seal flares on the ground. Gold, pale
## gold, storm blue for the runes' shadow.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const GOLD := Color("ffd24a")
const PALE := Color("fff3c0")
const STORM := Color("3a4a8a")
const AMBER := Color("ffa83a")
const L := 15.0
const FLIGHT := 0.2
const SIZE := 3.2


static func _spear() -> ArrayMesh:
	if M.has("gungnir_spear"):
		return M.get_mesh("gungnir_spear")
	var p := M.lance(Color("5a3a1a"), Color("ffe6a0"), GOLD)
	# Rune bands round the shaft.
	p.ink(GOLD, 0.0, 1.0)
	for y in [0.16, 0.3, 0.44, 0.58]:
		p.tube(Vector3(0, y, 0), Vector3(0, y + 0.022, 0), 0.026, 0.026, 6)
	return M.solid("gungnir_spear", p)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	# Over the shoulder, point forward, rising into place.
	B.body(art, _spear(), "GungnirForm", Vector3(0.4, 2.4, -1.2), Vector3.ONE * SIZE, t + 0.05, {"rim_color": PALE, "rim": 1.0, "glow_color": GOLD}, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.4, "decay": 0.99, "travel": Vector3(0, 0.3, -0.2)}, Vector3(PI * 0.5 - 0.15, 0, 0))
	B.light(art, B.hoops("gungnir_bands", 3, 0.0, 1.2, 0.5, 0.35, B.a(GOLD, 0.95), 0.0, 0.0, 0.12), "GungnirBands", Vector3(0.4, 2.5, -0.6), Vector3.ONE, t + 0.05, {"soft": 0.8, "hot": B.hot(PALE), "add": 0.65}, {"initial": 2.0, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.97}, Vector3(-0.15, 0, 0))
	B.light(art, B.runes("gungnir_seal", B.a(GOLD, 0.95), 12, 0.8), "GungnirSeal", Vector3.UP * 0.06, Vector3.ONE * 2.2, t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(PALE, 0.8), "add": 0.55}, {"initial": 0.6, "grow_time": 0.8, "spin": -1.2, "decay": 0.97})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, center)
	var line := B.pierce_line(c)
	var reach: float = line[0]
	var k := reach / L
	var at := B.ground(origin)
	var art := B.open(c, at, 1.4, "Throw")
	if art == null:
		return false
	B.body(art, _spear(), "GungnirSpear", Vector3(0.2, 1.6, -0.4), Vector3.ONE * SIZE, FLIGHT, {"rim_color": PALE, "rim": 1.0, "glow_color": GOLD, "priority": 2}, {"fade_in": 0.01, "decay": 0.95, "travel": Vector3(-0.2, -0.4, reach - SIZE * 0.6)}, Vector3(PI * 0.5, 0, 0))
	B.light(art, B.streak("gungnir_trail", 1.3, B.a(AMBER, 0.9), B.a(GOLD, 1.0)), "GungnirTrail", Vector3(0, 1.3, 0.4), Vector3(1, 1, reach), 0.6, {"sweep": FLIGHT, "tail": 2.0, "soft": 1.1, "hot": B.warm(GOLD), "core": 0.7, "add": 0.55, "gain": 0.95}, {"fade_in": 0.01, "decay": 0.5})
	B.light(art, B.hoops("gungnir_rings", 6, 1.5, L, 0.8, 1.5, B.a(GOLD, 0.95), FLIGHT / L, 1.3, 0.2), "GungnirRings", Vector3.ZERO, Vector3(1, 1, k), 0.7, {"soft": 0.8, "hot": B.hot(PALE), "add": 0.7}, {"fade_in": 0.01, "decay": 0.5})
	B.light(art, B.lane("gungnir_scar", 0.6, L, 1.2, B.a(STORM, 0.35), B.a(GOLD, 0.9), 0), "GungnirScar", Vector3.UP * 0.06, Vector3(1, 1, k), 1.3, {"sweep": FLIGHT, "soft": 0.6, "hot": B.hot(PALE, 0.7), "add": 0.5}, {"fade_in": 0.01, "decay": 0.55})
	B.bits(art, B.line_burst("gungnir_sparks", "ember", 28, 1.0, L, 0.6, 2.4, 3.5, [GOLD, PALE, AMBER], 0.14, 231, 1.5, FLIGHT), "GungnirSparks", Vector3.ZERO, 1.0, {"life": 0.7, "gravity": 5.0, "drag": 1.5, "piece": 0.14, "add": 0.75, "shrink": 0.3}, {}, Vector3(1, 1, k))
	M.shock(art, "gungnir_burst", GOLD, 2.6, 0.0, 0.4, 0.24, 0.1)
	# The end of its flight.
	var end := B.open(c, at + (c.fwd as Vector3) * reach, 1.4, "Land", 1)
	if end:
		M.pillar(end, "gungnir_pillar", GOLD, 2.8, 8.0, FLIGHT, 0.6)
		B.light(end, B.runes("gungnir_seal", B.a(GOLD, 0.95), 12, 0.8), "GungnirLand", Vector3.UP * 0.07, Vector3.ONE * 2.6, 1.1, {"soft": 0.6, "hot": B.hot(PALE, 0.8), "flick": 0.06, "add": 0.55}, {"delay": FLIGHT, "initial": 0.4, "grow_time": 0.2, "spin": 1.0, "decay": 0.55})
		M.shock(end, "gungnir_land", GOLD, 3.4, FLIGHT, 0.5, 0.22, 0.1)
		M.sparks(end, "gungnir_land_sparks", [GOLD, PALE, AMBER], 20, 0.2, 0.8, 5.0, 6.0, 0.15, FLIGHT, 0.8, Vector3.UP * 0.6, 7.0, 232)
	var hits := B.open(c, at, 1.3, "Hits", 1)
	if hits:
		hits.rotation = Vector3.ZERO
		B.pierce_hits(hits, c, line[1], origin, GOLD, PALE, reach / FLIGHT, 1.3)
	return true
