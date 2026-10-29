class_name RenderWatchdog
extends RefCounted
## Notices the "flat screen" a phone sometimes shows (the 3D world drawn as one colour,
## the HUD still on top) and works its way back to a picture, one step at a time, for
## the rest of the session:
##   1  the zone's camera is made the one that draws and put back behind the hero
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
## Checks that found a built world drawn with almost nothing (see world_starved).
static var starved_count := 0
## Tests feed the frame's triangle count (-1: the renderer's).
static var triangles_override := -1
const STARVED_TRIANGLES := 15000
const STARVED_NODES := 1500


## A zone of a thousand-odd nodes on screen with almost no triangles drawn: the world
## is loaded but culled away (the wrong camera, or one looking at nothing).
static func world_starved(tree: SceneTree) -> bool:
	var triangles := triangles_override if triangles_override >= 0 else int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) >= STARVED_NODES and triangles < STARVED_TRIANGLES and tree.get_first_node_in_group("hero") != null


## The camera that draws and the zone's camera, for the session report.
static func camera_report(tree: SceneTree) -> Dictionary:
	var out := {}
	var cam := tree.root.get_viewport().get_camera_3d()
	var hero := tree.get_first_node_in_group("hero")
	var rig: ThirdPersonCamera = (hero as Hero).camera_rig if hero is Hero else null
	out["camOwn"] = 1 if cam != null and rig != null and cam == rig.camera else 0
	if cam != null:
		out["camY"] = snappedf(cam.global_position.y - ((hero as Node3D).global_position.y if hero is Node3D else 0.0), 0.1)
		out["camPitch"] = snappedf(rad_to_deg(cam.global_basis.get_euler().x), 0.1)
		out["camDist"] = snappedf(cam.global_position.distance_to((hero as Node3D).global_position) if hero is Node3D else -1.0, 0.1)
		out["camFar"] = cam.far
	return out


static func tick(tree: SceneTree, delta: float, watching: bool) -> void:
	_accum += delta
	if _accum < CHECK_SECONDS:
		return
	_accum = 0.0
	_keep(tree)
	if not watching or step >= STEPS:
		_flat_run = 0
		return
	# A world that is built but hardly drawn (an iPhone village frame: ~100 draw calls and
	# 7.6k triangles against 1,300 and 510k for the same village at low quality) is caught
	# from the renderer's own counters, before any pixel is read.
	var starved := world_starved(tree)
	if starved:
		starved_count += 1
	var spread := spread_override if spread_override >= 0.0 else (0.0 if starved else _frame_spread(tree))
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
			# Another camera (a menu's stage) may have kept the view: the zone's draws again.
			rig.camera.make_current()
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
