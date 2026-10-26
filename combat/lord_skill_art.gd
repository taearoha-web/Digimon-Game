class_name LordSkillArt
extends SculptureArt
## The Dark Lord's art: every skill of the line (25) and its four star skills get
## their own layered composition of royal sculptures. Royal seals turn under the
## Lord, crowns and scepters of light rise and fall, war banners and great feathered
## wings unfold for his commands, shadow ravens wheel out and dive, dark comets and
## force lances fly, fire tongues ring the field, lightning bolts drop from a storm
## and the earth splits with stone spikes and shockwaves. The Lord's raven gets its
## own strike art (raven_peck): claw cuts and scattering feathers on one monster, a
## dark shockwave and converging shadow ravens on a pack.
##
## Five palettes by the skill's colour: royal gold, dark force violet, ember fire,
## storm lightning and blood. Built on SculptureArt (shadow_ink for the dark bodies,
## shadow_glow for the light); a few sculptures are borrowed from the Assassin's
## (ShadowSkillArt: crescent, smoke, vortex, eclipse, rift). Cosmetic only: it
## never selects victims, deals damage or changes timing.

const KINDS := "raven feather regalia scepter seal pillar shock spikes flame bolt comet banner shield plumes orb"
const BORROWED := ["crescent", "smoke", "vortex", "eclipse", "rift"]
## [primary, accent, shade] palettes.
const ROYAL := [Color("ffcf5a"), Color("fff6d8"), Color("2a1606")]
const FORCE := [Color("8a4dff"), Color("f0e2ff"), Color("140828")]
const EMBER := [Color("ff6a2a"), Color("fff0b0"), Color("2a0805")]
const STORM := [Color("7ab8ff"), Color("f4fbff"), Color("0a1230")]
const BLOOD := [Color("ff3a4a"), Color("ffe0e4"), Color("2a0510")]
const STAR_PALETTES := {"chaos_inferno": "ember", "raven_sovereign": "force", "lords_dominion": "royal", "imperial_cataclysm": "royal"}
const CONTACT_GAP_MS := 90
const PECK_GAP_MS := 120
static var _meshes: Dictionary = {}
static var _last_contact: Dictionary = {}
static var _last_peck := -100000


static func handles(skill: Dictionary) -> bool:
	return not skill.is_empty() and SkillShow.family_of(skill) == "darklord"


## The palette of a skill: fire, lightning, royal gold or dark force by its colour.
static func palette(skill: Dictionary) -> Array:
	var id := String(skill.get("id", ""))
	if STAR_PALETTES.has(id):
		return _named(STAR_PALETTES[id])
	var color: Color = skill.get("color", FORCE[0])
	if color.is_equal_approx(Color("ff6a2a")):
		return EMBER
	if color.is_equal_approx(Color("8fd8ff")):
		return STORM
	if color.is_equal_approx(Color("e8b64a")):
		return ROYAL
	return FORCE


static func _named(name: String) -> Array:
	match name:
		"ember": return EMBER
		"storm": return STORM
		"royal": return ROYAL
		"blood": return BLOOD
	return FORCE


static func layer_cap() -> int:
	return int([6, 11, 18][VfxBudget.quality()] * MemoryGuard.effect_scale())


func _sculpture(kind: String) -> ArrayMesh:
	return mesh(kind)


static func warm_geometry() -> void:
	for kind in KINDS.split(" "):
		mesh(kind)


## Draws both materials once, invisibly, so the first cast does not stall on a phone.
static func warm_up(parent: Node3D, at: Vector3) -> void:
	warm_geometry()
	var art := _root(parent, at, "LordArt_Warm")
	art.cap = 2
	art.layer("seal", true, ROYAL, Vector3.UP, Vector3.ONE * 0.01, Vector3.ZERO, 0.0, 0.3, {"opacity": 0.001})
	art.layer("raven", false, FORCE, Vector3.UP, Vector3.ONE * 0.01, Vector3.ZERO, 0.0, 0.3, {"opacity": 0.001})


static func _root(parent: Node3D, at: Vector3, label: String) -> LordSkillArt:
	var art := LordSkillArt.new()
	art.name = label
	art.cap = layer_cap()
	parent.add_child(art)
	art.global_position = at
	return art


# ---------------------------------------------------------------------------
# Entry points
# ---------------------------------------------------------------------------

## Wind-up: the Lord's power gathers. A royal seal turns at his feet and light
## gathers on the scepter; from Lv.40 two shadow ravens wheel over him; from Lv.80
## a crown of light rises over his head in a faint pillar. Bound to the caster's
## skill generation (a cancel drops it).
static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, aim: Vector3, duration: float, visual: HeroVisual = null) -> void:
	if not handles(skill) or not _alive(parent) or duration < 0.12 or not VfxBudget.can_decorate(4 + RESERVE):
		return
	var c := palette(skill)
	var level := int(skill.get("level", 1))
	var time := maxf(duration, 0.15)
	var art := _root(parent, origin, "LordArt_Windup_" + String(skill.get("id", "")))
	art.rotation.y = _yaw(origin, aim)
	if visual:
		art.owner_ref = weakref(visual)
		art.generation = visual.skill_generation
	art.layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 1.3, Vector3.ZERO, 0.0, time + 0.08, {"initial": 0.2, "grow": 1.3, "spin": 1.8, "decay": 0.85, "fade_in": 0.3})
	art.layer("orb", true, c, Vector3(0.3, 1.55, 0.35), Vector3.ONE * 0.28, Vector3.ZERO, 0.0, time + 0.05, {"initial": 0.1, "grow": 1.2, "spin": 4.0, "decay": 0.9, "fade_in": 0.25})
	if level >= 40 or skill.has("star"):
		for i in 2:
			art.layer("raven", false, FORCE, Vector3(0, 2.3 + 0.2 * i, 0), Vector3.ONE * 0.45, Vector3(0, float(i) * PI, 0), 0.0, time + 0.1,
				{"initial": 0.6, "orbit": 1.1, "orbit_speed": 3.2, "phase": float(i) * PI, "flap": 0.15, "fade_in": 0.3, "decay": 0.8, "opacity": 0.85})
	if level >= 80 or skill.has("star"):
		art.layer("regalia", true, ROYAL, Vector3(0, 2.4, 0), Vector3.ONE * 0.55, Vector3.ZERO, 0.0, time + 0.1, {"initial": 0.2, "grow": 1.3, "spin": 1.5, "decay": 0.85, "fade_in": 0.35, "travel": Vector3(0, 0.3, 0)})
		art.layer("pillar", true, c, Vector3.ZERO, Vector3(0.9, 3.2, 0.9), Vector3.ZERO, 0.0, time + 0.1, {"initial": 0.3, "grow": 1.5, "fade_in": 0.4, "decay": 0.8, "opacity": 0.35})


