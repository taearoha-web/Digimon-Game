extends RefCounted
## Warrior Lv.92 "Divine Piercing" (fan, 8 hits): eight holy swords loosed at once. Wind-up:
## eight swords of light open into a fan behind the warrior, points out, over an eight-
## pointed star seal at his feet. Release: each sword flies straight at its own foe (the
## very foes and flight times of the hit: the target first, then the nearest in range),
## a trail of light following it; where one arrives a flare, a ring round the blade and
## sparks. Swords with no foe left fly out to the eight directions and fade. Gold, pale
## gold, steel blue.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const HOLY := Color("ffd85a")
const PALE := Color("fff3c0")
const STEEL := Color("e8eef8")
const AMBER := Color("ffaa3a")
const COUNT := 8
const LENGTH := 2.2


static func _sword() -> ArrayMesh:
	return M.get_mesh("dpierce_sword") if M.has("dpierce_sword") else M.solid("dpierce_sword", B.sword(STEEL, HOLY, PALE, Color("8a5a2a"), 0.11))


## The fan of eight swords behind the warrior (XY plane, facing +Z), points out.
static func _fan() -> ArrayMesh:
	if M.has("dpierce_fan"):
		return M.get_mesh("dpierce_fan")
	var st := K.begin()
	var part := B.sword(STEEL, HOLY, PALE, Color("8a5a2a"), 0.11)
	for i in COUNT:
		var ang := lerpf(-1.4, 1.4, float(i) / float(COUNT - 1))
		var basis := Basis(Vector3.BACK, -ang)
		K.stamp(st, part, Transform3D(basis.scaled(Vector3.ONE * 1.7), basis * Vector3(0, 0.6, 0)), 0.03 * absf(float(i) - 3.5), 0.0)
	return M.keep("dpierce_fan", K.finish(st, Vector3.ONE))


## The eight-pointed star seal on the ground, radius 1.
static func _star() -> ArrayMesh:
	if M.has("dpierce_star"):
		return M.get_mesh("dpierce_star")
	var st := B._st()
	for i in COUNT:
		var a0 := TAU * float(i) / float(COUNT)
		var a1 := a0 + TAU / float(COUNT * 2)
		var a2 := a0 + TAU / float(COUNT)
		var p0 := Vector3(sin(a0), 0, cos(a0))
		var p1 := Vector3(sin(a1), 0, cos(a1)) * 0.45
		var p2 := Vector3(sin(a2), 0, cos(a2))
		K.ribbon(st, PackedVector3Array([p0, p1, p2]), 0.05, B.a(HOLY, 0.95), 0.0, 0.0, Vector3.UP, 0.0)
		K.ribbon(st, PackedVector3Array([Vector3.ZERO, p0 * 0.98]), 0.03, B.a(PALE, 0.8), 0.0, 0.0, Vector3.UP, 0.0)
	K.ring(st, 1.08, 0.04, B.a(HOLY, 0.9), 0.0, 64)
	K.ring(st, 0.5, 0.03, B.a(PALE, 0.8), 0.0, 48)
	return B._done("dpierce_star", st)


