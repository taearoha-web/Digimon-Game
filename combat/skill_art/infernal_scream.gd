extends RefCounted
## Dark Lord Lv.80: Infernal Scream (เสียงคำรามนรก). Hellfire gathers round the Lord's
## feet and dark smoke curls up as the scream builds in a red glow. On the release the
## scream bursts out as a firestorm: a ring of hellfire races out to the edge of the area,
## fire whirls round in a low storm, shock rings of the roar roll out one after another,
## the ground scorches and cracks red, embers fly and soot billows; tongues of fire keep
## licking the scorched ring for a moment (the burn) before dying down. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const FIRE := Color("ff6a2a")
const FIRE_HI := Color("ffd08a")
const EMBER := Color("ffb040")
const CRIMSON := Color("b0201a")
const SOOT := Color("3a2228")
const VIOLET := Color("8a4dff")
const FLAMES := [Color(0.75, 0.15, 0.08, 0.9), Color(1.0, 0.35, 0.1, 0.9), Color(1.0, 0.6, 0.2, 0.75), Color(1.0, 0.8, 0.4, 0.45), Color(1.0, 0.9, 0.6, 0.2)]
const FIRE_LOOK := {"noise_amt": 0.6, "noise_scale": Vector2(4.0, 2.0), "flow": Vector2(0.0, -3.5), "bias": 0.3, "taper": 0.8, "hot": Color("ffd890"), "edge_heat": 0.5}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.1
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, S.flame_ring("infernal_feet", FLAMES, 12, 0.15, 0.9, 0.55), "InfernalFeet", Vector3.ZERO, Vector3(1.3, 1.2, 1.3), Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.2, "spin": -2.0, "decay": 0.9}, FIRE_LOOK)
		K.put(art, K.VEIL, S.spiral("infernal_smoke", Color(0.3, 0.15, 0.2, 0.7), Color(0.5, 0.2, 0.2, 0.0), 3, 1.0, 0.5), "InfernalSmoke", Vector3.UP * 0.2, Vector3(1.1, 2.8, 1.1), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": 3.0, "decay": 0.9})
		K.put(art, K.VEIL, K.sprite(), "InfernalMaw", Vector3(0, 1.45, 0.3), Vector3.ONE * 0.7, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.95, "pulse": true}, {"radial": 1.8, "billboard": true, "tint": Color("c03010"), "opacity": 0.85})
		K.put(art, K.VEIL, K.cracks("infernal_heat", SOOT, FIRE, 9, 0.3), "InfernalHeat", Vector3.UP * 0.04, Vector3.ONE * 1.8, Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.92, "priority": -1})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var r := M.radius(skill, 7.0)
	var storm := c.open(origin, 1.9, "Storm", null)
	if storm:
		K.put(storm, K.VEIL, M.fire_ring("infernal_wave", FLAMES, r * 0.85, 28, 0.34, 1.9), "InfernalWave", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.85, {"initial": 0.2, "grow_time": 0.55, "fade_in": 0.01, "decay": 0.45, "front": true}, FIRE_LOOK)
		K.put(storm, K.VEIL, S.spiral("infernal_whirl", Color(1.0, 0.45, 0.15, 0.85), Color(1.0, 0.75, 0.3, 0.1), 5, 1.3, 0.85), "InfernalWhirl", Vector3.ZERO, Vector3(r * 0.45, 2.2, r * 0.45), Vector3.ZERO, 0.9, {"initial": 0.4, "grow_time": 0.4, "fade_in": 0.01, "spin": 7.0, "decay": 0.45})
		K.put(storm, K.VEIL, K.shock(FIRE, FIRE_HI, CRIMSON), "InfernalShock", Vector3.UP * 0.1, Vector3.ONE * r, Vector3.ZERO, 0.55, {"initial": 0.12, "grow_time": 0.85, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(storm, K.VEIL, M.scar("infernal_scorch", SOOT, FIRE, 14), "InfernalScorch", Vector3.UP * 0.04, Vector3.ONE * r * 0.9, Vector3.ZERO, 1.8, {"initial": 0.4, "grow_time": 0.15, "fade_in": 0.01, "decay": 0.6, "priority": -1})
		M.show(storm)
	var roar := c.open(origin, 1.6, "Roar", c.caster)
	if roar:
		K.put(roar, K.VEIL, K.shock(EMBER, FIRE_HI, FIRE), "InfernalRoar1", Vector3.UP * 0.9, Vector3.ONE * r * 0.55, Vector3.ZERO, 0.5, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35, "delay": 0.1}, {"opacity": 0.7})
		K.put(roar, K.VEIL, K.shock(FIRE, EMBER, CRIMSON), "InfernalRoar2", Vector3.UP * 0.5, Vector3.ONE * r * 0.75, Vector3.ZERO, 0.5, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35, "delay": 0.22}, {"opacity": 0.6})
		K.put(roar, K.GLOW, K.embers("infernal_embers", [FIRE, EMBER, FIRE_HI], 30, 3.0, 5.0), "InfernalEmbers", Vector3.UP * 0.4, Vector3.ONE * 1.3, Vector3.ZERO, 1.5, {"cull": 12.0, "decay": 0.8}, {"burst": 1.0, "gravity": 1.0, "drag": 1.3, "life": 1.5, "opacity": 0.8})
		K.put(roar, K.VEIL, K.sprite(), "InfernalGlow", Vector3.UP * 0.12, Vector3.ONE * r * 0.6, Vector3(-PI / 2, 0, 0), 0.6, {"initial": 0.5, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.3}, {"radial": 1.4, "tint": Color("a02a08"), "opacity": 0.2})
		M.show(roar)
	var burn := c.open(origin, 2.4, "Burn", null)
	if burn:
		K.put(burn, K.VEIL, M.fire_ring("infernal_lick", FLAMES, r * 0.85, 22, 0.24, 1.0), "InfernalLick", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 2.0, {"initial": 0.9, "grow_time": 0.2, "fade_in": 0.05, "spin": 0.3, "decay": 0.55, "delay": 0.35}, FIRE_LOOK)
		K.put(burn, K.SOLID, S.puffs("infernal_soot", Color("5a3a40"), SOOT, 10, 7.0), "InfernalSoot", Vector3.UP * 0.3, Vector3.ONE * 0.7, Vector3.ZERO, 1.6, {"cull": 12.0, "decay": 0.6}, M.DARK_LOOK.merged({"burst": 1.0, "gravity": -0.6, "drag": 2.2, "life": 1.6}))
		M.show(burn)
	return true
