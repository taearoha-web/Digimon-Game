extends RefCounted
## Bard god skill: ซิมโฟนีแห่งทวยเทพ. A celestial orchestra: a curved stage of light
## with a giant golden harp, a violin, a horn and a drum floating in an arc over the
## field, a ribbon of staff lines carrying notes through the air. Each wave another
## instrument plays a visible wave of sound from its side; for the finale they strike
## together: a great bell tolls, its ring sweeps the field, notes and petals of light
## fountain up. Rose, gold and ivory with pastel rainbow accents. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const ID := "divine_symphony"
## The field camera looks down from behind the caster: the orchestra sits low and
## close round the back of the field so that view holds all of it.
const HARP := Vector3(-2.7, 0.0, 3.6)
const VIOLIN := Vector3(-6.6, 3.1, -0.4)
const HORN := Vector3(6.6, 3.1, -0.4)
const DRUM := Vector3(3.0, 2.3, 3.9)
const BELL := Vector3(0, 6.7, 1.2)
const HARP_SIZE := 0.7
const ROSE := Color("ff6fb5")
const ROSE_DK := Color("d6387f")
const ROSE_LT := Color("ffb3d6")
const GOLD := Color("ffd257")
const GOLD_DK := Color("dd9a22")
const IVORY := Color("fff8e6")
const RAINBOW := [Color("ff8fb4"), Color("ffc58a"), Color("fff09a"), Color("a6f0b6"), Color("9ad8ff"), Color("c9a8ff")]
const LOOK := {"rim_color": Color("fff6dc"), "rim": 0.5, "shadow_tint": Color(0.88, 0.62, 0.72)}
const BOB := {"flap": 0.22, "flap_rate": 2.6}
const RIBBON_SPACING := 2.2
## The ribbons rise out of the ground: this much of each path lies under it.
const LEAD := 24.0
static var _ribbons := {}


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := clampf(float(skill.get("radius", 9.0)), 4.0, 10.0)
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	# The bard: a ribbon of staff lines winds up round the body over a ring of rose light.
	_ribbon(art, "SymphonyCallRibbon", "call", time, 6.0, 9.0 + 16.0 * time / 1.5, {"girth": 0.34, "wave_amp": 0.08})
	K.put(art, K.VEIL, K.shock(ROSE, IVORY, GOLD), "SymphonyCallRing", Vector3.UP * 0.08, Vector3.ONE * 1.9, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.5, "spin": 1.0, "decay": 0.9}, {"opacity": 0.8})
	var ground := K.root(parent, Vector3(point.x, 0, point.z), time, "StarGodGround_" + ID, origin, art)
	if ground:
		# The stage rises with its harp; the instruments come down out of the sky.
		K.put(ground, K.SOLID, bandstand_mesh(), "GodStage", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, time, {"fade_in": 0.1, "decay": 1.0, "cull": 12.0}, LOOK.merged({"slide": Vector3(0, -8.5, 0), "slide_time": time * 0.7, "slide_ease": -2.4}))
		K.put(ground, K.SOLID, ensemble_mesh(), "GodOrchestra", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, time * 0.8, {"fade_in": 0.15, "decay": 1.0, "delay": time * 0.2, "cull": 14.0}, LOOK.merged(BOB).merged({"slide": Vector3(0, 9.0, 0), "slide_time": time * 0.6, "slide_ease": -2.4}))
		K.put(ground, K.VEIL, K.area_mark(ROSE, GOLD), "SymphonyArea", Vector3.UP * 0.07, Vector3.ONE * r, Vector3.ZERO, time, {"initial": 0.2, "grow_time": 0.45, "spin": 0.25, "decay": 0.97})
		_ribbon(ground, "SymphonyRibbon", "field", time, 4.0, 4.0 + 13.0 * time, {})
		ground._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var sky := K.root(parent, Vector3(point.x, 0, point.z), time, "StarGodSky_" + ID, origin, art)
	if sky:
		_lights(sky, time, true)
		K.put(sky, K.SOLID, confetti_mesh(), "SymphonyPetals", Vector3(0, 5.5, 0.0), Vector3(1.6, 0.4, 1.6), Vector3.ZERO, time, {"cull": 20.0, "decay": 0.9, "delay": time * 0.3}, LOOK.merged({"burst": 1.0, "gravity": 2.4, "drag": 2.0, "life": time}))
		sky._draw()
	return true


## Stage lighting: a warm aureole behind the harp and a fan of pastel beams.
static func _lights(art: StarSkillArt, seconds: float, gather: bool) -> void:
	var come := 0.3 if gather else 0.001
	K.put(art, K.GLOW, K.sprite(), "SymphonyAureole", HARP + Vector3(0, 2.6, 0.8), Vector3.ONE * 5.0, Vector3.ZERO, seconds, {"initial": 0.5 if gather else 1.0, "grow_time": 0.5, "fade_in": come, "decay": 0.8, "priority": -2}, {"radial": 1.5, "billboard": true, "tint": Color("ffd0a0"), "opacity": 0.45})
	K.put(art, K.VEIL, rays_mesh(), "SymphonyBeams", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, seconds, {"fade_in": come, "decay": 0.8, "priority": -1}, {"opacity": 0.9})


