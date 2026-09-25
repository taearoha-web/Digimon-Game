extends Node
## End-to-end test of the vertical slice using the real scenes:
## new game -> world -> partner follows -> talk to Mira -> quest -> training
## grounds -> wild battle -> victory/EXP -> turn in quest -> rewards ->
## save -> load. Runs headless:
##   godot --headless --path . res://tests/integration/vertical_slice_test.tscn
## Exit code 0 = pass.

const TEST_DIR := "user://test_saves_integration"
const STEP_TIMEOUT := 30.0

var _failures: Array[String] = []
var _driver_mode := false
var _completed := false


func _ready() -> void:
	if not has_meta("driver"):
		# Re-parent a copy of this script under the root so scene changes
		# don't free the test driver.
		var driver := Node.new()
		driver.set_script(get_script())
		driver.set_meta("driver", true)
		get_parent().remove_child.call_deferred(self)
		get_tree().root.add_child.call_deferred(driver)
		return
	_driver_mode = true
	await get_tree().process_frame
	SaveManager.save_dir = TEST_DIR
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	for slot in range(0, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
	await _run()
	if not _completed:
		_failures.append("test aborted before finishing (see errors above)")
	for slot in range(0, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
	print("")
	if _failures.is_empty():
		print("VERTICAL SLICE TEST: PASS")
	else:
		print("VERTICAL SLICE TEST: FAIL (%d)" % _failures.size())
		for f in _failures:
			print("  - ", f)
	get_tree().quit(_failures.size())


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		print("  FAIL ", message)
		_failures.append(message)


func _run() -> void:
	print("== New game")
	var draft := NewGameDraft.new()
	draft.player_name = "Slice"
	draft.appearance = CharacterAppearance.create_default(&"female")
	draft.appearance.hair_style = &"twin_tails"
	draft.starter_species_id = &"patamon"
	_check(draft.is_complete(), "draft complete")
	GameState.start_new_game(draft)
	SaveManager.autosave("starter confirmed", true)
	_check(SaveManager.slot_exists(SaveManager.AUTOSAVE_SLOT), "autosave after starter confirmation")
	_check(GameState.roster.get_lead().species_id == &"patamon", "starter stored in party slot 1")

	print("== Enter world")
	SceneManager.goto_map(&"starter_zone", &"start", {"intro": true})
	await _wait_transition()
	var world := get_tree().current_scene as WorldMap
	_check(world != null, "starter zone loaded")
	if world == null:
		return
	await _frames(20)
	_check(world.player != null and world.player.is_inside_tree(), "player spawned")
	_check(world.partner != null and world.partner.visual.species.id == &"patamon", "partner Patamon follows player")
	_check(world.player.avatar.appearance.hair_style == &"twin_tails", "player appearance applied")
	_check(world.get_node_or_null("NPCs/Mira") != null, "Mira present")

	print("== Partner follow")
	var start_pos := world.player.global_position
	world.player.global_position = start_pos + Vector3(6, 0, 0)
	world.player.global_position.y = world.get_ground_height(world.player.global_position.x, world.player.global_position.z) + 0.3
	await _seconds(2.5)
	var gap := world.partner.global_position.distance_to(world.player.global_position)
	_check(gap < 5.0, "partner caught up with the player (gap %.1f m)" % gap)

	print("== Talk to Mira")
	var mira := world.get_node("NPCs/Mira") as Npc
	_teleport(world, mira.global_position + Vector3(0, 0, 1.8))
	await _seconds(0.5)
	_check(world.player.interaction.get_current() != null, "interaction target detected")
	world.player.try_interact()
	await _seconds(0.3)
	_check(world.dialogue_box.is_open, "dialogue opened")
	await _finish_dialogue(world)
	await _seconds(0.3)
	_check(QuestManager.get_state(&"q_first_steps") == QuestLog.State.ACTIVE, "quest received")

	print("== Travel to the Training Grounds")
	var tg := world.get_node("Waypoints/training_grounds") as Node3D
	_teleport(world, tg.global_position + Vector3(1, 0, 1))
	await _seconds(0.8)
	_check(GameState.quest_log.get_step(&"q_first_steps") == 1, "training grounds objective complete")

	print("== Battle a wild Digimon")
	var wild := WildDigimon.new()
	wild.setup(&"kunemon", 3, tg.global_position, Vector3(4, 0, 4), world.player)
	world.add_child(wild)
	wild.global_position = world.player.global_position + Vector3(3, 0.3, 0)
	await _frames(2)
	world._encounter_grace = 0.0
	world._on_encounter(wild)
	await _wait_for_scene("BattleScene")
	var battle := get_tree().current_scene as BattleScene
	_check(battle != null, "battle scene loaded")
	if battle == null:
		return
	var lead := GameState.roster.get_lead()
	var level_before := lead.level
	var exp_before := lead.experience
	await _auto_battle(battle)
	_check(battle.controller.outcome == BattleController.Outcome.VICTORY, "won the battle")
	await _dismiss_battle_popups(battle)
	await _wait_for_scene("StarterZone")
	world = get_tree().current_scene as WorldMap
	_check(world != null, "returned to the world")
	if world == null:
		return
	await _frames(10)
	_check(lead.level > level_before or lead.experience > exp_before, "EXP gained (Lv %d -> %d)" % [level_before, lead.level])
	_check(QuestManager.get_state(&"q_first_steps") == QuestLog.State.COMPLETED, "quest ready to turn in")
	tg = world.get_node("Waypoints/training_grounds") as Node3D
	_check(world.player.global_position.distance_to(tg.global_position) < 10.0, "player returned where the battle started")

	print("== Turn in quest")
	mira = world.get_node("NPCs/Mira") as Npc
	_teleport(world, mira.global_position + Vector3(0, 0, 1.8))
	await _seconds(0.5)
	world.player.try_interact()
	await _seconds(0.3)
	await _finish_dialogue(world)
	await _seconds(0.5)
	await _dismiss_popups(world.popups)
	_check(QuestManager.get_state(&"q_first_steps") == QuestLog.State.REWARDED, "quest rewarded")
	_check(GameState.inventory.has_item(&"evo_shard"), "reward item received")
	_check(GameState.get_flag(&"gateway_unlocked", false), "gateway unlocked")
	_check(QuestManager.get_state(&"q_new_friend") == QuestLog.State.AVAILABLE, "next quest available")

	print("== Save and load")
	_check(SaveManager.save_game(1), "manual save")
	var saved_currency := GameState.profile.currency
	var saved_pos := world.player.global_position
	GameState.profile.add_currency(999)
	_check(SaveManager.load_game(1), "load slot 1")
	_check(GameState.profile.currency == saved_currency, "currency restored")
	_check(GameState.profile.player_name == "Slice", "name restored")
	_check(QuestManager.get_state(&"q_first_steps") == QuestLog.State.REWARDED, "quest state restored")
	SceneManager.goto_map(GameState.world.current_map_id, GameState.world.spawn_id)
	await _wait_transition()
	world = get_tree().current_scene as WorldMap
	await _frames(10)
	_check(world != null and world.player.global_position.distance_to(saved_pos) < 1.5, "player position restored after load")
	_check(world != null and world.partner.visual.species.id == GameState.roster.get_lead().species_id, "partner restored after load")

	print("== Pause menu tabs")
	for tab in [&"digimon", &"party", &"inventory", &"quests", &"settings", &"save"]:
		world.pause_menu.open(tab)
		await _frames(3)
		_check(world.pause_menu.is_open and world.pause_menu.current_tab == tab, "pause menu tab %s" % tab)
	world.pause_menu.close()
	_check(not get_tree().paused, "game unpaused after closing menu")
	_completed = true


# ---------------------------------------------------------------------------

func _auto_battle(battle: BattleScene) -> void:
	var elapsed := 0.0
	while not battle.controller.is_finished() and elapsed < 90.0:
		battle.ui._tapped = true
		if battle.ui._commands.visible:
			if battle.controller.phase == BattleController.Phase.AWAITING_SWITCH:
				for i in battle.controller.party.size():
					if not battle.controller.party[i].is_fainted():
						battle.ui.hide_menus()
						battle._on_forced_switch(i)
						break
			else:
				var best: Dictionary = {}
				for o in battle.controller.get_skill_options():
					if o.usable and (best.is_empty() or o.skill.power > best.skill.power):
						best = o
				battle.ui.hide_menus()
				battle._on_command({"type": "defend"} if best.is_empty() else {"type": "skill", "skill_id": best.skill.id})
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _dismiss_battle_popups(battle: BattleScene) -> void:
	var elapsed := 0.0
	while elapsed < STEP_TIMEOUT and not SceneManager.is_transitioning:
		if is_instance_valid(battle) and battle.ui:
			battle.ui._tapped = true
			for node in battle.ui.find_children("*", "Button", true, false):
				var b := node as Button
				if b.is_visible_in_tree() and not b.disabled and b.text in ["Continue", "OK", "Welcome!", "Great!", "Later", "Not now"]:
					b.pressed.emit()
					break
			await _dismiss_popups(battle.popups, 0.2)
		await get_tree().create_timer(0.15).timeout
		elapsed += 0.15


func _dismiss_popups(queue: PopupQueue, limit := STEP_TIMEOUT) -> void:
	var elapsed := 0.0
	while is_instance_valid(queue) and queue.is_busy() and elapsed < limit:
		for node in queue.find_children("*", "Button", true, false):
			var b := node as Button
			if b.is_visible_in_tree() and not b.disabled and b.text in ["OK", "Later", "Continue"]:
				b.pressed.emit()
				break
		await get_tree().create_timer(0.15).timeout
		elapsed += 0.15


func _finish_dialogue(world: WorldMap) -> void:
	var elapsed := 0.0
	while world.dialogue_box.is_open and elapsed < STEP_TIMEOUT:
		world.dialogue_box._advance()
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05


func _teleport(world: WorldMap, pos: Vector3) -> void:
	world.player.global_position = Vector3(pos.x, world.get_ground_height(pos.x, pos.z) + 0.3, pos.z)
	world.player.velocity = Vector3.ZERO
	world.camera_rig.snap_to_target()
	world.partner.teleport_near_target()


func _wait_transition() -> void:
	await get_tree().process_frame
	var elapsed := 0.0
	while SceneManager.is_transitioning and elapsed < STEP_TIMEOUT:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	await _frames(5)


func _wait_for_scene(scene_name: String) -> void:
	var elapsed := 0.0
	while elapsed < STEP_TIMEOUT:
		var scene := get_tree().current_scene
		if scene and scene.name == scene_name and not SceneManager.is_transitioning:
			break
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	await _frames(5)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
