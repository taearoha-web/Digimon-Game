class_name RenderWatchdog
extends RefCounted
## Notices the "flat screen" a phone sometimes shows (the 3D world drawn as one colour,
## the HUD still on top) and works its way back to a picture, one step at a time, for
## the rest of the session:
##   1  the camera is put back behind the hero
##   2  medium quality and the memory guard's strict level (no glow, small shadow map,
##      fewer effects, a lower drawn resolution on an iPhone)
##   3  no sun shadows
##   4  the other players (world players, their capes, wings and ravens) are hidden
## Every few seconds it reads a sparse grid of the frame's middle band (the HUD sits at
## the edges); two flat readings in a row take the next step. The steps taken and the
## flat readings go into the session report (renderFallback, flatScreens), so the next
## report says what brought the picture back.

const CHECK_SECONDS := 5.0
const FLAT_SPREAD := 0.012
const STEPS := 4

static var step := 0
static var flat_count := 0
static var _flat_run := 0
static var _accum := 0.0
## Tests feed a reading instead of the frame (-1: read the frame).
static var spread_override := -1.0


static func tick(tree: SceneTree, delta: float, watching: bool) -> void:
	_accum += delta
	if _accum < CHECK_SECONDS:
		return
	_accum = 0.0
	_keep(tree)
	if not watching or step >= STEPS:
		_flat_run = 0
		return
	var spread := spread_override if spread_override >= 0.0 else _frame_spread(tree)
	if spread < 0.0:
		return
	if spread >= FLAT_SPREAD:
		_flat_run = 0
		return
	flat_count += 1
	_flat_run += 1
	if _flat_run >= 2:
		_flat_run = 0
		take_step(tree)


## How varied the middle of the frame is (RGB standard deviation, 0..1); -1 if unreadable.
static func _frame_spread(tree: SceneTree) -> float:
	var viewport := tree.root.get_viewport()
	var texture := viewport.get_texture()
	if texture == null:
		return -1.0
	var img := texture.get_image()
	if img == null or img.is_empty():
		return -1.0
	var w := img.get_width()
	var h := img.get_height()
	var sum := Vector3.ZERO
	var values: Array[Vector3] = []
	for gy in 5:
		for gx in 8:
			var c := img.get_pixel(int(w * (0.25 + 0.5 * gx / 7.0)), int(h * (0.3 + 0.35 * gy / 4.0)))
			var v := Vector3(c.r, c.g, c.b)
			values.append(v)
			sum += v
	var mean := sum / float(values.size())
	var sq := 0.0
	for v in values:
		sq += (v - mean).length_squared()
	return sqrt(sq / float(values.size()))


static func take_step(tree: SceneTree) -> void:
	step = mini(step + 1, STEPS)
	_apply(tree)


## Keeps the cheap steps in force (a new zone builds its suns, players come and go).
static func _keep(tree: SceneTree) -> void:
	if step >= 3:
		for node in tree.get_nodes_in_group("sun"):
			(node as DirectionalLight3D).shadow_enabled = false
	if step >= 4:
		for node in tree.get_nodes_in_group("world_players"):
			(node as Node3D).visible = false


static func _apply(tree: SceneTree) -> void:
	var hero := tree.get_first_node_in_group("hero")
	if step >= 1 and hero is Hero and (hero as Hero).camera_rig:
		var rig := (hero as Hero).camera_rig
		rig.snap_to_target()
		if rig.camera:
			rig.camera.position = Vector3.ZERO
			rig.camera.rotation = Vector3.ZERO
	if step >= 2:
		if GameSettings.quality > 1:
			GameSettings.quality = 1
		MemoryGuard.force(2, tree)
		GameSettings.apply_live(tree)
	if step >= 3:
		for node in tree.get_nodes_in_group("sun"):
			(node as DirectionalLight3D).shadow_enabled = false
	if step >= 4:
		for node in tree.get_nodes_in_group("world_players"):
			(node as Node3D).visible = false
