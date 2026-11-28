extends RefCounted
## Warrior Ascension ultimate (★500): ดาบเหินฟ้า (emperor_heavensword). Its wind-up only:
## the move itself (the rising slash that throws every foe within 10 m into the air, the
## aerial slashes and the slam) is its own script, combat/ascend_ult/emperor_heavensword.gd
## (AscendUlt), which draws its own art. Here the warrior sinks into a low draw while a gale
## gathers round it: the ring of who will be thrown, streaks of wind spiralling up off the
## ground, the dust stirring and the blade's light gathering low at its side. No sky gate,
## no falling swords: this wind goes UP. Cosmetic only.
const K := preload("res://combat/god_art/_kit_melee.gd")
const ID := "emperor_heavensword"
## The thrown ring (the script's RADIUS).
const RADIUS := 10.0
const STREAKS := 18
static var _cache := {}


static func _palette(skill: Dictionary) -> Array:
	var c: Array = AscendSkillData.COLORS.get(String(skill.get("id", ID)), ["ffb43a", "fff4c0", "6a1a2a"])
	return [Color(c[0]), Color(c[1]), Color(c[2])]


## Wind streaks of a unit ring rising in spirals to a height of 1: FLAT strokes, each
## revealed from the ground up, a little after the one before.
static func _updraft(gold: Color, pale: Color) -> ArrayMesh:
	if _cache.has("updraft"):
		return _cache.updraft
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in STREAKS:
		var a := TAU * float(i) / float(STREAKS) + rng.randf_range(-0.12, 0.12)
		var r := rng.randf_range(0.3, 0.95)
		var top := rng.randf_range(0.75, 1.0)
		var pts := PackedVector3Array()
		for j in 12:
			var t := float(j) / 11.0
			var ang := a + t * 1.6
			var rad := r * (1.0 - 0.35 * t)
			pts.append(Vector3(sin(ang) * rad, t * top, cos(ang) * rad))
		var c := gold.lerp(pale, rng.randf())
		c.a = rng.randf_range(0.55, 0.9)
		K.ribbon(st, pts, rng.randf_range(0.025, 0.05), c, float(i % 6) * 0.08, 0.0, Vector3(sin(a), 0, cos(a)), 1.0)
	_cache.updraft = K.finish(st, Vector3.ONE * 0.3, false)
	return _cache.updraft


## The blade's light gathering low at the warrior's side, ready to rise.
static func _edge(pale: Color) -> ArrayMesh:
	if _cache.has("edge"):
		return _cache.edge
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.beam(st, Vector3.ZERO, 1.0, 0.12, pale, 2, 0.0, 0.0, 0.0)
	K.disc(st, 0.35, Color(pale.r, pale.g, pale.b, 0.7), 0.02, 20)
	_cache.edge = K.finish(st, Vector3.ONE * 0.2, false)
	return _cache.edge


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, _point: Vector3, time: float) -> bool:
	if not is_instance_valid(art) or not is_instance_valid(caster):
		return true
	var pal := _palette(skill)
	var gold: Color = pal[0]
	var pale: Color = pal[1]
	var parent := art.get_parent() as Node3D
	var origin := caster.global_position
	# The launch takes everything round the warrior, whatever it aimed at.
	K.put(art, K.FLAT, K.area_ring("heavensword_lift_area", gold), "HeavenLiftArea", Vector3.UP * 0.07, Vector3.ONE * RADIUS, time + 0.1, {"soft": 0.5, "hot": Color(1, 0.97, 0.8, 0.8), "core": 0.5, "add": 0.35}, {"initial": 0.35, "grow_time": 0.4, "fade_in": 0.1, "spin": -0.35, "decay": 0.9})
	K.put(art, K.FLAT, _edge(pale), "HeavenLiftEdge", Vector3(0.45, 0.05, 0.55), Vector3(1.6, 2.4, 1.6), time, {"soft": 1.5, "flick": 0.1, "hot": Color(1, 1, 0.92, 0.9), "add": 0.65}, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.15, "decay": 0.92})
	if GodSkillArt.extra_roots(1) < 1 or parent == null:
		return true
	var gale := K.extra(parent, origin, time + 0.15, "StarGodGale_" + ID, origin, art)
	if gale:
		K.put(gale, K.FLAT, _updraft(gold, pale), "HeavenLiftDraft", Vector3.UP * 0.05, Vector3(RADIUS, 4.6, RADIUS), time + 0.15, {"sweep": 0.45, "tail": 0.6, "flow": 1.6, "soft": 1.2, "hot": Color(1, 1, 0.95, 0.9), "core": 0.4, "add": 0.6}, {"fade_in": 0.1, "spin": 1.4, "decay": 0.85, "travel": Vector3.UP * 0.8})
		K.put(gale, K.FLAT, K.glow_disc("heavensword_dust", Color(0.85, 0.75, 0.55, 0.35)), "HeavenLiftDust", Vector3.UP * 0.04, Vector3.ONE * RADIUS * 0.8, time + 0.1, {"soft": 1.0, "add": 0.0, "flow": 0.8}, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.3, "spin": 0.8, "decay": 0.9})
		gale._draw()
	return true
