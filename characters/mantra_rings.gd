class_name MantraRings
extends MultiMeshInstance3D
## The Muay Thai fighter's mantra rings (วงประเจียด): 2 / 4 / 6 glowing cloth bands
## (MuayThai.ring_count by level) orbiting the body at chest height, each turning on
## itself. One node and one draw for all of them: a MultiMesh of ONE shared low-poly
## torus with ONE shared unshaded emissive material (the class's orange-gold fire), no
## light, no shadow, no particles. The orbit follows the graphics quality: on the lowest
## quality (or a crowd's light dress) it moves every other frame and does not bob; far
## from the camera (HeroVisual.set_far) the rings are hidden and nothing is updated.
## A skill that throws them (MuayThai: ring throw, ultimate) lends them out: they hide
## while their flying copies (fly) are away, then come back.

const HEIGHT := 1.2
const RADIUS := 0.56
const SPIN := 1.6
const SIZE := 0.17
const COLOR := Color("ffb347")
const GLOW := Color("ff7a1a")

static var _mesh: TorusMesh
static var _mat: StandardMaterial3D

var count := 2
var _visual: Node3D
var _time := 0.0
var _frame := 0
var _away_until := 0
var _cheap := false


static func mesh() -> TorusMesh:
	if _mesh == null:
		_mesh = TorusMesh.new()
		_mesh.inner_radius = SIZE * 0.78
		_mesh.outer_radius = SIZE
		_mesh.rings = 12
		_mesh.ring_segments = 4
		_mesh.material = material()
	return _mesh


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.albedo_color = COLOR
		_mat.emission_enabled = true
		_mat.emission = GLOW
		_mat.emission_energy_multiplier = 1.6
	return _mat


func setup(visual: Node3D, rings: int) -> void:
	name = "MantraRings"
	_visual = visual
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh()
	multimesh = mm
	_cheap = GameSettings.quality == 0 or bool(visual.get("decor_light"))
	set_count(rings)


func set_count(rings: int) -> void:
	count = clampi(rings, 0, 6)
	if multimesh != null and multimesh.instance_count != count:
		multimesh.instance_count = count
		_place()


## The rings fly off for [param seconds] (a throw): hidden here until they are back.
func lend(seconds: float) -> void:
	_away_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	visible = false


func _process(delta: float) -> void:
	if _away_until > 0 and Time.get_ticks_msec() >= _away_until:
		_away_until = 0
	var far := bool(_visual.get("_far")) if is_instance_valid(_visual) else false
	var show := _away_until == 0 and not far
	if visible != show:
		visible = show
	if not show:
		return
	_time += delta
	_frame += 1
	if _cheap and _frame % 2 == 1:
		return
	_place()


func _place() -> void:
	if multimesh == null:
		return
	for i in count:
		var a := _time * SPIN + TAU * float(i) / float(maxi(count, 1))
		var bob := 0.0 if _cheap else 0.08 * sin(_time * 2.3 + float(i) * 1.7)
		# Rings of a pair sit on two heights, so six read as a crown of bands, not a belt.
		var y := HEIGHT + (0.16 if i % 2 == 1 else -0.04) + bob
		var at := Vector3(cos(a) * RADIUS, y, sin(a) * RADIUS)
		# Each band faces outward and rolls along its orbit.
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.5 + 0.15 * sin(_time * 1.3 + float(i)))
		multimesh.set_instance_transform(i, Transform3D(b, at))


## A flying copy of a ring (the throws): from [param from] to [param to] and back to
## [param home] (a Node3D followed as it moves) over [param seconds]; one mesh node,
## freed when it lands back.
static func fly(parent: Node, from: Vector3, to: Vector3, home: Node3D, seconds := 0.6, scale := 1.6) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var ring := MeshInstance3D.new()
	ring.mesh = mesh()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3.ONE * scale
	parent.add_child(ring)
	VfxBudget.track_decoration(ring)
	ring.global_position = from
	var home_ref: WeakRef = weakref(home) if home != null else null
	var tween := ring.create_tween()
	tween.tween_method(func(t: float):
		if not is_instance_valid(ring):
			return
		var back: Node3D = home_ref.get_ref() as Node3D if home_ref != null else null
		var end := back.global_position + Vector3(0, HEIGHT, 0) if is_instance_valid(back) else from
		var p := from.lerp(to, sin(t * PI * 0.5)) if t < 1.0 else to.lerp(end, t - 1.0)
		ring.global_position = p + Vector3(0, sin(t * PI) * 0.4, 0)
		ring.rotation = Vector3(PI * 0.5, t * 14.0, 0.0)
	, 0.0, 2.0, seconds)
	tween.tween_callback(ring.queue_free)
