extends Node
## The class is picked on the create screen (no Vagabond start, no Lv.10 line choice):
## every class plays from Lv.1 with its own skills, passive and weapon, its skills and
## advancements open in order; the create screen's class picker fits a phone; an old save
## still a Vagabond (ClassData.LEGACY) picks its class once on load and keeps its progress;
## no world player is a Vagabond.
var failures := 0
var checks := 0
var main: Node

## A phone app in landscape, a narrow phone browser and a portrait window.
const SHAPES := [Vector2i(1688, 780), Vector2i(1280, 720), Vector2i(800, 1000)]


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	await get_tree().process_frame
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	_check_classes()
	_check_world_players()
	await _check_create_screen()
	await _check_old_save()
	if main:
		main.queue_free()
		main = null
		await frames(3)
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	print("class_pick_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _check_classes() -> void:
	check(not ClassData.IDS.has(ClassData.LEGACY) and ClassData.IDS.size() == 10, "ten playable classes, the Vagabond not among them")
	for cls in ClassData.IDS:
		Game.new_profile(cls, "ทดสอบ", FaceKit.default_look())
		check(Game.class_id() == cls and int(Game.profile.level) == 1 and Game.class_tier() == 1 and not Game.needs_class(), "%s: a new hero is a Lv.1 %s" % [cls, cls])
		var bar := Game.loadout_skills()
		check(not (bar[0] as Dictionary).is_empty() and Game.skill_unlocked(bar[0]) and Game.skill_lock_reason(bar[0]) == "" and Game.effective_rank(bar[0]) == 1, "%s: its first skill is on the bar and usable at Lv.1" % cls)
		check(Game.loadout().filter(func(id): return String(id) != "").size() == 1, "%s: one skill at Lv.1" % cls)
		var passive: Dictionary = Game.passive_pool()[0]
		check(int(passive.level) == 1 and Game.skill_unlocked(passive), "%s: its first passive works from Lv.1" % cls)
		var weapon: Dictionary = Game.profile.equip.get("weapon", {})
		check(String(weapon.get("class", "")) == String(cls) and String(weapon.get("name", "")).ends_with("ของมือใหม่"), "%s: starts with its own beginner weapon" % cls)
		check(Game._valid_profile(Game.profile.duplicate(true)), "%s: the new save passes the save check" % cls)
		check(Game.next_step_level() == JobData.TIER_LEVELS[0] and not Game.next_step().is_empty(), "%s: the first advancement waits at Lv.%d" % [cls, JobData.TIER_LEVELS[0]])
		# Every skill opens at its own level once the advancements due by then are taken, in order.
		var last := 0
		var ordered := true
		for skill in ClassData.pool(cls):
			if skill.has("star"):
				continue
			var lv := int(skill.level)
			ordered = ordered and lv >= last
			last = lv
			Game.profile["level"] = lv
			Game.profile["adv"] = JobData.adv_for_level(lv)
			check(Game.skill_unlocked(skill), "%s: %s opens at Lv.%d" % [cls, skill.id, lv])
			Game.profile["level"] = maxi(1, lv - 1)
			Game.profile["adv"] = JobData.adv_for_level(maxi(1, lv - 1))
			check(lv == 1 or not Game.skill_unlocked(skill), "%s: %s stays shut below Lv.%d" % [cls, skill.id, lv])
		check(ordered, "%s: the skill pool is in unlock order" % cls)
		# Lv.5: the second skill joins the bar on its own.
		Game.profile["level"] = 1
		Game.profile["adv"] = 0
		Game.profile["exp"] = 0
		Game.add_exp(HeroStats.exp_to_next(1) + HeroStats.exp_to_next(2) + HeroStats.exp_to_next(3) + HeroStats.exp_to_next(4))
		check(int(Game.profile.level) == 5 and Game.loadout().filter(func(id): return String(id) != "").size() == 2, "%s: at Lv.5 the second skill is on the bar" % cls)
		Game.delete_save()


func _check_world_players() -> void:
	var t := WorldPlayers.now()
	var ok := true
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		ok = ok and ClassData.IDS.has(StringName(s["class"])) and ClassData.IDS.has(StringName(WorldPlayers.member(i, t)["class"]))
	check(ok, "no world player is a Vagabond")


func _check_create_screen() -> void:
	for shape in SHAPES:
		get_window().size = shape
		var screen := ClassSelect.new()
		add_child(screen)
		await frames(4)
		check(screen._class_buttons.size() == ClassData.IDS.size(), "%s: ten class buttons" % shape)
		check(screen.picked == ClassData.DEFAULT and screen._stage.visual.class_id == ClassData.DEFAULT, "%s: a class is picked from the start, shown on the stage" % shape)
		screen.set_class(&"mage")
		await frames(3)
		check(screen.picked == &"mage" and (screen._class_buttons[&"mage"] as Button).disabled and screen._stage.visual.class_id == &"mage", "%s: tapping the mage shows a mage" % shape)
		check(screen._class_desc.text == String(ClassData.get_class_data(&"mage").desc) and screen._class_main.text.contains("INT") and screen._class_skills.text.contains("Lv.1"), "%s: its description, main stat and first skills" % shape)
		var canvas := get_viewport().get_visible_rect().size
		for label in [screen._class_title, screen._class_desc, screen._class_role, screen._class_main, screen._class_skills]:
			var r: Rect2 = (label as Label).get_global_rect()
			check(r.position.x >= -1.0 and r.end.x <= canvas.x + 1.0 and (label as Label).autowrap_mode != TextServer.AUTOWRAP_OFF, "%s: '%s' wraps inside the screen" % [shape, (label as Label).text.left(20)])
		for id in screen._class_buttons:
			var b: Rect2 = (screen._class_buttons[id] as Button).get_global_rect()
			check(b.position.x >= -1.0 and b.end.x <= canvas.x + 1.0 and b.size.y >= 44.0, "%s: the %s button is on screen and tappable" % [shape, id])
		var got := []
		screen.confirmed.connect(func(cls: StringName, hero_name: String, look: Dictionary): got.append([cls, hero_name, look]))
		screen._name_input.text = "เมจน้อย"
		screen._on_confirm()
		check(got.size() == 1 and got[0][0] == &"mage" and got[0][1] == "เมจน้อย", "%s: creating sends the picked class" % shape)
		screen.queue_free()
		await frames(2)
	get_window().size = Vector2i(1280, 720)


func _check_old_save() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(10)
	# An old Lv.14 Vagabond with spent stat points and a skill rank, saved in slot 2.
	Game.slot = 2
	Game.new_profile(ClassData.LEGACY, "เก่าแก่", FaceKit.default_look())
	Game.profile["level"] = 14
	Game.profile["exp"] = 77
	Game.profile["points"] = 2
	Game.profile["attrs"] = {"str": 20, "int": 0, "dex": 4, "vit": 12}
	Game.profile["skills"] = {"round_slash": 4}
	Game.profile["gold"] = 4321
	var sp_before := int(Game.profile.skill_points)
	Game.save()
	Game.has_profile = false
	check(Game.slot_info(2).get("class", "") == "vagabond", "the old save still reads as a Vagabond on the character select")
	main._continue(2)
	await frames(6)
	var pick: ClassSelect = main.class_screen as ClassSelect
	check(pick != null and pick.pick_only, "loading an old Vagabond save opens the class picker")
	check(main.zone == null and not Game.playing, "and play waits for the pick")
	if pick == null:
		return
	check(pick._name_input == null and pick._class_buttons.size() == ClassData.IDS.size(), "the picker shows only the classes (no name or look)")
	# Back: to the character select, still a Vagabond.
	pick.cancelled.emit()
	await frames(4)
	check(main.class_screen == null and main.title_screen != null, "back returns to the character select")
	check(Game.slot_info(2).get("class", "") == "vagabond", "going back converts nothing")
	main._continue(2)
	await frames(6)
	pick = main.class_screen as ClassSelect
	check(pick != null and pick.pick_only, "the picker comes back on the next load")
	if pick == null:
		return
	pick.set_class(&"lancer")
	(pick.find_child("Confirm", true, false) as Button).pressed.emit()
	var waited := 0
	while main.zone == null and waited < 600:
		await get_tree().process_frame
		waited += 1
	check(main.zone != null and Game.playing and main.class_screen == null, "after the pick the game starts")
	check(Game.class_id() == &"lancer" and int(Game.profile.level) == 14 and int(Game.profile.exp) == 77 and int(Game.profile.gold) >= 4321, "converted to a lancer, level, EXP and gold kept (Lv.%d, %d EXP, %d gold)" % [int(Game.profile.level), int(Game.profile.exp), int(Game.profile.gold)])
	check(int(Game.profile.points) == 38 and int(Game.profile.attrs.str) == 0, "every stat point is back to spend (%d)" % int(Game.profile.points))
	check(int(Game.profile.skill_points) == sp_before + 3 and not Game.profile.skills.has("round_slash"), "the Vagabond's skill ranks are back as skill points")
	check(String(Game.profile.equip.weapon["class"]) == "lancer", "the Vagabond's weapon became a spear")
	check(String(Game.loadout()[0]) != "" and Game.skill_lock_reason(Game.loadout_skills()[0]) == "", "the lancer's skills are on the bar, usable")
	Game.save()
	check(Game.slot_info(2).get("class", "") == "lancer", "the save holds the new class")
	check(Game.load_game(2) and not Game.needs_class(), "the next load asks nothing")
	Game.playing = false