## Release: the skill's own composition, at the same beat as its damage.
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, delay := 0.0) -> void:
	if not handles(skill) or not _alive(parent) or skill.has("star") or not VfxBudget.can_decorate(3 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var shape := String(skill.get("shape", "single"))
	var c := palette(skill)
	var at := center if shape == "blast" else origin
	var art := _root(parent, Vector3(at.x, origin.y, at.z), "LordArt_" + id)
	art.rotation.y = _yaw(origin, center)
	var reach := Vector2(center.x - origin.x, center.z - origin.z).length()
	var radius := float(skill.get("radius", 3.0))
	art._compose(id, c, reach, radius, maxf(delay, 0.0))


## Every hit: a small mark of the skill's element on the victim (one per gap).
static func contact(parent: Node3D, skill: Dictionary, at: Vector3) -> void:
	if not handles(skill) or skill.has("star") or not _alive(parent) or not VfxBudget.can_decorate(2 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var now := Time.get_ticks_msec()
	if now - int(_last_contact.get(id, -100000)) < CONTACT_GAP_MS:
		return
	_last_contact[id] = now
	var c := palette(skill)
	var art := _root(parent, at, "LordArt_Hit_" + id)
	art.cap = mini(art.cap, 3)
	var tilt := randf_range(-0.4, 0.4)
	if c == EMBER:
		art.layer("flame", true, c, Vector3(0, -0.6, 0), Vector3(0.8, 1.2, 0.8), Vector3.ZERO, 0.0, 0.45, {"initial": 0.3, "face_camera": true, "travel": Vector3(0, 0.3, 0)})
	elif c == STORM:
		art.layer("bolt", true, c, Vector3(0, -0.9, 0), Vector3(0.6, 1.8, 0.6), Vector3(0, 0, tilt * 0.3), 0.0, 0.25, {"initial": 0.9, "face_camera": true})
	else:
		art.layer("crescent", true, c, Vector3.ZERO, Vector3.ONE * 0.8, Vector3(0, 0, 0.9 + tilt), 0.0, 0.32, {"initial": 0.4, "roll": -6.0, "face_camera": true})
	art.layer("shock", true, c, Vector3(0, -0.95, 0), Vector3.ONE * 0.7, Vector3.ZERO, 0.02, 0.4, {"initial": 0.2, "grow": 5.0})
	if int(skill.get("level", 1)) >= 60:
		art.layer("feather", false, FORCE if c != FORCE else BLOOD, Vector3(0, 0.1, 0), Vector3.ONE * 0.5, Vector3(0, randf() * TAU, tilt), 0.0, 0.6, {"initial": 0.8, "travel": Vector3(randf_range(-0.6, 0.6), 0.5, randf_range(-0.6, 0.6)), "roll": 4.0, "face_camera": true})


## Star skills: one composition per contact beat of StarSkillSequence.
static func star(parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> void:
	if not handles(skill) or not _alive(parent) or not VfxBudget.can_decorate(3 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var c := palette(skill)
	var ground := Vector3(point.x, source.y, point.z)
	var art := _root(parent, ground, "LordArt_Star_%s_%d" % [id, index])
	art.rotation.y = _yaw(source, point)
	var radius := clampf(float(skill.get("radius", 6.0)), 3.0, 10.0)
	art._star(id, c, index, radius)


## The raven's strike (DarkRaven): on one monster, three claw cuts, feathers
## bursting out and a dark ring; on a pack, a shockwave out to the pack's edge, a
## dark vortex, shadow ravens converging on the point and a burst of feathers.
## [param at] is the body the raven struck, [param from] where it dived from.
static func raven_peck(parent: Node3D, at: Vector3, from: Vector3, group: bool) -> void:
	if not _alive(parent) or not VfxBudget.can_decorate((4 if group else 2) + RESERVE):
		return
	var now := Time.get_ticks_msec()
	if now - _last_peck < PECK_GAP_MS:
		return
	_last_peck = now
	var art := _root(parent, at, "LordArt_RavenPeck")
	art.rotation.y = _yaw(from, at)
	art.cap = mini(art.cap, 11 if group else 6)
	var c := FORCE
	var floor_y := -0.95
	for k in 3:
		var tilt := (float(k) - 1.0) * 0.32
		art.layer("crescent", true, c if k != 1 else BLOOD, Vector3((float(k) - 1.0) * 0.12, 0.05, 0), Vector3.ONE * 0.75, Vector3(0, 0, 0.9 + tilt), 0.015 * k, 0.3, {"initial": 0.35, "roll": -7.0, "face_camera": true})
	for k in 3:
		var a := randf() * TAU
		art.layer("feather", false, c, Vector3.ZERO, Vector3.ONE * 0.45, Vector3(0, a, randf_range(-1.0, 1.0)), 0.02, 0.7, {"initial": 0.9, "travel": Vector3(cos(a), 0.6 + randf() * 0.5, sin(a)) * 0.9, "roll": randf_range(-6.0, 6.0), "face_camera": true, "decay": 0.5})
	if not group:
		art.layer("shock", true, c, Vector3(0, floor_y, 0), Vector3.ONE * 0.8, Vector3.ZERO, 0.02, 0.45, {"initial": 0.2, "grow": 5.0})
		return
	var r := DarkRaven.GROUP_RADIUS
	art.layer("rift", false, c, Vector3(0, floor_y + 0.02, 0), Vector3.ONE * r * 0.55, Vector3.ZERO, 0.0, 0.8, {"initial": 0.3, "opacity": 0.8})
	art.layer("shock", true, c, Vector3(0, floor_y, 0), Vector3.ONE * r, Vector3.ZERO, 0.0, 0.6, {"initial": 0.15, "grow": 4.0, "opacity": 0.5})
	art.layer("vortex", true, c, Vector3(0, floor_y + 0.03, 0), Vector3.ONE * r * 0.8, Vector3.ZERO, 0.0, 0.7, {"initial": 0.3, "spin": 6.0, "opacity": 0.5})
	for k in 3:
		var a := float(k) * TAU / 3.0 + randf() * 0.5
		var out := Vector3(sin(a), 0.0, cos(a)) * r * 0.9
		art.layer("raven", false, c, out + Vector3(0, 0.6, 0), Vector3.ONE * 0.4, Vector3(0.5, a + PI, 0), 0.0, 0.45, {"initial": 1.0, "travel": -out + Vector3(0, -0.4, 0), "accelerate": true, "flap": 0.25, "decay": 0.6})
	art.layer("pillar", true, c, Vector3(0, floor_y, 0), Vector3(0.6, 2.4, 0.6), Vector3.ZERO, 0.05, 0.4, {"initial": 0.3, "grow": 6.0, "opacity": 0.6})


# ---------------------------------------------------------------------------
# Compositions
# ---------------------------------------------------------------------------

## A dark lance (comet) from the scepter to [param to], landing after [param flight].
func _lance(c: Array, to: Vector3, start: float, flight: float, size := 0.55, yaw := 0.0) -> void:
	var from := Vector3(0.25, 1.3, 0.5)
	layer("comet", true, c, from, Vector3.ONE * size, Vector3(0, yaw, 0), start, flight + 0.05, {"initial": 0.9, "travel": to - from, "accelerate": true, "decay": 0.9})


## A ring of fire tongues round [param at].
func _flame_ring(c: Array, at: Vector3, radius: float, count: int, start: float, height := 1.4, seconds := 0.9) -> void:
	for k in count:
		var a := float(k) * TAU / float(count)
		var spot := at + Vector3(sin(a), 0, cos(a)) * radius
		layer("flame", true, c, spot, Vector3(height * 0.55, height, height * 0.55), Vector3.ZERO, start + 0.02 * float(k % 3), seconds, {"initial": 0.2, "grow": 3.0, "face_camera": true, "travel": Vector3(0, 0.25, 0)})


## Lightning bolts dropping round [param at] (a storm over an area).
func _bolt_rain(c: Array, at: Vector3, radius: float, count: int, start: float, height := 4.0) -> void:
	for k in count:
		var a := float(k) * 2.39996 + 0.4
		var spot := at + Vector3(sin(a), 0, cos(a)) * radius * sqrt(float(k + 1) / float(count))
		layer("bolt", true, c, spot, Vector3(0.9, height, 0.9), Vector3(0, 0, randf_range(-0.12, 0.12)), start + 0.07 * float(k), 0.28, {"initial": 1.0, "face_camera": true})
		layer("shock", true, c, spot + Vector3.UP * 0.03, Vector3.ONE * 0.9, Vector3.ZERO, start + 0.07 * float(k), 0.45, {"initial": 0.2, "grow": 5.0})


## A war banner planted at [param at], rising out of the ground.
func _banner(c: Array, at: Vector3, yaw: float, start: float, seconds := 1.6, size := 1.0) -> void:
	layer("banner", false, c, at + Vector3(0, -0.6, 0), Vector3.ONE * size, Vector3(0, yaw, 0), start, seconds, {"initial": 1.0, "travel": Vector3(0, 0.6, 0), "flap": 0.05, "fade_in": 0.1, "decay": 0.75})


## Shadow ravens flying out from the Lord along [param count] headings over [param spread].
func _raven_flight(c: Array, count: int, spread: float, distance: float, start: float, size := 0.55) -> void:
	for k in count:
		var a := (float(k) / maxf(1.0, float(count - 1)) - 0.5) * spread if count > 1 else 0.0
		var dir := Vector3(sin(a), 0, cos(a))
		layer("raven", false, c, Vector3(0, 1.4 + 0.15 * float(k % 2), 0.3), Vector3.ONE * size, Vector3(0, a, 0), start + 0.03 * float(k), 0.6, {"initial": 0.7, "travel": dir * distance + Vector3(0, -0.4, 0), "flap": 0.3, "decay": 0.75})
		if k % 2 == 0:
			layer("feather", false, c, Vector3(0, 1.3, 0.4), Vector3.ONE * 0.35, Vector3(0, a, 0.6), start + 0.05 + 0.03 * float(k), 0.7, {"initial": 0.9, "travel": dir * distance * 0.5 + Vector3(0, 0.6, 0), "roll": 5.0, "face_camera": true})


func _compose(id: String, c: Array, reach: float, radius: float, d: float) -> void:
	var target := Vector3(0, 0, reach)
	var r := minf(radius, 9.5)
	match id:
		"force":
			layer("orb", true, c, Vector3(0.25, 1.3, 0.5), Vector3.ONE * 0.4, Vector3.ZERO, d, 0.3, {"initial": 0.3, "grow": 6.0, "spin": 6.0})
			_lance(c, target + Vector3.UP * 1.0, d, 0.22)
			layer("orb", false, c, target + Vector3.UP * 1.0, Vector3.ONE * 0.6, Vector3.ZERO, d + 0.22, 0.45, {"initial": 0.3, "grow": 6.0})
			layer("shock", true, c, target + Vector3.UP * 0.04, Vector3.ONE * 1.2, Vector3.ZERO, d + 0.22, 0.5, {"initial": 0.2, "grow": 5.0})
			layer("crescent", true, c, target + Vector3.UP * 1.0, Vector3.ONE * 0.9, Vector3(0, 0, 0.8), d + 0.24, 0.3, {"initial": 0.4, "roll": -6.0, "face_camera": true})
		"critical_damage":
			layer("seal", true, ROYAL, Vector3(0, 0.05, 0), Vector3.ONE * 2.2, Vector3.ZERO, d, 1.3, {"initial": 0.2, "spin": 1.6})
			layer("regalia", true, ROYAL, Vector3(0, 2.3, 0), Vector3.ONE * 0.6, Vector3.ZERO, d + 0.05, 1.2, {"initial": 0.3, "spin": 2.0, "travel": Vector3(0, 0.4, 0)})
			for i in 3:
				layer("crescent", true, BLOOD if i == 1 else ROYAL, Vector3(0, 0.5 + 0.5 * i, 0), Vector3.ONE * (1.0 - 0.12 * i), Vector3(PI * 0.5, i * 2.1, 0), d + 0.06 * i, 0.9, {"initial": 0.4, "spin": 8.0 - 2.0 * i, "travel": Vector3(0, 0.6, 0)})
			_x_cut(BLOOD, Vector3(0, 1.4, 0.6), 1.0, d + 0.1)
		"fire_burst":
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.85, Vector3.ZERO, d, 0.9, {"initial": 0.3, "spin": 2.4})
			layer("orb", true, c, Vector3(0, 0.8, 0), Vector3.ONE * 0.9, Vector3.ZERO, d, 0.45, {"initial": 0.2, "grow": 6.0})
			_flame_ring(c, Vector3.ZERO, r * 0.45, 6, d + 0.04, 1.6, 0.8)
			layer("shock", true, c, Vector3(0, 0.04, 0), Vector3.ONE * r, Vector3.ZERO, d + 0.02, 0.6, {"initial": 0.15, "grow": 4.0})
			layer("smoke", false, c, Vector3.ZERO, Vector3(r * 0.35, r * 0.25, r * 0.35), Vector3.ZERO, d + 0.15, 1.0, {"initial": 0.3, "opacity": 0.45})
		"summon":
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 3.0, Vector3.ZERO, d, 1.6, {"initial": 0.2, "spin": 1.2})
			layer("pillar", true, c, Vector3.ZERO, Vector3(1.3, 4.5, 1.3), Vector3.ZERO, d, 1.2, {"initial": 0.3, "grow": 3.0, "opacity": 0.6})
			layer("vortex", true, c, Vector3(0, 0.08, 0), Vector3.ONE * 2.4, Vector3.ZERO, d, 1.3, {"initial": 0.2, "spin": -3.0})
			for i in 4:
				var a := float(i) * TAU / 4.0
				layer("raven", false, c, Vector3(0, 1.6 + 0.3 * float(i % 2), 0), Vector3.ONE * 0.5, Vector3(0, a, 0), d + 0.05 * i, 1.2, {"initial": 0.6, "orbit": 1.6, "orbit_speed": 4.0, "phase": a, "flap": 0.25, "travel": Vector3(0, 1.2, 0)})
			layer("regalia", true, ROYAL, Vector3(0, 2.6, 0), Vector3.ONE * 0.5, Vector3.ZERO, d + 0.1, 1.2, {"initial": 0.3, "spin": 2.0})
		"earthshake":
			layer("scepter", true, ROYAL, Vector3(0, 2.2, 0.8), Vector3.ONE * 1.3, Vector3(PI, 0, 0), d, 0.35, {"initial": 1.0, "travel": Vector3(0, -2.0, 0), "accelerate": true, "decay": 0.7})
			for i in 3:
				layer("shock", true, c, Vector3(0, 0.04 + 0.01 * i, 0), Vector3.ONE * r * (0.55 + 0.25 * i), Vector3.ZERO, d + 0.1 * i, 0.6, {"initial": 0.15, "grow": 4.0})
			layer("spikes", false, c, Vector3.ZERO, Vector3(r * 0.6, 1.2, r * 0.6), Vector3.ZERO, d + 0.08, 1.0, {"initial": 0.2, "grow": 6.0})
			layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * r * 0.55, Vector3.ZERO, d + 0.05, 1.2, {"initial": 0.3})
			layer("smoke", false, c, Vector3.ZERO, Vector3(r * 0.4, 0.8, r * 0.4), Vector3.ZERO, d + 0.12, 1.0, {"initial": 0.3, "opacity": 0.4})
		"force_wave":
			layer("orb", true, c, Vector3(0.25, 1.3, 0.5), Vector3.ONE * 0.5, Vector3.ZERO, d, 0.35, {"initial": 0.3, "grow": 6.0})
			for i in 3:
				var a := (float(i) - 1.0) * 0.38
				var dir := Vector3(sin(a), 0, cos(a))
				layer("crescent", true, c if i != 1 else BLOOD, Vector3(0, 1.0, 0.6), Vector3(1.6, 1.0, 1.0), Vector3(0, a, 0), d + 0.03 * i, 0.5, {"initial": 0.5, "travel": dir * 9.0, "decay": 0.7})
				layer("shock", true, c, dir * 4.0 + Vector3.UP * 0.04, Vector3.ONE * 1.0, Vector3.ZERO, d + 0.18 + 0.03 * i, 0.4, {"initial": 0.2, "grow": 5.0})
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 1.4, Vector3.ZERO, d, 0.7, {"initial": 0.4, "spin": 3.0})
		"electric_spike":
			layer("bolt", true, c, target, Vector3(1.6, 7.0, 1.6), Vector3.ZERO, d, 0.35, {"initial": 1.0, "face_camera": true})
			layer("pillar", true, c, target, Vector3(0.8, 5.0, 0.8), Vector3.ZERO, d, 0.4, {"initial": 0.5, "grow": 6.0, "opacity": 0.55})
			layer("shock", true, c, target + Vector3.UP * 0.04, Vector3.ONE * 2.2, Vector3.ZERO, d + 0.03, 0.5, {"initial": 0.15, "grow": 5.0})
			_bolt_rain(c, target, 3.0, 3, d + 0.12, 2.6)
			layer("orb", true, c, Vector3(0.25, 1.5, 0.4), Vector3.ONE * 0.45, Vector3.ZERO, d, 0.4, {"initial": 0.3, "grow": 6.0, "spin": 8.0})
		"fire_scream":
			# The scream: waves rolling from the Lord to the burst (the art sits on the burst).
			for i in 3:
				layer("crescent", true, c, Vector3(0, 1.3, 0.6 - reach), Vector3(1.4 + 0.3 * i, 1.0, 1.0), Vector3.ZERO, d + 0.05 * i, 0.4, {"initial": 0.4, "travel": Vector3(0, -0.6, reach - 0.6), "decay": 0.6})
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.8, Vector3.ZERO, d + 0.15, 1.0, {"initial": 0.3, "spin": -2.0})
			_flame_ring(c, Vector3.ZERO, r * 0.55, 8, d + 0.2, 2.0, 1.0)
			layer("orb", true, c, Vector3(0, 1.0, 0), Vector3.ONE * 1.1, Vector3.ZERO, d + 0.2, 0.5, {"initial": 0.2, "grow": 6.0})
			layer("smoke", false, c, Vector3.ZERO, Vector3(r * 0.45, r * 0.3, r * 0.45), Vector3.ZERO, d + 0.3, 1.2, {"initial": 0.3, "opacity": 0.4})
		"birds":
			_raven_flight(c, 5, 1.1, 9.0, d)
			layer("crescent", true, c, Vector3(0, 1.3, 0.4), Vector3(1.8, 1.0, 1.0), Vector3(PI * 0.5, 0, 0), d, 0.35, {"initial": 0.4})
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 1.4, Vector3.ZERO, d, 0.8, {"initial": 0.4, "spin": 2.4})
		"chaos_strike":
			layer("crescent", true, c, target + Vector3.UP * 1.2, Vector3.ONE * 2.2, Vector3(0, 0, 0.5), d, 0.45, {"initial": 0.3, "roll": -5.0, "face_camera": true})
			_x_cut(BLOOD, target + Vector3.UP * 1.0, 1.4, d + 0.08)
			layer("orb", false, c, target + Vector3.UP * 1.0, Vector3.ONE * 0.8, Vector3.ZERO, d + 0.05, 0.5, {"initial": 0.3, "grow": 5.0})
			layer("vortex", true, c, target + Vector3.UP * 0.05, Vector3.ONE * 1.6, Vector3.ZERO, d + 0.05, 0.8, {"initial": 0.3, "spin": 5.0})
			layer("shock", true, c, target + Vector3.UP * 0.04, Vector3.ONE * 1.8, Vector3.ZERO, d + 0.08, 0.5, {"initial": 0.2, "grow": 5.0})
		"iron_defense":
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 2.4, Vector3.ZERO, d, 1.4, {"initial": 0.2, "spin": 1.0})
			for i in 4:
				var a := float(i) * TAU / 4.0
				layer("shield", false, c, Vector3(0, 1.1, 0), Vector3.ONE * 0.75, Vector3(0, a, 0), d + 0.04 * i, 1.4, {"initial": 0.3, "grow": 3.0, "orbit": 1.2, "orbit_speed": 2.0, "phase": a, "decay": 0.75})
			layer("pillar", true, c, Vector3.ZERO, Vector3(1.4, 2.8, 1.4), Vector3.ZERO, d, 1.2, {"initial": 0.4, "grow": 3.0, "opacity": 0.4})
			layer("regalia", true, c, Vector3(0, 2.4, 0), Vector3.ONE * 0.45, Vector3.ZERO, d + 0.1, 1.1, {"initial": 0.3, "spin": 1.5})
		"commanders_aura":
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 2.8, Vector3.ZERO, d, 1.6, {"initial": 0.2, "spin": 1.0})
			for i in 3:
				var a := float(i) * TAU / 3.0 + PI
				_banner(c, Vector3(sin(a), 0, cos(a)) * 1.6, a, d + 0.06 * i)
			layer("regalia", true, c, Vector3(0, 2.5, 0), Vector3.ONE * 0.6, Vector3.ZERO, d + 0.1, 1.4, {"initial": 0.3, "spin": 1.6})
			for i in 2:
				layer("crescent", true, c, Vector3(0, 0.3, 0), Vector3.ONE * (1.3 + 0.3 * i), Vector3(PI * 0.5, i * PI, 0), d + 0.12 * i, 1.0, {"initial": 0.5, "spin": 5.0, "travel": Vector3(0, 2.0, 0)})
		"fire_blast":
			layer("orb", true, c, Vector3(0.25, 1.3, 0.5), Vector3.ONE * 0.55, Vector3.ZERO, d, 0.3, {"initial": 0.3, "grow": 6.0})
			_lance(c, target + Vector3.UP * 1.0, d, 0.24, 0.8)
			layer("flame", true, c, target, Vector3(1.4, 2.4, 1.4), Vector3.ZERO, d + 0.24, 0.7, {"initial": 0.2, "grow": 5.0, "face_camera": true})
			_flame_ring(c, target, 0.9, 4, d + 0.28, 1.0, 0.6)
			layer("shock", true, c, target + Vector3.UP * 0.04, Vector3.ONE * 1.8, Vector3.ZERO, d + 0.24, 0.5, {"initial": 0.2, "grow": 5.0})
			layer("smoke", false, c, target, Vector3.ONE * 0.8, Vector3.ZERO, d + 0.35, 0.9, {"initial": 0.3, "opacity": 0.45})
		"plasma_storm":
			layer("vortex", true, c, Vector3(0, 4.2, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, d, 1.3, {"initial": 0.2, "grow": 2.0, "spin": 3.0, "opacity": 0.75})
			layer("smoke", false, c, Vector3(0, 3.8, 0), Vector3(r * 0.5, 0.6, r * 0.5), Vector3.ZERO, d, 1.3, {"initial": 0.3, "opacity": 0.45, "spin": 0.6})
			_bolt_rain(c, Vector3.ZERO, r * 0.7, 6, d + 0.08, 4.2)
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.9, Vector3.ZERO, d, 1.2, {"initial": 0.3, "spin": -1.5})
		"chaotic_diseier":
			layer("eclipse", false, c, Vector3(0, 2.5, -0.6), Vector3.ONE * 0.8, Vector3.ZERO, d, 0.9, {"face_camera": true, "initial": 0.3, "roll": 1.5})
			for i in 6:
				var a := (float(i) / 5.0 - 0.5) * 1.2
				var dir := Vector3(sin(a), 0, cos(a))
				_lance(BLOOD if i % 2 == 1 else c, dir * 10.0 + Vector3.UP * 1.0, d + 0.02 * i, 0.35, 0.6, a)
			layer("vortex", true, c, Vector3(0, 1.3, 0.6), Vector3.ONE * 0.9, Vector3(PI * 0.5, 0, 0), d, 0.5, {"initial": 0.3, "roll": 8.0})
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 1.8, Vector3.ZERO, d, 0.9, {"initial": 0.3, "spin": 3.0})
		"royal_crush":
			layer("scepter", true, c, target + Vector3(0, 4.0, 0), Vector3.ONE * 2.0, Vector3(PI, 0, 0.3), d, 0.3, {"initial": 1.0, "travel": Vector3(0, -3.0, 0), "accelerate": true, "decay": 0.6})
			layer("regalia", true, c, target + Vector3.UP * 2.6, Vector3.ONE * 0.7, Vector3.ZERO, d + 0.2, 0.8, {"initial": 0.4, "spin": 3.0})
			for i in 2:
				layer("shock", true, c, target + Vector3.UP * (0.04 + 0.01 * i), Vector3.ONE * (2.0 + 1.0 * i), Vector3.ZERO, d + 0.22 + 0.08 * i, 0.55, {"initial": 0.15, "grow": 4.0})
			layer("spikes", false, c, target, Vector3(1.4, 0.9, 1.4), Vector3.ZERO, d + 0.24, 0.8, {"initial": 0.2, "grow": 6.0})
			layer("rift", false, c, target + Vector3.UP * 0.04, Vector3.ONE * 1.6, Vector3.ZERO, d + 0.22, 1.0, {"initial": 0.3})
		"thunder_lord":
			layer("regalia", true, c, Vector3(0, 2.6, 0), Vector3.ONE * 0.7, Vector3.ZERO, d, 1.0, {"initial": 0.3, "spin": 3.0})
			layer("pillar", true, c, Vector3.ZERO, Vector3(1.0, 3.6, 1.0), Vector3.ZERO, d, 0.7, {"initial": 0.4, "grow": 4.0, "opacity": 0.5})
			layer("bolt", true, c, target, Vector3(1.8, 7.5, 1.8), Vector3.ZERO, d + 0.05, 0.35, {"initial": 1.0, "face_camera": true})
			_bolt_rain(c, target, 4.0, 5, d + 0.12, 3.2)
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 2.0, Vector3.ZERO, d, 1.0, {"initial": 0.3, "spin": 2.0})
		"dark_comet":
			var sky := Vector3(-2.5, 11.0, -3.0)
			var fall := (-sky).normalized()
			layer("comet", true, c, sky, Vector3.ONE * 2.2, Vector3(asin(-fall.y), _yaw_of(fall), 0), 0.0, maxf(d, 0.3) + 0.05, {"initial": 0.6, "grow": 3.0, "travel": -sky + Vector3.UP * 0.5, "accelerate": true, "decay": 0.9})
			layer("eclipse", false, c, Vector3(0, 1.5, 0), Vector3.ONE * 1.6, Vector3.ZERO, d, 0.9, {"face_camera": true, "initial": 0.2, "grow": 5.0, "roll": 1.0})
			for i in 2:
				layer("shock", true, c, Vector3(0, 0.04 + 0.01 * i, 0), Vector3.ONE * r * (0.7 + 0.35 * i), Vector3.ZERO, d + 0.08 * i, 0.7, {"initial": 0.15, "grow": 4.0})
			layer("spikes", false, c, Vector3.ZERO, Vector3(r * 0.5, 1.4, r * 0.5), Vector3.ZERO, d + 0.05, 1.1, {"initial": 0.2, "grow": 6.0})
			layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * r * 0.6, Vector3.ZERO, d, 1.4, {"initial": 0.3})
			layer("smoke", false, c, Vector3.ZERO, Vector3(r * 0.45, r * 0.3, r * 0.45), Vector3.ZERO, d + 0.1, 1.3, {"initial": 0.3, "opacity": 0.45})
		"lord_of_command":
			layer("plumes", false, c, Vector3(0, 0.9, -0.5), Vector3.ONE * 1.4, Vector3.ZERO, d, 1.6, {"initial": 0.2, "grow": 3.0, "flap": 0.06, "face_camera": true})
			layer("regalia", true, c, Vector3(0, 2.6, 0), Vector3.ONE * 0.75, Vector3.ZERO, d + 0.05, 1.5, {"initial": 0.3, "spin": 1.6})
			for i in 4:
				var a := float(i) * TAU / 4.0 + PI * 0.25
				_banner(c, Vector3(sin(a), 0, cos(a)) * 1.9, a, d + 0.05 * i, 1.7, 1.1)
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 3.0, Vector3.ZERO, d, 1.7, {"initial": 0.2, "spin": 1.0})
			layer("pillar", true, c, Vector3.ZERO, Vector3(1.6, 4.0, 1.6), Vector3.ZERO, d, 1.3, {"initial": 0.3, "grow": 3.0, "opacity": 0.45})
		"infernal_scream":
			layer("eclipse", false, c, Vector3(0, 4.6, 0), Vector3.ONE * 1.6, Vector3.ZERO, d, 1.6, {"face_camera": true, "initial": 0.2, "grow": 2.0, "roll": 0.8})
			_flame_ring(c, Vector3.ZERO, r * 0.4, 6, d, 2.2, 1.1)
			_flame_ring(c, Vector3.ZERO, r * 0.8, 8, d + 0.15, 2.8, 1.2)
			for i in 2:
				layer("shock", true, c, Vector3(0, 0.04 + 0.01 * i, 0), Vector3.ONE * r * (0.6 + 0.4 * i), Vector3.ZERO, d + 0.1 * i, 0.7, {"initial": 0.15, "grow": 4.0})
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.95, Vector3.ZERO, d, 1.5, {"initial": 0.2, "spin": -1.2})
			layer("smoke", false, c, Vector3.ZERO, Vector3(r * 0.5, r * 0.3, r * 0.5), Vector3.ZERO, d + 0.3, 1.4, {"initial": 0.3, "opacity": 0.4})
		"chaos_sovereign":
			layer("eclipse", false, c, target + Vector3(0, 3.2, -0.4), Vector3.ONE * 1.2, Vector3.ZERO, d, 1.2, {"face_camera": true, "initial": 0.3, "roll": 1.2})
			layer("scepter", true, c, target + Vector3(0, 4.5, 0), Vector3.ONE * 2.2, Vector3(PI, 0, -0.3), d, 0.3, {"initial": 1.0, "travel": Vector3(0, -3.2, 0), "accelerate": true, "decay": 0.6})
			_x_cut(BLOOD, target + Vector3.UP * 1.2, 2.2, d + 0.22)
			for side in [-1.0, 1.0]:
				layer("raven", false, c, target + Vector3(side * 2.6, 2.6, -0.5), Vector3.ONE * 0.7, Vector3(0.6, side * -PI * 0.5, 0), d + 0.05, 0.4, {"initial": 1.0, "travel": Vector3(-side * 2.6, -1.6, 0.5), "accelerate": true, "flap": 0.3, "decay": 0.6})
			layer("rift", false, c, target + Vector3.UP * 0.04, Vector3.ONE * 2.2, Vector3.ZERO, d + 0.22, 1.3, {"initial": 0.3})
			layer("vortex", true, c, target + Vector3.UP * 0.06, Vector3.ONE * 2.4, Vector3.ZERO, d + 0.22, 1.0, {"initial": 0.3, "spin": 5.0})
			layer("shock", true, c, target + Vector3.UP * 0.04, Vector3.ONE * 3.0, Vector3.ZERO, d + 0.24, 0.6, {"initial": 0.15, "grow": 4.0})
		"raven_storm":
			layer("plumes", false, c, Vector3(0, 0.9, -0.5), Vector3.ONE * 1.3, Vector3.ZERO, d, 1.2, {"initial": 0.2, "grow": 3.0, "flap": 0.08, "face_camera": true})
			for i in 8:
				var a := float(i) * TAU / 8.0
				layer("raven", false, c, Vector3(0, 1.5 + 0.2 * float(i % 2), 0), Vector3.ONE * 0.6, Vector3(0, a, 0), d + 0.025 * i, 0.9, {"initial": 0.7, "orbit": 1.0, "orbit_speed": 5.0, "phase": a, "travel": Vector3(sin(a), -0.2, cos(a)) * 8.0, "flap": 0.3, "decay": 0.75})
			layer("vortex", true, c, Vector3(0, 0.08, 0), Vector3.ONE * 3.5, Vector3.ZERO, d, 1.1, {"initial": 0.2, "spin": 4.0})
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 2.2, Vector3.ZERO, d, 1.1, {"initial": 0.3, "spin": -2.0})
		"earth_dominion":
			layer("scepter", true, c, Vector3(0, 3.0, 0.9), Vector3.ONE * 1.6, Vector3(PI, 0, 0), d, 0.3, {"initial": 1.0, "travel": Vector3(0, -2.6, 0), "accelerate": true, "decay": 0.6})
			layer("spikes", false, c, Vector3.ZERO, Vector3(r * 0.45, 1.6, r * 0.45), Vector3.ZERO, d + 0.1, 1.2, {"initial": 0.2, "grow": 6.0})
			layer("spikes", false, c, Vector3.ZERO, Vector3(r * 0.8, 2.0, r * 0.8), Vector3(0, 0.26, 0), d + 0.2, 1.2, {"initial": 0.2, "grow": 6.0})
			for i in 3:
				layer("shock", true, c, Vector3(0, 0.04 + 0.01 * i, 0), Vector3.ONE * r * (0.45 + 0.3 * i), Vector3.ZERO, d + 0.1 * i, 0.7, {"initial": 0.15, "grow": 4.0})
			layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, d + 0.05, 1.5, {"initial": 0.3})
			layer("regalia", true, c, Vector3(0, 2.8, 0), Vector3.ONE * 0.7, Vector3.ZERO, d + 0.1, 1.2, {"initial": 0.3, "spin": 2.0})
		"emperors_command":
			layer("plumes", false, c, Vector3(0, 0.9, -0.5), Vector3.ONE * 1.8, Vector3.ZERO, d, 1.9, {"initial": 0.2, "grow": 2.5, "flap": 0.06, "face_camera": true})
			layer("regalia", true, c, Vector3(0, 2.8, 0), Vector3.ONE * 0.9, Vector3.ZERO, d + 0.05, 1.8, {"initial": 0.3, "spin": 1.4})
			for i in 6:
				var a := float(i) * TAU / 6.0
				_banner(c if i % 2 == 0 else FORCE, Vector3(sin(a), 0, cos(a)) * 2.6, a, d + 0.04 * i, 1.9, 1.2)
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 3.8, Vector3.ZERO, d, 1.9, {"initial": 0.2, "spin": 0.8})
			layer("pillar", true, c, Vector3.ZERO, Vector3(2.0, 5.5, 2.0), Vector3.ZERO, d, 1.5, {"initial": 0.3, "grow": 2.5, "opacity": 0.45})
			for i in 2:
				layer("crescent", true, c, Vector3(0, 0.3, 0), Vector3.ONE * (2.0 + 0.4 * i), Vector3(PI * 0.5, i * PI, 0), d + 0.15 * i, 1.2, {"initial": 0.5, "spin": 4.0, "travel": Vector3(0, 3.0, 0)})
		"imperial_judgment":
			layer("pillar", true, c, Vector3.ZERO, Vector3(2.2, 7.0, 2.2), Vector3.ZERO, d, 1.4, {"initial": 0.3, "grow": 3.0, "opacity": 0.55})
			layer("regalia", true, c, Vector3(0, 4.2, 0), Vector3.ONE * 1.2, Vector3.ZERO, d, 1.6, {"initial": 0.3, "spin": 2.0})
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.95, Vector3.ZERO, d, 1.7, {"initial": 0.2, "spin": 1.0})
			_bolt_rain(STORM, Vector3.ZERO, r * 0.75, 6, d + 0.1, 4.5)
			_flame_ring(EMBER, Vector3.ZERO, r * 0.5, 6, d + 0.2, 2.0, 1.0)
			layer("eclipse", false, FORCE, Vector3(0, 6.0, -0.5), Vector3.ONE * 2.0, Vector3.ZERO, d, 1.6, {"face_camera": true, "initial": 0.2, "grow": 2.0, "roll": 0.7})
			for i in 2:
				layer("shock", true, c, Vector3(0, 0.04 + 0.01 * i, 0), Vector3.ONE * r * (0.55 + 0.45 * i), Vector3.ZERO, d + 0.15 * i, 0.8, {"initial": 0.15, "grow": 4.0})
		_:
			layer("shock", true, c, target + Vector3.UP * 0.04, Vector3.ONE * 1.4, Vector3.ZERO, d, 0.5, {"initial": 0.2, "grow": 5.0})


