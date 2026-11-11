extends RefCounted
## Summoner 150 stars: ราชสำนักภูต. The Summoner convenes the court of spirits: a seal
## of leaf-green and gold opens round the feet, eight paper lanterns float up out of it
## and bob in a ring, spirit wisps circle, and a jade spirit gate rises behind. With the
## buff the lanterns flare, the wisps spiral in round the Summoner in a column of green
## light, petals and leaves burst out and a ring sweeps over the party. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const ID := "spirit_court"
const LIME := Color("9be03a")
const LIME_HI := Color("e6ffb0")
const JADE := Color("2fae78")
const JADE_DK := Color("1e5a44")
const GOLD := Color("ffd25a")
const PAPER := Color("fff2c8")
const PAPER_DK := Color("f0b860")
const RING := 3.1
const GATE := Vector3(0, 0, 2.9)
const LOOK := {"rim_color": Color("f6ffd8"), "rim": 0.6, "shadow_tint": Color(0.62, 0.72, 0.62)}
const PETALS := [Color("ffd0e8"), Color("c8f080"), Color("ffe080"), Color("9be03a")]


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	var stay := time + 2.0
	var court := S.root(parent, origin, stay, "StarSpiritCourt_" + ID, origin)
	if court:
		S.face_away(court)
		K.put(court, K.VEIL, seal_mesh(), "CourtSeal", Vector3.UP * 0.06, Vector3.ONE * (RING + 0.9), Vector3.ZERO, stay, {"initial": 0.15, "grow_time": time / stay * 0.8, "fade_in": 0.05, "spin": 0.3, "decay": 0.85})
		K.put(court, K.SOLID, lanterns_mesh(), "CourtLanterns", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, stay, {"fade_in": time / stay * 0.5, "decay": 0.8, "spin": 0.35, "cull": 4.0, "travel": Vector3.UP * 0.6}, LOOK.merged({"slide": Vector3(0, -1.6, 0), "slide_time": time * 0.9, "slide_ease": -2.0, "flap": 0.18, "flap_rate": 3.0}))
		K.put(court, K.SOLID, gate_mesh(), "CourtGate", GATE, Vector3.ONE, Vector3.ZERO, stay - time * 0.4, {"fade_in": 0.08, "decay": 0.82, "delay": time * 0.4, "cull": 4.0}, LOOK.merged({"slide": Vector3(0, -4.4, 0), "slide_time": time * 0.7, "slide_ease": -2.4}))
		K.put(court, K.VEIL, S.spiral("court_wisps", Color(0.75, 1.0, 0.55, 0.7), Color(1.0, 1.0, 0.85, 0.0), 3, 0.6, 1.0), "CourtWisps", Vector3.UP * 0.8, Vector3(RING * 0.9, 1.6, RING * 0.9), Vector3.ZERO, time + 0.4, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.3, "spin": 2.4, "decay": 0.8})
		if S.rich():
			K.put(court, K.GLOW, K.sprite(), "CourtGateGlow", GATE + Vector3.UP * 2.0, Vector3.ONE * 3.4, Vector3.ZERO, stay - time * 0.4, {"fade_in": 0.2, "decay": 0.8, "delay": time * 0.5, "priority": -2}, {"radial": 1.8, "billboard": true, "tint": Color("8ae05a"), "opacity": 0.32})
		court._draw()
	K.put(art, K.VEIL, S.spiral("court_rise", Color(0.7, 1.0, 0.45, 0.75), Color(1.0, 0.95, 0.6, 0.0), 3, 1.3, 0.3), "CourtRise", Vector3.UP * 0.1, Vector3(1.4, 2.4, 1.4), Vector3.ZERO, time, {"initial": 0.5, "grow_time": 0.6, "fade_in": 0.2, "spin": 4.0, "decay": 0.85})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var reach := clampf(float(skill.get("radius", 8.0)), 4.0, 9.0)
	# The court is convened: the wisps spiral in round the Summoner in a column of green light.
	K.put(art, K.VEIL, S.spiral("court_gather", Color(0.75, 1.0, 0.5, 0.85), Color(1.0, 1.0, 0.8, 0.0), 4, 1.8, 0.35), "CourtGather", Vector3.ZERO, Vector3(RING * 0.8, 4.2, RING * 0.8), Vector3.ZERO, 0.9, {"initial": 1.2, "grow_time": 0.6, "fade_in": 0.02, "spin": -6.0, "decay": 0.5, "front": true})
	K.put(art, K.GLOW, K.column("court_pillar", [Color(0.7, 1.0, 0.4, 0.5), Color(0.5, 0.9, 0.5, 0.3), Color(1.0, 0.95, 0.6, 0.12), Color(1.0, 0.95, 0.6, 0.0)], 0.7, 16), "CourtPillar", Vector3.ZERO, Vector3(1.3, 5.5, 1.3), Vector3.ZERO, 0.7, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.35}, {"noise_amt": 0.5, "noise_scale": Vector2(8.0, 1.2), "flow": Vector2(0.0, -3.0), "bias": -0.2, "taper": 0.3, "fres": 0.8})
	K.put(art, K.VEIL, K.shock(LIME, LIME_HI, JADE), "CourtSweep", Vector3.UP * 0.1, Vector3.ONE * reach, Vector3.ZERO, 0.75, {"initial": 0.12, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.45}, {"opacity": 0.7})
	K.put(art, K.SOLID, S.leaves("court_petals", PETALS, 30, 6.0, 5.0), "CourtPetals", Vector3.UP * 0.5, Vector3.ONE, Vector3.ZERO, 1.6, {"cull": 12.0, "decay": 0.85}, LOOK.merged({"burst": 1.0, "gravity": 2.0, "drag": 1.6, "life": 1.6}))
	K.put(art, K.GLOW, flares_mesh(), "CourtLanternFlare", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.8, {"initial": 0.6, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.4, "spin": 0.35, "travel": Vector3.UP * 0.4}, {"radial": 1.6, "opacity": 0.8})
	K.put(art, K.VEIL, S.sparkles("court", [LIME_HI, GOLD, LIME], 20, 4.5, 2.5), "CourtMotes", Vector3.UP * 0.6, Vector3.ONE, Vector3.ZERO, 1.4, {"cull": 8.0, "decay": 0.85}, {"burst": 1.0, "gravity": -1.0, "drag": 1.8, "life": 1.4})
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
static func _lantern_at(i: int) -> Vector3:
	var a := TAU * (i + 0.5) / 8.0
	return Vector3(sin(a) * RING, 1.7 + 0.35 * float(i % 3), cos(a) * RING)


