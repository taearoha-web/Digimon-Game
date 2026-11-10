extends RefCounted
## Summoner god skill: จักรพรรดิมังกรสวรรค์. A full-bodied eastern dragon (one mesh laid
## on a spline by the PATH shader) comes down through a cloud bank, circles the field
## during the wind-up, sweeps through the centre from four sides on the four waves (claw
## swipe, tail sweep, jade fire, lightning from its coils), then coils up and dives
## head-first into the middle. Cosmetic only: StarSkillSequence owns every contact.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const ID := "celestial_dragon_emperor"
const BODY := 26.0
const SPACING := 2.3
const ROSE := 8.5
## How high the petals of the flight lift at their tips.
const LIFT := 2.1
## The cloud bank the dragon comes down through, at the side of the field.
const CLOUD := Vector3(8.6, 5.4, -1.2)
const JADE := Color("17c48c")
const JADE_HI := Color("52f0b4")
const JADE_DK := Color("0a6e5c")
const BELLY := Color("fff2bd")
const BELLY_DK := Color("f0c060")
const GOLD := Color("ffca3a")
const GOLD_DK := Color("c98418")
const IVORY := Color("fbfff2")
const DRAGON_LOOK := {"rim_color": Color("d6fff0"), "rim": 0.55, "shadow_tint": Color(0.42, 0.52, 0.72), "scales": 1.0, "girth": 1.4, "wave_amp": 0.55, "wave_len": 9.0, "wave_speed": 7.0}
const CLOUD_LOOK := {"rim_color": Color("7fd8c0"), "rim": 1.0, "shadow_tint": Color(0.62, 0.88, 0.84)}
static var _course := {}


# ---------------------------------------------------------------------------
# The dragon's whole flight, in the root's space (+Z away from the caster).
# ---------------------------------------------------------------------------
static func course() -> Dictionary:
	if not _course.is_empty():
		return _course
	var line := PackedVector3Array()
	# Down from the heavens through the cloud bank, then a wide circle that sinks and
	# widens into the first petal's tip.
	var way := []
	# The field camera looks down from behind the caster: what is far (+Z) must fly low.
	var a0 := atan2(CLOUD.x, CLOUD.z) + TAU
	way.append(CLOUD + Vector3.UP * 30.0)
	way.append(CLOUD + Vector3.UP * 16.0)
	way.append(CLOUD + Vector3.UP * 7.0)
	var steps := 18
	for i in range(0, steps + 1):
		var f := float(i) / steps
		var a := lerpf(a0, PI * 0.5, f)
		var radius := lerpf(Vector2(CLOUD.x, CLOUD.z).length(), ROSE, smoothstep(0.5, 1.0, f))
		var z := cos(a) * radius
		var y := lerpf(CLOUD.y - 0.6, 3.5 - 0.2 * z, smoothstep(0.0, 0.2, f)) + sin(f * 9.0) * 0.3
		y = lerpf(y, 1.5 + LIFT, smoothstep(0.8, 1.0, f))
		way.append(Vector3(sin(a) * radius, y, z))
	line.append_array(K.smooth(way, 10))
	# The rose: four passes through the centre, one petal per wave.
	var crossing := []
	for i in range(1, 224 + 13):
		var phi := float(i) * PI / 128.0
		var c := cos(2.0 * phi)
		var r := ROSE * signf(c) * pow(absf(c), 0.55)
		line.append(Vector3(r * cos(phi), 1.5 + LIFT * c * c, r * sin(phi)))
		if i % 64 == 32: crossing.append(line.size() - 1)
	# The coil: up round the centre, over the top and straight down into it.
	var last := line[line.size() - 1]
	var from := atan2(last.z, last.x)
	var r0 := Vector2(last.x, last.z).length()
	way = [line[line.size() - 2], last]
	for j in range(1, 7):
		var f := float(j) / 6.0
		var a := from + f * TAU * 0.72
		var radius := lerpf(r0, 2.4, pow(f, 0.8))
		way.append(Vector3(cos(a) * radius, lerpf(last.y, 8.0, pow(f, 0.9)), sin(a) * radius))
	var over := from + TAU * 0.72 + 0.7
	way.append(Vector3(cos(over) * 1.0, 9.2, sin(over) * 1.0))
	way.append(Vector3(0, 6.5, 0))
	way.append(Vector3(0, 3.2, 0))
	way.append(Vector3(0, 0.4, 0))
	way.append(Vector3(0, -6.0, 0))
	way.append(Vector3(0, -12.0, 0))
	var tail := K.smooth(way, 10)
	var ground := -1
	for i in range(11, tail.size()):
		line.append(tail[i])
		if ground < 0 and tail[i].y <= 0.45 and i > 40: ground = line.size() - 1
	var arc := PackedFloat32Array([0.0])
	for i in range(1, line.size()):
		arc.append(arc[i - 1] + line[i].distance_to(line[i - 1]))
	var cross := []
	for index in crossing: cross.append(arc[index])
	_course = {"points": K.resample(line, SPACING), "cross": cross, "ground": arc[ground]}
	return _course


## The direction the dragon flies through the centre on wave [param index].
static func heading(index: int) -> Vector3:
	return [Vector3(-1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, -1)][index % 4].normalized()


static func _dragon(art: StarSkillArt, label: String, seconds: float, first: int, last: int, keys: Array, style := {}) -> void:
	var data := course()
	var params := K.path_params(data.points, SPACING, first, last, keys)
	params.merge(DRAGON_LOOK)
	K.put(art, K.PATH, dragon_mesh(), label, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, seconds, {"fade_in": 0.02, "decay": 1.0, "cull": 80.0}.merged(style, true), params)


