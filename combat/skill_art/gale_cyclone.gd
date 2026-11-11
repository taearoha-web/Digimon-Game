extends RefCounted
## Lancer Lv.84 "Gale Cyclone" (burst, slows): a towering cyclone of spears. Wind-up: wind
## rises off the ground in a ring round the lancer and dust and leaves are drawn in.
## Release: a tall funnel of mint wind roars up round him with a tighter one turning the
## other way inside it; six spears ride the cyclone round and up, a broad spiral of wind
## races out over the ground, a ring sweeps the area and leaves and shards are whirled up.
## Aftermath: the funnel lifts and thins, the wind on the ground keeps turning (the slow),
## dust settles. Mint, sea green, pale aqua. Taller and wider than Typhoon Spear.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const MINT := Color("7affd0")
const SEA := Color("1fae8a")
const AQUA := Color("d8fff2")
const LEAF := Color("8fe07a")
const DUST := Color("cfe0c8")
const R := 7.5


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.15, duration)
	var s := float(skill.get("radius", R)) / R
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.funnel("gale_rise", 2.6, 2.2, 2.4, 0.6, 7, 0.32, B.a(MINT, 0.85), B.a(AQUA, 0.0)), "GaleRise", Vector3.ZERO, Vector3.ONE * s, t + 0.05, {"sweep": t * 0.8, "soft": 0.8, "hot": B.hot(AQUA, 0.7), "flow": 2.5, "add": 0.55}, {"spin": 4.0, "fade_in": 0.1, "decay": 0.9})
	B.light(art, B.spiral("gale_in", 4.6, 0.8, 1.2, 0.5, B.a(MINT, 0.8), B.a(AQUA, 0.9), 3), "GaleIn", Vector3.UP * 0.07, Vector3.ONE * s, t + 0.05, {"sweep": t * 0.8, "soft": 0.8, "hot": B.hot(AQUA, 0.8), "add": 0.55}, {"spin": 5.0, "fade_in": 0.1, "decay": 0.9})
	B.bits(art, B.gather("gale_gather", "shard", 22, 4.4, 9.0, 1.5, [MINT, AQUA, LEAF, DUST], 0.18, 211, 0.2, 1.6), "GaleGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.18, "add": 0.45, "shrink": 0.4, "spin": 8.0})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var radius := float(skill.get("radius", R))
	var s := radius / R
	var at := B.ground(origin)
	var art := B.open(c, at, 1.7, "Cyclone")
	if art == null:
		return false
	var tall := B.sky(c, at, 7.5)
	var hs := clampf(tall / 7.5, 0.6, 1.0)
	B.light(art, B.funnel("gale_funnel", 1.2, 4.6, 7.5, 2.0, 8, 0.6, B.a(MINT, 0.92), B.a(AQUA, 0.15)), "GaleFunnel", Vector3.ZERO, Vector3(s, hs, s), 1.25, {"sweep": 0.22, "soft": 0.7, "hot": B.hot(AQUA, 0.8), "flow": 2.8, "add": 0.6}, {"fade_in": 0.01, "decay": 0.5, "spin": -6.5, "travel": Vector3.UP * 1.2, "initial": 0.7, "grow_time": 0.25})
	B.light(art, B.funnel("gale_core", 0.7, 2.2, 6.0, 1.6, 5, 0.4, B.a(AQUA, 0.9), B.a(MINT, 0.1)), "GaleCore", Vector3.ZERO, Vector3(1, hs, 1), 1.0, {"sweep": 0.18, "soft": 0.7, "hot": B.hot(AQUA), "flow": 3.5, "add": 0.65}, {"fade_in": 0.01, "decay": 0.5, "spin": 9.0})
	B.body(art, B.lance_ring("gale_spears", 6, 2.8, 2.6, Color("2a4a40"), Color("c8fff0"), MINT, 1.2, 0.35), "GaleSpears", Vector3.ZERO, Vector3.ONE * s, 1.0, {"rim_color": AQUA, "rim": 0.8, "glow_color": MINT}, {"initial": 0.6, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.55, "spin": -7.0, "travel": Vector3.UP * 2.6})
	B.light(art, B.spiral("gale_ground", 1.0, 7.2, 1.0, 0.9, B.a(MINT, 0.9), B.a(SEA, 0.35), 4), "GaleGround", Vector3.UP * 0.07, Vector3.ONE * s, 1.6, {"sweep": 0.2, "soft": 0.7, "hot": B.hot(AQUA, 0.8), "flow": 2.0, "add": 0.6}, {"fade_in": 0.01, "decay": 0.6, "spin": -2.5})
	M.shock(art, "gale_shock", MINT, radius, 0.06, 0.55, 0.2, 0.1)
	B.bits(art, B.whirl("gale_leaves", "shard", 36, 1.5, 5.0, 7.0, 7.0, [MINT, AQUA, LEAF, SEA], 0.22, 212, -1.0, 0.3, 2.0), "GaleLeaves", Vector3.ZERO, 1.5, {"life": 1.3, "gravity": 2.5, "drag": 1.2, "piece": 0.22, "add": 0.35, "shrink": 0.5, "spin": 9.0, "sway": 0.3})
	var after := B.open(c, at, 1.8, "Dust", 1)
	if after:
		M.dust(after, "gale_dust", DUST, 16, radius * 0.5, radius * 0.95, 0.05, 1.4, Vector3.ZERO, 1.1, 213)
		M.flash(after, "gale_flash", MINT, radius * 0.5, 0.0, 0.35)
	return true
