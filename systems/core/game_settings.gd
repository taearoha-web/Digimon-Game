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
		var file := FileAccess.open(PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
		if parsed is Dictionary:
			var saved_quality: Variant = parsed.get("quality", -1)
			if saved_quality is int or saved_quality is float:
				if is_finite(float(saved_quality)):
					quality = clampi(int(saved_quality), -1, 2)
			var saved_speed: Variant = parsed.get("camera_speed", 1.0)
			if saved_speed is int or saved_speed is float:
				if is_finite(float(saved_speed)):
					camera_speed = clampf(float(saved_speed), 0.4, 2.5)
			if parsed.get("vibration") is bool:
				vibration = parsed.vibration
	if quality < 0:
		# First run: phones and browsers get the lighter setting.
		quality = 1 if (OS.has_feature("web") or OS.has_feature("mobile")) else 2


static func save_settings() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"quality": quality, "camera_speed": camera_speed, "vibration": vibration}))


static func view_scale() -> float:
	return [0.5, 0.7, 1.0][clampi(quality, 0, 2)]


static func density_scale() -> float:
	return [0.45, 0.75, 1.0][clampi(quality, 0, 2)]


static func shadow_distance() -> float:
	return [0.0, 24.0, 55.0][clampi(quality, 0, 2)]


## Tallest the 3D scene is drawn (pixels on the screen's short side). Phones
## have 2-3x dense screens; drawing every one of those pixels is what stutters,
## so the 3D view is drawn smaller and stretched while the UI stays sharp.
const RENDER_HEIGHT := [540, 720, 1440]
## Directional shadow map size per quality (the shadow is shorter on medium).
const SHADOW_ATLAS := [1024, 2048, 4096]


static func render_scale(window_size: Vector2i) -> float:
	var short := maxf(float(mini(window_size.x, window_size.y)), 1.0)
	return clampf(float(RENDER_HEIGHT[clampi(quality, 0, 2)]) / short, 0.35, 1.0)


## Fits the 3D resolution to the window (call again when the window resizes).
static func apply_resolution(tree: SceneTree) -> void:
	var root := tree.root
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = render_scale(root.size)
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[clampi(quality, 0, 2)], true)


## Trees, rocks and monsters only cast real shadows on high quality; below that
## the shadow pass draws just the hero and friends (monsters get a blob shadow).
static func world_shadows() -> bool:
	return quality >= 2


static func particle_scale() -> float:
	return [0.4, 0.7, 1.0][clampi(quality, 0, 2)]


## Applies the shadow and resolution settings to the running scene.
static func apply_live(tree: SceneTree) -> void:
	apply_resolution(tree)
	for node in tree.get_nodes_in_group("sun"):
		var sun := node as DirectionalLight3D
		sun.shadow_enabled = shadow_distance() > 0.0
		sun.directional_shadow_max_distance = maxf(shadow_distance(), 1.0)


static func vibrate(ms := 40) -> void:
	if vibration:
		Input.vibrate_handheld(ms)
