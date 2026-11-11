extends RefCounted
## Lancer Lv.72 "Sky Pierce" (single, pierces 8 on a long line): the lance flies through
## everything and on into the sky. Wind-up: wisps of cloud gather round the lancer, the long
## line lights faintly on the ground and the lance tip shines. Release: a pale-blue beam
## runs the whole line and bends up into the sky at its end, a lance of light riding its
## head; pressure rings stand along it, every foe on it flares, wind shards fly off. Where it
## leaves the ground a column of light stands and puffs of cloud burst out. Sky blue,
## ice white, cloud.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const SKY := Color("9fd8ff")
const PALE := Color("e8f6ff")
const DEEP := Color("3a7ac8")
const CLOUD := Color("eef4fa")
const RUN := 0.2
const L := 13.0


## The beam: along +Z at chest height to L, then bending up into the sky.
static func _path() -> ArrayMesh:
	if M.has("skypierce_path"):
		return M.get_mesh("skypierce_path")
	var st := B._st()
	var pts := PackedVector3Array()
	for i in 21:
		pts.append(Vector3(0, 1.1, lerpf(0.4, L, float(i) / 20.0)))
	for i in range(1, 9):
		var ang := PI * 0.5 * float(i) / 8.0
		pts.append(Vector3(0, 1.1 + (1.0 - cos(ang)) * 2.4 + sin(ang) * float(i) * 0.5, L + sin(ang) * 2.4))
	K.ribbon(st, pts, 1.1, B.a(SKY, 0.95), 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0, B.a(PALE, 0.95))
	K.ribbon(st, pts, 0.7, B.a(PALE, 0.85), 0.0, 0.0, Vector3.RIGHT, 0.0, 0.0, 1.0, B.a(SKY, 0.6))
	return B._done("skypierce_path", st)


static func _lance() -> ArrayMesh:
	return M.get_mesh("skypierce_lance") if M.has("skypierce_lance") else M.solid("skypierce_lance", M.lance(Color("3a4a6a"), PALE, SKY))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var reach := float((skill.get("pierce", {}) as Dictionary).get("len", L))
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.lane("skypierce_lane", 0.6, L, 1.8, B.a(DEEP, 0.25), B.a(SKY, 0.85), 8), "SkyPierceLane", Vector3.UP * 0.06, Vector3(1, 1, reach / L), t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(PALE, 0.7), "add": 0.5}, {"fade_in": 0.05, "decay": 0.95})
	B.bits(art, B.gather("skypierce_clouds", "puff", 12, 2.4, 4.0, 0.6, [CLOUD, PALE, SKY], 0.6, 181, 0.6, 2.2), "SkyPierceClouds", Vector3.ZERO, t + 0.05, {"life": t * 0.95, "gravity": 0.0, "drag": 1.0, "piece": 0.6, "alpha": 0.6, "shrink": 0.5, "spin": 1.5})
	B.light(art, B.hoop("skypierce_glint", B.a(PALE, 1.0), 0.22), "SkyPierceGlint", Vector3(0, 1.2, 1.0), Vector3.ONE * 0.35, t + 0.05, {"soft": 1.0, "hot": B.hot(PALE), "add": 0.7}, {"initial": 2.6, "grow_time": 0.95, "fade_in": 0.2, "decay": 0.95})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, center)
	var line := B.pierce_line(c)
	var reach: float = line[0]
	var k := reach / L
	var at := B.ground(origin)
	var art := B.open(c, at, 1.3, "Beam")
	if art == null:
		return false
	B.light(art, _path(), "SkyPierceBeam", Vector3.ZERO, Vector3(1, 1, k), RUN + 0.5, {"sweep": RUN, "tail": 1.3, "soft": 1.0, "hot": B.warm(PALE), "core": 0.6, "add": 0.55, "gain": 1.0}, {"fade_in": 0.01, "decay": 0.5})
	B.body(art, _lance(), "SkyPierceLance", Vector3(0, 1.1, 0.3), Vector3.ONE * 2.6, RUN, {"rim_color": PALE, "rim": 0.9, "glow_color": SKY}, {"fade_in": 0.01, "decay": 0.9, "travel": Vector3(0, 0, reach - 2.6)}, Vector3(PI * 0.5, 0, 0))
	B.body(art, _lance(), "SkyPierceRise", Vector3(0, 1.6, reach), Vector3.ONE * 2.6, 0.3, {"rim_color": PALE, "rim": 0.9, "glow_color": SKY}, {"delay": RUN, "fade_in": 0.01, "decay": 0.6, "travel": Vector3(0, 7.0, 0), "accelerate": true})
	B.light(art, B.hoops("skypierce_hoops", 6, 1.5, L, 0.6, 1.2, B.a(PALE, 0.95), RUN / L, 1.1, 0.16), "SkyPierceHoops", Vector3.ZERO, Vector3(1, 1, k), 0.65, {"soft": 0.8, "hot": B.hot(PALE), "add": 0.65}, {"fade_in": 0.01, "decay": 0.5})
	B.bits(art, B.line_burst("skypierce_wind", "shard", 26, 1.0, L, 0.5, 3.0, 2.0, [SKY, PALE, CLOUD], 0.2, 182, 2.0, RUN), "SkyPierceWind", Vector3.ZERO, 1.0, {"life": 0.8, "gravity": 1.0, "drag": 1.6, "piece": 0.2, "add": 0.4, "shrink": 0.5, "spin": 8.0}, {}, Vector3(1, 1, k))
	B.light(art, B.lane("skypierce_scar", 0.6, L, 0.9, B.a(DEEP, 0.4), B.a(SKY, 0.9), 0), "SkyPierceScar", Vector3.UP * 0.06, Vector3(1, 1, k), 1.25, {"sweep": RUN, "soft": 0.6, "hot": B.hot(PALE, 0.7), "add": 0.5}, {"fade_in": 0.01, "decay": 0.55})
	# Where it leaves for the sky: a column of light and puffs of cloud.
	var end := B.open(c, at + (c.fwd as Vector3) * reach, 1.3, "Sky", 1)
	if end:
		M.pillar(end, "skypierce_pillar", SKY, 2.4, 8.0, RUN, 0.6)
		M.dust(end, "skypierce_puffs", CLOUD, 12, 0.4, 1.6, RUN, 1.1, Vector3.UP * 1.0, 1.1, 183)
		M.shock(end, "skypierce_shock", SKY, 3.0, RUN, 0.45, 0.2, 0.1)
	var hits := B.open(c, at, 1.3, "Hits", 1)
	if hits:
		hits.rotation = Vector3.ZERO
		B.pierce_hits(hits, c, line[1], origin, SKY, PALE, reach / RUN, 1.1)
	return true
