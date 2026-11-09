extends Node
## บทที่ 2: เงาเหนือดวงดาว (StoryChapter2, StoryChapter): the chain's order and data, and
## every objective completed headlessly through the real NPC dialogs: the talks, the kill
## counts, the collect quests, the three landmarks, the escort (a real body the waves
## attack; a lost attempt can be retried), the mid-boss rite (its tint and two telegraphed
## moves), the finale's portal (only while its quest is active), the throne stage with the
## queen's three phases and dialog interrupts, the ending, the title, the achievement, the
## aura, rewards paid once, the dialog states of each NPC, the tracker, the quest log, the
## world players' lines and a save / load in the middle of the chain.
##   godot --headless --audio-driver Dummy --path . res://tests/integration/story_chapter2_test.tscn

var checks := 0
var failures := 0
var main: Node
var toasts: Array[String] = []
## Every line each chapter NPC said (role -> {text: true}).
var said := {}


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	ZoneData.ensure()
	_data()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	Game.toast.connect(func(text: String, _kind: StringName): toasts.append(text))
	Game.slot = 1
	Game.delete_save()
	Game.new_profile(&"warrior", "ผู้กล้าเงาQA")
	Game.playing = true
	Game.profile.level = 100
	Game.paragon().level = 200
	_heal()
	main.hud.visible = true
	main._traveling = false
	await main.go(&"town", true)
	await _wait(0.4)
	await _opening()
	await _sanctum_part_one()
	await _abyss_part_one()
	await _mid_boss()
	await _abyss_part_two()
	await _finale()
	_chat_and_log()
	print("STORY CHAPTER 2: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- The data -------------------------------------------------------------------------

func _data() -> void:
	var order := StoryChapter2.ORDER
	check(order.size() == 12 and order[0] == StoryChapter2.FIRST and order[-1] == StoryChapter2.FINALE, "twelve quests from the omen to the throne")
	var types := {}
	var last_star := 0
	for i in order.size():
		var id: String = order[i]
		var quest := StoryChapter2.get_quest(id)
		check(not quest.is_empty(), "quest exists " + id)
		var expected_next: String = order[i + 1] if i + 1 < order.size() else ""
		check(String(quest.next) == expected_next, "chain order after " + id)
		check(int(quest.star) >= last_star and int(quest.star) >= 200 and int(quest.star) <= 300, "stars climb from 200 to 300 (%s)" % id)
		last_star = int(quest.star)
		types[String(quest.type)] = true
		check(StoryChapter2.ROLES.has(String(quest.giver)) and StoryChapter2.ROLES.has(StoryChapter2.turn_in_role(id)), "a chapter NPC gives and pays " + id)
		var pay := StoryChapter2.reward(id)
		check(int(pay.exp) > 0 and int(pay.gold) > 0 and not (pay.items as Array).is_empty(), "reward " + id)
		check(String(quest.name) != "" and String(quest.desc).length() > 20 and StoryChapter2.objective_text(id) != "", "Thai text " + id)
		if String(quest.type) == "kill":
			var zone := ZoneData.get_zone(StringName(quest.zone))
			for t in quest.targets:
				var lives := zone.has("boss") and StringName(zone.boss.monster) == StringName(t)
				for camp in zone.camps:
					lives = lives or camp.monsters.has(StringName(t))
				check(lives, "%s hunts %s, a monster of %s" % [id, t, quest.zone])
		if String(quest.type) == "collect":
			check(ItemData.JEWELS.has(String(quest.item)), "%s collects a real jewel" % id)
	for t in ["talk", "kill", "collect", "investigate", "escort", "boss", "finale"]:
		check(types.has(t), "the chain has a %s quest" % t)
	check(int(StoryChapter2.get_quest(StoryChapter2.FINALE).star) == 300 and int(StoryChapter2.get_quest("ch2_midboss").star) == 250, "the mid-boss at 250 stars, the finale at 300")
	check(int(StoryChapter2.reward("ch2_midboss").exp) > int(StoryChapter2.reward("ch2_sprites").exp), "a boss quest pays more")
	# The chapter's monsters are real monsters with the fields' tuning.
	for id in StoryChapter2.MONSTERS:
		var m := MonsterData.get_monster(id)
		check(m.name == StoryChapter2.MONSTERS[id].name and bool(m.boss), "monster dispatch " + String(id))
		check(ResourceLoader.exists("res://assets/models/monsters/%s.gltf" % m.model) or ResourceLoader.exists("res://assets/models/monsters/%s.glb" % m.model), "monster model " + String(id))
		check(not (m.tint as Color).is_equal_approx(Color.WHITE), "its own tint " + String(id))
	var queen := MonsterData.stats_for(&"shadow_queen", EndgameFields.BOSS_LEVEL)
	var tyrant := MonsterData.stats_for(DrownedAbyssData.BOSS, EndgameFields.BOSS_LEVEL)
	check(float(queen.atk) > float(tyrant.atk) * 0.7 and float(queen.atk) < float(tyrant.atk) * 1.6, "the queen hits in the abyss's band (%d vs %d)" % [int(queen.atk), int(tyrant.atk)])
	check(float(queen.hp) > float(tyrant.hp) and float(queen.hp) < float(tyrant.hp) * 2.0, "the queen is tougher than the tyrant, within reason")
	# The throne stage: reachable only through the quest portal, gated at 300 stars.
	var stage := ZoneData.get_zone(StoryChapter2.STAGE_ID)
	check(String(stage.name) == StoryChapter2.STAGE_TITLE and bool(stage.story_stage) and not stage.has("boss") and (stage.camps as Array).is_empty(), "the throne stage is a story stage without camps")
	check(not ZoneData.ZONES.has(StoryChapter2.STAGE_ID) and not WarpScreen.destinations().has(StoryChapter2.STAGE_ID), "the stage is not a travel destination")
	check(ZoneData.access_reason(StoryChapter2.STAGE_ID, 100, 299) != "" and ZoneData.access_reason(StoryChapter2.STAGE_ID, 100, 300) == "", "the stage needs 300 stars")
	check(AudioManager.has_music(StringName(stage.music)), "the stage has music")
	check(Achievements.entry(StoryChapter2.ACH_ID).title == StoryChapter2.END_TITLE, "the finale's achievement grants the title")
	check(StoryChapter2.ENDING_PAGES.size() >= 3 and StoryChapter2.QUEEN_LINES.size() == 3, "ending pages and three queen lines")


# --- Helpers ----------------------------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _heal() -> void:
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp


func _story() -> StoryChapter:
	return main.story


func _zone() -> Zone:
	return main.zone


func _npc(role: String) -> Npc:
	for n in _zone().npcs:
		if n.role == role:
			return n
	return null


## Talks to a chapter NPC and records what it said; returns the dialog's text.
func _talk(role: String) -> String:
	var dialog: DialogBox = main.dialog
	if dialog.is_open:
		dialog.close()
	_story().talk(role)
	var text: String = dialog._text.text
	if not said.has(role):
		said[role] = {}
	said[role][text] = true
	return text


func _dialog_has(label: String) -> bool:
	for b in main.dialog._buttons.get_children():
		if b is Button and (b as Button).text == label:
			return true
	return false


## Presses the dialog's button labelled `label`; false when it is not there.
func _press(label: String) -> bool:
	for b in main.dialog._buttons.get_children():
		if b is Button and (b as Button).text == label:
			(b as Button).pressed.emit()
			return true
	return false


func _accept(role: String, id: String) -> void:
	_talk(role)
	check(_dialog_has("รับเควสต์"), "%s offers %s" % [role, id])
	_press("รับเควสต์")
	check(StoryChapter2.status(id) == "active", "%s is active" % id)


## Turns a ready quest in and checks it pays exactly once.
func _turn_in(role: String, id: String) -> void:
	if String(StoryChapter2.get_quest(id).type) != "talk":
		check(StoryChapter2.status(id) == "ready", "%s is ready to turn in" % id)
	# Achievements earned on the way pay gold of their own: settle them before measuring.
	Game.check_achievements()
	var gold := int(Game.profile.gold)
	var pay := StoryChapter2.reward(id)
	_talk(role)
	check(_dialog_has("รับรางวัล"), "%s pays %s" % [role, id])
	_press("รับรางวัล")
	check(StoryChapter2.status(id) == "done", "%s is done" % id)
	# The EXP paid may earn star achievements that pay gold of their own: at least the quest's.
	check(int(Game.profile.gold) >= gold + int(pay.gold), "%s paid its gold (%d -> %d, reward %d)" % [id, gold, int(Game.profile.gold), int(pay.gold)])
	var again := int(Game.profile.gold)
	_talk(role)
	if _dialog_has("รับรางวัล"):
		_press("รับรางวัล")
	check(int(Game.profile.gold) == again and StoryChapter2.status(id) == "done", "%s cannot be paid twice" % id)
	if main.dialog.is_open:
		main.dialog.close()


func _go(zone_id: StringName) -> void:
	main._traveling = false
	await main.go(zone_id, true)
	await _wait(0.3)
	check(_zone() != null and _zone().zone_id == zone_id and _zone().is_built, "arrived at %s" % zone_id)


func _tracker() -> String:
	main.hud._tracker_timer = 0.0
	main.hud._update_tracker(1.0)
	return main.hud._tracker.text


# --- The village: the offer -------------------------------------------------------------

func _opening() -> void:
	print("== The scholar")
	_story().tick(0.5)
	check(toasts.any(func(t): return t.contains(StoryChapter2.TITLE)), "a 200-star hero is told where the chapter starts")
	var before := toasts.size()
	_story().tick(0.5)
	check(toasts.size() == before, "the offer toast comes once a session")
	var scholar := _npc("scholar")
	check(scholar != null, "the scholar stands in the village")
	_zone()._update_interact()
	check(scholar != null and scholar.marker.visible, "the scholar bobs a quest marker")
	# Below 200 stars the chapter is locked.
	Game.paragon().level = 199
	_talk("scholar")
	check(not _dialog_has("รับเควสต์") and main.dialog._text.text.contains("200"), "199 stars cannot take the chapter")
	main.dialog.close()
	Game.paragon().level = 200
	_accept("scholar", "ch2_omen")
	check(StoryChapter2.tracker_line().contains(StoryChapter2.role_name("sanctum_guardian")), "the tracker sends the hero to the guardian")
	check(QuestData.current_quest() == "slimes", "the elder's own chain is untouched")
	_talk("scholar")
	check(not _dialog_has("รับเควสต์"), "the scholar only hints while the guardian's work is on")
	main.dialog.close()
	# The quest log lists the chapter.
	main.menu.open_menu(&"quests")
	var listed := false
	for label in main.menu.find_children("*", "Label", true, false):
		if (label as Label).text.contains(StoryChapter2.get_quest("ch2_omen").name):
			listed = true
	check(listed, "the quest log shows the chapter")
	main.menu.close_menu()
	get_tree().paused = false
	await _wait(0.1)


# --- The sanctum: talk, kill, collect, investigate ---------------------------------------

func _sanctum_part_one() -> void:
	print("== The sanctum")
	await _go(DivineRegionData.ID)
	check(_tracker().contains("บทที่ 2"), "the HUD tracker shows the chapter's objective in the field")
	var guardian := _npc("sanctum_guardian")
	check(guardian != null, "the guardian stands at the sanctum's entrance")
	_zone()._update_interact()
	check(guardian != null and guardian.marker.visible, "the guardian is marked while the hero is sent to it")
	_turn_in("sanctum_guardian", "ch2_omen")
	check(StoryChapter2.status("ch2_omen") == "done", "the talk quest is finished and paid by the guardian")
	# Kill 20 sprites.
	_accept("sanctum_guardian", "ch2_sprites")
	for i in 19:
		Game.report_kill(&"lotus_sprite")
	check(StoryChapter2.status("ch2_sprites") == "active" and StoryChapter2.progress("ch2_sprites") == 19, "kills count toward the chapter quest")
	Game.report_kill(&"jade_monk")
	check(StoryChapter2.progress("ch2_sprites") == 19, "other monsters do not count")
	Game.report_kill(&"lotus_sprite")
	check(_tracker().contains("เสร็จแล้ว"), "the tracker says the quest is done")
	_turn_in("sanctum_guardian", "ch2_sprites")
	# Collect 5 Lotus Scales (a field drop).
	Game.paragon().level = 210
	_accept("sanctum_guardian", "ch2_scales")
	_story().tick(0.5)
	check(StoryChapter2.status("ch2_scales") == "active", "no scales, no turn-in yet")
	Game.add_item(ItemData.jewel("lotus_scale", 5))
	_story().tick(0.5)
	check(StoryChapter2.status("ch2_scales") == "ready", "five scales in the bag finish the collect quest")
	var scales := Game.jewel_count("lotus_scale")
	_turn_in("sanctum_guardian", "ch2_scales")
	check(Game.jewel_count("lotus_scale") == scales - 5 + 3, "the five scales are taken, the reward's three given")
	# Investigate three landmarks.
	Game.paragon().level = 220
	_accept("sanctum_guardian", "ch2_landmarks")
	_story().tick(0.5)
	var marks := _zone().find_children("*StoryMark*", "", false, false)
	check(marks.size() == 3, "three landmark markers stand in the sanctum (%d)" % marks.size())
	var quest := StoryChapter2.get_quest("ch2_landmarks")
	var hero: Hero = _zone().hero
	for k in 3:
		hero.global_position = (quest.marks[k][1] as Vector3) + Vector3(1.0, 0.2, 0)
		_story().tick(0.5)
		check(StoryChapter2.mark_seen(k), "landmark %d found by walking to it" % k)
	check(StoryChapter2.status("ch2_landmarks") == "ready" and StoryChapter2.progress("ch2_landmarks") == 3, "all three landmarks finish the investigation")
	_turn_in("sanctum_guardian", "ch2_landmarks")
	_story().tick(0.5)
	await get_tree().process_frame
	check(_zone().find_children("*StoryMark*", "", false, false).is_empty(), "the markers go when the investigation is over")
	Game.paragon().level = 230
	_accept("sanctum_guardian", "ch2_exile")
	# The sanctum guardian has spoken in several states by now.
	check((said.get("sanctum_guardian", {}) as Dictionary).size() >= 3, "the guardian has at least three dialog states (%d)" % (said.get("sanctum_guardian", {}) as Dictionary).size())


# --- The abyss: talk, kill, escort -------------------------------------------------------

func _abyss_part_one() -> void:
	print("== The abyss")
	await _go(DrownedAbyssData.ID)
	check(_zone().portals.size() == 1 and not _zone().story_portal_open(), "no throne portal before the finale")
	var exile := _npc("abyss_exile")
	check(exile != null, "the exile stands at the abyss entrance")
	_turn_in("abyss_exile", "ch2_exile")
	Game.paragon().level = 235
	_accept("abyss_exile", "ch2_mermen")
	for i in 15:
		Game.report_kill(&"abyss_merman")
	_turn_in("abyss_exile", "ch2_mermen")
	# The escort: a real body the waves attack; a lost attempt can be tried again.
	Game.paragon().level = 240
	_accept("abyss_exile", "ch2_escort")
	_talk("abyss_exile")
	check(_dialog_has("เริ่มพิธี"), "the exile offers to start the reading")
	_press("เริ่มพิธี")
	var story := _story()
	check(not story.escort.is_empty(), "the escort attempt begins")
	var body: StoryEscort = story.escort.escort
	check(body != null and is_instance_valid(body) and body.is_in_group("companions") and body.max_hp > 0, "the exile is a real body the monsters can target")
	check(exile != null and not exile.visible and not _zone().npcs.has(exile), "the standing exile steps aside while his body reads")
	story.tick(2.0)
	var wave := get_tree().get_nodes_in_group("mobs").filter(func(m): return m.has_meta("escort_wave"))
	check(wave.size() >= StoryChapter.ESCORT_WAVE_SIZE, "a wave of abyss monsters comes for him (%d)" % wave.size())
	var hp := body.hp
	body.take_damage(500.0, null)
	check(body.hp < hp and not body.is_dead(), "monsters hurt the escort")
	body.take_damage(1.0e9, null)
	check(body.is_dead(), "enough damage fells him")
	story.tick(0.5)
	check(story.escort.is_empty() and StoryChapter2.status("ch2_escort") == "active", "a lost attempt ends and the quest stays active for another try")
	await get_tree().process_frame
	check(exile != null and exile.visible and _zone().npcs.has(exile), "the exile stands again after the loss")
	_talk("abyss_exile")
	_press("เริ่มพิธี")
	check(not story.escort.is_empty(), "the attempt can be started again")
	var elapsed := 0.0
	while elapsed < StoryChapter2.ESCORT_SECONDS - 1.0 and not story.escort.is_empty():
		story.tick(1.0)
		elapsed += 1.0
	check(not story.escort.is_empty() and StoryChapter2.status("ch2_escort") == "active", "the quest waits for the full minute (%.0f s)" % elapsed)
	story.tick(1.5)
	check(story.escort.is_empty() and StoryChapter2.status("ch2_escort") == "ready", "60 seconds of protection finish the escort")
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("mobs").filter(func(m): return m.has_meta("escort_wave") and not m.is_queued_for_deletion()).is_empty(), "the waves are gone once it is over")
	# A save and a load in the middle of the chain keep every quest state.
	var statuses := {}
	for id in StoryChapter2.ORDER:
		statuses[id] = StoryChapter2.status(id)
	check(Game.save() and Game.load_game(), "the chain saves and loads")
	for id in StoryChapter2.ORDER:
		check(StoryChapter2.status(id) == statuses[id], "%s keeps its status across save / load (%s)" % [id, statuses[id]])
	check(StoryChapter2.marks_seen() == 7 and StoryChapter2.current() == "ch2_escort", "the landmark bits and the current quest survive the reload")
	Game.playing = true
	_turn_in("abyss_exile", "ch2_escort")


