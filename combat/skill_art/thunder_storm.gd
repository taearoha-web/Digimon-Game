extends RefCounted
## Mage Lv.76 "Thunder Storm" (พายุสายฟ้า): the wind-up of the storm. Cosmetic only.
## ThunderStormSequence (ThunderStormArt) owns the storm itself: its sky ring, seal, cloud
## deck and every strike. This signature dresses only SkillShow's wind-up, so no shared
## class layer plays under it: lightning crackles round the raised staff, a thunder sigil
## writes itself at the mage's feet and a bolt climbs from the staff into the sky over the
## storm zone, where the sequence's ring is about to form.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const BOLT := {"c_core": Color("f4f6ff"), "c_mid": Color("a8c8ff"), "c_edge": Color("3a5ad0")}
const VOLT := {"c_core": Color("fffbe0"), "c_mid": Color("ffe88a"), "c_edge": Color("b08a2a")}
const SEAL := {"c_core": Color("e8f0ff"), "c_mid": Color("8ab0ff"), "c_edge": Color("2a3a9a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Windup", duration)
	if not r:
		return true
	var hand := r.to_local(c.hand())
	A.sigil(r, Vector3.UP * 0.05, 2.0, 6.0, SEAL, 0.0, duration + 0.15, duration * 0.8, 0.55, 1.0)
	A.flash(r, hand, 1.2, BOLT, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	for k in c.n(2, 3, 5):
		var a := float(k) * 2.3
		var off := Vector3(sin(a) * 0.9, 0.3 + 0.4 * float(k % 2), cos(a) * 0.9)
		A.bolt(r, hand + off, hand, 0.45, BOLT if k % 2 == 0 else VOLT, duration * 0.16 * float(k), 0.14, 0.85, float(k) * 2.1)
	# A bolt climbs from the staff into the sky over the storm zone.
	var sky := r.to_local(A.flat(aim)) + Vector3.UP * 7.5
	A.bolt(r, sky, hand, 0.8, BOLT, duration * 0.7, duration * 0.3 + 0.15, 0.9, 5.0)
	A.ring(r, Vector3.UP * 0.07, 2.6, SEAL, duration * 0.6, duration * 0.4 + 0.15, 0.7)
	return true


## The storm (ThunderStormSequence) draws everything after the wind-up.
static func play(_parent: Node3D, _skill: Dictionary, _center: Vector3, _origin: Vector3, _impact_delay: float) -> bool:
	return true
