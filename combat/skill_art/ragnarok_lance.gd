extends RefCounted
## Lancer Lv.100 "Ragnarok Lance" (single, pierces 10): the lance of the world's end, the
## lancer's greatest thrust. Wind-up: a colossal lance of molten gold and crimson rises
## behind him, point forward, over a burning rune lane that runs the whole line; embers
## swirl up. Release: the colossus drives down the line: a gold-and-crimson shock trail,
## pressure rings bursting open along it, the ground splitting into a molten fissure from
## his feet to the end, jagged rock bursting up on both sides of the line one after another,
## every foe on it flaring; at the end of the line an eruption: a column of fire-gold, a
## ring and thrown rock. Aftermath: the fissure glows down, ash and embers drift. Gold,
## crimson, molten orange over dark rock.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const GOLD := Color("ffd84a")
const CRIMSON := Color("e8261c")
const MOLTEN := Color("ff7a1c")
const PALE := Color("fff0c0")
const ROCK := Color("4a3a36")
const L := 15.0
const DRIVE := 0.24
const SIZE := 6.0


static func _lance() -> ArrayMesh:
	if M.has("ragnarok_lance"):
		return M.get_mesh("ragnarok_lance")
	var p := M.lance(Color("2c1a1c"), Color("ffcf6a"), CRIMSON)
	p.ink(MOLTEN, 0.0, 1.0)
	for y in [0.2, 0.38, 0.54]:
		p.tube(Vector3(0, y, 0), Vector3(0, y + 0.02, 0), 0.025, 0.025, 6)
	return M.solid("ragnarok_lance", p)


