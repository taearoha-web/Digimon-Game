class_name ShadowSkillArt
extends Node3D
## The Assassin's art: every skill of the line (25) and its four star skills
## get their own layered composition of shadow sculptures. Phantom assassins
## step out of the dark and cut, crescent blades cross in violet and crimson,
## daggers fly, fall and orbit, a crescent moon and a black sun rise over the
## field, rifts tear the ground open, death sigils turn and smoke shells swell.
##
## Two materials: shadow_ink (a dark churning body, violet rim, bright inlays)
## for the shadows and shadow_glow (additive energy, white-hot core) for the
## cuts. One clock per cast; the layers are budgeted (VfxBudget, fewer at lower
## quality, with a reserve for the hits that follow) and the geometry is built
## once and shared. Cosmetic only: it never selects victims, deals damage or
## changes timing, and a cancelled cast (new skill generation) drops its wind-up.

const INK := preload("res://shaders/shadow_ink.gdshader")
const GLOW := preload("res://shaders/shadow_glow.gdshader")
const KINDS := "crescent dagger phantom moon eclipse rift sigil fangs smoke wings crown blades vortex"
## [primary, accent, shade] palettes.
const NIGHT := [Color("9a6bff"), Color("f3eaff"), Color("140a26")]
const BLOOD := [Color("ff3a6e"), Color("ffe3ec"), Color("26050f")]
const VENOM := [Color("7ee05a"), Color("f4ffd9"), Color("0d2116")]
const VOID := [Color("6a5cff"), Color("e8e4ff"), Color("07051a")]
## Decorations left free for hits, flourishes and other casters.
const RESERVE := 8
const CONTACT_GAP_MS := 90
static var _meshes: Dictionary = {}
static var _last_contact: Dictionary = {}

var age := 0.0
var lifetime := 0.5
var layers: Array[Dictionary] = []
var owner_ref: WeakRef
var generation := -1
var cap := 16


static func handles(skill: Dictionary) -> bool:
	return not skill.is_empty() and SkillShow.family_of(skill) == "assassin"


## The palette of a skill from its authored recipe (shadow / nightblood / venom).
static func palette(skill: Dictionary) -> Array:
	var id := String(skill.get("id", ""))
	if id in ["shadow_execution", "veil_of_night"]:
		return BLOOD if id == "shadow_execution" else VOID
	if id in ["umbral_lacerate", "eclipse_requiem"]:
		return NIGHT
	match String(SkillArtDirection.RECIPES.get(id, ["", "shadow"])[1]):
		"nightblood": return BLOOD
		"venom": return VENOM
	return NIGHT


static func layer_cap() -> int:
	return int([5, 10, 16][VfxBudget.quality()] * MemoryGuard.effect_scale())


static func warm_geometry() -> void:
	for kind in KINDS.split(" "):
		mesh(kind)


## Draws both materials once, invisibly, so the first cast does not stall on a phone.
static func warm_up(parent: Node3D, at: Vector3) -> void:
	warm_geometry()
	var art := _root(parent, at, "ShadowArt_Warm")
	art.cap = 2
	art.layer("crescent", true, NIGHT, Vector3.UP, Vector3.ONE * 0.01, Vector3.ZERO, 0.0, 0.3, {"opacity": 0.001})
	art.layer("phantom", false, NIGHT, Vector3.UP, Vector3.ONE * 0.01, Vector3.ZERO, 0.0, 0.3, {"opacity": 0.001})


static func _root(parent: Node3D, at: Vector3, label: String) -> ShadowSkillArt:
	var art := ShadowSkillArt.new()
	art.name = label
	art.cap = layer_cap()
	parent.add_child(art)
	art.global_position = at
	return art


static func _alive(parent: Node3D) -> bool:
	return is_instance_valid(parent) and parent.is_inside_tree() and not parent.is_queued_for_deletion()


static func _yaw(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z) if Vector2(d.x, d.z).length_squared() > 0.001 else 0.0


## One layer: a shared sculpture in the ink or glow material. size scales the
## unit geometry; style keys: initial, grow (speed), travel, accelerate, drop and
## land, spin (around Y, rad/s), roll (around Z, rad/s), turn, orbit and
## orbit_speed, flap, face_camera, fade_in, decay, opacity.
func layer(kind: String, glow: bool, c: Array, at: Vector3, size: Vector3, angles := Vector3.ZERO, start := 0.0, seconds := 1.0, style := {}) -> void:
	if layers.size() >= cap or not VfxBudget.can_decorate(1 + RESERVE):
		return
	var node := MeshInstance3D.new()
	node.name = kind.capitalize()
	node.mesh = mesh(kind)
	var mat := ShaderMaterial.new()
	mat.shader = GLOW if glow else INK
	mat.set_shader_parameter("primary", c[0])
	mat.set_shader_parameter("accent", c[1])
	mat.set_shader_parameter("shade", c[2])
	mat.set_shader_parameter("opacity", float(style.get("opacity", 0.9 if glow else 0.86)))
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	VfxBudget.track_decoration(node)
	layers.append({"node": node, "mat": mat, "at": at, "size": size, "angles": angles, "start": start, "seconds": maxf(seconds, 0.05), "style": style})
	lifetime = maxf(lifetime, start + seconds + 0.02)


func _process(delta: float) -> void:
	if owner_ref:
		var visual := owner_ref.get_ref() as HeroVisual
		if not is_instance_valid(visual) or visual.skill_generation != generation:
			queue_free()
			return
	age += delta
	_draw()
	if age >= lifetime:
		queue_free()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	for data in layers:
		var node: MeshInstance3D = data.node
		var style: Dictionary = data.style
		var local := age - float(data.start)
		var t := clampf(local / float(data.seconds), 0.0, 1.0)
		node.visible = local >= 0.0 and t < 1.0
		if not node.visible:
			continue
		var rise := 1.0 - pow(1.0 - minf(t * float(style.get("grow", 4.0)), 1.0), 3.0)
		node.scale = (data.size as Vector3) * maxf(0.004, lerpf(float(style.get("initial", 0.55)), 1.0, rise))
		var travel: Vector3 = style.get("travel", Vector3.ZERO)
		var progress := t * t if bool(style.get("accelerate", false)) else 1.0 - pow(1.0 - t, 2.0)
		var at: Vector3 = (data.at as Vector3) + travel * progress
		if style.has("drop"):
			at.y += float(style.drop) * (1.0 - smoothstep(0.0, maxf(0.01, float(style.get("land", 0.15))), local))
		if style.has("orbit"):
			var a := float(style.get("phase", 0.0)) + local * float(style.get("orbit_speed", 3.0))
			at += Vector3(sin(a), 0.0, cos(a)) * float(style.orbit)
		node.position = at
		var rot: Vector3 = (data.angles as Vector3) + (style.get("turn", Vector3.ZERO) as Vector3) * smoothstep(0.0, 0.6, t)
		rot.y += float(style.get("spin", 0.0)) * local
		rot.z += float(style.get("roll", 0.0)) * local + sin(local * 7.0) * float(style.get("flap", 0.0))
		node.rotation = rot
		if bool(style.get("face_camera", false)) and camera:
			var toward := global_basis.inverse() * (camera.global_position - node.global_position)
			node.rotation.y = atan2(toward.x, toward.z)
		var fade := smoothstep(0.0, float(style.get("fade_in", 0.06)), t) * (1.0 - smoothstep(minf(float(style.get("decay", 0.55)), 0.98), 1.0, t))
		var mat: ShaderMaterial = data.mat
		mat.set_shader_parameter("fade", fade)
		mat.set_shader_parameter("age", local)


# ---------------------------------------------------------------------------
# Entry points
# ---------------------------------------------------------------------------