# --- The mid-boss at 250 stars -----------------------------------------------------------

func _mid_boss() -> void:
	print("== The mid-boss")
	Game.paragon().level = 250
	await _go(DivineRegionData.ID)
	_accept("sanctum_guardian", "ch2_midboss")
	_talk("sanctum_guardian")
	check(_dialog_has("เริ่มพิธี"), "the guardian offers the rite")
	_press("เริ่มพิธี")
	var story := _story()
	var boss: Mob = story.mid_boss
	check(boss != null and is_instance_valid(boss) and boss.monster_id == &"shadow_seraph" and boss.is_boss, "the shadow seraph rises")
	check(boss != null and not (boss.template.tint as Color).is_equal_approx(DivineRegionData.MONSTERS[&"lotus_seraph"].tint), "it wears its own night tint, not the seraph's")
	var moves := StoryBoss.of(boss)
	check(moves != null and moves.moves == ["nova", "lance"], "two special moves")
	moves.force_special("nova")
	check(not moves.telegraph.is_empty() and moves._meshes.size() == 2, "the nova is telegraphed on the ground")
	check(moves.inside(boss.global_position + Vector3(3, 0, 0)) and not moves.inside(boss.global_position + Vector3(StoryBoss.NOVA_RADIUS + 2.0, 0, 0)), "the nova covers a ring round the boss")
	var hero: Hero = _zone().hero
	hero.global_position = boss.global_position + Vector3(StoryBoss.NOVA_RADIUS + 4.0, 0.2, 0)
	var hp := int(Game.profile.hp)
	moves.tick(StoryBoss.TELEGRAPH + 0.1)
	check(moves.telegraph.is_empty() and moves.specials == 1 and int(Game.profile.hp) == hp, "stepping out of the nova avoids it")
	moves.force_special("lance")
	check(not moves.telegraph.is_empty() and moves._meshes.size() == 1, "the lance is a single line")
	var dir: Vector3 = moves.telegraph.shapes[0].dir
	var center: Vector3 = moves.telegraph.shapes[0].center
	check(moves.inside(center + dir * 6.0) and not moves.inside(center + dir * 6.0 + dir.rotated(Vector3.UP, PI * 0.5) * 5.0), "the lance covers its line only")
	hero.global_position = center + dir * 6.0 + Vector3(0, 0.2, 0)
	moves.tick(StoryBoss.TELEGRAPH + 0.1)
	check(moves.specials == 2 and int(Game.profile.hp) < hp, "standing in the lance hurts")
	_heal()
	_talk("sanctum_guardian")
	check(not _dialog_has("เริ่มพิธี"), "no second rite while the boss stands")
	main.dialog.close()
	var cores := Game.jewel_count("set_core")
	boss.take_hit(boss.hp, false, Color.WHITE, hero)
	await get_tree().process_frame
	check(StoryChapter2.status("ch2_midboss") == "ready", "the boss kill finishes the quest")
	_turn_in("sanctum_guardian", "ch2_midboss")
	check(Game.jewel_count("set_core") == cores + 1, "the boss quest pays a set core")


