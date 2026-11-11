extends RefCounted
## Defender 100 stars "Judgment Rebound": the shield of judgment, thrown three times. Wind-up:
## the seal of judgment (a gold ring round the scales of justice) is struck on the ground
## over the target and the defender's shield flares gold. Each throw: the defender's own
## shield spins across on a gold comet tail and rings off the target with a clang of light,
## sparks and a ring; the second and third land harder. The third is the verdict: a column of
## judgment crashes down on the seal, which stamps itself into the ground and cracks it.
## Gold, warm white and bronze.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const GOLD := Color("ffd23a")
const PALE := Color("fff5c8")
const AMBER := Color("ffb02a")
const BRONZE := Color("5a4a10")
const ROCK := Color("6b5a4c")
const ID := "judgment_rebound"
static var _shield: Mesh


## The seal of judgment (radius 1): a gold double ring and the scales of justice.
static func _seal() -> ArrayMesh:
	if M.has("rebound_seal"):
		return M.get_mesh("rebound_seal")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.0, M.a(BRONZE, 0.35), 0.0, 40, 0.0, Vector3.UP, Vector3.ZERO, M.a(BRONZE, 0.0), 0.0, true)
	K.ring(st, 1.0, 0.045, M.a(GOLD, 1.0), 0.002, 72)
	K.ring(st, 0.9, 0.02, M.a(PALE, 0.8), 0.002, 72)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var dir := Vector3(sin(ang), 0.003, cos(ang))
		K.ribbon(st, PackedVector3Array([dir * 0.9, dir * 1.0]), 0.05, M.a(GOLD, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	# The scales: a beam on a post, two pans hanging from it (drawn flat, +Z up the seal).
	var y := 0.004
	K.ribbon(st, PackedVector3Array([Vector3(0, y, -0.55), Vector3(0, y, 0.45)]), 0.05, M.a(GOLD, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	K.ribbon(st, PackedVector3Array([Vector3(-0.5, y, 0.38), Vector3(0.5, y, 0.38)]), 0.05, M.a(GOLD, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	for s in [-1.0, 1.0]:
		K.ribbon(st, PackedVector3Array([Vector3(s * 0.5, y, 0.38), Vector3(s * 0.32, y, -0.05)]), 0.02, M.a(PALE, 0.9), 0.0, 0.0, Vector3.UP, 0.0)
		K.ribbon(st, PackedVector3Array([Vector3(s * 0.5, y, 0.38), Vector3(s * 0.68, y, -0.05)]), 0.02, M.a(PALE, 0.9), 0.0, 0.0, Vector3.UP, 0.0)
		K.ribbon(st, M.arc(Vector3(s * 0.5, y, -0.05), 0.2, -PI * 0.5, PI * 0.5, 0.0, 0.0, 10), 0.05, M.a(GOLD, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	K.ribbon(st, PackedVector3Array([Vector3(-0.22, y, -0.55), Vector3(0.22, y, -0.55)]), 0.06, M.a(GOLD, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("rebound_seal", K.finish(st, Vector3.ONE * 0.2, false))


## The clang: spikes of light round a ring, in the XY plane.
static func _clang() -> ArrayMesh:
	if M.has("rebound_clang"):
		return M.get_mesh("rebound_clang")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := PackedVector3Array()
	for i in 41:
		var ang := TAU * float(i) / 40.0
		ring.append(Vector3(sin(ang), cos(ang), 0) * 0.42)
	K.ribbon(st, ring, 0.1, M.a(GOLD, 1.0), 0.0, 0.0, Vector3.BACK, 0.0)
	for i in 12:
		var ang := TAU * float(i) / 12.0 + 0.13
		var dir := Vector3(sin(ang), cos(ang), 0)
		K.ribbon(st, PackedVector3Array([dir * 0.5, dir * (1.0 if i % 2 == 0 else 0.75)]), 0.13, M.a(PALE if i % 2 == 0 else AMBER, 0.95), 0.0, 0.0, Vector3.BACK, 1.0)
	return M.keep("rebound_clang", K.finish(st, Vector3.ONE * 0.2, false))


## A comet tail along -Z from the origin (1 long).
static func _tail() -> ArrayMesh:
	if M.has("rebound_tail"):
		return M.get_mesh("rebound_tail")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for up in [Vector3.UP, Vector3.RIGHT]:
		K.ribbon(st, PackedVector3Array([Vector3(0, 0, 0.1), Vector3(0, 0, -0.4), Vector3(0, 0, -1.0)]), 1.0, M.a(GOLD, 0.95), 0.0, 0.0, up, 0.0, 0.0, 1.0, M.a(AMBER, 0.0))
	return M.keep("rebound_tail", K.finish(st, Vector3.ONE * 0.3, false))


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := clampf(float(skill.get("radius", 6.0)), 3.0, 8.0)
	var parent := art.get_parent() as Node3D
	_shield = StarSkillArt.equipped_sword(caster)
	StarSkillArt._recent_shield = _shield
	K.put(art, K.FLAT, K.glow_disc("rebound_flare", M.a(GOLD, 0.8), M.a(AMBER, 0.0)), "ReboundFlare", Vector3(0.2, 1.3, 0.5), Vector3.ONE * 1.1, time + 0.05, {"soft": 0.6, "add": 0.8, "flick": 0.15}, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.1, "decay": 0.9, "face_camera": true}, Vector3(PI * 0.5, 0, 0))
	M.sparks(art, "rebound_gather", [GOLD, PALE], 16, 0.2, 0.9, 0.4, 2.2, 0.12, 0.0, time, Vector3.ZERO, -1.0, 111, 0.4, 1.6)
	# The seal stays under the target through the three throws (the third stamps it).
	var hold := time + 0.6 + 0.28 + 0.05
	var mark := K.extra(parent, Vector3(point.x, 0, point.z), hold, "StarMark_" + ID, caster.global_position)
	if mark:
		K.put(mark, K.FLAT, _seal(), "ReboundSeal", Vector3.UP * 0.06, Vector3.ONE * r * 0.5, hold, {"sweep": time * 0.6, "soft": 0.45, "hot": M.hot(GOLD, 0.5), "core": 0.6, "flick": 0.06, "add": 0.4, "gain": 0.75}, {"initial": 1.6, "grow_time": 0.35, "fade_in": 0.08, "decay": 0.92}, Vector3(0, K.facing(mark) + PI, 0))
		M.area(mark, "rebound_area", GOLD, r, hold, 0.3)
		mark._draw()
	return true


## The defender's own shield, spinning across on a gold comet tail.
static func launch(art: StarSkillArt, caster: Node3D, _skill: Dictionary, point: Vector3, duration: float) -> bool:
	if is_instance_valid(caster):
		_shield = StarSkillArt.equipped_sword(caster)
	var mesh := _shield if _shield else MartialGeometry.mesh("blade")
	var travel := art.global_basis.inverse() * (point - art.global_position)
	K.put(art, K.SOLID, mesh, "ReboundShield", Vector3.ZERO, Vector3.ONE * 1.35, duration, {"remap": 1.0, "tone_a": Color("8a6a1a"), "tone_b": PALE, "rim_color": GOLD, "rim": 0.9}, {"travel": travel, "fade_in": 0.01, "decay": 0.97, "spin": 18.0}, Vector3(-PI * 0.5, 0, 0))
	K.put(art, K.FLAT, _tail(), "ReboundTail", Vector3.ZERO, Vector3(0.9, 0.9, 2.6), duration, {"soft": 1.0, "hot": M.hot(PALE), "core": 0.5, "add": 0.7}, {"travel": travel, "initial": 0.4, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.9})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := clampf(float(skill.get("radius", 6.0)), 3.0, 8.0)
	var power := 0.75 + 0.2 * float(index)
	# The clang where the shield rings off the target.
	K.put(art, K.FLAT, _clang(), "ReboundClang", Vector3(0, 1.3, -0.3), Vector3.ONE * 1.8 * power, 0.3, {"soft": 0.7, "hot": M.hot(PALE), "core": 0.4, "add": 0.75}, {"initial": 0.3, "grow_time": 0.25, "fade_in": 0.01, "decay": 0.35, "face_camera": true})
	M.shock(art, "rebound_ring", GOLD, r * (0.55 + 0.25 * float(index)), 0.0, 0.45, 0.18)
	M.sparks(art, "rebound_sparks", [GOLD, PALE, AMBER], 20, 0.1, 0.6, 4.5, 4.0, 0.14, 0.0, 0.7, Vector3.UP * 0.8, 7.0, 112 + index, -0.3, 0.6)
	if index < 2:
		M.flash(art, "rebound_flash", AMBER, 2.0 * power, 0.0, 0.3)
		return true
	# The verdict: a column of judgment crashes down and the seal stamps into the ground.
	M.pillar(art, "rebound_verdict", GOLD, 2.4, 11.0, 0.0, 0.6)
	K.put(art, K.FLAT, _seal(), "ReboundStamp", Vector3.UP * 0.08, Vector3.ONE * r * 0.55, 1.3, {"soft": 0.4, "hot": M.hot(PALE), "core": 0.4, "add": 0.7, "gain": 1.2}, {"initial": 1.5, "grow_time": 0.12, "fade_in": 0.01, "decay": 0.6}, Vector3(0, K.facing(art) + PI, 0))
	M.cracks(art, "rebound_cracks", GOLD, r * 0.85, 0.02, 1.4, 9, 115)
	M.rubble(art, "rebound_rubble", [ROCK, ROCK.lightened(0.15)], 16, 0.4, 1.8, 4.0, 6.0, 0.3, 0.02, 1.2, Vector3.ZERO, 116)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var after := K.extra(parent, Vector3(point.x, 0, point.z), 1.6, "StarAfter_" + ID, source)
	if after:
		M.shock(after, "rebound_ring_big", AMBER, r * 1.2, 0.08, 0.6, 0.12)
		M.sparks(after, "rebound_motes", [GOLD, PALE], 30, 0.4, r * 0.7, 0.4, 2.5, 0.13, 0.05, 1.5, Vector3.ZERO, -0.8, 117, 0.1, 1.0)
		after._draw()
	return true
