class_name EncounterSpawner
extends Node3D
## Spawns wild Digimon inside a rectangular region using EncounterTable data.
## "Encounters enabled" = the monsters may turn hostile (false keeps them calm).
## Never exceeds the table's max_active; checks on a timer (not per frame).

@export var table_id: StringName
## Half-size of the spawn rectangle (x/z).
@export var extents := Vector3(10, 0, 10)
## Minimum distance from the player for new spawns (no popping in on top).
@export var min_player_distance := 9.0
@export var initial_spawns := 2

var player: Node3D
var ground_query: Callable
var table: EncounterTable

var _active: Array[WildDigimon] = []
var _timer := 0.0
var _respawn_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _encounters_enabled := true


func _ready() -> void:
	_rng.randomize()
	table = GameData.get_encounter_table(table_id)
	if table == null:
		push_warning("EncounterSpawner: unknown table '%s'" % table_id)
		set_process(false)


## Called by the map once the player exists.
func start(p_player: Node3D, p_ground_query: Callable) -> void:
	player = p_player
	ground_query = p_ground_query
	if table == null:
		return
	for i in mini(initial_spawns, table.max_active):
		_try_spawn(true)
	_timer = table.check_interval


func set_encounters_enabled(enabled: bool) -> void:
	_encounters_enabled = enabled
	for wild in _active:
		if is_instance_valid(wild):
			wild.encounters_enabled = enabled


func get_active_count() -> int:
	return _active.size()


func _process(delta: float) -> void:
	if table == null or player == null:
		return
	_respawn_timer = maxf(0.0, _respawn_timer - delta)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = table.check_interval
	if _active.size() < table.max_active and _respawn_timer <= 0.0 and _rng.randf() < table.spawn_chance:
		_try_spawn(false)


func _try_spawn(ignore_player_distance: bool) -> void:
	var entry := table.pick_entry(_rng)
	if entry == null or GameData.get_species(entry.species_id) == null:
		return
	for attempt in 8:
		var pos := global_position + Vector3(_rng.randf_range(-extents.x, extents.x), 0, _rng.randf_range(-extents.z, extents.z))
		if not ignore_player_distance and player.global_position.distance_to(pos) < min_player_distance:
			continue
		if player.global_position.distance_to(pos) < 4.0:
			continue
		pos.y = ground_query.call(pos.x, pos.z) if ground_query.is_valid() else global_position.y
		var wild := WildDigimon.new()
		wild.name = "Wild_%s_%d" % [entry.species_id, _rng.randi() % 10000]
		wild.setup(entry.species_id, _rng.randi_range(entry.min_level, entry.max_level), global_position, extents, player)
		wild.spawn_key = "%s:%s" % [name, wild.name]
		wild.encounters_enabled = _encounters_enabled
		get_parent().add_child(wild)
		wild.global_position = pos + Vector3.UP * 0.3
		wild.tree_exiting.connect(_on_wild_exiting.bind(wild))
		_active.append(wild)
		return


func _on_wild_exiting(wild: WildDigimon) -> void:
	_active.erase(wild)
	if table:
		_respawn_timer = table.respawn_delay
