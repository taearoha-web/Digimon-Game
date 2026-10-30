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
## An iPhone that stays under this frame rate for LOW_FPS_SECONDS is working its GPU
## to the limit (a v0.9.4 report: High quality at 1920 px, 18-25 fps for half an hour,
## then closed by iOS): the guard steps up one level, which also lowers the drawn
## resolution (render_quality).
const LOW_FPS := 22.0
const LOW_FPS_SECONDS := 30.0
static var _slow_seconds := 0.0
## An iPhone that runs warm: under HOT_FPS for HOT_SECONDS in all (a v0.9.4 report: the
## frame rate sank from 48 to 34 over twenty minutes of auto-hunting at high quality, then
## iOS closed the page). From then on, for the session, the 3D scale follows the frame
## rate at every quality (high "คมชัด" too), never above HOT_SCALE, and decorative
## effects are cut to HOT_EFFECTS of the pressure level's share.
const HOT_FPS := 42.0
const HOT_SECONDS := 60.0
const HOT_SCALE := 0.75
## The floor while warm, at every quality (the frame rate decides between it and HOT_SCALE).
const HOT_FLOOR := 0.65
const HOT_EFFECTS := 0.6
static var hot := false
static var hot_seconds := 0.0

## The 3D resolution scale on a phone (Viewport.scaling_3d_scale, bilinear): the world is
## drawn at this share of the canvas and the HUD stays at the full, crisp size. Every zone
## starts at full size. High quality "สูง (คมชัด)" stays there: it is the sharp picture
## (names and the world read clearly), and the owner chooses it for that. At medium and
## low quality, and at high "สูง (ลื่น)" (GameSettings.high_smooth), the scale follows the
## frame rate, SCALE_3D_STEP at a time between SCALE_3D_MIN and 1.0: a
## slow stretch (under SCALE_3D_SLOW_FPS for SCALE_3D_SLOW_TICKS readings) lowers it, a
## fast one (over SCALE_3D_FAST_FPS for SCALE_3D_FAST_TICKS readings) raises it again.
## Desktops always draw at 1.0.
const SCALE_3D_START := 1.0
const SCALE_3D_MIN := 0.6
const SCALE_3D_STEP := 0.05
const SCALE_3D_SLOW_FPS := 46.0
const SCALE_3D_SLOW_TICKS := 2
const SCALE_3D_FAST_FPS := 57.0
const SCALE_3D_FAST_TICKS := 6
static var scale_3d := 1.0
## How low the frame rate may take the 3D scale at each quality: medium keeps the world
## and the names over the heads readable (0.85), high "ลื่น" 0.8, low goes to SCALE_3D_MIN.
const SCALE_3D_FLOORS := [SCALE_3D_MIN, 0.85, 0.8]


static func scale_3d_floor() -> float:
	var floor_now := float(SCALE_3D_FLOORS[clampi(GameSettings.quality, 0, 2)])
	return minf(floor_now, HOT_FLOOR) if hot else floor_now
static var _scale_slow := 0
static var _scale_fast := 0
static var _scale_applied := -1.0

## Tests pin the device family: -1 asks the engine, 0 not iOS, 1 iOS.
static var ios_override := -1
## Tests pin the phone / browser budget the same way (-1 asks the engine).
static var phone_override := -1
static var _ios := -1
static var _heap_script := "typeof window.toonHeapBytes === 'function' ? window.toonHeapBytes() : 0"


## Tests pin the frame rate (-1 reads the engine).
static var fps_override := -1.0


static func _frame_rate() -> float:
	return fps_override if fps_override >= 0.0 else Engine.get_frames_per_second()


## The web shell's pixel budget (0: 1280 px, 1: 2048 px, 2: 2560 px on the long edge):
## the chosen quality, one step lower per pressure level on an iPhone, where every
## drawn pixel costs GPU time and render-target memory.
static func render_quality() -> int:
	var q := clampi(GameSettings.quality, 0, 2)
	if ios():
		q -= pressure
	return clampi(q, 0, 2)


static func phone() -> bool:
	if phone_override >= 0:
		return phone_override == 1
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
	var wanted := _wanted(step)
	_watch_heat(tree, step)
	_follow_frame_rate(tree)
	if ios() and _forced < 0 and wanted < 2 and _frame_rate() < LOW_FPS:
		_slow_seconds += step
		if _slow_seconds >= LOW_FPS_SECONDS:
			_slow_seconds = 0.0
			wanted = maxi(wanted, pressure + 1)
	else:
		_slow_seconds = 0.0
	set_level(wanted, tree)


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
	# An iPhone keeps a raised level for the session: every change re-allocates glow
	# and shadow buffers, and switching back and forth during a fight flickered.
	if ios():
		return pressure
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


