extends RefCounted
## Bard 100 stars: โซนาตาสลายใจ. A glossy rose heart swells over the victim, beating
## faster through the wind-up, a ring of rose light under it. The Bard strums six notes
## that arc through the air one after another (each lobbed on its own curve); every note
## that lands pops a little heart and a ring, and the heart above throbs; the sixth breaks
## it: the two halves fly apart, shards of rose glass rain down and a jagged crack splits
## the ground ring (the armour breaks). Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "heartbreak_sonata"
const BEATS := [0.0, 0.14, 0.28, 0.42, 0.56, 0.94]
const HEART_AT := Vector3(0, 3.3, 0)
const ROSE := Color("ff5aa0")
const ROSE_HI := Color("ffb8d8")
const ROSE_DK := Color("b8205e")
const WINE := Color("5a0a30")
const GOLD := Color("ffd27a")
const LOOK := {"rim_color": Color("ffe0f0"), "rim": 0.7, "shadow_tint": Color(0.82, 0.55, 0.7)}
## The arc of a lobbed note: it rises this high (m) over its flight.
const ARC := 1.4
static var _launched := 0
static var _victim: WeakRef


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	_launched = 0
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	K.put(art, K.VEIL, S.spiral("sonata_strum", Color(1.0, 0.45, 0.7, 0.75), Color(1.0, 0.8, 0.5, 0.0), 2, 1.3, 0.35), "SonataStrum", Vector3.UP * 0.1, Vector3(1.3, 2.4, 1.3), Vector3.ZERO, time, {"initial": 0.5, "grow_time": 0.6, "fade_in": 0.2, "spin": 5.0, "decay": 0.85})
	K.put(art, K.GLOW, S.twinkle("sonata_hand", Color(1.0, 0.5, 0.75, 0.9), ROSE_HI), "SonataHand", Vector3(0.3, 1.4, 0.45), Vector3.ONE * 0.6, Vector3.ZERO, time, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.9}, {"billboard": true})
	# The heart over the victim beats until the sixth note breaks it. (Not tied to the
	# wind-up's skill generation: the sequence replays the strum before every note.)
	var stay := time + float(BEATS[5]) + 0.28
	var heart := S.root(parent, Vector3(point.x, 0, point.z), stay, "StarSonataHeart_" + ID, origin)
	if heart:
		var hero := caster as Hero
		if hero and hero._valid_target(hero.target):
			heart.follow_ref = weakref(hero.target)
			heart.follow_offset = Vector3.ZERO
		K.put(heart, K.SOLID, heart_mesh(), "SonataHeart", HEART_AT, Vector3.ONE * 1.5, Vector3(-0.3, 0, 0), stay, {"initial": 0.2, "grow_time": time / stay * 0.9, "fade_in": 0.1, "decay": 0.99, "pulse": true, "front": true}, LOOK.merged({"flap": 0.0}))
		K.put(heart, K.GLOW, K.sprite(), "SonataHeartGlow", HEART_AT, Vector3.ONE * 3.0, Vector3.ZERO, stay, {"initial": 0.2, "grow_time": 0.4, "fade_in": 0.3, "decay": 0.95, "priority": -2}, {"radial": 1.7, "billboard": true, "tint": Color("ff4a9a"), "opacity": 0.4})
		K.put(heart, K.VEIL, K.area_mark(ROSE_HI, ROSE), "SonataMark", Vector3.UP * 0.07, Vector3.ONE * 1.7, Vector3.ZERO, stay, {"initial": 1.8, "grow_time": 0.2, "spin": -1.2, "decay": 0.95})
		heart._draw()
	return true


