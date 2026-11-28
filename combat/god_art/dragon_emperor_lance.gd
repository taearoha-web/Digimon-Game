extends RefCounted
## Lancer Ascension ultimate (★500): หอกพายุบูมเมอแรง (dragon_emperor_lance). Its wind-up
## only: the throw itself (the giant lance spinning out 14 m as a travelling storm and back
## to the hand) is its own script, combat/ascend_ult/dragon_emperor_lance.gd (AscendUlt),
## which draws its own art. Here the lancer draws back to throw: the storm's lane opens on
## the ground ahead (its width, its length, chevrons running out and curling back), wind
## gathers spinning round the lancer and a glint grows at the hand. Cosmetic only.
const K := preload("res://combat/god_art/_kit_melee.gd")
const ID := "dragon_emperor_lance"
## The throw's reach and the storm's half width (the script's REACH and STORM).
const REACH := 14.0
const STORM := 2.4
static var _cache := {}


static func _palette(skill: Dictionary) -> Array:
	var c: Array = AscendSkillData.COLORS.get(String(skill.get("id", ID)), ["4ad0ff", "f0fbff", "122a6a"])
	return [Color(c[0]), Color(c[1]), Color(c[2])]


## The lane along +Z: its two edges, a soft floor and chevrons pointing out (the way the
## lance goes) and back (the way it returns), in metres. FLAT, revealed from the lancer out.
static func _lane(blue: Color, pale: Color) -> ArrayMesh:
	if _cache.has("lane"):
		return _cache.lane
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		var edge := PackedVector3Array()
		for i in 15:
			var z := lerpf(0.8, REACH, float(i) / 14.0)
			edge.append(Vector3(s * STORM, 0.0, z))
		K.ribbon(st, edge, 0.07, Color(blue.r, blue.g, blue.b, 0.85), 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0)
	var floor_pts := PackedVector3Array([Vector3(0, 0, 0.8), Vector3(0, 0, REACH * 0.5), Vector3(0, 0, REACH)])
	K.ribbon(st, floor_pts, STORM * 2.0, Color(blue.r, blue.g, blue.b, 0.22), 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0)
	for k in 6:
		var z := 2.2 + float(k) * 2.0
		var out := k % 2 == 0
		var tip := z + (0.6 if out else -0.6)
		var c := pale if out else blue
		K.ribbon(st, PackedVector3Array([Vector3(-1.1, 0, z), Vector3(0, 0, tip), Vector3(1.1, 0, z)]), 0.14, Color(c.r, c.g, c.b, 0.8), 0.0, 0.0, Vector3.UP, 0.0, z / REACH, z / REACH + 0.04)
	_cache.lane = K.finish(st, Vector3.ONE * 0.3, false)
	return _cache.lane


## Wind winding round the lancer, up to a height of 1 on a unit ring.
static func _gather(blue: Color, pale: Color) -> ArrayMesh:
	if _cache.has("gather"):
		return _cache.gather
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var a := TAU * float(i) / 10.0
		var pts := PackedVector3Array()
		for j in 14:
			var t := float(j) / 13.0
			var ang := a + t * 3.4
			var rad := 1.0 - 0.45 * t
			pts.append(Vector3(sin(ang) * rad, 0.15 + t * 0.85, cos(ang) * rad))
		var c := blue.lerp(pale, 0.5 if i % 2 == 0 else 0.0)
		c.a = 0.8
		K.ribbon(st, pts, 0.05, c, float(i % 5) * 0.1, 0.0, Vector3(sin(a), 0, cos(a)), 1.0)
	_cache.gather = K.finish(st, Vector3.ONE * 0.3, false)
	return _cache.gather


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, _point: Vector3, time: float) -> bool:
	if not is_instance_valid(art) or not is_instance_valid(caster):
		return true
	var pal := _palette(skill)
	var blue: Color = pal[0]
	var pale: Color = pal[1]
	# The lane runs the way the lancer faces: that is where the lance goes.
	var facing: Variant = caster.get("_facing")
	if facing != null:
		art.rotation.y = float(facing)
	K.put(art, K.FLAT, _lane(blue, pale), "StormLaneGround", Vector3.UP * 0.06, Vector3.ONE, time + 0.1, {"sweep": time * 0.7, "soft": 0.7, "hot": Color(1, 1, 1, 0.8), "core": 0.5, "flick": 0.06, "add": 0.45}, {"fade_in": 0.08, "decay": 0.9})
	K.put(art, K.FLAT, _gather(blue, pale), "StormGather", Vector3.ZERO, Vector3(1.5, 3.0, 1.5), time, {"sweep": 0.5, "tail": 0.7, "flow": 2.0, "soft": 1.2, "hot": Color(1, 1, 1, 0.9), "core": 0.4, "add": 0.6}, {"initial": 0.6, "grow_time": 0.8, "fade_in": 0.1, "spin": 4.5, "decay": 0.9})
	K.put(art, K.FLAT, K.glow_disc("storm_lance_glint", Color(pale.r, pale.g, pale.b, 0.8)), "StormGlint", Vector3(0.35, 1.7, -0.2), Vector3.ONE * 0.6, time, {"soft": 1.0, "add": 0.8, "flick": 0.2}, {"initial": 0.1, "grow_time": 1.0, "fade_in": 0.2, "decay": 0.95, "face_camera": true, "pulse": true})
	return true
