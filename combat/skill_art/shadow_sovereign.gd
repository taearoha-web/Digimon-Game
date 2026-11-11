extends RefCounted
## Assassin Lv.96 "Shadow Sovereign" (ATK, crit and dodge up): the king of shadows stands up
## behind the assassin. Wind-up: the shadows of the ground pool round the feet and a crown
## of violet sparks gathers over the head. Release: a towering shadow sovereign rises behind
## the assassin, violet-eyed, a crown of violet flame on its brow, while a ring of eight
## shadow daggers turns round the assassin like a crown, the throne sigil spreads on the
## ground, a cloak of dark mist swirls up and violet motes rise. Royal violet, lilac, plum
## and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "shadow_sovereign"
const VIOLET := Color("9a6bff")
const LILAC := Color("e4d6ff")
const PLUM := Color("3a1a6e")
const STEEL := Color("b8b4d8")
const INK := Color(0.05, 0.02, 0.08)
const BEHIND := 1.9


## The sovereign: the cloaked figure standing tall (no lunge), a crown of flame on its head.
static func _sovereign() -> ArrayMesh:
	if M.has("ss_sovereign"):
		return M.get_mesh("ss_sovereign")
	var p := K.Part.new()
	p.ink(INK, 0.2)
	p.tube(Vector3(0, 0.0, 0), Vector3(0, 1.0, 0), 0.55, 0.28, 7)
	p.tube(Vector3(0, 1.0, 0), Vector3(0, 1.5, 0.05), 0.28, 0.3, 7)
	p.ink(PLUM, 0.25)
	for s in [-1.0, 1.0]:
		p.tube(Vector3(s * 0.28, 1.45, 0.05), Vector3(s * 0.62, 1.05, 0.2), 0.12, 0.09, 5)
		p.tube(Vector3(s * 0.62, 1.05, 0.2), Vector3(s * 0.5, 0.7, 0.42), 0.09, 0.07, 5)
		p.tube(Vector3(s * 0.32, 1.5, -0.05), Vector3(s * 0.75, 0.2, -0.35), 0.08, 0.0, 3, 0.3)
	p.ink(INK, 0.2)
	p.ball(Vector3(0, 1.7, 0.08), Vector3(0.2, 0.22, 0.2), 7, 4)
	p.tube(Vector3(0, 1.78, 0.02), Vector3(0, 2.0, -0.2), 0.16, 0.0, 5)
	p.ink(VIOLET, 0.0, 1.0)
	for x in [-0.07, 0.07]:
		p.gem(Vector3(x, 1.72, 0.27), Vector3(0.04, 0.022, 0.02))
	p.ink(VIOLET, 0.5, 0.8)
	p.add(M.crown(VIOLET, LILAC, 5), Transform3D(Basis.IDENTITY.scaled(Vector3(0.2, 0.26, 0.2)), Vector3(0, 1.86, 0.06)))
	var st := K.begin()
	K.stamp(st, p)
	return M.keep("ss_sovereign", K.finish(st, Vector3(1, 4, 1)))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var caster := G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.facing(caster), visual)
	if r == null:
		return false
	G.flat(r, K.glow_disc("ss_pool", Color(0.05, 0.02, 0.1, 0.75)), "Pool", Vector3.UP * 0.04, Vector3.ONE * 2.6, time + 0.04, {"soft": 0.6, "add": 0.0}, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.98})
	G.bits(r, G.inward("ss_crown", "ember", G.n(16), 0.8, 1.4, [VIOLET, LILAC], 0.1, 3.5, 1.2, 0.1, 961, 2.0, 2.6), "Crown", Vector3.ZERO, time + 0.04, {"life": time, "gravity": 0.0, "drag": 3.5, "piece": 0.1, "add": 0.85, "shrink": 0.6, "spin": 3.0}, {"decay": 0.95})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.facing(caster)
	var label := "Skill_%s_throne" % ID
	var r := G.aura(parent, caster, 2.3, label, turn) if caster else G.open(parent, origin, 2.3, label, turn, null)
	if r == null:
		return false
	var behind := K.away(r) * BEHIND
	var fit := G.sky_fit(r, behind, 4.2)
	G.solid(r, _sovereign(), "Sovereign", behind, Vector3.ONE * 2.1 * fit, 2.1, {"drop": -1.4, "flight": 0.35, "ease": 1.0, "rim_color": VIOLET, "rim": 1.6, "glow_color": LILAC, "dim": 0.75}, {"fade_in": 0.03, "decay": 0.78}, Vector3(0, K.facing(r), 0))
	G.solid(r, G.dagger_ring("ss_daggers", 8, STEEL, INK, LILAC, 0.3), "DaggerCrown", Vector3.UP * 1.25, Vector3.ONE * 1.25, 2.0, {"rim_color": VIOLET, "rim": 1.3, "glow_color": LILAC}, {"initial": 2.0, "grow_time": 0.25, "fade_in": 0.03, "decay": 0.8, "spin": 3.2})
	G.flat(r, G.sigil("ss_throne", VIOLET, 3, 32, 8, 0.45), "Throne", Vector3.UP * 0.05, Vector3.ONE * 2.8, 2.2, G.lit(VIOLET, 0.5, 0.5), {"initial": 0.5, "grow_time": 0.25, "fade_in": 0.03, "decay": 0.8, "spin": -0.4})
	G.motes(r, "ss_motes", [VIOLET, LILAC], G.n(18), 0.3, 1.6, 2.6, 0.12, 0.15, 1.8, 962)
	M.shock(r, "ss_ring", VIOLET, 3.0, 0.0, 0.5, 0.16)
	G.flat(r, G.curtain("ss_mist", Color(0.12, 0.04, 0.22, 0.7), Color(0.12, 0.04, 0.22, 0.0), 1.0, 32), "Mist", Vector3.ZERO, Vector3(1.0, 2.2, 1.0), 1.1, {"soft": 0.8, "add": 0.2, "flow": 3.0}, {"initial": 1.6, "grow_time": 0.3, "fade_in": 0.03, "decay": 0.6, "spin": 2.4})
	G.done(r)
	if G.extras(1) > 0:
		var halo := G.aura(parent, caster, 2.0, "Skill_%s_flame" % ID, turn) if caster else null
		if halo:
			var crown := behind + Vector3.UP * 4.15 * fit
			M.pillar(halo, "ss_flame", VIOLET, 1.4 * fit, 1.6 * fit, 0.3, 1.5, crown)
			M.flash(halo, "ss_dark", PLUM, 2.4, 0.0, 0.6)
			M.sparks(halo, "ss_embers", [VIOLET, LILAC], G.n(14), 0.1, 0.5 * fit, 0.6, 2.2, 0.1, 0.3, 1.4, crown, -0.6, 963, 0.0, 0.4)
			G.done(halo)
	return true
