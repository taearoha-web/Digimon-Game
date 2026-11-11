extends RefCounted
## Defender 200 stars "Heaven's Bulwark": the rampart of heaven falls. Wind-up (the defender
## rises on the wings): the seal of the bulwark draws itself over the field and a colossal
## winged shield of light forms in the sky over it. Three waves: shields of light, three at a
## time, slam down on an arc round the far side of the field, each with a quake, fissures and
## thrown stone. The fourth: the winged colossus crashes into the centre: a great quake,
## a ring of light-pillars round the field, fissures everywhere and a wall of dust; the
## stunned enemies are left facing the defender. Sky blue, warm white and gold.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const SKY_BLUE := Color("8fd0ff")
const BLUE := Color("3f7fe0")
const WHITE := Color("fffbe8")
const GOLD := Color("ffd25a")
const NAVY := Color("2a3f8a")
const ROCK := Color("6b5a4c")
const STONE := Color("8d93a2")
const ID := "heavens_bulwark"
const COLOSSUS := 5.6


## The colossus: a shield with a pair of feathered wings, facing +Z, 1 tall.
static func _colossus() -> ArrayMesh:
	if M.has("bulwark_colossus"):
		return M.get_mesh("bulwark_colossus")
	var st := K.begin()
	K.stamp(st, M.shield(BLUE, GOLD, WHITE))
	var wing := K.Part.new()
	for k in 6:
		var t := float(k) / 5.0
		wing.ink(WHITE.lerp(SKY_BLUE, t * 0.6), 0.6)
		var root := Vector3(0.36, 0.7 - t * 0.28, -0.04)
		var tip := Vector3(0.65 + 0.55 * cos(t * 1.1), 0.95 - t * 0.75, -0.06)
		wing.tube(root, tip, 0.07, 0.0, 4, 0.25)
	wing.ink(GOLD, 1.0)
	wing.tube(Vector3(0.36, 0.72, -0.04), Vector3(1.2, 1.0, -0.06), 0.035, 0.012, 4)
	K.stamp(st, wing)
	K.stamp(st, wing, Transform3D(Basis().scaled(Vector3(-1, 1, 1)), Vector3.ZERO))
	return M.keep("bulwark_colossus", K.finish(st, Vector3(1, 30, 1)))


## Three shields of light slamming down on an arc at radius 1, beyond the fight as the camera
## sees it (one SOLID mesh).
static func _trio() -> ArrayMesh:
	if M.has("bulwark_trio"):
		return M.get_mesh("bulwark_trio")
	var st := K.begin()
	var part := M.shield(Color("6aa8ff"), GOLD, WHITE)
	for i in 3:
		var ang := (float(i) - 1.0) * 1.05
		var at := Vector3(sin(ang), 0, cos(ang)) * 0.55
		K.stamp(st, part, Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * 0.5), at + Vector3.DOWN * 0.05), 0.05 * float(i), 1.0)
	return M.keep("bulwark_trio", K.finish(st, Vector3(1, 30, 1)))