static func _target(index: int) -> Vector3:
	return [Vector3(-0.8, 1.2, 0.2), Vector3(-2.4, 1.2, -1.6), Vector3(2.4, 1.2, -1.6), Vector3(0.8, 1.0, 0.4)][index % 4]


static func _player(index: int) -> Vector3:
	return [HARP + Vector3(0, 2.6, -0.5), VIOLIN, HORN, DRUM + Vector3(0, 0.6, -0.8)][index % 4]


static func wave(art: StarSkillArt, parent: Node3D, skill: Dictionary, index: int, point: Vector3, source: Vector3) -> bool:
	var r := clampf(float(skill.get("radius", 9.0)), 4.0, 10.0)
	_stage(parent, r, point, source, index)
	var from := _player(index)
	var to := _target(index)
	var d := (to - from).normalized()
	var aim := Vector3(asin(-d.y), atan2(d.x, d.z), 0)
	var tone: Color = RAINBOW[[0, 4, 2, 5][index % 4]]
	var flight := 0.3
	# The instrument's voice: arcs of sound cross the air and break into notes.
	K.put(art, K.VEIL, arcs_mesh(), "SymphonySound", from + d * 1.2, Vector3.ONE * (5.6 if index == 3 else 4.8), aim, flight + 0.3, {"initial": 0.35, "grow_time": 0.8, "travel": (to - from) * 0.8, "fade_in": 0.04, "decay": 0.6, "front": true}, {"tint": IVORY.lerp(tone, 0.55)})
	K.put(art, K.SOLID, note_burst(), "SymphonyNotes", to + Vector3.UP * 0.4, Vector3.ONE * (1.25 if index == 3 else 1.0), Vector3(0, index * 1.4, 0), 1.2, {"cull": 14.0, "decay": 0.9, "delay": flight * 0.8}, LOOK.merged({"burst": 1.0, "gravity": 5.0, "drag": 1.6, "life": 1.1}))
	# The instrument that plays swells and flashes.
	var solo: Mesh = [harp_mesh(), violin_mesh(), horn_mesh(), drum_mesh()][index % 4]
	var seat: Vector3 = [HARP, VIOLIN, HORN, DRUM][index % 4]
	K.put(art, K.SOLID, solo, "SymphonySolo", seat, Vector3.ONE, Vector3.ZERO, 0.42, {"initial": 1.3, "grow_time": 0.7, "fade_in": 0.01, "decay": 0.7, "cull": 6.0}, LOOK.merged(BOB if index > 0 else {}).merged({"glow": 0.5, "glow_color": Color("fff3c8")}))
	K.put(art, K.VEIL, ripple_mesh(), "SymphonyRipple", Vector3(to.x, 0.1, to.z), Vector3.ONE * (r * 0.75 if index == 3 else r * 0.42), Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "decay": 0.4, "delay": flight * 0.8}, {"tint": IVORY.lerp(tone, 0.4)})
	if K.quality() == 2:
		K.put(art, K.GLOW, K.sprite(), "SymphonyFlash", seat + Vector3(0, 2.6 if index == 0 else 0.0, -0.8), Vector3.ONE * 4.5, Vector3.ZERO, 0.35, {"initial": 0.4, "grow_time": 0.4, "fade_in": 0.02, "decay": 0.3}, {"radial": 1.6, "billboard": true, "tint": IVORY.lerp(tone, 0.5), "opacity": 0.7})
	return true


