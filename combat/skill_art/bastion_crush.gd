extends RefCounted
## Defender Lv.64 "Bastion Crush": a bastion's tower shield comes down on one foe like a
## press. Wind-up: the tower shield of coral light hangs face-down over the target, its
## shadow spreading on the ground and pressure chevrons closing in round it. Release: the
## shield slams down flat onto the foe and is gone in a breath (the foe stays in sight), the
## ground caves in a ring, dust squirts out sideways, cracks run out, coral sparks fly, and
## the shield's outline is left pressed into the ground. Coral, brick and warm stone.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "bastion_crush"
const CORAL := Color("ff8a5a")
const BRICK := Color("b8452a")
const PEACH := Color("ffd7b8")
const STEEL := Color("6a5a64")
const DUST := Color("c4a58a")
const HIGH := 3.4


static func _tower() -> ArrayMesh:
	return M.solid("bc_tower", G.tower(STEEL, CORAL, PEACH), Vector3(1, 5, 1))


## The shield's outline pressed into the ground (level, 1 tall along +Z, foot at -Z).
static func _imprint() -> ArrayMesh:
	if M.has("bc_imprint"):
		return M.get_mesh("bc_imprint")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	for i in 9:
		var a := lerpf(-PI * 0.5, PI * 0.5, float(i) / 8.0)
		pts.append(Vector3(sin(a) * 0.36, 0, 0.36 + cos(a) * 0.12))
	pts.append(Vector3(0.36, 0, -0.44))
	pts.append(Vector3(0.24, 0, -0.5))
	pts.append(Vector3(-0.24, 0, -0.5))
	pts.append(Vector3(-0.36, 0, -0.44))
	pts.append(pts[0])
	K.disc(st, 0.55, M.a(Color(0.12, 0.04, 0.02), 0.55), -0.005, 28, 0.0, Vector3.UP, Vector3.ZERO, M.a(Color(0.12, 0.04, 0.02), 0.0), 0.0, true)
	K.ribbon(st, pts, 0.09, M.a(CORAL, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	K.ribbon(st, PackedVector3Array([Vector3(0, 0, -0.4), Vector3(0, 0, 0.38)]), 0.03, M.a(CORAL, 0.8), 0.0, 0.0, Vector3.UP, 0.0)
	K.ribbon(st, PackedVector3Array([Vector3(-0.28, 0, 0.12), Vector3(0.28, 0, 0.12)]), 0.03, M.a(CORAL, 0.8), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("bc_imprint", K.finish(st, Vector3.ONE * 0.2, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var turn := G.yaw(origin, aim)
	var r := G.windup(parent, Vector3(aim.x, 0.0, aim.z), time + 0.06, "Skill_%s_windup" % ID, turn, visual)
	if r == null:
		return false
	# Face-down over the foe, lifting a little higher before it falls.
	G.solid(r, _tower(), "Press", Vector3(0, HIGH, 0.9), Vector3.ONE * 2.0, time + 0.04, {"drop": -0.5, "flight": time, "ease": 1.0, "rim_color": PEACH, "rim": 1.1, "glow_color": CORAL, "dim": 0.9}, {"initial": 0.6, "grow_time": 0.5, "fade_in": 0.1, "decay": 0.98}, Vector3(-PI * 0.5, 0, 0))
	G.flat(r, K.glow_disc("bc_shadow", Color(0.12, 0.03, 0.0, 0.55)), "Shadow", Vector3.UP * 0.04, Vector3(1.0, 1, 1.3), time + 0.04, {"soft": 0.8, "add": 0.0}, {"initial": 0.4, "grow_time": 1.0, "fade_in": 0.1, "decay": 0.97})
	G.flat(r, G.chevrons("bc_chevrons", 8, CORAL, 0.16), "Chevrons", Vector3.UP * 0.06, Vector3.ONE * 1.2, time + 0.04, G.lit(CORAL, 0.6, 0.5), {"initial": 2.2, "grow_time": 0.95, "fade_in": 0.1, "decay": 0.95, "spin": 0.6})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var spot := Vector3(center.x, 0.0, center.z)
	var turn := G.yaw(origin, spot, G.facing(caster))
	var r := G.open(parent, spot, 1.4, "Skill_%s_crush" % ID, turn, caster)
	if r == null:
		return false
	# The press comes down flat and is gone in a breath.
	G.solid(r, _tower(), "Slam", Vector3(0, 0.35, 1.1), Vector3.ONE * 2.4, 0.34, {"drop": (HIGH - 0.35) / 2.4, "flight": 0.06, "heat": 0.9, "rim_color": PEACH, "rim": 0.9, "glow_color": CORAL}, {"fade_in": 0.01, "decay": 0.35}, Vector3(-PI * 0.5, 0, 0))
	M.shock(r, "bc_ring", CORAL, 3.0, 0.03, 0.42, 0.26)
	M.pillar(r, "bc_press", CORAL, 0.9, 3.6, 0.0, 0.26)
	M.cracks(r, "bc_cracks", CORAL, 2.6, 0.03, 1.1, 7, 641, 0.06)
	# Dust squirted out sideways from under the press.
	G.bits(r, K.burst("bc_squirt", "puff", G.n(16), 0.6, 1.2, 6.0, 0.6, [DUST, DUST.lightened(0.1), DUST.darkened(0.1)], 0.7, 0.04, 642, 0.05, 0.25), "Squirt", Vector3.ZERO, 1.0, {"life": 0.9, "gravity": -0.3, "drag": 3.0, "piece": 0.7, "swell": 1.8, "alpha": 0.6, "shrink": 0.4, "spin": 1.0}, {"delay": 0.03, "decay": 0.85})
	M.sparks(r, "bc_sparks", [CORAL, PEACH, BRICK], G.n(18), 0.2, 0.8, 4.0, 3.5, 0.11, 0.03, 0.7, Vector3.ZERO, 7.0, 643, 0.1, 0.5)
	G.done(r)
	if G.extras(1) > 0:
		var ring := G.open(parent, spot, 1.45, "Skill_%s_cave" % ID, turn, caster)
		if ring:
			G.flat(ring, _imprint(), "Imprint", Vector3.UP * 0.05, Vector3.ONE * 2.4, 1.35, G.lit(CORAL, 0.6, 0.4, {"flick": 0.08}), {"delay": 0.05, "fade_in": 0.04, "decay": 0.7})
			M.flash(ring, "bc_flash", BRICK, 1.8, 0.02, 0.32)
			M.shock(ring, "bc_ring_b", PEACH, 3.6, 0.1, 0.45, 0.1)
			M.rubble(ring, "bc_rubble", [STEEL.darkened(0.3), Color("6b5a4c"), Color("8a7a68")], G.n(14), 0.4, 1.4, 3.0, 4.5, 0.22, 0.03, 0.9, Vector3.ZERO, 644)
			G.done(ring)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [CORAL, PEACH], crit)
