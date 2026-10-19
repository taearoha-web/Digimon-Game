class_name FieldHpBar
extends Node3D
## Camera-facing health bar floating above a monster in the world.

const WIDTH := 1.1
const HEIGHT := 0.13

## The fill is one fixed quad; a shader clips its right edge at the ratio
## (left edge fixed) and tints it. Damage ticks then change two uniforms
## instead of rebuilding a mesh for every fighter on every hit, which
## fragmented the web heap over a long fight. The billboard lines are the ones
## StandardMaterial3D generates for BILLBOARD_ENABLED.
const FILL_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, depth_test_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float ratio = 1.0;
uniform float width = 1.1;

void vertex() {
	VERTEX.x = min(VERTEX.x, width * (ratio - 0.5));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	ALBEDO = color.rgb;
}
"""
static var _fill_shader: Shader
static var _fill_mesh: QuadMesh

var _back: MeshInstance3D
var _fill: MeshInstance3D
var _material: ShaderMaterial
var _ratio := 1.0


func _ready() -> void:
	_back = _make_quad(Color(0.02, 0.03, 0.1, 0.85), WIDTH + 0.08, HEIGHT + 0.07, 0)
	_back.mesh.set("center_offset", Vector3.ZERO)
	add_child(_back)
	if _fill_shader == null:
		_fill_shader = Shader.new()
		_fill_shader.code = FILL_SHADER_CODE
		_fill_mesh = QuadMesh.new()
		_fill_mesh.size = Vector2(WIDTH, HEIGHT)
	_material = ShaderMaterial.new()
	_material.shader = _fill_shader
	_material.set_shader_parameter("width", WIDTH)
	_material.render_priority = 1 + 10
	_fill = MeshInstance3D.new()
	_fill.mesh = _fill_mesh
	_fill.material_override = _material
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill)
	set_ratio(_ratio)


func set_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	if _material == null:
		return
	# The shader clips the quad at the ratio; a tiny sliver stays, as before.
	_material.set_shader_parameter("ratio", maxf(_ratio, 0.001 / WIDTH))
	_material.set_shader_parameter("color", UIPalette.hp_color(_ratio))


func _make_quad(color: Color, width: float, height: float, priority: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var material := StandardMaterial3D.new()
	MaterialKeeper.keep(material)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = color
	material.no_depth_test = true
	material.render_priority = priority + 10
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
