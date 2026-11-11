extends RefCounted
## Assassin Lv.72 "Death Mark" (armour shred over an area): the mark of death is branded on
## the ground. Wind-up: over the target area a crimson rune circle draws itself stroke by
## stroke, a dagger-cross sigil at its heart, while dark wisps are drawn in to it. Release:
## the mark brands: the sigil flares and burns into the ground, a pillar of crimson rises out
## of it, the eye of the mark opens over the area, shards of broken armour burst up off the
## foes (the shred) and dark smoke rolls out; the brand stays glowing a while after. Blood
## crimson, wine, iron and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "death_mark"
const CRIMSON := Color("ff4f7b")
const BLUSH := Color("ffd0dc")
const WINE := Color("4a0828")
const IRON := Color("8a8a96")
const INK := Color(0.05, 0.01, 0.05)


## The mark (radius 1): rings, an inverted triangle, a cross of two daggers, runes.
static func _mark() -> ArrayMesh:
	if M.has("dm_mark"):
		return M.get_mesh("dm_mark")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.0, M.a(WINE, 0.5), 0.0, 40, 0.0, Vector3.UP, Vector3.ZERO, M.a(WINE, 0.0), 0.0, true)
	K.ring(st, 0.96, 0.06, M.a(CRIMSON, 1.0), 0.004, 72, 0.0)
	K.ring(st, 0.84, 0.025, M.a(CRIMSON, 0.85), 0.004, 64, 0.08)
	var tri := PackedVector3Array()
	for i in 4:
		var a := PI + TAU * float(i) / 3.0
		tri.append(Vector3(sin(a), 0.006, cos(a)) * 0.82)
	K.ribbon(st, tri, 0.045, M.a(CRIMSON, 1.0), 0.15, 0.0, Vector3.UP, 0.0)
	for s in [-1.0, 1.0]:
		var dir := Vector3(s * 0.7071, 0.008, 0.7071)
		K.ribbon(st, PackedVector3Array([-dir * 0.55, dir * 0.1, dir * 0.6]), 0.1, M.a(BLUSH, 1.0), 0.25, 0.0, Vector3.UP, 0.7)
		var guard := Vector3(dir.z, 0, -dir.x)
		K.ribbon(st, PackedVector3Array([-dir * 0.36 - guard * 0.13, -dir * 0.36 + guard * 0.13]), 0.05, M.a(CRIMSON, 1.0), 0.25, 0.0, Vector3.UP, 0.0)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var c := Vector3(sin(a), 0.006, cos(a)) * 0.9
		var t := Vector3(cos(a), 0, -sin(a))
		K.ribbon(st, PackedVector3Array([c - t * 0.04, c + Vector3(sin(a), 0, cos(a)) * 0.03, c + t * 0.04]), 0.02, M.a(BLUSH, 0.9), 0.1 + 0.01 * float(i), 0.0, Vector3.UP, 0.0)
	return M.keep("dm_mark", K.finish(st, Vector3.ONE * 0.2, false))