func _star(id: String, c: Array, index: int, radius: float) -> void:
	match id:
		"chaos_inferno":
			if index == 0:
				layer("scepter", true, ROYAL, Vector3(0, 2.8, 0), Vector3.ONE * 1.8, Vector3(PI, 0, 0), 0.0, 0.3, {"initial": 1.0, "travel": Vector3(0, -2.4, 0), "accelerate": true, "decay": 0.6})
				layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * radius * 0.95, Vector3.ZERO, 0.0, 1.4, {"initial": 0.2, "spin": 1.5})
				_flame_ring(c, Vector3.ZERO, radius * 0.45, 7, 0.1, 2.2, 1.0)
				layer("shock", true, c, Vector3(0, 0.04, 0), Vector3.ONE * radius * 0.7, Vector3.ZERO, 0.08, 0.7, {"initial": 0.15, "grow": 4.0})
			else:
				_flame_ring(c, Vector3.ZERO, radius * 0.8, 9, 0.0, 3.0, 1.2)
				layer("eclipse", false, FORCE, Vector3(0, 4.5, 0), Vector3.ONE * 1.8, Vector3.ZERO, 0.0, 1.4, {"face_camera": true, "initial": 0.2, "grow": 2.5, "roll": 0.8})
				layer("shock", true, c, Vector3(0, 0.04, 0), Vector3.ONE * radius, Vector3.ZERO, 0.0, 0.8, {"initial": 0.15, "grow": 4.0})
				layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * radius * 0.6, Vector3.ZERO, 0.05, 1.4, {"initial": 0.3})
				layer("smoke", false, c, Vector3.ZERO, Vector3(radius * 0.45, radius * 0.3, radius * 0.45), Vector3.ZERO, 0.1, 1.4, {"initial": 0.3, "opacity": 0.4})
		"raven_sovereign":
			var final := index >= 5
			var side := 1.0 if index % 2 == 0 else -1.0
			var size := 2.0 if final else 0.9
			var from := Vector3(side * 3.0, 3.2 if final else 2.4, -1.0)
			layer("raven", false, c, from, Vector3.ONE * size, Vector3(0.5, _yaw_of(-from), 0), 0.0, 0.32, {"initial": 1.0, "travel": -from + Vector3.UP * 1.0, "accelerate": true, "flap": 0.3, "decay": 0.6})
			layer("crescent", true, c if index % 2 == 0 else BLOOD, Vector3.UP * 1.2, Vector3.ONE * (2.4 if final else 1.1), Vector3(0, 0, side * 0.9), 0.24, 0.35, {"initial": 0.3, "roll": -side * 7.0, "face_camera": true})
			for k in 2:
				var a := randf() * TAU
				layer("feather", false, c, Vector3.UP * 1.1, Vector3.ONE * 0.5, Vector3(0, a, 0), 0.25, 0.7, {"initial": 0.9, "travel": Vector3(cos(a), 0.7, sin(a)), "roll": 5.0, "face_camera": true})
			if final:
				layer("eclipse", false, c, Vector3(0, 3.2, 0), Vector3.ONE * 1.8, Vector3.ZERO, 0.2, 1.3, {"face_camera": true, "initial": 0.3, "roll": 1.2})
				layer("plumes", false, c, Vector3(0, 0.6, -0.4), Vector3.ONE * 1.8, Vector3.ZERO, 0.2, 1.2, {"initial": 0.2, "grow": 3.0, "flap": 0.08, "face_camera": true})
				layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * 2.6, Vector3.ZERO, 0.25, 1.3, {"initial": 0.2})
				layer("shock", true, c, Vector3(0, 0.04, 0), Vector3.ONE * 3.0, Vector3.ZERO, 0.25, 0.7, {"initial": 0.15, "grow": 4.0})
		"lords_dominion":
			layer("plumes", false, c, Vector3(0, 0.9, -0.5), Vector3.ONE * 2.0, Vector3.ZERO, 0.0, 2.0, {"initial": 0.2, "grow": 2.5, "flap": 0.06, "face_camera": true})
			layer("regalia", true, c, Vector3(0, 3.0, 0), Vector3.ONE * 1.0, Vector3.ZERO, 0.0, 1.9, {"initial": 0.3, "spin": 1.2})
			layer("seal", true, c, Vector3(0, 0.05, 0), Vector3.ONE * radius * 0.9, Vector3.ZERO, 0.0, 2.0, {"initial": 0.2, "spin": 0.8})
			layer("pillar", true, c, Vector3.ZERO, Vector3(2.2, 6.0, 2.2), Vector3.ZERO, 0.0, 1.6, {"initial": 0.3, "grow": 2.5, "opacity": 0.45})
			for i in 6:
				var a := float(i) * TAU / 6.0 + PI / 6.0
				_banner(c if i % 2 == 0 else FORCE, Vector3(sin(a), 0, cos(a)) * radius * 0.4, a, 0.05 * i, 2.0, 1.3)
		"imperial_cataclysm":
			var final := index >= 4
			if index == 0:
				layer("seal", true, c, Vector3(0, 0.06, 0), Vector3.ONE * radius * 0.95, Vector3.ZERO, 0.0, 2.6, {"initial": 0.2, "spin": 0.8, "decay": 0.85})
				layer("vortex", true, STORM, Vector3(0, 6.5, 0), Vector3.ONE * radius * 0.6, Vector3.ZERO, 0.0, 2.6, {"initial": 0.2, "spin": 2.0, "opacity": 0.7, "decay": 0.85})
			_bolt_rain(STORM, Vector3.ZERO, radius * 0.75, 3, 0.0, 5.0)
			_flame_ring(EMBER, Vector3.ZERO, radius * (0.3 + 0.12 * float(index)), 4, 0.05, 1.8, 0.8)
			if final:
				layer("pillar", true, c, Vector3.ZERO, Vector3(2.4, 8.0, 2.4), Vector3.ZERO, 0.05, 1.4, {"initial": 0.3, "grow": 3.0, "opacity": 0.6})
				layer("regalia", true, c, Vector3(0, 4.5, 0), Vector3.ONE * 1.4, Vector3.ZERO, 0.05, 1.4, {"initial": 0.3, "spin": 2.4})
				layer("eclipse", false, FORCE, Vector3(0, 6.5, 0), Vector3.ONE * 2.2, Vector3.ZERO, 0.05, 1.4, {"face_camera": true, "initial": 0.2, "roll": 0.8})
				layer("shock", true, c, Vector3(0, 0.04, 0), Vector3.ONE * radius, Vector3.ZERO, 0.1, 0.8, {"initial": 0.15, "grow": 4.0})


