extends RefCounted
## Bard Lv.96: Hymn of Legends (บทเพลงแห่งตำนาน), the Bard's greatest song. Golden light
## falls round the Bard onto a ring of gold staff lines. On the release the hymn rises: a
## golden harp of light rises behind the Bard and plays, a halo of gold turns over the
## head, a pillar of warm light climbs, a fountain of notes leaps up and falls all round,
## and gold rings run out to every ally the song reaches; the harp fades back into the light
## as the last notes fall. Cosmetic only (the buff is the hero's).
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const SHINE := Color("ffd36b")
const SHINE_HI := Color("fff4cc")
const SHINE_DK := Color("a8701c")
const ROSE := Color("ff6fb5")
const AQUA := Color("9fe8ff")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.12
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, K.column("hymn_fall", [Color(1.0, 0.85, 0.4, 0.0), Color(1.0, 0.88, 0.45, 0.35), Color(1.0, 0.92, 0.6, 0.45), Color(1.0, 0.95, 0.7, 0.0)], 0.7, 16), "HymnLight", Vector3.ZERO, Vector3(1.5, 7.5, 1.5), Vector3.ZERO, t, {"initial": 0.6, "grow_time": 0.8, "fade_in": 0.4, "decay": 0.9}, {"noise_amt": 0.5, "noise_scale": Vector2(5.0, 1.5), "flow": Vector2(0.0, 2.5), "bias": 0.2, "taper": 0.3, "fres": 0.5})
		K.put(art, K.VEIL, M.staff("hymn", SHINE, [ROSE, AQUA, SHINE_HI]), "HymnStaff", Vector3.UP * 0.05, Vector3.ONE * 2.0, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": 1.0, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var choir := c.open(origin, 2.6, "Choir", c.caster)
	if choir:
		S.face_away(choir)
		K.put(choir, K.SOLID, M.DS.harp_mesh(), "HymnHarp", Vector3(0, 0, 1.6), Vector3.ONE * 0.75, Vector3.ZERO, 2.5, {"initial": 0.4, "grow_time": 0.15, "fade_in": 0.02, "decay": 0.65, "cull": 6.0}, M.NOTE_LOOK.merged({"slide": Vector3(0, -2.5, 0), "slide_time": 0.35, "slide_ease": -2.5}))
		K.put(choir, K.VEIL, K.shock(SHINE_HI, SHINE, ROSE), "HymnHalo", Vector3.UP * 2.6, Vector3.ONE * 0.75, Vector3.ZERO, 2.4, {"initial": 0.3, "grow_time": 0.2, "fade_in": 0.02, "spin": 1.5, "decay": 0.7}, {"opacity": 0.9})
		K.put(choir, K.VEIL, K.column("hymn_pillar", [Color(1.0, 0.82, 0.35, 0.55), Color(1.0, 0.88, 0.5, 0.4), Color(1.0, 0.9, 0.7, 0.15), Color(1.0, 0.95, 0.8, 0.0)], 0.75, 18), "HymnPillar", Vector3.ZERO, Vector3(1.4, 7.0, 1.4), Vector3.ZERO, 0.9, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.55, "noise_amt": 0.5, "noise_scale": Vector2(6.0, 1.5), "flow": Vector2(0.0, -3.0), "bias": 0.1, "taper": 0.5, "fres": 0.5})
		K.put(choir, K.VEIL, M.staff("hymn", SHINE, [ROSE, AQUA, SHINE_HI]), "HymnFloor", Vector3.UP * 0.05, Vector3.ONE * 3.4, Vector3.ZERO, 2.4, {"initial": 0.6, "grow_time": 0.2, "fade_in": 0.01, "spin": 0.5, "decay": 0.6, "priority": -1})
		M.show(choir)
	var song := c.open(origin, 2.6, "Song", c.caster)
	if song:
		K.put(song, K.SOLID, M.DS.note_fountain(), "HymnFountain", Vector3.UP * 0.3, Vector3.ONE * 0.5, Vector3.ZERO, 2.4, {"cull": 14.0, "decay": 0.85}, M.NOTE_LOOK.merged({"burst": 1.0, "gravity": 12.0, "drag": 0.9, "life": 2.4}))
		K.put(song, K.VEIL, K.shock(SHINE, SHINE_HI, SHINE_DK), "HymnRing", Vector3.UP * 0.08, Vector3.ONE * 6.0, Vector3.ZERO, 0.7, {"initial": 0.12, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(song, K.VEIL, M.DS.ripple_mesh(), "HymnRipple", Vector3.UP * 0.07, Vector3.ONE * 4.5, Vector3.ZERO, 0.9, {"initial": 0.15, "grow_time": 0.9, "decay": 0.45, "delay": 0.3}, {"tint": Color("ffe0a0"), "opacity": 0.75})
		K.put(song, K.VEIL, S.sparkles("hymn_gold", [SHINE, SHINE_HI, ROSE, AQUA], 30, 5.0, 2.5), "HymnSparkles", Vector3.UP * 0.6, Vector3.ONE * 1.1, Vector3.ZERO, 2.2, {"cull": 10.0, "decay": 0.8}, {"burst": 1.0, "gravity": -0.4, "drag": 1.5, "life": 2.2})
		M.show(song)
	var team := M.allies(c, 12.0, [1, 2, 4][c.q])
	if not team.is_empty():
		var marks := c.open(origin, 1.4, "Chorus", null)
		if marks:
			marks.rotation.y = 0.0
			for i in team.size():
				var at: Vector3 = marks.to_local((team[i] as Node3D).global_position)
				K.put(marks, K.VEIL, K.shock(SHINE, SHINE_HI, ROSE), "HymnChorus%d" % i, at + Vector3.UP * 0.08, Vector3.ONE * 1.6, Vector3.ZERO, 0.9, {"initial": 0.2, "grow_time": 0.8, "decay": 0.4, "delay": 0.15 + 0.05 * i}, {"opacity": 0.8})
			M.show(marks)
	return true
