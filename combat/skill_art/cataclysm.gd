extends RefCounted
## Summoner Lv.96: Cataclysm (ธรรมชาติพิโรธ). Nature's wrath gathers: a storm cloud of
## dark green churns over the Summoner, leaves and grit are dragged inward on a whirlwind
## and the ground cracks with green light. On the release the whole area erupts: a ring of
## giant thorned roots heaves up, stone spikes break the ground at the edge, green lightning
## lashes down out of the cloud, a tornado of leaves tears up from the middle and a wall of
## dust rolls out over the field; the cloud breaks and the roots sink as the dust settles.
## Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const LEAF := Color("b8ff7a")
const LEAF_HI := Color("f0ffd0")
const LEAF_DK := Color("2a6a2a")
const STORM := Color("8aa890")
const STORM_DK := Color("4a6a56")
const ROCK := Color("7a6a50")
const ROCK_HI := Color("c8b080")
const BOLT := Color("8aff50")
const LEAVES := [Color("8fe07a"), Color("b8ff7a"), Color("e8d860"), Color("4a9a40"), Color("a07a40")]
const TALL := 7.5


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.15
	c.fit = K.frame(parent, origin, origin, TALL, 0.0)
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, S.spiral("cata_pull", Color(0.6, 0.9, 0.4, 0.75), Color(0.85, 0.8, 0.5, 0.0), 5, 1.2, 0.4), "CataPull", Vector3.UP * 0.1, Vector3(4.0, 2.6, 4.0), Vector3.ZERO, t, {"initial": 1.8, "grow_time": 1.0, "fade_in": 0.2, "spin": -6.0, "decay": 0.9})
		K.put(art, K.SOLID, S.cloud("cata_storm", STORM, STORM_DK, 16, 0.45, 3), "CataCloud", Vector3.UP * 6.4, Vector3(2.2, 1.0, 2.2), Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.3, "spin": 0.6, "decay": 0.98, "cull": 6.0}, {"rim_color": Color("b8ff90"), "rim": 0.6, "shadow_tint": Color(0.6, 0.7, 0.6)})
		K.put(art, K.VEIL, K.cracks("cata_gather", Color(0.1, 0.15, 0.05), LEAF, 12, 0.3), "CataCracks", Vector3.UP * 0.04, Vector3.ONE * 3.0, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.95, "fade_in": 0.2, "decay": 0.92, "priority": -1})
		K.put(art, K.SOLID, S.leaves("cata_drag", LEAVES, 18, 2.5, 1.5), "CataDrag", Vector3.UP * 0.4, Vector3.ONE * 1.4, Vector3.ZERO, t, {"cull": 6.0, "decay": 0.85, "spin": -5.0}, M.LEAF_LOOK.merged({"burst": 1.0, "gravity": -0.4, "drag": 3.0, "life": t + 0.3}))
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	c.fit = K.frame(parent, origin, origin, TALL, 0.0)
	var r := M.radius(skill, 9.0) / c.fit
	var quake := c.open(origin, 2.2, "Wrath", null)
	if quake:
		K.put(quake, K.SOLID, M.vines("cata_thorns_thin", Color("3a2a14"), Color("6a9038"), 12, true, 13, 1.0, 0.36), "CataThorns", Vector3.ZERO, Vector3(r * 0.5, 2.6, r * 0.5), Vector3.ZERO, 1.4, {"initial": 1.0, "fade_in": 0.005, "decay": 0.5, "front": true, "cull": 6.0}, M.LEAF_LOOK.merged({"slide": Vector3(0, -2.8, 0), "slide_time": 0.2, "slide_ease": -2.5}))
		K.put(quake, K.VEIL, K.shock(LEAF, LEAF_HI, LEAF_DK), "CataShock", Vector3.UP * 0.1, Vector3.ONE * r, Vector3.ZERO, 0.7, {"initial": 0.1, "grow_time": 0.85, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(quake, K.VEIL, M.scar("cata_split", Color(0.25, 0.3, 0.12), LEAF, 16), "CataSplit", Vector3.UP * 0.04, Vector3.ONE * r * 0.8, Vector3.ZERO, 2.1, {"initial": 0.4, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "priority": -1})
		K.put(quake, K.SOLID, K.debris("cata_rocks", [ROCK, ROCK_HI, LEAF_DK], 30, 0.4), "CataRocks", Vector3.UP * 0.2, Vector3.ONE * 1.3, Vector3.ZERO, 1.4, {"cull": 16.0, "decay": 0.9}, M.STONE_LOOK.merged({"burst": 1.0, "gravity": 15.0, "drag": 0.8, "life": 1.4}))
		M.show(quake)
	var storm := c.open(origin, 1.9, "Storm", null)
	if storm:
		K.put(storm, K.VEIL, S.spiral("cata_tornado", Color(0.45, 0.85, 0.3, 0.85), Color(0.8, 1.0, 0.6, 0.1), 5, 2.4, 1.3), "CataTornado", Vector3.ZERO, Vector3(1.4, TALL - 1.5, 1.4), Vector3.ZERO, 1.2, {"initial": 0.4, "grow_time": 0.25, "fade_in": 0.01, "spin": 10.0, "decay": 0.5, "front": true})
		K.put(storm, K.VEIL, M.lightning("cata_bolts_%d" % int(r * 10.0), Color(0.45, 0.95, 0.3, 0.9), Color(0.2, 0.7, 0.4, 0.7), 6, 6.0, 21, r * 0.55), "CataBolts", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.45, {"initial": 1.0, "fade_in": 0.01, "decay": 0.3, "delay": 0.03}, {"flicker": 0.4, "opacity": 0.9})
		K.put(storm, K.SOLID, S.cloud("cata_storm", STORM, STORM_DK, 16, 0.45, 3), "CataCloudBreak", Vector3.UP * 6.4, Vector3(2.2, 1.0, 2.2), Vector3.ZERO, 1.0, {"initial": 1.0, "grow_time": 0.6, "fade_in": 0.001, "spin": 1.5, "decay": 0.35, "cull": 6.0}, {"rim_color": Color("b8ff90"), "rim": 0.6, "shadow_tint": Color(0.6, 0.7, 0.6), "slide": Vector3(0, -0.6, 0), "slide_time": 0.1, "slide_ease": 2.0})
		K.put(storm, K.SOLID, M.spikes("cata_edge_thin", ROCK, ROCK_HI, 22, 23, 0.4, 0.3), "CataSpikes", Vector3.ZERO, Vector3(r * 0.9, 1.4, r * 0.9), Vector3.ZERO, 1.7, {"initial": 1.0, "fade_in": 0.005, "decay": 0.6, "delay": 0.1, "cull": 4.0}, M.STONE_LOOK.merged({"slide": Vector3(0, -2.2, 0), "slide_time": 0.12, "slide_ease": -2.5}))
		M.show(storm)
	var dust := c.open(origin, 2.0, "Dust", null)
	if dust:
		K.put(dust, K.SOLID, S.cloud_ring("cata_dust_s", Color("c8d098"), Color("7a8a50"), 26, 0.12), "CataDustWall", Vector3.UP * 0.2, Vector3(r * 0.55, 0.9, r * 0.55), Vector3.ZERO, 1.5, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.02, "decay": 0.45, "cull": 8.0}, M.STONE_LOOK)
		K.put(dust, K.SOLID, S.leaves("cata_burst", LEAVES, 32, 9.0, 6.0), "CataLeaves", Vector3.UP * 0.5, Vector3.ONE * 1.5, Vector3.ZERO, 1.9, {"cull": 16.0, "decay": 0.85}, M.LEAF_LOOK.merged({"burst": 1.0, "gravity": 2.5, "drag": 1.3, "life": 1.9}))
		K.put(dust, K.VEIL, K.sprite(), "CataGlow", Vector3.UP * 0.15, Vector3.ONE * r * 0.7, Vector3(-PI / 2, 0, 0), 0.7, {"initial": 0.6, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.3}, {"radial": 1.4, "tint": Color("2a6a20"), "opacity": 0.2})
		K.put(dust, K.VEIL, K.shock(LEAF_HI, LEAF, STORM), "CataEcho", Vector3.UP * 0.12, Vector3.ONE * r * 0.7, Vector3.ZERO, 0.7, {"initial": 0.1, "grow_time": 0.85, "decay": 0.35, "delay": 0.18}, {"opacity": 0.6})
		M.show(dust)
	if c.rich:
		var fall := c.open(origin, 2.4, "Fall", null)
		if fall:
			K.put(fall, K.SOLID, S.puffs("cata_puffs", Color("c8d098"), Color("7a8a50"), 12, 9.0), "CataPuffs", Vector3.UP * 0.2, Vector3.ONE * 0.7, Vector3.ZERO, 1.6, {"cull": 14.0, "decay": 0.7}, M.STONE_LOOK.merged({"burst": 1.0, "gravity": -0.5, "drag": 2.0, "life": 1.6}))
			K.put(fall, K.VEIL, S.sparkles("cata_motes", [LEAF, BOLT, LEAF_HI], 26, 2.0, 5.0), "CataMotes", Vector3.UP * 0.4, Vector3.ONE * 1.6, Vector3.ZERO, 2.3, {"cull": 14.0, "decay": 0.8}, {"burst": 1.0, "gravity": 0.6, "drag": 1.2, "life": 2.3})
			M.show(fall)
	return true