# --- The abyss again: collect, elites, the tyrant -----------------------------------------

func _abyss_part_two() -> void:
	print("== The deep")
	Game.paragon().level = 260
	await _go(DrownedAbyssData.ID)
	_accept("abyss_exile", "ch2_chaos")
	Game.add_item(ItemData.jewel("chaos", 8))
	_story().tick(0.5)
	var chaos := Game.jewel_count("chaos")
	_turn_in("abyss_exile", "ch2_chaos")
	check(Game.jewel_count("chaos") == chaos - 8, "the eight chaos jewels are taken")
	Game.paragon().level = 270
	_accept("abyss_exile", "ch2_elites")
	for i in 5:
		Game.report_kill(&"trench_horror")
		Game.report_kill(&"leviathan_whelp")
	check(StoryChapter2.status("ch2_elites") == "ready", "either elite counts")
	_turn_in("abyss_exile", "ch2_elites")
	Game.paragon().level = 280
	_accept("abyss_exile", "ch2_tyrant")
	Game.report_kill(&"tidal_tyrant", true)
	_turn_in("abyss_exile", "ch2_tyrant")
	check((said.get("abyss_exile", {}) as Dictionary).size() >= 3, "the exile has at least three dialog states (%d)" % (said.get("abyss_exile", {}) as Dictionary).size())
	check(StoryChapter2.current() == StoryChapter2.FINALE and not StoryChapter2.portal_open() and not _zone().story_portal_open(), "the finale waits for the scholar; no portal yet")


