class_name WorldMap
extends Node3D
## Base script for explorable maps. Creates the player, camera and partner,
## wires the HUD / dialogue / pause menu, starts battles from encounters and
## restores state when returning from a battle or loading a save.
##
## Expected children (all optional except SpawnPoints):
##   Builder (StarterZoneBuilder or any node with build()/get_height())
##   NavigationRegion3D (baked at runtime from the builder's colliders)
##   SpawnPoints/<spawn_id> (Marker3D)
##   Waypoints/<id> (Marker3D) — HUD compass targets
##   Nodes in group "ground_snap" get snapped onto the terrain.

const PLAYER_SCENE := preload("res://characters/player/player.tscn")
const ENCOUNTER_GRACE_SECONDS := 3.0

@export var map_id: StringName = &"starter_zone"

var player: PlayerController
var camera_rig: ThirdPersonCamera
var partner: PartnerFollower
var hud: HUD
var dialogue_box: DialogueBox
var pause_menu: PauseMenu
var popups: PopupQueue
var builder: Node

var _battle_starting := false
var _encounter_grace := ENCOUNTER_GRACE_SECONDS
var _params: Dictionary = {}


func _ready() -> void:
	add_to_group("world_map")
	add_to_group("save_listeners")
	_params = SceneManager.take_params()
	if not GameState.is_game_active:
		# Opened directly from the editor: start a quick debug game.
		_start_debug_game()
	GameState.world.current_map_id = map_id
	if not GameState.world.visited_maps.has(String(map_id)):
		GameState.world.visited_maps.append(String(map_id))

	builder = get_node_or_null("NavigationRegion3D/Builder")
	if builder == null:
		builder = get_node_or_null("Builder")
	if builder and builder.has_method("build"):
		builder.build()
	_snap_to_ground()

	_create_ui()
	_spawn_player()
	_spawn_partner()
	_start_spawners()
	for npc in get_tree().get_nodes_in_group("npcs"):
		(npc as Npc).set_player(player)

	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	EventBus.party_changed.connect(_on_party_changed)
	EventBus.quest_rewarded.connect(_on_quest_rewarded)
	EventBus.digimon_evolved.connect(func(_i, _f): _on_party_changed())

	var map_data := GameData.get_map(map_id)
	AudioManager.play_music(map_data.music_id if map_data else &"field")
	_bake_navigation.call_deferred()
	_on_arrival.call_deferred()


func _process(delta: float) -> void:
	_encounter_grace = maxf(0.0, _encounter_grace - delta)


## Terrain height query used for spawning / snapping.
func get_ground_height(x: float, z: float) -> float:
	if builder and builder.has_method("get_height"):
		return builder.get_height(x, z)
	return 0.0


## Resolves a waypoint id to a world position (NPC id, Waypoints marker…).
func resolve_waypoint(waypoint_id: StringName) -> Variant:
	if waypoint_id == &"":
		return null
	for npc in get_tree().get_nodes_in_group("npcs"):
		if (npc as Npc).npc_id == waypoint_id:
			return (npc as Node3D).global_position
	var marker := get_node_or_null("Waypoints/%s" % waypoint_id) as Node3D
	return marker.global_position if marker else null


func on_before_save() -> void:
	if player:
		GameState.world.current_map_id = map_id
		GameState.world.store_player_transform(player.global_position, player.get_facing())


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _start_debug_game() -> void:
	var draft := NewGameDraft.new()
	draft.player_name = "Tester"
	draft.starter_species_id = GameData.starter_roster.starter_ids[0] if not GameData.starter_roster.starter_ids.is_empty() else &"agumon"
	GameState.start_new_game(draft)


func _create_ui() -> void:
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	dialogue_box = DialogueBox.new()
	dialogue_box.name = "DialogueBox"
	add_child(dialogue_box)
	popups = PopupQueue.new()
	popups.name = "PopupQueue"
	add_child(popups)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	hud.menu_requested.connect(_on_menu_requested)
	pause_menu.closed.connect(_on_pause_closed)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as PlayerController
	add_child(player)
	player.apply_appearance(GameState.profile.appearance)
	var spawn_pos := Vector3.ZERO
	var spawn_yaw := 0.0
	var spawn_id: StringName = _params.get("spawn_id", GameState.world.spawn_id)
	if GameState.world.has_position and not _params.get("from_portal", false):
		spawn_pos = GameState.world.player_position
		spawn_yaw = GameState.world.player_yaw
	else:
		var marker := get_node_or_null("SpawnPoints/%s" % spawn_id) as Node3D
		if marker == null:
			marker = get_node_or_null("SpawnPoints/start") as Node3D
		if marker:
			spawn_pos = marker.global_position
			spawn_yaw = marker.global_rotation.y
	spawn_pos.y = get_ground_height(spawn_pos.x, spawn_pos.z) + 0.3
	player.global_position = spawn_pos
	player.set_facing(spawn_yaw)

	camera_rig = ThirdPersonCamera.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = player
	add_child(camera_rig)
	camera_rig.add_excluded_body(player)
	camera_rig.set_yaw_behind(spawn_yaw + PI)
	camera_rig.snap_to_target()
	player.camera_rig = camera_rig

	hud.bind(player, camera_rig, resolve_waypoint)
	hud.joystick.input_changed.connect(func(v: Vector2): player.touch_move = v)
	hud.camera_area.drag.connect(camera_rig.rotate_by_pixels)
	hud.camera_area.pinch.connect(camera_rig.zoom)
	hud.interact_pressed.connect(func(): player.try_interact())
	hud.sprint_toggled.connect(func(on: bool): player.sprint_toggled = on)
	player.interactable_changed.connect(hud.set_interact_target)


