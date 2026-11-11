extends RefCounted
## Warrior 100 stars "Crown Breaker": the king-breaker's execution. Wind-up: a golden crown set
## with rubies settles over the target's head on a crimson sigil, while a tall crimson blade
## of light rises over the warrior. Hit 1: a rising diagonal slash cuts across the target and
## cracks the crown. Hit 2: the execution, a towering crimson cleave falls straight through
## the target: the crown bursts into gold and ruby shards, the ground splits under it and a
## shockwave rings out. Crimson, gold and ruby.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const CRIMSON := Color("e8324a")
const GOLD := Color("ffc93a")
const RUBY := Color("c0102e")
const PALE := Color("ffe08a")
const DEEP := Color("5a1030")
const ROCK := Color("6b5a4c")
const ID := "crown_breaker"
const CROWN_Y := 3.0


static func _crown() -> ArrayMesh:
	return M.solid("breaker_crown", M.crown(GOLD, RUBY))


## The crown flying apart: band segments with their points, and loose rubies.
static func _shatter() -> ArrayMesh:
	if M.has("breaker_shatter"):
		return M.get_mesh("breaker_shatter")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 7
	for i in n:
		var am := TAU * (float(i) + 0.5) / float(n)
		var dir := Vector3(sin(am), 0, cos(am))
		var p := K.Part.new()
		p.ink(GOLD, 1.0)
		p.quad(Vector3(-0.38, -0.2, 0), Vector3(0.38, -0.2, 0), Vector3(0.38, 0.05, 0), Vector3(-0.38, 0.05, 0))
		p.tri(Vector3(-0.3, 0.05, 0), Vector3(0.3, 0.05, 0), Vector3(0, 0.5, 0))
		p.ink(GOLD.darkened(0.25), 0.6)
		p.tri(Vector3(0.3, 0.05, -0.02), Vector3(-0.3, 0.05, -0.02), Vector3(0, 0.48, -0.02))
		p.ink(RUBY, 0.8, 0.5)
		p.gem(Vector3(0, -0.07, 0.02), Vector3(0.09, 0.1, 0.06))
		var basis := Basis(Vector3.UP, am).scaled(Vector3.ONE * 0.6)
		var vel := dir * rng.randf_range(3.5, 5.0) + Vector3.UP * rng.randf_range(4.0, 6.0)
		K.bit(st, p, dir * 0.85 + Vector3.UP * 0.3, vel, rng.randf() * 0.03, 0.6, basis)
	for i in 14:
		var g := K.Part.new()
		g.ink(RUBY if i % 2 == 0 else PALE, 0.8)
		g.gem(Vector3.ZERO, Vector3(0.35, 0.45, 0.35))
		var ang := rng.randf() * TAU
		var dir := Vector3(sin(ang), 0, cos(ang))
		K.bit(st, g, dir * 0.6 + Vector3.UP * 0.4, dir * rng.randf_range(2.0, 5.5) + Vector3.UP * rng.randf_range(2.0, 7.0), rng.randf() * 0.05, 0.3, Basis().scaled(Vector3.ONE * 0.28))
	return M.keep("breaker_shatter", K.finish(st, Vector3(8, 9, 8), false))