## Two crossed cuts at [param at].
func _x_cut(c: Array, at: Vector3, size: float, start := 0.0) -> void:
	layer("crescent", true, c, at, Vector3.ONE * size, Vector3(0, 0, 0.85), start, 0.42, {"initial": 0.35, "roll": -5.0, "face_camera": true})
	layer("crescent", true, FORCE if c != FORCE else BLOOD, at, Vector3.ONE * size, Vector3(0, 0, -0.85), start + 0.05, 0.42, {"initial": 0.35, "roll": 5.0, "face_camera": true})


## The yaw that points +Z along [param dir].
static func _yaw_of(dir: Vector3) -> float:
	return atan2(dir.x, dir.z) if Vector2(dir.x, dir.z).length_squared() > 0.0001 else 0.0


# ---------------------------------------------------------------------------
# Geometry (built once per kind, shared). COLOR.r = inlay / core heat,
# COLOR.g = opacity mask.
# ---------------------------------------------------------------------------

static func mesh(kind: String) -> ArrayMesh:
	if kind in BORROWED:
		return ShadowSkillArt.mesh(kind)
	if _meshes.has(kind):
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"raven": _raven(st)
		"feather": _feather(st, Vector3.ZERO, Vector3.UP, 1.0, 0.16)
		"regalia": _regalia(st)
		"scepter": _scepter(st)
		"seal": _seal(st)
		"pillar": _pillar(st)
		"shock": _shock(st)
		"spikes": _spikes(st)
		"flame": _flame(st)
		"bolt": _bolt(st)
		"comet": _comet(st)
		"banner": _banner_mesh(st)
		"shield": _shield(st)
		"plumes": _plumes(st)
		"orb": _orb(st)
	var result := st.commit()
	_meshes[kind] = result
	return result


