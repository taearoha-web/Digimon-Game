extends RefCounted
## Warrior 200 stars "Celestial Swordfall": the heavens answer the king. Wind-up (the warrior
## rises on the wings): a celestial seal of gold and violet draws itself over the field, and
## high above it a wheel of ten spectral swords descends, points down, turning, while a
## halo of light follows the warrior up. The fall: ten copies of the warrior's own sword
## drop out of the wheel one after another, each on a gold streak; each lands in a burst of
## violet-gold light, splits the ground, throws stone and stands planted for a moment. The
## tenth lands under a ring of light that rolls across the whole field and a column of
## starlight. Gold, pale gold and royal violet.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const GOLD := Color("ffc83a")
const PALE := Color("fff0b8")
const VIOLET := Color("7a4cff")
const DEEP := Color("3a1f8a")
const ROCK := Color("6b5a4c")
const ID := "celestial_swordfall"
const SWORDS := 10
## Where the swords hang before they fall (StarSkillArt.sword_drop drops them from 9 m).
const SKY := 9.0
const WHEEL := 3.6
## The warrior's own sword (captured at the first drop), planted by every landing.
static var _sword: Mesh
## The field's centre (from the canopy), where the tenth landing's finale plays.
static var _center := Vector3.ZERO


## A spectral sword: point at the origin, hilt at +Y 1.
static func _ghost() -> ArrayMesh:
	if M.has("swordfall_ghost"):
		return M.get_mesh("swordfall_ghost")
	var p := K.Part.new()
	p.ink(PALE, 1.0)
	p.tube(Vector3.ZERO, Vector3(0, 0.16, 0), 0.0, 0.08, 4, 0.25, false)
	p.tube(Vector3(0, 0.16, 0), Vector3(0, 0.72, 0), 0.08, 0.065, 4, 0.25, false)
	p.ink(VIOLET, 0.0, 1.0)
	p.box(Vector3(0, 0.44, 0), Vector3(0.02, 0.48, 0.035))
	p.ink(GOLD, 0.9)
	p.box(Vector3(0, 0.74, 0), Vector3(0.3, 0.05, 0.06))
	p.tube(Vector3(0, 0.76, 0), Vector3(0, 0.92, 0), 0.025, 0.02, 5)
	p.gem(Vector3(0, 0.97, 0), Vector3(0.05, 0.06, 0.05))
	var st := K.begin()
	for i in SWORDS:
		var ang := TAU * float(i) / float(SWORDS)
		var at := Vector3(sin(ang), 0, cos(ang)) * WHEEL
		# Point down, the flat of the blade towards the wheel's centre.
		K.stamp(st, p, Transform3D(Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, PI).scaled(Vector3.ONE * 2.4), at + Vector3.UP * 2.4), 0.05 * float(i), 1.0)
	return M.keep("swordfall_ghost", K.finish(st, Vector3(0.5, 6.0, 0.5)))


