extends RefCounted
## Assassin Lv.100 "Oblivion Requiem": a requiem of oblivion; the dark erupts and tears all
## round the assassin. Wind-up: a rune circle of the requiem turns under the assassin, the
## shadows of the field are drawn in, and in the sky behind the sun begins to go black.
## Release: the eclipse is total, its crimson corona blazing over the field; the darkness
## erupts in three waves of crimson and violet cuts, each wider than the last, out to the
## edge of the area; a legion of shadow figures lunges in from the rim, a dome of shadow
## shards bursts, the ground is scarred with crimson rays, a pool of night spreads, dark
## petals fountain and the stars of the stun spin. Blood crimson, abyss violet, blush and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "oblivion_requiem"
const CRIMSON := Color("ff4f7b")
const VIOLET := Color("9a6bff")
const BLUSH := Color("ffd0dc")
const LILAC := Color("e4d6ff")
const WINE := Color("4a0828")
const INK := Color(0.05, 0.01, 0.06)
const BEHIND := 3.0


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var radius := float(skill.get("radius", 9.0))
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, aim), visual)
	if r == null:
		return false
	G.flat(r, G.sigil("or_runes", CRIMSON, 3, 36, 6, 0.5), "Runes", Vector3.UP * 0.05, Vector3.ONE * 3.0, time + 0.04, G.lit(CRIMSON, 0.55, 0.5), {"initial": 0.4, "grow_time": 0.9, "fade_in": 0.08, "decay": 0.97, "spin": 1.8})
	G.bits(r, G.inward("or_drawn", "puff", G.n(18), radius * 0.6, radius, [Color(0.12, 0.02, 0.08), Color(0.14, 0.05, 0.22), INK], 0.6, 3.0, 0.7, 0.15, 1001, 0.1, 0.8), "Drawn", Vector3.ZERO, time + 0.04, {"life": time, "gravity": 0.0, "drag": 3.0, "piece": 0.6, "alpha": 0.55, "swell": 1.2, "shrink": 0.6, "spin": 2.0}, {"decay": 0.95})
	var behind := K.away(r) * BEHIND
	var high := G.sky_height(r, behind, 6.5)
	G.flat(r, G.eclipse("or_eclipse", CRIMSON, BLUSH, 18), "Dimming", behind + Vector3.UP * high, Vector3.ONE * 1.3, time + 0.04, G.lit(CRIMSON, 0.5, 0.6), {"initial": 0.4, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.99}, Vector3(G.TILT_BACK, K.facing(r), 0))
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.yaw(origin, who[1], G.facing(caster)) if who[1] != Vector3.INF else G.facing(caster)
	var radius := float(skill.get("radius", 9.0))
	var feet := Vector3(origin.x, 0.0, origin.z)
	var s := radius / 9.0
	var r := G.open(parent, feet, 1.9, "Skill_%s_erupt" % ID, turn, caster)
	if r == null:
		return false
	# Three waves of cuts, each wider than the last.
	G.flat(r, G.cut_storm("or_wave1b", 16, 0.8, 3.6, 0.22, M.a(CRIMSON, 0.95), M.a(CRIMSON.lightened(0.25), 0.9), M.a(INK, 1.0), 1002, 0.5, 2.0, 0.6), "Wave1", Vector3.ZERO, Vector3.ONE * s, 0.7, G.lit(CRIMSON, 0.65, 0.6, {"sweep": 0.08, "tail": 5.0}), {"fade_in": 0.01, "decay": 0.8})
	M.shock(r, "or_ring", CRIMSON, radius * 1.04, 0.0, 0.55, 0.2)
	G.flat(r, G.cut_storm("or_wave2b", 18, 3.0, 6.4, 0.24, M.a(VIOLET, 0.95), M.a(VIOLET.lightened(0.25), 0.9), M.a(INK, 1.0), 1003, 0.4, 1.9, 0.66), "Wave2", Vector3.ZERO, Vector3.ONE * s, 0.8, G.lit(VIOLET, 0.65, 0.6, {"sweep": 0.08, "tail": 5.0}), {"delay": 0.14, "fade_in": 0.01, "decay": 0.8})
	G.flat(r, G.cut_storm("or_wave3b", 20, 5.6, 8.8, 0.26, M.a(CRIMSON, 0.95), M.a(CRIMSON.lightened(0.25), 0.9), M.a(INK, 1.0), 1004, 0.3, 1.8, 0.72), "Wave3", Vector3.ZERO, Vector3.ONE * s, 0.9, G.lit(CRIMSON, 0.65, 0.6, {"sweep": 0.08, "tail": 5.0}), {"delay": 0.28, "fade_in": 0.01, "decay": 0.8})
	G.flat(r, K.glow_disc("or_pool", Color(0.08, 0.01, 0.06, 0.65)), "Pool", Vector3.UP * 0.035, Vector3.ONE * radius * 0.85, 1.85, {"soft": 0.6, "add": 0.0}, {"initial": 0.15, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.75})
	G.flat(r, G.rays("or_scars", 14, WINE.lightened(0.35), 0.022, 0.15, 1005), "Scars", Vector3.UP * 0.055, Vector3.ONE * radius * 0.9, 1.6, G.lit(CRIMSON, 0.35, 0.6, {"sweep": 0.35, "flick": 0.08}), {"fade_in": 0.01, "decay": 0.7})
	G.done(r)
	var more := G.extras(3)
	if more > 0:
		var sky := G.open(parent, feet, 1.9, "Skill_%s_eclipse" % ID, turn, caster)
		if sky:
			var behind := K.away(sky) * BEHIND
			var high := G.sky_height(sky, behind, 6.5)
			G.flat(sky, G.eclipse("or_eclipse", CRIMSON, BLUSH, 18), "Eclipse", behind + Vector3.UP * high, Vector3.ONE * 1.9, 1.8, G.lit(CRIMSON, 0.6, 0.6, {"flick": 0.1}), {"initial": 0.7, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.8, "spin": 0.4}, Vector3(G.TILT_BACK, K.facing(sky), 0))
			G.bits(sky, K.burst("or_petals", "feather", G.n(40), 0.5, 3.0, 5.0, 6.5, [CRIMSON, WINE, INK, VIOLET, BLUSH], 0.4, 0.3, 1006, 0.3, 1.6), "Petals", Vector3.ZERO, 1.8, {"life": 1.6, "gravity": 2.8, "drag": 1.2, "piece": 0.4, "sway": 0.4, "spin": 6.0, "floor_y": 0.08, "shrink": 0.85}, {"decay": 0.9})
			G.daze(sky, Color("ffd070"), Vector3(0, 2.5, 2.6), 1.1, 1.5, 0.2, 6)
			G.done(sky)
	if more > 1:
		var legion := G.open(parent, feet, 1.2, "Skill_%s_legion" % ID, turn + PI / 6.0, caster)
		if legion:
			G.solid(legion, G.legion("or_legion", 6, 5.8, INK, WINE, CRIMSON, true, 0.03), "Legion", Vector3.ZERO, Vector3.ONE * 1.1 * s, 0.8, {"rim_color": CRIMSON, "rim": 1.5, "glow_color": BLUSH, "dim": 0.8}, {"delay": 0.08, "initial": 1.25, "grow_time": 0.6, "fade_in": 0.02, "decay": 0.45})
			M.cracks(legion, "or_cracks", CRIMSON, radius * 0.6, 0.05, 1.1, 10, 1007, 0.07)
			M.shock(legion, "or_ring_b", VIOLET, radius * 0.7, 0.16, 0.5, 0.12)
			G.done(legion)
	if more > 2:
		var dome := G.open(parent, feet, 1.4, "Skill_%s_shards" % ID, turn, caster)
		if dome:
			G.bits(dome, K.burst("or_shards", "shard", G.n(30), 0.6, 2.0, 6.0, 7.0, [INK, WINE, Color(0.14, 0.05, 0.22), CRIMSON], 0.36, 0.08, 1008, 0.4, 1.8), "Shards", Vector3.ZERO, 1.3, {"life": 1.1, "gravity": 9.0, "drag": 0.8, "piece": 0.36, "floor_y": 0.06, "shrink": 0.8, "spin": 9.0, "hot": Color(1.0, 0.3, 0.45, 0.5)}, {"delay": 0.03, "decay": 0.85})
			M.flash(dome, "or_flash", WINE, 3.2, 0.0, 0.5)
			M.shock(dome, "or_ring_c", BLUSH, radius * 1.15, 0.3, 0.6, 0.08)
			G.done(dome)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [CRIMSON, BLUSH], crit, true)
