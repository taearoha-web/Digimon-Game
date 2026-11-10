extends RefCounted
## Dark Lord god skill: บัลลังก์จักรพรรดิอเวจี. The ground splits into an abyss licked by
## violet fire; a jagged obsidian throne rises out of it with the shadow emperor seated
## and his ravens circling. The waves are black lightning, pillars of dark flame and
## chains whipped out of the pit; for the finale a crown of black iron slams down and
## the abyss erupts through it while the ravens scatter. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const ID := "abyssal_throne"
## The field camera looks down from behind the caster, so the throne stands just
## behind the centre and is no taller than that view shows.
const THRONE := Vector3(0, 0, 2.1)
const THRONE_SIZE := 0.62
const CROWN := Vector3(0, 0.1, -2.4)
const RAVENS := Vector3(0, 4.0, -1.6)
const PIT := 5.6
const OBS := Color("2a1a44")
const OBS_DK := Color("140b24")
const OBS_HI := Color("5a3a96")
const SHADOW := Color("0d0716")
const SICK := Color("cdbb4e")
const SICK_DK := Color("7d6b20")
const MAGENTA := Color("ff3ad0")
const VIOLET := Color("9a30ff")
const IRON := Color("241a32")
const STONE_LOOK := {"rim_color": Color("c060ff"), "rim": 0.7, "shadow_tint": Color(0.42, 0.34, 0.62)}
const FIRE_LOOK := {"noise_amt": 1.0, "noise_scale": Vector2(5.0, 1.5), "flow": Vector2(0.0, -3.0), "bias": 0.12, "taper": 0.95, "sway": 0.5, "edge_heat": 0.9, "hot": Color(1.0, 0.45, 0.92)}


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := clampf(float(skill.get("radius", 9.0)), 4.0, 10.0)
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	# The Dark Lord: a ring of dark fire at the feet, ravens wheeling round the shoulders.
	K.put(art, K.VEIL, K.shock(VIOLET, MAGENTA, Color("1a0630")), "ThroneCallRing", Vector3.UP * 0.08, Vector3.ONE * 1.9, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.5, "spin": -1.2, "decay": 0.9}, {"opacity": 0.85})
	K.put(art, K.SOLID, raven_mesh(), "ThroneCallRavens", Vector3.UP * 2.3, Vector3.ONE * 1.5, Vector3.ZERO, time, {"initial": 0.4, "grow_time": 0.4, "spin": 2.6, "fade_in": 0.1}, STONE_LOOK.merged({"flap": 0.09, "flap_rate": 14.0}))
	var ground := K.root(parent, Vector3(point.x, 0, point.z), time, "StarGodGround_" + ID, origin, art)
	if ground:
		# The throne rises out of the opening pit.
		K.put(ground, K.SOLID, throne_mesh(), "GodThrone", THRONE, Vector3.ONE * THRONE_SIZE, Vector3.ZERO, time, {"fade_in": 0.03, "decay": 1.0, "cull": 16.0}, STONE_LOOK.merged({"slide": Vector3(0, -13.8, 0), "slide_time": time * 0.86, "slide_ease": -2.4}))
		K.put(ground, K.VEIL, abyss_mesh(), "ThroneAbyss", Vector3.UP * 0.05, Vector3.ONE * PIT, Vector3.ZERO, time, {"initial": 0.08, "grow_time": 0.4, "fade_in": 0.05, "decay": 1.0, "priority": -2})
		K.put(ground, K.VEIL, pit_fire(), "ThroneFire", Vector3.UP * 0.05, Vector3.ONE, Vector3.ZERO, time, {"initial": 0.2, "grow_time": 0.5, "fade_in": 0.2, "decay": 1.0, "delay": time * 0.12}, FIRE_LOOK)
		K.put(ground, K.VEIL, K.area_mark(MAGENTA, VIOLET), "ThroneArea", Vector3.UP * 0.07, Vector3.ONE * r, Vector3.ZERO, time, {"initial": 0.2, "grow_time": 0.45, "spin": -0.25, "decay": 0.97})
		K.put(ground, K.VEIL, mist_mesh(), "ThroneMist", Vector3.UP * 0.09, Vector3.ONE * PIT * 0.9, Vector3.ZERO, time, {"initial": 0.1, "grow_time": 0.45, "fade_in": 0.3, "decay": 1.0, "spin": 0.5, "priority": -1}, {"noise_amt": 1.0, "noise_scale": Vector2(5.0, 1.6), "flow": Vector2(0.25, -0.5), "bias": -0.5, "taper": 0.0, "tint": Color(0.6, 0.5, 0.9), "opacity": 0.7})
		ground._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var sky := K.root(parent, Vector3(point.x, 0, point.z), time, "StarGodSky_" + ID, origin, art)
	if sky:
		_court(sky, time, 0.0, true)
		sky._draw()
	return true


