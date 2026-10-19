extends Node
## Skill stars: every star of every skill changes what the skill does, the
## combat code reads the same numbers as the Skill Master's per-star table, and
## upgrading at the Skill Master keeps the list where the player was.
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func settle() -> void:
	for i in 5:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	await get_tree().process_frame
	_check_tables()
	_check_scaling()
	await _check_trainer()
	print("skill_rank_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## Every active and passive skill of every class: one table row per value, a
## value per star, and every upgrade (1->2 .. 4->5) changes at least the damage
## or, for skills without damage, the heal / buff / control.
func _check_tables() -> void:
	for cls in ClassData.IDS:
		for skill in ClassData.pool(cls):
			var rows := SkillRank.table(skill)
			check(rows.size() >= 2, "%s has a star table" % skill.id)
			for row in rows:
				check((row[1] as Array).size() == SkillRank.MAX, "%s row %s has five stars" % [skill.id, row[0]])
			for rank in range(1, SkillRank.MAX):
				var changes := SkillRank.next_changes(rows, rank)
				var main := 0
				for c in changes:
					if not c.begins_with("MP") and not c.begins_with("คูลดาวน์"):
						main += 1
				check(main > 0, "%s ★%d->★%d raises a value besides MP/cooldown (%s)" % [skill.id, rank, rank + 1, ", ".join(changes)])
			check(SkillRank.next_changes(rows, SkillRank.MAX).is_empty(), "%s has nothing after ★5" % skill.id)
		for passive in ClassData.PASSIVES.get(cls, []):
			var rows := SkillRank.passive_table(passive)
			check(not rows.is_empty(), "passive %s has a star table" % passive.id)
			for rank in range(1, SkillRank.MAX):
				check(not SkillRank.next_changes(rows, rank).is_empty(), "passive %s ★%d->★%d grows" % [passive.id, rank, rank + 1])


func _check_scaling() -> void:
	var buff_skill := {"id": "t", "shape": "self", "mp": 10, "cd": 20.0, "mult": 0.0, "fx": {"buff": {"atk": 0.5, "def": 0.25, "secs": 60.0}, "heal": 0.9, "stun": 1.0}}
	var at5 := SkillRank.scaled(buff_skill, 5)
	check(is_equal_approx(float(at5.fx.buff.atk), 0.5 * 1.32), "★5 buff +32%")
	check(is_equal_approx(float(at5.fx.buff.secs), 60.0), "buff time stays one minute")
	check(is_equal_approx(float(at5.fx.heal), 1.0), "heal capped at full HP")
	check(is_equal_approx(float(at5.fx.buff.shield), 0.9 * 1.4 - 1.0), "heal past full HP becomes a shield")
	check(not buff_skill.fx.buff.has("shield"), "the overheal shield is not written into the skill data")
	var heal_only := {"id": "h", "shape": "self", "mp": 10, "cd": 20.0, "mult": 0.0, "fx": {"heal": 0.9}}
	var shield: Dictionary = SkillRank.scaled(heal_only, 5).fx.buff
	check(bool(shield.get("overheal", false)) and is_equal_approx(float(shield.secs), 60.0), "heal-only overheal is a 1-minute shield")
	var book: Array = []
	book = BuffBook.insert(book, {"atk": 0.3, "secs": 60.0}, Color.RED, "a", false, "a")
	book = BuffBook.insert(book, {"def": 0.3, "secs": 60.0}, Color.RED, "b", false, "b")
	book = BuffBook.insert(book, shield, Color.GREEN, "h", false, "h")
	check(book.size() == 3, "the overheal shield does not push out the two buffs")
	book = BuffBook.insert(book, {"crit": 0.1, "secs": 60.0}, Color.RED, "c", false, "c")
	check(book.size() == 3 and BuffBook.contains(book, "h", false), "a third buff replaces a buff, not the shield")
	check(is_equal_approx(float(at5.fx.stun), 1.24), "★5 stun +24%")
	check(is_equal_approx(float(buff_skill.fx.buff.atk), 0.5), "scaling does not touch the skill data")
	check(SkillRank.scaled(buff_skill, 1) == buff_skill, "★1 is the skill as written")
	var chain := {"id": "c", "shape": "chain", "hits": 3, "mp": 10, "cd": 5.0, "mult": 1.0, "radius": 4.0}
	check(SkillRank.hits(chain, 2) == 3 and SkillRank.hits(chain, 3) == 4 and SkillRank.hits(chain, 5) == 5, "chains gain a target at ★3 and ★5")
	check(is_equal_approx(float(SkillRank.scaled(chain, 5).radius), 4.0 * 1.32), "★5 area +32%")
	check(is_equal_approx(SkillRank.power(5), 1.6), "★5 damage +60%")
	check(is_equal_approx(Game.radius_scale(3), SkillRank.radius_scale(3)), "Game.radius_scale reads SkillRank")
	# The hero's own numbers come from SkillRank.
	Game.new_profile(&"priest", "Rank QA", FaceKit.default_look())
	Game.profile.level = 100
	var skill: Dictionary = Game.skill_pool()[0]
	Game.profile.skills[skill.id] = 4
	var hero := Hero.new()
	check(is_equal_approx(hero.rank_mult(skill), SkillRank.power(4)), "hero damage per star matches the table")
	check(hero.mp_cost(skill) == SkillRank.mp(skill, 4), "hero MP per star matches the table")
	hero.free()


func _check_trainer() -> void:
	Game.new_profile(&"warrior", "Trainer QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.skill_points = 40
	Game.profile.gold = 10000000
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	var trainer := SkillTrainer.new()
	add_child(trainer)
	trainer.open_trainer()
	await settle()
	var tables := trainer._box.find_children("RankTable", "", true, false)
	check(tables.size() == Game.skill_pool().size() + Game.passive_pool().size(), "every skill row shows its star table")
	var scroll: TouchScroll = trainer._scroll
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "the skill list scrolls")
	scroll.scroll_vertical = 900
	await settle()
	var before := scroll.scroll_vertical
	check(before > 100, "fixture starts below the first page")
	var target: Dictionary = {}
	for skill in Game.skill_pool():
		if Game.skill_unlocked(skill) and Game.effective_rank(skill) < SkillRank.MAX:
			target = skill
	var rank := Game.effective_rank(target)
	check(Game.upgrade_skill(target), "upgrade at the Skill Master")
	await settle()
	check(Game.effective_rank(target) == rank + 1, "one star added")
	check(scroll.scroll_vertical == before, "upgrading keeps the list where it was (%d vs %d)" % [scroll.scroll_vertical, before])
	var next_lines := trainer._box.find_children("NextStar", "", true, false)
	check(next_lines.any(func(n): return String(n.text).begins_with("อัปเป็นดาว %d:" % (rank + 2))), "the upgraded skill now shows its next star")
	check(next_lines.all(func(n): return String(n.text) != ""), "every row says what the next star adds")
	# Optional screenshot: godot --path . res://tests/integration/skill_rank_test.tscn -- /abs/folder
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(args[0])
		for y in [0, before]:
			scroll.scroll_vertical = y
			await settle()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(args[0].path_join("skill_trainer_%d.png" % y))
	trainer.close_trainer()