## One feather from [param root] along [param dir] (in the plane facing [param face]):
## a bright shaft and a vane tapering to a rounded tip, darker at the edges.
static func _feather(st: SurfaceTool, root: Vector3, dir: Vector3, length: float, width: float, face := Vector3.BACK) -> void:
	var side := dir.cross(face).normalized()
	var rows := 6
	for i in rows:
		var t0 := float(i) / rows
		var t1 := float(i + 1) / rows
		var w0 := width * sin(PI * minf(1.0, 0.15 + t0 * 0.95)) * (1.0 - t0 * 0.25)
		var w1 := width * sin(PI * minf(1.0, 0.15 + t1 * 0.95)) * (1.0 - t1 * 0.25)
		var a := root + dir * length * t0
		var b := root + dir * length * t1
		var shaft := Color(0.85, 1, 0)
		var edge := Color(0.15, 0.7, 0)
		_quad(st, a, b, b + side * w1, a + side * w0, shaft, shaft, edge, edge)
		_quad(st, a - side * w0, b - side * w1, b, a, edge, edge, shaft, shaft)


static func _raven(st: SurfaceTool) -> void:
	# A shadow raven in flight, facing +Z, wings spread in the XZ plane (span ~2):
	# a body, head and heavy beak, two wings of fingered flight feathers and a
	# wedge tail; burning eyes.
	var body := Color(0, 1, 0)
	_tube(st, [Vector3(0, 0, -0.42), Vector3(0, 0.02, -0.1), Vector3(0, 0.04, 0.22), Vector3(0, 0.06, 0.38)], [0.05, 0.13, 0.11, 0.08], [body, body, body, body], 6)
	_sphere(st, Vector3(0, 0.08, 0.42), Vector3(0.1, 0.09, 0.11), body, 4, 8)
	_tube(st, [Vector3(0, 0.08, 0.5), Vector3(0, 0.06, 0.62), Vector3(0, 0.03, 0.7)], [0.045, 0.03, 0.004], [body, body, Color(0.3, 1, 0)], 4)
	for side in [-1.0, 1.0]:
		_sphere(st, Vector3(side * 0.06, 0.12, 0.48), Vector3.ONE * 0.022, Color(1, 1, 0), 2, 5)
		# The arm of the wing, then fingered primaries and a row of secondaries.
		var shoulder := Vector3(side * 0.08, 0.04, 0.1)
		var wrist := Vector3(side * 0.55, 0.1, 0.05)
		_tube(st, [shoulder, wrist], [0.06, 0.04], [body, body], 4)
		for k in 6:
			var t := float(k) / 5.0
			var root := shoulder.lerp(wrist, t)
			_feather(st, root, Vector3(side * 0.15, 0, -1.0).normalized(), 0.32 + 0.06 * t, 0.07, Vector3.UP)
		for k in 5:
			var a := deg_to_rad(-8.0 - 14.0 * float(k))
			var dir := Vector3(side * cos(a), 0.02 * float(k), sin(a)).normalized()
			_feather(st, wrist, dir, 0.55 - 0.05 * float(k), 0.075, Vector3.UP)
	# The wedge tail: the middle feathers longest.
	for k in 5:
		var a := (float(k) - 2.0) * 0.2
		_feather(st, Vector3(0, 0, -0.38), Vector3(sin(a), 0, -cos(a)), 0.42 - absf(float(k) - 2.0) * 0.06, 0.07, Vector3.UP)


