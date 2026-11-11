extends RefCounted
## Assassin 50 stars "Umbral Lacerate": twin daggers cross-cut in the dark. Wind-up: shadow
## boils up round the assassin's feet, violet glints run along both daggers and a faint X
## is drawn on the ground. Hit 1: two black slashes with violet-hot edges cross through
## the circle in an X. Hit 2: a second X turned half a quarter: an eight-pointed star of
## cuts; shadow blades fly outward on a ring and the wounds weep violet-crimson. The scars
## stay a moment in the ground. Violet, lilac and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const VIOLET := Color("9a5cff")
const LILAC := Color("e3d0ff")
const INK := Color(0.04, 0.01, 0.08)
const BLOOD := Color("c0206a")
const ID := "umbral_lacerate"


## An X of two cuts through the origin (radius 1), turned by [param turn].
static func _cross(key: String, turn: float) -> Array:
	if M._m.has(key):
		return M._m[key]
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	var scar := SurfaceTool.new()
	scar.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var ang := turn + PI * 0.25 + PI * 0.5 * float(k)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var side := Vector3(dir.z, 0, -dir.x)
		var pts := PackedVector3Array()
		var low := PackedVector3Array()
		var flip := 1.0 if k == 0 else -1.0
		for i in 15:
			var t := float(i) / 14.0
			var at := dir * lerpf(-1.0, 1.0, t) * flip + side * sin(t * PI) * 0.18
			pts.append(at + Vector3.UP * (0.24 + sin(t * PI) * 0.06))
			low.append(at + Vector3.UP * 0.01)
		for up in [Vector3.UP, side]:
			K.ribbon(flat, pts, 0.42, M.a(VIOLET, 0.95), 0.06 * float(k), 0.0, up, 1.0)
			K.ribbon(flat, pts, 0.17, M.a(INK, 1.0), 0.06 * float(k), 0.0, up, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
		K.ribbon(scar, low, 0.14, M.a(VIOLET, 0.85), 0.06 * float(k), 0.0, Vector3.UP, 1.0)
		K.ribbon(scar, low, 0.05, M.a(INK, 1.0), 0.06 * float(k), 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	var out := [K.finish(flat, Vector3.ONE * 0.3, false), K.finish(scar, Vector3.ONE * 0.2, false)]
	M._m[key] = out
	return out


## Shadow blades flying out on a ring (radius 1): little crescents, level.
static func _blades() -> ArrayMesh:
	if M.has("umbral_blades"):
		return M.get_mesh("umbral_blades")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var ang := TAU * float(i) / 8.0 + PI / 8.0
		K.ribbon(st, M.arc(Vector3.ZERO, 1.0, ang - 0.28, ang + 0.28, 0.25, 0.25, 8), 0.16, M.a(VIOLET, 0.95), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, M.a(LILAC, 0.9))
	return M.keep("umbral_blades", K.finish(st, Vector3.ONE * 0.2, false))


static func telegraph(art: StarSkillArt, _caster: Node3D, skill: Dictionary, _point: Vector3, time: float) -> bool:
	var r := clampf(float(skill.get("radius", 5.0)), 3.0, 7.0)
	K.put(art, K.BITS, K.burst("umbral_smoke", "puff", 18, 0.2, 1.0, 0.3, 1.8, [Color(0.08, 0.03, 0.14), Color(0.16, 0.06, 0.26), Color(0.03, 0.01, 0.06)], 0.6, 0.6, 141, 0.05, 0.4), "UmbralSmoke", Vector3.ZERO, Vector3.ONE, time + 0.25, {"life": 0.8, "gravity": -1.0, "drag": 1.5, "piece": 0.6, "swell": 1.6, "alpha": 0.6, "shrink": 0.4, "spin": 2.0}, {"fade_in": 0.05, "decay": 0.9})
	K.put(art, K.FLAT, _cross("umbral_omen", 0.0)[1], "UmbralOmen", Vector3.UP * 0.05, Vector3.ONE * r, time + 0.05, {"sweep": time * 0.8, "soft": 0.6, "hot": M.hot(VIOLET, 0.5), "core": 0.5, "flick": 0.15, "add": 0.5}, {"fade_in": 0.1, "decay": 0.85})
	M.area(art, "umbral_area", VIOLET, r, time + 0.6, 0.6)
	M.sparks(art, "umbral_glints", [VIOLET, LILAC], 14, 0.2, 0.6, 0.6, 1.4, 0.1, 0.0, time, Vector3.UP * 0.2, -1.0, 142, 0.8, 1.4)
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := clampf(float(skill.get("radius", 5.0)), 3.0, 7.0)
	var cross := _cross("umbral_x%d" % index, 0.0 if index == 0 else PI * 0.25)
	K.put(art, K.FLAT, cross[0], "UmbralCross", Vector3.ZERO, Vector3(r, 4.5, r), 0.5, {"sweep": 0.08, "tail": 2.5, "soft": 0.7, "hot": M.hot(LILAC), "core": 0.42, "add": 0.6, "gain": 1.1}, {"fade_in": 0.01, "decay": 0.45})
	K.put(art, K.FLAT, cross[1], "UmbralScar", Vector3.UP * 0.06, Vector3.ONE * r, 1.6 - 0.26 * float(index), {"sweep": 0.1, "soft": 0.5, "hot": M.hot(VIOLET), "core": 0.4, "flick": 0.12, "add": 0.6}, {"decay": 0.65})
	K.put(art, K.BITS, K.burst("umbral_wounds", "ember", 26, 0.6, r * 0.8, 2.5, 3.0, [VIOLET, BLOOD, LILAC], 0.15, 0.06, 143, 0.6, 1.6), "UmbralWounds", Vector3.ZERO, Vector3.ONE, 0.8, {"life": 0.65, "gravity": 7.0, "drag": 1.6, "piece": 0.15, "add": 0.6, "shrink": 0.3}, {"decay": 0.8})
	if index == 0:
		K.put(art, K.BITS, K.burst("umbral_feathers", "feather", 18, 0.5, r * 0.7, 1.4, 1.5, [INK, Color(0.14, 0.05, 0.22), Color(0.3, 0.1, 0.4)], 0.45, 0.1, 144, 0.8, 1.6), "UmbralFeathers", Vector3.ZERO, Vector3.ONE, 1.4, {"life": 1.2, "gravity": 2.4, "drag": 1.4, "piece": 0.45, "sway": 0.4, "spin": 5.0, "floor_y": 0.08, "shrink": 0.85}, {"decay": 0.9})
		return true
	# The star of cuts throws its shadow blades outward.
	K.put(art, K.FLAT, _blades(), "UmbralBlades", Vector3.ZERO, Vector3.ONE * r * 0.5, 0.45, {"soft": 0.7, "hot": M.hot(LILAC), "core": 0.45, "add": 0.6}, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.01, "decay": 0.4, "spin": 3.0})
	M.shock(art, "umbral_ring", VIOLET, r * 1.15, 0.02, 0.45, 0.16)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var after := K.extra(parent, Vector3(point.x, 0, point.z), 1.6, "StarAfter_" + ID, source)
	if after:
		K.put(after, K.BITS, K.burst("umbral_feathers_b", "feather", 26, 0.5, r * 0.8, 1.0, 2.0, [INK, Color(0.14, 0.05, 0.22), BLOOD.darkened(0.4)], 0.5, 0.1, 145, 1.0, 1.8), "UmbralFeathersB", Vector3.ZERO, Vector3.ONE, 1.6, {"life": 1.4, "gravity": 2.2, "drag": 1.3, "piece": 0.5, "sway": 0.45, "spin": 4.0, "floor_y": 0.08, "shrink": 0.85}, {"decay": 0.9})
		M.flash(after, "umbral_pool", Color("3a1060"), r * 0.6, 0.0, 0.8)
		after._draw()
	return true