## The sigil under the target: a crimson ring with the crown's seven points round it.
static func _sigil() -> ArrayMesh:
	if M.has("breaker_sigil"):
		return M.get_mesh("breaker_sigil")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.0, M.a(DEEP, 0.45), 0.0, 36, 0.0, Vector3.UP, Vector3.ZERO, M.a(DEEP, 0.0), 0.0, true)
	K.ring(st, 0.92, 0.09, M.a(CRIMSON, 1.0), 0.002, 56)
	K.ring(st, 0.7, 0.04, M.a(GOLD, 0.9), 0.002, 56)
	for i in 7:
		var ang := TAU * float(i) / 7.0
		var dir := Vector3(sin(ang), 0, cos(ang))
		var side := Vector3(cos(ang), 0, -sin(ang))
		K.ribbon(st, PackedVector3Array([dir * 0.7 - side * 0.13, dir * 1.18, dir * 0.7 + side * 0.13]), 0.07, M.a(CRIMSON, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("breaker_sigil", K.finish(st, Vector3.ONE * 0.3, false))


## The blade of light raised over the warrior (and the execution's falling edge): a long
## tapering stroke in the XY plane, point at the bottom.
static func _blade(key: String, length: float, width: float, raised := false) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	for i in 13:
		var t := float(i) / 12.0
		pts.append(Vector3(sin(t * PI) * 0.012 * length, length * (t if raised else 1.0 - t), 0))
	# Top to point: wide crimson, a darker ruby spine, gold-hot at its heart.
	K.ribbon(st, pts, width, M.a(CRIMSON, 0.95), 0.0, 0.0, Vector3.BACK, 0.8, 0.0, 1.0, M.a(RUBY, 0.95))
	K.ribbon(st, pts, width * 0.2, M.a(DEEP, 0.85), 0.0, 0.0, Vector3.BACK, 0.8, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.5, false))


## The rising cut: an arc across the target, low left to high right, in the XY plane.
static func _rising() -> ArrayMesh:
	if M.has("breaker_rising"):
		return M.get_mesh("breaker_rising")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	var low := PackedVector3Array()
	var a := Vector3(-1.5, 0.2, 0)
	var b := Vector3(1.6, 2.7, 0)
	var bow := Vector3(0.55, -0.7, 0)
	for i in 21:
		var t := float(i) / 20.0
		pts.append(a.lerp(b, t) + bow * sin(t * PI))
		low.append(a.lerp(b, t) + bow * sin(t * PI) * 1.25)
	K.ribbon(st, pts, 1.0, M.a(CRIMSON, 0.95), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, M.a(GOLD, 0.9))
	K.ribbon(st, low, 0.18, M.a(DEEP, 0.9), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return M.keep("breaker_rising", K.finish(st, Vector3.ONE * 0.5, false))


static func telegraph(art: StarSkillArt, caster: Node3D, _skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	# Over the warrior: the blade of light that will fall.
	K.put(art, K.FLAT, _blade("breaker_raised", 1.0, 0.24, true), "BreakerRaised", Vector3(0.35, 1.3, -0.2), Vector3(4.2, 4.2, 4.2), time + 0.15, {"soft": 0.8, "hot": M.hot(PALE), "core": 0.4, "flow": 1.5, "add": 0.6}, {"initial": 0.1, "grow_time": 0.7, "fade_in": 0.15, "decay": 0.85, "face_camera": true})
	M.sparks(art, "breaker_gather", [CRIMSON, GOLD, PALE], 18, 0.3, 1.0, 0.5, 2.4, 0.12, 0.0, time + 0.1, Vector3.ZERO, -1.2, 32, 0.2, 1.8)
	var at := Vector3(point.x, 0, point.z)
	# Over the target: the crown that will be broken, on its sigil. It stays until the
	# execution (index 1, 0.46 s after the release) shatters it.
	var hold := time + 0.46 + 0.02
	var mark := K.extra(parent, at, hold + 0.6, "StarMark_" + ID, caster.global_position)
	if mark:
		K.put(mark, K.SOLID, _crown(), "BreakerCrown", Vector3.UP * (CROWN_Y + 0.9), Vector3(0.75, 0.85, 0.75), hold, {"rim_color": PALE, "rim": 0.6, "glow_color": Color("ff6070")}, {"initial": 0.2, "grow_time": 0.4, "fade_in": 0.12, "decay": 0.985, "spin": 0.9, "travel": Vector3.DOWN * 0.9})
		K.put(mark, K.FLAT, _sigil(), "BreakerSigil", Vector3.UP * 0.06, Vector3.ONE * 1.9, hold + 0.6, {"soft": 0.5, "hot": M.hot(CRIMSON, 0.8), "core": 0.5, "flick": 0.08, "add": 0.5}, {"initial": 0.3, "grow_time": 0.3, "fade_in": 0.08, "spin": -0.6, "decay": 0.85})
		K.put(mark, K.FLAT, K.glow_disc("breaker_halo", M.a(GOLD, 0.6), M.a(GOLD, 0.0)), "BreakerHalo", Vector3.UP * (CROWN_Y - 0.05), Vector3.ONE * 1.1, hold, {"soft": 0.6, "add": 0.8}, {"initial": 0.2, "grow_time": 0.5, "fade_in": 0.1, "decay": 0.95})
		mark._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, _skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	if index == 0:
		# The rising cut, across the target as the camera sees it.
		K.put(art, K.FLAT, _rising(), "BreakerRising", Vector3.ZERO, Vector3.ONE * 1.1, 0.5, {"sweep": 0.09, "tail": 4.0, "soft": 0.7, "hot": M.hot(PALE), "core": 0.4, "add": 0.65, "gain": 1.1}, {"fade_in": 0.01, "decay": 0.5, "face_camera": true})
		M.sparks(art, "breaker_cut_sparks", [CRIMSON, GOLD, PALE], 26, 0.1, 0.6, 4.5, 3.5, 0.15, 0.0, 0.7, Vector3.UP * 0.4, 7.0, 33, 0.6, 1.8)
		M.flash(art, "breaker_flash", RUBY, 1.4, 0.0, 0.3)
		M.shock(art, "breaker_ring_a", CRIMSON, 2.4, 0.0, 0.4, 0.14)
		return true
	# The execution: a towering cleave falls through the target and the crown bursts.
	K.put(art, K.FLAT, _blade("breaker_fall", 1.0, 0.3), "BreakerExecution", Vector3.ZERO, Vector3(6.5, 6.5, 6.5), 0.6, {"sweep": 0.08, "tail": 5.0, "soft": 0.7, "hot": M.hot(PALE), "core": 0.35, "add": 0.65, "gain": 1.2}, {"fade_in": 0.01, "decay": 0.45, "face_camera": true})
	K.put(art, K.BITS, _shatter(), "BreakerShatter", Vector3.UP * CROWN_Y, Vector3.ONE, 1.4, {"life": 1.2, "gravity": 15.0, "piece": 0.6, "floor_y": 0.08 - CROWN_Y, "shrink": 0.85, "spin": 8.0, "hot": Color(1.0, 0.85, 0.4, 0.5)}, {"decay": 0.85})
	M.cracks(art, "breaker_cracks", CRIMSON, 3.4, 0.03, 1.4, 8, 34)
	M.shock(art, "breaker_ring_b", CRIMSON, 4.2, 0.03, 0.5, 0.18)
	M.rubble(art, "breaker_rubble", [ROCK, ROCK.lightened(0.15), ROCK.darkened(0.2)], 18, 0.2, 1.3, 4.0, 6.0, 0.3, 0.03, 1.2, Vector3.ZERO, 35)
	M.sparks(art, "breaker_exec_sparks", [CRIMSON, GOLD, PALE, RUBY], 34, 0.2, 1.4, 3.5, 5.0, 0.17, 0.02, 1.0, Vector3.UP * 0.5, 5.0, 36, 0.2, 2.5)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	# The aftermath: a glowing split where it struck and a ring of crimson light.
	var scar := K.extra(parent, Vector3(point.x, 0, point.z), 1.6, "StarScar_" + ID, source)
	if scar:
		M.flash(scar, "breaker_flash_b", RUBY, 2.2, 0.0, 0.35)
		M.pillar(scar, "breaker_pillar", CRIMSON, 1.6, 6.0, 0.0, 0.45)
		M.dust(scar, "breaker_dust", Color("c2a083"), 14, 0.5, 1.8, 0.05, 1.2, Vector3.ZERO, 0.9, 37)
		scar._draw()
	return true
