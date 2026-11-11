extends RefCounted
## Mage Lv.80 "Hell Meteor" (อุกกาบาตนรก): a meteor torn out of hell. Cosmetic only.
## Wind-up: a rift of hellfire opens in the sky over the area (a disc of burning dark rimmed
## with fire), a red sigil writes itself on the ground below and the mage's staff burns.
## Release: a great dark-red meteor sheathed in fire drives out of the rift, its warning
## ring tightening below. Landing (with the real hit): a burst of hellfire and two shock
## rings, a wall of fire springing up round the crater, a column of flame, a wide cracked
## scorch, rocks, sparks and smoke; the rift closes and the burn smoulders.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const HELL := {"c_core": Color("ffc890"), "c_mid": Color("ff4a2a"), "c_edge": Color("8a0a1a")}
const FIRE := {"c_core": Color("ffe0a0"), "c_mid": Color("ff7a2a"), "c_edge": Color("c0201a")}
const BLAZE := {"c_core": Color("fff0b8"), "c_mid": Color("ffa04a"), "c_edge": Color("e0401a")}
const RIFT := {"c_core": Color("ff9a5a"), "c_mid": Color("a01a2a"), "c_edge": Color("2a0610")}
const ASH := {"c_core": Color("3a1a18"), "c_mid": Color("ff5a2a"), "c_edge": Color("140808")}
const SMOKE := {"c_core": Color("7a6a6a"), "c_mid": Color("4a3a3e"), "c_edge": Color("201820")}
const ROCK := {"tint": Color("6a2a2a"), "ember": Color("ff7a3a"), "glow": Color("ff5a3a"), "rim": 0.9, "shadow": Color("200a10")}


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 9.0)), 3.0, 10.0)


static func _sky(r: K) -> Vector3:
	var back := -r.toward_camera() * 4.0
	return back + Vector3(0, clampf(GodSkillArt.headroom(r, r.global_position + r.global_basis * back) - 1.0, 4.5, 7.5), 0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.9, visual)
	var rad := _radius(skill)
	var w := c.toward(origin, aim, duration + 0.12, "Staff", duration)
	if w:
		A.flash(w, w.to_local(c.hand()), 1.3, FIRE, 0.0, duration + 0.1, 0.55, {"grow": duration, "from": 0.2})
		A.sigil(w, Vector3.UP * 0.05, 2.0, 5.0, HELL, 0.0, duration + 0.12, duration * 0.8, 0.5, -0.7)
	var centre := A.flat(aim)
	var g := c.toward(centre, centre + (centre - origin), duration + 0.9, "Rift", duration)
	if g:
		var sky := _sky(g)
		var yaw := A.S.face_camera(g)
		var disc := Vector3(-0.9, yaw, 0)
		A.glow(g, 4, sky, Vector3.ONE * 2.6, disc, RIFT, 0.0, duration + 0.85, 0.9, {"p1": 0.9}, {"grow": duration * 0.8, "from": 0.1, "fin": 0.1, "fout": 0.3, "veil": true})
		A.glow(g, 1, sky, Vector3.ONE * 3.0, disc, HELL, duration * 0.3, duration * 0.7 + 0.5, 0.6, {"p1": 0.7, "life": 9.0}, {"fout": 0.3, "veil": true})
		A.sigil(g, Vector3.UP * 0.05, rad, 5.0, HELL, 0.0, duration + 0.85, duration, 0.42, 0.25)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, impact_delay: float) -> bool:
	var land := maxf(impact_delay, 0.05)
	var rad := _radius(skill)
	var c := A.cast(parent, skill, origin, land + 2.4)
	var centre := A.flat(center)
	var r := c.toward(centre, centre + (centre - origin), land + 2.4, "Meteor")
	if not r:
		return true
	var sky := _sky(r)
	var dive := Vector3(0, 0.8, 0) - sky
	var o := {"travel": dive, "tw": Vector2(0, land), "ease": 1, "fin": 0.04, "fout": 0.02, "priority": 3}
	A.solid(r, K.mesh("meteor"), ROCK, sky, Vector3.ONE * 2.8, A.pointing(dive), 0.0, land + 0.02, o)
	A.glow(r, 2, sky, Vector3.ONE * 2.6, Vector3.ZERO, FIRE, 0.0, land + 0.02, 0.5, {"billboard": true, "p1": 9.0, "p2": 0.35}, o.merged({"priority": 2}))
	A.ring(r, Vector3.UP * 0.07, rad * 0.9, HELL, 0.0, land, 0.45, {"to": Vector3.ONE * 0.3})
	# The landing.
	A.flash(r, Vector3.UP * 1.0, rad * 0.55, HELL, land, 0.4, 0.3)
	A.ring(r, Vector3.UP * 0.08, rad * 1.12, FIRE, land, 0.65, 0.65)
	A.column(r, Vector3.ZERO, 2.0, 6.0, BLAZE, land, 0.8, 0.5, -5.0, {"to": Vector3(0.6, 1.0, 0.6)})
	A.puffs(r, Vector3.ZERO, rad * 0.5, c.n(5, 8, 12), FIRE, 1.6, land, 0.8, 1.1, true, 3.0, 0.14)
	if c.has(0):
		A.fire_wall(r, Vector3.ZERO, rad * 0.55, 1.6, HELL, land + 0.05, 1.6, 0.75, {"grow": 0.18, "from": 0.4})
		A.scorch(r, Vector3.UP * 0.04, rad * 0.6, ASH, land, 2.4, 6.0)
		A.S.sparks(r, Vector3.UP * 0.6, c.n(10, 16, 24), BLAZE, 0.32, land, 1.0, 12.0, 6.0, 9, 1.2, 2.0)
	if c.has(1):
		A.ring(r, Vector3.UP * 0.09, rad * 0.75, BLAZE, land + 0.14, 0.7, 0.5)
		A.clouds(r, Vector3.UP * 1.8, rad * 0.35, c.n(3, 4, 6), SMOKE, 1.8, land + 0.45, 1.4, 0.4, 9.0)
		var yaw := A.S.face_camera(r)
		A.glow(r, 4, sky, Vector3.ONE * 2.6, Vector3(-0.9, yaw, 0), RIFT, 0.0, land + 0.5, 0.9, {"p1": 0.9}, {"to": Vector3.ONE * 0.2, "fout": 0.4, "veil": true})
	return true
