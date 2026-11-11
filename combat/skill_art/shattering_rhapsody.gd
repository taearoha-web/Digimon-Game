extends RefCounted
## Bard Lv.72: Shattering Rhapsody (ราพโซดีสายฟ้า). Lilac storm light gathers over the
## target area and a staff of five lines turns on the ground, crackling. On the release the
## rhapsody strikes in rhythm: three bolts of lilac lightning crash down one after another,
## and the foes' armour shatters into flying shards of glass light (the shred), ripples of
## sound run out and the staff flashes; a slow lilac haze hangs (the slow) as it fades.
## Cosmetic only (the hit lands at the release).
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const TEMPEST := Color("c79bff")
const TEMPEST_HI := Color("f0e4ff")
const TEMPEST_DK := Color("4a2a8a")
const ROSE := Color("ff8ac8")
const GOLD := Color("f0c870")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.08
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, S.spiral("rhapsody_call", Color(0.8, 0.6, 1.0, 0.75), Color(1.0, 0.8, 1.0, 0.0), 3, 1.5, 0.4), "RhapsodyCall", Vector3.UP * 0.1, Vector3(1.2, 2.4, 1.2), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": 6.0, "decay": 0.9})
		M.show(art)
	var point := Vector3(aim.x, origin.y, aim.z)
	var r := M.radius(skill, 6.0)
	var area := c.open(point, t, "Gather", null)
	if area:
		K.put(area, K.VEIL, M.staff("rhapsody", TEMPEST, [ROSE, GOLD, TEMPEST_HI]), "RhapsodyStaff", Vector3.UP * 0.05, Vector3.ONE * r, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.2, "spin": 0.8, "decay": 0.92})
		K.put(area, K.VEIL, M.lightning("rhapsody_crackle_%d" % int(r * 10.0), Color(TEMPEST_HI, 0.9), Color(TEMPEST, 0.6), 5, 1.4, 17, r * 0.6), "RhapsodyCrackle", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, t, {"initial": 0.7, "grow_time": 0.6, "fade_in": 0.3, "spin": 2.0, "decay": 0.9}, {"flicker": 0.6, "opacity": 0.7})
		K.put(area, K.VEIL, S.wash("rhapsody_sky", Color(0.6, 0.45, 0.95, 0.35), Color(0.75, 0.6, 1.0, 0.2)), "RhapsodyCloud", Vector3.UP * 5.5, Vector3.ONE * r * 0.6, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.3, "spin": 0.5, "decay": 0.95})
		M.show(area)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var point := Vector3(center.x, origin.y, center.z)
	var r := M.radius(skill, 6.0)
	var beat := c.open(point, 1.4, "Beat", null)
	if beat:
		for k in 3:
			var spot := Vector3(sin(k * 2.3 + 0.4), 0, cos(k * 2.3 + 0.4)) * r * (0.15 + 0.2 * k)
			K.put(beat, K.VEIL, M.lightning("rhapsody_strike%d" % k, Color(TEMPEST_HI, 0.95), Color(TEMPEST, 0.75), 1, 6.0, 7 + k * 11, 0.05), "RhapsodyBolt%d" % k, spot, Vector3.ONE, Vector3.ZERO, 0.28, {"initial": 1.0, "fade_in": 0.01, "decay": 0.45, "delay": 0.13 * k}, {"flicker": 0.3, "opacity": 0.95})
		K.put(beat, K.VEIL, M.DS.ripple_mesh(), "RhapsodyRipple", Vector3.UP * 0.06, Vector3.ONE * r * 0.9, Vector3.ZERO, 0.8, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.45}, {"tint": Color("d0b0ff"), "opacity": 0.85})
		K.put(beat, K.VEIL, M.glass("rhapsody_shards", [TEMPEST, TEMPEST_HI, ROSE, Color("a0c8ff")], 30, 6.0, 5.0), "RhapsodyShards", Vector3.UP * 0.3, Vector3.ONE * 1.3, Vector3.ZERO, 1.2, {"cull": 12.0, "decay": 0.8}, {"burst": 1.0, "gravity": 9.0, "drag": 1.2, "life": 1.2})
		M.show(beat)
	var haze := c.open(point, 1.8, "Haze", null)
	if haze:
		K.put(haze, K.VEIL, M.staff("rhapsody", TEMPEST, [ROSE, GOLD, TEMPEST_HI]), "RhapsodyFlash", Vector3.UP * 0.05, Vector3.ONE * r, Vector3.ZERO, 1.2, {"initial": 1.0, "fade_in": 0.01, "spin": 1.6, "decay": 0.5})
		K.put(haze, K.VEIL, K.shock(TEMPEST, TEMPEST_HI, TEMPEST_DK), "RhapsodyShock", Vector3.UP * 0.1, Vector3.ONE * r, Vector3.ZERO, 0.55, {"initial": 0.12, "grow_time": 0.85, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(haze, K.VEIL, S.wash("rhapsody_haze", Color(0.65, 0.5, 1.0, 0.3), Color(0.75, 0.6, 1.0, 0.2)), "RhapsodySlow", Vector3.UP * 0.03, Vector3.ONE * r, Vector3.ZERO, 1.8, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.05, "decay": 0.6, "delay": 0.2, "priority": -2})
		K.put(haze, K.VEIL, S.sparkles("rhapsody_sparks", [TEMPEST, TEMPEST_HI, GOLD], 20, 3.0, 3.0), "RhapsodySparks", Vector3.UP * 0.3, Vector3.ONE * 1.2, Vector3.ZERO, 1.4, {"cull": 10.0, "decay": 0.8}, {"burst": 1.0, "gravity": 2.0, "drag": 1.6, "life": 1.4})
		M.show(haze)
	return true
