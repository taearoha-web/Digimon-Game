extends Node
## Autoload "GameState": the running game (what a save file contains).
##
## Each concern is its own small object (profile, roster, inventory, quests,
## world) so this node stays a thin container rather than a God object.

signal state_reset()

var profile: PlayerProfile = PlayerProfile.new()
var roster: DigimonRoster = DigimonRoster.new()
var inventory: Inventory = Inventory.new()
var quest_log: QuestLog = QuestLog.new()
var world: WorldState = WorldState.new()

var is_game_active: bool = false
## Slot used by manual saves; 0 is the autosave slot.
var active_slot: int = 1

## Battle hand-off between the world and the battle scene.
var pending_battle: BattleRequest = null
## Summary of the last finished battle, read by the world on return.
var last_battle_summary: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_state_signals()


func _process(delta: float) -> void:
	if is_game_active and not get_tree().paused:
		profile.play_time_seconds += delta


func reset() -> void:
	profile = PlayerProfile.new()
	roster = DigimonRoster.new()
	inventory = Inventory.new()
	quest_log = QuestLog.new()
	world = WorldState.new()
	pending_battle = null
	last_battle_summary = {}
	is_game_active = false
	var cfg: RecruitmentConfig = GameData.recruitment_config
	if cfg:
		roster.capacity = cfg.roster_capacity
	_connect_state_signals()
	state_reset.emit()


## Creates a brand-new game from the New Game screens.
func start_new_game(draft: NewGameDraft) -> void:
	reset()
	profile.player_name = NameValidator.sanitize(draft.player_name)
	profile.appearance = draft.appearance.duplicate_appearance()
	profile.starter_species_id = draft.starter_species_id
	profile.created_at = int(Time.get_unix_time_from_system())

	var roster_cfg: StarterRoster = GameData.starter_roster
	var starting_level := roster_cfg.starting_level if roster_cfg else 5
	var partner := DigimonInstance.create(draft.starter_species_id, starting_level)
	partner.origin = &"starter"
	partner.friendship = 20
	roster.add_digimon(partner)

	if roster_cfg:
		profile.currency = roster_cfg.starting_currency
		for item_id in roster_cfg.starting_items.keys():
			inventory.add_item(StringName(item_id), int(roster_cfg.starting_items[item_id]))

	world.current_map_id = &"starter_zone"
	world.spawn_id = &"start"
	world.has_position = false
	is_game_active = true
	QuestManager.refresh_availability()
	EventBus.new_game_started.emit()


func set_flag(flag: StringName, value: Variant = true) -> void:
	world.set_flag(flag, value)
	EventBus.flag_changed.emit(flag, value)


func get_flag(flag: StringName, default_value: Variant = false) -> Variant:
	return world.get_flag(flag, default_value)


func make_evolution_context() -> Dictionary:
	return {"inventory": inventory, "quest_log": quest_log, "flags": world.flags}


func get_lead_digimon() -> DigimonInstance:
	return roster.get_lead()


func to_dict() -> Dictionary:
	return {
		"profile": profile.to_dict(),
		"roster": roster.to_dict(),
		"inventory": inventory.to_dict(),
		"quests": quest_log.to_dict(),
		"world": world.to_dict(),
	}


## Replaces the current state. Missing sections fall back to defaults so a
## partially damaged save still loads.
func load_from_dict(data: Dictionary) -> void:
	reset()
	profile.load_dict(_section(data, "profile"))
	roster.load_dict(_section(data, "roster"))
	inventory.load_dict(_section(data, "inventory"))
	quest_log.load_dict(_section(data, "quests"))
	world.load_dict(_section(data, "world"))
	if roster.size() == 0:
		# A save without Digimon is unplayable: give back the starter.
		var species_id := profile.starter_species_id
		if GameData.get_species(species_id) == null:
			species_id = GameData.starter_roster.starter_ids[0] if GameData.starter_roster and not GameData.starter_roster.starter_ids.is_empty() else &"agumon"
		var partner := DigimonInstance.create(species_id, 5)
		partner.origin = &"starter"
		roster.add_digimon(partner)
	if GameData.get_map(world.current_map_id) == null:
		world.current_map_id = &"starter_zone"
		world.has_position = false
	is_game_active = true
	QuestManager.refresh_availability()


func _section(data: Dictionary, key: String) -> Dictionary:
	var value = data.get(key, {})
	return value if value is Dictionary else {}


func _connect_state_signals() -> void:
	if not roster.party_changed.is_connected(_on_party_changed):
		roster.party_changed.connect(_on_party_changed)
	if not inventory.item_added.is_connected(_on_item_added):
		inventory.item_added.connect(_on_item_added)


func _on_party_changed() -> void:
	EventBus.party_changed.emit()


func _on_item_added(item_id: StringName, amount: int) -> void:
	EventBus.item_obtained.emit(item_id, amount)
