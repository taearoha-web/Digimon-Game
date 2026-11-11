extends RefCounted
## Defender Lv.76 "Unbreakable" (DEF up, heal, reflect): the defender is set in diamond.
## Wind-up: golden facets glint in a wide ring round the defender and are drawn in. Release:
## a lattice of golden hexagons builds itself into a dome from the ground up (the defender
## stays in sight through it), clangs with a ring of light, then thorn-like crystal shards
## burst outward off it (the reflect) while warm motes rise (the heal) and the stance sigil
## settles under the feet. Gold, amber and honey.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "unbreakable"
const GOLD := Color("ffd27a")
const AMBER := Color("f0a030")
const HONEY := Color("fff1c4")
const DEEP := Color("8a5a10")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var caster := G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.facing(caster), visual)
	if r == null:
		return false
	G.bits(r, G.inward("ub_facets", "shard", G.n(20), 2.4, 3.4, [GOLD, AMBER, HONEY], 0.22, 3.2, 0.25, 0.1, 761, 0.3, 2.0), "Facets", Vector3.ZERO, time + 0.04, {"life": time, "gravity": 0.0, "drag": 3.2, "piece": 0.22, "add": 0.5, "shrink": 0.7, "spin": 5.0}, {"decay": 0.95})
	G.flat(r, G.sigil("ub_sigil", GOLD, 2, 18, 6, 0.25), "Sigil", Vector3.UP * 0.05, Vector3.ONE * 1.8, time + 0.04, G.lit(GOLD, 0.5, 0.5), {"initial": 1.5, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95, "spin": -1.0})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var r := G.aura(parent, caster, 1.9, "Skill_%s_shell" % ID, G.facing(caster)) if caster else G.open(parent, origin, 1.9, "Skill_%s_shell" % ID, 0.0, null)
	if r == null:
		return false
	# The dome builds from the ground up, holds, and is gone.
	G.flat(r, G.hex_dome("ub_dome", GOLD, 5, 0.3), "Dome", Vector3.ZERO, Vector3(1.55, 1.85, 1.55), 1.4, G.lit(GOLD, 0.6, 0.6, {"flick": 0.06}), {"initial": 1.3, "grow_time": 0.3, "fade_in": 0.04, "decay": 0.72})
	M.shock(r, "ub_clang", GOLD, 2.4, 0.3, 0.42, 0.18, 0.12)
	# The reflect: crystal thorns thrown off the shell.
	G.bits(r, K.burst("ub_thorns", "shard", G.n(22), 1.3, 1.6, 6.0, 2.5, [GOLD, HONEY, AMBER], 0.3, 0.05, 762, 0.4, 2.0), "Thorns", Vector3.ZERO, 1.1, {"life": 0.8, "gravity": 4.0, "drag": 1.6, "piece": 0.3, "add": 0.45, "shrink": 0.55, "spin": 9.0, "hot": Color(1.0, 0.9, 0.5, 0.6)}, {"delay": 0.32, "decay": 0.85})
	G.motes(r, "ub_heal", [GOLD, HONEY], G.n(16), 0.3, 1.2, 2.6, 0.12, 0.25, 1.4, 763)
	G.flat(r, G.sigil("ub_stance", AMBER, 3, 24, 6, 0.35), "Stance", Vector3.UP * 0.05, Vector3.ONE * 1.9, 1.85, G.lit(GOLD, 0.5, 0.5), {"initial": 0.6, "grow_time": 0.2, "fade_in": 0.04, "decay": 0.8, "spin": 0.5})
	G.flat(r, G.curtain("ub_glow", M.a(GOLD, 0.5), M.a(HONEY, 0.0), 1.0, 40), "Glow", Vector3.ZERO, Vector3(1.0, 2.2, 1.0), 0.9, G.lit(GOLD, 0.6, 1.2), {"delay": 0.28, "initial": 0.7, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.5})
	G.done(r)
	if G.extras(1) > 0:
		var shell := G.aura(parent, caster, 1.6, "Skill_%s_facets" % ID, 0.0) if caster else null
		if shell:
			M.flash(shell, "ub_flash", AMBER, 2.2, 0.28, 0.4)
			M.sparks(shell, "ub_glints", [HONEY, GOLD], G.n(14), 0.8, 1.6, 0.6, 1.4, 0.1, 0.3, 1.1, Vector3.ZERO, -0.8, 764, 0.4, 2.2)
			M.shock(shell, "ub_ring_b", HONEY, 3.2, 0.36, 0.5, 0.08, 0.1)
			G.done(shell)
	return true
