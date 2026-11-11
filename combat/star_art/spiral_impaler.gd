extends RefCounted
## Lancer 50 stars "Spiral Impaler": a lance-thrust that drills a tunnel of wind. Wind-up: the
## lane the thrust will pierce lights up on the ground and a spiral of wind winds round the
## lance. Each of the three thrusts throws a spinning drill of cyan light down the lane on a
## corkscrew of wind; where the line is pierced, rings of pressure stand round it and the
## ground is scored along it. The third drives the corkscrew the whole length and bursts at
## its end. Cyan, ice white and deep sea blue.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const CYAN := Color("18d8ff")
const ICE := Color("bff6ff")
const SEA := Color("15468f")
const STEEL := Color("9fc4e8")
const ID := "spiral_impaler"


## The lane the line hits: two edges and a faint floor from 0 to 1 along +Z (width 1).
static func _lane() -> ArrayMesh:
	if M.has("impaler_lane"):
		return M.get_mesh("impaler_lane")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.ribbon(st, PackedVector3Array([Vector3(0, 0, 0.05), Vector3(0, 0, 1.0)]), 1.0, M.a(SEA, 0.35), 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	for s in [-0.5, 0.5]:
		K.ribbon(st, PackedVector3Array([Vector3(s, 0, 0.05), Vector3(s, 0, 1.0)]), 0.06, M.a(CYAN, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	for i in 8:
		var z := 0.12 + 0.11 * float(i)
		K.ribbon(st, PackedVector3Array([Vector3(-0.3, 0, z), Vector3(0, 0, z + 0.06), Vector3(0.3, 0, z)]), 0.04, M.a(ICE, 0.8), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("impaler_lane", K.finish(st, Vector3.ONE * 0.2, false))


## A corkscrew of wind along +Z from 0 to 1 (radius 1 round the axis), [param turns] turns.
static func _helix(key: String, turns: float, strands := 2, width := 0.22) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in strands:
		var pts := PackedVector3Array()
		var n := int(turns * 14.0)
		for i in n + 1:
			var t := float(i) / float(n)
			var ang := t * turns * TAU + TAU * float(s) / float(strands)
			var rad := lerpf(0.35, 1.0, minf(1.0, t * 4.0))
			pts.append(Vector3(cos(ang) * rad, sin(ang) * rad, t))
		var color := CYAN if s % 2 == 0 else ICE
		K.ribbon(st, pts, width, M.a(color, 0.9), 0.0, 0.0, Vector3.FORWARD, 0.4)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.5, false))


## The drill: a spiral-grooved cone pointing +Z, 1 long.
static func _drill() -> ArrayMesh:
	if M.has("impaler_drill"):
		return M.get_mesh("impaler_drill")
	var p := K.Part.new()
	p.ink(STEEL, 1.0)
	p.tube(Vector3.ZERO, Vector3(0, 0, 1.0), 0.3, 0.0, 8, 1.0, true)
	p.ink(CYAN, 0.0, 1.0)
	for k in 3:
		for i in 6:
			var t0 := float(i) / 6.0
			var t1 := float(i + 1) / 6.0
			var a0 := t0 * TAU * 1.2 + TAU * float(k) / 3.0
			var a1 := t1 * TAU * 1.2 + TAU * float(k) / 3.0
			var r0 := 0.31 * (1.0 - t0)
			var r1 := 0.31 * (1.0 - t1)
			p.tube(Vector3(cos(a0) * r0, sin(a0) * r0, t0), Vector3(cos(a1) * r1, sin(a1) * r1, t1), 0.04 * (1.0 - t0) + 0.01, 0.04 * (1.0 - t1) + 0.01, 3)
	p.ink(SEA, 0.4)
	p.tube(Vector3(0, 0, -0.25), Vector3.ZERO, 0.16, 0.3, 8)
	return M.solid("impaler_drill", p)


## Rings of pressure standing round the line (in XY planes) at three points along it.
static func _rings() -> ArrayMesh:
	if M.has("impaler_rings"):
		return M.get_mesh("impaler_rings")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var z := -4.5 + 3.0 * float(k)
		var pts := PackedVector3Array()
		for i in 33:
			var ang := TAU * float(i) / 32.0
			pts.append(Vector3(cos(ang), sin(ang) + 1.1, z))
		K.ribbon(st, pts, 0.22, M.a(CYAN if k % 2 == 0 else ICE, 0.9), 0.05 * float(k), 0.0, Vector3.BACK, 0.0)
	return M.keep("impaler_rings", K.finish(st, Vector3.ONE * 0.5, false))


## The ground scored along the line (from -1 to 1 along Z, scaled by the line).
static func _score() -> ArrayMesh:
	if M.has("impaler_score"):
		return M.get_mesh("impaler_score")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	for k in 2:
		var pts := PackedVector3Array()
		for i in 11:
			var t := float(i) / 10.0
			pts.append(Vector3((float(k) - 0.5) * 0.5 + rng.randf_range(-0.05, 0.05), 0, lerpf(-1.0, 1.0, t)))
		K.ribbon(st, pts, 0.45, M.a(CYAN, 0.8), 0.0, 0.0, Vector3.UP, 1.0)
		K.ribbon(st, pts, 0.14, Color(0.03, 0.08, 0.14, 0.9), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return M.keep("impaler_score", K.finish(st, Vector3.ONE * 0.3, false))


static func telegraph(art: StarSkillArt, _caster: Node3D, skill: Dictionary, _point: Vector3, time: float) -> bool:
	var length := float(skill.get("length", 13.0))
	var width := float(skill.get("width", 1.7)) * 2.0
	K.put(art, K.FLAT, _lane(), "ImpalerLane", Vector3.UP * 0.06, Vector3(width, 1.0, length), time + 1.2, {"sweep": time * 0.7, "soft": 0.5, "hot": M.hot(CYAN, 0.7), "core": 0.5, "flick": 0.06, "add": 0.45}, {"fade_in": 0.06, "decay": 0.85})
	# The wind winds round the lance (the hand at about 1.2 m, the point out ahead).
	K.put(art, K.FLAT, _helix("impaler_coil", 2.5, 2, 0.16), "ImpalerCoil", Vector3(0.25, 1.15, 0.2), Vector3(0.45, 0.45, 2.4), time + 0.05, {"soft": 0.8, "hot": M.hot(ICE), "core": 0.45, "flow": 3.0, "add": 0.6}, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.1, "decay": 0.85, "turn": Vector3(0, 0, -TAU * 1.5)})
	M.sparks(art, "impaler_gather", [CYAN, ICE], 16, 0.2, 0.9, 0.5, 2.0, 0.11, 0.0, time + 0.1, Vector3(0.2, 0, 0.8), -1.0, 62, 0.6, 1.6)
	return true


## A thrust's carrier: the drill flies down the lane on its corkscrew.
static func launch(art: StarSkillArt, _caster: Node3D, _skill: Dictionary, point: Vector3, duration: float) -> bool:
	var travel := art.global_basis.inverse() * (point - art.global_position)
	var length := travel.length()
	K.put(art, K.SOLID, _drill(), "ImpalerDrill", Vector3.ZERO, Vector3(1.1, 1.1, 1.7), duration, {"rim_color": ICE, "rim": 0.8, "glow_color": ICE}, {"travel": travel, "fade_in": 0.02, "decay": 0.92, "turn": Vector3(0, 0, TAU * 3.0)})
	K.put(art, K.FLAT, _helix("impaler_trail", 6.0), "ImpalerTrail", Vector3.ZERO, Vector3(0.8, 0.8, length), duration + 0.15, {"sweep": duration, "tail": 0.5, "soft": 0.8, "hot": M.hot(ICE), "core": 0.45, "add": 0.6}, {"fade_in": 0.01, "decay": 0.7})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var length := float(skill.get("length", 13.0))
	var last := index >= 2
	# Rings of pressure round the line where it pierced, the ground scored along it.
	K.put(art, K.FLAT, _rings(), "ImpalerRings", Vector3.ZERO, Vector3.ONE * (1.0 + 0.25 * float(index)), 0.45, {"soft": 1.0, "hot": M.hot(ICE), "core": 0.5, "add": 0.6}, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.02, "decay": 0.35})
	K.put(art, K.FLAT, _score(), "ImpalerScore", Vector3.UP * 0.06, Vector3(1.0 + 0.3 * float(index), 1.0, length * 0.45), 1.0, {"sweep": 0.15, "soft": 0.5, "hot": M.hot(CYAN), "core": 0.4, "add": 0.6}, {"decay": 0.6})
	K.put(art, K.BITS, M.fan("impaler_spray", "shard", 22, 0.2, 2.5, 0.35, 7.0, 2.5, [CYAN, ICE, STEEL], 0.22, 63, 0.6, 1.6), "ImpalerSpray", Vector3(0, 0, -1.5), Vector3.ONE, 0.8, {"life": 0.65, "gravity": 7.0, "drag": 1.5, "piece": 0.22, "add": 0.5, "shrink": 0.4, "spin": 9.0}, {"decay": 0.8})
	if not last:
		M.sparks(art, "impaler_sparks", [CYAN, ICE], 14, 0.1, 0.8, 3.0, 2.5, 0.12, 0.0, 0.6, Vector3.UP * 0.4, 5.0, 64)
		return true
	# The third: the corkscrew drives the whole length and bursts at its end.
	var start := -(length * 0.55 - 0.8)
	K.put(art, K.FLAT, _helix("impaler_vortex", 7.0, 3, 0.3), "ImpalerVortex", Vector3(0, 1.1, start), Vector3(1.4, 1.4, length - 0.8), 0.6, {"sweep": 0.2, "tail": 2.0, "soft": 0.8, "hot": M.hot(ICE), "core": 0.45, "add": 0.65, "gain": 1.1}, {"fade_in": 0.01, "decay": 0.55})
	M.dust(art, "impaler_dust", Color("b9c8cf"), 12, 0.3, 1.2, 0.05, 1.0, Vector3(0, 0, length * 0.45), 0.8, 65)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var end := K.extra(parent, art.to_global(Vector3(0, 0, length * 0.45)), 1.2, "StarEnd_" + ID, source)
	if end:
		M.shock(end, "impaler_end_ring", CYAN, 3.2, 0.12, 0.5, 0.18)
		M.sparks(end, "impaler_end_burst", [CYAN, ICE, STEEL], 30, 0.1, 0.6, 4.0, 4.5, 0.15, 0.12, 0.9, Vector3.UP * 0.6, 6.0, 66, 0.4, 1.6)
		M.flash(end, "impaler_end_flash", CYAN, 2.4, 0.12, 0.35)
		end._draw()
	return true
