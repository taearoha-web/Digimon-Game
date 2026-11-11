extends RefCounted
## Assassin Lv.84 "Abyss Vortex" (slows, tears): the abyss opens round the assassin and drags
## everything in. Wind-up: the ground under the assassin darkens and the first spiral arms
## of violet start to turn. Release: a whirlpool of the abyss spreads over the whole area,
## its spiral arms turning in, a second set counter-turning inside it; shadow and violet
## shreds are sucked in from the edge to the heart, a column of darkness rises out of the
## centre, cuts flicker inside the whirl and a ring of violet rolls out. Abyss violet, plum,
## lilac and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "abyss_vortex"
const VIOLET := Color("9a6bff")
const LILAC := Color("e4d6ff")
const PLUM := Color("3a1a6e")
const DEEP := Color(0.08, 0.03, 0.16)
const INK := Color(0.05, 0.02, 0.08)


## Spiral arms (radius 1, level): [param arms] arms curling from the rim into the heart.
static func _spiral(key: String, arms: int, color: Color, edge: Color, width: float, turns := 1.1) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in arms:
		var a0 := TAU * float(k) / float(arms)
		var pts := PackedVector3Array()
		for i in 29:
			var t := float(i) / 28.0
			var rr := lerpf(1.0, 0.08, t)
			var a := a0 + t * TAU * turns
			pts.append(Vector3(sin(a) * rr, 0.0, cos(a) * rr))
		K.ribbon(st, pts, width, M.a(color, 1.0), 0.0, 0.0, Vector3.UP, 0.85, 0.0, 1.0, M.a(edge, 1.0))
	return M.keep(key, K.finish(st, Vector3.ONE * 0.2, false))


## The column of darkness: a dark beam (crossed planes) with a violet rim.
static func _column() -> ArrayMesh:
	if M.has("av_column"):
		return M.get_mesh("av_column")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.beam(st, Vector3.ZERO, 1.0, 1.0, Color(0.06, 0.02, 0.12, 0.9), 3, 0.0, 0.0, 0.35)
	K.beam(st, Vector3.ZERO, 1.0, 1.25, M.a(VIOLET, 0.5), 3, 0.0, 0.0, 0.5)
	return M.keep("av_column", K.finish(st, Vector3.ONE * 0.4, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, aim), visual)
	if r == null:
		return false
	G.flat(r, K.glow_disc("av_dark", Color(0.06, 0.02, 0.12, 0.75)), "Dark", Vector3.UP * 0.035, Vector3.ONE * 2.4, time + 0.04, {"soft": 0.6, "add": 0.0}, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.98})
	G.flat(r, _spiral("av_arms_small", 3, VIOLET, PLUM, 0.12), "Arms", Vector3.UP * 0.05, Vector3.ONE * 2.2, time + 0.04, G.lit(VIOLET, 0.6, 0.5), {"initial": 0.4, "grow_time": 0.9, "fade_in": 0.15, "decay": 0.97, "spin": 4.0})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.facing(caster)
	var radius := float(skill.get("radius", 7.5))
	var feet := Vector3(origin.x, 0.0, origin.z)
	var r := G.open(parent, feet, 1.9, "Skill_%s_whirl" % ID, turn, caster)
	if r == null:
		return false
	G.flat(r, _spiral("av_arms", 5, VIOLET, PLUM, 0.08), "Arms", Vector3.UP * 0.05, Vector3.ONE * radius, 1.75, G.lit(VIOLET, 0.6, 0.5, {"flow": 3.0}), {"initial": 0.25, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.75, "spin": 2.6})
	G.bits(r, G.inward("av_drag", "shard", G.n(30), radius * 0.6, radius, [PLUM, VIOLET, INK, LILAC], 0.26, 1.6, 0.8, 0.5, 841, 0.1, 1.2), "Drag", Vector3.ZERO, 1.7, {"life": 1.2, "gravity": 0.0, "drag": 1.6, "piece": 0.26, "add": 0.35, "shrink": 0.6, "spin": 6.0}, {"decay": 0.9})
	G.flat(r, _column(), "Column", Vector3.ZERO, Vector3(1.2, 4.2, 1.2), 1.5, {"soft": 0.9, "add": 0.3, "flow": 4.0, "hot": M.hot(VIOLET), "core": 0.6}, {"delay": 0.05, "initial": 0.3, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.7, "spin": 3.0})
	G.flat(r, G.cut_storm("av_cuts2", 18, 1.0, radius * 0.75, 0.9, M.a(VIOLET, 0.95), M.a(VIOLET.lightened(0.25), 0.9), M.a(INK, 1.0), 842, 0.4, 1.6, 0.5), "Cuts", Vector3.ZERO, Vector3.ONE, 1.3, G.lit(VIOLET, 0.65, 0.6, {"sweep": 0.08, "tail": 5.0}), {"delay": 0.05, "fade_in": 0.01, "decay": 0.9, "spin": 1.5})
	M.shock(r, "av_ring", VIOLET, radius * 1.03, 0.0, 0.5, 0.14)
	G.flat(r, K.glow_disc("av_dark", Color(0.06, 0.02, 0.12, 0.75)), "Dark", Vector3.UP * 0.035, Vector3.ONE * radius * 0.85, 1.8, {"soft": 0.6, "add": 0.0}, {"initial": 0.3, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.75})
	G.done(r)
	if G.extras(1) > 0:
		var inner := G.open(parent, feet, 1.6, "Skill_%s_inner" % ID, turn + 0.7, caster)
		if inner:
			G.flat(inner, _spiral("av_arms_in", 3, LILAC, VIOLET, 0.06, 0.8), "Counter", Vector3.UP * 0.06, Vector3.ONE * radius * 0.55, 1.5, G.lit(LILAC, 0.6, 0.5), {"delay": 0.08, "initial": 0.3, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.75, "spin": -4.0})
			M.dust(inner, "av_smoke", Color(0.14, 0.06, 0.24), G.n(16), radius * 0.5, radius * 0.9, 0.1, 1.4, Vector3.ZERO, 1.0, 843)
			M.sparks(inner, "av_motes", [VIOLET, LILAC], G.n(16), 0.3, 1.0, 0.8, 5.0, 0.1, 0.1, 1.2, Vector3.ZERO, -1.0, 844, 0.2, 1.0)
			G.done(inner)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [VIOLET, LILAC], crit, true)
