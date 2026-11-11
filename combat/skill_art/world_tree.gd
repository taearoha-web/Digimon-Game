extends RefCounted
## Summoner Lv.80: World Tree (ต้นไม้โลก). A sapling of light sprouts beside the Summoner
## while the great World Tree rises behind the target area, glowing leaves drift down and a
## seal of the forest opens on the ground. On the release the tree shakes loose a rain of
## glowing seeds that falls on the area; where it lands
## (the real landing, impact_delay) thorned roots burst up round the area, leaves blast
## out, glowing root-cracks and a carpet of moss (the slow) spread, and the tree fades
## back into the sky. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const LEAF := Color("8fe07a")
const LEAF_HI := Color("e4ffb8")
const LEAF_DK := Color("2f7a3a")
const BARK := Color("7a5a3a")
const GOLD := Color("ffe27a")
const MOSS := Color("4a9a4a")
const LEAVES := [Color("8fe07a"), Color("c8f080"), Color("ffe27a"), Color("5ac060")]
const TALL := 9.0
const CANOPY := 6.4


static func _r(skill: Dictionary) -> float:
	return M.radius(skill, 8.5)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.2) + 0.1
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.SOLID, M.tree("world_sapling", BARK, LEAF, LEAF_HI, 4), "WorldSapling", Vector3(0.9, 0, -0.4), Vector3.ONE * 1.5, Vector3.ZERO, t, {"initial": 0.1, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95}, M.LEAF_LOOK)
		K.put(art, K.VEIL, S.spiral("world_call", Color(0.6, 1.0, 0.5, 0.75), Color(1.0, 0.95, 0.6, 0.0), 3, 1.4, 0.4), "WorldCall", Vector3.UP * 0.1, Vector3(1.5, 2.8, 1.5), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": 5.0, "decay": 0.9})
		M.show(art)
	var point := Vector3(aim.x, 0.0, aim.z)
	c.fit = K.frame(parent, point, origin, TALL, _r(skill) * 0.7)
	var r := _r(skill) / c.fit
	var area := c.open(point, t + 0.05, "Grove", null)
	if area:
		K.put(area, K.VEIL, M.sigil("world", LEAF_HI, Color(LEAF, 0.16), 12, 5, 12), "WorldSeal", Vector3.UP * 0.05, Vector3.ONE * r, Vector3.ZERO, t + 0.05, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.2, "spin": 0.4, "decay": 0.95}, {"opacity": 0.4})
		K.put(area, K.VEIL, S.sparkles("world_fall", [LEAF_HI, GOLD, LEAF], 20, -0.6, 0.6), "WorldDrift", Vector3.UP * 4.5, Vector3.ONE * r * 0.35, Vector3.ZERO, t + 0.05, {"cull": 10.0, "decay": 0.9}, {"burst": 1.0, "gravity": 1.6, "drag": 1.0, "life": t + 0.3})
		M.show(area)
	var tree := c.open(point, t + 0.05, "Tree", null)
	if tree:
		S.face_away(tree)
		K.put(tree, K.SOLID, M.tree("world_great", BARK, LEAF, LEAF_HI, 12), "WorldTree", Vector3(0, 0, r * 0.75), Vector3.ONE * TALL, Vector3.ZERO, t + 0.05, {"initial": 0.3, "grow_time": 1.0, "fade_in": 0.3, "decay": 0.98, "cull": 12.0}, M.LEAF_LOOK.merged({"slide": Vector3(0, -3.0, 0), "slide_time": t, "slide_ease": -2.0}))
		M.show(tree)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var point := Vector3(center.x, 0.0, center.z)
	c.fit = K.frame(parent, point, origin, TALL, _r(skill) * 0.7)
	var r := _r(skill) / c.fit
	var land := maxf(impact_delay, 0.0)
	var stay := land + 2.0
	# The tree stands on until the seeds land, then fades back into the sky.
	var tree := c.open(point, stay, "Tree", null)
	if tree:
		S.face_away(tree)
		K.put(tree, K.SOLID, M.tree("world_great", BARK, LEAF, LEAF_HI, 12), "WorldTreeStand", Vector3(0, 0, r * 0.75), Vector3.ONE * TALL, Vector3.ZERO, land + 0.9, {"initial": 1.0, "fade_in": 0.001, "decay": 0.55, "cull": 12.0}, M.LEAF_LOOK)
		if land > 0.08:
			K.put(tree, K.GLOW, seed_rain(), "WorldSeeds", Vector3(0, CANOPY - 1.0, 0), Vector3.ONE * (r * 0.75 / 6.0), Vector3.ZERO, land, {"initial": 1.0, "travel": Vector3.DOWN * (CANOPY - 1.0), "accelerate": true, "fade_in": 0.05, "decay": 0.97, "front": true})
		M.show(tree)
	var roots := c.open(point, stay, "Roots", null)
	if roots:
		K.put(roots, K.SOLID, M.vines("world_thorns_thin", Color("5a4426"), Color("9ad060"), 16, true, 7, 1.0, 0.32), "WorldRoots", Vector3.ZERO, Vector3(r * 0.72, 2.4, r * 0.72), Vector3.ZERO, 1.8, {"initial": 1.0, "fade_in": 0.01, "decay": 0.6, "front": true, "delay": land, "cull": 6.0}, M.LEAF_LOOK.merged({"slide": Vector3(0, -2.6, 0), "slide_time": 0.22, "slide_ease": -2.5}))
		K.put(roots, K.VEIL, K.shock(LEAF, LEAF_HI, LEAF_DK), "WorldShock", Vector3.UP * 0.1, Vector3.ONE * r, Vector3.ZERO, 0.6, {"initial": 0.1, "grow_time": 0.85, "fade_in": 0.01, "decay": 0.35, "delay": land}, {"opacity": 0.85})
		K.put(roots, K.SOLID, S.leaves("world_burst", LEAVES, 30, 8.0, 4.5), "WorldLeafBurst", Vector3.UP * 0.5, Vector3.ONE * 1.4, Vector3.ZERO, 1.6, {"cull": 14.0, "decay": 0.85, "delay": land}, M.LEAF_LOOK.merged({"burst": 1.0, "gravity": 2.5, "drag": 1.5, "life": 1.6}))
		K.put(roots, K.VEIL, M.scar("world_roots", Color(0.28, 0.36, 0.14), LEAF_HI, 14), "WorldCracks", Vector3.UP * 0.04, Vector3.ONE * r * 0.95, Vector3.ZERO, 1.9, {"initial": 0.4, "grow_time": 0.12, "fade_in": 0.01, "decay": 0.6, "delay": land, "priority": -1})
		M.show(roots)
	var moss := c.open(point, stay, "Moss", null)
	if moss:
		K.put(moss, K.VEIL, S.wash("world_moss", Color(MOSS, 0.45), Color(LEAF, 0.3)), "WorldMoss", Vector3.UP * 0.03, Vector3.ONE * r, Vector3.ZERO, 2.0, {"initial": 0.3, "grow_time": 0.3, "fade_in": 0.05, "decay": 0.65, "delay": land, "priority": -2})
		K.put(moss, K.VEIL, S.sparkles("world_pollen", [GOLD, LEAF_HI, LEAF], 26, 3.5, 4.0), "WorldPollen", Vector3.UP * 0.5, Vector3.ONE * 1.5, Vector3.ZERO, 1.9, {"cull": 12.0, "decay": 0.8, "delay": land}, {"burst": 1.0, "gravity": -0.3, "drag": 1.5, "life": 1.9})
		K.put(moss, K.VEIL, K.sprite(), "WorldGlow", Vector3.UP * 0.12, Vector3.ONE * r * 0.75, Vector3(-PI / 2, 0, 0), 0.7, {"initial": 0.6, "grow_time": 0.4, "fade_in": 0.02, "decay": 0.3, "delay": land}, {"radial": 1.4, "tint": Color("3aa040"), "opacity": 0.2})
		M.show(moss)
	return true


## Glowing seeds scattered over a disc of radius 6 m at heights 0..2.5 m (they fall as one).
static func seed_rain() -> ArrayMesh:
	return K.cached("mystic_world_seeds", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 91
		for i in 34:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 5.7
			var p := Vector3(sin(a) * d, rng.randf_range(0.0, 2.5), cos(a) * d)
			var tone: Color = [Color(0.6, 1.0, 0.45, 0.95), Color(1.0, 0.92, 0.45, 0.95), Color(0.8, 1.0, 0.6, 0.95)][i % 3]
			b.gem(p, Vector3(0.05, 0.28, 0.05), tone, Color(tone.lerp(Color.WHITE, 0.3), 0.6))
			b.quad(p + Vector3(-0.025, 0.2, 0), p + Vector3(0.025, 0.2, 0), p + Vector3(0.012, 1.1, 0), p + Vector3(-0.012, 1.1, 0), Color(tone, 0.6), Color(tone, 0.0))
		return b.mesh())
