extends RefCounted
## Mage Ascension ultimate (★500): ประตูมิติร้อยบาน. Its wind-up only (cosmetic): the seal of
## the area is drawn on the ground, a sigil of fire, ice or lightning glows where each portal
## will open, and a small portal turns before the mage's hands. From the release the portals
## are their own (combat/ascend_ult/cosmos_genesis.gd, AscendUlt): no waves, no finale here.
const ID := "cosmos_genesis"
const ULT := preload("res://combat/ascend_ult/cosmos_genesis.gd")


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	return ULT.telegraph(art, caster, skill, point, time)


static func wave(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _index: int, _point: Vector3, _source: Vector3) -> bool:
	return true


static func finale(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _point: Vector3, _source: Vector3) -> bool:
	return true
