extends RefCounted
## Lancer 200 stars "Worldsplitter": the lance that splits the world. Wind-up: a colossal lance
## of violet light rises point-down over the lancer while fault lines glow through a rune
## circle on the ground. Three rifts: each beat tears a fissure out from the lancer in a new
## direction, molten violet-gold light in it, slabs of rock heaving up along both lips and
## stone thrown into the air. The fourth: the colossal lance drives down into the centre;
## the whole circle splits along every fault, a crater of slabs heaves up round the shaft,
## a column of light and two shockwaves roll out. Violet, gold and dark stone.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const VIOLET := Color("8a5cff")
const GOLD := Color("ffd88a")
const NIGHT := Color("2e1b5e")
const STONE := Color("5a4f62")
const ROCK := Color("4a4250")
const ID := "worldsplitter"
const GIANT := 7.5
## The direction of each rift, from the lancer's facing (+Z).
const RIFTS := [0.0, 2.2, -2.2]


static func _giant() -> ArrayMesh:
	if M.has("splitter_giant"):
		return M.get_mesh("splitter_giant")
	var st := K.begin()
	var part := M.lance(NIGHT.lightened(0.15), Color("c8b8ff"), GOLD)
	K.stamp(st, part, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 1.0, 0)))
	return M.keep("splitter_giant", K.finish(st, Vector3(0.5, 30.0, 0.5)))


## The rune circle with its fault lines (radius 1).
static func _runes() -> ArrayMesh:
	if M.has("splitter_runes"):
		return M.get_mesh("splitter_runes")
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.ring(st, 1.0, 0.025, M.a(VIOLET, 1.0), 0.0, 72)
	K.ring(st, 0.9, 0.012, M.a(GOLD, 0.8), 0.0, 72)
	for i in 16:
		var ang := TAU * float(i) / 16.0
		var dir := Vector3(sin(ang), 0, cos(ang))
		var side := Vector3(cos(ang), 0, -sin(ang))
		var c := dir * 0.95
		K.ribbon(st, PackedVector3Array([c - side * 0.03, c + dir * 0.03, c + side * 0.03, c - dir * 0.03, c - side * 0.03]), 0.012, M.a(GOLD, 0.9), 0.0, 0.0, Vector3.UP, 0.0)
	K.crack_star(st, rng, Vector3.ZERO, 9, 0.05, 0.88, 0.03, M.a(VIOLET, 0.9), 0.0, 1, 0.3)
	return M.keep("splitter_runes", K.finish(st, Vector3.ONE * 0.2, false))


## One rift along +Z from the centre, 1 long: [molten fissure FLAT, slabs SOLID, stone BITS].
static func _rift() -> Array:
	if M._m.has("splitter_rift"):
		return M._m["splitter_rift"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 92
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	for i in 15:
		var t := float(i) / 14.0
		pts.append(Vector3(sin(t * 9.0) * 0.25 + rng.randf_range(-0.1, 0.1), 0.0, 0.5 + t * 9.5))
	K.ribbon(flat, pts, 2.6, M.a(VIOLET, 0.7), 0.0, 0.0, Vector3.UP, 1.0)
	K.ribbon(flat, pts, 1.1, M.a(GOLD, 0.95), 0.0, 0.0, Vector3.UP, 1.0)
	K.ribbon(flat, pts, 0.32, Color(0.08, 0.03, 0.12, 1.0), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	var solid := K.begin()
	var bits := SurfaceTool.new()
	bits.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9:
		var t := (float(i) + 0.5) / 9.0
		var at := pts[int(t * 14.0)]
		for s in [-1.0, 1.0]:
			var lip := at + Vector3(s * rng.randf_range(0.7, 1.1), 0, rng.randf_range(-0.3, 0.3))
			var size := rng.randf_range(0.9, 1.6) * (1.2 - t * 0.5)
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, s * rng.randf_range(0.25, 0.55))).scaled(Vector3(size * 0.9, size * 1.5, size * 0.9))
			K.stamp(solid, K.spike(rng, STONE if i % 2 == 0 else ROCK, 0.25), Transform3D(basis, lip + Vector3.DOWN * 0.15), t * 0.18, 1.0)
		K.burst_at(bits, rng, "rock", 3, at, 0.2, 0.9, 3.0, 6.0, [ROCK, STONE, ROCK.lightened(0.15)], 0.32, t * 0.18, 0.05)
		K.burst_at(bits, rng, "ember", 3, at, 0.0, 0.5, 1.5, 5.5, [VIOLET.lightened(0.3), GOLD], 0.14, t * 0.18, 0.08)
	var out := [K.finish(flat, Vector3.ONE * 0.5, false), K.finish(solid, Vector3(1.0, 4.0, 1.0)), K.finish(bits, Vector3(8, 8, 8), false)]
	M._m["splitter_rift"] = out
	return out


