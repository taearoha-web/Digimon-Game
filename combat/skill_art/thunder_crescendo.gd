extends RefCounted
## Bard Lv.92: Thunder Crescendo (เครสเชนโดสายฟ้า). Four drums of the sky rise round the
## Bard on a staff of lilac light while storm light gathers overhead. On the release the
## drums are struck: they leap, and lightning crashes down in a ring round the Bard on the
## beat, a thunderclap rolls out in rings of lilac, the drums' sound ripples over the field,
## sparks fly and the stunned foes are left under a dim lilac haze (the weaken) as the
## drums sink away. Cosmetic only (the hit lands at the release).
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const TEMPEST := Color("c79bff")
const TEMPEST_HI := Color("f0e4ff")
const TEMPEST_DK := Color("3a2070")
const SORROW := Color("8fb8ff")
const GOLD := Color("f0c870")
const ROSE := Color("ff6fb5")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.1
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.SOLID, M.drums("crescendo_s", 4, 0.15), "CrescendoDrums", Vector3.ZERO, Vector3.ONE * 2.6, Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": 0.6, "decay": 0.95}, M.NOTE_LOOK.merged({"slide": Vector3(0, -1.2, 0), "slide_time": t, "slide_ease": -2.0}))
		K.put(art, K.VEIL, M.staff("crescendo", TEMPEST, [GOLD, ROSE, TEMPEST_HI]), "CrescendoStaff", Vector3.UP * 0.05, Vector3.ONE * 2.6, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": -1.0, "decay": 0.9})
		K.put(art, K.VEIL, S.wash("crescendo_sky", Color(0.55, 0.4, 0.9, 0.35), Color(0.7, 0.55, 1.0, 0.2)), "CrescendoSky", Vector3.UP * 5.5, Vector3.ONE * 3.0, Vector3.ZERO, t + 0.2, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.3, "spin": 0.6, "decay": 0.85})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var r := M.radius(skill, 8.0)
	var drum := c.open(origin, 1.8, "Drums", c.caster)
	if drum:
		K.put(drum, K.SOLID, M.drums("crescendo_s", 4, 0.15), "CrescendoBeat", Vector3.ZERO, Vector3.ONE * 2.6, Vector3.ZERO, 1.0, {"initial": 1.0, "fade_in": 0.001, "spin": 0.6, "decay": 0.75}, M.NOTE_LOOK.merged({"slide": Vector3(0, 0.5, 0), "slide_time": 0.12, "slide_ease": 2.0, "flap": 0.3, "flap_rate": 14.0}))
		K.put(drum, K.VEIL, M.DS.ripple_mesh(), "CrescendoRipple", Vector3.UP * 0.07, Vector3.ONE * r, Vector3.ZERO, 0.9, {"initial": 0.1, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.45}, {"tint": Color("d8c0ff"), "opacity": 0.85})
		K.put(drum, K.VEIL, K.shock(TEMPEST, TEMPEST_HI, Color("8a6ad0")), "CrescendoClap", Vector3.UP * 0.1, Vector3.ONE * r, Vector3.ZERO, 0.55, {"initial": 0.12, "grow_time": 0.85, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		M.show(drum)
	var storm := c.open(origin, 1.4, "Storm", null)
	if storm:
		K.put(storm, K.VEIL, M.lightning("crescendo_ring_%d" % int(r * 10.0), Color(TEMPEST_HI, 0.95), Color(TEMPEST, 0.75), 8, 6.0, 29, r * 0.65), "CrescendoBolts", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.45, {"initial": 1.0, "fade_in": 0.01, "decay": 0.4}, {"flicker": 0.4, "opacity": 0.95})
		K.put(storm, K.VEIL, M.lightning("crescendo_ring2_%d" % int(r * 10.0), Color(SORROW, 0.9), Color(TEMPEST, 0.7), 6, 5.5, 43, r * 0.4), "CrescendoBolts2", Vector3.ZERO, Vector3.ONE, Vector3(0, 0.5, 0), 0.4, {"initial": 1.0, "fade_in": 0.01, "decay": 0.4, "delay": 0.12}, {"flicker": 0.4, "opacity": 0.9})
		K.put(storm, K.VEIL, K.shock(SORROW, TEMPEST_HI, TEMPEST), "CrescendoEcho", Vector3.UP * 0.12, Vector3.ONE * r * 0.75, Vector3.ZERO, 0.55, {"initial": 0.1, "grow_time": 0.85, "decay": 0.35, "delay": 0.14}, {"opacity": 0.65})
		K.put(storm, K.VEIL, S.sparkles("crescendo_sparks", [TEMPEST, TEMPEST_HI, SORROW, GOLD], 26, 3.0, 5.0), "CrescendoSparks", Vector3.UP * 0.4, Vector3.ONE * 1.4, Vector3.ZERO, 1.3, {"cull": 12.0, "decay": 0.8}, {"burst": 1.0, "gravity": 2.5, "drag": 1.4, "life": 1.3})
		M.show(storm)
	var haze := c.open(origin, 2.0, "Haze", null)
	if haze:
		K.put(haze, K.VEIL, S.wash("crescendo_haze", Color(0.55, 0.45, 0.95, 0.2), Color(0.6, 0.7, 1.0, 0.12)), "CrescendoHaze", Vector3.UP * 0.03, Vector3.ONE * r, Vector3.ZERO, 1.9, {"initial": 0.4, "grow_time": 0.4, "fade_in": 0.05, "decay": 0.6, "delay": 0.15, "priority": -2})
		K.put(haze, K.VEIL, M.staff("crescendo", TEMPEST, [GOLD, ROSE, TEMPEST_HI]), "CrescendoStaffFlash", Vector3.UP * 0.05, Vector3.ONE * r * 0.55, Vector3.ZERO, 1.6, {"initial": 0.6, "grow_time": 0.2, "fade_in": 0.01, "spin": -0.8, "decay": 0.55, "priority": -1})
		M.show(haze)
	return true