static func _regalia(st: SurfaceTool) -> void:
	# A royal crown (radius 0.5, y 0 to 0.7): a jewelled band, five tall points
	# each tipped with an orb, and arches meeting under a cross-orb on top.
	var seg := 30
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var d0 := Vector3(sin(a0), 0, cos(a0)) * 0.5
		var d1 := Vector3(sin(a1), 0, cos(a1)) * 0.5
		_quad(st, d0, d1, d1 + Vector3.UP * 0.18, d0 + Vector3.UP * 0.18, Color(0.5, 1, 0), Color(0.5, 1, 0), Color(0.8, 1, 0), Color(0.8, 1, 0))
		if i % 6 == 3:
			_sphere(st, (d0 + d1) * 0.5 * 1.04 + Vector3.UP * 0.09, Vector3.ONE * 0.04, Color(1, 1, 0), 2, 5)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var dir := Vector3(sin(a), 0, cos(a))
		var side := Vector3(cos(a), 0, -sin(a))
		var base := dir * 0.5 + Vector3.UP * 0.18
		var tip := dir * 0.56 + Vector3.UP * 0.55
		_tri(st, base - side * 0.13, tip, base + side * 0.13, Color(0.6, 1, 0), Color(1, 1, 0), Color(0.6, 1, 0))
		_sphere(st, tip + Vector3.UP * 0.04, Vector3.ONE * 0.05, Color(1, 1, 0), 3, 6)
		# An arch from the point's base towards the top.
		_tube(st, [base + Vector3.UP * 0.05, dir * 0.32 + Vector3.UP * 0.55, Vector3.UP * 0.66], [0.02, 0.018, 0.015], [Color(0.7, 1, 0), Color(0.8, 1, 0), Color(1, 1, 0)], 4)
	_sphere(st, Vector3.UP * 0.72, Vector3.ONE * 0.07, Color(1, 1, 0), 3, 6)
	_tube(st, [Vector3.UP * 0.78, Vector3.UP * 0.92], [0.015, 0.015], [Color(1, 1, 0), Color(1, 1, 0)], 4)
	_tube(st, [Vector3(-0.05, 0.86, 0), Vector3(0.05, 0.86, 0)], [0.013, 0.013], [Color(1, 1, 0), Color(1, 1, 0)], 4)