## The emperor's court in the air: ravens over the throne under a dark vortex.
static func _court(art: StarSkillArt, seconds: float, turned: float, gather: bool) -> void:
	var come := {"fade_in": 0.001}
	if gather: come = {"initial": 0.3, "grow_time": 0.5, "fade_in": 0.25, "delay": seconds * 0.3}
	K.put(art, K.SOLID, raven_mesh(), "ThroneRavens", RAVENS, Vector3(5.2, 5.2, 5.2), Vector3(0, turned * 1.7, 0), seconds - float(come.get("delay", 0.0)), {"spin": 1.7, "decay": 0.9, "cull": 4.0}.merged(come, true), STONE_LOOK.merged({"flap": 0.085, "flap_rate": 13.0}))
	K.put(art, K.GLOW, K.column("pit_glow", [Color(1.0, 0.3, 0.9, 0.34), Color(0.6, 0.2, 1.0, 0.16), Color(0.5, 0.2, 1.0, 0.0)], 0.8), "ThronePitGlow", Vector3.ZERO, Vector3(PIT * 0.86, 4.5, PIT * 0.86), Vector3.ZERO, seconds, {"fade_in": 0.3 if gather else 0.001, "decay": 0.8, "priority": -1}, {"noise_amt": 0.6, "noise_scale": Vector2(9.0, 0.8), "flow": Vector2(0.0, -0.8), "bias": -0.38, "taper": 0.2, "fres": 0.8})


static func _spot(index: int) -> Vector3:
	return [Vector3(-4.6, 0, -1.6), Vector3(4.4, 0, -0.8), Vector3(-2.2, 0, -4.6), Vector3(2.8, 0, -4.2)][index % 4]


static func wave(art: StarSkillArt, parent: Node3D, skill: Dictionary, index: int, point: Vector3, source: Vector3) -> bool:
	var r := clampf(float(skill.get("radius", 9.0)), 4.0, 10.0)
	_stage(parent, r, point, source, index)
	var spot := _spot(index)
	var yaw := atan2(spot.x, spot.z)
	var rich := K.quality() == 2
	var chains := {"slide": Vector3(0, -7.5, 0), "slide_time": 0.16, "slide_ease": -2.0}
	if index % 2 == 0:
		# Black lightning walks down on the spot; a chain fan lashes out of the pit after it.
		K.put(art, K.VEIL, bolts_mesh(), "ThroneLightning", spot, Vector3.ONE, Vector3(0, index * 1.3, 0), 0.5, {"fade_in": 0.01, "decay": 0.6, "front": true, "cull": 6.0}, {"flicker": 0.5})
		K.put(art, K.SOLID, chain_mesh(), "ThroneChains", Vector3.ZERO, Vector3.ONE, Vector3(0, yaw, 0), 0.9, {"turn": Vector3(0, 0.35, 0), "fade_in": 0.01, "decay": 0.7, "delay": 0.05, "cull": 10.0}, STONE_LOOK.merged(chains))
		K.put(art, K.VEIL, pillars_mesh(), "ThroneFlame", spot, Vector3(0.7, 0.6, 0.7), Vector3(0, index * 2.0, 0), 0.8, {"initial": 0.3, "grow_time": 0.2, "fade_in": 0.03, "decay": 0.5, "delay": 0.06}, FIRE_LOOK)
	else:
		# Pillars of dark flame burst up; chains whip across them.
		K.put(art, K.VEIL, pillars_mesh(), "ThroneFlame", spot, Vector3(1.15, 1.2, 1.15), Vector3(0, index * 2.0, 0), 0.95, {"initial": 0.25, "grow_time": 0.16, "fade_in": 0.03, "decay": 0.5, "front": true}, FIRE_LOOK)
		K.put(art, K.SOLID, chain_mesh(), "ThroneChains", Vector3.ZERO, Vector3(-1, 1, 1), Vector3(0, yaw, 0), 0.9, {"turn": Vector3(0, -0.35, 0), "fade_in": 0.01, "decay": 0.7, "delay": 0.05, "cull": 10.0}, STONE_LOOK.merged(chains))
		K.put(art, K.VEIL, bolts_mesh(), "ThroneLightning", spot, Vector3(0.7, 1, 0.7), Vector3(0, index * 1.3, 0), 0.4, {"fade_in": 0.01, "decay": 0.6, "delay": 0.08, "cull": 6.0}, {"flicker": 0.5})
	K.put(art, K.VEIL, K.cracks("abyss", Color(0.05, 0.0, 0.1), Color(1.0, 0.3, 0.9), 9, 0.4), "ThroneScar", spot + Vector3.UP * 0.06, Vector3.ONE * 3.4, Vector3(0, index, 0), 1.3, {"initial": 0.3, "grow_time": 0.1, "decay": 0.6, "priority": -1})
	if rich:
		K.put(art, K.GLOW, K.embers("abyss", [MAGENTA, Color("b060ff"), SICK]), "ThroneEmbers", spot + Vector3.UP * 0.3, Vector3.ONE, Vector3.ZERO, 1.1, {"cull": 10.0, "decay": 0.9}, {"burst": 1.0, "gravity": -2.0, "drag": 1.4, "life": 1.0})
		K.put(art, K.VEIL, K.shock(VIOLET, Color("ff9cf0"), MAGENTA), "ThroneRing", spot + Vector3.UP * 0.1, Vector3.ONE * 3.6, Vector3.ZERO, 0.5, {"initial": 0.15, "grow_time": 0.9, "decay": 0.3})
	return true


