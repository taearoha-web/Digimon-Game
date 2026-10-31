class_name ThunderStormArt
extends Node3D
## A great ring of light hanging in the sky over the storm zone, crackling with arcs of
## lightning that run round it, from which the bolts strike down (it replaced the old
## storm cloud). No lights, CPU particles, camera effects or full-screen flash.
const CLOUD_HEIGHT := 8.8
const SEAL_SHADER := preload("res://shaders/thunder_seal.gdshader")
const IMPACT_SHADER := preload("res://shaders/thunder_impact.gdshader")
## Bolt tubes keyed by their rounded path and width: repeated strikes on the
## same spot reuse the geometry instead of building a new tube per layer.
const BOLT_CACHE_LIMIT := 48
static var _bolt_meshes: Dictionary = {}
var radius := 9.0
## The sky ring (named ThunderStormCloud, as the cloud it replaced was).
var cloud: MeshInstance3D
## The ring's own materials and their full alpha, faded and pulsed together.
var _ring_mats: Array[StandardMaterial3D] = []
var _ring_alpha: Array[float] = []
var _ring_root: Node3D
const RING_COLOR := Color(0.55, 0.82, 1.0)
const ARC_COLOR := Color(0.85, 0.95, 1.0)
const ARCS := 8
var _seal_mat: ShaderMaterial

static func warm_up(parent: Node3D, at: Vector3) -> void:
	var sample := ThunderStormArt.new()
	sample.radius = 0.01
	sample.scale = Vector3.ONE * 0.001
	sample.position = at
	parent.add_child(sample)
	sample._impact(Vector3.ZERO)
	sample.create_tween().tween_interval(0.45).finished.connect(sample.queue_free, CONNECT_ONE_SHOT)

func _ready() -> void:
	_build_ring()
	# A single quad carries the entire engraved seal, including its mist band.
	_seal_mat = ShaderMaterial.new()
	_seal_mat.shader = SEAL_SHADER
	_seal_mat.set_shader_parameter("age", 0.0)
	var seal := MeshInstance3D.new()
	seal.name = "EssentialSkillRange"
	seal.mesh = SkillInk.quad()
	seal.material_override = _seal_mat
	seal.position.y = 0.055
	seal.rotation.x = -PI * 0.5
	seal.scale = Vector3.ONE * (radius / 0.94)
	seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(seal)
	VfxBudget.track_decoration(seal)
	var tw := create_tween()
	tw.tween_method(_set_fade, 0.0, 1.0, 0.5)
	tw.tween_interval(1.55)
	tw.tween_method(_set_fade, 1.0, 0.0, 0.55)
	# Tween age rather than shader TIME: pause freezes the engravings.
	create_tween().tween_method(func(v: float): _seal_mat.set_shader_parameter("age", v), 0.0, 2.6, 2.6)

func _set_fade(value: float) -> void:
	_seal_mat.set_shader_parameter("fade", value)
	for i in _ring_mats.size():
		_ring_mats[i].albedo_color.a = _ring_alpha[i] * value

func flash() -> void:
	_set_pulse(1.0)
	create_tween().tween_method(_set_pulse, 1.0, 0.0, 0.42)

func _set_pulse(value: float) -> void:
	_seal_mat.set_shader_parameter("pulse", value)
	if is_instance_valid(_ring_root):
		_ring_root.scale = Vector3.ONE * (1.0 + 0.06 * value)
	for m in _ring_mats:
		var a := m.albedo_color.a
		m.albedo_color = RING_COLOR.lerp(Color.WHITE, 0.25 + 0.6 * value) if m.has_meta("ring") else m.albedo_color
		m.albedo_color.a = a

