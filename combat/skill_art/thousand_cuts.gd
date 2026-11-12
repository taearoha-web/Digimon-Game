extends RefCounted
## Assassin Lv.60 "Thousand Cuts": a storm of shadow blades round the assassin. Wind-up: the
## assassin sinks into a pool of shadow, violet motes are drawn in and a ring of blade glints
## turns round the body. Release: a whirl of crescents spins round the assassin while cut
## after cut flashes all over the area (two storms of violet slashes, each lit on its own
## moment), slash scars are left across the ground, dark petals and violet sparks scatter.
## Violet, lilac and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "thousand_cuts"
const VIOLET := Color("9a6bff")
const LILAC := Color("e4d6ff")
const PLUM := Color("3a1a6e")
const INK := Color(0.05, 0.02, 0.08)


## A whirl of three crescents round the assassin (level, radius 1).
static func _whirl() -> ArrayMesh:
	if M.has("tc_whirl"):
		return M.get_mesh("tc_whirl")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a0 := TAU * float(k) / 3.0
		G.crescent(st, Vector3(0, 0.9 + 0.2 * float(k), 0), Vector3.RIGHT, Vector3.BACK, 1.0 - 0.1 * float(k), a0, a0 + 2.2, 0.32, M.a(VIOLET, 0.95), M.a(LILAC, 0.9), M.a(INK, 1.0))
	return M.keep("tc_whirl", K.finish(st, Vector3.ONE * 0.4, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, aim), visual)
	if r == null:
		return false
	G.flat(r, K.glow_disc("tc_pool", Color(0.06, 0.02, 0.1, 0.7)), "Pool", Vector3.UP * 0.04, Vector3.ONE * 1.9, time + 0.04, {"soft": 0.6, "add": 0.0}, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.1, "decay": 0.97})
	G.bits(r, G.inward("tc_gather", "ember", G.n(18), 1.6, 3.0, [VIOLET, LILAC], 0.11, 3.5, 0.8, 0.12, 601, 0.3, 1.8), "Gather", Vector3.ZERO, time + 0.04, {"life": time, "gravity": 0.0, "drag": 3.5, "piece": 0.11, "add": 0.85, "shrink": 0.6, "spin": 4.0}, {"decay": 0.95})
	G.flat(r, G.glints("tc_glints", LILAC, 6), "Glints", Vector3.UP * 1.0, Vector3.ONE * 1.1, time + 0.04, G.lit(LILAC, 0.7, 0.5), {"initial": 1.6, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95, "spin": 9.0})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.facing(caster)
	var radius := float(skill.get("radius", 6.2))
	var feet := Vector3(origin.x, 0.0, origin.z)
	var r := G.open(parent, feet, 1.3, "Skill_%s_storm" % ID, turn, caster)
	if r == null:
		return false
	var s := radius / 6.2
	G.flat(r, G.cut_storm("tc_storm2", 26, 0.8, 5.2, 0.42, M.a(VIOLET, 0.95), M.a(VIOLET.lightened(0.25), 0.9), M.a(INK, 1.0), 602, 0.5, 2.0, 0.6), "Storm", Vector3.ZERO, Vector3.ONE * s, 0.95, G.lit(VIOLET, 0.65, 0.6, {"sweep": 0.08, "tail": 5.0}), {"fade_in": 0.01, "decay": 0.85})
	G.flat(r, _whirl(), "Whirl", Vector3.ZERO, Vector3.ONE * 1.7, 0.55, G.lit(LILAC, 0.65, 0.7), {"initial": 0.6, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.6, "spin": -14.0})
	G.flat(r, G.rays("tc_scars", 10, PLUM.lightened(0.3), 0.025, 0.3, 603), "Scars", Vector3.UP * 0.05, Vector3.ONE * radius * 0.85, 1.2, G.lit(PLUM.lightened(0.3), 0.35, 0.6, {"sweep": 0.2}), {"fade_in": 0.02, "decay": 0.7})
	G.bits(r, K.burst("tc_petals", "feather", G.n(24), 0.3, 2.5, 3.5, 3.0, [PLUM, VIOLET, INK, LILAC], 0.3, 0.3, 604, 0.6, 1.8), "Petals", Vector3.ZERO, 1.25, {"life": 1.1, "gravity": 2.5, "drag": 1.4, "piece": 0.3, "sway": 0.35, "spin": 6.0, "floor_y": 0.06, "shrink": 0.8}, {"decay": 0.85})
	M.shock(r, "tc_ring", VIOLET, radius * 1.02, 0.0, 0.45, 0.12)
	M.sparks(r, "tc_sparks", [VIOLET, LILAC], G.n(18), 0.5, radius * 0.7, 3.0, 3.0, 0.1, 0.05, 0.8, Vector3.ZERO, 5.0, 605, 0.4, 1.6)
	G.done(r)
	if G.extras(1) > 0:
		var echo := G.open(parent, feet, 1.1, "Skill_%s_echo" % ID, turn + 1.3, caster)
		if echo:
			G.flat(echo, G.cut_storm("tc_storm_b2", 20, 1.5, 5.8, 0.4, M.a(PLUM.lightened(0.4), 0.95), M.a(VIOLET, 0.9), M.a(INK, 1.0), 606, 0.4, 1.7, 0.5), "StormB", Vector3.ZERO, Vector3.ONE * s, 0.95, G.lit(VIOLET, 0.65, 0.6, {"sweep": 0.08, "tail": 5.0}), {"delay": 0.12, "fade_in": 0.01, "decay": 0.85})
			G.flat(echo, K.glow_disc("tc_shade", Color(0.06, 0.02, 0.1, 0.5)), "Shade", Vector3.UP * 0.04, Vector3.ONE * radius * 0.7, 1.0, {"soft": 0.6, "add": 0.0}, {"initial": 0.3, "grow_time": 0.3, "fade_in": 0.05, "decay": 0.7})
			G.done(echo)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [VIOLET, LILAC], crit, true)
