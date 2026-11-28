extends RefCounted
## Archer Ascension ultimate (★500): เลนส์ตะวัน. Its wind-up only (cosmetic): the sun lights
## up behind the archer, its shaft comes down into a golden lens that assembles ahead of it,
## and the beam's line is drawn on the ground. From the release the beam is its own
## (combat/ascend_ult/starfall_emperor_arrow.gd, AscendUlt): no waves, no finale here.
const ID := "starfall_emperor_arrow"
const ULT := preload("res://combat/ascend_ult/starfall_emperor_arrow.gd")


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	return ULT.telegraph(art, caster, skill, point, time)


static func wave(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _index: int, _point: Vector3, _source: Vector3) -> bool:
	return true


static func finale(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _point: Vector3, _source: Vector3) -> bool:
	return true
