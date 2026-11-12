extends RefCounted
## Summoner Lv.68: Ancient Treant (เอนท์โบราณ). A leaf-green seal opens where the treant
## will stand and young roots worm out of it while a whirl of leaves gathers round the
## Summoner. On the release great old roots heave up out of the ground and arch round the
## treant as it rises, a pillar of forest light climbs through them, leaves burst out and
## moss and glowing root-cracks spread under it; the roots sink back as leaves settle. The
## creature (Summon) and its AI are untouched. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const LEAF := Color("8fd85a")
const LEAF_HI := Color("d8ff90")
const BARK := Color("6a4a2a")
const BARK_HI := Color("a8804a")
const MOSS := Color("3a7a3a")
const GOLD := Color("f0d870")
const LEAVES := [Color("7ad04a"), Color("b0e070"), Color("e8d860"), Color("4aa040")]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.15
	var spot := M.formation(skill, 0, 1)
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		art.rotation.y = 0.0
		K.put(art, K.VEIL, M.sigil("treant", LEAF_HI, Color(LEAF, 0.22), 8, 3, 8), "TreantSeal", spot + Vector3.UP * 0.05, Vector3.ONE * 1.9, Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.2, "spin": 1.0, "decay": 0.92})
		K.put(art, K.SOLID, M.vines("treant_sprout", BARK, BARK_HI, 6, false, 5, 0.8), "TreantSprouts", spot, Vector3(1.2, 0.9, 1.2), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95, "cull": 3.0}, M.LEAF_LOOK.merged({"slide": Vector3(0, -0.9, 0), "slide_time": t, "slide_ease": -2.0}))
		K.put(art, K.VEIL, S.spiral("treant_call", Color(0.55, 0.9, 0.4, 0.7), Color(0.9, 1.0, 0.6, 0.0), 3, 1.2, 0.5), "TreantCall", Vector3.UP * 0.1, Vector3(1.3, 2.3, 1.3), Vector3.ZERO, t, {"initial": 0.6, "grow_time": 0.7, "fade_in": 0.2, "spin": 5.0, "decay": 0.85})
		K.put(art, K.SOLID, S.leaves("treant_swirl", LEAVES, 14, 2.0, 1.5), "TreantLeaves", Vector3.UP * 0.3, Vector3.ONE * 0.7, Vector3.ZERO, t, {"cull": 5.0, "decay": 0.85, "spin": 4.0}, M.LEAF_LOOK.merged({"burst": 1.0, "gravity": -0.4, "drag": 3.0, "life": t + 0.3}))
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	(VfxBudget.carry(func(): _arrive(c))).call_deferred()
	return true


static func _arrive(c: M.Cast) -> void:
	var found := M.summons(c.parent, c.id, c.origin)
	var at := (found[0] as Node3D).global_position if not found.is_empty() else c.origin + M.formation(c.skill, 0, 1)
	var follow: Node3D = found[0] if not found.is_empty() else null
	var rise := c.open(at, 2.0, "Rise", follow)
	if rise:
		rise.rotation.y = 0.0
		K.put(rise, K.SOLID, M.vines("treant_roots", BARK, BARK_HI, 9, false, 11, 1.0, 1.25), "TreantRoots", Vector3.ZERO, Vector3(2.2, 3.0, 2.2), Vector3.ZERO, 1.9, {"initial": 1.0, "fade_in": 0.01, "decay": 0.62, "front": true, "cull": 5.0}, M.LEAF_LOOK.merged({"slide": Vector3(0, -3.0, 0), "slide_time": 0.3, "slide_ease": -2.5}))
		K.put(rise, K.VEIL, K.column("treant_light", [Color(0.6, 1.0, 0.45, 0.55), Color(0.75, 1.0, 0.5, 0.35), Color(0.95, 1.0, 0.7, 0.12), Color(1.0, 1.0, 0.8, 0.0)], 0.75, 16), "TreantPillar", Vector3.ZERO, Vector3(1.4, 6.0, 1.4), Vector3.ZERO, 0.8, {"initial": 0.4, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.35}, {"noise_amt": 0.6, "noise_scale": Vector2(6.0, 1.5), "flow": Vector2(0.0, -2.5), "bias": 0.1, "taper": 0.5, "fres": 0.5})
		K.put(rise, K.SOLID, S.leaves("treant_burst", LEAVES, 28, 6.5, 4.5), "TreantLeafBurst", Vector3.UP * 0.6, Vector3.ONE, Vector3.ZERO, 1.6, {"cull": 12.0, "decay": 0.85}, M.LEAF_LOOK.merged({"burst": 1.0, "gravity": 2.4, "drag": 1.6, "life": 1.6}))
		K.put(rise, K.VEIL, K.shock(LEAF, LEAF_HI, MOSS), "TreantShock", Vector3.UP * 0.1, Vector3.ONE * 3.6, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.35}, {"opacity": 0.8})
		M.show(rise)
	var ground := c.open(at, 2.2, "Moss", null)
	if ground:
		K.put(ground, K.VEIL, K.cracks("treant_roots", Color(0.3, 0.42, 0.18), LEAF_HI, 10, 0.32), "TreantCracks", Vector3.UP * 0.04, Vector3.ONE * 2.6, Vector3.ZERO, 2.1, {"initial": 0.4, "grow_time": 0.15, "fade_in": 0.02, "decay": 0.6, "priority": -1})
		K.put(ground, K.VEIL, S.wash("treant_moss", Color(MOSS, 0.5), Color(LEAF, 0.35)), "TreantMoss", Vector3.UP * 0.03, Vector3.ONE * 2.2, Vector3.ZERO, 2.2, {"initial": 0.3, "grow_time": 0.4, "fade_in": 0.05, "decay": 0.6, "priority": -2})
		K.put(ground, K.VEIL, S.sparkles("treant_pollen", [GOLD, LEAF_HI, Color("fff4b0")], 22, 3.5, 2.4), "TreantPollen", Vector3.UP * 0.6, Vector3.ONE, Vector3.ZERO, 1.8, {"cull": 8.0, "decay": 0.8}, {"burst": 1.0, "gravity": -0.4, "drag": 1.6, "life": 1.8})
		M.show(ground)
	var call := c.open(c.origin, 0.8, "Call", c.caster)
	if call:
		K.put(call, K.VEIL, K.shock(LEAF_HI, GOLD, LEAF), "TreantCallRing", Vector3.UP * 0.08, Vector3.ONE * 2.2, Vector3.ZERO, 0.5, {"initial": 0.2, "grow_time": 0.9, "decay": 0.35}, {"opacity": 0.7})
		M.show(call)