## From the release on (the first beat the budget lets through): the orchestra plays over
## the field until the last note has fallen.
static func _stage(parent: Node3D, r: float, point: Vector3, source: Vector3, index: int) -> void:
	if parent.has_node(NodePath("StarGodSet_" + ID)):
		return
	var since := float(StarSkillData.GOD_BEATS[index])
	var stay := float(StarSkillData.GOD_BEATS[4]) - since + 1.8
	var art := K.root(parent, point, stay, "StarGodSet_" + ID, source)
	if not art:
		return
	K.put(art, K.SOLID, bandstand_mesh(), "GodStage", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, stay, {"fade_in": 0.001, "decay": 0.88, "cull": 12.0}, LOOK)
	K.put(art, K.SOLID, ensemble_mesh(), "GodOrchestra", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, stay, {"fade_in": 0.001, "decay": 0.88, "cull": 14.0}, LOOK.merged(BOB))
	K.put(art, K.VEIL, K.area_mark(ROSE, GOLD), "SymphonyArea", Vector3.UP * 0.07, Vector3.ONE * r, Vector3.ZERO, stay, {"spin": 0.25, "decay": 0.8, "fade_in": 0.001})
	_ribbon(art, "SymphonyRibbon", "field", stay, 4.0 + 13.0 * (1.5 + since), 4.0 + 13.0 * (1.5 + since + stay), {"fade_in": 0.001})
	if MemoryGuard.pressure == 0:
		_lights(art, stay, false)
	art._draw()


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	var r := clampf(float(skill.get("radius", 9.0)), 4.0, 10.0)
	_stage(parent, r, point, source, 4)
	# The great bell swings in and tolls; its ring sweeps the field.
	K.put(art, K.SOLID, bell_mesh(), "GodBell", BELL, Vector3.ONE * 1.55, Vector3.ZERO, 1.8, {"initial": 1.35, "grow_time": 0.12, "flap": 0.3, "flap_rate": 11.0, "fade_in": 0.01, "decay": 0.85, "cull": 20.0}, LOOK.merged({"slide": Vector3(0, 5.0, 0), "slide_time": 0.14, "slide_ease": 2.0, "shadow_tint": Color(1.0, 0.72, 0.5)}))
	K.put(art, K.VEIL, ripple_mesh(), "SymphonyToll", Vector3.UP * 0.12, Vector3.ONE * r * 1.15, Vector3.ZERO, 0.85, {"initial": 0.08, "grow_time": 0.8, "fade_in": 0.02, "decay": 0.45}, {"tint": Color("fff0c8")})
	K.put(art, K.SOLID, note_fountain(), "SymphonyFountain", Vector3.UP * 0.4, Vector3.ONE, Vector3.ZERO, 1.8, {"cull": 24.0, "decay": 0.92}, LOOK.merged({"burst": 1.0, "gravity": 12.0, "drag": 0.5, "life": 1.7}))
	K.put(art, K.SOLID, confetti_mesh(), "SymphonyConfetti", Vector3.UP * 1.0, Vector3.ONE, Vector3.ZERO, 1.9, {"cull": 24.0, "decay": 0.92}, LOOK.merged({"burst": 1.0, "gravity": 6.5, "drag": 1.3, "life": 1.85}))
	K.put(art, K.VEIL, K.column("rose_pillar", [Color(1.0, 0.8, 0.6, 0.6), Color(1.0, 0.45, 0.7, 0.45), Color(1.0, 0.75, 0.4, 0.25), Color(1.0, 0.85, 0.6, 0.0)], 0.75, 16), "SymphonyPillar", Vector3.ZERO, Vector3(1.8, 6.0, 1.8), Vector3.ZERO, 0.9, {"initial": 0.4, "grow_time": 0.15, "fade_in": 0.02, "decay": 0.35}, {"noise_amt": 0.6, "noise_scale": Vector2(8.0, 1.2), "flow": Vector2(0.3, -3.0), "bias": -0.3, "taper": 0.3, "fres": 0.6})
	K.put(art, K.VEIL, K.shock(GOLD, IVORY, ROSE), "SymphonyBellRing", BELL + Vector3.DOWN * 4.1, Vector3.ONE * r * 0.7, Vector3.ZERO, 0.7, {"initial": 0.1, "grow_time": 0.8, "fade_in": 0.02, "decay": 0.4}, {"opacity": 0.85})
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	# Tutti: every instrument swells at once and throws its sound at the centre.
	var avatar := K.root(parent, point, 1.9, "StarGodAvatar_" + ID, source)
	if avatar:
		K.put(avatar, K.VEIL, tutti_mesh(), "SymphonyTutti", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.75, {"initial": 1.12, "grow_time": 0.9, "fade_in": 0.03, "decay": 0.45, "cull": 10.0}, {"tint": Color("fff0d8")})
		K.put(avatar, K.SOLID, ensemble_mesh(), "SymphonyStrike", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.45, {"initial": 1.1, "grow_time": 0.7, "fade_in": 0.01, "decay": 0.6, "cull": 14.0}, LOOK.merged(BOB).merged({"glow": 0.55, "glow_color": Color("fff3c8")}))
		K.put(avatar, K.SOLID, rainbow_mesh(), "SymphonyRainbow", Vector3(0, 0.0, 2.2), Vector3(8.6, 5.6, 8.6), Vector3(0.25, 0, 0), 1.8, {"initial": 0.3, "grow_time": 0.2, "fade_in": 0.1, "decay": 0.6}, LOOK)
		avatar._draw()
	if extras < 2:
		return true
	var temple := K.root(parent, point, 2.1, "StarGodTemple_" + ID, source)
	if temple:
		_ribbon(temple, "SymphonyCrescendo", "rise", 1.6, 4.0, 62.0, {"fade_in": 0.02, "decay": 0.8})
		K.put(temple, K.SOLID, confetti_mesh(), "SymphonyShower", Vector3(0, 4.5, 0), Vector3(2.2, 0.5, 2.2), Vector3(0, 1.0, 0), 2.0, {"cull": 24.0, "decay": 0.9, "delay": 0.1}, LOOK.merged({"burst": 1.0, "gravity": 3.2, "drag": 1.6, "life": 1.9}))
		K.put(temple, K.VEIL, K.sprite(), "SymphonyAfterglow", Vector3.UP * 0.2, Vector3.ONE * r * 0.9, Vector3(-PI / 2, 0, 0), 1.9, {"fade_in": 0.05, "decay": 0.35, "priority": -1}, {"radial": 1.2, "tint": Color("ff9ccc"), "opacity": 0.5})
		temple._draw()
	return true


# ---------------------------------------------------------------------------
# The staff ribbon
# ---------------------------------------------------------------------------
static func _ribbon_points(which: String) -> PackedVector3Array:
	if not _ribbons.has(which):
		var way := []
		match which:
			"call":
				# A helix up round the bard.
				way.append(Vector3(0, -LEAD, 1.5))
				for i in 40:
					var a := i * 0.55
					way.append(Vector3(sin(a), 0, cos(a)) * (1.5 - i * 0.008) + Vector3.UP * (0.3 + i * 0.075))
			"rise":
				# A spiral climbing round the centre of the field.
				way.append(Vector3(0, -LEAD, 6.8))
				for i in 36:
					var a := i * 0.42
					way.append(Vector3(sin(a), 0, cos(a)) * (6.8 - i * 0.12) + Vector3.UP * (0.8 + i * 0.17))
			_:
				# Out of the harp, a long wavy lap and a half round the field.
				way.append(HARP + Vector3(0, -LEAD, 0))
				way.append(HARP + Vector3(0, -8.0, 0))
				way.append(HARP + Vector3(0, 3.0, 0))
				for i in 34:
					var a := 0.35 + i * 0.3
					way.append(Vector3(sin(a) * 7.4, 2.5 + 0.9 * sin(i * 0.9) - 0.14 * cos(a) * 6.4, cos(a) * 6.4 - 0.6))
		_ribbons[which] = K.resample(K.smooth(way, 6), RIBBON_SPACING)
	return _ribbons[which]


