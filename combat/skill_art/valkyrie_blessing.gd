extends RefCounted
## Lancer Lv.88 "Valkyrie's Blessing" (self: ATK, speed, crit up): a valkyrie's blessing
## from the sky. Wind-up: a shaft of pale gold light comes down on the lancer and a ring of
## light opens at his feet. Release: great wings of white-gold light unfold behind him, a
## halo turns over his head, a valkyrie's spear drops out of the sky and plants itself
## beside him, a ring rolls out and a column of light stands up; feathers drift down after.
## Aftermath: wings fold away into light. Pale gold, sky white, soft blue.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const GOLD := Color("ffe08a")
const PALE := Color("fff6dc")
const BLUE := Color("a8d0ff")
const DEEP := Color("8a6a2a")
const SPEAR := 3.4


static func _spear() -> ArrayMesh:
	return M.get_mesh("valk_spear") if M.has("valk_spear") else M.solid("valk_spear", M.lance(Color("c8a050"), PALE, GOLD))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var at := B.ground(origin)
	var art := B.open(c, at, t + 0.05, "Windup")
	if art == null:
		return false
	var h := B.sky(c, at, 8.0)
	B.light(art, B.streak("valk_shaft", 1.4, B.a(GOLD, 0.0), B.a(PALE, 0.85)), "ValkShaft", Vector3.UP * h, Vector3(1, 1, h), t + 0.05, {"sweep": t * 0.7, "soft": 1.2, "hot": B.hot(PALE), "flow": 3.0, "add": 0.7}, {"fade_in": 0.1, "decay": 0.95}, Vector3(PI * 0.5, 0, 0))
	B.light(art, B.runes("valk_ring", B.a(GOLD, 0.95), 8, 0.82), "ValkRing", Vector3.UP * 0.06, Vector3.ONE * 2.2, t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(PALE, 0.8), "add": 0.55}, {"initial": 0.5, "grow_time": 0.8, "spin": 0.9, "decay": 0.97})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var at := B.ground(origin)
	var art := B.open(c, at, 2.0, "Wings")
	if art == null:
		return false
	B.follow(c, art)
	var behind := K.beyond(art, 0.45)
	B.light(art, B.wings("valk_wings", 9, B.a(PALE, 0.97), B.a(GOLD, 0.9), B.a(BLUE, 0.7), 1.0), "ValkWings", behind + Vector3.UP * 1.25, Vector3.ONE * 2.5, 1.85, {"soft": 0.5, "hot": B.hot(PALE), "core": 0.4, "add": 0.6}, {"initial": 0.25, "grow_time": 0.22, "fade_in": 0.01, "decay": 0.65, "face_camera": true, "flap": 0.04, "flap_rate": 5.0})
	B.light(art, B.hoop("valk_halo", B.a(GOLD, 1.0), 0.16), "ValkHalo", Vector3.UP * 2.5, Vector3.ONE * 0.55, 1.8, {"soft": 0.8, "hot": B.hot(PALE), "add": 0.7}, {"initial": 0.3, "grow_time": 0.25, "fade_in": 0.01, "decay": 0.65}, Vector3(PI * 0.5, 0, 0))
	# The valkyrie's spear drops from the sky and stands planted beside him.
	var side := K.away(art).cross(Vector3.UP).normalized() * 1.5 - K.away(art) * 0.6
	var drop := B.sky(c, at, 8.0)
	B.body(art, _spear(), "ValkSpear", side + Vector3.DOWN * 0.4, Vector3.ONE * SPEAR, 1.8, {"drop": drop / SPEAR, "flight": 0.16, "rim_color": PALE, "rim": 0.9, "glow_color": GOLD, "heat": 0.8}, {"fade_in": 0.01, "decay": 0.7})
	M.shock(art, "valk_shock", GOLD, 4.0, 0.16, 0.5, 0.22, 0.1)
	M.pillar(art, "valk_pillar", GOLD, 2.6, 7.0, 0.0, 0.65)
	var rain := B.open(c, at, 2.4, "Feathers", 1)
	if rain:
		B.bits(rain, B.fall("valk_feathers", "feather", 22, 2.6, 2.6, 5.0, [PALE, GOLD, BLUE], 0.32, 221, 0.7), "ValkFeathers", Vector3.ZERO, 2.3, {"life": 2.0, "gravity": 0.3, "drag": 0.6, "piece": 0.32, "add": 0.3, "shrink": 0.6, "spin": 3.0, "sway": 0.4}, {"delay": 0.15})
		B.light(rain, B.runes("valk_ring", B.a(GOLD, 0.95), 8, 0.82), "ValkGround", Vector3.UP * 0.06, Vector3.ONE * 2.4, 1.9, {"soft": 0.6, "hot": B.hot(PALE, 0.8), "flick": 0.05, "add": 0.5}, {"initial": 0.95, "grow_time": 0.1, "spin": 0.6, "decay": 0.6})
	return true
