extends RefCounted
## Mage Lv.60 "Meteo" (เมทีโอ): a meteor called down onto the field. Cosmetic only.
## Wind-up: a sigil of fire writes itself under the mage, the staff burns and the sky over
## the target glows. Release: a burning meteor drops out of the glowing sky, its warning
## ring tightening on the ground below. Landing (with the real hit): a burst of flame and
## a shock ring, a short column of fire, a scorch whose cracks cool, rocks and sparks thrown
## up; the burn smoulders in licks of flame and the smoke rises.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const FIRE := {"c_core": Color("ffe6a0"), "c_mid": Color("ff8a3a"), "c_edge": Color("c02a1a")}
const BLAZE := {"c_core": Color("fff0b8"), "c_mid": Color("ffaa4a"), "c_edge": Color("e0501a")}
const WARN := {"c_core": Color("ffd0a0"), "c_mid": Color("ff7a3a"), "c_edge": Color("a02a1a")}
const ASH := {"c_core": Color("3a2420"), "c_mid": Color("ff6a2a"), "c_edge": Color("1a0e0c")}
const SMOKE := {"c_core": Color("8a7a78"), "c_mid": Color("5a4a4a"), "c_edge": Color("2a2026")}
const ROCK := {"tint": Color("8a4a3a"), "ember": Color("ffb04a"), "glow": Color("ff9a5a"), "rim": 0.8, "shadow": Color("3a1a1a")}


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 8.0)), 3.0, 10.0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.8, visual)
	var w := c.toward(origin, aim, duration + 0.12, "Staff", duration)
	if w:
		A.sigil(w, Vector3.UP * 0.05, 2.0, 5.0, FIRE, 0.0, duration + 0.12, duration * 0.8, 0.5, 0.6)
		A.flash(w, w.to_local(c.hand()), 1.2, BLAZE, 0.0, duration + 0.1, 0.55, {"grow": duration, "from": 0.2})
	var centre := A.flat(aim)
	var g := c.toward(centre, centre + (centre - origin), duration + 0.8, "Sky", duration)
	if g:
		var sky := Vector3(-2.5, clampf(GodSkillArt.headroom(g, g.global_position) - 0.5, 5.0, 8.0), -1.5)
		A.flash(g, sky, 4.0, FIRE, duration * 0.3, duration * 0.7 + 0.75, 0.25, {"grow": duration * 0.7, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, impact_delay: float) -> bool:
	var land := maxf(impact_delay, 0.05)
	var rad := _radius(skill)
	var c := A.cast(parent, skill, origin, land + 2.0)
	var centre := A.flat(center)
	var r := c.toward(centre, centre + (centre - origin), land + 2.0, "Meteor")
	if not r:
		return true
	var sky := Vector3(-2.5, clampf(GodSkillArt.headroom(r, r.global_position) - 0.5, 5.0, 8.0), -1.5)
	var start := sky * 1.6
	var dive := Vector3(0, 0.6, 0) - start
	# The meteor drops, the warning ring tightens below it.
	A.solid(r, K.mesh("meteor"), ROCK, start, Vector3.ONE * 1.9, A.pointing(dive), 0.0, land + 0.02, {"travel": dive, "tw": Vector2(0, land), "ease": 1, "fin": 0.03, "fout": 0.02, "priority": 3})
	A.flash(r, start, 2.6, BLAZE, 0.0, land + 0.02, 0.4, {"travel": dive, "tw": Vector2(0, land), "ease": 1, "fout": 0.02})
	A.ring(r, Vector3.UP * 0.07, rad * 0.9, WARN, 0.0, land, 0.4, {"to": Vector3.ONE * 0.35})
	# The landing.
	A.flash(r, Vector3.UP * 0.9, rad * 0.6, FIRE, land, 0.35, 0.45)
	A.ring(r, Vector3.UP * 0.08, rad * 1.1, FIRE, land, 0.6, 0.6)
	A.column(r, Vector3.ZERO, 1.6, 4.5, BLAZE, land, 0.7, 0.5, -5.0, {"to": Vector3(0.6, 1.0, 0.6)})
	A.puffs(r, Vector3.ZERO, rad * 0.45, c.n(4, 6, 9), BLAZE, 1.4, land, 0.75, 1.0, true, 3.0, 0.12)
	if c.has(0):
		A.scorch(r, Vector3.UP * 0.04, rad * 0.5, ASH, land, 2.2, 2.0)
		A.S.sparks(r, Vector3.UP * 0.6, c.n(8, 12, 18), BLAZE, 0.3, land, 0.9, 10.0, 6.0, 9, 1.2, 2.0)
	if c.has(1):
		A.ring(r, Vector3.UP * 0.09, rad * 0.7, BLAZE, land + 0.12, 0.6, 0.45)
		A.fire_wall(r, Vector3.ZERO, rad * 0.35, 0.8, FIRE, land + 0.1, 1.5, 0.7, {"grow": 0.2, "from": 0.4})
		A.clouds(r, Vector3.UP * 1.6, rad * 0.25, c.n(2, 3, 5), SMOKE, 1.5, land + 0.45, 1.2, 0.4, 7.0)
	return true