## The celestial seal on the ground (radius 1): rings, a ten-pointed star, runes.
static func _seal() -> ArrayMesh:
	if M.has("swordfall_seal"):
		return M.get_mesh("swordfall_seal")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.0, M.a(DEEP, 0.3), 0.0, 48, 0.0, Vector3.UP, Vector3.ZERO, M.a(DEEP, 0.0), 0.0, true)
	K.ring(st, 1.0, 0.03, M.a(GOLD, 1.0), 0.002, 80)
	K.ring(st, 0.93, 0.012, M.a(PALE, 0.8), 0.002, 80)
	K.ring(st, 0.52, 0.02, M.a(VIOLET, 1.0), 0.002, 64)
	var star := PackedVector3Array()
	for i in SWORDS * 2 + 1:
		var ang := TAU * float(i) / float(SWORDS * 2)
		var rad := 0.9 if i % 2 == 0 else 0.55
		star.append(Vector3(sin(ang), 0.003, cos(ang)) * rad)
	K.ribbon(st, star, 0.025, M.a(GOLD, 0.95), 0.0, 0.0, Vector3.UP, 0.0)
	for i in 30:
		var ang := TAU * float(i) / 30.0
		var dir := Vector3(sin(ang), 0.003, cos(ang))
		var side := Vector3(cos(ang), 0, -sin(ang))
		K.ribbon(st, PackedVector3Array([dir * 0.95 - side * 0.015, dir * 0.95 + side * 0.015]), 0.04 if i % 3 == 0 else 0.02, M.a(PALE, 0.9), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("swordfall_seal", K.finish(st, Vector3.ONE * 0.2, false))


## The wheel in the sky the swords hang from (radius 1, level): a gold ring, a violet halo.
static func _wheel() -> ArrayMesh:
	if M.has("swordfall_wheel"):
		return M.get_mesh("swordfall_wheel")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.25, M.a(VIOLET, 0.35), 0.0, 48, 0.0, Vector3.UP, Vector3.ZERO, M.a(VIOLET, 0.0), 0.0, true)
	K.ring(st, 1.0, 0.07, M.a(GOLD, 1.0), 0.0, 72)
	K.ring(st, 0.84, 0.03, M.a(PALE, 0.8), 0.0, 72)
	for i in SWORDS:
		var ang := TAU * float(i) / float(SWORDS)
		var dir := Vector3(sin(ang), 0, cos(ang))
		K.ribbon(st, PackedVector3Array([dir * 0.3, dir * 1.0]), 0.04, M.a(GOLD, 0.8), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("swordfall_wheel", K.finish(st, Vector3.ONE * 0.2, false))


## The halo that follows the warrior up (radius 1, in the XY plane).
static func _halo() -> ArrayMesh:
	if M.has("swordfall_halo"):
		return M.get_mesh("swordfall_halo")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.0, M.a(GOLD, 0.35), 0.0, 32, 0.0, Vector3.BACK, Vector3(0, 0, -0.02), M.a(VIOLET, 0.0), 0.0, true)
	var rim := PackedVector3Array()
	for i in 49:
		var ang := TAU * float(i) / 48.0
		rim.append(Vector3(sin(ang), cos(ang), 0) * 0.82)
	K.ribbon(st, rim, 0.09, M.a(GOLD, 1.0), 0.0, 0.0, Vector3.BACK, 0.0)
	for i in 20:
		var ang := TAU * float(i) / 20.0
		var dir := Vector3(sin(ang), cos(ang), 0)
		K.ribbon(st, PackedVector3Array([dir * 0.9, dir * (1.35 if i % 2 == 0 else 1.1)]), 0.06, M.a(PALE, 0.9), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, M.a(GOLD, 0.0))
	return M.keep("swordfall_halo", K.finish(st, Vector3.ONE * 0.3, false))


