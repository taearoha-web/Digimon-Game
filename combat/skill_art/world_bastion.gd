extends RefCounted
## Defender Lv.100 "World Bastion": the defender plants the shield in the world and a fortress
## answers. Wind-up: a golden seal of the bastion turns under the feet, golden fissures run
## IN to the defender, stones lift off the ground and a colossal shield of light gathers over
## the head. Release: the colossal shield drives into the ground behind the defender and
## stands like a keep, a ring of crenellated stone ramparts and towers heaves out of the
## earth round the whole area, wave after wave of golden quake rings roll out, fissures
## blaze, rubble and dust are thrown, pillars of light stand at six towers, a great crest
## shines in the sky and a "!" pops over every foe the bastion now holds (the taunt), the
## stars of the stun spinning over them. Royal gold, bronze, granite and cream.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "world_bastion"
const GOLD := Color("ffd84a")
const BRONZE := Color("b8701e")
const CREAM := Color("fff1c8")
const GRANITE := Color("7a7068")
const SLATE := Color("5a524c")
const DUST := Color("c8b090")
const BEHIND := 2.6
const RING := 7.6


static func _keep() -> ArrayMesh:
	return M.solid("wb_keep", G.tower(Color("6a4a20"), GOLD, CREAM), Vector3(1, 6, 1))


## A ring of stone ramparts and six towers, built at RING metres (scale it by radius / RING),
## each segment rising on its own moment round the ring.
static func _ramparts() -> ArrayMesh:
	if M.has("wb_ramparts"):
		return M.get_mesh("wb_ramparts")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1001
	var st := K.begin()
	var segments := 24
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var mid := (a0 + a1) * 0.5
		var dir := Vector3(sin(mid), 0, cos(mid)) * RING
		var length := 2.0 * sin((a1 - a0) * 0.5) * 1.02 * RING
		var p := K.Part.new()
		p.ink(GRANITE if i % 2 == 0 else SLATE, 0.15)
		p.box(Vector3(0, 0.38, 0), Vector3(length, 0.76, 0.42))
		p.ink(GRANITE.lightened(0.12), 0.15)
		for m in 2:
			p.box(Vector3((float(m) - 0.5) * length * 0.5, 0.86, 0), Vector3(length * 0.26, 0.22, 0.44))
		p.ink(GOLD, 0.0, 1.0)
		p.box(Vector3(0, 0.66, 0.215), Vector3(length * 0.95, 0.06, 0.02))
		K.stamp(st, p, Transform3D(Basis(Vector3.UP, mid), dir), 0.012 * float(i % 12), 1.0)
	for t in 6:
		var a := TAU * float(t) / 6.0
		var dir := Vector3(sin(a), 0, cos(a)) * RING
		var p := K.Part.new()
		p.ink(SLATE, 0.2)
		p.tube(Vector3(0, 0, 0), Vector3(0, 1.4, 0), 0.5, 0.44, 8)
		p.ink(GRANITE.lightened(0.15), 0.2)
		p.tube(Vector3(0, 1.4, 0), Vector3(0, 1.58, 0), 0.56, 0.56, 8)
		p.ink(Color("8a2a1a"), 0.3)
		p.tube(Vector3(0, 1.58, 0), Vector3(0, 2.3, 0), 0.54, 0.0, 8)
		p.ink(GOLD, 0.6, 0.8)
		p.box(Vector3(0, 1.0, 0.46), Vector3(0.14, 0.32, 0.04))
		K.stamp(st, p, Transform3D(Basis(Vector3.UP, a), dir), 0.02 + 0.012 * float(t * 2), 1.0)
	return M.keep("wb_ramparts", K.finish(st, Vector3(1, 3, 1)))


## Six light pillars on a ring of radius 1 at the towers.
static func _beacons() -> ArrayMesh:
	if M.has("wb_beacons"):
		return M.get_mesh("wb_beacons")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a := TAU * float(i) / 6.0
		K.beam(st, Vector3(sin(a), 0, cos(a)) * 1.02, 1.0, 0.09, M.a(GOLD, 0.85), 2, 0.03 * float(i), 0.0, 0.02)
	return M.keep("wb_beacons", K.finish(st, Vector3.ONE * 0.3, false))


