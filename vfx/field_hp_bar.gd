class_name FieldHpBar
extends Node3D
## Camera-facing health bar floating above a monster in the world.

const WIDTH := 1.1
const HEIGHT := 0.13

var _back: MeshInstance3D
var _fill: MeshInstance3D
var _fill_mesh: QuadMesh
var _material: StandardMaterial3D
var _ratio := 1.0


func _ready() -> void:
	_back = _make_quad(Color(0.02, 0.03, 0.1, 0.85), WIDTH + 0.08, HEIGHT + 0.07, 0)
	_back.mesh.set("center_offset", Vector3.ZERO)
	add_child(_back)
	_fill = _make_quad(UIPalette.HP_HIGH, WIDTH, HEIGHT, 1)
	_fill_mesh = _fill.mesh
	_material = _fill.material_override
	add_child(_fill)
	set_ratio(_ratio)


func set_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	if _fill_mesh == null:
		return
	_fill_mesh.size = Vector2(maxf(WIDTH * _ratio, 0.001), HEIGHT)
	_fill_mesh.center_offset = Vector3(-WIDTH * 0.5 + WIDTH * _ratio * 0.5, 0, 0)
	_material.albedo_color = UIPalette.hp_color(_ratio)


func _make_quad(color: Color, width: float, height: float, priority: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var material := StandardMaterial3D.new()
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