static func _ribbon(art: StarSkillArt, label: String, which: String, seconds: float, from: float, to: float, extra: Dictionary) -> void:
	var points := _ribbon_points(which)
	var params := K.path_params(points, RIBBON_SPACING, 0, points.size() - 1, [[0.0, LEAD + from], [seconds, LEAD + to]])
	params.merge(LOOK)
	params.merge({"ref_up": Vector3(0, 0.75, -0.66), "wave_amp": 0.3, "wave_len": 7.0, "wave_speed": 4.0, "girth": 1.25})
	var style := {"fade_in": 0.08, "decay": 0.9, "cull": 60.0}
	for key in ["fade_in", "decay"]:
		if extra.has(key): style[key] = extra[key]
	for key in ["girth", "wave_amp"]:
		if extra.has(key): params[key] = extra[key]
	K.put(art, K.PATH, ribbon_mesh(), label, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, seconds, style, params)


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
## A note in the builder's XY plane (head at the origin, stem up), facing -Z.
static func _note(b: K.Builder, tone: Color) -> void:
	var head := [Vector3.ZERO]
	for j in 9:
		var a := TAU * j / 8.0
		head.append(Vector3(cos(a) * 0.34 * cos(0.35) - sin(a) * 0.25 * sin(0.35), cos(a) * 0.34 * sin(0.35) + sin(a) * 0.25 * cos(0.35), 0))
	b.fan(head, tone.lerp(Color.WHITE, 0.35), tone)
	b.quad(Vector3(0.25, 0.05, 0), Vector3(0.33, 0.05, 0), Vector3(0.33, 1.15, 0), Vector3(0.25, 1.15, 0), tone)
	b.tri3(Vector3(0.33, 1.15, 0), Vector3(0.33, 0.78, 0), Vector3(0.74, 0.58, 0), tone, tone, tone.lerp(Color.WHITE, 0.5))


## Five staff lines 22 m long along +Z (1.7 m wide, pointed at both ends) with notes riding them.
static func ribbon_mesh() -> ArrayMesh:
	return K.cached("staff_ribbon", func():
		var b := K.Builder.new()
		var long := 22.0
		var step := 0.55
		b.emit = 0.55
		for line in 5:
			var x := (line - 2) * 0.42
			var z := 0.0
			while z < long - 0.01:
				var w0 := sin(PI * clampf(z / long, 0.0, 1.0)) * 0.9 + 0.1
				var w1 := sin(PI * clampf((z + step) / long, 0.0, 1.0)) * 0.9 + 0.1
				var tone := GOLD.lerp(IVORY, 0.5 + 0.5 * sin(z * 0.9 + line))
				b.quad(Vector3((x - 0.06) * w0, 0, z), Vector3((x + 0.06) * w0, 0, z), Vector3((x + 0.06) * w1, 0, z + step), Vector3((x - 0.06) * w1, 0, z + step), tone)
				z += step
		b.emit = 0.75
		var count := 0
		var zn := 1.4
		while zn < long - 1.5:
			var on: int = [0, 3, 1, 4, 2, 3, 0, 2][count % 8]
			var w := sin(PI * zn / long) * 0.9 + 0.1
			b.xf = Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)).scaled(Vector3.ONE * 0.95), Vector3((on - 2) * 0.42 * w, 0.03, zn))
			_note(b, RAINBOW[count % RAINBOW.size()])
			count += 1
			zn += 1.35
		b.xf = Transform3D.IDENTITY
		b.emit = 1.0
		b.gem(Vector3(0, 0, 0.2), Vector3(0.3, 0.3, 0.5), IVORY, GOLD)
		return b.mesh())