# ---------------------------------------------------------------------------
# Beats
# ---------------------------------------------------------------------------
static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := clampf(float(skill.get("radius", 9.5)), 4.0, 10.0)
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	# The summoner: a ring of jade light and a wreath of cloud at the feet.
	K.put(art, K.GLOW, K.shock(JADE, Color("fff3b0"), JADE_HI), "DragonCallRing", Vector3.UP * 0.08, Vector3.ONE * 1.9, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.5, "spin": 1.2, "decay": 0.9}, {"opacity": 0.8})
	K.put(art, K.SOLID, cloud_ring(), "DragonCallCloud", Vector3.UP * 0.25, Vector3(1.5, 1.2, 1.5), Vector3.ZERO, time, {"initial": 0.4, "grow_time": 0.5, "spin": -1.6, "fade_in": 0.15}, CLOUD_LOOK)
	var ground := K.root(parent, Vector3(point.x, 0, point.z), time, "StarGodGround_" + ID, origin, art)
	if ground:
		var data := course()
		var goal: float = data.cross[0]
		var keys := []
		for f in [0.0, 0.25, 0.5, 0.7, 0.85, 1.0]:
			keys.append([time * f, lerpf(27.0, goal, 0.55 * f + 0.45 * f * f * f)])
		_dragon(ground, "GodDragon", time, 0, int(ceil(goal / SPACING)) + 2, keys, {"fade_in": 0.06})
		K.put(ground, K.GLOW, K.area_mark(Color("9dffd8"), JADE), "DragonArea", Vector3.UP * 0.07, Vector3.ONE * r, Vector3.ZERO, time, {"initial": 0.2, "grow_time": 0.45, "spin": 0.25, "decay": 0.97})
		ground._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var sky := K.root(parent, Vector3(point.x, 0, point.z), time, "StarGodSky_" + ID, origin, art)
	if sky:
		_heavens(sky, time, 0.0, true)
		sky._draw()
	return true


## The cloud bank the dragon comes through, lit gold from above.
static func _heavens(art: StarSkillArt, seconds: float, turned: float, gather: bool) -> void:
	var at := CLOUD
	var style := {"spin": 0.22, "decay": 0.9, "fade_in": 0.001}
	if gather: style.merge({"initial": 0.25, "grow_time": 0.4, "fade_in": 0.2, "decay": 0.99})
	K.put(art, K.SOLID, cloud_bank(), "DragonHeavens", at, Vector3(3.6, 2.4, 3.6), Vector3(0, turned, 0), seconds, style, CLOUD_LOOK)
	K.put(art, K.GLOW, K.sprite(), "DragonSkyLight", at + Vector3(0, 0.6, 0.0), Vector3.ONE * 6.5, Vector3.ZERO, seconds, {"initial": 0.4, "grow_time": 0.5, "fade_in": 0.3, "decay": 0.8, "priority": -2}, {"radial": 1.6, "billboard": true, "tint": Color("ffe08a"), "opacity": 0.3})
	K.put(art, K.GLOW, K.column("shaft", [Color(1, 0.95, 0.7, 0.0), Color(0.8, 1.0, 0.85, 0.16), Color(1.0, 0.96, 0.7, 0.34)], 0.45), "DragonShaft", Vector3(at.x, 0.0, at.z), Vector3(2.6, at.y, 2.6), Vector3.ZERO, seconds, {"fade_in": 0.4, "decay": 0.7, "priority": -2}, {"noise_amt": 0.5, "noise_scale": Vector2(9.0, 0.6), "flow": Vector2(0.15, 0.0), "bias": -0.42, "taper": 0.0, "fres": 1.0})