## Wind-up: the shadows gather. Blades of light cross at the hands; from Lv.40 a
## phantom rises behind the caster; from Lv.80 a sigil turns at its feet under
## the moon. Bound to the caster's skill generation (a cancel drops it).
static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, aim: Vector3, duration: float, visual: HeroVisual = null) -> void:
	if not handles(skill) or not _alive(parent) or duration < 0.12 or not VfxBudget.can_decorate(4 + RESERVE):
		return
	var c := palette(skill)
	var level := int(skill.get("level", 1))
	var time := maxf(duration, 0.15)
	var art := _root(parent, origin, "ShadowArt_Windup_" + String(skill.get("id", "")))
	art.rotation.y = _yaw(origin, aim)
	if visual:
		art.owner_ref = weakref(visual)
		art.generation = visual.skill_generation
	for side in [-1.0, 1.0]:
		art.layer("crescent", true, c, Vector3(side * 0.25, 1.15, 0.45), Vector3.ONE * 0.55, Vector3(0, 0, side * 0.9), 0.0, time + 0.05, {"initial": 0.1, "grow": 1.2, "roll": -side * 5.0, "decay": 0.85, "fade_in": 0.3})
	if level >= 40 or skill.has("star"):
		art.layer("phantom", false, c, Vector3(0, 0, -0.55), Vector3.ONE * 1.08, Vector3.ZERO, 0.0, time + 0.08, {"initial": 0.7, "grow": 1.5, "fade_in": 0.45, "decay": 0.8, "opacity": 0.55, "travel": Vector3(0, 0.1, -0.15)})
	if level >= 80 or skill.has("star"):
		art.layer("sigil", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 1.6, Vector3.ZERO, 0.0, time + 0.1, {"initial": 0.2, "grow": 1.4, "spin": 1.6, "decay": 0.85, "fade_in": 0.3})
		art.layer("moon", true, c, Vector3(0, 2.7, -0.6), Vector3.ONE * 0.7, Vector3.ZERO, 0.0, time + 0.1, {"initial": 0.3, "grow": 1.3, "face_camera": true, "decay": 0.85, "fade_in": 0.35, "opacity": 0.7})