## Eight paper lanterns in a ring of radius RING (in metres), each bobbing on its own beat.
static func lanterns_mesh() -> ArrayMesh:
	return K.cached("star_court_lanterns", func():
		var b := K.Builder.new()
		for i in 8:
			var c := _lantern_at(i)
			b.weight = 1.0
			b.phase = float(i) / 8.0
			b.emit = 0.65
			b.ball(c, Vector3(0.32, 0.4, 0.32), PAPER, PAPER_DK, 10, 6)
			b.emit = 0.0
			b.tube([c + Vector3.UP * 0.36, c + Vector3.UP * 0.46], [0.18], 8, [JADE_DK])
			b.tube([c - Vector3.UP * 0.46, c - Vector3.UP * 0.36], [0.16], 8, [JADE_DK])
			b.emit = 0.3
			b.cone(c - Vector3.UP * 0.46, c - Vector3.UP * 0.85, 0.06, 4, Color("e04040"), GOLD)
			b.emit = 0.0
		b.weight = 0.0
		b.phase = -1.0
		return b.mesh())


## A soft glow at each lantern (crossed quads, the shader's radial falloff).
static func flares_mesh() -> ArrayMesh:
	return K.cached("star_court_flares", func():
		var b := K.Builder.new()
		for i in 8:
			var c := _lantern_at(i)
			var s := 0.9
			for plane in 2:
				var u := Vector3.RIGHT if plane == 0 else Vector3.BACK
				b.quad(c - u * s - Vector3.UP * s, c + u * s - Vector3.UP * s, c + u * s + Vector3.UP * s, c - u * s + Vector3.UP * s, Color(1.0, 0.92, 0.55, 0.9))
		return b.mesh())


## The court's seal (radius 1): rings of leaf-green and gold, twelve leaves round the
## rim and a ring of small circles where the lanterns rise.
static func seal_mesh() -> ArrayMesh:
	return K.cached("star_court_seal", func():
		var b := K.Builder.new()
		b.annulus(0.0, 0.94, 40, Color(JADE_DK, 0.18), Color(JADE, 0.24))
		b.annulus(0.94, 0.98, 48, Color(LIME, 0.95), Color(LIME_HI, 0.95))
		b.annulus(0.98, 1.06, 48, Color(LIME, 0.5), Color(LIME, 0.0))
		b.annulus(0.42, 0.45, 36, Color(GOLD, 0.85), Color(GOLD, 0.85))
		for i in 12:
			var a := TAU * i / 12.0
			var out := Vector3(sin(a), 0.004, cos(a))
			var side := Vector3(out.z, 0, -out.x)
			b.fan([out * 0.72, out * 0.56, out * 0.68 + side * 0.06, out * 0.9, out * 0.68 - side * 0.06, out * 0.56], Color(LIME_HI, 0.85), Color(LIME, 0.7))
		for i in 8:
			var a := TAU * (i + 0.5) / 8.0
			b.xf = Transform3D(Basis.IDENTITY, Vector3(sin(a), 0.006, cos(a)) * (RING / (RING + 0.9)))
			b.annulus(0.07, 0.1, 14, Color(GOLD, 0.95), Color(GOLD, 0.95))
			b.xf = Transform3D.IDENTITY
		return b.mesh())


## The jade spirit gate (in metres, facing -Z): two pillars, a sweeping top beam, a gold plaque.
static func gate_mesh() -> ArrayMesh:
	return K.cached("star_court_gate", func():
		var b := K.Builder.new()
		var pillar := JADE
		var hi := Color("6ae0a8")
		for x in [-1.7, 1.7]:
			b.tube([Vector3(x, -0.1, 0), Vector3(x * 0.95, 3.6, 0)], [0.17, 0.14], 8, [pillar, hi])
			b.tube([Vector3(x, 0.0, 0), Vector3(x, 0.35, 0)], [0.24], 8, [JADE_DK])
		b.box(Vector3(0, 3.0, 0), Vector3(3.9, 0.22, 0.24), JADE_DK, pillar)
		# The top beam sweeps up at both ends.
		var top := []
		for k in 13:
			var f := float(k) / 12.0
			var x := lerpf(-2.6, 2.6, f)
			top.append(Vector3(x, 3.75 + 0.35 * pow(absf(f - 0.5) * 2.0, 2.2), 0))
		b.tube(top, [Vector2(0.14, 0.18)], 6, [[hi, pillar]], Vector3.UP)
		b.box(Vector3(0, 3.42, 0), Vector3(0.6, 0.55, 0.1), JADE_DK)
		b.emit = 0.6
		b.box(Vector3(0, 3.42, -0.06), Vector3(0.46, 0.42, 0.04), GOLD)
		b.emit = 0.0
		return b.mesh())
