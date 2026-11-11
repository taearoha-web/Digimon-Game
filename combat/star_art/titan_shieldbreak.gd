extends RefCounted
## Defender 50 stars "Titan Shieldbreak": the titan's shield comes down. Wind-up: a towering
## bronze titan shield heaves up over the defender's front, its shadow on the ground. Hit 1:
## it slams face-down into the ground ahead: a bronze quake ring, fissures and thrown stone.
## Hit 2: the ground breaks round the defender, a ring of rock spikes bursts up, dust rolls
## out and stars of the stun spin over the field. Bronze, amber and warm cream.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const BRONZE := Color("d9822a")
const AMBER := Color("ffa64a")
const CREAM := Color("fff2c8")
const DEEP := Color("6a3412")
const ROCK := Color("6b5a4c")
const STONE := Color("8a7a68")
const ID := "titan_shieldbreak"
const AHEAD := 1.9
const SIZE := 3.3


static func _titan() -> ArrayMesh:
	return M.solid("titan_shield", M.shield(BRONZE, Color("ffd27a"), CREAM), Vector3(1, 6, 1))


## Rock spikes breaking up in a ring round the defender (radius 1).
static func _spikes() -> ArrayMesh:
	if M.has("titan_spikes"):
		return M.get_mesh("titan_spikes")
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var st := K.begin()
	for i in 16:
		var ang := TAU * float(i) / 16.0 + rng.randf_range(-0.1, 0.1)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var size := rng.randf_range(0.35, 0.6)
		var basis := Basis(Vector3(dir.z, 0, -dir.x), -rng.randf_range(0.2, 0.45)).scaled(Vector3(size, size * rng.randf_range(1.6, 2.4), size))
		K.stamp(st, K.spike(rng, STONE if i % 2 == 0 else ROCK, 0.2), Transform3D(basis, dir * rng.randf_range(0.82, 1.0) + Vector3.DOWN * 0.1), 0.012 * float(i % 5), 1.0)
	return M.keep("titan_spikes", K.finish(st, Vector3(1, 3, 1)))


## Spinning stars of the stun (radius 1 ring of five stars, level).
static func _daze() -> ArrayMesh:
	if M.has("titan_daze"):
		return M.get_mesh("titan_daze")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var ang := TAU * float(i) / 5.0
		var c := Vector3(sin(ang), 0, cos(ang))
		var pts := PackedVector3Array()
		for k in 11:
			var a2 := TAU * float(k) / 10.0
			var rad := 0.22 if k % 2 == 0 else 0.09
			pts.append(c + Vector3(sin(a2) * rad, cos(a2) * rad, 0))
		K.ribbon(st, pts, 0.07, M.a(Color("ffe070"), 1.0), 0.0, 0.0, Vector3.BACK, 0.0)
	return M.keep("titan_daze", K.finish(st, Vector3.ONE * 0.3, false))


static func telegraph(art: StarSkillArt, _caster: Node3D, _skill: Dictionary, _point: Vector3, time: float) -> bool:
	# The titan shield heaves up over the defender's front, its shadow growing below it.
	K.put(art, K.SOLID, _titan(), "TitanRaise", Vector3(0, 1.0, AHEAD), Vector3.ONE * SIZE, time + 0.02, {"drop": -0.35, "flight": time * 0.9, "ease": 1.0, "rim_color": CREAM, "rim": 0.7, "glow_color": CREAM}, {"initial": 0.5, "grow_time": 0.5, "fade_in": 0.1, "decay": 0.99, "travel": Vector3.UP * 1.0}, Vector3(-0.25, 0, 0))
	K.put(art, K.FLAT, K.glow_disc("titan_shadow", Color(0.12, 0.05, 0.0, 0.55)), "TitanShadow", Vector3(0, 0.05, AHEAD + 0.4), Vector3(1.8, 1, 2.2), time + 0.05, {"soft": 0.8, "add": 0.0}, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.15, "decay": 0.95})
	M.area(art, "titan_area", AMBER, 7.0, time + 0.5, 0.3)
	M.sparks(art, "titan_gather", [AMBER, CREAM], 14, 0.2, 1.0, 0.4, 2.2, 0.12, 0.0, time, Vector3.ZERO, -1.0, 102, 0.3, 1.6)
	return true


static func strike(art: StarSkillArt, parent: Node3D, _skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	if index == 0:
		# Face-down into the ground ahead.
		var at := Vector3(0, 0.12, AHEAD)
		K.put(art, K.SOLID, _titan(), "TitanSlam", at + Vector3(0, 0, -SIZE * 0.45), Vector3.ONE * SIZE, 0.95, {"from": Vector3(0, 0, -0.9), "flight": 0.08, "heat": 0.6, "rim_color": CREAM, "rim": 0.6, "glow_color": Color("ffc070")}, {"fade_in": 0.01, "decay": 0.7}, Vector3(PI * 0.5, 0, 0))
		M.shock(art, "titan_quake", AMBER, 7.4, 0.05, 0.5, 0.2)
		M.cracks(art, "titan_cracks", AMBER, 4.2, 0.05, 1.2, 8, 103, 0.07)
		M.rubble(art, "titan_rubble", [ROCK, STONE, ROCK.darkened(0.2)], 20, 0.6, 2.2, 4.5, 6.0, 0.32, 0.05, 1.2, Vector3(0, 0, AHEAD), 104)
		M.dust(art, "titan_dust", Color("c9ad8a"), 16, 1.0, 2.6, 0.05, 1.2, Vector3(0, 0, AHEAD), 0.95, 105)
		return true
	# The ground breaks round the defender: spikes, a second quake, stars of the stun.
	K.put(art, K.SOLID, _spikes(), "TitanSpikes", Vector3.ZERO, Vector3(4.6, 1.7, 4.6), 1.3, {"drop": -1.2, "flight": 0.16, "ease": 1.0, "rim_color": AMBER, "rim": 0.45, "glow_color": AMBER, "heat": 0.4}, {"decay": 0.8})
	M.shock(art, "titan_quake_b", BRONZE, 8.2, 0.0, 0.6, 0.26)
	M.dust(art, "titan_dust_b", Color("c9ad8a"), 22, 3.0, 5.0, 0.0, 1.4, Vector3.ZERO, 1.1, 106)
	M.rubble(art, "titan_rubble_b", [ROCK, STONE], 22, 3.4, 5.0, 3.0, 5.5, 0.3, 0.0, 1.2, Vector3.ZERO, 107)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var daze := K.extra(parent, Vector3(point.x, 0, point.z), 1.6, "StarDaze_" + ID, source)
	if daze:
		K.put(daze, K.FLAT, _daze(), "TitanDaze", Vector3(0, 2.4, AHEAD + 1.4), Vector3.ONE * 0.9, 1.5, {"soft": 0.4, "hot": M.hot(Color("ffe070")), "core": 0.5, "add": 0.6}, {"initial": 0.4, "grow_time": 0.2, "fade_in": 0.05, "spin": 4.0, "decay": 0.75})
		M.cracks(daze, "titan_cracks_b", BRONZE, 6.5, 0.0, 1.4, 12, 108)
		daze._draw()
	return true
