extends RefCounted
## Dark Lord 100 stars: ราชันอีกา. The sovereign raven, a giant bird of night with
## violet sheen and burning eyes, beats up over the Dark Lord's head before a pale violet
## moon while a feathered sigil marks the victim. Five shadow ravens peel off it and dive
## on the victim one after another (each contact: a claw rake, torn feathers, a ring);
## for the sixth the sovereign itself folds its wings and stoops, and the strike bursts
## in a storm of feathers with claw scars left on the ground. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "raven_sovereign"
const BEATS := [0.0, 0.14, 0.28, 0.42, 0.56, 0.94]
const HOVER := Vector3(0.0, 4.4, -0.2)
const BLACK := Color("150b26")
const SHEEN := Color("5a34a6")
const VIOLET := Color("8a4dff")
const LILAC := Color("e0ccff")
const EYE := Color("f6b8ff")
const LOOK := {"rim_color": Color("b48cff"), "rim": 0.75, "shadow_tint": Color(0.5, 0.42, 0.75)}


## Where the k-th shadow raven starts its dive, in the victim's root (+Z away from the caster).
static func _perch(k: int) -> Vector3:
	return [Vector3(-3.6, 4.6, -2.4), Vector3(3.8, 4.2, -1.6), Vector3(-2.6, 5.0, 1.8), Vector3(3.0, 4.8, 2.2), Vector3(-4.0, 3.8, 0.4)][k % 5]


