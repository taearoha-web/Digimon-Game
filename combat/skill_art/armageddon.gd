extends RefCounted
## Mage Lv.100 "Armageddon" (อาร์มาเกดดอน): the summons of the end. Cosmetic only.
## ArmageddonSequence (MeteorArt) owns the giant meteor, its landing and the ten fragments.
## This signature dresses only SkillShow's wind-up, so no shared class layer plays under
## it: a sigil of hellfire writes itself round the mage, flames lick up round the raised
## staff in a corona, embers stream up, and a pillar of fire shoots from the staff into the
## sky over the target while the sky there turns red for the meteor to come.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const HELL := {"c_core": Color("ffd0a0"), "c_mid": Color("ff5a2a"), "c_edge": Color("8a0a1a")}
const FIRE := {"c_core": Color("ffe8a8"), "c_mid": Color("ff8a3a"), "c_edge": Color("c0281a")}
const EMBER := {"c_core": Color("ffe0a0"), "c_mid": Color("ff8a3a"), "c_edge": Color("a02a1a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.4, visual)
	var r := c.toward(origin, aim, duration + 0.35, "Windup", duration)
	if not r:
		return true
	var hand := r.to_local(c.hand())
	A.sigil(r, Vector3.UP * 0.05, 2.6, 5.0, HELL, 0.0, duration + 0.3, duration * 0.7, 0.55, -0.8)
	A.fire_wall(r, Vector3.ZERO, 1.6, 0.9, FIRE, 0.0, duration + 0.2, 0.6, {"grow": duration * 0.6, "from": 0.3})
	A.glow(r, 2, hand, Vector3.ONE * 1.6, Vector3.ZERO, FIRE, 0.0, duration + 0.1, 0.5, {"billboard": true, "p1": 9.0, "p2": 0.3}, {"grow": duration, "from": 0.2})
	if c.has(0):
		A.S.motes(r, Vector3.ZERO, 1.8, c.n(5, 8, 12), EMBER, 0.24, 0.0, duration * 0.7, 0.9, 2.2, 9, 1.0)
	# A pillar of fire from the staff into the sky over the target; the sky reddens.
	var sky := r.to_local(A.flat(aim)) + Vector3.UP * 8.0
	A.beam(r, hand, sky, 0.9, FIRE, duration * 0.65, 0.6, 0.6, 9.0, {"veil": true})
	A.flash(r, sky, 5.0, HELL, duration * 0.7, 0.9, 0.35, {"grow": 0.4, "from": 0.3, "veil": true})
	A.ring(r, Vector3.UP * 0.07, 3.0, FIRE, duration * 0.7, 0.5, 0.7)
	return true


## The meteor (ArmageddonSequence) draws everything after the wind-up.
static func play(_parent: Node3D, _skill: Dictionary, _center: Vector3, _origin: Vector3, _impact_delay: float) -> bool:
	return true