## Release: the skill's own composition, at the same beat as its damage.
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, delay := 0.0) -> void:
	if not handles(skill) or not _alive(parent) or skill.has("star") or not VfxBudget.can_decorate(3 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var shape := String(skill.get("shape", "single"))
	var c := palette(skill)
	var at := center if shape == "blast" else origin
	var art := _root(parent, Vector3(at.x, origin.y, at.z), "ShadowArt_" + id)
	art.rotation.y = _yaw(origin, center)
	var reach := Vector2(center.x - origin.x, center.z - origin.z).length()
	var radius := float(skill.get("radius", 3.0))
	art._compose(id, c, reach, radius, maxf(delay, 0.0))


## Every hit: a small crossed cut of shadow light on the victim (one per gap).
static func contact(parent: Node3D, skill: Dictionary, at: Vector3) -> void:
	if not handles(skill) or skill.has("star") or not _alive(parent) or not VfxBudget.can_decorate(2 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var now := Time.get_ticks_msec()
	if now - int(_last_contact.get(id, -100000)) < CONTACT_GAP_MS:
		return
	_last_contact[id] = now
	var c := palette(skill)
	var art := _root(parent, at, "ShadowArt_Hit_" + id)
	art.cap = mini(art.cap, 3)
	var tilt := randf_range(-0.4, 0.4)
	art.layer("crescent", true, c, Vector3.ZERO, Vector3.ONE * 0.85, Vector3(0, randf() * TAU, 0.9 + tilt), 0.0, 0.32, {"initial": 0.4, "roll": -6.0, "face_camera": true})
	art.layer("crescent", true, BLOOD if c != BLOOD else NIGHT, Vector3.ZERO, Vector3.ONE * 0.85, Vector3(0, randf() * TAU, -0.9 + tilt), 0.03, 0.32, {"initial": 0.4, "roll": 6.0, "face_camera": true})
	if int(skill.get("level", 1)) >= 60:
		art.layer("rift", false, c, Vector3(0, -0.95, 0), Vector3.ONE * 0.8, Vector3(0, randf() * TAU, 0), 0.02, 0.6, {"initial": 0.3, "opacity": 0.8})


## Star skills: one composition per contact beat of StarSkillSequence.
static func star(parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> void:
	if not handles(skill) or not _alive(parent) or not VfxBudget.can_decorate(3 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var c := palette(skill)
	var ground := Vector3(point.x, source.y, point.z)
	var art := _root(parent, ground, "ShadowArt_Star_%s_%d" % [id, index])
	art.rotation.y = _yaw(source, point)
	var radius := clampf(float(skill.get("radius", 6.0)), 3.0, 10.0)
	art._star(id, c, index, radius)


# ---------------------------------------------------------------------------
# Compositions
# ---------------------------------------------------------------------------

func _x_cut(c: Array, at: Vector3, size: float, start := 0.0, other: Array = BLOOD) -> void:
	layer("crescent", true, c, at, Vector3.ONE * size, Vector3(0, 0, 0.85), start, 0.42, {"initial": 0.35, "roll": -5.0, "face_camera": true})
	layer("crescent", true, other, at, Vector3.ONE * size, Vector3(0, 0, -0.85), start + 0.05, 0.42, {"initial": 0.35, "roll": 5.0, "face_camera": true})


func _phantom(c: Array, at: Vector3, yaw: float, start: float, seconds := 0.55, size := 1.0, style := {}) -> void:
	var options := {"initial": 0.9, "grow": 6.0, "fade_in": 0.12, "decay": 0.45, "opacity": 0.82}
	options.merge(style, true)
	layer("phantom", false, c, at, Vector3.ONE * size * 0.9, Vector3(0, yaw, 0), start, seconds, options)


func _compose(id: String, c: Array, reach: float, radius: float, d: float) -> void:
	var target := Vector3(0, 0, reach)
	var r := minf(radius, 9.5)
	match id:
		"twin_fang":
			_x_cut(c, target + Vector3.UP * 1.1, 1.5, d)
			_phantom(c, Vector3(0, 0, -0.2), 0.0, d, 0.45, 1.0, {"travel": Vector3(0, 0, -0.7), "opacity": 0.6})
			layer("smoke", false, c, target + Vector3.UP * 0.1, Vector3.ONE * 0.7, Vector3.ZERO, d + 0.04, 0.7, {"initial": 0.3, "opacity": 0.55})
		"shadow_veil":
			layer("smoke", false, c, Vector3.ZERO, Vector3(1.6, 1.3, 1.6), Vector3.ZERO, d, 1.3, {"initial": 0.3, "grow": 2.0, "opacity": 0.6, "spin": 0.6})
			_phantom(c, Vector3.ZERO, 0.0, d, 1.0, 1.12, {"initial": 1.15, "opacity": 0.7, "decay": 0.3, "travel": Vector3(0, 0.25, 0)})
			for i in 3:
				layer("crescent", true, c, Vector3(0, 0.4 + i * 0.55, 0), Vector3.ONE * (1.1 - i * 0.15), Vector3(PI * 0.5, i * 2.1, 0), d + i * 0.06, 0.9, {"initial": 0.4, "spin": 7.0 - i * 2.0})
			layer("moon", true, c, Vector3(0, 2.6, -0.5), Vector3.ONE * 0.8, Vector3.ZERO, d + 0.1, 1.2, {"face_camera": true, "initial": 0.3, "opacity": 0.75})
		"venom_edge":
			layer("dagger", true, c, target + Vector3(0, 1.05, -1.6), Vector3.ONE * 0.95, Vector3(PI * 0.5, 0, 0), d, 0.32, {"initial": 1.0, "travel": Vector3(0, 0, 1.4), "accelerate": true, "decay": 0.7})
			_x_cut(c, target + Vector3.UP * 1.05, 1.2, d + 0.1, NIGHT)
			layer("smoke", false, c, target, Vector3(1.0, 0.9, 1.0), Vector3.ZERO, d + 0.12, 1.0, {"initial": 0.3, "opacity": 0.6})
			layer("rift", false, c, target + Vector3.UP * 0.04, Vector3.ONE * 1.2, Vector3.ZERO, d + 0.1, 1.0, {"initial": 0.3})
		"shadow_step":
			for i in 3:
				var f := 0.25 + 0.25 * float(i)
				_phantom(c, Vector3(0, 0, reach * f), 0.0, d + 0.03 * i, 0.4, 1.0, {"opacity": 0.75 - 0.15 * i, "decay": 0.3})
			_phantom(c, target + Vector3(0, 0, 0.8), PI, d + 0.08, 0.7, 1.05, {"initial": 0.6})
			_x_cut(c, target + Vector3.UP * 1.1, 1.4, d + 0.12)
			layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * 1.1, Vector3.ZERO, d, 0.9, {"initial": 0.4})
		"blade_flurry":
			layer("blades", true, c, Vector3(0, 1.0, 0), Vector3.ONE * r * 0.55, Vector3.ZERO, d, 0.8, {"initial": 0.2, "grow": 3.0, "spin": 10.0})
			for i in 2:
				layer("crescent", true, BLOOD if i == 1 else c, Vector3(0, 0.8 + i * 0.45, 0), Vector3.ONE * r * (0.6 - 0.1 * i), Vector3(PI * 0.5, i * PI, 0), d + 0.05 * i, 0.55, {"initial": 0.3, "spin": 12.0 - i * 3.0})
			layer("fangs", false, c, Vector3.ZERO, Vector3(r * 0.6, 1.0, r * 0.6), Vector3.ZERO, d + 0.05, 0.8, {"initial": 0.2})
		"fan_of_knives":
			for i in 5:
				var a := (float(i) - 2.0) * 0.24
				layer("dagger", true, c, Vector3(0, 1.1, 0.5), Vector3.ONE * 0.8, Vector3(PI * 0.5, a, 0), d + 0.015 * i, 0.4, {"initial": 1.0, "travel": Vector3(sin(a), 0, cos(a)) * 9.0, "decay": 0.75})
			layer("crescent", true, c, Vector3(0, 1.1, 0.8), Vector3(2.2, 1.2, 1.2), Vector3(PI * 0.5, 0, 0), d, 0.35, {"initial": 0.4})
			layer("smoke", false, c, Vector3(0, 0.2, 0.3), Vector3.ONE * 0.6, Vector3.ZERO, d, 0.6, {"initial": 0.3, "opacity": 0.5})
		"killing_focus":
			layer("eclipse", false, c, Vector3(0, 2.7, -0.4), Vector3.ONE * 0.7, Vector3.ZERO, d, 1.3, {"face_camera": true, "initial": 0.2, "spin": 0.0, "roll": 1.2})
			layer("sigil", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 1.8, Vector3.ZERO, d, 1.2, {"initial": 0.3, "spin": -2.0})
			for i in 2:
				layer("crescent", true, c, Vector3(0, 0.3, 0), Vector3.ONE * (1.0 + i * 0.3), Vector3(PI * 0.5, i * PI, 0), d + 0.1 * i, 0.9, {"initial": 0.5, "spin": 6.0, "travel": Vector3(0, 2.0, 0)})
			_phantom(c, Vector3(0, 0, -0.3), 0.0, d, 0.9, 1.15, {"initial": 1.2, "opacity": 0.55, "decay": 0.35})
		"backstab":
			_phantom(c, target + Vector3(0, 0, 0.9), PI, d, 0.75, 1.05, {"initial": 0.5, "grow": 5.0})
			layer("dagger", true, c, target + Vector3(0, 1.0, 1.0), Vector3.ONE * 1.1, Vector3(-PI * 0.5, 0, 0), d + 0.06, 0.35, {"initial": 1.0, "travel": Vector3(0, 0, -0.9), "accelerate": true})
			_x_cut(c, target + Vector3.UP * 1.0, 1.3, d + 0.12, NIGHT)
			layer("rift", false, c, target + Vector3.UP * 0.04, Vector3.ONE * 1.3, Vector3.ZERO, d + 0.1, 1.0, {"initial": 0.3})
		"smoke_bomb":
			for i in 3:
				layer("smoke", false, c, Vector3(0, 0.0, 0), Vector3(r * (0.32 + 0.14 * i), r * (0.22 + 0.08 * i), r * (0.32 + 0.14 * i)), Vector3(0, i, 0), d + 0.06 * i, 1.6 - 0.2 * i, {"initial": 0.15, "grow": 2.5, "opacity": 0.55 - 0.1 * i, "spin": 0.5 - 0.3 * i})
			layer("sigil", true, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, d, 1.2, {"initial": 0.2, "spin": 1.5})
			layer("crescent", true, c, Vector3(0, 0.4, 0), Vector3.ONE * r * 0.6, Vector3(PI * 0.5, 0, 0), d, 0.5, {"initial": 0.2, "spin": 9.0})
			layer("eclipse", false, c, Vector3(0, 2.4, 0), Vector3.ONE * 0.7, Vector3.ZERO, d + 0.1, 1.0, {"face_camera": true, "initial": 0.3})
		"night_raid":
			layer("moon", true, c, target + Vector3(0, 3.6, -0.5), Vector3.ONE * 1.1, Vector3.ZERO, d, 1.3, {"face_camera": true, "initial": 0.3})
			for i in 4:
				var a := float(i) * TAU / 4.0 + 0.4
				var spot := target + Vector3(sin(a), 0, cos(a)) * 1.8
				_phantom(c, spot, a + PI, d + 0.08 * i, 0.45, 1.0)
				layer("crescent", true, BLOOD if i % 2 == 1 else c, spot.lerp(target, 0.6) + Vector3.UP * 1.1, Vector3.ONE * 1.1, Vector3(0, a, 0.9 * (1 if i % 2 == 1 else -1)), d + 0.08 * i + 0.1, 0.32, {"initial": 0.4, "roll": 6.0, "face_camera": true})
		"crimson_cut":
			layer("crescent", true, c, target + Vector3.UP * 1.1, Vector3.ONE * 2.3, Vector3(0, 0, 0.6), d, 0.5, {"initial": 0.3, "roll": -4.0, "face_camera": true})
			layer("crescent", true, NIGHT, target + Vector3.UP * 1.0, Vector3.ONE * 1.6, Vector3(0, 0, -1.1), d + 0.08, 0.45, {"initial": 0.3, "roll": 4.0, "face_camera": true})
			_phantom(c, Vector3(0, 0, reach * 0.4), 0.0, d, 0.4, 1.0, {"opacity": 0.6})
			layer("rift", false, c, target + Vector3.UP * 0.04, Vector3.ONE * 1.4, Vector3.ZERO, d + 0.1, 1.1, {"initial": 0.3})
			layer("smoke", false, c, target, Vector3.ONE * 0.8, Vector3.ZERO, d + 0.1, 0.8, {"initial": 0.3, "opacity": 0.5})
		"shadow_clone":
			for side in [-1.0, 1.0]:
				_phantom(c, Vector3(side * 1.25, 0, -0.35), side * -0.3, d + 0.05, 1.6, 1.0, {"initial": 0.3, "grow": 3.0, "decay": 0.75, "flap": 0.04})
				layer("smoke", false, c, Vector3(side * 1.25, 0, -0.35), Vector3.ONE * 0.75, Vector3.ZERO, d, 0.9, {"initial": 0.3, "opacity": 0.5})
			layer("moon", true, c, Vector3(0, 2.8, -0.8), Vector3.ONE * 0.9, Vector3.ZERO, d + 0.1, 1.4, {"face_camera": true, "initial": 0.3})
			layer("sigil", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 2.2, Vector3.ZERO, d, 1.3, {"initial": 0.3, "spin": 1.2})
		"phantom_daggers":
			for i in 5:
				layer("dagger", true, BLOOD if i % 2 == 1 else c, Vector3((float(i) - 2.0) * 0.18, 1.0 + 0.08 * (i % 2), 0.4), Vector3.ONE * 0.95, Vector3(PI * 0.5, 0, 0), d + 0.04 * i, 0.5, {"initial": 1.0, "travel": Vector3(0, 0, 12.0), "decay": 0.8})
			layer("vortex", true, c, Vector3(0, 1.0, 0.6), Vector3.ONE * 0.9, Vector3(PI * 0.5, 0, 0), d, 0.45, {"initial": 0.3, "spin": 0.0, "roll": 8.0})
			_phantom(c, Vector3(0, 0, -0.4), 0.0, d, 0.5, 1.05, {"opacity": 0.55})
		"deadly_venom":
			for i in 2:
				layer("smoke", false, c, Vector3.ZERO, Vector3(r * (0.42 + 0.18 * i), r * 0.28, r * (0.42 + 0.18 * i)), Vector3(0, i * 1.3, 0), d + 0.08 * i, 1.6, {"initial": 0.15, "grow": 2.2, "opacity": 0.5 - 0.15 * i, "spin": 0.4})
			layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, d, 1.5, {"initial": 0.2})
			layer("fangs", true, c, Vector3.ZERO, Vector3(r * 0.5, 0.8, r * 0.5), Vector3.ZERO, d + 0.1, 1.0, {"initial": 0.2, "spin": 0.8})
			layer("sigil", true, c, Vector3(0, 0.06, 0), Vector3.ONE * r * 0.85, Vector3.ZERO, d, 1.4, {"initial": 0.3, "spin": -1.0})
		"thousand_cuts":
			for i in 6:
				var tilt := float(i) * 0.55
				layer("crescent", true, BLOOD if i % 2 == 1 else c, Vector3(0, 1.0 + 0.15 * (i % 3), 0), Vector3.ONE * r * (0.42 + 0.05 * i), Vector3(PI * 0.5 + sin(tilt) * 0.5, i * 1.05, cos(tilt) * 0.4), d + 0.04 * i, 0.5, {"initial": 0.2, "spin": 11.0 * (1 if i % 2 == 1 else -1)})
			layer("blades", true, c, Vector3(0, 1.1, 0), Vector3.ONE * r * 0.6, Vector3.ZERO, d, 0.9, {"initial": 0.3, "spin": -9.0})
			layer("fangs", false, c, Vector3.ZERO, Vector3(r * 0.65, 1.2, r * 0.65), Vector3.ZERO, d + 0.08, 0.9, {"initial": 0.2})
			layer("sigil", true, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.9, Vector3.ZERO, d, 1.1, {"initial": 0.3, "spin": 2.0})
		"throat_slit":
			_phantom(c, target + Vector3(0, 0, 0.75), PI, d, 0.6, 1.0, {"initial": 0.6})
			layer("crescent", true, c, target + Vector3.UP * 1.35, Vector3(2.0, 2.0, 2.0), Vector3(PI * 0.5, 0, 0), d + 0.05, 0.4, {"initial": 0.2, "spin": 14.0})
			layer("crescent", true, NIGHT, target + Vector3.UP * 1.35, Vector3.ONE * 1.3, Vector3(0, 0, 1.4), d + 0.08, 0.35, {"initial": 0.3, "roll": -7.0, "face_camera": true})
			layer("eclipse", false, c, target + Vector3(0, 2.6, 0), Vector3.ONE * 0.6, Vector3.ZERO, d + 0.1, 0.8, {"face_camera": true, "initial": 0.3})
		"shadow_dance":
			layer("moon", true, c, target + Vector3(0, 4.0, -0.6), Vector3.ONE * 1.5, Vector3.ZERO, d, 1.5, {"face_camera": true, "initial": 0.3})
			for i in 5:
				var a := float(i) * TAU / 5.0
				_phantom(c, target, a, d + 0.06 * i, 0.9, 1.0, {"orbit": 2.0, "orbit_speed": 5.0, "phase": a, "initial": 0.7})
			layer("blades", true, c, target + Vector3(0, 1.0, 0), Vector3.ONE * 2.0, Vector3.ZERO, d + 0.1, 0.9, {"initial": 0.3, "spin": 9.0})
			layer("sigil", true, c, target + Vector3(0, 0.05, 0), Vector3.ONE * 2.6, Vector3.ZERO, d, 1.3, {"initial": 0.3, "spin": -1.5})
		"death_mark":
			layer("sigil", true, c, Vector3(0, 0.06, 0), Vector3.ONE * r * 0.95, Vector3.ZERO, d, 1.6, {"initial": 0.15, "grow": 2.5, "spin": 0.8})
			layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * r * 0.6, Vector3.ZERO, d + 0.1, 1.5, {"initial": 0.2})
			layer("eclipse", false, c, Vector3(0, 3.4, 0), Vector3.ONE * 1.1, Vector3.ZERO, d, 1.5, {"face_camera": true, "initial": 0.3})
			for i in 6:
				var a := float(i) * TAU / 6.0
				layer("dagger", true, NIGHT if i % 2 == 1 else c, Vector3(sin(a), 0, cos(a)) * r * 0.55 + Vector3.UP * 0.9, Vector3.ONE * 1.1, Vector3(PI, a, 0), d + 0.05 * i, 0.5, {"initial": 1.0, "drop": 5.0, "land": 0.22, "decay": 0.7})
		"night_lord":
			layer("crown", true, c, Vector3(0, 2.35, 0), Vector3.ONE * 0.9, Vector3.ZERO, d, 1.5, {"initial": 0.2, "spin": 2.0})
			layer("wings", false, c, Vector3(0, 1.2, -0.45), Vector3.ONE * 1.3, Vector3.ZERO, d + 0.05, 1.5, {"initial": 0.2, "grow": 2.0, "flap": 0.08, "face_camera": true})
			layer("moon", true, c, Vector3(0, 3.0, -0.9), Vector3.ONE * 1.1, Vector3.ZERO, d + 0.1, 1.5, {"face_camera": true, "initial": 0.3})
			layer("sigil", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 2.4, Vector3.ZERO, d, 1.5, {"initial": 0.3, "spin": 1.2})
			layer("smoke", false, c, Vector3.ZERO, Vector3(1.4, 0.8, 1.4), Vector3.ZERO, d, 1.2, {"initial": 0.3, "opacity": 0.45})
		"eclipse_fang":
			layer("eclipse", false, c, target + Vector3(0, 2.2, 0.6), Vector3.ONE * 1.6, Vector3.ZERO, d, 1.3, {"face_camera": true, "initial": 0.3, "roll": 0.8})
			_x_cut(c, target + Vector3.UP * 1.2, 2.6, d + 0.05, NIGHT)
			for side in [-1.0, 1.0]:
				_phantom(c, target + Vector3(side * 1.6, 0, 0), side * PI * 0.5 * -1.0, d, 0.55, 1.05, {"travel": Vector3(-side * 1.0, 0, 0), "initial": 0.8})
			layer("rift", false, c, target + Vector3.UP * 0.04, Vector3.ONE * 2.2, Vector3.ZERO, d + 0.1, 1.3, {"initial": 0.2})
			layer("smoke", false, c, target, Vector3.ONE * 1.1, Vector3.ZERO, d + 0.15, 1.0, {"initial": 0.3, "opacity": 0.5})
		"abyss_vortex":
			layer("vortex", false, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.9, Vector3.ZERO, d, 1.6, {"initial": 0.2, "grow": 2.0, "spin": -3.0})
			layer("vortex", true, c, Vector3(0, 0.08, 0), Vector3.ONE * r * 0.7, Vector3(0, 1.0, 0), d + 0.05, 1.5, {"initial": 0.3, "spin": -5.0})
			layer("blades", true, BLOOD, Vector3(0, 1.0, 0), Vector3.ONE * r * 0.55, Vector3.ZERO, d, 1.3, {"initial": 0.9, "spin": -7.0, "travel": Vector3(0, -0.5, 0)})
			layer("smoke", false, c, Vector3.ZERO, Vector3(r * 0.45, r * 0.25, r * 0.45), Vector3.ZERO, d + 0.1, 1.5, {"initial": 0.3, "opacity": 0.45, "spin": -1.0})
			layer("fangs", false, c, Vector3.ZERO, Vector3(r * 0.75, 1.4, r * 0.75), Vector3.ZERO, d + 0.15, 1.1, {"initial": 0.2})
			layer("eclipse", false, c, Vector3(0, 4.2, 0), Vector3.ONE * 1.4, Vector3.ZERO, d, 1.5, {"face_camera": true, "initial": 0.3, "roll": -1.0})
		"phantom_legion":
			layer("wings", false, c, Vector3(0, 1.3, -0.6), Vector3.ONE * 1.6, Vector3.ZERO, d, 1.3, {"initial": 0.2, "grow": 2.5, "flap": 0.1})
			for i in 4:
				var a := (float(i) - 1.5) * 0.7
				_phantom(c, Vector3(sin(a) * 1.8, 0, -0.8 + cos(a) * 0.4), a * 0.3, d + 0.05 * i, 0.8, 0.95, {"initial": 0.5, "opacity": 0.7})
			for i in 8:
				var a := (float(i) - 3.5) * 0.2
				layer("dagger", true, BLOOD if i % 2 == 1 else c, Vector3(0, 1.2 + 0.1 * (i % 2), 0.4), Vector3.ONE * 0.9, Vector3(PI * 0.5, a, 0), d + 0.1 + 0.02 * i, 0.5, {"initial": 1.0, "travel": Vector3(sin(a), 0, cos(a)) * 11.0, "decay": 0.8})
		"midnight_execution":
			layer("moon", true, c, Vector3(0, 6.0, -1.0), Vector3.ONE * 2.0, Vector3.ZERO, d, 1.6, {"face_camera": true, "initial": 0.4})
			layer("dagger", true, c, Vector3(0, 0.4, 0), Vector3(2.4, 3.6, 2.4), Vector3(PI, 0, 0), d, 0.85, {"initial": 1.0, "drop": 6.0, "land": 0.14, "decay": 0.6})
			layer("rift", false, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.75, Vector3.ZERO, d + 0.1, 1.5, {"initial": 0.15, "grow": 3.0})
			layer("fangs", false, c, Vector3.ZERO, Vector3(r * 0.6, 1.6, r * 0.6), Vector3.ZERO, d + 0.12, 1.1, {"initial": 0.2})
			_x_cut(c, Vector3.UP * 1.4, 2.6, d + 0.12, NIGHT)
			layer("eclipse", false, c, Vector3(0, 2.6, 0), Vector3.ONE * 1.2, Vector3.ZERO, d + 0.14, 1.0, {"face_camera": true, "initial": 0.4})
			layer("smoke", false, c, Vector3.ZERO, Vector3(r * 0.4, r * 0.2, r * 0.4), Vector3.ZERO, d + 0.15, 1.2, {"initial": 0.3, "opacity": 0.45})
		"shadow_sovereign":
			layer("wings", false, c, Vector3(0, 1.25, -0.5), Vector3.ONE * 1.8, Vector3.ZERO, d, 1.7, {"initial": 0.2, "grow": 2.0, "flap": 0.08, "face_camera": true})
			layer("crown", true, c, Vector3(0, 2.4, 0), Vector3.ONE * 1.0, Vector3.ZERO, d + 0.05, 1.7, {"initial": 0.2, "spin": 1.6})
			layer("eclipse", false, c, Vector3(0, 2.0, -0.9), Vector3.ONE * 1.3, Vector3.ZERO, d + 0.1, 1.7, {"face_camera": true, "initial": 0.3, "roll": 0.6})
			for side in [-1.0, 1.0]:
				_phantom(c, Vector3(side * 1.4, 0, 0.2), side * -0.4, d + 0.12, 1.4, 0.85, {"initial": 0.4, "grow": 3.0, "decay": 0.7})
			layer("sigil", true, c, Vector3(0, 0.05, 0), Vector3.ONE * 2.8, Vector3.ZERO, d, 1.6, {"initial": 0.3, "spin": 1.0})
			layer("blades", true, NIGHT, Vector3(0, 1.0, 0), Vector3.ONE * 1.6, Vector3.ZERO, d + 0.15, 1.5, {"initial": 0.3, "spin": 4.0})
		"oblivion_requiem":
			layer("eclipse", false, c, Vector3(0, 6.5, 0), Vector3.ONE * r * 0.45, Vector3.ZERO, d, 2.0, {"face_camera": true, "initial": 0.2, "grow": 2.0, "roll": 0.7})
			layer("vortex", false, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.95, Vector3.ZERO, d, 1.9, {"initial": 0.2, "grow": 2.0, "spin": 2.5})
			layer("sigil", true, c, Vector3(0, 0.07, 0), Vector3.ONE * r * 0.85, Vector3.ZERO, d, 1.9, {"initial": 0.2, "spin": -1.2})
			layer("blades", true, BLOOD, Vector3(0, 1.2, 0), Vector3.ONE * r * 0.5, Vector3.ZERO, d + 0.05, 1.6, {"initial": 0.2, "spin": 8.0})
			for i in 4:
				layer("crescent", true, BLOOD if i % 2 == 1 else c, Vector3(0, 1.0 + 0.25 * i, 0), Vector3.ONE * r * (0.5 + 0.08 * i), Vector3(PI * 0.5 + 0.2 * (i % 2), i * 0.8, 0), d + 0.06 * i, 0.7, {"initial": 0.2, "spin": 10.0 * (1 if i % 2 == 1 else -1)})
			for i in 4:
				var a := float(i) * TAU / 4.0 + PI * 0.25
				_phantom(c, Vector3(sin(a), 0, cos(a)) * r * 0.55, a + PI, d + 0.1 + 0.05 * i, 1.0, 1.05, {"initial": 0.5, "travel": -Vector3(sin(a), 0, cos(a)) * r * 0.3})
			layer("fangs", false, c, Vector3.ZERO, Vector3(r * 0.8, 1.8, r * 0.8), Vector3.ZERO, d + 0.2, 1.3, {"initial": 0.2})
			layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * r * 0.6, Vector3.ZERO, d + 0.2, 1.6, {"initial": 0.2})
			layer("smoke", false, c, Vector3.ZERO, Vector3(r * 0.5, r * 0.25, r * 0.5), Vector3.ZERO, d + 0.25, 1.4, {"initial": 0.3, "opacity": 0.4})
		_:
			_x_cut(c, target + Vector3.UP * 1.1, 1.4, d)


