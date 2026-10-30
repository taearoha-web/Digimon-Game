extends Node
## The first five minutes (headless): a fresh Lv.1 hero in the village starts the tutorial
## (Tutorial on Main) at step 1 with an online world player force-joined as the guide, who
## greets through the world chat; the steps finish from the game state alone (a quest taken,
## a potion added, the first field, three kills, a quest turned in), each with a banner and a
## hint toast repeated while pending; the finish gives five potions, marks flags["tut"] 99 and
## the guide says goodbye and leaves; a Lv.6 hero and a hero with tut 99 never start, and a
## hero reaching Lv.6 midway ends it silently.
##   godot --headless --path . res://tests/integration/tutorial_test.tscn
var failures := 0
var checks := 0
var main: Node
var chat: Array = []
var toasts: Array = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ready() -> void:
	WorldPlayers.clear_bonus()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.3)
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	check(main.tutorial != null and main.tutorial is Tutorial, "Main carries the tutorial")
	Game.world_chat.connect(func(speaker: String, text: String, _c: Color): chat.append([speaker, text]))
	Game.toast.connect(func(text: String, _kind: StringName): toasts.append(text))
	# A busy moment of the world's third day: plenty of low-level players online.
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 2.4 * 86400.0 - WorldPlayers.now()
	await _fresh_hero()
	await _lv6_never_starts()
	await _done_never_starts()
	await _lv6_midway()
	print("TUTORIAL: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _new_hero(level := 1) -> void:
	Game.new_profile(ClassData.START, "มือใหม่", FaceKit.default_look())
	Game.profile.level = level
	Game.profile.hp = Game.stats_now().max_hp
	Game.playing = true
	main.hud.visible = true
	main._traveling = false
	await main.go(&"town", true)
	await _wait(1.0)


func _count(text: String) -> int:
	return toasts.filter(func(t: String) -> bool: return t.begins_with(text)).size()


func _hp_potions() -> int:
	var n := 0
	for item in Game.profile.inv:
		if item.get("kind", "") == "potion" and String(item.id).begins_with("hp_"):
			n += int(item.count)
	return n


func _guide_here() -> bool:
	for c in main.zone.companions:
		if c is FieldPlayer and (c as FieldPlayer).party_mode and (c as FieldPlayer).world_index == main.tutorial.guide:
			return true
	return false


func _fresh_hero() -> void:
	var tut: Tutorial = main.tutorial
	var expected_guide := Tutorial.pick_guide(WorldPresence.clock())
	check(expected_guide >= 0, "someone is online to guide a newcomer")
	if expected_guide >= 0:
		var s := WorldPlayers.state(expected_guide, WorldPresence.clock())
		check(bool(s.online) and int(s.guild) == 0, "the guide is an online player without a guild (%s Lv.%d)" % [s.name, int(s.level)])
	await _new_hero()
	check(int(Game.profile.flags.get("tut", 0)) == 1 and tut.step == 1, "a fresh Lv.1 hero in the village starts step 1 (flag %s)" % str(Game.profile.flags.get("tut")))
	check(toasts.has(Tutorial.HINTS[1]) and tut.shown.size() == 1, "step 1 shows its hint")
	var guide_name := ""
	if expected_guide >= 0:
		guide_name = String(WorldPlayers.entry(expected_guide).name)
		check(tut.guide == expected_guide and tut.guide_forced and Game.party().size() == 1 and Game.in_party(expected_guide), "the guide force-joins the party")
		check(_guide_here(), "the guide walks in the village with the hero")
		check(chat.has([guide_name, PartyTalk.GUIDE_LINES[1][0]]), "the guide says hello in the world chat")
	await _wait(Tutorial.GREET_TIME + 0.8)
	check(tut.step == 2 and int(Game.profile.flags.tut) == 2 and _count(Tutorial.HINTS[2]) == 1, "the greeting leads to step 2: talk to the elder")
	# The hint is repeated while the step is pending, rate-limited.
	tut._hint_at = -INF
	await _wait(0.8)
	check(_count(Tutorial.HINTS[2]) == 2, "a pending step's hint is repeated (rate-limited)")
	Game.profile.quests["slimes"] = {"status": "active", "progress": 0}
	await _wait(0.8)
	check(tut.step == 3 and _count(Tutorial.HINTS[3]) == 1, "an active quest completes step 2")
	var before := _hp_potions()
	await _wait(0.8)
	check(tut.step == 3, "the starter potions do not finish step 3 by themselves")
	Game.add_item(ItemData.potion("hp_s", 2))
	await _wait(0.8)
	check(tut.step == 4 and _hp_potions() == before + 2 and _count(Tutorial.HINTS[4]) == 1, "a potion added completes step 3")
	await main.go(&"meadow", true)
	await _wait(1.0)
	check(tut.step == 5 and Game.current_zone == &"meadow", "the first field completes step 4")
	check(_count(Tutorial.HINTS[5]) == 1 and toasts.has(Tutorial.HINTS[5] + " (0/3)"), "step 5 counts the kills in its hint")
	if expected_guide >= 0:
		check(_guide_here(), "the guide walks into the field with the hero")
	Game.profile.kills = int(Game.profile.kills) + 3
	await _wait(0.8)
	check(tut.step == 6 and _count(Tutorial.HINTS[6]) == 1, "three kills complete step 5")
	before = _hp_potions()
	Game.profile.quests["slimes"]["status"] = "done"
	await _wait(0.8)
	check(tut.step == 0 and int(Game.profile.flags.tut) == 99, "a quest turned in finishes the tutorial (flag %s)" % str(Game.profile.flags.get("tut")))
	check(_hp_potions() == before + 5 and toasts.has(Tutorial.FINISH_BANNER), "the finish gives five potions and says so")
	check(not Game.profile.flags.has("tut_k") and not Game.profile.flags.has("tut_p"), "the step counters are cleared")
	if expected_guide >= 0:
		var goodbye := chat.filter(func(line: Array) -> bool: return line[0] == guide_name and PartyTalk.GUIDE_LINES[7].has(line[1]))
		check(not goodbye.is_empty(), "the guide says goodbye")
		await _wait(Tutorial.GOODBYE_TIME + 0.8)
		check(not Game.in_party(expected_guide) and Game.party().is_empty(), "the guide leaves the party after the tutorial")
	await _wait(1.0)
	check(tut.step == 0 and int(Game.profile.flags.tut) == 99, "a finished tutorial stays finished")


func _lv6_never_starts() -> void:
	toasts.clear()
	await _new_hero(6)
	check(main.tutorial.step == 0 and int(Game.profile.flags.get("tut", 0)) == 99, "a Lv.6 hero never starts the tutorial")
	check(Game.party().is_empty() and not toasts.has(Tutorial.HINTS[1]), "no guide and no hint for a Lv.6 hero")


func _done_never_starts() -> void:
	toasts.clear()
	Game.new_profile(ClassData.START, "มือเก่า", FaceKit.default_look())
	Game.profile.flags["tut"] = 99
	Game.profile.hp = Game.stats_now().max_hp
	main._traveling = false
	await main.go(&"town", true)
	await _wait(1.0)
	check(main.tutorial.step == 0 and Game.party().is_empty() and not toasts.has(Tutorial.HINTS[1]), "a hero with tut 99 never starts the tutorial")


## Lv.6 reached midway: the tutorial ends without a word and the forced guide goes too.
func _lv6_midway() -> void:
	toasts.clear()
	await _new_hero()
	var tut: Tutorial = main.tutorial
	check(tut.step == 1, "another fresh hero starts the tutorial again")
	var forced := tut.guide_forced
	Game.profile.level = 6
	await _wait(0.8)
	check(tut.step == 0 and int(Game.profile.flags.tut) == 99, "reaching Lv.6 ends the tutorial silently")
	check(not toasts.has(Tutorial.FINISH_BANNER) and (not forced or Game.party().is_empty()), "no finish banner, and the forced guide leaves")
