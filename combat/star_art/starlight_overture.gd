extends RefCounted
## Bard 50 stars: โหมโรงแสงดาว. The Bard lifts a hand and a constellation draws itself
## in gold over the target, its stars joined by lines of light, a ring of staff light on
## the ground below. On each of the three beats one of its stars falls as a shining
## star-note with a comet's tail and bursts where it lands: a twinkle, a ring of rose and
## gold, sparkles and notes thrown up; the third lands in the middle, brightest, and
## leaves the constellation printed on the ground. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "starlight_overture"
const BEATS := [0.0, 0.30, 0.60]
const SKY := 4.6
const GOLD := Color("ffc24a")
const GOLD_HI := Color("fff0b0")
const ROSE := Color("ff7ab8")
const LILAC := Color("b48cff")
const PLUM := Color("7a4a8a")
const NOTE_LOOK := {"rim_color": Color("fff6d0"), "rim": 0.6, "shadow_tint": Color(0.9, 0.7, 0.75)}
static var _launched := 0


static func _r(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 6.5)), 3.0, 8.0)


## Where the k-th star lands, in a root on the target facing away from the caster.
static func _spot(k: int, r: float) -> Vector3:
	return [Vector3(-0.42, 0, 0.16), Vector3(0.4, 0, -0.14), Vector3(0.0, 0, 0.04)][k % 3] * r


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	_launched = 0
	var r := _r(skill)
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	# The Bard: a twinkle at the raised hand, notes spiralling up round it.
	K.put(art, K.GLOW, S.twinkle("overture_hand", Color(1.0, 0.8, 0.4, 0.9), GOLD_HI), "OvertureHand", Vector3(0.3, 2.0, 0.3), Vector3.ONE * 0.7, Vector3.ZERO, time, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.9, "spin": 0.0}, {"billboard": true})
	K.put(art, K.VEIL, S.spiral("overture_rise", Color(1.0, 0.75, 0.35, 0.75), Color(1.0, 0.5, 0.8, 0.0), 3, 1.2, 0.3), "OvertureRise", Vector3.UP * 0.1, Vector3(1.3, 2.4, 1.3), Vector3.ZERO, time, {"initial": 0.5, "grow_time": 0.6, "fade_in": 0.2, "spin": 4.0, "decay": 0.85})
	# The constellation over the target holds until its last star has fallen.
	var stay := time + float(BEATS[2]) + 0.28
	var sky := S.root(parent, Vector3(point.x, 0, point.z), stay + 0.25, "StarOvertureSky_" + ID, origin)
	if sky:
		K.put(sky, K.VEIL, S.constellation("overture", Color(1.0, 0.78, 0.3, 1.0), Color(1.0, 0.6, 0.7, 0.9), 9, 7), "OvertureConstellation", Vector3.UP * SKY, Vector3.ONE * r * 0.62, Vector3(-0.35, 0, 0), stay + 0.25, {"initial": 0.3, "grow_time": time / stay * 0.8, "fade_in": time / stay * 0.6, "spin": 0.25, "decay": 0.9})
		K.put(sky, K.GLOW, K.sprite(), "OvertureSkyGlow", Vector3.UP * SKY, Vector3.ONE * r * 0.6, Vector3.ZERO, stay + 0.25, {"initial": 0.3, "grow_time": 0.4, "fade_in": 0.3, "decay": 0.85, "priority": -2}, {"radial": 1.8, "billboard": true, "tint": Color("ff9ad2"), "opacity": 0.28})
		K.put(sky, K.VEIL, staff_ring(), "OvertureStaff", Vector3.UP * 0.06, Vector3.ONE * r * 0.86, Vector3.ZERO, stay + 0.25, {"initial": 0.5, "grow_time": 0.35, "fade_in": 0.2, "spin": -0.4, "decay": 0.9, "priority": -1})
		sky._draw()
	return true


