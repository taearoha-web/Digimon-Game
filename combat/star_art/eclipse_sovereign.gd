extends RefCounted
## Summoner 200 stars: โพไซดอนจ้าวสมุทร (Poseidon, Lord of Tides). The tide rises to the
## Summoner's call: a whirlpool opens where the sea king will stand, spouts of water climb
## round it and his golden trident hangs glinting in the sky. On the release Poseidon
## bursts up inside a towering waterspout, the trident plunges down into the ground at
## his side and a tidal ring floods outward with spray. His two skills are drawn by the
## same hand (the Maelstrom: a whirlpool with a twisting column of water; the Glacial
## Bloom: a crown of ice crystals erupting from frost), and his farewell is a great ring
## wave. The creature itself (Summon, a legend rig) is untouched. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "eclipse_sovereign"
const SEA := Color("2fa8ff")
const SEA_HI := Color("8ae0ff")
const DEEP := Color("0b2a6e")
const FOAM := Color("b8eaff")
const GOLD := Color("ffc83a")
const GOLD_DK := Color("a8701c")
const ICE := Color("bff4ff")
const ICE_DK := Color("5ab4e8")
const LOOK := {"rim_color": Color("e8fcff"), "rim": 0.6, "shadow_tint": Color(0.55, 0.6, 0.8)}
const ICE_LOOK := {"rim_color": Color("ffffff"), "rim": 0.9, "shadow_tint": Color(0.6, 0.78, 0.95)}
const TRIDENT_SKY := 4.6


## Where Poseidon appears (Summon._formation for a single creature), from the summoner.
static func _arrival(skill: Dictionary) -> Vector3:
	var size := Summon.size_for_rank(maxi(1, Game.effective_rank(skill))) if Game.has_profile else 1.0
	return Vector3(0, 0, 2.6 + 1.2 * (size - 1.0))