static func _harp(b: K.Builder, at: Transform3D) -> void:
	b.xf = at
	# Plinth.
	b.box(Vector3(0, 0.25, 0), Vector3(4.2, 0.5, 1.5), ROSE_DK, ROSE)
	b.emit = 0.3
	b.box(Vector3(0, 0.52, -0.02), Vector3(4.3, 0.1, 1.56), GOLD)
	b.emit = 0.0
	# Pillar, soundboard and the swan-neck.
	b.tube([Vector3(1.7, 0.5, 0), Vector3(1.7, 3.4, 0), Vector3(1.7, 6.3, 0)], [0.24, 0.17, 0.2], 8, [[GOLD, GOLD_DK]], Vector3.BACK)
	b.ball(Vector3(1.7, 6.5, 0), Vector3(0.36, 0.36, 0.36), GOLD, GOLD_DK, 7, 5)
	b.tube([Vector3(-2.0, 6.0, 0), Vector3(-1.0, 3.9, 0), Vector3(0.3, 1.6, 0), Vector3(1.3, 0.5, 0)], [Vector2(0.26, 0.34), Vector2(0.32, 0.42), Vector2(0.34, 0.44), Vector2(0.3, 0.38)], 8, [[GOLD, GOLD_DK]], Vector3.BACK)
	b.tube([Vector3(1.7, 6.4, 0), Vector3(0.9, 7.05, 0), Vector3(-0.2, 6.5, 0), Vector3(-1.2, 6.45, 0), Vector3(-2.05, 6.0, 0), Vector3(-2.5, 6.4, 0), Vector3(-2.3, 6.9, 0)], [0.2, 0.2, 0.18, 0.18, 0.2, 0.14, 0.0], 7, [[GOLD, GOLD_DK]], Vector3.BACK)
	# Strings of light.
	b.emit = 1.0
	for k in 13:
		var f := k / 12.0
		var x := lerpf(-1.75, 1.35, f)
		var foot := lerpf(5.5, 0.75, f)
		var head := 6.4 + 0.45 * sin(f * PI) * (1.0 if f > 0.45 else 0.3)
		b.quad(Vector3(x - 0.028, foot, -0.05), Vector3(x + 0.028, foot, -0.05), Vector3(x + 0.028, head, -0.05), Vector3(x - 0.028, head, -0.05), IVORY if k % 3 else ROSE_LT)
	# A rose gem on the pillar, wings of ivory behind the soundboard.
	b.gem(Vector3(1.7, 7.05, 0), Vector3(0.24, 0.36, 0.24), ROSE, ROSE_LT)
	b.emit = 0.25
	for side in [-1.0, 1.0]:
		for k in 4:
			var root := Vector3(side * (1.9 if side > 0.0 else 2.2), 4.4 - k * 0.5, 0.25)
			b.tri3(root + Vector3(0, 0.45, 0), root - Vector3(0, 0.45, 0), root + Vector3(side * (3.6 - k * 0.55), 1.6 - k * 0.75, 0.5), IVORY, IVORY, ROSE_LT)
	b.emit = 0.0
	b.xf = Transform3D.IDENTITY


static func _violin(b: K.Builder, at: Transform3D) -> void:
	b.xf = at * Transform3D(Basis.from_euler(Vector3(0.1, 0.25, -0.55)).scaled(Vector3.ONE * 1.5), Vector3.ZERO)
	b.ball(Vector3(0, -0.75, 0), Vector3(0.82, 0.78, 0.2), ROSE, ROSE_DK, 10, 5)
	b.ball(Vector3(0, 0.38, 0), Vector3(0.64, 0.62, 0.19), ROSE, ROSE_DK, 10, 5)
	b.emit = 0.3
	b.box(Vector3(0, -0.2, 0.0), Vector3(1.0, 0.5, 0.3), GOLD_DK, GOLD)
	b.emit = 0.0
	b.box(Vector3(0, 1.3, -0.13), Vector3(0.22, 2.0, 0.1), Color("7a2456"), Color("a03a74"))
	b.box(Vector3(0, 2.45, -0.02), Vector3(0.2, 0.5, 0.22), GOLD_DK, GOLD)
	b.ball(Vector3(0, 2.82, -0.02), Vector3(0.22, 0.22, 0.2), GOLD, GOLD_DK, 6, 4)
	for side in [-1.0, 1.0]:
		b.cone(Vector3(side * 0.1, 2.4, 0), Vector3(side * 0.42, 2.45, 0), 0.07, 4, GOLD, IVORY)
		b.quad(Vector3(side * 0.3, -0.5, -0.2), Vector3(side * 0.37, -0.5, -0.2), Vector3(side * 0.33, 0.0, -0.19), Vector3(side * 0.26, 0.0, -0.19), Color("5a163e"))
	b.box(Vector3(0, -0.55, -0.24), Vector3(0.42, 0.1, 0.08), IVORY)
	b.box(Vector3(0, -1.15, -0.2), Vector3(0.2, 0.5, 0.06), Color("7a2456"))
	b.emit = 1.0
	for k in 3:
		var x := (k - 1) * 0.07
		b.quad(Vector3(x - 0.014, -0.95, -0.27), Vector3(x + 0.014, -0.95, -0.27), Vector3(x + 0.014, 2.3, -0.2), Vector3(x - 0.014, 2.3, -0.2), IVORY)
	b.emit = 0.3
	# The bow lies across the strings.
	b.tube([Vector3(-1.5, -1.0, -0.42), Vector3(1.5, 0.6, -0.42)], [0.045, 0.03], 5, [GOLD])
	b.quad(Vector3(-1.45, -1.08, -0.4), Vector3(1.45, 0.5, -0.4), Vector3(1.45, 0.53, -0.4), Vector3(-1.45, -1.05, -0.4), IVORY)
	b.emit = 0.0
	b.xf = Transform3D.IDENTITY