func _star(id: String, c: Array, index: int, radius: float) -> void:
	match id:
		"umbral_lacerate":
			var turn := 0.8 if index == 0 else -0.8
			for i in 3:
				layer("crescent", true, BLOOD if i == 1 else c, Vector3(0, 1.0 + 0.3 * i, 0), Vector3.ONE * radius * (0.6 - 0.08 * i), Vector3(PI * 0.5 + 0.25 * (i - 1), turn * i, 0), 0.02 * i, 0.55, {"initial": 0.2, "spin": 12.0 * (1 if index == 0 else -1)})
			_x_cut(c, Vector3.UP * 1.5, radius * 0.4, 0.0)
			layer("fangs", false, c, Vector3.ZERO, Vector3(radius * 0.7, 1.5, radius * 0.7), Vector3(0, index * 0.3, 0), 0.04, 1.0, {"initial": 0.2})
			if index == 0:
				layer("sigil", true, c, Vector3(0, 0.05, 0), Vector3.ONE * radius * 0.9, Vector3.ZERO, 0.0, 1.2, {"initial": 0.2, "spin": 1.5})
				_phantom(c, Vector3.ZERO, 0.0, 0.0, 0.9, 1.15, {"initial": 1.2, "opacity": 0.55, "decay": 0.3})
			else:
				layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * radius * 0.6, Vector3.ZERO, 0.0, 1.3, {"initial": 0.2})
				layer("moon", true, c, Vector3(0, 4.5, 0), Vector3.ONE * 1.6, Vector3.ZERO, 0.0, 1.3, {"face_camera": true, "initial": 0.4})
		"shadow_execution":
			var final := index >= 5
			var side := 1.0 if index % 2 == 0 else -1.0
			layer("crescent", true, c if index % 2 == 0 else NIGHT, Vector3.UP * 1.2, Vector3.ONE * (2.6 if final else 1.2 + 0.1 * index), Vector3(0, 0, side * 0.9), 0.0, 0.35, {"initial": 0.3, "roll": -side * 7.0, "face_camera": true})
			_phantom(c, Vector3(side * 1.2, 0, 0.2), -side * PI * 0.5, 0.0, 0.3, 1.0, {"initial": 1.0, "opacity": 0.6, "decay": 0.3})
			if final:
				_x_cut(c, Vector3.UP * 1.3, 3.0, 0.04, NIGHT)
				layer("eclipse", false, c, Vector3(0, 2.8, 0), Vector3.ONE * 1.8, Vector3.ZERO, 0.0, 1.3, {"face_camera": true, "initial": 0.3, "roll": 1.2})
				layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * 2.6, Vector3.ZERO, 0.05, 1.3, {"initial": 0.2})
				layer("fangs", false, c, Vector3.ZERO, Vector3(2.4, 1.4, 2.4), Vector3.ZERO, 0.06, 1.0, {"initial": 0.2})
				layer("smoke", false, c, Vector3.ZERO, Vector3.ONE * 1.4, Vector3.ZERO, 0.08, 1.0, {"initial": 0.3, "opacity": 0.5})
		"veil_of_night":
			layer("moon", true, c, Vector3(0, 3.2, -0.8), Vector3.ONE * 1.6, Vector3.ZERO, 0.0, 1.8, {"face_camera": true, "initial": 0.3})
			layer("smoke", false, c, Vector3.ZERO, Vector3(radius * 0.35, 1.0, radius * 0.35), Vector3.ZERO, 0.0, 1.6, {"initial": 0.2, "grow": 2.0, "opacity": 0.45, "spin": 0.5})
			layer("sigil", true, c, Vector3(0, 0.05, 0), Vector3.ONE * radius * 0.9, Vector3.ZERO, 0.0, 1.7, {"initial": 0.2, "spin": 1.0})
			layer("wings", false, c, Vector3(0, 1.3, -0.5), Vector3.ONE * 1.5, Vector3.ZERO, 0.05, 1.6, {"initial": 0.2, "flap": 0.08, "face_camera": true})
			for side in [-1.0, 1.0]:
				_phantom(c, Vector3(side * 1.6, 0, -0.2), side * -0.5, 0.1, 1.5, 0.95, {"initial": 0.3, "grow": 3.0, "decay": 0.7})
			layer("crown", true, c, Vector3(0, 2.4, 0), Vector3.ONE * 0.9, Vector3.ZERO, 0.1, 1.6, {"initial": 0.2, "spin": 2.0})
		"eclipse_requiem":
			var final := index >= 4
			if index == 0:
				layer("eclipse", false, c, Vector3(0, 7.0, 0), Vector3.ONE * radius * 0.4, Vector3.ZERO, 0.0, 2.6, {"face_camera": true, "initial": 0.3, "roll": 0.6, "decay": 0.85})
				layer("sigil", true, c, Vector3(0, 0.06, 0), Vector3.ONE * radius * 0.95, Vector3.ZERO, 0.0, 2.6, {"initial": 0.2, "spin": 0.8, "decay": 0.85})
			for k in 3:
				var a := float(index * 3 + k) * 2.39996
				var spot := Vector3(sin(a), 0, cos(a)) * radius * (0.25 + 0.2 * float(k))
				layer("dagger", true, BLOOD if k == 1 else c, spot + Vector3.UP * 0.6, Vector3(1.2, 1.8, 1.2), Vector3(PI, a, 0), 0.02 * k, 0.5, {"initial": 1.0, "drop": 7.0, "land": 0.2, "decay": 0.7})
			layer("rift", false, c, Vector3(0, 0.04, 0), Vector3.ONE * radius * (0.4 + 0.08 * index), Vector3(0, index, 0), 0.15, 1.0, {"initial": 0.2})
			if final:
				layer("vortex", true, c, Vector3(0, 0.08, 0), Vector3.ONE * radius * 0.9, Vector3.ZERO, 0.1, 1.4, {"initial": 0.2, "spin": 3.0})
				layer("blades", true, BLOOD, Vector3(0, 1.2, 0), Vector3.ONE * radius * 0.5, Vector3.ZERO, 0.1, 1.3, {"initial": 0.2, "spin": 8.0})
				_x_cut(c, Vector3.UP * 1.6, radius * 0.45, 0.15, NIGHT)