## From the release on (the first beat the budget lets through): the throne stands over
## the open abyss until the finale has burnt out.
static func _stage(parent: Node3D, r: float, point: Vector3, source: Vector3, index: int) -> void:
	if parent.has_node(NodePath("StarGodSet_" + ID)):
		return
	var beat := float(StarSkillData.GOD_BEATS[4]) - float(StarSkillData.GOD_BEATS[index])
	var stay := beat + 1.9
	var art := K.root(parent, point, stay, "StarGodSet_" + ID, source)
	if not art:
		return
	K.put(art, K.SOLID, throne_mesh(), "GodThrone", THRONE, Vector3.ONE * THRONE_SIZE, Vector3.ZERO, stay, {"fade_in": 0.001, "decay": 0.88, "cull": 16.0}, STONE_LOOK)
	K.put(art, K.VEIL, abyss_mesh(), "ThroneAbyss", Vector3.UP * 0.05, Vector3.ONE * PIT, Vector3.ZERO, stay, {"fade_in": 0.001, "decay": 0.8, "priority": -2})
	K.put(art, K.VEIL, pit_fire(), "ThroneFire", Vector3.UP * 0.05, Vector3.ONE, Vector3.ZERO, stay, {"fade_in": 0.001, "decay": 0.8}, FIRE_LOOK)
	K.put(art, K.VEIL, K.area_mark(MAGENTA, VIOLET), "ThroneArea", Vector3.UP * 0.07, Vector3.ONE * r, Vector3.ZERO, stay, {"spin": -0.25, "decay": 0.8, "fade_in": 0.001})
	if MemoryGuard.pressure == 0 and index < 4:
		K.put(art, K.SOLID, raven_mesh(), "ThroneRavens", RAVENS, Vector3(5.2, 5.2, 5.2), Vector3(0, 1.8, 0), beat + 0.25, {"spin": 1.7, "fade_in": 0.001, "decay": 0.97, "cull": 4.0}, STONE_LOOK.merged({"flap": 0.085, "flap_rate": 13.0}))
	art._draw()


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	var r := clampf(float(skill.get("radius", 9.0)), 4.0, 10.0)
	var land := 0.24
	_stage(parent, r, point, source, 4)
	# The crown of black iron falls and slams down; the abyss erupts through it.
	K.put(art, K.SOLID, crown_mesh(), "GodCrown", CROWN, Vector3.ONE * 2.7, Vector3(0.06, 0.4, -0.05), 1.9, {"fade_in": 0.005, "decay": 0.86, "cull": 30.0}, STONE_LOOK.merged({"slide": Vector3(0, 9.0, 0), "slide_time": land, "slide_ease": 2.2, "rim_color": Color("ffd0ff")}))
	K.put(art, K.VEIL, eruption_mesh(), "ThroneEruption", Vector3(CROWN.x, 0, CROWN.z), Vector3(1.9, 16.0, 1.9), Vector3.ZERO, 1.35, {"initial": 0.3, "grow_time": 0.1, "fade_in": 0.02, "decay": 0.5, "delay": land, "front": true}, FIRE_LOOK.merged({"noise_scale": Vector2(9.0, 3.6), "flow": Vector2(0.3, -5.5), "bias": 0.1, "taper": 0.8, "sway": 0.04}, true))
	K.put(art, K.VEIL, K.shock(VIOLET, Color("ffb0f4"), MAGENTA), "ThroneShock", Vector3.UP * 0.12, Vector3.ONE * r * 1.12, Vector3.ZERO, 0.75, {"initial": 0.1, "grow_time": 0.75, "fade_in": 0.02, "decay": 0.45, "delay": land}, {"opacity": 0.75})
	K.put(art, K.GLOW, K.column("abyss_core", [Color(1.0, 0.9, 0.6, 1.0), Color(1.0, 0.35, 0.9, 0.8), Color(0.7, 0.2, 1.0, 0.4), Color(0.6, 0.2, 1.0, 0.0)], 0.6, 12), "ThroneCore", Vector3(CROWN.x, 0, CROWN.z), Vector3(1.0, 13.0, 1.0), Vector3.ZERO, 0.8, {"initial": 0.3, "grow_time": 0.1, "fade_in": 0.02, "decay": 0.35, "delay": land, "front": true}, {"noise_amt": 0.6, "noise_scale": Vector2(6.0, 2.0), "flow": Vector2(0.0, -6.0), "bias": -0.3, "taper": 0.3})
	K.put(art, K.SOLID, K.debris("obsidian", [OBS, OBS_HI, OBS_DK, SICK_DK], 30, 0.55), "ThroneDebris", Vector3(CROWN.x, 0.4, CROWN.z), Vector3.ONE * 1.6, Vector3.ZERO, 1.6, {"cull": 20.0, "decay": 0.92, "delay": land}, STONE_LOOK.merged({"burst": 1.0, "gravity": 14.0, "drag": 0.9, "life": 1.4}))
	K.put(art, K.VEIL, K.cracks("abyss_big", Color(0.05, 0.0, 0.1), Color(1.0, 0.3, 0.9), 13, 0.0), "ThroneRift", Vector3.UP * 0.06, Vector3.ONE * r * 1.05, Vector3.ZERO, 1.9, {"initial": 0.5, "grow_time": 0.08, "fade_in": 0.01, "decay": 0.7, "delay": land, "priority": -1})
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	# The ravens scatter; dark fire rings the field.
	var avatar := K.root(parent, point, 2.0, "StarGodAvatar_" + ID, source)
	if avatar:
		K.put(avatar, K.SOLID, raven_mesh(), "ThroneRavensScatter", RAVENS, Vector3(5.2, 5.2, 5.2), Vector3(0, 1.8 + 1.7 * 1.75, 0), 1.6, {"fade_in": 0.001, "decay": 0.8, "delay": land, "cull": 30.0}, STONE_LOOK.merged({"flap": 0.1, "flap_rate": 20.0, "burst": 1.0, "gravity": -0.6, "drag": 0.5, "life": 1.7}))
		K.put(avatar, K.VEIL, fire_ring(), "ThroneFireRing", Vector3.UP * 0.05, Vector3(r * 0.105, 1.0, r * 0.105), Vector3.ZERO, 1.3, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.05, "decay": 0.5, "delay": land + 0.08}, FIRE_LOOK)
		K.put(avatar, K.VEIL, bolts_mesh(), "ThroneCrownBolts", Vector3.ZERO, Vector3(2.6, 1.2, 2.6), Vector3.ZERO, 0.55, {"fade_in": 0.01, "decay": 0.6, "delay": land, "cull": 8.0}, {"flicker": 0.5})
		avatar._draw()
	if extras < 2:
		return true
	var temple := K.root(parent, point, 2.0, "StarGodTemple_" + ID, source)
	if temple:
		var chains := {"slide": Vector3(0, -7.5, 0), "slide_time": 0.2, "slide_ease": -2.0}
		K.put(temple, K.SOLID, chain_mesh(), "ThroneChainsFront", Vector3.ZERO, Vector3.ONE * 1.25, Vector3(0, PI, 0), 1.3, {"turn": Vector3(0, 0.4, 0), "fade_in": 0.01, "decay": 0.7, "delay": land, "cull": 12.0}, STONE_LOOK.merged(chains))
		K.put(temple, K.SOLID, chain_mesh(), "ThroneChainsSide", Vector3.ZERO, Vector3(-1.25, 1.25, 1.25), Vector3(0, PI + 1.9, 0), 1.3, {"turn": Vector3(0, -0.4, 0), "fade_in": 0.01, "decay": 0.7, "delay": land + 0.06, "cull": 12.0}, STONE_LOOK.merged(chains))
		K.put(temple, K.GLOW, K.embers("abyss", [MAGENTA, Color("b060ff"), SICK]), "ThroneEmbers", Vector3.UP * 0.4, Vector3(2.4, 1.8, 2.4), Vector3.ZERO, 1.9, {"cull": 20.0, "decay": 0.9, "delay": land}, {"burst": 1.0, "gravity": -2.5, "drag": 1.2, "life": 1.7})
		K.put(temple, K.VEIL, K.sprite(), "ThroneAfterglow", Vector3.UP * 0.2, Vector3.ONE * r * 0.9, Vector3(-PI / 2, 0, 0), 1.9, {"fade_in": 0.05, "decay": 0.35, "delay": land, "priority": -1}, {"radial": 1.2, "tint": Color("b040ff"), "opacity": 0.5})
		temple._draw()
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
## The obsidian throne (about 9 m wide, 13 m tall) with the seated emperor, facing -Z.
static func throne_mesh() -> ArrayMesh:
	return K.cached("abyssal_throne", func():
		var b := K.Builder.new()
		# Dais.
		b.box(Vector3(0, 0.3, 0), Vector3(8.0, 0.6, 5.4), OBS_DK, OBS)
		b.box(Vector3(0, 0.9, 0.3), Vector3(6.6, 0.6, 4.4), OBS_DK, OBS)
		b.emit = 0.35
		b.box(Vector3(0, 0.58, -2.72), Vector3(7.6, 0.1, 0.06), SICK)
		b.box(Vector3(0, 1.18, -1.92), Vector3(6.2, 0.1, 0.06), SICK)
		b.emit = 0.0
		# Seat, arms, back.
		b.box(Vector3(0, 1.9, 0.5), Vector3(3.6, 1.4, 2.8), OBS_DK, OBS)
		b.box(Vector3(0, 5.2, 2.0), Vector3(4.2, 6.4, 0.8), OBS_DK, OBS)
		for side in [-1.0, 1.0]:
			b.box(Vector3(side * 2.2, 2.6, 0.2), Vector3(0.9, 2.2, 3.2), OBS_DK, OBS)
			b.ball(Vector3(side * 2.2, 3.95, -1.25), Vector3(0.5, 0.5, 0.5), SICK, SICK_DK, 7, 5)
			b.cone(Vector3(side * 2.2, 3.4, -1.5), Vector3(side * 2.5, 3.2, -2.7), 0.3, 4, OBS, OBS_HI, Vector3.UP, true)
			b.emit = 0.35
			b.box(Vector3(side * 2.2, 3.72, -0.1), Vector3(0.95, 0.08, 2.4), SICK)
			b.emit = 0.0
		# Jagged spires of obsidian behind and beside the back.
		var spires := [[0.0, 6.0, 13.2, 0.0, 1.25], [-1.6, 5.0, 11.2, -0.7, 0.95], [1.6, 5.0, 10.6, 0.8, 0.95], [-3.0, 3.0, 9.0, -1.6, 0.9], [3.0, 3.0, 9.6, 1.5, 0.9], [-4.1, 0.6, 6.6, -2.4, 0.85], [4.1, 0.6, 6.0, 2.6, 0.85], [-2.4, 0.5, 5.0, -1.2, 0.7], [2.5, 0.5, 4.6, 1.0, 0.7]]
		for q in spires:
			var base := Vector3(q[0], q[1], 2.3 + absf(q[0]) * 0.12)
			var tip := Vector3(q[0] + q[3], q[2], 2.5 + absf(q[0]) * 0.3)
			var mid := base.lerp(tip, 0.45)
			b.tube([base, mid, tip], [q[4], q[4] * 0.72, 0.0], 5, [OBS_DK, OBS, OBS_HI.lerp(VIOLET, 0.35)], Vector3.BACK, true, true)
		# Crystals shouldering out of the dais.
		for q in [[-4.4, -1.0, -2.2, 2.6], [4.5, -0.6, 2.0, 2.3], [-3.9, 1.8, -1.6, 3.2], [3.8, 2.0, 1.8, 3.0], [-4.3, -2.3, -1.2, 1.5], [4.2, -2.2, 1.4, 1.7]]:
			b.cone(Vector3(q[0] * 0.8, 0.2, q[1]), Vector3(q[0] + q[2] * 0.4, q[3], q[1] - 0.3), 0.55, 4, OBS_DK, OBS_HI, Vector3.UP, true)
		# The seal over the emperor's head.
		b.emit = 1.0
		b.gem(Vector3(0, 8.9, 1.52), Vector3(0.55, 0.9, 0.2), MAGENTA, Color("ffc0f4"))
		b.emit = 0.35
		for k in 4:
			var a := TAU * k / 4.0 + PI / 4
			b.gem(Vector3(cos(a) * 1.0, 8.9 + sin(a) * 1.25, 1.52), Vector3(0.16, 0.3, 0.1), SICK, SICK)
		b.emit = 0.0
		# The shadow emperor: seated, broad, horned and crowned.
		b.tube([Vector3(0, 2.5, 0.6), Vector3(0, 4.0, 0.9), Vector3(0, 5.5, 1.0)], [Vector2(1.15, 0.85), Vector2(1.3, 0.9), Vector2(1.65, 0.95)], 8, [SHADOW], Vector3.BACK)
		b.ball(Vector3(0, 6.45, 0.8), Vector3(0.58, 0.7, 0.58), SHADOW, SHADOW, 8, 5)
		for side in [-1.0, 1.0]:
			b.cone(Vector3(side * 1.4, 5.5, 1.0), Vector3(side * 2.9, 6.6, 1.1), 0.65, 5, SHADOW, OBS, Vector3.UP, true)
			b.cone(Vector3(side * 1.5, 5.3, 0.8), Vector3(side * 2.6, 5.4, 0.2), 0.45, 4, SHADOW, OBS, Vector3.UP, true)
			b.tube([Vector3(side * 0.42, 6.75, 0.85), Vector3(side * 1.15, 7.2, 0.95), Vector3(side * 1.35, 8.3, 0.6)], [0.22, 0.17, 0.0], 5, [SHADOW, SHADOW, OBS_HI])
			var hand := Vector3(side * 2.2, 4.0, -0.9) if side < 0.0 else Vector3(2.35, 4.75, -1.75)
			b.tube([Vector3(side * 1.45, 5.1, 0.9), Vector3(side * 2.25, 4.1, 0.5), hand], [0.42, 0.36, 0.3], 6, [SHADOW])
			b.ball(hand, Vector3(0.36, 0.3, 0.4), SHADOW, SHADOW, 6, 4)
			b.tube([Vector3(side * 0.7, 2.75, 0.3), Vector3(side * 0.85, 2.75, -1.35), Vector3(side * 0.9, 0.95, -1.85)], [0.55, 0.5, 0.36], 6, [SHADOW])
			b.box(Vector3(side * 0.9, 0.78, -2.15), Vector3(0.7, 0.36, 1.0), SHADOW)
			# The cloak falls from the shoulders over the arms of the throne.
			b.quad(Vector3(side * 1.3, 1.3, 1.5), Vector3(side * 3.3, 1.3, 1.0), Vector3(side * 2.7, 5.9, 1.25), Vector3(side * 1.4, 5.6, 1.4), Color("1d0d33"), SHADOW)
			b.emit = 1.0
			b.gem(Vector3(side * 0.24, 6.5, 0.24), Vector3(0.15, 0.07, 0.06), MAGENTA, Color("ffd0f8"))
			b.emit = 0.0
		for k in 5:
			var a := lerpf(-1.1, 1.1, k / 4.0)
			b.cone(Vector3(sin(a) * 0.5, 7.0, 0.75 - cos(a) * 0.3), Vector3(sin(a) * 0.75, 7.75 + 0.25 * (1 - absi(k - 2)), 0.7 - cos(a) * 0.5), 0.14, 4, SICK_DK, SICK, Vector3.UP, true)
		# His sword, planted by the right arm, the hand on its pommel.
		b.box(Vector3(2.35, 2.2, -1.75), Vector3(0.5, 3.4, 0.12), Color("342a4c"), Color("6a5a90"))
		b.emit = 0.8
		b.box(Vector3(2.35, 2.2, -1.82), Vector3(0.1, 3.2, 0.03), MAGENTA)
		b.emit = 0.35
		b.box(Vector3(2.35, 3.95, -1.75), Vector3(1.5, 0.2, 0.22), SICK)
		b.emit = 0.0
		b.box(Vector3(2.35, 4.3, -1.75), Vector3(0.16, 0.6, 0.16), SHADOW)
		return b.mesh())