static func _dive(art: StarSkillArt, from: Vector3, to: Vector3, seconds: float, size: float, delay := 0.0, label := "RavenDive") -> void:
	var dir := to - from
	var angles := Basis.looking_at(dir, Vector3.UP, true).get_euler()
	K.put(art, K.SOLID, raven_mesh(), label, from, Vector3.ONE * size, angles, seconds, {"travel": dir, "accelerate": true, "fade_in": 0.02, "decay": 0.97, "delay": delay, "front": true, "cull": 8.0}, LOOK.merged({"flap": 0.05, "flap_rate": 30.0}))


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	K.put(art, K.VEIL, S.spiral("raven_call", Color(0.35, 0.12, 0.7, 0.7), Color(0.75, 0.5, 1.0, 0.0), 2, 1.4, 0.35), "RavenCall", Vector3.UP * 0.1, Vector3(1.5, 2.6, 1.5), Vector3.ZERO, time, {"initial": 0.5, "grow_time": 0.6, "fade_in": 0.2, "spin": 4.0, "decay": 0.85})
	# The sovereign stays aloft over the Dark Lord until it stoops for the sixth contact.
	# (Its roots are not tied to the wind-up's skill generation: the sequence replays the
	# cast motion before every contact, and the court must outlive those.)
	var stay := time + float(BEATS[4])
	var court := S.root(parent, origin, stay, "StarRavenCourt_" + ID, origin)
	if court:
		S.face_target(court, point)
		# The first shadow raven peels off the sovereign and arrives with the release.
		_dive(court, HOVER + Vector3(1.2, 0.4, 0.2), court.to_local(Vector3(point.x, origin.y, point.z)) + Vector3.UP * 1.1, 0.2, 0.75, maxf(0.0, time - 0.2))
		K.put(court, K.SOLID, raven_mesh(), "RavenSovereign", HOVER, Vector3.ONE * 1.35, Vector3(-0.15, 0, 0), stay, {"fade_in": 0.12, "decay": 0.985, "cull": 8.0, "front": true}, LOOK.merged({"flap": 0.22, "flap_rate": 9.0, "slide": Vector3(0, -1.0, -0.4), "slide_time": time * 0.8, "slide_ease": -2.0}))
		K.put(court, K.VEIL, moon_mesh(), "RavenMoon", HOVER + Vector3(0, 1.3, 1.1), Vector3.ONE * 1.1, Vector3(-0.75, 0, 0), stay, {"initial": 0.3, "grow_time": 0.4, "fade_in": 0.25, "decay": 0.9, "priority": -2})
		K.put(court, K.GLOW, K.sprite(), "RavenHalo", HOVER + Vector3(0, 0.3, 1.2), Vector3.ONE * 3.2, Vector3.ZERO, stay, {"initial": 0.3, "grow_time": 0.5, "fade_in": 0.3, "decay": 0.9, "priority": -2}, {"radial": 1.8, "billboard": true, "tint": Color("7a3cff"), "opacity": 0.35})
		court._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var mark := S.root(parent, Vector3(point.x, 0, point.z), stay + 0.4, "StarRavenMark_" + ID, origin)
	if mark:
		K.put(mark, K.VEIL, K.area_mark(LILAC, VIOLET), "RavenSigil", Vector3.UP * 0.07, Vector3.ONE * 1.6, Vector3.ZERO, stay + 0.4, {"initial": 2.2, "grow_time": 0.25, "spin": 1.6, "decay": 0.9})
		K.put(mark, K.VEIL, S.wash("raven_shadow", Color(0.12, 0.04, 0.26, 0.5), Color(0.2, 0.06, 0.4, 0.35)), "RavenShadow", Vector3.UP * 0.04, Vector3.ONE * 1.8, Vector3.ZERO, stay + 0.4, {"initial": 0.3, "grow_time": 0.4, "fade_in": 0.2, "decay": 0.9, "priority": -2})
		mark._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var hit := Vector3.UP * 1.1
	var final := index >= 5
	var yaw := 0.6 * (1.0 if index % 2 == 0 else -1.0)
	if not final:
		# A shadow raven's strike: the claw rakes, feathers tear loose, a ring of violet.
		K.put(art, K.VEIL, S.rake("raven_claw", Color(1.0, 0.85, 1.0, 0.95), VIOLET), "RavenRake", hit + Vector3.UP * 0.2, Vector3(1.2, 1.6, 1.2), Vector3(0, yaw, yaw * 0.6), 0.32, {"initial": 0.6, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.4, "front": true})
		K.put(art, K.SOLID, S.feathers("raven", [BLACK, SHEEN, Color("2a1648")], 14, 3.5), "RavenFeathers", Vector3.ZERO, Vector3.ONE * 0.9, Vector3(0, index, 0), 0.9, {"cull": 6.0, "decay": 0.85}, LOOK.merged({"burst": 1.0, "gravity": 3.0, "drag": 2.5, "life": 0.9}))
		K.put(art, K.VEIL, K.shock(VIOLET, LILAC, Color("2a0f5a")), "RavenRing", Vector3.UP * 0.1, Vector3.ONE * (1.3 + 0.15 * index), Vector3.ZERO, 0.35, {"initial": 0.2, "grow_time": 0.9, "decay": 0.3}, {"opacity": 0.8})
		K.put(art, K.GLOW, K.sprite(), "RavenFlash", hit, Vector3.ONE * 1.2, Vector3.ZERO, 0.2, {"initial": 0.6, "grow_time": 0.4, "fade_in": 0.02, "decay": 0.3}, {"radial": 1.6, "billboard": true, "tint": Color("b070ff"), "opacity": 0.7})
		# The next diver is already on its way to the next contact.
		var gap := float(BEATS[index + 1]) - float(BEATS[index])
		if index < 4:
			_dive(art, _perch(index + 1), hit, gap, 0.75)
		else:
			# The sovereign itself stoops from over the Dark Lord onto the victim.
			var from := art.to_local(source + Vector3.UP * HOVER.y + (Vector3(point.x, 0, point.z) - Vector3(source.x, 0, source.z)).normalized() * HOVER.z)
			_dive(art, from, hit + Vector3.UP * 0.3, gap, 1.35, 0.0, "RavenSovereignStoop")
		return true
	# The sovereign's strike.
	K.put(art, K.SOLID, S.feathers("raven_storm", [BLACK, SHEEN, Color("2a1648"), BLACK], 34, 7.0), "RavenFeatherStorm", Vector3.ZERO, Vector3.ONE * 1.3, Vector3.ZERO, 1.6, {"cull": 12.0, "decay": 0.85}, LOOK.merged({"burst": 1.0, "gravity": 2.0, "drag": 1.6, "life": 1.6}))
	K.put(art, K.VEIL, S.rake("raven_claw_big", Color(1.0, 0.85, 1.0, 0.95), VIOLET, 4), "RavenRakeBig", hit + Vector3.UP * 0.3, Vector3(2.4, 2.8, 2.4), Vector3(0, 0.3, 0.5), 0.45, {"initial": 0.6, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.45, "front": true})
	K.put(art, K.VEIL, K.shock(VIOLET, LILAC, Color("2a0f5a")), "RavenShock", Vector3.UP * 0.1, Vector3.ONE * 3.6, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "decay": 0.35}, {"opacity": 0.85})
	K.put(art, K.VEIL, scar_mesh(), "RavenScars", Vector3.UP * 0.05, Vector3.ONE * 2.2, Vector3(0, 0.3, 0), 1.8, {"initial": 0.6, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "priority": -1})
	K.put(art, K.GLOW, K.sprite(), "RavenBurst", hit, Vector3.ONE * 3.2, Vector3.ZERO, 0.35, {"initial": 0.4, "grow_time": 0.4, "fade_in": 0.02, "decay": 0.3}, {"radial": 1.5, "billboard": true, "tint": Color("9a5cff"), "opacity": 0.75})
	if GodSkillArt.extra_roots(1) < 1:
		return true
	# The sovereign beats up and away over the victim, the night thinning behind it.
	var after := S.root(parent, point, 1.4, "StarRavenAfter_" + ID, source)
	if after:
		K.put(after, K.SOLID, raven_mesh(), "RavenSovereignRise", Vector3.UP * 1.6, Vector3.ONE * 1.35, Vector3(-0.6, 0, 0), 0.8, {"travel": Vector3(0, 4.5, 3.0), "fade_in": 0.01, "decay": 0.6, "front": true, "cull": 8.0}, LOOK.merged({"flap": 0.25, "flap_rate": 14.0}))
		K.put(after, K.VEIL, K.shock(Color("3a1a7a"), VIOLET, LILAC), "RavenAfterRing", Vector3.UP * 0.12, Vector3.ONE * 2.4, Vector3.ZERO, 0.8, {"initial": 0.2, "grow_time": 0.9, "decay": 0.4, "delay": 0.1}, {"opacity": 0.6})
		K.put(after, K.VEIL, S.sparkles("raven", [VIOLET, LILAC, Color("6a3aff")], 18, 3.0, 2.0), "RavenMotes", Vector3.UP * 0.6, Vector3.ONE, Vector3.ZERO, 1.3, {"cull": 8.0, "decay": 0.8}, {"burst": 1.0, "gravity": -1.2, "drag": 1.6, "life": 1.3})
		after._draw()
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
## One raven facing +Z, wings spread (about 2.8 m across at scale 1), the wing tips weighed for the flap.
static func raven_mesh() -> ArrayMesh:
	return K.cached("star_raven", func():
		var b := K.Builder.new()
		b.ball(Vector3(0, 0, -0.05), Vector3(0.26, 0.24, 0.62), BLACK.lerp(SHEEN, 0.3), BLACK, 9, 6)
		b.ball(Vector3(0, 0.14, 0.58), Vector3(0.22, 0.21, 0.24), BLACK.lerp(SHEEN, 0.25), BLACK, 8, 5)
		b.cone(Vector3(0, 0.12, 0.74), Vector3(0, 0.02, 1.12), 0.09, 5, Color("3a3046"), Color("8a80a0"))
		b.emit = 1.0
		for side in [-1.0, 1.0]:
			b.gem(Vector3(side * 0.13, 0.22, 0.72), Vector3(0.05, 0.05, 0.05), EYE, Color.WHITE)
		b.emit = 0.0
		# Tail fan.
		for k in 5:
			var a := lerpf(-0.45, 0.45, k / 4.0)
			var tip := Vector3(sin(a) * 0.55, 0.0, -0.55 - cos(a) * 0.6)
			b.tri3(Vector3(-0.1, 0.02, -0.5), Vector3(0.1, 0.02, -0.5), tip, BLACK, BLACK, SHEEN)
		# Wings: a broad inner panel and fingered primaries, heavier towards the tip.
		for side in [-1.0, 1.0]:
			var s: float = side
			var pts := [Vector3(s * 0.15, 0.06, 0.3), Vector3(s * 0.15, 0.06, -0.3), Vector3(s * 0.75, 0.16, 0.32), Vector3(s * 0.78, 0.12, -0.38), Vector3(s * 1.3, 0.14, 0.1)]
			var w := [0.0, 0.0, 0.5, 0.5, 1.0]
			var ix := []
			for k in pts.size():
				b.weight = float(w[k])
				ix.append(b.pt(pts[k], Vector3.UP, BLACK.lerp(SHEEN, float(w[k]) * 0.55)))
			b.tri(ix[0], ix[1], ix[3]); b.tri(ix[0], ix[3], ix[2]); b.tri(ix[2], ix[3], ix[4])
			for f in 5:
				var root := Vector3(s * lerpf(0.82, 1.28, f / 4.0), 0.13, lerpf(-0.36, 0.08, f / 4.0))
				var tip := root + Vector3(s * lerpf(0.55, 0.38, f / 4.0), 0.02, lerpf(-0.42, 0.18, f / 4.0))
				var side_v := Vector3(0, 0, 0.09)
				b.weight = 1.0
				var a0 := b.pt(root - side_v, Vector3.UP, BLACK.lerp(SHEEN, 0.5))
				var a1 := b.pt(root + side_v, Vector3.UP, BLACK.lerp(SHEEN, 0.5))
				b.weight = 1.5
				var a2 := b.pt(tip, Vector3.UP, SHEEN.lerp(VIOLET, 0.4))
				b.tri(a0, a1, a2)
		b.weight = 0.0
		return b.mesh())


