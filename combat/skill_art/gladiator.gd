extends RefCounted
## Warrior Lv.100 "Gladiator" (single target): the legend's killing stroke, in an arena of
## his own. Wind-up: a ring of crimson-lit stone pillars heaves up round the warrior and his
## foe (open towards the camera), a crimson arena circle is drawn on the sand and a red war
## aura flares on the warrior. Release: an X of two crimson cuts crosses on the foe, then a
## great overhead cleave splits it: a ring and flash, sparks, and a burning fissure torn
## along the ground through the foe and beyond, rock thrown up. Aftermath: the arena pillars
## crumble back into the ground, embers drift. Crimson, gold, dark red, stone.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const CRIMSON := Color("ff3a3a")
const GOLD := Color("ffc04a")
const EMBER := Color("ff7a3a")
const DEEP := Color("5a0a10")
const STONE := Color("8a7a6a")
const SAND := Color("c8a878")
## The arena round the warrior and his foe.
const ARENA := 4.4


## Stone pillars in a ring (open towards +Z, where the camera is put), each with a red glow.
static func _pillars() -> ArrayMesh:
	if M.has("glad_pillars"):
		return M.get_mesh("glad_pillars")
	var rng := RandomNumberGenerator.new()
	rng.seed = 131
	var st := K.begin()
	var n := 9
	for i in n:
		var ang := lerpf(0.75, TAU - 0.75, float(i) / float(n - 1))
		var dir := Vector3(sin(ang), 0, cos(ang))
		var p := K.Part.new()
		p.ink(STONE, 0.3)
		p.tube(Vector3(0, -0.2, 0), Vector3(0, 1.6, 0), 0.32, 0.26, 6)
		p.ink(STONE.lightened(0.15), 0.4)
		p.box(Vector3(0, 1.65, 0), Vector3(0.75, 0.16, 0.75))
		p.box(Vector3(0, 0.0, 0), Vector3(0.8, 0.2, 0.8))
		p.ink(CRIMSON, 0.0, 1.0)
		p.box(Vector3(0, 1.0, 0.27), Vector3(0.1, 0.9, 0.06))
		p.ink(GOLD, 0.0, 1.0)
		p.gem(Vector3(0, 1.9, 0), Vector3(0.14, 0.18, 0.14))
		var h := rng.randf_range(0.85, 1.15)
		K.stamp(st, p, Transform3D(Basis(Vector3.UP, ang + PI).scaled(Vector3(1.0, h, 1.0)), dir * ARENA), 0.02 * float(i), 1.0)
	return M.keep("glad_pillars", K.finish(st, Vector3(1, 4, 1)))