## The mouth of the abyss (radius 1): a jagged black pit lit magenta round its lip, cracks running out.
static func abyss_mesh() -> ArrayMesh:
	return K.cached("abyss", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 17
		var segs := 30
		var edge := []
		for j in segs:
			edge.append(rng.randf_range(0.84, 1.0))
		var black := Color(0.02, 0.0, 0.05, 0.97)
		var bands := [[0.0, black], [0.8, Color(0.06, 0.0, 0.13, 0.96)], [0.93, Color(1.0, 0.25, 0.85, 0.95)], [1.0, Color(0.07, 0.01, 0.12, 0.95)], [1.12, Color(0.07, 0.01, 0.12, 0.0)]]
		for k in bands.size() - 1:
			var base := b.v.size()
			for j in segs + 1:
				var a := TAU * j / float(segs)
				var d := Vector3(sin(a), 0, cos(a)) * float(edge[j % segs])
				b.pt(d * float(bands[k][0]), Vector3.UP, bands[k][1])
				b.pt(d * float(bands[k + 1][0]), Vector3.UP, bands[k + 1][1])
			for j in segs:
				var q := base + j * 2
				b.tri(q, q + 1, q + 3); b.tri(q, q + 3, q + 2)
		for i in 9:
			var a := TAU * i / 9.0 + rng.randf_range(-0.2, 0.2)
			var here := Vector3(sin(a), 0, cos(a)) * 0.95
			var width := 0.05
			for k in 4:
				a += rng.randf_range(-0.35, 0.35)
				var next := here + Vector3(sin(a), 0, cos(a)) * rng.randf_range(0.12, 0.2)
				var side := Vector3(cos(a), 0, -sin(a))
				var thin := width * (1.0 - (k + 1) / 4.0)
				b.quad(here - side * width, here + side * width, next + side * thin, next - side * thin, Color(0.05, 0.0, 0.1, 0.95))
				b.quad(here - side * width * 0.4 + Vector3.UP * 0.004, here + side * width * 0.4 + Vector3.UP * 0.004, next + side * thin * 0.4 + Vector3.UP * 0.004, next - side * thin * 0.4 + Vector3.UP * 0.004, Color(1.0, 0.3, 0.9, 1.0), Color(0.7, 0.2, 1.0, 0.9))
				here = next
				width = thin
		return b.mesh())