static func _horn(b: K.Builder, at: Transform3D) -> void:
	# Its bell opens towards the centre of the field.
	var d := Vector3(-0.8, -0.3, -0.52).normalized()
	var side := d.cross(Vector3.UP).normalized()
	var frame := at * Transform3D(Basis(d, side.cross(d), side).scaled(Vector3.ONE * 1.5), Vector3.ZERO)
	# The bell: a flare turned about the horn's own X axis.
	b.xf = frame * Transform3D(Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), Vector3(-0.2, 0, 0))
	b.lathe([[0.13, 0.0, GOLD_DK], [0.17, 0.75, GOLD], [0.3, 1.2, GOLD], [0.62, 1.5, GOLD], [1.05, 1.68, IVORY]], 14)
	b.lathe([[0.13, 0.7, ROSE_DK], [0.3, 1.2, ROSE_DK], [1.0, 1.66, ROSE]], 14)
	b.xf = frame
	var coil := []
	for k in 15:
		var a := TAU * k / 14.0
		coil.append(Vector3(-0.55 + cos(a) * 0.62, sin(a) * 0.62, 0.0))
	b.tube(coil, [0.12], 6, [[GOLD, GOLD_DK]], Vector3.BACK, false)
	b.tube([Vector3(-1.05, 0.45, 0), Vector3(-1.7, 0.55, 0), Vector3(-2.2, 0.55, 0)], [0.1, 0.08, 0.06], 6, [[GOLD, GOLD_DK]], Vector3.BACK)
	b.cone(Vector3(-2.2, 0.55, 0), Vector3(-2.45, 0.55, 0), Vector2(0.14, 0.14), 6, IVORY, GOLD, Vector3.BACK)
	for k in 3:
		b.tube([Vector3(-0.8 + k * 0.25, 0.25, 0), Vector3(-0.8 + k * 0.25, 0.95, 0)], [0.09, 0.09], 6, [GOLD_DK, IVORY], Vector3.BACK)
	b.xf = Transform3D.IDENTITY


static func _drum(b: K.Builder, at: Transform3D) -> void:
	# Tipped forward so its head shows.
	b.xf = at * Transform3D(Basis.from_euler(Vector3(-0.8, -0.2, 0.1)).scaled(Vector3.ONE * 1.3), Vector3.ZERO)
	b.lathe([[1.3, -0.62, ROSE_DK], [1.38, -0.58, GOLD_DK], [1.38, -0.44, GOLD], [1.3, -0.42, ROSE_DK], [1.36, 0.0, ROSE], [1.3, 0.42, ROSE], [1.38, 0.44, GOLD], [1.38, 0.58, GOLD], [1.3, 0.62, IVORY]], 16)
	b.emit = 0.35
	b.annulus(0.0, 1.3, 16, IVORY, Color("ffe6ee"), 0.62)
	b.emit = 0.0
	b.annulus(0.0, 1.3, 16, ROSE_DK, ROSE_DK, -0.62)
	b.emit = 0.4
	for k in 8:
		var a := TAU * k / 8.0
		b.gem(Vector3(sin(a) * 1.38, 0.0, cos(a) * 1.38), Vector3(0.12, 0.2, 0.12), GOLD, IVORY)
	# Two sticks over the head.
	for side in [-1.0, 1.0]:
		var tip := Vector3(side * 0.35, 0.95, 0.1)
		b.tube([Vector3(side * 1.5, 2.1, -0.5), tip], [0.06, 0.05], 5, [IVORY])
		b.ball(tip, Vector3(0.16, 0.16, 0.16), GOLD, GOLD_DK, 6, 4)
	b.emit = 0.0
	b.xf = Transform3D.IDENTITY


## The curved stage of light (two risers on the far side of the field) and the harp on it.
static func bandstand_mesh() -> ArrayMesh:
	return K.cached("bandstand", func():
		var b := K.Builder.new()
		b.emit = 0.4
		b.lathe([[8.9, 0.0, ROSE_DK], [8.9, 0.9, Color("ffc4dc")], [7.4, 0.9, IVORY], [7.2, 0.9, GOLD], [7.2, 0.45, Color("ffdcea")], [6.0, 0.45, IVORY], [5.8, 0.45, GOLD], [5.8, 0.0, GOLD_DK]], 30, -1.25, 1.25)
		# Footlights along the front edge.
		b.emit = 1.0
		for k in 9:
			var a := lerpf(-1.1, 1.1, k / 8.0)
			b.gem(Vector3(sin(a), 0, cos(a)) * 5.9 + Vector3.UP * 0.62, Vector3(0.18, 0.26, 0.18), RAINBOW[k % RAINBOW.size()], IVORY)
		b.emit = 0.0
		_harp(b, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * HARP_SIZE), HARP))
		return b.mesh())


static func harp_mesh() -> ArrayMesh:
	return K.cached("harp", func():
		var b := K.Builder.new()
		_harp(b, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * HARP_SIZE), Vector3.ZERO))
		return b.mesh())


static func _solo(key: String, part: Callable, phase: float) -> ArrayMesh:
	return K.cached(key, func():
		var b := K.Builder.new()
		b.weight = 1.0
		b.phase = phase
		part.call(b, Transform3D.IDENTITY)
		return b.mesh())


static func violin_mesh() -> ArrayMesh:
	return _solo("violin", func(b: K.Builder, at: Transform3D): _violin(b, at), 0.0)


static func horn_mesh() -> ArrayMesh:
	return _solo("horn", func(b: K.Builder, at: Transform3D): _horn(b, at), 0.37)


static func drum_mesh() -> ArrayMesh:
	return _solo("drum", func(b: K.Builder, at: Transform3D): _drum(b, at), 0.7)