static func wave(art: StarSkillArt, parent: Node3D, skill: Dictionary, index: int, point: Vector3, source: Vector3) -> bool:
	var r := clampf(float(skill.get("radius", 9.5)), 4.0, 10.0)
	_flight(parent, r, point, source, index)
	var d := heading(index)
	var yaw := atan2(d.x, d.z)
	var rich := K.quality() == 2
	match index % 4:
		0:
			# Claw swipe: three raking crescents and the gouges they leave.
			K.put(art, K.VEIL, claw_mesh(), "DragonClaw", Vector3.UP * 0.2, Vector3.ONE * 5.4, Vector3(0, yaw, 0), 0.5, {"initial": 0.5, "grow_time": 0.22, "fade_in": 0.02, "decay": 0.5, "front": true}, {"heat": 0.5, "hot": Color.WHITE})
			K.put(art, K.VEIL, gouge_mesh(), "DragonGouges", Vector3.UP * 0.05, Vector3.ONE * r * 0.62, Vector3(0, yaw, 0), 1.3, {"initial": 0.5, "grow_time": 0.1, "decay": 0.6})
			K.put(art, K.SOLID, wisp_burst(), "DragonWisps", Vector3.UP * 0.6, Vector3.ONE, Vector3(0, yaw, 0), 1.0, {"cull": 12.0, "decay": 0.9}, CLOUD_LOOK.merged({"burst": 1.0, "gravity": -1.5, "drag": 2.6, "life": 0.95}))
			if rich: K.put(art, K.VEIL, K.shock(JADE, Color("fff8d0"), JADE_HI), "DragonRing", Vector3.UP * 0.1, Vector3.ONE * r * 0.5, Vector3.ZERO, 0.5, {"initial": 0.15, "grow_time": 0.9, "decay": 0.3}, {"opacity": 0.7})
		1:
			# Tail sweep: a broad low arc whipped round, the cloud floor thrown outward.
			K.put(art, K.VEIL, sweep_mesh(), "DragonTail", Vector3.UP * 1.0, Vector3.ONE * r * 0.74, Vector3(0, yaw + 2.2, 0), 0.5, {"initial": 0.7, "grow_time": 0.4, "turn": Vector3(0, -3.6, 0), "fade_in": 0.02, "decay": 0.5, "front": true}, {"heat": 0.4, "hot": Color("fffbe0")})
			K.put(art, K.SOLID, wisp_burst(), "DragonDust", Vector3.UP * 0.4, Vector3(1.7, 0.6, 1.7), Vector3(0, yaw + 1.0, 0), 1.1, {"cull": 14.0, "decay": 0.9}, CLOUD_LOOK.merged({"burst": 1.0, "gravity": -0.6, "drag": 2.2, "life": 1.05}))
			K.put(art, K.VEIL, K.shock(JADE, Color("fff8d0"), GOLD), "DragonRing", Vector3.UP * 0.1, Vector3.ONE * r * 0.8, Vector3.ZERO, 0.6, {"initial": 0.12, "grow_time": 0.9, "decay": 0.3}, {"opacity": 0.7})
			if rich: K.put(art, K.SOLID, shard_burst(), "DragonScales", Vector3.UP * 0.5, Vector3.ONE * 0.7, Vector3(0, yaw, 0), 1.0, {"cull": 12.0}, {"burst": 1.0, "gravity": 14.0, "drag": 1.2, "life": 0.9, "rim_color": Color("fff3b0"), "rim": 0.6})
		2:
			# Breath of jade fire: a wall of flame along its pass over a scorched streak.
			K.put(art, K.VEIL, fire_mesh(), "DragonFire", Vector3.UP * 0.05, Vector3(r * 0.105, 1.15, 1.3), Vector3(0, yaw, 0), 0.95, {"initial": 0.5, "grow_time": 0.16, "fade_in": 0.03, "decay": 0.5, "front": true}, {"noise_amt": 1.0, "noise_scale": Vector2(5.0, 1.5), "flow": Vector2(0.0, -3.0), "bias": 0.12, "taper": 0.95, "sway": 0.5, "heat": 0.0, "edge_heat": 0.7, "hot": Color("d8ffe6")})
			K.put(art, K.VEIL, scorch_mesh(), "DragonScorch", Vector3.UP * 0.05, Vector3(r * 0.2, 1, r * 0.95), Vector3(0, yaw, 0), 1.4, {"initial": 0.6, "grow_time": 0.12, "decay": 0.55})
			K.put(art, K.GLOW, ember_burst(), "DragonEmbers", Vector3.UP * 0.3, Vector3(0.5, 1, 1.9), Vector3(0, yaw, 0), 1.2, {"cull": 12.0, "decay": 0.9}, {"burst": 1.0, "gravity": -3.0, "drag": 1.6, "life": 1.1})
			if rich: K.put(art, K.GLOW, K.sprite(), "DragonFlare", Vector3.UP * 2.0, Vector3.ONE * 6.5, Vector3.ZERO, 0.4, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.25}, {"radial": 1.5, "billboard": true, "tint": Color("3dffa8"), "opacity": 0.5})
		3:
			# Lightning from its coils: gold-white bolts walk across the field.
			K.put(art, K.GLOW, bolt_mesh(), "DragonLightning", Vector3.ZERO, Vector3(r * 0.11, 1, r * 0.11), Vector3(0, yaw, 0), 0.5, {"fade_in": 0.01, "decay": 0.55, "front": true}, {"flicker": 0.55, "heat": 1.0, "hot": Color.WHITE})
			K.put(art, K.VEIL, strike_rings(), "DragonStrikes", Vector3.UP * 0.1, Vector3(r * 0.11, 1, r * 0.11), Vector3(0, yaw, 0), 0.7, {"initial": 0.4, "grow_time": 0.5, "decay": 0.35})
			K.put(art, K.GLOW, ember_burst(), "DragonSparks", Vector3.UP * 0.3, Vector3(1.6, 1, 1.6), Vector3(0, yaw, 0), 0.9, {"cull": 12.0, "decay": 0.9}, {"burst": 1.0, "gravity": 6.0, "drag": 2.0, "life": 0.8, "tint": Color("fff2a0")})
			if rich: K.put(art, K.SOLID, wisp_burst(), "DragonWisps", Vector3.UP * 5.0, Vector3(1.3, 0.7, 1.3), Vector3(0, yaw, 0), 1.0, {"cull": 12.0, "decay": 0.9}, CLOUD_LOOK.merged({"burst": 1.0, "gravity": 0.0, "drag": 2.6, "life": 0.95}))
	return true