## A disc of smoke (radius 1) the shader stirs: the mist in the pit, the vortex overhead.
static func mist_mesh() -> ArrayMesh:
	return K.cached("abyss_mist", func():
		var b := K.Builder.new()
		b.annulus(0.0, 0.35, 28, Color(0.5, 0.15, 0.9, 0.0), Color(0.55, 0.18, 0.95, 0.5))
		b.annulus(0.35, 0.8, 28, Color(0.55, 0.18, 0.95, 0.5), Color(0.9, 0.25, 0.9, 0.55))
		b.annulus(0.8, 1.0, 28, Color(0.9, 0.25, 0.9, 0.55), Color(0.4, 0.1, 0.8, 0.0))
		return b.mesh())


static func _flame(b: K.Builder, at: Vector3, wide: float, high: float, lean := Vector3.ZERO) -> void:
	b.xf = Transform3D(Basis.IDENTITY, at)
	b.lathe([[wide, 0.0, Color(1.0, 0.75, 0.55, 0.95)], [wide * 0.84, high * 0.06, Color(1.0, 0.2, 0.82, 0.95)], [wide * 0.58, high * 0.28, Color(0.56, 0.08, 0.92, 0.92)], [wide * 0.36, high * 0.56, Color(0.22, 0.02, 0.44, 0.9)], [wide * 0.15, high * 0.83, Color(0.09, 0.0, 0.2, 0.85)], [0.0, high, Color(0.05, 0.0, 0.12, 0.0)]], 9, 0.0, TAU, lean * high)
	b.xf = Transform3D.IDENTITY


