extends TestCase

const TEST_DIR := "user://test_saves"

var _old_dir := ""


func before_each() -> void:
	_old_dir = SaveManager.save_dir
	SaveManager.save_dir = TEST_DIR
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	for slot in range(0, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
	reset_game(&"agumon", "Quester")


func after_each() -> void:
	for slot in range(0, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
	SaveManager.save_dir = _old_dir


func test_first_quest_flow() -> void:
	check_eq(QuestManager.get_state(&"q_first_steps"), QuestLog.State.AVAILABLE, "available at start")
	check_eq(QuestManager.get_npc_marker(&"mira"), &"available", "! marker")
	var talk := QuestManager.resolve_npc_interaction(&"mira")
	check_eq(talk.action, &"offer", "mira offers quest")
	QuestManager.apply_npc_action(talk, &"mira")
	check_eq(QuestManager.get_state(&"q_first_steps"), QuestLog.State.ACTIVE, "active")
	check_eq(QuestManager.resolve_npc_interaction(&"mira").action, &"in_progress", "hint while active")
	EventBus.battle_won.emit(&"kunemon", 3)
	check_eq(GameState.quest_log.get_step(&"q_first_steps"), 0, "battle before area doesn't count")
	EventBus.area_entered.emit(&"training_grounds", "Training Grounds")
	check_eq(GameState.quest_log.get_step(&"q_first_steps"), 1, "area reached")
	EventBus.battle_won.emit(&"goburimon", 4)
	check_eq(QuestManager.get_state(&"q_first_steps"), QuestLog.State.COMPLETED, "completed")
	check_eq(QuestManager.get_npc_marker(&"mira"), &"turn_in", "? marker")
	var lead := GameState.roster.get_lead()
	var level := lead.level
	var turn_in := QuestManager.resolve_npc_interaction(&"mira")
	check_eq(turn_in.action, &"turn_in", "turn in")
	var rewards := QuestManager.apply_npc_action(turn_in, &"mira")
	check_eq(QuestManager.get_state(&"q_first_steps"), QuestLog.State.REWARDED, "rewarded")
	check_eq(int(rewards.exp), 100, "exp reward summary")
	check(lead.level > level or lead.experience > 0, "party got EXP")
	check(GameState.inventory.has_item(&"evo_shard"), "evo shard rewarded")
	check(GameState.get_flag(&"gateway_unlocked", false), "gateway flag set")
	check_eq(QuestManager.get_state(&"q_new_friend"), QuestLog.State.AVAILABLE, "follow-up quest unlocked")
	check(SaveManager.slot_exists(SaveManager.AUTOSAVE_SLOT), "autosave after quest reward")


func test_collect_and_recruit_objectives() -> void:
	QuestManager.start_quest(&"q_scattered_data")
	GameState.inventory.add_item(&"data_fragment", 1)
	check_eq(GameState.quest_log.get_progress(&"q_scattered_data"), 1, "progress 1/3")
	check(QuestManager.get_objective_text(&"q_scattered_data").contains("1/3"), "tracker shows progress")
	GameState.inventory.add_item(&"data_fragment", 2)
	check_eq(QuestManager.get_state(&"q_scattered_data"), QuestLog.State.COMPLETED, "collected all")
	GameState.quest_log.set_state(&"q_first_steps", QuestLog.State.REWARDED)
	QuestManager.refresh_availability()
	QuestManager.start_quest(&"q_new_friend")
	EventBus.digimon_recruited.emit(DigimonInstance.create(&"palmon", 4))
	check_eq(QuestManager.get_state(&"q_new_friend"), QuestLog.State.COMPLETED, "recruit objective")


func test_save_and_load_roundtrip() -> void:
	GameState.profile.appearance.hair_style = &"twin_tails"
	GameState.profile.add_currency(55)
	GameState.inventory.add_item(&"evo_shard", 1)
	var recruit := DigimonInstance.create(&"palmon", 4)
	GameState.roster.add_digimon(recruit)
	GameState.roster.get_lead().take_damage(5)
	QuestManager.start_quest(&"q_first_steps")
	GameState.world.store_player_transform(Vector3(12, 1, -3), 1.25)
	GameState.set_flag(&"test_flag", true)
	var lead_hp := GameState.roster.get_lead().current_hp
	check(SaveManager.save_game(2), "saved")
	var info := SaveManager.get_slot_info(2)
	check(info.exists and not info.corrupt, "slot info")
	check_eq(str(info.player_name), "Quester", "meta name")
	reset_game(&"gabumon", "Other")
	check(SaveManager.load_game(2), "loaded")
	check_eq(GameState.profile.player_name, "Quester", "name restored")
	check_eq(GameState.profile.appearance.hair_style, &"twin_tails", "appearance restored")
	check_eq(GameState.profile.starter_species_id, &"agumon", "starter restored")
	check_eq(GameState.profile.currency, 155, "currency restored")
	check_eq(GameState.roster.size(), 2, "roster restored")
	check_eq(GameState.roster.get_lead().species_id, &"agumon", "lead restored")
	check_eq(GameState.roster.get_lead().current_hp, lead_hp, "hp restored")
	check(GameState.inventory.has_item(&"evo_shard"), "inventory restored")
	check_eq(QuestManager.get_state(&"q_first_steps"), QuestLog.State.ACTIVE, "quest restored")
	check(GameState.world.player_position.is_equal_approx(Vector3(12, 1, -3)), "position restored")
	check(GameState.get_flag(&"test_flag", false), "flags restored")


func test_corrupt_save_falls_back_to_backup() -> void:
	check(SaveManager.save_game(1), "first save")
	GameState.profile.add_currency(1)
	check(SaveManager.save_game(1), "second save creates backup")
	var file := FileAccess.open(SaveManager.get_slot_path(1), FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	check(SaveManager.load_game(1), "backup used")
	check_eq(GameState.profile.player_name, "Quester", "backup data")


func test_fully_corrupt_save_does_not_crash() -> void:
	var file := FileAccess.open(SaveManager.get_slot_path(3), FileAccess.WRITE)
	file.store_string("garbage")
	file.close()
	var info := SaveManager.get_slot_info(3)
	check(info.exists and info.corrupt, "reported corrupt")
	check(not SaveManager.load_game(3), "load fails gracefully")
	check(GameState.is_game_active, "current game untouched")


func test_migration_from_v0() -> void:
	var legacy := {
		"version": 0,
		"profile": {"player_name": "Old", "appearance": {}, "starter_species_id": "patamon"},
		"roster": {"owned": [DigimonInstance.create(&"patamon", 6).to_dict()], "party": []},
		"inventory": {"small_patch": 2},
		"quests": {},
		"world": {"current_map_id": "starter_zone"},
	}
	var migrated = SaveManager.migrate(legacy)
	check(migrated != null, "migrated")
	check_eq(int(migrated.version), SaveManager.SAVE_VERSION, "version bumped")
	check(migrated.has("state"), "state section created")
	GameState.load_from_dict(migrated.state)
	check_eq(GameState.profile.player_name, "Old", "legacy name")
	check_eq(GameState.roster.get_party().size(), 1, "empty party repaired")
	check(SaveManager.migrate({"version": 999}) == null, "future versions rejected")
