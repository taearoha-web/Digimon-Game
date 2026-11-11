extends RefCounted
## Lancer Lv.76 "Dragon Stance" (self: ATK, DEF up, heals): the dragon's guard. Wind-up: an
## amber seal of coiling scales opens at the lancer's feet and amber light gathers. Release:
## an amber dragon of light coils up round him from the ground in a rising spiral, its head
## rearing over his shoulder towards the camera with a roar (a ring snaps out), scales of
## light shower off it, a column of warm light stands up. Aftermath: the coil burns out from
## the tail up and the seal fades. Amber, flame red, gold.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const AMBER := Color("ffb04a")
const RED := Color("e8461c")
const GOLD := Color("ffe08a")
const DEEP := Color("6a2a08")
const COIL := 3.4


## The dragon's body: one wide band spiralling up round the lancer (UV.y up the coil).
static func _coil() -> ArrayMesh:
	if M.has("dstance_coil"):
		return M.get_mesh("dstance_coil")
	var st := B._st()
	var pts := PackedVector3Array()
	var n := 60
	for i in n + 1:
		var t := float(i) / float(n)
		var ang := t * TAU * 1.6
		var r := lerpf(1.6, 1.1, t)
		pts.append(Vector3(sin(ang) * r, 0.2 + t * COIL, cos(ang) * r))
	K.ribbon(st, pts, 0.75, B.a(RED, 0.9), 0.0, 0.0, Vector3.UP, 0.3, 0.0, 1.0, B.a(AMBER, 0.97))
	var spine := PackedVector3Array()
	for p in pts:
		spine.append(p * Vector3(1.04, 1.0, 1.04) + Vector3.UP * 0.12)
	K.ribbon(st, spine, 0.3, B.a(GOLD, 0.9), 0.0, 0.0, Vector3.UP, 0.4, 0.0, 1.0, B.a(GOLD, 0.95))
	return B._done("dstance_coil", st)


static func _head() -> ArrayMesh:
	if M.has("dstance_head"):
		return M.get_mesh("dstance_head")
	# Baked in profile (snout to +X, rearing up): turned to the camera it roars across the screen.
	var p := K.Part.new()
	p.add(B.dragon_head(AMBER, GOLD, Color("fff0d0"), Color("fff6a0")), Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -0.45), Vector3.ZERO))
	return M.solid("dstance_head", p)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.spiral("dstance_seal", 0.4, 2.2, 1.6, 0.35, B.a(AMBER, 0.9), B.a(RED, 0.7), 2), "DStanceSeal", Vector3.UP * 0.07, Vector3.ONE, t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(GOLD, 0.8), "add": 0.55}, {"spin": 1.5, "fade_in": 0.05, "decay": 0.95})
	B.light(art, K.shock("dstance_ring", B.a(AMBER, 1.0), 0.18), "DStanceRing", Vector3.UP * 0.08, Vector3.ONE * 2.5, t + 0.05, {"soft": 1.0, "hot": B.hot(GOLD), "add": 0.6}, {"initial": 0.5, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.95})
	B.bits(art, B.gather("dstance_gather", "scale", 16, 2.4, 5.0, 1.2, [AMBER, GOLD, RED], 0.16, 191, 0.3, 1.8), "DStanceGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.16, "add": 0.6, "shrink": 0.4, "spin": 6.0})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var at := B.ground(origin)
	var art := B.open(c, at, 1.9, "Dragon")
	if art == null:
		return false
	B.follow(c, art)
	B.light(art, _coil(), "DStanceCoil", Vector3.ZERO, Vector3.ONE, 1.6, {"sweep": 0.3, "tail": 0.0, "soft": 0.6, "hot": B.hot(GOLD), "core": 0.4, "flow": 2.6, "add": 0.7}, {"fade_in": 0.01, "decay": 0.55, "spin": 1.8})
	# The head rears over his shoulder towards the camera as the coil reaches the top.
	var h := B.sky(c, at, COIL + 1.6)
	B.body(art, _head(), "DStanceHead", Vector3.UP * clampf(h - 0.6, 2.4, COIL + 0.6), Vector3.ONE * 2.0, 1.55, {"rim_color": GOLD, "rim": 0.8, "glow_color": Color("fff6a0")}, {"delay": 0.22, "initial": 0.3, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.7, "face_camera": true, "travel": Vector3.UP * 0.3})
	M.shock(art, "dstance_roar", AMBER, 4.2, 0.26, 0.5, 0.22, 0.1)
	M.pillar(art, "dstance_pillar", AMBER, 2.4, 5.5, 0.0, 0.6)
	B.bits(art, B.whirl("dstance_scales", "scale", 28, 0.8, 1.6, 3.5, 4.5, [AMBER, GOLD, RED], 0.22, 192, 1.0, 0.6, 3.2), "DStanceScales", Vector3.ZERO, 1.5, {"life": 1.2, "gravity": 5.0, "drag": 1.2, "piece": 0.22, "add": 0.45, "shrink": 0.5, "spin": 7.0}, {"delay": 0.1})
	B.light(art, B.spiral("dstance_seal", 0.4, 2.2, 1.6, 0.35, B.a(AMBER, 0.9), B.a(RED, 0.7), 2), "DStanceGround", Vector3.UP * 0.07, Vector3.ONE * 1.3, 1.8, {"soft": 0.6, "hot": B.hot(GOLD, 0.8), "flick": 0.06, "add": 0.5}, {"spin": 1.0, "decay": 0.6})
	return true
