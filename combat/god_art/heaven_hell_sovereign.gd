extends RefCounted
## Darklord Ascension ultimate (★500): จักรพรรดิสวรรค์และอเวจี. The class's god art under the
## Ascension's heavens (AscendSkillArt); cosmetic only.
const ID := "heaven_hell_sovereign"


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	return AscendSkillArt.ult_telegraph(art, caster, skill, point, time)


static func wave(art: StarSkillArt, parent: Node3D, skill: Dictionary, index: int, point: Vector3, source: Vector3) -> bool:
	return AscendSkillArt.ult_wave(art, parent, skill, index, point, source)


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	return AscendSkillArt.ult_finale(art, parent, skill, point, source)
