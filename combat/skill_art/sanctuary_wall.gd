extends RefCounted
## Defender Lv.96 "Sanctuary Wall" (party ATK up, damage cut): a sanctuary rises round the
## defender. Wind-up: a rose window of light draws itself on the ground and motes gather.
## Release: eight slim columns of ivory stone rise round the defender one after another,
## arches of golden light spring from column to column and ribs of light vault over the
## top into a dome, the rose window flares under the feet, a winged crest shines in the sky
## above, light pillars stand in every column and blessed motes drift up through it all.
## Ivory, honey gold and a soft rose.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "sanctuary_wall"
const GOLD := Color("ffe9a0")
const HONEY := Color("f0b84a")
const ROSE := Color("ffa8a0")
const IVORY := Color("f4ead8")
const STONE := Color("c8b89a")
const RING := 2.7
const COLUMNS := 8


## Eight slim columns on a ring of radius 1 (1 tall), each rising on its own moment.
static func _columns() -> ArrayMesh:
	if M.has("sw_columns"):
		return M.get_mesh("sw_columns")
	var st := K.begin()
	for i in COLUMNS:
		var a := TAU * float(i) / float(COLUMNS)
		var at := Vector3(sin(a), 0, cos(a))
		var p := K.Part.new()
		p.ink(STONE, 0.3)
		p.box(Vector3(0, 0.03, 0), Vector3(0.12, 0.06, 0.12))
		p.ink(IVORY, 0.4)
		p.tube(Vector3(0, 0.05, 0), Vector3(0, 0.92, 0), 0.04, 0.034, 8)
		p.ink(HONEY, 0.8, 0.5)
		p.box(Vector3(0, 0.95, 0), Vector3(0.11, 0.05, 0.11))
		p.gem(Vector3(0, 1.02, 0), Vector3(0.035, 0.05, 0.035))
		K.stamp(st, p, Transform3D(Basis.IDENTITY, at), 0.04 * float(i), 1.0)
	return M.keep("sw_columns", K.finish(st, Vector3(1, 2, 1)))


## Arches from column top to column top (radius 1, columns 1 tall) and ribs vaulting over.
static func _vault() -> ArrayMesh:
	if M.has("sw_vault"):
		return M.get_mesh("sw_vault")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in COLUMNS:
		var a0 := TAU * float(i) / float(COLUMNS)
		var a1 := TAU * float(i + 1) / float(COLUMNS)
		var p0 := Vector3(sin(a0), 0.95, cos(a0))
		var p1 := Vector3(sin(a1), 0.95, cos(a1))
		var mid := (p0 + p1) * 0.5
		var pts := PackedVector3Array()
		for k in 13:
			var t := float(k) / 12.0
			pts.append(p0.lerp(p1, t) + Vector3.UP * sin(t * PI) * 0.32)
		var out := Vector3(mid.x, 0, mid.z).normalized()
		K.ribbon(st, pts, 0.07, M.a(GOLD, 1.0), 0.15 + 0.03 * float(i), 0.0, out, 0.3)
		# A rib from the column top to the apex.
		var rib := PackedVector3Array()
		for k in 11:
			var t := float(k) / 10.0
			rib.append(Vector3(sin(a0) * cos(t * PI * 0.5), 0.95 + sin(t * PI * 0.5) * 0.85, cos(a0) * cos(t * PI * 0.5)))
		K.ribbon(st, rib, 0.045, M.a(HONEY, 0.9), 0.3 + 0.02 * float(i), 0.0, Vector3(cos(a0), 0, -sin(a0)), 0.2)
	return M.keep("sw_vault", K.finish(st, Vector3.ONE * 0.3, false))