## [from, to, flight] of each sword: the foes and flight times of the hit (hero.gd _shoot),
## then the eight directions for the swords left over.
static func _flights(c: Dictionary) -> Array:
	var from := B.hand(c)
	var reach := float((c.skill as Dictionary).get("range", 12.0))
	var list := B.foes(c.parent, c.origin, reach, 32)
	var first := B.mob_at(c.parent, c.center)
	if first:
		list.erase(first)
		list.push_front(first)
	var out: Array = []
	for mob in list.slice(0, COUNT):
		var to: Vector3 = (mob as Mob).hit_point()
		out.append([from, to, clampf(from.distance_to(to) / 20.0, 0.12, 0.6), true])
	var f: Vector3 = c.fwd
	var k := 0
	while out.size() < COUNT:
		var ang := TAU * float(k) / float(COUNT)
		var dir := f.rotated(Vector3.UP, ang)
		out.append([from, from + dir * 8.0 + Vector3.DOWN * 0.3, 0.4, false])
		k += 1
	return out


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var at := B.ground(origin)
	var art := B.open(c, at, t + 0.05, "Windup")
	if art == null:
		return false
	var spot := K.beyond(art, 0.7)
	B.body(art, _fan(), "DPierceFan", spot + Vector3.UP * 1.4, Vector3.ONE, t + 0.05, {"rim_color": PALE, "rim": 0.9, "glow_color": HOLY}, {"initial": 0.3, "grow_time": 0.7, "fade_in": 0.3, "decay": 0.99, "face_camera": true})
	B.light(art, _star(), "DPierceStar", Vector3.UP * 0.06, Vector3.ONE * 2.6, t + 0.05, {"sweep": t * 0.7, "soft": 0.6, "hot": B.hot(PALE, 0.8), "add": 0.55}, {"initial": 0.5, "grow_time": 0.7, "spin": 1.0, "decay": 0.97})
	B.bits(art, B.gather("dpierce_gather", "ember", 16, 2.2, 4.0, 2.2, [HOLY, PALE], 0.12, 111, 0.6, 2.2), "DPierceGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.12, "add": 0.8, "shrink": 0.4})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, center)
	var flights := _flights(c)
	var at := B.ground(origin)
	var longest := 0.0
	for f in flights:
		longest = maxf(longest, float(f[2]))
	# The seal flaring as they go.
	var seal := B.open(c, at, longest + 1.2, "Seal")
	if seal == null:
		return false
	seal.rotation = Vector3.ZERO
	B.light(seal, _star(), "DPierceSeal", Vector3.UP * 0.06, Vector3.ONE * 2.8, longest + 1.1, {"soft": 0.6, "hot": B.hot(PALE, 0.8), "flick": 0.05, "add": 0.55}, {"initial": 1.0, "spin": 0.5, "decay": 0.5})
	M.shock(seal, "dpierce_shock", HOLY, 3.2, 0.0, 0.45, 0.2, 0.1)
	# Trails, flares, rings and sparks: one mesh each, every piece on its own clock.
	var trails := B._st()
	var flares := B._st()
	var spray := B._st()
	var rng := RandomNumberGenerator.new()
	rng.seed = 113
	var sweep := 0.12
	for f in flights:
		var from: Vector3 = f[0]
		var to: Vector3 = f[1]
		var flight: float = f[2]
		var dir := (to - from).normalized()
		K.ribbon(trails, PackedVector3Array([from - at, (from + to) * 0.5 - at, to - at]), 0.6, B.a(HOLY, 0.9), maxf(0.0, flight - sweep), 0.0, Vector3.UP, 0.0, 0.0, 1.0, B.a(PALE, 0.95))
		if bool(f[3]):
			K.disc(flares, 1.4, B.a(HOLY, 0.95), 0.0, 16, flight, dir, to - at, B.a(AMBER, 0.0), -1.0)
			var u := dir.cross(Vector3.UP).normalized()
			var w := dir.cross(u)
			var ring := PackedVector3Array()
			for k in 25:
				var ang := TAU * float(k) / 24.0
				ring.append(to - at + (u * cos(ang) + w * sin(ang)) * 1.0)
			K.ribbon(flares, ring, 0.2, B.a(PALE, 1.0), flight, 0.0, dir, 0.0)
			K.burst_at(spray, rng, "ember", 7, B.ground(to) - at + Vector3.UP * 0.4, 0.1, 0.4, 3.5, 3.0, [HOLY, PALE, AMBER], 0.13, flight, 0.03, 0.4, 1.0)
	B.light(seal, K.finish(trails, Vector3.ONE * 0.5, false), "DPierceTrails", Vector3.ZERO, Vector3.ONE, longest + 0.45, {"sweep": sweep, "tail": 1.3, "soft": 0.9, "hot": B.hot(PALE), "add": 0.7}, {"fade_in": 0.01, "decay": 0.8})
	var hits := B.open(c, at, longest + 1.0, "Hits")
	if hits:
		hits.rotation = Vector3.ZERO
		B.light(hits, K.finish(flares, Vector3.ONE * 0.5, false), "DPierceFlares", Vector3.ZERO, Vector3.ONE, longest + 0.5, {"soft": 0.8, "hot": B.hot(PALE), "add": 0.7, "flash": 0.32}, {"fade_in": 0.01, "decay": 0.85})
		B.bits(hits, K.finish(spray, Vector3.ONE * 8.0, false), "DPierceSpray", Vector3.ZERO, longest + 0.9, {"life": 0.6, "gravity": 7.0, "drag": 1.5, "piece": 0.13, "add": 0.75, "shrink": 0.3})
	# The swords themselves, each on its own straight flight (a layer each: two roots of them).
	var mesh := _sword()
	var roots: Array = [B.open(c, at, longest + 0.2, "SwordsA"), B.open(c, at, longest + 0.2, "SwordsB", 1)]
	var i := 0
	for f in flights:
		var art: StarSkillArt = roots[0] if i < COUNT / 2 or roots[1] == null else roots[1]
		i += 1
		if art == null:
			continue
		art.rotation = Vector3.ZERO
		var from: Vector3 = f[0]
		var to: Vector3 = f[1]
		var dir := (to - from).normalized()
		var basis := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
		B.body(art, mesh, "DPierceSword", from - at - dir * LENGTH * 0.5, Vector3.ONE * LENGTH, float(f[2]), {"rim_color": PALE, "rim": 0.9, "glow_color": HOLY}, {"travel": to - from, "fade_in": 0.01, "decay": 0.97 if bool(f[3]) else 0.5}, basis.get_euler())
	return true