# ---------------------------------------------------------------------------
# Geometry (built once per kind, shared). COLOR.r = inlay / core heat,
# COLOR.g = opacity mask. Flat pieces lie in the XY plane facing +Z, ground
# pieces in the XZ plane, upright figures stand on y = 0 facing +Z.
# ---------------------------------------------------------------------------

static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"crescent": _crescent(st)
		"dagger": _dagger(st)
		"phantom": _phantom_mesh(st)
		"moon": _moon(st)
		"eclipse": _eclipse(st)
		"rift": _rift(st)
		"sigil": _sigil(st)
		"fangs": _fangs(st)
		"smoke": _smoke(st)
		"wings": _wings(st)
		"crown": _crown(st)
		"blades": _blades(st)
		"vortex": _vortex(st)
	var result := st.commit()
	_meshes[kind] = result
	return result


static func _v(st: SurfaceTool, p: Vector3, n: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.add_vertex(p)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n := (b - a).cross(c - a)
	n = n.normalized() if n.length_squared() > 0.0000001 else Vector3.BACK
	_v(st, a, n, ca)
	_v(st, b, n, cb)
	_v(st, c, n, cc)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri(st, a, b, c, ca, cb, cc)
	_tri(st, a, c, d, ca, cc, cd)


## A flat strip from a to b in the plane with normal [param up].
static func _strip(st: SurfaceTool, a: Vector3, b: Vector3, width: float, up: Vector3, ca: Color, cb: Color, end_width := -1.0) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(up).normalized()
	var w2 := width if end_width < 0.0 else end_width
	_quad(st, a - side * width * 0.5, b - side * w2 * 0.5, b + side * w2 * 0.5, a + side * width * 0.5, ca, cb, cb, ca)


## A smooth tube through points (radius per point), coloured per point.
static func _tube(st: SurfaceTool, points: Array, radii: Array, colors: Array, sides := 6) -> void:
	var rings: Array = []
	for i in points.size():
		var p: Vector3 = points[i]
		var a: Vector3 = points[maxi(i - 1, 0)]
		var b: Vector3 = points[mini(i + 1, points.size() - 1)]
		var axis := (b - a).normalized()
		var helper := Vector3.BACK if absf(axis.z) < 0.9 else Vector3.RIGHT
		var u := axis.cross(helper).normalized()
		var v := axis.cross(u)
		var ring: Array = []
		for s in sides:
			var t := TAU * float(s) / float(sides)
			var d := u * cos(t) + v * sin(t)
			ring.append([p + d * float(radii[i]), d])
		rings.append(ring)
	for i in points.size() - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			var q := [rings[i][s], rings[i + 1][s], rings[i + 1][s2], rings[i][s2]]
			var cols := [colors[i], colors[i + 1], colors[i + 1], colors[i]]
			for k in [0, 1, 2, 0, 2, 3]:
				_v(st, q[k][0], q[k][1], cols[k])


static func _sphere(st: SurfaceTool, centre: Vector3, radius: Vector3, color: Color, rings := 5, seg := 8) -> void:
	for r in rings:
		for s in seg:
			var pts: Array = []
			for k in [[r, s], [r + 1, s], [r + 1, s + 1], [r, s + 1]]:
				var phi := PI * float(k[0]) / float(rings)
				var th := TAU * float(k[1]) / float(seg)
				var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
				pts.append([centre + d * radius, d])
			for k in [0, 1, 2, 0, 2, 3]:
				_v(st, pts[k][0], pts[k][1], color)


static func _crescent(st: SurfaceTool) -> void:
	# A sweeping cut: a white-hot leading edge fading into the arc.
	var rows := 28
	for i in rows:
		var t0 := float(i) / rows
		var t1 := float(i + 1) / rows
		var a0 := lerpf(-1.3, 1.3, t0)
		var a1 := lerpf(-1.3, 1.3, t1)
		var w0 := 0.36 * pow(sin(PI * t0), 0.8)
		var w1 := 0.36 * pow(sin(PI * t1), 0.8)
		var o0 := Vector3(sin(a0), cos(a0), 0)
		var o1 := Vector3(sin(a1), cos(a1), 0)
		var m0 := o0 * (1.0 - w0 * 0.3)
		var m1 := o1 * (1.0 - w1 * 0.3)
		var n0 := o0 * (1.0 - w0)
		var n1 := o1 * (1.0 - w1)
		var edge0 := Color(1, minf(1.0, 0.25 + 3.0 * w0), 0)
		var edge1 := Color(1, minf(1.0, 0.25 + 3.0 * w1), 0)
		_quad(st, o0, o1, m1, m0, edge0, edge1, Color(0.6, 0.9, 0), Color(0.6, 0.9, 0))
		_quad(st, m0, m1, n1, n0, Color(0.6, 0.9, 0), Color(0.6, 0.9, 0), Color(0.1, 0, 0), Color(0.1, 0, 0))


static func _dagger(st: SurfaceTool) -> void:
	# Along +Y, the tip at y = 1: a diamond-section blade with bright edges, a guard, grip and pommel.
	var rows := 10
	var rings: Array = []
	for i in rows + 1:
		var t := float(i) / rows
		var y := lerpf(0.24, 1.0, t)
		var w := 0.075 * (1.0 - pow(t, 1.5)) + 0.002
		var th := 0.022 * (1.0 - t * 0.7)
		rings.append([Vector3(-w, y, 0), Vector3(0, y, th), Vector3(w, y, 0), Vector3(0, y, -th)])
	var edge := Color(1, 1, 0)
	var ridge := Color(0.35, 1, 0)
	for i in rows:
		for k in 4:
			var k2 := (k + 1) % 4
			_quad(st, rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k], edge if k % 2 == 0 else ridge, edge if k2 % 2 == 0 else ridge, edge if k2 % 2 == 0 else ridge, edge if k % 2 == 0 else ridge)
	_tube(st, [Vector3(-0.17, 0.215, 0), Vector3(0, 0.2, 0), Vector3(0.17, 0.215, 0)], [0.02, 0.028, 0.02], [Color(0.7, 1, 0), Color(0.4, 1, 0), Color(0.7, 1, 0)], 5)
	_tube(st, [Vector3(0, 0.0, 0), Vector3(0, 0.2, 0)], [0.025, 0.022], [Color(0, 1, 0), Color(0, 1, 0)], 6)
	_sphere(st, Vector3(0, -0.03, 0), Vector3.ONE * 0.04, Color(1, 1, 0), 3, 6)


