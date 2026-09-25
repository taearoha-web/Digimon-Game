extends Node
## Walks the player through the maps with simulated joystick input (real
## physics, real colliders) to catch places the player cannot pass, such as a
## bridge whose deck is a step too high. Runs headless:
##   godot --headless --path . res://tests/integration/traversal_test.tscn
## Exit code = number of failed routes.

const ROUTES := {
	&"starter_zone": [
		# [name, from (x, z), to (x, z)]
		["bridge west -> east", Vector2(-9.0, 0.0), Vector2(13.0, 0.0)],
		["bridge east -> west", Vector2(13.0, 0.4), Vector2(-9.0, 0.4)],
		["plaza -> training grounds", Vector2(-30.0, 6.0), Vector2(-6.0, 0.5)],
	],
	&"data_forest": [
		["gateway -> ranger camp", Vector2(-40.0, 40.0), Vector2(-27.0, 27.0)],
		["camp -> ruins path", Vector2(-14.0, 22.0), Vector2(26.0, 9.0)],
	],
}
const WALK_TIMEOUT := 12.0
const REACH_DISTANCE := 1.6

var _failures: Array[String] = []


func _ready() -> void:
	if not has_meta("driver"):
		var driver := Node.new()
		driver.set_script(get_script())
		driver.set_meta("driver", true)
		get_parent().remove_child.call_deferred(self)
		get_tree().root.add_child.call_deferred(driver)
		return
	await get_tree().process_frame
	TestCase.use_locale("en")
	var draft := NewGameDraft.new()
	draft.player_name = "Walker"
	draft.starter_species_id = &"agumon"
	GameState.start_new_game(draft)
	for map_id in ROUTES.keys():
		SceneManager.goto_map(map_id, GameData.get_map(map_id).default_spawn_id)
		await _wait_for_map(map_id)
		var world := get_tree().current_scene as WorldMap
		for node in world.find_children("*", "EncounterSpawner", true, false):
			(node as EncounterSpawner).set_encounters_enabled(false)
		for route in ROUTES[map_id]:
			await _walk(world, route[0], route[1], route[2])
	print("")
	if _failures.is_empty():
		print("TRAVERSAL TEST: PASS")
	else:
		print("TRAVERSAL TEST: FAIL (%d)" % _failures.size())
		for f in _failures:
			print("  - ", f)
	get_tree().quit(_failures.size())


func _walk(world: WorldMap, route_name: String, from: Vector2, to: Vector2) -> void:
	var player := world.player
	player.global_position = Vector3(from.x, world.get_ground_height(from.x, from.y) + 0.3, from.y)
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var elapsed := 0.0
	var best := INF
	while elapsed < WALK_TIMEOUT:
		var here := Vector2(player.global_position.x, player.global_position.z)
		var left := to - here
		best = minf(best, left.length())
		if left.length() < REACH_DISTANCE:
			break
		# Point the camera along the route and hold the stick forward, like a
		# player would (movement is camera-relative).
		world.camera_rig.set_yaw_behind(atan2(-left.x, -left.y))
		player.touch_move = Vector2(0, -1)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	player.touch_move = Vector2.ZERO
	var end := Vector2(player.global_position.x, player.global_position.z)
	# Also require the player to still be standing on the terrain (a missing
	# collider would let them fall while "moving" horizontally).
	var on_ground := absf(player.global_position.y - world.get_ground_height(end.x, end.y)) < 1.5
	var ok := end.distance_to(to) < REACH_DISTANCE and on_ground
	print("  %s  %s (ended %.1f m from target at %s)" % ["ok  " if ok else "FAIL", route_name, end.distance_to(to), end])
	if not ok:
		_failures.append("%s: stuck %.1f m short at %s" % [route_name, end.distance_to(to), end])


func _wait_for_map(map_id: StringName) -> void:
	var elapsed := 0.0
	while elapsed < 30.0:
		var scene := get_tree().current_scene
		if scene is WorldMap and (scene as WorldMap).map_id == map_id and not SceneManager.is_transitioning:
			break
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	for i in 10:
		await get_tree().process_frame
