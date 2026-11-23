extends RefCounted
## Muay Thai 200 stars: หนุมานแผลงฤทธิ์. Risen into the sky on the fighter's cape, it calls
## หนุมาน: the white monkey warrior rises from gold clouds behind it, yawns stars and a
## crescent moon over the target (หาวเป็นดาวเป็นเดือน), and from each star a gold ตรีเพชร
## falls to stake the ground on its beat, a ยันต์ seal and its อักขระ bursting round it;
## the fifth falls from the moon at the centre. Drawn by RamakienArt (a lit spirit sculpture
## over a dimmed field, light and painted seals); cosmetic only.
const ID := "heaven_ring_cataclysm"
## The script's last index is the finale (StarSignature.strike); every beat is drawn by strike.
const LAST := 4


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	return RamakienArt.hanuman_telegraph(art, caster, skill, point, time)


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	return RamakienArt.hanuman_strike(art, parent, skill, point, index, source)
