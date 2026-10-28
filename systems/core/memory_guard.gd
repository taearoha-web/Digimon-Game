class_name MemoryGuard
extends RefCounted
## Keeps the game inside a phone browser's memory budget while a fight is on.
##
## iOS Safari closes a page that grows past a few hundred megabytes without any
## warning the page can catch, so the game watches itself: every couple of
## seconds it reads the renderer's video memory and (on the web) the wasm heap
## and sets a pressure level the effects read:
##   0 normal     every effect at the chosen quality
##   1 trimmed    fewer particles and decorations per effect, no glow, no effect lights
##   2 strict     the big skills keep their signature pieces only, smaller shadow map
## Gameplay, damage, projectiles and warning rings are never affected; only
## decorative counts shrink. A level drops again once memory has been
## comfortably under the threshold for a while (hysteresis), so the scene does
## not flicker between settings.

## [raise above, drop below] in MB, for phones / browsers and for desktops.
const VIDEO_PHONE := [135.0, 110.0, 170.0, 145.0]   # level 1 raise/drop, level 2 raise/drop
const HEAP_PHONE := [250.0, 215.0, 310.0, 275.0]
## An iPhone / iPad (Safari or a home-screen app) closes the page much earlier: a
## v0.9.4 Dark Lord session was closed at a 199 MB heap and 117 MB of video memory
## without the guard ever stepping in (its phone lines are 250 / 135), and a native
## 30-minute soak of the same hunt stays flat, so the budget, not a leak, ran out.
const VIDEO_IOS := [100.0, 85.0, 130.0, 115.0]
const HEAP_IOS := [175.0, 155.0, 225.0, 200.0]
const VIDEO_DESKTOP := [700.0, 600.0, 1000.0, 880.0]
const HEAP_DESKTOP := [1400.0, 1200.0, 1900.0, 1700.0]
const TICK_SECONDS := 2.0
const DROP_AFTER_SECONDS := 20.0

static var pressure := 0
static var video_mb := 0.0
static var heap_mb := 0.0
static var raises := 0
static var _forced := -1
static var _calm_seconds := 0.0
static var _accum := 0.0
## Tests pin the device family: -1 asks the engine, 0 not iOS, 1 iOS.
static var ios_override := -1
static var _ios := -1
static var _heap_script := "typeof window.toonHeapBytes === 'function' ? window.toonHeapBytes() : 0"


static func phone() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile")


static func ios() -> bool:
	if ios_override >= 0:
		return ios_override == 1
	if _ios < 0:
		var found := OS.has_feature("web_ios") or OS.has_feature("ios")
		if not found and OS.has_feature("web"):
			# iPadOS reports a Mac; its touch points give it away.
			found = bool(JavaScriptBridge.eval("/iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)", true))
		_ios = 1 if found else 0
	return _ios == 1


## [video, heap] lines for this device.
static func lines() -> Array:
	if ios():
		return [VIDEO_IOS, HEAP_IOS]
	return [VIDEO_PHONE, HEAP_PHONE] if phone() else [VIDEO_DESKTOP, HEAP_DESKTOP]


## Called every frame by Game; does its reading every TICK_SECONDS.
static func tick(tree: SceneTree, delta: float) -> void:
	_accum += delta
	if _accum < TICK_SECONDS:
		return
	var step := _accum
	_accum = 0.0
	video_mb = float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval(_heap_script, true)
		heap_mb = float(raw) / 1048576.0 if (raw is float or raw is int) else 0.0
	else:
		heap_mb = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	set_level(_wanted(step), tree)


## The level the readings ask for, with hysteresis against the current one.
static func _wanted(step: float) -> int:
	if _forced >= 0:
		return _forced
	var video: Array = lines()[0]
	var heap: Array = lines()[1]
	var level := 0
	if video_mb >= float(video[2]) or heap_mb >= float(heap[2]):
		level = 2
	elif video_mb >= float(video[0]) or heap_mb >= float(heap[0]):
		level = 1
	if level >= pressure:
		_calm_seconds = 0.0
		return level
	# Lower readings: only come down after a calm stretch below the drop line.
	var drop_video: float = float(video[1]) if pressure == 1 else float(video[3])
	var drop_heap: float = float(heap[1]) if pressure == 1 else float(heap[3])
	if video_mb < drop_video and heap_mb < drop_heap:
		_calm_seconds += step
		if _calm_seconds >= DROP_AFTER_SECONDS:
			_calm_seconds = 0.0
			return pressure - 1
	else:
		_calm_seconds = 0.0
	return pressure


static func set_level(level: int, tree: SceneTree) -> void:
	level = clampi(level, 0, 2)
	if level == pressure:
		return
	if level > pressure:
		raises += 1
	pressure = level
	apply_render(tree)


## Tests and tools pin a level (-1 lets the readings decide again).
static func force(level: int, tree: SceneTree) -> void:
	_forced = level
	set_level(level if level >= 0 else 0, tree)


## Shadow map size and glow for the current quality and pressure. Called when a
## zone is built, when the quality changes and when the pressure changes.
static func apply_render(tree: SceneTree) -> void:
	GameSettings.load_settings()
	var size := shadow_size()
	# A 16-bit depth map halves the memory and is plenty for a sun over a field.
	RenderingServer.directional_shadow_atlas_set_size(size, phone() or pressure > 0)
	if tree == null:
		return
	for node in tree.get_nodes_in_group("world_env"):
		var env: Environment = (node as WorldEnvironment).environment if node is WorldEnvironment else null
		if env != null:
			env.glow_enabled = glow_allowed() and bool(node.get_meta("glow_look", true))


static func shadow_size() -> int:
	if pressure >= 2:
		return 1024
	if phone():
		return 2048 if GameSettings.quality >= 2 else 1024
	return 2048


## Glow (bloom) costs extra render targets and passes: phones keep it for high
## quality, and every platform drops it while memory is tight.
static func glow_allowed() -> bool:
	if pressure >= 1:
		return false
	var glow_quality := 2 if phone() else 1
	return GameSettings.quality >= glow_quality


## Multiplier for decorative counts (particles, motes, decorations).
static func effect_scale() -> float:
	return [1.0, 0.65, 0.4][pressure]


static func report() -> Dictionary:
	return {"pressure": pressure, "videoMB": snappedf(video_mb, 0.1), "heapMB": snappedf(heap_mb, 0.1), "raises": raises}