## A note lobbed on its own curve from the Bard's hands onto the victim.
static func launch(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, flight: float) -> bool:
	var k := _launched
	_launched += 1
	var from := art.global_position
	StarSkillArt._face(art, from, point)
	var reach := Vector2(point.x - from.x, point.z - from.z).length()
	var drop := point.y - from.y
	var roll: float = [0.0, 0.7, -0.7, 0.4, -0.4, 0.0][k % 6]
	var final := k >= 5
	var tone: Color = ROSE if k % 2 == 0 else Color("ff8ac0")
	# The burst shader throws the note: forward over [param reach] in [param flight] s,
	# rising ARC and coming down onto the victim's height.
	var lob := lob_mesh(flight)
	var size := Vector3(1.0, 1.0, reach)
	K.put(art, K.SOLID, lob, "SonataNote", Vector3.UP * drop, size, Vector3(0, 0, roll), flight, {"fade_in": 0.05, "decay": 0.99, "front": true, "cull": reach + 4.0}, LOOK.merged({"burst": 1.0, "gravity": 8.0 * ARC / (flight * flight), "drag": 0.0001, "life": 99.0, "slide": Vector3(0, -drop, 0), "slide_time": flight, "slide_ease": -1.0}))
	K.put(art, K.GLOW, S.twinkle("sonata_spark", Color(1.0, 0.45, 0.75, 0.9), ROSE_HI), "SonataSpark", Vector3.ZERO, Vector3.ONE * (0.45 if not final else 0.8), Vector3.ZERO, flight, {"travel": art.to_local(point), "fade_in": 0.05, "decay": 0.98}, {"billboard": true})
	if final:
		K.put(art, K.SOLID, S.note("sonata_final", ROSE_DK), "SonataFinalNote", Vector3.UP * 0.3, Vector3.ONE * 1.4, Vector3.ZERO, flight, {"travel": art.to_local(point) - Vector3.UP * 0.3, "accelerate": true, "fade_in": 0.05, "decay": 0.98, "front": true}, LOOK)
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var hit := Vector3.UP * 1.2
	if index < 5:
		# The note lands: a little heart pops, a ring of rose spreads, the big heart throbs.
		K.put(art, K.SOLID, heart_mesh(), "SonataPop", hit, Vector3.ONE * 0.45, Vector3(-0.3, 0, 0), 0.45, {"initial": 0.4, "grow_time": 0.3, "travel": Vector3.UP * 1.0, "fade_in": 0.02, "decay": 0.5, "front": true}, LOOK)
		K.put(art, K.GLOW, S.twinkle("sonata_pop", Color(1.0, 0.4, 0.7, 0.9), ROSE_HI), "SonataPopFlash", hit, Vector3.ONE * (0.9 + 0.12 * index), Vector3.ZERO, 0.25, {"initial": 0.4, "grow_time": 0.4, "fade_in": 0.02, "decay": 0.35}, {"billboard": true})
		K.put(art, K.VEIL, K.shock(ROSE, ROSE_HI, ROSE_DK), "SonataRing", Vector3.UP * 0.1, Vector3.ONE * (1.2 + 0.18 * index), Vector3.ZERO, 0.35, {"initial": 0.2, "grow_time": 0.9, "decay": 0.3}, {"opacity": 0.8})
		K.put(art, K.VEIL, S.sparkles("sonata_small", [ROSE, ROSE_HI, GOLD], 10, 3.0, 1.8), "SonataSparks", hit - Vector3.UP * 0.6, Vector3.ONE * 0.6, Vector3.ZERO, 0.6, {"cull": 6.0, "decay": 0.8}, {"burst": 1.0, "gravity": 4.0, "drag": 2.0, "life": 0.6})
		return true
	# The heartbreak: the heart splits and its halves fly apart, rose glass rains, the ground cracks.
	K.put(art, K.SOLID, halves_mesh(), "SonataHalves", HEART_AT, Vector3.ONE * 1.5, Vector3(-0.3, 0, 0), 1.1, {"fade_in": 0.005, "decay": 0.7, "front": true, "cull": 8.0}, LOOK.merged({"burst": 1.0, "gravity": 7.0, "drag": 1.0, "life": 1.1}))
	K.put(art, K.SOLID, K.debris("sonata_glass", [ROSE, ROSE_HI, ROSE_DK, Color("ff8ac0")], 26, 0.32), "SonataShards", HEART_AT - Vector3.UP * 0.6, Vector3.ONE * 0.75, Vector3.ZERO, 1.3, {"cull": 12.0, "decay": 0.9}, LOOK.merged({"burst": 1.0, "gravity": 13.0, "drag": 1.2, "life": 1.2}))
	K.put(art, K.GLOW, S.twinkle("sonata_break", Color(1.0, 0.35, 0.65, 0.95), ROSE_HI), "SonataBreakFlash", HEART_AT, Vector3.ONE * 3.0, Vector3.ZERO, 0.35, {"initial": 0.3, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.35, "front": true}, {"billboard": true})
	K.put(art, K.VEIL, K.shock(ROSE, ROSE_HI, WINE), "SonataShock", Vector3.UP * 0.1, Vector3.ONE * 3.6, Vector3.ZERO, 0.6, {"initial": 0.12, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.4}, {"opacity": 0.85})
	K.put(art, K.VEIL, crack_mesh(), "SonataCrack", Vector3.UP * 0.05, Vector3.ONE * 2.4, Vector3.ZERO, 1.7, {"initial": 0.5, "grow_time": 0.08, "fade_in": 0.01, "decay": 0.65, "priority": -1})
	K.put(art, K.VEIL, S.sparkles("sonata_big", [ROSE, ROSE_HI, GOLD, Color("ff8ac0")], 24, 4.5, 3.0), "SonataStorm", hit, Vector3.ONE, Vector3.ZERO, 1.3, {"cull": 10.0, "decay": 0.85}, {"burst": 1.0, "gravity": 2.0, "drag": 1.6, "life": 1.3})
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
## The heart's outline (the classic curve), about 1 m across, centred.
static func _outline(steps := 28) -> Array:
	var pts := []
	for j in steps:
		var t := TAU * j / float(steps)
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x, y + 2.0) / 32.0)
	return pts


