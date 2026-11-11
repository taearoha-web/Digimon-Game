extends RefCounted
## Defender 150 stars "Eternal Aegis": the everlasting shield. Wind-up: a ring of runes draws
## round the defender and a dome of hexagonal light-cells builds itself up from the ground
## (thin lines, the fight inside stays in view). Release: the dome flashes as light runs
## along its seams, a great silver-blue shield rises over the defender and a wave of light
## washes out over the allies it shields. The dome then breaks into hexagonal shards that
## drift up and fade. Sky blue, silver and pale gold.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const BLUE := Color("5fb4ff")
const SILVER := Color("d8e8ff")
const NAVY := Color("1a3a7a")
const GOLD := Color("ffd98a")
const ID := "eternal_aegis"
const DOME := 3.4


## The dome of hexagon cells (radius 1): its lines, UV.y = height (the reveal climbs).
static func _dome() -> ArrayMesh:
	if M.has("eternal_dome"):
		return M.get_mesh("eternal_dome")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 5
	for row in rows:
		var e0 := float(row) / float(rows) * PI * 0.5
		var e1 := float(row + 1) / float(rows) * PI * 0.5
		var count := maxi(5, int(round(16.0 * cos((e0 + e1) * 0.5))))
		for i in count:
			var off := 0.5 * float(row % 2)
			var a0 := TAU * (float(i) + off) / float(count)
			var a1 := TAU * (float(i) + 1.0 + off) / float(count)
			var am := (a0 + a1) * 0.5
			var em := (e0 + e1) * 0.5
			var corners: Array[Vector3] = []
			for k in 6:
				var ang := TAU * float(k) / 6.0
				var da := cos(ang) * (a1 - a0) * 0.5 * 0.92
				var de := sin(ang) * (e1 - e0) * 0.5 * 0.92
				var aa := am + da
				var ee := clampf(em + de, 0.0, PI * 0.5)
				corners.append(Vector3(sin(aa) * cos(ee), sin(ee), cos(aa) * cos(ee)))
			corners.append(corners[0])
			var pts := PackedVector3Array(corners)
			K.ribbon(st, pts, 0.022, M.a(BLUE if (i + row) % 3 else SILVER, 0.9), 0.0, 0.0, pts[0].normalized(), 0.0, em / (PI * 0.5), em / (PI * 0.5) + 0.01)
	return M.keep("eternal_dome", K.finish(st, Vector3.ONE * 0.2, false))


## The rune ring on the ground (radius 1).
static func _runes() -> ArrayMesh:
	if M.has("eternal_runes"):
		return M.get_mesh("eternal_runes")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.0, M.a(NAVY, 0.3), 0.0, 40, 0.0, Vector3.UP, Vector3.ZERO, M.a(BLUE, 0.15), 0.0, true)
	K.ring(st, 1.0, 0.04, M.a(BLUE, 1.0), 0.002, 72)
	K.ring(st, 0.84, 0.02, M.a(SILVER, 0.85), 0.002, 72)
	for i in 6:
		var ang := TAU * float(i) / 6.0
		var c := Vector3(sin(ang), 0.003, cos(ang)) * 0.92
		var hexagon := PackedVector3Array()
		for k in 7:
			var a2 := TAU * float(k) / 6.0
			hexagon.append(c + Vector3(sin(a2), 0, cos(a2)) * 0.07)
		K.ribbon(st, hexagon, 0.02, M.a(GOLD, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("eternal_runes", K.finish(st, Vector3.ONE * 0.2, false))


## The great shield, silver-blue, facing +Z.
static func _shield() -> ArrayMesh:
	return M.solid("eternal_great_shield", M.shield(Color("4f8ad8"), SILVER, GOLD))


## Hexagonal shards drifting up from the dome as it breaks (radius 1).
static func _shards() -> ArrayMesh:
	if M.has("eternal_shards"):
		return M.get_mesh("eternal_shards")
	var rng := RandomNumberGenerator.new()
	rng.seed = 121
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hexagon := K.Part.new()
	for k in 6:
		var a0 := TAU * float(k) / 6.0
		var a1 := TAU * float(k + 1) / 6.0
		hexagon.ink(BLUE.lerp(SILVER, 0.3 * float(k % 2)), 0.5)
		hexagon.tri(Vector3.ZERO, Vector3(sin(a0), cos(a0), 0) * 0.5, Vector3(sin(a1), cos(a1), 0) * 0.5)
	for i in 34:
		var ang := rng.randf() * TAU
		var el := rng.randf_range(0.1, 1.3)
		var at := Vector3(sin(ang) * cos(el), sin(el), cos(ang) * cos(el)) * DOME
		var vel := at.normalized() * rng.randf_range(0.6, 1.6) + Vector3.UP * rng.randf_range(0.6, 1.6)
		K.bit(st, hexagon, at, vel, rng.randf() * 0.25, 0.5, Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)).scaled(Vector3.ONE * rng.randf_range(0.4, 0.7)))
	return M.keep("eternal_shards", K.finish(st, Vector3(6, 8, 6), false))