## The eye of the mark (facing +Z, 1 across): a lidded almond, a slit pupil.
static func _eye() -> ArrayMesh:
	if M.has("dm_eye"):
		return M.get_mesh("dm_eye")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 0.9, M.a(WINE, 0.45), -0.01, 32, 0.0, Vector3.BACK, Vector3.ZERO, M.a(WINE, 0.0), 0.0, true)
	for s in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for i in 13:
			var t := lerpf(-1.0, 1.0, float(i) / 12.0)
			pts.append(Vector3(t * 0.5, s * (1.0 - t * t) * 0.22, 0))
		K.ribbon(st, pts, 0.06, M.a(CRIMSON, 1.0), 0.0, 0.0, Vector3.BACK, 0.4)
	K.ribbon(st, PackedVector3Array([Vector3(0, -0.17, 0.005), Vector3(0, 0, 0.005), Vector3(0, 0.17, 0.005)]), 0.07, M.a(INK, 1.0), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	K.disc(st, 0.13, M.a(CRIMSON, 0.9), 0.0, 18, 0.0, Vector3.BACK, Vector3.ZERO, M.a(BLUSH, 0.7), 0.0, true)
	return M.keep("dm_eye", K.finish(st, Vector3.ONE * 0.2, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var spot := Vector3(aim.x, 0.0, aim.z)
	var radius := float(skill.get("radius", 6.0))
	var r := G.windup(parent, spot, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, spot), visual)
	if r == null:
		return false
	G.flat(r, _mark(), "Draw", Vector3.UP * 0.05, Vector3.ONE * radius * 0.9, time + 0.04, G.lit(CRIMSON, 0.55, 0.5, {"sweep": time * 0.8}), {"fade_in": 0.02, "decay": 0.97, "spin": 0.5})
	G.bits(r, G.inward("dm_wisps", "puff", G.n(14), radius * 0.6, radius * 0.95, [Color(0.12, 0.02, 0.06), WINE, INK], 0.45, 3.0, 0.5, 0.15, 721, 0.1, 0.6), "Wisps", Vector3.ZERO, time + 0.04, {"life": time, "gravity": 0.0, "drag": 3.0, "piece": 0.45, "alpha": 0.55, "swell": 1.3, "shrink": 0.6, "spin": 2.0}, {"decay": 0.95})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var spot := Vector3(center.x, 0.0, center.z)
	var radius := float(skill.get("radius", 6.0))
	var turn := G.yaw(origin, spot, G.facing(caster))
	var r := G.open(parent, spot, 2.0, "Skill_%s_brand" % ID, turn, caster)
	if r == null:
		return false
	G.flat(r, _mark(), "Brand", Vector3.UP * 0.05, Vector3.ONE * radius * 0.9, 1.95, G.lit(CRIMSON, 0.6, 0.5, {"flick": 0.08}), {"initial": 1.08, "grow_time": 0.12, "fade_in": 0.01, "decay": 0.75, "spin": 0.15})
	M.pillar(r, "dm_pillar", CRIMSON, 2.4, 4.5, 0.0, 0.5)
	G.flat(r, _eye(), "Eye", Vector3.UP * 3.1, Vector3.ONE * 2.4, 1.3, G.lit(CRIMSON, 0.6, 0.5), {"delay": 0.06, "initial": 0.2, "grow_time": 0.18, "fade_in": 0.02, "decay": 0.7, "face_camera": true})
	# The shred: armour shards thrown up off the area.
	G.bits(r, K.burst("dm_shards", "shard", G.n(26), 0.5, radius * 0.75, 2.5, 6.0, [IRON, IRON.darkened(0.3), CRIMSON], 0.28, 0.12, 722, 0.4, 1.4), "Shred", Vector3.ZERO, 1.3, {"life": 1.1, "gravity": 9.0, "drag": 0.8, "piece": 0.28, "floor_y": 0.06, "shrink": 0.85, "spin": 9.0, "hot": Color(1.0, 0.3, 0.4, 0.5)}, {"delay": 0.05, "decay": 0.85})
	M.shock(r, "dm_ring", CRIMSON, radius * 1.03, 0.0, 0.45, 0.14)
	M.dust(r, "dm_smoke", Color(0.16, 0.04, 0.1), G.n(16), radius * 0.4, radius * 0.8, 0.05, 1.4, Vector3.ZERO, 1.0, 723)
	G.done(r)
	if G.extras(1) > 0:
		var burn := G.open(parent, spot, 1.6, "Skill_%s_burn" % ID, turn, caster)
		if burn:
			M.flash(burn, "dm_flash", WINE, radius * 0.6, 0.0, 0.6)
			M.cracks(burn, "dm_cracks", CRIMSON, radius * 0.75, 0.04, 1.5, 9, 724, 0.07)
			M.sparks(burn, "dm_embers", [CRIMSON, BLUSH], G.n(16), 0.5, radius * 0.7, 0.8, 3.0, 0.1, 0.1, 1.2, Vector3.ZERO, -0.5, 725, 0.1, 0.6)
			G.done(burn)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [CRIMSON, BLUSH], crit)