## Tongues of violet fire licking up round the lip of the pit (in metres).
static func pit_fire() -> ArrayMesh:
	return K.cached("pit_fire", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for i in 15:
			var a := TAU * i / 15.0 + rng.randf_range(-0.1, 0.1)
			# Lower in front of the throne and towards the caster, so neither is hidden.
			var front := 0.55 + 0.45 * absf(sin(a))
			_flame(b, Vector3(sin(a), 0, cos(a)) * PIT * rng.randf_range(0.86, 0.95), rng.randf_range(0.4, 0.62), rng.randf_range(2.0, 3.6) * front, Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)))
		return b.mesh())


## Three pillars of dark flame in a cluster (in metres, about 6 m tall).
static func pillars_mesh() -> ArrayMesh:
	return K.cached("dark_pillars", func():
		var b := K.Builder.new()
		_flame(b, Vector3(0, 0, 0), 0.95, 7.5, Vector3(0.08, 0, 0.05))
		_flame(b, Vector3(-1.7, 0, 0.7), 0.6, 5.0, Vector3(-0.2, 0, 0.1))
		_flame(b, Vector3(1.5, 0, -0.8), 0.65, 5.6, Vector3(0.22, 0, -0.1))
		_flame(b, Vector3(0.3, 0, 1.5), 0.45, 3.6, Vector3(0.05, 0, 0.25))
		return b.mesh())


