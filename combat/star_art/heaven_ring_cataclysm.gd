extends RefCounted
## Muay Thai 200 stars: หนุมานแผลงฤทธิ์. The fighter, cape on, raises its hands and calls
## หนุมาน to its side: at the spot beside it (HanumanAvatar.side_offset) a gold ยันต์ ring
## turns on the ground, gold light spirals up out of it and star glints gather; on the
## release a gold column and a ring of light burst there as หนุมาน himself drops into it
## (HanumanAvatar draws him, his blows and his farewell). Nothing falls from the sky and
## nothing strikes here: the blows are his. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const ID := "heaven_ring_cataclysm"
const GOLD := Color("ffc24a")
const GOLD_HI := Color("fff0b8")
const RED := Color("d0302c")
const SPARK := [Color("fff6c8"), Color("ffd36a"), Color("ffb03a"), Color("ffffff")]


static func _spot(art: StarSkillArt, caster: Node3D) -> Vector3:
	var yaw := float(caster.get("_facing")) if "_facing" in caster else caster.rotation.y
	return art.to_local(caster.global_position + HanumanAvatar.side_offset(yaw)) * Vector3(1, 0, 1)


static func telegraph(art: StarSkillArt, caster: Node3D, _skill: Dictionary, _point: Vector3, time: float) -> bool:
	var spot := _spot(art, caster)
	K.put(art, K.VEIL, K.area_mark(GOLD, Color(1.0, 0.7, 0.25, 0.35)), "HanumanSeal", spot + Vector3.UP * 0.04, Vector3.ONE * 1.6, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.45, "fade_in": 0.15, "spin": 1.5, "decay": 0.9}, {"opacity": 0.9})
	K.put(art, K.VEIL, S.spiral("hanuman_call", Color(1.0, 0.75, 0.25, 0.85), Color(1.0, 0.95, 0.7, 0.0), 3, 1.5, 0.4), "HanumanCall", spot + Vector3.UP * 0.05, Vector3(1.4, 3.6, 1.4), Vector3.ZERO, time, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.25, "spin": 5.0, "decay": 0.85})
	K.put(art, K.VEIL, S.spiral("hanuman_ground", Color(1.0, 0.7, 0.2, 0.7), Color(1.0, 0.9, 0.6, 0.0), 4, 0.8, 0.5), "HanumanGround", spot + Vector3.UP * 0.05, Vector3(2.0, 0.5, 2.0), Vector3.ZERO, time, {"initial": 1.5, "grow_time": 0.9, "fade_in": 0.3, "spin": -6.0, "decay": 0.9})
	if S.rich():
		K.put(art, K.SOLID, S.sparkles("hanuman_glints", SPARK, 22, 3.5, 1.6), "HanumanGlints", spot + Vector3.UP * 0.2, Vector3.ONE, Vector3.ZERO, time, {"cull": 6.0, "decay": 0.8})
	return true


static func strike(_art: StarSkillArt, parent: Node3D, _skill: Dictionary, _point: Vector3, index: int, source: Vector3) -> bool:
	if index != 0:
		return true
	var hanuman: HanumanAvatar = null
	for h: HanumanAvatar in HanumanAvatar.active():
		if h.by_hero and h.get_parent() == parent:
			hanuman = h
	var at := hanuman.global_position if hanuman else source
	var land := S.root(parent, at, 1.3, "StarHanuman_" + ID, source)
	if land:
		if hanuman:
			land.follow_ref = weakref(hanuman)
		K.put(land, K.VEIL, K.column("hanuman_column", [Color(1.0, 0.85, 0.45, 0.6), Color(1.0, 0.75, 0.3, 0.4), Color(1.0, 0.9, 0.6, 0.15), Color(1.0, 0.95, 0.8, 0.0)], 0.8, 18), "HanumanColumn", Vector3.ZERO, Vector3(1.6, 6.0, 1.6), Vector3.ZERO, 0.75, {"initial": 0.5, "grow_time": 0.18, "fade_in": 0.02, "spin": 4.0, "decay": 0.4}, {"noise_amt": 0.6, "noise_scale": Vector2(6.0, 1.5), "flow": Vector2(0.8, -2.0), "bias": 0.1, "taper": 0.5, "fres": 0.6})
		K.put(land, K.VEIL, K.shock(GOLD, GOLD_HI, RED), "HanumanShock", Vector3.UP * 0.1, Vector3.ONE * 3.2, Vector3.ZERO, 0.55, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.35}, {"opacity": 0.85})
		land._draw()
	return true
