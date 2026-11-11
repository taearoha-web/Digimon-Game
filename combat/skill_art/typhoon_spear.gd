extends RefCounted
## Lancer Lv.60 "Typhoon Spear" (burst, slows): the lance whirled into a low typhoon.
## Wind-up: mint wind spirals in along the ground and a ring of wind tightens round the
## lancer's hips. Release: a wheel of eight spears of wind-light spins out round him over a
## four-armed spiral of wind racing across the ground, two flat rings of wind slicing round
## at knee and chest height, leaves and wind shards flung round, a ring at the edge.
## Aftermath: little eddies keep turning over the area (the slow), then still. Mint, sea
## green, pale aqua.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const MINT := Color("7affd0")
const SEA := Color("1fae8a")
const AQUA := Color("d8fff2")
const LEAF := Color("8fe07a")
const R := 6.5


## Small eddies scattered over the area (radius R): the slow lingering on the ground.
static func _eddies() -> ArrayMesh:
	if M.has("typhoon_eddies"):
		return M.get_mesh("typhoon_eddies")
	var rng := RandomNumberGenerator.new()
	rng.seed = 151
	var st := B._st()
	for i in 9:
		var ang := rng.randf() * TAU
		var center := Vector3(sin(ang), 0, cos(ang)) * R * sqrt(rng.randf_range(0.15, 0.85))
		var pts := PackedVector3Array()
		var start := rng.randf() * TAU
		for k in 19:
			var t := float(k) / 18.0
			var a2 := start + t * TAU * 1.4
			pts.append(center + Vector3(sin(a2), 0, cos(a2)) * lerpf(0.9, 0.2, t))
		K.ribbon(st, pts, 0.16, B.a(MINT, 0.85), rng.randf() * 0.2, 0.0, Vector3.UP, 0.5, 0.0, 1.0, B.a(AQUA, 0.3))
	return B._done("typhoon_eddies", st)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.15, duration)
	var s := float(skill.get("radius", R)) / R
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.spiral("typhoon_in", 3.8, 0.6, 1.2, 0.45, B.a(MINT, 0.8), B.a(AQUA, 0.9), 3), "TyphoonIn", Vector3.UP * 0.07, Vector3.ONE * s, t + 0.05, {"sweep": t * 0.8, "soft": 0.8, "hot": B.hot(AQUA, 0.8), "add": 0.55}, {"spin": 5.0, "fade_in": 0.1, "decay": 0.9})
	B.light(art, B.slash("typhoon_belt", 1.3, 0.0, TAU, 1.0, 1.0, 0.45, B.a(MINT, 0.85), B.a(AQUA, 0.5), Color(0, 0, 0, 0), -1.0, 0.4), "TyphoonBelt", Vector3.ZERO, Vector3.ONE, t + 0.05, {"sweep": t * 0.6, "soft": 0.8, "hot": B.hot(AQUA), "flow": 3.0, "add": 0.6}, {"spin": 9.0, "initial": 1.8, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.92})
	B.bits(art, B.gather("typhoon_gather", "shard", 18, 3.4, 7.0, 0.8, [MINT, AQUA, LEAF], 0.16, 152, 0.2, 1.4), "TyphoonGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.16, "add": 0.5, "shrink": 0.4, "spin": 8.0})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var radius := float(skill.get("radius", R))
	var s := radius / R
	var at := B.ground(origin)
	var art := B.open(c, at, 1.4, "Typhoon")
	if art == null:
		return false
	# The wheel of spears, flung out spinning.
	var spears := B.lance_ring("typhoon_spears", 8, 3.0, 2.4, Color("2a4a40"), Color("c8fff0"), MINT, 0.9, 0.1)
	B.body(art, spears, "TyphoonSpears", Vector3.ZERO, Vector3.ONE * s, 0.6, {"rim_color": AQUA, "rim": 0.8, "glow_color": MINT}, {"initial": 0.45, "grow_time": 0.5, "fade_in": 0.01, "decay": 0.6, "spin": 11.0})
	B.light(art, B.spiral("typhoon_wind", 0.8, 6.0, 0.9, 0.75, B.a(MINT, 0.9), B.a(SEA, 0.35), 4), "TyphoonWind", Vector3.UP * 0.07, Vector3.ONE * s, 0.9, {"sweep": 0.18, "soft": 0.7, "hot": B.hot(AQUA, 0.8), "flow": 2.0, "add": 0.6}, {"fade_in": 0.01, "decay": 0.55, "spin": 4.0})
	B.light(art, B.slash("typhoon_ring_a", 3.4, 0.0, TAU * 0.8, 0.6, 0.7, 1.3, B.a(MINT, 0.9), B.a(AQUA, 0.6), Color(0, 0, 0, 0), 4.6, 0.3), "TyphoonRingA", Vector3.ZERO, Vector3.ONE * s, 0.5, {"sweep": 0.1, "tail": 3.0, "soft": 0.7, "hot": B.hot(AQUA), "add": 0.65}, {"fade_in": 0.01, "decay": 0.5, "spin": 8.0})
	B.light(art, B.slash("typhoon_ring_b", 2.4, PI, PI + TAU * 0.8, 1.5, 1.4, 1.0, B.a(AQUA, 0.9), B.a(MINT, 0.6), Color(0, 0, 0, 0), 3.4, 0.3), "TyphoonRingB", Vector3.ZERO, Vector3.ONE * s, 0.45, {"sweep": 0.1, "tail": 3.0, "soft": 0.7, "hot": B.hot(AQUA), "add": 0.65}, {"delay": 0.04, "fade_in": 0.01, "decay": 0.5, "spin": 10.0})
	M.shock(art, "typhoon_shock", MINT, radius, 0.06, 0.5, 0.2, 0.1)
	B.bits(art, B.whirl("typhoon_leaves", "shard", 30, 1.2, 4.0, 8.0, 3.0, [MINT, AQUA, LEAF, SEA], 0.2, 153, 1.0, 0.3, 1.6), "TyphoonLeaves", Vector3.ZERO, 1.2, {"life": 1.0, "gravity": 2.0, "drag": 1.4, "piece": 0.2, "add": 0.35, "shrink": 0.5, "spin": 9.0, "sway": 0.2})
	var after := B.open(c, at, 1.9, "Eddies", 1)
	if after:
		B.light(after, _eddies(), "TyphoonEddies", Vector3.UP * 0.06, Vector3.ONE * s, 1.8, {"soft": 0.7, "hot": B.hot(AQUA, 0.7), "flow": 2.5, "add": 0.5}, {"delay": 0.15, "fade_in": 0.15, "decay": 0.6})
		M.dust(after, "typhoon_dust", Color("cfe8d8"), 12, radius * 0.5, radius * 0.9, 0.05, 1.2, Vector3.ZERO, 0.9, 154)
	return true
