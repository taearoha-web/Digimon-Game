extends RefCounted
## Warrior Lv.76 "Drastic Spirit" (self: DEF up, heals): the warrior's fighting spirit
## flares up as fire. Wind-up: low flames lick round his boots, a ring of fire runes kindles
## on the ground and embers are drawn in. Release: a crown of tall crimson-and-gold flames
## roars up round him with a lower ring outside it, a column of orange light, a ring snapping
## out and embers rising; the fire runes burn on and the flames settle. Crimson, orange,
## pale gold (the skill's own), never a white flash.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const CRIMSON := Color("ff4a2a")
const ORANGE := Color("ff9a3a")
const GOLD := Color("ffe9a0")
const DEEP := Color("6a1a08")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.flames("drastic_low", 12, 0.9, 0.4, B.a(CRIMSON, 0.9), B.a(GOLD, 0.0), 41), "DrasticLow", Vector3.UP * 0.05, Vector3(0.8, 1.0, 0.8), t + 0.05, {"soft": 0.8, "hot": B.hot(ORANGE), "flow": 3.5, "flick": 0.15, "add": 0.65}, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95})
	B.light(art, B.runes("drastic_runes", B.a(ORANGE, 0.9), 8), "DrasticRunes", Vector3.UP * 0.06, Vector3.ONE * 2.3, t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(GOLD, 0.8), "add": 0.5}, {"initial": 0.7, "grow_time": 0.8, "fade_in": 0.1, "spin": 0.8, "decay": 0.95})
	B.bits(art, B.gather("drastic_gather", "ember", 16, 2.4, 5.0, 1.2, [CRIMSON, ORANGE, GOLD], 0.12, 42, 0.2, 1.6), "DrasticGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.12, "add": 0.8, "shrink": 0.4})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var art := B.open(c, B.ground(origin), 1.8, "Spirit")
	if art == null:
		return false
	B.follow(c, art)
	# The spirit roars up: a crown of tall flames and a lower ring outside it.
	B.light(art, B.flames("drastic_crown", 18, 3.0, 0.9, B.a(CRIMSON, 1.0), B.a(ORANGE, 0.2), 43), "DrasticCrown", Vector3.UP * 0.05, Vector3(1.1, 1.0, 1.1), 1.6, {"soft": 0.55, "hot": B.hot(ORANGE), "core": 0.4, "flow": 3.2, "flick": 0.12, "add": 0.7}, {"initial": 0.35, "grow_time": 0.18, "fade_in": 0.01, "decay": 0.55})
	M.pillar(art, "drastic_pillar", ORANGE, 2.6, 5.5, 0.0, 0.6)
	M.shock(art, "drastic_shock", CRIMSON, 3.6, 0.03, 0.5, 0.22, 0.1)
	B.light(art, B.flames("drastic_ring", 24, 1.6, 0.7, B.a(ORANGE, 0.95), B.a(GOLD, 0.1), 44), "DrasticRing", Vector3.UP * 0.05, Vector3(2.1, 1.0, 2.1), 1.3, {"soft": 0.6, "hot": B.hot(GOLD, 0.8), "flow": 2.6, "flick": 0.15, "add": 0.65}, {"delay": 0.05, "initial": 0.5, "grow_time": 0.25, "decay": 0.5})
	B.light(art, B.runes("drastic_runes", B.a(ORANGE, 0.9), 8), "DrasticSeal", Vector3.UP * 0.06, Vector3.ONE * 2.6, 1.75, {"soft": 0.6, "hot": B.hot(GOLD, 0.8), "flick": 0.08, "add": 0.5}, {"initial": 0.9, "grow_time": 0.15, "spin": 0.8, "decay": 0.6})
	M.sparks(art, "drastic_embers", [CRIMSON, ORANGE, GOLD], 30, 0.3, 1.6, 1.4, 5.5, 0.14, 0.02, 1.5, Vector3.ZERO, -1.2, 45, 0.2, 1.4)
	return true