## Rays of starlight across the field for the finale (radius 1).
static func _rays() -> ArrayMesh:
	if M.has("swordfall_rays"):
		return M.get_mesh("swordfall_rays")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 20:
		var ang := TAU * float(i) / 20.0
		var dir := Vector3(sin(ang), 0, cos(ang))
		K.ribbon(st, PackedVector3Array([dir * 0.08, dir * (1.0 if i % 2 == 0 else 0.7)]), 0.16 if i % 2 == 0 else 0.1, M.a(GOLD if i % 2 == 0 else VIOLET, 0.95), 0.0, 0.0, Vector3.UP, 1.0)
	return M.keep("swordfall_rays", K.finish(st, Vector3.ONE * 0.2, false))


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := clampf(float(skill.get("radius", 8.0)), 4.0, 9.0)
	var parent := art.get_parent() as Node3D
	_sword = StarSkillArt.equipped_sword(caster)
	_center = Vector3(point.x, 0, point.z)
	# The halo follows the warrior up into the sky (StarSkillSequence lifts 5 m in 1.15 s).
	K.put(art, K.FLAT, _halo(), "SwordfallHalo", Vector3(0, 1.7, -0.45), Vector3.ONE * 1.1, 1.15, {"soft": 0.7, "hot": M.hot(GOLD), "core": 0.5, "flick": 0.06, "add": 0.6}, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.1, "decay": 0.99, "face_camera": true, "travel": Vector3.UP * 4.6})
	var held := M.stage(art, time + 2.6, "StarStage_" + ID)
	K.put(held, K.FLAT, _halo(), "SwordfallHaloHeld", Vector3(0, 6.3, -0.45), Vector3.ONE * 1.1, time + 2.6, {"soft": 0.7, "hot": M.hot(GOLD), "core": 0.5, "flick": 0.06, "add": 0.6}, {"delay": 1.12, "fade_in": 0.02, "decay": 0.9, "face_camera": true, "spin": 0.0})
	M.sparks(art, "swordfall_lift", [GOLD, PALE, VIOLET.lightened(0.3)], 26, 0.2, 1.2, 0.6, 3.5, 0.13, 0.0, 1.3, Vector3.ZERO, -2.0, 51, 0.1, 1.0)
	var origin := caster.global_position
	var ground := K.extra(parent, _center, time + 3.4, "StarGround_" + ID, origin)
	if ground:
		K.put(ground, K.FLAT, _seal(), "SwordfallSeal", Vector3.UP * 0.06, Vector3.ONE * r, time + 3.4, {"sweep": time * 0.6, "soft": 0.45, "hot": M.hot(GOLD, 0.8), "core": 0.5, "flick": 0.05, "add": 0.5}, {"initial": 0.7, "grow_time": 0.5, "fade_in": 0.08, "spin": 0.1, "decay": 0.92})
		ground._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var sky := K.extra(parent, _center, time + 0.2, "StarSky_" + ID, origin)
	if sky:
		var top := minf(SKY, K.sky(sky, Vector3.ZERO, SKY) - 0.3)
		K.put(sky, K.SOLID, _ghost(), "SwordfallWheelSwords", Vector3.UP * (top - 2.4), Vector3.ONE, time + 0.2, {"drop": 6.0, "flight": time * 0.6, "ease": 1.0, "rim_color": GOLD, "rim": 0.8, "glow_color": Color("b89cff"), "dim": 0.95}, {"fade_in": 0.1, "spin": 0.5, "decay": 0.9})
		K.put(sky, K.FLAT, _wheel(), "SwordfallWheel", Vector3.UP * (top + 0.15), Vector3.ONE * WHEEL * 1.05, time + 0.2, {"soft": 0.6, "hot": M.hot(GOLD, 0.8), "core": 0.5, "add": 0.55}, {"initial": 0.2, "grow_time": 0.7, "fade_in": 0.15, "spin": 0.5, "decay": 0.9}, K.tipped(sky, 0.5))
		sky._draw()
	return true


## The sky over the field while the ten swords fall (StarSkillArt.sword_canopy).
static func canopy(parent: Node3D, point: Vector3, _radius: float, duration: float) -> StarSkillArt:
	if not VfxBudget.can_decorate():
		return null
	var art := StarSkillArt._root(parent, point, duration, "StarCanopy_" + ID)
	if not art:
		return null
	_center = Vector3(point.x, 0, point.z)
	var top := minf(SKY, K.sky(art, Vector3.ZERO, SKY) - 0.3)
	K.put(art, K.FLAT, _wheel(), "SwordfallCanopy", Vector3.UP * (top + 0.15), Vector3.ONE * WHEEL * 1.05, duration, {"soft": 0.6, "hot": M.hot(GOLD, 0.8), "core": 0.5, "flick": 0.05, "add": 0.55}, {"fade_in": 0.02, "spin": 0.5, "decay": 0.85}, K.tipped(art, 0.5))
	M.sparks(art, "swordfall_sky_motes", [GOLD, PALE, VIOLET.lightened(0.35)], 30, 0.5, WHEEL * 1.2, 0.3, -0.6, 0.14, 0.0, duration, Vector3.UP * (top - 0.5), 1.2, 52, 0.0, 0.6)
	art._draw()
	return art