func strike(to: Vector3, seed_value: int) -> void:
	var points := PackedVector3Array()
	# From the ring's edge above the target, down onto it.
	var flat := Vector2(to.x, to.z)
	var edge := (flat.normalized() if flat.length() > 0.5 else Vector2(1, 0)) * ring_radius()
	var start := Vector3(edge.x, CLOUD_HEIGHT, edge.y)
	for i in 12:
		var t := float(i) / 11.0
		var p := start.lerp(to, t)
		if i > 0 and i < 11:
			p.x += sin(seed_value * 3.7 + i * 8.1) * 0.65
			p.z += cos(seed_value * 5.3 + i * 6.7) * 0.48
		points.append(p)
	# Essential gold path is always rendered. Halos, forks and impact engraving
	# share the global decoration budget, so overlapping casts remain bounded.
	_bolt_layer(points, 0.20, Color("ffd044"), "ThunderStormStrike", 2, false)
	_bolt_layer(points, 0.58, Color(0.10, 0.48, 1.0, 0.16), "ThunderStormCorona", 0)
	_bolt_layer(points, 0.34, Color(0.18, 0.70, 1.0, 0.60), "ThunderStormBlue", 1)
	_bolt_layer(points, 0.085, Color("fff7ce"), "ThunderStormCore", 3)
	for fork in VfxBudget.count(3, 1):
		var joint := 2 + fork * 2
		var side := -1.0 if (seed_value + fork) % 2 == 0 else 1.0
		var branch := PackedVector3Array([points[joint], points[joint] + Vector3(side * 1.25, -0.45, 0.35), points[joint] + Vector3(side * 0.8, -1.0, 0.6), points[joint] + Vector3(side * 1.8, -1.8, 0.85)])
		_bolt_layer(branch, 0.105, Color(0.24, 0.73, 1.0, 0.8), "ThunderStormFork", 1)
		_bolt_layer(branch, 0.038, Color("ffe597"), "ThunderStormForkCore", 2)
	_impact(to)

func ring_radius() -> float:
	return radius * 0.72


## The sky ring: a thick glowing band with a soft halo, a thin inner ring turning the other
## way, runes round the band and arcs of lightning crackling along it.
func _build_ring() -> void:
	_ring_root = Node3D.new()
	_ring_root.name = "ThunderStormRing"
	_ring_root.position.y = CLOUD_HEIGHT
	add_child(_ring_root)
	var r := ring_radius()
	var outer := Node3D.new()
	_ring_root.add_child(outer)
	cloud = _torus(outer, "ThunderStormCloud", r, 0.32, _ring_mat(RING_COLOR.lerp(Color.WHITE, 0.25), 0.95, true))
	VfxBudget.track_decoration(cloud)
	if VfxBudget.can_decorate():
		VfxBudget.track_decoration(_torus(outer, "ThunderStormHalo", r, 0.9, _ring_mat(RING_COLOR, 0.28)))
		for k in 12:
			var a := TAU * float(k) / 12.0
			var rune := MeshInstance3D.new()
			rune.name = "ThunderStormRune"
			rune.mesh = SkillInk.quad()
			rune.material_override = _ring_mat(Color(0.95, 0.98, 1.0), 0.9)
			rune.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
			rune.scale = Vector3(0.22, 0.22, 0.22)
			rune.rotation = Vector3(-PI * 0.5, 0.0, a)
			rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			outer.add_child(rune)
	var spin := outer.create_tween().set_loops()
	spin.tween_property(outer, "rotation:y", TAU, 6.0).from(0.0)
	if VfxBudget.can_decorate():
		var inner := Node3D.new()
		_ring_root.add_child(inner)
		VfxBudget.track_decoration(_torus(inner, "ThunderStormInnerRing", r * 0.62, 0.12, _ring_mat(Color(0.75, 0.9, 1.0), 0.8)))
		var back := inner.create_tween().set_loops()
		back.tween_property(inner, "rotation:y", -TAU, 4.0).from(0.0)
	# Arcs of lightning running round the band, each flickering on its own beat.
	for k in VfxBudget.count(ARCS, 3):
		var a0 := TAU * float(k) / float(ARCS)
		var pts := PackedVector3Array()
		for j in 7:
			var a := a0 + 0.55 * float(j) / 6.0
			var wob := 0.0 if j == 0 or j == 6 else (0.45 if (j + k) % 2 == 0 else -0.45)
			pts.append(Vector3(cos(a) * (r + wob * 0.6), wob, sin(a) * (r + wob * 0.6)))
		var arc := MeshInstance3D.new()
		arc.name = "ThunderStormArc"
		arc.mesh = bolt_mesh(pts, 0.07)
		var mat := _ring_mat(ARC_COLOR, 1.0)
		arc.material_override = mat
		arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		outer.add_child(arc)
		VfxBudget.track_decoration(arc)
		var flick := arc.create_tween().set_loops()
		flick.tween_property(arc, "visible", true, 0.0)
		flick.tween_interval(0.08 + 0.03 * float(k % 3))
		flick.tween_property(arc, "visible", false, 0.0)
		flick.tween_interval(0.1 + 0.05 * float((k * 2) % 5))