## A ring of ten pillars of dark flame (radius ~6 at scale 1).
static func fire_ring() -> ArrayMesh:
	return K.cached("dark_fire_ring", func():
		var b := K.Builder.new()
		for i in 10:
			var a := TAU * i / 10.0 + 0.3
			_flame(b, Vector3(sin(a), 0, cos(a)) * 6.4, 0.8, 5.8 if i % 2 == 0 else 4.0, Vector3(cos(a), 0, -sin(a)) * 0.2)
		return b.mesh())


## The eruption: a column of radius 1 and height 1, flared at the foot.
static func eruption_mesh() -> ArrayMesh:
	return K.cached("abyss_eruption", func():
		var b := K.Builder.new()
		b.lathe([[1.3, 0.0, Color(1.0, 0.8, 0.5, 0.95)], [1.05, 0.04, Color(1.0, 0.25, 0.85, 0.95)], [1.0, 0.2, Color(0.62, 0.12, 0.98, 0.92)], [0.92, 0.5, Color(0.22, 0.03, 0.44, 0.9)], [0.78, 0.8, Color(0.09, 0.0, 0.2, 0.8)], [0.5, 1.0, Color(0.06, 0.0, 0.14, 0.0)]], 18)
		return b.mesh())


## Three bolts of black lightning (13 m tall) with a magenta corona.
static func bolts_mesh() -> ArrayMesh:
	return K.cached("black_bolts", func():
		var b := K.Builder.new()
		var feet := [Vector3(0, 0, 0), Vector3(-1.5, 0, 0.9), Vector3(1.3, 0, -1.1)]
		for pass_ in 2:
			var rng := RandomNumberGenerator.new()
			rng.seed = 27
			for foot in feet:
				var top: Vector3 = foot * 0.3 + Vector3(rng.randf_range(-1.5, 1.5), 13.0, rng.randf_range(-1.0, 1.0))
				if pass_ == 0:
					K.bolt(b, top, foot, 0.62, Color(1.0, 0.35, 0.92, 0.95), Color(0.6, 0.2, 1.0, 1.0), rng, 7, 1.2)
				else:
					K.bolt(b, top, foot, 0.2, Color(0.03, 0.0, 0.08, 1.0), Color(0.03, 0.0, 0.08, 1.0), rng, 7, 1.2)
		return b.mesh())


static func _link(b: K.Builder, at: Vector3, along: Vector3, flat: Vector3, size: float, tone: Color) -> void:
	# A flat oval link: outer and inner outline joined by quads.
	var side := along.cross(flat).normalized()
	var ring := []
	for j in 8:
		var a := TAU * j / 8.0
		ring.append([at + along * cos(a) * size * 0.62 + side * sin(a) * size * 0.36, at + along * cos(a) * size * 0.4 + side * sin(a) * size * 0.16])
	for j in 8:
		var p: Array = ring[j]
		var q: Array = ring[(j + 1) % 8]
		b.quad(p[1], q[1], q[0], p[0], tone)