## One puffy heart (or one half of it: side -1 left, +1 right, 0 whole) in the XY plane.
static func _heart(b: K.Builder, side: float) -> void:
	var outline := _outline()
	var depth := 0.16
	var front := []
	var back := []
	var hub := Vector3(0.0, 0.05, 0)
	for p in outline:
		var q: Vector2 = p
		if side != 0.0:
			# A jagged break line down the middle.
			var jag := 0.03 * sin(q.y * 40.0)
			if side < 0.0: q.x = minf(q.x, jag)
			else: q.x = maxf(q.x, jag)
		front.append(Vector3(q.x, q.y, -depth * 0.3))
		back.append(Vector3(q.x, q.y, depth * 0.3))
	var lit := ROSE.lerp(ROSE_HI, 0.35)
	var n := outline.size()
	var f := b.pt(hub + Vector3(0.12 * side - 0.1 * float(side == 0.0), 0.12, -depth), Vector3.BACK * -1.0, ROSE_HI)
	for j in n:
		var a := b.pt(front[j], Vector3(0, 0, -1), lit)
		var c := b.pt(front[(j + 1) % n], Vector3(0, 0, -1), lit)
		b.tri(f, c, a)
	var g := b.pt(hub + Vector3(0, 0, depth), Vector3.BACK, ROSE_DK)
	for j in n:
		var a := b.pt(back[j], Vector3.BACK, ROSE_DK)
		var c := b.pt(back[(j + 1) % n], Vector3.BACK, ROSE_DK)
		b.tri(g, a, c)
	for j in n:
		var p0: Vector3 = front[j]
		var p1: Vector3 = front[(j + 1) % n]
		var q1: Vector3 = back[(j + 1) % n]
		var q0: Vector3 = back[j]
		b.quad(p0, p1, q1, q0, ROSE, ROSE_DK)
	b.emit = 0.8
	b.ball(Vector3(-0.17 + 0.05 * absf(side), 0.2, -depth * 1.05), Vector3(0.07, 0.05, 0.02), Color.WHITE.lerp(ROSE_HI, 0.3), ROSE_HI, 6, 3)
	b.emit = 0.0


static func heart_mesh() -> ArrayMesh:
	return K.cached("star_sonata_heart", func():
		var b := K.Builder.new()
		_heart(b, 0.0)
		return b.mesh())


## The broken heart: its two halves, thrown apart (burst).
static func halves_mesh() -> ArrayMesh:
	return K.cached("star_sonata_halves", func():
		var b := K.Builder.new()
		for side in [-1.0, 1.0]:
			b.piece(Vector3(side * 0.05, 0, 0), Vector3(side * 3.2, 2.5, 0.6), 0.0, side * -2.6)
			_heart(b, side)
		return b.mesh())


## A jagged crack of rose light split across the ground (radius 1).
static func crack_mesh() -> ArrayMesh:
	return K.cached("star_sonata_crack", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		b.annulus(0.0, 0.45, 20, Color(0.35, 0.02, 0.18, 0.5), Color(0.5, 0.05, 0.25, 0.0))
		for arm in 2:
			var dir := Vector3(0, 0, 1) if arm == 0 else Vector3(0, 0, -1)
			var here := Vector3.ZERO
			var width := 0.07
			for k in 6:
				var next := here + (dir + Vector3(rng.randf_range(-0.6, 0.6), 0, 0)).normalized() * 0.18
				var side := (next - here).cross(Vector3.UP).normalized()
				var thin := width * 0.82
				var up := Vector3.UP * 0.004
				b.quad(here - side * width + up, here + side * width + up, next + side * thin + up, next - side * thin + up, Color(0.25, 0.0, 0.12, 0.95))
				b.quad(here - side * width * 0.4 + up * 2.0, here + side * width * 0.4 + up * 2.0, next + side * thin * 0.4 + up * 2.0, next - side * thin * 0.4 + up * 2.0, Color(1.0, 0.55, 0.8, 1.0))
				here = next
				width = thin
		return b.mesh())


## A note thrown by the burst shader (gravity set by the layer) from the origin to (0, 0, 1)
## in [param flight] s, rising and falling on the way; the layer's Z scale is the reach.
static func lob_mesh(flight: float) -> ArrayMesh:
	var t := snappedf(flight, 0.01)
	return K.cached("star_sonata_lob_%d" % int(t * 100.0), func():
		var b := K.Builder.new()
		var g := 8.0 * ARC / (t * t)
		b.emit = 0.7
		b.piece(Vector3.ZERO, Vector3(0, g * t * 0.5, 1.0 / t), 0.0, 0.0, Basis.IDENTITY.scaled(Vector3.ONE * 1.35))
		S.DS._note(b, ROSE)
		return b.mesh())