func _torus(parent: Node3D, label: String, ring_r: float, thickness: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = ring_r - thickness * 0.5
	mesh.outer_radius = ring_r + thickness * 0.5
	mesh.rings = 64
	mesh.ring_segments = 10
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _ring_mat(color: Color, alpha: float, is_ring := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	MaterialKeeper.keep(m)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.0)
	if is_ring:
		m.set_meta("ring", true)
	_ring_mats.append(m)
	_ring_alpha.append(alpha)
	return m


func _impact(at: Vector3) -> void:
	if not VfxBudget.can_decorate():
		return
	var node := MeshInstance3D.new()
	node.name = "ThunderStormImpact"
	node.mesh = SkillInk.quad()
	var mat := ShaderMaterial.new()
	mat.shader = IMPACT_SHADER
	node.material_override = mat
	node.position = Vector3(at.x, 0.075, at.z)
	node.rotation.x = -PI * 0.5
	node.scale = Vector3.ONE * 1.9
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	VfxBudget.track_decoration(node)
	var tw := node.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("age", v), 0.0, 1.0, 0.48)
	tw.tween_callback(node.queue_free)

func _bolt_layer(points: PackedVector3Array, width: float, color: Color, label: String, priority: int, decorative := true) -> void:
	if decorative and not VfxBudget.can_decorate():
		return
	var bolt := MeshInstance3D.new()
	bolt.name = label
	bolt.mesh = bolt_mesh(points, width)
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	MaterialKeeper.keep(mat)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.render_priority = priority
	bolt.material_override = mat
	add_child(bolt)
	if decorative:
		VfxBudget.track_decoration(bolt)
	var tw := bolt.create_tween()
	tw.tween_interval(0.13)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.24)
	tw.tween_callback(bolt.queue_free)


static func bolt_mesh(points: PackedVector3Array, width: float) -> ArrayMesh:
	var rounded := PackedInt32Array()
	for point in points:
		rounded.append(roundi(point.x * 100.0))
		rounded.append(roundi(point.y * 100.0))
		rounded.append(roundi(point.z * 100.0))
	rounded.append(roundi(width * 1000.0))
	var key := var_to_bytes(rounded).hex_encode()
	if _bolt_meshes.has(key):
		return _bolt_meshes[key]
	if _bolt_meshes.size() >= BOLT_CACHE_LIMIT:
		# Dropping a reference never invalidates a bolt that is still drawn.
		_bolt_meshes.erase(_bolt_meshes.keys()[0])
	var mesh := SpellSpectacle._tube_mesh(points, width)
	_bolt_meshes[key] = mesh
	return mesh


## Drops the cached effect meshes (on travel: effects seen in the last zone, cast by any
## class nearby, need not stay in a phone's memory). Live effects keep their own.
static func release_mesh_cache() -> void:
	_bolt_meshes.clear()