## The rose window (radius 1): rings, eight petals, a star at the heart.
static func _rose() -> ArrayMesh:
	if M.has("sw_rose"):
		return M.get_mesh("sw_rose")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.0, M.a(HONEY.darkened(0.4), 0.3), 0.0, 40, 0.0, Vector3.UP, Vector3.ZERO, M.a(HONEY, 0.0), 0.0, true)
	K.ring(st, 0.97, 0.05, M.a(GOLD, 1.0), 0.004, 72)
	K.ring(st, 0.86, 0.025, M.a(ROSE, 0.9), 0.004, 64)
	K.ring(st, 0.26, 0.035, M.a(GOLD, 1.0), 0.004, 40)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var u := Vector3(sin(a), 0, cos(a))
		var v := Vector3(cos(a), 0, -sin(a))
		var pts := PackedVector3Array()
		for k in 15:
			var t := lerpf(-PI * 0.5, PI * 0.5, float(k) / 14.0)
			pts.append(u * (0.28 + 0.52 * cos(t)) + v * sin(t) * 0.16 + Vector3.UP * 0.005)
		K.ribbon(st, pts, 0.04, M.a(ROSE if i % 2 == 0 else GOLD, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("sw_rose", K.finish(st, Vector3.ONE * 0.2, false))


## A winged crest facing +Z (1 across): a small heater shield between two wings of light.
static func _crest() -> ArrayMesh:
	if M.has("sw_crest"):
		return M.get_mesh("sw_crest")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		for k in 4:
			var root := Vector3(s * 0.16, 0.05 - 0.04 * float(k), 0)
			var tip := Vector3(s * (0.95 - 0.13 * float(k)), 0.42 - 0.16 * float(k), 0)
			K.ribbon(st, PackedVector3Array([root, (root + tip) * 0.5 + Vector3(0, 0.1, 0), tip]), 0.1 - 0.015 * float(k), M.a(GOLD, 1.0), 0.0, 0.0, Vector3.BACK, 0.8, 0.0, 1.0, M.a(IVORY, 0.6))
	var pts := PackedVector3Array([Vector3(-0.18, 0.25, 0), Vector3(0.18, 0.25, 0), Vector3(0.16, -0.05, 0), Vector3(0, -0.28, 0), Vector3(-0.16, -0.05, 0), Vector3(-0.18, 0.25, 0)])
	K.ribbon(st, pts, 0.05, M.a(HONEY, 1.0), 0.0, 0.0, Vector3.BACK, 0.0)
	K.disc(st, 0.14, M.a(ROSE, 1.0), 0.0, 16, 0.0, Vector3.BACK, Vector3(0, 0.03, 0), M.a(ROSE, 0.6), 0.0, true)
	return M.keep("sw_crest", K.finish(st, Vector3.ONE * 0.2, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var caster := G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.facing(caster), visual)
	if r == null:
		return false
	G.flat(r, _rose(), "Rose", Vector3.UP * 0.05, Vector3.ONE * RING * 1.1, time + 0.04, G.lit(GOLD, 0.55, 0.5, {"sweep": time}), {"initial": 0.6, "grow_time": 0.6, "fade_in": 0.05, "decay": 0.97, "spin": 0.5})
	G.bits(r, G.inward("sw_gather", "ember", G.n(16), 2.2, 3.4, [GOLD, ROSE, IVORY], 0.12, 3.0, 0.4, 0.15, 961, 0.4, 2.4), "Gather", Vector3.ZERO, time + 0.04, {"life": time, "gravity": 0.0, "drag": 3.0, "piece": 0.12, "add": 0.85, "shrink": 0.6, "spin": 3.0}, {"decay": 0.95})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.facing(caster)
	var label := "Skill_%s_sanctum" % ID
	var r := G.aura(parent, caster, 2.4, label, turn) if caster else G.open(parent, origin, 2.4, label, turn, null)
	if r == null:
		return false
	var tall := 2.5
	G.solid(r, _columns(), "Columns", Vector3.ZERO, Vector3(RING, tall, RING), 2.25, {"drop": -1.0, "flight": 0.22, "ease": 1.0, "rim_color": GOLD, "rim": 0.8, "glow_color": HONEY}, {"fade_in": 0.02, "decay": 0.82})
	G.flat(r, _vault(), "Vault", Vector3.ZERO, Vector3(RING, tall, RING), 2.2, G.lit(GOLD, 0.6, 0.6, {"flick": 0.05}), {"fade_in": 0.02, "decay": 0.78})
	G.flat(r, _rose(), "Rose", Vector3.UP * 0.05, Vector3.ONE * RING * 1.25, 2.3, G.lit(GOLD, 0.55, 0.5), {"initial": 0.85, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.8, "spin": 0.3})
	G.motes(r, "sw_motes", [GOLD, ROSE, IVORY], G.n(22), 0.4, RING, 2.4, 0.12, 0.2, 2.0, 962)
	M.shock(r, "sw_ring", GOLD, RING * 1.6, 0.0, 0.5, 0.14)
	G.flat(r, G.curtain("sw_light", M.a(HONEY, 0.5), M.a(GOLD, 0.0), 1.0, 40), "Light", Vector3.ZERO, Vector3(RING, 1.6, RING), 1.0, G.lit(HONEY, 0.6, 1.1, {"flow": 2.5}), {"delay": 0.12, "initial": 0.4, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.6})
	G.done(r)
	if G.extras(2) > 0:
		var sky := G.aura(parent, caster, 2.3, "Skill_%s_crest" % ID, turn) if caster else null
		if sky:
			var high := G.sky_height(sky, Vector3.ZERO, 4.2)
			G.flat(sky, _crest(), "Crest", Vector3.UP * high, Vector3.ONE * 1.6, 2.1, G.lit(GOLD, 0.6, 0.6), {"delay": 0.25, "initial": 0.3, "grow_time": 0.25, "fade_in": 0.04, "decay": 0.82, "face_camera": true})
			G.flat(sky, G.rays("sw_sky_rays", 14, IVORY, 0.05, 0.3), "Rays", Vector3.UP * high, Vector3.ONE * 2.0, 1.6, G.lit(GOLD, 0.5, 0.6), {"delay": 0.3, "initial": 0.3, "grow_time": 0.3, "fade_in": 0.04, "decay": 0.7, "spin": 0.4}, Vector3(PI * 0.5 + G.TILT_BACK, 0, 0))
			M.flash(sky, "sw_flash", HONEY.darkened(0.2), RING * 1.2, 0.0, 0.5)
			M.shock(sky, "sw_ring_b", ROSE, RING * 2.0, 0.15, 0.6, 0.08)
			G.done(sky)
	return true
