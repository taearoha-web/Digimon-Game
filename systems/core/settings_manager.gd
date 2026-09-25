extends Node
## Autoload "Settings": user preferences persisted in user://settings.cfg.
##
## Graphics quality is broadcast to the "quality_listeners" group so world
## objects (lights, props, particles) can scale themselves.

signal changed()

enum Quality { LOW, MEDIUM, HIGH }

const PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High"]
const LANGUAGES := {"en": "English"}

var music_volume: float = 0.7
var sfx_volume: float = 0.9
var ui_volume: float = 0.8
var graphics_quality: int = Quality.MEDIUM
var camera_sensitivity: float = 1.0
var invert_camera_y: bool = false
var show_fps: bool = false
var language: String = "en"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _is_mobile():
		graphics_quality = Quality.HIGH
	load_settings()
	# Wait until every autoload (AudioManager creates buses) is ready.
	apply.call_deferred()


func set_setting(key: StringName, value: Variant) -> void:
	if not key in self:
		push_warning("Settings: unknown key '%s'" % key)
		return
	set(key, value)
	_sanitize()
	apply()
	save_settings()
	changed.emit()


func apply() -> void:
	apply_audio()
	apply_graphics()
	if language in LANGUAGES:
		TranslationServer.set_locale(language)


func apply_audio() -> void:
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("UI", ui_volume)


func apply_graphics() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	match graphics_quality:
		Quality.LOW:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.75
			Engine.max_fps = 30
		Quality.MEDIUM:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.scaling_3d_scale = 0.9 if _is_mobile() else 1.0
			Engine.max_fps = 60
		_:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.scaling_3d_scale = 1.0
			Engine.max_fps = 60
	if get_tree():
		get_tree().call_group("quality_listeners", "apply_quality", graphics_quality)


func get_quality_name() -> String:
	return QUALITY_NAMES[clampi(graphics_quality, 0, QUALITY_NAMES.size() - 1)]


func to_dict() -> Dictionary:
	return {
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ui_volume": ui_volume,
		"graphics_quality": graphics_quality,
		"camera_sensitivity": camera_sensitivity,
		"invert_camera_y": invert_camera_y,
		"show_fps": show_fps,
		"language": language,
	}


func load_dict(data: Dictionary, persist := true) -> void:
	for key in to_dict().keys():
		if data.has(key):
			set(key, data[key])
	_sanitize()
	apply()
	if persist:
		save_settings()
	changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	var values := to_dict()
	for key in values.keys():
		cfg.set_value("settings", key, values[key])
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Settings: could not save (%s)" % error_string(err))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in to_dict().keys():
		if cfg.has_section_key("settings", key):
			set(key, cfg.get_value("settings", key))
	_sanitize()


func _sanitize() -> void:
	music_volume = clampf(float(music_volume), 0.0, 1.0)
	sfx_volume = clampf(float(sfx_volume), 0.0, 1.0)
	ui_volume = clampf(float(ui_volume), 0.0, 1.0)
	graphics_quality = clampi(int(graphics_quality), Quality.LOW, Quality.HIGH)
	camera_sensitivity = clampf(float(camera_sensitivity), 0.2, 3.0)
	invert_camera_y = bool(invert_camera_y)
	show_fps = bool(show_fps)
	language = str(language) if str(language) in LANGUAGES else "en"


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


static func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