static func _trident() -> ArrayMesh:
	return S.trident("poseidon", GOLD, GOLD_DK, SEA)


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	var spot := _arrival(skill)
	# The Summoner: a ring of tide at the feet, drops lifting off it.
	K.put(art, K.VEIL, K.shock(SEA, FOAM, DEEP), "TideCallRing", Vector3.UP * 0.08, Vector3.ONE * 2.0, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.5, "spin": 1.4, "decay": 0.9}, {"opacity": 0.8})
	K.put(art, K.VEIL, S.spiral("tide_call", Color(0.45, 0.8, 1.0, 0.8), Color(0.9, 1.0, 1.0, 0.0), 3, 1.4, 0.35), "TideCall", Vector3.UP * 0.1, Vector3(1.4, 2.6, 1.4), Vector3.ZERO, time, {"initial": 0.5, "grow_time": 0.6, "fade_in": 0.2, "spin": 5.0, "decay": 0.85})
	var sea := S.root(parent, origin + spot, time + 0.1, "StarTideRise_" + ID, origin, art)
	if sea:
		# The whirlpool opens, spouts climb round it, the trident hangs in the sky.
		K.put(sea, K.VEIL, S.whirlpool("poseidon", DEEP, SEA, FOAM), "TideWhirlpool", Vector3.UP * 0.05, Vector3.ONE * 3.0, Vector3.ZERO, time + 0.1, {"initial": 0.1, "grow_time": 0.8, "fade_in": 0.1, "spin": -4.0, "decay": 0.95})
		K.put(sea, K.SOLID, _trident(), "TideTridentHigh", Vector3.UP * TRIDENT_SKY, Vector3.ONE * 0.9, Vector3(0, 0, 0.15), time + 0.1, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.3, "spin": 2.2, "decay": 0.95, "cull": 6.0}, LOOK)
		K.put(sea, K.GLOW, K.sprite(), "TideTridentGlint", Vector3.UP * (TRIDENT_SKY - 1.6), Vector3.ONE * 2.4, Vector3.ZERO, time + 0.1, {"initial": 0.2, "grow_time": 0.7, "fade_in": 0.4, "decay": 0.9, "priority": -2}, {"radial": 1.8, "billboard": true, "tint": Color("40b8ff"), "opacity": 0.4})
		K.put(sea, K.VEIL, spouts_mesh(), "TideSpouts", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, time + 0.1, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.2, "spin": 1.2, "decay": 0.92}, S.WATER_LOOK.merged({"flow": Vector2(0.3, -2.4)}, true))
		if S.rich():
			K.put(sea, K.VEIL, S.wave("poseidon_ring", DEEP, SEA, FOAM, 0.0, true), "TideRingRise", Vector3.ZERO, Vector3(2.4, 0.8, 2.4), Vector3.ZERO, time + 0.1, {"initial": 1.3, "grow_time": 1.0, "fade_in": 0.3, "decay": 0.92}, S.WATER_LOOK.merged({"opacity": 0.6}, true))
		sea._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	if index >= 2:
		return _farewell(art, point)
	var king := S.newest_summon(parent, ID)
	var at := king.global_position if king else source + _arrival(skill)
	var rise := S.root(parent, at, 1.9, "StarTideKing_" + ID, source)
	if rise:
		if king:
			rise.follow_ref = weakref(king)
		# He bursts up inside a towering waterspout; the trident plunges in at his side.
		K.put(rise, K.VEIL, S.spout("poseidon", SEA, FOAM), "TideSpout", Vector3.ZERO, Vector3(1.9, 6.5, 1.9), Vector3.ZERO, 0.75, {"initial": 0.4, "grow_time": 0.18, "fade_in": 0.02, "spin": 3.0, "decay": 0.35}, S.WATER_LOOK.merged({"flow": Vector2(0.3, -4.0), "opacity": 0.5, "fres": 1.2}, true))
		K.put(rise, K.SOLID, _trident(), "TideTrident", Vector3(1.6, -0.9, 0.3), Vector3.ONE * 0.95, Vector3(0, 0.4, -0.08), 1.8, {"fade_in": 0.005, "decay": 0.75, "cull": 10.0}, LOOK.merged({"slide": Vector3(0, TRIDENT_SKY + 1.0, 0), "slide_time": 0.16, "slide_ease": 2.2}))
		K.put(rise, K.VEIL, S.spray("poseidon", [SEA_HI, FOAM, SEA, ICE], 40, 11.0, 5.5), "TideSpray", Vector3.UP * 0.4, Vector3.ONE * 1.2, Vector3.ZERO, 1.4, {"cull": 14.0, "decay": 0.8}, {"burst": 1.0, "gravity": 14.0, "drag": 1.0, "life": 1.4, "opacity": 0.9})
		K.put(rise, K.VEIL, K.cracks("poseidon_trident", Color(0.05, 0.15, 0.35), SEA_HI, 9, 0.25), "TideTridentCracks", Vector3(1.6, 0.05, 0.3), Vector3.ONE * 2.0, Vector3.ZERO, 1.7, {"initial": 0.5, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "delay": 0.16, "priority": -1})
		K.put(rise, K.VEIL, S.whirlpool("poseidon", DEEP, SEA, FOAM), "TideEddy", Vector3.UP * 0.05, Vector3.ONE * 2.6, Vector3.ZERO, 1.8, {"initial": 1.1, "grow_time": 0.2, "fade_in": 0.01, "spin": -3.0, "decay": 0.55, "priority": -1})
		rise._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	# The tide floods outward in a ring wave.
	var flood := S.root(parent, at, 1.6, "StarTideFlood_" + ID, source)
	if flood:
		K.put(flood, K.VEIL, S.wave("poseidon_ring", DEEP, SEA, FOAM, 0.0, true), "TideFlood", Vector3.ZERO, Vector3(6.0, 1.2, 6.0), Vector3.ZERO, 0.9, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.5}, S.WATER_LOOK.merged({"opacity": 0.75}, true))
		K.put(flood, K.VEIL, K.shock(SEA, FOAM, DEEP), "TideShock", Vector3.UP * 0.1, Vector3.ONE * 6.5, Vector3.ZERO, 0.75, {"initial": 0.1, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.4, "delay": 0.05}, {"opacity": 0.8})
		K.put(flood, K.GLOW, K.sprite(), "TideShimmer", Vector3.UP * 0.15, Vector3.ONE * 4.5, Vector3(-PI / 2, 0, 0), 0.8, {"initial": 0.4, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.35}, {"radial": 1.4, "tint": Color("2090ff"), "opacity": 0.45})
		flood._draw()
	return true


## Poseidon's farewell: a great ring wave rolls out from him before he leaves.
static func _farewell(art: StarSkillArt, point: Vector3) -> bool:
	K.put(art, K.VEIL, S.wave("poseidon_ring", DEEP, SEA, FOAM, 0.0, true), "TideFarewell", Vector3.ZERO, Vector3(7.5, 2.2, 7.5), Vector3.ZERO, 1.1, {"initial": 0.12, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.55}, S.WATER_LOOK)
	K.put(art, K.VEIL, S.spout("poseidon", SEA, FOAM), "TideFarewellSpout", Vector3.ZERO, Vector3(1.6, 5.0, 1.6), Vector3.ZERO, 0.8, {"initial": 0.4, "grow_time": 0.2, "fade_in": 0.02, "spin": 3.0, "decay": 0.45}, S.WATER_LOOK.merged({"flow": Vector2(0.3, -4.0)}, true))
	K.put(art, K.VEIL, K.shock(SEA, FOAM, DEEP), "TideFarewellShock", Vector3.UP * 0.1, Vector3.ONE * 7.8, Vector3.ZERO, 0.8, {"initial": 0.1, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.4}, {"opacity": 0.8})
	K.put(art, K.VEIL, S.spray("poseidon", [SEA_HI, FOAM, SEA, ICE], 40, 11.0, 5.5), "TideFarewellSpray", Vector3.UP * 0.4, Vector3.ONE * 1.5, Vector3.ZERO, 1.4, {"cull": 14.0, "decay": 0.8}, {"burst": 1.0, "gravity": 14.0, "drag": 1.0, "life": 1.4, "opacity": 0.9})
	return true


