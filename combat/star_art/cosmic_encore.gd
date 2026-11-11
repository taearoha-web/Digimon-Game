extends RefCounted
## Bard 200 stars: อังกอร์แห่งจักรวาล. Flying high, the Bard plays the encore to the
## cosmos: a spiral galaxy of lilac, rose and sky blue opens and turns over the target
## with three ringed planets wheeling round it, a constellation drawn on the ground below.
## On each of four waves a meteor-note falls out of the galaxy with a comet's tail and
## bursts on its spot in a star, rings and a spray of notes; for the fifth the galaxy
## collapses into a supernova over the middle: a pillar of starlight, a giant star, rings
## of pastel light chasing out over the field and a fountain of notes. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "cosmic_encore"
const BEATS := [0.0, 0.32, 0.64, 0.96, 1.36]
const SKY := 6.0
const TALL := 8.0
const FALL := 0.26
const LILAC := Color("c79bff")
const LILAC_DK := Color("5a32a8")
const ROSE := Color("ff8ac8")
const SKYBLUE := Color("8ad8ff")
const GOLD := Color("ffd87a")
const PEARL := Color("fff0ff")
const NOTE_LOOK := {"rim_color": Color("fff4ff"), "rim": 0.6, "shadow_tint": Color(0.75, 0.68, 0.95)}
static var _fit := 1.0


static func _r(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 7.5)), 4.0, 9.0)


static func _root(parent: Node3D, point: Vector3, seconds: float, label: String, source: Vector3) -> StarSkillArt:
	return S.root(parent, Vector3(point.x, 0, point.z), seconds, label, source, null, _fit)


static func _spot(index: int, r: float) -> Vector3:
	return [Vector3(-0.4, 0, 0.12), Vector3(0.38, 0, 0.3), Vector3(-0.08, 0, -0.36), Vector3(0.3, 0, -0.18), Vector3.ZERO][index % 5] * r


