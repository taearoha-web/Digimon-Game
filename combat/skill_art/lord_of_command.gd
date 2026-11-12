extends RefCounted
## Dark Lord Lv.76: Lord of Command (จ้าวบัญชาการ). The Lord raises the scepter: a royal
## seal of gold opens underfoot and golden light climbs round the Lord. On the release a
## ring of violet-and-gold standards rises out of the ground round the Lord, banners
## snapping, a small gold crown of light turns over the Lord's head, a column of gold
## light flares and a ring of command runs out; each ally the order reaches gets a gold
## ring at their feet. The standards sink as the light settles. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const ROYAL := Color("e8b64a")
const GOLD_HI := Color("fff0c0")
const GOLD_DK := Color("8a5a18")
const VIOLET := Color("8a4dff")
const VIOLET_DK := Color("3a1a6a")
const POLE := Color("2a2030")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.12
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, M.sigil("command", GOLD_HI, Color(ROYAL, 0.22), 8, 3, 8), "CommandSeal", Vector3.UP * 0.05, Vector3.ONE * 1.8, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": 1.2, "decay": 0.9})
		K.put(art, K.VEIL, S.spiral("command_rise", Color(1.0, 0.82, 0.4, 0.75), Color(0.75, 0.55, 1.0, 0.0), 3, 1.3, 0.5), "CommandRise", Vector3.UP * 0.1, Vector3(1.2, 2.6, 1.2), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": 5.0, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var court := c.open(origin, 2.2, "Court", c.caster)
	if court:
		K.put(court, K.SOLID, M.standards("command", POLE, VIOLET_DK.lightened(0.15), ROYAL, 6), "CommandStandards", Vector3.ZERO, Vector3(2.4, 2.0, 2.4), Vector3.ZERO, 2.1, {"initial": 1.0, "fade_in": 0.01, "decay": 0.65, "spin": 0.15, "cull": 4.0}, M.GOLD_LOOK.merged({"slide": Vector3(0, -2.2, 0), "slide_time": 0.3, "slide_ease": -2.5, "flap": 0.12, "flap_rate": 7.0}))
		K.put(court, K.SOLID, M.crown("command", ROYAL, VIOLET, 7), "CommandCrown", Vector3.UP * 2.55, Vector3.ONE * 0.36, Vector3.ZERO, 2.0, {"initial": 0.3, "grow_time": 0.2, "fade_in": 0.02, "spin": 1.6, "decay": 0.7}, M.GOLD_LOOK.merged({"slide": Vector3(0, 1.0, 0), "slide_time": 0.3, "slide_ease": -2.0}))
		K.put(court, K.VEIL, M.sigil("command", GOLD_HI, Color(ROYAL, 0.22), 8, 3, 8), "CommandSealOpen", Vector3.UP * 0.05, Vector3.ONE * 2.7, Vector3.ZERO, 2.0, {"initial": 0.6, "grow_time": 0.2, "fade_in": 0.01, "spin": 0.5, "decay": 0.6, "priority": -1})
		K.put(court, K.VEIL, K.column("command_light", [Color(1.0, 0.8, 0.35, 0.55), Color(1.0, 0.85, 0.45, 0.4), Color(0.8, 0.6, 1.0, 0.15), Color(0.8, 0.6, 1.0, 0.0)], 0.7, 16), "CommandPillar", Vector3.ZERO, Vector3(1.2, 5.5, 1.2), Vector3.ZERO, 0.8, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.3}, {"opacity": 0.55, "noise_amt": 0.5, "noise_scale": Vector2(6.0, 1.5), "flow": Vector2(0.0, -3.0), "bias": 0.1, "taper": 0.5, "fres": 0.5})
		M.show(court)
	var order := c.open(origin, 1.6, "Order", c.caster)
	if order:
		K.put(order, K.VEIL, K.shock(ROYAL, GOLD_HI, GOLD_DK), "CommandRing", Vector3.UP * 0.08, Vector3.ONE * 4.6, Vector3.ZERO, 0.65, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.8})
		K.put(order, K.VEIL, S.sparkles("command_gold", [ROYAL, GOLD_HI, Color("c8a0ff")], 22, 3.5, 2.0), "CommandSparks", Vector3.UP * 0.6, Vector3.ONE, Vector3.ZERO, 1.6, {"cull": 8.0, "decay": 0.8}, {"burst": 1.0, "gravity": -0.5, "drag": 1.6, "life": 1.6})
		K.put(order, K.VEIL, K.shock(VIOLET, GOLD_HI, ROYAL), "CommandEcho", Vector3.UP * 0.1, Vector3.ONE * 3.4, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "decay": 0.35, "delay": 0.35}, {"opacity": 0.6})
		M.show(order)
	var team := M.allies(c, 12.0, [1, 2, 4][c.q])
	if not team.is_empty():
		var marks := c.open(origin, 1.2, "Rally", null)
		if marks:
			marks.rotation.y = 0.0
			for i in team.size():
				var at: Vector3 = marks.to_local((team[i] as Node3D).global_position)
				K.put(marks, K.VEIL, K.shock(ROYAL, GOLD_HI, VIOLET), "CommandRally%d" % i, at + Vector3.UP * 0.08, Vector3.ONE * 1.4, Vector3.ZERO, 0.8, {"initial": 0.2, "grow_time": 0.8, "decay": 0.4, "delay": 0.12 + 0.05 * i}, {"opacity": 0.75})
			M.show(marks)
	return true