# ---------------------------------------------------------------------------
# Poseidon's two skills (LegendMoves): wind-up and landing
# ---------------------------------------------------------------------------
static func legend_windup(parent: Node3D, style: String, pos: Vector3, radius: float, seconds: float, caster: Node3D = null) -> void:
	var art := S.root(parent, pos, seconds + 0.05, "StarTideWindup_" + ID, pos)
	if not art:
		return
	if style == "whirl":
		K.put(art, K.VEIL, S.whirlpool("poseidon", DEEP, SEA, FOAM), "TideMaelstromOpen", Vector3.UP * 0.05, Vector3.ONE * radius * 0.9, Vector3.ZERO, seconds + 0.05, {"initial": 0.1, "grow_time": 0.9, "fade_in": 0.1, "spin": -5.0, "decay": 0.95})
	else:
		K.put(art, K.VEIL, frost_mesh(), "TideFrostCreep", Vector3.UP * 0.05, Vector3.ONE * radius, Vector3.ZERO, seconds + 0.05, {"initial": 0.1, "grow_time": 0.9, "fade_in": 0.1, "spin": 0.3, "decay": 0.95})
	art._draw()


static func legend_move(parent: Node3D, style: String, pos: Vector3, radius: float) -> bool:
	var art := S.root(parent, pos, 1.8, "StarTideMove_" + ID, pos)
	if not art:
		return false
	if style == "whirl":
		# The Maelstrom: the whirlpool turns hard and a twisting column of water rises out of it.
		K.put(art, K.VEIL, S.spiral("tide_column", Color(0.3, 0.7, 1.0, 0.85), Color(0.9, 1.0, 1.0, 0.0), 4, 2.4, 0.5), "TideMaelstromColumn", Vector3.ZERO, Vector3(radius * 0.55, 5.0, radius * 0.55), Vector3.ZERO, 1.0, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.02, "spin": -9.0, "decay": 0.5, "front": true})
		K.put(art, K.VEIL, S.whirlpool("poseidon", DEEP, SEA, FOAM), "TideMaelstrom", Vector3.UP * 0.05, Vector3.ONE * radius * 0.95, Vector3.ZERO, 1.6, {"initial": 0.9, "grow_time": 0.2, "fade_in": 0.01, "spin": -7.0, "decay": 0.55, "priority": -1})
		K.put(art, K.VEIL, K.shock(SEA, FOAM, DEEP), "TideMaelstromRing", Vector3.UP * 0.1, Vector3.ONE * radius, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "decay": 0.35}, {"opacity": 0.85})
		K.put(art, K.VEIL, S.spray("poseidon", [SEA_HI, FOAM, SEA, ICE], 40, 11.0, 5.5), "TideMaelstromSpray", Vector3.UP * 0.4, Vector3.ONE * 0.9, Vector3.ZERO, 1.3, {"cull": 12.0, "decay": 0.8}, {"burst": 1.0, "gravity": 14.0, "drag": 1.0, "life": 1.3, "opacity": 0.9})
	else:
		# The Glacial Bloom: a crown of ice crystals bursts up out of the frost.
		K.put(art, K.SOLID, crystals_mesh(), "TideCrystals", Vector3.ZERO, Vector3.ONE * radius / 5.0, Vector3.ZERO, 1.7, {"fade_in": 0.005, "decay": 0.7, "cull": 8.0}, ICE_LOOK.merged({"slide": Vector3(0, -3.2, 0), "slide_time": 0.16, "slide_ease": -2.4}))
		K.put(art, K.VEIL, frost_mesh(), "TideFrost", Vector3.UP * 0.05, Vector3.ONE * radius * 1.05, Vector3.ZERO, 1.8, {"initial": 0.9, "grow_time": 0.15, "fade_in": 0.01, "decay": 0.65, "priority": -1})
		K.put(art, K.VEIL, K.shock(ICE_DK, Color.WHITE.lerp(ICE, 0.4), ICE), "TideFrostRing", Vector3.UP * 0.1, Vector3.ONE * radius, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "decay": 0.35}, {"opacity": 0.85})
		K.put(art, K.SOLID, K.debris("tide_ice", [ICE, ICE_DK, Color("e8fbff")], 24, 0.3), "TideIceShards", Vector3.UP * 0.4, Vector3.ONE, Vector3.ZERO, 1.2, {"cull": 10.0, "decay": 0.9}, ICE_LOOK.merged({"burst": 1.0, "gravity": 14.0, "drag": 1.2, "life": 1.1}))
		K.put(art, K.VEIL, K.column("tide_cold", [Color(0.8, 0.95, 1.0, 0.0), Color(0.8, 0.95, 1.0, 0.4), Color(0.7, 0.9, 1.0, 0.18), Color(0.7, 0.9, 1.0, 0.0)], 1.2, 20), "TideColdMist", Vector3.ZERO, Vector3(radius * 0.8, 2.2, radius * 0.8), Vector3.ZERO, 1.5, {"initial": 0.7, "grow_time": 0.5, "fade_in": 0.1, "travel": Vector3.UP * 0.5, "decay": 0.5, "delay": 0.15, "priority": -1}, {"noise_amt": 1.0, "noise_scale": Vector2(9.0, 1.2), "flow": Vector2(0.15, -0.6), "bias": -0.1, "taper": 0.6})
	art._draw()
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
## Six spouts of water climbing round the whirlpool (in metres, radius about 2.4).
static func spouts_mesh() -> ArrayMesh:
	return K.cached("star_poseidon_spouts", func():
		var b := K.Builder.new()
		for i in 6:
			var a := TAU * i / 6.0
			var c := Vector3(sin(a), 0, cos(a)) * 2.5
			var h := 2.4 + 0.9 * float(i % 2)
			b.xf = Transform3D(Basis.IDENTITY.scaled(Vector3(0.38, h, 0.38)), c)
			b.lathe([[1.3, 0.0, Color(FOAM, 0.0)], [1.0, 0.06, Color(FOAM, 0.9)], [0.8, 0.3, Color(SEA.lerp(FOAM, 0.3), 0.8)], [0.6, 0.7, Color(SEA, 0.65)], [0.8, 1.0, Color(FOAM, 0.0)]], 10)
			b.xf = Transform3D.IDENTITY
		return b.mesh())