## A meteor-note falls from the galaxy onto [param spot] and lands [param delay] + FALL s from now.
static func _meteor(art: StarSkillArt, spot: Vector3, delay: float, big := 1.0) -> void:
	var high := spot + Vector3(0, SKY - 0.5, 1.2)
	var fall := spot + Vector3.UP * 0.8 - high
	var tone: Color = [ROSE, SKYBLUE, GOLD, LILAC][int(absf(spot.x * 7.0)) % 4]
	K.put(art, K.SOLID, S.note("encore_" + tone.to_html(), tone), "EncoreMeteor", high, Vector3.ONE * 1.3 * big, Vector3(-0.6, 0, -0.25), FALL, {"travel": fall, "accelerate": true, "fade_in": 0.05, "decay": 0.98, "delay": delay, "front": true}, NOTE_LOOK)
	K.put(art, K.GLOW, S.tail("encore_" + tone.to_html(), Color(tone.lerp(PEARL, 0.25), 0.9), Color(LILAC, 0.6)), "EncoreTail", high, Vector3(0.9, 3.2, 0.9) * big, Vector3(0.19, 0, 0), FALL, {"travel": fall, "accelerate": true, "fade_in": 0.05, "decay": 0.98, "delay": delay})


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	_fit = K.frame(parent, point, origin, TALL, 0.0)
	var r := _r(skill) / _fit
	# The Bard rises on a spiral of starlight.
	K.put(art, K.VEIL, S.spiral("encore_rise", Color(0.8, 0.6, 1.0, 0.8), Color(1.0, 0.6, 0.85, 0.0), 3, 1.6, 0.4), "EncoreRise", Vector3.UP * 0.2, Vector3(1.6, 5.5, 1.6), Vector3.ZERO, time, {"initial": 0.4, "grow_time": 0.5, "fade_in": 0.2, "spin": 4.0, "decay": 0.85})
	K.put(art, K.VEIL, K.shock(LILAC, PEARL, ROSE), "EncoreCallRing", Vector3.UP * 0.08, Vector3.ONE * 2.0, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.5, "spin": 1.2, "decay": 0.9}, {"opacity": 0.8})
	# The galaxy turns over the target until the supernova.
	var stay := time + float(BEATS[4])
	var sky := _root(parent, point, stay + 0.15, "StarEncoreSky_" + ID, origin)
	if sky:
		var come := {"initial": 0.15, "grow_time": time / stay * 0.8, "fade_in": time / stay * 0.5}
		K.put(sky, K.VEIL, galaxy_mesh(), "EncoreGalaxy", Vector3.UP * SKY, Vector3.ONE * r * 0.8, Vector3(-0.3, 0, 0), stay + 0.15, {"spin": 0.9, "decay": 0.92, "priority": -1}.merged(come, true), {"noise_amt": 0.5, "noise_scale": Vector2(6.0, 2.0), "flow": Vector2(0.3, 0.0), "bias": 0.3, "taper": 0.4})
		K.put(sky, K.GLOW, K.sprite(), "EncoreCore", Vector3.UP * SKY, Vector3.ONE * 2.4, Vector3.ZERO, stay + 0.15, {"decay": 0.92, "pulse": true}.merged(come, true), {"radial": 1.6, "billboard": true, "tint": Color("ff9ae0"), "opacity": 0.6})
		K.put(sky, K.SOLID, planets_mesh(), "EncorePlanets", Vector3.UP * (SKY - 0.3), Vector3.ONE * r * 0.62, Vector3(-0.3, 0, 0), stay + 0.15, {"spin": 1.3, "decay": 0.92, "cull": 6.0}.merged(come, true), NOTE_LOOK)
		K.put(sky, K.VEIL, K.area_mark(PEARL, LILAC), "EncoreArea", Vector3.UP * 0.07, Vector3.ONE * r, Vector3.ZERO, stay + 0.15, {"spin": -0.3, "decay": 0.92}.merged(come, true))
		K.put(sky, K.VEIL, S.constellation("encore_ground", Color(0.85, 0.7, 1.0, 1.0), Color(1.0, 0.65, 0.9, 0.85), 11, 13), "EncoreChart", Vector3.UP * 0.08, Vector3.ONE * r * 0.92, Vector3.ZERO, stay + 0.15, {"spin": 0.2, "decay": 0.92}.merged(come, true))
		# The first meteor-note lands with the release.
		_meteor(sky, _spot(0, r), maxf(0.0, time - FALL))
		sky._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := _r(skill) / _fit
	art.scale = Vector3.ONE * _fit
	if index >= 4:
		return _finale(art, parent, r, point, source)
	var spot := _spot(index, r)
	var tone: Color = [ROSE, SKYBLUE, GOLD, LILAC][index % 4]
	K.put(art, K.GLOW, S.twinkle("encore_" + tone.to_html(), Color(tone, 0.95), PEARL), "EncoreStar", spot + Vector3.UP * 1.1, Vector3.ONE * 2.6, Vector3.ZERO, 0.4, {"initial": 0.3, "grow_time": 0.35, "fade_in": 0.01, "decay": 0.4, "front": true}, {"billboard": true})
	K.put(art, K.VEIL, K.shock(tone, PEARL, LILAC_DK), "EncoreRing", spot + Vector3.UP * 0.1, Vector3.ONE * 3.4, Vector3.ZERO, 0.5, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.35}, {"opacity": 0.85})
	K.put(art, K.SOLID, S.note_spray("encore", [ROSE, SKYBLUE, GOLD, LILAC], 10, 6.0, 3.5), "EncoreNotes", spot, Vector3.ONE * 1.0, Vector3(0, index * 1.7, 0), 1.0, {"cull": 8.0, "decay": 0.8}, NOTE_LOOK.merged({"burst": 1.0, "gravity": 8.0, "drag": 1.2, "life": 1.0}))
	K.put(art, K.VEIL, S.sparkles("encore", [LILAC, ROSE, SKYBLUE, GOLD], 22, 4.0, 3.0), "EncoreSparkles", spot + Vector3.UP * 0.3, Vector3.ONE, Vector3.ZERO, 1.1, {"cull": 8.0, "decay": 0.85}, {"burst": 1.0, "gravity": 2.0, "drag": 1.8, "life": 1.1})
	K.put(art, K.VEIL, K.cracks("encore_" + tone.to_html(), Color(0.2, 0.08, 0.35), tone, 8, 0.3), "EncoreScar", spot + Vector3.UP * 0.05, Vector3.ONE * 2.2, Vector3(0, index, 0), 1.2, {"initial": 0.4, "grow_time": 0.1, "decay": 0.6, "priority": -1})
	# The next meteor-note is already falling towards the next wave (the supernova: the middle).
	var next := float(BEATS[index + 1]) - float(BEATS[index])
	if index < 3:
		_meteor(art, _spot(index + 1, r), maxf(0.0, next - FALL))
	return true