## The dragon's flight through the four waves and its dive. It starts on the first beat
## the budget lets through (normally the release) and joins the flight where that beat finds it.
static func _flight(parent: Node3D, r: float, point: Vector3, source: Vector3, index: int) -> void:
	if parent.has_node(NodePath("StarGodFlight_" + ID)):
		return
	var data := course()
	var beats: Array = StarSkillData.GOD_BEATS
	var cross: Array = data.cross
	var since := float(beats[index])
	var dive := float(beats[4]) - since
	var speed := (float(data.ground) - float(cross[3])) / maxf(0.1, float(beats[4]) - float(beats[3]))
	var gone := dive + (BODY + 6.0) / speed
	var flight := K.root(parent, point, gone + 0.05, "StarGodFlight_" + ID, source)
	if not flight:
		return
	var keys := []
	for k in range(mini(index, 3), 4): keys.append([float(beats[k]) - since, cross[k]])
	keys.append([dive, data.ground])
	keys.append([gone, float(data.ground) + BODY + 6.0])
	var from: float = cross[mini(index, 3)] if index < 4 else data.ground
	_dragon(flight, "GodDragon", gone, int((from - BODY - 3.0) / SPACING), 9999, keys, {"fade_in": 0.001, "front": true})
	K.put(flight, K.GLOW, K.area_mark(Color("9dffd8"), JADE), "DragonArea", Vector3.UP * 0.07, Vector3.ONE * r, Vector3.ZERO, gone, {"spin": 0.25, "decay": 0.8, "fade_in": 0.001})
	if MemoryGuard.pressure == 0:
		_heavens(flight, gone + 0.3, 0.33, false)
	flight._draw()


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	var r := clampf(float(skill.get("radius", 9.5)), 4.0, 10.0)
	_flight(parent, r, point, source, 4)
	# The dive lands: a pillar of jade and gold light, the shock, the cracked ground.
	K.put(art, K.VEIL, K.column("jade_pillar", [Color(1.0, 0.95, 0.6, 0.9), Color(0.25, 1.0, 0.65, 0.8), Color(0.05, 0.85, 0.55, 0.55), Color(1.0, 0.8, 0.25, 0.3), Color(1.0, 0.8, 0.3, 0.0)], 0.5, 18), "DragonPillar", Vector3.ZERO, Vector3(2.6, 17.0, 2.6), Vector3.ZERO, 1.15, {"initial": 0.35, "grow_time": 0.12, "fade_in": 0.02, "decay": 0.4, "front": true}, {"noise_amt": 0.75, "noise_scale": Vector2(8.0, 1.6), "flow": Vector2(0.4, -4.0), "bias": -0.25, "taper": 0.4, "heat": 0.25, "hot": Color("fff6c0"), "fres": 0.5, "opacity": 0.85})
	K.put(art, K.VEIL, K.shock(JADE, Color("fff6c0"), GOLD), "DragonShock", Vector3.UP * 0.12, Vector3.ONE * r * 1.12, Vector3.ZERO, 0.75, {"initial": 0.08, "grow_time": 0.75, "fade_in": 0.02, "decay": 0.45}, {"opacity": 0.8})
	K.put(art, K.VEIL, crack_mesh(), "DragonCrater", Vector3.UP * 0.04, Vector3.ONE * r * 0.86, Vector3.ZERO, 2.0, {"initial": 0.3, "grow_time": 0.07, "fade_in": 0.01, "decay": 0.7, "priority": -1})
	K.put(art, K.SOLID, shard_burst(), "DragonScales", Vector3.UP * 0.4, Vector3.ONE * 1.5, Vector3.ZERO, 1.5, {"cull": 20.0, "decay": 0.92}, {"burst": 1.0, "gravity": 13.0, "drag": 0.9, "life": 1.4, "rim_color": Color("fff3b0"), "rim": 0.6})
	K.put(art, K.GLOW, K.sprite(), "DragonCore", Vector3.UP * 1.4, Vector3.ONE * 5.5, Vector3.ZERO, 0.35, {"initial": 0.3, "grow_time": 0.25, "fade_in": 0.01, "decay": 0.2, "front": true}, {"radial": 1.8, "billboard": true, "tint": Color("ffe27a"), "opacity": 0.7})
	K.put(art, K.SOLID, wisp_burst(), "DragonBlast", Vector3.UP * 0.5, Vector3(1.5, 0.7, 1.5), Vector3.ZERO, 1.3, {"cull": 24.0, "decay": 0.92}, CLOUD_LOOK.merged({"burst": 1.0, "gravity": -1.0, "drag": 1.8, "life": 1.25}))
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	# The clouds spiral up round the pillar.
	var avatar := K.root(parent, point, 1.9, "StarGodAvatar_" + ID, source)
	if avatar:
		K.put(avatar, K.SOLID, cloud_helix(), "DragonSpiral", Vector3.ZERO, Vector3(1.0, 0.6, 1.0), Vector3.ZERO, 1.7, {"initial": 0.55, "grow_time": 0.5, "spin": 4.2, "travel": Vector3.UP * 1.2, "fade_in": 0.05, "decay": 0.6, "cull": 6.0}, CLOUD_LOOK)
		K.put(avatar, K.VEIL, K.shock(GOLD, Color("fffbe0"), JADE_HI), "DragonHalo", Vector3.UP * 3.6, Vector3.ONE * r * 0.7, Vector3.ZERO, 0.9, {"initial": 0.1, "grow_time": 0.8, "decay": 0.4, "delay": 0.08})
		K.put(avatar, K.GLOW, ember_burst(), "DragonEmbers", Vector3.UP * 0.4, Vector3(2.2, 1.6, 2.2), Vector3.ZERO, 1.8, {"cull": 20.0, "decay": 0.9}, {"burst": 1.0, "gravity": -2.5, "drag": 1.2, "life": 1.7})
		avatar._draw()
	if extras < 2:
		return true
	var temple := K.root(parent, point, 2.0, "StarGodTemple_" + ID, source)
	if temple:
		K.put(temple, K.SOLID, cloud_ring(), "DragonSurge", Vector3.UP * 0.35, Vector3(r * 0.9, 0.8, r * 0.9), Vector3.ZERO, 1.2, {"initial": 0.25, "grow_time": 0.6, "spin": 2.4, "fade_in": 0.05, "decay": 0.55}, CLOUD_LOOK)
		K.put(temple, K.VEIL, K.shock(GOLD, Color("fffbe0"), JADE_HI), "DragonSecondShock", Vector3.UP * 0.14, Vector3.ONE * r * 0.8, Vector3.ZERO, 0.8, {"initial": 0.08, "grow_time": 0.8, "decay": 0.4, "delay": 0.16})
		K.put(temple, K.VEIL, K.sprite(), "DragonAfterglow", Vector3.UP * 0.2, Vector3.ONE * r * 0.9, Vector3(-PI / 2, 0, 0), 1.9, {"fade_in": 0.05, "decay": 0.35, "priority": -1}, {"radial": 1.2, "tint": Color("3dffa8"), "opacity": 0.4})
		temple._draw()
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
static func _girth(s: float) -> float:
	var f := clampf((s - 1.6) / (BODY - 1.6), 0.0, 1.0)
	return lerpf(0.5, 0.64, smoothstep(0.0, 0.18, f)) * (1.0 - 0.86 * smoothstep(0.5, 1.0, f))