## A crown of ice crystals (in metres at radius 5): a great spire in the middle and a ring of shards leaning out.
static func crystals_mesh() -> ArrayMesh:
	return K.cached("star_poseidon_crystals", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		b.emit = 0.25
		b.cone(Vector3(0, -0.2, 0), Vector3(0.1, 3.4, 0.05), 0.75, 6, ICE_DK, Color.WHITE.lerp(ICE, 0.5), Vector3.FORWARD, true)
		for i in 11:
			var a := TAU * i / 11.0 + rng.randf_range(-0.15, 0.15)
			var out := Vector3(sin(a), 0, cos(a))
			var d := rng.randf_range(1.6, 4.2)
			var tall := rng.randf_range(1.2, 2.6) * (1.2 - d / 6.0)
			b.cone(out * d - Vector3.UP * 0.2, out * (d + tall * 0.35) + Vector3.UP * tall, rng.randf_range(0.28, 0.5), 5, ICE_DK, Color.WHITE.lerp(ICE, 0.4), Vector3.FORWARD, true)
		b.emit = 0.0
		return b.mesh())


## Frost spreading on the ground (radius 1): a pale wash and branching rime lines.
static func frost_mesh() -> ArrayMesh:
	return K.cached("star_poseidon_frost", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 8
		b.annulus(0.0, 0.85, 32, Color(0.8, 0.95, 1.0, 0.4), Color(0.7, 0.9, 1.0, 0.3))
		b.annulus(0.85, 1.05, 32, Color(0.7, 0.9, 1.0, 0.3), Color(0.7, 0.9, 1.0, 0.0))
		for i in 10:
			var a := TAU * i / 10.0 + rng.randf_range(-0.2, 0.2)
			var here := Vector3.ZERO
			var width := 0.035
			for k in 5:
				var next := here + Vector3(sin(a), 0, cos(a)) * 0.2
				var side := Vector3(cos(a), 0, -sin(a))
				var up := Vector3.UP * 0.005
				b.quad(here - side * width + up, here + side * width + up, next + side * width * 0.7 + up, next - side * width * 0.7 + up, Color(1.0, 1.0, 1.0, 0.9))
				var twig := a + (0.6 if k % 2 == 0 else -0.6)
				var tip := next + Vector3(sin(twig), 0, cos(twig)) * 0.1
				b.tri3(next - side * width * 0.5 + up, next + side * width * 0.5 + up, tip + up, Color(1.0, 1.0, 1.0, 0.85))
				here = next
				width *= 0.75
				a += rng.randf_range(-0.2, 0.2)
		return b.mesh())
