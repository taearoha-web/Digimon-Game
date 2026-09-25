class_name Portal
extends Interactable
## Gateway to another map. Locked until [member required_flag] is set.
## If the target map is not registered yet it shows a "coming soon" message,
## so new zones can be connected later by just adding MapData.

@export var target_map_id: StringName
@export var target_spawn_id: StringName = &"start"
@export var required_flag: StringName = &"gateway_unlocked"
@export var locked_dialogue_id: StringName = &"portal_locked"
@export var unavailable_dialogue_id: StringName = &"portal_unlocked"

var _swirl_material: ShaderMaterial
var _ring_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	prompt_text = L10n.t("Enter")
	interaction_radius = 3.0
	_build_visual()
	EventBus.flag_changed.connect(func(_f, _v): _refresh_state())
	_refresh_state()


func is_unlocked() -> bool:
	return required_flag == &"" or bool(GameState.get_flag(required_flag, false))


func _on_interact(by: Node) -> void:
	var box := DialogueBox.find(get_tree())
	if not is_unlocked():
		AudioManager.play_ui(&"ui_error")
		if box:
			await box.play(locked_dialogue_id)
		return
	var map := GameData.get_map(target_map_id)
	if map == null or not ResourceLoader.exists(map.scene_path):
		AudioManager.play_sfx(&"portal")
		if box:
			await box.play(unavailable_dialogue_id)
		return
	AudioManager.play_sfx(&"portal")
	if by is PlayerController:
		(by as PlayerController).set_input_enabled(false)
	GameState.world.current_map_id = target_map_id
	GameState.world.spawn_id = target_spawn_id
	GameState.world.has_position = false
	SceneManager.goto_map(target_map_id, target_spawn_id, {"from_portal": true})


func _refresh_state() -> void:
	if _swirl_material == null:
		return
	var open := is_unlocked()
	_swirl_material.set_shader_parameter("tint", Color(0.25, 0.9, 1.0) if open else Color(0.9, 0.25, 0.35))
	_swirl_material.set_shader_parameter("intensity", 1.4 if open else 0.6)
	_ring_material.albedo_color = Color(0.3, 0.95, 1.0) if open else Color(0.6, 0.3, 0.4)
	_ring_material.emission = _ring_material.albedo_color


func _build_visual() -> void:
	var stone := MeshKit.toon(Color("4b5a99"))
	MeshKit.part(self, MeshKit.cylinder(), stone, Vector3(0, 0.12, 0), Vector3(5.0, 0.24, 5.0))
	MeshKit.part(self, MeshKit.cylinder(), MeshKit.toon(Color("6f7fc4")), Vector3(0, 0.3, 0), Vector3(4.0, 0.16, 4.0))
	_ring_material = StandardMaterial3D.new()
	_ring_material.emission_enabled = true
	_ring_material.emission_energy_multiplier = 1.5
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.55
	torus.outer_radius = 1.85
	torus.rings = 48
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = _ring_material
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(0, 2.2, 0)
	add_child(ring)
	var disc := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.2, 3.2)
	disc.mesh = quad
	_swirl_material = ShaderMaterial.new()
	_swirl_material.shader = load("res://shaders/portal_swirl.gdshader")
	disc.material_override = _swirl_material
	disc.position = Vector3(0, 2.2, 0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	for side in [-1, 1]:
		MeshKit.part(self, MeshKit.box(), stone, Vector3(2.1 * side, 1.4, 0), Vector3(0.5, 2.8, 0.6))
		MeshKit.part(self, MeshKit.sphere(), MeshKit.toon(UIPalette.CYAN, {"emission": 1.5}), Vector3(2.1 * side, 3.0, 0), Vector3(0.45, 0.45, 0.45))
	var label := Label3D.new()
	label.text = L10n.t("Gateway")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.005
	label.font_size = 48
	label.outline_size = 12
	label.position = Vector3(0, 4.3, 0)
	add_child(label)
