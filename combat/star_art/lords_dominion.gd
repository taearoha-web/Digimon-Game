extends RefCounted
## Dark Lord 150 stars: อาณาจักรแห่งลอร์ด. The Dark Lord claims the ground: an imperial
## seal of gold and violet spreads from his feet while dark mist curls at its rim and
## gold motes spiral into him, and a crown of gold forms high overhead. With the buff the
## crown settles over his head, six obsidian standards with violet banners burst up in a
## ring round the party and a ring of gold sweeps out to everyone it reaches. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const ID := "lords_dominion"
const GOLD := Color("f2c14a")
const GOLD_DK := Color("a8701c")
const GOLD_HI := Color("fff0b0")
const VIOLET := Color("5a2a9a")
const VIOLET_DK := Color("2a1050")
const OBSIDIAN := Color("1e1630")
const OBSIDIAN_HI := Color("4a3a70")
const RING := 3.8
const CROWN_AT := Vector3(0, 2.75, 0)
const LOOK := {"rim_color": Color("ffe9a8"), "rim": 0.6, "shadow_tint": Color(0.55, 0.45, 0.7)}


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	# The seal of the dominion spreads from his feet; gold motes spiral into him.
	K.put(art, K.VEIL, sigil_mesh(), "DominionSigil", Vector3.UP * 0.06, Vector3.ONE * 4.6, Vector3.ZERO, time + 0.05, {"initial": 0.1, "grow_time": 0.75, "fade_in": 0.1, "spin": 0.5, "decay": 0.95})
	K.put(art, K.SOLID, crown_mesh(), "DominionCrownForming", CROWN_AT + Vector3.UP * 2.2, Vector3.ONE * 0.62, Vector3.ZERO, time + 0.05, {"initial": 0.4, "grow_time": 0.6, "fade_in": 0.5, "spin": 1.2, "decay": 0.97, "travel": Vector3.DOWN * 0.9}, LOOK)
	K.put(art, K.VEIL, S.spiral("dominion_gold", Color(1.0, 0.82, 0.3, 0.8), Color(0.6, 0.3, 1.0, 0.0), 4, 1.2, 0.25), "DominionMotes", Vector3.UP * 0.1, Vector3(3.0, 2.6, 3.0), Vector3.ZERO, time, {"initial": 1.3, "grow_time": 1.0, "fade_in": 0.2, "spin": -3.0, "decay": 0.85})
	K.put(art, K.VEIL, K.column("dominion_mist", [Color(0.2, 0.08, 0.35, 0.0), Color(0.25, 0.1, 0.42, 0.55), Color(0.15, 0.06, 0.3, 0.25), Color(0.1, 0.04, 0.2, 0.0)], 1.15, 26), "DominionMist", Vector3.ZERO, Vector3(4.4, 1.6, 4.4), Vector3.ZERO, time + 0.05, {"initial": 0.5, "grow_time": 0.8, "fade_in": 0.3, "spin": 0.4, "decay": 0.9, "priority": -1}, {"noise_amt": 1.0, "noise_scale": Vector2(11.0, 1.0), "flow": Vector2(0.2, -0.6), "bias": -0.05, "taper": 0.7})
	if S.rich():
		K.put(art, K.GLOW, K.sprite(), "DominionGlow", CROWN_AT + Vector3.UP * 1.6, Vector3.ONE * 1.6, Vector3.ZERO, time, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.3, "decay": 0.9}, {"radial": 1.8, "billboard": true, "tint": Color("ffb030"), "opacity": 0.5})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var reach := clampf(float(skill.get("radius", 8.0)), 4.0, 9.0)
	# The crown settles over his head; the seal flares; a ring of gold sweeps out.
	K.put(art, K.SOLID, crown_mesh(), "DominionCrown", CROWN_AT, Vector3.ONE * 0.62, Vector3.ZERO, 2.2, {"fade_in": 0.005, "decay": 0.8, "spin": 0.7}, LOOK.merged({"slide": Vector3(0, 1.4, 0), "slide_time": 0.12, "slide_ease": 2.0}))
	K.put(art, K.VEIL, K.shock(GOLD, GOLD_HI, VIOLET), "DominionSweep", Vector3.UP * 0.1, Vector3.ONE * reach, Vector3.ZERO, 0.7, {"initial": 0.1, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.4}, {"opacity": 0.85})
	K.put(art, K.VEIL, sigil_mesh(), "DominionSeal", Vector3.UP * 0.06, Vector3.ONE * 4.6, Vector3.ZERO, 2.2, {"initial": 1.15, "grow_time": 0.15, "fade_in": 0.01, "spin": 0.5, "decay": 0.7})
	K.put(art, K.GLOW, K.column("dominion_pillar", [Color(1.0, 0.75, 0.25, 0.55), Color(0.85, 0.5, 0.2, 0.32), Color(0.55, 0.25, 0.9, 0.12), Color(0.5, 0.2, 0.9, 0.0)], 0.6, 16), "DominionPillar", Vector3.ZERO, Vector3(1.4, 6.0, 1.4), Vector3.ZERO, 0.6, {"initial": 0.5, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.35}, {"noise_amt": 0.6, "noise_scale": Vector2(8.0, 1.2), "flow": Vector2(0.0, -3.0), "bias": -0.2, "taper": 0.3, "fres": 0.8})
	K.put(art, K.VEIL, S.sparkles("dominion", [GOLD, GOLD_HI, Color("b070ff")], 26, 4.5, 3.0), "DominionSparks", Vector3.UP * 0.4, Vector3.ONE * 1.2, Vector3.ZERO, 1.5, {"cull": 10.0, "decay": 0.85}, {"burst": 1.0, "gravity": -1.0, "drag": 1.5, "life": 1.5})
	if GodSkillArt.extra_roots(1) < 1:
		return true
	# Six standards of the dominion burst up round the party.
	var court := S.root(parent, point, 2.4, "StarDominionCourt_" + ID, source)
	if court:
		S.face_away(court)
		K.put(court, K.SOLID, banners_mesh(), "DominionBanners", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 2.3, {"fade_in": 0.005, "decay": 0.78, "cull": 6.0}, LOOK.merged({"slide": Vector3(0, -4.2, 0), "slide_time": 0.22, "slide_ease": -2.4, "flap": 0.16, "flap_rate": 5.0}))
		K.put(court, K.VEIL, K.cracks("dominion_feet", Color(0.12, 0.05, 0.2), Color(1.0, 0.75, 0.25), 6, 0.0), "DominionBannerCracks", Vector3.UP * 0.05, Vector3.ONE * (RING + 0.9), Vector3(0, PI / 6, 0), 2.0, {"initial": 0.7, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.7, "priority": -1})
		K.put(court, K.VEIL, K.shock(VIOLET, GOLD, VIOLET_DK), "DominionRing", Vector3.UP * 0.12, Vector3.ONE * (RING + 0.3), Vector3.ZERO, 0.5, {"initial": 0.5, "grow_time": 0.6, "decay": 0.35}, {"opacity": 0.7})
		if S.rich():
			K.put(court, K.SOLID, K.debris("dominion_rubble", [OBSIDIAN, OBSIDIAN_HI, GOLD_DK], 24, 0.28), "DominionRubble", Vector3.UP * 0.2, Vector3(RING * 0.36, 0.7, RING * 0.36), Vector3.ZERO, 1.0, {"cull": 10.0, "decay": 0.9}, LOOK.merged({"burst": 1.0, "gravity": 16.0, "drag": 1.2, "life": 0.9}))
		court._draw()
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
## The seal of the dominion (radius 1): rings of gold, eight crown points, a violet field.
static func sigil_mesh() -> ArrayMesh:
	return K.cached("star_dominion_sigil", func():
		var b := K.Builder.new()
		b.annulus(0.0, 0.92, 40, Color(VIOLET_DK, 0.2), Color(VIOLET, 0.26))
		b.annulus(0.92, 0.97, 48, Color(GOLD, 0.95), Color(GOLD_HI, 0.95))
		b.annulus(0.97, 1.04, 48, Color(GOLD, 0.6), Color(GOLD, 0.0))
		b.annulus(0.56, 0.6, 40, Color(GOLD, 0.85), Color(GOLD_HI, 0.85))
		b.annulus(0.2, 0.23, 24, Color(GOLD, 0.8), Color(GOLD, 0.8))
		for i in 8:
			var a := TAU * i / 8.0
			var out := Vector3(sin(a), 0, cos(a))
			var side := Vector3(out.z, 0, -out.x)
			var up := Vector3.UP * 0.004
			# A crown point between the rings and a spoke to the hub.
			b.tri3(out * 0.6 - side * 0.09 + up, out * 0.6 + side * 0.09 + up, out * 0.88 + up, Color(GOLD, 0.9), Color(GOLD, 0.9), Color(GOLD_HI, 0.95))
			b.quad(out * 0.23 - side * 0.012 + up, out * 0.23 + side * 0.012 + up, out * 0.56 + side * 0.012 + up, out * 0.56 - side * 0.012 + up, Color(GOLD, 0.7))
			var b2 := TAU * (i + 0.5) / 8.0
			var o2 := Vector3(sin(b2), 0, cos(b2))
			b.xf = Transform3D(Basis.IDENTITY, o2 * 0.76 + up)
			b.annulus(0.0, 0.045, 8, Color(Color("d070ff"), 0.95), Color(Color("d070ff"), 0.6))
			b.xf = Transform3D.IDENTITY
		return b.mesh())