## The burning fissure along +Z through the foe (from z -1 to 5).
static func _rift() -> ArrayMesh:
	if M.has("glad_rift"):
		return M.get_mesh("glad_rift")
	var rng := RandomNumberGenerator.new()
	rng.seed = 132
	var st := B._st()
	var pts := PackedVector3Array()
	for i in 13:
		var t := float(i) / 12.0
		pts.append(Vector3(rng.randf_range(-0.18, 0.18) if i > 0 and i < 12 else 0.0, 0.0, lerpf(-1.4, 5.2, t)))
	K.ribbon(st, pts, 1.1, B.a(CRIMSON, 0.9), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, B.a(GOLD, 0.6))
	K.ribbon(st, pts, 0.36, B.a(DEEP, 1.0), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	K.crack_star(st, rng, Vector3(0, 0, 0.3), 6, 0.2, 1.8, 0.16, Color(0.2, 0.03, 0.03, 1.0), 0.0, 1, 0.3)
	return B._done("glad_rift", st)


## The X: two diagonal cuts crossing at the origin (XY plane, facing +Z), the second a
## beat after the first (its own clock in UV2), each with a dark core line.
static func _x() -> ArrayMesh:
	if M.has("glad_xcut"):
		return M.get_mesh("glad_xcut")
	var st := B._st()
	for k in 2:
		var s := -1.0 if k == 0 else 1.0
		var pts := PackedVector3Array()
		for i in 13:
			var t := float(i) / 12.0
			pts.append(Vector3(s * lerpf(-1.5, 1.5, t), lerpf(1.6, -1.4, t), 0.0) + Vector3(0, sin(t * PI) * 0.18, 0))
		K.ribbon(st, pts, 0.85, B.a(CRIMSON, 0.97), 0.07 * float(k), 0.0, Vector3.BACK, 1.0, 0.0, 1.0, B.a(GOLD, 0.9))
		K.ribbon(st, pts, 0.2, B.a(DEEP, 0.95), 0.07 * float(k), 0.0, Vector3.BACK, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return B._done("glad_xcut", st)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.flames("glad_aura", 12, 1.7, 0.45, B.a(CRIMSON, 0.9), B.a(GOLD, 0.0), 133), "GladAura", Vector3.UP * 0.05, Vector3(0.75, 1.0, 0.75), t + 0.05, {"soft": 0.8, "hot": B.hot(EMBER), "flow": 3.5, "flick": 0.15, "add": 0.7}, {"initial": 0.3, "grow_time": 0.7, "fade_in": 0.1, "decay": 0.95})
	B.bits(art, B.gather("glad_gather", "ember", 16, 2.0, 5.0, 1.0, [CRIMSON, GOLD, EMBER], 0.13, 134, 0.5, 1.8), "GladGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.13, "add": 0.8, "shrink": 0.4})
	# The arena outlives the wind-up: it stands through the stroke (bound to the caster).
	var mid := B.ground(origin.lerp(aim, 0.5))
	var c2 := B.cast(parent, skill, origin, aim, visual)
	var arena := B.open(c2, mid, t + 1.7, "Arena")
	if arena:
		B.turn_to_camera(arena)
		B.body(arena, _pillars(), "GladPillars", Vector3.ZERO, Vector3.ONE, t + 1.65, {"drop": -2.4, "flight": maxf(0.12, t * 0.8), "ease": 1.0, "rim_color": Color("ffd0a0"), "rim": 0.45, "glow_color": CRIMSON}, {"fade_in": 0.01, "decay": 0.8})
		B.light(arena, B.runes("glad_ring", B.a(CRIMSON, 0.9), 12, 0.88), "GladRing", Vector3.UP * 0.06, Vector3.ONE * (ARENA + 0.5), t + 1.6, {"sweep": t, "soft": 0.6, "hot": B.hot(GOLD, 0.8), "flick": 0.05, "add": 0.5}, {"fade_in": 0.05, "decay": 0.75})
		M.dust(arena, "glad_sand", SAND, 12, ARENA - 0.6, ARENA + 0.4, 0.0, 1.0, Vector3.ZERO, 0.9, 135)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, center)
	var at := B.ground(center)
	var art := B.open(c, at, 1.3, "Stroke")
	if art == null:
		return false
	var cut := {"sweep": 0.06, "tail": 3.5, "soft": 0.6, "hot": B.hot(GOLD), "core": 0.35, "add": 0.7, "gain": 1.2}
	B.light(art, _x(), "GladCutX", Vector3.UP * 1.2, Vector3.ONE * 1.25, 0.5, cut, {"fade_in": 0.01, "decay": 0.5, "face_camera": true})
	B.light(art, B.vslash("glad_cleave", 3.0, 0.25, -2.6, 2.2, B.a(CRIMSON, 1.0), B.a(GOLD, 0.95), B.a(DEEP, 0.95)), "GladCleave", Vector3.UP * 1.4, Vector3.ONE, 0.5, {"sweep": 0.07, "tail": 3.5, "soft": 0.55, "hot": B.hot(GOLD), "core": 0.3, "add": 0.75, "gain": 1.25}, {"delay": 0.15, "fade_in": 0.01, "decay": 0.5}, Vector3(0, PI * 0.5, 0))
	B.impact(art, "glad_hit", CRIMSON, GOLD, 3.2, 0.17, 26, Vector3.UP * 1.0)
	var scar := B.open(c, at, 1.6, "Rift", 1)
	if scar:
		B.light(scar, _rift(), "GladRift", Vector3.UP * 0.06, Vector3.ONE, 1.5, {"sweep": 0.12, "soft": 0.5, "hot": B.hot(GOLD), "core": 0.4, "flick": 0.1, "add": 0.6}, {"delay": 0.17, "decay": 0.55})
		B.bits(scar, B.line_burst("glad_rubble", "rock", 18, -0.5, 4.8, 0.6, 2.5, 6.0, [STONE, STONE.darkened(0.2), STONE.lightened(0.1)], 0.3, 136, 1.0, 0.1), "GladRubble", Vector3.ZERO, 1.3, {"life": 1.1, "gravity": 18.0, "piece": 0.3, "floor_y": 0.06, "shrink": 0.8, "spin": 7.0, "hot": Color(1.0, 0.4, 0.2, 0.4)}, {"delay": 0.17})
		M.sparks(scar, "glad_embers", [CRIMSON, EMBER, GOLD], 24, 0.3, 2.0, 0.8, 3.0, 0.14, 0.2, 1.3, Vector3(0, 0, 1.5), -1.0, 137, 0.1, 1.0)
	return true