# --- The finale at 300 stars -------------------------------------------------------------

func _finale() -> void:
	print("== The throne")
	await _go(&"town")
	Game.paragon().level = 290
	_talk("scholar")
	check(not _dialog_has("รับเควสต์") and main.dialog._text.text.contains("300"), "290 stars cannot take the finale")
	main.dialog.close()
	Game.paragon().level = 300
	_accept("scholar", StoryChapter2.FINALE)
	check(StoryChapter2.portal_open(), "the throne portal is open while the finale is active")
	await _go(DrownedAbyssData.ID)
	check(_zone().story_portal_open() and _zone().portals.size() == 2, "the abyss shows the throne portal")
	check(_zone().has_node("Portal_" + String(StoryChapter2.STAGE_ID)), "the portal is built in the world")
	await _go(StoryChapter2.STAGE_ID)
	var zone := _zone()
	var stage: StoryStage = zone.story_stage
	check(stage != null and stage.state == "intro", "the throne stage runs")
	check(zone.has_node("SpecialStageArt") and zone.get_node("SpecialStageArt").has_node("ShadowThroneArt"), "the throne court is built")
	check(zone.portals.size() == 1 and StringName(zone.portals[0].to) == DrownedAbyssData.ID, "the only way out leads back to the abyss")
	stage.step(StoryStage.INTRO + 0.1)
	var queen: Mob = stage.boss
	check(queen != null and is_instance_valid(queen) and queen.monster_id == &"shadow_queen", "the queen rises")
	check(main.dialog.is_open and main.dialog._speaker.text.contains("นิรา"), "she speaks when she appears")
	main.dialog.close()
	var moves := StoryBoss.of(queen)
	check(moves != null and moves.moves.size() == 2, "phase one: two moves")
	var hero: Hero = zone.hero
	queen.take_hit(int(queen.max_hp * 0.35), false, Color.WHITE, hero)
	check(stage.phase == 1 and queen.phase == 1, "70%% health starts phase two")
	check(main.dialog.is_open and main.dialog._text.text.contains("ผู้พิทักษ์"), "phase two interrupts with her line")
	main.dialog.close()
	check(moves.moves.size() == 4 and moves.moves.has("veil") and moves.haste < 1.0, "phase two widens her moves and quickens them")
	moves.force_special("rain")
	check(not moves.telegraph.is_empty() and (moves.telegraph.shapes as Array).size() == StoryBoss.RAIN_COUNT, "the star rain drops three circles")
	moves.tick(StoryBoss.TELEGRAPH + 0.1)
	moves.force_special("veil")
	moves.tick(StoryBoss.TELEGRAPH + 0.1)
	var adds := get_tree().get_nodes_in_group("mobs").filter(func(m): return m.has_meta("story_add"))
	check(adds.size() == StoryBoss.ADD_COUNT, "the veil calls her drowned guardians (%d)" % adds.size())
	queen.take_hit(int(queen.max_hp * 0.3), false, Color.WHITE, hero)
	check(stage.phase == 2 and queen.phase == 2, "40%% health starts phase three")
	check(main.dialog.is_open and main.dialog._text.text.contains("นักบวช"), "phase three interrupts with her last line")
	main.dialog.close()
	check(moves.moves.size() == 5, "phase three: every move")
	var gold := int(Game.profile.gold)
	var cores := Game.jewel_count("set_core")
	queen.take_hit(queen.hp, false, Color.WHITE, hero)
	await get_tree().process_frame
	check(queen.is_dead() and stage.state == "ending", "the queen falls")
	stage.step(StoryStage.END_DELAY + 0.1)
	check(stage.state == "done", "the stage ends")
	var ending: EndingScreen = null
	for child in main.get_children():
		if child is EndingScreen:
			ending = child
	check(ending != null and ending.pages == StoryChapter2.ENDING_PAGES and get_tree().paused, "the ending cutscene plays with the chapter's pages")
	check(StoryChapter2.status(StoryChapter2.FINALE) == "done" and StoryChapter2.finished(), "the finale is done")
	check(int(Game.profile.gold) >= gold + int(StoryChapter2.reward(StoryChapter2.FINALE).gold) and Game.jewel_count("set_core") == cores + 2, "the finale pays once: gold and two set cores")
	check(int(Game.profile.flags.get(StoryChapter2.DONE_FLAG, 0)) == 1 and StoryChapter2.has_aura(), "the done and aura flags are set")
	check(Achievements.is_earned(StoryChapter2.ACH_ID, Game.profile), "the achievement is earned")
	check(Achievements.title_of(Game.profile) == StoryChapter2.END_TITLE, "the title is worn")
	check(not StoryChapter2.portal_open(), "the portal closes with the quest")
	var paid := int(Game.profile.gold)
	_story().on_stage_finished({"won": true})
	check(int(Game.profile.gold) == paid, "a second stage result pays nothing more")
	if ending:
		ending._finish()
	await get_tree().process_frame
	check(not get_tree().paused, "closing the ending resumes the game")
	# Closing the ending takes the hero back up to the abyss, where the portal is gone.
	var guard := 0
	while (main._traveling or _zone() == null or _zone().zone_id != DrownedAbyssData.ID) and guard < 600:
		await get_tree().process_frame
		guard += 1
	await _wait(0.3)
	check(_zone() != null and _zone().zone_id == DrownedAbyssData.ID and not _zone().story_portal_open() and _zone().portals.size() == 1, "back in the abyss without the portal")
	check(_zone().hero.visual.find_child("ShadowStarAura", true, false) != null, "the hero wears the shadow star aura")
	check(_tracker().find("บทที่ 2") < 0, "the tracker drops the chapter line when it is over")
	check(Game.save() and Game.load_game() and StoryChapter2.finished() and Achievements.title_of(Game.profile) == StoryChapter2.END_TITLE, "the finished chapter and its title survive save / load")
	Game.playing = true
	var transfer := Game._decode_import(Game.export_code())
	check(not transfer.is_empty() and int(transfer.flags.get(StoryChapter2.DONE_FLAG, 0)) == 1, "the chapter flags pass the save validation")
	await _go(&"town")
	var epilogue := _talk("scholar")
	check(epilogue.contains(StoryChapter2.END_TITLE), "the scholar's epilogue names the hero's title")
	main.dialog.close()
	check((said.get("scholar", {}) as Dictionary).size() >= 3, "the scholar has at least three dialog states (%d)" % (said.get("scholar", {}) as Dictionary).size())