## The dragon along +Z: the nose at 0, the tail tuft at BODY; +Y is its back.
static func dragon_mesh() -> ArrayMesh:
	return K.cached("dragon", func():
		var b := K.Builder.new()
		# Body: jade back over a pale gold belly, flagged for the scale pattern.
		b.weight = 1.0
		var path := []
		var radii := []
		var cols := []
		var s := 1.6
		while s <= BODY + 0.01:
			var f := (s - 1.6) / (BODY - 1.6)
			path.append(Vector3(0, 0, s))
			radii.append(_girth(s))
			cols.append([JADE.lerp(JADE_DK, 0.55 * f), BELLY.lerp(BELLY_DK, 0.5 * f)])
			s += 0.5
		b.tube(path, radii, 10, cols)
		# Head: a long snout swelling into the skull, an open lower jaw.
		b.weight = 0.6
		b.xf = Transform3D(Basis.IDENTITY.scaled(Vector3(1.32, 1.32, 1.18)), Vector3.ZERO)
		b.tube([Vector3(0, 0.05, 0), Vector3(0, 0.09, 0.3), Vector3(0, 0.13, 0.75), Vector3(0, 0.2, 1.15), Vector3(0, 0.14, 1.55), Vector3(0, 0.0, 1.9)],
			[Vector2(0.2, 0.13), Vector2(0.31, 0.2), Vector2(0.4, 0.28), Vector2(0.58, 0.42), Vector2(0.58, 0.48), Vector2(0.5, 0.5)], 10,
			[[JADE_HI, BELLY], [JADE_HI, BELLY], [JADE, BELLY], [JADE, BELLY], [JADE, BELLY], [JADE, BELLY]])
		b.weight = 0.0
		b.tube([Vector3(0, -0.36, 0.18), Vector3(0, -0.42, 0.55), Vector3(0, -0.4, 1.0), Vector3(0, -0.24, 1.45)],
			[Vector2(0.15, 0.06), Vector2(0.25, 0.09), Vector2(0.34, 0.12), Vector2(0.42, 0.16)], 8, [[BELLY, BELLY_DK]])
		b.quad(Vector3(-0.28, -0.3, 0.3), Vector3(0.28, -0.3, 0.3), Vector3(0.36, -0.14, 1.35), Vector3(-0.36, -0.14, 1.35), Color("d8304a"), Color("7a1028"))
		for side in [-1.0, 1.0]:
			# Fangs and teeth along the upper jaw.
			b.cone(Vector3(side * 0.16, -0.02, 0.2), Vector3(side * 0.17, -0.32, 0.26), 0.06, 5, IVORY)
			for k in 3:
				b.cone(Vector3(side * (0.24 + 0.04 * k), -0.06, 0.5 + 0.25 * k), Vector3(side * (0.25 + 0.04 * k), -0.24, 0.52 + 0.25 * k), 0.045, 4, IVORY)
			# Brow ridge, then the lit eye under it.
			b.tube([Vector3(side * 0.2, 0.4, 0.62), Vector3(side * 0.44, 0.56, 0.9), Vector3(side * 0.6, 0.6, 1.3)], [0.07, 0.1, 0.05], 5, [JADE_DK])
			b.emit = 1.0
			b.ball(Vector3(side * 0.44, 0.4, 0.95), Vector3(0.12, 0.11, 0.15), Color("fffdd0"), Color("ffd040"), 6, 4)
			b.emit = 0.0
			b.ball(Vector3(side * 0.53, 0.4, 0.9), Vector3(0.04, 0.09, 0.07), Color("3a0a10"), Color("3a0a10"), 5, 3)
			# Antlers.
			b.tube([Vector3(side * 0.3, 0.5, 1.3), Vector3(side * 0.52, 1.1, 1.9), Vector3(side * 0.66, 1.5, 2.7), Vector3(side * 0.6, 1.62, 3.3)], [0.13, 0.1, 0.06, 0.0], 6, [[GOLD, GOLD_DK]])
			b.tube([Vector3(side * 0.52, 1.1, 1.9), Vector3(side * 0.86, 1.5, 2.1), Vector3(side * 1.0, 1.9, 2.5)], [0.08, 0.06, 0.0], 5, [[GOLD, GOLD_DK]])
			b.tube([Vector3(side * 0.6, 1.36, 2.4), Vector3(side * 0.9, 1.75, 2.9)], [0.06, 0.0], 5, [[GOLD, GOLD_DK]])
			# Whiskers trailing back along the neck.
			b.emit = 0.45
			var whisker := []
			var thin := []
			for k in 9:
				var u := float(k) / 8.0
				whisker.append(Vector3(side * (0.24 + 0.75 * sin(u * 2.4) + 0.2 * u), 0.0 + 0.45 * sin(u * 4.4) * u - 0.1 * u, 0.22 + u * 5.2))
				thin.append(lerpf(0.06, 0.012, u))
			b.tube(whisker, thin, 5, [GOLD])
			b.emit = 0.0
			# Cheek fin.
			b.tri3(Vector3(side * 0.5, 0.2, 1.25), Vector3(side * 0.56, -0.25, 1.35), Vector3(side * 1.25, 0.25, 2.3), JADE_HI, JADE, IVORY)
			b.tri3(Vector3(side * 0.5, 0.2, 1.25), Vector3(side * 0.52, 0.5, 1.4), Vector3(side * 1.1, 0.75, 2.4), JADE_HI, JADE, IVORY)
		b.ball(Vector3(0, 0.15, 0.06), Vector3(0.19, 0.12, 0.14), JADE_HI, JADE, 6, 4)
		# Mane: swept-back flames of white round the skull; a beard under the chin.
		b.emit = 0.3
		for k in 11:
			var a := lerpf(-0.5, PI + 0.5, float(k) / 10.0)
			var out := Vector3(cos(a), sin(a), 0)
			var long := 1.5 + 0.5 * float(k % 3)
			b.cone(Vector3(out.x * 0.44, out.y * 0.4 + 0.08, 1.5), Vector3(out.x * 1.05, out.y * 1.0 + 0.1, 1.6 + long), Vector2(0.17, 0.17), 5, IVORY, Color("b8ffe0"))
		for k in 3:
			b.cone(Vector3(0.14 * (k - 1), -0.45, 1.0), Vector3(0.3 * (k - 1), -1.05, 1.9 + 0.2 * (k % 2)), 0.1, 5, IVORY, Color("b8ffe0"))
		b.xf = Transform3D.IDENTITY
		# Dorsal fins: a saw of gold all the way down the back.
		s = 2.0
		while s < BODY - 1.2:
			var f := s / BODY
			var base := _girth(s) * 0.86
			var high := 0.62 * (1.0 - 0.6 * f) + 0.1
			b.tri3(Vector3(0, base, s - 0.08), Vector3(0, base, s + 0.56), Vector3(0, base + high, s + 0.62), GOLD, GOLD, Color("fff6c8"))
			s += 0.56
		# Tail tuft.
		for k in 5:
			var a := lerpf(-0.9, 0.9, float(k) / 4.0)
			b.tri3(Vector3(0, -0.12, BODY - 0.7), Vector3(0, 0.12, BODY - 0.7), Vector3(0, sin(a) * 1.5, BODY + cos(a) * 2.0), GOLD, GOLD, IVORY)
			b.tri3(Vector3(-0.12, 0, BODY - 0.7), Vector3(0.12, 0, BODY - 0.7), Vector3(sin(a) * 1.1, 0, BODY + cos(a) * 1.7), GOLD, GOLD, IVORY)
		b.emit = 0.0
		# Four legs with three ivory claws each.
		for at in [5.2, 14.0]:
			var size := 1.0 if at < 10.0 else 0.85
			for side in [-1.0, 1.0]:
				var foot := Vector3(side * 1.12 * size, -1.05 * size, at - 0.85)
				b.tube([Vector3(side * 0.36, -0.15, at), Vector3(side * 0.98 * size, -0.5 * size, at - 0.2), foot], [0.3 * size, 0.22 * size, 0.15 * size], 6, [[JADE, JADE_DK]])
				for k in 3:
					b.cone(foot, foot + Vector3(side * 0.26 * (k - 1) + side * 0.1, -0.32, -0.62) * size, 0.09 * size, 5, IVORY)
		return b.mesh())


