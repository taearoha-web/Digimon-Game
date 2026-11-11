extends RefCounted
## Summoner 50 stars: ราชาวานรวายุ (Wind Monkey King). A gale gathers round the
## Summoner and a golden cloud comes swooping down out of the sky with a jade wake; on
## the release the Wind Monkey King lands in a whirling column of wind, his golden staff
## slams down beside him and leaves and cloud burst out in a ring. His two skills get
## the same hand: the Monkey Storm (a whirlwind of jade gusts and leaves round him) and
## the Staff Quake (the giant staff comes down, the ground cracks gold, dust rolls out).
## The creature itself (Summon, a legend rig) is untouched. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "moonwolf_pact"
const JADE := Color("3fdc9a")
const JADE_HI := Color("b8ffd8")
const JADE_DK := Color("1d5a3e")
const GOLD := Color("ffcf4a")
const GOLD_DK := Color("c88a1e")
const CLOUD_TOP := Color("fff6d0")
const CLOUD_UNDER := Color("f0c060")
const RED := Color("c8322a")
const SAND := Color("e8c890")
const LOOK := {"rim_color": Color("fff8d8"), "rim": 0.6, "shadow_tint": Color(0.7, 0.62, 0.55)}
const CLOUD_LOOK := {"rim_color": Color("fffbe8"), "rim": 0.8, "shadow_tint": Color(0.92, 0.75, 0.55)}
const LEAVES := [Color("5ad88a"), Color("8af0a8"), Color("e8d050"), Color("3aa86a")]


