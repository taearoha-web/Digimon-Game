extends RefCounted
## Mage Lv.96 "Judgment Ray" (รังสีพิพากษา): the caster's side of the judgement. Cosmetic only.
## JudgmentRaySequence (JudgmentRayArt) owns the seal in the sky, the lock on the target
## and the ray itself. This signature dresses only SkillShow's wind-up, in place of the
## shared weapon charge: a golden sigil writes itself under the mage, light gathers into
## the staff in a growing corona, motes of gold rise round it, and as the ray falls a beam
## runs from the staff up into the sky seal.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const GOLD := {"c_core": Color("fff6d0"), "c_mid": Color("ffd86a"), "c_edge": Color("b8781a")}
const LIGHT := {"c_core": Color("fffbe8"), "c_mid": Color("fff0a0"), "c_edge": Color("d0a040")}
const SEAL := {"c_core": Color("fff0c0"), "c_mid": Color("f0c060"), "c_edge": Color("8a5a1a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.3, visual)
	var r := c.toward(origin, aim, duration + 0.3, "Windup", duration)
	if not r:
		return true
	var hand := r.to_local(c.hand())
	A.sigil(r, Vector3.UP * 0.05, 2.2, 8.0, SEAL, 0.0, duration + 0.25, duration * 0.7, 0.55, 0.5)
	A.glow(r, 2, hand, Vector3.ONE * 1.3, Vector3.ZERO, GOLD, 0.0, duration + 0.1, 0.45, {"billboard": true, "p1": 10.0, "p2": 0.3}, {"grow": duration, "from": 0.2})
	A.flash(r, hand, 0.9, LIGHT, 0.0, duration + 0.1, 0.45, {"grow": duration, "from": 0.2})
	if c.has(0):
		A.S.motes(r, Vector3.ZERO, 1.6, c.n(4, 7, 10), GOLD, 0.24, 0.0, duration * 0.6, 0.9, 1.8, 10, 1.0)
	# As the ray falls, a beam runs from the staff into the sky seal over the target.
	var sky := r.to_local(A.flat(aim)) + Vector3.UP * 7.0
	A.beam(r, hand, sky, 0.5, GOLD, duration * 0.8, 0.5, 0.55, 8.0)
	A.ring(r, Vector3.UP * 0.07, 2.6, GOLD, duration * 0.85, 0.5, 0.7)
	return true


## The ray (JudgmentRaySequence) draws everything after the wind-up.
static func play(_parent: Node3D, _skill: Dictionary, _center: Vector3, _origin: Vector3, _impact_delay: float) -> bool:
	return true