static func _puffs(b: K.Builder, count: int, rng: RandomNumberGenerator, place: Callable, big: float, lon := 12, lat := 6) -> void:
	for i in count:
		var p := big * rng.randf_range(0.6, 1.0)
		b.ball(place.call(i, rng), Vector3(p, p * 0.74, p), Color("f6fffa").lerp(Color("d6f7ea"), rng.randf()), Color("93dfc8"), lon, lat)


## A heap of cloud, about 1 across (scaled up by the layer).
static func cloud_bank() -> ArrayMesh:
	return K.cached("cloud_bank", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var place := func(i: int, g: RandomNumberGenerator) -> Vector3:
			var a := TAU * i / 15.0 + g.randf_range(-0.2, 0.2)
			var d := 0.35 + 0.65 * g.randf()
			return Vector3(sin(a) * d, g.randf_range(-0.1, 0.22), cos(a) * d * 0.8)
		_puffs(b, 15, rng, place, 0.46)
		return b.mesh())


## A wreath of cloud of radius 1.
static func cloud_ring() -> ArrayMesh:
	return K.cached("cloud_ring", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var place := func(i: int, g: RandomNumberGenerator) -> Vector3:
			var a := TAU * i / 18.0 + g.randf_range(-0.08, 0.08)
			return Vector3(sin(a), g.randf_range(-0.05, 0.1), cos(a)) * g.randf_range(0.9, 1.04)
		_puffs(b, 16, rng, place, 0.15, 10, 5)
		return b.mesh())