## Where the king appears (Summon._formation for a single creature), from the summoner.
static func _arrival(skill: Dictionary) -> Vector3:
	var size := Summon.size_for_rank(maxi(1, Game.effective_rank(skill))) if Game.has_profile else 1.0
	return Vector3(0, 0, 2.6 + 1.2 * (size - 1.0))


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	# The wind-up root faces the cast; the king appears at a fixed world offset.
	var spot := art.to_local(caster.global_position + _arrival(skill)) * Vector3(1, 0, 1)
	# The gale gathers round the Summoner; the golden cloud swoops down onto the spot.
	var from := spot + Vector3(-5.5, 6.5, 2.5)
	K.put(art, K.SOLID, S.cloud("kintoun", CLOUD_TOP, CLOUD_UNDER, 12, 0.5, 4), "GaleCloud", from, Vector3(1.4, 0.9, 1.0), Vector3.ZERO, time, {"travel": spot + Vector3.UP * 0.5 - from, "fade_in": 0.12, "decay": 0.97, "initial": 0.6, "grow_time": 0.5, "front": true, "cull": 8.0}, CLOUD_LOOK)
	K.put(art, K.VEIL, S.tail("gale", Color(0.55, 1.0, 0.75, 0.75), Color(1.0, 0.9, 0.5, 0.4)), "GaleWake", from, Vector3(1.6, 4.0, 1.6), Vector3(0.3, 0, 0.7), time, {"travel": spot + Vector3.UP * 0.5 - from, "fade_in": 0.12, "decay": 0.95})
	K.put(art, K.VEIL, S.spiral("gale_call", Color(0.45, 0.95, 0.7, 0.75), Color(0.9, 1.0, 0.8, 0.0), 3, 1.4, 0.35), "GaleCall", Vector3.UP * 0.1, Vector3(1.6, 2.4, 1.6), Vector3.ZERO, time, {"initial": 0.5, "grow_time": 0.6, "fade_in": 0.2, "spin": 6.0, "decay": 0.85})
	K.put(art, K.VEIL, S.spiral("gale_ground", Color(0.4, 0.95, 0.65, 0.7), Color(0.9, 1.0, 0.8, 0.0), 4, 0.8, 0.5), "GaleGround", spot + Vector3.UP * 0.05, Vector3(2.2, 0.6, 2.2), Vector3.ZERO, time, {"initial": 1.6, "grow_time": 0.9, "fade_in": 0.3, "spin": -7.0, "decay": 0.9})
	if S.rich():
		K.put(art, K.SOLID, S.leaves("gale_call", LEAVES, 16, 2.5, 2.0), "GaleLeaves", Vector3.UP * 0.2, Vector3.ONE * 0.8, Vector3.ZERO, time, {"cull": 6.0, "decay": 0.85, "spin": 5.0}, LOOK.merged({"burst": 1.0, "gravity": -0.5, "drag": 2.5, "life": time + 0.2}))
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var king := S.newest_summon(parent, ID)
	var at := king.global_position if king else source + _arrival(skill)
	var land := S.root(parent, at, 1.7, "StarWindKing_" + ID, source)
	if land:
		if king:
			land.follow_ref = weakref(king)
		# He lands in a whirling column of wind; the staff slams down at his side.
		K.put(land, K.VEIL, S.spiral("gale_tornado", Color(0.3, 0.9, 0.62, 0.95), Color(0.85, 1.0, 0.8, 0.2), 5, 2.2, 0.75), "GaleTornado", Vector3.ZERO, Vector3(2.0, 5.4, 2.0), Vector3.ZERO, 0.95, {"initial": 0.4, "grow_time": 0.25, "fade_in": 0.02, "spin": 10.0, "decay": 0.45, "front": true})
		K.put(land, K.VEIL, K.column("gale_sheath", [Color(0.4, 0.95, 0.7, 0.45), Color(0.5, 1.0, 0.75, 0.3), Color(0.8, 1.0, 0.85, 0.12), Color(0.9, 1.0, 0.9, 0.0)], 0.7, 18), "GaleSheath", Vector3.ZERO, Vector3(1.8, 5.0, 1.8), Vector3.ZERO, 0.8, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.02, "spin": 6.0, "decay": 0.4}, {"noise_amt": 0.8, "noise_scale": Vector2(6.0, 1.5), "flow": Vector2(1.2, -2.0), "bias": 0.1, "taper": 0.5, "fres": 0.6})
		K.put(land, K.SOLID, staff_mesh(), "KingStaff", Vector3(1.4, -0.4, 0.2), Vector3.ONE, Vector3(0, 0, -0.12), 1.3, {"fade_in": 0.005, "decay": 0.72, "cull": 8.0}, LOOK.merged({"slide": Vector3(0, 9.0, 0), "slide_time": 0.14, "slide_ease": 2.0}))
		K.put(land, K.VEIL, K.shock(JADE, Color("fff2b0"), GOLD), "GaleShock", Vector3.UP * 0.1, Vector3.ONE * 3.8, Vector3.ZERO, 0.55, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.35}, {"opacity": 0.85})
		K.put(land, K.SOLID, S.leaves("gale_burst", LEAVES, 28, 7.0, 4.0), "GaleLeafBurst", Vector3.UP * 0.4, Vector3.ONE, Vector3.ZERO, 1.4, {"cull": 12.0, "decay": 0.85}, LOOK.merged({"burst": 1.0, "gravity": 3.0, "drag": 1.6, "life": 1.4}))
		K.put(land, K.SOLID, S.puffs("kintoun", CLOUD_TOP, CLOUD_UNDER, 10, 6.0), "GaleCloudBurst", Vector3.UP * 0.3, Vector3.ONE * 0.9, Vector3.ZERO, 0.9, {"cull": 12.0, "decay": 0.8}, CLOUD_LOOK.merged({"burst": 1.0, "gravity": -0.8, "drag": 2.6, "life": 0.9}))
		land._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var ring := S.root(parent, at, 1.4, "StarWindRing_" + ID, source)
	if ring:
		K.put(ring, K.VEIL, K.cracks("gale_staff", Color(0.25, 0.15, 0.05), GOLD, 8, 0.3), "GaleStaffCracks", Vector3(1.4, 0.05, 0.2), Vector3.ONE * 1.8, Vector3.ZERO, 1.4, {"initial": 0.5, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "delay": 0.12, "priority": -1})
		K.put(ring, K.VEIL, K.shock(JADE_HI, JADE, JADE_DK), "GaleWideRing", Vector3.UP * 0.12, Vector3.ONE * 5.5, Vector3.ZERO, 0.8, {"initial": 0.2, "grow_time": 0.9, "decay": 0.4, "delay": 0.1}, {"opacity": 0.6})
		K.put(ring, K.GLOW, K.sprite(), "GaleFlash", Vector3.UP * 0.15, Vector3.ONE * 3.0, Vector3(-PI / 2, 0, 0), 0.6, {"initial": 0.4, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.35}, {"radial": 1.4, "tint": Color("40e090"), "opacity": 0.5})
		K.put(ring, K.VEIL, S.sparkles("gale", [GOLD, JADE_HI, JADE], 18, 4.0, 2.5), "GaleSparkles", Vector3.UP * 0.5, Vector3.ONE, Vector3.ZERO, 1.2, {"cull": 8.0, "decay": 0.85}, {"burst": 1.0, "gravity": -0.6, "drag": 1.8, "life": 1.2})
		ring._draw()
	return true