## The crown of the dominion (radius 1): a gold band, five tall points with violet stones.
static func crown_mesh() -> ArrayMesh:
	return K.cached("star_dominion_crown", func():
		var b := K.Builder.new()
		b.lathe([[0.92, 0.0, GOLD_DK], [1.0, 0.05, GOLD], [0.98, 0.42, GOLD], [0.93, 0.48, GOLD_HI], [0.88, 0.42, GOLD_DK], [0.88, 0.0, GOLD_DK]], 24)
		b.emit = 0.3
		b.lathe([[1.01, 0.16, Color("7a3cc0")], [1.03, 0.21, Color("a060ff")], [1.01, 0.26, Color("7a3cc0")]], 24)
		b.emit = 0.0
		for i in 5:
			var a := TAU * i / 5.0
			var out := Vector3(sin(a), 0, cos(a))
			b.tube([out * 0.95 + Vector3.UP * 0.4, out * 1.0 + Vector3.UP * 0.85, out * 1.04 + Vector3.UP * 1.25], [0.24, 0.14, 0.0], 4, [GOLD_DK, GOLD, GOLD_HI], out, true, true)
			b.emit = 0.9
			b.ball(out * 1.04 + Vector3.UP * 1.3, Vector3.ONE * 0.09, GOLD_HI, GOLD, 6, 4)
			b.gem(out * 1.02 + Vector3.UP * 0.21, Vector3(0.1, 0.14, 0.1), Color("c070ff"), Color("f0d0ff"))
			b.emit = 0.0
		return b.mesh())