## The violin, the horn and the drum in their arc over the field, each bobbing on its own beat.
static func ensemble_mesh() -> ArrayMesh:
	return K.cached("ensemble", func():
		var b := K.Builder.new()
		b.weight = 1.0
		b.phase = 0.0
		_violin(b, Transform3D(Basis.IDENTITY, VIOLIN))
		b.phase = 0.37
		_horn(b, Transform3D(Basis.IDENTITY, HORN))
		b.phase = 0.7
		_drum(b, Transform3D(Basis.IDENTITY, DRUM))
		return b.mesh())


## The great bell hanging under its pivot (radius 1, 2.7 tall).
static func bell_mesh() -> ArrayMesh:
	return K.cached("bell", func():
		var b := K.Builder.new()
		b.box(Vector3(0, -0.12, 0), Vector3(0.9, 0.24, 0.3), GOLD_DK, GOLD)
		b.tube([Vector3(0, -0.2, 0), Vector3(0, -0.55, 0)], [0.16, 0.2], 6, [GOLD_DK], Vector3.BACK)
		b.lathe([[1.08, -2.68, IVORY], [1.02, -2.55, Color("ffe07a")], [0.85, -2.3, GOLD], [0.68, -1.8, GOLD], [0.6, -1.2, Color("ffe07a")], [0.5, -0.7, GOLD], [0.3, -0.52, GOLD], [0.0, -0.5, IVORY]], 18)
		b.lathe([[0.45, -1.2, ROSE_DK], [0.66, -2.2, ROSE_DK], [0.98, -2.64, ROSE]], 18)
		b.emit = 0.4
		b.lathe([[0.66, -1.6, IVORY], [0.68, -1.52, ROSE_LT], [0.65, -1.45, IVORY]], 18)
		b.lathe([[1.03, -2.54, IVORY], [1.02, -2.48, ROSE_LT], [0.97, -2.42, IVORY]], 18)
		b.emit = 0.0
		b.tube([Vector3(0, -1.2, 0), Vector3(0, -2.5, 0)], [0.06, 0.08], 5, [GOLD_DK], Vector3.BACK)
		b.emit = 0.5
		b.ball(Vector3(0, -2.7, 0), Vector3(0.24, 0.24, 0.24), ROSE, ROSE_DK, 7, 5)
		return b.mesh())


## Four arcs of sound of growing radius, opening along +Z, flat and upright.
static func arcs_mesh() -> ArrayMesh:
	return K.cached("sound_arcs", func():
		var b := K.Builder.new()
		for plane in 2:
			b.xf = Transform3D(Basis.IDENTITY if plane == 0 else Basis(Vector3.BACK, PI / 2), Vector3.ZERO)
			for k in 4:
				var radius := 0.4 + 0.2 * k
				var half := 0.95 - 0.1 * k
				var soft := Color(1.0, 0.55, 0.8, 0.0)
				var crest := Color(1.0, 0.98, 0.92, 1.0 - 0.1 * k)
				b.annulus(radius - 0.1, radius - 0.035, 14, soft, Color(1.0, 0.6, 0.82, 0.8), 0.0, -half, half)
				b.annulus(radius - 0.035, radius, 14, crest, crest, 0.0, -half, half)
				b.annulus(radius, radius + 0.03, 14, Color(1.0, 0.82, 0.4, 0.9), Color(1.0, 0.85, 0.6, 0.0), 0.0, -half, half)
		return b.mesh())


## Three thin rings spreading on the ground (radius 1).
static func ripple_mesh() -> ArrayMesh:
	return K.cached("sound_ripple", func():
		var b := K.Builder.new()
		for k in 3:
			var radius := 1.0 - 0.24 * k
			var crest := Color(1.0, 0.98, 0.9, 0.95 - 0.2 * k)
			b.annulus(radius - 0.11, radius - 0.02, 40, Color(1.0, 0.6, 0.8, 0.0), crest)
			b.annulus(radius - 0.02, radius, 40, crest, Color(1.0, 0.85, 0.5, 0.9))
			b.annulus(radius, radius + 0.03, 40, Color(1.0, 0.85, 0.5, 0.9), Color(1.0, 0.85, 0.5, 0.0))
		return b.mesh())


## Every instrument's sound thrown at the centre at once (in the stage's own space).
static func tutti_mesh() -> ArrayMesh:
	return K.cached("tutti", func():
		var b := K.Builder.new()
		var k := 0
		for from in [HARP + Vector3(0, 2.6, -0.5), VIOLIN, HORN, DRUM + Vector3(0, 0.6, -0.8)]:
			var d: Vector3 = (Vector3(0, 1.4, 0.0) - from).normalized()
			var side := d.cross(Vector3.UP).normalized()
			var tone: Color = RAINBOW[[0, 4, 2, 5][k]]
			for plane in 2:
				var across := side if plane == 0 else d.cross(side)
				b.xf = Transform3D(Basis(across, d.cross(across), d).scaled(Vector3.ONE * 4.6), from + d * 0.8)
				for ring in 4:
					var radius := 0.4 + 0.2 * ring
					var half := 0.9 - 0.1 * ring
					var crest := Color(1.0, 0.98, 0.92, 0.9 - 0.12 * ring).lerp(Color(tone, 0.9), 0.35)
					b.annulus(radius - 0.06, radius, 12, Color(tone, 0.0), crest, 0.0, -half, half)
					b.annulus(radius, radius + 0.02, 12, crest, Color(tone, 0.0), 0.0, -half, half)
			k += 1
		return b.mesh())