# ---------------------------------------------------------------------------
# The king's two skills (LegendMoves): wind-up and landing
# ---------------------------------------------------------------------------
static func legend_windup(parent: Node3D, style: String, pos: Vector3, radius: float, seconds: float, caster: Node3D = null) -> void:
	var art := S.root(parent, pos, seconds + 0.05, "StarKingWindup_" + ID, pos)
	if not art:
		return
	if caster:
		art.follow_ref = weakref(caster)
	if style == "storm":
		# The wind is drawn in round him, leaves and all.
		K.put(art, K.VEIL, S.spiral("gale_draw", Color(0.45, 0.95, 0.7, 0.7), Color(0.9, 1.0, 0.85, 0.0), 4, 1.0, 0.5), "KingStormDraw", Vector3.UP * 0.1, Vector3(radius * 0.8, 2.2, radius * 0.8), Vector3.ZERO, seconds + 0.05, {"initial": 1.5, "grow_time": 1.0, "fade_in": 0.2, "spin": -6.0, "decay": 0.9})
		K.put(art, K.SOLID, S.leaves("gale_call", LEAVES, 16, 2.5, 2.0), "KingStormLeaves", Vector3.UP * 0.3, Vector3.ONE * 1.2, Vector3.ZERO, seconds + 0.05, {"cull": 8.0, "decay": 0.85, "spin": -5.0}, LOOK.merged({"burst": 1.0, "gravity": -0.5, "drag": 2.5, "life": seconds + 0.3}))
	else:
		# The staff swings up high over his head.
		K.put(art, K.SOLID, staff_mesh(), "KingStaffRaised", Vector3(0.6, 2.6, 0), Vector3.ONE * 0.9, Vector3(0, 0, -0.3), seconds + 0.05, {"fade_in": 0.1, "decay": 0.95, "cull": 8.0}, LOOK.merged({"slide": Vector3(0, -2.4, 0), "slide_time": seconds * 0.8, "slide_ease": -2.0}))
		K.put(art, K.VEIL, K.area_mark(GOLD, SAND), "KingQuakeMark", Vector3.UP * 0.07, Vector3.ONE * radius, Vector3.ZERO, seconds + 0.05, {"initial": 0.5, "grow_time": 0.6, "spin": 0.4, "decay": 0.95})
	art._draw()