func _spawn_partner() -> void:
	if partner:
		partner.queue_free()
		partner = null
	var lead := GameState.roster.get_lead()
	if lead == null:
		return
	partner = PartnerFollower.new()
	partner.name = "Partner"
	add_child(partner)
	partner.setup(lead, player)
	partner.teleport_near_target()
	var p := partner.global_position
	partner.global_position = Vector3(p.x, get_ground_height(p.x, p.z) + 0.3, p.z)


func _start_spawners() -> void:
	for node in find_children("*", "EncounterSpawner", true, false):
		var spawner := node as EncounterSpawner
		spawner.start(player, get_ground_height)
		spawner.encounter_started.connect(_on_encounter)


func _snap_to_ground() -> void:
	for node in get_tree().get_nodes_in_group("ground_snap"):
		if node is Node3D and is_ancestor_of(node):
			var n := node as Node3D
			var p := n.global_position
			n.global_position = Vector3(p.x, get_ground_height(p.x, p.z) + float(n.get_meta("ground_offset", 0.0)), p.z)


func _bake_navigation() -> void:
	var region := get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if region and region.navigation_mesh:
		region.bake_navigation_mesh(true)


func _on_arrival() -> void:
	if _params.get("intro", false):
		hud.show_banner("Digital World")
		await get_tree().create_timer(1.2).timeout
		EventBus.toast("Talk to Mira in the plaza — look for the \"!\" marker.", &"quest")
	elif _params.get("from_portal", false):
		var map_data := GameData.get_map(map_id)
		hud.show_banner(map_data.display_name if map_data else String(map_id))
		SaveManager.autosave("area transition", true)
	elif _params.get("from_battle", false):
		_encounter_grace = ENCOUNTER_GRACE_SECONDS
		_show_battle_aftermath()
	else:
		var map_data := GameData.get_map(map_id)
		hud.show_banner(map_data.display_name if map_data else "")


func _show_battle_aftermath() -> void:
	var summary := GameState.last_battle_summary
	GameState.last_battle_summary = {}
	if summary.get("outcome", -1) == BattleController.Outcome.DEFEAT:
		EventBus.toast("Your party was restored at the Recovery Terminal.", &"info")


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func _on_encounter(wild: WildDigimon) -> void:
	if _battle_starting or _encounter_grace > 0.0 or dialogue_box.is_open or get_tree().paused:
		return
	if GameState.roster.is_party_defeated():
		EventBus.toast("Your Digimon need rest! Visit the Recovery Terminal.", &"warning")
		return
	_battle_starting = true
	player.set_input_enabled(false)
	hud.set_controls_visible(false)
	for node in find_children("*", "EncounterSpawner", true, false):
		(node as EncounterSpawner).set_encounters_enabled(false)
	AudioManager.play_sfx(&"encounter")
	camera_rig.shake(0.25)
	on_before_save()
	var request := BattleRequest.wild(wild.species_id, wild.level)
	request.return_map_id = map_id
	request.source_id = wild.spawn_key
	var map_data := GameData.get_map(map_id)
	if map_data:
		request.arena_theme = map_data.battle_arena
	await get_tree().create_timer(0.35).timeout
	SceneManager.goto_battle(request)


func _on_dialogue_started(_id: StringName) -> void:
	player.set_input_enabled(false)
	hud.set_controls_visible(false)


func _on_dialogue_finished(_id: StringName) -> void:
	if _battle_starting:
		return
	player.set_input_enabled(true)
	hud.set_controls_visible(true)


func _on_menu_requested(tab: StringName) -> void:
	if dialogue_box.is_open or _battle_starting or popups.is_busy():
		return
	pause_menu.open(tab)


func _on_pause_closed() -> void:
	# Party order / evolutions may have changed while paused.
	_on_party_changed()


func _on_party_changed() -> void:
	var lead := GameState.roster.get_lead()
	if lead == null:
		return
	if partner == null or partner.instance != lead or partner.visual.species == null or partner.visual.species.id != lead.species_id:
		var old_pos := partner.global_position if partner else player.global_position
		_spawn_partner()
		if partner:
			partner.global_position = old_pos
	hud.refresh_partner()


func _on_quest_rewarded(_quest_id: StringName, rewards: Dictionary) -> void:
	popups.show_quest_rewards(rewards)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu") and not dialogue_box.is_open and not pause_menu.is_open:
		get_viewport().set_input_as_handled()
		_on_menu_requested(&"")
	elif event.is_action_pressed("interact") and not dialogue_box.is_open and not pause_menu.is_open:
		if player.try_interact():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_party") and not pause_menu.is_open:
		_on_menu_requested(&"party")
	elif event.is_action_pressed("open_inventory") and not pause_menu.is_open:
		_on_menu_requested(&"inventory")
	elif event.is_action_pressed("open_quests") and not pause_menu.is_open:
		_on_menu_requested(&"quests")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button: toggles the pause menu (single handler on purpose).
		if pause_menu == null or (dialogue_box and dialogue_box.is_open):
			return
		if pause_menu.is_open:
			pause_menu.close()
		else:
			pause_menu.open(&"")
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		# Mobile: autosave when the app goes to the background.
		SaveManager.autosave("app paused", true)
