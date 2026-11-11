extends RefCounted
## Dark Lord Lv.64: Royal Crush (ทุบคทาราชัน). A giant scepter of gold rises over the
## Lord's head on a crown seal while the Lord winds up. On the release it slams down on the
## target: a golden crown-shaped shock bursts from the blow, the ground cracks gold under it,
## stones jump, and a ring of little gold stars wheels round the dazed foe's head (the
## stun) before fading. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const ROYAL := Color("e8b64a")
const GOLD_HI := Color("fff0c0")
const GOLD_DK := Color("8a5a18")
const VIOLET := Color("8a4dff")
const SHAFT := Color("3a2850")
const ROCK := Color("8a7050")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.06
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.SOLID, M.scepter("royal", SHAFT, ROYAL, VIOLET), "CrushScepter", Vector3(0.3, 2.0, -0.5), Vector3.ONE * 2.4, Vector3(-0.5, 0, 0.2), t, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.1, "decay": 0.95, "turn": Vector3(-0.4, 0, 0), "front": true}, M.GOLD_LOOK.merged({"slide": Vector3(0, -1.2, 0), "slide_time": t * 0.8, "slide_ease": -2.0}))
		K.put(art, K.VEIL, M.sigil("royal_crown", GOLD_HI, Color(ROYAL, 0.22), 5, 2, 5), "CrushSeal", Vector3.UP * 0.05, Vector3.ONE * 1.4, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": 2.0, "decay": 0.9})
		K.put(art, K.VEIL, K.sprite(), "CrushGleam", Vector3(0.3, 4.3, -0.4), Vector3.ONE * 0.9, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.1, "decay": 0.95, "pulse": true}, {"radial": 1.8, "billboard": true, "tint": Color("a060ff"), "opacity": 0.8})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var at := Vector3(center.x, origin.y, center.z)
	var blow := c.open(at, 1.4, "Blow", null)
	if blow:
		# The scepter comes down head first on the target.
		K.put(blow, K.SOLID, M.scepter("royal", SHAFT, ROYAL, VIOLET), "CrushSlam", Vector3(0, 3.6, -0.4), Vector3.ONE * 3.2, Vector3(PI - 0.25, 0, 0), 0.5, {"initial": 1.0, "fade_in": 0.005, "decay": 0.55, "front": true}, M.GOLD_LOOK.merged({"slide": Vector3(0, 3.5, -1.2), "slide_time": 0.09, "slide_ease": 2.0}))
		K.put(blow, K.VEIL, M.crown("royal_shock", ROYAL, VIOLET, 7), "CrushCrownShock", Vector3.UP * 0.05, Vector3(1.9, 0.7, 1.9), Vector3.ZERO, 0.5, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.01, "decay": 0.4}, {"opacity": 0.85})
		K.put(blow, K.VEIL, K.shock(ROYAL, GOLD_HI, GOLD_DK), "CrushRing", Vector3.UP * 0.1, Vector3.ONE * 3.4, Vector3.ZERO, 0.5, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(blow, K.VEIL, K.cracks("royal_crack", Color(0.25, 0.15, 0.05), ROYAL, 9, 0.3), "CrushCracks", Vector3.UP * 0.04, Vector3.ONE * 2.4, Vector3.ZERO, 1.3, {"initial": 0.5, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "priority": -1})
		K.put(blow, K.SOLID, K.debris("royal_stones", [ROCK, ROYAL, ROCK.lightened(0.3)], 16, 0.22), "CrushStones", Vector3.UP * 0.2, Vector3.ONE * 0.7, Vector3.ZERO, 0.9, {"cull": 8.0, "decay": 0.9}, M.STONE_LOOK.merged({"burst": 1.0, "gravity": 16.0, "drag": 1.0, "life": 0.9}))
		K.put(blow, K.VEIL, S.twinkle("royal_hit", Color(ROYAL, 0.95), Color("b070ff")), "CrushStar", Vector3.UP * 1.0, Vector3.ONE * 1.6, Vector3.ZERO, 0.3, {"initial": 0.3, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.4, "front": true}, {"billboard": true, "opacity": 0.8})
		M.show(blow)
	var daze := c.open(at, 1.3, "Daze", null)
	if daze:
		daze.rotation.y = 0.0
		K.put(daze, K.SOLID, M.orbs("royal_daze", [ROYAL, Color("ffd890"), Color("c890ff")], 5, 0.14), "CrushDaze", Vector3.UP * 2.4, Vector3(0.75, 0.75, 0.75), Vector3(0.25, 0, 0), 1.1, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.05, "spin": 7.0, "decay": 0.7, "delay": 0.1}, M.GOLD_LOOK)
		K.put(daze, K.SOLID, K.debris("royal_dust", [Color("e8d8b0"), Color("c8b080")], 10, 0.16), "CrushDust", Vector3.UP * 0.1, Vector3.ONE * 0.6, Vector3.ZERO, 0.8, {"cull": 6.0, "decay": 0.8}, M.STONE_LOOK.merged({"burst": 1.0, "gravity": 6.0, "drag": 3.0, "life": 0.8}))
		M.show(daze)
	return true