## Five chains arcing out of the pit's heart over a quarter of the field, hooked blades at their ends (in metres).
static func chain_mesh() -> ArrayMesh:
	return K.cached("abyss_chains", func():
		var b := K.Builder.new()
		for c in 5:
			var a := lerpf(-0.95, 0.95, c / 4.0)
			var out := Vector3(sin(a), 0, cos(a))
			var reach := 6.8 + 1.2 * (c % 2)
			var high := 4.2 + 1.4 * ((c + 1) % 2)
			var prev := Vector3.ZERO
			var links := 20
			for i in links + 1:
				var f := float(i) / links
				var here := out * reach * f + Vector3.UP * (high * 4.0 * f * (1.0 - f) - 0.5 * (1.0 - f))
				if i > 0:
					var along := (here - prev).normalized()
					var flat := out.cross(Vector3.UP) if i % 2 == 0 else along.cross(out.cross(Vector3.UP)).normalized()
					b.emit = 0.25 if i % 4 == 0 else 0.0
					_link(b, (here + prev) * 0.5, along, flat, 0.62, SICK_DK if i % 4 == 0 else IRON.lerp(OBS_HI, 0.35))
				prev = here
			b.emit = 0.0
			var tip := out * reach
			b.cone(tip + Vector3.UP * 0.9, tip - Vector3.UP * 0.5 + out * 0.3, 0.3, 4, IRON, OBS_HI, Vector3.RIGHT, true)
		return b.mesh())


## Seven ravens wheeling on a ring of radius 1 (they fly apart as a burst).
static func raven_mesh() -> ArrayMesh:
	return K.cached("ravens", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var black := Color("160c26")
		var sheen := Color("4a2a86")
		for i in 7:
			var a := TAU * i / 7.0 + rng.randf_range(-0.2, 0.2)
			var out := Vector3(sin(a), 0, cos(a))
			var ahead := Vector3(cos(a), 0, -sin(a))
			var size := rng.randf_range(0.17, 0.24)
			var at := out * rng.randf_range(0.65, 1.05) + Vector3.UP * rng.randf_range(-0.22, 0.22)
			b.piece(at, (out * rng.randf_range(1.6, 3.0) + ahead * 1.2 + Vector3.UP * rng.randf_range(0.2, 1.2)), rng.randf_range(0.0, 0.15), 0.0, Basis(ahead, Vector3.UP, ahead.cross(Vector3.UP)).scaled(Vector3.ONE * size))
			b.phase = float(i) / 7.0
			b.weight = 0.0
			b.ball(Vector3.ZERO, Vector3(0.6, 0.22, 0.24), black, black, 6, 4)
			b.ball(Vector3(0.55, 0.12, 0), Vector3(0.2, 0.18, 0.18), black, black, 5, 3)
			b.cone(Vector3(0.68, 0.1, 0), Vector3(1.05, 0.02, 0), 0.08, 4, SICK, SICK_DK)
			b.tri3(Vector3(-0.45, 0.02, -0.14), Vector3(-0.45, 0.02, 0.14), Vector3(-1.15, 0.0, 0), black, black, sheen)
			b.emit = 1.0
			b.gem(Vector3(0.62, 0.2, 0.13), Vector3(0.05, 0.05, 0.05), MAGENTA)
			b.gem(Vector3(0.62, 0.2, -0.13), Vector3(0.05, 0.05, 0.05), MAGENTA)
			b.emit = 0.0
			for side in [-1.0, 1.0]:
				var pts := [Vector3(0.3, 0.06, side * 0.15), Vector3(-0.3, 0.06, side * 0.15), Vector3(0.38, 0.1, side * 0.9), Vector3(-0.42, 0.06, side * 0.85), Vector3(-0.25, 0.06, side * 1.3), Vector3(0.05, 0.06, side * 1.75)]
				var bend := [0.0, 0.0, 0.6, 0.55, 0.95, 1.4]
				var index := []
				for k in pts.size():
					b.weight = float(bend[k])
					index.append(b.pt(pts[k], Vector3.UP, black.lerp(sheen, float(bend[k]) * 0.6)))
				b.tri(index[0], index[1], index[3]); b.tri(index[0], index[3], index[2])
				b.tri(index[2], index[3], index[4]); b.tri(index[2], index[4], index[5])
			b.weight = 0.0
		b.phase = -1.0
		return b.mesh())


## The emperor's crown of black iron (radius 1): eight jagged spikes, a band of sick gold, magenta stones.
static func crown_mesh() -> ArrayMesh:
	return K.cached("iron_crown", func():
		var b := K.Builder.new()
		var iron := Color("2a1f3c")
		b.lathe([[0.96, 0.0, IRON], [1.06, 0.06, iron], [1.02, 0.5, iron], [0.96, 0.56, Color("4a3868")], [0.9, 0.5, IRON], [0.92, 0.0, IRON]], 24)
		b.emit = 0.4
		b.lathe([[1.07, 0.2, SICK_DK], [1.1, 0.25, SICK], [1.07, 0.3, SICK_DK]], 24)
		b.emit = 0.0
		for i in 8:
			var a := TAU * i / 8.0
			var out := Vector3(sin(a), 0, cos(a))
			var tall := 1.75 if i % 2 == 0 else 1.15
			b.tube([out * 0.98 + Vector3.UP * 0.45, out * 1.06 + Vector3.UP * (0.45 + tall * 0.45), out * 1.16 + Vector3.UP * (0.5 + tall)], [0.3, 0.2, 0.0], 4, [iron, Color("4a3868"), Color("8a60c8")], out, true, true)
			b.emit = 1.0
			b.gem(out * 1.09 + Vector3.UP * 0.25, Vector3(0.09, 0.13, 0.09), MAGENTA, Color("ffd0f8"))
			b.emit = 0.0
		return b.mesh())
