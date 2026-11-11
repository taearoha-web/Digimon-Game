extends RefCounted
## Bard Lv.76: Maestro's Fervor (ไฟแห่งวาทยกร). The conductor's spark: a gold light flares
## at the Bard's hand and gold notes whirl up. On the release the Bard catches fire with
## the music: golden flames ring the feet, ribbons of gold fire spiral up round them, a
## ring of gold notes turns at the chest like a conductor's flourish, and sparks rise; the
## fervour burns on round the Bard for a moment as it settles into them. Cosmetic only (the
## buff is the Bard's own).
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const GILT := Color("f0c870")
const GILT_HI := Color("fff2c8")
const AMBER := Color("ff9a40")
const ROSE := Color("ff6fb5")
const FLAMES := [Color(1.0, 0.55, 0.2, 0.9), Color(1.0, 0.72, 0.3, 0.85), Color(1.0, 0.85, 0.45, 0.7), Color(1.0, 0.9, 0.6, 0.45), Color(1.0, 0.95, 0.75, 0.2)]
const NOTES := [Color("f0c870"), Color("ffd890"), Color("ff9ad0"), Color("ffb060")]
const FIRE_LOOK := {"noise_amt": 0.6, "noise_scale": Vector2(4.0, 2.0), "flow": Vector2(0.0, -3.5), "bias": 0.3, "taper": 0.8, "hot": Color("fff0b0"), "edge_heat": 0.4}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.12
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		var hand := c.local(art, c.hand())
		K.put(art, K.VEIL, S.twinkle("fervor_spark", Color(GILT, 0.95), AMBER), "FervorSpark", hand + Vector3(0, 0.2, 0.2), Vector3.ONE * 0.8, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95}, {"billboard": true, "opacity": 0.9})
		K.put(art, K.SOLID, S.note_spray("fervor_rise", NOTES, 10, 3.0, 1.2), "FervorNotes", Vector3.UP * 0.4, Vector3.ONE * 0.7, Vector3.ZERO, t + 0.2, {"cull": 5.0, "decay": 0.8}, M.NOTE_LOOK.merged({"burst": 1.0, "gravity": -1.0, "drag": 2.5, "life": t + 0.3}))
		K.put(art, K.VEIL, M.staff("fervor", GILT, [ROSE, AMBER, GILT_HI]), "FervorStaff", Vector3.UP * 0.05, Vector3.ONE * 1.5, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": 2.0, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var fire := c.open(origin, 2.2, "Fervor", c.caster)
	if fire:
		K.put(fire, K.VEIL, M.fire_ring("fervor_feet", FLAMES, 1.1, 14, 0.24, 1.2), "FervorFlames", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 2.0, {"initial": 0.3, "grow_time": 0.15, "fade_in": 0.01, "spin": 1.2, "decay": 0.6}, FIRE_LOOK)
		K.put(fire, K.VEIL, S.spiral("fervor_ribbons", Color(1.0, 0.7, 0.25, 0.9), Color(1.0, 0.9, 0.6, 0.1), 3, 1.8, 0.5), "FervorRibbons", Vector3.UP * 0.1, Vector3(1.2, 3.4, 1.2), Vector3.ZERO, 1.3, {"initial": 0.5, "grow_time": 0.25, "fade_in": 0.01, "spin": 7.0, "decay": 0.5})
		K.put(fire, K.SOLID, M.note_ring("fervor", NOTES, 8), "FervorFlourish", Vector3.UP * 1.25, Vector3.ONE * 0.95, Vector3(0.2, 0, 0), 1.9, {"initial": 0.4, "grow_time": 0.2, "fade_in": 0.02, "spin": 4.5, "decay": 0.65}, M.NOTE_LOOK)
		K.put(fire, K.VEIL, K.shock(GILT, GILT_HI, AMBER), "FervorRing", Vector3.UP * 0.08, Vector3.ONE * 2.8, Vector3.ZERO, 0.55, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.8})
		M.show(fire)
	var spark := c.open(origin, 2.0, "Sparks", c.caster)
	if spark:
		K.put(spark, K.GLOW, K.embers("fervor_embers", [GILT, AMBER, GILT_HI], 24, 3.5, 1.6), "FervorEmbers", Vector3.UP * 0.3, Vector3.ONE * 0.8, Vector3.ZERO, 1.8, {"cull": 6.0, "decay": 0.8}, {"burst": 1.0, "gravity": -0.8, "drag": 1.6, "life": 1.8, "opacity": 0.75})
		K.put(spark, K.VEIL, M.staff("fervor", GILT, [ROSE, AMBER, GILT_HI]), "FervorStaffOpen", Vector3.UP * 0.05, Vector3.ONE * 2.2, Vector3.ZERO, 1.8, {"initial": 0.7, "grow_time": 0.2, "fade_in": 0.01, "spin": 1.0, "decay": 0.6, "priority": -1})
		M.show(spark)
	return true
