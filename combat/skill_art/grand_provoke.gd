extends RefCounted
## Defender Lv.72 "Grand Provoke": the defender bangs the shield and dares the whole field.
## Wind-up: the shield flares, a war crest of flame-orange light rises over the defender's
## head and the ground sigil glows. Release: the crest blazes, a roar of three shock rings
## rolls out to the edge of the area while rings of chevrons sweep INWARD from the edge (every
## foe is pulled to the defender), embers burst, and a bold "!" pops over each foe it caught.
## Flame orange, gold and ember red.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "grand_provoke"
const FLAME := Color("ff7a4a")
const GOLD := Color("ffcf5a")
const EMBER := Color("c8341e")
const CREAM := Color("fff0d0")


static func _crest() -> ArrayMesh:
	return M.solid("gp_crest", M.shield(Color("a8401e"), GOLD, CREAM), Vector3.ONE * 1.5)


## Sound-wave arcs thrown forward from the shield (level, radius 1, +Z ahead).
static func _roar() -> ArrayMesh:
	if M.has("gp_roar"):
		return M.get_mesh("gp_roar")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var rr := 0.45 + 0.27 * float(k)
		K.ribbon(st, M.arc(Vector3.ZERO, rr, -1.0, 1.0, 0.0, 0.0, 16), 0.09, M.a(FLAME, 1.0), 0.04 * float(k), 0.0, Vector3.UP, 1.0, 0.0, 1.0)
	return M.keep("gp_roar", K.finish(st, Vector3.ONE * 0.2, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, aim), visual)
	if r == null:
		return false
	G.solid(r, _crest(), "Crest", Vector3(0, 2.35, 0), Vector3.ONE * 0.95, time + 0.04, {"drop": -0.6, "flight": time * 0.8, "ease": 1.0, "rim_color": GOLD, "rim": 1.2, "glow_color": FLAME}, {"initial": 0.3, "grow_time": 0.7, "fade_in": 0.08, "decay": 0.98, "face_camera": true})
	G.flat(r, G.sigil("gp_sigil", FLAME, 3, 24, 8, 0.3), "Sigil", Vector3.UP * 0.05, Vector3.ONE * 2.2, time + 0.04, G.lit(FLAME, 0.55, 0.5), {"initial": 0.4, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95, "spin": 1.2})
	M.sparks(r, "gp_heat", [FLAME, GOLD], G.n(12), 0.3, 1.0, 0.6, 2.4, 0.1, 0.0, time + 0.04, Vector3.ZERO, -1.0, 721, 0.2, 1.2)
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.yaw(origin, who[1], G.facing(caster)) if who[1] != Vector3.INF else G.facing(caster)
	var radius := float(skill.get("radius", 8.0))
	var feet := Vector3(origin.x, 0.0, origin.z)
	var r := G.open(parent, feet, 1.5, "Skill_%s_roar" % ID, turn, caster)
	if r == null:
		return false
	# Chevrons sweep in from the edge to the defender (the pull), the roar rolls out.
	G.flat(r, G.chevrons("gp_chev", 28, FLAME, 0.07), "PullA", Vector3.UP * 0.07, Vector3.ONE * radius * 0.22, 0.8, G.lit(FLAME, 0.65, 0.5), {"initial": 4.6, "grow_time": 0.95, "fade_in": 0.06, "decay": 0.75})
	M.shock(r, "gp_ring", FLAME, radius * 1.05, 0.0, 0.5, 0.16)
	G.solid(r, _crest(), "Crest", Vector3(0, 2.35, 0), Vector3.ONE * 1.05, 0.7, {"rim_color": GOLD, "rim": 1.4, "glow_color": FLAME, "heat": 0.9}, {"initial": 1.25, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.6, "face_camera": true})
	G.flat(r, _roar(), "Roar", Vector3(0, 1.2, 0.3), Vector3.ONE * 2.6, 0.5, G.lit(FLAME, 0.7, 0.6), {"initial": 0.4, "grow_time": 0.6, "fade_in": 0.01, "decay": 0.5}, Vector3(-0.3, 0, 0))
	M.sparks(r, "gp_embers", [FLAME, GOLD, EMBER], G.n(22), 0.4, 1.2, 5.0, 3.5, 0.12, 0.0, 0.9, Vector3.ZERO, 5.0, 722, 0.3, 1.4)
	G.flat(r, G.chevrons("gp_chev", 28, FLAME, 0.07), "PullB", Vector3.UP * 0.07, Vector3.ONE * radius * 0.22, 0.8, G.lit(GOLD, 0.65, 0.5), {"delay": 0.18, "initial": 4.6, "grow_time": 0.95, "fade_in": 0.06, "decay": 0.75})
	G.done(r)
	if G.extras(2) > 0:
		var echo := G.open(parent, feet, 1.2, "Skill_%s_echo" % ID, turn, caster)
		if echo:
			M.shock(echo, "gp_ring_b", GOLD, radius * 0.8, 0.1, 0.5, 0.1)
			M.shock(echo, "gp_ring_c", EMBER, radius * 1.1, 0.2, 0.55, 0.08)
			M.flash(echo, "gp_flash", EMBER, 2.6, 0.0, 0.35)
			G.done(echo)
	# A "!" over each foe the challenge caught.
	var most := 6 if G.hero() else 0
	if most > 0 and G.extras(2) > 1:
		var spots := G.foes(parent, feet, radius, most)
		if not spots.is_empty():
			var marks := G.open(parent, feet, 1.3, "Skill_%s_marks" % ID, 0.0, caster)
			if marks:
				for i in spots.size():
					G.flat(marks, G.bang("gp_bang", FLAME), "Bang", marks.to_local(spots[i]) + Vector3.UP * 2.35, Vector3.ONE * 0.75, 1.2, G.lit(GOLD, 0.6, 0.5), {"delay": 0.08 + 0.04 * float(i), "initial": 0.2, "grow_time": 0.12, "fade_in": 0.02, "decay": 0.75, "face_camera": true})
				G.done(marks)
	return true


static func contact(_parent: Node3D, _skill: Dictionary, _at: Vector3, _crit: bool) -> void:
	pass