## A pale violet moon, a crescent in the XZ plane (radius 1; turn it upright).
static func moon_mesh() -> ArrayMesh:
	return K.cached("star_raven_moon", func():
		var b := K.Builder.new()
		b.annulus(1.0, 1.3, 32, Color(0.6, 0.4, 1.0, 0.22), Color(0.5, 0.3, 1.0, 0.0))
		K.crescent(b, 0.98, 0.42, -2.2, 0.9, Color(0.95, 0.88, 1.0, 0.9), Color(0.75, 0.6, 1.0, 0.8), 18, 0.01)
		return b.mesh())


## Four claw scars torn into the ground (radius 1): dark gouges with a violet heart.
static func scar_mesh() -> ArrayMesh:
	return K.cached("star_raven_scars", func():
		var b := K.Builder.new()
		for k in 4:
			var x := (float(k) - 1.5) * 0.32
			var bow := 0.1 * (1.0 - absf(float(k) - 1.5) / 1.5)
			var prev := Vector3(x, 0, -0.95)
			for i in range(1, 9):
				var f := float(i) / 8.0
				var here := Vector3(x + sin(f * PI) * bow, 0, lerpf(-0.95, 0.95, f))
				var w0 := 0.08 * sin(PI * (f - 0.125)) + 0.01
				var w1 := 0.08 * sin(PI * f) + 0.01
				var side := Vector3(1, 0, 0)
				b.quad(prev - side * w0, prev + side * w0, here + side * w1, here - side * w1, Color(0.08, 0.02, 0.16, 0.92))
				b.quad(prev - side * w0 * 0.4 + Vector3.UP * 0.006, prev + side * w0 * 0.4 + Vector3.UP * 0.006, here + side * w1 * 0.4 + Vector3.UP * 0.006, here - side * w1 * 0.4 + Vector3.UP * 0.006, Color(0.8, 0.5, 1.0, 0.95))
				prev = here
		return b.mesh())
