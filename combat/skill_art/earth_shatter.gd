extends RefCounted
## Summoner Lv.64: Earth Shatter (ทุบพื้นสะเทือน). The Summoner gathers the earth: cracks
## glow amber under the feet, grit and pebbles drift up round a stone rune. On the release
## the ground heaves: a ring of rock spikes punches up out of the ground, the earth cracks
## out to the edge of the area, a wall of dust rolls outward and rocks are thrown high; the
## spikes crumble back as the dust settles. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const SAND := Color("e8c79f")
const AMBER := Color("ffb84a")
const DIRT := Color("5a3e22")
const ROCK := Color("9a7a52")
const ROCK_HI := Color("e0c08a")
const DUST_TOP := Color("f2dcb0")
const DUST_UNDER := Color("b8946a")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.12
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, K.cracks("shatter_gather", DIRT, AMBER, 9, 0.3), "ShatterGather", Vector3.UP * 0.04, Vector3.ONE * 2.2, Vector3.ZERO, t, {"initial": 0.25, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.9, "priority": -1})
		K.put(art, K.VEIL, M.sigil("shatter", AMBER, Color(SAND, 0.2), 8, 3, 4), "ShatterRune", Vector3.UP * 0.06, Vector3.ONE * 1.7, Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": -1.2, "decay": 0.9})
		K.put(art, K.SOLID, K.debris("shatter_grit", [ROCK, ROCK_HI, DIRT.lightened(0.2)], 14, 0.18), "ShatterGrit", Vector3.UP * 0.1, Vector3.ONE, Vector3.ZERO, t, {"cull": 4.0, "decay": 0.85}, M.STONE_LOOK.merged({"burst": 1.0, "gravity": -0.3, "drag": 6.0, "life": t + 0.3}))
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var r := M.radius(skill, 6.0)
	var main := c.open(origin, 1.8, "Quake", null)
	if main:
		# The spikes punch up out of the ground, the earth cracks out to the edge.
		K.put(main, K.SOLID, M.spikes("shatter_ring", ROCK, ROCK_HI, 14, 5), "ShatterSpikes", Vector3.ZERO, Vector3(r * 0.52, 1.7, r * 0.52), Vector3.ZERO, 1.5, {"initial": 1.0, "fade_in": 0.005, "decay": 0.6, "front": true, "cull": 4.0}, M.STONE_LOOK.merged({"slide": Vector3(0, -1.9, 0), "slide_time": 0.12, "slide_ease": -2.5}))
		K.put(main, K.VEIL, M.scar("shatter_crack", DIRT, AMBER, 13), "ShatterCracks", Vector3.UP * 0.04, Vector3.ONE * r * 0.95, Vector3.ZERO, 1.7, {"initial": 0.35, "grow_time": 0.12, "fade_in": 0.01, "decay": 0.6, "priority": -1})
		K.put(main, K.VEIL, K.shock(AMBER, Color("ffe8b8"), SAND), "ShatterShock", Vector3.UP * 0.1, Vector3.ONE * r, Vector3.ZERO, 0.55, {"initial": 0.12, "grow_time": 0.85, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(main, K.SOLID, K.debris("shatter_rocks", [ROCK, ROCK_HI, DIRT.lightened(0.15)], 26, 0.34), "ShatterRocks", Vector3.UP * 0.2, Vector3.ONE, Vector3.ZERO, 1.2, {"cull": 12.0, "decay": 0.9}, M.STONE_LOOK.merged({"burst": 1.0, "gravity": 16.0, "drag": 0.9, "life": 1.2}))
		M.show(main)
	var dust := c.open(origin, 1.6, "Dust", null)
	if dust:
		K.put(dust, K.SOLID, S.cloud_ring("shatter_dust", DUST_TOP, DUST_UNDER, 22, 0.14), "ShatterDustWall", Vector3.UP * 0.2, Vector3(r * 0.45, 0.8, r * 0.45), Vector3.ZERO, 1.2, {"initial": 0.5, "grow_time": 0.75, "fade_in": 0.02, "decay": 0.45, "cull": 6.0}, M.STONE_LOOK)
		K.put(dust, K.SOLID, M.spikes("shatter_inner", ROCK.darkened(0.1), AMBER, 8, 9, 0.2), "ShatterInner", Vector3.ZERO, Vector3(r * 0.24, 1.25, r * 0.24), Vector3(0, 0.4, 0), 1.3, {"initial": 1.0, "fade_in": 0.005, "decay": 0.55, "delay": 0.07, "cull": 3.0}, M.STONE_LOOK.merged({"slide": Vector3(0, -1.5, 0), "slide_time": 0.1, "slide_ease": -2.5}))
		K.put(dust, K.VEIL, K.sprite(), "ShatterGlow", Vector3.UP * 0.12, Vector3.ONE * r * 0.6, Vector3(-PI / 2, 0, 0), 0.6, {"initial": 0.5, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.3}, {"radial": 1.5, "tint": Color("c87a20"), "opacity": 0.28})
		K.put(dust, K.VEIL, K.shock(SAND, AMBER, DIRT), "ShatterEcho", Vector3.UP * 0.12, Vector3.ONE * r * 0.75, Vector3.ZERO, 0.6, {"initial": 0.1, "grow_time": 0.85, "decay": 0.35, "delay": 0.14}, {"opacity": 0.6})
		M.show(dust)
	var grit := c.open(origin, 1.5, "Grit", null)
	if grit:
		K.put(grit, K.SOLID, S.puffs("shatter_puffs", DUST_TOP, DUST_UNDER, 12, 8.0), "ShatterPuffs", Vector3.UP * 0.2, Vector3.ONE * 0.65, Vector3.ZERO, 1.2, {"cull": 12.0, "decay": 0.7}, M.STONE_LOOK.merged({"burst": 1.0, "gravity": -0.5, "drag": 2.2, "life": 1.2}))
		K.put(grit, K.VEIL, K.embers("shatter_sparks", [AMBER, ROCK_HI, SAND], 24, 2.0, 3.5), "ShatterSparks", Vector3.UP * 0.2, Vector3.ONE, Vector3.ZERO, 1.2, {"cull": 8.0, "decay": 0.8}, {"burst": 1.0, "gravity": 5.0, "drag": 1.4, "life": 1.2})
		M.show(grit)
	return true
