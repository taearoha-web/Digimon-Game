extends RefCounted
## Dark Lord Lv.84: Chaos Sovereign (ราชันแห่งความโกลาหล). A spiked crown of chaos rises
## over the Lord's head and a violet aura coils round them while a great crescent of force
## gathers at the scepter. On the release the crescent rips through the target: a giant
## violet blade sweeps across it and a second smaller one cuts back, the air tears open in a
## dark rift, shards of shattered force fly and a ring of chaos bursts round the foe; the
## rift seals in violet smoke. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const VIOLET := Color("8a4dff")
const VIOLET_HI := Color("e8d4ff")
const VIOLET_DK := Color("1e0a3a")
const MAGENTA := Color("d040ff")
const GOLD := Color("e8b64a")
const IRON := Color("2a2236")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.06
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.SOLID, M.crown("chaos_iron", IRON, MAGENTA, 8, true), "SovereignCrown", Vector3.UP * 2.5, Vector3.ONE * 0.38, Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.1, "spin": 2.0, "decay": 0.95}, M.DARK_LOOK.merged({"slide": Vector3(0, -0.6, 0), "slide_time": t, "slide_ease": -2.0}))
		K.put(art, K.VEIL, S.spiral("sovereign_aura", Color(0.55, 0.25, 1.0, 0.8), Color(0.9, 0.5, 1.0, 0.0), 3, 1.6, 0.5), "SovereignAura", Vector3.UP * 0.1, Vector3(1.1, 2.6, 1.1), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": -7.0, "decay": 0.9})
		K.put(art, K.VEIL, M.slash("sovereign_gather", VIOLET_HI, VIOLET, VIOLET_DK), "SovereignGather", Vector3(0.4, 1.4, 0.5), Vector3.ONE * 1.0, Vector3(0, 0.3, 0.6), t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.95, "face_camera": true})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var at := Vector3(center.x, origin.y, center.z)
	var rip := c.open(at, 1.4, "Rip", null)
	if rip:
		# The great blade sweeps across the foe, a second cuts back.
		K.put(rip, K.VEIL, M.slash("sovereign", VIOLET_HI, VIOLET, VIOLET_DK), "SovereignSlash", Vector3(0, 1.3, -0.2), Vector3.ONE * 3.4, Vector3(0, 0, -0.5), 0.4, {"initial": 0.6, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.45, "turn": Vector3(0, 0, 1.4), "front": true, "face_camera": true})
		K.put(rip, K.VEIL, M.slash("sovereign_back", MAGENTA, VIOLET, VIOLET_DK), "SovereignBack", Vector3(0, 1.4, 0.1), Vector3.ONE * 2.4, Vector3(0, PI, 0.6), 0.35, {"initial": 0.6, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.45, "turn": Vector3(0, 0, -1.2), "delay": 0.1, "front": true, "face_camera": true})
		K.put(rip, K.VEIL, K.cracks("sovereign_rift", VIOLET_DK, MAGENTA, 8, 0.0), "SovereignRift", Vector3(0, 1.2, 0), Vector3(1.1, 1.0, 2.2), Vector3(PI / 2, 0, 0.3), 0.9, {"initial": 0.3, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.55, "delay": 0.05, "face_camera": true})
		K.put(rip, K.VEIL, M.glass("sovereign_shards", [VIOLET, MAGENTA, VIOLET_HI, IRON], 20, 6.0, 4.0), "SovereignShards", Vector3.UP * 0.4, Vector3.ONE * 0.9, Vector3.ZERO, 1.0, {"cull": 8.0, "decay": 0.8}, {"burst": 1.0, "gravity": 8.0, "drag": 1.4, "life": 1.0})
		K.put(rip, K.VEIL, K.shock(VIOLET, VIOLET_HI, VIOLET_DK), "SovereignRing", Vector3.UP * 0.1, Vector3.ONE * 3.8, Vector3.ZERO, 0.5, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(rip, K.VEIL, K.sprite(), "SovereignFlash", Vector3.UP * 1.1, Vector3.ONE * 1.6, Vector3.ZERO, 0.3, {"initial": 0.4, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.35}, {"radial": 1.6, "billboard": true, "tint": Color("8030e0"), "opacity": 0.8})
		M.show(rip)
	var smoke := c.open(at, 1.5, "Smoke", null)
	if smoke:
		K.put(smoke, K.VEIL, K.cracks("sovereign_ground", VIOLET_DK, MAGENTA, 9, 0.3), "SovereignScar", Vector3.UP * 0.04, Vector3.ONE * 2.6, Vector3.ZERO, 1.4, {"initial": 0.5, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "priority": -1})
		K.put(smoke, K.SOLID, S.puffs("sovereign_smoke", Color("6a4a9a"), Color("2a1a4a"), 9, 5.0), "SovereignPuffs", Vector3.UP * 0.6, Vector3.ONE * 0.6, Vector3.ZERO, 1.3, {"cull": 8.0, "decay": 0.6, "delay": 0.15}, M.DARK_LOOK.merged({"burst": 1.0, "gravity": -0.8, "drag": 2.4, "life": 1.3}))
		K.put(smoke, K.GLOW, K.embers("sovereign_gold", [GOLD, MAGENTA, VIOLET_HI], 16, 2.5, 2.5), "SovereignSparks", Vector3.UP * 0.8, Vector3.ONE * 0.7, Vector3.ZERO, 1.1, {"cull": 6.0, "decay": 0.8}, {"burst": 1.0, "gravity": 2.0, "drag": 1.6, "life": 1.1, "opacity": 0.8})
		M.show(smoke)
	return true
