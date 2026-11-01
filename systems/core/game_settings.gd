class_name GameSettings
extends RefCounted
## Player options kept in their own small file (separate from the save):
## graphics quality, camera speed, cinematic hitstop. Quality changes how much scenery
## is drawn, whether shadows are on and how many particles weather uses.

const PATH := "user://toon_tale_settings.json"
const QUALITY_NAMES := ["ต่ำ (เครื่องช้า)", "กลาง", "สูง"]

static var quality := -1          # 0 low, 1 medium, 2 high; -1 = not chosen yet
## High quality comes in two modes: "สูง (คมชัด)" (false: the 3D scale stays at 1.0, the
## sharp picture) and "สูง (ลื่น)" (true: quality 2 effects, but on a phone the 3D scale
## follows the frame rate like medium does, MemoryGuard._follow_frame_rate).
static var high_smooth := false
static var camera_speed := 1.0
static var combat_hitstop := true
## The safe picture (settings, or the flat-screen watchdog's last step): no other players,
## stalls or lantern glow in the zones, so a phone whose world came out as one flat colour
## shows the plain world again. Saved with the settings; the player switches it off.
static var safe_picture := false
## The world players (AI) walking in the zones (settings: switch them off to leave only
## their bodies out; the world chat, the online count, parties and guild wars stay).
static var show_world_players := true
## Tapping a monster or rival on the screen (TAP_MODES): 0 locks on and goes for it,
## 1 only makes it the target (the hero attacks when the attack button is pressed),
## 2 does nothing (taps only open players' cards).
const TAP_MODES := ["แตะแล้ววิ่งเข้าไปตีทันที", "แตะเพื่อเลือกเป้าอย่างเดียว", "ปิดการแตะเลือกเป้า"]
static var tap_target_mode := 0
## Settings files older than REV were written while the grey village was chased down
## (the web build's threaded cull, fixed in project.godot): their hidden world players
## and the watchdog's safe picture came from that bug, so they are not carried over.
const REV := 2
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	# Mobile combat should flow continuously; cinematic hitstop is opt-in there.
	combat_hitstop = not (OS.has_feature("web") or OS.has_feature("mobile"))
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
			if parsed.get("combat_hitstop") is bool:
				combat_hitstop = parsed.combat_hitstop
			var saved_tap: Variant = parsed.get("tap_target_mode", 0)
			if (saved_tap is int or saved_tap is float) and is_finite(float(saved_tap)):
				tap_target_mode = clampi(int(saved_tap), 0, TAP_MODES.size() - 1)
			if parsed.get("high_smooth") is bool:
				high_smooth = parsed.high_smooth
			var rev: Variant = parsed.get("rev", 1)
			var current := (rev is int or rev is float) and is_finite(float(rev)) and int(rev) >= REV
			if current and parsed.get("safe_picture") is bool:
				safe_picture = parsed.safe_picture
			if current and parsed.get("show_world_players") is bool:
				show_world_players = parsed.show_world_players
	if quality < 0:
		# First run: phones and browsers get the lighter setting.
		quality = 1 if (OS.has_feature("web") or OS.has_feature("mobile")) else 2
	apply_web_render_quality()


static func save_settings() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"rev": REV, "quality": quality, "camera_speed": camera_speed, "combat_hitstop": combat_hitstop, "high_smooth": high_smooth, "safe_picture": safe_picture, "show_world_players": show_world_players, "tap_target_mode": tap_target_mode}))


## The name of the chosen quality as the settings show it (High names its mode).
static func quality_name() -> String:
	if quality >= 2:
		return "สูง (ลื่น)" if high_smooth else "สูง (คมชัด)"
	return String(QUALITY_NAMES[clampi(quality, 0, 2)])


## Whether the 3D scale may follow the frame rate at the chosen quality (phones only).
static func dynamic_scale() -> bool:
	return quality < 2 or high_smooth


static func view_scale() -> float:
	return [0.55, 0.8, 1.0][clampi(quality, 0, 2)]


static func density_scale() -> float:
	return [0.45, 0.75, 1.0][clampi(quality, 0, 2)]


static func shadow_distance() -> float:
	return [0.0, 34.0, 55.0][clampi(quality, 0, 2)]


## Trees, rocks and monsters only cast real shadows on high quality; below that
## the shadow pass draws just the hero and friends (monsters get a blob shadow).
static func world_shadows() -> bool:
	return quality >= 2


static func particle_scale() -> float:
	return [0.4, 0.7, 1.0][clampi(quality, 0, 2)]


## Applies the shadow setting to every sun in the running scene.
static func apply_live(tree: SceneTree) -> void:
	MemoryGuard.apply_render(tree)
	for node in tree.get_nodes_in_group("sun"):
		var sun := node as DirectionalLight3D
		sun.shadow_enabled = shadow_distance() > 0.0
		sun.directional_shadow_max_distance = maxf(shadow_distance(), 1.0)
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality >= 2 else DirectionalLight3D.SHADOW_ORTHOGONAL


## The web shell caps Retina pixel work independently of authored art detail (lower
## on an iPhone under memory pressure: MemoryGuard.render_quality).
static func apply_web_render_quality() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.toonSetRenderQuality) window.toonSetRenderQuality(%d);" % MemoryGuard.render_quality())