static func legend_move(parent: Node3D, style: String, pos: Vector3, radius: float) -> bool:
	var art := S.root(parent, pos, 1.6, "StarKingMove_" + ID, pos)
	if not art:
		return false
	if style == "storm":
		# The Monkey Storm: a ring of whirlwind, gusts raking round, leaves flung out.
		K.put(art, K.VEIL, S.spiral("gale_storm", Color(0.4, 0.95, 0.68, 0.8), Color(0.92, 1.0, 0.85, 0.0), 5, 1.2, 0.85), "KingStorm", Vector3.ZERO, Vector3(radius * 0.85, 3.4, radius * 0.85), Vector3.ZERO, 0.9, {"initial": 0.4, "grow_time": 0.3, "fade_in": 0.02, "spin": 8.0, "decay": 0.45, "front": true})
		K.put(art, K.VEIL, S.rake("gale_gust", Color(0.85, 1.0, 0.9, 0.9), JADE, 3), "KingGusts", Vector3(0, 0.3, radius * 0.45), Vector3(1.6, 2.0, 1.6), Vector3(0, 0, 0.5), 0.6, {"orbit": 0.0, "spin": 9.0, "initial": 0.5, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.45})
		K.put(art, K.VEIL, K.shock(JADE, JADE_HI, JADE_DK), "KingStormRing", Vector3.UP * 0.1, Vector3.ONE * radius, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "decay": 0.35}, {"opacity": 0.8})
		K.put(art, K.SOLID, S.leaves("gale_burst", LEAVES, 28, 7.0, 4.0), "KingStormLeaves", Vector3.UP * 0.4, Vector3.ONE, Vector3.ZERO, 1.4, {"cull": 12.0, "decay": 0.85}, LOOK.merged({"burst": 1.0, "gravity": 3.0, "drag": 1.6, "life": 1.4}))
	else:
		# The Staff Quake: the giant staff comes down, the ground cracks gold and dust rolls out.
		K.put(art, K.SOLID, staff_mesh(), "KingQuakeStaff", Vector3(0, -0.6, 0.6), Vector3.ONE * 1.25, Vector3(0.15, 0, 0), 1.1, {"fade_in": 0.005, "decay": 0.7, "cull": 10.0}, LOOK.merged({"slide": Vector3(0, 9.0, 0), "slide_time": 0.1, "slide_ease": 2.0}))
		K.put(art, K.VEIL, K.cracks("king_quake", Color(0.25, 0.14, 0.05), GOLD, 12, 0.4), "KingQuakeCracks", Vector3.UP * 0.05, Vector3.ONE * radius * 0.85, Vector3.ZERO, 1.6, {"initial": 0.5, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "priority": -1})
		K.put(art, K.VEIL, K.shock(GOLD, Color("fff2b0"), SAND), "KingQuakeRing", Vector3.UP * 0.1, Vector3.ONE * radius, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "decay": 0.35}, {"opacity": 0.85})
		K.put(art, K.SOLID, S.cloud_ring("king_dust", Color("f4e2b8"), Color("c8a070"), 16, 0.22), "KingQuakeDust", Vector3.UP * 0.2, Vector3(radius * 0.6, 1.0, radius * 0.6), Vector3.ZERO, 1.0, {"initial": 0.4, "grow_time": 0.6, "fade_in": 0.02, "decay": 0.4, "cull": 6.0}, CLOUD_LOOK)
		K.put(art, K.SOLID, K.debris("king_rock", [Color("8a6a40"), Color("b08a50"), Color("6a5030")], 22, 0.3), "KingQuakeRocks", Vector3.UP * 0.2, Vector3.ONE, Vector3.ZERO, 1.1, {"cull": 10.0, "decay": 0.9}, LOOK.merged({"burst": 1.0, "gravity": 15.0, "drag": 1.0, "life": 1.0}))
	art._draw()
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
## The king's golden staff (about 6 m, +Y up from the foot): gold ends, a red shaft with gold bands.
static func staff_mesh() -> ArrayMesh:
	return K.cached("star_king_staff", func():
		var b := K.Builder.new()
		var hi := GOLD.lerp(Color.WHITE, 0.35)
		b.tube([Vector3(0, 0.0, 0), Vector3(0, 0.9, 0)], [0.17, 0.16], 10, [GOLD_DK, GOLD])
		b.tube([Vector3(0, 0.9, 0), Vector3(0, 5.1, 0)], [0.13, 0.13], 10, [RED.darkened(0.15), RED])
		b.tube([Vector3(0, 5.1, 0), Vector3(0, 6.0, 0)], [0.16, 0.17], 10, [GOLD, GOLD_DK])
		b.emit = 0.4
		for y in [0.9, 1.9, 3.0, 4.1, 5.1]:
			b.tube([Vector3(0, y - 0.07, 0), Vector3(0, y + 0.07, 0)], [0.175], 10, [hi])
		b.emit = 0.0
		return b.mesh())