## The crater round the shaft: a ring of heaved slabs (radius 1).
static func _crater() -> ArrayMesh:
	if M.has("splitter_crater"):
		return M.get_mesh("splitter_crater")
	var rng := RandomNumberGenerator.new()
	rng.seed = 93
	var st := K.begin()
	for i in 14:
		var ang := TAU * float(i) / 14.0 + rng.randf_range(-0.1, 0.1)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var size := rng.randf_range(0.5, 0.85)
		var basis := Basis(Vector3(dir.z, 0, -dir.x), -rng.randf_range(0.5, 0.9)) * Basis(Vector3.UP, ang)
		K.stamp(st, K.rock(rng, STONE if i % 2 == 0 else ROCK), Transform3D(basis.scaled(Vector3(size * 1.4, size * 0.7, size)), dir * rng.randf_range(0.85, 1.05)), 0.01 * float(i), 1.0)
	return M.keep("splitter_crater", K.finish(st, Vector3(1.0, 3.0, 1.0)))


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, _point: Vector3, time: float) -> bool:
	var r := clampf(float(skill.get("radius", 10.0)), 4.0, 10.0)
	var parent := art.get_parent() as Node3D
	# The ground answers first: the rune circle and its faults, glowing.
	K.put(art, K.FLAT, _runes(), "SplitterRunes", Vector3.UP * 0.06, Vector3.ONE * r, time + 1.9, {"sweep": time * 0.7, "soft": 0.45, "hot": M.hot(VIOLET, 0.8), "core": 0.5, "flick": 0.1, "add": 0.5}, {"initial": 0.8, "grow_time": 0.4, "fade_in": 0.06, "decay": 0.9})
	M.sparks(art, "splitter_rise", [VIOLET.lightened(0.3), GOLD], 30, 0.5, r * 0.7, 0.2, 2.5, 0.13, 0.0, time + 0.3, Vector3.ZERO, -1.2, 94, 0.05, 0.3)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	# The colossal lance takes shape over the lancer, point down, until the finale drives it.
	var sky := K.extra(parent, caster.global_position * Vector3(1, 0, 1), time + 1.3, "StarSky_" + ID, caster.global_position)
	if sky:
		var room := K.sky(sky, Vector3.ZERO, 14.0)
		var tall := minf(GIANT, room * 0.62)
		K.put(sky, K.SOLID, _giant(), "SplitterGiant", Vector3.UP * maxf(2.6, room - tall * 1.05), Vector3(tall * 3.2, tall, tall * 3.2), time + 1.3, {"drop": 3.0, "flight": time * 0.8, "ease": 1.0, "rim_color": GOLD, "rim": 0.8, "glow_color": GOLD}, {"fade_in": 0.2, "decay": 0.985, "spin": 0.6})
		M.pillar(sky, "splitter_aura", VIOLET, 1.2, room, 0.0, time + 1.3)
		sky._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := clampf(float(skill.get("radius", 10.0)), 4.0, 10.0)
	if index < 3:
		var rift := _rift()
		var yaw := Vector3(0, float(RIFTS[index]), 0)
		var scale := Vector3.ONE * (r / 10.0)
		K.put(art, K.FLAT, rift[0], "SplitterRift", Vector3.UP * 0.07, scale, 2.6 - 0.4 * float(index), {"sweep": 0.18, "soft": 0.5, "hot": M.hot(GOLD), "core": 0.4, "flick": 0.1, "flow": 1.0, "add": 0.65, "gain": 1.1}, {"decay": 0.8}, yaw)
		K.put(art, K.SOLID, rift[1], "SplitterSlabs", Vector3.ZERO, scale, 2.5 - 0.4 * float(index), {"drop": -2.2, "flight": 0.22, "ease": 1.0, "rim_color": VIOLET, "rim": 0.6, "glow_color": GOLD, "heat": 0.5}, {"decay": 0.85}, yaw)
		K.put(art, K.BITS, rift[2], "SplitterStone", Vector3.ZERO, scale, 1.5, {"life": 1.2, "gravity": 17.0, "piece": 0.32, "floor_y": 0.06, "shrink": 0.8, "spin": 7.0, "hot": Color(0.8, 0.6, 1.0, 0.4)}, {"decay": 0.9}, yaw)
		M.shock(art, "splitter_ring_%d" % index, VIOLET, 3.0 + float(index), 0.0, 0.4, 0.18)
		return true
	# The fourth: the colossal lance drives down, the whole circle splits.
	var flight := 0.18
	K.put(art, K.SOLID, _giant(), "SplitterImpale", Vector3.DOWN * 1.2, Vector3(GIANT * 3.2, GIANT, GIANT * 3.2), 1.8, {"drop": 22.0 / GIANT, "flight": flight, "heat": 0.7, "rim_color": GOLD, "rim": 0.9, "glow_color": GOLD}, {"decay": 0.8})
	M.cracks(art, "splitter_fissures", VIOLET, r * 1.05, flight, 2.0, 11, 95)
	K.put(art, K.SOLID, _crater(), "SplitterCrater", Vector3.ZERO, Vector3(2.4, 2.0, 2.4), 1.9, {"drop": -1.4, "flight": 0.2, "ease": 1.0, "rim_color": VIOLET, "rim": 0.5, "glow_color": GOLD, "heat": 0.6}, {"delay": flight, "decay": 0.85})
	M.shock(art, "splitter_big_ring", VIOLET, r * 1.25, flight, 0.7, 0.16)
	M.rubble(art, "splitter_rubble", [ROCK, STONE, ROCK.lightened(0.15)], 40, 0.6, 2.4, 7.5, 10.0, 0.5, flight, 2.0, Vector3.ZERO, 96)
	M.pillar(art, "splitter_column", VIOLET, 2.4, 12.0, flight, 0.8)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var after := K.extra(parent, Vector3(point.x, 0, point.z), 2.2, "StarAfter_" + ID, source)
	if after:
		M.shock(after, "splitter_big_ring_b", GOLD, r * 0.85, flight + 0.12, 0.7, 0.22)
		M.sparks(after, "splitter_embers", [VIOLET.lightened(0.3), GOLD, Color("ff9ae0")], 60, 0.5, r * 0.75, 1.0, 4.0, 0.18, flight, 2.0, Vector3.ZERO, -1.0, 97, 0.1, 1.2)
		M.dust(after, "splitter_dust", Color("8c8094"), 22, 1.0, 3.5, flight, 1.8, Vector3.ZERO, 1.2, 98)
		after._draw()
	return true
