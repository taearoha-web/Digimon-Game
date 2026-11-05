extends Node
## The Defender's เบ่งเลือด (skill id "brace"): max HP +30% and damage taken -10% for a
## minute at ★1, +50% / -25% at ★5; the added HP is filled in and goes when it ends; it
## is the Defender's own; it always stays on the bar; AI casters get the HP too.
##   godot --headless --path . res://tests/integration/blood_swell_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	WorldEvents.festival_enabled = false
	var spec := ClassData.find_skill(&"defender", "brace")
	check(String(spec.name) == "เบ่งเลือด" and int(spec.level) == 10 and String(spec.shape) == "self", "the Defender's Lv.10 self skill is เบ่งเลือด")
	check(BuffBook.is_self_only(spec.fx.buff), "it is the Defender's own buff")
	var r1: Dictionary = SkillRank.scaled_fx(spec.fx, 1).buff
	var r5: Dictionary = SkillRank.scaled_fx(spec.fx, 5).buff
	check(is_equal_approx(float(r1.hp), 0.30) and is_equal_approx(float(r1.guard), 0.10), "★1: HP +30%%, damage -10%% (%s)" % [r1])
	check(is_equal_approx(float(r5.hp), 0.50) and is_equal_approx(float(r5.guard), 0.25), "★5: HP +50%%, damage -25%% (%s)" % [r5])
	check(is_equal_approx(float(r1.secs), 60.0), "it lasts one minute")
	var rows := SkillRank.table(spec)
	var hp_row: Array = []
	var guard_row: Array = []
	for row in rows:
		if String(row[0]) == "บัฟHP สูงสุด":
			hp_row = row[1]
		elif String(row[0]) == "บัฟลดดาเมจ":
			guard_row = row[1]
	check(hp_row == ["+30%", "+35%", "+40%", "+45%", "+50%"], "the Skill Master shows HP +30..+50%% (%s)" % [hp_row])
	check(not guard_row.is_empty() and guard_row[0] == "+10%" and guard_row[4] == "+25%", "and damage -10..-25%% (%s)" % [guard_row])

	# The hero: cast at ★1 in a field.
	Game.new_profile(&"defender", "Swell QA", FaceKit.default_look())
	Game.profile.level = 30
	Game.profile.adv = 1
	Game.fill_loadout()
	check(Game.loadout().has("brace"), "a Defender has เบ่งเลือด on the bar")
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	await main.go(&"meadow", true)
	await get_tree().create_timer(0.5).timeout
	var hero: Hero = main.zone.hero
	hero._invulnerable_until = Time.get_ticks_msec() + 600000
	hero.refresh_stats()
	var base_max := int(hero.stats.max_hp)
	Game.profile.hp = base_max
	Game.profile.mp = 99999
	var slot := Game.loadout().find("brace")
	check(hero.use_skill(slot) == "", "the Defender casts เบ่งเลือด")
	await get_tree().create_timer(0.6).timeout
	var swollen := int(hero.stats.max_hp)
	check(absi(swollen - int(base_max * 1.3)) <= 2, "★1: max HP %d -> %d (+30%%)" % [base_max, swollen])
	check(int(Game.profile.hp) == swollen, "and the added HP is filled in (%d / %d)" % [int(Game.profile.hp), swollen])
	check(absi(int(Game.stats_now().max_hp) - swollen) <= 2, "every stats_now reader sees the raised maximum")
	Game.clamp_vitals()
	check(int(Game.profile.hp) == swollen, "clamp_vitals keeps the swollen HP")
	check(BuffBook.absorb(hero._buffs, 1000) == 900, "damage taken -10%% (1000 -> %d)" % BuffBook.absorb(hero._buffs, 1000))
	# A recast refreshes it without stacking more HP.
	hero.cooldowns.clear()
	hero._cast_until = 0
	check(hero.use_skill(slot) == "", "recast")
	await get_tree().create_timer(0.6).timeout
	check(int(hero.stats.max_hp) == swollen and int(Game.profile.hp) == swollen, "a recast refreshes it, no extra HP")
	# It ends: the maximum and the HP above it go back.
	for buff in hero._buffs:
		buff.until = 1
	await get_tree().create_timer(0.2).timeout
	check(int(hero.stats.max_hp) == base_max and int(Game.profile.hp) <= base_max, "when it ends HP goes back to %d (max %d hp %d buffs %d)" % [base_max, int(hero.stats.max_hp), int(Game.profile.hp), hero._buffs.size()])
	check(is_equal_approx(Game.live_hp_buff, 0.0), "and stats_now loses the buff")
	# ★5.
	Game.profile.skills["brace"] = 5
	hero.cooldowns.clear()
	hero._cast_until = 0
	Game.profile.hp = base_max
	check(hero.use_skill(slot) == "", "cast at ★5")
	await get_tree().create_timer(0.6).timeout
	check(absi(int(hero.stats.max_hp) - int(base_max * 1.5)) <= 2, "★5: max HP +50%% (%d)" % int(hero.stats.max_hp))
	check(BuffBook.absorb(hero._buffs, 1000) == 750, "★5: damage taken -25%% (1000 -> %d)" % BuffBook.absorb(hero._buffs, 1000))

	# Always on the bar: not replaced from outside, put back when missing.
	var other := ""
	for sk in ClassData.pool(&"defender"):
		if String(sk.id) != "brace" and Game.skill_unlocked(sk) and not Game.loadout().has(String(sk.id)):
			other = String(sk.id)
			break
	if other != "":
		check(not Game.equip_skill(other, slot) and Game.loadout()[slot] == "brace", "another skill cannot take เบ่งเลือด's slot")
	var bar: Array = Game.loadout()
	bar[slot] = ""
	Game.fill_loadout()
	check(Game.loadout().has("brace"), "fill_loadout puts it back on the bar")

	# AI: a rival gets the HP and loses it again.
	var rival := Rival.new()
	rival.max_hp = 1000
	rival.hp = 1000
	rival._raise_hp(0.3)
	check(rival.max_hp == 1300 and rival.hp == 1300, "a rival's เบ่งเลือด raises HP to %d/%d" % [rival.hp, rival.max_hp])
	rival._raise_hp(0.3)
	check(rival.max_hp == 1300, "a second cast does not stack")
	rival._drop_hp_bonus()
	check(rival.max_hp == 1000 and rival.hp == 1000, "and it ends back at %d/%d" % [rival.hp, rival.max_hp])
	rival.free()
	print("BLOOD SWELL: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