# --- The world's chat and the quest log ---------------------------------------------------

func _chat_and_log() -> void:
	var lines := StoryChapter2.chat_lines()
	check(not lines.is_empty() and lines.all(func(l): return String(l).contains(String(Game.profile.name)) and (String(l).contains("ราชินีเงา") or String(l).contains("ปราบ"))), "world players speak of the finished chapter truthfully")
	var player := {"name": "ดาวจ๋า", "class": "warrior", "level": 100, "stars": 250, "doing": "hunt", "place": String(DrownedAbyssData.ID), "guild": 1, "index": 0}
	var spoke := false
	for seed_value in 300:
		if StoryChapter2.chat_lines().has(WorldChat.line_for(player, seed_value)):
			spoke = true
	check(spoke, "a starred world player sometimes says one of those lines")
	var fresh_lines_before := StoryChapter2.chat_lines().size()
	Game.profile.flags.erase(StoryChapter2.DONE_FLAG)
	for id in StoryChapter2.ORDER:
		Game.profile.quests.erase(id)
	check(StoryChapter2.chat_lines().size() == 1 and String(StoryChapter2.chat_lines()[0]).contains("ปิ่นดารา") and fresh_lines_before == 2, "before the chapter the chat only says the scholar is looking")
	Game.profile.level = 60
	check(StoryChapter2.chat_lines().is_empty(), "no chapter talk around a low-level hero")
