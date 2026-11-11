extends RefCounted
## Summoner Lv.84: Fairy Spirit (ภูตินางฟ้า). A pink flower bud of light swells at the
## Summoner's side under a pentacle of petals, sparkles spiralling round it. On the release
## the bud bursts into bloom and the fairy appears out of a pink star in a shower of petals
## and heart-light, a ring of light runs out on the ground, and a ribbon of sparkles trails
## her for a moment as she takes her place beside the Summoner. The fairy (Summon) and her
## healing are untouched. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const PINK := Color("ffb6e6")
const PINK_HI := Color("fff0fa")
const ROSE := Color("ff7ac0")
const LILAC := Color("c8a8ff")
const GOLD := Color("ffe08a")
const PETALS := [Color("ffb6e6"), Color("ffd8f0"), Color("ffe08a"), Color("e0b8ff")]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.15
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.SOLID, M.lotus("fairy_bud", ROSE, PINK, GOLD, 8, 2), "FairyBud", Vector3(0.9, 1.1, 0.2), Vector3.ONE * 0.5, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.1, "spin": 2.0, "decay": 0.95}, M.NOTE_LOOK)
		K.put(art, K.VEIL, M.sigil("fairy", PINK_HI, Color(PINK, 0.2), 5, 2, 5), "FairySeal", Vector3.UP * 0.05, Vector3.ONE * 1.5, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": 1.6, "decay": 0.9})
		K.put(art, K.VEIL, S.spiral("fairy_call", Color(1.0, 0.7, 0.9, 0.75), Color(1.0, 0.95, 0.7, 0.0), 3, 1.6, 0.3), "FairyCall", Vector3(0.9, 0.2, 0.2), Vector3(0.8, 1.6, 0.8), Vector3.ZERO, t, {"initial": 0.6, "grow_time": 0.7, "fade_in": 0.2, "spin": 7.0, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var bloom := c.open(origin, 1.0, "Bloom", c.caster)
	if bloom:
		K.put(bloom, K.SOLID, M.lotus("fairy_bud", ROSE, PINK, GOLD, 8, 2), "FairyBloom", Vector3(0.9, 1.1, 0.2), Vector3.ONE * 0.9, Vector3.ZERO, 0.6, {"initial": 0.55, "grow_time": 0.3, "fade_in": 0.01, "spin": 3.0, "decay": 0.45}, M.NOTE_LOOK)
		K.put(bloom, K.VEIL, K.shock(PINK, PINK_HI, LILAC), "FairyRing", Vector3.UP * 0.08, Vector3.ONE * 3.0, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.75})
		M.show(bloom)
	(VfxBudget.carry(func(): _arrive(c))).call_deferred()
	return true


static func _arrive(c: M.Cast) -> void:
	var found := M.summons(c.parent, c.id, c.origin)
	if found.is_empty():
		return
	var fairy: Node3D = found[0]
	var art := c.open(fairy.global_position, 2.4, "Fairy", fairy)
	if not art:
		return
	art.rotation.y = 0.0
	var high := 1.35
	K.put(art, K.VEIL, K.column("fairy_light", [Color(1.0, 0.7, 0.9, 0.5), Color(1.0, 0.8, 0.95, 0.35), Color(1.0, 0.92, 0.8, 0.12), Color(1.0, 0.95, 0.9, 0.0)], 0.6, 14), "FairyPillar", Vector3.ZERO, Vector3(0.9, 4.0, 0.9), Vector3.ZERO, 0.6, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.35}, {"fres": 0.5})
	K.put(art, K.SOLID, M.lotus("fairy_bud", ROSE, PINK, GOLD, 8, 2), "FairyCradle", Vector3.UP * (high - 0.5), Vector3.ONE * 0.8, Vector3.ZERO, 0.8, {"initial": 0.3, "grow_time": 0.3, "fade_in": 0.01, "spin": 2.5, "decay": 0.45}, M.NOTE_LOOK)
	K.put(art, K.VEIL, S.twinkle("fairy_star", Color(ROSE, 0.95), GOLD), "FairyStar", Vector3.UP * high, Vector3.ONE * 2.2, Vector3.ZERO, 0.5, {"initial": 0.2, "grow_time": 0.35, "fade_in": 0.01, "decay": 0.4, "front": true}, {"billboard": true})
	K.put(art, K.SOLID, S.leaves("fairy_petals", PETALS, 24, 4.0, 3.0), "FairyPetals", Vector3.UP * high, Vector3.ONE * 0.8, Vector3.ZERO, 1.6, {"cull": 8.0, "decay": 0.8}, M.NOTE_LOOK.merged({"burst": 1.0, "gravity": 1.2, "drag": 2.0, "life": 1.6}))
	K.put(art, K.VEIL, S.sparkles("fairy_glitter", [PINK, GOLD, LILAC, PINK_HI], 24, 3.0, 2.2), "FairyGlitter", Vector3.UP * high, Vector3.ONE * 0.8, Vector3.ZERO, 1.6, {"cull": 6.0, "decay": 0.8}, {"burst": 1.0, "gravity": 0.6, "drag": 2.0, "life": 1.6})
	K.put(art, K.VEIL, K.shock(PINK_HI, PINK, ROSE), "FairyHalo", Vector3.UP * high, Vector3.ONE * 1.3, Vector3(0.4, 0, 0), 0.6, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.4}, {"opacity": 0.7})
	M.show(art)
	var trail := c.open(fairy.global_position, 2.6, "FairyTrail", fairy)
	if trail:
		trail.rotation.y = 0.0
		# A ribbon of sparkles rides with her as she flies to her place.
		K.put(trail, K.VEIL, S.spiral("fairy_trail", Color(1.0, 0.75, 0.92, 0.8), Color(1.0, 0.95, 0.75, 0.0), 2, 2.0, 0.4), "FairyTrail", Vector3.UP * 0.4, Vector3(0.6, 1.4, 0.6), Vector3.ZERO, 2.4, {"initial": 0.8, "grow_time": 0.3, "fade_in": 0.1, "spin": 6.0, "decay": 0.6, "delay": 0.2})
		K.put(trail, K.VEIL, M.sigil("fairy", PINK_HI, Color(PINK, 0.2), 5, 2, 5), "FairyMark", Vector3.UP * 0.05, Vector3.ONE * 1.2, Vector3.ZERO, 1.4, {"initial": 0.3, "grow_time": 0.4, "fade_in": 0.02, "spin": -1.5, "decay": 0.55})
		M.show(trail)
