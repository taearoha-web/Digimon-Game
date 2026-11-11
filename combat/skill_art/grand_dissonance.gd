extends RefCounted
## Bard Lv.80: Grand Dissonance (มหาเสียงไม่ประสาน). Over the target area two staffs of
## violet light turn against each other, out of true, and dark notes jitter round between
## them. On the release the discord breaks: warped rings of sound burst off-centre one after
## another, the notes crack and fly apart as shards of violet glass (the armour shred),
## jagged cracks of dissonance split the ground and a pall of violet smoke sinks over the
## foes (the weaken) before it drifts away. Cosmetic only (the hit lands at the release).
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const DISSO := Color("b07aff")
const DISSO_HI := Color("eadcff")
const DISSO_DK := Color("2e1458")
const SORROW := Color("8fb8ff")
const ROSE := Color("ff6fb5")
const NOTES := [Color("7a4ad0"), Color("b07aff"), Color("5a3a9a"), Color("8fb8ff")]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.08
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, S.spiral("disso_call", Color(0.6, 0.4, 1.0, 0.75), Color(0.5, 0.7, 1.0, 0.0), 3, 1.5, 0.4), "DissoCall", Vector3.UP * 0.1, Vector3(1.2, 2.4, 1.2), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": -7.0, "decay": 0.9})
		M.show(art)
	var point := Vector3(aim.x, origin.y, aim.z)
	var r := M.radius(skill, 7.0)
	var area := c.open(point, t, "Discord", null)
	if area:
		K.put(area, K.VEIL, M.staff("disso_a", DISSO, [DISSO_DK, SORROW, DISSO_HI]), "DissoStaffA", Vector3(0.4, 0.05, 0.2), Vector3.ONE * r * 0.9, Vector3(0.05, 0, 0.04), t, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.2, "spin": 1.2, "decay": 0.92})
		K.put(area, K.VEIL, M.staff("disso_b", SORROW, [DISSO, ROSE, DISSO_HI]), "DissoStaffB", Vector3(-0.4, 0.07, -0.25), Vector3.ONE * r * 0.75, Vector3(-0.06, 0, -0.03), t, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.2, "spin": -1.6, "decay": 0.92})
		K.put(area, K.SOLID, M.note_ring("disso", NOTES, 10), "DissoNotes", Vector3.UP * 1.6, Vector3.ONE * 1.9, Vector3(0.12, 0, -0.1), t, {"initial": 0.6, "grow_time": 0.6, "fade_in": 0.2, "spin": -3.0, "decay": 0.92, "pulse": true}, M.DARK_LOOK.merged({"flap": 0.25, "flap_rate": 18.0}))
		M.show(area)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var point := Vector3(center.x, origin.y, center.z)
	var r := M.radius(skill, 7.0)
	var crack := c.open(point, 1.6, "Break", null)
	if crack:
		for k in 3:
			var off := Vector3(sin(k * 2.1), 0, cos(k * 2.1)) * r * 0.18
			K.put(crack, K.VEIL, K.shock([DISSO, SORROW, ROSE][k], DISSO_HI, Color("7a50c0")), "DissoWave%d" % k, off + Vector3.UP * (0.08 + 0.02 * k), Vector3.ONE * r * (0.95 - 0.12 * k), Vector3(0.04 * (k - 1), 0, 0.05), 0.55, {"initial": 0.1, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35, "delay": 0.1 * k}, {"opacity": 0.85})
		K.put(crack, K.VEIL, M.glass("disso_shards", [DISSO, DISSO_HI, SORROW, DISSO_DK], 30, 6.5, 5.0), "DissoShards", Vector3.UP * 0.5, Vector3.ONE * 1.4, Vector3.ZERO, 1.3, {"cull": 12.0, "decay": 0.8}, {"burst": 1.0, "gravity": 8.0, "drag": 1.2, "life": 1.3})
		K.put(crack, K.VEIL, M.scar("disso_split", DISSO_DK, DISSO, 13), "DissoSplit", Vector3.UP * 0.04, Vector3.ONE * r * 0.9, Vector3.ZERO, 1.5, {"initial": 0.4, "grow_time": 0.12, "fade_in": 0.01, "decay": 0.6, "priority": -1})
		M.show(crack)
	var pall := c.open(point, 2.0, "Pall", null)
	if pall:
		K.put(pall, K.SOLID, S.note_spray("disso_break", NOTES, 14, 5.0, 4.5), "DissoNoteBreak", Vector3.UP * 1.0, Vector3.ONE * 1.1, Vector3.ZERO, 1.1, {"cull": 10.0, "decay": 0.75}, M.DARK_LOOK.merged({"burst": 1.0, "gravity": 9.0, "drag": 1.2, "life": 1.1}))
		K.put(pall, K.VEIL, S.wash("disso_pall", Color(0.4, 0.25, 0.7, 0.4), Color(0.5, 0.4, 0.9, 0.25)), "DissoPall", Vector3.UP * 0.04, Vector3.ONE * r, Vector3.ZERO, 1.9, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.05, "decay": 0.6, "delay": 0.15, "priority": -2})
		K.put(pall, K.SOLID, S.puffs("disso_smoke", Color("8a6ac8"), Color("3a2a6a"), 10, 6.0), "DissoSmoke", Vector3.UP * 0.3, Vector3.ONE * 0.6, Vector3.ZERO, 1.6, {"cull": 10.0, "decay": 0.6, "delay": 0.1}, M.DARK_LOOK.merged({"burst": 1.0, "gravity": 0.6, "drag": 2.2, "life": 1.6}))
		K.put(pall, K.VEIL, S.sparkles("disso_motes", [DISSO, SORROW, DISSO_HI], 20, 1.5, 3.0), "DissoMotes", Vector3.UP * 1.5, Vector3.ONE * 1.3, Vector3.ZERO, 1.8, {"cull": 10.0, "decay": 0.8}, {"burst": 1.0, "gravity": 1.2, "drag": 1.4, "life": 1.8})
		M.show(pall)
	return true
