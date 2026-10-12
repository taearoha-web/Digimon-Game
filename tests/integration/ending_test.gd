extends Node
## Final-field routing, old-save compatibility, replay UI and delayed callbacks.
## Run with isolated user data and --headless --fixed-fps 60.

var checks := 0
var failures := 0
var endings := 0


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", detail)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	Game.ending_requested.connect(_record_ending)
	var original_scale := Engine.time_scale
	Engine.time_scale = 8.0
	_new_character("Legacy magma save")
	Game.profile.flags["ending_seen"] = 1
	Game.set_quest("magma", "active", 0)
	check(not Game.ending_unlocked(), "legacy magma ending does not unlock the final-stage replay")
	check(_replay_button() == null, "legacy magma save has no finale replay button")
	var earlier_bosses := 0
	for zone_id in ZoneData.ZONES:
		var zone := ZoneData.get_zone(zone_id)
		if zone_id == Game.ENDING_ZONE or not zone.has("boss"):
			continue
		Game.current_zone = zone_id
		Game.report_kill(zone.boss.monster, true)
		earlier_bosses += 1
	check(earlier_bosses == 14, "all fourteen earlier field bosses were exercised")
	check(Game.quest_status("magma") == "ready" and Game.quest_state("magma").progress == 1, "magma quest progress still reaches its turn-in state")
	check(QuestData.get_quest("magma").next == "bones", "magma quest still leads into the graveyard")
	check(int(Game.profile.boss_kills.get("magma_dragon", 0)) == 1, "magma victory is still counted")
	Game.current_zone = &"tower"
	Game.report_kill(&"void_emperor", true)
	Game.current_zone = Game.ENDING_ZONE
	Game.report_kill(&"void_emperor", false)
	await _wait(2.8)
	check(endings == 0 and not Game.ending_unlocked(), "earlier bosses, tower emperor and non-boss kills never end the game")
	check(Game.save() and Game.load_game(), "legacy progress saves and reloads")
	check(int(Game.profile.flags.get("ending_seen", 0)) == 1 and not Game.ending_unlocked(), "old completion flag survives without blocking the new finale")
	var final_field := ZoneData.get_zone(Game.ENDING_ZONE)
	check(final_field.boss.monster == &"eclipse_sovereign" and String(final_field.next).is_empty(), "ending destination is the final field in the travel chain")
	Game.report_kill(final_field.boss.monster, true)
	Game.report_kill(final_field.boss.monster, true)
	check(Game.ending_unlocked(), "final field victory unlocks replay immediately")
	get_tree().paused = true
	await _wait(3.0)
	check(endings == 0, "victory delay waits while a menu has paused the game")
	get_tree().paused = false
	await _wait(2.8)
	check(endings == 1, "two quick final boss kills schedule only one ending")
	check(Game.save() and Game.load_game() and Game.ending_unlocked(), "finale completion persists across save and reload")
	check(Game.save_code_roundtrip(), "finale progress survives backup validation and transfer")
	Game.report_kill(&"eclipse_sovereign", true)
	await _wait(2.8)
	check(endings == 1, "repeat farming after reload does not reopen the ending")
	var replay := _replay_button()
	check(replay != null, "final-stage victory unlocks the settings replay button")
	if replay:
		replay.pressed.emit()
		check(endings == 2 and not get_tree().paused, "replay leaves the settings menu and requests the ending")
	_clear_menu()
	var transfer := Game._decode_import(Game.export_code())
	check(not transfer.is_empty() and int(transfer.flags.get(Game.ENDING_FLAG, 0)) == 1, "new ending flag is accepted by import validation")
	var baseline := endings
	_new_character("Departing winner")
	Game.current_zone = Game.ENDING_ZONE
	Game.report_kill(&"eclipse_sovereign", true)
	Game.current_zone = &"town"
	await _wait(2.8)
	check(endings == baseline and Game.ending_unlocked(), "leaving during the delay keeps replay but cancels the field cutscene")
	_new_character("Replaced winner")
	Game.current_zone = Game.ENDING_ZONE
	Game.report_kill(&"eclipse_sovereign", true)
	_new_character("Replacement character")
	Game.current_zone = Game.ENDING_ZONE
	await _wait(2.8)
	check(endings == baseline and not Game.ending_unlocked(), "an old timer cannot show the finale on a replacement profile in the same slot")
	_new_character("Returning to title")
	Game.current_zone = Game.ENDING_ZONE
	Game.report_kill(&"eclipse_sovereign", true)
	Game.playing = false
	await _wait(2.8)
	check(endings == baseline, "returning to the title cancels the delayed cutscene")
	check(EndingScreen.PAGES[0].contains("ราชันสุริยคราส") and not EndingScreen.PAGES[0].contains("แมกมา"), "ending narration belongs to the final emperor")
	Game.ending_requested.disconnect(_record_ending)
	Engine.time_scale = original_scale
	Game.has_profile = false
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	print("ENDING: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


func _record_ending() -> void:
	endings += 1


func _new_character(label: String) -> void:
	Game.slot = 1
	Game.new_profile(&"warrior", label)
	Game.playing = true


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _replay_button() -> Button:
	_clear_menu()
	var menu := GameMenu.new()
	menu.name = "ReplayMenu"
	add_child(menu)
	menu.open_menu(&"settings")
	var found: Button
	for node in menu.find_children("*", "Button", true, false):
		if node.text == "ดูตอนจบอีกครั้ง":
			found = node
	if found == null:
		menu.close_menu()
	return found


func _clear_menu() -> void:
	var menu := get_node_or_null("ReplayMenu")
	if menu:
		menu.free()