static func _scepter(st: SurfaceTool) -> void:
	# A scepter along +Y (0 to 1.6): a ringed shaft, a crown of four prongs round a
	# glowing orb at the head and a pommel.
	var shaft := Color(0.5, 1, 0)
	_tube(st, [Vector3(0, 0, 0), Vector3(0, 1.25, 0)], [0.035, 0.03], [shaft, shaft], 6)
	for y in [0.2, 0.6, 1.0, 1.22]:
		_tube(st, [Vector3(0, y - 0.02, 0), Vector3(0, y + 0.02, 0)], [0.06, 0.06], [Color(0.9, 1, 0), Color(0.9, 1, 0)], 6)
	_sphere(st, Vector3(0, -0.04, 0), Vector3.ONE * 0.06, Color(0.9, 1, 0), 3, 6)
	_sphere(st, Vector3(0, 1.42, 0), Vector3.ONE * 0.15, Color(1, 1, 0), 4, 8)
	for k in 4:
		var a := TAU * float(k) / 4.0
		var dir := Vector3(sin(a), 0, cos(a))
		_tube(st, [Vector3(0, 1.24, 0), dir * 0.17 + Vector3.UP * 1.36, dir * 0.12 + Vector3.UP * 1.6], [0.025, 0.02, 0.004], [shaft, Color(0.8, 1, 0), Color(1, 1, 0)], 4)


static func _seal(st: SurfaceTool) -> void:
	# The Lord's seal on the ground (radius 1): two rings with a band of rune
	# ticks between them, an eight-pointed star and a crown at the heart.
	var up := Vector3.UP
	for ring in [[1.0, 0.03, 0.8], [0.86, 0.018, 0.6], [0.4, 0.02, 0.7]]:
		var r := float(ring[0])
		var w := float(ring[1])
		var tone := Color(float(ring[2]), 0.9, 0)
		for i in 56:
			var a0 := TAU * float(i) / 56.0
			var a1 := TAU * float(i + 1) / 56.0
			var d0 := Vector3(sin(a0), 0, cos(a0))
			var d1 := Vector3(sin(a1), 0, cos(a1))
			_quad(st, d0 * (r - w), d1 * (r - w), d1 * (r + w), d0 * (r + w), tone, tone, tone, tone)
	for k in 24:
		var a := TAU * float(k) / 24.0
		var dir := Vector3(sin(a), 0, cos(a))
		var length := 0.07 if k % 2 == 0 else 0.04
		_strip(st, dir * (0.93 - length * 0.5), dir * (0.93 + length * 0.5), 0.02, up, Color(1, 1, 0), Color(1, 1, 0))
	for k in 8:
		var a := TAU * float(k) / 8.0
		var b := TAU * float(k + 3) / 8.0
		_strip(st, Vector3(sin(a), 0, cos(a)) * 0.84, Vector3(sin(b), 0, cos(b)) * 0.84, 0.022, up, Color(0.55, 0.85, 0), Color(0.55, 0.85, 0))
	# The crown at the heart: a band and three points.
	for k in 3:
		var x := (float(k) - 1.0) * 0.12
		_tri(st, Vector3(x - 0.06, 0.002, -0.06), Vector3(x, 0.002, 0.12 + 0.05 * float(1 - absi(k - 1))), Vector3(x + 0.06, 0.002, -0.06), Color(1, 1, 0), Color(1, 1, 0), Color(1, 1, 0))
	_strip(st, Vector3(-0.2, 0.002, -0.09), Vector3(0.2, 0.002, -0.09), 0.06, up, Color(1, 1, 0), Color(1, 1, 0))


static func _pillar(st: SurfaceTool) -> void:
	# A column of light (radius 1, height 1), bright at the foot, fading upwards.
	var seg := 20
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		_quad(st, d0, d1, d1 * 0.85 + Vector3.UP * 0.5, d0 * 0.85 + Vector3.UP * 0.5, Color(0.9, 0.8, 0), Color(0.9, 0.8, 0), Color(0.5, 0.5, 0), Color(0.5, 0.5, 0))
		_quad(st, d0 * 0.85 + Vector3.UP * 0.5, d1 * 0.85 + Vector3.UP * 0.5, d1 * 0.7 + Vector3.UP, d0 * 0.7 + Vector3.UP, Color(0.5, 0.5, 0), Color(0.5, 0.5, 0), Color(0.2, 0, 0), Color(0.2, 0, 0))


static func _shock(st: SurfaceTool) -> void:
	# A shockwave on the ground (radius 1): a bright front with a ragged edge,
	# trailing off inwards.
	var seg := 40
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		var o0 := 1.0 + 0.06 * sin(a0 * 7.0)
		var o1 := 1.0 + 0.06 * sin(a1 * 7.0)
		_quad(st, d0 * 0.6, d1 * 0.6, d1 * 0.9, d0 * 0.9, Color(0.1, 0, 0), Color(0.1, 0, 0), Color(0.7, 0.8, 0), Color(0.7, 0.8, 0))
		_quad(st, d0 * 0.9, d1 * 0.9, d1 * o1, d0 * o0, Color(0.7, 0.8, 0), Color(0.7, 0.8, 0), Color(1, 1, 0), Color(1, 1, 0))


static func _spikes(st: SurfaceTool) -> void:
	# Twelve jagged stone spikes bursting from the ground in a ring (radius 1),
	# leaning outwards, glowing cracks at their feet.
	for k in 12:
		var a := TAU * float(k) / 12.0 + (0.12 if k % 2 == 1 else 0.0)
		var dir := Vector3(sin(a), 0, cos(a))
		var h := 0.75 if k % 2 == 0 else 0.5
		var base := dir * (1.0 if k % 2 == 0 else 0.82)
		_tube(st, [base, base + dir * 0.06 + Vector3.UP * h * 0.55, base + dir * 0.18 + Vector3.UP * h], [0.11, 0.07, 0.004], [Color(0.6, 1, 0), Color(0.05, 1, 0), Color(0.3, 1, 0)], 4)
		_strip(st, base * 0.75 + Vector3.UP * 0.005, base + Vector3.UP * 0.005, 0.05, Vector3.UP, Color(1, 0.4, 0), Color(1, 1, 0))


static func _flame(st: SurfaceTool) -> void:
	# A tongue of fire in the XY plane (base at y = 0, height 1): a hot core
	# rising into licking tips.
	var rows := 10
	for i in rows:
		var t0 := float(i) / rows
		var t1 := float(i + 1) / rows
		var w0 := 0.5 * sin(PI * minf(1.0, 0.2 + t0 * 0.85)) * (1.0 - t0 * 0.4) + 0.04 * sin(t0 * 17.0)
		var w1 := 0.5 * sin(PI * minf(1.0, 0.2 + t1 * 0.85)) * (1.0 - t1 * 0.4) + 0.04 * sin(t1 * 17.0)
		var s0 := 0.08 * sin(t0 * 6.0)
		var s1 := 0.08 * sin(t1 * 6.0)
		var c0 := Color(1.0 - t0 * 0.8, 1.0 - t0 * 0.3, 0)
		var c1 := Color(1.0 - t1 * 0.8, 1.0 - t1 * 0.3, 0)
		var e0 := Color(0.2, 0.3 * (1.0 - t0), 0)
		var e1 := Color(0.2, 0.3 * (1.0 - t1), 0)
		var m0 := Vector3(s0, t0, 0)
		var m1 := Vector3(s1, t1, 0)
		_quad(st, m0 - Vector3(w0, 0, 0), m1 - Vector3(w1, 0, 0), m1, m0, e0, e1, c1, c0)
		_quad(st, m0, m1, m1 + Vector3(w1, 0, 0), m0 + Vector3(w0, 0, 0), c0, c1, e1, e0)
	# Two side tongues.
	for side in [-1.0, 1.0]:
		_tri(st, Vector3(side * 0.2, 0.25, 0.01), Vector3(side * 0.42, 0.75, 0.01), Vector3(side * 0.05, 0.45, 0.01), Color(0.7, 0.8, 0), Color(0.2, 0, 0), Color(0.8, 0.9, 0))


