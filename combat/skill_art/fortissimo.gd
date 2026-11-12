extends RefCounted
## Bard Lv.68: Fortissimo (ฟอร์ติสซิโม). The Bard draws breath: rings of sound shrink in
## onto the lute and a rose light swells in it. On the release the loudest chord there is
## blasts out at the foe: a cone of rose sound and rings of it fly down the line one after
## another, and on the foe the blast bursts in a rose star, notes are flung up and a ring of
## little stars wheels round its head (the stun). Cosmetic only (the hit is the skill's,
## at the release).
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const ROSE := Color("ff6fb5")
const ROSE_HI := Color("ffe0f0")
const ROSE_DK := Color("a02a6a")
const GOLD := Color("f0c870")
const NOTES := [Color("ff6fb5"), Color("ffb3dc"), Color("f0c870"), Color("ff9ad0")]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.06
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		var hand := c.local(art, c.hand()) + Vector3(0, 0, 0.3)
		K.put(art, K.VEIL, K.shock(ROSE, ROSE_HI, ROSE_DK), "FortissimoDraw", hand, Vector3.ONE * 0.6, Vector3(PI / 2, 0, 0), t, {"initial": 3.2, "grow_time": 1.0, "fade_in": 0.2, "decay": 0.95}, {"opacity": 0.8})
		K.put(art, K.VEIL, K.shock(GOLD, ROSE_HI, ROSE), "FortissimoDraw2", hand, Vector3.ONE * 0.45, Vector3(PI / 2, 0, 0), t, {"initial": 4.0, "grow_time": 1.0, "fade_in": 0.3, "decay": 0.95, "delay": 0.06}, {"opacity": 0.7})
		K.put(art, K.VEIL, K.sprite(), "FortissimoSwell", hand, Vector3.ONE * 0.8, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.95, "fade_in": 0.2, "decay": 0.95, "pulse": true}, {"radial": 1.8, "billboard": true, "tint": Color("e0408a"), "opacity": 0.85})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var from := c.hand() + c.forward * 0.3
	var to := Vector3(center.x, origin.y + 1.0, center.z)
	var blast := c.open(from, 0.8, "Blast", null)
	if blast:
		blast.rotation.y = 0.0
		var dir := to - from
		M.span(blast, K.VEIL, M.beam("fortissimo_cone", Color(1.0, 0.55, 0.8, 0.75), Color(1.0, 0.8, 0.6, 0.3), 2.6), "FortissimoCone", from, to, 1.2, 0.4, {"initial": 0.3, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.4}, {"noise_amt": 0.3, "noise_scale": Vector2(2.0, 6.0), "flow": Vector2(0.0, -8.0), "bias": 0.5, "taper": 0.0})
		for k in 3:
			K.put(blast, K.VEIL, K.shock(ROSE_HI, ROSE, ROSE_DK), "FortissimoRing%d" % k, Vector3.ZERO, Vector3.ONE * (0.7 + 0.25 * k), M.along(dir), 0.22, {"initial": 0.6, "grow_time": 1.0, "travel": dir, "fade_in": 0.01, "decay": 0.8, "delay": 0.05 * k}, {"opacity": 0.85})
		M.show(blast)
	var hit := c.open(Vector3(center.x, origin.y, center.z), 1.3, "Hit", null)
	if hit:
		K.put(hit, K.VEIL, S.twinkle("fortissimo_star", Color(ROSE, 0.95), GOLD), "FortissimoStar", Vector3.UP * 1.1, Vector3.ONE * 3.0, Vector3.ZERO, 0.35, {"initial": 0.3, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.4, "front": true, "delay": 0.08}, {"billboard": true, "opacity": 0.85})
		K.put(hit, K.VEIL, K.shock(ROSE, ROSE_HI, ROSE_DK), "FortissimoBurst", Vector3.UP * 0.08, Vector3.ONE * 3.6, Vector3.ZERO, 0.5, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35, "delay": 0.08}, {"opacity": 0.85})
		K.put(hit, K.SOLID, M.DS.note_burst(), "FortissimoNotes", Vector3.UP * 0.8, Vector3.ONE * 0.85, Vector3.ZERO, 1.0, {"cull": 8.0, "decay": 0.75, "delay": 0.08}, M.NOTE_LOOK.merged({"burst": 1.0, "gravity": 9.0, "drag": 1.3, "life": 1.0}))
		K.put(hit, K.SOLID, M.orbs("fortissimo_daze", [ROSE, GOLD, Color("ffd0ea")], 5, 0.14), "FortissimoDaze", Vector3.UP * 2.4, Vector3.ONE * 0.7, Vector3(0.25, 0, 0), 1.1, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.05, "spin": 7.0, "decay": 0.7, "delay": 0.15}, M.NOTE_LOOK)
		M.show(hit)
	return true