static func _phantom_mesh(st: SurfaceTool) -> void:
	# A hooded assassin of shadow, about 1.9 tall, facing +Z with a dagger in each hand.
	var body := Color(0, 1, 0)
	var hem := Color(0, 0.25, 0)
	var seg := 14
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var y0 := 0.06 + (0.16 if i % 2 == 1 else 0.0)
		var y1 := 0.06 + (0.0 if i % 2 == 1 else 0.16)
		var b0 := Vector3(sin(a0) * 0.52, y0, cos(a0) * 0.46 - 0.05)
		var b1 := Vector3(sin(a1) * 0.52, y1, cos(a1) * 0.46 - 0.05)
		var t0 := Vector3(sin(a0) * 0.2, 1.3, cos(a0) * 0.17)
		var t1 := Vector3(sin(a1) * 0.2, 1.3, cos(a1) * 0.17)
		var n0 := Vector3(sin(a0), 0.35, cos(a0)).normalized()
		var n1 := Vector3(sin(a1), 0.35, cos(a1)).normalized()
		for k in [[b0, n0, hem], [t0, n0, body], [t1, n1, body], [b0, n0, hem], [t1, n1, body], [b1, n1, hem]]:
			_v(st, k[0], k[1], k[2])
	_sphere(st, Vector3(0, 1.47, 0.0), Vector3(0.27, 0.25, 0.27), body, 5, 10)
	# The hood's peak, swept back.
	for i in 10:
		var a0 := TAU * float(i) / 10.0
		var a1 := TAU * float(i + 1) / 10.0
		var r0 := Vector3(sin(a0) * 0.28, 1.56, cos(a0) * 0.27)
		var r1 := Vector3(sin(a1) * 0.28, 1.56, cos(a1) * 0.27)
		_tri(st, r0, r1, Vector3(0, 1.98, -0.2), body, body, Color(0.4, 1, 0))
	# Eyes that burn in the hood.
	for side in [-1.0, 1.0]:
		var eye := Vector3(side * 0.09, 1.47, 0.255)
		_tri(st, eye + Vector3(-0.045, 0, 0), eye + Vector3(0, 0.022, 0.01), eye + Vector3(0.045, 0, 0), Color(1, 1, 0), Color(1, 1, 0), Color(1, 1, 0))
		_tri(st, eye + Vector3(-0.045, 0, 0), eye + Vector3(0.045, 0, 0), eye + Vector3(0, -0.018, 0.01), Color(1, 1, 0), Color(1, 1, 0), Color(1, 1, 0))
		# Arms reaching forward, each ending in a dagger pointing ahead and down.
		var shoulder := Vector3(side * 0.22, 1.24, 0.02)
		var elbow := Vector3(side * 0.36, 1.05, 0.25)
		var hand := Vector3(side * 0.3, 1.0, 0.5)
		_tube(st, [shoulder, elbow, hand], [0.075, 0.06, 0.05], [body, body, body], 6)
		var tip := hand + Vector3(side * 0.08, -0.12, 0.5)
		_tube(st, [hand, hand.lerp(tip, 0.5), tip], [0.03, 0.022, 0.002], [Color(0.8, 1, 0), Color(1, 1, 0), Color(1, 1, 0)], 4)
	# A scarf tail streaming behind.
	_tube(st, [Vector3(0, 1.32, -0.18), Vector3(0.12, 1.2, -0.5), Vector3(0.3, 1.02, -0.85), Vector3(0.42, 0.95, -1.15)], [0.06, 0.05, 0.035, 0.005], [body, Color(0.2, 0.9, 0), Color(0.4, 0.6, 0), Color(0.6, 0.2, 0)], 4)