## Six obsidian standards (in metres) in a ring of radius RING, banners of violet and
## gold facing out; the banner cloth is weighed for the flap.
static func banners_mesh() -> ArrayMesh:
	return K.cached("star_dominion_banners", func():
		var b := K.Builder.new()
		for i in 6:
			var a := TAU * (i + 0.5) / 6.0
			var out := Vector3(sin(a), 0, cos(a))
			var side := Vector3(out.z, 0, -out.x)
			var foot := out * RING
			var top := foot + Vector3.UP * 3.6
			b.tube([foot - Vector3.UP * 0.2, top], [0.08, 0.06], 6, [OBSIDIAN, OBSIDIAN_HI], Vector3.FORWARD)
			b.emit = 0.6
			b.cone(top, top + Vector3.UP * 0.55, 0.13, 4, GOLD, GOLD_HI, Vector3.FORWARD, true)
			b.emit = 0.0
			b.tube([top - Vector3.UP * 0.12 - side * 0.62, top - Vector3.UP * 0.12 + side * 0.62], [0.045], 5, [GOLD_DK], Vector3.UP)
			# The cloth: rows weighed more the lower they hang, swallow-tailed at the foot.
			var rows := 6
			var face := out * 0.06
			for r in rows:
				var y0 := 3.45 - r * 0.32
				var y1 := y0 - 0.32
				var w0 := float(r) / rows
				var w1 := float(r + 1) / rows
				var notch := 0.32 if r == rows - 1 else 0.0
				var tone0 := VIOLET.lerp(VIOLET_DK, w0 * 0.6)
				var tone1 := VIOLET.lerp(VIOLET_DK, w1 * 0.6)
				for half in [-1.0, 1.0]:
					var h: float = half
					var p0 := foot + face + Vector3.UP * y0
					var p1 := foot + face + side * 0.55 * h + Vector3.UP * y0
					var p2 := foot + face + side * 0.55 * h + Vector3.UP * y1
					var p3 := foot + face + Vector3.UP * (y1 + notch)
					b.weight = w0
					var i0 := b.pt(p0, out, tone0)
					var i1 := b.pt(p1, out, tone0)
					b.weight = w1
					var i2 := b.pt(p2, out, tone1)
					var i3 := b.pt(p3, out, tone1)
					b.tri(i0, i1, i2); b.tri(i0, i2, i3)
					# The gold hem down the side.
					b.weight = w0
					var e0 := b.pt(p1 + out * 0.005, out, GOLD)
					var e1 := b.pt(p1 - side * 0.08 * h + out * 0.005, out, GOLD)
					b.weight = w1
					var e2 := b.pt(p2 - side * 0.08 * h + out * 0.005, out, GOLD)
					var e3 := b.pt(p2 + out * 0.005, out, GOLD)
					b.tri(e0, e1, e2); b.tri(e0, e2, e3)
			# The crown emblem on the cloth.
			b.weight = 0.35
			b.emit = 0.5
			var c := foot + face * 1.6 + Vector3.UP * 2.55
			b.quad(c - side * 0.28 - Vector3.UP * 0.12, c + side * 0.28 - Vector3.UP * 0.12, c + side * 0.28, c - side * 0.28, GOLD)
			for k in 3:
				var x := (k - 1) * 0.25
				b.tri3(c + side * (x - 0.09), c + side * (x + 0.09), c + side * x + Vector3.UP * (0.3 if k == 1 else 0.22), GOLD, GOLD, GOLD_HI)
			b.emit = 0.0
			b.weight = 0.0
		return b.mesh())
