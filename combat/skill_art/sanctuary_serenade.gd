extends RefCounted
## Bard Lv.64: Sanctuary Serenade (เซเรเนดแห่งวิหาร). Aqua notes drift down round the Bard
## onto a ring of staff lines. On the release the song raises a sanctuary: a dome of aqua
## light with ribs like a chapel's rises over the Bard, a ring of notes circles inside it,
## a ward ripple runs over the ground and soft light drifts up; each party member the song
## reaches gets a small ring of the same light. The dome thins away as the verse ends.
## Cosmetic only (the heal, the guard and the shield are the hero's).
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const AQUA := Color("9fe8ff")
const AQUA_HI := Color("e8faff")
const AQUA_DK := Color("2a8ab8")
const ROSE := Color("ff8ac8")
const GOLD := Color("f0c870")
const NOTES := [Color("9fe8ff"), Color("ffb3dc"), Color("f0c870"), Color("c8f4ff")]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.12
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, M.staff("serenade", AQUA, [ROSE, GOLD, AQUA_HI]), "SerenadeStaff", Vector3.UP * 0.05, Vector3.ONE * 1.8, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": 1.2, "decay": 0.9})
		K.put(art, K.SOLID, M.note_ring("serenade", NOTES, 8), "SerenadeFall", Vector3.UP * 2.6, Vector3.ONE * 1.2, Vector3.ZERO, t, {"initial": 0.6, "grow_time": 0.7, "fade_in": 0.3, "spin": 2.5, "decay": 0.92}, M.NOTE_LOOK.merged({"slide": Vector3(0, 1.2, 0), "slide_time": t, "slide_ease": -2.0}))
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var dome := c.open(origin, 2.2, "Sanctuary", c.caster)
	if dome:
		K.put(dome, K.VEIL, M.dome("serenade", Color(0.75, 0.95, 1.0, 1.0), Color(0.55, 0.88, 1.0, 0.28)), "SerenadeDome", Vector3.ZERO, Vector3(2.6, 2.4, 2.6), Vector3.ZERO, 2.1, {"initial": 0.2, "grow_time": 0.2, "fade_in": 0.02, "spin": 0.3, "decay": 0.62}, {"fres": 0.0, "opacity": 0.85})
		K.put(dome, K.SOLID, M.note_ring("serenade", NOTES, 8), "SerenadeCircle", Vector3.UP * 1.2, Vector3.ONE * 1.6, Vector3.ZERO, 2.0, {"initial": 0.5, "grow_time": 0.25, "fade_in": 0.02, "spin": 1.8, "decay": 0.65}, M.NOTE_LOOK)
		K.put(dome, K.VEIL, M.staff("serenade", AQUA, [ROSE, GOLD, AQUA_HI]), "SerenadeFloor", Vector3.UP * 0.05, Vector3.ONE * 2.7, Vector3.ZERO, 2.1, {"initial": 0.7, "grow_time": 0.2, "fade_in": 0.01, "spin": 0.6, "decay": 0.62, "priority": -1})
		K.put(dome, K.VEIL, K.shock(AQUA, AQUA_HI, AQUA_DK), "SerenadeWard", Vector3.UP * 0.08, Vector3.ONE * 3.8, Vector3.ZERO, 0.6, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.8})
		M.show(dome)
	var glow := c.open(origin, 2.0, "Hymn", c.caster)
	if glow:
		K.put(glow, K.VEIL, S.sparkles("serenade_motes", [AQUA, AQUA_HI, ROSE, GOLD], 24, 3.0, 1.8), "SerenadeMotes", Vector3.UP * 0.4, Vector3.ONE, Vector3.ZERO, 1.9, {"cull": 6.0, "decay": 0.8}, {"burst": 1.0, "gravity": -0.8, "drag": 1.8, "life": 1.9})
		K.put(glow, K.VEIL, K.shock(AQUA_HI, AQUA, ROSE), "SerenadeEcho", Vector3.UP * 0.1, Vector3.ONE * 2.8, Vector3.ZERO, 0.6, {"initial": 0.2, "grow_time": 0.9, "decay": 0.35, "delay": 0.45}, {"opacity": 0.6})
		M.show(glow)
	var team := M.allies(c, 12.0, [1, 2, 4][c.q])
	if not team.is_empty():
		var marks := c.open(origin, 1.3, "Ward", null)
		if marks:
			marks.rotation.y = 0.0
			for i in team.size():
				var at: Vector3 = marks.to_local((team[i] as Node3D).global_position)
				K.put(marks, K.VEIL, K.shock(AQUA, AQUA_HI, AQUA_DK), "SerenadeShield%d" % i, at + Vector3.UP * 0.08, Vector3.ONE * 1.4, Vector3.ZERO, 0.9, {"initial": 0.2, "grow_time": 0.8, "decay": 0.4, "delay": 0.12 + 0.05 * i}, {"opacity": 0.75})
			M.show(marks)
	return true
