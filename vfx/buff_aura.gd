class_name BuffAura
extends Node3D
## A lasting effect that shows a buff on a character, in the spirit of Priston
## Tale: a green barrier bubble for defence, a flaring power aura for attack,
## wind rings for speed and drifting sparkles for critical chance.
##   kind: "shield" | "power" | "wind" | "spark"

const SHIELD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.4, 1.0, 0.6, 1.0);
uniform float strength = 1.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.0);
	float sweep = 0.5 + 0.5 * sin(wpos.y * 8.0 - TIME * 2.4);
	float hex = 0.5 + 0.5 * sin(wpos.x * 9.0 + wpos.z * 5.0 + TIME * 0.8) * sin(wpos.z * 9.0 - wpos.x * 5.0);
	float a = clamp(fres * 0.85 + sweep * 0.05 + hex * 0.03 + 0.025, 0.0, 1.0) * strength;
	ALBEDO = tint.rgb * (0.35 + fres * 0.7);
	ALPHA = a;
}
"""

static var _shield_shader: Shader

var kind := "shield"
## Height of the character it surrounds (feet to top of hair/hat); sizes the barrier.
var body_top := 2.8
var color := Color("5aff9a")
var _age := 0.0
var _spin: Array[Node3D] = []
var _body: Node3D
var _base_scale := Vector3.ONE
var _material: ShaderMaterial


func setup(p_kind: String, p_color: Color) -> void:
	kind = p_kind
	color = p_color


func _ready() -> void:
	match kind:
		"shield": _build_shield()
		"power": _build_power()
		"wind": _build_wind()
		_: _build_spark()
	scale = Vector3.ONE * 0.2
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_age += delta
	for node in _spin:
		node.rotation.y += delta * float(node.get_meta("spin", 1.0))
	if _material:
		_material.set_shader_parameter("strength", 0.9 + 0.12 * sin(_age * 3.0))
	if kind == "shield" and _body:
		_body.scale = _base_scale * (1.0 + 0.02 * sin(_age * 3.0))


func _build_shield() -> void:
	if _shield_shader == null:
		_shield_shader = Shader.new()
		_shield_shader.code = SHIELD_SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shield_shader
	_material.set_shader_parameter("tint", Color(color.r, color.g, color.b, 1.0))
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 28
	sphere.rings = 14
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The hero measures ~2.8 m with its big head: the bubble runs from below the soles to above the hair.
	var half := body_top * 0.5 + 0.45
	mi.scale = Vector3(half * 0.9, half, half * 0.9)
	mi.position = Vector3(0, body_top * 0.5, 0)
	add_child(mi)
	_body = mi
	_base_scale = mi.scale
	# A glowing base ring where the bubble meets the ground.
	_ring(Vector3(0, 0.06, 0), half * 0.8, color, 0.7, 1.4)


func _build_power() -> void:
	_ring(Vector3(0, 0.07, 0), 0.8, color, 0.6, 2.4)
	_ring(Vector3(0, 0.07, 0), 0.5, color.lightened(0.3), 0.45, -3.2)
	var p := CPUParticles3D.new()
	p.amount = 22
	p.lifetime = 1.1
	p.local_coords = true
	p.position = Vector3(0, 0.1, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 0.55
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 2.6
	p.gravity = Vector3.ZERO
	var dot := SphereMesh.new()
	dot.radius = 0.09
	dot.height = 0.18
	dot.radial_segments = 6
	dot.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color.lightened(0.2)
	dot.material = mat
	p.mesh = dot
	add_child(p)


func _build_wind() -> void:
	for i in 2:
		var ring := _ring(Vector3(0, 0.3 + i * 0.45, 0), 0.62 + i * 0.06, color, 0.4, 5.0 + i * 1.6)
		ring.scale = Vector3(1.0, 0.5, 1.0)


func _build_spark() -> void:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.4
	p.local_coords = true
	p.position = Vector3(0, 1.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.75
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.7
	p.gravity = Vector3.ZERO
	var dot := SphereMesh.new()
	dot.radius = 0.07
	dot.height = 0.14
	dot.radial_segments = 6
	dot.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.6)
	dot.material = mat
	p.mesh = dot
	add_child(p)


## A flat glowing ring that spins (spin = radians per second).
func _ring(at: Vector3, radius: float, ring_color: Color, alpha: float, spin: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(ring_color.r, ring_color.g, ring_color.b, alpha)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.torus()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.scale = Vector3(radius * 2.0, 0.18, radius * 2.0)
	mi.set_meta("spin", spin)
	add_child(mi)
	_spin.append(mi)
	return mi
