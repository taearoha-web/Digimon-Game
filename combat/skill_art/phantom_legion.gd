extends RefCounted
## Assassin Lv.88 "Phantom Legion": an army of shadows throws in every direction. Wind-up:
## eight phantoms of the assassin rise out of the ground in a ring round the assassin, violet
## eyes lit, a ring of the legion's sigil under them. Release: every phantom throws at once:
## a ring of eight shadow daggers flies out to all eight sides, the real throws streak to the
## foes they were meant for (SkillTableau.flight, with each one's own flight time) and burst
## on them, and the phantoms come apart into smoke. Violet, lilac, steel and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "phantom_legion"
const VIOLET := Color("9a6bff")
const LILAC := Color("e4d6ff")
const PLUM := Color("3a1a6e")
const STEEL := Color("b8b4d8")
const INK := Color(0.05, 0.02, 0.08)
const RING := 1.8


static func _legion() -> ArrayMesh:
	return G.legion("pl_legion", 8, RING, INK, PLUM, VIOLET, false, 0.025)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, aim), visual)
	if r == null:
		return false
	G.solid(r, _legion(), "Legion", Vector3.ZERO, Vector3.ONE * 0.9, time + 0.04, {"drop": -2.0, "flight": time * 0.8, "ease": 1.0, "rim_color": VIOLET, "rim": 1.4, "glow_color": LILAC, "dim": 0.8}, {"fade_in": 0.05, "decay": 0.99})
	G.flat(r, G.sigil("pl_sigil", VIOLET, 2, 16, 8, 0.4), "Sigil", Vector3.UP * 0.05, Vector3.ONE * 2.4, time + 0.04, G.lit(VIOLET, 0.55, 0.5), {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.1, "decay": 0.97, "spin": 1.2})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.yaw(origin, who[1], G.facing(caster)) if who[1] != Vector3.INF else G.facing(caster)
	var reach := float(skill.get("range", 12.0))
	var feet := Vector3(origin.x, 0.0, origin.z)
	var r := G.open(parent, feet, 1.2, "Skill_%s_throw" % ID, turn, caster)
	if r == null:
		return false
	G.solid(r, _legion(), "Legion", Vector3.ZERO, Vector3.ONE * 0.9, 0.5, {"rim_color": VIOLET, "rim": 1.5, "glow_color": LILAC, "dim": 0.8}, {"fade_in": 0.01, "decay": 0.3})
	G.bits(r, K.burst("pl_smoke", "puff", G.n(18), RING * 0.8, RING * 1.1, 1.0, 1.4, [Color(0.1, 0.04, 0.16), Color(0.18, 0.08, 0.3), INK], 0.6, 0.15, 882, 0.3, 1.4), "Smoke", Vector3.ZERO, 1.1, {"life": 1.0, "gravity": -1.0, "drag": 1.8, "piece": 0.6, "swell": 1.7, "alpha": 0.6, "shrink": 0.4, "spin": 2.0}, {"delay": 0.15, "decay": 0.85})
	M.shock(r, "pl_ring", VIOLET, 3.2, 0.0, 0.4, 0.14)
	G.flat(r, G.rays("pl_streaks", 8, VIOLET, 0.05, 0.2, 881), "Streaks", Vector3.UP * 1.1, Vector3.ONE * reach * 0.7, 0.45, G.lit(LILAC, 0.6, 0.7, {"sweep": 0.2, "tail": 1.4}), {"fade_in": 0.01, "decay": 0.6})
	G.done(r)
	# The volley: a dagger flies out to each of the eight sides (four to a root).
	for half in G.extras(2):
		var volley := G.open(parent, feet, 0.6, "Skill_%s_volley%d" % [ID, half], turn, caster, 4)
		if volley == null:
			break
		for k in 4:
			var ang := TAU * float(half * 4 + k) / 8.0
			var dir := Vector3(sin(ang), 0, cos(ang))
			var end := dir * reach * 0.7 + Vector3.UP * 1.15
			G.solid(volley, G.thrown("pl_dagger", STEEL, INK, LILAC), "Dagger", end, Vector3.ONE * 0.8, 0.5, {"from": Vector3(0, 0, -reach * 0.62 / 0.8), "flight": 0.38, "ease": 1.0, "rim_color": VIOLET, "rim": 1.4, "glow_color": LILAC}, {"fade_in": 0.01, "decay": 0.75}, Vector3(0, ang, 0))
		G.done(volley)
	return true


## One real throw to a foe: a shadow dagger with its streak, on the throw's own clock.
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, _size: float) -> Node3D:
	var d := to - from
	if d.length_squared() < 0.01:
		return null
	var turn := atan2(d.x, d.z)
	var pitch := -atan2(d.y, Vector2(d.x, d.z).length())
	var r := G.carry(parent, skill, G.thrown("pl_dagger", STEEL, INK, LILAC), from, to, 0.0, seconds, 0.8, [VIOLET, LILAC], "throw", {"rim": 1.4}, 0.0, Vector3(pitch, turn, 0), 0.32, 0.5)
	if r == null:
		return null
	G.flat(r, G._hit_cross(), "Burst", Vector3.ZERO, Vector3.ONE * 0.9, 0.3, G.lit(LILAC, 0.7), {"delay": seconds, "fade_in": 0.01, "decay": 0.4, "face_camera": true})
	M.sparks(r, "pl_hit", [VIOLET, LILAC], G.n(10), 0.05, 0.25, 3.0, 2.0, 0.09, seconds, 0.4, Vector3.ZERO, 6.0, 883, -0.2, 0.2)
	G.done(r)
	return r


## The hits land with the throws (drawn there).
static func contact(_parent: Node3D, _skill: Dictionary, _at: Vector3, _crit: bool) -> void:
	pass
