extends Node
## Autoload "SceneManager": the single place that changes scenes.
##
## Scenes are addressed by key (see SCENES) or by map id (MapData), never by
## scattered hard-coded paths. Parameters for the next scene are passed via
## [member params]; the new scene reads them with [method take_params].

signal scene_changed(scene_key: StringName)
signal transition_started()
signal transition_finished()

const SCENES := {
	&"boot": "res://scenes/boot/boot.tscn",
	&"main_menu": "res://ui/main_menu/main_menu.tscn",
	&"character_creation": "res://ui/new_game/character_creation.tscn",
	&"starter_selection": "res://ui/new_game/starter_selection.tscn",
	&"player_name": "res://ui/new_game/player_name.tscn",
	&"confirmation": "res://ui/new_game/new_game_confirmation.tscn",
	&"intro": "res://ui/new_game/intro.tscn",
	&"battle": "res://scenes/battle/battle_scene.tscn",
}

const TIPS := [
	"Tip: Push the joystick all the way to run.",
	"Tip: Weakened wild Digimon are easier to befriend.",
	"Tip: Recovery Terminals fully heal your party.",
	"Tip: Your partner learns new skills as it levels up.",
	"Tip: Vaccine beats Virus, Virus beats Data, Data beats Vaccine.",
	"Tip: Defending halves damage and restores a little SP.",
]

var params: Dictionary = {}
var current_scene_key: StringName = &""
var is_transitioning := false

var _layer: CanvasLayer
var _fade: ColorRect
var _loading_box: Control
var _loading_label: Label
var _tip_label: Label
var _progress: ProgressBar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()


func goto_scene(key: StringName, new_params := {}, show_loading := false) -> void:
	if not SCENES.has(key):
		push_error("SceneManager: unknown scene key '%s'" % key)
		return
	await _transition(SCENES[key], key, new_params, show_loading)


func goto_map(map_id: StringName, spawn_id: StringName = &"", new_params := {}) -> void:
	var map_data: MapData = GameData.get_map(map_id)
	if map_data == null or not ResourceLoader.exists(map_data.scene_path):
		push_error("SceneManager: unknown map '%s'" % map_id)
		EventBus.toast("That area is not available yet.", &"warning")
		return
	var p := new_params.duplicate()
	p["map_id"] = map_id
	p["spawn_id"] = spawn_id if spawn_id != &"" else map_data.default_spawn_id
	await _transition(map_data.scene_path, StringName("map:" + String(map_id)), p, true)


func goto_battle(request: BattleRequest) -> void:
	GameState.pending_battle = request
	await goto_scene(&"battle", {"request": request}, false)


## Parameters passed by whoever requested the current scene.
func take_params() -> Dictionary:
	return params


func _transition(path: String, key: StringName, new_params: Dictionary, show_loading: bool) -> void:
	if is_transitioning:
		push_warning("SceneManager: transition already running, ignoring request for %s" % path)
		return
	is_transitioning = true
	transition_started.emit()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0, 0.25)
	get_tree().paused = false

	_loading_box.visible = show_loading
	_tip_label.text = TIPS[randi() % TIPS.size()]
	_progress.value = 0.0
	var packed := await _load_packed(path)
	if packed == null:
		push_error("SceneManager: failed to load %s" % path)
		EventBus.toast("Failed to load scene.", &"warning")
		if key != &"main_menu":
			packed = load(SCENES[&"main_menu"]) as PackedScene
			key = &"main_menu"
			new_params = {}

	var old_scene := get_tree().current_scene
	if old_scene:
		old_scene.queue_free()
		await get_tree().process_frame
	params = new_params
	var instance := packed.instantiate()
	get_tree().root.add_child(instance)
	get_tree().current_scene = instance
	current_scene_key = key
	scene_changed.emit(key)

	await get_tree().process_frame
	_loading_box.visible = false
	await _fade_to(0.0, 0.3)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	transition_finished.emit()


func _load_packed(path: String) -> PackedScene:
	if ResourceLoader.load_threaded_request(path) != OK:
		return load(path) as PackedScene
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if not progress.is_empty():
			_progress.value = float(progress[0]) * 100.0
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return null
		await get_tree().process_frame
	_progress.value = 100.0
	return ResourceLoader.load_threaded_get(path) as PackedScene


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	await tween.finished


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	_layer.name = "TransitionLayer"
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.05, 0.13, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)

	_loading_box = VBoxContainer.new()
	_loading_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_loading_box.anchor_left = 0.5
	_loading_box.anchor_right = 0.5
	_loading_box.anchor_top = 1.0
	_loading_box.anchor_bottom = 1.0
	_loading_box.offset_left = -260
	_loading_box.offset_right = 260
	_loading_box.offset_top = -150
	_loading_box.offset_bottom = -60
	_loading_box.add_theme_constant_override("separation", 10)
	_loading_box.visible = false
	_layer.add_child(_loading_box)

	_loading_label = Label.new()
	_loading_label.text = "Loading Digital World…"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.theme_type_variation = &"HeaderLabel"
	_loading_box.add_child(_loading_label)

	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 14)
	_progress.show_percentage = false
	_progress.theme_type_variation = &"EXPBar"
	_loading_box.add_child(_progress)

	_tip_label = Label.new()
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.theme_type_variation = &"DimLabel"
	_loading_box.add_child(_tip_label)
