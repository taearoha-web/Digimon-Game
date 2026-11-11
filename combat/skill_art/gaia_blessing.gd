extends RefCounted
## Summoner Lv.88: Gaia's Blessing (พรแห่งไกอา). Warm light pours down on the Summoner
## from above while the earth's seal opens at the feet. On the release a great lotus of
## green and gold blossoms round the Summoner in a pillar of sunlit green, a grove of young
## trees springs up in a ring about them, a wreath of leaves turns over the head like a
## crown, and leaves and pollen rise; the grove sinks and the petals close as the blessing
## settles. Cosmetic only (the heal and the buff are the hero's).
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const SPRING := Color("d8ffb0")
const LEAF := Color("7ad85a")
const LEAF_HI := Color("eaffc0")
const GOLD := Color("ffd860")
const PETAL := Color("ffe8a0")
const BARK := Color("8a6a40")
const LEAVES := [Color("8fe07a"), Color("d8ffb0"), Color("ffd860"), Color("5ac060")]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.15
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, K.column("gaia_fall", [Color(1.0, 0.9, 0.5, 0.0), Color(1.0, 0.92, 0.55, 0.35), Color(0.85, 1.0, 0.6, 0.45), Color(0.8, 1.0, 0.6, 0.0)], 0.6, 16), "GaiaLight", Vector3.ZERO, Vector3(1.3, 7.0, 1.3), Vector3.ZERO, t, {"initial": 0.6, "grow_time": 0.8, "fade_in": 0.4, "decay": 0.9}, {"noise_amt": 0.5, "noise_scale": Vector2(5.0, 1.5), "flow": Vector2(0.0, 2.0), "bias": 0.2, "taper": 0.3, "fres": 0.5})
		K.put(art, K.VEIL, M.sigil("gaia", GOLD, Color(SPRING, 0.2), 10, 3, 10), "GaiaSeal", Vector3.UP * 0.05, Vector3.ONE * 1.9, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": 0.9, "decay": 0.9})
		K.put(art, K.VEIL, S.sparkles("gaia_motes", [GOLD, SPRING, LEAF_HI], 16, -1.0, 0.8), "GaiaMotes", Vector3.UP * 3.5, Vector3.ONE * 0.8, Vector3.ZERO, t, {"cull": 6.0, "decay": 0.9}, {"burst": 1.0, "gravity": 3.0, "drag": 1.0, "life": t + 0.2})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var bloom := c.open(origin, 2.2, "Bloom", c.caster)
	if bloom:
		K.put(bloom, K.SOLID, M.lotus("gaia_lotus", LEAF, PETAL, GOLD, 12, 3), "GaiaLotus", Vector3.UP * 0.02, Vector3.ONE * 2.3, Vector3.ZERO, 2.1, {"initial": 0.15, "grow_time": 0.18, "fade_in": 0.01, "spin": 0.3, "decay": 0.65}, M.LEAF_LOOK)
		K.put(bloom, K.VEIL, K.column("gaia_pillar", [Color(0.7, 1.0, 0.5, 0.55), Color(0.9, 1.0, 0.6, 0.4), Color(1.0, 0.95, 0.6, 0.15), Color(1.0, 0.95, 0.7, 0.0)], 0.7, 18), "GaiaPillar", Vector3.ZERO, Vector3(1.5, 7.0, 1.5), Vector3.ZERO, 0.9, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.4}, {"noise_amt": 0.5, "noise_scale": Vector2(6.0, 1.5), "flow": Vector2(0.0, -3.0), "bias": 0.1, "taper": 0.5, "fres": 0.5})
		K.put(bloom, K.VEIL, K.shock(LEAF_HI, GOLD, LEAF), "GaiaShock", Vector3.UP * 0.08, Vector3.ONE * 4.2, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.8})
		K.put(bloom, K.SOLID, S.cloud_ring("gaia_wreath", Color("a8f080"), Color("3a8a3a"), 14, 0.16), "GaiaWreath", Vector3.UP * 2.45, Vector3(0.55, 0.6, 0.55), Vector3.ZERO, 2.0, {"initial": 0.3, "grow_time": 0.25, "fade_in": 0.02, "spin": 1.4, "decay": 0.7}, M.LEAF_LOOK)
		M.show(bloom)
	var grove := c.open(origin, 2.2, "Grove", c.caster)
	if grove:
		K.put(grove, K.SOLID, M.grove("gaia", BARK, LEAF, LEAF_HI, 7), "GaiaGrove", Vector3.ZERO, Vector3(2.9, 2.4, 2.9), Vector3.ZERO, 2.1, {"initial": 1.0, "fade_in": 0.01, "decay": 0.62, "delay": 0.06, "cull": 4.0}, M.LEAF_LOOK.merged({"slide": Vector3(0, -1.8, 0), "slide_time": 0.25, "slide_ease": -2.5}))
		K.put(grove, K.SOLID, S.leaves("gaia_rise", LEAVES, 26, 3.5, 5.5), "GaiaLeaves", Vector3.UP * 0.3, Vector3.ONE * 1.1, Vector3.ZERO, 2.0, {"cull": 10.0, "decay": 0.8}, M.LEAF_LOOK.merged({"burst": 1.0, "gravity": 0.8, "drag": 1.6, "life": 2.0}))
		K.put(grove, K.VEIL, S.sparkles("gaia_pollen", [GOLD, SPRING, PETAL], 26, 4.0, 2.4), "GaiaPollen", Vector3.UP * 0.4, Vector3.ONE, Vector3.ZERO, 2.0, {"cull": 8.0, "decay": 0.8}, {"burst": 1.0, "gravity": -0.6, "drag": 1.6, "life": 2.0})
		K.put(grove, K.VEIL, S.wash("gaia_ground", Color(0.75, 1.0, 0.5, 0.4), Color(1.0, 0.9, 0.5, 0.25)), "GaiaWash", Vector3.UP * 0.03, Vector3.ONE * 3.6, Vector3.ZERO, 2.0, {"initial": 0.4, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.6, "priority": -2})
		M.show(grove)
	# The blessing reaches the party: a small bloom of light on each.
	var team := M.allies(c, 12.0, [1, 2, 4][c.q])
	if not team.is_empty():
		var marks := c.open(origin, 1.2, "Gift", null)
		if marks:
			marks.rotation.y = 0.0
			for i in team.size():
				var at: Vector3 = marks.to_local((team[i] as Node3D).global_position)
				K.put(marks, K.VEIL, K.shock(GOLD, LEAF_HI, LEAF), "GaiaGift%d" % i, at + Vector3.UP * 0.08, Vector3.ONE * 1.4, Vector3.ZERO, 0.8, {"initial": 0.2, "grow_time": 0.8, "decay": 0.4, "delay": 0.12 + 0.05 * i}, {"opacity": 0.75})
			M.show(marks)
	return true