## Stage lighting: pastel spotlights from high on both wings crossing over the field, each with its pool of light.
static func rays_mesh() -> ArrayMesh:
	return K.cached("spotlights", func():
		var b := K.Builder.new()
		var feet := [Vector3(-2.5, 0.1, -1.0), Vector3(3.0, 0.1, 1.5), Vector3(0.5, 0.1, -3.5), Vector3(2.5, 0.1, -1.0), Vector3(-3.0, 0.1, 1.5), Vector3(-0.5, 0.1, 3.0)]
		for k in feet.size():
			var top := Vector3(-11.0 if k < 3 else 11.0, 10.0, -1.0)
			var foot: Vector3 = feet[k]
			var along := (foot - top).normalized()
			var side := along.cross(Vector3.UP).normalized()
			var tone: Color = RAINBOW[(k * 2 + (0 if k < 3 else 1)) % RAINBOW.size()]
			for across in [side, side.cross(along)]:
				b.quad(top - across * 0.1, top + across * 0.1, foot + across * 1.2, foot - across * 1.2, Color(tone, 0.34), Color(tone.lerp(Color.WHITE, 0.3), 0.12))
			b.xf = Transform3D(Basis.IDENTITY, foot)
			b.annulus(0.0, 1.0, 14, Color(tone.lerp(Color.WHITE, 0.4), 0.42), Color(tone, 0.3))
			b.annulus(1.0, 1.5, 14, Color(tone, 0.3), Color(tone, 0.0))
			b.xf = Transform3D.IDENTITY
		return b.mesh())


## A pastel rainbow arching over the back of the field (radius 1, in the XY plane).
static func rainbow_mesh() -> ArrayMesh:
	return K.cached("rainbow", func():
		var b := K.Builder.new()
		b.xf = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO)
		b.emit = 0.75
		for k in RAINBOW.size():
			var outer := 1.0 - 0.045 * k
			var tone: Color = RAINBOW[k]
			b.annulus(outer - 0.045, outer, 40, tone, tone.lerp(Color.WHITE, 0.25), 0.0, -PI * 0.5, PI * 0.5)
		return b.mesh())


static func _notes(key: String, count: int, seed_value: int, launch: Callable) -> ArrayMesh:
	return K.cached(key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		b.emit = 0.7
		for i in count:
			var shot: Array = launch.call(i, rng)
			b.piece(shot[0], shot[1], shot[2], 0.0, Basis.from_euler(Vector3(0, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.5, 0.5))).scaled(Vector3.ONE * rng.randf_range(0.9, 1.5)))
			_note(b, RAINBOW[i % RAINBOW.size()].lerp(ROSE if i % 2 == 0 else GOLD, 0.25))
		return b.mesh())


## Notes breaking outward from where a wave of sound lands (burst).
static func note_burst() -> ArrayMesh:
	return _notes("note_burst", 14, 3, func(i: int, rng: RandomNumberGenerator) -> Array:
		var a := TAU * i / 14.0 + rng.randf_range(-0.2, 0.2)
		var out := Vector3(sin(a), 0, cos(a))
		return [out * rng.randf_range(0.2, 0.8), out * rng.randf_range(3.0, 6.5) + Vector3.UP * rng.randf_range(3.5, 7.5), rng.randf_range(0.0, 0.08)])


## A fountain of notes from the centre of the field (burst).
static func note_fountain() -> ArrayMesh:
	return _notes("note_fountain", 30, 8, func(i: int, rng: RandomNumberGenerator) -> Array:
		var a := rng.randf() * TAU
		var out := Vector3(sin(a), 0, cos(a))
		return [out * rng.randf_range(0.2, 1.4), out * rng.randf_range(1.0, 5.5) + Vector3.UP * rng.randf_range(10.0, 17.0), rng.randf_range(0.0, 0.45)])


## Petals and confetti of pastel light thrown up from a 3 m disc, fluttering (burst).
static func confetti_mesh() -> ArrayMesh:
	return K.cached("confetti", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 12
		b.emit = 0.5
		for i in 64:
			var a := rng.randf() * TAU
			var out := Vector3(sin(a), 0, cos(a))
			b.piece(out * rng.randf_range(0.3, 3.0) + Vector3.UP * rng.randf_range(0.0, 1.2), out * rng.randf_range(1.5, 7.0) + Vector3.UP * rng.randf_range(5.0, 12.0), rng.randf_range(0.0, 0.3), rng.randf_range(5.0, 11.0), Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)))
			var tone: Color = RAINBOW[i % RAINBOW.size()] if i % 3 else ROSE_LT
			var s := rng.randf_range(0.16, 0.3)
			if i % 3 == 0:
				b.fan([Vector3.ZERO, Vector3(0, -s, 0), Vector3(s * 0.6, 0, 0.05), Vector3(0, s, 0), Vector3(-s * 0.6, 0, 0.05), Vector3(0, -s, 0)], Color.WHITE, tone)
			else:
				b.quad(Vector3(-s * 0.5, -s * 0.28, 0), Vector3(s * 0.5, -s * 0.28, 0), Vector3(s * 0.5, s * 0.28, 0), Vector3(-s * 0.5, s * 0.28, 0), tone, tone.lerp(Color.WHITE, 0.4))
		return b.mesh())