## The 3D scale a fresh zone starts from on this device at the chosen quality.
static func base_scale_3d() -> float:
	if not phone():
		return 1.0
	return minf(SCALE_3D_START, scale_cap())


## The highest 3D scale allowed now (HOT_SCALE once an iPhone runs warm).
static func scale_cap() -> float:
	return HOT_SCALE if hot else 1.0


## Counts the slow seconds on an iPhone; HOT_SECONDS of them (a quick stretch takes
## them back off) mark it as warm for the session.
static func _watch_heat(tree: SceneTree, step: float) -> void:
	if hot or not ios() or _forced >= 0:
		return
	var fps := _frame_rate()
	# Under the 30 fps cap "warm" means sagging below the cap, not below HOT_FPS.
	var hot_line := HOT_FPS if Engine.max_fps <= 0 else minf(HOT_FPS, Engine.max_fps * 0.85)
	if fps > 0.0 and fps < hot_line:
		hot_seconds += step
	else:
		hot_seconds = maxf(0.0, hot_seconds - step)
	if hot_seconds < HOT_SECONDS:
		return
	hot = true
	if scale_3d > HOT_SCALE:
		set_scale_3d(HOT_SCALE, tree)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.toonSession && window.toonSession.mark) window.toonSession.mark('hot');", true)


## One reading of the frame rate: a slow stretch lowers the 3D scale a step, a fast one
## raises it (phones below high quality, or at high "สูง (ลื่น)", only; the frame rate is
## read once a tick, TICK_SECONDS apart).
static func _follow_frame_rate(tree: SceneTree) -> void:
	if not phone() or _forced >= 0 or not (GameSettings.dynamic_scale() or hot):
		return
	var fps := _frame_rate()
	if fps <= 0.0:
		return
	# Under the iPhone's 30 fps cap the same lines sit just under the cap.
	var slow_line := SCALE_3D_SLOW_FPS if Engine.max_fps <= 0 else Engine.max_fps * 0.85
	var fast_line := SCALE_3D_FAST_FPS if Engine.max_fps <= 0 else Engine.max_fps * 0.97
	if fps < slow_line:
		_scale_slow += 1
		_scale_fast = 0
		if _scale_slow >= SCALE_3D_SLOW_TICKS and scale_3d > scale_3d_floor() + 0.001:
			_scale_slow = 0
			set_scale_3d(scale_3d - SCALE_3D_STEP, tree)
	elif fps > fast_line:
		_scale_fast += 1
		_scale_slow = 0
		if _scale_fast >= SCALE_3D_FAST_TICKS and scale_3d < scale_cap() - 0.001:
			_scale_fast = 0
			set_scale_3d(scale_3d + SCALE_3D_STEP, tree)
	else:
		_scale_slow = 0
		_scale_fast = 0


static func set_scale_3d(value: float, tree: SceneTree) -> void:
	scale_3d = snappedf(clampf(value, scale_3d_floor(), maxf(scale_3d_floor(), scale_cap())), 0.01)
	_apply_scale_3d(tree)


static func _apply_scale_3d(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	if is_equal_approx(_scale_applied, scale_3d):
		return
	_scale_applied = scale_3d
	tree.root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	tree.root.scaling_3d_scale = scale_3d


## A new zone (or a quality change) starts again from the device's base scale.
static func reset_scale_3d(tree: SceneTree) -> void:
	_scale_slow = 0
	_scale_fast = 0
	set_scale_3d(base_scale_3d(), tree)


const IOS_MAX_FPS := 30


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
	GameSettings.apply_web_render_quality()
	# An iPhone kept at full tilt heats up within minutes, then iOS slows the chip
	# (the frame rate halves) and at last closes the page. 30 fps steady keeps it cool.
	Engine.max_fps = IOS_MAX_FPS if ios() else 0
	var size := shadow_size()
	# A 16-bit depth map halves the memory and is plenty for a sun over a field.
	RenderingServer.directional_shadow_atlas_set_size(size, phone() or pressure > 0)
	if tree == null:
		return
	_apply_scale_3d(tree)
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
	return [1.0, 0.65, 0.4][pressure] * (HOT_EFFECTS if hot else 1.0)


static func report() -> Dictionary:
	return {"pressure": pressure, "videoMB": snappedf(video_mb, 0.1), "heapMB": snappedf(heap_mb, 0.1), "raises": raises, "scale3d": scale_3d, "hot": hot}