static func _moon(st: SurfaceTool) -> void:
	# A crescent moon opening to the right, glowing rim on the outside.
	var rows := 32
	for i in rows:
		var t0 := float(i) / rows
		var t1 := float(i + 1) / rows
		var a0 := lerpf(PI * 0.22, PI * 1.78, t0)
		var a1 := lerpf(PI * 0.22, PI * 1.78, t1)
		var w0 := 0.5 * pow(sin(PI * t0), 0.7)
		var w1 := 0.5 * pow(sin(PI * t1), 0.7)
		var o0 := Vector3(cos(a0), sin(a0), 0)
		var o1 := Vector3(cos(a1), sin(a1), 0)
		var i0 := o0 * (1.0 - w0) + Vector3(w0 * 0.35, 0, 0)
		var i1 := o1 * (1.0 - w1) + Vector3(w1 * 0.35, 0, 0)
		_quad(st, o0, o1, i1, i0, Color(1, 1, 0), Color(1, 1, 0), Color(0.45, 0.85, 0), Color(0.45, 0.85, 0))
	# A soft halo around it.
	for i in 24:
		var a0 := TAU * float(i) / 24.0
		var a1 := TAU * float(i + 1) / 24.0
		_quad(st, Vector3(cos(a0), sin(a0), -0.01) * 1.02, Vector3(cos(a1), sin(a1), -0.01) * 1.02, Vector3(cos(a1), sin(a1), -0.01) * 1.32, Vector3(cos(a0), sin(a0), -0.01) * 1.32, Color(0.3, 0.35, 0), Color(0.3, 0.35, 0), Color(0, 0, 0), Color(0, 0, 0))


static func _eclipse(st: SurfaceTool) -> void:
	# A black sun: a dark disc, a burning corona and long and short rays.
	var seg := 32
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var d0 := Vector3(cos(a0), sin(a0), 0)
		var d1 := Vector3(cos(a1), sin(a1), 0)
		_tri(st, Vector3.ZERO, d0, d1, Color(0, 1, 0), Color(0.05, 1, 0), Color(0.05, 1, 0))
		_quad(st, d0, d1, d1 * 1.16, d0 * 1.16, Color(1, 1, 0), Color(1, 1, 0), Color(0.7, 0.8, 0), Color(0.7, 0.8, 0))
		_quad(st, d0 * 1.16, d1 * 1.16, d1 * 1.34, d0 * 1.34, Color(0.7, 0.8, 0), Color(0.7, 0.8, 0), Color(0.3, 0, 0), Color(0.3, 0, 0))
	for k in 12:
		var a := TAU * float(k) / 12.0
		var long := 1.75 if k % 2 == 0 else 1.45
		var d := Vector3(cos(a), sin(a), 0.005)
		var side := Vector3(-sin(a), cos(a), 0) * 0.07
		_tri(st, d * 1.14 - side, d * long, d * 1.14 + side, Color(1, 1, 0), Color(0.6, 0.2, 0), Color(1, 1, 0))