static func _finale(art: StarSkillArt, parent: Node3D, r: float, point: Vector3, source: Vector3) -> bool:
	K.put(art, K.VEIL, K.column("encore_pillar", [Color(1.0, 0.55, 0.85, 0.75), Color(0.75, 0.5, 1.0, 0.6), Color(0.45, 0.7, 1.0, 0.35), Color(0.6, 0.5, 1.0, 0.0)], 0.6, 16), "EncorePillar", Vector3.ZERO, Vector3(1.8, SKY + 1.0, 1.8), Vector3.ZERO, 0.75, {"initial": 0.4, "grow_time": 0.15, "fade_in": 0.01, "decay": 0.35, "front": true}, {"noise_amt": 0.6, "noise_scale": Vector2(6.0, 2.0), "flow": Vector2(0.0, -6.0), "bias": -0.25, "taper": 0.3, "fres": 0.5})
	K.put(art, K.GLOW, S.twinkle("encore_nova", Color(1.0, 0.6, 0.9, 0.95), Color(0.6, 0.85, 1.0)), "EncoreNova", Vector3.UP * 2.4, Vector3.ONE * 5.0, Vector3.ZERO, 0.6, {"initial": 0.2, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.4, "front": true}, {"billboard": true})
	K.put(art, K.VEIL, K.shock(LILAC, PEARL, ROSE), "EncoreShock", Vector3.UP * 0.12, Vector3.ONE * r * 1.15, Vector3.ZERO, 0.75, {"initial": 0.08, "grow_time": 0.75, "fade_in": 0.02, "decay": 0.45}, {"opacity": 0.85})
	K.put(art, K.SOLID, S.DS.note_fountain(), "EncoreFountain", Vector3.UP * 0.3, Vector3.ONE * 0.8, Vector3.ZERO, 1.8, {"cull": 20.0, "decay": 0.85}, NOTE_LOOK.merged({"burst": 1.0, "gravity": 10.0, "drag": 0.9, "life": 1.8}))
	K.put(art, K.VEIL, S.constellation("encore_print", Color(0.9, 0.75, 1.0, 1.0), Color(1.0, 0.6, 0.9, 0.9), 11, 13), "EncorePrint", Vector3.UP * 0.09, Vector3.ONE * r * 0.95, Vector3.ZERO, 1.9, {"initial": 1.2, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.6, "spin": 0.2})
	K.put(art, K.VEIL, S.sparkles("encore_big", [LILAC, ROSE, SKYBLUE, GOLD, PEARL], 30, 6.0, 4.5), "EncoreStardust", Vector3.UP * 0.4, Vector3.ONE * 1.6, Vector3.ZERO, 1.8, {"cull": 16.0, "decay": 0.85}, {"burst": 1.0, "gravity": 1.5, "drag": 1.4, "life": 1.8})
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	var rings := _root(parent, point, 2.0, "StarEncoreRings_" + ID, source)
	if rings:
		K.put(rings, K.VEIL, K.shock(ROSE, PEARL, LILAC), "EncoreRingRose", Vector3.UP * 0.14, Vector3.ONE * r * 0.85, Vector3.ZERO, 0.8, {"initial": 0.08, "grow_time": 0.8, "decay": 0.4, "delay": 0.12})
		K.put(rings, K.VEIL, K.shock(SKYBLUE, PEARL, LILAC), "EncoreRingBlue", Vector3.UP * 0.16, Vector3.ONE * r * 0.65, Vector3.ZERO, 0.8, {"initial": 0.08, "grow_time": 0.8, "decay": 0.4, "delay": 0.24})
		K.put(rings, K.VEIL, galaxy_mesh(), "EncoreCollapse", Vector3.UP * SKY, Vector3.ONE * r * 0.16, Vector3(-0.3, 0, 0), 0.5, {"initial": 5.0, "grow_time": 0.9, "fade_in": 0.001, "decay": 0.6, "spin": 6.0, "priority": -1})
		rings._draw()
	if extras < 2:
		return true
	var glow := _root(parent, point, 1.9, "StarEncoreGlow_" + ID, source)
	if glow:
		K.put(glow, K.SOLID, S.DS.confetti_mesh(), "EncoreConfetti", Vector3.UP * 0.4, Vector3.ONE * 1.1, Vector3.ZERO, 1.8, {"cull": 16.0, "decay": 0.85}, NOTE_LOOK.merged({"burst": 1.0, "gravity": 5.0, "drag": 2.0, "life": 1.8}))
		K.put(glow, K.VEIL, K.sprite(), "EncoreAfterglow", Vector3.UP * 0.2, Vector3.ONE * r * 0.9, Vector3(-PI / 2, 0, 0), 1.8, {"fade_in": 0.05, "decay": 0.35, "priority": -1}, {"radial": 1.2, "tint": Color("c07aff"), "opacity": 0.45})
		glow._draw()
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
## A spiral galaxy (radius 1, flat): a glowing heart and three arms of lilac, rose and
## sky blue fading out, dusted with stars.
static func galaxy_mesh() -> ArrayMesh:
	return K.cached("star_encore_galaxy", func():
		var b := K.Builder.new()
		b.annulus(0.0, 0.25, 24, Color(1.0, 0.85, 1.0, 0.85), Color(0.85, 0.6, 1.0, 0.55))
		b.annulus(0.25, 1.0, 32, Color(0.6, 0.4, 1.0, 0.35), Color(0.3, 0.15, 0.6, 0.0))
		var arms := [ROSE, SKYBLUE, LILAC]
		for arm in 3:
			var tone: Color = arms[arm]
			var prev_a := Vector3.ZERO
			var prev_b := Vector3.ZERO
			for k in range(0, 31):
				var f := float(k) / 30.0
				var a := TAU * arm / 3.0 + f * 4.4
				var d := Vector3(sin(a), 0, cos(a))
				var rr := 0.15 + 0.85 * f
				var w := 0.16 * (1.0 - f) + 0.03
				var pa := d * (rr - w) + Vector3.UP * 0.01
				var pb := d * (rr + w) + Vector3.UP * 0.01
				if k > 0:
					var c := Color(tone.lerp(Color.WHITE, 0.25 * (1.0 - f)), 0.85 * (1.0 - f * 0.9))
					b.quad(prev_a, prev_b, pb, pa, c, c)
				prev_a = pa
				prev_b = pb
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in 26:
			var a := rng.randf() * TAU
			var p := Vector3(sin(a), 0.02, cos(a)) * rng.randf_range(0.2, 0.95)
			var s := rng.randf_range(0.02, 0.045)
			b.fan([p, p + Vector3(-s * 2.0, 0, 0), p + Vector3(0, 0, s * 0.4), p + Vector3(s * 2.0, 0, 0), p + Vector3(0, 0, -s * 0.4), p + Vector3(-s * 2.0, 0, 0)], Color(PEARL, 0.95), Color(PEARL, 0.0))
			b.fan([p, p + Vector3(0, 0, -s * 2.0), p + Vector3(s * 0.4, 0, 0), p + Vector3(0, 0, s * 2.0), p + Vector3(-s * 0.4, 0, 0), p + Vector3(0, 0, -s * 2.0)], Color(PEARL, 0.95), Color(PEARL, 0.0))
		return b.mesh())


## Three ringed planets on a circle of radius 1 (they wheel with the layer's spin).
static func planets_mesh() -> ArrayMesh:
	return K.cached("star_encore_planets", func():
		var b := K.Builder.new()
		var tones := [[ROSE, Color("c0407a")], [SKYBLUE, Color("3a78c0")], [GOLD, Color("c08a30")]]
		for k in 3:
			var a := TAU * k / 3.0 + 0.4
			var c := Vector3(sin(a), 0.1 * k, cos(a))
			var s: float = [0.075, 0.06, 0.09][k]
			b.ball(c, Vector3.ONE * s, tones[k][0], tones[k][1], 12, 7)
			b.xf = Transform3D(Basis(Vector3(1, 0, 0), 0.4).rotated(Vector3.UP, a), c)
			b.emit = 0.5
			b.annulus(s * 1.35, s * 1.85, 24, Color(PEARL, 1.0), Color(LILAC, 1.0))
			b.emit = 0.0
			b.xf = Transform3D.IDENTITY
		return b.mesh())
