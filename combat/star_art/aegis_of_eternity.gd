extends RefCounted
## Defender Ascension buff (★500): ผู้พิทักษ์ทีม. The class's support star art under the
## Ascension's crown (AscendSkillArt); cosmetic only.
const ID := "aegis_of_eternity"


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	return AscendSkillArt.buff_telegraph(art, caster, skill, point, time)


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	return AscendSkillArt.buff_strike(art, parent, skill, point, index, source)
