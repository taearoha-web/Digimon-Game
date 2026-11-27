extends RefCounted
## Muay Thai 300 stars: สิบเศียรสิบกรสะท้านสามภพ. The fighter TURNS INTO ทศกัณฐ์ for eight
## seconds (ThotsakanForm): it grows, the ten-headed spirit stands up behind it with its
## twenty arms, every normal punch strikes and burns every foe round it, and the form
## ends in one god fist slammed down before the fighter.
## This signature draws the wind-up only (ThotsakanFormArt.telegraph: the seal, the
## column of jade light, the flash of the change); the cast has no waves or finale beats
## of its own (StarSkillSequence starts the form on the release), so wave / finale draw
## nothing. Roots follow the god contract: StarGodGround (always), StarGodSky (no memory
## pressure); the form's finisher opens StarGodAvatar (no pressure) and StarGodTemple
## (high quality only).
const ID := "three_realms_fist"


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	return ThotsakanFormArt.telegraph(art, caster, skill, point, time)


static func wave(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _index: int, _point: Vector3, _source: Vector3) -> bool:
	return true


static func finale(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _point: Vector3, _source: Vector3) -> bool:
	return true
