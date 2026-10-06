class_name GameSettings
extends RefCounted
## Player options kept in their own small file (separate from the save):
## graphics quality, camera speed, vibration. Quality changes how much scenery
## is drawn, whether shadows are on and how many particles weather uses.

const PATH := "user://toon_tale_settings.json"
const QUALITY_NAMES := ["ต่ำ (เครื่องช้า)", "กลาง", "สูง"]

static var quality := -1          # 0 low, 1 medium, 2 high; -1 = not chosen yet
static var camera_speed := 1.0
static var vibration := true
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.open(PATH, FileAccess.READ).get_as_text())
		if parsed is Dictionary:
			quality = int(parsed.get("quality", -1))
			camera_speed = clampf(float(parsed.get("camera_speed", 1.0)), 0.4, 2.5)
			vibration = bool(parsed.get("vibration", true))
	if quality < 0:
		# First run: phones and browsers get the lighter setting.
		quality = 1 if (OS.has_feature("web") or OS.has_feature("mobile")) else 2


static func save_settings() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"quality": quality, "camera_speed": camera_speed, "vibration": vibration}))


static func view_scale() -> float:
	return [0.55, 0.8, 1.0][clampi(quality, 0, 2)]


static func density_scale() -> float:
	return [0.45, 0.75, 1.0][clampi(quality, 0, 2)]


static func shadow_distance() -> float:
	return [0.0, 34.0, 55.0][clampi(quality, 0, 2)]


static func particle_scale() -> float:
	return [0.4, 0.7, 1.0][clampi(quality, 0, 2)]


## Applies the shadow setting to every sun in the running scene.
static func apply_live(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("sun"):
		var sun := node as DirectionalLight3D
		sun.shadow_enabled = shadow_distance() > 0.0
		sun.directional_shadow_max_distance = maxf(shadow_distance(), 1.0)


static func vibrate(ms := 40) -> void:
	if vibration:
		Input.vibrate_handheld(ms)
