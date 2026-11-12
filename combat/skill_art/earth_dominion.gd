extends RefCounted
## Dark Lord Lv.92: Earth Dominion (ปกครองพสุธา). The Lord lifts the scepter and runes of
## gold crawl over the ground in a royal seal. On the release the scepter strikes and the
## earth obeys: a ring of gold-capped obelisks bursts up round the area, the ground splits
## in cracks of gold to its edge, rock spikes shove up inside the ring, a wall of dust rolls
## out and stones fly; little gold stars circle over the stunned field; the stones sink back
## into the earth as the dust settles. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const ROYAL := Color("e8b64a")
const GOLD_HI := Color("fff0c0")
const GOLD_DK := Color("8a5a18")
const VIOLET := Color("8a4dff")
const STONE := Color("9a8aa8")
const ROCK := Color("8a7458")
const DUST_TOP := Color("eadcb8")
const DUST_UNDER := Color("b8a078")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.1
	var r := M.radius(skill, 8.0)
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, M.sigil("dominion", GOLD_HI, Color(ROYAL, 0.15), 8, 3, 8), "DominionSeal", Vector3.UP * 0.05, Vector3.ONE * r * 0.7, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.2, "spin": 0.6, "decay": 0.92}, {"opacity": 0.6})
		K.put(art, K.VEIL, K.cracks("dominion_runes", Color(0.3, 0.2, 0.08), ROYAL, 10, 0.25), "DominionCrawl", Vector3.UP * 0.04, Vector3.ONE * 2.4, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.95, "fade_in": 0.2, "decay": 0.92, "priority": -1})
		K.put(art, K.VEIL, K.sprite(), "DominionGem", c.local(art, c.hand()) + Vector3.UP * 0.4, Vector3.ONE * 0.8, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.95, "pulse": true}, {"radial": 1.8, "billboard": true, "tint": Color("d09020"), "opacity": 0.8})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var r := M.radius(skill, 8.0)
	var rule := c.open(origin, 2.2, "Rule", null)
	if rule:
		K.put(rule, K.SOLID, M.obelisks("dominion_slim", STONE, ROYAL, 10, 17, 0.42), "DominionObelisks", Vector3.ZERO, Vector3(r * 0.78, 2.4, r * 0.78), Vector3.ZERO, 2.0, {"initial": 1.0, "fade_in": 0.01, "decay": 0.65, "front": true, "cull": 4.0}, M.STONE_LOOK.merged({"slide": Vector3(0, -2.6, 0), "slide_time": 0.16, "slide_ease": -2.5}))
		K.put(rule, K.VEIL, M.scar("dominion_split", Color(0.28, 0.18, 0.06), ROYAL, 16), "DominionSplit", Vector3.UP * 0.04, Vector3.ONE * r * 0.92, Vector3.ZERO, 2.0, {"initial": 0.35, "grow_time": 0.12, "fade_in": 0.01, "decay": 0.6, "priority": -1})
		K.put(rule, K.VEIL, K.shock(ROYAL, GOLD_HI, GOLD_DK), "DominionShock", Vector3.UP * 0.1, Vector3.ONE * r, Vector3.ZERO, 0.6, {"initial": 0.12, "grow_time": 0.85, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(rule, K.SOLID, K.debris("dominion_stones", [ROCK, STONE, ROYAL], 28, 0.36), "DominionStones", Vector3.UP * 0.2, Vector3.ONE * 1.2, Vector3.ZERO, 1.3, {"cull": 14.0, "decay": 0.9}, M.STONE_LOOK.merged({"burst": 1.0, "gravity": 15.0, "drag": 0.9, "life": 1.3}))
		M.show(rule)
	var heave := c.open(origin, 2.0, "Heave", null)
	if heave:
		K.put(heave, K.SOLID, M.spikes("dominion_inner", ROCK, GOLD_HI, 14, 41, 0.35, 0.4), "DominionSpikes", Vector3.ZERO, Vector3(r * 0.45, 1.5, r * 0.45), Vector3(0, 0.3, 0), 1.6, {"initial": 1.0, "fade_in": 0.01, "decay": 0.6, "delay": 0.08, "cull": 3.0}, M.STONE_LOOK.merged({"slide": Vector3(0, -1.8, 0), "slide_time": 0.12, "slide_ease": -2.5}))
		K.put(heave, K.SOLID, S.cloud_ring("dominion_dust", DUST_TOP, DUST_UNDER, 24, 0.12), "DominionDust", Vector3.UP * 0.2, Vector3(r * 0.5, 0.8, r * 0.5), Vector3.ZERO, 1.4, {"initial": 0.4, "grow_time": 0.75, "fade_in": 0.02, "decay": 0.45, "cull": 6.0}, M.STONE_LOOK)
		K.put(heave, K.VEIL, K.shock(GOLD_HI, ROYAL, VIOLET), "DominionEcho", Vector3.UP * 0.12, Vector3.ONE * r * 0.7, Vector3.ZERO, 0.6, {"initial": 0.1, "grow_time": 0.85, "decay": 0.35, "delay": 0.16}, {"opacity": 0.6})
		K.put(heave, K.VEIL, K.sprite(), "DominionGlow", Vector3.UP * 0.12, Vector3.ONE * r * 0.6, Vector3(-PI / 2, 0, 0), 0.6, {"initial": 0.5, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.3}, {"radial": 1.4, "tint": Color("8a5a10"), "opacity": 0.2})
		M.show(heave)
	var daze := c.open(origin, 1.8, "Daze", null)
	if daze:
		K.put(daze, K.VEIL, M.sigil("dominion", GOLD_HI, Color(ROYAL, 0.15), 8, 3, 8), "DominionBrand", Vector3.UP * 0.05, Vector3.ONE * r * 0.55, Vector3.ZERO, 1.7, {"initial": 1.1, "grow_time": 0.2, "fade_in": 0.01, "spin": 0.4, "decay": 0.6, "priority": -2}, {"opacity": 0.6})
		K.put(daze, K.SOLID, M.orbs("dominion_stars", [ROYAL, Color("ffd890"), Color("c890ff")], 8, 0.05), "DominionStars", Vector3.UP * 2.4, Vector3.ONE * r * 0.4, Vector3.ZERO, 1.5, {"initial": 0.6, "grow_time": 0.3, "fade_in": 0.05, "spin": 2.5, "decay": 0.65, "delay": 0.15}, M.GOLD_LOOK)
		K.put(daze, K.GLOW, K.embers("dominion_gold", [ROYAL, GOLD_HI, VIOLET], 24, 2.5, 4.0), "DominionSparks", Vector3.UP * 0.3, Vector3.ONE * 1.2, Vector3.ZERO, 1.5, {"cull": 12.0, "decay": 0.8}, {"burst": 1.0, "gravity": 2.0, "drag": 1.4, "life": 1.5, "opacity": 0.8})
		M.show(daze)
	return true