## Golden fissures converging on the centre (the reveal runs inward: UV.y from the rim).
static func _converge() -> ArrayMesh:
	if M.has("wb_converge"):
		return M.get_mesh("wb_converge")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1002
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var a := TAU * float(i) / 10.0 + rng.randf_range(-0.2, 0.2)
		var pts := PackedVector3Array()
		for k in 8:
			var t := float(k) / 7.0
			var rr := lerpf(1.0, 0.12, t)
			var aa := a + rng.randf_range(-0.12, 0.12) / maxf(rr, 0.3)
			pts.append(Vector3(sin(aa) * rr, 0.0, cos(aa) * rr))
		K.ribbon(st, pts, 0.05, M.a(GOLD, 1.0), 0.0, 0.0, Vector3.UP, 0.4)
	return M.keep("wb_converge", K.finish(st, Vector3.ONE * 0.2, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var radius := float(skill.get("radius", 9.0))
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, aim), visual)
	if r == null:
		return false
	G.flat(r, G.sigil("wb_seal", GOLD, 3, 36, 12, 0.35), "Seal", Vector3.UP * 0.05, Vector3.ONE * 3.2, time + 0.04, G.lit(GOLD, 0.55, 0.5), {"initial": 0.5, "grow_time": 0.9, "fade_in": 0.08, "decay": 0.97, "spin": 1.6})
	G.flat(r, _converge(), "Converge", Vector3.UP * 0.06, Vector3.ONE * radius * 0.8, time + 0.04, G.lit(GOLD, 0.6, 0.5, {"sweep": time * 0.9}), {"fade_in": 0.02, "decay": 0.95})
	var high := G.sky_height(r, Vector3.ZERO, 4.0)
	G.solid(r, _keep(), "Gather", Vector3.UP * (high - 2.2), Vector3.ONE * 2.2, time + 0.04, {"drop": -0.6, "flight": time, "ease": 1.0, "rim_color": CREAM, "rim": 1.2, "glow_color": GOLD, "dim": 0.9}, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.08, "decay": 0.98, "face_camera": true})
	G.bits(r, K.burst("wb_lift", "rock", G.n(14), 1.0, 3.2, 0.2, 2.6, [GRANITE, SLATE], 0.22, 0.2, 1003, 0.05, 0.2), "Lift", Vector3.ZERO, time + 0.04, {"life": time + 0.1, "gravity": 0.0, "drag": 2.0, "piece": 0.22, "shrink": 0.9, "spin": 3.0}, {"decay": 0.95})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.yaw(origin, who[1], G.facing(caster)) if who[1] != Vector3.INF else G.facing(caster)
	var radius := float(skill.get("radius", 9.0))
	var feet := Vector3(origin.x, 0.0, origin.z)
	var r := G.open(parent, feet, 2.0, "Skill_%s_keep" % ID, turn, caster)
	if r == null:
		return false
	var behind := K.away(r) * BEHIND
	var fit := G.sky_fit(r, behind, 4.6)
	# The keep: the colossal shield driven into the ground behind the defender.
	G.solid(r, _keep(), "Keep", behind + Vector3.DOWN * 0.4, Vector3.ONE * 4.6 * fit, 1.8, {"drop": 5.0 / (4.6 * fit), "flight": 0.08, "heat": 0.9, "rim_color": CREAM, "rim": 0.9, "glow_color": GOLD}, {"fade_in": 0.01, "decay": 0.78}, Vector3(G.TILT_BACK * 0.5, K.facing(r), 0))
	G.solid(r, _ramparts(), "Ramparts", Vector3.ZERO, Vector3.ONE * radius * 0.86 / RING, 1.7, {"drop": -1.6, "flight": 0.18, "ease": 1.0, "rim_color": GOLD, "rim": 0.5, "glow_color": GOLD, "heat": 0.4}, {"delay": 0.04, "fade_in": 0.01, "decay": 0.8})
	M.shock(r, "wb_ring", GOLD, radius * 1.04, 0.0, 0.55, 0.2)
	M.cracks(r, "wb_cracks", GOLD, radius * 0.7, 0.02, 1.6, 10, 1004, 0.07)
	M.rubble(r, "wb_rubble", [GRANITE, SLATE, GRANITE.darkened(0.2)], G.n(28), radius * 0.6, radius * 0.9, 3.5, 7.0, 0.32, 0.06, 1.3, Vector3.ZERO, 1005)
	M.dust(r, "wb_dust", DUST, G.n(22), radius * 0.7, radius * 0.95, 0.08, 1.5, Vector3.ZERO, 1.2, 1006)
	G.done(r)
	var more := G.extras(3)
	if more > 0:
		var waves := G.open(parent, feet, 1.8, "Skill_%s_waves" % ID, turn, caster)
		if waves:
			G.flat(waves, _beacons(), "Beacons", Vector3(0, 2.3, 0), Vector3(radius * 0.86, 4.0, radius * 0.86), 1.3, G.lit(GOLD, 0.65, 1.2), {"delay": 0.2, "initial": 0.3, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.6})
			M.shock(waves, "wb_ring_b", BRONZE, radius * 0.7, 0.12, 0.5, 0.26)
			M.shock(waves, "wb_ring_c", CREAM, radius * 1.15, 0.24, 0.6, 0.08)
			M.flash(waves, "wb_flash", BRONZE, 3.2, 0.0, 0.45)
			G.daze(waves, Color("ffe070"), Vector3(0, 2.4, 2.2), 1.1, 1.5, 0.2, 6)
			M.sparks(waves, "wb_embers", [GOLD, CREAM, BRONZE], G.n(22), 1.0, radius * 0.6, 3.0, 6.0, 0.13, 0.05, 1.2, Vector3.ZERO, 5.0, 1007, 0.1, 0.8)
			G.done(waves)
	if more > 1:
		var sky := G.open(parent, feet, 1.9, "Skill_%s_crest" % ID, turn, caster)
		if sky:
			var spot := K.away(sky) * (BEHIND + 1.0)
			var high := G.sky_height(sky, spot, 6.5)
			G.flat(sky, G.rays("wb_sky_rays", 18, GOLD, 0.06, 0.25), "Glory", spot + Vector3.UP * high, Vector3.ONE * 3.2, 1.5, G.lit(GOLD, 0.55, 0.6), {"delay": 0.1, "initial": 0.3, "grow_time": 0.3, "fade_in": 0.03, "decay": 0.7, "spin": 0.3}, Vector3(PI * 0.5 + G.TILT_BACK, K.facing(sky), 0))
			G.flat(sky, G.orbits("wb_halo", 1, CREAM, 0.05, 0.0), "Halo", spot + Vector3.UP * high, Vector3.ONE * 1.5, 1.6, G.lit(CREAM, 0.6, 0.5), {"delay": 0.05, "initial": 0.4, "grow_time": 0.3, "fade_in": 0.03, "decay": 0.75, "spin": 0.8})
			G.done(sky)
	if more > 2 and G.hero():
		var spots := G.foes(parent, feet, radius, 6)
		if not spots.is_empty():
			var marks := G.open(parent, feet, 1.4, "Skill_%s_marks" % ID, 0.0, caster)
			if marks:
				for i in spots.size():
					G.flat(marks, G.bang("wb_bang", GOLD), "Bang", marks.to_local(spots[i]) + Vector3.UP * 2.4, Vector3.ONE * 0.75, 1.3, G.lit(GOLD, 0.6, 0.5), {"delay": 0.12 + 0.04 * float(i), "initial": 0.2, "grow_time": 0.12, "fade_in": 0.02, "decay": 0.75, "face_camera": true})
				G.done(marks)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [GOLD, CREAM], crit)
