extends RefCounted
## Warrior Lv.96 "Triumph of Valhalla" (self: ATK, crit, speed up): the hall of heroes
## hails the warrior. Wind-up: a gold ring of Norse runes opens at his feet and light pours
## up his raised sword. Release: six painted round shields of the einherjar heave up out of
## the ground in a ring round him and turn slowly, a horned war-helm of gold rises over his
## head, a column of gold light stands up, a ring rolls out and a fountain of gold sparks
## bursts; gold confetti showers down after. Aftermath: the shields sink back and the helm
## fades. Gold, bronze, shield red and blue.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const GOLD := Color("ffd84a")
const BRONZE := Color("c8862a")
const RED := Color("c83a2a")
const BLUE := Color("2a5aa8")
const PALE := Color("fff2c0")
const WOOD := Color("8a5a2a")
const RING := 2.6


## Six round shields standing in a ring of radius RING, faces out, rising one after another.
static func _shields() -> ArrayMesh:
	if M.has("valhalla_shields"):
		return M.get_mesh("valhalla_shields")
	var st := K.begin()
	for i in 6:
		var ang := TAU * float(i) / 6.0 + PI / 6.0
		var dir := Vector3(sin(ang), 0, cos(ang))
		var face := B.round_shield(RED if i % 2 == 0 else BLUE, PALE if i % 2 == 0 else GOLD, BRONZE, GOLD)
		var basis := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, -0.18)
		K.stamp(st, face, Transform3D(basis.scaled(Vector3.ONE * 0.9), dir * RING + Vector3.UP * 1.0), 0.04 * float(i), 1.0)
	return M.keep("valhalla_shields", K.finish(st, Vector3(1, 3, 1)))


static func _helm() -> ArrayMesh:
	return M.get_mesh("valhalla_helm") if M.has("valhalla_helm") else M.solid("valhalla_helm", B.horned_helm(GOLD, Color("fff0d0"), BRONZE))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	B.light(art, B.runes("valhalla_runes", B.a(GOLD, 0.95), 16, 0.8), "ValhallaRunes", Vector3.UP * 0.06, Vector3.ONE * 3.0, t + 0.05, {"sweep": t * 0.8, "soft": 0.6, "hot": B.hot(PALE, 0.8), "add": 0.55}, {"initial": 0.5, "grow_time": 0.8, "spin": 0.7, "decay": 0.97})
	B.light(art, B.streak("valhalla_raise", 0.5, B.a(GOLD, 0.0), B.a(PALE, 0.9)), "ValhallaRaise", Vector3.UP * 0.3, Vector3(1, 1, 2.6), t + 0.05, {"sweep": t * 0.7, "soft": 1.2, "hot": B.hot(PALE), "flow": 3.0, "add": 0.7}, {"fade_in": 0.1, "decay": 0.95}, Vector3(-PI * 0.5, 0, 0))
	B.bits(art, B.gather("valhalla_gather", "ember", 18, 2.8, 5.0, 2.0, [GOLD, PALE, BRONZE], 0.13, 121, 0.3, 2.0), "ValhallaGather", Vector3.ZERO, t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.13, "add": 0.8, "shrink": 0.4})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var at := B.ground(origin)
	var art := B.open(c, at, 2.2, "Hall")
	if art == null:
		return false
	B.follow(c, art)
	B.body(art, _shields(), "ValhallaShields", Vector3.ZERO, Vector3.ONE, 2.1, {"drop": -2.2, "flight": 0.3, "ease": 1.0, "rim_color": PALE, "rim": 0.6, "glow_color": GOLD, "heat": 0.5}, {"fade_in": 0.01, "decay": 0.72, "spin": 0.5})
	var h := B.sky(c, at, 4.4)
	B.body(art, _helm(), "ValhallaHelm", Vector3.UP * clampf(h - 1.2, 2.5, 3.6), Vector3.ONE * 1.7, 1.9, {"rim_color": PALE, "rim": 0.8, "glow_color": GOLD}, {"initial": 0.3, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.7, "face_camera": true, "travel": Vector3.UP * 0.35})
	M.pillar(art, "valhalla_pillar", GOLD, 3.2, 6.5, 0.0, 0.7)
	M.shock(art, "valhalla_shock", GOLD, 4.6, 0.03, 0.55, 0.22, 0.1)
	B.light(art, B.runes("valhalla_runes", B.a(GOLD, 0.95), 16, 0.8), "ValhallaGround", Vector3.UP * 0.06, Vector3.ONE * 3.2, 2.1, {"soft": 0.6, "hot": B.hot(PALE, 0.8), "flick": 0.05, "add": 0.5}, {"initial": 0.95, "grow_time": 0.1, "spin": 0.5, "decay": 0.6})
	M.sparks(art, "valhalla_fountain", [GOLD, PALE, BRONZE], 34, 0.2, 0.8, 3.5, 10.0, 0.16, 0.04, 1.4, Vector3.ZERO, 9.0, 122, 1.0, 2.2)
	var rain := B.open(c, at, 2.4, "Confetti", 1)
	if rain:
		B.bits(rain, B.fall("valhalla_confetti", "shard", 30, 3.6, 3.0, 5.5, [GOLD, PALE, RED, BLUE], 0.2, 123, 0.8), "ValhallaConfetti", Vector3.ZERO, 2.2, {"life": 1.9, "gravity": 0.6, "drag": 0.5, "piece": 0.2, "add": 0.3, "shrink": 0.6, "spin": 6.0, "sway": 0.35}, {"delay": 0.25})
		M.shock(rain, "valhalla_shock2", BRONZE, 6.0, 0.18, 0.6, 0.16, 0.08)
	return true