## A star-note falls from the constellation onto its spot, arriving with the contact.
static func launch(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, flight: float) -> bool:
	var k := _launched
	_launched += 1
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	var r := _r(skill)
	var ground := Vector3(point.x, 0, point.z)
	var drop := S.root(parent, ground, flight + 0.05, "StarOvertureFall_" + ID, origin)
	if not drop:
		return true
	var spot := _spot(k, r)
	var high := spot + Vector3.UP * SKY
	var fall := Vector3.DOWN * (SKY - 0.7)
	var big := 1.0 + 0.4 * float(k == 2)
	K.put(drop, K.SOLID, S.note("overture_gold", GOLD), "OvertureNote", high, Vector3.ONE * 1.1 * big, Vector3(-0.5, 0, -0.3), flight, {"travel": fall, "accelerate": true, "fade_in": 0.05, "decay": 0.98, "front": true}, NOTE_LOOK)
	K.put(drop, K.GLOW, S.tail("overture", Color(1.0, 0.8, 0.45, 0.9), Color(1.0, 0.45, 0.75, 0.6)), "OvertureTail", high + Vector3.UP * 0.3, Vector3(0.9, 2.8, 0.9) * big, Vector3.ZERO, flight, {"travel": fall, "accelerate": true, "fade_in": 0.05, "decay": 0.98})
	K.put(drop, K.GLOW, S.twinkle("overture_head", Color(1.0, 0.75, 0.4, 0.9), GOLD_HI), "OvertureHead", high + Vector3.UP * 0.4, Vector3.ONE * 0.8 * big, Vector3.ZERO, flight, {"travel": fall, "accelerate": true, "fade_in": 0.05, "decay": 0.98}, {"billboard": true})
	drop._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := _r(skill)
	var spot := _spot(index, r)
	var final := index >= 2
	var s := 1.45 if final else 1.0
	K.put(art, K.GLOW, S.twinkle("overture_burst", Color(1.0, 0.72, 0.38, 0.95), Color(1.0, 0.55, 0.8)), "OvertureBurst", spot + Vector3.UP * 1.0, Vector3.ONE * 2.2 * s, Vector3.ZERO, 0.4, {"initial": 0.3, "grow_time": 0.35, "fade_in": 0.01, "decay": 0.4, "front": true}, {"billboard": true})
	K.put(art, K.VEIL, K.shock(ROSE, GOLD_HI, GOLD), "OvertureRing", spot + Vector3.UP * 0.1, Vector3.ONE * 2.8 * s, Vector3.ZERO, 0.5, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.35}, {"opacity": 0.85})
	K.put(art, K.VEIL, S.sparkles("overture", [GOLD, ROSE, GOLD_HI, LILAC], 22, 4.0, 2.6), "OvertureSparkles", spot + Vector3.UP * 0.3, Vector3.ONE * s, Vector3.ZERO, 1.1, {"cull": 8.0, "decay": 0.85}, {"burst": 1.0, "gravity": 2.5, "drag": 1.8, "life": 1.1})
	K.put(art, K.SOLID, S.note_spray("overture", [GOLD, ROSE, Color("ffd27a"), LILAC], 10, 5.0, 3.0), "OvertureNotes", spot, Vector3.ONE * 0.9 * s, Vector3(0, index * 1.3, 0), 1.0, {"cull": 8.0, "decay": 0.8}, NOTE_LOOK.merged({"burst": 1.0, "gravity": 7.0, "drag": 1.2, "life": 1.0}))
	K.put(art, K.GLOW, K.sprite(), "OvertureGlow", spot + Vector3.UP * 0.12, Vector3.ONE * 2.0 * s, Vector3(-PI / 2, 0, 0), 0.6, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.3}, {"radial": 1.5, "tint": Color("ffb050"), "opacity": 0.55})
	if final:
		K.put(art, K.VEIL, S.constellation("overture_ground", Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.6, 0.75, 0.9), 9, 7), "OverturePrint", Vector3.UP * 0.08, Vector3.ONE * r * 0.62, Vector3.ZERO, 1.6, {"initial": 0.7, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.6, "spin": 0.25})
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
## Five thin staff lines of light round the area (radius 1), notes of gold set on them.
static func staff_ring() -> ArrayMesh:
	return K.cached("star_overture_staff", func():
		var b := K.Builder.new()
		for line in 5:
			var r := 0.86 + 0.032 * line
			b.annulus(r - 0.005, r + 0.005, 56, Color(1.0, 0.85, 0.55, 0.7), Color(1.0, 0.7, 0.8, 0.7))
		b.emit = 0.7
		for i in 10:
			var a := TAU * i / 10.0 + 0.2
			var on := 0.86 + 0.032 * float([0, 3, 1, 4, 2][i % 5])
			b.xf = Transform3D(Basis(Vector3.UP, a).rotated(Vector3.UP, 0.0) * Basis(Vector3(1, 0, 0), -PI / 2).scaled(Vector3.ONE * 0.12), Vector3(sin(a), 0.004, cos(a)) * on)
			DS_note(b, [GOLD, ROSE, LILAC][i % 3])
		b.xf = Transform3D.IDENTITY
		return b.mesh())


static func DS_note(b: K.Builder, tone: Color) -> void:
	S.DS._note(b, Color(tone, 0.95))