## One of the ten swords falling onto [param point] in [param flight] s (StarSkillArt.sword_drop).
static func drop(caster: Node3D, parent: Node3D, point: Vector3, index: int, flight: float) -> StarSkillArt:
	if not is_instance_valid(parent) or not VfxBudget.can_decorate():
		return null
	var art := StarSkillArt._root(parent, point, flight + 0.05, "StarDrop_%s_%02d" % [ID, index])
	if not art:
		return null
	if is_instance_valid(caster):
		_sword = StarSkillArt.equipped_sword(caster)
	var mesh := _sword if _sword else MartialGeometry.mesh("blade")
	var height := minf(SKY, K.sky(art, Vector3.ZERO, SKY) - 0.3) - 1.0
	var pose := GodSkillArt._point_down(mesh, 3.0, 0.0)
	var yaw := float(index) * TAU / float(SWORDS)
	K.put(art, K.SOLID, mesh, "SwordfallBlade", pose[0] + Vector3.UP * height, pose[1], flight, {"remap": 1.0, "tone_a": Color("b07a10"), "tone_b": PALE, "rim_color": Color("c8b0ff"), "rim": 0.9}, {"travel": Vector3.DOWN * height, "accelerate": true, "fade_in": 0.02, "decay": 0.99}, Vector3(PI, yaw, 0))
	# Its streak of light, following it down.
	if not M.has("swordfall_streak"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		K.beam(st, Vector3.ZERO, 1.0, 0.5, M.a(GOLD, 0.85), 2, 0.0, 0.0, 0.05)
		M.keep("swordfall_streak", K.finish(st, Vector3.ONE * 0.2, false))
	K.put(art, K.FLAT, M.get_mesh("swordfall_streak"), "SwordfallStreak", Vector3.UP * (height + 2.6), Vector3(1.0, 4.0, 1.0), flight, {"soft": 1.4, "hot": M.hot(PALE), "core": 0.5, "add": 0.7}, {"travel": Vector3.DOWN * height, "accelerate": true, "fade_in": 0.05, "decay": 0.95})
	art._draw()
	return art


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, _point: Vector3, index: int, source: Vector3) -> bool:
	var last := index >= SWORDS - 1
	var mesh := _sword if _sword else MartialGeometry.mesh("blade")
	# The sword stands planted where it fell, white-hot for a moment, then fades.
	var pose := GodSkillArt._point_down(mesh, 3.0, -0.55)
	K.put(art, K.SOLID, mesh, "SwordfallPlanted", pose[0], pose[1], 1.0 if not last else 1.6, {"remap": 1.0, "tone_a": Color("b07a10"), "tone_b": PALE, "rim_color": Color("c8b0ff"), "rim": 0.9}, {"fade_in": 0.01, "decay": 0.7}, Vector3(PI, float(index) * TAU / float(SWORDS), 0.08))
	M.flash(art, "swordfall_land", VIOLET, 2.2, 0.0, 0.4)
	M.cracks(art, "swordfall_cracks", GOLD, 2.4, 0.0, 1.1, 6, 53)
	M.shock(art, "swordfall_ring", GOLD, 2.8, 0.0, 0.4, 0.16)
	M.rubble(art, "swordfall_rubble", [ROCK, ROCK.lightened(0.15), ROCK.darkened(0.2)], 8, 0.2, 0.8, 3.2, 5.5, 0.26, 0.0, 1.0, Vector3.ZERO, 54)
	M.sparks(art, "swordfall_sparks", [GOLD, PALE, VIOLET.lightened(0.3)], 16, 0.1, 0.6, 3.0, 4.0, 0.14, 0.0, 0.7, Vector3.ZERO, 6.0, 55)
	if not last or GodSkillArt.extra_roots(1) < 1:
		return true
	# The tenth: a ring of light rolls over the whole field, starlight rises from its centre.
	var r := clampf(float(skill.get("radius", 8.0)), 4.0, 9.0)
	var fin := K.extra(parent, _center, 2.0, "StarFinale_" + ID, source)
	if fin:
		K.put(fin, K.FLAT, _rays(), "SwordfallRays", Vector3.UP * 0.08, Vector3.ONE * r, 1.2, {"sweep": 0.25, "soft": 0.6, "hot": M.hot(GOLD, 0.6), "core": 0.7, "add": 0.65}, {"initial": 0.4, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.5})
		M.shock(fin, "swordfall_big_ring", GOLD, r * 1.25, 0.0, 0.8, 0.12)
		M.pillar(fin, "swordfall_pillar", VIOLET, 2.6, 11.0, 0.0, 0.8)
		M.shock(fin, "swordfall_big_ring_b", VIOLET, r * 0.9, 0.12, 0.7, 0.2)
		M.sparks(fin, "swordfall_stars", [GOLD, PALE, VIOLET.lightened(0.3)], 50, 0.5, r * 0.8, 0.6, 3.5, 0.16, 0.05, 1.8, Vector3.ZERO, -1.0, 56, 0.1, 1.5)
		fin._draw()
	return true
