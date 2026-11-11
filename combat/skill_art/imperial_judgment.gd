extends RefCounted
## Dark Lord Lv.100: Imperial Judgment (คำพิพากษาจักรพรรดิ), the Lord's greatest strike.
## Three orbs (void violet, hellfire, storm blue) wheel round the Lord over a great
## imperial seal while a ring of dark cloud gathers overhead. On the release the judgment
## falls in three: a column of void erupts at the Lord and a violet shock throws the foes
## back (the repel), a ring of hellfire races out, and a crown of lightning bolts crashes
## down round the area; the ground splits gold, the three orbs fly apart, stones and sparks
## burst, and the imperial seal stays burnt into the ground as the smoke rolls away.
## Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const ROYAL := Color("e8b64a")
const GOLD_HI := Color("fff0c0")
const VIOLET := Color("8a4dff")
const VIOLET_HI := Color("e0c8ff")
const VIOLET_DK := Color("1e0a3a")
const FIRE := Color("ff6a2a")
const BOLT := Color("8fd8ff")
const BOLT_CORE := Color("d0f2ff")
const ROCK := Color("5a4a60")
const FLAMES := [Color(0.75, 0.15, 0.08, 0.9), Color(1.0, 0.35, 0.1, 0.9), Color(1.0, 0.6, 0.2, 0.75), Color(1.0, 0.8, 0.4, 0.45), Color(1.0, 0.9, 0.6, 0.2)]
const FIRE_LOOK := {"noise_amt": 0.6, "noise_scale": Vector2(4.0, 2.0), "flow": Vector2(0.0, -3.5), "bias": 0.3, "taper": 0.8, "hot": Color("ffd890"), "edge_heat": 0.5}
const TALL := 7.0


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.12
	var r := M.radius(skill, 9.0)
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.SOLID, M.orbs("judgment_three", [VIOLET, FIRE, BOLT], 3, 0.2), "JudgmentOrbs", Vector3.UP * 1.6, Vector3.ONE * 1.1, Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.7, "fade_in": 0.2, "spin": 8.0, "decay": 0.95}, M.GOLD_LOOK)
		K.put(art, K.VEIL, M.sigil("judgment", GOLD_HI, Color(VIOLET, 0.15), 12, 5, 12), "JudgmentSeal", Vector3.UP * 0.05, Vector3.ONE * r * 0.6, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.2, "spin": 0.7, "decay": 0.92}, {"opacity": 0.65})
		K.put(art, K.VEIL, S.spiral("judgment_gather", Color(0.6, 0.35, 1.0, 0.75), Color(1.0, 0.75, 0.4, 0.0), 4, 1.2, 0.4), "JudgmentGather", Vector3.UP * 0.1, Vector3(2.4, 2.4, 2.4), Vector3.ZERO, t, {"initial": 1.6, "grow_time": 1.0, "fade_in": 0.2, "spin": -6.0, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	c.fit = K.frame(parent, origin, origin, TALL, 0.0)
	var r := M.radius(skill, 9.0) / c.fit
	# The void: a column erupts and a violet shock throws the foes back.
	var void_root := c.open(origin, 2.0, "Void", null)
	if void_root:
		K.put(void_root, K.VEIL, K.column("judgment_void", [Color(0.5, 0.25, 0.95, 0.65), Color(0.4, 0.18, 0.8, 0.5), Color(0.3, 0.12, 0.6, 0.25), Color(0.25, 0.1, 0.5, 0.0)], 1.3, 18), "JudgmentVoid", Vector3.ZERO, Vector3(1.1, TALL - 1.5, 1.1), Vector3.ZERO, 0.7, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.5, "noise_amt": 0.7, "noise_scale": Vector2(5.0, 2.0), "flow": Vector2(0.3, -3.0), "bias": 0.15, "taper": 0.6, "fres": 0.4})
		K.put(void_root, K.VEIL, K.shock(VIOLET, VIOLET_HI, VIOLET_DK), "JudgmentRepel", Vector3.UP * 0.1, Vector3.ONE * r, Vector3.ZERO, 0.6, {"initial": 0.1, "grow_time": 0.8, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.9})
		K.put(void_root, K.VEIL, M.scar("judgment_split", Color(0.3, 0.18, 0.06), ROYAL, 16), "JudgmentSplit", Vector3.UP * 0.04, Vector3.ONE * r * 0.85, Vector3.ZERO, 1.9, {"initial": 0.35, "grow_time": 0.12, "fade_in": 0.01, "decay": 0.6, "priority": -1})
		K.put(void_root, K.SOLID, M.orbs("judgment_three", [VIOLET, FIRE, BOLT], 3, 0.2), "JudgmentOrbsFly", Vector3.UP * 1.6, Vector3.ONE * r * 0.6, Vector3.ZERO, 0.5, {"initial": 0.08, "grow_time": 0.9, "fade_in": 0.01, "spin": 3.0, "decay": 0.5}, M.GOLD_LOOK)
		M.show(void_root)
	# The fire: a ring of hellfire races out.
	var fire := c.open(origin, 1.8, "Fire", null)
	if fire:
		K.put(fire, K.VEIL, M.fire_ring("judgment_fire", FLAMES, r * 0.7, 30, 0.34, 1.9), "JudgmentFire", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.9, {"initial": 0.15, "grow_time": 0.6, "fade_in": 0.01, "decay": 0.45, "delay": 0.06}, FIRE_LOOK)
		K.put(fire, K.VEIL, K.shock(FIRE, Color("ffd08a"), Color("a02010")), "JudgmentFireRing", Vector3.UP * 0.12, Vector3.ONE * r * 0.8, Vector3.ZERO, 0.6, {"initial": 0.1, "grow_time": 0.85, "decay": 0.35, "delay": 0.06}, {"opacity": 0.75})
		K.put(fire, K.GLOW, K.embers("judgment_embers", [FIRE, ROYAL, VIOLET_HI], 30, 3.0, 5.0), "JudgmentEmbers", Vector3.UP * 0.4, Vector3.ONE * 1.3, Vector3.ZERO, 1.6, {"cull": 14.0, "decay": 0.8}, {"burst": 1.0, "gravity": 1.0, "drag": 1.3, "life": 1.6, "opacity": 0.8})
		M.show(fire)
	# The storm: a crown of bolts crashes down round the area.
	var storm := c.open(origin, 1.6, "Storm", null)
	if storm:
		K.put(storm, K.VEIL, M.lightning("judgment_crown_%d" % int(r * 10.0), Color(BOLT_CORE, 0.95), Color(VIOLET, 0.75), 7, 6.0, 37, r * 0.72), "JudgmentBolts", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.5, {"initial": 1.0, "fade_in": 0.01, "decay": 0.35, "delay": 0.12}, {"flicker": 0.4, "opacity": 0.95})
		K.put(storm, K.VEIL, K.shock(BOLT, BOLT_CORE, VIOLET), "JudgmentStormRing", Vector3.UP * 0.14, Vector3.ONE * r * 0.6, Vector3.ZERO, 0.6, {"initial": 0.1, "grow_time": 0.85, "decay": 0.35, "delay": 0.14}, {"opacity": 0.7})
		K.put(storm, K.SOLID, M.crown("judgment", ROYAL, VIOLET, 9, true), "JudgmentCrown", Vector3.UP * 3.2, Vector3.ONE * 0.7, Vector3.ZERO, 1.4, {"initial": 0.3, "grow_time": 0.2, "fade_in": 0.02, "spin": 1.2, "decay": 0.65, "front": true}, M.GOLD_LOOK.merged({"slide": Vector3(0, 3.0, 0), "slide_time": 0.25, "slide_ease": -2.0}))
		M.show(storm)
	var seal := c.open(origin, 2.4, "Seal", null)
	if seal:
		K.put(seal, K.VEIL, M.sigil("judgment", GOLD_HI, Color(VIOLET, 0.15), 12, 5, 12), "JudgmentBrand", Vector3.UP * 0.05, Vector3.ONE * r * 0.75, Vector3.ZERO, 2.3, {"initial": 0.6, "grow_time": 0.15, "fade_in": 0.01, "spin": 0.3, "decay": 0.6, "priority": -2}, {"opacity": 0.6})
		K.put(seal, K.SOLID, K.debris("judgment_stones", [ROCK, ROYAL, VIOLET.darkened(0.4)], 30, 0.36), "JudgmentStones", Vector3.UP * 0.2, Vector3.ONE * 1.3, Vector3.ZERO, 1.4, {"cull": 16.0, "decay": 0.9}, M.STONE_LOOK.merged({"burst": 1.0, "gravity": 15.0, "drag": 0.8, "life": 1.4}))
		K.put(seal, K.VEIL, K.sprite(), "JudgmentGlow", Vector3.UP * 0.12, Vector3.ONE * r * 0.6, Vector3(-PI / 2, 0, 0), 0.7, {"initial": 0.5, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.3}, {"radial": 1.4, "tint": Color("5a2090"), "opacity": 0.2})
		M.show(seal)
	if c.rich:
		var smoke := c.open(origin, 2.4, "Smoke", null)
		if smoke:
			K.put(smoke, K.SOLID, S.puffs("judgment_smoke", Color("6a5a8a"), Color("2a2040"), 12, 8.0), "JudgmentPuffs", Vector3.UP * 0.3, Vector3.ONE * 0.8, Vector3.ZERO, 1.8, {"cull": 14.0, "decay": 0.6, "delay": 0.1}, M.DARK_LOOK.merged({"burst": 1.0, "gravity": -0.5, "drag": 2.0, "life": 1.8}))
			K.put(smoke, K.VEIL, S.sparkles("judgment_sparks", [BOLT, ROYAL, VIOLET_HI], 24, 3.0, 4.0), "JudgmentSparkles", Vector3.UP * 0.5, Vector3.ONE * 1.4, Vector3.ZERO, 1.8, {"cull": 12.0, "decay": 0.8}, {"burst": 1.0, "gravity": 1.0, "drag": 1.4, "life": 1.8})
			M.show(smoke)
	return true
