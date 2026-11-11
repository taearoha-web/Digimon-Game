extends RefCounted
## Bard Lv.84: Aria of Ruin (อาเรียแห่งหายนะ). The Bard sings the highest note there is:
## it rises out of the lute as a giant rose note of light and climbs into the sky over the
## foe, rings of the song gathering under it and a thin thread of light already marking the
## foe. On the release the note splits down onto the foe: a pillar of rose light drives into
## it, the air shatters in rose glass, notes burst out and a crack of song splits the ground;
## a fading ring of light hums on after. Cosmetic only (the hit lands at the release).
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const ROSE := Color("ff6fb5")
const ROSE_HI := Color("ffe0f0")
const ROSE_DK := Color("8a1a5a")
const GOLD := Color("f0c870")
const HIGH := 6.0


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.06
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, S.spiral("aria_voice", Color(1.0, 0.5, 0.75, 0.8), Color(1.0, 0.85, 0.6, 0.0), 3, 1.6, 0.4), "AriaVoice", Vector3.UP * 0.1, Vector3(1.2, 2.6, 1.2), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": 6.0, "decay": 0.9})
		M.show(art)
	var point := Vector3(aim.x, origin.y, aim.z)
	c.fit = K.frame(parent, point, origin, HIGH + 1.5, 0.0)
	var sky := c.open(point, t, "Note", null)
	if sky:
		sky.rotation.y = 0.0
		K.put(sky, K.SOLID, S.note("aria_high", ROSE), "AriaNote", Vector3.UP * HIGH, Vector3.ONE * 3.0, Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.98, "face_camera": true, "front": true}, M.NOTE_LOOK.merged({"slide": Vector3(0, -4.0, 0), "slide_time": t, "slide_ease": -2.0}))
		K.put(sky, K.VEIL, K.sprite(), "AriaGlow", Vector3.UP * (HIGH + 0.6), Vector3.ONE * 2.2, Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.98, "pulse": true}, {"radial": 1.8, "billboard": true, "tint": Color("d0407a"), "opacity": 0.45})
		K.put(sky, K.VEIL, K.shock(ROSE_HI, ROSE, GOLD), "AriaGather", Vector3.UP * 0.08, Vector3.ONE * 1.4, Vector3.ZERO, t, {"initial": 2.6, "grow_time": 1.0, "fade_in": 0.2, "decay": 0.95}, {"opacity": 0.8})
		K.put(sky, K.VEIL, M.beam("aria_thread", Color(1.0, 0.6, 0.85, 0.6), Color(1.0, 0.85, 0.7, 0.2), 1.0), "AriaThread", Vector3.UP * HIGH, Vector3(0.18, 0.18, HIGH), Vector3(PI / 2, 0, 0), t, {"initial": 1.0, "fade_in": 0.5, "decay": 0.98})
		M.show(sky)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var point := Vector3(center.x, origin.y, center.z)
	c.fit = K.frame(parent, point, origin, HIGH + 1.5, 0.0)
	var ruin := c.open(point, 1.4, "Ruin", null)
	if ruin:
		ruin.rotation.y = 0.0
		K.put(ruin, K.SOLID, S.note("aria_high", ROSE), "AriaDive", Vector3.UP * 1.0, Vector3.ONE * 3.0, Vector3.ZERO, 0.3, {"initial": 1.0, "fade_in": 0.005, "decay": 0.5, "face_camera": true, "front": true}, M.NOTE_LOOK.merged({"slide": Vector3(0, HIGH - 1.0, 0), "slide_time": 0.08, "slide_ease": 2.0}))
		K.put(ruin, K.VEIL, K.column("aria_pillar", [Color(1.0, 0.45, 0.72, 0.7), Color(1.0, 0.6, 0.8, 0.55), Color(1.0, 0.8, 0.85, 0.25), Color(1.0, 0.85, 0.9, 0.0)], 0.8, 16), "AriaPillar", Vector3.ZERO, Vector3(1.3, HIGH + 1.0, 1.3), Vector3.ZERO, 0.6, {"initial": 0.5, "grow_time": 0.15, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.75, "noise_amt": 0.5, "noise_scale": Vector2(6.0, 1.5), "flow": Vector2(0.0, 6.0), "bias": 0.1, "taper": 0.3, "fres": 0.5})
		K.put(ruin, K.VEIL, M.glass("aria_glass", [ROSE, ROSE_HI, GOLD, Color("ff9ad0")], 26, 6.0, 5.0), "AriaShatter", Vector3.UP * 0.8, Vector3.ONE * 1.1, Vector3.ZERO, 1.1, {"cull": 10.0, "decay": 0.8}, {"burst": 1.0, "gravity": 9.0, "drag": 1.2, "life": 1.1})
		K.put(ruin, K.VEIL, K.shock(ROSE, ROSE_HI, ROSE_DK), "AriaShock", Vector3.UP * 0.1, Vector3.ONE * 3.6, Vector3.ZERO, 0.55, {"initial": 0.12, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		M.show(ruin)
	var after := c.open(point, 1.6, "Hum", null)
	if after:
		K.put(after, K.SOLID, M.DS.note_burst(), "AriaNotes", Vector3.UP * 0.8, Vector3.ONE * 0.75, Vector3.ZERO, 1.1, {"cull": 10.0, "decay": 0.75}, M.NOTE_LOOK.merged({"burst": 1.0, "gravity": 9.0, "drag": 1.3, "life": 1.1}))
		K.put(after, K.VEIL, M.scar("aria_crack", ROSE_DK, ROSE, 8), "AriaCrack", Vector3.UP * 0.04, Vector3.ONE * 2.6, Vector3.ZERO, 1.4, {"initial": 0.5, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "priority": -1})
		K.put(after, K.VEIL, M.DS.ripple_mesh(), "AriaHum", Vector3.UP * 0.07, Vector3.ONE * 2.4, Vector3.ZERO, 1.2, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.02, "decay": 0.5, "delay": 0.2}, {"tint": Color("ffb0d8"), "opacity": 0.8})
		M.show(after)
	return true
