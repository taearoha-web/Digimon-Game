extends RefCounted
## Warrior Lv.84 "Sword of Justice" (single target): judgment falls from the sky. Wind-up:
## a gold seal of judgment turns under the target while a giant sword of light forms in the
## sky over it, point down. Release: the sword drops and drives into the target: a ring and
## a flash, fissures of light, a column of gold standing up round it and sparks thrown off.
## Aftermath: the sword stays planted a moment, then burns away from the hilt down. Gold,
## pale gold, steel.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const HOLY := Color("ffd85a")
const PALE := Color("fff3c0")
const STEEL := Color("dfe6f0")
const AMBER := Color("ffaa3a")
const ROCK := Color("7a6a5a")
## The giant sword's length and how far its point sinks into the ground.
const LENGTH := 5.2
const SINK := 0.8


static func _blade() -> ArrayMesh:
	return M.get_mesh("justice_sword") if M.has("justice_sword") else M.solid("justice_sword", B.sword(STEEL, HOLY, PALE, Color("8a5a2a"), 0.15), Vector3.ONE * 2.0)


## Height of the sword's point over the target before it falls.
static func _hover(c: Dictionary, at: Vector3) -> float:
	return clampf(B.sky(c, at, 7.5) - LENGTH, 0.6, 2.4)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var at := B.ground(aim)
	var art := B.open(c, at, t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.runes("justice_seal", B.a(HOLY, 0.95), 10), "JusticeSeal", Vector3.UP * 0.07, Vector3.ONE * 1.9, t + 0.05, {"sweep": t * 0.7, "soft": 0.6, "hot": B.hot(PALE, 0.8), "add": 0.55}, {"initial": 0.5, "grow_time": 0.6, "fade_in": 0.05, "spin": 1.2, "decay": 0.97})
	var hover := _hover(c, at)
	# The sword, point down over the target, forming out of light.
	B.body(art, _blade(), "JusticeForm", Vector3.UP * (hover + LENGTH), Vector3.ONE * LENGTH, t + 0.05, {"rim_color": PALE, "rim": 1.0, "glow_color": HOLY}, {"initial": 0.6, "grow_time": 0.8, "fade_in": 0.6, "decay": 0.99}, Vector3(PI, 0, 0))
	B.light(art, B.streak("justice_ray", 0.5, B.a(HOLY, 0.5), B.a(PALE, 0.0)), "JusticeRay", Vector3.UP * hover, Vector3(1, 1, hover), t + 0.05, {"soft": 1.2, "hot": B.hot(PALE, 0.6), "flow": 3.0, "add": 0.6}, {"fade_in": 0.3, "decay": 0.95}, Vector3(PI * 0.5, 0, 0))
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, center)
	var at := B.ground(center)
	var art := B.open(c, at, 1.5, "Judgment")
	if art == null:
		return false
	var hover := _hover(c, at)
	# The drop (in the sword's own space: it hangs upside down, scaled by LENGTH): from where it hung to its point buried in the ground, in a tenth of a second.
	B.body(art, _blade(), "JusticeSword", Vector3.UP * (LENGTH - SINK), Vector3.ONE * LENGTH, 1.35, {"drop": -(hover + SINK) / LENGTH, "flight": 0.1, "rim_color": PALE, "rim": 1.0, "glow_color": HOLY, "heat": 1.0}, {"fade_in": 0.01, "decay": 0.6, "front": true}, Vector3(PI, 0, 0))
	M.shock(art, "justice_shock", HOLY, 3.6, 0.1, 0.55, 0.24, 0.1)
	M.cracks(art, "justice_cracks", HOLY, 3.4, 0.1, 1.3, 9, 51)
	M.pillar(art, "justice_pillar", HOLY, 3.2, 6.0, 0.1, 0.6)
	M.flash(art, "justice_flash", HOLY, 2.8, 0.1, 0.4)
	M.sparks(art, "justice_sparks", [HOLY, PALE, AMBER], 24, 0.2, 0.8, 5.0, 5.0, 0.15, 0.1, 0.85, Vector3.UP * 0.4, 7.0, 52)
	var after := B.open(c, at, 1.5, "Verdict", 1)
	if after:
		B.light(after, B.runes("justice_seal", B.a(HOLY, 0.95), 10), "JusticeSealAfter", Vector3.UP * 0.07, Vector3.ONE * 2.1, 1.4, {"soft": 0.6, "hot": B.hot(PALE, 0.8), "flick": 0.06, "add": 0.5}, {"initial": 1.0, "spin": 0.6, "decay": 0.55})
		M.rubble(after, "justice_rubble", [ROCK, ROCK.lightened(0.15)], 12, 0.2, 0.8, 3.0, 5.5, 0.26, 0.1, 1.1, Vector3.ZERO, 53)
		M.dust(after, "justice_dust", Color("d8c8a8"), 10, 1.0, 2.2, 0.12, 1.2, Vector3.ZERO, 0.8, 54)
	return true