## Quakes, fissures and dust under the three shields: [light FLAT, stone BITS].
static func _trio_ground() -> Array:
	if M._m.has("bulwark_trio_ground"):
		return M._m["bulwark_trio_ground"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 131
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bits := SurfaceTool.new()
	bits.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var ang := (float(i) - 1.0) * 1.05
		var at := Vector3(sin(ang), 0, cos(ang)) * 0.55
		var delay := 0.05 * float(i) + 0.1
		K.disc(flat, 0.2, M.a(SKY_BLUE, 0.9), 0.07, 16, delay, Vector3.UP, at, M.a(SKY_BLUE, 0.0), -1.0)
		K.crack_star(flat, rng, at + Vector3.UP * 0.06, 6, 0.02, 0.24, 0.02, Color(0.06, 0.08, 0.16, 1.0), delay, 1, 0.25)
		K.burst_at(bits, rng, "rock", 6, at, 0.0, 0.1, 0.35, 0.6, [ROCK, STONE], 0.035, delay, 0.03)
	var out := [K.finish(flat, Vector3.ONE * 0.2, false), K.finish(bits, Vector3(2, 2, 2), false)]
	M._m["bulwark_trio_ground"] = out
	return out


## The seal of the bulwark (radius 1): rings and a crown of shield glyphs.
static func _seal() -> ArrayMesh:
	if M.has("bulwark_seal"):
		return M.get_mesh("bulwark_seal")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.0, M.a(NAVY, 0.3), 0.0, 48, 0.0, Vector3.UP, Vector3.ZERO, M.a(NAVY, 0.0), 0.0, true)
	K.ring(st, 1.0, 0.03, M.a(SKY_BLUE, 1.0), 0.002, 80)
	K.ring(st, 0.94, 0.012, M.a(GOLD, 0.9), 0.002, 80)
	K.ring(st, 0.45, 0.02, M.a(SKY_BLUE, 0.9), 0.002, 64)
	for i in 12:
		var ang := TAU * float(i) / 12.0
		var dir := Vector3(sin(ang), 0.004, cos(ang))
		var side := Vector3(cos(ang), 0, -sin(ang))
		var c := dir * 0.78
		K.ribbon(st, PackedVector3Array([c - side * 0.05 + dir * 0.05, c + side * 0.05 + dir * 0.05, c + side * 0.045 - dir * 0.01, c - dir * 0.07, c - side * 0.045 - dir * 0.01, c - side * 0.05 + dir * 0.05]), 0.016, M.a(GOLD, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
		K.ribbon(st, PackedVector3Array([dir * 0.46, dir * 0.66]), 0.012, M.a(WHITE, 0.7), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("bulwark_seal", K.finish(st, Vector3.ONE * 0.2, false))


## Pillars of light round the field (radius 1).
static func _pillars() -> ArrayMesh:
	if M.has("bulwark_pillars"):
		return M.get_mesh("bulwark_pillars")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var ang := TAU * float(i) / 10.0
		var at := Vector3(sin(ang), 0, cos(ang)) * 0.85
		K.beam(st, at, 0.9, 0.09, M.a(SKY_BLUE, 0.8), 2, 0.025 * float(i), 0.0, 0.03)
		K.disc(st, 0.1, M.a(WHITE, 0.85), 0.01, 12, 0.025 * float(i), Vector3.UP, at, M.a(SKY_BLUE, 0.0), -1.0)
	return M.keep("bulwark_pillars", K.finish(st, Vector3.ONE * 0.2, false))


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := clampf(float(skill.get("radius", 10.0)), 4.0, 10.0)
	var parent := art.get_parent() as Node3D
	var center := Vector3(point.x, 0, point.z)
	var hold := time + 1.2 + 0.6
	var ground := K.extra(parent, center, hold, "StarGround_" + ID, caster.global_position)
	if ground:
		K.put(ground, K.FLAT, _seal(), "BulwarkSeal", Vector3.UP * 0.06, Vector3.ONE * r, hold, {"sweep": time * 0.6, "soft": 0.45, "hot": M.hot(SKY_BLUE, 0.8), "core": 0.5, "flick": 0.05, "add": 0.5}, {"initial": 0.7, "grow_time": 0.5, "fade_in": 0.08, "spin": -0.1, "decay": 0.9})
		M.sparks(ground, "bulwark_rise", [SKY_BLUE, WHITE, GOLD], 30, 1.0, r * 0.9, 0.2, 3.0, 0.13, 0.0, time + 0.2, Vector3.ZERO, -1.4, 132, 0.05, 0.3)
		ground._draw()
	M.sparks(art, "bulwark_lift", [SKY_BLUE, WHITE], 20, 0.2, 1.1, 0.5, 3.5, 0.12, 0.0, 1.3, Vector3.ZERO, -2.0, 133, 0.1, 1.0)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	# The colossus forms in the sky, behind the defender as the camera sees it.
	var sky := K.extra(parent, center, time + 1.2 + 0.02, "StarSky_" + ID, caster.global_position)
	if sky:
		var spot := K.beyond(sky, 5.0)
		var room := K.sky(sky, spot, 13.0)
		var tall := minf(COLOSSUS, room * 0.55)
		K.put(sky, K.SOLID, _colossus(), "BulwarkColossus", spot + Vector3.UP * (room - tall * 1.05), Vector3.ONE * tall, time + 1.22, {"drop": 1.2, "flight": time * 0.8, "ease": 1.0, "rim_color": WHITE, "rim": 0.8, "glow_color": WHITE}, {"initial": 0.4, "grow_time": 0.6, "fade_in": 0.2, "decay": 0.99}, Vector3(-0.35, K.facing(sky), 0))
		K.put(sky, K.FLAT, K.glow_disc("bulwark_halo", M.a(SKY_BLUE, 0.55), M.a(SKY_BLUE, 0.0)), "BulwarkHalo", spot + Vector3.UP * (room - tall * 0.5) - K.away(sky) * -0.6, Vector3.ONE * tall * 0.9, time + 1.22, {"soft": 0.6, "add": 0.8, "flick": 0.05}, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.95, "face_camera": true}, Vector3(PI * 0.5, 0, 0))
		sky._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := clampf(float(skill.get("radius", 10.0)), 4.0, 10.0)
	if index < 3:
		# The three land on an arc beyond the fight as the camera sees it, swinging a little
		# further round each wave: none lands between the camera and the fight.
		var yaw := Vector3(0, K.facing(art) + PI + [0.0, 0.5, -0.5][index], 0)
		var spread := r * (0.6 + 0.15 * float(index))
		var ground := _trio_ground()
		K.put(art, K.SOLID, _trio(), "BulwarkTrio", Vector3.ZERO, Vector3.ONE * spread, 0.9, {"drop": 9.0 / spread, "flight": 0.1, "heat": 0.6, "rim_color": WHITE, "rim": 0.7, "glow_color": WHITE}, {"decay": 0.7}, yaw)
		K.put(art, K.FLAT, ground[0], "BulwarkTrioLight", Vector3.ZERO, Vector3.ONE * spread, 1.2, {"sweep": 0.15, "soft": 0.5, "hot": M.hot(SKY_BLUE), "core": 0.4, "add": 0.6, "flash": 0.35}, {"decay": 0.7}, yaw)
		K.put(art, K.BITS, ground[1], "BulwarkTrioStone", Vector3.ZERO, Vector3.ONE * spread, 1.3, {"life": 1.0, "gravity": 18.0 / spread, "piece": 0.035, "floor_y": 0.06 / spread, "shrink": 0.8, "spin": 7.0}, {"decay": 0.9}, yaw)
		M.shock(art, "bulwark_quake_%d" % index, SKY_BLUE, r * (0.7 + 0.2 * float(index)), 0.1, 0.5, 0.14)
		return true
	# The colossus crashes into the centre.
	var flight := 0.16
	var tall := COLOSSUS
	K.put(art, K.SOLID, _colossus(), "BulwarkCrash", K.beyond(art, 4.5) + Vector3.DOWN * 0.3, Vector3.ONE * tall, 1.9, {"drop": 14.0 / tall, "flight": flight, "heat": 0.7, "rim_color": WHITE, "rim": 0.9, "glow_color": WHITE}, {"decay": 0.8}, Vector3(-0.2, K.facing(art), 0))
	K.put(art, K.FLAT, _pillars(), "BulwarkPillars", Vector3.ZERO, Vector3(r, 9.0, r), 1.0, {"soft": 1.4, "hot": M.hot(WHITE, 0.8), "core": 0.6, "flow": 2.5, "add": 0.7}, {"delay": flight, "initial": 0.5, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.35})
	M.cracks(art, "bulwark_fissures", BLUE, r * 1.05, flight, 2.0, 12, 134)
	M.shock(art, "bulwark_big_quake", SKY_BLUE, r * 1.3, flight, 0.75, 0.16)
	M.rubble(art, "bulwark_rubble", [ROCK, STONE, ROCK.darkened(0.2)], 40, 0.8, 3.0, 7.0, 9.0, 0.45, flight, 1.9, Vector3.ZERO, 135)
	M.dust(art, "bulwark_dust", Color("b8b4ae"), 26, 2.0, 5.5, flight, 1.8, Vector3.ZERO, 1.4, 136)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var after := K.extra(parent, Vector3(point.x, 0, point.z), 2.2, "StarAfter_" + ID, source)
	if after:
		M.shock(after, "bulwark_big_quake_b", GOLD, r * 0.9, flight + 0.12, 0.7, 0.22)
		M.sparks(after, "bulwark_motes", [SKY_BLUE, WHITE, GOLD], 50, 0.5, r * 0.85, 0.6, 3.0, 0.15, flight, 2.0, Vector3.ZERO, -0.8, 137, 0.1, 1.5)
		M.flash(after, "bulwark_floor", SKY_BLUE, r * 0.6, flight, 0.6)
		after._draw()
	return true
