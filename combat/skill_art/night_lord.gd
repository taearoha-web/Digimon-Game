extends RefCounted
## Assassin Lv.76 "Night Lord" (ATK, crit and speed up, heal): night falls round the assassin.
## Wind-up: the light drains into a spreading pool of shadow under the assassin and violet
## motes sink into it. Release: a crescent moon rises behind the assassin in a violet glow,
## a flock of shadow bats bursts up out of the pool and wheels away, a ring of violet light
## and a cloak of dark mist turn round the body, two blade glints circle it and pale motes
## rise (the heal). Midnight violet, lilac, a cold moon and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "night_lord"
const VIOLET := Color("9a6bff")
const LILAC := Color("e4d6ff")
const MOON := Color("b48cff")
const PLUM := Color("3a1a6e")
const INK := Color(0.05, 0.02, 0.08)
const BEHIND := 1.4


## A bat: two scalloped wings and a small body, facing +Z.
static func _bat_shape(color: Color) -> K.Part:
	var p := K.Part.new()
	p.ink(color)
	for s in [-1.0, 1.0]:
		p.tri(Vector3(0, 0.05, 0), Vector3(s * 0.5, 0.2, 0), Vector3(s * 0.32, -0.06, 0))
		p.tri(Vector3(0, 0.05, 0), Vector3(s * 0.32, -0.06, 0), Vector3(s * 0.16, -0.1, 0))
		p.tri(Vector3(s * 0.5, 0.2, 0), Vector3(s * 0.46, -0.04, 0), Vector3(s * 0.32, -0.06, 0))
	p.ink(color.lightened(0.15))
	p.gem(Vector3(0, 0.0, 0.01), Vector3(0.06, 0.1, 0.05))
	return p


## A flock of bats thrown up and out (one BITS mesh).
static func _bats() -> ArrayMesh:
	if M.has("nl_bats"):
		return M.get_mesh("nl_bats")
	var rng := RandomNumberGenerator.new()
	rng.seed = 761
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 18:
		var a := rng.randf() * TAU
		var dir := Vector3(sin(a), 0, cos(a))
		var origin := dir * rng.randf_range(0.2, 0.8) + Vector3.UP * rng.randf_range(0.2, 0.8)
		var vel := dir * rng.randf_range(2.0, 4.0) + Vector3.UP * rng.randf_range(3.0, 6.0)
		var color := INK if i % 3 else PLUM
		var size := rng.randf_range(0.7, 1.0) * 0.9
		var basis := Basis(Vector3.UP, a).scaled(Vector3.ONE * size)
		K.bit(st, _bat_shape(color), origin, vel, rng.randf() * 0.2, 0.9, basis)
	return M.keep("nl_bats", K.finish(st, Vector3.ONE * 8.0, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var caster := G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.facing(caster), visual)
	if r == null:
		return false
	G.flat(r, K.glow_disc("nl_pool", Color(0.05, 0.02, 0.1, 0.75)), "Pool", Vector3.UP * 0.04, Vector3.ONE * 2.2, time + 0.04, {"soft": 0.6, "add": 0.0}, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.98})
	G.bits(r, G.inward("nl_sink", "ember", G.n(16), 1.2, 2.4, [VIOLET, LILAC], 0.1, 3.0, 0.6, 0.12, 762, 0.8, 2.2), "Sink", Vector3.ZERO, time + 0.04, {"life": time, "gravity": 2.0, "drag": 3.0, "piece": 0.1, "add": 0.85, "shrink": 0.6, "spin": 3.0}, {"decay": 0.95})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.facing(caster)
	var label := "Skill_%s_night" % ID
	var r := G.aura(parent, caster, 2.0, label, turn) if caster else G.open(parent, origin, 2.0, label, turn, null)
	if r == null:
		return false
	var behind := K.away(r) * BEHIND
	var high := G.sky_height(r, behind, 3.0)
	G.flat(r, G.moon("nl_moon", MOON, VIOLET, 0.62), "Moon", behind + Vector3.UP * high, Vector3.ONE * 1.25, 1.9, {"soft": 0.6, "add": 0.55, "hot": M.a(LILAC, 0.5), "core": 0.6}, {"travel": Vector3.UP * 0.5, "initial": 0.5, "grow_time": 0.3, "fade_in": 0.05, "decay": 0.8}, Vector3(G.TILT_BACK, K.facing(r), -0.35))
	G.bits(r, _bats(), "Bats", Vector3.ZERO, 1.5, {"life": 1.3, "gravity": -0.5, "drag": 1.0, "piece": 0.9, "sway": 0.5, "spin": 1.5, "shrink": 0.8}, {"decay": 0.85})
	G.flat(r, K.glow_disc("nl_pool", Color(0.05, 0.02, 0.1, 0.75)), "Pool", Vector3.UP * 0.04, Vector3.ONE * 2.6, 1.6, {"soft": 0.6, "add": 0.0}, {"initial": 0.85, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.7})
	G.flat(r, G.glints("nl_glints", LILAC, 2), "Glints", Vector3.UP * 1.1, Vector3.ONE * 1.0, 1.4, G.lit(LILAC, 0.75, 0.6), {"initial": 0.6, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.75, "spin": 7.0})
	G.motes(r, "nl_heal", [LILAC, MOON, VIOLET], G.n(14), 0.3, 1.0, 2.4, 0.11, 0.15, 1.4, 763)
	M.shock(r, "nl_ring", VIOLET, 2.6, 0.0, 0.45, 0.14)
	G.done(r)
	if G.extras(1) > 0:
		var cloak := G.aura(parent, caster, 1.6, "Skill_%s_cloak" % ID, turn) if caster else null
		if cloak:
			G.flat(cloak, G.curtain("nl_mist", Color(0.12, 0.04, 0.22, 0.7), Color(0.12, 0.04, 0.22, 0.0), 1.0, 32), "Mist", Vector3.ZERO, Vector3(0.9, 2.0, 0.9), 1.2, {"soft": 0.8, "add": 0.2, "flow": 3.0}, {"initial": 1.5, "grow_time": 0.3, "fade_in": 0.03, "decay": 0.6, "spin": 2.0})
			G.flat(cloak, G.orbits("nl_orbit", 1, VIOLET, 0.04, 0.3), "Orbit", Vector3.UP * 1.0, Vector3.ONE * 1.2, 1.4, G.lit(VIOLET, 0.6, 0.5), {"initial": 1.6, "grow_time": 0.3, "fade_in": 0.03, "decay": 0.75, "spin": -3.0})
			G.done(cloak)
	return true
