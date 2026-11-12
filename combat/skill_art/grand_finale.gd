extends RefCounted
## Bard Lv.100: Grand Finale (มหาคอนเสิร์ตปิดม่าน), the Bard's greatest show. The stage
## is set: three spotlights of rose, gold and aqua swing down out of the sky onto the
## target area, a great staff of light turns round it and a ring of notes circles over the
## foes. On the release the finale goes off: fireworks of rose, gold and aqua burst over the
## area one after another, a pillar of stage light drives down, a fountain of notes and a
## storm of confetti fly up, rings of sound roll out over the field and the stunned foes are
## left in a shower of falling sparkles as the lights go down. Cosmetic only (the hit lands
## at the release).
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const ROSE := Color("ff6fb5")
const ROSE_HI := Color("ffe0f0")
const ROSE_DK := Color("8a1a5a")
const GOLD := Color("ffd36b")
const AQUA := Color("9fe8ff")
const LILAC := Color("c79bff")
const NOTES := [Color("ff6fb5"), Color("ffd36b"), Color("9fe8ff"), Color("c79bff")]
const TALL := 8.0


static func _lights(parent: Node3D, point: Vector3) -> Array:
	var back := M.away(parent)
	var side := back.cross(Vector3.UP).normalized()
	return [point + back * 6.0 + side * 5.0 + Vector3.UP * 9.0, point + back * 7.0 + Vector3.UP * 10.0, point + back * 6.0 - side * 5.0 + Vector3.UP * 9.0]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.06
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, S.spiral("finale_call", Color(1.0, 0.55, 0.8, 0.8), Color(1.0, 0.9, 0.6, 0.0), 4, 1.6, 0.4), "FinaleCall", Vector3.UP * 0.1, Vector3(1.4, 3.0, 1.4), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": 6.0, "decay": 0.9})
		K.put(art, K.SOLID, M.note_ring("finale_lute", NOTES, 8), "FinaleLute", Vector3.UP * 1.2, Vector3.ONE * 0.9, Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.7, "fade_in": 0.2, "spin": 4.0, "decay": 0.92}, M.NOTE_LOOK)
		M.show(art)
	var point := Vector3(aim.x, origin.y, aim.z)
	var r := M.radius(skill, 9.5)
	var stage := c.open(point, t + 0.05, "Stage", null)
	if stage:
		stage.rotation.y = 0.0
		var tones := [Color(1.0, 0.55, 0.8, 0.45), Color(1.0, 0.85, 0.45, 0.45), Color(0.6, 0.9, 1.0, 0.45)]
		var lights := _lights(parent, point)
		for k in 3:
			var foot := point + Vector3(sin(k * 2.1 + 0.6), 0, cos(k * 2.1 + 0.6)) * r * 0.35
			M.span(stage, K.VEIL, M.beam("finale_spot_%d" % k, tones[k], Color(tones[k], 0.15), 3.5), "FinaleSpot%d" % k, lights[k], foot, 0.8, t + 0.05, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.3, "decay": 0.97})
		K.put(stage, K.VEIL, M.staff("finale", GOLD, [ROSE, AQUA, LILAC]), "FinaleStaff", Vector3.UP * 0.05, Vector3.ONE * r, Vector3.ZERO, t + 0.05, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.2, "spin": 0.6, "decay": 0.95})
		K.put(stage, K.SOLID, M.note_ring("finale", NOTES, 12), "FinaleCircle", Vector3.UP * 3.8, Vector3.ONE * 1.7, Vector3.ZERO, t + 0.05, {"initial": 0.5, "grow_time": 0.8, "fade_in": 0.2, "spin": -1.4, "decay": 0.95}, M.NOTE_LOOK)
		M.show(stage)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var point := Vector3(center.x, origin.y, center.z)
	c.fit = K.frame(parent, point, origin, TALL, 0.0)
	var r := M.radius(skill, 9.5) / c.fit
	# The fireworks: rose, gold and aqua bursts over the area, one after another.
	var sky := c.open(point, 2.2, "Fireworks", null)
	if sky:
		sky.rotation.y = 0.0
		var back := M.away(parent) / c.fit
		for k in 3:
			var tone: Color = [ROSE, GOLD, AQUA][k]
			var spot := Vector3(sin(k * 2.1 + 0.9), 0, cos(k * 2.1 + 0.9)) * r * 0.35 + back * 2.0 + Vector3.UP * (5.5 + k * 0.6)
			K.put(sky, K.VEIL, S.twinkle("finale_" + tone.to_html(), Color(tone, 0.9), Color(LILAC, 0.8)), "FinaleBloom%d" % k, spot, Vector3.ONE * 2.6, Vector3.ZERO, 0.45, {"initial": 0.2, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.45, "delay": 0.12 * k}, {"billboard": true, "opacity": 0.65})
			K.put(sky, K.VEIL, S.sparkles("finale_burst_" + tone.to_html(), [tone, tone.lerp(Color.WHITE, 0.3), LILAC], 26, 1.5, 6.0), "FinaleBurst%d" % k, spot, Vector3.ONE * 1.0, Vector3.ZERO, 1.8, {"cull": 14.0, "decay": 0.8, "delay": 0.12 * k}, {"burst": 1.0, "gravity": 3.0, "drag": 1.6, "life": 1.8})
		M.show(sky)
	var stage := c.open(point, 2.4, "Show", null)
	if stage:
		K.put(stage, K.VEIL, K.column("finale_pillar", [Color(1.0, 0.5, 0.78, 0.65), Color(1.0, 0.7, 0.6, 0.45), Color(1.0, 0.85, 0.6, 0.2), Color(1.0, 0.9, 0.7, 0.0)], 0.7, 18), "FinalePillar", Vector3.ZERO, Vector3(1.8, TALL, 1.8), Vector3.ZERO, 0.7, {"initial": 0.5, "grow_time": 0.15, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.6, "noise_amt": 0.5, "noise_scale": Vector2(6.0, 1.5), "flow": Vector2(0.0, 6.0), "bias": 0.1, "taper": 0.3, "fres": 0.5})
		K.put(stage, K.VEIL, K.shock(ROSE, ROSE_HI, ROSE_DK), "FinaleShock", Vector3.UP * 0.1, Vector3.ONE * r, Vector3.ZERO, 0.7, {"initial": 0.1, "grow_time": 0.85, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(stage, K.SOLID, M.DS.note_fountain(), "FinaleFountain", Vector3.UP * 0.3, Vector3.ONE * 0.75, Vector3.ZERO, 2.2, {"cull": 18.0, "decay": 0.85}, M.NOTE_LOOK.merged({"burst": 1.0, "gravity": 11.0, "drag": 0.9, "life": 2.2}))
		K.put(stage, K.VEIL, M.staff("finale", GOLD, [ROSE, AQUA, LILAC]), "FinaleStaffFlash", Vector3.UP * 0.05, Vector3.ONE * r, Vector3.ZERO, 1.6, {"initial": 1.0, "fade_in": 0.01, "spin": 1.2, "decay": 0.5, "priority": -1})
		M.show(stage)
	var crowd := c.open(point, 2.4, "Encore", null)
	if crowd:
		K.put(crowd, K.SOLID, M.DS.confetti_mesh(), "FinaleConfetti", Vector3.UP * 0.4, Vector3.ONE * 1.2, Vector3.ZERO, 2.2, {"cull": 16.0, "decay": 0.85}, M.NOTE_LOOK.merged({"burst": 1.0, "gravity": 5.0, "drag": 2.0, "life": 2.2}))
		K.put(crowd, K.VEIL, M.DS.ripple_mesh(), "FinaleRipple", Vector3.UP * 0.07, Vector3.ONE * r * 0.85, Vector3.ZERO, 1.0, {"initial": 0.12, "grow_time": 0.9, "decay": 0.45, "delay": 0.25}, {"tint": Color("ffc0e0"), "opacity": 0.8})
		K.put(crowd, K.VEIL, K.shock(GOLD, Color("fff4cc"), LILAC), "FinaleEcho", Vector3.UP * 0.12, Vector3.ONE * r * 0.7, Vector3.ZERO, 0.7, {"initial": 0.1, "grow_time": 0.85, "decay": 0.35, "delay": 0.4}, {"opacity": 0.65})
		M.show(crowd)
	if c.rich:
		var rain := c.open(point, 2.6, "Sparkle", null)
		if rain:
			K.put(rain, K.VEIL, S.sparkles("finale_rain", [ROSE, GOLD, AQUA, LILAC], 30, -0.4, 3.5), "FinaleRain", Vector3.UP * 4.5, Vector3.ONE * 1.6, Vector3.ZERO, 2.4, {"cull": 16.0, "decay": 0.85, "delay": 0.3}, {"burst": 1.0, "gravity": 1.6, "drag": 1.2, "life": 2.4})
			K.put(rain, K.SOLID, M.DS.note_burst(), "FinaleNotes", Vector3.UP * 0.8, Vector3.ONE * 1.0, Vector3.ZERO, 1.4, {"cull": 12.0, "decay": 0.75, "delay": 0.15}, M.NOTE_LOOK.merged({"burst": 1.0, "gravity": 9.0, "drag": 1.2, "life": 1.4}))
			M.show(rain)
	return true