## Cloud winding up round a pillar: 4 m wide at the ground, 12 m tall.
static func cloud_helix() -> ArrayMesh:
	return K.cached("cloud_helix", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for arm in 2:
			var place := func(i: int, _g: RandomNumberGenerator) -> Vector3:
				var f := float(i) / 10.0
				var a := arm * PI + f * TAU * 1.2
				return Vector3(sin(a), 0, cos(a)) * lerpf(4.6, 2.6, f) + Vector3.UP * (0.6 + f * 11.0)
			_puffs(b, 9, rng, place, 1.15, 10, 5)
		return b.mesh())


## Puffs of cloud thrown outward along the ground (burst).
static func wisp_burst() -> ArrayMesh:
	return K.cached("wisp_burst", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		for i in 11:
			var a := TAU * i / 11.0 + rng.randf_range(-0.2, 0.2)
			var out := Vector3(sin(a), 0, cos(a))
			b.piece(out * rng.randf_range(0.3, 1.0), out * rng.randf_range(5.0, 11.0) + Vector3.UP * rng.randf_range(0.2, 1.6), rng.randf_range(0.0, 0.08), 0.0)
			var p := rng.randf_range(0.45, 0.85)
			b.ball(Vector3.ZERO, Vector3(p, p * 0.72, p), Color("f6fffa").lerp(Color("d6f7ea"), rng.randf()), Color("93dfc8"), 10, 5)
		return b.mesh())


## Jade and gold scales thrown up and tumbling (burst).
static func shard_burst() -> ArrayMesh:
	return K.cached("scale_burst", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 31
		for i in 34:
			var a := rng.randf() * TAU
			var out := Vector3(sin(a), 0, cos(a))
			b.piece(out * rng.randf_range(0.2, 1.2), out * rng.randf_range(2.5, 7.5) + Vector3.UP * rng.randf_range(6.0, 13.0), rng.randf_range(0.0, 0.1), rng.randf_range(5.0, 12.0), Basis(Vector3(1, 0.3, 0.2).normalized(), rng.randf() * TAU))
			b.emit = 0.35 if i % 3 == 0 else 0.0
			var tone: Color = [JADE, JADE_HI, GOLD][i % 3]
			var size := rng.randf_range(0.2, 0.42)
			b.gem(Vector3.ZERO, Vector3(size, size * 0.12, size * 1.6), tone, tone.lerp(Color.WHITE, 0.6))
		return b.mesh())


## Small diamonds of light that drift up (burst, GLOW).
static func ember_burst() -> ArrayMesh:
	return K.cached("ember_burst", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		for i in 30:
			var a := rng.randf() * TAU
			var out := Vector3(sin(a), 0, cos(a))
			b.piece(out * rng.randf_range(0.3, 2.6) + Vector3.UP * rng.randf_range(0.0, 1.0), out * rng.randf_range(0.5, 3.0) + Vector3.UP * rng.randf_range(2.0, 6.0), rng.randf_range(0.0, 0.25), rng.randf_range(2.0, 6.0))
			var size := rng.randf_range(0.09, 0.2)
			var tone: Color = [Color("8dffc8"), Color("ffe680"), Color("f4fff0")][i % 3]
			b.gem(Vector3.ZERO, Vector3(size, size * 1.7, size), tone, Color.WHITE)
		return b.mesh())


## Three raking claw crescents (radius 1), standing on the ground along +Z.
static func claw_mesh() -> ArrayMesh:
	return K.cached("claws", func():
		var b := K.Builder.new()
		for k in 3:
			# Each crescent stands in a plane leaning over the path, one behind the other.
			b.xf = Transform3D(Basis(Vector3.BACK, 0.32 * (k - 1)) * Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Vector3(0.42 * (k - 1), 0.0, 0.0))
			K.crescent(b, 1.0, 0.3, -1.25, 1.25, Color(JADE_HI, 0.0), Color(1, 1, 0.86, 1.0), 14)
		return b.mesh())


## Three gouges torn along +Z (length 2, centred): dark earth with a lit jade heart.
static func gouge_mesh() -> ArrayMesh:
	return K.cached("gouges", func():
		var b := K.Builder.new()
		for k in 3:
			var x := 0.26 * (k - 1)
			var dark := Color(0.02, 0.12, 0.1, 0.85)
			for pass_ in 2:
				var half := 0.075 if pass_ == 0 else 0.026
				var col := dark if pass_ == 0 else Color(0.6, 1.0, 0.8, 1.0)
				var y := 0.0 if pass_ == 0 else 0.01
				b.fan([Vector3(x, y, 0.0), Vector3(x, y, -1.0), Vector3(x - half, y, -0.2), Vector3(x - half * 0.8, y, 0.6), Vector3(x, y, 1.0), Vector3(x + half * 0.8, y, 0.6), Vector3(x + half, y, -0.2), Vector3(x, y, -1.0)], col, Color(col, col.a * 0.6))
		return b.mesh())


## A broad low crescent of radius 1 (the tail's sweep), three ribs of light.
static func sweep_mesh() -> ArrayMesh:
	return K.cached("tail_sweep", func():
		var b := K.Builder.new()
		K.crescent(b, 1.0, 0.34, -1.7, 1.7, Color(JADE, 0.0), Color(0.75, 1.0, 0.85, 0.95), 20)
		K.crescent(b, 0.78, 0.16, -1.2, 1.5, Color(GOLD, 0.0), Color(1.0, 0.95, 0.6, 0.8), 16, 0.12)
		K.crescent(b, 1.06, 0.07, -1.5, 1.0, Color(JADE, 0.0), Color(1, 1, 1, 0.9), 16, -0.1)
		return b.mesh())