## The molten fissure: a jagged glowing crack along +Z with branching cracks (UV.y along).
static func _fissure() -> ArrayMesh:
	if M.has("ragnarok_fissure"):
		return M.get_mesh("ragnarok_fissure")
	var rng := RandomNumberGenerator.new()
	rng.seed = 251
	var st := B._st()
	var pts := PackedVector3Array()
	for i in 25:
		var t := float(i) / 24.0
		pts.append(Vector3(rng.randf_range(-0.25, 0.25) if i > 0 else 0.0, 0.0, lerpf(0.5, L, t)))
	K.ribbon(st, pts, 1.6, B.a(MOLTEN, 0.95), 0.0, 0.0, Vector3.UP, 0.4, 0.0, 1.0, B.a(GOLD, 0.8))
	K.ribbon(st, pts, 0.55, B.a(Color(0.2, 0.03, 0.02), 1.0), 0.0, 0.0, Vector3.UP, 0.4, 0.0, 1.0, Color(0, 0, 0, -1), true)
	for k in 8:
		var z := lerpf(1.5, L - 1.0, (float(k) + rng.randf()) / 8.0)
		var s := -1.0 if k % 2 == 0 else 1.0
		var branch := PackedVector3Array([Vector3(0, 0, z), Vector3(s * rng.randf_range(0.6, 1.0), 0, z + rng.randf_range(0.2, 0.6)), Vector3(s * rng.randf_range(1.3, 2.0), 0, z + rng.randf_range(0.4, 1.0))])
		K.ribbon(st, branch, 0.32, B.a(MOLTEN, 0.85), 0.0, 0.0, Vector3.UP, 0.7, z / L, z / L + 0.08)
	return B._done("ragnarok_fissure", st)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var reach := float((skill.get("pierce", {}) as Dictionary).get("len", L))
	var at := B.ground(origin)
	var art := B.open(c, at, t + 0.05, "Windup")
	if art == null:
		return false
	var h := B.sky(c, at, 4.5)
	B.body(art, _lance(), "RagnarokForm", Vector3(0, clampf(h - 1.0, 2.2, 3.4), -2.6), Vector3.ONE * SIZE, t + 0.05, {"rim_color": PALE, "rim": 0.9, "glow_color": MOLTEN}, {"initial": 0.5, "grow_time": 0.8, "fade_in": 0.4, "decay": 0.99, "travel": Vector3(0, 0.2, -0.4)}, Vector3(PI * 0.5 - 0.08, 0, 0))
	B.light(art, B.lane("ragnarok_lane", 0.6, L, 2.6, B.a(Color(0.25, 0.04, 0.02), 0.5), B.a(MOLTEN, 0.95), 8), "RagnarokLane", Vector3.UP * 0.06, Vector3(1, 1, reach / L), t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(GOLD, 0.8), "flick": 0.1, "add": 0.55}, {"fade_in": 0.05, "decay": 0.95})
	B.bits(art, B.gather("ragnarok_gather", "ember", 22, 3.0, 6.0, 2.5, [GOLD, MOLTEN, CRIMSON], 0.14, 252, 0.2, 2.4), "RagnarokGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.14, "add": 0.8, "shrink": 0.4})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, center)
	var line := B.pierce_line(c)
	var reach: float = line[0]
	var k := reach / L
	var at := B.ground(origin)
	var art := B.open(c, at, 1.9, "Drive")
	if art == null:
		return false
	B.body(art, _lance(), "RagnarokLance", Vector3(0, 1.5, -2.0), Vector3.ONE * SIZE, DRIVE + 0.1, {"rim_color": PALE, "rim": 0.9, "glow_color": MOLTEN, "priority": 2}, {"fade_in": 0.01, "decay": 0.75, "travel": Vector3(0, -0.3, reach - SIZE * 0.6)}, Vector3(PI * 0.5, 0, 0))
	B.light(art, B.streak("ragnarok_trail", 2.4, B.a(CRIMSON, 0.92), B.a(MOLTEN, 1.0)), "RagnarokTrail", Vector3(0, 1.3, 0.3), Vector3(1, 1, reach), 0.7, {"sweep": DRIVE, "tail": 2.2, "soft": 1.0, "hot": B.warm(GOLD), "core": 0.65, "add": 0.55, "gain": 1.0}, {"fade_in": 0.01, "decay": 0.5})
	B.light(art, _fissure(), "RagnarokFissure", Vector3.UP * 0.06, Vector3(1, 1, k), 1.85, {"sweep": DRIVE, "soft": 0.5, "hot": B.hot(GOLD), "core": 0.35, "flick": 0.1, "flow": 1.2, "add": 0.6}, {"fade_in": 0.01, "decay": 0.6})
	B.body(art, B.spikes_line("ragnarok_spikes", 14, 1.6, L - 0.5, 2.0, 2.0, ROCK, B.a(MOLTEN, 1.0), DRIVE, 253), "RagnarokSpikes", Vector3.ZERO, Vector3(1, 1, k), 1.8, {"drop": -2.2, "flight": 0.14, "ease": 1.0, "rim_color": GOLD, "rim": 0.45, "glow_color": MOLTEN, "heat": 0.7}, {"fade_in": 0.01, "decay": 0.72})
	B.light(art, B.hoops("ragnarok_rings", 6, 1.5, L, 1.0, 1.9, B.a(GOLD, 0.95), DRIVE / L, 1.3, 0.24), "RagnarokRings", Vector3.ZERO, Vector3(1, 1, k), 0.75, {"soft": 0.8, "hot": B.hot(PALE), "add": 0.7}, {"fade_in": 0.01, "decay": 0.5})
	M.shock(art, "ragnarok_burst", CRIMSON, 3.2, 0.0, 0.45, 0.26, 0.1)
	# The eruption at the end of the line.
	var end := B.open(c, at + (c.fwd as Vector3) * reach, 1.8, "Erupt", 1)
	if end:
		M.pillar(end, "ragnarok_pillar", MOLTEN, 3.6, 8.5, DRIVE, 0.7)
		M.shock(end, "ragnarok_end", GOLD, 4.2, DRIVE, 0.55, 0.24, 0.1)
		M.rubble(end, "ragnarok_rubble", [ROCK, ROCK.lightened(0.14), ROCK.darkened(0.2)], 18, 0.3, 1.4, 4.0, 8.0, 0.36, DRIVE, 1.3, Vector3.ZERO, 254)
		M.sparks(end, "ragnarok_ash", [GOLD, MOLTEN, CRIMSON], 30, 0.3, 2.0, 1.2, 5.0, 0.14, DRIVE + 0.1, 1.4, Vector3.ZERO, -1.0, 255, 0.2, 1.2)
	var hits := B.open(c, at, 1.4, "Hits", 1)
	if hits:
		hits.rotation = Vector3.ZERO
		B.pierce_hits(hits, c, line[1], origin, MOLTEN, GOLD, reach / DRIVE, 1.4)
	return true