static func _bolt(st: SurfaceTool) -> void:
	# A lightning bolt in the XY plane from the sky (y = 1) to the ground (y = 0):
	# a jagged white-hot core with two forks.
	var points := [Vector3(0, 1, 0), Vector3(0.12, 0.84, 0), Vector3(-0.06, 0.66, 0), Vector3(0.1, 0.48, 0), Vector3(-0.08, 0.3, 0), Vector3(0.05, 0.14, 0), Vector3(0, 0, 0)]
	for i in points.size() - 1:
		_strip(st, points[i], points[i + 1], 0.07, Vector3.BACK, Color(1, 1, 0), Color(1, 1, 0))
		_strip(st, points[i], points[i + 1], 0.2, Vector3.BACK, Color(0.3, 0.4, 0), Color(0.3, 0.4, 0))
	for fork in [[2, Vector3(-0.25, 0.5, 0), Vector3(-0.33, 0.38, 0)], [4, Vector3(0.22, 0.17, 0), Vector3(0.3, 0.06, 0)]]:
		var start: Vector3 = points[int(fork[0])]
		_strip(st, start, fork[1], 0.04, Vector3.BACK, Color(1, 1, 0), Color(0.8, 0.8, 0))
		_strip(st, fork[1], fork[2], 0.03, Vector3.BACK, Color(0.8, 0.8, 0), Color(0.4, 0.3, 0))


static func _comet(st: SurfaceTool) -> void:
	# A comet heading +Z: a white-hot head and a long tail streaming back to -Z.
	_sphere(st, Vector3.ZERO, Vector3.ONE * 0.22, Color(1, 1, 0), 4, 8)
	_tube(st, [Vector3(0, 0, 0.05), Vector3(0, 0, -0.5), Vector3(0, 0, -1.2), Vector3(0, 0, -2.0)], [0.24, 0.2, 0.11, 0.005], [Color(0.9, 1, 0), Color(0.6, 0.8, 0), Color(0.3, 0.5, 0), Color(0.1, 0, 0)], 8)
	for side in [-1.0, 1.0]:
		_tube(st, [Vector3(side * 0.12, 0.05, -0.1), Vector3(side * 0.24, 0.08, -0.8), Vector3(side * 0.3, 0.1, -1.4)], [0.06, 0.035, 0.003], [Color(0.8, 0.8, 0), Color(0.4, 0.5, 0), Color(0.1, 0, 0)], 4)


static func _banner_mesh(st: SurfaceTool) -> void:
	# A war banner (XY plane): a pole 2.2 tall with a gold finial, a cloth hanging
	# from the crossbar with a swallowtail hem, a crest diamond and gold edges.
	_tube(st, [Vector3(0, 0, 0), Vector3(0, 2.2, 0)], [0.035, 0.03], [Color(0.5, 1, 0), Color(0.5, 1, 0)], 5)
	_sphere(st, Vector3(0, 2.28, 0), Vector3.ONE * 0.07, Color(1, 1, 0), 3, 6)
	_tube(st, [Vector3(-0.45, 2.05, 0), Vector3(0.45, 2.05, 0)], [0.025, 0.025], [Color(0.8, 1, 0), Color(0.8, 1, 0)], 4)
	var cloth := Color(0.0, 1, 0)
	var rows := 8
	for i in rows:
		var t0 := float(i) / rows
		var t1 := float(i + 1) / rows
		var y0 := 2.02 - t0 * 1.3
		var y1 := 2.02 - t1 * 1.3
		var z0 := 0.04 * sin(t0 * 5.0)
		var z1 := 0.04 * sin(t1 * 5.0)
		_quad(st, Vector3(-0.4, y0, z0), Vector3(-0.4, y1, z1), Vector3(0.4, y1, z1), Vector3(0.4, y0, z0), cloth, cloth, cloth, cloth)
	# The swallowtail hem and gold edges.
	_tri(st, Vector3(-0.4, 0.72, 0.03), Vector3(-0.4, 0.35, 0.03), Vector3(0.0, 0.72, 0.03), cloth, Color(0.3, 0.9, 0), cloth)
	_tri(st, Vector3(0.0, 0.72, 0.03), Vector3(0.4, 0.35, 0.03), Vector3(0.4, 0.72, 0.03), cloth, Color(0.3, 0.9, 0), cloth)
	for side in [-1.0, 1.0]:
		_strip(st, Vector3(side * 0.4, 2.02, 0.01), Vector3(side * 0.4, 0.35, 0.01), 0.05, Vector3.BACK, Color(1, 1, 0), Color(1, 1, 0))
	# The crest: a diamond with a crown over it.
	var c := Vector3(0, 1.35, 0.05)
	_quad(st, c + Vector3(0, 0.28, 0), c + Vector3(-0.2, 0, 0), c + Vector3(0, -0.28, 0), c + Vector3(0.2, 0, 0), Color(1, 1, 0), Color(1, 1, 0), Color(1, 1, 0), Color(1, 1, 0))
	_quad(st, c + Vector3(0, 0.18, 0.005), c + Vector3(-0.12, 0, 0.005), c + Vector3(0, -0.18, 0.005), c + Vector3(0.12, 0, 0.005), Color(0.2, 1, 0), Color(0.2, 1, 0), Color(0.2, 1, 0), Color(0.2, 1, 0))


static func _shield(st: SurfaceTool) -> void:
	# A heater shield in the XY plane facing +Z (about 0.9 tall): a dark face, a
	# bright rim and a cross of light with a crown at its head.
	var outline: Array = []
	for i in 13:
		var t := float(i) / 12.0
		var x := lerpf(-0.36, 0.36, t)
		outline.append(Vector3(x, 0.42 + 0.04 * cos(PI * (t - 0.5)), 0))
	for i in 13:
		var t := float(i) / 12.0
		var a := lerpf(0.0, PI, t)
		outline.append(Vector3(0.36 * cos(a), -0.05 - 0.45 * sin(a) * (0.6 + 0.4 * sin(a)), 0))
	var centre := Vector3(0, 0.05, 0.02)
	for i in outline.size():
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i + 1) % outline.size()]
		_tri(st, centre, a * 0.88, b * 0.88, Color(0, 1, 0), Color(0.1, 1, 0), Color(0.1, 1, 0))
		_quad(st, a * 0.88, b * 0.88, b, a, Color(0.9, 1, 0), Color(0.9, 1, 0), Color(1, 1, 0), Color(1, 1, 0))
	_strip(st, Vector3(0, 0.34, 0.03), Vector3(0, -0.4, 0.03), 0.07, Vector3.BACK, Color(1, 1, 0), Color(0.8, 1, 0))
	_strip(st, Vector3(-0.26, 0.12, 0.03), Vector3(0.26, 0.12, 0.03), 0.07, Vector3.BACK, Color(1, 1, 0), Color(1, 1, 0))


static func _plumes(st: SurfaceTool) -> void:
	# Great feathered wings rising behind the Lord (XY plane, roots at the origin):
	# on each side an arm, nine long flight feathers fanning up and out and a row
	# of coverts over their roots.
	for side in [-1.0, 1.0]:
		var wrist := Vector3(side * 0.7, 0.75, 0)
		_tube(st, [Vector3(side * 0.08, 0.05, 0), Vector3(side * 0.35, 0.5, 0), wrist], [0.06, 0.05, 0.035], [Color(0.5, 1, 0), Color(0.6, 1, 0), Color(0.8, 1, 0)], 5)
		for k in 9:
			var a := deg_to_rad(lerpf(80.0, -55.0, float(k) / 8.0))
			var dir := Vector3(side * cos(a), sin(a), 0)
			var root := Vector3(side * 0.1, 0.1, 0).lerp(wrist, minf(1.0, float(k) / 5.0))
			_feather(st, root, dir, 0.9 + 0.35 * sin(PI * float(k) / 8.0), 0.13)
		for k in 5:
			var a := deg_to_rad(lerpf(60.0, -10.0, float(k) / 4.0))
			_feather(st, Vector3(side * 0.12, 0.15, 0.01).lerp(wrist, float(k) / 4.0), Vector3(side * cos(a), sin(a), 0), 0.45, 0.1)


static func _orb(st: SurfaceTool) -> void:
	# A sphere of power with a tilted ring of light round it.
	_sphere(st, Vector3.ZERO, Vector3.ONE * 0.5, Color(0.7, 1, 0), 5, 10)
	_sphere(st, Vector3.ZERO, Vector3.ONE * 0.3, Color(1, 1, 0), 4, 8)
	var tilt := Basis(Vector3.RIGHT, 0.5)
	for i in 32:
		var a0 := TAU * float(i) / 32.0
		var a1 := TAU * float(i + 1) / 32.0
		var d0 := tilt * Vector3(sin(a0), 0, cos(a0))
		var d1 := tilt * Vector3(sin(a1), 0, cos(a1))
		_quad(st, d0 * 0.68, d1 * 0.68, d1 * 0.8, d0 * 0.8, Color(1, 1, 0), Color(1, 1, 0), Color(0.6, 0.6, 0), Color(0.6, 0.6, 0))
