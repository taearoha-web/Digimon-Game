extends RefCounted
## Warrior Lv.88 "Godly Shield" (self: DEF up, heals): a god's shield is raised over the
## warrior. Wind-up: a blue-and-gold seal opens at his feet, a faint ward of light begins
## to curve up round him and motes gather. Release: a great heraldic shield rises behind
## him (as the camera sees it, so he stays in view), the lattice ward closes over him and
## settles in, a ring snaps out, a column of pale blue light stands up and motes rise.
## Aftermath: the shield and the ward fade while blue shards drift down. Sky blue, royal
## blue and gold (the skill's own white is tinted: no white-out).
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const SKY := Color("8fd0ff")
const ROYAL := Color("3a7cff")
const GOLD := Color("ffd76a")
const PALE := Color("e2f2ff")
const DEEP := Color("1a3a7a")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.runes("gshield_seal", B.a(SKY, 0.95), 12, 0.72), "GShieldSeal", Vector3.UP * 0.06, Vector3.ONE * 2.4, t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(GOLD, 0.8), "add": 0.55}, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.05, "spin": -0.8, "decay": 0.97})
	B.light(art, B.dome("gshield_dome", B.a(SKY, 0.8), 10, 3), "GShieldRising", Vector3.ZERO, Vector3(1.7, 0.4, 1.7), t + 0.05, {"sweep": t, "soft": 0.8, "hot": B.hot(PALE, 0.6), "add": 0.55}, {"initial": 1.4, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.97})
	B.bits(art, B.gather("gshield_gather", "ember", 16, 2.4, 5.0, 1.0, [SKY, GOLD, PALE], 0.12, 101, 0.3, 2.0), "GShieldGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.12, "add": 0.8, "shrink": 0.4})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var at := B.ground(origin)
	var art := B.open(c, at, 2.0, "Aegis")
	if art == null:
		return false
	B.follow(c, art)
	# The god's shield, rising behind him (as the camera sees it) and facing the camera.
	var spot := K.beyond(art, 1.1)
	var h := B.sky(c, at + spot, 4.6)
	var size := clampf(h / 4.6, 0.65, 1.0) * 2.7
	var shield := M.get_mesh("gshield_shield") if M.has("gshield_shield") else M.solid("gshield_shield", M.shield(ROYAL, GOLD, SKY))
	B.body(art, shield, "GShieldShield", spot + Vector3.UP * maxf(0.6, h - size - 0.2), Vector3.ONE * size, 1.9, {"rim_color": SKY, "rim": 0.9, "glow_color": GOLD}, {"initial": 0.25, "grow_time": 0.18, "fade_in": 0.01, "decay": 0.7, "face_camera": true, "travel": Vector3.UP * 0.35})
	B.light(art, B.dome("gshield_dome", B.a(SKY, 0.8), 10, 3), "GShieldDome", Vector3.ZERO, Vector3(1.7, 1.9, 1.7), 1.6, {"soft": 0.8, "hot": B.hot(PALE, 0.7), "flick": 0.05, "add": 0.6}, {"initial": 1.45, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.5})
	M.shock(art, "gshield_shock", SKY, 3.6, 0.02, 0.5, 0.22, 0.1)
	M.pillar(art, "gshield_pillar", SKY, 1.3, 5.0, 0.0, 0.6)
	B.light(art, B.runes("gshield_seal", B.a(SKY, 0.95), 12, 0.72), "GShieldGround", Vector3.UP * 0.06, Vector3.ONE * 2.6, 1.9, {"soft": 0.6, "hot": B.hot(GOLD, 0.8), "flick": 0.05, "add": 0.5}, {"initial": 0.95, "grow_time": 0.1, "spin": -0.6, "decay": 0.6})
	M.sparks(art, "gshield_motes", [SKY, GOLD, PALE], 24, 0.4, 1.8, 1.0, 4.0, 0.13, 0.05, 1.6, Vector3.ZERO, -1.0, 102, 0.2, 1.2)
	var after := B.open(c, at, 2.0, "Shards", 1)
	if after:
		B.bits(after, B.fall("gshield_shards", "shard", 22, 2.6, 2.2, 4.0, [SKY, PALE, GOLD], 0.22, 103, 0.6), "GShieldShards", Vector3.ZERO, 1.9, {"life": 1.6, "gravity": 0.5, "drag": 0.6, "piece": 0.22, "add": 0.6, "shrink": 0.5, "spin": 4.0, "sway": 0.3}, {"delay": 0.15})
	return true