static func telegraph(art: StarSkillArt, _caster: Node3D, _skill: Dictionary, _point: Vector3, time: float) -> bool:
	var hold := M.stage(art, time + 1.1, "StarStage_" + ID)
	if hold == null:
		return false
	K.put(hold, K.FLAT, _dome(), "AegisDomeCells", Vector3.UP * 0.05, Vector3.ONE * DOME, time + 0.45, {"sweep": time * 0.85, "soft": 0.5, "hot": M.hot(SILVER, 0.8), "core": 0.4, "flick": 0.08, "add": 0.6}, {"fade_in": 0.02, "decay": 0.9})
	K.put(hold, K.FLAT, _runes(), "AegisRunes", Vector3.UP * 0.06, Vector3.ONE * (DOME + 0.4), time + 1.1, {"sweep": time * 0.5, "soft": 0.45, "hot": M.hot(BLUE, 0.8), "core": 0.5, "add": 0.45}, {"initial": 0.5, "grow_time": 0.4, "fade_in": 0.05, "spin": 0.2, "decay": 0.85})
	M.sparks(art, "eternal_rise", [BLUE.lightened(0.3), SILVER], 22, DOME - 0.4, DOME + 0.2, 0.1, 2.5, 0.12, 0.0, time + 0.2, Vector3.ZERO, -1.0, 122, 0.05, 0.4)
	hold._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	if index > 0:
		return true
	var reach := clampf(float(skill.get("radius", 8.0)), 4.0, 9.0)
	# The seams of the dome flash, the great shield rises, the wave washes over the allies.
	K.put(art, K.FLAT, _dome(), "AegisDomeFlash", Vector3.UP * 0.05, Vector3.ONE * DOME * 1.02, 0.55, {"soft": 0.3, "hot": M.hot(GOLD), "core": 0.3, "add": 0.75, "gain": 1.3, "flow": 2.0}, {"fade_in": 0.01, "decay": 0.4})
	K.put(art, K.SOLID, _shield(), "AegisGreatShield", Vector3.UP * 2.7, Vector3.ONE * 2.4, 1.4, {"rim_color": GOLD, "rim": 0.75, "glow_color": GOLD, "heat": 0.4}, {"initial": 0.3, "grow_time": 0.15, "fade_in": 0.03, "decay": 0.72, "face_camera": true, "travel": Vector3.UP * 0.9})
	M.shock(art, "eternal_wave", BLUE, reach * 1.35, 0.0, 0.8, 0.14)
	M.shock(art, "eternal_wave_b", GOLD, reach * 0.95, 0.1, 0.65, 0.2)
	K.put(art, K.BITS, _shards(), "AegisShards", Vector3.ZERO, Vector3.ONE, 1.8, {"life": 1.6, "gravity": -0.6, "drag": 0.8, "piece": 0.5, "sway": 0.3, "spin": 3.0, "shrink": 0.5, "add": 0.5}, {"delay": 0.35, "decay": 0.8})
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var after := K.extra(parent, Vector3(point.x, 0, point.z), 1.8, "StarAfter_" + ID, source)
	if after:
		M.flash(after, "eternal_floor", BLUE, DOME + 0.5, 0.0, 0.7)
		M.sparks(after, "eternal_motes", [BLUE.lightened(0.35), SILVER, GOLD], 30, 0.4, DOME, 0.3, 2.0, 0.12, 0.1, 1.6, Vector3.ZERO, -0.8, 123, 0.2, 2.2)
		after._draw()
	return true
