class_name WorldState
extends RefCounted
## Where the player is and what has changed in the world.

var current_map_id: StringName = &"starter_zone"
var spawn_id: StringName = &"start"
var has_position: bool = false
var player_position: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0
## Where the player recovers after a defeat.
var respawn_map_id: StringName = &"starter_zone"
var respawn_spawn_id: StringName = &"start"
## Story / progression flags, e.g. { &"gateway_unlocked": true }.
var flags: Dictionary = {}
## Ids of one-time pickups already collected.
var collected_pickups: Array[String] = []
var visited_maps: Array[String] = []


func set_flag(flag: StringName, value: Variant = true) -> void:
	flags[flag] = value


func get_flag(flag: StringName, default_value: Variant = false) -> Variant:
	return flags.get(flag, default_value)


func is_pickup_collected(pickup_id: String) -> bool:
	return collected_pickups.has(pickup_id)


func mark_pickup_collected(pickup_id: String) -> void:
	if not collected_pickups.has(pickup_id):
		collected_pickups.append(pickup_id)


func store_player_transform(position: Vector3, yaw: float) -> void:
	player_position = position
	player_yaw = yaw
	has_position = true


func to_dict() -> Dictionary:
	var flag_out := {}
	for key in flags.keys():
		flag_out[String(key)] = flags[key]
	return {
		"current_map_id": String(current_map_id),
		"spawn_id": String(spawn_id),
		"has_position": has_position,
		"player_position": [player_position.x, player_position.y, player_position.z],
		"player_yaw": player_yaw,
		"respawn_map_id": String(respawn_map_id),
		"respawn_spawn_id": String(respawn_spawn_id),
		"flags": flag_out,
		"collected_pickups": collected_pickups.duplicate(),
		"visited_maps": visited_maps.duplicate(),
	}


func load_dict(data: Dictionary) -> void:
	current_map_id = StringName(str(data.get("current_map_id", "starter_zone")))
	spawn_id = StringName(str(data.get("spawn_id", "start")))
	has_position = bool(data.get("has_position", false))
	var pos = data.get("player_position", [0, 0, 0])
	if pos is Array and pos.size() >= 3:
		player_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		if not player_position.is_finite():
			player_position = Vector3.ZERO
			has_position = false
	player_yaw = float(data.get("player_yaw", 0.0))
	respawn_map_id = StringName(str(data.get("respawn_map_id", "starter_zone")))
	respawn_spawn_id = StringName(str(data.get("respawn_spawn_id", "start")))
	flags.clear()
	var f = data.get("flags", {})
	if f is Dictionary:
		for key in f.keys():
			flags[StringName(str(key))] = f[key]
	collected_pickups.clear()
	var picks = data.get("collected_pickups", [])
	if picks is Array:
		for p in picks:
			collected_pickups.append(str(p))
	visited_maps.clear()
	var visited = data.get("visited_maps", [])
	if visited is Array:
		for m in visited:
			visited_maps.append(str(m))
