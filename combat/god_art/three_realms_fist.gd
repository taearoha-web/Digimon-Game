extends RefCounted
## Muay Thai 300 stars: สิบเศียรสิบกรสะท้านสามภพ. ทศกัณฐ์ rises behind the fighter, ten
## heads in tiers, twenty arms unfurling round them. Its fists rain round the fighter in
## four waves (GOD_BEATS), each denser and faster; then the last wave's fists fly up and
## fuse into one enormous fist that slams down before the fighter, gold light cracking
## the ground into temple glass mosaic (กระจกสี) while the three realms quake.
## Painted by RamakienArt (the fighter's MuayPaint); cosmetic only. Roots follow the god
## contract: StarGodGround (always), StarGodSky (the giant, no memory pressure),
## StarGodAvatar on the finale (no pressure), StarGodTemple (high quality only).
const ID := "three_realms_fist"


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	return RamakienArt.thotsakan_telegraph(art, caster, skill, point, time)


static func wave(art: StarSkillArt, parent: Node3D, skill: Dictionary, index: int, point: Vector3, source: Vector3) -> bool:
	return RamakienArt.thotsakan_wave(art, parent, skill, index, point, source)


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	return RamakienArt.thotsakan_finale(art, parent, skill, point, source)