static func _rift(st: SurfaceTool) -> void:
	# A tear in the ground: a dark pool and jagged glowing cracks running out of it.
	var up := Vector3.UP
	var seg := 18
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var r0 := 0.5 * (1.0 + 0.22 * sin(a0 * 5.0))
		var r1 := 0.5 * (1.0 + 0.22 * sin(a1 * 5.0))
		_tri(st, Vector3.ZERO, Vector3(sin(a1) * r1, 0, cos(a1) * r1), Vector3(sin(a0) * r0, 0, cos(a0) * r0), Color(0, 1, 0), Color(0.15, 0.7, 0), Color(0.15, 0.7, 0))
	for k in 9:
		var a := TAU * float(k) / 9.0 + 0.2
		var dir := Vector3(sin(a), 0, cos(a))
		var side := Vector3(cos(a), 0, -sin(a))
		var pts := [dir * 0.4, dir * 0.62 + side * 0.08, dir * 0.82 - side * 0.07, dir * (1.0 + 0.12 * float(k % 3))]
		for j in pts.size() - 1:
			_strip(st, pts[j] + up * 0.005, pts[j + 1] + up * 0.005, 0.07 * (1.0 - float(j) * 0.3), up, Color(1, 1, 0), Color(1, 0.8 - 0.2 * j, 0), 0.07 * (1.0 - float(j + 1) * 0.3))


static func _sigil(st: SurfaceTool) -> void:
	# The death mark: two rings, an inverted triangle, six dagger glyphs and a crescent at the heart.
	var up := Vector3.UP
	for ring in [[1.0, 0.035, 0.75], [0.84, 0.016, 0.6]]:
		var r := float(ring[0])
		var w := float(ring[1])
		var tone := Color(float(ring[2]), 0.9, 0)
		for i in 48:
			var a0 := TAU * float(i) / 48.0
			var a1 := TAU * float(i + 1) / 48.0
			var d0 := Vector3(sin(a0), 0, cos(a0))
			var d1 := Vector3(sin(a1), 0, cos(a1))
			_quad(st, d0 * (r - w), d1 * (r - w), d1 * (r + w), d0 * (r + w), tone, tone, tone, tone)
	var corners: Array = []
	for k in 3:
		var a := TAU * float(k) / 3.0 + PI
		corners.append(Vector3(sin(a), 0, cos(a)) * 0.84)
	for k in 3:
		_strip(st, corners[k], corners[(k + 1) % 3], 0.025, up, Color(0.55, 0.85, 0), Color(0.55, 0.85, 0))
	for k in 6:
		var a := TAU * float(k) / 6.0 + PI / 6.0
		var dir := Vector3(sin(a), 0, cos(a))
		var side := Vector3(cos(a), 0, -sin(a))
		_tri(st, dir * 0.88 - side * 0.05, dir * 1.18, dir * 0.88 + side * 0.05, Color(1, 1, 0), Color(1, 0.6, 0), Color(1, 1, 0))
		_strip(st, dir * 0.88, dir * 0.8, 0.05, up, Color(0.6, 1, 0), Color(0.6, 1, 0))
	for i in 16:
		var t0 := float(i) / 16.0
		var t1 := float(i + 1) / 16.0
		var a0 := lerpf(PI * 0.22, PI * 1.78, t0)
		var a1 := lerpf(PI * 0.22, PI * 1.78, t1)
		var w0 := 0.5 * pow(sin(PI * t0), 0.7)
		var w1 := 0.5 * pow(sin(PI * t1), 0.7)
		var o0 := Vector3(cos(a0), 0, sin(a0)) * 0.24
		var o1 := Vector3(cos(a1), 0, sin(a1)) * 0.24
		_quad(st, o0, o1, o1 * (1.0 - w1), o0 * (1.0 - w0), Color(1, 1, 0), Color(1, 1, 0), Color(0.8, 1, 0), Color(0.8, 1, 0))


static func _fangs(st: SurfaceTool) -> void:
	# Ten curved shadow fangs bursting from the ground in a ring, leaning inward.
	for k in 10:
		var a := TAU * float(k) / 10.0
		var dir := Vector3(sin(a), 0, cos(a))
		var h := 0.7 if k % 2 == 0 else 0.5
		var base := dir * 1.0
		_tube(st, [base, base - dir * 0.05 + Vector3.UP * h * 0.5, base - dir * 0.2 + Vector3.UP * h], [0.09, 0.05, 0.003], [Color(0, 1, 0), Color(0.3, 1, 0), Color(1, 1, 0)], 4)


static func _smoke(st: SurfaceTool) -> void:
	# A shell of night: a swollen dome of overlapping puffs, thinner at the edges.
	_sphere(st, Vector3(0, 0.5, 0), Vector3(0.55, 0.5, 0.55), Color(0, 0.75, 0), 5, 9)
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		_sphere(st, Vector3(sin(a) * 0.62, 0.3 + 0.08 * float(k % 2), cos(a) * 0.62), Vector3.ONE * (0.36 + 0.06 * float(k % 3)), Color(0, 0.55, 0), 4, 8)
	_sphere(st, Vector3(0.1, 0.95, -0.05), Vector3.ONE * 0.32, Color(0, 0.6, 0), 4, 8)


static func _wings(st: SurfaceTool) -> void:
	# Shadow bat wings spreading from the back (XY plane, roots at the origin).
	for side in [-1.0, 1.0]:
		var wrist := Vector3(side * 0.62, 0.5, 0)
		var tips := [Vector3(side * 0.95, 1.25, 0), Vector3(side * 1.45, 0.95, 0), Vector3(side * 1.55, 0.4, 0), Vector3(side * 1.2, -0.15, 0), Vector3(side * 0.6, -0.35, 0)]
		_tube(st, [Vector3(side * 0.05, 0.05, 0), wrist], [0.05, 0.035], [Color(0.4, 1, 0), Color(0.7, 1, 0)], 5)
		for i in tips.size():
			_tube(st, [wrist, tips[i]], [0.025, 0.004], [Color(0.7, 1, 0), Color(1, 1, 0)], 4)
		for i in tips.size() - 1:
			var a: Vector3 = tips[i]
			var b: Vector3 = tips[i + 1]
			var scallop := a.lerp(b, 0.5).lerp(wrist, 0.22)
			_tri(st, wrist, a, scallop, Color(0, 0.85, 0), Color(0.2, 0.8, 0), Color(0.5, 0.7, 0))
			_tri(st, wrist, scallop, b, Color(0, 0.85, 0), Color(0.5, 0.7, 0), Color(0.2, 0.8, 0))
		var last: Vector3 = tips[tips.size() - 1]
		_tri(st, Vector3(side * 0.05, 0.05, 0), wrist, last, Color(0, 0.9, 0), Color(0, 0.85, 0), Color(0.3, 0.7, 0))


static func _crown(st: SurfaceTool) -> void:
	# A crown of eight daggers, points up and leaning out, on a thin ring.
	var blade := mesh("dagger")
	for k in 8:
		var a := TAU * float(k) / 8.0
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.32) * Basis.from_scale(Vector3.ONE * 0.55)
		st.append_from(blade, 0, Transform3D(basis, Vector3(sin(a), 0, cos(a)) * 0.42))
	for i in 32:
		var a0 := TAU * float(i) / 32.0
		var a1 := TAU * float(i + 1) / 32.0
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		_quad(st, d0 * 0.4, d1 * 0.4, d1 * 0.48, d0 * 0.48, Color(1, 1, 0), Color(1, 1, 0), Color(1, 1, 0), Color(1, 1, 0))


static func _blades(st: SurfaceTool) -> void:
	# Twelve daggers lying flat in a ring, points chasing each other around it.
	var blade := mesh("dagger")
	for k in 12:
		var a := TAU * float(k) / 12.0
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.FORWARD, PI * 0.5) * Basis.from_scale(Vector3.ONE * 0.36)
		st.append_from(blade, 0, Transform3D(basis, Vector3(sin(a), 0, cos(a))))


static func _vortex(st: SurfaceTool) -> void:
	# Five spiral arms winding into a dark centre (XZ plane).
	var up := Vector3.UP
	for arm in 5:
		var base := TAU * float(arm) / 5.0
		var prev := Vector3.ZERO
		for i in 15:
			var t := float(i + 1) / 15.0
			var r := 0.12 + 0.88 * t
			var a := base + t * 2.4
			var p := Vector3(sin(a) * r, 0.002 * float(arm), cos(a) * r)
			if i > 0:
				_strip(st, prev, p, 0.16 * (1.0 - t) + 0.02, up, Color(1.0 - t * 0.6, 1, 0), Color(1.0 - t * 0.6, 1.0 - t * 0.4, 0), 0.16 * (1.0 - t - 1.0 / 15.0) + 0.02)
			prev = p