## A row of flame tongues along Z (-5..5 m), each 1.6 m wide and up to 4 m tall.
static func fire_mesh() -> ArrayMesh:
	return K.cached("jade_fire", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in 13:
			var high := rng.randf_range(3.0, 5.2) * (1.0 - 0.35 * absf(i - 6.0) / 6.0)
			b.xf = Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-0.6, 0.6), 0, -5.2 + 10.4 * i / 12.0))
			b.lathe([[0.72, 0.0, Color(0.9, 1.0, 0.75, 1.0)], [0.6, high * 0.08, Color(0.2, 0.98, 0.6, 0.95)], [0.42, high * 0.3, Color(0.03, 0.85, 0.55, 0.92)], [0.25, high * 0.58, Color(0.0, 0.66, 0.5, 0.88)], [0.1, high * 0.84, Color(0.0, 0.48, 0.42, 0.75)], [0.0, high, Color(0.0, 0.4, 0.38, 0.0)]], 8, 0.0, TAU, Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.3, 0.3)) * high)
		return b.mesh())


## A scorched streak along Z (length 2, width 2): soft dark with a jade ember line.
static func scorch_mesh() -> ArrayMesh:
	return K.cached("scorch", func():
		var b := K.Builder.new()
		var dark := Color(0.03, 0.09, 0.08, 0.7)
		b.fan([Vector3.ZERO, Vector3(0, 0, -1), Vector3(-0.7, 0, -0.5), Vector3(-1, 0, 0), Vector3(-0.7, 0, 0.5), Vector3(0, 0, 1), Vector3(0.7, 0, 0.5), Vector3(1, 0, 0), Vector3(0.7, 0, -0.5), Vector3(0, 0, -1)], dark, Color(dark, 0.0))
		b.fan([Vector3(0, 0.01, 0), Vector3(0, 0.01, -0.9), Vector3(-0.16, 0.01, 0), Vector3(0, 0.01, 0.9), Vector3(0.16, 0.01, 0), Vector3(0, 0.01, -0.9)], Color(0.5, 1.0, 0.75, 0.9), Color(0.1, 0.9, 0.55, 0.0))
		return b.mesh())


## Five bolts from the dragon's height to the ground, walking along Z (units of ~1 m at scale 1).
static func bolt_mesh() -> ArrayMesh:
	return K.cached("coil_bolts", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 19
		for spot in _strike_spots():
			K.bolt(b, Vector3(spot.x * 0.4 + rng.randf_range(-1, 1), 10.5, spot.z * 0.55), spot, 0.42, Color(1, 1, 0.9, 1.0), Color(1.0, 0.85, 0.3, 1.0), rng, 7, 1.3)
		return b.mesh())


static func _strike_spots() -> Array:
	return [Vector3(0, 0, 0), Vector3(-3.2, 0, -5.2), Vector3(3.0, 0, 4.6), Vector3(4.2, 0, -3.0), Vector3(-4.4, 0, 2.8)]


## A ring of light under each bolt.
static func strike_rings() -> ArrayMesh:
	return K.cached("strike_rings", func():
		var b := K.Builder.new()
		for spot in _strike_spots():
			b.xf = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.2), spot)
			b.annulus(0.0, 0.5, 14, Color(1, 1, 0.85, 0.9), Color(1.0, 0.9, 0.4, 0.5))
			b.annulus(0.5, 1.0, 14, Color(1.0, 0.9, 0.4, 0.5), Color(0.3, 1.0, 0.7, 0.0))
		return b.mesh())


## The crater of the dive (radius 1): a scorched bowl and jagged cracks lit jade from inside.
static func crack_mesh() -> ArrayMesh:
	return K.cached("dive_cracks", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 13
		b.annulus(0.0, 0.42, 20, Color(0.02, 0.1, 0.08, 0.8), Color(0.03, 0.12, 0.1, 0.6))
		b.annulus(0.42, 0.7, 20, Color(0.03, 0.12, 0.1, 0.6), Color(0.03, 0.12, 0.1, 0.0))
		for i in 11:
			var a := TAU * i / 11.0 + rng.randf_range(-0.15, 0.15)
			var reach := rng.randf_range(0.6, 1.0)
			var here := Vector3(sin(a), 0, cos(a)) * 0.1
			var width := 0.055
			for k in 5:
				a += rng.randf_range(-0.3, 0.3)
				var next := here + Vector3(sin(a), 0, cos(a)) * reach / 5.0
				var side := Vector3(cos(a), 0, -sin(a))
				var thin := width * (1.0 - (k + 1) / 5.0)
				b.quad(here - side * width + Vector3.UP * 0.005, here + side * width + Vector3.UP * 0.005, next + side * thin + Vector3.UP * 0.005, next - side * thin + Vector3.UP * 0.005, Color(0.01, 0.07, 0.06, 0.95))
				b.quad(here - side * width * 0.45 + Vector3.UP * 0.012, here + side * width * 0.45 + Vector3.UP * 0.012, next + side * thin * 0.45 + Vector3.UP * 0.012, next - side * thin * 0.45 + Vector3.UP * 0.012, Color(0.65, 1.0, 0.8, 1.0), Color(0.2, 0.95, 0.6, 1.0))
				here = next
				width = thin
		return b.mesh())
